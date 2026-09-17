# Galactic Chess Invaders

Galactic Chess Invaders is an arcade–chess hybrid for macOS. A real game of chess plays out on
screen — legal moves, real check and checkmate, a live engine playing Black — except Black's pieces
are simultaneously an arcade invader fleet, sweeping sideways, descending a rank at a time, and
shooting at you.

You play both halves at once. You command White's moves with the mouse, and a laser ship at the
bottom of the board with the keyboard, against a five-second turn clock. Arcade reflex decides
whether you survive; the chess decides what you are surviving against.

![Galactic Chess Invaders title screen](docs/GCI%20title.jpg)

The two halves are genuinely entangled rather than side by side. Shooting a black piece removes it
from the chess position. A descending piece crushes whatever White has on the square it lands on.
Checkmating the black king wins the wave, and so does shooting it. Walking a pawn to the eighth rank
promotes it *and* raises your laser cap — the one moment the game asks you to do both things at once.

Ten levels, each with a mechanic of its own rather than a difficulty multiplier: pawns start
shooting back, Black gets extra moves per turn, the fleet's sweep widens, bishops open fire on the
diagonal, regenerated pawns arrive armoured and immune to lasers, the black king raises a forcefield
and draws its own weapon — and Blitz, the last wave, which takes most of that back at a three-second
clock and comes apart as you play it.

**Watch a 90-second demo:** [Galactic Chess Invaders](https://www.youtube.com/watch?v=yVaNIPDnGa0) on YouTube

<a href="https://www.youtube.com/watch?v=yVaNIPDnGa0"><img src="docs/GCI%20blitz.jpg" width="440" alt="Level 10, Blitz — the fleet at full strength against a three-second clock"></a>

[Download for macOS](https://github.com/ZUrlocker1/GCI/raw/main/GCI-1.2.dmg)

Current release: `1.2` (build 9). Universal binary — runs natively on both Apple Silicon and Intel
Macs, signed and notarized. Download the DMG disk image file, open it, and drag Galactic Chess
Invaders to your Applications folder. Or build it from source with Xcode (see [SETUP.md](SETUP.md)).

**What's new in v1.2** — the release that prepares the Mac game for iPad and iPhone:

- **Better window resizing.** The board and the readouts lay themselves out from the space available instead of being scaled into a fixed canvas. Everything on the playfield — the ship, the lasers, the raiders, the explosions — is sized against the board rather than staying as drawn.
- **Lighter on the CPU.** Readouts redraw when they change rather than on every frame, and the title screen no longer re-renders its own type sixty times a second — that alone took it from 53% CPU to under 40%. Steady 60fps throughout.
- **The Nuke hits harder.** Its own screen shake, and slow motion that no longer snaps.
- **The log panel moved behind Test Mode.** Press `⌘T`, then `L`.
- Groundwork for the iPad and iPhone port — see [IOS-Port.md](docs/IOS-Port.md).

**What's new in v1.1:**

- **Cadet is now the default difficulty**, and the harder mode is **Ace**.
  Chess Hints are on for Cadet, off for Ace by default, but can be changed.
- **Chess Hints** — the pieces worth moving glow, and the gutter names them:
  `MOVE A PAWN`, or `MOVE A PAWN / OR KNIGHT` etc.
- **Arcade Hints** — Similarly a message is displayed if the user goes 3 moves
  without firing, or does not use the arrow keys. A message is also displayed
  in red if they hit their own piece a second time. Hints rearm at each level.

**What's new in v1.0:**

- Minor edits. First official release.

Earlier releases are in the [change log](docs/change-log.md).

**Status:** The game is fully functional and feature complete. It is playable with all ten levels,
power-ups and full arcade audio. `M` mutes the music from anywhere. Press `⌘T` for Test Mode, which
unlocks the diagnostics log on `L` and 4 debug keys:

- `A` plays White automatically, at speed
- `P` grants the next power-up
- `R` sends the next raider
- `V` skips to the next level

**Next steps:**

- Play testing to adjust levels, speed, difficulty, etc. Feedback welcome!
- Add arcade soundtrack for each specific level

**History:**

The original was prototyped in 1983 on an Apple II in TASC-compiled Applesoft BASIC. This version is
written in Swift 6 and SpriteKit with no third-party dependencies, and was developed with Claude —
the design documents, the implementation and the record of what was tried and rejected are all in
this repository.

---

## Documentation

### Design

- [gci-design-brief.pdf](docs/gci-design-brief.pdf) — the original design brief, and the best short
  introduction to what the game is trying to be.
- [gci-game-design.md](docs/gci-game-design.md) — the full design document: every rule, mechanic,
  level, sprite spec, sound and screen. The authoritative source, and what the code cites by section
  number throughout. Appendix A covers an eventual iOS and iPadOS port, which is not scheduled — the
  architecture rules that keep it possible are followed in the macOS build regardless.
- [art-handoff.md](docs/art-handoff.md) — the visual handoff written before any code existed: screen
  layouts, HUD, FX language, design tokens and the sprite system.

### Build

- [implementation.md](docs/implementation.md) — what is actually built, phase by phase, against the
  design doc's plan. Includes every deviation from the spec and why it was taken, and the playtest
  fixes that shaped the game.
- [change-log.md](docs/change-log.md) — every release, newest first.
- [SETUP.md](SETUP.md) — building from a fresh clone.
- [CLAUDE.md](CLAUDE.md) — architecture rules, layer separation and performance constraints. Written
  for Claude, useful for anyone reading the code.

## Licence and attribution

Copyright (c) 1983-2026 M. Zack Urlocker. All rights reserved.

The chess playing algorithm is derived from
[ChessKit](https://github.com/aperechnev/ChessKit) by Alexander Perechnev — the
bitboard board representation, the square indexing, the ray-scan move generation
and the FEN serialisation. It is an adaptation rather than a dependency: in
every released version of ChessKit, `FenSerialization` and `Position` have no
public initialiser, so an external consumer cannot construct a `Position` at
all. ChessKit is MIT licensed, and its licence requires the following notice to
be reproduced in full:

```
MIT License

Copyright (c) 2020 Alexander Perechnev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Fonts, sound effects and music are credited in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
