#!/usr/bin/env bash
# cache-key-uniqueness.sh — no two declared cache keys resolve to the same string.
#
# WHY THIS EXISTS
# A cacheKey is what per-stream freshness tracking is keyed on. Two streams sharing a key share a
# fetched-at timestamp, so one screen's refresh silently marks the other fresh and the second screen
# stops refetching — a staleness bug with no error, no crash, and no obvious cause.
#
# The keys used to live in one `AppCacheKeys` object, whose KDoc claimed they "cannot drift or
# silently collide". That was never true: two members with DIFFERENT names and the SAME string value
# compile perfectly. A single object prevents duplicate member NAMES, which Kotlin would have caught
# anyway; it never checked the values. Splitting the keys per store did not introduce this risk — it
# made an unchecked property visible, so it is checked here for the first time.
#
# CONTRACT
#   CK-1 no two rows across all stores declare the same literal `key:`
#   CK-2 a key's placeholders match its declared params (a typo'd {id} would generate uncompilable
#        code, but the message is far clearer here than a Kotlin error in generated output)
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 2
APP_YAML="app-profile/app.yaml"
[ -f "$APP_YAML" ] || { echo "cache-key-uniqueness: $APP_YAML missing"; exit 2; }
fails=0

# `key:` lines nested under a store's cache_keys — awk over the block, no YAML parser (RULE-CI-001
# forbids python/jq on idea-layer; app-profile is source, but staying awk-only keeps it uniform).
keys=$(awk '
  /^core_store:[[:space:]]*$/ { inmod=1; next }
  /^[a-z_]+:[[:space:]]*$/    { inmod=0 }
  inmod && /cache_keys:/      { inck=1; next }
  inmod && inck && /^[[:space:]]*-[[:space:]]*\{/ {
    line=$0
    if (match(line, /key:[[:space:]]*"[^"]*"/)) {
      k=substr(line, RSTART, RLENGTH); sub(/key:[[:space:]]*"/,"",k); sub(/"$/,"",k); print k
    }
    next
  }
  inmod && inck && /^[[:space:]]*[a-z_]+:/ { inck=0 }
' "$APP_YAML")

total=$(printf '%s\n' "$keys" | grep -c .)
dupes=$(printf '%s\n' "$keys" | sort | uniq -d)

echo "cache-key-uniqueness: $total declared key(s)"
if [ -n "$dupes" ]; then
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    echo "  ❌ CK-1 cache key '$d' is declared more than once"
    echo "       two streams sharing a key share a fetched-at stamp — one refresh marks the other"
    echo "       fresh, and the second screen silently stops refetching"
    fails=$((fails + 1))
  done <<< "$dupes"
fi

# CK-2 — every {placeholder} has a matching declared param name on the same row
while IFS= read -r line; do
  case "$line" in *cache_keys*|"") continue ;; esac
  ph=$(printf '%s' "$line" | grep -oE '\{[a-zA-Z0-9_]+\}' | tr -d '{}' | sort -u)
  [ -z "$ph" ] && continue
  for name in $ph; do
    if ! printf '%s' "$line" | grep -q "name: $name"; then
      echo "  ❌ CK-2 key placeholder {$name} has no matching param on its row:"
      echo "       $(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
      fails=$((fails + 1))
    fi
  done
done < <(grep -E '^[[:space:]]*-[[:space:]]*\{[[:space:]]*(fn|name):' "$APP_YAML")

[ "$fails" -eq 0 ] && { echo "✅ cache-key-uniqueness: CK-1..CK-2 pass"; exit 0; }
echo "❌ cache-key-uniqueness: $fails failure(s)"; exit 1
