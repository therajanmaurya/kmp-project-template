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
rc=0
ok()  { echo "   ✅ $1"; }
bad() { echo "   ❌ $1"; rc=1; }

SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/scripts" "$SB/app-profile" "$SB/feature" "$SB/$(dirname "$GEN_REL")"
cp "$ROOT/scripts/remove-demo.sh" "$SB/scripts/"
cp "$ROOT/$GEN_REL" "$SB/$GEN_REL"
mkdir -p "$SB/$(dirname "$DB_REL")" "$SB/$SCHEMA_REL"
cp "$ROOT/$DB_REL" "$SB/$DB_REL"
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

( cd "$SB" && bash scripts/remove-demo.sh --apply --all --no-format ) >/dev/null 2>&1

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

ver="$(grep -o 'TEMPLATE_BASE_VERSION = [0-9]*' "$SB/$DB_REL" | head -1 | grep -o '[0-9]*')"
[ "$ver" = "1" ] \
  && ok "TEMPLATE_BASE_VERSION reset to 1 (fresh-fork baseline)" \
  || bad "TEMPLATE_BASE_VERSION is ${ver:-<unset>}, not 1 — the reset silently missed (it did, for a while)"

after_schema="$(find "$SB/$SCHEMA_REL" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
[ "$after_schema" = "0" ] \
  && ok "dropped all $before_schema exported schema JSON(s) — the fork exports its own v1 on first build" \
  || bad "$after_schema schema JSON(s) of the TEMPLATE's lineage survive alongside the v1 reset"

exit "$rc"
