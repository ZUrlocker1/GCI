# Implementation Checklist

Progress against the 15-phase plan in `gci-game-design.md` §20. Phase numbering is
the design doc's. Deviations get one line each — reasoning lives in the code.

✅ done · 🟡 partial · ⬜ not started

Ten levels play end to end, each with a mechanic of its own. What is left, in
the order it is worth doing rather than the order §20 numbers it:

1. **Raiders** (6.x) — the Scout flies; the Galaxian Escort, the Flagship and
   the special scouts are next. Every sprite is already in the atlas
2. **Music and settings** (5), then polish and release (8, 9) — craft work that
   interacts with nothing and can happen whenever

§20's phase numbers were a plan written before any of this existed. They are a
checklist, not a running order.

| Phase | Title | |
|---|---|---|
| 0 | Skeleton — app runs, title screen, music | ✅ |
| 1 | Chess logic | ✅ |
| 2.1 | Playfield: chess functional | 🟡 |
| 2.2 | Playfield: Recharged visual treatment | ✅ |
| 3.1 | Arcade layer: fleet movement | ✅ |
| 3.2 | Arcade layer: shooting & collision | ✅ |
| 3.3 | Arcade layer: damage states & juice | ✅ |
| 4 | Basic sound effects | 🟡 |
| 5 | Background music + settings | ⬜ |
| 6.1 | Raiders: scout & basic escort | 🟡 — Scout done, Escort next |
| 6.2 | Raiders: flagship, variants, special scouts | ⬜ |
| 7.1 | Level escalation: chess AI | ⬜ |
| 7.2 | Level escalation: arcade mechanics | ✅ |
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
- [x] Hidden `V` skips to the next level mid-game, keeping score and lives —
      no wave-clear overlay and no bonus, but the mechanic banner still
      shows, plus a brief SKIP LEVEL notice in the gutter
- [x] Hidden Auto Mode — `A` toggles; White auto-moves on a 1s beat, labelled
      TEST MODE in the gutter and logged; ends automatically at mate/stalemate
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

| L | Banner | Mechanic |
|---|---|---|
| 1 | — | Passive. One slow king warning shot at Critical (§10.1) |
| 2 | FIRE POWER | Pawns fire back |
| 3 | DOUBLE TROUBLE | Black moves twice |
| 4 | RELENTLESS | Fire speed +30% |
| 5 | TRIPLE THREAT | Black moves three times |
| 6 | WIDE ORBIT | Sweep widens to 1.5 squares |
| 7 | CROSSFIRE | Bishops fire diagonals on their own cadence |
| 8 | ARMORED PAWNS | Half of every regenerated pawn arrives immune to lasers for three White moves |
| 9 | KING ACTIVATED | King forcefield (+50% hits) and its own heavy weapon, fired straight down or leaning 9°–31° at a white piece |
| 10 | BLITZ! | ranks sweep out of phase with each other (`FleetRules.rankPhaseLag`), plus: 3s clock, three marching ranks, a sweep that widens 0.1 square every 4th lap with the march quickening 6% every 6th — **and Crossfire and Armored Pawns both back** |

Escalations persist except where a level's identity depends on not persisting.
Levels 7–9 each own a mechanic outright and hand it back, and Blitz takes them
all — except King Activated, which stays one wave's character.

### Combat, as it stands

**White's auto-move pushes pawns.** Promotion is worth reaching, and a depth-2
search can never see it coming — a pawn on rank 2 is six moves from rank 8, so
the reward is invisible and the engine advances a pawn only by accident. A
White-pawn advancement term in the evaluation (rank², `pawnAdvanceStep`) lays a
gradient the shallow search can climb. It has to be in the *evaluation*: a bonus
on the root move was tried and measured at 3% of games promoting, no better than
none, because the search still sees Black take the pawn on the reply. Measured
with the eval term: 7% on a full board, and **97% once Black is thinned to a
king and four pieces** — which is what GCI becomes as soon as the player starts
shooting — in a median of eight White moves, losing no material. Never set for
Black, which promotes by reaching rank 1, i.e. by breaching.

**Promoting a pawn is the player's only reward** (§7.2). Reaching rank 8 raises
the laser cap by one, stacking to six, reset at each wave. The hull fills the
same green an armored pawn wears, brightening with the stack — the gutter notice
is gone in a second, and the fill is the standing reminder of what the ship is
carrying. `Silhouette` finds the fillable shape inside a hollow outline by
flooding in from the image border; the pawn and the ship share it. The cap is
*concurrency* — `canFire` is `activeLasers < laserCap` and a slot frees the
moment its round lands — so it pays only when shots are missing, which is what
happens at range and under pressure: 1.7 shots/second at two, 5.0 at six. It is
also the one mechanic that needs the chess half and the arcade half at the same
time, since the pawn has to be walked up the board while the player dodges.

**Who shoots.** Pawns are the fleet's gunners from Level 2; bishops add
diagonals at Crossfire, and the black king its own heavy weapon at King
Activated. Arming a *type* replaces §5.3's weighting toward pawns: the weighting
was real (84% of shots) but invisible, and a rule is something a banner can
promise and a player can act on. Two guards keep it honest — with no pawns left
everything remaining takes over, and at most half the gunners fire in a beat, so
the charge-up never lights the whole rank.

