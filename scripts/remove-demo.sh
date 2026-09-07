#!/usr/bin/env bash
#
# remove-demo.sh — strip the kmp-project-template demo showcase, leaving a clean fork.
#
# Invoked by `scripts/white-label/customize.sh --clean`. Convention (showcase-framework-separation epic):
#   • demo domain code lives under **/demo/** packages,
#   • demo feature modules are include()d inside a `// demo:begin … // demo:end` block
#     in settings.gradle.kts,
#   • demo entries in central files (@Database, Koin modules, store registry) are wrapped
#     in `// demo:begin … // demo:end` markers.
#
# Removal = strip every marked block + delete every **/demo/** package + delete the demo
# feature modules + reset the DB schema to a fresh-fork baseline + swap the demo-coupled
# app shell (home dashboard + nav) for a minimal placeholder.
#
# NOTE: feature-name regex accepts [A-Za-z0-9_-]+ (Kotlin-idiomatic include(":feature:PascalCase")
# + digit-suffixed feature dirs are legal). Regression-tested by
# tests/fixtures/remove-demo-regex-canary/{red,green}/.
#
# Usage:
#   remove-demo.sh                 # DRY RUN (default) — report what would change, touch nothing
#   remove-demo.sh --apply         # actually perform the removal
#   remove-demo.sh --apply --all   # explicit; --all is the only supported scope today
#
set -euo pipefail

APPLY=0
FORMAT=1
REGEN=1
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --all)   : ;;                    # only supported scope today; per-feature is a later enhancement
    --dry-run) APPLY=0 ;;
    --no-format) FORMAT=0 ;;         # skip closing spotlessApply (fast iteration)
    --no-regen)  REGEN=0 ;;          # skip the post-strip syncForkConfig (gradle-free callers only)
    *) echo "remove-demo.sh: unknown arg '$arg'" >&2; exit 2 ;;
  esac
done

# repo root = parent of scripts/
cd "$(dirname "$0")/.."

MODE=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)
say() { if [ "$APPLY" -eq 1 ]; then echo "  $*"; else echo "  [dry-run] would $*"; fi; }

# ── 1. Demo feature names (parsed from the settings demo-block BEFORE it is stripped) ──
DEMO_FEATURES=$(awk '/demo:begin/{s=1;next} /demo:end/{s=0} s' settings.gradle.kts \
                  | grep -oE 'feature:[A-Za-z0-9_-]+' | sed 's/feature://' || true)

