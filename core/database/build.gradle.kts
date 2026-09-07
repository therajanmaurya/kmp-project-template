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