**The telegraph.** Every round charges for 0.35s before it leaves. The piece
lights from within — a tinted additive copy of its own texture, so no new shape
appears and it cannot be confused with the check halo — and a tick grows out of
its foot along the exact line the round will take, from the same `atan2` that
aims the round.

**Angles.** Bishops lean toward one of White's actual pieces, 17°–45°, at
§21.3's 160 px/s. The king inflects instead: 9°–31°, on 45% of its rounds, at
30% above its own straight speed, since a lean lengthens the path and would
otherwise make the angled round the weaker of the two. Aiming at real targets
rather than a fixed 45° is what keeps the shot on the board — from the back rank
a true diagonal crosses seven files before it reaches White.

**Rounds shoot each other down.** Black's fire can take a player laser out of
the air. §20's bitmask spec excluded that; it is a deliberate departure and a
costly one, since a laser eaten in flight still counts against the two-round cap
until it clears. The clash throws cyan and magenta along their own two headings
around a white core.

**Formation membership goes both ways.** A black piece rejoins the fleet on a
chess move back into the marching band, and a rank descent sweeps up any stray
it comes down onto — sliding into step over 0.2s, since the fleet transform is
shared and a joining piece must land on the formation's current offset. The band
has a front edge only: nothing is behind the fleet to be separated from, so a
king retreating to rank 8 after the fleet has descended still marches, and the
formation is deeper than `formationRanks` by design. Its rear rank comes from the
descent count, not from where the members happen to be.

**A damaged piece keeps its identity.** The art erodes bottom-up, which takes
the profile with it — a Cracked pawn, bishop, queen and knight were all "a blob
with debris". A full-height slice of one side, 34% of the ink width, is drawn
from the undamaged texture underneath the damage. No new art: every damage state
shares the full sprite's canvas, so a sub-texture lands exactly where that part
of the piece was, and a test pins that invariant against a re-export. The
surviving side is the one the shot missed, taken from the contact point and
fixed by the first hit; a centre hit tosses a coin. The hitbox is compound, so
the wedge is hittable without also covering the gap between it and the top.

### Regeneration and armored pawns (§23.9, §10.1)

One system: armor arrives *only* through regeneration, so Level 9's banner is a
promise Level 4's regeneration has to be built to keep.

- **Regeneration** from Level 4, after *any* black death — shot, captured by a
  chess move, or crushed by the fleet: a pawn replaces it after one
  beat — 4s at most levels, 3s at Blitz — capped by the level's slot count (2 at
  Level 4, rising to 9). §23.9's flat 10s was written before the beat settled at
  4; and the 1.8s beam-in is part of the wait, so the delay only has to cover
  the invisible part. Kill to live pawn is 5.8s, or 4.8s at Blitz.
- **A green RESPAWNING warning** flashes in the left gutter for the 1.5s before
  a pawn starts arriving — high for Black, low for White. Once it is beaming in
  the shimmer is the warning, but by then the square cannot be cleared. It
  mirrors state rather than reacting to events, so simultaneous arrivals raise
  one warning and none can be stranded. White is unused: nothing white
  regenerates yet, and the ship's own respawn stays silent
- **Arrivals go in front of the formation**, not behind it — second rank, then
  third, then the back rank as a fallback. This inverts §23.9's "back of the
  fleet": a regenerated pawn is a body in the way, and at Level 8 an armored one
  cannot be shot at all, so it is worth far more shielding the queen and king
  than tucked behind them where the player was never going to reach
  A slot is spent when the timer is *set*, not when it lands, or a two-slot wave
  could queue twenty at once. A level ending cancels everything pending, which
  falls out of the queue living on the scene rather than needing its own rule.
  The king never regenerates
- **Transporter beam-in**, 1.8s: a shaft of light four squares tall striking
  into the square, flecks falling through it, and the piece strobing into
  existence rather than fading up — a linear fade spends most of its time as a
  faint ghost, which is the part nobody sees. It resolves with a white frame and
  a burst. The pawn has no hitbox until it finishes: §23.9's "the shimmering
  column is the warning" is the entire UI for that state. Green-white normally,
  blue-white in defensive mode
- **Defensive mode**: once the black king is Cracked or worse, pawns stop
  scattering along the rear rank and materialise directly in front of him.
  §23.9's rook and bishop defensive spawns are not built
- **Armored pawns** (Level 8, and again at Blitz): half of every regenerated pawn arrives with its
  interior filled the same translucent green the transporter column arrived in —
  outline untouched, so it reads as the same pawn wearing something rather than
  as a different piece — and immune to laser fire for three White moves. One
  colour for one event, and complementary to Black's magenta. The sprites are hollow, so the fill is a
  silhouette found by flooding inward from the image border: transparent pixels
  the flood cannot reach are the ones the outline encloses. Cached per texture,
  beside the ink bounds. A hit ricochets — orange sparks,
  a metallic clunk, the outline flares — and does nothing. Only a chess capture
  removes it, which is the point of the level: it asks the player to solve
  something with the board rather than the trigger. Armor expires with a crack
  and a shatter, and the pawn underneath is ordinary
