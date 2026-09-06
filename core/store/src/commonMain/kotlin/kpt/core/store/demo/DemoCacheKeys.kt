/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.store.demo

/**
 * Demo-showcase cache keys, relocated out of the template-owned [kpt.core.store.AppCacheKeys]
 * (E1/C5). Lives under `demo/` so `scripts/remove-demo.sh` deletes the whole file rather than
 * editing a template file in place — that is what lets a template sync blind-copy `AppCacheKeys.kt`
 * without re-introducing demo keys into a cleaned fork.
 *
 * A fork does NOT edit this file: it adds its own keys to `AppCacheKeys`, next to its store
 * qualifier in `AppStoreRegistry`.
 */
object DemoCacheKeys {
    // whole-list / single-instance streams (static keys).
    const val ALERTS = "alerts"
    const val WATCHLIST = "watchlist"
    const val LOANS = "loans"
    const val BILL_REMINDERS = "billReminders"
    const val COIN_MARKETS = "crypto:coinMarkets"

    // Per-key streams — typed builders own the format string; the call site passes only the values.
    fun loan(id: String): String = "loan:$id"

    /** Cache key for one bill reminder's store-backed detail read. */
    fun billReminder(id: String): String = "billReminder:$id"

    fun coinDetail(coinId: String): String = "crypto:coinDetail:$coinId"

    fun cloudTodo(id: Int): String = "cloudTodo:$id"

    fun exchangeRates(baseCurrency: String): String = "currency:exchangeRates:$baseCurrency"

    fun spotRate(baseCurrency: String): String = "currency:spotRate:$baseCurrency"

    fun rateHistory(from: String, to: String, days: Int): String = "currency:rateHistory:$from-$to-${days}d"

    fun interestRateSeries(seriesId: String, days: Int): String = "economic:rates:$seriesId:${days}d"

    fun macroIndicator(countryCode: String, indicator: String, years: Int): String =
        "economic:macro:$countryCode:$indicator:${years}y"
}
