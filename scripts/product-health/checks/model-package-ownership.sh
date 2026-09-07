#!/usr/bin/env bash
# model-package-ownership.sh — core/model's declared packages stay consistent with the contract.
#
# WHY THIS EXISTS
# core/model classifies the OTHER way round from its sibling modules: the TEMPLATE's packages are
# enumerated (app-profile#model.packages[] + a `demo-showcase` rule each) and everything else under
# `kpt/core/model/` is the FORK's, resolved by the module catch-all. That is what makes the strip
# clean — one list to delete, no declaration needed for a fork's own models.
#
# It is only safe while the template's half is actually declared. A template package with no
# app-profile row is never stripped (a "clean" fork keeps showcase models it did not ask for); a
# template package with no ownership rule falls to the fork catch-all and silently stops syncing.
# Neither shows up as a build failure — the tree compiles perfectly in both cases.
#
#   MP-1 every `owner: template` package in model.packages[] resolves `demo-showcase`
#   MP-2 every declared package exists on disk in at least one source set
#   MP-3 no `demo/` directory remains under core/model (the convention this replaced)
#   MP-4 an UNDECLARED package resolves `fork` — the catch-all direction the design depends on
#
# A fork's own package is deliberately NOT required to be declared. That asymmetry is the point.
#
# exit 0 PASS / 1 FAIL.
set -uo pipefail
: "${HEALTH_ROOT:?model-package-ownership: HEALTH_ROOT not set (run via product-health.sh)}"
CS="$HEALTH_ROOT/scripts/customization-surface.sh"
APP_YAML="${MP_YAML:-$HEALTH_ROOT/app-profile/app.yaml}"
MODEL_SRC="${MP_SRC:-$HEALTH_ROOT/core/model/src}"
PKG_REL="kotlin/kpt/core/model"
fails=0
note() { echo "  $1"; fails=$((fails + 1)); }

[ -f "$APP_YAML" ] || { echo "no app-profile/app.yaml — nothing to audit (ok)"; exit 0; }
# shellcheck disable=SC1090
. "$CS" 2>/dev/null || { echo "❌ cannot source customization-surface.sh"; exit 2; }

# Declared rows: `- { id: x, owner: y }` inside the `model:` block's `packages:` list.
declared="$(awk '
  /^model:[[:space:]]*$/                      { inmod=1; next }
  /^[a-z_]+:[[:space:]]*$/                    { inmod=0 }
  inmod && /^[[:space:]]*packages:[[:space:]]*$/ { inpkg=1; next }
  inmod && inpkg && /^[[:space:]]*-[[:space:]]*\{/ {
    id=$0; sub(/.*id:[[:space:]]*/,"",id); sub(/[,}[:space:]].*$/,"",id)
    ow=$0; sub(/.*owner:[[:space:]]*/,"",ow); sub(/[,}[:space:]].*$/,"",ow)
    print id "\t" ow; next
  }
  inmod && inpkg && /^[[:space:]]*[a-z_]+:/   { inpkg=0 }
' "$APP_YAML")"

[ -n "$declared" ] || { echo "❌ MP-0 no model.packages[] declared — this audit would pass vacuously"; exit 1; }

while IFS=$'\t' read -r id owner; do
  [ -z "${id:-}" ] && continue
  # MP-2 — a declared package that does not exist is a row nobody maintains.
  if ! compgen -G "$MODEL_SRC/*/$PKG_REL/$id" >/dev/null 2>&1; then
    note "❌ MP-2 declared core/model package '$id' has no directory under $PKG_REL/"
    continue
  fi
  # MP-1 — a template package must be demo-showcase, or a sync stops updating it for forks.
  if [ "$owner" = "template" ]; then
    got="$(cs_resolve_owner "core/model/src/commonMain/$PKG_REL/$id/Probe.kt")"
    [ "$got" = "demo-showcase" ] \
      || note "❌ MP-1 core/model package '$id' is owner:template in app-profile but resolves '$got' — expected demo-showcase (add its rule to customization-surface.yaml, or it stops syncing to forks)"
  fi
done <<< "$declared"

# MP-3 — the path convention this replaced must be gone.
if find "$MODEL_SRC" -type d -name demo -not -path '*/build/*' 2>/dev/null | grep -q .; then
  note "❌ MP-3 a demo/ directory still exists under core/model — ownership is declared now, not path-inferred"
fi

# MP-4 — the catch-all direction. A fork's own package must NOT be claimed by the template blanket.
undeclared="$(cs_resolve_owner "core/model/src/commonMain/$PKG_REL/zz-undeclared-fork-pkg/X.kt")"
[ "$undeclared" = "fork" ] \
  || note "❌ MP-4 an undeclared core/model package resolves '$undeclared', expected fork — a fork's own models would be claimed by the core/** blanket"

n="$(printf '%s\n' "$declared" | grep -c .)"
[ "$fails" -eq 0 ] && { echo "✅ model-package-ownership: MP-1..MP-4 pass ($n declared package(s))"; exit 0; }
echo "❌ model-package-ownership: $fails failure(s)"; exit 1
