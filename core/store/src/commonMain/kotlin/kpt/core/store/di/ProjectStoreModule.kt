/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.store.di

import org.koin.dsl.module

/**
 * THE FORK'S Store5 DI seam. Empty on the neutral template — this is yours to fill.
 *
 * `core/store`'s demo bindings are an inline comment fence inside [StoreModule]
 * rather than a separate file, so unlike the other layers there was never even a misnamed seam here —
 * a cleaned fork simply had nowhere of its own to register stores. This file is that place, and it
 * lives outside `demo/` so `scripts/remove-demo.sh` leaves it standing.
 *
 * Register the fork's Store5 factories + their logout purge here:
 * ```
 * single(MyThingKeys.Qualifier) { provideMyThingStore(get(), get()) }
 * ```
 * Prefer DECLARING the store in `app-profile/app.yaml#core_store.stores` — codegen then writes its
 * `<Store>Keys` object, its binding, and its logout purge, and the three cannot disagree. Hand-wire
 * here only for something a declaration cannot express.
 *
 * If you do hand-wire, add the store to the `StoreCacheManager` logout registration yourself — an
 * unregistered store leaks the previous user's cached rows into the next session on a shared device.
 * `store-logout-purge.sh` (LP-1) checks this file for exactly that.
 */
val ProjectStoreModule = module {
    // Intentionally empty on the template — a fork adds its own Store5 factories here.
}
