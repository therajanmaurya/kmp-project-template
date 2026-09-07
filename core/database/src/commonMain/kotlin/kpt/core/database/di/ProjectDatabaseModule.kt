/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.database.di

import org.koin.dsl.module

/**
 * THE FORK'S database DI seam. Empty on the neutral template — this is yours to fill.
 *
 * It lives outside `demo/` on purpose, so `scripts/remove-demo.sh` leaves it standing: a fork that
 * runs the customizer (which strips the demo BY DEFAULT — "forking = starting clean") keeps this file
 * and can wire DI immediately. Its demo counterpart is deleted by that same strip.
 *
 * Example:
 * ```
 * single { get<AppDatabase>().myDao }
 * ```
 */
// demo:begin — marker type for the one-shot converter install below.
private object ChargeTypeConvertersInstalled
// demo:end

val ProjectDatabaseModule = module {
    // demo:begin — a one-shot converter install: ChargeTypeConverters needs a FieldEncryptor before
    // Room touches an encrypted column. It is NOT derivable from a `daos:`/`entities:` declaration
    // the way a DAO binding is, so it belongs in the fork seam rather than in generated code.
    // `createdAtStart = true` runs it at graph construction; the marker object only keys the single.
    single(createdAtStart = true) {
        kpt.core.database.currency.converter.ChargeTypeConverters.install(
            get<kpt.core.base.crypto.FieldEncryptor>(),
        )
        ChargeTypeConvertersInstalled
    }
    // demo:end
    // Intentionally empty on the template — a fork adds its own bindings here.
}
