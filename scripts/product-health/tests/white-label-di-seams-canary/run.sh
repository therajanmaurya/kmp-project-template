#!/usr/bin/env bash
# run.sh — RED/GREEN canary for checks/white-label-di-seams.sh.
#
# Every cell is a way a fork silently loses its DI seam to `--clean`. None of them fails to compile on
# the TEMPLATE — the damage only appears in a consumer's repo after the demo strip, which is exactly
# why it went unnoticed until now.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$(cd "$HERE/../../checks" && pwd)/white-label-di-seams.sh"
SURFACE_SH="$(cd "$HERE/../../.." && pwd)/customization-surface.sh"
rc_ok=0
cell() {
  local t="$1" exp="$2" lbl="$3" out rc
  out="$(HEALTH_ROOT="$HERE/$t" WLS_CORE_DIR="$HERE/$t/core" WLS_REGISTRY="$HERE/$t/reg/FeatureRegistry.kt" \
         WLS_SURFACE_SH="$SURFACE_SH" WLS_SURFACE_YAML="$HERE/$t/customization-surface.yaml" \
         bash "$CHECK" 2>&1)"; rc=$?
  if [ "$rc" = "$exp" ]; then echo "   ✅ $lbl → exit $rc (expected $exp)"
  else echo "   ❌ $lbl → exit $rc (expected $exp)"; printf '%s\n' "$out" | sed 's/^/        /'; rc_ok=1; fi
}
echo "── white-label DI seams (white-label-di-seams.sh) ──"
cell green            0 "seam survives, demo fenced      → PASS"
cell wls1-no-seam     1 "WLS-1 demo module, no seam      → FAIL"
cell wls2-stranded    1 "WLS-2 Project*Module under demo → FAIL"
cell wls3-seam-fenced 1 "WLS-3 seam inside demo fence    → FAIL"
cell wls4-demo-loose  1 "WLS-4 demo module outside fence → FAIL"
cell wls5-template-owned 1 "WLS-5 seam owner:template       → FAIL"
exit "$rc_ok"
