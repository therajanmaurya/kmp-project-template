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

import kpt.core.base.ui.screen.ScreenStateDefaults

/**
 * THE FORK'S branding for the shared empty / error / no-network / loading visuals.
 * Identity on the neutral template — this is yours to fill.
 *
 * [kpt.core.store.config.appScreenStateDefaults] builds the framework defaults (localized copy,
 * bundled Lottie specs, the categorised error mapper) and then hands them here, so a fork overrides
 * only what it rebrands and inherits the rest:
 *
 * ```kotlin
 * fun ScreenStateDefaults.applyProjectOverrides(): ScreenStateDefaults = copy(
 *     empty = empty.copy(visual = ScreenStateVisual.Lottie(spec = MyBrandAnimations.empty)),
 *     error = error.copy(onShown = { e -> AppTelemetry.recordError("screen_state_error", e) }),
 * )
 * ```
 *
 * The template file used to carry `!! THIS IS THE FORK CUSTOMIZATION POINT !!` and two `TODO(fork)`
 * markers, which made all 103 lines `owner: fork`: rebranding one Lottie spec cost a fork every
 * later upstream fix to the wiring around it. Splitting the seam out is what lets both sides keep
 * developing — the template evolves `config/AppScreenStateDefaults.kt`, the fork owns this file, and
 * a sync never has to merge them.
 */
fun ScreenStateDefaults.applyProjectOverrides(): ScreenStateDefaults = this
