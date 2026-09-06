#!/usr/bin/env bash
# checks/network-access-points.sh — app-profile is the ONLY place a network endpoint is declared,
# and every derived surface is a faithful projection of it.
#
# `app-profile/app.yaml#network.access_points` is the SoT. `./gradlew syncForkConfig` projects it onto
# four committed Kotlin surfaces:
#
#   AppAccessPoints.kt        the registry list          (NAP-1 ids · NAP-2 fields)
#   AppUrlTypes.kt            the UrlType vocabulary     (NAP-3)
#   GeneratedApiBindings.kt   the Koin bindings          (NAP-4)
#   AppSupabaseAnonKeys.kt    the per-point anon keys    (NAP-5 rows · NAP-6 no committed key)
#
# WHY a gate and not just codegen: the generated files are COMMITTED (the build must work on a fresh
# clone with no Gradle run), so nothing forces them to still match app.yaml. Whoever edits app.yaml
# and forgets `syncForkConfig` gets a repo that compiles and is wrong. That is not hypothetical —
# AppUrlTypes was hand-kept and had drifted to 3 constants against 8 declared points, and the drift
# was SILENT AND WRONG-ANSWERING: AppMultiUrlConfigProvider.getBaseUrl falls back to UrlType.MAIN for
# an unrecognised type, so a lookup for an undeclared endpoint returned the MAIN base URL rather than
# failing. NAP-3 is that bug's gate.
#
# NAP-7 closes the loop: wiring must go THROUGH the generated file. A hand-added restApi(...) line
# re-creates the drift the codegen removes (a binding with no declared endpoint, or an endpoint whose
# binding nobody regenerates), so it is refused even though it compiles.
#
# exit 0 PASS / 1 FAIL. Ruby (like fork-props-manifest-parity.sh) — YAML + Kotlin in one pass.
set -uo pipefail
: "${HEALTH_ROOT:?network-access-points: HEALTH_ROOT not set (run via product-health.sh)}"

YAML="${NAP_YAML:-$HEALTH_ROOT/app-profile/app.yaml}"
NET="${NAP_NET_DIR:-$HEALTH_ROOT/core/network/src/commonMain/kotlin/kpt/core/network}"

# A fork that stripped the white-label machinery has nothing to compare. PASS.
[ -f "$YAML" ] || { echo "no app-profile/app.yaml — nothing to compare (ok)"; exit 0; }
command -v ruby >/dev/null 2>&1 || { echo "ruby not available — cannot audit access points"; exit 1; }

ruby - "$YAML" "$NET" <<'RUBY'
require 'yaml'
yaml_path, net_dir = ARGV
profile = begin
  YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(File.read(yaml_path)) : YAML.load(File.read(yaml_path))
rescue StandardError
  nil
end
unless profile.is_a?(Hash)
  puts "❌ could not parse #{yaml_path} as YAML"; exit 1
end
points = profile.dig("network", "access_points")
if points.nil?
  puts "no network.access_points declared — nothing to project (ok)"; exit 0
end
unless points.is_a?(Array)
  puts "❌ network.access_points is not a list"; exit 1
end
points = points.select { |p| p.is_a?(Hash) && p["id"].to_s.strip != "" }

def read(path)
  File.exist?(path) ? File.read(path) : nil
end

ap_src    = read(File.join(net_dir, "config/AppAccessPoints.kt"))
ut_src    = read(File.join(net_dir, "config/AppUrlTypes.kt"))
keys_src  = read(File.join(net_dir, "config/AppSupabaseAnonKeys.kt"))
bind_src  = read(File.join(net_dir, "demo/di/GeneratedApiBindings.kt"))

fail = false
def bad(msg)
  puts(msg)
  true
end

# ── NAP-1 / NAP-2 — the registry list ────────────────────────────────────────
if ap_src.nil?
  fail = bad("❌ NAP-1 AppAccessPoints.kt missing — the registry has no source")
