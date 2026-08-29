# Implementation Checklist

Progress against the 15-phase plan in `gci-game-design.md` §20. Phase numbering is
the design doc's. Deviations get one line each — reasoning lives in the code.

✅ done · 🟡 partial · ⬜ not started

Ten levels play end to end, each with a mechanic of its own, with all five
power-ups, a settings screen, its own soundtrack and full arcade audio. Signed,
notarized and shipping as a DMG.

What a player would still notice: no level-clear fanfare or game-over riff of
their own, and no hyperspace jump between waves. Everything else outstanding is
production — a balance pass and an Instruments run.

The raiders are done and the rest of §6 is **cut** — no Escort, Flagship,
Kamikaze or Llama. Gameplay is feature-complete; what is left is production.

Full detail in **[Roadmap — what is left](#roadmap--what-is-left)** near the end
of this file. §20's phase numbers were a plan written before any of this
existed; they are a checklist, not a running order.

| Phase | Title                                       | Status                                                 |
|-------|---------------------------------------------|--------------------------------------------------------|
| 0     | Skeleton — app runs, title screen, music    | ✅                                                      |
| 1     | Chess logic                                 | ✅                                                      |
| 2.1   | Playfield: chess functional                 | ✅                                                      |
| 2.2   | Playfield: Recharged visual treatment       | ✅                                                      |
| 3.1   | Arcade layer: fleet movement                | ✅                                                      |
| 3.2   | Arcade layer: shooting & collision          | ✅                                                      |
| 3.3   | Arcade layer: damage states & juice         | ✅                                                      |
| 4     | Basic sound effects                         | 🟡                                                      |
| 5     | Background music + settings                 | ✅                                                      |
| 6.1   | Raiders: scout & basic escort               | ✅ — Scout built, Escort cut                            |
| 6.2   | Raiders: flagship, variants, special scouts | ✅ — special scouts built, Flagship and variants cut    |
| 7.1   | Level escalation: chess AI                  | ✅ — built with the level ladder                        |
| 7.2   | Level escalation: arcade mechanics          | ✅                                                      |
| 8     | Visual polish                               | 🟡 — score pops, banners, high scores, end screens done |
| 9     | Mac hardening & release                     | 🟡 — signed, notarized, shipping as a DMG               |

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

## Phase 2.1 — Playfield: Chess Functional ✅

- [x] `BoardNode` — coordinate mapping, selection, legal-move markers. The
      lattice, deployment bands and coordinate labels are off by default and
      come in together on the Display slider
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
- [x] Hidden `V` skips to the next level mid-game, keeping score and lives —
      no wave-clear overlay and no bonus, but the mechanic banner still
      shows, plus a brief SKIP LEVEL notice in the gutter
- [x] Auto Chess — `A` toggles it, and so does the Settings screen's CHESS
      control: one persisted setting, not two almost-identical modes. White
      auto-moves on a 1s beat, the gutter reads AUTO CHESS and the countdown
      hides, since at that beat it only flickers
- [x] Hidden `R` sends a raider in immediately — raiders are on a ~28s clock and
      most levels go quiet after one is shot down, so otherwise testing a
      power-up means waiting for a crossing that may never come. Successive
      presses walk the level's whole list and wrap, on a cursor of their own so
      looking at the third raider does not change what the clock sends next.
      Routed through the real launch path, not a shortcut of its own. It is a
      genuine override: it walks the level's roster as it *started*, so it keeps
      working after raids have ended for the wave — which is the case it mainly
      exists for, re-testing a power-up already collected once
- [x] Hidden `P` grants the next power-up outright, cycling through all five and
      wrapping. `R` exercises the crossing, the flight path and the hitbox; this
      exercises only the effect, which is the half that is otherwise unreachable
      when a level's roster does not happen to offer it. Routed through the same
      `activate` call the kill path makes, so a granted effect is
      indistinguishable from an earned one, and it awards no points — scoring
      belongs to the kill, not the effect
- [x] **Pause is Escape only.** `P` was one of §5's two pause keys and is now
      this test key; nothing user-facing named it, so nothing had to change on
      screen. Escape always pauses: §5's "cancel the chess selection first" was
      never built and is not wanted — clicking a different square already
      deselects, with a sound to confirm it
- [x] The log names the test keys on its first line, so they are written down
      somewhere they will actually be seen. Startup logging was trimmed at the
      same time: the app-launch and state-transition lines said nothing a
      timestamp did not, the starfield's sprite and action counts were a
      one-time measurement rather than a running fact, and the absent-sound
      count only ever counted files that are deliberately not bundled
- [x] Lives read from `SpaceshipState`, including on a HUD built mid-run

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

### Why the fleet moves as it does

Each of these is a readability rule, and the fleet was unplayable without them.

- **The sweep is bounded** to well under half a square end to end
  (`sweepAmplitudeRatio`), so a piece never drifts far enough to be ambiguous
  about which file it is on
- **The sweep is stepped, not continuous** — discrete jumps at the same overall
  pace. Smooth motion reads as drifting; stepped motion reads as marching
- **Descent paces off the chess beat**, not off wall bounces, so difficulty is
  not coupled to sweep width
- **The drop is split unevenly** (0.3 then 0.7). An even half-and-half parks the
  fleet on a rank boundary, which is the same ambiguity as horizontal drift on
  the other axis
- **A fixed grid** is drawn as a stationary reference, which the bounded sweep
  made worth having
- **A descent telegraph and capture tethers**, purely so the player can track
  where pieces actually are
- **A piece that makes a chess move leaves the formation**, rather than staying a
  hybrid that both marches and plays chess

## Phase 3.2 — Shooting & Collision ✅

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

### The level ladder

Built during 3.2 and now the game's whole shape. Level 10 is the last wave —
clearing it wins the run (`LevelManager.finalLevel`), where §10.1's "no ceiling"
left the game with no ending at all.

| L  | Banner         | Mechanic                                                                                                                                                                                                                                        |
|----|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | —              | Passive. One slow king warning shot at Critical (§10.1)                                                                                                                                                                                         |
| 2  | FIRE POWER     | Pawns fire back                                                                                                                                                                                                                                 |
| 3  | DOUBLE TROUBLE | Black moves twice                                                                                                                                                                                                                               |
| 4  | RELENTLESS     | Fire speed +30%                                                                                                                                                                                                                                 |
| 5  | TRIPLE THREAT  | Black moves three times                                                                                                                                                                                                                         |
| 6  | WIDE ORBIT     | Sweep widens to 1.5 squares                                                                                                                                                                                                                     |
| 7  | CROSSFIRE      | Bishops fire diagonals on their own cadence                                                                                                                                                                                                     |
| 8  | ARMORED PAWNS  | Half of every regenerated pawn arrives immune to lasers for three White moves                                                                                                                                                                   |
| 9  | KING ACTIVATED | King forcefield (+50% hits) and its own heavy weapon, fired straight down or leaning 9°–31° at a white piece                                                                                                                                    |
| 10 | BLITZ!         | ranks sweep out of phase with each other (`FleetRules.rankPhaseLag`), plus: 3s clock, three marching ranks, a sweep that widens 0.1 square every 4th lap with the march quickening 6% every 6th — **and Crossfire and Armored Pawns both back** |

Escalations persist except where a level's identity depends on not persisting.
Levels 7–9 each own a mechanic outright and hand it back, and Blitz takes them
all — except King Activated, which stays one wave's character.

### Combat, as it stands

- **White's auto-move pushes pawns** — a rank² term in the *evaluation*, not a
  bonus on the root move, or the shallow search sees Black take the pawn on the
  reply. Never set for Black, which promotes by breaching to rank 1
- **Promotion raises the laser cap** by one, stacking to six, reset each wave
  (Cadet carries it over). The cap is concurrency, not ammunition, so it pays
  only when shots are missing: 1.7 shots/second at two, 5.0 at six
- **Who shoots** — pawns from Level 2, bishops on the diagonal at Crossfire, the
  black king at King Activated. With no pawns left the rest take over, and at
  most half the gunners fire in a beat
- **Every round telegraphs for 0.35s** — the piece lights from within and a tick
  grows from its foot along the exact line the round will take
- **Angles** — bishops lean 17°–45° toward a real White piece at 160 px/s; the
  king inflects 9°–31° on 45% of its rounds, 30% faster to pay for the longer path
- **Rounds shoot each other down.** A deliberate departure from §20's bitmask
  spec, and a costly one: a laser eaten in flight still holds its slot
- **Formation membership goes both ways** — a chess move back into the band
  rejoins it, a descent sweeps up strays. The band has a front edge only, so its
  rear rank comes from the descent count rather than from where members are
- **A damaged piece keeps its identity** — a full-height slice of one side, 34%
  of the ink width, drawn from the undamaged texture underneath. The surviving
  side is the one the shot missed, fixed by the first hit

### Regeneration and armored pawns (§23.9, §10.1)

One system: armor arrives *only* through regeneration, so Level 8's banner is a
promise Level 4's regeneration has to be built to keep.

- **From Level 4**, after any black death — shot, captured or crushed — a pawn
  replaces it one beat later, capped by the level's slots (2 at Level 4, rising
  to 9). Kill to live pawn is 5.8s, or 4.8s at Blitz. The king never regenerates
