/*
 * Copyright 2025 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.tools.storeksp

import com.google.devtools.ksp.processing.CodeGenerator
import com.google.devtools.ksp.processing.Dependencies
import com.google.devtools.ksp.processing.KSPLogger
import com.google.devtools.ksp.processing.Resolver
import com.google.devtools.ksp.processing.SymbolProcessor
import com.google.devtools.ksp.processing.SymbolProcessorEnvironment
import com.google.devtools.ksp.processing.SymbolProcessorProvider
import com.google.devtools.ksp.symbol.KSAnnotation
import com.google.devtools.ksp.symbol.KSAnnotated
import com.google.devtools.ksp.symbol.KSFunctionDeclaration

private const val PROVIDER = "kpt.core.base.store.annotation.StoreProvider"
private const val BINDINGS_PKG = "kpt.core.store.di"
private val TTL_RE = Regex("^(\\d+)(m|h|d)$")
private val PLACEHOLDER_RE = Regex("\\{([A-Za-z0-9_]+)}")

private data class KeySpec(val name: String, val fn: String, val key: String, val params: List<Pair<String, String>>)

private data class StoreSpec(
    val id: String,
    val qualifier: String,
    val ttl: String,
    val logout: Boolean,
    val pkg: String,
    val providerFqn: String,
    val providerName: String,
    val deps: List<String>,
    val keys: List<KeySpec>,
)

/**
 * Derives every Store5 wiring surface from `@StoreProvider`.
 *
 * Emits, per annotated function, a `<Qualifier>Keys` object into the provider's OWN package, and one
 * aggregated `GeneratedStoreBindings` carrying each binding plus the logout purge.
 *
 * Deriving both from a single annotation is the point: the binding and the purge used to be two
 * hand-kept lists that had to agree, and a store bound but never registered survives sign-out and
 * shows the previous user's cached rows to the next person on a shared device. They cannot disagree
 * if neither is written by hand.
 *
 * Validation is a BUILD ERROR, not a later gate: duplicate ids, duplicate key strings, a placeholder
 * with no matching param, a malformed ttl. A key collision matters because two streams sharing a key
 * share a fetched-at stamp — one screen's refresh marks the other fresh and it silently stops
 * refetching.
 */
