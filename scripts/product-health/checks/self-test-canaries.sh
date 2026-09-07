#!/usr/bin/env bash
# checks/self-test-canaries.sh — runs every product-health canary (tests/*/run.sh) so the RED/GREEN
# fixtures are LOAD-BEARING in CI, not decorative. Discovered + executed by product-health.sh (which
# runs every checks/*.sh), which quality-gate.yml already invokes. Each canary is self-contained
# (own GREEN/RED fixtures) and deterministic — runs in both fork and TEMPLATE_SELF_BUILD context.
#
#   exit 0 = every canary PASS · exit 1 = one or more canaries FAIL (blocks).
#
# Locks (among others): flip-precondition-canary (guard↔YAML ownership drift, incl. og-images=generated)
# and sync-dirs-template-remote-canary (URL-match template resolution + ungated dry-run remote-add).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"        # …/checks
TESTS_DIR="$(cd "$HERE/.." && pwd)/tests"                    # …/product-health/tests

shopt -s nullglob
canaries=("$TESTS_DIR"/*/run.sh)
[ "${#canaries[@]}" -eq 0 ] && { echo "self-test-canaries: no canaries found (skip)"; exit 0; }

# ── CI-1: a canary with a RED leg must assert WHICH check failed, not just a non-zero exit ──────
#
# This is the load-bearing rule, not a style preference. A gate that breaks VACUOUSLY — its scan
# yields zero items, so it reports success having examined nothing — still makes a RED fixture exit
# non-zero, because RED fixtures typically violate several rules at once. An exit-code-only canary
# therefore stays green while the rule it exists to prove has stopped running entirely.
#
# That is not hypothetical. G-WHITE-LABEL-SEPARATION's demo-import check was disabled for a while by
# an `unbound variable` in the pipeline feeding its loop (set -u killed the process substitution, the
# loop read nothing, the check passed on everything). Its canary stayed green throughout: the RED
# fixture still failed on four OTHER checks. Two blind spots covering for each other.
#
# A canary that greps the output for its own identifier cannot be fooled that way — a vacuous gate
# emits no such line. So: any canary with a red* fixture, or that says "expect FAIL", must inspect
# output, not just $?.
ci1_fail=0
for run in "${canaries[@]}"; do
  name="$(basename "$(dirname "$run")")"
  has_red=0
  compgen -G "$(dirname "$run")/red*" >/dev/null 2>&1 && has_red=1
  # Detection must be broad: canaries express "this leg must fail" in several shapes — a red* fixture,
  # "expect FAIL", `expect_fail_on`, or a `cell <fixture> 1 "..."` row. Missing one is a false
  # negative in the very rule meant to catch false negatives, which is how this check first passed
  # over network-access-points-canary (its legs say "→ FAIL", not "expect FAIL").
  grep -qiE 'expect (FAIL|a failure)|expect_fail|FAIL"|[[:space:]]1[[:space:]]+"' "$run" 2>/dev/null && has_red=1
  [ "$has_red" = "1" ] || continue
  # "inspects output" = pipes/greps the check's stdout somewhere, rather than only testing $? / if <cmd>
  if grep -qE 'grep -q|grep -oE|grep -c|\| *grep' "$run" 2>/dev/null; then continue; fi
  echo "  ❌ CI-1 $name has a RED leg but asserts only the exit code"
  echo "       → a vacuously-passing gate still makes RED exit non-zero; assert the specific check id"
  ci1_fail=1
done
[ "$ci1_fail" = "0" ] && echo "  ✓ CI-1 every RED leg asserts a specific check (${#canaries[@]} canaries)"

fail=$ci1_fail
for run in "${canaries[@]}"; do
  name="$(basename "$(dirname "$run")")"
  out="$(bash "$run" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "  ✅ $name"
  else
    echo "  ❌ $name (exit $rc)"
    printf '%s\n' "$out" | sed 's/^/       /'
    fail=1
  fi
done
exit "$fail"
