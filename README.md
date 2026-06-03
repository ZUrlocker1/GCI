# Galactic Chess Invaders

> "40 years in the making."

An arcade-chess hybrid for macOS. A real chess game plays out on screen while Black's pieces simultaneously behave as a Space Invaders fleet — sliding, descending, and firing at you. You command White's chess moves **and** a laser spaceship at the bottom of the screen, at the same time.

Originally prototyped in spring 1983 on an Apple II in TASC-compiled Applesoft BASIC, using the HRCG High Res Character Generator with a chess font, a synth startup tune, and BASIC speaker sound effects. The original floppies were rediscovered 40 years later. This is the full realization.

![](<mockups/GCI title mockup.jpg>)

## Platform

- **Primary:** macOS (Swift / SpriteKit) — runs in a window
- **Planned:** iOS / iPadOS (Phase 10–11)

## Tech Stack

Swift 6 · SpriteKit · SwiftUI · ChessKit · GameplayKit · AVFoundation

## Development

See `SETUP.md` for Xcode project creation steps.  
See `docs/gci-game-design.md` for the full game design document.  
See `CLAUDE.md` for Claude Code project context.

## Project Structure

```
docs/          Game design document
assets/        Sprite atlas, music files, SFX
mockups/       Screen mockup images
GalacticChessInvaders/   Swift source
```

## Aesthetic

Neon-vector Recharged — smooth glowing outlines on pure black, bloom via SKEffectNode. 
Color palette: `#12E0FF` (player/white) · `#FF2060` (enemy/black) · `#7DFF4D` (scout) · `#FF8A1E` (escort) · `#3AA2FF` (flagship).  
Font: Press Start 2P.


