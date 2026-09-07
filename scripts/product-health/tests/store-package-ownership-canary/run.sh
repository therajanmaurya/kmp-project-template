#!/usr/bin/env bash
# store-package-ownership-canary — RED/GREEN for SP-1..SP-3.
#
# Each RED leg asserts the SPECIFIC check id it is meant to trip. A canary that only asserts
# "exit != 0" cannot tell a working gate from a broken one: a gate that crashes on a typo also exits
# non-zero, and would sail through. Requiring the gate to name its own failure is what makes a
# vacuous pass detectable.
set -uo pipefail
cd "$(dirname "$0")/../../../.." || exit 2
GATE="scripts/product-health/checks/store-package-ownership.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
fails=0

seed() {
  rm -rf "$SANDBOX/repo"; mkdir -p "$SANDBOX/repo"
  # Only what the gate reads: app-profile + the store package tree + the gate itself.
  mkdir -p "$SANDBOX/repo/app-profile" \
           "$SANDBOX/repo/scripts/product-health/checks" \
           "$SANDBOX/repo/core/store/src/commonMain/kotlin/kpt/core/store"
  cp "$GATE" "$SANDBOX/repo/scripts/product-health/checks/"
  cat > "$SANDBOX/repo/app-profile/app.yaml" <<'YAML'
core_store:
  packages:
    - { id: alerts,  owner: template }
    - { id: prefs,   owner: fork }
org:
  name: X
YAML
  mkdir -p "$SANDBOX/repo/core/store/src/commonMain/kotlin/kpt/core/store/alerts"
  mkdir -p "$SANDBOX/repo/core/store/src/commonMain/kotlin/kpt/core/store/prefs"
  mkdir -p "$SANDBOX/repo/core/store/src/commonMain/kotlin/kpt/core/store/di"
}

run_gate() { ( cd "$SANDBOX/repo" && bash scripts/product-health/checks/store-package-ownership.sh 2>&1 ); }

expect_red() {
  local label="$1" id="$2" out rc
  out=$(run_gate); rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "❌ $label: gate PASSED but should have failed"; fails=$((fails + 1)); return
  fi
  if ! echo "$out" | grep -q "$id"; then
    echo "❌ $label: gate failed but never named $id — cannot tell a real catch from a broken gate"
    echo "$out" | sed 's/^/     /'; fails=$((fails + 1)); return
  fi
  echo "✅ $label: gate failed and named $id"
}

# ── GREEN — declarations and disk agree ──────────────────────────────────────
seed
if out=$(run_gate); then echo "✅ green: gate passes on a consistent tree"; else
  echo "❌ green: gate failed on a consistent tree"; echo "$out" | sed 's/^/     /'; fails=$((fails + 1)); fi

# ── RED-1 (SP-1) — a package on disk nobody declared ─────────────────────────
# The real defect: remove-demo.sh cannot see it, so it survives --clean by accident.
seed
mkdir -p "$SANDBOX/repo/core/store/src/commonMain/kotlin/kpt/core/store/undeclared"
expect_red "red-1 undeclared package on disk" "SP-1"

# ── RED-2 (SP-2) — a declaration pointing at nothing ─────────────────────────
seed
rm -rf "$SANDBOX/repo/core/store/src/commonMain/kotlin/kpt/core/store/alerts"
expect_red "red-2 declared package missing from disk" "SP-2"

# ── RED-3 (SP-3) — the path convention creeping back ─────────────────────────
seed
mkdir -p "$SANDBOX/repo/core/store/src/commonMain/kotlin/kpt/core/store/demo/legacy"
expect_red "red-3 demo/ directory reappears" "SP-3"

[ "$fails" -eq 0 ] && { echo "✅ store-package-ownership-canary: all legs pass"; exit 0; }
echo "❌ store-package-ownership-canary: $fails leg(s) failed"; exit 1
