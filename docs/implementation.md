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
| 3.1 | Arcade layer: fleet movement | ✅ |
| 3.2 | Arcade layer: shooting & collision | 🟡 |
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
- [x] Escape while entering a high-score name records the entry with a blank
      name rather than trapping the player in the prompt or discarding the score
- [x] **Keyboard focus.** "PRESS ANY KEY TO START" ignored every key until the
      player clicked — a focus bug, not an input-mapping one. The diagnostics
      sidebar's log is a *selectable* `NSTextView`, so it accepts first
      responder, and the sidebar is on by default in debug builds: AppKit gave
      it the initial focus and it swallowed every keystroke. Clicking the game
      moved focus to the `SKView`, which is why keys worked afterwards.
      `KeyboardFocusedSKView` claims focus on `viewDidMoveToWindow` and again on
      the next run-loop turn. Reproduced in isolation to confirm: 0 keys reach
      the scene without it, 1 with
- [x] Pausing: any key **or** mouse click resumes, and the banner says so.
      Previously only Escape/P were mapped while paused, so every other key did
      nothing with no indication why
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

## Phase 3.1 — Fleet Movement ✅

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
- [x] Playtested and reworked over several rounds — see below

### Playability: what was tried, what stuck

The first build was unplayable. What got it there, in brief:

- Unbounded horizontal sweep let pieces drift off their true file —
  unreadable. **Constrained the sweep** to well under half a square
  (`sweepAmplitudeRatio`, 0.35 → 0.7 of a square total).
- Descent tied to wall bounces coupled difficulty to sweep width. **Decoupled
  it** — descent now paces off the chess beat instead.
- An even 0.5/0.5 two-step drop left the fleet parked on a rank boundary —
  same ambiguity as the horizontal drift, other axis. **Split it unevenly**
  (0.3 then 0.7) instead.
- A smooth continuous sweep read as drifting, not marching. **Stepped it** —
  discrete jumps at the same overall pace.
- Constraining the sweep retired the original reason for having no grid.
  **Added a fixed grid** as a stationary reference.
- **Added a descent telegraph and capture tethers**, purely to help the
  player track where pieces actually are.
- **Chess-move pieces now leave the fleet formation** rather than staying a
  hybrid piece that both marches and plays chess.
- Speed, amplitude and grid brightness were each tuned twice more after that,
  directly against user feedback.

Pass: fleet sweeps indefinitely without drift, chess still fully playable, 60fps.

## Phase 3.2 — Shooting & Collision 🟡

The core shoot-em-up loop, and the phase that finally lets a run *end*.

- [x] `SpaceshipState.swift` — lives, 2-shot laser cap, respawn/invincibility
      timer (pure). Shield is a later power-up, not built here
- [x] `ProjectileState.swift` — ownership, damage, speed (pure)
- [x] `LaserNode` + **`LaserPool`** — 6 player and 16 enemy nodes pre-created,
      never removed from the scene graph. No projectile art exists yet, so the
      beam is a solid tinted rect — the existing bloom filter glows it for free
- [x] `CollisionResolver.swift` — pure damage/scoring/destruction outcomes
- [x] `CollisionHandler.swift` — physics contact delegate; identifies who
      collided from `PhysicsCategory` bitmasks and reports it through
      callbacks, same pattern as `FleetController`'s `onCrush`/`onRankDescended`.
      Bitmasks follow the design doc's own Phase 3.2 spec exactly: the player
      laser tests only pieces, never the ship or an enemy shot directly
- [x] Fleet firing — once per beat, after the position settles (same reasoning
      as fleet descent: never races a chess move for the same square); shot
      count and front-rank weighting live in `FleetFiring.swift` (pure)
- [x] Damage: player laser 2 HP, invader shot 1 HP, friendly fire 2 HP
- [x] Shooting scores at the higher table (§9); chess captures were quietly
      using the *shoot* value since it was the only one that existed — fixed to
      use the correct, lower `chessCaptureValue`
- [x] **Real lose conditions**: 3 lives gone, a black piece reaching rank 1
      (previously just halted the fleet), white king destroyed by anything
      other than checkmate (shot, or crushed by fleet descent)
