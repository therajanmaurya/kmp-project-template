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
 * DemoNetworkModule — Koin bindings for the DEMO showcase's network needs. Deleted wholesale by
 * `scripts/remove-demo.sh` along with every other `demo` package.
 *
 * This is NOT the fork's seam. A fork wires its own hand-written network singles in
 * [kpt.core.network.di.ProjectNetworkModule], which lives outside `demo/` and therefore SURVIVES the
 * strip. The two were previously one file named `ProjectNetworkModule` under `demo/di`, which read
 * like a fork seam but was demo content on a demo lifecycle — so `--clean` deleted the fork's only
 * place to wire network DI.
 *
 * API bindings belong in neither: they are GENERATED into `kpt.core.network.di.GeneratedApiBindings`
 * from `app-profile/app.yaml#network.access_points`.
 */
val DemoNetworkModule = module {
    // FRED's API key is a request-time @Query parameter (not client setup), so its config stays here
    // (InterestRateSeriesStore injects it); the base URL + proxy come from the "fred" access point.
    single<FredApiConfig> {
        FredApiConfig(apiKey = BuildKonfig.FRED_API_KEY.takeIf { it.isNotBlank() })
    }
}
