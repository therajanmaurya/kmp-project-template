/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.network.demo.appconfig.api

import kpt.core.base.network.SupabaseConfigClient
import kpt.core.network.demo.appconfig.dto.RemoteAppConfigDto

/**
 * Reference SUPABASE access-point API — the Supabase twin of the Ktorfit demo APIs.
 *
 * This is what "a fork writes only the API type" looks like on the Supabase side. It is bound by
 * `GeneratedApiBindings` (generated from the `supabase_data` access point's `api:` declaration), so
 * there is no hand-written wiring; the single-arg constructor taking [SupabaseConfigClient] is the
 * whole contract `supabaseApi<T>("<id>")` requires.
 *
 * Unlike REST there is no generated stub to implement — supabase-kt has no interface-generation step,
 * so the "API type" is a hand-written typed facade over `client.postgrest`. That asymmetry is
 * inherent to supabase-kt, not to the wiring.
 *
 * **Inert by default.** The template declares the `supabase_data` endpoint but ships no Supabase
 * project and no anon key, so [SupabaseConfigClient.isConfigured] is false and every call returns
 * empty rather than throwing. Constructing this class never touches the network — the underlying
 * `client` is `by lazy`, so Koin can build the binding on an unconfigured fork safely.
 *
 * A fork points this at its own project by setting the access point's `base_url` and
 * `anon_key_env:` in `app-profile/app.yaml`, then running `./gradlew syncForkConfig`.
 */
class AppConfigApi(
    private val supabase: SupabaseConfigClient,
) {
    /** True when a real project URL + anon key are configured; false on the neutral template. */
    val isConfigured: Boolean get() = supabase.isConfigured

    /**
     * Every `app_config` row, or an empty list when Supabase is not configured.
     *
     * Returning empty rather than throwing keeps an unconfigured fork on the "no remote config, use
     * defaults" path instead of crashing at start-up — the same posture the FRED-key-absent screens
     * take.
     */
    suspend fun fetchConfig(): List<RemoteAppConfigDto> {
        if (!isConfigured) return emptyList()
        return supabase.data.from(TABLE).select().decodeList<RemoteAppConfigDto>()
    }

    /** The value for [key], or `null` when absent or unconfigured. */
    suspend fun fetchValue(key: String): String? =
        fetchConfig().firstOrNull { it.key == key }?.value

    private companion object {
        const val TABLE = "app_config"
    }
}
