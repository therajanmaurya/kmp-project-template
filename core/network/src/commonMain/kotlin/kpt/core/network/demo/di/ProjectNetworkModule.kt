/*
 * Copyright 2025 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.network.demo.di

import kpt.core.network.BuildKonfig
import kpt.core.network.demo.economic.config.FredApiConfig
import org.koin.dsl.module

/**
 * ProjectNetworkModule — the FORK-OWNED API-client wiring. This is where a fork wires its API
 * interfaces to the app's network **access points**.
 *
 * Every server the app talks to is declared ONCE in `app-profile/app.yaml#network.access_points`,
 * and every binding for one is GENERATED from that declaration into [GeneratedApiBindings] — included
 * below. `core-base/network` builds each transport (base URL, logging, proxy) from the access point,
 * so there is no per-API Ktorfit boilerplate, no hardcoded URL, and no hand-added wiring line.
 *
 * **To add an API: declare the endpoint with its `api:` FQN in app.yaml, write the API type, run
 * `./gradlew syncForkConfig`.** That is the whole loop — REST and Supabase alike.
 *
 * What stays hand-written here is what is NOT derivable from an endpoint declaration: config objects
 * like [FredApiConfig], whose key is a request-time `@Query` parameter rather than client setup.
 *
 * Ownership: fork-owned `demo/` package (customization-surface.yaml); installed via
 * `FeatureRegistry.featureKoinModules`; the customizer `--clean` strips it. The infra aggregator
 * [kpt.core.network.di.NetworkModule] stays demo-free `owner: template`.
 */
val ProjectNetworkModule = module {
    // FRED's API key is a request-time @Query parameter (not client setup), so its config stays here
    // (InterestRateSeriesStore injects it); the base URL + proxy come from the "fred" access point.
    single<FredApiConfig> {
        FredApiConfig(apiKey = BuildKonfig.FRED_API_KEY.takeIf { it.isNotBlank() })
    }

    // Every declared endpoint's binding, generated from app-profile (base URL + logging + proxy
    // resolved from its access point). Includes the WRITABLE jsonplaceholder backend that the Store5
    // MUTABLE (offline-write) archetype demo runs against.
    includes(GeneratedApiBindings)
}