- [x] **Real win condition**: the black king falling — by checkmate, chess
      capture, fleet crush, or the player's laser — all four read as the same
      win (§25.2's "the mission is the King"), and continue into the next wave
      exactly like checkmate already did. "All pieces destroyed" isn't a
      separate check: the last piece standing is necessarily the king, which
      the king-fall check already catches
- [x] King shot at checkmate — the 800 bonus. The window is real: a beat that
      delivers mate doesn't formally end until it resolves, so the king can
      still be shot while already checkmated

**A real bug fixed along the way, same class as `forcePlace`:** `GCIBoard
.applyDamage` only ever updated the arcade-facing `pieces` dictionary, never
the chess engine's own board. A laser kill was the first thing to actually
exercise `applyDamage` in production, so this had been latent since the field
was written. Fixed with `ChessEngine.forceRemove(at:)`, the same fix shape as
`forceRelocate`.

**Judgment calls made without an explicit spec answer:**
- Player laser speed is 400 px/s — the design doc's own §20 Phase 3.2 testing
  section states this explicitly; it is not a guess
- Enemy laser origin/travel distance derived from the fleet piece's *drawn*
  position (sweep offset included), consistent with how check-paths and
  tethers already resolve a fleet piece's real screen position
- `.blackMated`, a `GameOverNode.Outcome` case, was already dead — never
  constructed anywhere, a leftover from before wave-clear existed. Removed
  while touching this enum for the new win/lose cases

**Playtest #1 found three real defects, all fixed:**
- **No collisions at all.** Every physics body was created `isDynamic = false`.
  SpriteKit only evaluates a contact pair when at least one body is dynamic —
  two static bodies never produce a `didBegin` callback, so lasers passed
  straight through pieces: no damage, no explosion, no score. The laser is now
  the dynamic half (gravity off, no collision response, SKAction-driven as
  before); pieces and the ship stay static. Verified empirically against a real
  render loop — static/static reports 0 contacts, one dynamic reports the hit —
  and pinned by `LaserPhysicsTests`
- **Enemy shots spawned off-target.** They used `drawnPosition`, which is
  board-local — correct for check paths and tethers, which are `boardNode`
  children — but lasers live in `bloomNode`, and the board is inset within it.
  Every fleet shot appeared a board-origin down and to the left. Now converted
  through `laserOrigin(forFleetSquare:)`
- **Silent.** Every sound the shooting loop asks for was in the "not yet
  bundled" set, so the whole arcade layer had no audio. Added
  `SoundKey.placeholderFilename` — `filename` stays the canonical intended
  asset, and a stand-in from the 12 bundled files is used only when the real
  one is absent. The startup log now reports how many keys are on placeholders,
  so a stopgap is never mistaken for finished sound design
- **Damage was invisible until a piece moved.** Two causes, both fixed. The hit
  path called `applyHitFlash()` but never `refresh(with:)`, so a surviving
  piece kept its full-HP sprite until some *other* event happened to refresh it
  — in practice only a chess move, which is why damage appeared to "arrive"
  late. And `damageState` used remaining-HP ratio buckets rather than §7.1's
  explicit table, which ran a full stage behind on rook, queen and king: a
  rook's first hit (8→6 HP) still resolved to `.full`. Six of the twenty
  reachable states disagreed with the doc, every one of them hiding damage.
  Ruled out rasterization as a cause first — a texture swap inside a
  `shouldRasterize` effect node does repaint, verified against a real render loop
- **The sounds were never missing — they were never copied.** `assets/sfx/`
  holds the full 132-file library, already converted to `.caf`; only 16 files
  had ever been copied into the bundled `Resources/sfx/`. Copied the 10 the
  shooting loop needs (+0.8 MB), so lasers, impacts and explosions all play
  their real assets. A short-lived placeholder-fallback mechanism written before
  spotting this has been removed — it solved a misdiagnosed problem
- **Destruction remapped onto the kenney `explosionCrunch` ladder**, which is
  conveniently graduated by length (0.78 / 1.26 / 1.36 / 1.55 / 1.98s) so a
  bigger piece gets a longer boom, and `_004` lands exactly on §12's "~2
  seconds" for the king. Four of these were specced to gdc-bundle files of
  2.5–15.5 MB each; a 15 MB bishop death is not shippable, and 28 MB for four
  sounds bought nothing over 0.6 MB of kenney audio. Deviation from §12.12,
  taken on size
- Added `SHOOT` diagnostics for both fire paths. Their absence is why the
  playtest log gave no clue — the shooting loop was completely invisible in it

**Not yet done:** visually verified in the running app. Confirmed instead via
a trustworthy typecheck pass (macro-plugin flakiness ruled out first), a
standalone runtime harness exercising every pure Logic path (31/31 checks:
`SpaceshipState`, `CollisionResolver`, `FleetFiring`, the scoring tables), and
a clean signed build. Launching the app to drive it interactively was denied
in this environment — there is no GUI automation available here for a native
macOS app, unlike the iOS simulator tooling. A firing/hit/lose/win playtest
pass is the next real step before trusting this beyond "it typechecks and the
logic is right in isolation."

Unblocks three things that were stuck: the HUD lives display (was hardcoded
to 3), banking a score without having to lose at chess, and runs ending from
arcade pressure rather than chess grinding.

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
- **`typecheck.sh`'s `-typecheck` mode can silently miss real errors** when
  `swift-plugin-server` fails to expand `@Observable` (`DiagnosticsLog`,
  `ScoreManager`) — observed to suppress unrelated diagnostics for the rest of
  the module, so a genuinely broken reference reported "no errors" three runs
  in a row. `typecheck.sh` now detects the plugin failure and fails the whole
  run rather than filtering it out; a clean run is only trustworthy when it
  actually says so. A real build remains the authority regardless
- **Fixed a serious desync between the chess engine's own board and the
  rendering-facing `pieces` dictionary.** `GCIBoard.forcePlace` (the fleet's
  only way to move a piece) updated `pieces` but never told `ChessEngine`'s own
  `position` — so after any descent, the engine went on believing every
  descended piece was still at its pre-descent square, forever. When the
  engine later proposed a move from that stale square, `applyChessMove` looked
  up whichever piece had since occupied it *for real* and moved that one
  instead. Reported directly from playtest as two pieces rendered on the same
  square; reproduced and pinned with a standalone harness before fixing, since
  `swift-plugin-server` flakiness was actively unreliable at the time. Fixed
  by `ChessEngine.forceRelocate(from:to:)`, called from `forcePlace`

## Full-codebase review

Three parallel agents (logic, rendering, input/audio/app) read every source
file. Findings, and what was done about each:

- [x] `NeonPalette.swift` — the cyan/magenta/orange constants were copy-pasted
      verbatim into 8 rendering files plus a handful of inline literals in
      `GameScene.swift`/`SpaceshipNode.swift`. Now one shared enum; every file
      keeps its own `private static let cyan = NeonPalette.cyan`-style alias,
      so no call site changed. Orange turned out to be two *deliberately*
      distinct shades (UI chrome vs. a hotter title-screen/AUTO-flash accent)
      — kept both, named `orange` and `alertOrange`, not merged
- [x] Stale header comments in `ChessRules.swift`, `ChessFEN.swift`,
      `Chess.swift` claiming castling/en passant are absent and there's no
      fifty-move/threefold tracking — all three are implemented; the comments
      were simply never updated when that changed. Corrected
- [x] `InputHandler.swift` — Escape and P each had their own `case ... : return
      isDown ? .pause : nil` line; collapsed to one `case 53, 35:`
- [x] `GCITests.swift` — the FEN-to-`Position` unwrap helper was duplicated
      verbatim across `ChessRulesTests` and `AutoMoveTests`; moved to a shared
      `XCTestCase` extension
- [x] `AudioManager.setVolume(_:for:)` — zero call sites anywhere, removed
- [ ] `GameOverNode`/`HighScoreEntryNode`/`HowToPlayNode` each have their own
      `label(...)` builder. Looked like the same boilerplate; on inspection
      they're not identical (`HowToPlayNode`'s uses baseline vertical
      alignment and a variable horizontal alignment; `GameOverNode`'s sets a
      `zPosition` the others don't). Left alone — collapsing them safely would
      need a more flexible shared signature than the ~20 lines saved justify
- Confirmed dead but left alone as accurate phase-status markers, not bugs:
  `LaserNode.swift` (unreferenced, Phase-1+ stub), `SpaceshipNode`'s
  shield/invincibility API (unreferenced), `GameAction.confirmRestart` /
  `.returnToMenu` (never constructed), ~40 `SoundKey` cases with no asset yet
  (already self-reported by `AudioManager.preloadAll`'s own log line),
  `.fireLaser` (dispatched by Space, no handler yet)
- Noted, not changed — real but out of scope for a mechanical pass:
  `GameState.swift` imports SpriteKit and calls into `GameScene` directly,
  the one Logic-layer file that isn't SpriteKit-free per the architecture
  rule; `GameScene` writes `DiagnosticsLog.fps`/`.nodeCount` (Rendering
  writing into Logic state). Both are pre-existing structural choices, not
  something to "fix" without a design conversation
- Checked and NOT a bug: `PlayingState.didEnter`'s hardcoded `"Level 1
  started"` log line. Verified it only ever fires on a fresh game (Title →
  Playing); leveling up 2+ takes a different path (`GameScene.startNextLevel`)
  that logs the real level number without re-entering `PlayingState`
