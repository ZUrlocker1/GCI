# Implementation Checklist

Progress against the 15-phase plan in `gci-game-design.md` §20. Phase numbering is
the design doc's. Deviations get one line each — reasoning lives in the code.

✅ done · 🟡 partial · ⬜ not started

| Phase | Title | |
|---|---|---|
| 0 | Skeleton — app runs, title screen, music | ✅ |
| 1 | Chess logic | ✅ |
| 2.1 | Playfield: chess functional | 🟡 |
| 2.2 | Playfield: Recharged visual treatment | ✅ |
| 3.1 | Arcade layer: fleet movement | ⬜ |
| 3.2 | Arcade layer: shooting & collision | ⬜ |
| 3.3 | Arcade layer: damage states & juice | ⬜ |
| 4 | Basic sound effects | 🟡 |
| 5 | Background music + settings | ⬜ |
| 6.1 | Raiders: scout & basic escort | ⬜ |
| 6.2 | Raiders: flagship, variants, special scouts | ⬜ |
| 7.1 | Level escalation: chess AI | ⬜ |
| 7.2 | Level escalation: arcade mechanics | ⬜ |
| 8 | Visual polish | ⬜ |
| 9 | Mac hardening & App Store release | ⬜ |

---

## Phase 0 — Skeleton ✅

- [x] SwiftUI shell hosting `SKView`, black background
- [x] Single `SKEffectNode` bloom parent for all glowing content
- [x] Title screen — colour-cycling title, blinking start prompt
- [x] Animated parallax starfield — 3 tiers, batched sprites, seamless tiling
- [x] Intro music on launch
- [x] `GKStateMachine` — TITLE / PLAYING / PAUSED / GAME_OVER
- [x] `DiagnosticsLog` + sidebar (`NSTextView`, selectable, Copy button), `L` toggles
- [x] `GameAction` as the only input abstraction
- [x] How To Play screen *(pulled forward)*, with copyright line
- [x] HUD — score, level, lives, INFO chip *(pulled forward from 2.1)*
- [x] App icon
- [x] `I` / `⌘I` / `?` open How To Play; any key dismisses; opening pauses play
- [x] Window close quits; `X` restarts and clears the log (works from play, pause
      or How To Play). It deliberately leaves the high score table alone
- [x] `CFBundleIdentifier` / `CFBundleExecutable` in Info.plist — without them the
      app had no bundle identity, so `UserDefaults` silently used a process-name
      domain (this is what made high scores look broken), and App Store submission
      would have been rejected
- [ ] **60fps / draw count / music looping never actually measured**

Deviations
- Window 960×700, not 900×700 — How To Play needs the width
- fps + node count go to the sidebar, not on-canvas. Draw count has no public API,
  so SpriteKit's own overlay is tied to sidebar visibility instead
- Starfield uses ~170 batched sprites, not 2 tiling textures (§18). Revisit in
  Phase 8 if node count binds

## Phase 1 — Chess Logic ✅

- [x] `Chess.swift` — bitboard board, squares, pieces, moves, castling rights
- [x] `ChessRules.swift` — move generation, attack detection, check/mate/stalemate
- [x] `ChessFEN.swift` — parse and write
- [x] `ChessEngine.swift` — facade + depth-2 negamax, runs off the main thread
- [x] `GCIBoard.swift` — position + per-piece HP + `forcePlace` with crush
- [x] `TurnTimer.swift` — chess beat, 8s check extension, warning threshold
- [x] `LevelManager.swift` — the whole §21.1 table
- [x] Perft exact at depths 1–4 (28 values, 11.3M nodes)
- [x] Draw detection — threefold repetition and the fifty-move rule
- [x] Perf criteria met — 1,000 generations 5.6ms (budget 100ms), search 0.5ms (50ms)

Deviations
- **ChessKit unusable** — `FenSerialization` and `Position` have no public init in
  any released version, so a consumer cannot construct a `Position`. Algorithms
  ported into `Game/Logic/Chess/` under MIT. Runtime dependencies: 0
- Castling, en passant and all four promotions implemented, though §4 excluded
  them — standard rules make the published perft suite usable as ground truth.
  Gameplay still auto-queens
- **Draw rules added, reversing a documented omission.** §4 listed only win/lose
  conditions. A depth-2 search cannot force mate even with queen and rook against
  a bare king, so it shuffles: one playtest ran ~200 plies. Threefold repetition
  is keyed on the whole position (side to move, castling rights and the
  en-passant square all count); a capture or pawn move resets the clock and
  clears the table. Measured over 60 engine games: median 76 plies, max 269, none
  unfinished. Endings observed: 58 mate, 1 repetition, 1 fifty-move
- Stalemate ends the game as a draw. Note it is *not* what a queen chasing a bare
  king produces — that side is in check with legal moves available, which is a
  repetition draw, not stalemate
- Own negamax instead of `GKMinmaxStrategist` (`GKGameModel` fights Swift 6
  concurrency)
