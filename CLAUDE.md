# Galactic Chess Invaders — Claude Code Project Brief

> "40 years in the making." Originally prototyped in 1983 on an Apple II in TASC-compiled Applesoft BASIC.

**Full design document:** `docs/gci-game-design.md` — read this for all rules, mechanics, and visual specs.

---

## What This Game Is

An arcade-chess hybrid for macOS (Swift / SpriteKit). A real chess game plays out on screen, but Black's pieces simultaneously behave as a Space Invaders fleet — sliding left and right, descending, and firing at the player. The player controls White's chess moves **and** a horizontally-moving laser spaceship at the bottom of the screen, simultaneously.

The chess game is real but fast and shallow (5-second turn timer, 1–2 ply engine). Arcade reflex, not deep strategy, determines whether you survive.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| Game rendering | SpriteKit |
| UI / menus | SwiftUI (hosts SpriteKit scene) |
| Chess logic | ChessKit (SPM: `https://github.com/aperechnev/ChessKit`) |
| Chess AI | GameplayKit — `GKMinmaxStrategist`, depth 2 |
| Audio | AVFoundation — preloaded `AVAudioPlayer` instances |
| State machine | GameplayKit — `GKStateMachine` |
| Game math | simd |

**Total runtime Swift dependencies: 1** (ChessKit). Everything else is Apple built-in.

---

## Project Structure

```
GCI/
├── CLAUDE.md                        ← this file
├── README.md
├── SETUP.md                         ← Xcode project creation guide
├── .gitignore
├── docs/
│   └── gci-game-design.md           ← full design document
├── assets/
│   ├── GCI.spriteatlas/             ← all piece + ship sprites (neon vector PNGs)
│   └── music/                       ← MIDI and audio files
├── mockups/                         ← screen mockup JPGs
└── GalacticChessInvaders/           ← Swift source root
    ├── App/
    │   ├── GalacticChessInvadersApp.swift
    │   └── ContentView.swift
    ├── Game/
    │   ├── Logic/
    │   │   ├── GCIBoard.swift        ← wraps ChessKit, adds force-place, HP tracking
    │   │   ├── Piece.swift           ← piece type, color, HP, damage state
    │   │   ├── FleetController.swift ← invader movement, descent, logical square updates
    │   │   ├── MoveGenerator.swift   ← wraps ChessKit move generation
    │   │   ├── GameState.swift       ← GKStateMachine states
    │   │   └── ScoreManager.swift    ← score, multiplier, high score persistence
    │   ├── Rendering/
    │   │   ├── GameScene.swift       ← main SKScene, update loop, physics delegate
    │   │   ├── PieceNode.swift       ← SKSpriteNode subclass, damage state frames
    │   │   ├── SpaceshipNode.swift   ← player ship node, laser cap, shield state
    │   │   ├── LaserNode.swift       ← laser projectile node
    │   │   ├── HUDNode.swift         ← score, level, lives, turn timer display
    │   │   └── DiagnosticsOverlay.swift ← green-on-black dev log panel (debug only)
    │   ├── Input/
    │   │   ├── GameAction.swift      ← platform-agnostic action enum
    │   │   └── InputHandler.swift    ← keyboard/mouse → GameAction translation
    │   └── Audio/
    │       └── AudioManager.swift    ← preloads all SFX + music, pool management
    ├── Scenes/
    │   ├── TitleScene.swift
    │   ├── GameScene.swift           ← (symlink or same as Game/Rendering/GameScene)
    │   └── GameOverScene.swift
    └── Tests/
        └── GCITests.swift
```

---

## Architecture Rules — Read Before Writing Any Code

### Three-Layer Separation
1. **Game Logic** (`Game/Logic/`) — pure Swift, zero SpriteKit imports. Runs on any platform. Unit-testable.
2. **Rendering** (`Game/Rendering/`) — SpriteKit only. Reads from Logic layer, never writes back.
3. **Input** (`Game/Input/`) — translates platform events to `GameAction` enum. Logic layer consumes `GameAction` only.

### Never Block the Main Thread
- Chess engine (`GKMinmaxStrategist`) runs in `Task.detached(priority: .userInitiated)`
- Result delivered back via `await MainActor.run { }`
- Fleet movement, physics, rendering always on main thread via SKAction

### Performance Rules
- **Object pools** for lasers, score pop-ups, reticles — zero allocation during gameplay
- **Single SKEffectNode** parent for all bloom content (`shouldRasterize = true`)
- **Texture atlases** — use `GCI.spriteatlas` for all piece/ship sprites
- **Delta-time movement** — all positions updated via `dt` parameter in `update(_:)`
- **Never** mutate `node.position` in `update()` — use `SKAction` for all animation
- **Default texture filtering** (linear, not `.nearest`) — sprites are smooth vector art, not pixel art

### Platform Portability
- All input goes through `GameAction` enum — no direct keyboard code in Logic or Rendering
- `AudioManager` and all game logic are identical on macOS and iOS
- SpriteKit scene size is resolution-independent; use scene coordinates not screen points
- macOS: runs in a window (not forced fullscreen). Minimum window: 640×500 pts.

