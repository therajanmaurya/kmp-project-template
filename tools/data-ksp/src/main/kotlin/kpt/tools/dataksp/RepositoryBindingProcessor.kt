/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.tools.dataksp

import com.google.devtools.ksp.processing.CodeGenerator
import com.google.devtools.ksp.processing.Dependencies
import com.google.devtools.ksp.processing.KSPLogger
import com.google.devtools.ksp.processing.Resolver
import com.google.devtools.ksp.processing.SymbolProcessor
import com.google.devtools.ksp.processing.SymbolProcessorEnvironment
import com.google.devtools.ksp.processing.SymbolProcessorProvider
import com.google.devtools.ksp.symbol.KSAnnotated
import com.google.devtools.ksp.symbol.KSClassDeclaration
import com.google.devtools.ksp.symbol.KSFunctionDeclaration
import com.google.devtools.ksp.symbol.KSType
import com.google.devtools.ksp.symbol.KSValueParameter

/**
 * Derives `GeneratedRepositoryBindings` from `@RepositoryBinding` on repository implementations.
 *
 * The binding for a repository is mechanical — `single<Iface> { Impl(a = get(), b = get(q)) }` — and
 * was hand-written for twelve implementations across two modules. Mechanical is exactly what an
 * annotation should own: the constructor already states the dependencies, so a hand-written module
 * restates them, and a repository whose binding is forgotten fails at Koin graph construction rather
 * than at compile time.
 *
 * Bindings whose VALUE needs a lambda — an outbox serializer, a syncer's `submitBlock`, a
 * bookkeeper's `keySerializer` — are derived too, via `@DataProvider` on a factory FUNCTION. The
 * lambda stays in the function body where it is readable and type-checked; only the wiring is
 * generated. That is the same split `@StoreProvider` makes for a Store5 fetcher, and it is what
 * let the last hand-written data module go away.
 */