- A regenerated pawn is worth 15 rather than 25 (§9), and `ChessEngine.forceAdd`
  keeps the engine's own board in step — without it the search moves other
  pieces straight through the new pawn, the same class of bug as `forcePlace`

### Raiders (§6)

The only things in the game that run on a real-time clock rather than the chess
beat. Everything else — sweep, descent, fire, regeneration — is paced off the
turn, so the board pulses together; a raider ignores that entirely.

- **Raider Scout** on §21.1's `raiderInterval` (20s, tightening to a 6s floor):
  one acid-green shot straight down at 125% of the fleet's speed — floored at
  180, because §21.1 gives Level 1 a projectile speed of *zero* and a
  zero-speed round never fires at all. 1 HP, 100 points, warbling as it goes. Two on screen at once; a spawn blocked by the cap
  stays due rather than being skipped
- **Three crossing patterns**, each a real escalation and each fixed for the
  level so one sighting teaches the next: **over the board** (L1–3), above every
  piece, where the mystery ship belongs; **piece height** (L4–6), §6's rank 4–5,
  firing into traffic; **weaving** (L7+), the same crossing with the height no
  longer constant, so aiming stops being a purely horizontal problem. The weave
  is ±55pt — most of a square, and inside the board at either rank
- **A warning pass is owed once per attack pattern, per run** — three in a run,
  at Levels 1, 4 and 7, as each new pattern first appears.
  §6 gives one every level, which spends its own rationale ("the player sees
  the attack pattern before being shot at") the first time and then keeps
  handing over a harmless raider forever. Two per run, and everything else fires
- On Levels 1–2 the scout does not arrive at all until the fleet's rear rank is
  down to half: the first one should be a reward for making progress, not one
  more thing to parse on an untouched board
- 220 px/s, and the constraint is the ship's 294: a scout the player cannot
  outrun can only be hit by already standing under it. Closing at 74 px/s means
  a missed pass is recoverable
- **A raider is never on screen more than 60% of the time.** §21.1's interval
  tightens to 6s against a 4.9s crossing, which is 94% — always there, and a
  raider that is always there is scenery rather than an event. The interval is
  stretched to whatever the cap needs (8.2s from Level 5), derived from the
  crossing time so changing the scout's speed cannot silently break it
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

### Playtest fixes

One line each; the reasoning is in the commits and the code.

- **No collisions at all** — every physics body was static, and SpriteKit needs
  one dynamic body in a pair to report a contact
- **Hitboxes followed the frame, not the art** — ink bounds are measured and
  cached per texture
- **Damage was invisible** — the hit path never refreshed the sprite, and
  `damageState` used HP ratios rather than §7.1's table
- **Enemy shots spawned off-target** — board-local coordinates for a node living
  in `bloomNode`
- **Angled rounds flew broadside** — `zRotation` turns a node's own axes, so the
  bolt ended up perpendicular to its own travel. Aimed from the travel vector
  now, dressed as a missile, with a circular hitbox so the angle cannot matter
- **A hit that resolved to nothing deleted the round in mid-air** — deactivated
  before the board lookup
- **Heavy shots landed light** — the resolver hardcoded `enemyShotDamage`
- **Play continued after a win** — `isBeatSuspended` gates every path that could
  restart the beat
- **Two crashes, one cause** — releasing a fleet member by square no-oped on a
  stale key. Released by identity now
- **`applyDamage` never told the chess engine** — same class as `forcePlace`
- **The sounds were never missing, only never copied** into `Resources/sfx/`
- **Player shots detonated against nothing, two squares up** — a parked laser
  cleared its contact *test* but kept its category, and SpriteKit fires a
  contact when either body's test matches the other's category. Harmless until
  rounds could shoot each other down; after that every spent enemy shot was an
  invisible mine where it died. Both masks are cleared now, and the handler
  additionally refuses any contact involving a round that is not in flight
- **The ship could come back invisible** — respawn was a scene `SKAction` that
  bailed if the game was not PLAYING on the frame it fired, with nothing to
  retry it. Scene actions run while paused, so pausing in the second after
  dying threw the respawn away: hidden ship, still able to move and fire. It is
  a countdown the update loop owns now, which only advances while playing
- **Messages stacked** — the reveal banner was only cleared on teardown

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

### Not yet verified in the running app

Confirmed by a trustworthy typecheck (macro-plugin flakiness ruled out first),
standalone runtime harnesses for every pure Logic path, and geometry rendered to
PNG where a shape was in question. There is no GUI automation for a native macOS
app in this environment, so a firing/hit/lose/win playtest is the real next step.

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
- [ ] Arcade SFX (laser, impacts, destruction, fleet, raiders) — arrive with 3.x
- [ ] 8 sounds still need generating with jsfxr (marked `generated/` in `SoundKey`)
- [ ] **Bundle size**: only the 12 wired files are bundled (7.7MB). All 49
      referenced would be 91MB, dominated by three long uncompressed GDC stems —
      trim or convert to AAC before ship

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
