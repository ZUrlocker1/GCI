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
