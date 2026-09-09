/*
 * Copyright 2025 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
plugins {
    alias(libs.plugins.kmp.library.convention)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.kotlin.parcelize)
    alias(libs.plugins.mifos.kmp.room)
    alias(libs.plugins.ksp)
}

kotlin {
    sourceSets {
        androidMain.dependencies {
            implementation(libs.koin.android)
        }

        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.kermit.logging)
            api(projects.core.common)
            implementation(projects.core.model)
            api(projects.coreBase.database)
            implementation(projects.coreBase.crypto)
        }

        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
            implementation(libs.turbine)
            implementation(libs.koin.test)
        }
    }
}

// ── Fork-owned dependency seam (white-label, mirrors `feature-deps.gradle.kts`) ────────────────
// A fork adds its OWN dependencies for this module in `core/database/module-deps.gradle.kts` — never in
// this file. That is what lets THIS build file be `owner: template` and FULL-COPY on a template
// sync: the fork's deps live in a file the sync never touches, so a template plugin/version bump
// can no longer drop them and no 3-way merge is needed.
//
// String `"commonMainImplementation"(...)` notation is used in the seam, not the type-safe
// `libs.`/`projects.` accessors: those are NOT generated for `apply(from = ...)` script plugins.
//
// Guarded like feature-deps: a fork that adopted the template BEFORE this seam existed may not have
// the file yet, and an unconditional apply would fail the whole configuration.
project.file("module-deps.gradle.kts").takeIf { it.exists() }?.let { apply(from = it) }

/*
 * This module's tests are desktop-only (Room + SQLite). Its `jsTest` / `wasmJsTest` / `nativeTest` /
 * `androidUnitTest` sources contain ONLY the `actual val testPlatformModule` counterparts that let
 * `commonTest` compile on those targets - there is not a single `@Test` among them.
 *
 * Gradle 9 fails a test task that has sources but discovers no tests, so every one of those targets
 * failed with "test sources present ... did not discover any tests". The expectation is declared for
 * ALL test tasks rather than a hand-picked list: an earlier version named only the web tasks and
 * `iosSimulatorArm64Test` promptly failed the same way. The flag only takes effect when zero tests
 * are discovered, so `desktopTest` and its 44 real tests are unaffected - and adding a genuine test
 * to any target makes it run with no build edit needed.
 */
tasks.withType<org.gradle.api.tasks.testing.AbstractTestTask>().configureEach {
    failOnNoDiscoveredTests.set(false)
}

/*
 * AppDatabase is GENERATED WHOLE by :tools:database-ksp from the @DbEntity / @DbDao /
 * @DbConverters annotations on the tables themselves.
 *
 * Room needs ONE compile-time `entities = [...]` literal inside the @Database class, so the list
 * cannot live in a separate object the way GeneratedStoreBindings does — an annotation argument
 * cannot be read from a `val`. Emitting the class whole is what removes AppDatabase.kt from the
 * sync surface: it was the LAST hand-merged file under core/.
 *
 * Putting the metadata pass's output on commonMain's srcDir makes the generated file an ORDINARY
 * source file for every per-target compilation, so Room's own per-target ksp tasks read it exactly
 * as they read the hand-written one. No processor consumes another's output mid-round.
 */
dependencies {
    add("kspCommonMainMetadata", project(":tools:database-ksp"))
}

kotlin.sourceSets.named("commonMain") {
    kotlin.srcDir(layout.buildDirectory.dir("generated/ksp/metadata/commonMain/kotlin"))
}

/*
 * The two inputs that are NOT annotations, passed as ksp args from their existing owners.
 *
 * Framework infra tables live in core-base/database — a different module, whose sources this
 * compilation cannot scan — so they keep their declaration in that module's module-schema.yaml.
 * Migrations are schema HISTORY: no class can carry a `from`/`to` edge, and a version invented by
 * scanning source strands every installed device, so they keep coming from the fork-owned ledger.
 */
val infraSchema = rootProject.file("core-base/database/module-schema.yaml")
val ledger = rootProject.file("app-profile/migration-ledger.yaml")

fun yamlList(file: File, key: String): List<String> {
    if (!file.isFile) return emptyList()
    val out = mutableListOf<String>()
    var inKey = false
    file.forEachLine { raw ->
        val line = raw.substringBefore('#').trimEnd()
        when {
            line.matches(Regex("^$key:\\s*$")) -> inKey = true
            line.matches(Regex("^[a-zA-Z_]+:.*$")) -> inKey = false
            inKey && line.trimStart().startsWith("- ") -> out += line.trimStart().removePrefix("- ").trim()
        }
    }
    return out
}

// `- { name: fooDao, type: a.b.FooDao }` -> "fooDao:a.b.FooDao"
fun infraDaoRows(): List<String> = yamlList(infraSchema, "daos").mapNotNull { row ->
    val name = Regex("name:\\s*([A-Za-z0-9_]+)").find(row)?.groupValues?.get(1)
    val type = Regex("type:\\s*([A-Za-z0-9_.]+)").find(row)?.groupValues?.get(1)
    if (name == null || type == null) null else "$name:$type"
}

// `- { from: 8, to: 10, unit: x, spec: a.b.Spec }` -> "AutoMigration(from = 8, to = 10, spec = a.b.Spec::class)"
fun migrationRows(): List<String> = yamlList(ledger, "migrations").mapNotNull { row ->
    val from = Regex("from:\\s*(\\d+)").find(row)?.groupValues?.get(1) ?: return@mapNotNull null
    val to = Regex("to:\\s*(\\d+)").find(row)?.groupValues?.get(1) ?: return@mapNotNull null
    val spec = Regex("spec:\\s*([A-Za-z0-9_.]+)").find(row)?.groupValues?.get(1)
    buildString {
        append("AutoMigration(from = ").append(from).append(", to = ").append(to)
        if (spec != null) append(", spec = ").append(spec).append("::class")
        append(")")
    }
}

ksp {
    arg("kpt.database.infraEntities", yamlList(infraSchema, "entities").joinToString("|"))
    arg("kpt.database.infraDaos", infraDaoRows().joinToString("|"))
    arg("kpt.database.migrations", migrationRows().joinToString("|"))
}

// Everything that READS commonMain waits for the metadata pass — including the per-target ksp tasks
// (Room's own), which now take the generated dir as an input and would otherwise race a half-written
// file or fail Gradle's undeclared-dependency check.
val kspCommonMetadata = "kspCommonMainKotlinMetadata"
tasks.matching {
    (it.name.startsWith("compileKotlin") || it.name.startsWith("ksp")) && it.name != kspCommonMetadata
}.configureEach { dependsOn(kspCommonMetadata) }
