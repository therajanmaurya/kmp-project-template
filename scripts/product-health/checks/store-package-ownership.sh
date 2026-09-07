#!/usr/bin/env bash
# store-package-ownership.sh — every core/store domain package declares its ownership.
#
# WHY THIS EXISTS
# core/store's demo boundary used to be the `**/demo/**` PATH convention: `remove-demo.sh` deleted a
# package because of where it sat. That was unambiguous in practice but it was not a declaration, so
# two things could go wrong silently — a fork's own store authored under `demo/` was deleted on
# `--clean`, and a template showcase authored OUTSIDE `demo/` survived it. Neither is detectable by
# reading the code; both are detectable by comparing disk against a declaration.
#
# The packages now sit at `kpt/core/store/<id>/` and declare `owner:` in
# `app-profile/app.yaml#core_store.packages[]`, matching what `network.access_points` and
# `database.packages` already do.
#
# CONTRACT
#   SP-1 every package directory under kpt/core/store/ is declared in core_store.packages[]
#   SP-2 every declared package exists on disk in at least one source set
#   SP-3 no `demo/` package directory remains under core/store (the convention this replaced)
#
# NOT CHECKED HERE: whether a package's `owner:` value is CORRECT. That is a judgement about intent,
# not a mechanical property — AC-1..AC-4 (archetype coverage) is what stops a showcase disappearing.
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 2

APP_YAML="app-profile/app.yaml"
STORE_ROOT="core/store/src"
PKG_REL="kotlin/kpt/core/store"
fails=0
note() { printf '  %s\n' "$*"; }

[ -f "$APP_YAML" ] || { echo "store-package-ownership: $APP_YAML missing"; exit 2; }

# Declared ids (core_store.packages[] only — stop at the next top-level key).
declared=$(awk '
  /^core_store:[[:space:]]*$/ { inmod=1; next }
  /^[a-z_]+:[[:space:]]*$/    { inmod=0 }
  inmod && /^[[:space:]]*packages:[[:space:]]*$/ { inpkg=1; next }
  inmod && inpkg && /^[[:space:]]*-[[:space:]]*\{/ {
    id=$0; sub(/.*id:[[:space:]]*/,"",id); sub(/[,}[:space:]].*$/,"",id); print id; next
  }
  inmod && inpkg && /^[[:space:]]*[a-z_]+:/ { inpkg=0 }
' "$APP_YAML" | sort -u)

# Directories actually on disk. `di` and `infra` are aggregator/infra dirs, not domain packages.
ondisk=$(for ss in "$STORE_ROOT"/*/"$PKG_REL"; do
  [ -d "$ss" ] || continue
  for d in "$ss"/*/; do
    [ -d "$d" ] || continue
    b=$(basename "$d")
    # `di` (Koin modules), `config` (generated registry + cache keys) and `infra` are the module's
    # own structure, not domain packages a fork declares or the strip deletes.
    case "$b" in di|config|infra) continue ;; esac
    echo "$b"
  done
done | sort -u)

echo "store-package-ownership: declared=$(echo "$declared" | grep -c .) on-disk=$(echo "$ondisk" | grep -c .)"

# SP-1 — every on-disk package is declared
for d in $ondisk; do
  if ! echo "$declared" | grep -qx "$d"; then
    note "❌ SP-1 core/store package '$d' exists on disk but is NOT declared in $APP_YAML#core_store.packages[]"
    note "     a package nobody declared is invisible to remove-demo.sh — it survives --clean by accident"
    fails=$((fails + 1))
  fi
done

# SP-2 — every declared package exists
for d in $declared; do
  if ! echo "$ondisk" | grep -qx "$d"; then
    note "❌ SP-2 declared core/store package '$d' has no directory under $STORE_ROOT/*/$PKG_REL/"
    fails=$((fails + 1))
  fi
done

# SP-3 — the path convention this replaced must be gone
if find "$STORE_ROOT" -type d -name demo 2>/dev/null | grep -q .; then
  note "❌ SP-3 a demo/ directory still exists under core/store — ownership is declared now, not path-inferred"
  find "$STORE_ROOT" -type d -name demo | sed 's/^/       /'
  fails=$((fails + 1))
fi

if [ "$fails" -eq 0 ]; then
  echo "✅ store-package-ownership: SP-1..SP-3 pass"
  exit 0
fi
echo "❌ store-package-ownership: $fails failure(s)"
exit 1
