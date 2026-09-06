#!/usr/bin/env bash
# Canary for NAP-8 (network-access-points.sh) — RED must FAIL, GREEN must PASS.
#
# RED reproduces the shipped bug: an access point declares `anon_key_env: MY_SUPABASE_KEY`, the
# codegen emits `BuildKonfig.MY_SUPABASE_KEY` into AppSupabaseAnonKeys, and NOTHING declares the
# field — `Unresolved reference` on :core:network. GREEN is the same tree with the field present in
# the generated `syncForkConfig:buildkonfig` region.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../checks/network-access-points.sh"
rc=0
run_leg() {
  local leg="$1"
  HEALTH_ROOT="$HERE/$leg" \
  NAP_YAML="$HERE/$leg/app.yaml" \
  NAP_NET_DIR="$HERE/$leg/core/network/src/commonMain/kotlin/kpt/core/network" \
  NAP_BUILD_FILE="$HERE/$leg/core/network/build.gradle.kts" \
    bash "$CHECK" >/dev/null 2>&1
}
echo "── RED (expect FAIL) ──"
if run_leg red; then echo "  ✗ RED passed — NAP-8 does not catch the undeclared field"; rc=1; else echo "  ✓ RED failed"; fi
echo "── GREEN (expect PASS) ──"
if run_leg green; then echo "  ✓ GREEN passed"; else echo "  ✗ GREEN failed"; rc=1; fi
echo ""
[ $rc = 0 ] && echo "CANARY: ✅ PASS" || echo "CANARY: ❌ FAIL"
exit $rc