- **A green RESPAWNING warning** flashes in the left gutter 1.5s ahead. It
  mirrors state rather than events, so simultaneous arrivals raise one warning
- **Arrivals go in front of the formation** — second rank, then third, then the
  back rank. This inverts §23.9: a regenerated pawn is a body in the way, worth
  far more shielding the queen than tucked behind her
- **1.8s transporter beam-in**, with no hitbox until it lands. Green-white
  normally, blue-white in defensive mode
- **Defensive mode** — once the black king is Cracked or worse, pawns
  materialise in front of him instead of scattering along the rear rank
- **Armored pawns** (Level 8, again at Blitz) — half of every regenerated pawn
  arrives immune to laser fire for three White moves, its hollow interior filled
  translucent green. Hits ricochet. Only a chess capture removes it, which is
  the point of the level: it asks the player to solve something with the board
- A regenerated pawn is worth 15 rather than 25 (§9), and `ChessEngine.forceAdd`
  keeps the engine's own board in step

### Traps worth remembering

Rules that were learned the hard way, kept as rules rather than as incidents.
Each one is a mistake that is easy to make again.

- **A parked projectile must clear its category, not just its contact test.**
  SpriteKit fires a contact when *either* body's test matches the other's
  category, so a spent round that keeps its category is an invisible mine sitting
  where it died. The handler also refuses any contact involving a round that is
  not in flight
- **`zRotation` turns a node's own axes.** A bolt's length is its y-axis, so an
  angled round aimed by rotation flies broadside. Aim from the travel vector, and
  give anything angled a circular hitbox so the angle cannot matter
- **Deactivate a round only after the board lookup succeeds**, or a hit that
  resolves to nothing deletes the round in mid-air
- **Release a fleet member by identity, not by square.** A stale key silently
  no-ops, and two crashes came from that
- **Anything that changes the board must tell the chess engine** — `applyDamage`
  and `forcePlace` alike, or the search moves pieces through what it cannot see
- **Scene `SKAction`s keep running while paused.** Anything that must not be
  lost to a pause belongs in the update loop, which only advances while playing;
  the respawn was an action that bailed if the game was not PLAYING on the frame
  it fired, and pausing in the second after dying threw it away
- **Nothing that renders may be keyed by a square that can change.** The fleet
  descends on the beat, so squares move underneath any handler that outlives a
  frame. Track the node
- **A missing texture or sound fails silently** — the texture draws a grey X and
  logs nothing, the sound simply does not play. Both are now checked by
  `typecheck.sh` and by the sound audit
- **Hitboxes follow the art, not the frame** — ink bounds measured and cached per
  texture
- **A pool must outlive the thing it serves.** `reset()` hides a pool's nodes
  without unparenting them, so rebuilding a pool per level orphaned 288 nodes
  and 40 physics bodies into the scene graph every time. Built once with the
  scene now
- **Clear the previous message before showing a new one**, or banners stack

### Deviations from the design doc

- The late order is Crossfire, Armored Pawns, King Activated — §10.1 has King
  Activated first and Armored Pawns last. Each of the three teaches something
  the next one is more interesting for, and the king reads best as the last
  thing before Blitz
- King Activated is arcade, not chess. §10.1 asks for aggressive King *play*; that was
  built and reverted — it measured as invisible in a full position, because the
  king's move never outscores thirty alternatives until the fleet is nearly
  cleared, and it read as chess rather than arcade
