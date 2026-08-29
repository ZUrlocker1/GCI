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

There are no package dependencies to resolve — the chess model is part of
the source. See THIRD-PARTY-NOTICES.md for what it adapts and from whom.
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

## Making a build for someone else

Exactly the Zudio routine.

### 1. Archive it in Xcode

**Product → Archive.** The Organizer opens with the new archive selected.

> If Xcode complains about the Hardened Runtime, the archive was built before
> the signing settings were added. Quit Xcode, reopen the project, and archive
> again — the settings are in `project.yml` and are applied by
> `xcodegen generate`.

### 2. Distribute it

**Distribute App**, then:

- **Direct Distribution** — for Ben, or anyone else testing. Xcode signs it,
  sends it to Apple for notarization, and staples the ticket. Wait for it to
  finish, then **Export** the app to `~/Downloads`.
- **App Store Connect** — only when it is going to the store.

### 3. Wrap it in a DMG

```bash
./release-dmg.sh
```

Takes `~/Downloads/GalacticChessInvaders.app` and writes
`~/Downloads/GalacticChessInvaders-<version>.dmg`, ready to send. Pass a path if
the app is somewhere else.

It refuses to build a DMG from an app that has not been notarized, because that
is the mistake that reaches the other person as a scary warning rather than as a
game.

Needs `create-dmg` once: `brew install create-dmg`.

---

## What is set up, for reference

Signing matches Zudio: team `K66MA9TR8Z`, Developer ID for Release, ad-hoc for
local Debug builds, Hardened Runtime on, and `GalacticChessInvaders.entitlements`
turning on the App Sandbox with no exceptions — the game reads only its own
bundle and writes only `UserDefaults`.

All of it lives in `project.yml`. After pulling changes, run `xcodegen generate`
to apply them, then reopen the project in Xcode.
