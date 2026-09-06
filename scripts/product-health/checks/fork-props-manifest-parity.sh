#!/usr/bin/env bash
# checks/fork-props-manifest-parity.sh — the TWO writers of gradle/fork.properties must agree on
# which keys they derive, and on where each one comes from in app-profile.
#
# gradle/fork.properties has two writers, by design:
#   scripts/white-label/derive.rb          via AppProfile::MAP        (deployment/_shared/config.rb)
#   syncForkConfig §5b                     via APP_PROFILE_MAP        (SyncForkConfigPlugin.kt)
#
# derive.rb is pure Ruby and is what CI + doctor's fast lane run (no JDK, no Gradle); syncForkConfig
# runs in a real Gradle build. If their manifests diverge, the SAME repo produces a DIFFERENT bridge
# depending on which path materialised it — and every consumer silently falls back for whatever the
# running writer omitted.
#
# That is not hypothetical. On 2026-09-06 the Ruby manifest was missing five keys the Kotlin one had
# (network.base.url.{demo,prod} / demo.username / demo.password / log.tag), so a derive.rb-only
# bridge carried 71 keys where syncForkConfig produced 86. app.yaml documents that exact block as
# flowing to fork.properties → per-flavor BuildConfig, so a CI-derived bridge silently built with the
# plugin's hardcoded template defaults for the API base URLs and demo credentials. Nothing detected
# it, because each writer was internally consistent.
#
# FAILS on: a key in one manifest and not the other · a key both map to DIFFERENT app-profile paths.
# exit 0 PASS / 1 FAIL.
set -uo pipefail
: "${HEALTH_ROOT:?fork-props-manifest-parity: HEALTH_ROOT not set (run via product-health.sh)}"

KT="${FORK_PARITY_KT:-$HEALTH_ROOT/build-logic/convention/src/main/kotlin/SyncForkConfigPlugin.kt}"
RB="${FORK_PARITY_RB:-$HEALTH_ROOT/deployment/_shared/config.rb}"

# Both absent → nothing to compare (a fork that stripped the white-label machinery). PASS.
if [ ! -f "$KT" ] && [ ! -f "$RB" ]; then
  echo "neither manifest present — nothing to compare (ok)"; exit 0
fi
# Exactly one present is itself a divergence: one writer could derive keys the other cannot.
if [ ! -f "$KT" ] || [ ! -f "$RB" ]; then
  echo "❌ only ONE manifest present — the two writers cannot agree"
  [ -f "$KT" ] || echo "     missing: $KT"
  [ -f "$RB" ] || echo "     missing: $RB"
  exit 1
fi

command -v ruby >/dev/null 2>&1 || { echo "ruby not available — cannot compare manifests"; exit 1; }

ruby - "$KT" "$RB" <<'RUBY'
kt_path, rb_path = ARGV
kt_src = File.read(kt_path)
rb_src = File.read(rb_path)

kt = kt_src[/APP_PROFILE_MAP: Map<String, String> = mapOf\((.*?)^\s*\)/m, 1].to_s
       .scan(/"([a-z][\w.]*)"\s+to\s+"([^"]+)"/).to_h
rb = rb_src[/MAP\s*=\s*\{(.*?)\n  \}/m, 1].to_s
       .scan(/^\s*"([^"]+)"\s*=>\s*"([^"]+)"/).to_h

# An empty extraction means the declaration was reshaped and this check silently stopped checking —
# the classic way a gate rots into decoration. Treat it as a failure, not a pass.
if kt.empty? || rb.empty?
  puts "❌ manifest extraction returned nothing (kotlin=#{kt.size}, ruby=#{rb.size})"
  puts "     the declaration shape changed — update this check's regex rather than letting it pass vacuously"
  exit 1
end

kt_only = (kt.keys - rb.keys).sort
rb_only = (rb.keys - kt.keys).sort
differ  = (kt.keys & rb.keys).reject { |k| kt[k] == rb[k] }.sort
fail = false

unless kt_only.empty?
  fail = true
  puts "❌ #{kt_only.size} key(s) only syncForkConfig can derive — a derive.rb bridge (CI, doctor fast lane) omits them:"
  kt_only.each { |k| puts "     #{k.ljust(32)} → #{kt[k]}" }
  puts "     → Fix: add them to AppProfile::MAP in deployment/_shared/config.rb (paths above)."
end
unless rb_only.empty?
  fail = true
  puts "❌ #{rb_only.size} key(s) only derive.rb can derive — syncForkConfig will not refresh them:"
  rb_only.each { |k| puts "     #{k.ljust(32)} → #{rb[k]}" }
  puts "     → Fix: add them to APP_PROFILE_MAP in SyncForkConfigPlugin.kt (paths above)."
end
unless differ.empty?
  fail = true
  puts "❌ #{differ.size} key(s) mapped to DIFFERENT app-profile paths — the writers disagree on the SoT:"
  differ.each { |k| puts "     #{k.ljust(28)} kotlin=#{kt[k]}  ruby=#{rb[k]}" }
end

if fail
  exit 1
end
puts "manifest parity: #{kt.size} keys, identical paths in APP_PROFILE_MAP + AppProfile::MAP"
RUBY
