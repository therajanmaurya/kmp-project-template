#!/usr/bin/env bash
# store-logout-purge.sh — every read store is purged on logout.
#
# WHY THIS EXISTS
# `StoreCacheManager.clearAll()` is a PRIVACY boundary: on a shared device it is what stops user A's
# cached rows from surfacing in user B's session. Registration is manual — a fork adds
# `single(AppStoreRegistry.Foo) { … }` and must ALSO add `mgr.register(get(AppStoreRegistry.Foo))` to
# the logout list. Nothing enforced the second half, so a new store could ship fully wired, fully
# tested, and silently survive logout.
#
# CONTRACT
#   LP-1 every read store registered as a `single(AppStoreRegistry.X)` also appears in the
#        logout-clear list
#
# EXCLUDED BY TYPE, NOT BY CHOICE: the `*Mutable` qualifiers. In Store5 5.1 `MutableStore` is not a
# `Store` subtype (separate read hierarchy) and `StoreCacheManagerImpl.register` takes `Store<*, *>`,
# so they cannot be registered. Their DATA is still purged — each write store shares its Room table
# with the matching read store, whose `deleteAll` wipes it. What is not purged is the MutableStore's
# own in-memory cache; if Store5 ever unifies the hierarchies, register them and drop this carve-out.
#
# Exit 0 = PASS · 1 = FAIL (blocks) · 2 = WARN.
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
# Bindings moved OUT of StoreModule.kt: they are generated into GeneratedStoreBindings.kt from
# app-profile#core_store.stores, and a fork may hand-write its own in ProjectStoreModule.kt. Both are
# scanned. StoreModule.kt is deliberately NOT scanned any more — it holds only framework wiring, and
# its KDoc describes the old shape (`single(AppStoreRegistry.X) …`), which this grep would otherwise
# read as a real binding of a store called "X" and demand a purge for it.
#
# For generated rows the drift this check was written to catch is now structurally impossible — the
# binding and the purge come from the same `logout:` field. The check still earns its keep for
# ProjectStoreModule.kt, where a fork wires a store by hand.
MODULES="$ROOT/core/store/src/commonMain/kotlin/kpt/core/store/di/GeneratedStoreBindings.kt
$ROOT/core/store/src/commonMain/kotlin/kpt/core/store/di/ProjectStoreModule.kt"
MODULE="$(mktemp)"
trap 'rm -f "$MODULE"' EXIT
# Comment lines are dropped before matching. Both files carry KDoc that SHOWS the binding shape
# (`single(AppStoreRegistry.MyThing) { … }` as a fork-facing example), and grepping raw text reads
# those samples as real bindings and demands a logout purge for a store that does not exist. A
# check that cannot tell code from prose fails on documentation, which is the wrong incentive.
while IFS= read -r m; do
  [ -f "$m" ] || continue
  sed -e 's://.*::' -e '/^[[:space:]]*\*/d' -e '/^[[:space:]]*\/\*/d' "$m" >> "$MODULE"
done <<< "$MODULES"

if [ ! -f "$MODULE" ]; then
    echo "  ✗ missing $MODULE"
    exit 1
fi

# Bindings are `single(<Store>Keys.Qualifier)` since the registry was split per store. The old
# matcher looked for `single(AppStoreRegistry.X)`, which after the split matched NOTHING — the gate
# reported "all 0 read stores are purged" and passed while checking nothing at all. A privacy gate
# that silently measures an empty set is worse than no gate, so the shape is asserted below (LP-0).
singles=$(grep -oE 'single\([A-Za-z]+Keys\.Qualifier\)' "$MODULE" \
    | sed 's/single(//; s/Keys\.Qualifier)//' | grep -v 'Mutable$' | sort -u)
cleared=$(grep -oE 'register\(get\([A-Za-z]+Keys\.Qualifier' "$MODULE" \
    | sed 's/.*register(get(//; s/Keys\.Qualifier//' | sort -u)

missing=$(comm -23 <(printf '%s\n' "$singles") <(printf '%s\n' "$cleared"))

if [ -n "$missing" ]; then
    for m in $missing; do
        printf '  ✗ LP-1 %s is registered but never cleared on logout\n' "$m"
    done
    echo "        → set `logout: true` on its row in app-profile/app.yaml#core_store.stores (generated stores), or add mgr.register(get(AppStoreRegistry.<name>)) if you wired it by hand in ProjectStoreModule.kt"
    echo "        → a store missing here keeps one user's cached rows visible to the next user on a shared device"
    exit 1
fi

n=$(printf '%s\n' "$singles" | grep -c .)
# LP-0 — the matcher found NOTHING. That is not a pass: this check went vacuous once already when
# the binding shape changed from `single(AppStoreRegistry.X)` to `single(<Store>Keys.Qualifier)` and
# the regex was not updated, so it reported "all 0 read stores are purged" while a real regression
# would have sailed through. A privacy gate measuring an empty set must fail loudly.
if [ "$n" -eq 0 ]; then
  echo "  ✗ LP-0 no store bindings matched in $(basename "$MODULE" 2>/dev/null || echo 'the scanned modules')"
  echo "        the binding shape changed and this check is measuring nothing — fix the matcher,"
  echo "        do not treat an empty result as 'everything is purged'"
  exit 1
fi
printf '  ✓ all %s read stores are purged on logout (*Mutable excluded — not a Store subtype)\n' "$n"
exit 0