else
  # Parse the generated AccessPoint(...) entries: id + kind + baseUrl + loggableHost (+ proxiedHost).
  entries = ap_src.scan(/AccessPoint\(\s*(.*?)\n\s*\),/m).map do |body,|
    b = body
    {
      "id"    => b[/id\s*=\s*"([^"]*)"/, 1],
      "kind"  => b[/kind\s*=\s*AccessPointKind\.(\w+)/, 1],
      "base"  => b[/baseUrl\s*=\s*"([^"]*)"/, 1],
      "host"  => b[/loggableHost\s*=\s*"([^"]*)"/, 1],
      "proxy" => b[/proxiedHost\s*=\s*"([^"]*)"/, 1],
    }
  end
  declared = points.map { |p| p["id"].to_s }
  generated = entries.map { |e| e["id"] }.compact
  missing = declared - generated
  extra   = generated - declared
  fail = bad("❌ NAP-1 declared in app.yaml but NOT in AppAccessPoints: #{missing.join(', ')}\n     → run `./gradlew syncForkConfig`") if missing.any?
  fail = bad("❌ NAP-1 in AppAccessPoints but NOT declared in app.yaml: #{extra.join(', ')}\n     → remove them there, or declare them in app-profile (the SoT)") if extra.any?

  points.each do |p|
    e = entries.find { |x| x["id"] == p["id"].to_s } or next
    want_kind = p["type"].to_s.strip.downcase == "supabase" ? "SUPABASE" : "REST"
    diffs = []
    diffs << "kind #{e['kind']} != #{want_kind}"                                if e["kind"] != want_kind
    diffs << "baseUrl #{e['base'].inspect} != #{p['base_url'].to_s.inspect}"    if e["base"] != p["base_url"].to_s
    diffs << "loggableHost #{e['host'].inspect} != #{p['loggable_host'].to_s.inspect}" if e["host"] != p["loggable_host"].to_s
    want_proxy = p["proxied_host"].to_s.strip
    have_proxy = e["proxy"].to_s
    diffs << "proxiedHost #{have_proxy.inspect} != #{want_proxy.inspect}"       if have_proxy != want_proxy
    fail = bad("❌ NAP-2 '#{p['id']}' stale in AppAccessPoints: #{diffs.join('; ')}\n     → run `./gradlew syncForkConfig`") if diffs.any?
  end
end

# ── NAP-3 — the UrlType vocabulary ───────────────────────────────────────────
# AccessPoint.type defaults to UrlType(id.uppercase()), so the vocabulary is a pure projection of the
# id list. A missing constant does not fail to compile — it fails at runtime by returning MAIN's URL.
if ut_src.nil?
  fail = bad("❌ NAP-3 AppUrlTypes.kt missing")
else
  want = points.map { |p| p["id"].to_s.upcase.gsub(/[^A-Z0-9]/, "_") }
  # name => UrlType KEY. `UrlType.MAIN` is UrlType("MAIN"); everything else declares its key inline.
  decls = {}
  ut_src.scan(/^\s*val\s+([A-Z][A-Z0-9_]*)\s*:\s*UrlType\s*=\s*(UrlType\.MAIN|UrlType\("([^"]*)"\))/).each do |name, whole, key|
    decls[name] = whole == "UrlType.MAIN" ? "MAIN" : key
  end
  have = decls.keys
  missing = want - have
  extra   = have - want
  fail = bad("❌ NAP-3 access points with no AppUrlTypes constant: #{missing.join(', ')}\n     → run `./gradlew syncForkConfig` (getBaseUrl would silently fall back to MAIN)") if missing.any?
  fail = bad("❌ NAP-3 AppUrlTypes constants with no access point: #{extra.join(', ')}") if extra.any?

  # The constant's KEY must equal id.upcase() exactly — that is AccessPoint.type's default, and UrlType
  # equality is what restBaseUrl matches on. A constant whose NAME was sanitized but whose KEY was too
  # (e.g. id `pay-gw` declaring UrlType("PAY_GW")) compiles, resolves nothing, and falls back to MAIN's
  # URL. Checking existence alone would not catch it; checking the key does.
  points.each do |p|
    id   = p["id"].to_s
    name = id.upcase.gsub(/[^A-Z0-9]/, "_")
    key  = decls[name] or next
    next if key == id.upcase
    fail = bad("❌ NAP-3 '#{id}' declares UrlType(#{key.inspect}) but its access point carries UrlType(#{id.upcase.inspect})\n     → the keys must match exactly, or restBaseUrl misses and getBaseUrl returns MAIN's URL")
  end
  all_list = ut_src[/val\s+all\s*:\s*List<UrlType>\s*=\s*listOf\(([^)]*)\)/m, 1].to_s
  listed = all_list.split(",").map(&:strip).reject(&:empty?)
  fail = bad("❌ NAP-3 AppUrlTypes.all lists #{listed.size} of #{want.size} types — not every declared endpoint is enumerated") if listed.sort != want.sort
end

