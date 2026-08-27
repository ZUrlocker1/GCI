# Galactic Chess Invaders — Setup

## Quick start (fresh clone)

```bash
bash setup.sh
open GalacticChessInvaders.xcodeproj
```

`setup.sh` handles everything:
- Checks for Xcode CLT and xcodegen (installs xcodegen via Homebrew if missing)
- Downloads Press Start 2P font (OFL license, ~50 KB) into `assets/`
- Converts any audio source files to `.caf` if present
- Generates `GalacticChessInvaders.xcodeproj` via xcodegen

After opening in Xcode, SPM resolves ChessKit automatically on first build.
Press ⌘R — you should see the title screen at 60fps.

## Requirements

| Tool | Install |
|---|---|
| Xcode 16.2+ | App Store |
| xcodegen | `brew install xcodegen` |
| Homebrew (optional) | https://brew.sh — only needed if xcodegen isn't already installed |

## Project structure

The `.xcodeproj` is generated from `project.yml` and is **not** committed to the repo.
Always regenerate it after pulling changes that touch `project.yml`:

```bash
xcodegen generate
```

## Manual font install (if setup.sh can't reach the network)

1. Download **PressStart2P-Regular.ttf** from https://fonts.google.com/specimen/Press+Start+2P
2. Place it at `assets/PressStart2P-Regular.ttf`
3. Run `xcodegen generate` to add it to the bundle

The app registers the font programmatically at launch (`GalacticChessInvadersApp.swift`),
so no `Info.plist` changes are required.

## Adding audio (.caf files)

The `assets/sfx/` directory is gitignored (large binaries). To regenerate from sources:

```bash
bash assets/sfx/convert_to_caf.sh
```

Or `setup.sh` runs this automatically if source files are present.

---

## Signing and distribution

Set up the same way Zudio is: **Developer ID, notarized, shipped as a DMG.** Team
`K66MA9TR8Z`, sandboxed, hardened runtime on.

| Configuration | Identity | Why |
|---|---|---|
| Debug | `-` (ad-hoc), signing not required | a local build never waits on a certificate |
| Release | `Developer ID Application` | anything that leaves this machine is signed |

`GalacticChessInvaders.entitlements` turns on the App Sandbox and asks for
nothing else — the game reads only its own bundle and writes only
`UserDefaults`, so it needs no file, network or hardware exceptions.

### Making a build for someone else

```bash
./release.sh
```

Builds a universal Release binary, signs it, notarizes it, staples the ticket,
and writes a drag-to-install DMG to `~/Downloads`. One-time prerequisites are
listed at the top of the script: a Developer ID Application certificate, an
app-specific password stored as the `AC_PASSWORD` notarytool profile, and
`brew install create-dmg`.

### Why not App Store Connect

TestFlight needs App Store distribution certificates and, for external testers, a
review pass — a lot of process to get a build to one person. A notarized DMG
opens on any Mac with no warning and no account. If the App Store becomes the
goal later, the signing settings here are already what it needs; only the
certificate and the upload step change.

**"No Team Found in Archive"** was `DEVELOPMENT_TEAM` being unset, together with
`CODE_SIGNING_REQUIRED: NO`. Both are fixed in `project.yml`, so regenerate with
`xcodegen generate` after pulling.
