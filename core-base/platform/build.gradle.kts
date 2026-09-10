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
    alias(libs.plugins.kmp.core.base.library.convention)
    alias(libs.plugins.jetbrainsCompose)
    alias(libs.plugins.compose.compiler)
}


kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation(compose.ui)
            implementation(compose.runtime)
            implementation(libs.calf.permissions)

            // KmpToolkit IPC modules — power the cross-platform IntentManager impl
            // in nonAndroidMain (Android keeps its native ACTION_SEND/ACTION_VIEW path).
            implementation(libs.cmp.share)
            implementation(libs.cmp.intent.launcher)
            implementation(libs.cmp.open.url)
            implementation(libs.cmp.inapp.update)
            // The CompositionLocals read their managers OUT of Koin rather than constructing a
            // second copy — platformModule is the single owner. Same pattern as core-base/security.
            implementation(libs.koin.compose)

            // Explicit (rather than transitive via compose.runtime) — nonAndroidMain
            // IntentManagerImpl owns its own CoroutineScope for fire-and-forget dispatch.
            implementation(libs.kotlinx.coroutines.core)
        }

        androidMain.dependencies {
            implementation(libs.androidx.activity.ktx)
            implementation(libs.androidx.activity.compose)

            implementation(libs.androidx.metrics)
            implementation(libs.androidx.browser)
            implementation(libs.androidx.compose.runtime)

            implementation(compose.material3)

            // In-app REVIEW stays on Play Core — the toolkit has no review engine yet, so
            // AppReviewManager keeps its Android impl and its non-Android no-op. That is the
            // last Activity-bound manager, and the last reason LocalManagerProvider is split.
            implementation(libs.review)
            implementation(libs.review.ktx)
        }
    }
}
