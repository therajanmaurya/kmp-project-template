/*
 * Copyright 2025 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.base.platform

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.compositionLocalOf
import kpt.core.base.platform.context.AppContext
import kpt.core.base.platform.intent.IntentManager
import kpt.core.base.platform.share.ShareManager
import kpt.core.base.platform.url.UrlLauncher
import kpt.core.base.platform.review.AppReviewManager
import kpt.core.base.platform.update.AppUpdateManager

/**
 * A composable function that provides platform-specific managers to the composition tree.
 *
 * This function initializes and provides various platform-specific managers
 * (AppReviewManager, IntentManager, AppUpdateManager) to the composition through
 * CompositionLocal providers. It acts as a central point for injecting
 * platform-specific functionality into the Compose UI hierarchy.
 *
 * As an expect function, platform-specific implementations will be provided in
 * each target platform's source set, allowing for platform-specific initialization
 * while maintaining a consistent API across platforms.
 *
 * @param context The platform-specific AppContext to initialize the managers
 * @param content The composable content where the managers will be available
 */
@Composable
expect fun LocalManagerProvider(
    context: AppContext,
    content: @Composable () -> Unit,
)

/**
 * Provides access to the app review manager throughout the app.
 */
val LocalAppReviewManager: ProvidableCompositionLocal<AppReviewManager> = compositionLocalOf {
    error("CompositionLocal AppReviewManager not present")
}

/**
 * Provides access to the intent manager throughout the app.
 */
val LocalIntentManager: ProvidableCompositionLocal<IntentManager> = compositionLocalOf {
    error("CompositionLocal LocalIntentManager not present")
}

/**
 * Opening a URL — distinct from [LocalIntentManager] (system screens) and [LocalShareManager]
 * (handing content to another app).
 */
val LocalUrlLauncher: ProvidableCompositionLocal<UrlLauncher> = compositionLocalOf {
    error("CompositionLocal UrlLauncher not present")
}

/** Handing content to the platform share chooser. */
val LocalShareManager: ProvidableCompositionLocal<ShareManager> = compositionLocalOf {
    error("CompositionLocal ShareManager not present")
}

/**
 * Provides access to the circumstance manager throughout the app.
 */
val LocalAppUpdateManager: ProvidableCompositionLocal<AppUpdateManager> = compositionLocalOf {
    error("CompositionLocal LocalAppUpdateManager not present")
}
