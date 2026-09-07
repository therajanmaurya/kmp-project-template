#!/usr/bin/env bash
# store-fork-seam-wiring.sh — the template actually CONSULTS its fork seams.
#
# WHY THIS EXISTS
# `ProjectErrorMapper` and `ProjectScreenStateDefaults` are the only places a fork customizes error
# copy and screen-state visuals without editing a template-owned file. That contract holds only if
# the template files call them. Delete `projectCopy(error) ?:` or `.applyProjectOverrides()` and
# NOTHING fails: the template's own behaviour is unchanged, every unit test still passes, and the
# loss surfaces only in a fork whose branding silently stops applying.
#
# Both call sites sit inside `@Composable` functions and `core/store` does not carry the Compose
# ui-test dependency, so a unit test cannot reach them. `ForkSeamTest` covers the seams' DEFAULTS
# (null / identity); this covers the WIRING.
#
# CONTRACT
#   FS-1 config/AppErrorMapper consults projectErrorMessage BEFORE its own categorised branches
#   FS-2 config/AppScreenStateDefaults applies applyProjectOverrides to what it returns
#   FS-3 the seams are NEUTRAL on the template (null / this) — a template that customized itself
#        would make every fork inherit its choices
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 2
B="core/store/src/commonMain/kotlin/kpt/core/store"
fails=0

need() { # need <file> <regex> <id> <why>
  if [ ! -f "$1" ]; then echo "  ❌ $3 missing file: $1"; fails=$((fails + 1)); return; fi
  if ! grep -qE "$2" "$1"; then
    echo "  ❌ $3 $4"
    echo "       expected /$2/ in ${1#./}"
    fails=$((fails + 1))
  fi
}

# FS-1 — the ?: ordering is the contract: fork first, framework as fallback.
need "$B/config/AppErrorMapper.kt" 'projectCopy\(error\)[[:space:]]*\?:' "FS-1" \
  "AppErrorMapper no longer consults the fork seam — a fork's error copy would never appear"
need "$B/config/AppErrorMapper.kt" 'projectErrorMessage' "FS-1" \
  "AppErrorMapper does not reference projectErrorMessage at all"

# FS-2 — applied to the RETURNED value, not computed and discarded.
need "$B/config/AppScreenStateDefaults.kt" '\)\.applyProjectOverrides\(\)' "FS-2" \
  "AppScreenStateDefaults no longer applies the fork overrides — a fork's branding would be dropped"

# FS-3 — template neutrality.
need "$B/ProjectErrorMapper.kt" 'fun projectErrorMessage\(error: Throwable\): String\? = null' "FS-3" \
  "the template's projectErrorMessage is not neutral — it would shadow the framework's categorised copy"
need "$B/ProjectScreenStateDefaults.kt" 'fun ScreenStateDefaults\.applyProjectOverrides\(\): ScreenStateDefaults = this' "FS-3" \
  "the template's applyProjectOverrides is not identity — every fork would inherit the template's own overrides"

[ "$fails" -eq 0 ] && { echo "✅ store-fork-seam-wiring: FS-1..FS-3 pass"; exit 0; }
echo "❌ store-fork-seam-wiring: $fails failure(s)"; exit 1
