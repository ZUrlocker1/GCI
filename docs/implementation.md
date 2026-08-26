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
| 3.1 | Arcade layer: fleet movement | 🟡 |
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
  clears the table. The quiet-move draw is set to **20 moves, not the standard
  50** — this is an arcade game and a shuffling endgame is unwatchable long
  before a real match would be drawn. Caps a grind at 40 plies instead of 100.
  Measured over 60 normal games the peak quiet run is a median of 4 full moves
  and a 90th percentile of 9, so 20 touches 1 game in 60; below ~15 it starts
  cutting real play short. Measured over 60 engine games: median 76 plies, max 269, none
  unfinished. Endings observed: 58 mate, 1 repetition, 1 fifty-move
- Stalemate ends the game as a draw. Note it is *not* what a queen chasing a bare
  king produces — that side is in check with legal moves available
- **A depth-2 engine cannot convert a won endgame, and this is accepted.** Queen
  vs bare king ends on the fifty-move rule 19 times in 20, never by mate.
  Threefold rarely fires there because a roaming queen almost never repeats a
  whole position — 100 plies produced 99 distinct ones. Two fixes were measured
  and both rejected: an endgame mop-up evaluation changed nothing, and depth 3
  also converted nothing while costing 145ms per search against a 50ms budget.
  Real conversion needs a mating algorithm, which an arcade opponent does not
  warrant. Phase 3.2 makes it moot — lives and the fleet will end runs long
  before a chess grind matters
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
- [x] Mix — effects sit just under the music (loudest 0.66 vs 0.75). They had
      defaulted to 0.8–1.0, i.e. *over* the track. Tuned via one gain and a
      ceiling in `AudioManager`, so per-key balance is preserved. The check alarm
      and countdown tick are mixed further down and the alarm has a 3s cooldown —
      both repeat, and repetition reads as loudness
- [ ] Arcade SFX (laser, impacts, destruction, fleet, raiders) — arrive with 3.x
- [ ] 8 sounds still need generating with jsfxr (marked `generated/` in `SoundKey`)
- [ ] **Bundle size**: only the 12 wired files are bundled (7.7MB). All 49
      referenced would be 91MB, dominated by three long uncompressed GDC stems —
      trim or convert to AAC before ship

## Phase 3.1 — Fleet Movement 🟡

Get the black fleet sweeping and descending alongside the chess game. No shooting.

- [x] `FleetRules.swift` — two-step descent counter, rank descent, descent
      ordering, speed scaling (§21.2: 1.0× at 16 → 2.5× at 1)
- [x] `FleetController.swift` — sweep as one `SKAction` on the fleet parent, so
      16 pieces move at the cost of one; speed and extent recomputed per leg so
      the fleet accelerates as it thins without rebuilding a repeating action
- [x] Two half-drops per rank; only the second calls `forcePlace`. The parent is
      raised a rank at the same moment, or the fleet would appear to fall twice
- [x] Black pieces re-parented to the fleet, positioned at their *logical* square
      centre — the parent transform supplies the visual offset
- [x] Crush events, emitted **before** the descent re-key: the victim is still
      keyed at that square, and reversing the order destroys the arriving piece
- [x] Fleet log lines: sweep, half-drop, logical descent, breach
- [x] Playtested, then reworked (see below)

### 3.1 rework after playtest

The first build was unplayable: the fleet drifted three files off true and fell a
rank every few seconds. Two rules came out of it, both now pinned by tests.

- [x] **Sweep never exceeds ±0.4 of a square** (`FleetRules.sweepAmplitudeRatio`).
      Past half a square a piece straddles a file boundary and its square stops
      being readable, which makes the chess half unplayable
- [x] **Descent is paced by the chess beat, not wall bounces.** Tying it to
      bounces coupled difficulty to sweep width — narrowing the shuffle for
      readability would have silently made the fleet fall faster
- [x] Level 1: the fleet holds completely still for 3 beats, starts sweeping,
      then descends half a rank every 4 beats from beat 6 (a full rank every 8).
      `descentSchedule(for:)` tightens all three with level, floored so a rank
      never costs fewer than 4 beats. Movement always precedes ground being taken
