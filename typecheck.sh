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

# Filters the @Observable macro noise that appears when swift-plugin-server is
# unavailable to the CLI, then reports only real diagnostics.
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
