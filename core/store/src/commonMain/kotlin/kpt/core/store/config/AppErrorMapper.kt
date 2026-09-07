/*
 * Copyright 2025 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.store.config

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import kpt.core.base.store.error.ErrorCategory
import kpt.core.base.store.error.categorize
import kpt.core.store.generated.resources.Res
import kpt.core.store.generated.resources.error_category_auth
import kpt.core.store.generated.resources.error_category_client
import kpt.core.store.generated.resources.error_category_generic
import kpt.core.store.generated.resources.error_category_network
import kpt.core.store.generated.resources.error_category_quota
import kpt.core.store.generated.resources.error_category_ratelimit
import kpt.core.store.generated.resources.error_category_server
import kpt.core.store.generated.resources.error_category_timeout_connect
import kpt.core.store.generated.resources.error_category_timeout_read
import kpt.core.store.projectErrorMessage
import org.jetbrains.compose.resources.stringResource

/**
 * Application-level error → user-facing message mapper.
 *
 * ONE source of user-facing copy: [rememberAppErrorMessageFor], which resolves every
 * [ErrorCategory] through `stringResource(...)`. Wired into [appScreenStateDefaults] for the
 * [ScreenStateError.messageFor] hook.
 *
 * There used to be a second, non-Composable `mapErrorToUserMessage` carrying its own hardcoded
 * English copy. It was not merely a duplicate — it was FINER-GRAINED than the localized path, which
 * collapsed Timeout onto network copy and QuotaExceeded onto rate-limit copy. So the same error
 * produced different words depending on the call site, and the more accurate wording was the one
 * no locale could ever see. Those distinctions are now resource strings, and the non-Composable
 * entry point is [errorCategoryToken] — a stable diagnostic token, never user-facing, so it cannot
 * be rendered by mistake.
 *
 * TEMPLATE-OWNED — a sync full-copies this file, so a fork receives every improvement to the
 * framework branches below. Fork-specific errors go in [kpt.core.store.projectErrorMessage], which
 * both entry points consult FIRST; this file falls through to the categorised copy when it returns
 * null. Do not add fork branches here — they would be overwritten on the next sync.
 */
fun errorCategoryToken(error: Throwable): String = when (val cat = categorize(error)) {
    ErrorCategory.Network -> "network"
    ErrorCategory.Timeout.Connect -> "timeout_connect"
    ErrorCategory.Timeout.Read -> "timeout_read"
    ErrorCategory.Auth -> "auth"
    ErrorCategory.RateLimit -> "rate_limit"
    ErrorCategory.QuotaExceeded -> "quota_exceeded"
    is ErrorCategory.Server -> "server_${cat.httpCode}"
    is ErrorCategory.ClientError -> "client_${cat.httpCode}"
    ErrorCategory.Generic -> "generic"
}

/**
 * Composable factory that resolves per-category copy via `stringResource(...)`, returning
 * a pure-Kotlin `(Throwable) -> String` lambda safe to pass through to
 * [kpt.core.base.ui.screen.ScreenStateError.messageFor] (which is invoked from inside
 * composition where these strings are already memoised).
 *
 * Reuses [categorize] to bucket the error, then picks the localized string.
 */
@Composable
fun rememberAppErrorMessageFor(): (Throwable) -> String {
    val networkCopy = stringResource(Res.string.error_category_network)
    val connectTimeoutCopy = stringResource(Res.string.error_category_timeout_connect)
    val readTimeoutCopy = stringResource(Res.string.error_category_timeout_read)
    val authCopy = stringResource(Res.string.error_category_auth)
    val rateLimitCopy = stringResource(Res.string.error_category_ratelimit)
    val quotaCopy = stringResource(Res.string.error_category_quota)
    val serverCopy = stringResource(Res.string.error_category_server)
    val clientCopy = stringResource(Res.string.error_category_client)
    val genericCopy = stringResource(Res.string.error_category_generic)
    val projectCopy = ::projectErrorMessage
    return remember(
        networkCopy,
        connectTimeoutCopy,
        readTimeoutCopy,
        authCopy,
        rateLimitCopy,
        quotaCopy,
        serverCopy,
        clientCopy,
        genericCopy,
    ) {
        { error: Throwable ->
            projectCopy(error) ?: when (categorize(error)) {
                ErrorCategory.Network -> networkCopy
                ErrorCategory.Timeout.Connect -> connectTimeoutCopy
                ErrorCategory.Timeout.Read -> readTimeoutCopy
                ErrorCategory.Auth -> authCopy
                ErrorCategory.RateLimit -> rateLimitCopy
                ErrorCategory.QuotaExceeded -> quotaCopy
                is ErrorCategory.Server -> serverCopy
                is ErrorCategory.ClientError -> error.message ?: clientCopy
                ErrorCategory.Generic -> error.message ?: genericCopy
            }
        }
    }
}
