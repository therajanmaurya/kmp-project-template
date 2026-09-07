/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.data.demo.di

import org.koin.core.qualifier.named

/**
 * Demo-showcase `SubmitOutbox<*>` qualifiers, relocated out of the template-owned
 * [kpt.core.data.di.OutboxQualifiers] (E1/C4). Lives under `demo/` so `scripts/remove-demo.sh`
 * deletes the whole file rather than editing a template file in place — that is what lets a
 * template sync blind-copy `OutboxQualifiers.kt` without re-introducing demo qualifiers into a
 * cleaned fork.
 *
 * See [kpt.core.data.di.OutboxQualifiers] for WHY these qualifiers exist (Koin indexes
 * `single<T>` by raw class, so every `SubmitOutbox<*>` collides without one).
 *
 * A fork does NOT edit this file: it adds its own qualifiers to `OutboxQualifiers`.
 */
object DemoOutboxQualifiers {
    /** `SubmitOutbox<kpt.core.model.banking.Loan>`. */
    val Loan = named("outbox.loan")

    /** `SubmitOutbox<kpt.core.model.banking.BillReminder>`. */
    val BillReminder = named("outbox.billReminder")

    /** `SubmitOutbox<kpt.core.model.banking.LoanCalcScenario>`. */
    val LoanCalcScenario = named("outbox.loanCalcScenario")

    /** `SubmitOutbox<kpt.core.model.alerts.PriceAlert>`. */
    val PriceAlert = named("outbox.priceAlert")
}