- Engine variation: positional term + repetition penalty + random tie-break among
  near-equal moves, after it was caught shuffling one rook forever

## Phase 2.1 — Playfield: Chess Functional 🟡

- [x] `BoardNode` — coordinate mapping, selection, legal-move markers, **no grid**
- [x] `PieceNode` — square-fitted, side-tinted, damage-state swaps
- [x] `SpaceshipNode` — bottom-centre, delta-time arrow movement
- [x] Click to select, click to move; castling and en passant animate correctly
- [x] Chess beat drives play — Black replies at beat end, never early
- [x] Auto-move on expiry, honours the selected piece, "AUTO" flash
- [x] Countdown display — green, pulses in the last 2s, reads CHECK when extended;
      shown only while White can actually move, and reset on every new beat
- [x] Check / mate banner naming the side
- [x] Check path visualisation — glowing line from each attacker to the king,
      dashed for knights, magenta when White is checked and cyan when Black is
- [x] Reticle pool — 32 pre-created, allocates nothing on selection
- [x] Capture scoring (White's captures only)
- [x] Game over overlay — NEW GAME? Y/N; distinguishes win, loss, stalemate and
      the two draws, each saying why
- [x] Checkmate reveal — 2.5s hold on the board first: mating path traced with
      extra pulses, CHECKMATE banner, sting, then the overlay
- [x] Chess SFX — see Phase 4
- [x] King glows red on check (§25.4) — pulsing red halo plus red wash, either side
- [x] Level progression — checkmating Black shows YOU WIN, any key continues to
      the next level; score multiplier / tighter beat / multi-move all engage
- [x] Checkmate bonus (300), scaled by the level multiplier
- [x] High score entry — up to 8 characters (letters, digits, symbols), Return
      submits at any length, offered once per game; persists across games; seeded
      defaults are 60–100 so any real game displaces them
- [x] HUD hi-score drawn (best ever, or your run once you pass it)
- [x] Hidden test mode — `T` toggles; White auto-moves on a 1s beat, labelled
      TEST MODE in the gutter and logged; ends automatically at mate/stalemate
- [ ] Lives hardcoded to 3 *(blocked until 3.2 — nothing can kill the ship yet)*

Window resize works: the scene is a fixed 960×700 with `.aspectFit`, so layout is
resize-safe. At the 640×500 minimum a square renders ~43pt — under the 48pt
guideline, above the 40pt tap target.

## Phase 2.2 — Recharged Visual Treatment ✅

- [x] Final neon-vector sprites, all 4 damage states
- [x] Linear filtering, bloom with `shouldRasterize`, pure black background
- [x] Parallax starfield
- [x] Idle bob animation on pieces (staggered so the board breathes)
- [x] Piece move ghost trail
- [x] Reticle glow

## Phase 4 — Sound Effects 🟡

- [x] `AudioManager` — pooled polyphonic playback, preloaded, zero gameplay I/O
- [x] `SoundKey` — 120 events mapped; GDC filenames repaired (they were truncated
      and failing silently)
- [x] Chess set wired: select, move ×2, capture, illegal, check alarm, promotion,
      auto-move, countdown tick, victory / game-over stings, UI click
- [ ] Arcade SFX (laser, impacts, destruction, fleet, raiders) — arrive with 3.x
- [ ] 8 sounds still need generating with jsfxr (marked `generated/` in `SoundKey`)
- [ ] **Bundle size**: only the 12 wired files are bundled (7.7MB). All 49
      referenced would be 91MB, dominated by three long uncompressed GDC stems —
      trim or convert to AAC before ship

## Phases 3.x, 5, 6.x, 7.x, 8, 9 ⬜

Not started.

---

## Known performance characteristics

- Depth-2 search: **0.40ms** from the opening, **1.95ms** midgame, against a
  50ms budget. The engine is not a bottleneck and needs no pruning
- 1,000 legal-move generations: 5.6ms against a 100ms budget
- `Board.pieces()` walks the occupied mask rather than all 64 squares; it runs at
  every search leaf
- Diagnostics publish at 4Hz, not per frame — `DiagnosticsLog` is `@Observable`,
  so per-frame writes invalidated the sidebar 60 times a second
- Starfield is ~170 batched sprites in one draw call; `SKShapeNode` cannot batch
  and would have cost one draw call each

## Verification notes

- `typecheck.sh` runs two passes (sources, tests) at Swift 6 strict concurrency,
  and fails if a source on disk is missing from `project.pbxproj`. **New files
  need `xcodegen generate`** or Xcode won't see them
- `-typecheck` does **not** catch sending-risks-data-race errors (SIL stage only).
  A real build is the authority
- `ChessPerftTests` pins move generation against the standard reference positions.
  If those counts drift, the rules have regressed
- The XCTest suite has never been *run* as tests; every assertion in it was first
  executed as a standalone harness. `⌘U` in Xcode is untried
- Nothing has been visually or audibly verified here
