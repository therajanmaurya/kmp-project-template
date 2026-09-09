#!/usr/bin/env bash
# checks/shell-portability.sh — tracked shell scripts must run on the RUNNERS, not just on a Mac.
#
# The trap this guards (hit 2026-09-09): scripts/remove-demo.sh used `sed -i ''`, which is BSD/macOS
# syntax. GNU sed reads that '' as the SCRIPT argument and exits non-zero, so the ENTIRE demo strip
# died on every Linux runner. Two product-health checks failed as a result — demo-strip-coherence
# ("a cleaned fork cannot even be produced") and demo-strip-codegen-canary — and neither pointed at
# the real cause, because the check swallows the strip's output.
#
# It survived for as long as the script existed: the quality-gate job short-circuited before
# product-health ever ran, so nothing on Linux had executed it. A macOS developer cannot reproduce
# it, and CI could not report it. That combination is exactly what a static gate is for.
#
#   SP-1  no `sed -i ''` / `sed -i ""` — BSD-only. Use `sed -i.bak … && rm -f <file>.bak`, which
#         both seds accept. (`sed -i` with NO suffix is the inverse trap: GNU-only, BSD reads the
#         next argument as the suffix — so it is rejected too.)
#   SP-2  no bare `readlink -f` / `stat -f` / `md5` without a GNU fallback on the same line.
#         These are the other three BSD/GNU splits this repo's scripts actually reach for.
#
# Scope: TRACKED *.sh only (git ls-files), comment lines stripped (a commented-out form never
# runs). Two exclusions: product-health/tests/** (canary fixtures deliberately contain the
# broken forms so the RED leg has something to detect) and THIS file, which cannot describe
# the trap without spelling it in both its header and the error text it prints.
#
# exit 0 = PASS · 1 = FAIL (blocks).
set -uo pipefail
# shellcheck source=scripts/product-health/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
: "${HEALTH_ROOT:?shell-portability: HEALTH_ROOT not set (run via product-health.sh)}"
cd "$HEALTH_ROOT" || exit 2

fail=0

scripts="$(git ls-files -- '*.sh' 2>/dev/null \
             | grep -v '^scripts/product-health/tests/' \
             | grep -v '^scripts/product-health/checks/shell-portability.sh$' || true)"

# Comment-stripped view of a file: a commented-out `sed -i ''` never runs, so matching it would
# report prose as a defect. Blank the comment lines rather than deleting them, so grep -n still
# reports the true line number of a real hit.
uncommented() { sed 's/^[[:space:]]*#.*$//' "$1"; }
[ -z "$scripts" ] && { echo "no tracked shell scripts (ok)"; exit 0; }

# ── SP-1 — the in-place-edit split ─────────────────────────────────────────────────────────────
# BSD requires a suffix argument; GNU treats a separate '' as the script. `-i.bak` is the only
# spelling both accept, so it is the one this repo uses.
bsd_inplace="$(printf '%s\n' "$scripts" | while IFS= read -r f; do
  uncommented "$f" | grep -nE "sed[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-i[[:space:]]+(''|\"\")" 2>/dev/null \
    | sed "s|^|${f}:|"
done)"
if [ -n "$bsd_inplace" ]; then
  echo "${C_RED}✗ SP-1${C_RST}: BSD-only \`sed -i ''\` — GNU sed reads the '' as its script and exits 1,"
  echo "       so this line silently kills the whole script on every Linux runner:"
  printf '%s\n' "$bsd_inplace" | sed 's/^/       /'
  echo "       Use:  sed -i.bak … \"\$f\"  &&  rm -f \"\$f.bak\""
  fail=1
fi

gnu_inplace="$(printf '%s\n' "$scripts" | while IFS= read -r f; do
  uncommented "$f" | grep -nE "sed[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-i[[:space:]]+[\"']?(s|/|-e|-E)" 2>/dev/null \
    | sed "s|^|${f}:|"
done)"
if [ -n "$gnu_inplace" ]; then
  echo "${C_RED}✗ SP-1${C_RST}: GNU-only \`sed -i\` with no suffix — BSD sed consumes the NEXT argument"
  echo "       as the backup suffix and edits the wrong thing:"
  printf '%s\n' "$gnu_inplace" | sed 's/^/       /'
  echo "       Use:  sed -i.bak … \"\$f\"  &&  rm -f \"\$f.bak\""
  fail=1
fi

# ── SP-2 — the other BSD/GNU splits, allowed only WITH a fallback on the same line ─────────────
for probe in 'readlink -f' 'stat -f ' 'md5 '; do
  hits="$(printf '%s\n' "$scripts" | while IFS= read -r f; do
    uncommented "$f" | grep -nF -- "$probe" 2>/dev/null | grep -vE '\|\||2>/dev/null' | sed "s|^|${f}:|"
  done)"
  if [ -n "$hits" ]; then
    echo "${C_RED}✗ SP-2${C_RST}: \`${probe}\` has no GNU fallback on the line (BSD/GNU split):"
    printf '%s\n' "$hits" | sed 's/^/       /'
    echo "       Give it one, e.g.  stat -f \"%A\" \"\$f\" 2>/dev/null || stat -c \"%a\" \"\$f\""
    fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "shell portable ($(printf '%s\n' "$scripts" | wc -l | tr -d ' ') tracked scripts; runs on macOS + Linux runners)"
exit "$fail"
