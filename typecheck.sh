#!/usr/bin/env bash
# typecheck.sh — Swift 6 strict-concurrency check without xcodebuild.
# Required because xcrun/xcodebuild are broken on macOS 26 Tahoe + Xcode 16.2
# (libxcrun.dylib architecture mismatch: have arm64, need arm64e).
# Run before every commit: bash typecheck.sh

set -euo pipefail

SWIFTC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
SDK=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.sdk
MODCACHE=.build/modcache
# XCTest ships outside the SDK, so the test pass needs these search paths.
XCTEST_F=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks
XCTEST_I=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib

SOURCES=$(find GalacticChessInvaders -name "*.swift" \
  ! -path "*/Tests/*" \
  ! -path "*/Scenes/*" \
  | tr '\n' ' ')

# This script globs the disk; Xcode builds from project.pbxproj. A new file will
# therefore compile here and fail in Xcode until the project is regenerated, so
# check for that mismatch up front rather than discovering it at ⌘B.
PBXPROJ=GalacticChessInvaders.xcodeproj/project.pbxproj
if [ -f "$PBXPROJ" ]; then
  MISSING=""
  for file in $(find GalacticChessInvaders -name "*.swift" ! -path "*/Scenes/*"); do
    grep -q "$(basename "$file")" "$PBXPROJ" || MISSING="$MISSING  $file\n"
  done
  if [ -n "$MISSING" ]; then
    echo "✗ These sources are not in the Xcode project — run: xcodegen generate"
    printf "%b" "$MISSING"
    exit 1
  fi
fi

# Sprite names are string literals, so a texture that is referenced but not
# bundled compiles cleanly and fails at run time as SpriteKit's missing-texture
# placeholder — a big grey X on screen, with nothing in the log. That is exactly
# how the camel's two walk frames shipped broken: they were written into
# assets/GCI.spriteatlas, and the app loads from Resources/Sprites.
SPRITES=GalacticChessInvaders/Resources/Sprites
if [ -d "$SPRITES" ]; then
  MISSING_ART=""
  for name in $(grep -rhoE '"(chess|ship)-[a-z0-9-]+"' --include="*.swift" \
                  GalacticChessInvaders | tr -d '"' | sort -u); do
    [ -f "$SPRITES/$name.png" ] || MISSING_ART="$MISSING_ART  $name\n"
  done
  if [ -n "$MISSING_ART" ]; then
    echo "✗ Sprites referenced in code but not in $SPRITES:"
    printf "%b" "$MISSING_ART"
    echo "  (a missing texture renders as a grey X and logs nothing)"
    exit 1
  fi
fi

# swift-plugin-server (used to expand @Observable) is flaky in this environment
# and used to be treated as cosmetic noise — filtered out on the assumption that
# the rest of the diagnostics were still trustworthy. They are not: verified by
# deliberately breaking a reference elsewhere in the same compile and finding
# the run still reported clean. Once the plugin fails, the compiler appears to
# stop surfacing at least some real diagnostics for the rest of the module, so
# this state can no longer be filtered past — it has to fail the whole run.
#
# A shell variable can't carry this: run_pass's output is captured via
# $(...), which forks a subshell, so a plain `PLUGIN_SERVER_FLAKY=1` set inside
# it vanishes the moment the function returns and the caller never sees it.
# (This is exactly what happened the first time this guard was written — it
# silently never fired.) A flag file survives the subshell boundary.
mkdir -p .build/tc
FLAKY_MARKER="$(mktemp .build/tc/flaky.XXXXXX)"
trap 'rm -f "$FLAKY_MARKER"' EXIT

run_pass() {
  local label="$1"; shift
  echo "$label" >&2
  local output
  output=$("$SWIFTC" -typecheck \
    -swift-version 6 \
    -strict-concurrency=complete \
    -sdk "$SDK" \
    -target arm64-apple-macos14.0 \
    -module-cache-path "$MODCACHE" \
    "$@" 2>&1 || true)

  if echo "$output" | grep -q "swift-plugin-server\|malformed response"; then
    echo 1 > "$FLAKY_MARKER"
  fi

  echo "$output" \
    | grep -v "ObservationMacros\|swift-plugin-server\|malformed response\|externalMacro\|@attached" \
    | grep -E "error:|warning:" \
    | grep -v "note:" \
    || true
}

FILTERED=$(run_pass "Typechecking $(echo "$SOURCES" | wc -w | tr -d ' ') source files…" $SOURCES)

# Second pass covers the test target. `@testable import` can't resolve without a
# built module, so the tests are compiled alongside the sources with the import
# stripped — enough to catch signature drift between tests and the code.
TESTS=$(find GalacticChessInvaders/Tests -name "*.swift" | tr '\n' ' ')
if [ -n "$TESTS" ]; then
  mkdir -p .build/tc
  rm -f .build/tc/*.swift
  for test_file in $TESTS; do
    sed 's/^@testable import GalacticChessInvaders$//' "$test_file" \
      > ".build/tc/$(basename "$test_file")"
  done
  TEST_OUT=$(run_pass "Typechecking $(echo "$TESTS" | wc -w | tr -d ' ') test files…" \
    -F "$XCTEST_F" -I "$XCTEST_I" $SOURCES .build/tc/*.swift)
  FILTERED="$FILTERED$TEST_OUT"
fi

if [ -s "$FLAKY_MARKER" ]; then
  echo "✗ swift-plugin-server failed to expand a macro (@Observable) during this"
  echo "  run. That has been observed to silently suppress OTHER, unrelated"
  echo "  diagnostics for the rest of the module — a broken reference can pass"
  echo "  as \"no errors\". This run cannot be trusted. Re-run; if it recurs,"
  echo "  restart the toolchain (or use xcodebuild once its own arm64e mismatch"
  echo "  is resolved) before relying on a clean result."
  exit 1
fi

if [ -z "$FILTERED" ]; then
  echo "✓ No errors or warnings."
  exit 0
else
  echo "$FILTERED"
  # Fail on errors; warnings are informational
  if echo "$FILTERED" | grep -q "error:"; then
    echo ""
    echo "✗ Typecheck failed — fix errors above before committing."
    exit 1
  else
    echo ""
    echo "⚠ Warnings only — review before committing."
    exit 0
  fi
fi