class StoreProviderProcessor(
    private val codeGenerator: CodeGenerator,
    private val logger: KSPLogger,
) : SymbolProcessor {

    private var emitted = false

    override fun process(resolver: Resolver): List<KSAnnotated> {
        if (emitted) return emptyList()
        val fns = resolver.getSymbolsWithAnnotation(PROVIDER)
            .filterIsInstance<KSFunctionDeclaration>()
            .toList()
        if (fns.isEmpty()) return emptyList()

        val specs = fns.mapNotNull { toSpec(it) }
        if (specs.size != fns.size) return emptyList() // a spec failed validation; error already logged
        if (!validateGlobally(specs)) return emptyList()

        specs.forEach { emitKeys(it, fns) }
        emitBindings(specs, fns)
        emitted = true
        return emptyList()
    }

    private fun ann(fn: KSFunctionDeclaration, short: String): List<KSAnnotation> =
        fn.annotations.filter { it.shortName.asString() == short }.toList()

    private fun KSAnnotation.str(name: String): String =
        arguments.firstOrNull { it.name?.asString() == name }?.value?.toString().orEmpty()

    private fun toSpec(fn: KSFunctionDeclaration): StoreSpec? {
        val a = ann(fn, "StoreProvider").firstOrNull() ?: return null
        val id = a.str("id")
        if (id.isBlank()) {
            logger.error("@StoreProvider requires a non-blank id", fn); return null
        }
        val ttl = a.str("ttl")
        if (ttl.isNotEmpty() && !TTL_RE.matches(ttl)) {
            logger.error("@StoreProvider(ttl = \"$ttl\") must look like 5m / 1h / 7d", fn); return null
        }
        val declaredQualifier = a.str("qualifier")
        val qualifier = declaredQualifier.ifEmpty { id.replaceFirstChar { it.uppercaseChar() } }
        val logout = a.arguments.firstOrNull { it.name?.asString() == "logout" }?.value as? Boolean ?: true

        // The payoff: dependencies are READ from the signature, never restated.
        val deps = fn.parameters.mapNotNull { it.name?.asString() }

        val keys = ann(fn, "CacheKey").mapNotNull { k -> toKeySpec(k, fn) }
        if (keys.size != ann(fn, "CacheKey").size) return null

        // Providers live in `<domain>.impl`; their keys belong beside the domain, not inside impl.
        val pkg = fn.packageName.asString().removeSuffix(".impl")
        return StoreSpec(
            id = id, qualifier = qualifier, ttl = ttl, logout = logout, pkg = pkg,
            providerFqn = fn.qualifiedName?.asString().orEmpty(),
            providerName = fn.simpleName.asString(), deps = deps, keys = keys,
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun toKeySpec(k: KSAnnotation, fn: KSFunctionDeclaration): KeySpec? {
        val key = k.str("key")
        val name = k.str("name")
        val builder = k.str("fn")
        if (key.isBlank()) { logger.error("@CacheKey requires a non-blank key", fn); return null }
        if (name.isBlank() == builder.isBlank()) {
            logger.error("@CacheKey(key = \"$key\") needs exactly one of name= (constant) or fn= (builder)", fn)
            return null
        }
        val raw = (k.arguments.firstOrNull { it.name?.asString() == "params" }?.value as? List<*>).orEmpty()
        val params = raw.mapNotNull { p ->
            val t = p.toString()
            val i = t.indexOf(':')
            if (i <= 0) { logger.error("@CacheKey params entry '$t' must be \"name:Type\"", fn); null }
            else t.substring(0, i).trim() to t.substring(i + 1).trim()
        }
        if (params.size != raw.size) return null

        val placeholders = PLACEHOLDER_RE.findAll(key).map { it.groupValues[1] }.toSet()
        val declared = params.map { it.first }.toSet()
        (placeholders - declared).forEach {
            logger.error("@CacheKey(key = \"$key\") has placeholder {$it} with no matching param", fn)
        }
        (declared - placeholders).forEach {
            logger.error("@CacheKey(key = \"$key\") declares param '$it' that the key never uses", fn)
        }
        if (placeholders != declared) return null
        if (builder.isNotBlank() && params.isEmpty()) {
            logger.error("@CacheKey(fn = \"$builder\") has no params — use name= for a constant", fn); return null
        }
        return KeySpec(name, builder, key, params)
    }

    private fun validateGlobally(specs: List<StoreSpec>): Boolean {
        var ok = true
        specs.groupBy { it.id }.filterValues { it.size > 1 }.forEach { (id, dupes) ->
            logger.error("duplicate @StoreProvider id '$id' on ${dupes.joinToString { it.providerName }}"); ok = false
        }
        specs.groupBy { it.qualifier }.filterValues { it.size > 1 }.forEach { (q, dupes) ->
            logger.error("duplicate store qualifier '$q' on ${dupes.joinToString { it.providerName }}"); ok = false
        }
        specs.flatMap { s -> s.keys.map { it.key to s.providerName } }
            .groupBy({ it.first }, { it.second })
            .filterValues { it.size > 1 }
            .forEach { (key, owners) ->
                logger.error(
                    "duplicate cache key \"$key\" declared by ${owners.joinToString()} — two streams " +
                        "sharing a key share a fetched-at stamp, so one refresh silently marks the other fresh",
                )
                ok = false
            }
        return ok
    }

    /** `"loan:{id}"` -> `"loan:$id"`; braces only where the next char could continue the name. */
    private fun interpolate(key: String, names: List<String>): String {
        var out = key
        names.forEach { n ->
            val i = out.indexOf("{$n}")
            val after = out.getOrNull(i + n.length + 2)
            val braces = after != null && (after.isLetterOrDigit() || after == '_')
            out = out.replace("{$n}", if (braces) "\${$n}" else "$$n")
        }
        return out
    }

    private fun ttlExpr(ttl: String): String {
        val m = TTL_RE.find(ttl)!!
        return m.groupValues[1] + when (m.groupValues[2]) { "m" -> ".minutes"; "h" -> ".hours"; else -> ".days" }
    }

    private fun header(sb: StringBuilder) {
        sb.append("// GENERATED by store-ksp from @StoreProvider. DO NOT EDIT — this is a build\n")
        sb.append("// artifact, not committed source. Change the annotation on the provider instead.\n\n")
    }

    private fun emitKeys(s: StoreSpec, fns: List<KSFunctionDeclaration>) {
        val sb = StringBuilder()
        header(sb)
        sb.append("package ${s.pkg}\n\n")
        sb.append("import kpt.core.base.store.infra.StoreRegistry\n")
        if (s.ttl.isNotEmpty()) {
            sb.append("import kotlin.time.Duration.Companion.")
                .append(if (s.ttl.endsWith("d")) "days" else if (s.ttl.endsWith("h")) "hours" else "minutes")
                .append("\n")
        }
        sb.append("\n/** Everything addressing the `${s.id}` store. */\n")
        sb.append("object ${s.qualifier}Keys : StoreRegistry() {\n")
        sb.append("    val Qualifier = store(\"${s.id}\")\n")
        if (s.ttl.isNotEmpty()) sb.append("\n    val TTL = ${ttlExpr(s.ttl)}\n")
        val consts = s.keys.filter { it.name.isNotBlank() }
        val builders = s.keys.filter { it.fn.isNotBlank() }
        if (consts.isNotEmpty() || builders.isNotEmpty()) sb.append("\n")
        consts.forEach { sb.append("    const val ${it.name} = \"${it.key}\"\n") }
        if (consts.isNotEmpty() && builders.isNotEmpty()) sb.append("\n")
        builders.forEach { k ->
            val sig = k.params.joinToString(", ") { "${it.first}: ${it.second}" }
            sb.append("    fun ${k.fn}($sig): String = \"${interpolate(k.key, k.params.map { it.first })}\"\n")
        }
        sb.append("}\n")
        write(sb.toString(), s.pkg, "${s.qualifier}Keys", fns)
    }

    private fun emitBindings(specs: List<StoreSpec>, fns: List<KSFunctionDeclaration>) {
        val purged = specs.filter { it.logout }
        val imports = buildList {
            add("kpt.core.base.store.infra.StoreCacheManager")
            add("kpt.core.base.store.infra.impl.StoreCacheManagerImpl")
            addAll(specs.map { it.providerFqn })
            addAll(specs.map { "${it.pkg}.${it.qualifier}Keys" })
            add("org.koin.core.module.Module")
            add("org.koin.dsl.module")
        }.filter { it.isNotBlank() }.distinct().sorted()

        val sb = StringBuilder()
        header(sb)
        sb.append("package $BINDINGS_PKG\n\n")
        imports.forEach { sb.append("import $it\n") }
        sb.append("\n/**\n")
        sb.append(" * Every `@StoreProvider`: its Koin binding AND its logout purge, from one annotation.\n")
        sb.append(" *\n")
        sb.append(" * `*Mutable` stores declare `logout = false` — Store5 5.1's MutableStore is not a `Store`\n")
        sb.append(" * subtype so `register` cannot take one. Their rows still go: each shares a table with its\n")
        sb.append(" * read store, whose deleteAll wipes it.\n")
        sb.append(" *\n")
        sb.append(" * Pulled in by `StoreModule` via `includes(GeneratedStoreBindings)`.\n")
        sb.append(" */\n")
        sb.append("val GeneratedStoreBindings: Module = module {\n")
        specs.forEach { s ->
            val args = s.deps.joinToString(", ") { "$it = get()" }
            sb.append("    single(${s.qualifier}Keys.Qualifier) { ${s.providerName}($args) }\n")
        }
        if (purged.isNotEmpty()) {
            sb.append("\n    single(createdAtStart = true) {\n")
            sb.append("        val mgr = get<StoreCacheManager>() as StoreCacheManagerImpl\n")
            purged.forEach { sb.append("        mgr.register(get(${it.qualifier}Keys.Qualifier))\n") }
            sb.append("    }\n")
        }
        sb.append("}\n")
        write(sb.toString(), BINDINGS_PKG, "GeneratedStoreBindings", fns)
        logger.info("store-ksp: ${specs.size} store(s), ${purged.size} purged on logout")
    }

    private fun write(text: String, pkg: String, name: String, fns: List<KSFunctionDeclaration>) {
        codeGenerator.createNewFile(
            dependencies = Dependencies(aggregating = true, *fns.mapNotNull { it.containingFile }.toTypedArray()),
            packageName = pkg,
            fileName = name,
        ).bufferedWriter().use { it.write(text) }
    }
}

class StoreProviderProcessorProvider : SymbolProcessorProvider {
    override fun create(environment: SymbolProcessorEnvironment): SymbolProcessor =
        StoreProviderProcessor(environment.codeGenerator, environment.logger)
}
