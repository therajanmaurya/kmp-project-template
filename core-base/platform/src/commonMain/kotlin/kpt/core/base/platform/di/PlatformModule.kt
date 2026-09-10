/*
 * Copyright 2025 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.base.platform.di

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import org.koin.dsl.module
import kpt.core.base.platform.garbage.GarbageCollectionManager
import kpt.core.base.platform.garbage.GarbageCollectionManagerImpl
import kpt.core.base.platform.intent.IntentManager
import kpt.core.base.platform.intent.IntentManagerImpl
import kpt.core.base.platform.share.ShareManager
import kpt.core.base.platform.share.ShareManagerImpl
import kpt.core.base.platform.update.AppUpdateManager
import kpt.core.base.platform.update.AppUpdateManagerImpl
import kpt.core.base.platform.url.UrlLauncher
import kpt.core.base.platform.url.UrlLauncherImpl

val platformModule = module {
    single<CoroutineDispatcher> { Dispatchers.Unconfined }
    single<GarbageCollectionManager> { GarbageCollectionManagerImpl(get()) }

    // The three platform-capability managers. Bound here as well as provided through the
    // CompositionLocals in LocalManagerProviders, so a ViewModel or repository can inject one
    // without reaching into composition. All three are stateless — the per-target behaviour lives
    // in the toolkit engines they delegate to — so `single` is safe.
    single<UrlLauncher> { UrlLauncherImpl() }
    single<ShareManager> { ShareManagerImpl() }
    single<IntentManager> { IntentManagerImpl() }

    // Bindable as a single since cmp-in-app-update replaced the Play Core impl: the engine
    // resolves the target itself, so there is no Activity to hold and nothing per-platform
    // to construct. AppReviewManager is NOT here — it still takes an Activity.
    single<AppUpdateManager> { AppUpdateManagerImpl() }
}