---

## Key Game Mechanics (Quick Reference)

### Chess
- Real chess engine (ChessKit + GKMinmaxStrategist, depth 1–2)
- 5-second turn timer; on expiry, engine auto-moves White (constrained to selected piece if one is selected; otherwise picks best available)
- No castling, no en passant
- Win: Black King checkmated OR Black King shot to 0 HP
- Lose: White King shot to 0 HP, White King checkmated, ship loses 3 lives, or Black piece reaches Rank 1

### Fleet (Black Pieces)
- Sweep left/right in Invader formation; descend half a rank at each wall
- **Logical squares update on each descent** via `GCIBoard.forcePlace()` — bypasses chess legality
- Lateral sweep does NOT update logical squares — only descent does
- When Black piece descends onto a White piece's square: **crush event** (White piece removed instantly, animation plays)
- Fleet chess move fires AFTER each lateral sweep completes

### Damage System
- Pieces have HP: Pawn 2, Knight/Bishop 6, Rook 8, Queen 12, King 16
- Damage shown by **outline erosion** (not chipped pixels): Full → Chipped (d1) → Cracked (d2) → Critical (d2 + flicker)
- Sprite atlas: `chess-[w/b]-[piece].png`, `chess-[w/b]-[piece]-d1.png`, `chess-[w/b]-[piece]-d2.png`
- No HP bars — the sprite IS the health indicator

### Player Ship
- Arrow keys / WASD: move. Space: fire.
- Laser cap: 2 (normal), +1 per pawn promotion (stacks, hard cap 6), resets each level
- Click piece → click destination: chess move
- 3 lives; 2-second respawn invincibility after death

### Multi-Move (Level 3+)
- 2 black chess moves per turn at Level 3; 3 at Level 5
- All moves chosen simultaneously by engine, then animated in parallel via SKAction group

### Scoring
- Shoot Pawn: 25 | Knight/Bishop: 50 | Rook: 75 | Queen: 150 | King: 500
- Checkmate bonus: 300 | King shot at checkmate: 800 (both bonuses)
- Score multiplier: ×1.0 at Level 1, +0.5 per level

---

## Sprite Atlas Reference

All sprites in `assets/GCI.spriteatlas/`. Naming: `chess-[w/b]-[piece][-d1/-d2].png`

| Piece | Full HP | Chipped | Cracked | Size (@2x) |
|---|---|---|---|---|
| Pawn | chess-[w/b]-pawn.png | -d1 | -d2 | 160×232 |
| Bishop | chess-[w/b]-bishop.png | -d1 | -d2 | 176×264 |
| Rook | chess-[w/b]-rook.png | -d1 | -d2 | 192×256 |
| Queen | chess-[w/b]-queen.png | -d1 | -d2 | 192×272 |
| King | chess-[w/b]-king.png | -d1 | -d2 | 192×288 |
| Knight | chess-[w/b]-knight.png | -d1 | -d2 | 208×264 |

Ships: `ship-player.png`, `ship-scout.png` (green), `ship-escort.png` (orange), `ship-flagship.png` (blue)

White pieces: `#12E0FF` cyan glow. Black pieces: `#FF2060` magenta glow.
Font: **Press Start 2P** (Google Fonts, free).

---

## Diagnostics Log

`DiagnosticsLog.shared` — singleton, `ObservableObject`.
- **Debug builds only** (`#if DEBUG`) — auto-disabled in release
- Green category labels, white description text, monospace font
- macOS: right sidebar panel alongside the game
- Log everything: STARTUP, CHESS, FLEET, SHOOT, HIT, DESTROY, PROMOTE, SCORE, LEVEL, INPUT (optional)

```swift
DiagnosticsLog.shared.log(.chess, "Black Pawn e7→e5")
DiagnosticsLog.shared.log(.hit, "White Rook d1 hit (-2 HP → 6HP)")
```

---

## Physics Categories

```swift
struct PhysicsCategory {
    static let playerLaser:   UInt32 = 0b00001
    static let enemyPiece:    UInt32 = 0b00010
    static let friendlyPiece: UInt32 = 0b00100
    static let enemyShot:     UInt32 = 0b01000
    static let ship:          UInt32 = 0b10000
}
```

---

## Current Phase

**Phase 0 — Project Skeleton** (starting point)
- SwiftUI app shell, SpriteKit scene presented in window
- Black `#000000` background confirmed at 60fps
- Parallax starfield placeholder (2 twinkling star layers)
- `GKStateMachine` wired: TITLE → PLAYING → GAME_OVER
- `DiagnosticsLog` sidebar visible with STARTUP messages
- ChessKit added via SPM

See `docs/gci-game-design.md` §22 for the full 11-phase development plan.

---

## Adding ChessKit (SPM)

In Xcode: File → Add Package Dependencies → `https://github.com/aperechnev/ChessKit` → Up to Next Major from 2.0.0

```swift
import ChessKit
// Board, Position, Move, Piece types available
```
