#!/usr/bin/env bash
# run.sh — the generated API bindings must SURVIVE `remove-demo.sh` and be left coherent.
#
# GeneratedApiBindings.kt is derived from the FORK's app-profile, so it is not demo content — but it
# used to live under `core/network/.../demo/di/`, and remove-demo.sh deletes every `**/demo/**`
# package outright. That combination was silently destructive: `customize.sh` strips the demo BY
# DEFAULT ("forking = starting clean"), so a fork lost the generated file, and regenerateApiBindings'
# `if (!dir.isDirectory) return` guard then made every later syncForkConfig a NO-OP. A fork could
# declare `api:` in app.yaml forever and never get a binding, with nothing reporting it.
#
# Moving the file to `di/` fixes that but creates the opposite hazard: it now survives while the demo
# API classes it binds are deleted. So remove-demo.sh must ALSO (a) strip the fenced demo access
# points from app-profile/app.yaml, so a cleaned fork stops DECLARING endpoints it can no longer
# compile, and (b) reset the generated file to its empty-module form so the tree compiles before the
# fork re-runs syncForkConfig.
#
# The SAME hazard now exists for `core/database/**/AppDatabase.kt` (E1/C7): its demo entities/DAOs/
# migrations/converters moved OUT of `demo:`-fenced blocks in the file and into
# `app-profile/app.yaml#database`, projected back by syncForkConfig into `gen-*` regions. Stripping
# the app-profile fence removes the DECLARATION, but the generated OUTPUT is committed source — so
# remove-demo.sh must also empty those regions, or a cleaned fork keeps entities referencing
# `kpt.core.database.demo.*` classes step 4 just deleted (unresolved refs) plus AutoMigrations
# targeting a version past the v1 it just reset to. The exported schema JSONs go too: they describe
# the TEMPLATE's lineage (v1 is a lone `samples` table), so a fork that later bumps VERSION_OFFSET
# would have Room validate an auto-migration between two unrelated schemas.
#
# Asserted against the REAL repo files in a throwaway copy — never the working tree.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
GEN_REL="core/network/src/commonMain/kotlin/kpt/core/network/di/GeneratedApiBindings.kt"
DB_REL="core/database/src/commonMain/kotlin/kpt/core/database/AppDatabase.kt"
SCHEMA_REL="core/database/schemas/kpt.core.database.AppDatabase"
LEDGER_REL="app-profile/migration-ledger.yaml"
rc=0
ok()  { echo "   ✅ $1"; }
bad() { echo "   ❌ $1"; rc=1; }

SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/scripts" "$SB/app-profile" "$SB/feature" "$SB/$(dirname "$GEN_REL")"
cp "$ROOT/scripts/remove-demo.sh" "$SB/scripts/"
cp "$ROOT/$GEN_REL" "$SB/$GEN_REL"
mkdir -p "$SB/$(dirname "$DB_REL")" "$SB/$SCHEMA_REL"
cp "$ROOT/$DB_REL" "$SB/$DB_REL"
cp "$ROOT/$LEDGER_REL" "$SB/$LEDGER_REL" 2>/dev/null || true
mkdir -p "$SB/core/database"
cp "$ROOT/core/database/migration-units.yaml" "$SB/core/database/" 2>/dev/null || true
cp "$ROOT/$SCHEMA_REL"/*.json "$SB/$SCHEMA_REL/" 2>/dev/null || true
# app.yaml needs BOTH the network block and the database block for this fixture.
sed -n '/^network:/,/^org:/p' "$ROOT/app-profile/app.yaml"  > "$SB/app-profile/app.yaml"
sed -n '/^database:/,/^org:/p' "$ROOT/app-profile/app.yaml" >> "$SB/app-profile/app.yaml"
printf '// demo:begin\ninclude(":feature:probe")\n// demo:end\n' > "$SB/settings.gradle.kts"

echo "── demo strip vs generated bindings (remove-demo.sh) ──"
before_pts="$(grep -cE '^    - id:' "$SB/app-profile/app.yaml")"
before_bind="$(grep -c 'restApi(\|supabaseApi(' "$SB/$GEN_REL")"
before_ent="$(sed -n '/entities = \[/,/\]/p' "$SB/$DB_REL" | grep -c '::class')"
before_schema="$(find "$SB/$SCHEMA_REL" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
[ "$before_bind" -gt 0 ] || bad "fixture is vacuous — the repo's generated file has no bindings to strip"

# --no-regen: this sandbox is a handful of copied files with no gradlew, and the strip HARD-FAILS if
# it cannot re-derive. Its exit code is checked — it was not, and every green this canary reported
# after the regen step was added came from a strip that had exited 1 partway through. The assertions
# still held only because steps 1-4 run BEFORE the regen step, which is luck, not verification.
if ( cd "$SB" && bash scripts/remove-demo.sh --apply --all --no-format --no-regen ) >/dev/null 2>&1; then
  ok "strip completed (exit 0)"
else
  bad "strip FAILED — every assertion below is measuring a partially-stripped tree"
fi

[ -f "$SB/$GEN_REL" ] \
  && ok "generated bindings SURVIVE the strip (not under demo/)" \
  || bad "generated bindings were DELETED — codegen is now a permanent no-op for a cleaned fork"

if [ -f "$SB/$GEN_REL" ]; then
  left="$(grep -c 'restApi(\|supabaseApi(' "$SB/$GEN_REL")"
  [ "$left" = "0" ] \
    && ok "reset to the empty module (was $before_bind bindings, now $left)" \
    || bad "$left binding(s) remain, referencing deleted demo API classes"
  imports="$(grep -c '^import kpt.core.network.demo' "$SB/$GEN_REL")"
  [ "$imports" = "0" ] && ok "no dangling demo imports" || bad "$imports dangling demo import(s)"
fi

demo_api="$(grep -c 'api: kpt.core.network.demo' "$SB/app-profile/app.yaml")"
[ "$demo_api" = "0" ] \
  && ok "app.yaml no longer declares any demo api: binding" \
  || bad "$demo_api demo api: line(s) survive — the next syncForkConfig would rebuild an uncompilable binding"

after_pts="$(grep -cE '^    - id:' "$SB/app-profile/app.yaml")"
[ "$after_pts" -gt 0 ] && [ "$after_pts" -lt "$before_pts" ] \
  && ok "kept the $after_pts non-demo access point(s), dropped $((before_pts - after_pts)) demo one(s)" \
  || bad "access-point strip wrong: $before_pts → $after_pts (expected a partial drop, not all/none)"


echo "── demo strip vs the generated @Database regions (E1/C7) ──"
[ "$before_ent" -gt 4 ] || bad "fixture is vacuous — AppDatabase had no generated entities to strip"
[ "$before_schema" -gt 0 ] || bad "fixture is vacuous — no exported schema JSONs to drop"

demo_refs="$(grep -c 'kpt\.core\.database\.demo' "$SB/$DB_REL")"
[ "$demo_refs" = "0" ] \
  && ok "AppDatabase carries no demo reference (regions emptied)" \
  || bad "$demo_refs demo reference(s) survive — they point at classes remove-demo just deleted (compile break)"

migs="$(sed -n '/autoMigrations = \[/,/\]/p' "$SB/$DB_REL" | grep -c 'AutoMigration(')"
[ "$migs" = "0" ] \
  && ok "no AutoMigration survives (a fresh fork has no installed users to migrate)" \
  || bad "$migs AutoMigration(s) survive against the v1 baseline — Room rejects a migration past its version"

conv="$(grep -c '@ColumnTypeConverters' "$SB/$DB_REL")"
[ "$conv" = "0" ] \
  && ok "@ColumnTypeConverters removed entirely (Room rejects an argument-less one)" \
  || bad "@ColumnTypeConverters survives with deleted converter classes"

# The version moved OUT of AppDatabase into the fork-owned ledger: the template no longer
# contributes to a fork's schema version at all (TEMPLATE_BASE_VERSION + VERSION_OFFSET could not
# work — a template bump shifted the fork's numbering out from under its installed devices).
ver="$(grep -oE '^version:[[:space:]]*[0-9]+' "$SB/$LEDGER_REL" 2>/dev/null | grep -oE '[0-9]+')"
[ "$ver" = "1" ] \
  && ok "ledger version reset to 1 (fresh-fork baseline)" \
  || bad "ledger version is ${ver:-<unset>}, not 1 — the reset silently missed (it did, for a while)"
# The FRAMEWORK entities are generated too now (from core-base/database/module-schema.yaml), so the
# strip empties their region like any other. That is only safe because syncForkConfig refills it
# AFTER the strip — the ordering that customize.sh originally had backwards. If it ever regresses, a
# cleaned fork gets a @Database with ZERO entities, which is worse than any dangling reference: Room
# fails at compile with no table at all. Here (--no-regen) the region MUST be empty; the real
# "4 entities come back" proof needs gradle and lives in the clone test.
infra_e="$(sed -n '/gen-infra-entities:begin/,/gen-infra-entities:end/p' "$SB/$DB_REL" 2>/dev/null | grep -c '::class' | head -1)"
infra_d="$(sed -n '/gen-infra-daos:begin/,/gen-infra-daos:end/p' "$SB/$DB_REL" 2>/dev/null | grep -c 'abstract val' | head -1)"
[ "${infra_e:-0}" -gt 0 ] 2>/dev/null \
  && ok "cleaned fork KEEPS its ${infra_e} framework entities (gen-infra-* is not demo-lifecycle)" \
  || bad "cleaned fork has ${infra_e:-0} framework entities — a @Database with no tables does not compile"
[ "${infra_d:-0}" -gt 0 ] 2>/dev/null \
  && ok "cleaned fork KEEPS its ${infra_d} framework DAO accessors" \
  || bad "cleaned fork has ${infra_d:-0} framework DAO accessors — core-base cannot resolve its own DAOs"
grep -q 'gen-infra-entities:begin' "$SB/$DB_REL" 2>/dev/null \
  && ok "infra entity region MARKERS survive (regen has somewhere to write)" \
  || bad "gen-infra-entities markers gone — syncForkConfig can never refill; fork ships zero entities"

# NOTE: `grep -c` prints 0 AND exits 1 on no-match, so `|| echo 0` would yield "0\n0".
rows="$(grep -cE '^[[:space:]]*-[[:space:]]*\{.*from:' "$SB/$LEDGER_REL" 2>/dev/null | head -1)"
rows="${rows:-0}"
[ "$rows" = "0" ] \
  && ok "ledger migrations emptied (a fresh fork has no installed users to migrate)" \
  || bad "$rows migration row(s) survive against the v1 baseline"
# baseline_units is what stops the next syncForkConfig re-appending units the fresh v1 already has.
base="$(grep -oE '^baseline_units:.*' "$SB/$LEDGER_REL" 2>/dev/null)"
case "$base" in
  *"[]"*|"") bad "baseline_units is empty — syncForkConfig would append every template unit as a migration the fresh v1 already contains" ;;
  *)         ok "baseline_units records the units folded into the fresh schema" ;;
esac

after_schema="$(find "$SB/$SCHEMA_REL" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
[ "$after_schema" = "0" ] \
  && ok "dropped all $before_schema exported schema JSON(s) — the fork exports its own v1 on first build" \
  || bad "$after_schema schema JSON(s) of the TEMPLATE's lineage survive alongside the v1 reset"

exit "$rc"