- Promotion does **not** destroy the nearest black piece. §7.2 and §24.9 give it
  a targeting beam that does; a free kill for reaching rank 8 is a large and
  arbitrary second prize on top of a reward that is already substantial, and it
  takes the decision of what to shoot away from the player at the moment they
  earned more shots
- Promotion does not raise the laser cap either — §7.2's Rapid Fire moved onto
  the green Raider Scout. Crowning a pawn is far too rare to be the only way to
  earn it; most runs never see one, so the reward effectively did not exist. The
  chess prize (a queen) is unchanged
- §13.1's "one Special Scout per level from L2, two from L5, chosen at random
  from the five types" is not built. The roster is a fixed table instead — one
  offer for most of the run, two at Level 8 and three at 9 and 10 — because a
  random draw means the player cannot know what is coming, and a power-up you
  cannot prepare for is a worse reward than one you can plan a wave around
- §6.2's escalating raider frequency is gone: §21.1's `raiderInterval` is
  overridden at every level by the clear-sky rule. Raider frequency is set by
  how much the level is offering, not by the level number
- Crossfire is Levels 7 and 10, not "8 onward" (§21.3), and it is the bishops'
  cadence rather than a 40% roll on a pawn's shot
- **Fleet rush is cut** (§7.2: "one random piece jumps 2 ranks forward after
  each full-rank descent"). It was written when the fleet's only vertical
  movement was the descent. There are now four other ways a black piece changes
  rank — a chess move out of formation, a rejoin, a crush, a regeneration
  beaming in — and the pieces are large enough that a fifth, unannounced,
  two-rank jump would read as a glitch rather than as pressure. It also
  shortens the run to a rank-1 breach in a way the player cannot see coming,
  which is the one lose condition that should never feel arbitrary
- Level 4 fires +30%, not §21.1's +11% — its banner already promised "FASTER,
  HARDER FIRE"
- Level 6's wide sweep knowingly breaks the sub-half-square readability rule.
  That is the level. Pinned by its own test so it stays deliberate
- Banner limits are 16/38 characters, measured against the real font, not
  §12.11's nominal 18/22
- Pawns take two laser hits (HP 2 → 3); one-shot pawns skipped the damage art
- Friendly fire on your own king deflects rather than killing it
- Destruction uses the kenney `explosionCrunch` ladder, graduated by length, in
  place of §12.12's gdc-bundle files (28 MB for four sounds, no better)
- Pause is Escape, not §5's "Escape and `P`". `P` is the power-up test key, and
  Escape always pauses rather than first cancelling a chess selection — clicking
  another square already deselects

## Phase 3.3 — Damage States & Juice ✅

`Juice.swift` holds §24's table — shake tiers and decay, freeze lengths, pop
timings, the venting threshold — as pure data, so "how hard does a queen shake
the board" is answerable and tested in one place.

- [x] **Explosion on destruction** — `ExplosionPool`, 8 pre-built bursts: an
      expanding ring plus 8 shards in the target's own glow colour, riding the
      bloom already on the parent. Not a particle system and not grey smoke,
      which reads as mud against neon on black. 2.4× for a king, which also gets
      §24.8's white flash
- [x] **Shattered glass on a survivable hit** — `ShatterPool`, 14 pooled:
      §24.5's impact flash plus 9 slivers in a 150° cone along the round's own
      heading, tumbling and then falling. Pooled apart from the destruction
      bursts, which fire far less often and must not be starved by them
- [x] **Score pops** — `ScorePopPool`, 20 pooled labels; +N rises 30pt over 0.8s
      in the target's colour. Shows `ScoreManager.scaled`, the same number the
      total moves by, so a pop can never disagree with the HUD
- [x] **Screen shake** (§24.1) — three events only: black queen 14pt, a life
      lost 20, black or white king 30. Deliberately scarce and deliberately
      large. Tiers for ordinary kills and for every landed laser were built and
      removed: a shake that turns up on every rook is scenery, and then the two
      kills that decide a wave are no longer announced by it. What makes it read
      is the offset — full amplitude every frame, alternating roughly 180°, so
      consecutive frames land on opposite sides; picking x and y independently
      averages half the amplitude and looks like blur. Applied to `bloomNode`
      rather than a camera, since a camera also changes how a mouse point maps
      into the scene and click-to-select depends on that
- [x] **Hit freeze** (§24.2) — the king's alone, 10 frames. §24.2 grades it
      across the queen and the flagship too; tried and cut, because those
      already shake and the two compete for the same job — a queen's 67ms was
      real input latency that then vanished underneath the shake behind it. On
      the king the contrast earns its keep and makes that death the one moment
      the game stops, which is why it is well past the doc's 2–4 ceiling. The
      playfield *and* the starfield pause — they are siblings, and stars still
      scrolling is most of what gives a hitstop away — while the scene's own
      `update` keeps running to time it. The explosion lands after the pause
- [x] **The spaceship explodes when it is hit** — §8.4 and §24.1's medium shake,
      both specified and never built: losing a life had been a sound, a hidden
      sprite and a HUD icon going out. Glass in two opposed sprays, since the
      ship is coming apart rather than being shot through. The last life gets the
      heavy shake and white flash otherwise reserved for a king
- [x] **Per-rank sweep at Blitz** — each rank lags the rank behind it, so a
      wave travels down the formation instead of the whole fleet moving as one
      body. `FleetRules.rankPhaseLag` is the entire feature and it is a dial:
      `.pi/4` ships (neighbouring ranks stay within half a square, files still
      read), `.pi` is the counter-march (twice the shear, expect the grid to
      stop reading), `0` restores the single-body sweep exactly. Built as one
      container per rank slot carrying only horizontal movement — drops and the
      rank descent stay on the fleet node, and nothing re-parents on a descent
      because every member moves down together, so the set in each slot never
      changes
- [x] **Venting at ≤50% HP** — drifting embers in the piece's glow colour, one
      every 0.28s, self-removing. Deviates from §20's "smoke": grey is mud here.
      Flicker at Critical was already in place from 2.2

Pass: destroying pieces feels satisfying, performance unchanged from 3.2.

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
- [x] Arcade SFX wired: player laser, per-piece impacts and destruction, fleet
      volleys, the king's and the bishops' own rounds, raiders, armor, the
      transporter, and all five power-ups
- [x] **Sound audit**, 27 Aug 2026: every `SoundKey` the code actually plays was
      checked against what is bundled. Six were silent in a running build — four
      of the five power-ups among them — because the files existed in `assets/`
      but had never been copied into `Resources/`. A missing file degrades
      silently by design (`AudioManager.preload` reports a count and moves on),
      which is right for unbuilt phases and exactly why this needed checking
      rather than assuming
- [x] Two GDC stems were library-length rather than game-length and are now
      trimmed with a fade: the nuke shockwave 17.3s → 2.4s (6.6MB → 0.93MB) and
      the armor ricochet 15.1s → 0.4s (5.8MB → 0.16MB)
- [x] Three sounds synthesised, since the doc marks them "generate with jsfxr"
      and no source exists: the two Ice Scout whooshes and §12.12's sub-bass
      fleet heartbeat (an 88→52Hz double-thump)
- [x] `lightningScoutDestroyed` removed — the Lightning Scout is retired, so
      there is no ship left to make the sound
- [x] **Dead assets removed** (27 Aug 2026). Nine sprites: the Escort, Flagship
      and Llama, which are cut; the five purpose-built special-scout sprites that
      were tried and lost to the drawn overlays; and `chess-b-pawn-armored`,
      which nothing ever loaded — armor is drawn as a tinted `Silhouette` fill
      over the ordinary pawn. Three sounds, all for cut raiders. Six `SoundKey`
      cases went with them, so the enum no longer promises features that are not
      coming
- [x] **The game-over sting resampled, 6.1 MB → 1.4 MB.** It was 192 kHz stereo,
      four times the useful rate, and on its own a third of the bundle.
      Resampled to 44.1 kHz with `afconvert`; stereo kept, so the only thing
      discarded is content above 22 kHz that nothing can hear. Verified rather
      than assumed: duration, peak and RMS across four slices of the envelope are
      identical to four decimal places. Resources are 10.3 MB, from 15.1
- [x] **Every GDC sound resampled to 44.1 kHz, and five downmixed to mono.**
      Which five was measured rather than assumed, from the RMS of each file's
      side signal against its mid. Three carry real width and keep it — the nuke
      shockwave most of all, which is §13.2's "resonant wave that sweeps across
      the stereo field" delivered rather than a coincidence
- [ ] **8 keys reference files that are not bundled**, all for features that were
      never built (escorts, the flagship) or large GDC stems not yet trimmed
      (`ambientSpaceLoop` 28MB, `mechanicBannerTier2/3`, `fleetRankDrop`).
      Nothing the game plays is among them, and `typecheck.sh` now fails if that
      stops being true

## Phase 5 — Music ✅

Every track was generated by **Zudio**, in its Motorik Arcade style, written for
GCI. `Pre-Solstice` holds the title screen and both panels — Settings and How To
Play — so it is what the game sounds like when you are not in it. The ten waves
each have their own.

Bundled as AAC at 80k/32kHz, re-encoded down from Zudio's 128k/44.1k export with
the embedded cover art stripped: as exported this was 28MB of music in a 7MB
app, and is 19.7MB across eleven tracks. `MusicLibrary` is the only table; adding
or swapping means a filename there and an `.m4a` in `Resources/`, and
`typecheck.sh` fails if the two disagree.

Chosen from 21 candidates on the Key, Tempo and Mood in each `.zudio` file
rather than by ear. Tempo climbs 125 → 156 with a deliberate dip at Wide Orbit,
a level that widens the sweep without being harder — it gets the brightest mode
in the set and a slower beat, a breath before Crossfire. Modes alternate
major-feeling and minor-feeling and never run three the same way. Blitz takes
the harmonic minor rather than the fastest track: both tracks above 150 BPM are
bright, and a cheerful finale would undercut a three-second clock worse than a
slower menacing one.

| Level                 | Track                        | Style         | BPM | Key              | Mood   |
|-----------------------|------------------------------|---------------|-----|------------------|--------|
| Title, Settings, Info | `Pre-Solstice`              | Kosmic Drift  | 88  | E Dorian         | Dream  |
| 1                     | `Leise-Dunkels`              | relaxed       | 125 | E Mixolydian     | Bright |
| 2                     | `WelleZ-Machine`             | intense       | 134 | E Aeolian        | Deep   |
| 3                     | `BlitzSchnork`               | peppy         | 138 | C Mixolydian     | Bright |
| 4                     | `Rattert-Z-Machine`          | peppy         | 140 | C Lydian         | Free   |
| 5                     | `Frankfurt-Overdrive`        | intense       | 140 | A Dorian         | Bright |
| 6                     | `KraftSchmaltz`              | peppy intense | 137 | A Lydian         | Bright |
| 7                     | `Bochum-Level`               | peppy         | 156 | C Phrygian       | Free   |
| 8                     | `SchnorkPunkt`               | focused       | 147 | B Mixolydian     | Dream  |
| 9                     | `Leipzig-1999`               | focused       | 147 | B Aeolian        | Bright |
| 10                    | `BierWunderwaffe`            | intense       | 140 | G Harmonic Minor | Free   |

Style is the word the composer attached to each export, and was one of the three
inputs to the ordering alongside tempo and mode. Not to be confused with the
`Style:` field inside a `.zudio` file, except for the intro, where they agree.
Every level track is **Motorik Arcade**, a Zudio style built for arcade music;
the intro is **Kosmic Drift** — slower and dreamier, which is why it sits under
a menu rather than a wave.

The full `.zudio` logs are in `assets/music/zudio-sources/` — structure, chord
plan, per-track note counts, and the generator seed, which recreates a track
exactly if a source is ever lost. Sixteen files, 64KB, including the intro's
(`Pre-Solstice`) and five unused backups: `Dora`, `Blank-Knall`, `Outer-Koln`,
`Neu-Leipzig` and `Weit-Z-Maschine`, each noted in `MusicLibrary` against the
slot it would replace.

### Alternates

The intro and the first two waves are heard on every single run, so each has one
alternate. Levels 3-10 do not — a player reaches them rarely enough that the
track is still a novelty.

| Original | Alternate | |
|---|---|---|
| `Pre-Solstice` (title, Settings, Info) | `Zephyron` | Kosmic, B Dorian 118 against E Dorian 88 |
| `Leise-Dunkels` (L1) | — | |
| `WelleZ-Machine` (L2) | — | |

- **Locked until the player reaches Level 3** in the session. A first run should
  sound the way the game sounds; this is for someone who has heard the opening
  several times. `X` re-locks it, like everything else it resets — the ordinary
  return from game over does not
- Once unlocked, **35%**, rolled independently for the intro and for each of the
  two waves
- **The intro is rolled on the way to the title screen and then held for the
  whole run.** It is heard in three places — the title, Settings, Info — and
  those must never disagree, so the value is settled once rather than defended
  at each call site. `startNewGame` (the `Y` answer) skips the title and so
  keeps what the last visit settled on
- **A wave's track is latched when the wave starts.** Closing a panel calls
  `restoreScreenMusic`, and a fresh roll there would swap the track underneath
  the player
- The mid-track panel entry is **only offered for `Pre-Solstice`** — 0:57-1:12 is
  a quiet stretch of that specific track. An alternate opens at the top until a
  window has been chosen for it
- A track with no entry in the table simply never varies, so an incomplete set
  degrades to the shipped behaviour rather than to silence

### Hand-overs

- **Level start** — 1.2s fade, then 0.5s of silence. A level start is a bigger
  seam than stepping into a menu, and cutting from one arcade track straight to
  another sounds like a mistake; the gap is what makes it deliberate
- **A panel opening** — 0.5s fade to `Pre-Solstice`, no gap, since that track opens
  on a fade of its own. Half the time it starts at 0:57–1:12 instead of the top,
  fading up over a second: a quiet stretch that sounds nothing like the opening
  notes, which somebody checking Settings four times a run would otherwise hear
  four times
- **Pause** — 0.3s to silence. Fast enough for the reason people pause, and
  short of the click a hard stop makes mid-bar
- All of it is `asyncAfter`, not `SKAction`: panels pause the scene, which stops
  actions for the whole tree

---

## Phase 6.1 — Raiders: Scout ✅

The only things in the game that run on a real-time clock rather than the chess
beat. Everything else — sweep, descent, fire, regeneration — is paced off the
turn, so the board pulses together; a raider ignores that entirely.

- **Raider Scout**: one acid-green shot straight down at 125% of the fleet's
  speed — floored at 180, because §21.1 gives Level 1 a projectile speed of
  *zero* and a zero-speed round never fires at all. 1 HP, 100 points, warbling
  as it goes
- **Shooting one grants Rapid Fire** — +1 laser slot, stacking to 6, reset each
  wave. This was §7.2's promotion reward; see the deviations below
- 220 px/s, and the constraint is the ship's 294: a scout the player cannot
  outrun can only be hit by already standing under it. Closing at 74 px/s means
  a missed pass is recoverable
- **One scout on screen at a time.** §6 caps raiders at two, written for a mix of
  scouts, escorts and a flagship; with the roster offering one kind at a time,
  two of the same ship is the same offer twice and there is no clear sky left
  between crossings
- On Levels 1–2 the scout does not arrive at all until the fleet's rear rank is
  down to half: the first one should be a reward for making progress, not one
  more thing to parse on an untouched board
- **A free first pass is owed once per kind, per run** — five in a run, one per
  new silhouette. §6 gives one every level, which spends its own rationale
  ("the player sees the attack pattern before being shot at") the first time and
  then keeps handing over a harmless raider forever
- The warble is a genuine looping player, owned by the controller rather than
  the node: it is an `AVAudioPlayer`, so `isPaused` and `removeAllActions` do
  nothing to it and every path that should silence it says so explicitly
- Solid grey-green hull under the outline. Every piece on the board is a hollow
  outline, which is right for pieces standing on squares; a ship passing in
  front of them has to occlude them or it reads as a decal
- `RaiderController` is the architecture the rest of 6.x hangs off — pool, cap
  and clock. §6.1's separate `Raiders.spriteatlas` is not built: the sprites are
  already in `GCI.spriteatlas`, and a second atlas costs a texture binding for
  nothing

Hidden `R` sends the next raider in on demand — see Phase 2.1's dev aids.

**Cut, not pending:** the Galaxian Escort, the Flagship, the Kamikaze and Paired
and Looping variants, King Protection Mode, and the Llama. See "Cut from §6 and
§7" in the roadmap for why. The Mutant Camel is built, as the Nuke's carrier.

## Phase 6.2 — Special Scouts & Power-Ups ✅

§13's power-ups, delivered the way §13.1 specifies: no pickup falls and nothing
is collected — shooting the scout *is* the power-up. That keeps the reward on the
arcade half of the game, where the player already has to aim.

### The roster

A fixed table of which raider each level sends. Every level has one answer, the
same answer every run — a raider whose identity is a surprise is one the player
cannot prepare for, which is the opposite of what a rare reward should be.

| Lv | Name           | Scouts, in order                | Power-ups, in order                         |
|----|----------------|---------------------------------|---------------------------------------------|
| 1  | —              | green                           | RAPID FIRE                                  |
| 2  | FIRE POWER     | green                           | RAPID FIRE                                  |
| 3  | DOUBLE TROUBLE | repair                          | SHIELD UP                                   |
| 4  | RELENTLESS     | ice                             | TIME FREEZE                                 |
| 5  | TRIPLE THREAT  | green → repair                  | RAPID FIRE → SHIELD UP                      |
| 6  | WIDE ORBIT     | spread                          | SPREAD FIRE                                 |
| 7  | CROSSFIRE      | camel → camel                   | NUKE → NUKE                                 |
| 8  | ARMORED PAWNS  | green → spread                  | RAPID FIRE → SPREAD FIRE                    |
| 9  | KING ACTIVATED | green → spread → ice            | RAPID FIRE → SPREAD FIRE → TIME FREEZE      |
| 10 | BLITZ!         | green → spread → repair → camel | RAPID FIRE → SPREAD FIRE → SHIELD UP → NUKE |

- **One kind at a time, and it keeps coming back until it is shot down.** Only a
  kill advances the roster; missing costs nothing but time. So how many raiders a
  wave sees depends on how long the player takes to hit one, and raids end when
  the roster is empty
- Every power-up **debuts on a level of its own** and **every one comes round
  again** — a mechanic met once and never used is not worth building. Both are
  pinned by tests
- Level 5 and Levels 7–10 send more than one. Level 7 sends the same carrier
  twice, which is where the player first meets a wave that does not go quiet
  after one kill; 5 and 8–10 stack different ones, cheapest first, so Rapid Fire
  is banked before the spray arrives
- The gap between crossings **tightens with the roster** — 22s / 15s / 12s for
  one, two and three-or-more offers — or a level advertising four power-ups would
  realistically hand over one

### The carriers

| Scout  | Speed            | Closing rate | Crossing | Flight                                   | Enters          |
|--------|------------------|--------------|----------|------------------------------------------|-----------------|
| green  | 205 px/s (0.93×) | 89 px/s      | 5.1s     | dead level                               | above the board |
| repair | 220 px/s         | 74 px/s      | 4.8s     | long eased glide, 55–95% of its headroom | above the board |
| ice    | 132 px/s (0.6×)  | 162 px/s     | 8.0s     | tight weave, ±46–60pt over 0.75–1.05s    | rank 4–5        |
| spread | 220 px/s         | 74 px/s      | 4.8s     | wide weave, ±74–104pt over 1.9–2.6s      | rank 5–6        |
| camel  | 176 px/s (0.8×)  | 118 px/s     | 6.0s     | one dive and climb, 70–95% deep          | above the board |

All 1 HP. §13.2 gives the Bomb Scout two "like the Flagship"; on a target that
small, fast and briefly on screen a survivable hit reads as a miss, not as a
challenge. `RaiderNode.takeHit` keeps the branch for a ship large and slow enough
to carry it, which is now cut.

- **Closing rate is what the player feels**, not speed. The ship has only 74 px/s
  of margin at full scout speed, which is why the green scout's modest 7% cut
  adds a fifth to the rate at which a chase closes. The camel is slower again
  because it is the only one that swoops, and a target moving fast vertically is
  hard to lead with a vertical laser
- **Flight is tied to the ship, not the level**, so the path is part of each
  carrier's identity and a second cue for what is on offer. Parameters are
  randomised per crossing, so a learned shape still has to be read. The green
  scout is flat *because* the others are not: it is the one the player meets
  first and chases most often, so it stays a pure horizontal aiming problem
- Both descending paths reach the player: at the steep end of their ranges they
  bottom out at y=136, inside the board's first rank and 54pt above the ship.
  Every path is checked to stay inside the 110–652 strip between the HUD and the
  ship's lane, at every lane its kind uses
- **Raiders face the way they are going.** The crossing is built as legs rather
  than one `moveTo`, so a raider that turns can turn to face. Only the camel has
  a front, but it applies to all of them rather than being special-cased
- **The Spread and Bomb carriers double back** partway and then carry on, never
  past their own entry point. Spread flips a coin at 20%, because it appears once
  a level and there is no second of its kind to play against. The camel does not
  gamble: **the first never feints and the second always does**, so on Level 7
  the first crossing teaches its path honestly and the one arriving where the
  player has just learned there is nothing more to expect turns around. Gated on
  what has actually been brought down this level, so the `R` test key cannot fake
  it

### The effects

- **Rapid Fire** — +1 simultaneous laser, stacking to 6, reset each wave
- **Shield** — absorbs one lethal hit plus 0.8s of grace, so the next round of
  the same volley cannot simply kill you. A hexagon, never a circle, so it is
  not confused with the black king's forcefield
- **Time Freeze** — 3s. Stops the fleet, raiders, enemy rounds, starfield and
  turn timer, and drops the music to `rate` 0.5. The player's own movement and
  fire are untouched, which is the whole effect
- **Spread Fire** — a swept hose, not a fan: one stream at 12 rounds a second,
  oscillating ±20° on a 1.8s sweep, for 7s, **only while the fire key is held**.
  §13.2's five fixed streams covered 244% of the board and ended the wave.
  Range is a ceiling at y=556 — the seventh rank is reachable, the eighth is
  earned the ordinary way
- **Nuke** — a magenta-to-white ring that clears every enemy round it passes and
  detonates up to three of the nearest black pieces, at least one wherever
  anything is left. Each victim gets a fragment thrown from the blast centre,
  timed to arrive with the ring. Armor still stops it. **The black king is
  passed over** while anything else stands, and takes 6 damage floored at 1 HP
  when he is all that is left. The blast runs at 0.3× for 1.3s, holding at the
  floor and then accelerating back
- Only the two clocked effects are exclusive (§13.1); a second replaces the
  first, and the displaced one has its world changes lifted first

## Roadmap — what is left

Grouped by what it is rather than by §20's phase numbers, and ordered within
each group by what it would cost to *not* have at ship.

### Audio leftovers (§20 Phase 5)

The screen and the soundtrack both shipped — see Phase 5. What §5 still asks
for and has not been built:

- [x] **Game over riff** — four bass downers, one picked at random per death
      (`SoundKey.gameOverPool`). Trimmed to 3.0s with a 0.8s fade and matched to
      −18 LUFS; the sources ran 3.7–8.0s and 13 dB apart, which would have made
      the random pick sound like a fault rather than a choice
- [ ] **Win theme.** `GameOverState` stops the music, so YOU WIN — the end of a
      full ten-wave run — lands in silence. The one ending with nothing behind it
- [ ] **High score entry bed.** Same silence, immediately after
- [ ] **Level clear fanfare.** `levelClear` currently plays a *descending* arp,
      which is the shape of a deny cue. Music continues into the next wave, so
      this is a wrong cue rather than a missing one
- [ ] **Music ducking** under priority SFX. `AudioManager.duckMusic` exists and
      nothing calls it

**Level banners get no sound — not building it.** `mechanicBannerTier1/2/3`
remain named and unbundled. A banner is a two-second fade in and straight back
out, already carried by the hand-over from one wave's track to the next; a third
theme in that gap would be introduced and removed before it registered.

### Cut from §6 and §7 — not building these

Decided rather than deferred. The raider system has enough in it: five carriers,
five power-ups, five flight paths and a roster that changes every level.

- **Galaxian Escort, Flagship, Kamikaze, Paired and Looping Escorts** (§6.1,
  §6.3). The whole dive family, which would have needed a new motion model —
  everything built crosses the screen horizontally. What they were for, a raider
  that comes *at* the player rather than past them, the Bomb Scout's swoop
  already does
- **King Protection Mode** (§6.3) — raiders plugging an open lane to the black
  king. The best unbuilt idea in the doc, and it goes with the dive family it was
  written for
- **The Llama** (§6.4). The Mutant Camel flies as the Nuke carrier, so the Minter
  homage is paid; a second tribute ship on the score tally would be repeating a
  joke that has already landed. `ship-llama` stays in the atlas
- **Fleet rush** (§7.2) — one random piece jumping two ranks after each descent.
  Cut long before the others, for its own reasons, recorded under deviations
- `RaiderController`'s pool, cap, clock, roster and flight-path model would have
  carried all of it. It is a seam that will not now be used, which is the right
  outcome to record rather than quietly leave open

### Visual polish (§20 Phase 8)

Much of this phase landed early — score pops, banner animations, the high score
table, the game over and level clear screens, per-piece destruction sounds. What
is genuinely outstanding:

- **Wireframe debris — not building it.** §12.4's fourth parallax layer. The
  background has enough in it now: three star tiers, a per-level haze and a
  cycling title sky. A layer of geometry drifting in front of the board would
  compete with the pieces, which are the thing that has to be read. §12.4 is
  settled at three star tiers plus the nebula
- [x] **Background evolution per level** (§12.5) — `BackdropNode`, shipped 0.3.
      One additive sprite behind the starfield and outside `bloomNode`, keyed to
      each level's mechanic. Blitz also runs the starfield 1.35x, multiplied
      into the slow-motion scale rather than replacing it. See **Nebula
      palette** below
- **8-frame explosion sprite sheets — not building them.** The pooled particle
  bursts, tinted per piece, read well enough that sprite sheets would be work
  for no visible gain
- [ ] **Hyperspace jump on level clear.** Deferred, not cut
- **Attract mode — not building it.** §14.2's 5-slide cycle is a coin-op
  convention: a cabinet nobody is standing at has to sell itself to the room. An
  app someone chose to launch is already past that, and a window that starts
  playing to itself is just odd. The title screen does the job instead — a haze
  cycling through the palette and a raider crossing every 25–35 seconds

### Nebula palette (§12.5)

The void stays near black and the haze carries the change — §12.5's own table
(`#07070F` to `#160304`) is a few RGB points against black under bloom. Keyed to
each level's mechanic rather than ramped cold-to-hot: a linear red ramp says
"later", this says *which* wave you are on. The title screen cycles the palette
over 72s.

| Level | Void      | Haze                                   | Why this colour                                                                                                                   |
|-------|-----------|----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| 1     | `#000000` | none                                   | The reference every later level is read against                                                                                   |
| 2     | `#03040A` | indigo, very faint, low                | FIRE POWER — the faintest first hint, barely there                                                                                |
| 3     | `#04050C` | indigo, low and wide                   | DOUBLE TROUBLE                                                                                                                    |
| 4     | `#06050E` | indigo                                 | RELENTLESS — the same, deeper                                                                                                     |
| 5     | `#08040F` | violet                                 | TRIPLE THREAT                                                                                                                     |
| 6     | `#0A0410` | violet, spread wider                   | WIDE ORBIT — the haze widens as the sweep does                                                                                    |
| 7     | `#0D0412` | magenta, diagonal grain                | CROSSFIRE — the grain lies along the bishops' own diagonals                                                                       |
| 8     | `#0A0C08` | aqua-green                             | ARMORED PAWNS — the armour's colour, lightened and cooled; its own saturated green read as sickly. Deliberately off the heat ramp |
| 9     | `#100509` | amber, glowing from the top rank       | KING ACTIVATED — the light comes from where he sits                                                                               |
| 10    | `#140306` | crimson, and the starfield accelerates | BLITZ                                                                                                                             |

### Shipping (§20 Phase 9)

Signing, notarization and direct distribution are done — `release-dmg.sh` wraps
an Xcode-exported app, and 0.4 is out with an icon and a green test suite. What
is left:

- [ ] **Balance pass from outside playtesters.** §9's own criteria: is Level 1
      learnable in one attempt, Level 3 urgent, Level 5 overwhelming-but-fair
- [ ] **Instruments passes** — Allocations over 30 minutes for leaks, Time
      Profiler for the frame budget
- [ ] **App Store**, if it ever goes there: screenshots and metadata. The
      sandbox entitlements and hardened runtime are already in place

### Not scheduled

- **iOS / iPadOS port** — `gci-game-design.md` Appendix A. Wanted eventually, not
  now. The architecture rules that keep it possible are followed regardless: the
  logic layers import no SpriteKit or AppKit, and all input arrives as
  `GameAction`

---

## Performance

### Measured

- Depth-2 search: **0.40ms** from the opening, **1.95ms** midgame, against a
  50ms budget. The engine is not a bottleneck and needs no pruning
- 1,000 legal-move generations: 5.6ms against a 100ms budget
- `Board.pieces()` walks the occupied mask rather than all 64 squares; it runs at
  every search leaf
- Diagnostics publish at 4Hz, not per frame — `DiagnosticsLog` is `@Observable`,
  so per-frame writes invalidated the sidebar 60 times a second
- Starfield is ~170 batched sprites in one draw call; `SKShapeNode` cannot batch
  and would have cost one draw call each

### Done

The scene graph is flat across a session and the frame cost does not grow with
time played. What holds that:

- **Pools are built once with the scene, not per level.** `reset()` hides a
  pool's nodes without unparenting them, so rebuilding one orphaned 488 nodes —
  40 with physics bodies — into the graph for the rest of the run
- **`didMove(to:)` is guarded against running twice.** The scene is a singleton
  and SwiftUI can present it again on a window rebuild; nothing in `setupScene`
  was idempotent, and a second `bloomNode` means a second full-screen CIBloom
  pass every frame
- **`bloomNode.shouldRasterize` is off.** Every moving thing in the game is a
  child of it, so the cache was invalidated every frame and never read
- **Log messages are `@autoclosure`**, and the log trims in chunks of 200 rather
  than one line at a time — `removeFirst()` shifts the whole array
- **The FPS readout averages every frame in its window** instead of sampling one

Where that leaves it:

| Metric | Current          |
|--------|------------------|
| CPU    | ≤55% on Level 10 |
| nodes  | <900, flat       |
| FPS    | 45–63            |

Measured on an M4 (10 cores), Debug, with the diagnostics sidebar open — the
worst case, and slower than what ships: Swift at `-Onone` is several times
slower than `-O`, and a laptop downclocks under sustained load, so a percentage
that drifts upward over ten minutes is not necessarily more work.

### Considered and not needed

Each was investigated and left alone. Recorded so they are decisions rather than
oversights, and so the next person does not re-derive them.

- **`ignoresSiblingOrder`** is not set on the view. With explicit `zPosition`
  everywhere it would let SpriteKit reorder draws within a z-layer to batch by
  texture. Not worth it unless `showsDrawCount` (wired to the sidebar) shows a
  count worth cutting
- **Per-frame `SKLabelNode.text` writes.** `TurnTimerNode.refresh` writes both
  labels every frame while White may move, so a value that changes once a second
  is rebuilt sixty times; `syncPowerUpAlley` does the same for up to three lines.
  Guarding each write on an actual change is a few lines, and worth doing if that
  code is touched anyway — but it is not why anything is slow
- **`childNode(withName:)` in the per-frame path** — five lookups a frame, each a
  linear scan of `bloomNode`'s children
- **`rearRankPieces` runs every frame on every level.** Passed as an argument to
  `raiders?.update(...)`, so it is evaluated unconditionally: two array
  allocations plus a string parse per piece, and it is only *used* on Levels 1–2
- **CIBloom is a full-screen Core Image pass every frame.** The alternative is
  pre-blurred additive sprite copies per glowing node, trading GPU fill for draw
  calls and node count. A large change to the look as well as the cost, and the
  look is the game's whole identity

**Already handled, for the record:** the starfield is ~196 sprites sharing one
texture in a single draw call; `Silhouette`'s flood fill is measured once per
texture and cached; diagnostics publish at 4Hz; every laser, explosion, score
pop, shatter and raider is pooled, so gameplay allocates nothing.

## Tests

`GalacticChessInvaders/Tests/GCITests.swift` — 348 XCTest cases covering the
chess model, fleet, raiders, power-ups, scoring, audio assets and layout
geometry. **Run them with `⌘U` in Xcode**; the whole suite takes about a minute,
most of it the perft.

- **Why.** `ChessPerftTests` walks the standard reference positions to depth 4
  (~11M nodes) and must match the published counts exactly. Any change to move
  generation goes through it. The rest pin decisions that are otherwise silent
  when broken — the §7.1 damage table, the raider ladder, gutter layout
- **Debug is not sandboxed** — `GalacticChessInvaders-Debug.entitlements`.
  CoreAudio's analytics client aborts under the sandbox rather than degrading,
  which kills the whole run at launch. Release is sandboxed, hardened and signed
- The suite shares one `GameScene.shared`, so a test that drives the state
  machine must put it in a known state first

## Errors are visible without the log

Most people playing — testers included — do not have the log panel open, so a
fault nobody notices is a fault nobody reports. Anything logged at `.error`
bumps a counter, and the scene raises a magenta **`ERROR - SEE LOG`** flag in the
bottom-left corner, above the level banners. `X` clears both.

What can raise it:

| Error                                    | Meaning                                                                                                                                           |
|------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| `ghost <piece> <square> …`               | A destroyed piece still on the board a second later. Reports its alpha, board state and full ancestor chain, so the line names what is holding it |
| `<color> <piece> <square> had no hitbox` | A piece that cannot be shot. Repaired on the spot, and reported anyway                                                                            |
| `Legal-move markers exhausted`           | More destinations than the pool holds — some would silently not draw                                                                              |
| `Music not found: <track>.m4a`           | A `MusicLibrary` entry with no file behind it                                                                                                     |
| `sfx bundle directory not found`         | No sound effects at all will play                                                                                                                 |
| `Font not found in bundle`               | Press Start 2P missing; everything falls back to Helvetica                                                                                        |

The first two come from sweeps that run at 4Hz during play. The last four fire
at startup or on first use.

## Changing assets

Every asset failure here is silent: a missing texture draws a grey X and logs
nothing, a missing sound does not play, a missing font falls back to Helvetica
and the game still runs. So `typecheck.sh` checks for them on every invocation,
and fails:

| Check                             | Catches                               |
|-----------------------------------|---------------------------------------|
| Sprites named in code exist       | A texture that would draw a grey X    |
| Sounds the code *plays* exist     | A cue that would go silent            |
| Music named in `playMusic` exists | A track that would not start          |
| Fonts named in code exist         | Every label falling back to Helvetica |

Only sounds the code actually calls `play`/`stop` on are required, because
`SoundKey` deliberately names cues for features that were never built.

`./typecheck.sh --assets` adds two advisory reports, which are the ones to run
*before* adding or removing anything:

- **Files backing more than one key.** A file added for one cue may already be
  serving another, so deleting "the one I added" silences something else
- **Bundled files nothing names**, with their total size — dead weight in the
  DMG, and the other direction of the same mistake

Two rules that no script can enforce:

- **Delete by key, not by filename.** Find the key that owns the asset, remove
  it, then check whether any other key still resolves to that file
- **Adding a file to `assets/` does not bundle it.** The app loads from
  `Resources/`; the two are copied by hand and have drifted twice

## Verification notes

- `typecheck.sh` runs two passes (sources, tests) at Swift 6 strict concurrency,
  and fails if a source on disk is missing from `project.pbxproj`. **New files
  need `xcodegen generate`** or Xcode won't see them
- `-typecheck` does **not** catch sending-risks-data-race errors (SIL stage
  only). A real build is the authority
- **`typecheck.sh`'s `-typecheck` mode can silently miss real errors** when
  `swift-plugin-server` fails to expand `@Observable` (`DiagnosticsLog`,
  `ScoreManager`): it suppresses unrelated diagnostics for the rest of the
  module, so a genuinely broken reference reports "no errors". The script
  detects the plugin failure and fails the whole run rather than filtering it
  out — a clean run is only trustworthy when it says so
- `ChessPerftTests` pins move generation against the standard reference
  positions. If those counts drift, the rules have regressed

## Known compromises

Deliberate, and not worth fixing without a design conversation:

- `GameOverNode`, `HighScoreEntryNode` and `HowToPlayNode` each have their own
  `label(...)`. They look identical and are not
- `GameState.swift` imports SpriteKit and calls into `GameScene` — the one
  Logic-layer file that breaks the architecture rule. `GameScene` also writes
  `DiagnosticsLog.fps`/`.nodeCount`, which is Rendering writing into Logic. Both
  pre-date the rule
- Dead but kept as accurate phase markers: `LaserNode`'s Phase-1 stub,
  `SpaceshipNode`'s shield API, `GameAction.confirmRestart` / `.returnToMenu`,
  and the `SoundKey` cases with no asset yet