# ── 1b. TEMPLATE-owned ACCESS-POINT ids (declared, not inferred) ──────────────────────────────────
#     Every access point in app-profile carries `owner: fork|template`. `template` means the showcase
#     ships it and a clean fork must not: the entry AND its `kpt/core/network/<id>/` package go.
#
#     This used to be inferred by awk-ing between `# demo:begin`/`# demo:end` in app.yaml, which is
#     positional and could not express `supabase_data` — its point sat OUTSIDE the fence while its
#     `api:` sat inside, so the facade survived the strip and needed a second, separate parser. One
#     declared field per entry replaces both parsers and cannot drift from what it describes.
TEMPLATE_POINTS=$(awk '
  /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/ { id=$0; sub(/.*id:[[:space:]]*/,"",id); sub(/[[:space:]].*$/,"",id); owner="" ; next }
  /^[[:space:]]*owner:[[:space:]]*/ { o=$0; sub(/.*owner:[[:space:]]*/,"",o); sub(/[[:space:]].*$/,"",o); if (id != "" && o == "template") { print id; id="" } }
' app-profile/app.yaml 2>/dev/null || true)

# ── 2. Marked files to strip (convention-discovered) ──────────────────────────────────
# *.yaml included so app-profile's fenced demo blocks are stripped too. Test fixtures are EXCLUDED:
# `scripts/product-health/tests/**` holds RED/GREEN canary trees whose whole purpose is to CONTAIN
# demo fences (wls3-seam-fenced, wls4-demo-loose, network-buildkonfig). Stripping them turns every
# RED fixture green, silently disabling the gates that verify the white-label machinery — the strip
# would quietly break its own safety net.
MARKED_FILES=$(grep -rl 'demo:begin' --include='*.kt' --include='*.kts' --include='*.yaml' . 2>/dev/null \
  | grep -v '/build/' | grep -v '/product-health/tests/' || true)

echo "remove-demo ($MODE): demo features = ${DEMO_FEATURES//$'\n'/ }"
echo "remove-demo ($MODE): template access points = ${TEMPLATE_POINTS//$'\n'/ }"

# ── 3. Strip every `// demo:begin … // demo:end` block ────────────────────────────────
echo "strip marked blocks:"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  say "strip demo blocks in ${f#./}"
  if [ "$APPLY" -eq 1 ]; then
    awk '/demo:begin/{skip=1} /demo:end/{skip=0; next} !skip' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
done <<< "$MARKED_FILES"

# ── 3b. Remove dangling demo imports left in surviving files by the block strip ───────
#     (an `import kpt.core.<m>.demo.…` or `import kpt.feature.<demoFeature>.…` whose target
#      was just deleted is an unresolved-reference compile error, not a warning — drop them.)
echo "remove dangling demo imports:"
DEMO_PKGS=$(echo "$DEMO_FEATURES" | sed 's/-//g' | paste -sd'|' -)
[ -z "$DEMO_PKGS" ] && DEMO_PKGS="__none__"
say "strip 'import kpt.core.*.demo.*' + demo-feature imports from surviving .kt files"
if [ "$APPLY" -eq 1 ]; then
  find . -name '*.kt' -not -path '*/build/*' -not -path '*/product-health/tests/*' -print0 | while IFS= read -r -d '' f; do
    sed -i '' -E \
      -e '/^import kpt\.core\.[a-z]+\.demo\./d' \
      -e '/^import kpt\.feature\.[a-z]+\.demo\./d' \
      -e "/^import kpt\\.feature\\.(${DEMO_PKGS})[.]/d" \
      "$f"
  done
fi

# ── 4. Delete every **/demo/** package directory under core/ ──────────────────────────
echo "delete demo packages:"
while IFS= read -r d; do
  [ -z "$d" ] && continue
  say "rm -rf ${d#./}"
  [ "$APPLY" -eq 1 ] && rm -rf "$d"
done < <(find core feature -type d -name demo -not -path '*/build/*' 2>/dev/null)

# ── 4b. Reset the generated API bindings ──────────────────────────────────────────────
#     GeneratedApiBindings.kt is NOT under demo/ (deliberately — see NetworkModule), so step 4 leaves
#     it in place still binding the demo APIs it just deleted. Step 3b strips its `import kpt.core.*
#     .demo.*` lines but not the restApi(...) calls, which would then be unresolved references. Reset
#     it to the generator's own empty-module form; the fork's next `./gradlew syncForkConfig` refills
#     it from whatever its app-profile declares.
GEN_BINDINGS="core/network/src/commonMain/kotlin/kpt/core/network/di/GeneratedApiBindings.kt"
echo "reset generated api bindings:"
if [ -f "$GEN_BINDINGS" ]; then
  say "reset ${GEN_BINDINGS#./}"
  if [ "$APPLY" -eq 1 ]; then
    cat > "$GEN_BINDINGS" <<'GENEOF'
/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
package kpt.core.network.di

import org.koin.core.module.Module
import org.koin.dsl.module

/**
 * GENERATED by `./gradlew syncForkConfig` from `app-profile/app.yaml#network.access_points`
 * — one Koin binding per access point that declares `api:`. DO NOT HAND-EDIT.
 *
 * To add an API: declare the endpoint (with its `api:` FQN) in app-profile, write the API
 * type, and re-run syncForkConfig. There is no wiring step — that is the point.
 *
 * Pulled in by `NetworkModule` via `includes(GeneratedApiBindings)`.
 */
val GeneratedApiBindings: Module = module {
    // No access point declares `api:` yet — add one in app-profile/app.yaml.
}
GENEOF
  fi
fi

# ── 4b2. Delete TEMPLATE-owned per-module packages (core/<module>/<id>) ───────────────
#     Declared PER MODULE under `<module>: packages:` in app-profile — "core/database has an alerts
#     entity" is a different fact from "core/store has an alerts store", and the modules genuinely
#     differ (exchange is store-only; calc/emi have no table). One awk over each module's own block.
echo "delete template module packages:"
for mod in database data model store domain network ui designsystem common platform datastore firebase; do
  pkgs=$(awk -v m="$mod" '
    $0 ~ "^" m ":[[:space:]]*$" { inmod=1; next }
    /^[a-z_]+:[[:space:]]*$/    { inmod=0 }
    inmod && /^[[:space:]]*packages:[[:space:]]*$/ { inpkg=1; next }
    inmod && inpkg && /^[[:space:]]*-[[:space:]]*\{/ {
      line=$0
      if (line ~ /owner:[[:space:]]*template/) { id=line; sub(/.*id:[[:space:]]*/,"",id); sub(/[,}[:space:]].*$/,"",id); print id }
      next
    }
    inmod && inpkg && /^[[:space:]]*[a-z_]+:/ { inpkg=0 }
  ' app-profile/app.yaml 2>/dev/null || true)
  [ -z "$pkgs" ] && continue
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    for sub in commonMain commonTest androidMain iosMain desktopMain; do
      d="core/$mod/src/$sub/kotlin/kpt/core/$mod/$id"
      [ -d "$d" ] || continue
      say "rm -rf $d  (core/$mod package '$id', owner: template)"
      [ "$APPLY" -eq 1 ] && rm -rf "$d"
    done
  done <<< "$pkgs"
done

# ── 4c. Delete the per-access-point packages of the TEMPLATE-owned endpoints ──────────
#     Endpoint code lives in a package named for its access point (`kpt/core/network/<id>/`), not
#     under `demo/`, so step 4's sweep does not reach it.
echo "delete template access-point packages:"
NET_PKG_ROOT="core/network/src/commonMain/kotlin/kpt/core/network"
NET_TEST_ROOT="core/network/src/commonTest/kotlin/kpt/core/network"
while IFS= read -r ap; do
  [ -z "$ap" ] && continue
  # id -> package: lowercase, non-alphanumerics dropped (supabase_data -> supabasedata). MUST match
  # scaffoldAccessPointPackages in SyncForkConfigPlugin or the strip misses what the scaffold made.
  pkg=$(printf '%s' "$ap" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')
  [ -z "$pkg" ] && continue
  for d in "$NET_PKG_ROOT/$pkg" "$NET_TEST_ROOT/$pkg"; do
    [ -d "$d" ] || continue
    say "rm -rf $d  (access point '$ap', owner: template)"
    [ "$APPLY" -eq 1 ] && rm -rf "$d"
  done
done <<< "$TEMPLATE_POINTS"

# ── 4d. Drop those entries from app-profile itself ────────────────────────────────────
#     Block-shaped delete: an access point is a `- id:` block, so buffer each block and drop the ones
#     whose body declares `owner: template`. Comment-preserving, unlike a YAML round-trip.
echo "drop template access points from app-profile:"
say "remove $(echo "$TEMPLATE_POINTS" | grep -c . || echo 0) template access point(s) from app-profile/app.yaml"
if [ "$APPLY" -eq 1 ]; then
  awk '
    function flush() { if (n > 0) { if (!drop) for (i = 1; i <= n; i++) print buf[i]; n = 0; drop = 0 } }
    /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/ { flush(); inblk = 1; n = 1; buf[1] = $0; drop = 0; next }
    inblk && /^[[:space:]]*owner:[[:space:]]*template[[:space:]]*$/ { drop = 1; buf[++n] = $0; next }
    inblk && /^[[:space:]]{6,}/ { buf[++n] = $0; next }
    inblk && /^[[:space:]]*#/ { buf[++n] = $0; next }
    { flush(); inblk = 0; print }
    END { flush() }
  ' app-profile/app.yaml > app-profile/app.yaml.tmp && mv app-profile/app.yaml.tmp app-profile/app.yaml
  left=$(awk '/^[[:space:]]*owner:[[:space:]]*template/{c++} END{print c+0}' app-profile/app.yaml)
  [ "$left" = "0" ] || { echo "remove-demo: FAILED to drop template access points ($left left)" >&2; exit 1; }
fi

# ── 5. Delete demo feature modules ────────────────────────────────────────────────────
echo "delete demo feature modules:"
while IFS= read -r feat; do
  [ -z "$feat" ] && continue
  say "rm -rf feature/$feat"
  [ "$APPLY" -eq 1 ] && rm -rf "feature/$feat"
done <<< "$DEMO_FEATURES"

# ── 6. Reset the Room schema VERSION to a fresh-fork baseline ─────────────────────────
#     (the @AutoMigration history lived inside the stripped demo block; a fresh fork has
#      no installed users to migrate, so it starts clean at v1).
#     Reset the fork-owned LEDGER, not a constant on AppDatabase: the version now lives in
#     `app-profile/migration-ledger.yaml` and AppDatabase reads it via ForkDatabaseConfig.
#     A fresh fork is CREATED with the framework tables in their current shape, so it needs no
#     migration for them — it records every declared unit in `baseline_units` instead. Without that,
#     the next syncForkConfig would append all of them as migrations the fork's v1 already contains.
LEDGER="app-profile/migration-ledger.yaml"
if [ -f "$LEDGER" ]; then
  say "reset $LEDGER → version 1, empty migrations, baseline = every declared unit"
  if [ "$APPLY" -eq 1 ]; then
    # `|| true`: grep exits 2 when the file is absent, and under `set -e` that killed the whole strip
    # silently — a fork that stripped the white-label machinery legitimately has no units file.
    units=$(grep -hoE 'id:[[:space:]]*[A-Za-z0-9_-]+' core/database/migration-units.yaml 2>/dev/null \
              | sed 's/.*id:[[:space:]]*//' | paste -sd', ' - || true)
    sed -i '' -e "s/^version:[[:space:]]*[0-9][0-9]*/version: 1/" \
              -e "s/^baseline_units:.*/baseline_units: [${units}]/" "$LEDGER"
    grep -q '^version: 1$' "$LEDGER" \
      || { echo "remove-demo: FAILED to reset $LEDGER version" >&2; exit 1; }
  fi
fi

#     …and DROP the exported schema history with it. Version, autoMigrations and the exported
#     schema JSONs are ONE atomic unit: the JSONs under core/database/schemas/ describe the
#     TEMPLATE's lineage (v1 is a lone `samples` table dropped back at v10), which has nothing to do
#     with a cleaned fork's v1 of four infra tables. Leaving them behind is not cosmetic — the first
#     time the fork bumps ForkDatabaseConfig.VERSION_OFFSET, Room validates its auto-migration
#     against the template's stale N.json and computes a migration between unrelated schemas.
#     Deleting them makes the fork's first build export its own v1 from its own @Database.
#     …and EMPTY the syncForkConfig-generated regions that projected those declarations into
#     source. Stripping the app-profile fence removes the DECLARATION, but the generated OUTPUT is
#     committed source: AppDatabase.kt's `gen-*` regions still hold the demo entities/DAOs/migrations
#     whose classes step 4 just deleted (unresolved references), and an AutoMigration targeting v13
#     against the v1 we just reset to. Done as text surgery rather than by invoking syncForkConfig so
#     the strip stays gradle-free and deterministic; the fork's next syncForkConfig refills the
#     regions from its OWN app-profile.
GEN_REGION_FILES="core/database/src/commonMain/kotlin/kpt/core/database/AppDatabase.kt"
echo "empty generated regions:"
for f in $GEN_REGION_FILES; do
  [ -f "$f" ] || continue
  n_gen=$(grep -c 'gen-[a-z]*:begin' "$f" 2>/dev/null || echo 0)
  say "empty $n_gen generated region(s) in ${f#./}"
  if [ "$APPLY" -eq 1 ]; then
    # PROJECT-SPECIFIC regions only. `gen-infra-*` is deliberately NOT matched (the pattern excludes
    # hyphenated names): those hold the FRAMEWORK tables, which every fork has — emptying them would
    # leave a cleaned fork with a @Database of zero entities until a regen happened to run, and Room
    # fails at compile with no table at all. Demo/fork content is project-specific and must go; the
    # framework's is not and must stay.
    awk '/gen-[a-z]+:begin/{print; skip=1; next} /gen-[a-z]+:end/{skip=0} !skip' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    # A leftover demo reference here is a guaranteed compile break — fail loudly, never ship it.
    if grep -q 'kpt\.core\.database\.demo' "$f"; then
      echo "remove-demo: FAILED to empty generated regions in $f (demo refs remain)" >&2; exit 1
    fi
  fi
done

SCHEMAS="core/database/schemas"
if [ -d "$SCHEMAS" ]; then
  n_schema=$(find "$SCHEMAS" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
  say "drop $n_schema exported schema JSON(s) under $SCHEMAS/ (template lineage — regenerated on first build)"
  if [ "$APPLY" -eq 1 ]; then
    find "$SCHEMAS" -name '*.json' -delete
    left=$(find "$SCHEMAS" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
    [ "$left" = "0" ] \
      || { echo "remove-demo: FAILED to drop exported schemas under $SCHEMAS ($left left)" >&2; exit 1; }
  fi
fi

# ── 6c. Re-derive every syncForkConfig-generated surface from the STRIPPED app-profile ───
#     Stripping the demo fence removes the DECLARATION; the generated OUTPUT is committed source and
#     must be rebuilt from what survives. `customize.sh` runs syncForkConfig BEFORE this script, which
#     is the wrong side of the strip — so a cleaned fork kept AppAccessPoints / AppUrlTypes /
#     AppSupabaseAnonKeys listing the 5 demo endpoints that app.yaml no longer declares (NAP-1 + NAP-3
#     both fail on it).
#
#     The GENERATOR is the only thing that knows each file's correct empty form — notably these three
#     wrap `val points = listOf(` INSIDE their sentinel region, so text-emptying them would delete the
#     declaration and break every consumer. Hence a real regeneration, not more surgery.
if [ "$APPLY" -eq 1 ] && [ "$REGEN" -eq 1 ]; then
  echo "re-derive generated surfaces:"
  say "run ./gradlew syncForkConfig (rebuild generated files from the stripped app-profile)"
  if ./gradlew syncForkConfig --quiet --console=plain; then
    echo "  ✓ generated surfaces re-derived"
  else
    echo "remove-demo: FAILED to re-derive generated surfaces (./gradlew syncForkConfig)." >&2
    echo "  The tree still declares demo endpoints in AppAccessPoints/AppUrlTypes and will not be" >&2
    echo "  coherent. Re-run './gradlew syncForkConfig' manually, or pass --no-regen if intentional." >&2
    exit 1
  fi
elif [ "$REGEN" -eq 0 ]; then
  say "SKIP post-strip syncForkConfig (--no-regen) — generated surfaces may still list demo entries"
fi

# ── 7. Formatter pass to drop the now-unused demo imports left by the block strip ─────
#     The app shell (home dashboard + nav) needs NO swap: the demo dashboard lives under
#     feature/home/demo/ (deleted in step 4) and the framework HomeScreen shell + nav files
#     carry `// demo:begin … // demo:end` blocks (stripped in step 3). The stripped shell —
#     top bar + settings entry point + empty home body — compiles as-is for the fork to fill.
if [ "$APPLY" -eq 1 ] && [ "$FORMAT" -eq 1 ]; then
  say "run ./gradlew spotlessApply (drops now-unused imports left by the strip)"
  ./gradlew spotlessApply --console=plain -q || true
else
  say "spotless SKIPPED (--no-format or dry-run)"
fi

echo "remove-demo: done ($MODE)."