- [x] Check and mate lines resolve endpoints through the fleet's drawn position,
      not the logical square
- [x] Checkmate snap: the fleet eases onto its true squares over 0.32s and the
      mating line is redrawn, so the reveal shows the position the engine sees
- [x] Capture tethers: a hairline from a threatened fleet piece to its square,
      shown only while a white piece is selected
- [x] I / ? open the Info screen from the title screen, not just during play

### 3.1 second readability pass

- [x] **Uneven half-drops, 0.3 then 0.7.** An even split parked the fleet on a
      rank boundary for several beats — the exact ambiguity the sweep cap exists
      to prevent on the other axis. At 0.3 a piece reads as leaning off its rank
- [x] **A fixed grid** (`BoardNode.showsGrid`). §12.3 banned one because the
      fleet slid past the board's edges; capping the sweep below one file
      retired that reason. It never animates — being the one stationary thing on
      screen is the whole job. One shape node, one draw call
- [x] **Stepped sweep** — eight jumps per leg instead of a smooth slide, sized
      from the same points-per-second, so the fleet marches rather than drifts
- [x] **Descent telegraph** — the formation dips twice on the beat before a drop
      (`FleetRules.telegraphsDescent`, one flag and one call site to remove)
- [x] **Chess moves leave the formation.** A black piece that plays chess is
      re-parented onto the board and stops being swept or dropped. Descent walks
      fleet membership rather than colour. Two populations that read differently
      — things that march, things that sit — beat one hybrid one, and engaging
      Black on the board now defuses arcade pressure instead of stacking with it
- [x] Fixed `GCIBoard.forcePlace` silently overwriting a same-colour occupant
- [x] Tuning pass: fleet sweep/step pace ×0.7 (`FleetRules.sweepSpeedScale`),
      grid and deployment-band alpha ×1.3

Pass: fleet sweeps indefinitely without drift, chess still fully playable, 60fps.

## Phase 3.2 — Shooting & Collision ⬜

The core shoot-em-up loop, and the phase that finally lets a run *end*.

- [ ] `SpaceshipState.swift` — lives, 2-shot laser cap, shield, respawn and
      invincibility timers (pure)
- [ ] `ProjectileState.swift` — ownership, damage, speed, active flag (pure)
- [ ] `LaserNode` + **`LaserPool`** — 6 player and 16 enemy nodes pre-created
- [ ] `CollisionResolver.swift` — pure damage/scoring/destruction outcomes
- [ ] `CollisionHandler.swift` — physics contact delegate; bitmasks per the
      `PhysicsCategory` table, rule decisions delegated to the resolver
- [ ] Fleet firing — shots per turn from the §21.1 table, weighted to front-rank
      pawns; Level 1 fires none
- [ ] Damage: player laser 2 HP, invader shot 1 HP, friendly fire 2 HP
- [ ] Shooting score wired (the chess-capture path already exists)
- [ ] **Real lose conditions**: 3 lives gone, black piece reaches rank 1, white
      king shot to 0 HP
- [ ] **Real win condition**: all black pieces destroyed clears the wave
- [ ] King shot at checkmate — the 800 bonus (§Scoring), the one scoring rule
      still unimplemented

Pass: a level completable by shooting alone, all damage and scoring correct.

Unblocks three things currently stuck: the HUD lives display (hardcoded to 3),
banking a score without having to lose at chess, and runs ending from arcade
pressure rather than chess grinding.

## Phase 3.3 — Damage States & Juice ⬜

- [ ] Smoke trail at ≤50% HP, sprite flicker at ≤25%
- [ ] Explosion on destruction (placeholder burst; per-piece art in Phase 8)
- [ ] Score pop-ups floating from destroyed targets, via a **`ScorePopPool`** of 20
- [ ] Screen shake per §24.1 intensities; hit freeze on high-value kills
- [ ] Arcade SFX — the keys are already mapped in `SoundKey`, they just need
      bundling and wiring (see the Phase 4 note on bundle size)

Pass: destroying pieces feels satisfying, performance unchanged from 3.2.

## Phases 5, 6.x, 7.x, 8, 9 ⬜

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
