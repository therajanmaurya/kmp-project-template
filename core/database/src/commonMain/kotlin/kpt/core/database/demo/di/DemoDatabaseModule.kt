/*
 * Copyright 2024 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.database.demo.di

import kpt.core.base.security.FieldEncryptor
import kpt.core.database.AppDatabase
import kpt.core.database.demo.currency.converter.ChargeTypeConverters
import org.koin.dsl.module

/**
 * DemoDatabaseModule — DAO bindings for the demo Room entities. Deleted wholesale by `scripts/remove-demo.sh`
 * along with every other `demo` package.
 *
 * This is NOT the fork's seam. A fork wires its own bindings in the sibling `Project*Module` under
 * `di/`, which survives the strip. The two were previously ONE file named `Project*Module` under
 * `demo/di` — a name that read like a fork seam while carrying demo content on a demo lifecycle, so
 * `--clean` deleted the fork's only place to wire this layer.
 */
/**
 * Marker for the one-shot converter install below — `single(createdAtStart = true)` needs a type to
 * key the definition on, and this object exists only to be that key.
 */
private object ChargeTypeConvertersInstalled

val DemoDatabaseModule = module {
    single(createdAtStart = true) {
        ChargeTypeConverters.install(get<FieldEncryptor>())
        ChargeTypeConvertersInstalled
    }
    single { get<AppDatabase>().exchangeRatesDao }
    single { get<AppDatabase>().cloudTodoDao }
    single { get<AppDatabase>().coinMarketDao }
    single { get<AppDatabase>().coinDetailDao }
    single { get<AppDatabase>().rateHistoryDao }
    single { get<AppDatabase>().loanDao }
    single { get<AppDatabase>().billReminderDao }
    single { get<AppDatabase>().alertDao }
    single { get<AppDatabase>().interestRateSeriesDao }
}
