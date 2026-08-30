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
# Resources/Sprites, which is the only place sprites live.
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

# Same trap one layer over: a missing sound does not render a grey X, it simply
# does not play. Only keys the code actually calls `play`/`stop` on are checked —
# `SoundKey` deliberately names sounds for features that are not built, and those
# have no file yet by design. Written after deleting a file that two keys shared,
# which left the illegal-move cue silent and nothing said so.
python3 - <<'SOUNDCHECK' || exit 1
import os, re, pathlib, sys
root = pathlib.Path("GalacticChessInvaders")
keys = pathlib.Path(root, "Audio/SoundKey.swift").read_text()
paths = dict(re.findall(r'case \.(\w+):\s*return "([^"]+\.caf)"', keys))
played = set()
for f in root.rglob("*.swift"):
    if f.name in ("SoundKey.swift",) or "Tests" in f.parts: continue
    played |= set(re.findall(r'\.(?:play|stop)\(\.(\w+)\)', f.read_text()))
# Keys reached through a pool rather than named at the call site — a
# `play(oneOf:)` argument never matches the pattern above, so the four game
# over downers would have gone unchecked exactly like the banner horns did.
for pool in re.findall(r'static let \w*[Pp]ool: \[SoundKey\] = \[(.*?)\]', keys, re.S):
    played |= set(re.findall(r'\.(\w+)', pool))
base = root / "Resources/sfx"
missing = sorted(k for k in played if k in paths and not (base / paths[k]).is_file())
if missing:
    print("✗ Sounds played in code but not bundled in Resources/sfx:")
    for k in missing: print(f"  {k} -> {paths[k]}")
    print("  (a missing sound simply does not play, and logs nothing)")
    sys.exit(1)
SOUNDCHECK

# Advisory, not fatal. Two reports that between them cover the mistakes an asset
# change actually makes: deleting a file that a second key was quietly relying
# on, and leaving a file in the bundle that nothing loads.
if [ "${1:-}" = "--assets" ]; then
python3 - <<'ASSETAUDIT'
import re, pathlib
root = pathlib.Path("GalacticChessInvaders")
keys = pathlib.Path(root, "Audio/SoundKey.swift").read_text()
paths = dict(re.findall(r'case \.(\w+):\s*return "([^"]+\.caf)"', keys))

shared = {}
for key, f in paths.items(): shared.setdefault(f, []).append(key)
shared = {f: k for f, k in shared.items() if len(k) > 1}
if shared:
    print("• Sound files backing more than one key — deleting one key does not")
    print("  make the file unused:")
    for f, k in sorted(shared.items()): print(f"    {f}\n      {', '.join(sorted(k))}")

used = set(paths.values())
orphans = sorted(str(f.relative_to(root / "Resources/sfx"))
                 for f in (root / "Resources/sfx").rglob("*.caf")
                 if str(f.relative_to(root / "Resources/sfx")) not in used)
if orphans:
    total = sum((root / "Resources/sfx" / o).stat().st_size for o in orphans)
    print(f"• {len(orphans)} bundled sound(s) no SoundKey names, {total/1e6:.1f} MB:")
    for o in orphans: print(f"    {o}")

# Piece names are composed at runtime ("chess-\(colour)-\(type)\(damage)"),
# so the literal search that guards *missing* art cannot also find *unused*
# art — it would call every piece an orphan. The generated set is enumerated
# instead, and anything matching neither that nor a literal is genuinely stray.
music = sorted((root / "Resources").glob("*.m4a"))
if music:
    total = sum(f.stat().st_size for f in music)
    print(f"• {len(music)} music track(s), {total/1e6:.1f} MB:")
    for f in music:
        print(f"    {f.name}  {f.stat().st_size/1e6:.1f} MB")

generated = {f"chess-{c}-{t}{d}"
             for c in ("w", "b")
             for t in ("pawn", "knight", "bishop", "rook", "queen", "king")
             for d in ("", "-d1", "-d2")}
literals = set(re.findall(r'"((?:chess|ship)-[a-z0-9-]+)"', "".join(
        f.read_text() for f in root.rglob("*.swift"))))
sprites = root / "Resources/Sprites"
stray = sorted(f.stem for f in sprites.glob("*.png")
               if f.stem not in literals and f.stem not in generated)
if stray:
    print(f"• {len(stray)} bundled sprite(s) nothing names: {', '.join(stray)}")
ASSETAUDIT
fi

# Music tracks and the font are referenced by bare string, with no enum to
# anchor them. Both fail quietly: a missing track logs one line nobody reads, and
# a missing font makes every SKLabelNode fall back to Helvetica — the game still
# runs, it just stops looking like itself.
RES=GalacticChessInvaders/Resources
# Tracks are named in MusicLibrary's tables as well as in playMusic calls, and
# the tables are where the typos will be.
for track in $(
    { grep -rhoE 'playMusic\("[^"]+"' --include="*.swift" GalacticChessInvaders | sed 's/.*("//;s/"//'
      grep -v '^[[:space:]]*//' GalacticChessInvaders/Game/Audio/MusicLibrary.swift \
        | grep -hoE '"[A-Za-z0-9][A-Za-z0-9 .-]*"' | tr -d '"'
    } | sort -u); do
  [ -f "$RES/$track.m4a" ] || { echo "✗ Music referenced but not bundled: $track.m4a"; exit 1; }
  # On disk is not the same as in the app. `sfx/` is a folder reference, so a
  # new sound is picked up automatically, but the tracks sit at the Resources
  # root as individual file references — a new one is invisible to the build
  # until `xcodegen generate` runs. Two alternates shipped that way: present on
  # disk, absent from the bundle, and every check here passed.
  grep -q "$track.m4a" GalacticChessInvaders.xcodeproj/project.pbxproj || {
    echo "✗ Music on disk but not in the project: $track.m4a"
    echo "  (run: xcodegen generate)"; exit 1; }
done
# The README's download link must name a DMG that is actually in the repo.
# It has been wrong twice, both times because the version was bumped in the
# README before the DMG landed — and a 404 on the download button is the one
# broken thing every visitor sees.
python3 - <<'LINKCHECK' || exit 1
import pathlib, re, sys
readme = pathlib.Path("README.md").read_text()
m = re.search(r"raw/main/([A-Za-z0-9._-]+\.dmg)", readme)
if not m:
    print("✗ README has no download link"); sys.exit(1)
named = m.group(1)
if not pathlib.Path(named).is_file():
    have = sorted(p.name for p in pathlib.Path(".").glob("*.dmg"))
    print(f"✗ README links {named}, which is not in the repo.")
    print(f"  present: {', '.join(have) if have else 'no DMG at all'}")
    print("  The link and the version line move when the DMG lands, not when")
    print("  MARKETING_VERSION changes.")
    sys.exit(1)
# And the version line should agree with the file it points at.
ver = re.search(r"Current release: `([0-9.]+)`", readme)
if ver and ver.group(1) not in named:
    print(f"✗ README says {ver.group(1)} but links {named}"); sys.exit(1)
LINKCHECK

for font in $(grep -rhoE '"[A-Za-z0-9]+-Regular"' --include="*.swift" GalacticChessInvaders \
                | tr -d '"' | sort -u); do
  [ -f "$RES/$font.ttf" ] || { echo "✗ Font referenced but not bundled: $font.ttf"; exit 1; }
done

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
