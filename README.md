# Galactic Chess Invaders

Galactic Chess Invaders is an arcade–chess hybrid. A real game of chess plays out on screen —
legal moves, real check and checkmate, a live engine playing Black — except Black's pieces are
simultaneously an arcade invader fleet, sweeping sideways, descending a rank at a time, and
shooting at you.

You play both halves at once. You command White's moves, and a laser ship at the bottom of the
board, against a five-second turn clock. Arcade reflex decides whether you survive; the chess
decides what you are surviving against.

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

---

## Getting it

**Mac App Store** — [Galactic Chess Invaders](https://apps.apple.com/us/app/galactic-chess-invaders/id6811389163).
Free, no ads, no in-app purchases, and nothing collected.

Or [download the DMG for macOS](https://github.com/ZUrlocker1/GCI/raw/main/GCI-1.3.dmg) directly.
Open it and drag Galactic Chess Invaders to your Applications folder.

**Current release: 1.3 (build 10)** — a universal binary, signed and notarized, running natively on
Apple Silicon and Intel. You can also build it from source with Xcode; see [SETUP.md](SETUP.md).

## Platforms

The same codebase builds for Mac, iPad and iPhone.

| | State |
|---|---|
| **Mac** | Shipped. The DMG above and the App Store listing. |
| **iPad** | Playable by touch, checked on five sizes in both orientations. In testing. |
| **iPhone** | Playable by touch, both orientations, checked on three sizes. In testing (1.4). |

On a phone the game lays itself out differently rather than shrinking: in portrait the board takes
the full width and the readouts move underneath it, the top bar reflows to fit, and the Settings and
How To Play screens become one readable column instead of two small ones.

The touch builds are not on the store yet. Build one from source today, or see
[IOS-Port.md](docs/IOS-Port.md) for where the port stands.

## Playing it

| | |
|---|---|
| **Mac** | Arrows or `A`/`D` move the ship, `SPACE` fires, click a piece then its square. `ESC` pauses, `Q` quits, `M` mutes. |
| **Touch** | Drag the ship, hold FIRE, tap a piece then its square. A hardware keyboard works too. |

**Test Mode** is a cheat mode and a diagnostic. Press `⌘T` on a Mac, or hold the version badge on
any device. It unlocks four debug keys and a log panel:

- `L` the diagnostics log (landscape only on iOS)
- `A` plays White automatically, at speed
- `P` grants the next power-up
- `R` sends the next raider
- `V` skips to the next level

The game is feature complete: ten levels, every power-up, a settings screen, its own soundtrack and
full arcade audio. Play testing feedback is welcome.

## What's new

**1.4 — iPhone** *(in testing)*. The game runs on iPhone in both orientations. In portrait the
readouts move under the board so the squares get the full width, the top bar reflows, and Settings
and How To Play become one readable column.

**1.3 — iPad, and sound without the stutter.** The game runs on iPad. Heavy fire no longer costs
frames: sound effects are decoded once at launch and played from a pool of voices that are already
running, 11.7ms a shot down to 0.03ms. **The frame rate now stays well above 50 on both Mac and
iPad, including Level 10 at full strength** — where the Mac used to drop into the 40s and an iPad
mini into the 20s.

**1.2 — better window resizing, and the groundwork for touch.** The board and the readouts lay
themselves out from the space available instead of being scaled into a fixed canvas, and everything
on the playfield is sized against the board. That is what made iPad and iPhone possible in 1.3 and
1.4 — a fixed canvas can only ever be letterboxed onto a new screen shape.

**1.1 — Cadet and Ace.** Cadet became the default difficulty and the harder mode became Ace. Chess
Hints glow the pieces worth moving and name them in the gutter; Arcade Hints prompt a player who
goes three moves without firing.

**1.0 — the first official release.**

Every release is in the [change log](docs/change-log.md), in full.

## History

The original was prototyped in 1983 on an Apple II in TASC-compiled Applesoft BASIC. This version is
written in Swift 6 and SpriteKit with no third-party dependencies, and was developed with Claude —
the design documents, the implementation and the record of what was tried and rejected are all in
this repository.

---

## Documentation

**Design**

- [gci-design-brief.pdf](docs/gci-design-brief.pdf) — the original design brief, and the best short
  introduction to what the game is trying to be.
- [gci-game-design.md](docs/gci-game-design.md) — the full design document: every rule, mechanic,
  level, sprite spec, sound and screen. The authoritative source, and what the code cites by section
  number throughout.
- [art-handoff.md](docs/art-handoff.md) — the visual handoff written before any code existed: screen
  layouts, HUD, FX language, design tokens and the sprite system.

**Build**

- [implementation.md](docs/implementation.md) — what is actually built, phase by phase, against the
  design doc's plan. Includes every deviation from the spec and why it was taken.
- [IOS-Port.md](docs/IOS-Port.md) — how the scene lays itself out, what is tested on which device,
  and what is left.
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
