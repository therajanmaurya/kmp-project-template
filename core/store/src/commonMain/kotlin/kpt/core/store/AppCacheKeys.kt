/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.store

/**
 * Single source of truth for every `asScreenStream` / `asPagingScreenStream` **cacheKey** — the
 * string that keys per-stream fetched-at (freshness) tracking. Owned here in `core/store` next to
 * [AppStoreRegistry], so the key strings live in ONE place and cannot drift or silently collide.
 *
 * `core/data` repositories reference these constants + typed builders instead of inlining string
 * literals at the call site — a repo does `cacheKey = AppCacheKeys.MY_THINGS` or
 * `cacheKey = AppCacheKeys.myThing(id)`, never `cacheKey = "myThing:$id"`. The format of a key lives here;
 * a call site only supplies the values. A fork adds one line per new stream, next to its store
 * qualifier in [AppStoreRegistry]:
 * ```
 * const val MY_THINGS = "myThings"
 * fun myThing(id: String): String = "myThing:$id"
 * ```
 *
 * Intentionally EMPTY on the template (E1/C5). The demo showcase's keys live in the fork-owned
 * [kpt.core.store.demo.DemoCacheKeys] under `demo/`, so `remove-demo.sh` deletes them with the rest
 * of the showcase and a template sync can blind-copy THIS file without re-introducing them.
 */
object AppCacheKeys
