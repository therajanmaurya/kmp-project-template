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
import androidx.compose.runtime.CompositionLocalProvider
import kpt.core.base.platform.context.AppContext
import kpt.core.base.platform.review.AppReviewManagerImpl
import org.koin.compose.koinInject

@Composable
actual fun LocalManagerProvider(
    context: AppContext,
    content: @Composable () -> Unit,
) {
    CompositionLocalProvider(
        LocalAppReviewManager provides AppReviewManagerImpl(),
        // Resolved from platformModule — NOT constructed here. Constructing them again would
        // hand composition a different instance from the one a ViewModel injects.
        LocalIntentManager provides koinInject(),
        LocalUrlLauncher provides koinInject(),
        LocalShareManager provides koinInject(),
        LocalAppUpdateManager provides koinInject(),
    ) {
        content()
    }
}
