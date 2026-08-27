# Implementation Checklist

Progress against the 15-phase plan in `gci-game-design.md` §20. Phase numbering is
the design doc's. Deviations get one line each — reasoning lives in the code.

✅ done · 🟡 partial · ⬜ not started

Ten levels play end to end, each with a mechanic of its own, with all five
power-ups and full arcade audio. The three things left that a player would
notice, in the order they are worth doing:

1. **Music and a settings screen** (5) — one track plays everywhere and there is
   no way to change the volume. Blocked only on choosing tracks
2. **The rest of the raiders** (6.x) — the Scout and every power-up carrier fly;
   the diving family (Escort, Flagship, Kamikaze) does not. Every sprite is
   already in the atlas
3. **Polish and release** (8, 9) — attract mode, a fourth starfield tier, then
   balance, icon, DMG and notarization

Full detail in **[Roadmap — what is left](#roadmap--what-is-left)** near the end
of this file. §20's phase numbers were a plan written before any of this
existed; they are a checklist, not a running order.

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
| 6.2 | Raiders: flagship, variants, special scouts | 🟡 — special scouts and power-ups done |
| 7.1 | Level escalation: chess AI | ✅ — built with the level ladder |
| 7.2 | Level escalation: arcade mechanics | ✅ |
| 8 | Visual polish | 🟡 — score pops, banners, high scores, end screens done |
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
- [ ] 3 sounds still need generating: `llamaBleat`, `camelHonk` (Minter ships,
      not built) and nothing else — the rest of `generated/` is done
- [ ] 12 keys reference files that are not bundled, all belonging to unbuilt
      features (escorts, the flagship, the Minter ships) or to large GDC stems
      not yet trimmed (`criticalCrackleEerie` 24MB, `ambientSpaceLoop` 28MB,
      `mechanicBannerTier2/3`, `fleetRankDrop`)
- [ ] **Bundle size**: 37 files, 11.5MB. Every remaining GDC stem needs the same
      trim-and-fade treatment before it goes in — untrimmed they are 91MB
      between them

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

**Not built:** Galaxian Escort, Flagship, Kamikaze, King Protection Mode, the
Minter tribute ships. All of them plug into `RaiderController`'s existing pool,
cap, clock, roster and flight-path model; none needs new architecture.

## Phase 6.2 — Special Scouts & Power-Ups ✅

§13's power-ups, delivered the way §13.1 specifies: no pickup falls and nothing
is collected — shooting the scout *is* the power-up. That keeps the reward on
the arcade half of the game, where the player already has to aim.

### The roster

A fixed table of which raider each level sends, and what it is carrying. Every
level has one answer, the same answer every run.

| Lv | Name | Scouts, in order | Power-ups, in order |
|---|---|---|---|
| 1 | — | green | RAPID FIRE |
| 2 | FIRE POWER | green | RAPID FIRE |
| 3 | DOUBLE TROUBLE | repair | SHIELD UP |
| 4 | RELENTLESS | ice | TIME FREEZE |
| 5 | TRIPLE THREAT | green | RAPID FIRE |
| 6 | WIDE ORBIT | spread | SPREAD FIRE |
| 7 | CROSSFIRE | bomb | NUKE |
| 8 | ARMORED PAWNS | green → spread | RAPID FIRE → SPREAD FIRE |
| 9 | KING ACTIVATED | green → spread → ice | RAPID FIRE → SPREAD FIRE → TIME FREEZE |
| 10 | BLITZ! | green → spread → ice → bomb | RAPID FIRE → SPREAD FIRE → TIME FREEZE → NUKE |

Scout speeds and HP, since they are what decide whether a carrier is catchable:

| Scout | Speed | Closing rate | Crossing | HP |
|---|---|---|---|---|
| green | 205 px/s (0.93×) | 89 px/s | 5.1s | 1 |
| repair | 220 px/s | 74 px/s | 4.8s | 1 |
| ice | 132 px/s (0.6×) | 162 px/s | 8.0s | 1 |
| spread | 220 px/s | 74 px/s | 4.8s | 1 |
| bomb | 176 px/s (0.8×) | 118 px/s | 6.0s | 1 |

The closing rate is what the player actually feels, and it is why the green
scout's modest 7% cut matters: the ship only has 74 px/s of margin at full scout
speed, so taking 7% off the scout adds a fifth to the closing rate. The bomb is
slower again because it is the only one that *swoops* — a target moving fast
vertically is far harder to lead with a vertical laser than one flying level.

**Every carrier dies to one hit.** §13.2 gives the Bomb Scout two, "like the
Flagship", to make it "a meaningful challenge for the reward". It read as a bug
instead: a clean hit that leaves the target flying looks like the shot missed,
and a scout is small, fast and briefly on screen — there is no time to reconsider
what you just saw. The Flagship can carry that mechanic because it is large, slow
and announced; a scout cannot. `RaiderNode.takeHit` keeps the survive-a-hit
branch for it, unreachable for now.

- **One kind at a time, and it keeps coming back until it is shot down.** The
  entry at the front of the roster crosses, and only a kill advances to the next.
  Missing costs nothing but time, so how many raiders a wave sees depends on how
  long the player takes to hit one — which is the right thing for it to depend
  on. Most levels therefore go quiet after a single kill
- Every power-up **debuts on a level of its own**, so it is met and learned
  before it ever shares a wave, and **every one comes round again** — a mechanic
  the player meets once and never uses is not worth building. Both are pinned by
  tests. Blitz offering all four is what earns the Nuke its second outing: the
  other stacked levels are green/spread/ice, so without it the bomb scout
  appeared on Level 7 and never again
- Levels 8–10 stack what the player already knows, cheapest first: Rapid Fire is
  banked before the spray arrives, so there are more shots to go after it with,
  and Blitz puts the bomb last, because clearing the sky is worth most once the
  sky is at its fullest
- The gap between crossings **tightens with the roster** — 22s / 15s / 12s for
  one, two and three-or-more offers — because on those levels every miss costs a
  full gap and a level advertising three power-ups would realistically hand over
  one
- This replaced an unlocking-pool version, where any unlocked type could turn up
  on any later level. A raider whose identity is a surprise is one the player
  cannot prepare for, which is the opposite of what a rare reward should be

### Flight paths (§6.3)

Tied to the *kind* of raider rather than to the level, so the path is part of
each ship's identity and a second cue for what is on offer. Parameters are
randomised per crossing, so a learned shape still has to be read.

| Kind | Path | Enters |
|---|---|---|
| green | dead level, and the only straight one | above the board |
| ice | tight weave, ±46–60pt over 0.75–1.05s half-cycles | rank 4–5 |
| spread | the same at twice the scale — ±74–104pt over 1.9–2.6s | rank 5–6 |
| repair | a long eased glide down, giving up 55–95% of its headroom | above the board |
| bomb | one dive and climb, 70–95% deep, bottoming out at 45% across | above the board |

The bomb's dive is why it needed slowing: it is closest at mid-crossing, which is
also where it is moving most steeply, and a vertical laser has to lead that.

- The green scout is flat *because* the others are not: it is the raider the
  player meets first and chases most often, so it stays a pure horizontal aiming
  problem. It used to carry a 4pt hover; that is gone
- The two descending paths genuinely reach the player. Measured: at the steep end
  of their ranges both bottom out at y=136 — inside the board's first rank, 54pt
  above the ship's own hull — and every path was checked to stay inside the
  110–652 strip between the HUD and the ship's lane, at every lane each kind uses
- The weave is now symmetric about its lane. The first version offset by half
  the amplitude and then swung a full amplitude twice each way, which put the
  centre of the weave half an amplitude *below* the lane it was flying and made
  the low excursion three times the high one

### The effects

- **Time Freeze** stops the fleet, the raiders, enemy rounds, the starfield and
  the chess turn timer, and drops the music to `rate = 0.5` — §13.2's one
  sanctioned use of `rate`. The player's own movement, fire and rounds in flight
  are untouched, which is the whole effect
- **Spread Fire is a swept hose, not a fan** — Missile Command's spray. One
  stream, twelve rounds a second, the angle oscillating through ±20° on a 1.8s
  sweep, and it fires **only while the player holds the fire key**.

  It took three passes to get here, and the first two were the wrong axis.
  §13.2's version was five simultaneous streams at fixed angles, auto-firing for
  fifteen seconds and flying the full height of the screen: it swept **244% of
  the board area**, covering the whole position twice over wherever the ship
  happened to be, so collecting it ended the wave. Narrowing the fan to ±8°/±16°
  still left 84%, and cutting the duration and rate still left 32% — because a
  fixed fan means every angle is covered at once and there is nothing to aim.

  | | §13.2 | narrowed | cut back | now |
  |---|---|---|---|---|
  | streams | 5 fixed | 5 fixed | 5 fixed | **1 swept** |
  | duration | 15s | 15s | 7s | 7s |
  | rounds/sec | 40 | 40 | 20 | **12** |
  | angle | ±20°, ±40° | ±8°, ±16° | ±8°, ±16° | **±20° swept** |
  | range | full screen | full screen | 6 squares | **to rank 7** |
  | rounds fired | 600 | 600 | 140 | **84** |

  A single sweeping stream is a different weapon rather than a smaller one: only
  one round is ever on its way to a given place, so the player is pointing a hose
  instead of standing behind a wall of fire, and ±20° can be generous precisely
  because coverage now costs time
- **Only while the trigger is held.** §13.2 has the ship auto-fire for the
  duration, which sounds generous and plays badly: the power-up took the trigger
  away at the exact moment it handed over the firepower, so the most powerful
  thing in the game was also the one moment the player was not shooting. Needed
  a new `GameAction.stopFiring` on the fire key's release — ordinary fire is one
  shot per press and never needed it. Cleared on pause, on death and on a level
  change, since a key-up that lands while the scene is not listening is lost and
  the hose would still be running on resume
- The sweep's phase advances whether or not the trigger is down, so releasing and
  pressing again picks the hose up where it had got to rather than restarting the
  arc from centre. The period is chosen against the fire rate rather than by
  feel: at twelve rounds a second, 1.8s puts 10.8 rounds in each half-sweep,
  which is 3.7° and about 24pt apart at full reach — dense enough to read as a
  ribbon rather than a row of separate shots
- **The range is a ceiling, not a distance** — the constraint is which rank the
  spray may touch. Rounds burn out at y=556: rank 7 runs 504–568 with its pieces
  centred on 536, so that is past the middle of a rank-7 piece and 12pt clear of
  the nearest rank-8 one. The seventh row is reachable; the eighth has to be
  earned the ordinary way.

  It works out to 7.4 squares rather than the round 7 it looks like it should be,
  and the difference matters: a flat "one more square" than the previous six
  landed at 530, which is 6pt *short* of rank 7's centre and would only ever have
  clipped the bottom of a piece standing there. Aiming at the rank rather than at
  a round number of squares is the difference between reaching it and nearly
  reaching it.

  Rounds fade over their last 0.18s — every other laser in the game expires
  off-screen, so this is the only one that would otherwise blink out in view
- **Spray rounds pass through White's own pieces.** There are a great many of
  them and the sweep aims them rather than the player, so ordinary friendly fire
  made the reward demolish White's position as a side effect of being used. Done
  by dropping `friendlyPiece` from the round's contact mask rather than by
  ignoring the hit: a round that will do nothing should fly through, not be
  consumed by a piece it left unharmed
- **Spread Fire fires outside `SpaceshipState` entirely** rather than raising the
  cap. The cap counts rounds in flight and frees a slot as each resolves; a spray
  borrowing those slots would leave the count wherever the last round stranded it
  and the player would come out of the power-up unable to fire. The player laser
  pool is 24: measured, a round is in the air 0.97s over its 474pt range, so
  twelve a second put 11.6 up at once, plus the manual cap of 6. It has been 72
  and 32 on the way here — an under-sized pool does not fail loudly, it silently
  drops rounds and the spray just looks thinner than it should
- **Nuke** expands a magenta-to-white ring over 0.4s that clears every enemy
  round it passes over **and detonates the nearest black pieces**. §13.2's
  version only cleared projectiles, which is invisible: the player saw a big ring
  and then an absence, and read it as some buff they could not identify. Deleting
  things is not an effect you can see.

  Up to **three** victims, at least **one** wherever anything is left, chosen by
  distance with no radius limit — a cap on range would make the reward depend on
  where the swooping scout happened to die, and a Nuke that sometimes does
  nothing visible is the problem this redesign exists to fix. Each victim gets a
  **fragment** thrown at it from the blast centre, timed to arrive exactly as the
  ring does; without it the ring and the explosions are two things that happen
  near each other, and with it there is a line drawn from cause to effect.

  Victims are destroyed outright rather than taking an HP number — a blast that
  leaves a rook standing is not a blast. Armor still stops it (§10.1): a power-up
  that walked through armor would take Level 8's identity away.

  **The black king is passed over** while anything else stands, however close he
  is, so the rarest power-up in the game is never spent on the one target it
  cannot kill. He gets a forcefield flare and a clang when the blast reaches him
  anyway, or the ring looks like it missed the most obvious thing on the board.
  When he is the last piece left he *is* the target, for 6 damage floored at 1 HP
  — winning a wave has to stay something the player aimed at
- **The blast runs in slow motion**, which is most of what makes it land. The
  ring opens over 0.85s rather than 0.4, and the whole world drops to 0.3× for
  1.3 seconds: `dt` is scaled for everything the update loop drives, and
  `bloomNode.speed` for everything on an action — the fleet, the lasers, the
  explosions and the ring itself. Measured, that puts the ring's full expansion
  at 1.6s of real time and lands the fragments between roughly 0.24s and 1.0s,
  spread across the slow window rather than bunched at the start.

  The ramp holds at the floor for the first 45% and then *accelerates* back
  rather than easing out. Coming out of slow motion is the part that sells it: a
  linear return reads as the game recovering from a stall, where lingering low
  and then snapping back reads as a decision. The music drops to `rate` 0.7 —
  shallower than Time Freeze's 0.5, so the two are not mistaken for each other —
  and restores to whatever the world is actually doing, since a Time Freeze may
  still be running underneath and owns 0.5 until it expires
- **Shield** is a hexagon, not a circle, so it can never be confused with the
  black king's forcefield: one means protected, the other means unshootable
- Only the two clocked effects are exclusive (§13.1); a second replaces the
  first, and the displaced one has its world changes lifted before the new one
  applies. A shield sitting unspent competes with nothing, and neither does a
  laser cap that has already been raised
- **Carriers are split between atlas art and drawn overlays**, and the split is
  a playtest result rather than a principle. The specials began as shape overlays
  on the plain scout while `ship-scout-repair`, `-ice`, `-spread` and `-bomb` sat
  in the atlas unused; switching all four to their sprites was a clear win for
  Spread and a clear loss for Repair and Ice, whose hexagonal grid and
  crystalline facets read better drawn. So Spread flies `ship-scout-spread`, and
  Repair and Ice keep the disc and the overlay. `ship-scout-bomb` and
  `ship-scout-ice` remain in the atlas, unused
- **The Nuke flies §6.4's Mutant Camel**, not `ship-scout-bomb`. The bomb sprite
  is a competent red mine; the camel is a Jeff Minter tribute with legs, and one
  of those is the right thing to see swooping at you carrying a nuclear weapon.
  Half again the height of a scout (§6.4 makes it the larger tribute ship), and
  the only carrier with a voice — a generated low bray on entry, so you hear it
  before you have picked it out of the board
- **Raiders face the way they are going.** The crossing is built as legs rather
  than one `moveTo`, so a raider that turns can turn to face; the camel has legs
  and a head, and a camel crossing right-to-left rear-first reads as a bug. Every
  other carrier is a symmetrical disc, for which this is a no-op — which is why
  it applies to all of them rather than being special-cased
- **One crossing in five doubles back** partway and then carries on the way it
  was going, flipping to face each direction as it turns. Not a difficulty
  change — a raider that feints is on screen *longer* and is marginally easier to
  catch — but a crossing the player has already read stops being fully
  predictable. It never backs past its own entry point, which would read as a
  second entrance
- Carrier sizes are **measured, not uniform**. The plain scout is a wide 280×144
  disc and the specials are compact shapes on 200×200 squares, so scaling every
  sprite by canvas height gave the specials *half* the target area — the wrong
  way round, since they are the rarer and more valuable ships. Each multiplier is
  now the one that equalises visible ink against the scout's 49.6 × 21.2pt, with
  the camel deliberately left at 1.71× for presence
- Every active power-up shows as a standing line in the player's alley, **one
  line each** — two statuses sharing a line read as one status — with 5pt of air
  between them, and §13.2's countdown bar under the bottom line for a timed
  effect. No numbers: the laser cap was briefly appended to RAPID FIRE and the
  seconds to a timed effect, and both turned a status into something the player
  had to parse. Neither number was actionable — a shrinking bar is read without
  being read, which is what a status in the corner of the eye has to be, and the
  ship's own hull already brightens with each Rapid Fire stack.
- The four chess readouts — turn timer, AUTO MODE, the transient notice and the
  status line — all sit 8pt lower than they did, opening a gap between them and
  the power-up block. Applied as one `gutterDrop` constant rather than four
  edited literals, because they have to move together: at anything less than the
  full drop the timer's 22pt digits land on the transient notice.

  The block sits **above** the turn timer, which took two attempts. The gutter is
  fuller than it looks: below the status line there are 27pt, and every gap
  between the timer, the transient notice and the status line is 0.5 to 7.5pt —
  too narrow for a 9pt line. Two lines fitted in that 27pt band; three at a 5pt
  gap need 37. Above the timer's caption the gutter is empty to the HUD at
  y=664, so that is where it went. The first version was placed by eye against
  the timer's *centre* at 166 without accounting for its caption 18pt above and
  landed on top of the caption — so the measurements are now a table in the code
  and a test that fails on any overlap
- The two Ice sounds are synthesised (`Resources/sfx/generated/`): a swept-noise
  whoosh falling 2.4kHz → 180Hz with a comb-delay tail and a crystalline ring
  over the last third, and a shorter rising version for the expiry

**Lightning Scout is retired.** §13.2's fifth type grants "+1 laser slot", which
is what Rapid Fire is; two ships handing over the same reward is one ship too
many.

## Roadmap — what is left

Ten levels play end to end with every mechanic, all five power-ups, and full
arcade audio. What remains, grouped by what it is rather than by §20's phase
numbers — those were a plan written before any of this existed, and the running
order has diverged.

Ordered within each group by what it would cost to *not* have at ship.

### Music and settings (§20 Phase 5) — not started

The largest single gap, and the only one a player would notice immediately.

- [ ] **Per-level music.** One track (`GCI-intro.m4a`) is bundled and plays
      everywhere. §5 wants a pool drawn from per level. **Blocked on track
      selection** — `assets/music/` holds six unopened loop bundles and a
      MIDI set; someone has to listen and choose. Nothing else here depends on it
- [ ] **Level clear fanfare** (3–4s) and **game over riff**, both specced in §5
      and currently standing in with `levelClear` / `gameOver` one-shots
- [ ] **Title screen music**, stopping cleanly when the game starts
- [ ] **`SettingsView.swift`** — master / music / SFX volume sliders, music
      on/off, persisted via `UserDefaults`. `AudioManager` already exposes
      `setMusicVolume` and a per-key gain and ceiling, so the plumbing is
      in place and only the screen and the persistence are missing
- [ ] Stubbed Gameplay / Controls / Display sections in Settings, so adding
      difficulty and key remapping later needs no rework
- [ ] Settings entry points: a title-screen button and a gameplay shortcut that
      pauses while open. §5 is explicit that the pause overlay stays a plain
      overlay with no menu — that part is already true
- [ ] **Music ducking** under priority SFX. `AudioManager.duckMusic` exists and
      is not called from anywhere

### Raiders — the rest of §6 (§20 Phases 6.1, 6.2)

The Scout and all five power-up carriers are done. What is left is the dive
family, which needs a genuinely new motion model — everything built so far
crosses the screen horizontally.

- [ ] **Galaxian Escort** — peels off the fleet's rear rank, curved dive at the
      ship's *last known* position, fires at the apex, exits. Reaching the
      bottom strip costs a life. 150 pts
- [ ] **Galaxian Flagship** — 2 HP, flanked by two Escorts that must die first,
      immune while they live (white flash + clang so the rule teaches itself)
- [ ] **Escort variants** — Kamikaze (fast, silent, straight at the ship),
      Paired, Looping
- [ ] **King Protection Mode** (§6.3) — raiders actively plug an open lane to the
      black king. The most interesting unbuilt idea in the doc: it makes a clean
      shot at the king something the game contests rather than something the
      player waits for
- [ ] **Minter tribute ships** (§6.4) — Llama on even level clears, Mutant Camel
      on every third, flying across the score tally. Sprites are already in the
      atlas; both sounds still need generating
- [ ] `RaiderController`'s pool, cap, clock, roster and flight-path model are the
      seam all of the above plug into — none of it needs new architecture

### Gameplay decisions still open

Not bugs and not missing features — things playtesting raised that have no answer
yet.

- [ ] **Should Rapid Fire outlast its level?** It resets every wave, which was
      right when a promotion granted it and is arguable now that a scout does.
      Carrying it over would make the green scout the most valuable raider in the
      game, which may be the point or may be too much
- [ ] **Levels 7–10 and the one-kill rule.** Raids currently end for the wave
      once the player brings one down, at every level. By the late levels a
      player is fast enough that this can happen very early and leave a long
      quiet stretch — worth revisiting once those levels have been played
      properly
- [ ] **Level 11+.** Level 10 (Blitz) is deliberately the last wave and clearing
      it wins the run. A twelfth mechanic would need a reason to exist beyond
      "harder"
- [ ] **Fleet rush stays cut** (§7.2). Recorded under deviations with the
      reasoning; listed here so it is a decision rather than an oversight

### Visual polish (§20 Phase 8)

Much of this phase landed early — score pops, banner animations, the high score
table, the game over and level clear screens, per-piece destruction sounds. What
is genuinely outstanding:

- [ ] **Fourth starfield tier.** Three are built (46 / 26 / 12 sprites at
      20 / 58 / 140 px/s); §12.4 asks for four
- [ ] **Wireframe geometric debris** in a foreground layer, Asteroids Recharged
      style — the one piece of the art direction with nothing built against it
- [ ] **8-frame explosion sprite sheets per piece type.** Explosions are
      currently pooled particle bursts tinted per piece, which reads well enough
      that this may not be worth doing
- [ ] **Hyperspace jump on level clear**
- [ ] **Attract mode** — §14.2's 5-slide cycle on a 12s timeout. `HowToPlayNode`
      and `TitleOverlayNode` exist; nothing cycles

### Shipping (§20 Phase 9)

- [ ] **Balance pass from outside playtesters.** §9's own criteria: is Level 1
      learnable in one attempt, Level 3 urgent, Level 5 overwhelming-but-fair
- [ ] **Bundle size** — see Phase 4. Every remaining GDC stem needs trimming
- [ ] **App icon**, all sizes
- [ ] **DMG** for direct distribution, then App Store: sandbox entitlements,
      notarization, screenshots, metadata
- [ ] **Instruments passes** — Allocations over 30 minutes for leaks, Time
      Profiler for the frame budget. See "Potential optimizations" for where to
      look first
- [ ] **XCTest cannot run in this environment**, so the whole suite has been
      typechecked but never executed. Running it once in Xcode is the single
      highest-value verification step left

### Not scheduled

- **iOS / iPadOS port** — `gci-game-design.md` Appendix A. Wanted eventually, not
  now. The architecture rules that keep it possible are followed regardless: the
  logic layers import no SpriteKit or AppKit, and all input arrives as
  `GameAction`

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

## Potential optimizations

Nothing here is a known problem. Measured 27 Aug 2026 on an M4 (10 cores) with
Activity Monitor: **36–38% steady, 48% at the highest levels**, with no observed
lag or dropped input at any point.

That number is per *core*, not per machine, so it is 3.6–4.8% of an M4 — an
unremarkable figure for a 60fps SpriteKit scene running a full-screen Core Image
bloom pass. The rise at the late levels is expected load rather than drift: three
marching ranks, more pieces venting embers, more rounds in flight. It was also
almost certainly a **Debug** build, which pays for `-Onone` codegen, the
diagnostics log, and the node-count tree walk — none of which ship.

So this list is a place to start *if* CPU ever matters, roughly in order of
expected return. None of it has been measured; the first two are the only ones
worth trying before profiling.

**Check the frame rate first.** `preferredFramesPerSecond` is never set on the
`SKView`, and neither is anything else about its cadence. Press `L` and read the
FPS line: if it says ~120 on a ProMotion display, the game is rendering twice as
often as it needs to and capping it to 60 halves everything below. One line in
`ContentView.GameSKViewRepresentable`, and it costs nothing to find out.

**`bloomNode.shouldRasterize = true`** (`GameScene.setupBloomNode`). Rasterizing
an `SKEffectNode` caches its rendered output and re-renders when the subtree
changes. Every moving thing in the game is a child of this node, so the subtree
changes every frame and the cache is never hit — it is likely paying for a
texture round-trip per frame and getting nothing back. Apple's own guidance is to
rasterize only when contents rarely change. Flipping it to `false` is visually
identical, since rasterization is purely a caching strategy, so this is a safe
experiment. It is a `CLAUDE.md`-documented decision, which is the only reason it
has not been changed.

**`ignoresSiblingOrder` is not set on the view.** With explicit `zPosition`
everywhere — which this codebase has — setting it lets SpriteKit reorder draws
within a z-layer to batch by texture. The pieces already share one atlas, so
there is batching to win. Turn on `showsDrawCount` (it is wired to the sidebar)
and see whether the count actually drops before keeping it.

**`rearRankPieces` runs every frame on every level.** It is passed as an argument
to `raiders?.update(...)`, so it is evaluated unconditionally: two array
allocations (`allPieces(color:)` filters the piece dictionary, then a second
`filter`) plus a string parse per piece, 60 times a second. It is only *used* on
Levels 1–2, where `RaiderRules.waitsForThinnedRearRank` is true. Guarding the
call — or passing a closure instead of a value — makes it free from Level 3 on.

**The per-frame gutter syncs re-set text that has not changed.**
`syncPowerUpAlley` and `syncRespawnWarnings` run every frame and do up to seven
`childNode(withName:)` lookups between them, each a linear scan of `bloomNode`'s
children. `syncPowerUpAlley` also assigns `SKLabelNode.text` every frame, which
re-lays out glyphs. Only the countdown bar genuinely changes per frame; the
labels change a handful of times a wave. Cheap to guard, and the same pattern
would apply to any readout added later.

**72 pre-created player laser nodes** (`LaserPool`), up from 6, each carrying a
physics body. Parked bodies have `categoryBitMask = .none` so they are never
contact-tested, but SpriteKit still walks the body list. The number is derived
from the Gatling barrage's measured steady state, so it can only come down by
changing the barrage — a lower fire rate or a shorter reach would both shrink it.

**CIBloom is a full-screen Core Image pass every frame** at radius 6, intensity
0.9. The alternative to the whole approach is pre-blurred additive sprite copies
per glowing node, which trades GPU fill for draw calls and node count. That is a
large change to the look as well as the cost, so it is a last resort rather than
a tuning knob.

**Already handled, for the record:** the starfield is ~170 sprites sharing one
texture in a single draw call (`SKShapeNode` circles could not batch and cost one
each); `Silhouette`'s flood fill is measured once per texture and cached;
diagnostics publish at 4Hz rather than per frame; every laser, explosion, score
pop, shatter and raider is pooled, so gameplay allocates nothing.

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
