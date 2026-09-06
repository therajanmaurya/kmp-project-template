#!/usr/bin/env bash
# Canary for CMD-1..3 (core-module-deps.sh). Two RED legs, one GREEN.
#   red-noapply — build file does not apply the seam → the fork's deps are inert (CMD-1)
#   red-merge   — seam applied but build file back to owner:merge → merge surface returned (CMD-3)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../checks/core-module-deps.sh"
rc=0
leg() { HEALTH_ROOT="$HERE/$1" bash "$CHECK" >/dev/null 2>&1; }
for r in red-noapply red-merge; do
  echo "── RED $r (expect FAIL) ──"
  if leg "$r"; then echo "  ✗ $r passed"; rc=1; else echo "  ✓ $r failed"; fi
done
echo "── GREEN (expect PASS) ──"
if leg green; then echo "  ✓ GREEN passed"; else echo "  ✗ GREEN failed"; rc=1; fi
echo ""; [ $rc = 0 ] && echo "CANARY: ✅ PASS" || echo "CANARY: ❌ FAIL"; exit $rc