# ── NAP-4 — the generated Koin bindings ──────────────────────────────────────
want_bind = points.select { |p| p["api"].to_s.strip != "" }
if bind_src.nil?
  fail = bad("❌ NAP-4 GeneratedApiBindings.kt missing but #{want_bind.size} access point(s) declare `api:`\n     → run `./gradlew syncForkConfig`") if want_bind.any?
else
  bound = bind_src.scan(/(?:restApi|supabaseApi)\("([^"]+)"\)/).flatten
  missing = want_bind.map { |p| p["id"].to_s } - bound
  extra   = bound - points.map { |p| p["id"].to_s }
  fail = bad("❌ NAP-4 declares `api:` but has no generated binding: #{missing.join(', ')}\n     → run `./gradlew syncForkConfig`") if missing.any?
  fail = bad("❌ NAP-4 binding for an id that is not a declared access point: #{extra.join(', ')}") if extra.any?
  want_bind.each do |p|
    id     = p["id"].to_s
    simple = p["api"].to_s.split(".").last
    dsl    = p["type"].to_s.strip.downcase == "supabase" ? "supabaseApi" : "restApi"
    unless bind_src.include?(%Q{#{dsl}("#{id}")})
      fail = bad("❌ NAP-4 '#{id}' is #{p['type']} but its binding does not use #{dsl}(...)")
      next
    end
    factory = dsl == "restApi" ? "it.create#{simple}()" : "#{simple}(it)"
    fail = bad("❌ NAP-4 '#{id}' binding does not construct #{simple} (expected `#{factory}`)") unless bind_src.include?(factory)
  end
end

# ── NAP-5 / NAP-6 — Supabase anon keys ───────────────────────────────────────
supa = points.select { |p| p["type"].to_s.strip.downcase == "supabase" }
if keys_src.nil?
  fail = bad("❌ NAP-5 AppSupabaseAnonKeys.kt missing but #{supa.size} Supabase point(s) declared") if supa.any?
else
  rows = keys_src.scan(/"([^"]+)"\s*to\s+(.+?),\s*$/).to_h
  missing = supa.map { |p| p["id"].to_s } - rows.keys
  extra   = rows.keys - supa.map { |p| p["id"].to_s }
  fail = bad("❌ NAP-5 Supabase point with no anon-key row: #{missing.join(', ')}\n     → run `./gradlew syncForkConfig` (the point would be decorative)") if missing.any?
  fail = bad("❌ NAP-5 anon-key row for a non-Supabase / undeclared id: #{extra.join(', ')}") if extra.any?

  # NAP-6 — a row's VALUE may only be "" or a BuildKonfig read. Anything else is a key living in a
  # tracked file. Anon keys are publishable, but committing one still pins every fork to one project
  # and makes rotation a source edit; the BuildKonfig path (env / local.properties) is the sanctioned
  # one, identical to FRED_API_KEY.
  rows.each do |id, val|
    v = val.strip
    next if v == '""'
    next if v.match?(/\ABuildKonfig\.[A-Z0-9_]+\z/) || v.match?(/\A[\w.]*\.BuildKonfig\.[A-Z0-9_]+\z/)
    fail = bad("❌ NAP-6 anon key for '#{id}' is a literal in tracked source: #{v[0, 24]}…\n     → declare `anon_key_env: <ENV_KEY>` on the point and re-run syncForkConfig")
  end
end

# ── NAP-7 — no hand-rolled wiring ────────────────────────────────────────────
# The generated file is the ONLY place a binding may live; a hand-added line re-opens the drift the
# codegen closes. Comments and KDoc are stripped so the files that DOCUMENT the DSL don't trip it.
Dir.glob(File.join(net_dir, "**/*.kt")).sort.each do |f|
  next if f.end_with?("GeneratedApiBindings.kt")
  src = File.read(f)
  src = src.gsub(%r{/\*.*?\*/}m, "").gsub(%r{//[^\n]*}, "")
  hits = src.scan(/^\s*(restApi|supabaseApi)\("([^"]+)"\)/)
  hits.each do |dsl, id|
    fail = bad("❌ NAP-7 hand-wired #{dsl}(\"#{id}\") in #{f.sub(net_dir + '/', '')}\n     → declare `api:` on that access point in app-profile; the binding is generated")
  end
end

if fail
  puts "     → SoT is app-profile/app.yaml#network.access_points; regenerate with `./gradlew syncForkConfig`."
  exit 1
end
rest = points.count { |p| p["type"].to_s.strip.downcase != "supabase" }
puts "access points: #{points.size} declared (#{rest} REST, #{supa.size} Supabase), #{want_bind.size} bound — registry, url-types, bindings and anon-keys all match app-profile"
RUBY
