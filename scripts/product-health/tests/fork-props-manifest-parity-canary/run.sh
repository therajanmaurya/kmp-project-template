#!/usr/bin/env bash
# run.sh — RED/GREEN canary for checks/fork-props-manifest-parity.sh.
#
# gradle/fork.properties has two writers (derive.rb via AppProfile::MAP, syncForkConfig §5b via
# APP_PROFILE_MAP). If their manifests drift, the same repo yields a DIFFERENT bridge depending on
# which one ran, and consumers silently fall back for whatever the running writer omitted. A gate
# that cannot fail would not have caught the real 2026-09-06 drift, so both directions are proven:
#
#   identical manifests        → PASS
#   key missing from one       → FAIL  (the real incident's shape)
#   same key, different path   → FAIL
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$(cd "$HERE/../../checks" && pwd)/fork-props-manifest-parity.sh"
rc_ok=0

cell() { # <rb-fixture> <expected-exit> <label>
  local rb="$1" exp="$2" lbl="$3" out rc
  out="$(HEALTH_ROOT="$HERE" FORK_PARITY_KT="$HERE/kt-in-sync.kt" FORK_PARITY_RB="$HERE/$rb" bash "$CHECK" 2>&1)"; rc=$?
  if [ "$rc" = "$exp" ]; then
    echo "   ✅ $lbl → exit $rc (expected $exp)"
  else
    echo "   ❌ $lbl → exit $rc (expected $exp)"; printf '%s\n' "$out" | sed 's/^/        /'; rc_ok=1
  fi
}

echo "── manifest parity (fork-props-manifest-parity.sh) ──"
cell rb-in-sync.rb     0 "manifests identical        → PASS"
cell rb-missing-key.rb 1 "key missing from one       → FAIL"
cell rb-wrong-path.rb  1 "same key, different path   → FAIL"
exit "$rc_ok"
