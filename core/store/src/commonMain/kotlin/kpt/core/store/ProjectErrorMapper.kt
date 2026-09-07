/*
 * Copyright 2025 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.store

/**
 * THE FORK'S domain-error copy. Empty on the neutral template — this is yours to fill.
 *
 * [kpt.core.store.config.mapErrorToUserMessage] consults this FIRST and falls through to the
 * framework's `ErrorCategory` branches when it returns null. That ordering is the point: a fork adds
 * its own exception types here without touching the template file, and still receives every upstream
 * improvement to the framework branches on a sync.
 *
 * Previously the fork extension point was a `TODO(fork)` comment inside the template's own `when`,
 * which made the whole file `owner: fork` — so a fork that added one branch stopped receiving
 * template fixes to the other nine.
 *
 * Return `null` for anything you do not handle; never a generic fallback string, or the framework's
 * categorised copy (network / auth / rate-limit / server) becomes unreachable.
 *
 * ## Why there is no ProjectCacheKeys counterpart
 * Cache keys took a different shape: they are generated per store into that store's own package
 * (`banking/LoansKeys.kt`), so a fork's own store already gets its own keys object with no seam
 * needed. A hand-written `ProjectCacheKeys` would be a SECOND place to put the same thing, and keys
 * written there are invisible to `cache-key-uniqueness` (CK-1) — two streams could silently share a
 * key, share a fetched-at stamp, and one screen would stop refetching. Declare the key on its store
 * instead.
 *
 * ```kotlin
 * fun projectErrorMessage(error: Throwable): String? = when (error) {
 *     is InsufficientFundsException -> "Not enough balance for this transfer."
 *     is CardDeclinedException -> "That card was declined. Try another payment method."
 *     else -> null
 * }
 * ```
 */
@Suppress("UNUSED_PARAMETER")
fun projectErrorMessage(error: Throwable): String? = null
