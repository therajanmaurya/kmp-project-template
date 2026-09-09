#!/usr/bin/env bash
# checks/ruby-toolchain-coherence.sh — ONE Ruby version, declared once, reachable everywhere.
#
# The trap this guards (hit 2026-09-09): `ruby -c deployment/_shared/project_config.rb` reported a
# syntax error that looked real but was not. The file uses Ruby 3.0+ endless-method syntax
# (`def self.x = VALUE`); the interpreter that parsed it was Apple's SYSTEM ruby at /usr/bin/ruby
# (2.6.10), because rbenv's shims were not on PATH in that shell. Under the project's own ruby the
# same file is "Syntax OK". Nothing in the repo was wrong — but the misleading signal cost real time,
# so the coherence that makes it diagnosable is now asserted.
#
#   RT-1  .ruby-version agrees with Gemfile.lock's RUBY VERSION.
#   RT-2  deployment/.ruby-version resolves to the same version as the root one (it is a symlink, so
#         it cannot drift — matching how deployment/Gemfile{,.lock} already symlink to the root).
#   RT-3  the Gemfile `ruby '~> X.Y'` constraint is satisfied by .ruby-version.
#   RT-5  deployment/ (the second bundler app root, needed because fastlane resolves lanes from a
#         `fastlane/` subdir of cwd) points BUNDLE_PATH at the ROOT vendor tree, and that config is
#         TRACKED. BUNDLE_PATH is relative to each app root, so without this each root materializes
#         its own 135M copy of the same gems — and they drift: a root-only `bundle install` leaves
#         deployment/ on the previous fastlane. A gitignored config would fix only one machine.
#   RT-4  no tracked Ruby script hardcodes a `#!/usr/bin/ruby` shebang — that bypasses rbenv/bundler
#         and re-introduces the system-2.6 interpreter. Use `#!/usr/bin/env ruby`.
#
# exit 0 = PASS · 1 = FAIL (blocks). No .ruby-version → PASS (project declares no Ruby toolchain).
set -uo pipefail
# shellcheck source=scripts/product-health/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
: "${HEALTH_ROOT:?ruby-toolchain-coherence: HEALTH_ROOT not set (run via product-health.sh)}"

RV="$HEALTH_ROOT/.ruby-version"
[ -f "$RV" ] || { echo "no .ruby-version — project declares no Ruby toolchain (ok)"; exit 0; }

fail=0
want="$(tr -d '[:space:]' < "$RV")"

# RT-1 — .ruby-version vs Gemfile.lock RUBY VERSION.
LOCK="$HEALTH_ROOT/Gemfile.lock"
if [ -f "$LOCK" ]; then
  locked="$(grep -A1 '^RUBY VERSION' "$LOCK" | tail -1 | tr -d '[:space:]' | sed 's/^ruby//')"
  if [ -n "$locked" ] && [ "$locked" != "$want" ]; then
    echo "${C_RED}✗ RT-1${C_RST}: .ruby-version ($want) != Gemfile.lock RUBY VERSION ($locked)"
    fail=1
  fi
fi

# RT-2 — deployment/.ruby-version must resolve to the same version.
DRV="$HEALTH_ROOT/deployment/.ruby-version"
if [ -e "$DRV" ]; then
  got="$(tr -d '[:space:]' < "$DRV")"
  if [ "$got" != "$want" ]; then
    echo "${C_RED}✗ RT-2${C_RST}: deployment/.ruby-version ($got) != root .ruby-version ($want)"
    echo "       Make it a symlink so it cannot drift:  ln -sf ../.ruby-version deployment/.ruby-version"
    fail=1
  fi
fi

# RT-3 — Gemfile constraint must admit .ruby-version.
GF="$HEALTH_ROOT/Gemfile"
if [ -f "$GF" ]; then
  con="$(grep -oE "^ruby +'[^']+'" "$GF" | head -1 | sed -E "s/^ruby +'(.*)'$/\1/")"
  if [ -n "$con" ]; then
    series="$(printf '%s' "$con" | sed -E 's/^~> *//' )"
    case "$want" in
      "$series"|"$series".*) : ;;
      *) echo "${C_RED}✗ RT-3${C_RST}: Gemfile requires ruby '$con' but .ruby-version is $want"; fail=1 ;;
    esac
  fi
fi

# RT-4 — no hardcoded system-ruby shebang in tracked scripts (the /usr/bin/ruby 2.6 trap).
bad="$(git -C "$HEALTH_ROOT" grep -l '^#!/usr/bin/ruby' -- '*.rb' 2>/dev/null || true)"
if [ -n "$bad" ]; then
  echo "${C_RED}✗ RT-4${C_RST}: script(s) hardcode '#!/usr/bin/ruby' (bypasses rbenv → system 2.6):"
  printf '%s\n' "$bad" | sed 's/^/       /'
  echo "       Use '#!/usr/bin/env ruby' so the rbenv shim / bundler context wins."
  fail=1
fi

# RT-5 — deployment bundler app root must share the repo-root vendor tree, via a TRACKED config.
DBC="$HEALTH_ROOT/deployment/.bundle/config"
if [ -d "$HEALTH_ROOT/deployment/fastlane" ]; then
  if [ ! -f "$DBC" ]; then
    echo "${C_RED}\u2717 RT-5${C_RST}: deployment/ is a bundler app root but has no .bundle/config —"
    echo "       it will materialize its own vendor/bundle (duplicate gems that drift). Add:"
    echo "         BUNDLE_PATH: \"../vendor/bundle\""
    fail=1
  elif ! grep -qE '^BUNDLE_PATH:.*\.\./vendor/bundle' "$DBC"; then
    echo "${C_RED}\u2717 RT-5${C_RST}: deployment/.bundle/config does not point BUNDLE_PATH at ../vendor/bundle:"
    grep -E '^BUNDLE_PATH:' "$DBC" | sed 's/^/       /'
    fail=1
  elif [ "$(git -C "$HEALTH_ROOT" ls-files deployment/.bundle/config | wc -l | tr -d ' ')" -eq 0 ]; then
    echo "${C_RED}\u2717 RT-5${C_RST}: deployment/.bundle/config is UNTRACKED — it would fix only this machine."
    fail=1
  fi
fi

[ "$fail" -eq 0 ] && echo "ruby toolchain coherent (single version $want; Gemfile.lock + deployment agree)"
exit "$fail"
