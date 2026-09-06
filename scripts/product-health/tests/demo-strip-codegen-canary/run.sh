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
# Asserted against the REAL repo files in a throwaway copy — never the working tree.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
GEN_REL="core/network/src/commonMain/kotlin/kpt/core/network/di/GeneratedApiBindings.kt"
rc=0
ok()  { echo "   ✅ $1"; }
bad() { echo "   ❌ $1"; rc=1; }

SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/scripts" "$SB/app-profile" "$SB/feature" "$SB/$(dirname "$GEN_REL")"
cp "$ROOT/scripts/remove-demo.sh" "$SB/scripts/"
cp "$ROOT/$GEN_REL" "$SB/$GEN_REL"
sed -n '/^network:/,/^org:/p' "$ROOT/app-profile/app.yaml" > "$SB/app-profile/app.yaml"
printf '// demo:begin\ninclude(":feature:probe")\n// demo:end\n' > "$SB/settings.gradle.kts"

echo "── demo strip vs generated bindings (remove-demo.sh) ──"
before_pts="$(grep -cE '^    - id:' "$SB/app-profile/app.yaml")"
before_bind="$(grep -c 'restApi(\|supabaseApi(' "$SB/$GEN_REL")"
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

exit "$rc"
