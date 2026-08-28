# Galactic Chess Invaders

Galactic Chess Invaders is an arcade–chess hybrid for macOS. A real game of chess plays out on
screen — legal moves, real check and checkmate, a live engine playing Black — except Black's pieces
are simultaneously a *Space Invaders* fleet, sweeping sideways, descending a rank at a time, and
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

[Download for macOS](https://github.com/ZUrlocker1/GCI/raw/main/GCI-0.3.dmg)

Current release: `0.3` (build 3). Universal binary — runs natively on both Apple Silicon and Intel
Macs, signed and notarized. Download the DMG disk image file, open it, and drag Galactic Chess
Invaders to your Applications folder. Or build it from source with Xcode (see [SETUP.md](SETUP.md)).

**What's new in v0.3:**

- **Nebula background** — a coloured haze that changes with the level, faint at
  first and building as the waves get harder. It can be switched off in Settings.

**What's new in v0.2:**

- **Settings panel** — press `S`, or the gear in the top right. Music and sound effects each get a
  switch and a volume slider, and the display settings include a board grid you can dial from open
  space up to named rows and columns.
- **Cadet mode** — an easier on ramp for new players. The chess clock runs long, the fleet and its
  shots are slower, you get five lives, and power-ups carry across levels. Still hugely challenging!
- Settings persist between sessions.

**Status:** The game is fully functional and feature complete. It is playable with all ten levels,
power-ups and full arcade audio. Press `L` in game for the log diagnostics panel if you want to look
behind the scenes. There are also 4 debug keys:

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
- [SETUP.md](SETUP.md) — building from a fresh clone.
- [CLAUDE.md](CLAUDE.md) — architecture rules, layer separation and performance constraints. Written
  for Claude, useful for anyone reading the code.
