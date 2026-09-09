#!/usr/bin/env bash
# scripts/product-health/product-health.sh — product health / sanity harness.
#
# Reads gradle/fork.properties (the project-level SINGLE SOURCE OF TRUTH) and runs every
# scripts/product-health/checks/*.sh against it. This is the ONE place a fork learns whether its
# customization is complete + correct: signing/org identity re-forked, appId consolidated, store
# listing authored. Runs in CI (quality-gate.yml) and at the end of scripts/white-label/customize.sh so a fresh fork
# gets an immediate sanity report. Pure bash — no Gradle, no network.
#
# Check contract (each checks/*.sh): exit 0 = PASS · exit 1 = FAIL (blocks) · exit 2 = WARN
# (needs attention, non-blocking). Fork-only checks self-skip when TEMPLATE_SELF_BUILD=1.
#
# product-health exit: 0 when no check FAILs (WARNs allowed) · 1 when any check FAILs.
set -uo pipefail

HEALTH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # …/scripts/product-health
HEALTH_ROOT="$(cd "$HEALTH_DIR/../.." && pwd)"               # repo root
# shellcheck source=scripts/product-health/lib.sh
source "$HEALTH_DIR/lib.sh"

FORK_PROPERTIES="$(health_resolve_sot "$HEALTH_ROOT")" || {
  echo "${C_RED}❌ project-health: no gradle/fork.properties(.template) found — is this a fork of kmp-project-template?${C_RST}" >&2
  exit 1
}
export FORK_PROPERTIES HEALTH_ROOT

# ── Header — name the project from its SoT ───────────────────────────────────
org="$(fp_get org.name)"; [ -n "$org" ] || org="(unset)"
app_id="$(fp_get app.id)"
[ -n "$app_id" ] || app_id="$(grep -E '^\s*appId\s*=' "$HEALTH_ROOT/gradle/libs.versions.toml" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//; s/[[:space:]]*#.*$//; s/"//g; s/[[:space:]]*$//')"
[ -n "$app_id" ] || app_id="?"
echo "── ${C_BLD}Product Health${C_RST} · ${org} ${C_DIM}(${app_id})${C_RST} ──"
echo "   ${C_DIM}SoT: ${FORK_PROPERTIES#$HEALTH_ROOT/}${C_RST}"
[ "${TEMPLATE_SELF_BUILD:-}" = "1" ] && echo "   ${C_DIM}TEMPLATE_SELF_BUILD=1 — fork-only checks skip (this IS the upstream template)${C_RST}"
echo ""

# ── Run every check ──────────────────────────────────────────────────────────
fail=0; warn=0; pass=0
for chk in "$HEALTH_DIR"/checks/*.sh; do
  [ -f "$chk" ] || continue
  name="$(basename "$chk" .sh)"
  out="$(bash "$chk" 2>&1)"; rc=$?
  case "$rc" in
    0) pass=$((pass+1)); printf '  %s✅ PASS%s  %s\n' "$C_GRN" "$C_RST" "$name" ;;
    2) warn=$((warn+1)); printf '  %s⚠️  WARN%s  %s\n' "$C_YEL" "$C_RST" "$name" ;;
    *) fail=$((fail+1)); printf '  %s❌ FAIL%s  %s\n' "$C_RED" "$C_RST" "$name" ;;
  esac
  # Show the check's own lines (indented) whenever it wasn't a clean pass.
  [ "$rc" -ne 0 ] && [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/         /'
done

echo ""
echo "── ${pass} passed · ${warn} warn · ${fail} failed ──"
[ "$warn" -gt 0 ] && [ "$fail" = 0 ] && echo "   ${C_DIM}(warnings don't block — but resolve them before releasing)${C_RST}"

# ── Local-run hint: fork mode is the SAFE DEFAULT, so say why, don't infer around it ─────────
#
# Mode comes only from TEMPLATE_SELF_BUILD, which quality-gate.yml sets from `github.repository`
# ('1' upstream, '' on every fork). A LOCAL clone has no such signal, so it runs in fork mode —
# and in the template checkout the three directional identity checks (fork-identity /
# deployment-whitelabel B1/B8 / secrets-alias-namespace) then FAIL by design: they are reading the
# committed Mifos reference identity as "a fork that has not rebranded yet".
#
# That default is deliberate and stays. Auto-detecting template mode from git remotes would give a
# real white-label fork — which commonly also has `upstream` pointing at openMF — a silent local
# pass on the very checks that exist to tell it to rebrand. A missing hint is an annoyance; a
# false PASS is the failure this suite exists to prevent. So: explain the red, never remove it.
if [ "${TEMPLATE_SELF_BUILD:-}" != "1" ] && [ "$fail" -gt 0 ] && wl_identity_is_reference "$app_id" "$org"; then
  echo ""
  echo "   ${C_DIM}Note: identity still matches the committed Mifos reference${C_RST}"
  echo "   ${C_DIM}(${app_id} / ${org}), so the directional identity checks read this as an${C_RST}"
  echo "   ${C_DIM}un-rebranded FORK. If this checkout IS the upstream template, re-run:${C_RST}"
  echo "   ${C_DIM}  TEMPLATE_SELF_BUILD=1 bash scripts/product-health/product-health.sh${C_RST}"
  echo "   ${C_DIM}If it is a fork, this is the real finding — rebrand in app-profile/.${C_RST}"
fi

[ "$fail" -gt 0 ] && exit 1
exit 0