class RepositoryBindingProcessor(
    private val codeGenerator: CodeGenerator,
    private val logger: KSPLogger,
) : SymbolProcessor {
    private var emitted = false

    /** `@StoreProvider` id → the Koin qualifier symbol store-ksp generates for it. */
    private var storeQualifiers: Map<String, String> = emptyMap()

    /**
     * The registry symbol for a `@FromStore` id. Falls back to the id-derived name when no
     * `@StoreProvider` declares it — the store may live in a module this round cannot see, and a
     * genuinely wrong id still surfaces as an unresolved reference rather than a silent miss.
     */
    private fun registrySymbol(storeId: String): String =
        storeQualifiers[storeId] ?: storeId.replaceFirstChar { it.uppercaseChar() }

    override fun process(resolver: Resolver): List<KSAnnotated> {
        if (emitted) return emptyList()
        emitted = true

        // `@FromStore("x")` has to resolve to the SAME Koin qualifier store-ksp generated for the
        // store whose `@StoreProvider(id = "x")` declared it. store-ksp derives that symbol as
        // `qualifier.ifEmpty { id.replaceFirstChar(uppercase) }` — so an explicit `qualifier = "Y"`
        // makes the symbol `AppStoreRegistry.Y`, while this processor used to emit
        // `AppStoreRegistry.X` unconditionally. The two agreed only while no store set `qualifier`.
        //
        // The divergence fails the build (unresolved reference in generated code) rather than
        // corrupting anything, but it fails pointing at a file nobody wrote, describing a symbol
        // nobody typed. Reading the same annotation store-ksp reads removes the disagreement at the
        // source instead of documenting it.
        storeQualifiers = resolver.getSymbolsWithAnnotation(ANN_STORE_PROVIDER)
            .filterIsInstance<KSFunctionDeclaration>()
            .mapNotNull { fn ->
                val a = fn.annotations.firstOrNull { it.shortName.asString() == "StoreProvider" }
                    ?: return@mapNotNull null
                fun arg(n: String) = a.arguments.firstOrNull { it.name?.asString() == n }?.value as? String
                val id = arg("id")?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
                id to (arg("qualifier")?.takeIf { it.isNotBlank() } ?: id.replaceFirstChar { it.uppercaseChar() })
            }
            .toMap()

        val impls = resolver.getSymbolsWithAnnotation(ANN_BINDING)
            .filterIsInstance<KSClassDeclaration>()
            .toList()

        val rows = impls.mapNotNull { decl -> spec(decl) }.sortedBy { it.iface.substringAfterLast('.') }

        // Two implementations bound to one interface means the later `single` silently shadows the
        // earlier everywhere it is injected — Koin keeps the last definition for a type.
        rows.groupBy { it.iface }.filterValues { it.size > 1 }.forEach { (iface, dup) ->
            logger.error("data-ksp: $iface is bound by ${dup.joinToString { it.impl }}")
        }

        val providers = resolver.getSymbolsWithAnnotation(ANN_PROVIDER)
            .filterIsInstance<KSFunctionDeclaration>()
            .mapNotNull { fn -> provider(fn) }
            .toList()
            .sortedBy { it.fnName }

        // Two bindings under one qualifier is the failure the qualifier exists to prevent.
        providers.filter { it.qualifier.isNotBlank() }
            .groupBy { it.qualifier }.filterValues { it.size > 1 }
            .forEach { (q, dup) ->
                logger.error("data-ksp: qualifier '$q' is bound by ${dup.joinToString { it.fnName }}")
            }

        write(render(rows, providers), impls.mapNotNull { it.containingFile } + providers.mapNotNull { it.decl })
        writeQualifiers(providers)
        logger.info("data-ksp: ${rows.size} repository + ${providers.size} provider binding(s)")
        return emptyList()
    }

    private data class Row(val iface: String, val impl: String, val args: List<Pair<String, String>>)

    private data class Prov(
        val fnName: String,
        val fnFqn: String,
        val returns: String,
        val qualifier: String,
        val eager: Boolean,
        val args: List<Pair<String, String>>,
        val decl: com.google.devtools.ksp.symbol.KSFile?,
    )

    /**
     * One constructor dependency of a `@DataProvider` factory → `name to <Koin resolve expression>`,
     * or null when the parameter is defaulted (the fork may leave it unset) or has no usable name.
     *
     * Split out of [provider] so that function reads as "parse the annotation, resolve the bound
     * type, emit the binding" rather than also carrying the per-parameter resolution strategy.
     */
    private fun dependency(param: KSValueParameter): Pair<String, String>? {
        // Defaulted parameters are the fork's to leave unset; an unnamed one cannot be emitted.
        val name = param.name?.asString()
        if (param.hasDefault || name == null) return null
        val storeId = param.annotations.firstOrNull { it.shortName.asString() == "FromStore" }
            ?.arguments?.firstOrNull { it.name?.asString() == "id" }?.value as? String
        val named = param.annotations.firstOrNull { it.shortName.asString() == "FromQualifier" }
            ?.arguments?.firstOrNull { it.name?.asString() == "name" }?.value as? String
        // A nullable dependency is OPTIONAL — resolving it with get() would fail the graph for a
        // fork that never installed it.
        val nullable = param.type.resolve().isMarkedNullable
        val resolve = when {
            !storeId.isNullOrBlank() -> "get($REGISTRY.${registrySymbol(storeId)})"
            !named.isNullOrBlank() -> "get(named(\"$named\"))"
            nullable -> "getOrNull()"
            else -> "get()"
        }
        return name to resolve
    }

    /** A `@DataProvider` factory function: return type is the bound type, parameters are the deps. */
    private fun provider(fn: KSFunctionDeclaration): Prov? {
        val fqn = fn.qualifiedName?.asString()
        val ann = fn.annotations.firstOrNull { it.shortName.asString() == "DataProvider" }
        val ret = fn.returnType?.resolve()

        // Only an unresolvable RETURN TYPE is a user error worth reporting: a missing qualified
        // name or a function that simply is not annotated are both "not ours", and reporting them
        // would fire on every unrelated declaration KSP hands us.
        if (fqn != null && ann != null && ret == null) {
            logger.error("data-ksp: @DataProvider ${fn.simpleName.asString()} has no resolvable return type")
        }
        if (fqn == null || ann == null || ret == null) return null

        val qualifier = (ann.arguments.firstOrNull { it.name?.asString() == "qualifier" }?.value as? String).orEmpty()
        val eager = ann.arguments.firstOrNull { it.name?.asString() == "createdAtStart" }?.value as? Boolean ?: false
        val args = fn.parameters.mapNotNull(::dependency)
        // Keep the TYPE ARGUMENTS: `SubmitOutbox<Loan>`, not `SubmitOutbox`. Koin binds by the
        // declared type, and a bare `single { … }` cannot infer T through the factory call.
        val bound = buildString {
            append(ret.declaration.qualifiedName?.asString() ?: ret.toString())
            if (ret.arguments.isNotEmpty()) {
                append(ret.arguments.joinToString(", ", "<", ">") { arg ->
                    arg.type?.resolve()?.let { t ->
                        (t.declaration.qualifiedName?.asString() ?: t.toString()) + if (t.isMarkedNullable) "?" else ""
                    } ?: "*"
                })
            }
        }
        return Prov(fn.simpleName.asString(), fqn, bound, qualifier, eager, args, fn.containingFile)
    }

    /**
     * The named qualifiers every `@DataProvider(qualifier = …)` declares, as one object.
     *
     * Consumers (a feature module injecting an outbox) referenced a hand-written qualifier object
     * before; generating it from the same annotation that binds the value is what stops the two
     * drifting — a qualifier nothing binds is now impossible to reference.
     */
    private fun writeQualifiers(providers: List<Prov>) {
        val named = providers.filter { it.qualifier.isNotBlank() }.sortedBy { it.qualifier }
        if (named.isEmpty()) return
        val text = buildString {
            append(LICENSE)
            append("package $CONFIG_PKG\n\n")
            append("import org.koin.core.qualifier.named\n\n")
            append("/**\n")
            append(" * GENERATED from `@DataProvider(qualifier = …)`. DO NOT HAND-EDIT.\n")
            append(" *\n")
            append(" * Koin matches a `single<T>` by RAW class, not full KType, so several bindings that erase to\n")
            append(" * the same type (every `SubmitOutbox<*>`) collapse to whichever registered last unless each\n")
            append(" * declares a qualifier. Generating these beside the bindings means a qualifier cannot name a\n")
            append(" * binding that does not exist, and a binding cannot be left unqualified by accident.\n")
            append(" */\n")
            append("object AppOutboxQualifiers {\n")
            named.forEach { p ->
                val member = p.qualifier.substringAfterLast('.').replaceFirstChar { it.uppercaseChar() }
                append("    /** `${p.returns.substringAfterLast('.')}` from `${p.fnName}`. */\n")
                append("    val $member = named(\"${p.qualifier}\")\n")
            }
            append("}\n")
        }
        codeGenerator.createNewFile(
            dependencies = Dependencies(aggregating = true, *(named.mapNotNull { it.decl }).toTypedArray()),
            packageName = CONFIG_PKG,
            fileName = "AppOutboxQualifiers",
        ).bufferedWriter().use { it.write(text) }
    }

    private fun spec(decl: KSClassDeclaration): Row? {
        val impl = decl.qualifiedName?.asString()
        val iface = (
            decl.annotations
                .firstOrNull { it.shortName.asString() == "RepositoryBinding" }
                ?.arguments?.firstOrNull { it.name?.asString() == "binds" }
                ?.value as? KSType
            )?.declaration?.qualifiedName?.asString()
        val ctor = decl.primaryConstructor

        // No `else`: exactly one branch runs, so the FIRST failing check is the one reported —
        // the same diagnostic the earlier log-then-return chain produced. An unresolvable
        // qualified name is not a user error, so it rejects silently.
        when {
            impl == null -> Unit
            iface == null ->
                logger.error("data-ksp: @RepositoryBinding on ${decl.simpleName.asString()} has no resolvable `binds`")
            ctor == null ->
                logger.error("data-ksp: ${decl.simpleName.asString()} has no primary constructor to derive from")
        }
        if (impl == null || iface == null || ctor == null) return null

        val args = ctor.parameters.mapNotNull { param ->
            // A defaulted parameter is a TEST SEAM (clock, timeZone), not a graph dependency. Passing
            // `get()` for it would ask Koin for a type nothing binds and fail at construction.
            if (param.hasDefault) return@mapNotNull null
            val name = param.name?.asString() ?: return@mapNotNull null
            val storeId = param.annotations
                .firstOrNull { it.shortName.asString() == "FromStore" }
                ?.arguments?.firstOrNull { it.name?.asString() == "id" }
                ?.value as? String
            val resolve = if (storeId.isNullOrBlank()) {
                "get()"
            } else {
                // Same id -> member rule store-ksp uses, so the two generated files agree by construction.
                "get($REGISTRY.${registrySymbol(storeId)})"
            }
            name to resolve
        }
        return Row(iface, impl, args)
    }

    private fun render(rows: List<Row>, providers: List<Prov>): String {
        val imports = sortedSetOf("org.koin.core.module.Module", "org.koin.dsl.module")
        if ((rows + providers.map { Row(it.returns, it.fnFqn, it.args) })
                .any { r -> r.args.any { it.second.startsWith("get($REGISTRY") } }
        ) {
            imports += REGISTRY_FQN
        }
        if (providers.any { p -> p.args.any { it.second.startsWith("get(named(") } }) {
            imports += "org.koin.core.qualifier.named"
        }
        providers.forEach { imports += it.fnFqn }
        rows.forEach { imports += it.iface; imports += it.impl }

        return buildString {
            append(LICENSE)
            append("package $PKG\n\n")
            imports.forEach { append("import ").append(it).append('\n') }
            append("\n/**\n")
            append(" * GENERATED from `@RepositoryBinding` — one Koin binding per repository. DO NOT HAND-EDIT.\n")
            append(" *\n")
            append(" * To add a repository: annotate the implementation `@RepositoryBinding(binds = X::class)` and\n")
            append(" * mark its store parameters `@FromStore(\"<storeId>\")`. There is no wiring step — the\n")
            append(" * constructor IS the dependency list.\n")
            append(" *\n")
            append(" * Bindings that carry behaviour (submit syncers, the cloud-todo orchestrator, outbox\n")
            append(" * serializers) stay hand-written in `DemoRepositoryModule`: a lambda body is not a\n")
            append(" * dependency list, and eagerness is a lifecycle decision a constructor cannot state.\n")
            append(" *\n")
            append(" * Pulled in by `DataModule` via `includes(GeneratedRepositoryBindings)`.\n")
            append(" */\n")
            append("val GeneratedRepositoryBindings: Module = module {\n")
            providers.forEach { p ->
                val eager = if (p.eager) "(createdAtStart = true)" else ""
                val q = if (p.qualifier.isNotBlank()) {
                    if (p.eager) "(qualifier = named(\"${p.qualifier}\"), createdAtStart = true)"
                    else "(qualifier = named(\"${p.qualifier}\"))"
                } else {
                    eager
                }
                append("    single<${p.returns}>$q {\n")
                append("        ${p.fnName}(\n")
                p.args.forEach { (n, v) -> append("            $n = $v,\n") }
                append("        )\n")
                append("    }\n")
            }
            rows.forEach { r ->
                val iface = r.iface.substringAfterLast('.')
                val impl = r.impl.substringAfterLast('.')
                if (r.args.isEmpty()) {
                    append("    single<$iface> { $impl() }\n")
                } else {
                    append("    single<$iface> {\n")
                    append("        $impl(\n")
                    r.args.forEach { (n, v) -> append("            $n = $v,\n") }
                    append("        )\n")
                    append("    }\n")
                }
            }
            append("}\n")
        }
    }

    private fun write(text: String, files: List<com.google.devtools.ksp.symbol.KSFile>) {
        codeGenerator.createNewFile(
            dependencies = Dependencies(aggregating = true, *files.distinct().toTypedArray()),
            packageName = PKG,
            fileName = "GeneratedRepositoryBindings",
        ).bufferedWriter().use { it.write(text) }
    }

    private companion object {
        const val PKG = "kpt.core.data.di"
        const val ANN_BINDING = "kpt.core.base.data.annotation.RepositoryBinding"
        const val REGISTRY = "AppStoreRegistry"
        const val REGISTRY_FQN = "kpt.core.store.config.AppStoreRegistry"
        const val CONFIG_PKG = "kpt.core.data.config"
        const val ANN_PROVIDER = "kpt.core.base.data.annotation.DataProvider"
        const val ANN_STORE_PROVIDER = "kpt.core.base.store.annotation.StoreProvider"

        val LICENSE = """
            |/*
            | * Copyright 2026 Mifos Initiative
            | *
            | * This Source Code Form is subject to the terms of the Mozilla Public
            | * License, v. 2.0. If a copy of the MPL was not distributed with this
            | * file, You can obtain one at https://mozilla.org/MPL/2.0/.
            | *
            | * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
            | */
            |
        """.trimMargin()
    }
}

class RepositoryBindingProcessorProvider : SymbolProcessorProvider {
    override fun create(environment: SymbolProcessorEnvironment): SymbolProcessor =
        RepositoryBindingProcessor(environment.codeGenerator, environment.logger)
}
