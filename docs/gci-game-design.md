# Galactic Chess Invaders — Game Design Document

**Version 1.0**

*Target: macOS first (Swift/SpriteKit); iOS/iPadOS is possible later but not yet committed*

*"40 years in the making!"*

---

## Origin & History

Galactic Chess Invaders was first conceived and prototyped during **spring break 1983** by Zack Urlocker, then an undergraduate student, on an **Apple II**. The demo was written in Applesoft BASIC and compiled with **TASC — The Applesoft Compiler** for performance. Graphics were rendered using the **HRCG (High Res Character Generator)** with a dedicated chess font to animate the pieces in high-resolution mode. Startup music was produced through a simple Apple II synth routine; shot and hit sound effects were programmed directly in BASIC.

The core concept — a functioning chess engine whose pieces simultaneously behave as a Space Invaders fleet, with the player controlling both a chess side and a shooting spaceship — was fully present in this original demo.

The original floppies were rediscovered **forty years later**, along with a working Apple II. The disks loaded and the demo ran.

### Prior Art

No earlier documented game combining a real chess engine with real-time Space Invaders-style arcade shooting has been found. Modern games with similar names are all significantly later:

| Game | Year | Nature |
|---|---|---|
| **Galactic Chess Invaders** *(this game)* | **1983 prototype** | Apple II, TASC/Applesoft, HRCG chess font, real chess + real shooter |
| "Space Invaders Chess" (Chess.com Horde variant) | 2010s | Pure chess rule variant, no arcade element, borrowed the name |
| Chess Invaders (HauntedQuest, itch.io) | ~2022 | Jam submission, no player shooting, no opposing chess side, abandoned |
| Chess Invaders (LordJellington, itch.io) | ~2021 | Chess tower-defense jam entry, no arcade element, no audio, abandoned |
| Chess_Invaders (Squareswaves, itch.io) | ~2022 | Xevious-style scroller, no real chess, broken shooting, abandoned |
| Chessplosion (ctmatthews) | 2022 | Puzzle/arcade hybrid — bomb chain reactions on a chess board. Commercial, Windows/Steam |
| **Shotgun King: The Final Checkmate** (PUNKCAKE Délicieux) | **2022** | **Polished roguelite — King with shotgun vs. chess army. #1 Ludum Dare 50. Commercial, all platforms, actively maintained** |

The 2025 Swift/SpriteKit implementation documented here is a full realization of the original 1983 concept — same hybrid DNA, modern platform.

### Notes on Reviewed Games

**Chess Invaders — HauntedQuest (itch.io, ~2022)** *(played)*

Good effort for a weekend jam — decent blocky pixel animation, good sound effects, enjoyable synth chiptune. The core tension of invaders advancing is felt. But there is no player shooting (the player can only move chess pieces, making the game entirely passive), no real opposing chess side (the "enemies" have no chess identity and make no chess moves), and therefore no dual-input tension — the central drama of GCI. Instructive as a proof that either element alone produces a lesser game.

**Chess_Invaders — Squareswaves (itch.io, ~2022)** *(played)*

Essentially a Xevious-style vertical scroller with chess piece graphics as window dressing — no actual chess to be found. Controls are primitive, animation is basic colored blocks, and the shooting mechanics did not appear to work — a critical failure for a shooter. Good chiptune and sound effects are the only bright spots. A broken concept sketch with a misleading name.

**Chessplosion — ctmatthews (2022)**

A puzzle/arcade hybrid where you drop chess-piece-shaped bombs to create chain reactions. Multiple modes including 140+ puzzles, roguelike dungeon, and 1–4 player battle with online multiplayer. Rated 4.5/5, Windows/Steam, $12–$15, actively maintained. Less relevant to GCI — the chess connection is blast-shape geometry rather than chess strategy, and there is no invader-style pressure. Shows that chess-geometry games can branch into arcade-adjacent modes, but the design DNA is different.

**Shotgun King: The Final Checkmate — PUNKCAKE Délicieux (2022)** *(the one to study)*

The most polished and commercially successful chess/arcade hybrid found, and worth playing in depth before GCI implementation begins. Won **1st place overall at Ludum Dare 50** out of 1,900+ entries. Rated 4.8/5 from 268+ ratings. Available on Steam, Switch, PlayStation, Xbox, Android, and macOS. Actively maintained — v1.5 shipped September 2024 with 30 new cards. Price: $10.

The player controls the Black King, who carries a shotgun. The entire White army advances using standard chess movement rules; there is no White side for the player — the King fights alone. The shotgun has configurable Firepower, Fire Arc, Fire Range, and Ammo; crucially, **reloading happens by moving** — a beautifully elegant coupling of the game's two verbs. After each floor the player chooses from 3 cards that upgrade the King's abilities, but many cards simultaneously buff the enemy army, creating genuine risk/reward tension. The card pool exceeds 100; multiple shotgun types, game modes (Story, Endless, Chase, Throne with 12+ difficulty ranks), and a community modding system give the game lasting depth. Production values are high throughout: pixel art in Aseprite, mode-specific original soundtrack, strong SFX, threat indicator arrows, the King sprite visibly sweats when threatened, 17 languages, colorblind modes, Steam Deck support.

**What GCI can learn from it:** Enemy pieces moving by chess rules is an immediately readable threat language — players understand a rook bearing down a file without being told why. Asymmetry between the player's attack mode and the enemy's chess-rule movement creates drama that symmetry doesn't. Card upgrades between levels are a proven replayability mechanism worth considering for GCI post-MVP. Difficulty rank tiers allow one game to serve casual and hardcore players alike.

**A note on audio across all reviewed games:** Even the weakest jam entries — HauntedQuest's Chess Invaders and Squareswaves' Chess_Invaders — were redeemed somewhat by good sound effects and a chiptune music track. In every case, audio was the feature that made an otherwise rough game feel like a real game rather than a tech demo. This reinforces GCI's decision to add basic SFX and music early (Phases 4 and 5), well before the game is feature-complete. A music track and satisfying hit/fire sounds are table stakes for this genre, not a polish step.

**Key difference from GCI:** Shotgun King is **entirely turn-based** — player acts, enemies act, alternating. There is no real-time arcade action, no Space Invaders fleet, no simultaneous dual-input. GCI's design — firing the spaceship *while* watching the chess clock tick — is a fundamentally more chaotic and demanding experience. Shotgun King rewards careful positioning; GCI rewards split-second prioritization under simultaneous pressure. Both are valid; they are different games.

---

> ⚠️ **Naming:** In this document the word *Recharged* is occasionally used as a shorthand for the visual and audio aesthetic (neon glow, dark backgrounds, modern electronic music) inspired by the Atari Recharged game series. **“Recharged” is likely a trademark of Atari** and will not appear in the final product name. An alternative might be used such as: **Remastered, Evolved, Overdrive, Refueled, Supercharged, Reloaded, Reboot, Resurgence or Unleashed.**

---

## 1. Concept

Galactic Chess Invaders (GCI) is an arcade-chess hybrid. A standard chess game plays out on-screen, but the black pieces also behave like Space Invaders: they slide left and right as a fleet, periodically descend, and fire projectiles at the player's pieces and spaceship. The player controls white's chess moves *and* a horizontally-moving spaceship at the bottom of the screen that can shoot up at any target — enemy pieces, invader projectiles, or even the player's own damaged white pieces.

The chess game is real but fast and shallow. Arcade reflex, not deep strategy, determines whether you survive.

---

## 2. Core Loop

```
[Chess turn timer counts down]
       |
       v
[Player makes a chess move  OR  timer expires → computer auto-moves white]
       |
       v
[Computer makes a chess move for black]
       |
       v
[Black fleet shifts (left/right/down) in invader pattern]
       |
       v
[Invaders fire projectiles downward]
       |
       v
[Player moves spaceship, shoots; white pieces absorb or block hits]
       |
       └──► back to top
```
These phases overlap in real time — the chess turn timer ticks while invader projectiles are already in flight. The game never fully pauses for chess.

**Canonical timing rule:** Chess turns are paced by a fixed **chess beat**, not by fleet sweep completion. The beat duration is the level's turn timer in §21.1: Level 1–2 = 5s, Level 3+ = 4s. During each beat the player may make one White chess move at any time. If the player has not moved when the beat expires, the engine auto-moves White. Black's chess move or moves then execute once for that beat, and the next beat begins.

Fleet movement, raider movement, projectiles, ship movement, and shooting continue independently during the chess beat. Fleet wall bounces and visual half-drops do **not** trigger extra black chess moves. If playtesting shows black chess moves feel too fast at higher levels, tune the level's chess beat duration upward; do not tie chess move timing to screen width, fleet speed, or sweep completion.

---

## 3. The Game Board

### 3.1 Layout

The screen is divided into two horizontal zones:

```
┌───────────────────────────────────────┐
│  [Score]              [Level] [Lives] │  ← HUD bar
├───────────────────────────────────────┤
│                                       │
│   BLACK PIECES  (rows 8–7)            │  ← Enemy fleet zone
│   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░       │
│                                       │
│   Open board space (rows 6–3)         │  ← Combat / invader advance zone
│                                       │
│   WHITE PIECES  (rows 2–1)            │  ← Player defense zone
│                                       │
├──────────────────────────────────────-│
│  [▼ 5s]   [──── SPACESHIP ────►]      │  ← Spaceship + timer strip
└───────────────────────────────────────┘
```
- The 8×8 chess board fills the center of the screen.
- Each square is large enough to render the tallest displayed chess piece without overlap. Displayed piece size is derived from the runtime board square size, not from fixed pixel dimensions (see §12.2).
- No column or row labels are shown on screen. Algebraic notation (a–h, 1–8) is used internally and in debug builds only.

### 3.2 Coordinate System

Standard algebraic notation internally. Rendering maps rank/file to screen pixels. The spaceship travels in a strip below rank 1.

---

## 4. Chess Rules & Modifications

### 4.1 Standard Chess — What Stays

- All standard piece moves (including promotion).
- Captures remove the captured piece.
- Check and checkmate are recognized.
- Castling and en passant are **not implemented for either side in v1.0** — kept simple for arcade pace and to avoid special-case interactions with forced fleet movement.

### 4.2 What Changes

| Rule | Standard Chess | GCI |
|---|---|---|
| Turn time | Unlimited | Level-based chess beat; auto-move on expiry |
| Piece HP | N/A | Each piece has hit points; damage shown by outline erosion |
| Destroyed pieces | Only by capture | Also by shooting or HP reaching 0 |
| King loss | Illegal (checkmate ends game) | Shooting the king ends the chess game early |
| Promotion | Pawn reaches rank 8 | Still valid; promotes under fire |

### 4.3 Auto-Move on Timer Expiry

When the level's chess beat expires without a player move, the chess engine picks White's move (same 1-2 ply engine that drives Black). A brief "AUTO" flash appears over the piece that moved. This keeps the game flowing and prevents the player from stalling to focus on shooting.

**Selected-piece constraint:** If the player has selected a piece but not yet confirmed a destination, the engine is constrained to moves for that selected piece only — it picks the best legal move available to that piece. If the selected piece has no legal moves (e.g. it is pinned), the engine ignores the selection and picks the best overall legal move instead.

### 4.4 Simplified Chess: No Castling or En Passant

GCI intentionally uses simplified chess movement for **both White and Black** in v1.0:

- **Castling is disabled.** Kings and rooks move only as individual pieces. No castling reticle is shown for White, and the Black engine never selects a castling move.
- **En passant is disabled.** Pawns capture only by normal diagonal capture. No en passant reticle is shown for White, and the Black engine never selects an en passant move.

This is not a player-skill assumption; it is an implementation and readability decision. GCI's board can change through non-chess events: fleet descent, crushes, shooting, regeneration, and forced placement. Castling and en passant both depend on special move history and board-state rights that are easy to make confusing once pieces can be destroyed or forcibly moved outside normal chess rules.

**Implementation rule:** Even if the chess library supports castling and en passant, `MoveGenerator` filters those moves out before returning legal moves to the UI or the AI. `GCIBoard` also clears castling rights and en-passant target squares when constructing or updating library board state. There is no v1.0 code path where either side can castle or capture en passant.

### 4.5 Chess Engine

- **Depth:** 1-2 ply minimax (fast, ~milliseconds).
- **Evaluation:** Material count only. No positional tables.
- **Personality:** Slightly biased to keep pieces alive (avoids trading into losing positions by more than ~1 pawn). Will not sacrifice pieces tactically.
- **Black also uses this engine** to choose its chess moves each turn — but black's movement on-screen follows the Invader pattern, not just chess rules (see §5).

**Aggressive mode (Level 2+):** From Level 2 onward the engine is weighted to prefer attacking moves. Specifically: captures are scored higher than positional moves, pawns are actively advanced, and the engine prefers moves that put white in check or threaten multiple pieces simultaneously. This is implemented as a score modifier in `GCIBoard.score(for:)` passed to `GKMinmaxStrategist`. The aggressive weighting increases each level (see §21.1).

---

## 5. The Invader Fleet — Black Pieces

### 5.1 Formation Movement

Black pieces maintain their starting chess positions *relative to each other* as they shift laterally, exactly like Space Invaders:

1. Shift right N pixels per frame until the rightmost piece reaches the right wall.
2. Drop down one **visual half-rank**. This is animation only: black pieces remain on their current logical chess rank.
3. Shift left until the leftmost piece hits the left wall.
4. Drop down a second **visual half-rank**. The two visual half-rank drops now total one full rank, so each black piece's logical chess rank updates by one rank toward White.
5. Repeat.

The fleet's lateral speed increases as pieces are eliminated (classic Invaders behavior).

**Canonical rule:** Black pieces stay on their current logical chess rank until the **second** sweep/drop of the pair is complete. The first wall-bounce drop is purely visual. Only after the second wall-bounce drop does the board state change.

### 5.2 Chess Moves vs. Fleet Movement

Black's chess move happens once per scheduled chess beat, **after** White's move for that beat has been completed or auto-moved. It is not triggered by fleet sweep completion. The engine picks the best legal chess move; the selected piece slides to its new square with a brief animation.

The fleet may complete zero, one, or multiple lateral sweeps during a chess beat depending on level speed, piece count, and screen size. Those sweeps affect visual pressure and, every second visual half-drop, logical rank descent (see §23.6). They do **not** create additional black chess turns. This keeps black move cadence predictable: approximately one black chess response every 5s on Levels 1–2 and every 4s on Levels 3+ unless retuned during playtest.

If White moves early, Black does not immediately get extra turns. The player's early move is applied, then the game waits for the current chess beat to reach its black-move phase. The ship, lasers, projectiles, raiders, and fleet all remain active during that wait.

*Design note:* Black's king will rarely move under normal chess engine logic, making it a hard but high-value shooting target.

### 5.3 Invader Firing

A "turn" is one scheduled chess beat: one White move or auto-move, followed by Black's configured chess move or moves for that level. Once per turn, 0–3 random black pieces (weighted toward front-rank pawns) fire a projectile straight down. (Level 1 has 0 shots/turn — see §21.1.) Projectiles travel at a fixed speed and can be:

- **Blocked** by a white piece with HP remaining (piece takes damage).
- **Shot down** by the player's spaceship laser.
- **Costs one life** if they reach the bottom strip and hit the spaceship.

### 5.4 Last Piece — Last Stand Rush

When the black piece count drops to **1**, normal fleet behavior stops and the Last Stand Rush triggers:

1. **Center dash:** The surviving piece slides to the center of the board (file d or e, whichever is closer to its current position) using a fast `SKAction` move — ~0.4 seconds. A brief magenta flare burst plays on arrival.
2. **Maximum speed:** Fleet movement speed immediately locks at **2.5× that level's base speed** (the §21.2 speed multiplier ceiling). The piece sweeps the full board width at this speed.
3. **Aggressive fire:** The piece fires **once per complete lateral crossing** (wall-to-wall), independent of the chess turn timer — effectively 2–3× its normal fire rate.
4. **Heartbeat:** Locks to 180 BPM immediately, regardless of current tempo.
5. **Chess AI:** The engine still takes its chess turn on the normal timer. If the last piece is the King, it moves with full aggression — the engine prioritizes threatening White pieces.

**Visual signal:** The piece's glow briefly pulses white on the center-dash arrival (one frame of full-white colorBlendFactor, then back to its normal magenta). This communicates "something changed" without any text overlay.

**Music duck:** When the Last Stand Rush triggers, the level music fades to **~20% volume over 1 second** via `AVAudioPlayer.setVolume(_:fadeDuration:)`. The heartbeat (now at 180 BPM) and the piece's Critical HP spark crackle become the dominant soundscape. On level clear, music fades back to full volume over 0.5 seconds before the level-clear fanfare plays. This moment typically lasts 10–20 seconds — brief enough to feel like punctuation, long enough to be memorable.

**Playtesting flag:** This sequence is designed to be exciting but may prove overwhelming — particularly if the last piece is a Queen or King with high HP and the player is on their last life. If testing shows it causes frustration rather than tension, the first thing to dial back is the fire rate (revert to once-per-turn). The center-dash and heartbeat spike can stay regardless. The entire feature is gated in `FleetController.triggerLastStand()` — one call site, easy to tune or disable.

---

## 6. Raider Ships (Bonus Attackers)

Periodically, independent arcade ships swoop across the board on attack runs. These are not chess pieces — they have no chess identity, cannot be captured by chess moves, and do not affect the chess game state. They are pure arcade targets.

### 6.1 Ship Types

| Ship | Inspired by | Behavior | HP |
|---|---|---|---|
| **Raider Scout** | Space Invaders mystery ship | Flies straight across at mid-board height (rank 4–5), fires one shot straight down, exits the far side. **First Scout of each level does not fire during its crossing** — the player sees the attack pattern before being shot at. Subsequent Scouts that level fire normally. The player's ship can always move and fire. | 1 |
| **Galaxian Escort** | Galaxian escort fighter | Peels off from the *back* of the black fleet formation (rear rank), dives in a curved arc toward the player's spaceship, then exits or loops back up | 1 |
| **Galaxian Flagship** | Galaxian flagship | Dives in flanked by 2 Escorts (they die first); fires 2 shots on descent; worth most points | 2 (immune to first hit — flashes) |

### 6.2 Spawn Timing

- Raiders are independent of chess turns. They spawn on a real-time interval, slightly randomized.
- **Level 1:** one Raider Scout every ~20 seconds.
- **Level 2+:** mix of Scouts and Escorts; Flagship appears once per level minimum.
- Later levels: spawn rate increases, Flagships appear 2–3× per level.
- A maximum of 2 raider ships are on screen at once so they don't overwhelm the chess action.

### 6.3 Attack Behavior

- **Raider Scout:** fires one projectile straight down from its current x-position as it crosses the board. Projectile behaves like a black-piece shot — damages white pieces it hits, kills the spaceship on contact. **First-pass rule (Galaga precedent):** the first Scout to appear each level makes its crossing without firing — the player sees the attack pattern before being shot at. All subsequent Scouts that level fire normally. Implementation: `RaiderController` tracks a per-level boolean `firstScoutWarningPassUsed`; reset to `false` on level start; set to `true` after the first Scout completes its crossing; Scouts spawned while `false` skip their fire command.
- **Galaxian Escort:** detaches from the back rank of the fleet (visually sliding out from behind the rearmost piece in its column), then swoops down in a curved arc toward the spaceship's last known position. Fires one shot at the apex of its dive. If it reaches the bottom strip without being shot, it costs the player one life (collision) or exits if the ship dodged. After exiting it does not return — a fresh Escort spawns next cycle. If all pieces in a column's back rank have been destroyed, the Escort spawns from the rearmost surviving piece in any adjacent column instead. If the entire fleet has been reduced to front-rank pieces only, the Escort spawns from the rearmost surviving piece on the board.
- **Galaxian Flagship:** dives with the same arc as Escorts but fires twice and requires 2 hits to destroy. On the first hit it flashes red (visual feedback) and accelerates its dive.
- **Kamikaze Escort** (Level 4+): A variant Escort that peels off with no shot — instead it dives straight and fast directly at the ship's current position with no warning audio cue. Requires a lateral dodge. Worth 200 pts if shot before impact. If it reaches the bottom strip it costs the player one life.
- **Galaxian Flagship escort shield:** While the Flagship's two flanking Escorts are alive, the Flagship is immune to player laser fire — shots pass through it. Once both Escorts are destroyed, the Flagship becomes vulnerable. A visual indicator (brief white flash + metallic clang SFX) plays when a shot hits the Flagship while it is still shielded, so the player learns the mechanic quickly.

#### King Protection Mode (Level 2+)

Raiders are not merely opportunistic attackers — from Level 2 onward they actively respond to threats against the Black King. When the player's ship has a **clear line of sight to the Black King** (no pieces blocking the column between the ship and the King), King-protection behaviors override normal attack patterns:

- **Raider Scout:** if the King's column is unobstructed as the Scout crosses, it slows and lingers directly over that column — firing an extra shot straight down before resuming its crossing. Effectively plugging the lane for 1–2 seconds.
- **Galaxian Escort (Level 3+):** instead of targeting the ship's last known position, the Escort targets the **Black King's column** and dives to block it. It fires at the apex as normal, then loops back toward the fleet. The "open King column" condition overrides the random dive timer.
- **Galaxian Flagship:** when the Black King is at Cracked or Critical HP and an open lane exists, the Flagship dives and **hovers directly in front of the King** for 2 seconds — a living shield. It can be shot normally during the hover (2 HP to destroy). This behavior overrides the standard flanked-dive pattern.
- **Kamikaze Escort (Level 4+):** if the King column is open and a Kamikaze is active, it dives into the King's column and hovers at mid-board for 1 second before resuming its dive toward the ship. A brief but real obstacle.

The result: opening a clean shot at the King is an achievement the game actively contests. Raiders give the Black King a dynamic bodyguard layer that chess piece placement alone cannot provide. The player must manage both chess defense (positioning pieces) and arcade interception (timing shots around Raider coverage) to land the killing blow.

### 6.4 Jeff Minter Tribute Ships

In honor of Jeff Minter — the programmer behind *Tempest 2000* (Jaguar, 1994) and the legendary Llamasoft catalogue — two bonus ships appear as flyover targets between levels. They are purely arcade targets with no chess identity, no fleet membership, and no attack behavior. They exist to reward attention and delight players who recognize the reference.

Sprite assets are already in `GCI.spriteatlas`: `ship-llama.imageset` and `ship-camel.imageset`.

#### Ship Types

| Ship | Points | HP | Appearance | Visual |
|---|---|---|---|---|
| **Llama** | 1,000 | 1 | Level 2 clear and every other level clear thereafter (2, 4, 6…) | Purple neon vector llama outline — long neck, spindly legs, unmistakable silhouette |
| **Mutant Camel** | 2,000 | 2 (takes 2 hits) | Level 3 clear and every third level clear thereafter (3, 6, 9…) | Gold/orange neon camel — larger than the Llama, moves slightly faster |

#### Behavior

Both ships appear during the **Level Clear score-tally screen**, flying slowly across the board from one edge to the other at mid-height. They travel at 55 px/s (Llama) and 70 px/s (Camel) — slow enough to be a reliable target, fast enough to punish inattention. The player's ship is still active during the tally screen and can fire.

- Neither ship fires, dives, or interacts with the chess board.
- A brief on-screen label appears for 1.5 seconds when they enter: **"LLAMA — 1000 PTS"** / **"MUTANT CAMEL — 2000 PTS"** in Press Start 2P, dim cyan, above the ship's position.
- If the Llama is not destroyed before it exits, it makes a soft bleat sound effect as it disappears off-screen. The Camel makes a low honking sound.
- If destroyed: a small celebratory burst in the ship's color (purple/gold respectively), the point value pops up, and a brief ascending chime plays — slightly more musical than a standard ship explosion.
- On levels where both the Llama and Camel would appear simultaneously (Level 6, 12…), the **Mutant Camel enters first**, followed 2 seconds later by the **Llama from the opposite edge**. Both are active at the same time.

#### Audio

| Event | Sound |
|---|---|
| Llama enters | Soft synthesized bleat (short, high-pitched) |
| Camel enters | Low synthesized honk |
| Either ship destroyed | Ascending 3-note chime + burst |
| Either ship exits unshot | Animal call fades out (Llama: bleat; Camel: low groan) |

#### Design Intent

These ships are a moment of levity and heritage in what is otherwise an intense game. They appear *after* the tension of a level, during the score screen — a reward for surviving, not an additional challenge. Long-time players will recognize the reference; new players will simply see a funny-looking bonus target and shoot it anyway. Both reactions are correct.

*"Everything is better with Llamasoft." — Jeff Minter tradition*

---

### 6.5 Interaction with White Pieces

Raiders are not blocked by white chess pieces — they fly in the mid-board z-layer (visually above the board). Their **shots** do hit white pieces normally.

Galaxian Escorts that dive can clip white pieces in their flight path: each white piece in the path takes 1 damage as the raider passes through (the raider is not destroyed by this).

### 6.6 Visual & Audio

- Raider Scout: classic UFO disc shape, scrolls with a distinct hum sound.
- Galaxian Escort/Flagship: bright colored neon-vector ships (orange/blue respectively), dive accompanied by a swooping pitch-slide sound effect.
- Each raider type has its own explosion animation, distinct from chess-piece explosions.

---

## 7. Hit Points & Damage System

### 7.1 Piece Hit Points

| Piece | Max HP | Laser hits to kill |
|---|---|---|
| Pawn | 2 | 1 hit |
| Knight | 6 | 3 hits |
| Bishop | 6 | 3 hits |
| Rook | 8 | 4 hits |
| Queen | 12 | 6 hits |
| King | 16 | 8 hits |

**Damage is shown by outline erosion — no HP bars, no chipped pixels.** The piece's neon outline cracks and fades through four named states (Full → Chipped → Cracked → Critical) as it takes hits. Higher-value pieces have more complex outlines and more HP, so they degrade more slowly and still look imposing when damaged:

| Piece | Max HP | HP damage to reach each damage state |
|---|---|---|
| Pawn | 2 | Full→Chipped at 1 HP damage; destroyed at 2 |
| Knight | 6 | Chipped at 2, Cracked at 4, Critical at 5 |
| Bishop | 6 | Chipped at 2, Cracked at 4, Critical at 5 |
| Rook | 8 | Chipped at 2, Cracked at 4, Critical at 6 |
| Queen | 12 | Chipped at 3, Cracked at 6, Critical at 9 |
| King | 16 | Chipped at 4, Cracked at 8, Critical at 12 |

**Implementation:** Each piece type has a small set of pre-rendered outline variants (one per damage state). The renderer selects the variant matching current HP bracket. No overlay bars drawn — the outline itself tells the story.

### 7.2 Damage Sources

- **Invader projectile hits a white piece:** piece loses 1 HP.
- **Player shoots a white piece (friendly fire):** piece loses 2 HP instantly (useful to clear a blocked firing lane intentionally).
- **Player shoots a black piece:** each laser hit deals **2 HP damage**. Piece is destroyed when HP reaches 0.
- **Chess capture:** captured piece is destroyed instantly regardless of HP.

### 7.3 Destroyed Pieces

When a piece's HP reaches 0:

- It flashes and explodes (particle effect).
- It is removed from the board — no longer a legal chess piece.
- It cannot be moved or used as a blocker.
- If it was the **white king**, game over (defeat).
- If it was the **black king**, game over (victory — bonus points awarded).

---

## 8. Spaceship

### 8.1 Controls (macOS)

| Action | Input |
|---|---|
| Move left | ← arrow key or A |
| Move right | → arrow key or D |
| Fire laser | Space bar |
| Select chess piece | Mouse click on piece |
| Move chess piece | Mouse click on destination square |
| Pause / resume | P, or Escape when no chess piece is selected |
| Deselect chess piece | Escape, right-click, or click empty space |
| How To Play / Info | I · ⌘I · ? |

### 8.2 Spaceship Properties

- Moves horizontally only, confined to the bottom strip below rank 1.
- Two-shot laser cap under normal conditions — up to 2 lasers on screen simultaneously. This increases with pawn promotions (see §25.9).
- Has **3 lives** (shown as ship icons in HUD). Loses a life when an invader projectile reaches the bottom strip and hits the ship, or when an enemy piece advances to rank 1.
- No HP on the spaceship — one hit = one life lost, then respawn at center.

### 8.3 Firing Lanes

The laser fires straight up from the ship's current column. White pieces in the same column act as obstacles unless already destroyed. This creates a strategic reason to clear your own pieces for a clean shot — but at the cost of your own defense.

### 8.4 Losing a Life & Respawn

When the spaceship is hit it explodes, a life icon is removed from the HUD, and the ship respawns at the horizontal center of the bottom strip after a 1-second delay. The respawned ship is **invincible for 2 seconds**, flashing rapidly to signal the grace period. It can still move and fire during those 2 seconds. After 2 seconds invincibility ends with a final bright flash.

If the last life is lost the game ends immediately — no respawn.

### 8.5 Lives & HP Between Levels

- **Lives carry over** between levels. Losing a life on level 2 means starting level 3 with 2 lives. Lives can be replenished by reaching the 1,500-point milestone (see §9.1 — awarded once per game) or via future power-ups.
- **White piece HP resets to full** at the start of each new level. All 16 white pieces are restored to their starting positions and full HP — a fresh chess setup every level.
- **Spaceship position resets** to center-bottom at each level start.

---

## 9. Scoring

| Event | Points |
|---|---|
| Shoot black Pawn | 25 |
| Shoot black Knight | 50 |
| Shoot black Bishop | 50 |
| Shoot black Rook | 75 |
| Shoot black Queen | 150 |
| Shoot black King | 500 |
| Chess capture (Pawn) | 10 |
| Chess capture (Knight/Bishop) | 25 |
| Chess capture (Rook) | 40 |
| Chess capture (Queen) | 75 |
| Chess capture (King) | 500 |
| Shoot down invader projectile | 5 |
| Shoot Raider Scout (Space Invader ship) | 100 |
| Shoot Galaxian Escort | 150 |
| Shoot Galaxian Flagship | 300 |
| Destroy regenerated black Pawn | 15 (reduced — it came back) |
| Checkmate (king still alive) | 300 bonus |
| Shoot King that is simultaneously in checkmate | 500 (shot) + 300 (checkmate) = **800 total** — both bonuses awarded, logged separately |
| Clear a wave (all black pieces gone) | Level × 200 bonus |
| White piece surviving at level end | 10 × piece value |

Score multiplier starts at 1.0× and increases by 0.5× at the start of each new level (Level 1: 1.0×, Level 2: 1.5×, Level 3: 2.0×, etc.). Points scored during a level use that level's multiplier.

### 9.1 Extra Life Milestone

**One free life is awarded at 1,500 points.** This happens exactly once per game — reaching 1,500 again after losing that life grants nothing further.

- A brief jingle plays (classic ascending 3-note chime, same as the existing "extra life" SFX in §12.12).
- The lives display in the HUD ticks up by one with a quick flash.
- "1UP" appears briefly as a score pop-up at the ship's position.

**Rationale:** 1,500 pts is achievable by an average player completing Level 1 with decent board clearing and a few Scout kills — it rewards early engagement without becoming farmable. Original *Space Invaders* (1978) used 1,500 pts as its free-life threshold; the homage is intentional.

---

## 10. Level Structure

### 10.1 Wave Progression

Each level begins with a fresh standard chess setup and full white piece HP. Escalation happens across two tracks simultaneously: the chess engine gets more aggressive and the arcade action gets more intense.

#### Level 1 — Tutorial Wave

- Fleet speed: slow (40 px/s)
- Black chess moves: 1 per turn, passive engine (avoids losses)
- Scheduled fleet shots: **none** — black chess pieces do not make normal per-turn projectile attacks in Level 1. The player's ship can always fire. Exceptions: Raiders follow their own rules, and the Black King fires one slow warning shot if it reaches Critical damage (see "Level 1 warning shot" below).
- Raiders: Scouts only, 1 every 20s
- No Escorts, no Flagship
- Turn timer: 5s
- *Feel: learnable. Player figures out the dual controls without normal scheduled fleet shots. Raiders provide the only repeatable incoming fire — but the first Scout of each level crosses without shooting (Galaga precedent), so the player sees the attack pattern before being in danger. The Black King's Level 1 warning shot is a one-time preview, not part of the normal fleet firing cadence.*

**First-play hover hints (first run only):** On the first time a player ever reaches Level 1 (tied to the `hasSeenHowToPlay` flag from §14.4), two lightweight floating labels appear at level start:

1. **Above the player's ship:** `← → MOVE   SPACE FIRE` — small pixel-font text, no background, no border. Fades out after 5 seconds or on first ship movement or laser fire, whichever is first.
2. **Above the d2 pawn** (a natural first chess move): `CLICK PIECE → CLICK SQUARE` — same style. Fades out after 5 seconds or on any chess piece selection, whichever is first.

Both hints are non-blocking: all controls are fully live while the hints are visible. No modal, no sequence, no forced action. If playtesting shows they're distracting, remove the entire feature — they're isolated in a single `HintOverlayNode` class.

**Level 1 warning shot:** When the Black King reaches **Critical HP** (d2 + flicker state, approximately 4 HP remaining) during Level 1, the King fires a single projectile straight down — the first fleet shot the player has ever seen in the game. The shot travels at **50% of the normal Level 2 projectile speed**, making it clearly visible and easy to dodge or shoot down. No audio cue precedes it beyond the normal firing sound; the slow speed is the telegraph.

This is a preview, not a punishment. It tells the player: "Level 2 fires at you. Get ready." If the player kills the King before it reaches Critical HP in one sequence of shots (unlikely but possible), the warning shot is skipped — no forced scripted moment.

#### Level 2 — Pressure Builds

- Fleet speed: medium (55 px/s)
- Black chess moves: 1 per turn, engine shifts to **aggressive** — actively advances pawns, prefers attacking moves over passive ones
- Invader shots: 1–2 per turn
- Raiders: Scouts + single Escorts begin appearing
- Turn timer: 5s
- *Feel: chess starts mattering. Black pieces advance toward you with intent.*

#### Level 3 — Double Trouble

- Fleet speed: medium-fast (70 px/s)
- Black chess moves: **2 per turn** — two distinct pieces move to two distinct destination squares, creating a dramatic visual surge that makes the formation suddenly unpredictable. The moves are selected as a non-conflicting set before either animates; they execute in parallel with a shared animation trigger
- Invader shots: 2 per turn; diagonal shots introduced
- Raiders: Escorts now dive in **synchronized pairs**
- Flagship appears for the first time (once per level)
- Turn timer: 4s
- *Feel: the player is constantly reacting. Two chess moves per turn means the board shifts rapidly.*
- *Implementation note: for 2 (and 3) simultaneous moves, use the simple multi-move selection rule in §25.5. Moves animate in parallel with a shared `SKAction` group after the legal set is chosen.*

#### Level 4 — Relentless

- Fleet speed: fast (90 px/s)
- Black chess moves: 2 per turn, fully aggressive engine
- **Piece regeneration begins:** destroyed black pieces occasionally respawn as Pawns at the back of the fleet after ~10 seconds. Maximum 2 regenerations per level.
- Invader shots: 2–3 per turn, fire rate spikes when fewer than 5 pieces remain
- **Projectile speed increases to 200 px/s** (up from 180 px/s at Levels 2–3)
- Raiders: Escorts **loop back** after diving — they arc up and attack a second time before exiting. Flagship appears 1–2× per level.
- **Kamikaze Escorts** introduced: fast no-shot dive straight at the ship. No warning, requires a lateral dodge.
- Turn timer: 4s
- *Feel: the fleet never fully dies. Regeneration makes clearing the board feel urgent.*

#### Level 5 — Overwhelming

- Fleet speed: very fast (110 px/s)
- Black chess moves: **3 per turn** — all three animate simultaneously at the black-move phase of the scheduled chess beat
- Piece regeneration: up to 4 regenerations per level
- Invader shots: 3 per turn (cap); projectile speed increases by 20%
- Raiders: mix of paired Escorts, looping Escorts, Kamikazes, and 2–3 Flagship appearances
- Random black piece "rushes" — once per full-rank logical descent, after the second visual half-drop has updated the board state, one black piece jumps 2 ranks forward
- Turn timer: 4s
- *Feel: barely controlled chaos. Chess moves are survival decisions, not strategy.*

#### Level 6+ — Infinite Escalation

- Each level beyond 5 adds: +15 px/s fleet speed, +10% projectile speed, one additional regeneration slot
- Chess moves per turn stays at 3 (cap)
- Turn timer stays at 4s (floor)
- Flagship appears 3× per level minimum
- Kamikaze frequency increases each level
- *No ceiling — the game continues until the player dies.*

#### Level 7 — King Activated

A mechanic banner announces `KING ACTIVATED` / `THE KING NOW ATTACKS` at level start.

From Level 7 onward, the Black King is no longer passive — the engine shifts to **aggressive King play**, treating it as an attacking piece rather than one to protect. In chess endgame terms, an active King is genuinely dangerous.

**Chess behavior change:** The `GKMinmaxStrategist` AI weight for King moves is raised sharply — the engine will now actively advance the King toward White's back ranks, use it to threaten White pieces, and prioritise King moves over pawn pushes when an attacking King move is available.

**Visual cue:** The King's glow shifts from standard magenta (`#FF2060`) to a fierce **orange-red** (`#FF4400`) for the duration of Level 7+. This is distinct from the Critical HP crimson pulse — it is a constant color change that says "this piece has changed character." A brief crown-flash animation (one frame of full white followed by the new color) marks the moment the King activates at level start.

**Mechanic banner:** Shown once at Level 7 entry — `KING ACTIVATED` (large) / `THE KING NOW ATTACKS` (subtitle). Level 8+ does not repeat the banner.

#### Level 9 — Armored Pawns

A mechanic banner announces `ARMORED PAWNS` / `CHESS ONLY · BULLETS BOUNCE` at level start.

From Level 9 onward, **50% of regenerated Pawns** spawn as **Armored Pawns** — immune to laser fire for their armor window. Only a chess capture can remove them during this period.

**Rules:**

- Armored Pawns appear only through the regeneration system (standard or defensive), never as part of the starting board formation.
- Armor duration: **3 chess turns** after materialisation. A turn counter ticks down on each White move completion.
- After armor expires, the Pawn becomes a normal Pawn — same HP, same behavior, now laser-vulnerable. If destroyed by laser after armor has expired, it scores **15 pts** (reduced rate — the armor window was the hard part, and the pawn regenerated; it shouldn't reward as much as a starting-board pawn at 25 pts).
- Laser hits during the armor window: do zero damage, produce a spark ricochet effect, and play a distinct clunk/ricochet SFX.
- Chess captures work normally during and after the armor window.

**Visual design:**

- Standard Pawn sprite replaced by an **Armored Pawn variant**: same shape but with a heavy **silver metallic outline** (2px bright silver `#C0C8D0`) and a slightly darker, steel-grey tinted body. Feels immediately heavier and more dangerous than a regular Pawn.
- When a laser hits: a yellow spark burst at the impact point, the Pawn flashes white for one frame (impact feedback), and the armor outline briefly brightens. No HP lost.
- As armor expires (turn 3): the silver outline develops a hairline crack animation over 0.5 seconds, then shatters away in a brief particle burst — revealing the standard magenta Pawn beneath. Clear visual signal that it's now vulnerable.

**Audio:**

- Laser hit during armor: a sharp metallic "chunk" — a short percussive noise burst with a high-frequency click. Completely unlike normal hit sounds; instantly communicates "that didn't work."
- Armor break: a brief brittle shattering sound (high-pitched glass-crack character) on the turn it expires.

**Mechanic banner:** Shown once at Level 9 entry. Level 10+ does not repeat it.

### 10.2 Level End Conditions

A level ends when:

- **Victory:** The Black King is destroyed (shot to 0 HP), captured by a chess move, or checkmated. The level ends immediately — clearing remaining pieces is a score-maximizing strategy, not a requirement. If pieces remain when the King falls, the wave-clear and surviving-white-piece bonuses are not awarded; the board resets clean.
- **Defeat:** White king is destroyed, White king is checkmated, or the spaceship loses all remaining lives, or any black piece reaches rank 1 (they've "landed").

On victory, a brief score-tally screen appears before the next level loads.

---

## 11. Game States

```
MAIN_MENU
    └─► NEW_GAME → PLAYING
                      ├─► LEVEL_CLEAR → SCORE_TALLY → PLAYING (next level)
                      └─► GAME_OVER → SCORE_TALLY → MAIN_MENU
PLAYING ──► PAUSED ──► PLAYING
PLAYING ──► INFO   ──► PLAYING (game resumes on BACK or any key)
```
---

## 12. Visuals & Audio

### 12.1 Overall Art Direction

The visual style is **neon-vector Recharged** — smooth glowing outlines on a pure black void, with bloom added live at runtime. The aesthetic is retro-inspired but modern: Tron-like neon line art, not a blown-up low-resolution game. Think Atari Recharged, not Intellivision.

**The key visual rule:** sprites must look sharp and smooth at their display size on Mac screens, including Retina and standard displays. The danger to avoid is low-resolution assets scaled up 2× or 3×, which produces blocky, jagged, stairstepped edges. Sprites should be authored at sufficient resolution that they look clean when scaled *down* to fit the board, never scaled up.

**Core principles:**

- **Retro-inspired, modern execution** — neon glow and classic chess silhouettes, but crisp and smooth, not chunky or pixelated
- **Bloom at runtime** — clean line art; glow added live via `SKEffectNode`, not baked into sprite sheets
- **Pure-black void** — `#000000` background; pieces float in space; parallax starfield + nebula
- **Outline-forward** — empty interiors, bright neon edges, white-hot cores
- **Arcade FX** — capsule laser trails, dash-spark debris, fireball blasts
- Everything glows. Lasers glow. Pieces glow. Explosions bloom outward.

The tone is neon space-opera: like playing chess inside a laser light show at a 1983 arcade, rendered on a modern Retina display.

#### Color Palette

| Role | Hex | Usage |
|---|---|---|
| Void | `#000000` | Background |
| Player | `#12E0FF` | White pieces, player ship, UI |
| Enemy | `#FF2060` | Black pieces, enemy shots |
| Scout | `#7DFF4D` | Raider Scout ship |
| Escort | `#FF8A1E` | Galaxian Escort ship |
| Flagship | `#3AA2FF` | Galaxian Flagship |

#### Typeface

**Press Start 2P** — used for all display text: titles, HUD, scores, menus. All caps. This is a freely available Google Font that perfectly captures the golden-age arcade CRT look.

---

### 12.2 Piece Sprite Design

Chess pieces use **classic chess silhouettes rendered as neon vector outlines** — the shapes found in Sargon II/III and early IBM PC chess programs, reborn as smooth glowing line art. The pawn's rounded head, the knight's horse profile, the bishop's mitre, the rook's battlements, the queen's tall crown, the king's cross-topped crown. These are not spaceships. They are immediately recognizable chess pieces given the Recharged neon-vector treatment.

**Reference aesthetic:** Sargon III (Apple II, 1983), Chessmaster 2000 (PC, 1986) for silhouette shapes — but rendered as smooth vector outlines with neon glow, not as pixel art.

#### Palette & Glow

Both sides share the same silhouette shapes. Color and glow distinguish them:

| Side | Outline / glow color | Interior | Effect |
|---|---|---|---|
| **White (player)** | `#12E0FF` cyan | Empty / dark fill | Steady glow, clean |
| **Black (enemy)** | `#FF2060` magenta-pink | Empty / dark fill | Slightly more intense pulse |

Interiors are largely empty — the outline and its bloom do the work. A player identifies side instantly by color, without reading the shape. Both palettes are consistent across all six piece types on each side.

#### Sprite Sizes & Shapes

There are three different sizes to keep distinct:

- **Source asset size:** the pixel dimensions of the PNG in `GCI.spriteatlas`. These stay large so the neon outlines remain smooth on Retina displays.
- **Displayed size:** the size of the `SKSpriteNode` on screen. This is calculated at runtime from the board square size.
- **Collision / selection size:** the gameplay hit area derived from the displayed node size. This may be slightly larger than the visible sprite for easier mouse selection and forgiving laser hits.

Actual source asset dimensions from `GCI.spriteatlas`:

| Piece | Silhouette | Source PNG size (@2x) | Reference logical size if unscaled |
|---|---|---|---|
| **Pawn** | Round head, short neck, flared base — smallest piece | 160×232 px | ~80×116 pt |
| **Bishop** | Tall stepped mitre, narrow waist, flared base | 176×264 px | ~88×132 pt |
| **Rook** | Squat fortress tower, flat 3-merlon battlements, wide base | 192×256 px | ~96×128 pt |
| **Queen** | Rounded orb crown top, wide flared shoulders, hourglass waist | 192×272 px | ~96×136 pt |
| **King** | Cross finial top, wide layered base — tallest piece | 192×288 px | ~96×144 pt |
| **Knight** | Horse head in profile, mane and neck detail — only asymmetric piece | 208×264 px | ~104×132 pt |

Ships (for reference):

| Ship | Source PNG size (@2x) | Reference logical size if unscaled |
|---|---|---|
| Player Fighter | 232×200 px | ~116×100 pt |
| Raider Scout | 280×144 px | ~140×72 pt |
| Galaxian Escort | 224×176 px | ~112×88 pt |
| Galaxian Flagship | 272×160 px | ~136×80 pt |

**Canonical display sizing rule for macOS v1.0:** The source PNG dimensions above are **not** the on-screen size. `BoardLayout` computes `squareSize` from the current scene size after reserving space for the HUD, spaceship strip, and any visible diagnostics sidebar. Each chess piece is scaled so its displayed bounding box fits inside its square with consistent margins:

- Pawn: max height 62% of `squareSize`
- Knight / Bishop / Rook: max height 72% of `squareSize`
- Queen: max height 78% of `squareSize`
- King: max height 82% of `squareSize`

The piece keeps its source aspect ratio. If width would exceed 90% of `squareSize`, width becomes the limiting dimension instead. This prevents tall pieces from overlapping adjacent ranks and wide pieces from overlapping adjacent files.

**Minimum playable size:** On macOS, `squareSize` should not fall below 48 pt in normal windowed play. At the minimum supported window size (640×500 pt), the board layout must still keep the King at approximately 39 pt tall or larger (`48 * 0.82`) and keep selection targets usable. If a smaller window would force `squareSize < 48`, the app should preserve the minimum window size or letterbox the playfield rather than shrinking the board further.

**Collision sizing:** Piece physics bodies use the displayed node size, not source PNG pixels. Default body: centered circle with radius `min(displayedWidth, displayedHeight) * 0.42`. This is an arcade hitbox, not a pixel-perfect silhouette. It should be forgiving enough that a vertical laser through a piece's visual body registers consistently, while still narrow enough that shots in adjacent files do not hit accidentally. If a specific piece feels unfair in playtest, adjust its displayed-size-derived circle or rectangle; never use source PNG dimensions directly.

**Mouse selection sizing:** Mouse selection on macOS uses the displayed node bounds padded by 8 pt on all sides, with a minimum selectable rectangle of 40×40 pt. The visible sprite does not grow just because the selection target is padded.

**Future touch note:** If an iOS/iPadOS port is pursued later, touch targets should be re-evaluated separately. Do not let future touch requirements distort the Mac v1.0 board layout.

**Atlas naming convention:** `chess-[w/b]-[piece][-d1/-d2].png` — e.g. `chess-w-pawn.png` (full), `chess-b-rook-d1.png` (chipped), `chess-w-queen-d2.png` (cracked). Ships: `ship-[player/scout/escort/flagship].png`.

> ⚠️ **Smoothness note:** The current pawn sprite has some stairstepping in its outline. All sprites must look clean and smooth at their logical display size — not jagged or blocky. If any asset shows stairstepping at display scale, it should be redrawn at higher resolution or with smoother curves before ship. The bloom from `SKEffectNode` softens edges slightly but is not a substitute for smooth source art.

The Recharged glow is rendered by the parent `SKEffectNode` bloom pass — it is never baked into the artwork, keeping the outlines clean and sharp underneath. No `filteringMode = .nearest` needed — these are smooth vector-style shapes, not pixel art.

Each piece has animation states: idle float (gentle bob), move (brief brighten flash), damage states (see below), and destruction (explosion sequence).

**Damage = outline erosion.** As a piece takes hits its neon outline cracks, fragments, and fades — the piece literally losing its glow. No HP bar. Three sprite variants per piece in the atlas, plus a programmatic Critical state:

| State | Atlas variant | Appearance |
|---|---|---|
| **Full** | `chess-[w/b]-[piece].png` | Bright, clean outline — full neon glow intact |
| **Chipped** (d1) | `chess-[w/b]-[piece]-d1.png` | Outline starts to break; small cracks and gaps appear |
| **Cracked** (d2) | `chess-[w/b]-[piece]-d2.png` | Significant outline loss; internal lightning/energy bursts visible in the gaps |
| **Critical** | d2 sprite + programmatic flicker | d2 sprite rendered at reduced alpha with a slow flicker — no additional art asset needed |

At 0 HP: explosion, then gone.

Higher-value pieces have thicker, more complex outlines — a Queen or King takes proportionally longer to visually degrade than a Pawn, so they still look imposing even when damaged.

---

### 12.3 The Board

The board is rendered as a **space battle grid** floating in the void:

There is **no visible board grid**. The 8×8 grid exists only as an internal data structure used for chess move calculation, collision zones, and piece positioning. On screen, pieces float freely in space with no lines, squares, or borders drawn beneath them.

This is essential because black pieces slide horizontally beyond the logical board boundary during their Invader-pattern movement — a visible grid would break the illusion immediately.

Visual feedback that would normally rely on the grid is handled differently:

- **Selected piece:** a soft cyan glow halo pulses around the selected piece itself — no square highlight
- **Legal move indicators:** small neon green crosshair reticles (`⊕`, ~8px) appear floating at the center of valid destination positions in space — no square, just the marker. A reticle is a targeting crosshair, like the sight on a weapon — here it marks where you can legally move the selected piece.
- **Last move trail:** a brief neon orange motion-blur streak follows the piece as it moves, fading within ~0.5 seconds — no persistent square tint
- **Check indicator:** the white king's sprite pulses red and a warning flash appears in the HUD — no square glow needed
- **Piece "home" zones:** very faint, barely visible horizontal bands of slightly lighter black mark the white deployment zone (bottom) and black fleet zone (top) — not a grid, just a subtle atmospheric depth cue that can be toggled off in settings

The result: pieces read as ships in open space, not tokens on a board. The chess structure is invisible; the arcade feel is total.

---

### 12.4 Background & Layers

The scene has **4 parallax layers**, back to front. (Phase 2.2 implements 2 layers; the remaining 2 layers are added in Phase 8 — see §20.)

| Layer | Content | Scroll speed |
|---|---|---|
| 0 (furthest) | Dense starfield — tiny 1px white dots, pure black bg | 0.2× |
| 1 | Mid stars — slightly larger, occasional neon blue/cyan tint | 0.5× |
| 2 | Neon nebula wisps — thin glowing streaks of cyan and magenta, very faint | 0.3× horizontal drift |
| 3 (closest) | Occasional geometric debris — wireframe polygon shapes (Recharged style) drifting past | 0.8× |

All layers scroll **downward** very slowly. During level-clear the scroll accelerates into a **hyperspace jump**: stars stretch into lines, white flash, then new level fades in. The wireframe debris chunks in layer 3 should feel like Asteroids Recharged geometry — vector outlines with a soft glow, not solid filled shapes.

### 12.5 Level Color Temperature Progression

Inspired by *Breakout Recharged*, the background void color shifts subtly between levels — cold at the start, warmer and more ominous as the game progresses. The shift happens during the level-clear hyperspace transition so it reads as a scene change, not a distraction during gameplay.

**Level color table:**

| Level | Void color | Mood |
|---|---|---|
| 1 | `#07070F` — deep blue-black | Cold open space |
| 2 | `#08070F` — indigo-black | Deepening dark |
| 3 | `#0A0610` — deep violet | Unease begins |
| 4 | `#0D0610` — purple-black | Threat escalating |
| 5 | `#100510` — near-crimson black | Danger zone |
| 6 | `#12050C` — dark red-black | Hostile |
| 7 | `#140408` — deep crimson | Late-game dread |
| 8+ | `#160304` — near-red black | Barely survivable |

The star layers tint to complement — Layer 0 stars remain white, Layer 1 stars gain a slight warm tint (`colorBlendFactor` shift toward amber at Level 5+).

**Performance rules — non-negotiable:**

- Background color is set by changing `scene.backgroundColor` once per level transition, inside the hyperspace flash. Zero per-frame cost.
- Star layer tinting uses `SKSpriteNode.color` + `colorBlendFactor` — a static property change, not a shader. Zero per-frame cost.
- **No CIFilter, no fragment shader, no SKEffectNode** for the background color shift. Those are reserved for bloom on piece glows only.
- Within a level, the background color is static — no gradual hue animation during active gameplay. The shift only happens during the level-clear transition.
- If profiling shows the background layers consuming meaningful GPU time, drop Layer 2 (nebula wisps) first — it is the most expensive layer and the least missed.

---

### 12.6 HUD Design

```
┌──────────────────────────────────────────────────────────────────┐
│  SCORE: 004750   HI: 012300   LEVEL 03   ♠ ♠ ♠   [(i) INFO]    │
└──────────────────────────────────────────────────────────────────┘
```
- **Font:** monospace pixel font (e.g., Press Start 2P or a custom 8×8 bitmap font). All caps.
- **Score:** left-aligned, white. Digits roll up arcade-style when points are added.
- **Hi-Score:** center, dim yellow — flashes briefly when beaten.
- **Level:** right of center, white.
- **Lives:** right-aligned, shown as small spaceship silhouette icons (♠ placeholder above).
- **Info button chip:** far right, past the lives display. Rendered as a small neon-outlined pill in dim cyan showing the word **INFO** preceded by a small icon — either a circled-i `ⓘ` or a question-mark `?` (implementation decision). Clicking or tapping it opens the How To Play screen and pauses the game. Keyboard shortcuts: `I`, `⌘I`, `?`. The chip does not flash or animate during gameplay — it stays subtle so it never competes with live action.
- **Turn timer:** large digital countdown in the lower-left corner of the board area. Green → yellow → red as it counts down. Pulses on the last 2 seconds.
- **Auto-move indicator:** when the engine moves white, "AUTO" flashes in orange over the piece for 0.5 seconds.
- **Chess notation log:** debug/development builds only. Not shown in release builds — it would expose algebraic notation labels (a–h, 1–8) which are intentionally hidden from the player.

---

### 12.7 Lasers & Projectiles

| Projectile | Visual |
|---|---|
| Player laser | Bright cyan-white vertical beam, 2px core + bloom halo. Leaves a fading neon trail. |
| Invader shot (straight) | Hot magenta/red bolt, 3px, wobble animation, strong glow |
| Invader shot (diagonal, Level 3+) | Same bolt, rotated 45°, deep purple glow |
| Raider Scout shot | Acid green bolt — distinct from all other projectiles for readability |
| Escort/Flagship shot | Wide orange bolt with a trailing comet tail of particles |

All projectiles have a **neon bloom halo** (blur-and-add shader) and leave a **fading ghost trail** 4–6 pixels long. The overall effect should look like the projectiles in Asteroids Recharged or Tempest — bright cores with soft halos burning against pure black.

---

### 12.8 Explosions & Particle Effects

- **Small explosion** (Pawn, Escort): 8-frame sprite burst, ~24×24 px, orange/yellow
- **Medium explosion** (Knight, Bishop, Rook): same but ~36×36 px, adds white flash frame
- **Large explosion** (Queen, Flagship): ~48×48 px, multi-color (red → orange → white center), screen briefly flashes
- **King/Mothership destruction**: full-screen white flash, then an expanding ring shockwave sprite, then debris particles that drift and fade over ~2 seconds. Screen shakes for 0.3 seconds.
- **Ship destroyed**: same as medium explosion centered on the ship, followed by a respawn animation (ship fades in at center-bottom)
- **Piece damaged (not destroyed)**: small spark burst at impact point, 3-frame, no lingering particles
- **Smoke trail**: looping 4-frame animation attached to damaged pieces at ≤50% HP (complements the chipped sprite rather than replacing it)

---

### 12.9 Raider Ship Visuals

- **Raider Scout**: classic flying-saucer disc, 24×16 px. Wireframe-style outline with a spinning inner ring animation. Glows acid green, blinking underbelly light. Recharged-style — geometric, minimal, luminous.
- **Galaxian Escort**: narrow dart shape, 16×20 px. Hot orange outline, cyan engine glow at the tail. Wing-flap 2-frame animation in formation; elongated dive silhouette when attacking.
- **Galaxian Flagship**: wide and imposing, 32×24 px. Electric blue outline with gold/white center detailing. On first hit: full-body white flash and a shield-ring ripple effect before it accelerates. The most visually striking ship on screen.

---

### 12.10 Menus & Screens

- **Title screen:** "GALACTIC CHESS INVADERS" in large cyan neon (Press Start 2P), "★ 40 YEARS IN THE MAKING ★" in orange beneath it. A single row of 8 magenta chess pieces slides slowly left and right as a preview. "PRESS ANY KEY TO START" blinks below. Top 5 high scores displayed with initials, score, and level reached.
- **How To Play screen:** accessible from the **title screen** and from **within gameplay** via the Info button chip (`[(i) INFO]` in the HUD) or keyboard shortcuts `I`, `⌘I`, `?`. Opening it during gameplay pauses the game immediately. Content: controls, the dual-input twist, how to win, how to stay alive, scoring table (piece icons with point values), and the origin note. A **BACK** button in the lower-left (or pressing any key) dismisses the screen and resumes gameplay from the exact state it was in.

  **Canonical closing line of the How-to-Play screen** (displayed last, in a slightly dimmer style to distinguish it from the instruction text):

  > *"DON'T KNOW CHESS? JUST SHOOT EVERYTHING — IT STILL WORKS."*

  This line must always be present. It immediately lowers the skill-floor perception for non-chess players and confirms the game is approachable for anyone.
- **High score entry:** 8-character initial entry using up/down arrows per character, classic arcade style.
- **Pause screen:** triggered by **P**, or by **Escape** when no chess piece is selected. Game blurs/dims, "PAUSED" centered in large text. No menu, no settings, no secondary options. Press **P** or **Escape** again to resume while paused. Other gameplay input is ignored while paused.
- **Level clear screen:** score tally animates upward (points counting up sound effect), then "LEVEL X CLEAR" banner sweeps across. The two Jeff Minter tribute ships (§6.4 — llama silhouette and camel silhouette) make a brief flyover pass across the screen during the tally, purely decorative.
- **Game over screen:** "GAME OVER" in large magenta neon. Three stats centered below: FINAL SCORE | HI-SCORE (in orange if beaten) | LEVEL REACHED. A large explosion fireball lingers and fades at center-bottom — the player ship's last moment. "PRESS FIRE TO PLAY AGAIN" blinks; "ESC → MAIN MENU" beneath it.

### 12.11 Level Mechanic Announcement Banner

When a level introduces a genuinely new mechanic for the first time, a **mechanic banner** sweeps in at level start — before gameplay begins, after the level-clear transition. It exists to frame the escalation as a dramatic reveal rather than a surprise attack.

**Format:** Two lines of Press Start 2P pixel text, centered, over the board:

```
  ══════════════════════════════
   LINE 1 — MECHANIC NAME      ← large, bright white, ≤18 chars
   Line 2 — brief explanation  ← smaller, dim cyan, ≤22 chars
  ══════════════════════════════
```
**Animation sequence:**

1. Board and pieces are already visible (level just loaded). Ship is at start position.
2. Banner slides in from the **left** with a slight elastic overshoot — arrives at center in ~0.35s. Neon glow pulses once on arrival.
3. Background dims to ~40% while banner is visible (a dark overlay, not a fade to black).
4. Mechanic sting plays simultaneously with arrival (see audio below).
5. Banner holds for **2.0 seconds**.
6. Banner fades out in 0.3s. Dim overlay lifts. Gameplay begins.

Player input is **ignored** during the banner — no movement, no firing, no chess input. Duration is short enough that this never feels like a wait.

**Audio:** A distinct 1.5s synth sting — not the level-clear fanfare. Character shifts with urgency:

- Levels 2–3: ascending bright arpeggio (exciting, "new power unlocked" feel)
- Levels 4–5: lower, more ominous two-note chord hit
- Level 6+: a single deep bass hit with a descending tail ("this is going to hurt")

**Mechanic banner table** (shown once per mechanic, first time only — not repeated if the player reaches that level again in the same session. Level 4 has two banners shown sequentially; all others have one):

| Level | Line 1 | Line 2 |
|---|---|---|
| 2 | `FLEET NOW FIRES!` | `DODGE · SHOOT BACK` |
| 3 | `DOUBLE ATTACK` | `BLACK MOVES TWICE PER TURN` |
| 4a | `THE DEAD RETURN` | `PIECES RESPAWN · FINISH THEM` |
| 4b | `KAMIKAZES!` | `WATCH FOR FAST DIVERS` |
| 5 | `TRIPLE ATTACK` | `3 CHESS MOVES PER TURN` |
| 6+ | `DEEPER NOW` | `FASTER · MEANER · STILL POSSIBLE` |
| 7 | `KING ACTIVATED` | `THE KING NOW ATTACKS` |
| 9 | `ARMORED PAWNS` | `CHESS ONLY · BULLETS BOUNCE` |

Level 4 shows both banners sequentially — regeneration first (2s hold, fade, 0.3s gap), then Kamikazes (2s hold, fade), then gameplay.

**Implementation:** `MechanicBannerNode` — a self-contained `SKNode` subclass that takes `(line1: String, line2: String, sting: AudioClip)` and runs the full sequence via `SKAction` chain. `GameScene` calls `showBanner(for level:)` and awaits completion before enabling input. Shown once per mechanic per session, tracked in a `Set<Int>` of already-seen levels in `GameState`.

### 12.12 Audio Design

**SFX:** 8-bit / chiptune style — short synthesized tones. Generated with jsfxr or similar, exported as `.caf` for minimum latency (see §17.3).

**Music:** Modern electronic / dark synthpop in the Atari Recharged vein — not classic 8-bit beeps. Think driving synth with 80s/90s flavor: melodic, punchy, loopable. See §17.4 for sources and workflow.

#### Soundtrack

Each level has a **pool of 1–3 tracks**; one is picked randomly at wave start (never repeating the same track twice in a row). Higher levels use faster, more intense tracks. This is simpler and more reliable than adaptive tempo shifting, which causes pitch artifacts when using `AVAudioPlayer.rate`.

| Level | Tracks | Feel |
|---|---|---|
| 1 | 3 | Mid-tempo, accessible, slightly mysterious — most-played level gets most variety |
| 2 | 2 | More urgent |
| 3 | 2 | Driving, intense |
| 4 | 2 | Fast, aggressive |
| 5+ | 1 | Relentless |

Additionally:

- **Title screen:** atmospheric, slower, spacey
- **Level clear:** short punchy fanfare sting (3–4 seconds)
- **Game over:** brief descending dark riff

#### Sound Effects

**Player Spaceship**

| Sound | Character | Notes |
|---|---|---|
| Laser fire | Short rising tone, square wave | `pew` — 80ms, pitch 440→880 Hz |
| Laser hit (piece damaged) | Crunchy noise burst | Different pitch per piece type so you can hear what you hit |
| Laser miss (off-screen) | Soft descending blip | Subtle — doesn't compete with other sounds |
| Ship thrust (moving) | Very quiet low hum | Optional; can be toggled off in settings |
| Ship destroyed | Descending noise sweep + three-note death chord | Longer — ~1.5 seconds |
| Extra life awarded | Classic ascending 3-note jingle | |

**Chess Mechanics**

| Sound | Character | Notes |
|---|---|---|
| White piece selected | Soft tick, high pitch | Confirms selection without being distracting |
| White piece moves (chess) | Woody thud or stone-on-stone | Evokes a physical chess move |
| Black piece moves (chess) | Same but lower pitch | Distinguishes whose turn moved |
| Auto-move (timer expired) | Buzzer + move sound | Slightly harsh to signal the player was too slow |
| Turn timer warning (≤2s) | Rapid high-pitched ticking | Gets faster each tick |
| Pawn promotion | Ascending arpeggio flourish | Celebratory |
| Check | Sharp two-note alarm stab | Demands attention |

**Piece Destruction**

Each piece type has a unique explosion sound so the player gets audio feedback on what was hit without looking:

| Piece | Explosion sound |
|---|---|
| Pawn | Short sharp pop — noise burst, 100ms |
| Knight | Mid-pitch crunch with slight echo |
| Bishop | High-pitched crystalline shatter |
| Rook | Deep bass thud + rumble |
| Queen | Multi-layered explosion — two overlapping bursts |
| King | Long dramatic explosion — noise + falling pitch sweep, ~2 seconds |

White piece destruction sounds are the same family but with a lower, "sadder" pitch to signal it's your own piece.

**Critical HP Spark Loop**

When any piece (black or white) enters Critical HP (d2 + flicker state), a quiet looping electrical crackle plays until the piece is destroyed or the level ends. This gives the player an audio signal for near-dead pieces without requiring constant visual scanning.

| Piece type | Crackle pitch character | Notes |
|---|---|---|
| Pawn | High thin static — bright, papery | ~800 Hz centre |
| Knight / Bishop | Mid crackle — slightly buzzy | ~500 Hz centre |
| Rook | Low rumbling crackle — heavy | ~250 Hz centre |
| Queen | Two-layer crackle (high + mid) | More complex, more urgent |
| King | Deep electrical hum + slow crackle | Ominous; should be unmistakable |

**Implementation:** One looping `AVAudioPlayer` per Critical piece, started on Critical-state entry, stopped on destruction or level-clear. Volume: ~25% of master SFX — present but never dominant. If more than 3 pieces are simultaneously Critical, cap playback at 3 (lowest-HP pieces take priority) to avoid audio clutter. All loops use `numberOfLoops = -1`.

**Invader Fleet**

| Sound | Character |
|---|---|
| Invader projectile fired | Short descending squeal |
| Projectile hits white piece | Impact thud (same family as piece destruction but softer) |
| Projectile hits spaceship | Loud noise burst (same as ship destroyed) |
| Projectile shot down by player | Satisfying pop |
| Fleet hits side wall (bounce) | Low single-frame blip (classic Invaders) |
| Fleet drops one rank | Heavier low blip |

**Raider Ships**

| Sound | Character |
|---|---|
| Raider Scout enters screen | UFO warbling oscillator (classic mystery ship sound) |
| Raider Scout fires | Descending whistle |
| Raider Scout exits (unshot) | Oscillator fades out |
| Galaxian Escort peels off | Rising pitch sweep as it detaches from fleet |
| Escort/Flagship dive | Swooping pitch-slide tone (rises then falls as arc peaks) |
| Flagship first hit (flash) | Sharp metallic clang — communicates "not dead yet" |
| Any raider destroyed | Signature 3-note explosion unique to raiders |

#### Fleet Heartbeat

A persistent two-beat bass pulse plays throughout every level, speeding up as black pieces are destroyed — directly adapted from the original *Space Invaders* (1978) heartbeat and one of arcade gaming's most effective psychological tools.

**Sound design:** A low synthesized double-thump (thump-thump … pause) at approximately 60–80 Hz with a quick exponential decay. Not an 8-bit beep — closer to a deep electronic heartbeat: sub-bass body, short attack, no sustain. Generated once as a ~150ms `.caf` asset and triggered repeatedly by code; no pitch shifting, no rate manipulation.

**Tempo: driven by piece count, not fleet position.** As Black pieces are destroyed (by laser or chess capture), the BPM steps up. Each step is a discrete jump — no gradual glide between tempos.

| Black pieces remaining | BPM | Inter-beat interval |
|---|---|---|
| 13–16 (full fleet) | 52 | ~1.15 s |
| 9–12 | 66 | ~0.91 s |
| 7–8 | 80 | ~0.75 s |
| 5–6 | 100 | ~0.60 s |
| 3–4 | 130 | ~0.46 s |
| 2 | 155 | ~0.39 s |
| 1 (last piece) | 180 | ~0.33 s |

**Beat pattern:** Each beat is a double-thump: `thump₁` → +120ms → `thump₂` → [interval] → repeat. The 120ms inner gap is fixed at all tempos; only the outer gap shrinks.

**Implementation:** A `GameHeartbeat` class drives the pulse using a recursive `SKAction` sequence (`.playSoundFileNamed` + `.wait(forDuration:)`) rather than `AVAudioPlayer.rate` — rate-shifting causes pitch artifacts. On each cycle the class reads `FleetController.remainingPieceCount` to select the next interval. The sequence is started at level open and stopped on level-clear or game-over.

**Mix position:** Heartbeat sits at priority 7.5 in the audio mix — above fleet movement blips but below chess move sounds. Volume: ~50% of master SFX. It should be felt more than heard; it should never drown music.

**Visual sync:** The fleet pieces pulse ±15% brightness in sync with the heartbeat (`§24.7`). The Black King's damage-state pulse (`§24.8`) is locked to the same tempo. Both sync automatically because they read the same `GameHeartbeat.currentBPM` observable.

#### Audio Mix Priorities

When multiple sounds fire simultaneously, priority order (highest first):

1. Ship destroyed / King destroyed
2. Check alarm
3. Timer warning ticks
4. Piece explosions
5. Player laser fire / hit
6. Chess move sounds
7. Fleet movement blips
8. Raider ambient sounds
9. Music

The engine should duck (lower volume of) the music by ~30% whenever a level-1 or level-2 priority sound plays, then fade back up over ~0.5 seconds.

#### Settings

Volume controls live in a proper Settings screen (added Phase 5), accessible separately from pause. Pause is never a settings menu. Settings may be opened from the title screen and from a dedicated subtle Settings control or keyboard shortcut during gameplay; opening Settings pauses the game, but it is not part of the pause overlay.

- Master volume
- Music volume (separate)
- SFX volume (separate)
- Toggle: Music on/off

---

## 13. Power-Ups

### 13.1 Overview

Power-ups are delivered exclusively by **Special Scout variants** — rare versions of the Raider Scout that are visually distinct from the standard disc. Shooting a Special Scout destroys it for its point value and immediately activates its associated power-up. No pickup item falls to collect — the effect triggers on destruction.

Plain Raider Scouts (standard disc shape) never grant power-ups. Only the five Special Scout types do.

Flagships, Escorts, Kamikazes, Looping Escorts, Paired Escorts, chess pieces, and environmental events never drop or grant power-ups in v1.0.

**Spawn rules:**

- From Level 2 onward, one Special Scout appears per level, chosen at random from the five types.
- From Level 5 onward, two Special Scouts per level.
- Special Scouts spawn on the same real-time interval as standard Scouts but replace one standard Scout spawn — they do not add to the total Scout count.
- Only one power-up effect can be active at a time. If a second Special Scout is shot while an effect is running, the new effect replaces the old one immediately.

**Playtesting variables — tune after first playable build:**

- Which scout types feel satisfying vs. frustrating to encounter
- Spawn frequency (currently: 1 per level from L2, 2 per level from L5)
- First level each type appears (currently all from L2 — some types may be better held back)
- Duration and intensity of each effect (especially Gatling Barrage at 15s and Time Freeze at 3s)
- Whether any effect feels overpowered enough to break level tension (Nuke clearing all projectiles during Last Stand Rush could defuse the best moment in the game — consider excluding it from Level 5+)

**Design principle — make them feel overwhelming:** Power-ups should feel like a genuine moment of release. When a Recharged game gives you multiball or auto-cannon fire, the screen fills with action and you feel briefly invincible. That's the target feeling. GCI power-ups should err on the side of dramatic excess — too many shots, too fast — rather than modest stat bumps. If a power-up doesn't make the player instinctively grin the first time they get it, it's not strong enough.

### 13.2 Special Scout Types

Each Special Scout is visually unmistakable at a glance — different shape, different color, different movement signature. The design principle: the scout's appearance should hint at its power.

---

#### ⚡ Lightning Scout — Extra Laser Slot

- **Visual:** Yellow-gold neon. Elongated, streamlined shape — more aerodynamic than the standard disc. Crackles with small arcing electricity animations on its hull. Moves **faster** than standard scouts (1.4× speed).
- **Points:** 200 (harder to hit due to speed)
- **Effect:** Adds +1 simultaneous laser slot for **45 seconds**. Stacks with pawn promotion bonuses up to the hard cap of 6.
- **HUD indicator:** A lightning bolt icon appears in the HUD next to the laser count, with a countdown bar beneath it.
- **SFX on destroy:** Rising electric crackle surge — a fast ascending buzz that resolves into a satisfying snap.
- **SFX on expiry:** A brief descending crackle signals the extra slot dropping away. On expiry, the cap **reverts to base (2) plus the current level's earned promotion bonuses** — e.g. if the player has promoted 2 pawns this level, the cap drops to 4, not 2. The Lightning bonus is simply removed from the stack.

---

#### ❄ Ice Scout — Time Freeze

- **Visual:** Pale icy blue-white neon. Angular, crystalline shape — hexagonal facets, like a geometric snowflake. Moves **slower** than standard scouts (0.6× speed), drifting deliberately.
- **Points:** 150
- **Effect:** **3-second time freeze.** Fleet movement stops completely. Chess turn timer pauses. All enemy projectiles in flight freeze in place (they resume after the effect ends — they do not disappear). The player can still move and fire normally.
- **Music:** `AVAudioPlayer.rate` drops to **0.5** for the duration — the music slows and deepens in pitch, creating an unmistakable "time is warping" sensation. This is the one case where `rate` manipulation is intentional and desired.
- **SFX on destroy:** A deep, reverberant **whoooosh** — the sound of air rushing as time slows. Immediately followed by a crystalline ring on the freeze's first frame.
- **SFX on expiry:** A second whoosh (reversed) as time snaps back to normal speed. Music instantly returns to `rate = 1.0`.
- **Visual during freeze:** The background star layers stop scrolling. A faint blue-white tint washes briefly over the scene on activation and lifts on expiry.

---

#### 🔥 Spread Scout — Gatling Barrage

- **Visual:** Orange neon. Visibly **wider** than a standard scout — a fat, squat disc with five visible exhaust ports across its front edge. Moves at standard speed.
- **Points:** 150
- **Effect:** **15-second Gatling mode.** The laser cap is removed entirely and the ship auto-fires a continuous **5-way spread** — centre, ±20°, ±40° — at maximum rate (~8 shots/second) without the player pressing Space. The player retains full ship movement. The result is a dense garden-hose spray of lasers that covers most of the board width. Manual firing does nothing extra during this window — the auto-fire is the effect.
- **HUD indicator:** An orange spray-fan icon pulses in the HUD with a countdown bar. Hard to miss.
- **SFX on destroy:** A rapid multi-tone burst — five ascending notes fired in a tight 50ms sequence. Feels like a weapon powering up.
- **SFX during Gatling mode:** Each shot fires with a lighter, faster version of the standard laser sound. At 8 shots/second the effect sounds like a rapid continuous chatter — a genuine machine-gun feel.
- **SFX on expiry:** A brief wind-down tone signals the mode ending.
- **Balance note:** 15 seconds of 5-way auto-fire will clear most of the board. That's intentional — it's a genuine power moment. If playtesting shows it trivialises too much, reduce to 10 seconds or narrow the spread to ±15°/±30°.

---

#### 💥 Bomb Scout — Nuke

- **Visual:** Crimson-red neon. Angular, **spiky** silhouette — jagged protrusions like a sea mine. Flashes red on first hit (it takes **2 hits** to destroy, like the Flagship). The extra HP makes it a meaningful challenge for the reward.
- **Points:** 250 (2 hits required)
- **Effect:** On destruction, a **shockwave ring** radiates outward from the scout's position at high speed, destroying all enemy projectiles currently in flight. Pieces and Raiders are unaffected — only in-flight projectiles are cleared.
- **SFX:** A deep sub-bass explosion ring — a heavy thud followed by a resonant wave of sound that sweeps across the stereo field (left to right), mirroring the visual shockwave.
- **Visual:** The shockwave is a rapidly-expanding neon ring (magenta → white → transparent) that takes ~0.4 seconds to cross the screen. Small spark bursts appear at every projectile it destroys.

---

#### 🛡 Repair Scout — Shield Bubble

- **Visual:** Cyan-green neon. Standard disc shape but with a **visible hexagonal grid overlay** — looks armoured. Moves at standard speed.
- **Points:** 100
- **Effect:** A **hexagonal force-field** snaps around the player's ship. Absorbs the next single hit that would destroy the ship. After absorbing the hit, the shield shatters in a particle burst and the ship is unprotected again. The shield does **not** carry over to the next level.
- **SFX on destroy:** A soft ascending chime — reassuring and protective in character.
- **SFX on shield hit:** A resonant metallic clang — the hit is absorbed, but the player hears it clearly. Followed by the shield-shatter sound if it was the last charge.
- **Visual:** Cyan hexagonal outline softly pulses around the ship while active.

---

### 13.3 Power-Up Activation Visuals

Since power-ups activate immediately when a Special Scout is destroyed, there is no pickup sprite, falling item, or fly-under collection step. The visual feedback is on the scout itself:

- On destruction: the scout explodes with its type-color particle burst (gold for Lightning, blue-white for Ice, orange for Spread, red for Bomb, cyan-green for Repair) — larger and more elaborate than a standard scout explosion.
- A brief **type label** flashes at the destroy position for 0.8 seconds: `EXTRA SHOT`, `TIME FREEZE`, `SPREAD FIRE`, `NUKE`, `SHIELD UP` — large pixel text, same color as the scout, no background.
- The HUD updates immediately to reflect the active effect.

---

## 14. Title Screen & Attract Mode

### 14.1 Title Screen

On launch the game shows the title screen immediately:

```
        ★  GALACTIC CHESS INVADERS  ★
            PRESS ANY KEY TO START
```
- Title text in large pixel font, neon-lit, with a slow color-cycle animation (cycling through cyan → magenta → white).
- Stars drift in the background (parallax layers active).
- A row of black piece sprites (the fleet) slides slowly left and right across the bottom third of the screen as a visual teaser.
- "PRESS ANY KEY TO START" blinks at 1Hz.
- High score table is displayed below the prompt, showing the current top 5 scores and initials.

### 14.2 Attract Mode

If no key is pressed within **12 seconds**, the title screen transitions into **attract mode** — a looping demo that cycles through gameplay vignettes:

| Slide | Duration | Content |
|---|---|---|
| 1 | 4s | **Scoring table** — piece sprites displayed with their point values. "HOW TO SCORE" header. |
| 2 | 4s | **Ship types** — Raider Scout, Escort, Flagship shown with their point values and a brief animation of their attack pattern. |
| 3 | 4s | **Power-up** — a Special Scout (Repair Scout, cyan-green) flies across; player shoots it; Shield Bubble activates around the ship; ship absorbs a hit. "SHOOT SPECIAL SCOUTS FOR POWER-UPS" text. |
| 4 | 4s | **Pawn promotion** — pawn advancing to rank 8, triple-event animation (queen swap, nearest piece explosion, "MULTI-SHOT ACTIVATED" banner). "PROMOTE YOUR PAWNS" text. |
| 5 | 4s | **Live gameplay snippet** — 4 seconds of pre-recorded or simulated gameplay showing the fleet sweeping and the ship firing. |

After slide 5 it loops back to the title screen. Pressing any key at any point during attract mode starts the game immediately.

### 14.3 High Score Entry

After a game ends, if the player's score places in the top 10:

- "NEW HIGH SCORE!" flashes on the game over screen.
- Initials entry screen appears: **8 characters**, classic arcade-style selector (the title screen mockup shows 3-char but the intended design is 8 — e.g. ZACKU, PLAYER1).
  - Up/Down arrows (or scroll) cycle through A–Z, 0–9, and a space character.
  - Left/Right arrows move between character positions.
  - Enter or Fire button confirms.
- Score, initials, and level reached are saved to local storage (`UserDefaults`).
- High score table stores top 10 entries; **top 5 are displayed on the title screen** with three columns: rank, initials, score, level reached (e.g. L8, L7…). Note: the title screen mockup shows 3-char initials; the actual entry is 8 characters.

Game Center integration is planned for Phase 2 — the data model is designed to support it (score + level stored together) but the Game Center API calls are not wired in v1.0.

### 14.4 First-Run Detection & Auto How-to-Play

On the **very first launch only**, the How-to-Play overlay is shown automatically before the player can start a game.

**Behavior:**

- At startup, read `UserDefaults.standard.bool(forKey: "com.gci.hasSeenHowToPlay")`.
- If `false` (first run): after the title screen finishes its initial fade-in, trigger the How-to-Play overlay automatically without requiring a keypress. The `PRESS ANY KEY TO START` prompt is suppressed until the overlay is dismissed.
- On dismiss: write `true` to `hasSeenHowToPlay`. This is permanent — the auto-show never repeats.
- On all subsequent launches: title screen behaves normally. The INFO button remains available at all times for players who want to re-read the instructions.

**Rationale:** New players have no context for the dual-input mechanic (chess moves + ship) and will otherwise drop the controller on turn 1. One automatic first-run exposure is sufficient — repeated auto-shows would feel patronizing to returning players.

---

## 15. Technical Architecture (Swift / macOS)

### 15.1 Recommended Stack

| Component | Technology |
|---|---|
| Game rendering | **SpriteKit** (native macOS/iOS) |
| UI (menus, HUD) | **SwiftUI** overlaid on SpriteKit scene |
| Chess engine | Pure Swift module (`ChessEngine`) |
| State management | Swift actors / structured concurrency |
| Audio | **AVFoundation** or **SKAudioNode** |
| Data persistence | **UserDefaults** (high scores, settings) |

### 15.2 Module Breakdown

```
GalacticChessInvaders/
├── App/
│   ├── GCIApp.swift               ← SwiftUI entry point
│   └── ContentView.swift          ← SpriteKit scene host
├── Game/
│   ├── GameState.swift            ← Pure turn state machine, no SpriteKit
│   ├── TurnTimer.swift            ← level-based chess beat countdown, check extension
│   ├── LevelManager.swift         ← Wave/level progression
│   ├── GameRules.swift            ← Pure rule coordination, receives GameAction values
│   └── AttractMode.swift          ← Pure title/attract sequencing state
├── Chess/
│   ├── Board.swift                ← 8×8 board model (logical only, not rendered)
│   ├── Piece.swift                ← Piece type, color, HP
│   ├── MoveGenerator.swift        ← Legal move generation
│   ├── ChessEngine.swift          ← 1-2 ply minimax
│   └── ChessNotation.swift        ← Algebraic notation helpers
├── ArcadeRules/
│   ├── SpaceshipState.swift       ← Pure ship state: lives, laser cap, shield, invincibility
│   ├── ProjectileState.swift      ← Pure projectile state: owner, damage, speed, active/inactive
│   ├── FleetRules.swift           ← Pure fleet descent counters, logical rank updates, rush rules
│   ├── RaiderRules.swift          ← Pure raider spawn choices, targeting, power-up selection
│   ├── PowerUpRules.swift         ← Pure effect activation, replacement, expiry
│   └── CollisionResolver.swift    ← Pure collision outcomes: damage, scoring, destruction
├── Scene/
│   ├── GameScene.swift            ← Main SpriteKit scene, game loop, rule-to-node coordinator
│   ├── BoardLayout.swift          ← Converts logical board positions to scene coordinates
│   ├── FleetController.swift      ← SpriteKit fleet node movement; calls FleetRules on full-rank descent
│   ├── RaiderController.swift     ← SpriteKit raider spawning/animation; follows RaiderRules
│   ├── CollisionHandler.swift     ← SKPhysicsContactDelegate; delegates outcomes to CollisionResolver
│   └── AudioManager.swift         ← AVFoundation / SKAudioNode playback
├── Nodes/
│   ├── PieceNode.swift            ← SKSpriteNode subclass, damage states, smoke
│   ├── SpaceshipNode.swift        ← SpriteKit ship node, visual movement, respawn animation
│   ├── LaserNode.swift            ← SpriteKit projectile node, pooled and animated
│   ├── HUDNode.swift              ← Score, timer, lives, check warning, auto flash
│   ├── ReticleNode.swift          ← Legal move crosshair indicators
│   └── PowerUpNode.swift          ← Special Scout destruction effect + label flash
├── Scores/
│   ├── ScoreManager.swift         ← Local top-10 table, UserDefaults persistence
│   └── InitialsEntryScene.swift   ← 8-character classic arcade name entry
└── Assets.xcassets/
```
### 15.3 Rendering the Dual Systems

- **Chess moves** are discrete events: a piece moves from square A to square B via a smooth `SKAction.move`. Square coordinates are converted to screen positions by a `BoardLayout` helper — the grid is pure math, never rendered.
- **Fleet movement** runs continuously via `SKAction.repeatForever` on a fleet parent node — all piece nodes are children, so they shift together. Wall bounces create **visual half-rank drops**. The first half-drop does not change logical chess squares. After the second consecutive half-drop, the fleet has visually descended one full rank; only then are logical squares updated via `GCIBoard.forcePlace()` — bypassing chess legality. The chess engine always evaluates from the last completed full-rank logical descent, not from the in-between half-rank visual position. See §23.6 for full rules including crush events.
- **Collision detection** uses SpriteKit's physics bodies and `SKPhysicsContactDelegate`. Categories: `laser`, `enemyPiece`, `friendlyPiece`, `enemyProjectile`, `ship`.

### 15.4 Logic / SpriteKit Boundary

The codebase keeps every rule that can be tested without rendering in pure Swift. SpriteKit classes detect input, animate nodes, and report events; pure rule classes decide what those events mean.

**Pure rule/state layer:** `Game/`, `Chess/`, `ArcadeRules/`, and `Scores/` do not import `SpriteKit`, `AppKit`, or `UIKit`. They store board state, HP, lives, score, timers, laser caps, power-up timers, legal moves, fleet logical descent, and collision outcomes.

**SpriteKit scene layer:** `Scene/` and `Nodes/` may import `SpriteKit`. They own `SKScene`, `SKSpriteNode`, `SKAction`, physics bodies, particles, visual coordinates, hit detection, and audio playback. They do not decide scoring, legal chess moves, HP rules, or game-over conditions themselves.

**Event flow:** `GameScene` translates player/platform input into `GameAction`, asks pure rule objects for the result, then updates SpriteKit nodes to match. `CollisionHandler` receives physics contacts, converts them to rule inputs, calls `CollisionResolver`, and applies the returned effects to nodes and audio. `FleetController` runs visual sweeps, but only `FleetRules` decides when a full-rank logical descent happens and which board mutations are applied.

### 15.5 Future Portability Considerations

The v1.0 implementation target is macOS only. iOS/iPadOS may be considered later, but it is not a committed v1.0 or Phase 2 requirement.

Mac v1.0 should still avoid unnecessary platform coupling: keep game rules pure Swift, keep input translated through `GameAction`, and keep board layout responsive to the current scene size. Those choices help the Mac build immediately and preserve the option of a future port without forcing mobile UI work now.

---

## 16. Portability Architecture

This section defines how the macOS codebase should be structured so that game logic stays testable and the project does not accidentally depend on macOS-only concepts. A future iOS/iPadOS port is optional and not yet scheduled.

---

### 16.1 Core Principle: Separate Logic from Platform

Every system in the game belongs to one of three layers:

```
┌─────────────────────────────────────────┐
│           GAME LOGIC LAYER              │  ← Pure Swift. No UIKit, no AppKit,
│  Chess engine, board model, scoring,    │     no SpriteKit. Runs independently
│  level manager, fleet AI, collision     │     of platform UI.
│  rules, HP system, turn timer           │
├─────────────────────────────────────────┤
│         RENDERING / SCENE LAYER         │  ← SpriteKit.
│  GameScene, PieceNode, HUDNode,         │     SKScene works on both platforms
│  particle effects, audio nodes          │     with zero changes.
├─────────────────────────────────────────┤
│        PLATFORM INPUT LAYER             │  ← Separate per platform.
│  macOS: keyboard + mouse handlers       │     Future platforms would add
│  Future: touch/gamepad/etc.             │     their own adapters.
└─────────────────────────────────────────┘
```
**Rule:** The game logic layer must never import `AppKit`, `UIKit`, `SpriteKit`, or reference screen coordinates. It communicates with the scene layer through a clean protocol interface only.

---

### 16.2 Input Abstraction

The game must never respond directly to keyboard events or mouse clicks in the game logic. Instead, all input is translated into **abstract game actions** before being passed to the logic layer:

```swift
enum GameAction {
    case moveShipLeft
    case moveShipRight
    case fireShipLaser
    case selectPiece(position: BoardPosition)
    case movePiece(to: BoardPosition)
    case deselectPiece
    case pause
}
```
- On **macOS**: keyboard and mouse events are translated into `GameAction` values by a `MacInputHandler`.
- On a future touch platform: touch events, virtual joystick deltas, and button taps would be translated into `GameAction` values by a platform-specific input handler.
- The game logic layer receives only `GameAction` — it has no idea whether the source was a key press or a finger tap.

This means future input work should not require changing chess rules, scoring, fleet rules, or collision outcomes.

---

### 16.3 macOS Window Behavior

The game runs in a **standard resizable macOS window** — it does not take over the screen on launch. The user can optionally go full screen via the green traffic-light button or `⌃⌘F` as with any Mac app, but this is never forced.

**Default window size:** 900×700 points — large enough to see all pieces clearly, small enough to sit comfortably on a 13" laptop screen without dominating the desktop.

**Minimum window size:** 640×500 points — below this pieces become too small to click reliably.

**Resizing behavior:** the SpriteKit scene uses `scaleMode = .aspectFit` on macOS so the playfield scales cleanly inside any window size, with black letterbox bars if the window proportions differ from the scene's native ratio. The game never stretches or crops.

The app should **not** set `NSWindowStyleMask.fullSizeContentView` or hide the title bar — the standard macOS chrome (title bar, traffic lights, menu bar) remains visible at all times in windowed mode.

---

### 16.4 SpriteKit

SpriteKit is the rendering framework for macOS v1.0. It also leaves open a possible future path to iOS/iPadOS, but the current implementation should be judged first on Mac windowed gameplay, Mac input feel, and Mac performance.

---

### 16.5 Screen Size & Layout

The game must never use hardcoded pixel coordinates. All positions must be calculated relative to the scene size at runtime.

```swift
// Wrong — hardcoded
shipNode.position = CGPoint(x: 512, y: 40)

// Right — relative
shipNode.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.05)
```
**Key layout rules:**

- On macOS v1.0, the playfield uses `SKScene.scaleMode = .aspectFit` so resizing never crops the board, HUD, or spaceship strip
- The spaceship strip height is defined as a **percentage of scene height** (5%), not a fixed pixel value
- Displayed piece sizes are defined as percentages of `squareSize` using the canonical display sizing rule in §12.2; source PNG pixel dimensions are never used directly for layout
- HUD elements anchor to screen edges using `SKNode` anchor points — top-left for score, top-right for lives
- Future non-Mac layouts may choose different scale modes and safe-area behavior, but those are not v1.0 requirements

---

### 16.6 Audio

`AVFoundation` and `SKAudioNode` are acceptable for macOS v1.0 audio. Future platform-specific audio interruption handling can be designed if an iOS/iPadOS port is approved later; it is not part of the Mac v1.0 scope.

---

### 16.7 Asset Scaling — Mac v1.0

All sprite assets for Mac v1.0 must be provided at sufficient resolution for both standard and Retina Mac displays:

- `@1x` — standard Mac display
- `@2x` — Retina Mac display

`@3x` assets are not required for Mac v1.0. If an iOS/iPadOS port is approved later, `@3x` assets can be added during that porting work.

The neon-vector aesthetic uses smooth outlines — **do not set `filteringMode = .nearest`** on piece sprites (that is for pixel art and would introduce no benefit here). Sprite textures should use the default linear filtering so smooth vector shapes scale cleanly on Retina displays. The bloom glow from `SKEffectNode` renders at screen resolution automatically.

---

### 16.8 Optional Future Touch UI

The following are not part of Mac v1.0. If an iOS/iPadOS port is approved later, that work will need its own design pass:

| Element | Description |
|---|---|
| Virtual joystick | Left thumb zone — two arrow buttons or an analog stick for ship movement |
| Fire button | Large tap target, bottom-right, glows when laser is available |
| Pause button | Top-right corner, small, always accessible |
| Chess piece tap handling | Tap to select, tap reticle to move — replaces mouse click |
| Larger touch targets | Piece sprites may need slightly larger tap areas than their visual size on iPhone |
| Landscape-only lock | Game is landscape only on iPhone. Set `UISupportedInterfaceOrientations` to landscape in Info.plist |
| iPad layout | More screen real estate — HUD can be richer, pieces can be larger |

---

### 16.9 Persistence

Mac v1.0 stores high scores and settings in `UserDefaults`.

If online leaderboards or cross-device sync are approved later, the `ScoreManager` class should already be designed behind a protocol so the local implementation can be swapped without touching game rules:

```swift
protocol ScoreStorage {
    func submitScore(_ score: Int, level: Int, initials: String)
    func topScores() -> [ScoreEntry]
}

// v1.0
class LocalScoreManager: ScoreStorage { ... }

// Optional future online leaderboard implementation
class GameCenterScoreManager: ScoreStorage { ... }
```
---

### 16.10 Shared Codebase Structure

Mac v1.0 should use a single macOS app target. Keep folders organized so future platform work can reuse pure rules, but do not create an iOS target until that port is explicitly approved:

```
GalacticChessInvaders.xcodeproj
├── Targets:
│   └── GCI-macOS        (macOS deployment target)
├── Shared/              ← Pure rules and shared SpriteKit scene code
│   ├── Game/
│   ├── Chess/
│   ├── ArcadeRules/
│   ├── Scene/
│   ├── Nodes/
│   └── Scores/
├── macOS/               ← macOS-only files
│   ├── MacInputHandler.swift
│   └── AppDelegate.swift
```
This structure keeps the Mac build straightforward while preserving reusable game logic. Future platform folders should be added only when a future platform becomes real scope.

---

## 17. Libraries & Tools

All dependencies are chosen to be lightweight, actively maintained, MIT/BSD licensed, and Swift Package Manager compatible. The goal is a small, auditable dependency tree — not a framework graveyard.

---

### 17.1 Chess Logic — ChessKit

**Package:** `https://github.com/aperechnev/ChessKit`

**License:** MIT

**Swift Package Manager:** Yes — add as a package dependency in Xcode

**Status:** Active. v2.0.0 released September 2025, Swift 6 compatible.

ChessKit is a pure Swift chess logic library with no UIKit or AppKit dependencies. It uses UInt64 bitboards internally for fast move generation and handles legal moves, check, checkmate, FEN notation, and PGN. The library may support castling and en passant, but GCI v1.0 does not: those moves are filtered out of all White UI move lists and all Black AI move lists.

**What we use it for:**

- `MoveGenerator` — all legal moves for a given board position
- Check and checkmate detection
- Board state management

**What we write ourselves on top of it:**

- The minimax evaluation loop (1-2 ply, material count only)
- The "aggressive mode" weighting for Level 2+
- HP tracking (ChessKit has no concept of piece health)
- Multi-move-per-turn logic (Level 3+)
- Filtering out castling and en passant for both sides

ChessKit replaces writing a move generator from scratch — the most tedious and bug-prone part of a chess engine. The AI evaluation on top of it is small and straightforward.

**Alternative:** `chesskit-app/chesskit-swift` — nearly identical quality, good fallback if integration issues arise.

**Do not use:** `SteveBarnegren/SwiftChess` (abandoned), `nvzqz/Sage` (explicitly abandoned by author).

---

### 17.2 Chess AI — Apple GameplayKit (built-in)

**Framework:** `GameplayKit` — ships with macOS and iOS, no dependency needed.

Rather than writing a minimax loop from scratch, use Apple's `GKMinmaxStrategist`. It implements minimax with alpha-beta pruning and only requires implementing the `GKGameModel` protocol on our board state — roughly 4 methods.

```swift
// Conform our board model to GKGameModel
extension GCIBoard: GKGameModel {
    func gameModelUpdates(for player: GKGameModelPlayer) -> [GKGameModelUpdate]? {
        // return legal moves as GKGameModelUpdate objects
    }
    func score(for player: GKGameModelPlayer) -> Int {
        // return material count evaluation
    }
    // apply / unapply moves for tree search
}

let strategist = GKMinmaxStrategist()
strategist.maxLookAheadDepth = 2   // 1-2 ply
strategist.randomSource = nil       // deterministic
let move = strategist.bestMove(for: currentPlayer)
```
`GKMinmaxStrategist` runs synchronously but fast at depth 2 — wrap in `Task.detached` as per §18 performance rules. This is also used for `GKStateMachine` (game states: title, playing, paused, level clear, game over).

---

### 17.3 Sound Effects — pre-made library + generators + AVFoundation (built-in)

**Playback:** `AVFoundation` — ships with macOS and iOS, no dependency needed.

Two complementary approaches: start with a pre-made library for common sounds, then use a generator for anything custom or missing.

#### Pre-made Library — The Motion Monkey Retro Arcade Pack

**[The Motion Monkey — Free Retro Arcade Sounds](https://www.themotionmonkey.co.uk/free-resources/retro-arcade-sounds/)**

The best single starting point for GCI. 300+ original retro arcade sounds, **CC0 (public domain)**, available in 24-bit WAV, OGG, and M4A. No attribution required. Covers everything needed out of the box:

| Category | GCI use |
|---|---|
| Explosions | Piece destruction (small/medium/large/king) |
| Weapons / sci-fi lasers | Player laser fire, enemy shots |
| Impacts | Piece hit / damage |
| UI / beeps / clicks | Menu navigation, screen transitions, timer tick |
| Level / screen events | New level, game over, power-up activated |
| Arcade speech | "Game Over", "Power Up", "Bonus" stings |

Download the full pack, audition everything, and map the best candidates to GCI events. Many sounds work for multiple purposes.

#### Custom SFX Generator — jsfxr / ChipTone

For any sounds not covered by the library, or to create a unique signature sound (e.g. the player's specific laser tone):

- **[jsfxr](https://sfxr.me)** — browser-based, instant, no install. One-click randomise for laser/explosion/power-up/hit categories, then tweak parameters. Export as `.wav`.
- **[ChipTone](https://sfbgames.itch.io/chiptone)** — more powerful, free download, better for complex layered sounds or richer explosions.
- **[Bfxr](https://www.bfxr.net)** — desktop app (Mac/Win), sfxr-based with a mixer for combining multiple sounds into one. Good for the King explosion which should feel massive.

#### Workflow (for all SFX sources)

1. Collect `.wav` files from library and/or generators
2. Convert to `.caf` (Core Audio Format, linear PCM) — lowest decode latency on Apple hardware:

   ```
   afconvert -f caff -d LEI16 sound.wav sound.caf
   ```
3. Preload all `.caf` files into `AVAudioPlayer` instances at scene load — zero I/O during gameplay
4. For polyphonic sounds (rapid laser fire, simultaneous explosions) maintain a pool of 3–4 `AVAudioPlayer` instances per sound and round-robin between them

No third-party Swift audio library needed. `AVFoundation` handles everything.

---

### 17.4 Music — AVFoundation (built-in) + curated tracks

**Playback:** `AVFoundation` — built-in, no dependency. Load `.m4a` files with `AVAudioPlayer`, loop with `numberOfLoops = -1`.

**Style target:** Modern electronic / dark synthpop in the Atari Recharged vein — driving, melodic, punchy. *Not* classic 8-bit beeps. The Recharged series (Asteroids, Breakout, Centipede) uses fully modern electronic production by Megan McDuffee: dark electropop with 80s/90s flavor, strong melodic leads, short 2–2.5 minute loops. GCI should aim for the same territory.

**Per-level song pool** (simpler and more reliable than adaptive tempo):

| Level | Tracks | Feel |
|---|---|---|
| 1 | 3 | Mid-tempo, accessible, slightly mysterious |
| 2 | 2 | Slightly faster, more urgent |
| 3 | 2 | Driving, intense |
| 4 | 2 | Fast, aggressive |
| 5+ | 1 | Maximum intensity, relentless |

Plus: title theme, level-clear fanfare (short sting), game over riff (short sting).

Pick a random track from the level's pool at the start of each wave. Don't repeat the same track twice in a row.

#### Suggested BPM by Level

BPM is the primary lever for perceived intensity. Tracks should be selected or generated to land in these ranges:

| Context | BPM | Feel |
|---|---|---|
| Title screen | 80–95 | Atmospheric, spacey, inviting — sets the scene without pressure |
| Level 1 | 100–110 | Medium energy, accessible. Most-played level; shouldn't fatigue |
| Level 2 | 112–118 | Slightly more urgent, same melodic quality |
| Level 3 | 120–128 | Driving. This is the classic Motorik sweet spot — relentless 4/4 pulse |
| Level 4 | 130–140 | Fast and aggressive. Melody takes a back seat to rhythm |
| Level 5+ | 140–155 | Relentless. Sparse, pounding, mechanical |
| Level clear sting | — | 2–3 second ascending fanfare, any tempo |
| Game over riff | — | 2–3 second descending phrase, slow and deflating |

Tracks don't need to match BPM exactly — these are target zones. A 118 BPM track works fine at Level 2 even if it feels slightly fast; the gameplay action will fill the space.

**Note:** The earlier adaptive-tempo "heartbeat" system (adjusting `AVAudioPlayer.rate` dynamically) has been dropped. Rate-shifting causes pitch artifacts and the per-level pool approach achieves the same escalation feel more reliably.

#### Licensing Policy

**Free / CC0 / CC-BY only.** Commercial licenses are not used. All music must be usable in a distributed app without per-unit fees or royalty payments. CC0 (public domain) is ideal — no attribution required. CC-BY requires crediting the author in the app's credits screen, which is acceptable. CC-BY-SA and CC-BY-NC require review before use.

#### Option A — Purchased MIDI packs + Logic Pro (strong option)

Purchased MIDI/MP3 packs from itch.io can be re-rendered in **Logic Pro** using modern synth instruments — replacing the original 8-bit patches with Alchemy pads, Retro Synth leads, ES2 bass synths, and electronic drum kits. This gives full control over the final timbre while keeping the musical structure (melody, rhythm, arrangement) already composed. The result can be more rhythmically compelling and better structured than Zudio output, without the MIDI guitar problem.

**Workflow:**

1. Import the MIDI file into a new Logic Pro project
2. Replace default instrument assignments with modern electronic patches — suggested:
   - Lead melody → Retro Synth (sawtooth or square with portamento) or Alchemy synth lead
   - Bass → ES2 or Retro Synth sub bass, keep it punchy
   - Pads/atmosphere → Alchemy pad, slow attack, subtle filter sweep
   - Drums → Ultrabeat or Drum Machine Designer with electronic/industrial kit
3. Adjust tempo to match the target BPM for the intended level slot (see table above)
4. Bounce to `.wav` (44.1kHz stereo, 24-bit)
5. Convert to `.m4a`: `afconvert -f m4af -d aac music.wav music.m4a`
6. Trim the loop point cleanly — end should flow back into the start without a pop

**Tip:** Check that the track has consistent energy throughout the loop. Chiptune MIDI compositions sometimes have a quiet intro or a fade-out ending — cut or loop from the main body only.

#### Option B — Zudio-generated tracks

> **⚠ Pre-ship action required:** Verify that Zudio's commercial licensing terms permit bundling generated tracks in a paid Mac App Store app without per-unit fees or royalties. Zudio's terms may vary by subscription tier. Confirm before submitting to App Store Review — if commercial distribution is not covered, fall back to Option C (CC0 sources) for all tracks. Do not ship with Zudio tracks until this is confirmed in writing or via their published terms.

**[Zudio](https://zudio.co)** — Motorik and Kosmic songs generated by the Zudio app are a strong stylistic fit and already available in `.m4a` — no conversion needed. The Atari Recharged soundtrack (Megan McDuffee, [Vol. 1](https://meganmcduffee.bandcamp.com/album/atari-recharged-original-video-game-soundtrack) / [Vol. 2](https://meganmcduffee.bandcamp.com/album/atari-recharged-original-game-soundtrack-volume-2) / [Vol. 3](https://meganmcduffee.bandcamp.com/album/atari-recharged-original-game-soundtrack-volume-3)) is the sonic benchmark — dark electropop/synthpop, 80s/90s flavour, driving melodic leads, punchy mixes, ~2–2.5 minute loops. Zudio is in that territory.

**Known limitations to work around:**

- **MIDI electric guitar** patches can sound unconvincing — favour Zudio presets that avoid guitar and lean on synth pads, bass synths, arpeggios, and electronic drums
- **Freeform structure** — Zudio songs may not build tension naturally. Choose tracks that have a consistent energy throughout rather than ones that fade mid-loop. The game's action provides the escalation; the music just needs to sustain the energy
- **Loop point** — check that the track loops cleanly (end transitions back to start without a pop or awkward gap). Trim in GarageBand or Audacity if needed

Generate multiple versions at different tempos/moods and pick the best candidates per level slot.

#### Option C — Free licensed libraries

For a more explicitly retro or electronic sound, or to supplement Zudio tracks:

| Source | License | Style | Notes |
|---|---|---|---|
| **[HydroGene — 8-bit Musics](https://hydrogene.itch.io/high-quality-8-bit-musics)** | CC0 | Modern arcade chip | 18 tracks, arcade/shooter focused, no credit required — best free starting point |
| **[Soundimage.org — Chiptunes](https://soundimage.org/chiptunes/)** | Free for games | Arcade/electronic | Varied tempos; some tracks lean modern electronic rather than pure NES |
| **[Free Music Archive — Chiptune](https://freemusicarchive.org/genre/Chiptune/)** | CC (varies per track) | Broad range | Check individual track license; many CC0/CC-BY available |
| **[OpenGameArt.org — Chiptune](https://opengameart.org/content/free-action-chiptune-music-pack)** | CC0 / CC-BY | Arcade action | Large searchable library; filter by license before downloading |

#### Workflow (for any source)

1. Obtain or export track as `.wav` or `.m4a`
2. If `.wav`, convert to `.m4a` (AAC):

   ```
   afconvert -f m4af -d aac music.wav music.m4a
   ```
3. Bundle `.m4a` files in the Xcode project under a `Music/` folder
4. Load with `AVAudioPlayer`, `numberOfLoops = -1` for seamless looping
5. On level start, pick randomly from the level's track pool (avoid repeating last track)

#### Tempest 2000 as a Musical Reference

**Tempest 2000** (Atari Jaguar, 1994) is the strongest musical reference point for GCI. Composed Imagitec Design (a.k.a. Dream Weavers), the 12-track soundtrack — *Thermal Resolution, Mind's Eye, T2K, Ease Yourself, Tracking Depth, Constructive Demolition, Future Tense, Digital Terror, Hyper Prism, Glide Control, Ultra Yak,* and *2000 Dub* — blends driving techno-rave rhythms, dense sample layering, and human voice samples tied directly to gameplay events (most famously an escalating *"Yes! Yes! Yes!"* on power-up warp). This aesthetic maps perfectly onto GCI: both games are fast, arcade-reflex experiences with a pure-black void aesthetic, neon visuals, and an enemy fleet that demands constant attention. The music was authored as **Commodore Amiga MOD files** and played back via the Jaguar's Jerry DSP chip — a format that stores raw audio samples alongside tracker pattern data, making it possible to inspect every note, sample, and effect command directly.

**Finding the MOD files:** The original MOD files are in the publicly released Tempest 2000 source code (Jaguar Sector II, 2008) under `Tempest 2k Music 94/TEMPEST/MOD/`. Several of the tracks are also indexed on [ModArchive.org](https://modarchive.org). A 2021 fan remaster using these files is available at [archive.org/details/tempest-2000-ost-original-remastered-2021-flac-32-bit](https://archive.org/details/tempest-2000-ost-original-remastered-2021-flac-32-bit) — some files have been converted to MIDI using timidity.

**Converting MOD to MIDI on macOS:** The fastest path is `timidity`, available via Homebrew: `brew install timidity`, then `timidity -Ow -o output.mid input.mod` — though note that MOD-to-MIDI conversion is lossy (MOD samples pitch-shift raw audio; MIDI uses instrument programs) so the output captures melody and rhythm but not timbre. For a cleaner analysis workflow, open the MOD in OpenMPT (Windows/Wine), export each channel as a separate MIDI track (`File → Export → MIDI`), then import into GarageBand or Logic Pro on Mac. This lets you inspect scales, chord progressions, basslines, and drum patterns directly in a piano roll — the ground-truth source for understanding what makes the tracks hypnotic.

---

### 17.5 Game Math — simd (built-in)

**Framework:** `simd` — part of the Swift standard library, no dependency.

Use `SIMD2<Float>` for 2D positions and velocities, `simd_float2x2` for transforms. This is faster than `CGPoint` arithmetic for game logic calculations and is what SpriteKit uses internally.

No third-party math library is needed or recommended.

---

### 17.6 Full Dependency Summary

| Dependency | Type | Source | Used for |
|---|---|---|---|
| **ChessKit** | Swift Package | `github.com/aperechnev/ChessKit` | Legal move generation, check/checkmate |
| **GameplayKit** | Built-in framework | Apple SDK | Chess AI (GKMinmaxStrategist), state machines |
| **AVFoundation** | Built-in framework | Apple SDK | SFX and music playback |
| **SpriteKit** | Built-in framework | Apple SDK | All rendering, physics, animation |
| **SwiftUI** | Built-in framework | Apple SDK | Window hosting, diagnostics log panel |
| **simd** | Built-in | Swift stdlib | Game math |
| **jsfxr** | External tool (not a code dep) | sfxr.me | Generate .wav SFX assets |
| **ChipTone** | External tool (not a code dep) | sfbgames.itch.io | Alternative SFX generation |
| **Zudio** | External app | zudio.co | Generate Motorik/Kosmic music tracks in M4A |
| **HydroGene / Soundimage** | Asset library (CC0/free) | itch.io / soundimage.org | Free licensed music tracks if Zudio not used |
| **FamiStudio** | External tool (not a code dep) | famistudio.org | Optional: compose custom chiptune stings |
| **afconvert** | CLI tool (ships with Xcode) | macOS | Convert WAV → CAF/M4A for optimal playback |
| **OpenMPTSwift** | Optional Swift Package | `github.com/lukasz-pomianek/OpenMPTSwift` | Only if tracker file format chosen for music |

**Total runtime code dependencies: 1** (ChessKit). Everything else is Apple built-in frameworks or asset generation tools. This is intentional — fewer dependencies means fewer breakages across Xcode and Swift version updates.

---

### 17.7 Adding ChessKit to the Xcode Project

In Xcode:

1. File → Add Package Dependencies
2. Enter: `https://github.com/aperechnev/ChessKit`
3. Select version rule: Up to Next Major from `2.0.0`
4. Add to the `GCI-macOS` target

Then in `MoveGenerator.swift`:

```swift
import ChessKit
// Board, Position, Move, Piece types are now available
```
---

## 18. Performance Architecture

This section defines the performance rules that must be followed from Phase 0 onward. Violating these patterns produces games that run fine early and degrade as features are added — exactly what we want to avoid. None of these require exotic techniques; they are standard SpriteKit/Swift practices applied consistently.

**Target:** 60 fps on a 2019 MacBook Pro at all times, including during the most chaotic moments (fleet at full speed, multiple raiders, projectiles in flight, explosions active simultaneously).

---

### 18.1 Never Block the Main Thread

The single most important rule. SpriteKit renders on the main thread. Anything that takes more than ~4ms on the main thread causes a dropped frame.

**What must never run on the main thread:**

- Chess engine move generation and evaluation
- Any loop over all board positions
- File I/O (score saving, settings loading)
- Audio file loading

**Rule:** The chess engine runs on a **background thread** using Swift structured concurrency (`async/await` or `Task`). It posts its result back to the main thread via `await MainActor.run { }` only when the move is ready. The game loop never waits for the engine.

```swift
// Wrong — blocks main thread, drops frames
let move = chessEngine.bestMove(for: board)  // called in update()

// Right — engine runs in background, result posted when ready
Task.detached(priority: .userInitiated) {
    let move = await chessEngine.bestMove(for: board)
    await MainActor.run { gameState.applyMove(move) }
}
```
---

### 18.2 Object Pooling for Frequently Created Nodes

Creating and destroying `SKNode` objects every time the player fires or a projectile hits is expensive — it triggers memory allocation, SpriteKit scene graph updates, and garbage collection pressure. At arcade speed (player firing rapidly, dozens of projectiles per level) this adds up fast.

**Pool these objects from day one:**

| Object | Why pool it |
|---|---|
| Player laser nodes | Fired up to 3× simultaneously, repeatedly |
| Enemy projectile nodes | Up to 3 per turn × many turns |
| Score pop-up labels | Every hit spawns one |
| Small explosion particles | High frequency, short lifetime |
| Reticle nodes | Shown/hidden on every piece selection |

**Pattern:** maintain a fixed array of pre-created nodes. On spawn, take one from the pool and position/activate it. On despawn, reset it and return it to the pool — never remove it from the scene graph.

```swift
class LaserPool {
    private var available: [LaserNode] = []

    func acquire() -> LaserNode {
        if let node = available.popLast() {
            return node   // reuse existing node
        }
        return LaserNode()  // only allocates when pool is empty
    }

    func release(_ node: LaserNode) {
        node.reset()
        available.append(node)
    }
}
```
Pre-warm pools at level start, not on first use.

---

### 18.3 Texture Atlases — One Draw Call Per Atlas

Each individual texture file requires a separate GPU draw call. With 12 piece types × 4 animation frames + projectiles + HUD elements, a naive implementation makes 50+ draw calls per frame. SpriteKit batches draw calls automatically **only when sprites share the same texture atlas**.

**Rule:** Pack all sprites into texture atlases using Xcode's `.spriteatlas` folder format. Group by usage:

```
Assets.xcassets/
├── Pieces.spriteatlas/       ← all 12 piece types, all frames
├── Projectiles.spriteatlas/  ← lasers, enemy shots, all types
├── Raiders.spriteatlas/      ← Scout, Escort, Flagship frames
├── Explosions.spriteatlas/   ← all explosion sprite sheets
├── HUD.spriteatlas/          ← timer, lives, icons, banners
└── Effects.spriteatlas/      ← reticles, trails, shield bubble
```
Sprites within the same atlas render in a single draw call. Target: fewer than 10 draw calls per frame during normal gameplay. Check with SpriteKit's built-in stats overlay (`showsNodeCount`, `showsDrawCount`).

---

### 18.4 Keep the Node Tree Shallow and Small

SpriteKit traverses the entire node tree every frame. Deep hierarchies and large node counts slow this traversal.

**Rules:**

- Maximum node count during gameplay: **~150 nodes**. This is generous — a full board has 32 pieces + projectiles + HUD + background = well under 150 if managed correctly.
- Never add child nodes inside `update()` — only in response to discrete game events.
- Destroyed pieces are **removed from the scene graph immediately** after their explosion animation completes — not kept hidden.
- Background parallax layers use **a small number of large sprites** that wrap/tile, not hundreds of individual star sprites. Use an `SKTileMapNode` or a single scrolling texture for the starfield.

---

### 18.5 Use SKAction for All Animations

`SKAction` is SpriteKit's native animation system — it runs on the render thread without touching Swift code each frame. Manual position updates in `update()` are slower and harder to cancel.

**Rule:** Every animation — piece movement, projectile travel, explosions, fleet sweep, idle bob — uses `SKAction`. Never animate by mutating `node.position` directly in `update()`.

```swift
// Wrong — runs Swift code every frame
override func update(_ currentTime: TimeInterval) {
    laserNode.position.y += laserSpeed * deltaTime  // manual each frame
}

// Right — SpriteKit handles it natively
let move = SKAction.moveBy(x: 0, y: screenHeight, duration: travelTime)
laserNode.run(move) { [weak self] in self?.laserPool.release(laserNode) }
```
The fleet's lateral sweep uses `SKAction.repeatForever` on the parent fleet node — all 16 piece nodes move together at zero per-piece cost.

---

### 18.6 Simple Physics Bodies

SpriteKit's physics engine is accurate but not free. Complex polygon bodies are significantly more expensive than primitive shapes.

**Rules:**

- All collision bodies are **circles or rectangles only** — no polygon paths.
- Piece collision bodies: centered circle, radius = `min(displayedWidth, displayedHeight) * 0.42`, based on displayed node size.
- Laser collision bodies: thin rectangle.
- Use **category bitmasks** correctly so SpriteKit skips collision checks between pairs that can never interact (e.g. player laser vs player laser):

```swift
struct PhysicsCategory {
    static let playerLaser:    UInt32 = 0b00001
    static let enemyPiece:     UInt32 = 0b00010
    static let friendlyPiece:  UInt32 = 0b00100
    static let enemyShot:      UInt32 = 0b01000
    static let ship:           UInt32 = 0b10000
}
// Player laser only needs to test against enemy pieces and friendly pieces
laserBody.contactTestBitMask = PhysicsCategory.enemyPiece | PhysicsCategory.friendlyPiece
laserBody.collisionBitMask   = 0  // no physical bounce — just contact events
```
---

### 18.7 Preload All Audio at Startup

Creating an `AVAudioPlayer` or loading a sound file at the moment a sound needs to play causes a stutter — file I/O on or near the main thread. At arcade speed (laser fire, rapid hits) this becomes severe.

**Rule:** All SFX are loaded into memory once during the loading screen before gameplay begins. Store them in `AudioManager` as ready-to-play instances. Playing a sound must be a single method call with zero I/O:

```swift
// AudioManager preloads everything at startup
class AudioManager {
    private var sounds: [SoundEffect: AVAudioPlayer] = [:]

    func preloadAll() {
        for effect in SoundEffect.allCases {
            sounds[effect] = try? AVAudioPlayer(contentsOf: effect.url)
            sounds[effect]?.prepareToPlay()
        }
    }

    func play(_ effect: SoundEffect) {
        sounds[effect]?.play()  // zero I/O, instant
    }
}
```
For sounds that may overlap (e.g. rapid laser fire), use multiple pre-created player instances per sound and round-robin between them.

---

### 18.8 Delta-Time Based Movement

Never tie game speed to frame rate. On a fast machine running at 120fps, pieces would move twice as fast as on a 60fps machine if movement is frame-based.

**Rule:** All movement is calculated using `deltaTime` — the elapsed time since the last frame — not a fixed per-frame amount:

```swift
override func update(_ currentTime: TimeInterval) {
    let deltaTime = currentTime - lastUpdateTime
    lastUpdateTime = currentTime
    // pass deltaTime to all systems that need it
    fleetController.update(deltaTime: deltaTime)
}
```
SpriteKit's `SKAction` handles this automatically — another reason to prefer it over manual updates.

---

### 18.9 The Bloom Shader — Use Once, Apply Everywhere

The neon bloom effect (blur-and-add) is the most visually expensive operation in the game. Applied naively to every node it would destroy performance.

**Rule:** Apply the bloom shader to a **single `SKEffectNode`** that is the parent of all glowing content. One shader pass covers everything beneath it:

```swift
let effectNode = SKEffectNode()
effectNode.shouldEnableEffects = true
effectNode.filter = CIFilter(name: "CIBloom",
    parameters: ["inputRadius": 8.0, "inputIntensity": 0.8])
effectNode.shouldRasterize = true  // cache the result — only re-renders when children change
scene.addChild(effectNode)
// add all piece nodes, laser nodes etc. as children of effectNode
```
`shouldRasterize = true` is critical — it tells SpriteKit to cache the composited result and only re-render when something beneath the effect node actually changes. Without it the shader runs every frame regardless.

---

### 18.10 Profiling Schedule

Performance must be measured, not assumed. Use Instruments at the end of each phase:

| Phase | What to measure | Target |
|---|---|---|
| 2 (Playfield) | Frame rate with chess running | Steady 60 fps |
| 3 (Arcade layer) | Frame rate with fleet + 10 projectiles | Steady 60 fps |
| 6 (Raiders) | Frame rate with 2 raiders + fleet + projectiles | Steady 60 fps |
| 8 (Visual polish) | Frame rate with bloom shader active, full effects | Steady 60 fps |
| 9 (Hardening) | Memory over 30-minute session | No growth trend |

Tools: **Instruments → Game Performance** template (combines GPU, CPU, and memory). Check `SKScene.showsNodeCount` and `SKScene.showsDrawCount` during development — keep draw count under 10 and node count under 150.

**Fix performance issues at the phase they appear, not at the end.** A frame drop discovered in Phase 3 is a 1-hour fix. The same issue discovered in Phase 8 after layers of polish are built on top of it can be a week of rearchitecting.

---

## 19. Developer Diagnostics Log

### 19.1 Overview

The game includes a built-in live diagnostics log — a scrollable console view showing real-time events as they happen. It is the primary tool for understanding what the game is doing during development and playtesting without attaching Xcode's debugger.

The log is:

- **On by default in debug builds**, off by default in release builds
- Togglable at runtime with `L` on Mac or a button on iOS regardless of build type
- Monospace green text on black background — visually distinct from the game, reads like a classic terminal

---

### 19.2 Log Layout — macOS

The log appears as a **right sidebar** within the game window. The game scene occupies the left portion; the log occupies a fixed-width right panel.

```
┌──────────────────────────────┬─────────────────────────┐
│                              │ GALACTIC CHESS INVADERS │
│                              │ ─── DIAGNOSTIC LOG ──── │
│                              │                         │
│        GAME SCENE            │ 000.00 L00 B00 STARTUP  │
│                              │ 000.02 L00 B00 STARTUP  │
│                              │ 001.40 L01 B00 INIT     │
│                              │ 001.42 L01 B00 INIT     │
│                              │ 003.74 L01 B01 WHITE    │
│                              │ 003.91 L01 B01 BLACK    │
│                              │ 004.20 L01 B01 HIT      │
│                              │ 004.36 L01 B01 FLEET    │
│                              │ 006.10 L01 B02 RAIDER   │
│                              │ ...                     │
│                              │ [scroll up for history] │
└──────────────────────────────┴─────────────────────────┘
```
- **Sidebar width:** 360 points — wide enough for the time/level/beat prefix plus readable event text, narrow enough to leave the game playable
- **Font:** SF Mono or system monospace, 11pt, bright green (`#00ff44`) on pure black
- **Auto-scrolls** to the latest entry. The player can scroll up to read history — auto-scroll resumes when they scroll back to the bottom
- **Full session history retained** — all events since launch are kept in memory (capped at 2,000 lines to prevent memory growth in long sessions)
- A thin neon separator line divides the game scene from the log panel
- Log panel can be shown/hidden with `L` — game scene expands to fill the full window width when hidden

---

### 19.3 Optional Future Touch Log Layout

If an iPhone or other small-screen touch version is approved later, the screen will likely be too small for a sidebar. The log should become a **separate full-screen view** toggled by a small `[LOG]` button in the corner of the game screen.

```
┌─────────────────────────┐       ┌─────────────────────────┐
│                         │  ←→   │ ─── DIAGNOSTIC LOG ───  │
│      GAME SCREEN        │       │ 000.00 L00 B00 STARTUP  │
│                    [LOG]│       │ 001.42 L01 B00 INIT     │
│                         │       │ 003.74 L01 B01 WHITE    │
└─────────────────────────┘       │ 003.91 L01 B01 BLACK    │
                                  │ ...                     │
                                  │                  [GAME] │
                                  └─────────────────────────┘
```
- Tapping `[LOG]` switches to the log view (game is paused automatically)
- Tapping `[GAME]` returns to the game (resumes from pause)
- The log view is scrollable — full history visible
- Same monospace green-on-black styling

---

### 19.4 Log Categories & Format

Every log line follows the format:

```
EEE.ee L## B## CATEGORY  message text
```
The prefix is mandatory for every log line:

- `EEE.ee` = elapsed time in seconds since app launch, fixed to two decimals and padded to at least three digits before the decimal (`000.00`, `012.43`, `125.07`)
- `L##` = current level, padded to two digits (`L01`, `L05`, `L12`); use `L00` before gameplay starts
- `B##` = current chess beat within the level, padded to two digits (`B01`, `B03`, `B12`); use `B00` before the first beat of a level starts
- `CATEGORY` = fixed-width 8-character label, padded with spaces
- `message text` = concise event description

Use `B##` rather than `T##` because the game uses a timed chess beat, not a traditional alternating chess turn. The beat number increments when a new White move/auto-move window begins and resets to `B00` at each level start until the first beat begins.

| Category | Meaning |
|---|---|
| `STARTUP ` | App launch, scene transitions, music start |
| `INIT    ` | Board setup, piece placement, level load |
| `WHITE   ` | Player chess move or auto-move |
| `BLACK   ` | Enemy chess move |
| `HIT     ` | Any piece taking damage |
| `DESTROY ` | Any piece destroyed (chess or shooting) |
| `CAPTURE ` | Chess capture (piece taken by move) |
| `FLEET   ` | Fleet movement events |
| `RAIDER  ` | Raider ship spawn, fire, exit, destroy |
| `POWERUP ` | Special Scout effect activation, replacement, expiry |
| `PROMOTE ` | Pawn promotion event |
| `SCORE   ` | Points awarded |
| `TIMER   ` | Chess beat timer events (start, expiry, check extension) |
| `CHECK   ` | Check or checkmate detected |
| `LEVEL   ` | Level start, clear, game over |
| `AUDIO   ` | Music state changes, SFX triggers |
| `INPUT   ` | Player input events (debug only, very verbose) |
| `ERROR   ` | Unexpected states, assertion failures |

**Color scheme:** category label is always **green** (`#00ff44`), description text is always **white** (`#ffffff`). This applies uniformly to all categories. Exceptions for specific categories (e.g. ERROR label in red, CHECK label in red) can be added later once the log is running and we see which events need to stand out during playtesting.

`INPUT` events are suppressed by default even in debug builds — they are too frequent. Enable with a separate flag `logInput = true` in `DiagnosticsLog.swift`.

---

### 19.5 Example Log Output

```
000.00 L00 B00 STARTUP  App launched (macOS 15.2, debug build)
000.02 L00 B00 STARTUP  Window created 900x700
000.08 L00 B00 STARTUP  GameScene loaded
000.11 L00 B00 STARTUP  Intro music started
000.14 L00 B00 STARTUP  Title screen displayed
002.31 L00 B00 INPUT    Key pressed -> GameAction.startGame
002.45 L01 B00 LEVEL    Level 1 started
002.47 L01 B00 INIT     Board reset, 16 white + 16 black pieces placed
002.50 L01 B00 INIT     Spaceship positioned at centre
002.58 L01 B01 TIMER    Beat 1 started (5.0s)
003.12 L01 B01 INPUT    Mouse click -> BoardPosition(e2)
003.13 L01 B01 WHITE    Piece selected: White Pawn at e2
004.82 L01 B01 INPUT    Mouse click -> BoardPosition(e4)
004.84 L01 B01 WHITE    Pawn moved e2->e4
004.88 L01 B01 BLACK    Engine chose: Pawn e7->e5 (eval: +0.0)
004.95 L01 B01 TIMER    Beat 1 completed in 2.37s
004.96 L01 B02 TIMER    Beat 2 started (5.0s)
005.61 L01 B02 FLEET    Fleet swept right (speed: 40px/s)
006.04 L01 B02 FLEET    Visual half-drop 1/2; logical ranks unchanged
006.44 L01 B02 RAIDER   First Scout entered from left at rank 4
009.96 L01 B02 TIMER    Beat 2 expired; auto-move pending
010.02 L01 B02 WHITE    Auto-move selected: Knight g1->f3
010.08 L01 B02 BLACK    Engine chose: Pawn d7->d5 (eval: +0.2)
010.14 L01 B02 TIMER    Beat 2 completed (auto)
010.15 L01 B03 TIMER    Beat 3 started (5.0s)
011.35 L01 B03 RAIDER   Scout exited right (warning pass, no shot fired)
012.43 L01 B03 FLEET    Visual half-drop 2/2; logical ranks descended
013.10 L01 B03 CHECK    White King in check from Black Bishop c5
013.11 L01 B03 TIMER    Check detected; beat extended to 8.0s
014.90 L01 B03 WHITE    Pawn moved e4->e5 (resolves check)
014.92 L01 B03 CHECK    Check resolved
018.66 L01 B05 PROMOTE  White Pawn reached rank 8 at e8
018.67 L01 B05 PROMOTE  Pawn->Queen (HP set to 12)
018.69 L01 B05 DESTROY  Black Pawn f7 destroyed (promotion bonus)
018.70 L01 B05 PROMOTE  Multi-shot +1 (laser cap now: 3)
018.71 L01 B05 SCORE    +25 pts (promotion capture) -> total: 475
026.30 L01 B09 LEVEL    Level 1 cleared; all black pieces destroyed
026.31 L01 B09 SCORE    Level clear bonus: 200 pts -> total: 675
029.00 L02 B00 LEVEL    Level 2 started
029.03 L02 B00 INIT     Board reset, 16 white + 16 black pieces placed
029.18 L02 B01 TIMER    Beat 1 started (5.0s)
031.40 L02 B01 HIT      White Pawn d2 hit by projectile (-1 HP -> 1HP)
```
---

### 19.6 Implementation

```swift
// DiagnosticsLog.swift — shared across all platforms

enum LogCategory: String {
    case startup  = "STARTUP "
    case `init`   = "INIT    "
    case white    = "WHITE   "
    case black    = "BLACK   "
    case hit      = "HIT     "
    case destroy  = "DESTROY "
    case capture  = "CAPTURE "
    case fleet    = "FLEET   "
    case raider   = "RAIDER  "
    case powerup  = "POWERUP "
    case promote  = "PROMOTE "
    case score    = "SCORE   "
    case timer    = "TIMER   "
    case check    = "CHECK   "
    case level    = "LEVEL   "
    case audio    = "AUDIO   "
    case input    = "INPUT   "
    case error    = "ERROR   "
}

class DiagnosticsLog: ObservableObject {
    static let shared = DiagnosticsLog()

    @Published var lines: [LogLine] = []
    var currentLevel: Int = 0
    var currentBeat: Int = 0
    private let appStartTime = Date()
    var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    var logInput: Bool = false   // suppressed by default
    private let maxLines = 2000

    func log(_ category: LogCategory, _ message: String) {
        guard isEnabled else { return }
        if category == .input && !logInput { return }
        let line = LogLine(
            elapsedSeconds: Date().timeIntervalSince(appStartTime),
            level: currentLevel,
            beat: currentBeat,
            category: category,
            message: message
        )
        Task { @MainActor in
            self.lines.append(line)
            if self.lines.count > self.maxLines {
                self.lines.removeFirst()
            }
        }
    }
}

// Usage anywhere in the codebase:
DiagnosticsLog.shared.currentLevel = 1
DiagnosticsLog.shared.currentBeat = 3
DiagnosticsLog.shared.log(.white, "Pawn moved e2->e4")
DiagnosticsLog.shared.log(.hit, "White Pawn d2 hit (-1 HP -> 2HP)")
DiagnosticsLog.shared.log(.check, "White King in check from Black Bishop c5")
```
The `DiagnosticsLog` is a singleton `ObservableObject`. The SwiftUI log panel observes it and updates automatically as new lines arrive. `GameState` updates `currentLevel` and `currentBeat` at level start and beat start; all subsequent logs automatically include that context. The game logic layer calls `DiagnosticsLog.shared.log(...)` directly — no coupling to the view layer.

---

### 19.7 Log Panel in Phase 0

The log panel should be built in **Phase 0** alongside the skeleton app — it is a development tool, not a game feature, and it pays dividends from the very first line of game code written. By the time chess logic and arcade systems are added, every event will already be flowing into the log automatically.

---

## 20. Development Phases & Testing

---

### Phase 0 — Skeleton (App runs, title screen shows, music plays)

**Goal:** Get the Xcode project compiling and launching. Nothing is playable. This phase proves the project structure is sound and gives an early win before any real logic is written. Performance foundations are established here so every subsequent phase builds on them.

**Build:**

- Create Xcode project — macOS app target, SpriteKit + SwiftUI, window set to 900×700
- `GCIApp.swift` + `ContentView.swift` — SwiftUI host with embedded `SKView`
- `GameScene.swift` — bare SpriteKit scene, black background, star parallax placeholder
- Title screen — "GALACTIC CHESS INVADERS" text in pixel font, centered, color-cycling neon animation
- "PRESS ANY KEY TO START" blinking text
- Placeholder chiptune music loop playing on launch (even a simple repeating tone is fine)
- Pressing any key transitions to a static game screen — black background, placeholder colored rectangles where pieces will go, no interaction
- `DiagnosticsLog.swift` — singleton log, time/level/beat prefix, category system, 2,000-line cap
- Right sidebar log panel (macOS) — scrollable, monospace green on black, auto-scrolls to bottom
- `L` key toggles sidebar on/off; game scene expands to fill window when hidden
- Log panel shows STARTUP and INIT events from the moment the app launches
- ⚡ **Enable SpriteKit debug overlays from day one:** `skView.showsFPS = true`, `skView.showsNodeCount = true`, `skView.showsDrawCount = true` — visible in debug builds, off in release. These must stay green (60fps, <150 nodes, <10 draw calls) throughout development.
- ⚡ **`GameAction` enum defined** — all input will flow through this abstraction from the first keypress. Never reference `NSEvent` or `UITouch` outside `MacInputHandler.swift`.
- ⚡ **Single `SKEffectNode` established** as the parent for all glowing game content — bloom shader will be attached here in Phase 2. Establishing the node hierarchy now prevents restructuring later.

**Testing:**

- App compiles with zero warnings
- App launches without crashing
- Title screen renders correctly in a 900×700 window
- Music starts on launch, loops without glitching
- Pressing any key on the title screen transitions to the game screen
- Window is resizable, game screen scales correctly
- Full screen mode works via the green traffic-light button
- Quit via ⌘Q works cleanly
- Log sidebar visible on launch showing STARTUP events in green monospace
- `L` key hides/shows the sidebar, game scene resizes correctly
- ⚡ FPS counter shows 60fps on the title screen
- ⚡ Draw count shows ≤3 on the title screen (background + text + any decoration)
- **Pass criteria:** someone who has never seen the project can launch it, see the title screen, hear music, press a key, see a placeholder game screen, and see STARTUP events flowing in the log sidebar — all without a crash, at a steady 60fps

---

### Phase 1 — Chess Logic (No graphics, no sound)

**Goal:** Prove all chess rules work correctly in isolation before any visuals are added. Pure Swift, unit tests only — no SpriteKit involved.

**Build:**

- `Board.swift` — 8×8 board model, piece placement, debug position printer
- `Piece.swift` — piece types, colors, HP values
- `MoveGenerator.swift` — all legal moves for all piece types (no castling, no en passant)
- `ChessEngine.swift` — 1-2 ply minimax, material evaluation, aggressive mode flag
- `TurnTimer.swift` — level-based chess beat countdown logic, expiry callback, 8s check extension
- `LevelManager.swift` — level parameters table, state transitions
- ⚡ **Chess engine is pure Swift with no SpriteKit imports** — it must compile and run in a command-line test target with zero UI dependencies. This enforces the logic/rendering separation from the first line of chess code.
- ⚡ **Engine designed for async execution** — `ChessEngine.bestMove()` is marked `async` from day one, even though it won't be called from a background thread until Phase 2. Retrofitting async onto a synchronous design is painful.
- ⚡ **Move generation benchmarked** — add one performance test: generate all legal moves from the starting position 1,000 times and assert it completes in under 100ms total. This sets a baseline and catches accidental O(n²) loops early.

**Testing:**

- Unit test every piece's legal moves from a variety of board positions
- Unit test pawn promotion triggers correctly at rank 8
- Unit test check detection — king-in-check correctly identified
- Unit test checkmate — use Fool's mate and Scholar's mate positions
- Unit test engine produces only legal moves
- Unit test HP damage — piece takes damage, reaches 0, is removed from board model
- Unit test turn timer — fires at correct interval, extends to 8s on check
- Unit test chess beat scheduler — fleet sweep completion does not trigger a black chess move; black moves only during the scheduled black-move phase
- ⚡ Performance test: 1,000 move generations complete in under 100ms
- ⚡ Performance test: full 1-2 ply engine evaluation completes in under 50ms per turn
- **Pass criteria:** all unit tests green; chess engine plays a complete game to conclusion with no illegal moves; performance benchmarks pass

---

### Phase 2.1 — Playfield: Chess Functional

**Goal:** Wire the chess logic to the scene so chess is fully playable. Sprites are simple neon-colored shapes — correct size and color, not final art. Input, game state, HUD, and coordinate system all established correctly here.

**Build:**

- `BoardLayout.swift` — coordinate mapping, no visible grid. `boardLayout.screenPosition(for: square)` helper, all positions as fractions of scene size — no hardcoded pixels
- `PieceNode.swift` — simple colored placeholder silhouettes scaled by the §12.2 display sizing rule, correct glow colors (white=cyan, black=magenta); damage frames stubbed as progressively dimmer/thinner outlines (will be replaced by final neon-vector damage states in Phase 2.2)
- `HUDNode.swift` — score, level, lives, turn timer in pixel font
- `ReticleNode.swift` — plain crosshair markers, no glow yet
- `MacInputHandler.swift` — keyboard + mouse → `GameAction` abstraction
- `GameRules.swift` + `GameState.swift` — pure turn state machine and rule coordinator; `GameScene` reads their results and updates nodes
- Piece move animation — smooth `SKAction.move` slide
- Auto-move "AUTO" flash indicator
- Check warning — king flashes, HUD warning
- ⚡ **All piece sprites in `Pieces.spriteatlas`** from day one
- ⚡ **Chess engine called via `Task.detached`** — never on main thread, verified from first move
- ⚡ **`ReticleNode` pool** — 32 nodes pre-created, shown/hidden not added/removed
- **Chess SFX (basic set)** — wired here because even a functional chess game is dead without sound feedback:
  - Piece selected — soft click
  - White piece moves — soft thud
  - Black piece moves — same, slightly lower pitch
  - Piece captures — heavier impact thud
  - Check — two-note alarm stab
  - Checkmate — descending multi-note fanfare stab
  - Auto-move fired — buzzer + move sound
  - Turn timer warning (≤2s) — rapid ticking
  - Illegal move attempt — short low buzz

**Testing:**

- Click white piece — reticles appear at correct legal destinations
- Click reticle — piece slides to new position
- Timer counts down, expiry fires auto-move, "AUTO" appears
- Timer expiry with piece selected — engine moves that specific piece
- Fleet sweep completion during an active chess beat does not trigger a black chess move
- Check detected — alarm plays, timer extends to 8s
- Checkmate — fanfare plays, game over state reached
- Every chess sound plays on its correct trigger, none play spuriously
- Window resize — pieces stay in correct positions at 3 different sizes
- Window resize — `squareSize` remains ≥48 pt at the minimum supported 640×500 window, or the playfield letterboxes instead of shrinking below that minimum
- Piece layout — displayed piece bounds never overlap adjacent ranks/files at minimum, default, or full-screen window sizes
- Mouse selection — every displayed piece has at least a 40×40 pt selectable rectangle, and selection padding does not overlap a neighboring piece's selectable rectangle at minimum window size
- ⚡ 60fps, draw count ≤5, node count ≤80 with all 32 pieces on screen
- **Pass criteria:** full chess game playable to checkmate at 60fps — may look rough, must work correctly

---

### Phase 2.2 — Playfield: Recharged Visual Treatment

**Goal:** Replace placeholder shapes with final neon-vector sprites and apply the full Recharged aesthetic. No new gameplay — purely visual upgrade. Done once here; only minor refinements expected in Phase 8 if review identifies issues.

**Build:**

- Final neon-vector outline sprite for all 12 piece types (6 white, 6 black) — correct silhouettes per §12.2, smooth outlines, empty interiors
- All 4 damage states per piece: Full / Chipped / Cracked / Critical
- Default (linear) texture filtering — smooth vector shapes, no `.nearest` needed
- Neon bloom shader — `SKEffectNode` with `shouldRasterize = true` on Phase 0's effect node
- Idle bob animation — `SKAction.repeatForever` 4-frame float on all pieces
- Piece move ghost trail — neon motion blur streak fades in 0.3s
- Reticle glow — neon green bloom added to crosshair markers
- Basic parallax starfield — 2 tiling texture layers scrolling downward (no individual star sprites) (2 layers; expanded to 4 in Phase 8)
- Pure black background confirmed — no accidental grey

**Testing:**

- All 12 sprites match the design spec — correct silhouettes and glow colors
- Pixel art crisp at all window sizes including full screen on Retina display
- Bloom glow visible on pieces and reticles
- Idle bob animation running on all pieces simultaneously
- Ghost trail appears on piece moves, fades correctly
- Starfield scrolls smoothly, no tiling seams visible
- ⚡ `shouldRasterize = true` confirmed active — bloom not recalculating every frame
- ⚡ 60fps maintained with bloom active, draw count still ≤5
- **Pass criteria:** game looks like a Recharged arcade title; performance unchanged from Phase 2.1

---

### Phase 3.1 — Arcade Layer: Fleet Movement

**Goal:** Get the black fleet sweeping and descending correctly. No shooting yet — just prove the Invader formation movement works alongside chess.

**Build:**

- `FleetRules.swift` — pure two-step descent counter, full-rank logical descent, speed scaling by piece count
- `FleetController.swift` — SpriteKit lateral sweep via `SKAction.repeatForever` on fleet parent node; calls `FleetRules` at wall bounces
- Fleet speed multiplier table wired to piece count
- ⚡ **Fleet movement is one `SKAction` on the parent node** — 16 pieces move at zero per-piece cost
- Log entries: `FLEET Swept right (40px/s)`, `FLEET Visual half-drop 1/2`, `FLEET Logical rank descended`, `FLEET Speed 1.2× (12 pieces remain)`

**Testing:**

- Fleet sweeps right, hits wall, drops a visual half-rank with no logical board change, sweeps left, drops a second visual half-rank, then updates logical ranks by one
- Fleet speeds up correctly as pieces are eliminated — verify all 5 multiplier steps
- First visual half-drop does not affect chess logic; every second half-drop updates black logical ranks by one, and pieces snap to correct logical squares for move generation
- Chess game remains fully playable while fleet is sweeping
- ⚡ 60fps with full fleet sweeping continuously
- **Pass criteria:** fleet sweeps indefinitely without drift, chess still fully playable alongside it

---

### Phase 3.2 — Arcade Layer: Shooting & Collision

**Goal:** Add the spaceship, player laser, invader shots, HP damage, and lives. The core shoot-em-up loop.

**Build:**

- `SpaceshipState.swift` — pure ship lives, 2-shot laser cap, shield state, respawn/invincibility timers
- `ProjectileState.swift` — pure player/enemy projectile ownership, damage, speed, active state
- `SpaceshipNode.swift` — SpriteKit ship movement and respawn animation
- `LaserNode.swift` — SpriteKit player/enemy projectile nodes
- `CollisionResolver.swift` — pure damage/scoring/destruction outcomes
- `CollisionHandler.swift` — SpriteKit physics contact delegate. Physics bodies circles/rects only, bitmasks set correctly; delegates rule decisions to `CollisionResolver`
- Fleet firing — 1 shot per turn (Level 1: none), weighted toward front-rank pawns
- HP damage — player laser 2 HP per hit, invader shot 1 HP per hit, friendly fire 2 HP
- Piece destruction on HP=0 — removed from board model immediately
- Scoring — all point values wired up, score increments in HUD
- ⚡ **`LaserPool`** — 6 player + 16 enemy nodes pre-created, zero allocation during play
- ⚡ **`Projectiles.spriteatlas`** — all projectile sprites in one atlas
- ⚡ **Physics bitmasks** — player laser tests only enemy/friendly pieces; enemy shots test only white pieces + ship

**Testing:**

- Player laser fires, travels 400 px/s, damages black pieces correctly (HP values per piece type)
- Pawn dies in 1 hit, Knight/Bishop in 3, Rook in 4, Queen in 6, King in 8
- Invader shots travel 180 px/s, deal 1 HP to white pieces
- Friendly fire — 2 HP to own piece
- Ship hit — life lost, respawn at centre, 2s invincibility
- Invincibility — cannot be hit during grace period
- Lose 3 lives — game over
- Black piece reaches rank 1 — game over
- All black pieces destroyed — level clear
- All scoring events correct per scoring table
- ⚡ 60fps with fleet + 6 simultaneous projectiles
- **Pass criteria:** full level completable by shooting alone, all damage and scoring correct

---

### Phase 3.3 — Arcade Layer: Damage States & Juice

**Goal:** Add visual feedback for damage — smoke, flicker, explosions, screen shake, score pop-ups. The game should feel physical and satisfying.

**Build:**

- Smoke particle trail on pieces at ≤50% HP
- Sprite flicker on pieces at ≤25% HP
- Explosion animation on piece destruction (placeholder single burst — full per-piece animations in Phase 8)
- Score pop-up labels floating up from destroyed targets
- Screen shake per event (intensities per §24.1)
- Hit freeze on high-value piece destruction (2–4 frames)
- ⚡ **`ScorePopPool`** — 20 label nodes pre-created, reused for every pop-up

**Testing:**

- Smoke appears at correct HP threshold, disappears on piece destruction
- Flicker appears at correct threshold
- Explosion plays on every destruction
- Score pop appears at correct position, floats up, fades
- Screen shake fires on correct events at correct intensities
- Hit freeze noticeable on Queen/King destruction, absent on Pawns
- ⚡ 60fps maintained with smoke, explosions, and popups all active simultaneously
- **Pass criteria:** destroying pieces feels satisfying; performance unchanged from Phase 3.2

---

### Phase 4 — Basic Sound Effects

**Goal:** Get the core game feeling alive with essential SFX. No music yet — just the sounds that make every action feel responsive. Use placeholder/temp audio files if final assets aren't ready; the plumbing matters more than the polish at this stage.

**Build:**

- `AudioManager.swift` — preloads all SFX into memory at level load, zero I/O during gameplay. Multiple `AVAudioPlayer` instances per frequently-used sound (laser fire, hits) to allow overlapping playback without stutter
- Player laser fire — short rising tone
- Player laser hits a piece — crunchy impact burst
- Player laser misses (exits screen) — soft descending blip
- Black piece destroyed — explosion pop (one sound for all pieces for now; per-piece sounds come in Phase 7)
- White piece destroyed — lower sadder explosion pop
- Ship hit / destroyed — loud noise burst
- Ship respawn — short ascending tone
- Chess SFX already in from Phase 2.1 (piece select, move, capture, check, checkmate, auto-move, timer tick)

**Testing:**

- Every listed sound plays on its correct trigger
- No sounds play when they shouldn't (e.g. no explosion on a non-destroying hit)
- Sounds don't stack into a wall of noise when many events happen simultaneously
- Ship destruction sound is clearly distinct from piece destruction
- Game feels noticeably more alive than silent Phase 3
- **Pass criteria:** a full level playthrough with no jarring silences on any major event

---

### Phase 5 — Background Music + Settings

**Goal:** Add the chiptune soundtrack and a proper Settings screen. Music should loop cleanly and respond to basic game state changes. Settings are persistent and extensible — not a temporary hack.

**Build:**

- Main gameplay chiptune loop — looping cleanly with no audible gap
- Per-level music track — pick randomly from level pool, loop for duration of wave
- Level clear fanfare — short 3–4 second jingle
- Game over riff — descending death riff
- Title screen music — plays on the title/attract screen, stops when game starts
- Basic music/SFX volume balance — music ducked slightly under loud SFX
- **`SettingsView.swift`** — full SwiftUI settings screen, persistent via `UserDefaults`:
  - Master volume, Music volume, SFX volume (sliders)
  - Music on/off toggle
  - Stubbed sections for Gameplay (difficulty), Controls (key remapping), and Display — structure present now so adding entries later requires no rework
- Settings accessible from **separate entry points**: Settings button on title screen, plus a dedicated subtle Settings control or keyboard shortcut during gameplay. Opening Settings during gameplay pauses the game until Settings closes.
- Pause remains a simple overlay, not a menu. `P` always toggles pause/resume. `Escape` first cancels an active chess selection; if there is no active selection, it toggles pause/resume. The pause overlay has no buttons and no settings/options menu.

**Testing:**

- Music loops without a gap or click
- Music track loops cleanly throughout the wave without pops or gaps
- Level clear fanfare plays on victory, then next level music resumes
- Game over riff plays on defeat, does not loop
- Title music stops cleanly when game starts
- Music and SFX do not clash at default volume levels
- Volume sliders work correctly and persist across app restarts
- Settings reachable from title screen and from its dedicated gameplay entry point, not from the pause overlay
- Pause/resume via Escape and P freezes and restores the game without changing selection, settings, or game state
- Stubbed Gameplay/Controls/Display sections present but clearly marked as coming soon
- **Pass criteria:** a full playthrough with music feels like a complete arcade experience; settings persist correctly across sessions

---

### Phase 6.1 — Raiders: Scout & Basic Escort

**Goal:** Get the two simplest raiders working correctly before adding complex variants. Establish the `RaiderController` architecture that all subsequent raiders build on.

**Build:**

- `RaiderController.swift` — spawn timing, max-2-on-screen cap, real-time interval (independent of chess turns)
- `Raiders.spriteatlas` — Scout and Escort sprites packed together
- Raider Scout — enters from edge, crosses at rank 4–5, fires one acid-green shot, exits. 1 HP.
- Basic Galaxian Escort — peels off from back rank of fleet, curved dive toward ship's last position, fires at apex, exits. 1 HP.
- Escort peel-off animation — slides out from behind rearmost piece in its column
- Scout SFX: warbling UFO hum on entry, descending whistle on fire, fades on exit
- Escort SFX: rising pitch sweep on peel-off, swooping tone on dive
- Raider destroyed SFX: 3-note explosion distinct from fleet pieces
- Scoring: Scout 100 pts, Escort 150 pts

**Testing:**

- First Scout in a level enters from left or right edge, crosses at correct height without firing, and exits
- Subsequent Scouts in that level cross at the same height, fire one shot, and exit
- Scout shot is acid green — visually distinct from fleet shots
- Escort peels off from back rank, not a random position
- Escort dives toward ship's last known position (not current position)
- Escort collision with ship costs one life
- Maximum 2 raiders on screen — third queued until one exits
- All Scout and Escort SFX trigger correctly
- ⚡ No frame drop when both raiders are on screen simultaneously with full fleet
- **Pass criteria:** Scout and Escort behave correctly with audio; frame rate unaffected

---

### Phase 6.2 — Raiders: Flagship, Variants & Special Scouts

**Goal:** Add the Flagship and the three Escort variants (Kamikaze, Paired, Looping), plus the full Special Scout power-up system (§13).

**Build:**

- Galaxian Flagship — flanked dive with 2 Escorts, 2 HP, first-hit flash + clang, second hit destroys. 300 pts.
- Kamikaze Escort — fast no-shot straight dive at ship, no audio warning
- Paired Escorts — two Escorts dive in synchronized formation
- Looping Escort — dives, arcs back up, dives a second time before exiting
- `SpecialScoutController.swift` — per-level spawn logic, scout type selection, effect trigger on destruction
- `PowerUpNode.swift` — Special Scout destruction burst + type-label flash (no falling pickup — effects trigger on scout destroy)
- All 5 Special Scout types: Lightning, Ice, Spread, Bomb, Repair (§13.2)
- Each effect: activation, HUD indicator, expiry (§13.2)
- Flagship SFX: metallic clang on first hit, raider explosion on second
- Special Scout SFX: per-type destroy sound + effect audio (§13.2)
- Flagship added to `Raiders.spriteatlas`; Special Scout sprites added to same atlas

**Testing:**

- Flagship flanked by 2 Escorts — Escorts must die before Flagship takes damage
- Flagship first hit — flashes, clangs, accelerates; does not die
- Flagship second hit — dies, 300 pts
- Kamikaze — no shot, fast straight dive, requires lateral dodge
- Paired Escorts — two dive in formation simultaneously
- Looping Escort — dives, loops up, dives again before exiting
- Special Scouts replace standard Scout spawns according to §13.1; no falling pickup item is created
- Destroying a Special Scout immediately activates its power-up at the scout's destruction position
- Destroying a Repair Scout immediately activates Shield Bubble around the player's ship
- Shield Bubble absorbs one ship hit, then shatters visually and aurally
- Destroying a second Special Scout while any power-up is active replaces the previous effect immediately
- Flagships do not drop shields or power-ups
- All new SFX trigger correctly
- ⚡ 60fps with Flagship + 2 Escorts + full fleet + projectiles simultaneously
- **Pass criteria:** all raider types and power-up behave correctly with audio across 5+ levels of play

---

### Phase 7.1 — Level Escalation: Chess AI

**Goal:** Make black play smarter and faster as levels increase. These are changes to the chess engine and turn structure only — no new arcade content.

**Build:**

- Aggressive engine mode (Level 2+) — engine weights pawn advancement and attacking moves over passive play
- 2 chess moves per turn (Level 3) — two distinct pieces relocate to two distinct destination squares each turn
- 3 chess moves per turn (Level 5) — three distinct pieces relocate to three distinct destination squares each turn when enough non-conflicting legal moves exist
- Score multiplier wired to level — 1.0× at Level 1, +0.5× per level

**Testing:**

- Level 2: engine demonstrably prefers advancing pawns — log BLACK moves over 10 turns and verify advancement bias
- Level 3: exactly 2 BLACK log entries per turn
- Level 5: exactly 3 BLACK log entries per turn
- Multi-move turns never select the same source piece twice
- Multi-move turns never select the same destination square twice
- If fewer than the target number of non-conflicting legal moves exist, Black makes the available non-conflicting legal moves only
- Score multiplier — verify +25 pawn capture scores 25 on Level 1, 37 on Level 2, 50 on Level 3
- Chess game remains legal throughout — no illegal moves produced by multi-move turns
- **Pass criteria:** AI escalation verified by log output across Levels 1–5; no illegal chess states

---

### Phase 7.2 — Level Escalation: Arcade Mechanics

**Goal:** Add the arcade escalation features — diagonal shots, piece regeneration, fleet rush, and the pawn promotion power-up event.

**Build:**

- Diagonal invader shots (Level 3+) — 45° projectiles, purple glow, 160 px/s. Collision detection uses SpriteKit physics bodies (not strict geometric 45° line intersection) — the shot hits any piece whose physics body it overlaps during travel
- Piece regeneration (Level 4+) — destroyed black pieces respawn as Pawns after 10s, dimmer glow, slot cap per level
- Fleet rush mechanic (Level 5+) — one random piece jumps 2 ranks forward after each full-rank logical descent
- Pawn promotion triple event — auto-queen swap, targeting beam destroys nearest black piece, laser cap +1 (stacks per promotion, hard cap 6, resets next level)

**Testing:**

- Level 3: diagonal shots appear, travel at 45° at correct speed
- Level 4: regenerated Pawn spawns at back of fleet after 10s with dimmer glow
- Level 4: regeneration cap (2 per level) respected — stops after cap reached
- Level 5: one piece rushes forward 2 ranks per sweep — verify via log
- Pawn reaches rank 8 — Queen swap, nearest piece destroyed, multi-shot banner appears
- Multi-shot stacking: each promotion adds +1 to laser cap; verify cap is 3 after 1st, 4 after 2nd; hard cap of 6; resets to 2 at next level start
- Play Levels 1–5 in sequence — every feature activates on its correct level
- **Pass criteria:** 5 complete levels with every arcade escalation feature activating on schedule

---

### Phase 8 — Visual Polish

**Goal:** Refine and complete the visuals. Core sprites and glow are already in from Phase 2 — this phase adds cinematic detail, animation depth, and the remaining screen treatments. Also upgrades SFX to per-piece sounds.

**Build:**

- Full 4-layer parallax starfield (Phase 2 has 2 layers — complete it here)
- Wireframe geometric debris in foreground layer (Asteroids Recharged style)
- Full piece sprite art refinement — final neon-vector detail pass if needed
- 8-frame explosion sprite sheets per piece type — distinct per piece
- Per-piece explosion sounds (replacing the generic pop from Phase 4)
- Music ducking — music drops 30% on priority-1/2 SFX events, recovers in 0.5s
- Score pop float animations, turn timer pulse animation
- Hyperspace jump on level clear
- "AUTO", "CHECK", "MULTI-SHOT ACTIVATED" banner animations
- Title screen attract mode (5-slide cycle, 12s timeout)
- High score entry (8-character initials, top 10 stored, top 5 displayed)
- Game over and level clear screens

**Testing:**

- Pixel art crisp at all window sizes — no blurring on Retina
- Neon glow renders on all pieces and lasers
- Each piece type has a distinct explosion sound — Pawn pop vs Rook thud vs King sweep
- Music ducking works — loud SFX briefly lower music volume
- Attract mode cycles 5 slides, any key exits to game
- High score entry — 8 chars, A–Z/0–9, persists across restarts
- New high score — entry screen appears, saved to table
- All banner animations ("AUTO", "CHECK", "MULTI-SHOT ACTIVATED") trigger correctly
- **Pass criteria:** full playthrough from title to game over looks and sounds like a finished arcade game

---

### Phase 9 — Mac Hardening & App Store Release

**Goal:** Fix bugs, balance, submit to Mac App Store.

**Build:**

- Bug fixes from playtesting
- Balance tuning — HP values, fleet speeds, spawn rates
- App icon (all required sizes)
- Mac App Store screenshots and metadata
- App Sandbox entitlements
- Notarization

**Testing:**

- Playtest: 5+ hours across levels 1–5+ by 2–3 people outside the project
- Is Level 1 learnable in one attempt? Level 3 urgent? Level 5 overwhelming-but-fair?
- Regression test all Phase 0–8 cases after balance changes
- Memory — no leaks over 30 minutes (Instruments: Allocations)
- CPU — 60 fps on 2019 MacBook Pro or newer (Instruments: Time Profiler)
- Window resize during play — no crashes, no artifacts
- Rapid pause/unpause — no state corruption
- App Store guidelines compliance
- **Pass criteria:** no crashes in 2 hours, 60 fps, App Store submission accepted

---

### Optional Future Port — iPad

**Goal:** Not part of Mac v1.0. If an iPad version is approved later, use the shared codebase and perform a dedicated touch/layout design pass. iPad is likely lower risk than iPhone because its larger screen is closer to the Mac layout.

**Build:**

- New iOS target in Xcode project, only after the port is explicitly approved
- `TouchInputHandler.swift` — translates touch → `GameAction`
- `VirtualJoystick.swift` — left-thumb zone for ship movement
- On-screen fire button — large tap target, bottom-right
- Pause button — top-right corner
- iPad layout pass — pieces can be larger, HUD richer, more screen real estate
- Landscape-only lock (`UISupportedInterfaceOrientations`)
- Safe area insets handling
- Audio session interruption handling (phone calls, Siri)
- `scaleMode = .aspectFill` on iPad (fills the screen more fully than Mac's `.aspectFit`)

**Testing:**

- All Phase 1 chess logic unit tests pass unchanged
- Virtual joystick moves ship smoothly, fire button responsive
- Tap to select piece, tap reticle to move — works reliably on iPad Pro and iPad mini
- No misfire when tapping near piece vs. empty space
- Landscape lock — refuses portrait rotation
- Audio interruption — game pauses, resumes correctly after call ends
- 60 fps on iPad (8th gen) or newer
- Level 1–3 full playthrough on iPad — no control frustrations
- **Pass criteria:** complete playthrough on iPad Pro and iPad mini with no input errors

---

### Optional Future Port — iPhone

**Goal:** Not part of Mac v1.0. If an iPhone version is approved later, smaller screen size and narrower aspect ratio will require the most layout work.

**Build:**

- iPhone layout pass — smaller piece sprites, compact HUD, tighter touch zones
- Larger touch targets for piece selection (pieces are smaller but tap area is padded)
- Virtual joystick and fire button scaled for one-thumb reach
- HUD condensed — score and lives on same line to save vertical space
- Test on smallest supported screen (iPhone SE 3rd gen, 4.7")
- App Store metadata for iPhone

**Testing:**

- All touch controls work on iPhone SE (smallest screen)
- Piece tap targets — no misfires at minimum sprite size
- HUD legible at iPhone screen size — score, timer, lives all readable
- No UI elements clipped by notch or home indicator safe areas
- 60 fps on iPhone 12 or newer
- Level 1–3 full playthrough on iPhone 15 and iPhone SE
- Chess piece selection under fire — tap accuracy acceptable given arcade pace
- **Pass criteria:** complete playthrough on both iPhone SE and iPhone 15 Pro with no missed taps on piece selection

---

| Feature | Phase | Notes |
|---|---|---|
| Game Center leaderboards | 2 | Online high scores by level; replaces local-only table |
| iCloud sync | Future | High scores and settings across devices if a multi-device strategy is approved |
| Additional power-ups | Future | Post-launch DLC possibilities; v1.0 ships with the five Special Scout types only (§13) |
| Chess960 mode | 2 | Randomized starting positions — changes fleet formation shape each game |
| Multiplayer (local) | 3 | Two players: one flies the ship, one makes chess moves |
| Deeper engine option | 3 | Optional 3-4 ply for "hard" difficulty setting |
| Piece skins / themes | 3 | Unlock alternate neon color schemes via score milestones |
| Replay system | 3 | Record and play back last game |
| Soundtrack volume reactivity | 2 | Full dynamic music system tied to game state (designed in §12, basic version in v1.0) |

---

## 21. Difficulty Tuning

All values below are starting points for playtesting — they should be adjusted once the game is running. The key feel target: Level 1 should be learnable, Level 3 should feel urgent, Level 5+ should feel overwhelming-but-survivable.

### 21.1 Per-Level Parameters

| Level | Fleet speed (px/s) | Black moves/turn | Shots/turn | Proj. speed | Turn timer | Regen slots | Raider interval |
|---|---|---|---|---|---|---|---|
| 1 | 40 | 1 (passive) | **0** | — | 5s | 0 | 20s, Scouts only |
| 2 | 55 | 1 (aggressive) | 1–2 | 180 px/s | 5s | 0 | 15s, Escorts begin |
| 3 | 70 | 2 (aggressive) | 2 | 180 px/s | 4s | 0 | 12s, paired Escorts, Flagship ×1 |
| 4 | 90 | 2 (aggressive) | 2–3 | 200 px/s | 4s | 2 | 10s, looping + Kamikaze Escorts |
| 5 | 110 | 3 (aggressive) | 3 | 216 px/s | 4s | 4 | 8s, all raider types |
| 6+ | +15/level | 3 (cap) | 3 (cap) | +10%/level | 4s (floor) | +1/level | 6s (floor) |

*Note: "Proj. speed" above is straight-down invader shot speed. Diagonal shots (Level 3+) travel at 160 px/s regardless of level — see §21.3.*

### 21.2 Speed Scaling Within a Level

As black pieces are eliminated the fleet speeds up, classic Invaders-style:

| Black pieces remaining | Speed multiplier |
|---|---|
| 16 (full fleet) | 1.0× |
| 12 | 1.2× |
| 8 | 1.5× |
| 4 | 2.0× |
| 1 | 2.5× |

### 21.3 Projectile Speeds

| Projectile | Speed (px/s) |
|---|---|
| Invader shot (straight) | 180 |
| Invader shot (diagonal, Level 3+) | 160 |
| Raider Scout shot | 200 |
| Escort / Flagship shot | 220 |
| Player laser | 400 |

Player laser is always faster than any incoming projectile so shooting down enemy shots is reliably possible.

---

## 22. Controls Reference

### 22.1 macOS (Keyboard + Mouse / Trackpad)

The player operates two systems simultaneously — the spaceship with the keyboard (left hand) and chess with the mouse or trackpad (right hand). This split is intentional and central to the game's tension. Both inputs are always live; selecting a chess piece never freezes the ship.

| Action | Input |
|---|---|
| Move ship left | `←` or `A` |
| Move ship right | `→` or `D` |
| Fire laser | `Space` |
| Select white chess piece | Left-click on piece |
| Confirm chess move | Left-click on destination reticle |
| Deselect piece | `Escape`, right-click, or left-click empty space |
| Pause / resume | `P`, or `Escape` when no chess piece is selected |
| Quit to title | `⌘Q` |

Both `←/→` arrow keys **and** `A/D` keys are supported simultaneously with no configuration — the player uses whichever feels natural. This makes the game comfortable on both external keyboards (arrow keys) and laptop keyboards where WASD keeps the left hand centred on the trackpad.

Escape is contextual in the standard "back/cancel" sense. If a chess piece is selected, Escape cancels that selection and removes the reticles. If no chess piece is selected, Escape pauses the game. While paused, Escape resumes the game. `P` is the dedicated pause/resume toggle and does not affect chess selection.

#### Timer expiry with a piece selected

If the level's chess beat expires while the player has a white piece selected, the chess engine picks the **best available move for that specific piece** and executes it automatically. The reticles flash once before the move fires, giving a half-second visual warning. This rewards partial intent — the player chose a piece, the engine completes the thought.

If no legal move exists for the selected piece (e.g. it is pinned), the engine deselects it and picks any legal white move instead.

### 22.2 Optional Future Touch Controls

Not part of Mac v1.0. If an iOS/iPadOS port is approved later, likely controls are:

| Action | Input |
|---|---|
| Move ship | Left virtual joystick (bottom-left zone) |
| Fire laser | Fire button (bottom-right zone) |
| Select + move chess piece | Tap piece, then tap destination reticle |
| Deselect piece | Tap empty space |
| Pause | Pause button (top-right corner) |

The left half of the screen would drive the ship; the right half (and upper area) would handle chess. This needs a dedicated touch playtest pass before any mobile commitment.

### 22.3 Dual-Input Design Note

The game is explicitly designed around the difficulty of doing two things at once: flying and shooting with one hand while making timed chess decisions with the other. This is the core skill loop. Controls should never be simplified to remove this tension.

---

## 23. Edge Cases & Rules Clarifications

### 23.1 Stalemate

Chess stalemate (no legal moves for white, not in check) is **ignored**. The spaceship can always act — shoot, dodge — even if no chess move is currently legal. The turn timer still runs; when it expires the auto-move engine will find that no chess move is available and simply does nothing. The game continues. This situation is rare in practice given that pieces are being destroyed throughout the game.

### 23.2 Game Over Conditions — Complete List

**The mission is the King.** The level ends the moment the Black King falls — by shooting or by chess capture. Clearing the entire board first earns more points, but it is never required. This is the deliberate strategic choice every level: rush the King once a lane opens, or keep shooting to maximize score before delivering the killing blow.

The game ends immediately under any of the following:

| Condition | Result |
|---|---|
| White king HP reaches 0 (shot) | Defeat |
| White king is checkmated | Defeat |
| Spaceship loses all remaining lives | Defeat |
| Any black piece reaches rank 1 | Defeat |
| Black king HP reaches 0 (shot) | **Victory — level clear.** King shot bonus (+500 pts) awarded. Surviving white piece bonuses do NOT apply if pieces remain — the board resets. |
| Black king captured by chess move | **Victory — level clear.** Treated identically to King shot — +500 pts bonus, board resets immediately. |
| Black king checkmated | **Victory — level clear.** Immediate win even if other black pieces remain. Checkmate bonus (+300 pts) awarded in addition to King shot bonus if the King is simultaneously destroyed. |
| All black pieces destroyed (board clear) | **Victory — level clear.** Only achievable if the King was the last piece destroyed. Full surviving white piece bonuses apply. |

**How-to-Play wording (canonical):** *"Defeat the Black King — shoot it down or capture it in chess. The level ends the moment the King falls. Clear the board first for maximum points, or go straight for the King. Your call."*

**Checkmate as a bonus path:** Checkmate is not required to win but rewards skilled chess play with an instant win and a +300 bonus on top of the King destruction bonus. Non-chess players can ignore it entirely and win every level by shooting the King down.

### 23.3 Continues

None. Game over is permanent — the player returns to the title screen. Score is submitted to the local high score table. No mid-game saves.

### 23.4 Game Over Screen & Contextual Tips

**Screen layout:** Game over riff plays. Screen fades to black with centered text:

```
        ★  GAME OVER  ★

        SCORE   042750
        LEVEL   3
        REACHED

        [CONTEXTUAL TIP LINE — see below]

        PRESS ANY KEY
```
**Contextual tip overlay:** A single tip line appears below the score in a semi-transparent pill/label (legible but clearly secondary). The tip is chosen by evaluating the player's session stats against a priority-ordered list of conditions. The first matching condition wins. If no condition matches, a random general tip is shown.

`GameSession` tracks the following stats during play:

| Stat | Type | Description |
|---|---|---|
| `chessMovesMade` | Int | Number of chess moves the player completed |
| `piecesShot` | Int | Black pieces destroyed by player laser |
| `scoutsShot` | Int | Raider Scouts destroyed |
| `kingShotAttempts` | Int | Lasers fired when King column was unobstructed |
| `pawnsPromoted` | Int | Pawn promotions achieved |
| `levelReached` | Int | Last level reached |
| `deathCause` | Enum | `.raider`, `.fleetShot`, `.chessCheckmate`, `.fleetDescent`, `.kingShot` (own King) |
| `fleetReachedRank1` | Bool | Whether any black piece reached rank 1 |
| `livesLostToRaiders` | Int | Lives lost specifically to Raider fire |

**Tip priority table** (evaluated top to bottom; first match shown):

| Priority | Condition | Tip text |
|---|---|---|
| 1 | `chessMovesMade == 0` | `TIP: CLICK A PIECE · CLICK A SQUARE TO MOVE IN CHESS` |
| 2 | `livesLostToRaiders >= 2` | `TIP: SHOOT SCOUTS BEFORE THEY START FIRING BACK` |
| 3 | `fleetReachedRank1 == true` | `TIP: DON'T LET THE FLEET REACH THE BOTTOM ROW` |
| 4 | `piecesShot == 0 && levelReached == 1` | `TIP: BONUS POINTS IF YOU CLEAR THE BOARD` |
| 5 | `kingShotAttempts == 0 && levelReached >= 2` | `TIP: OPEN A CLEAR LANE TO TAKE THE KING DIRECTLY` |
| 6 | `pawnsPromoted == 0 && levelReached >= 3` | `TIP: ADVANCE A PAWN TO ROW 8 FOR AN EXTRA LASER SLOT` |
| 7 | `chessMovesMade <= 2 && levelReached >= 2` | `TIP: CHESS MOVES CAN CAPTURE BLACK PIECES INSTANTLY` |
| 8 | `deathCause == .chessCheckmate` | `TIP: IF IN CHECK · ANY MOVE THAT ESCAPES IT WORKS` |
| 9 | `scoutsShot == 0 && levelReached >= 2` | `TIP: SCOUTS ARE WORTH 100 PTS · AIM FOR THEM FIRST` |
| 10 | *(fallback — random from pool)* | See general tips pool below |

**General tips pool** (shown when no condition matches; pick one at random each game-over):

- `TIP: CHECKMATE THE KING FOR A 300 PT BONUS`
- `TIP: YOUR LASER CAP INCREASES WITH EVERY PAWN PROMOTION`
- `TIP: PIECES WITH CRITICAL DAMAGE WILL FLICKER · FINISH THEM OFF`
- `TIP: CHESS PIECES BLOCK THE FLEET'S DESCENT WHEN IN THEIR COLUMN`
- `TIP: THE FASTER THE FLEET SWEEPS · THE SOONER IT DESCENDS`

**Removal note:** The entire tip system is isolated in a `GameOverTipResolver` class. If playtesting shows tips are intrusive or unhelpful, delete the class and remove the one call site in `GameOverScene`. No other code changes needed.

### 23.5 Pause

Pressing `P` on macOS freezes everything: fleet movement, projectiles in flight, timers, raider ships, particles, music. The screen dims and "PAUSED" appears centered. Pressing `P` again or clicking "Resume" restores exactly the state that was frozen — no input is processed while paused.

### 23.6 Piece Logical Position During Fleet Sweep

**The fleet sweep is not purely cosmetic — it advances the chess game.**

As the black fleet sweeps laterally and descends, visual movement and logical chess position are deliberately separated. Each wall bounce drops the fleet by one **visual half-rank**, but the pieces stay on their current logical chess rank after the first half-drop. Only after the **second** half-drop completes has the fleet descended one full rank; at that moment every black piece's logical chess square is updated by one rank toward White.

This means the chess engine always works from the last completed **full-rank logical descent**, not from the fleet's in-between half-rank visual position. Black's pieces are genuinely advancing on the board — threatening new squares, exerting new pressure on white's position — but only on every second sweep/drop cycle.

The analogy: it is as if the black player has secretly moved all their pieces forward while white wasn't looking. White has no recourse — the new positions are simply where the army is now.

**Two positions, one canonical:**

- **Visual position:** the sprite's actual screen coordinates, updated continuously by `SKAction` on the fleet parent node. Used for shooting hit detection and rendering.
- **Logical position:** the chess square (a1–h8), updated only after every second visual half-drop and after each chess move. Used for all move generation, threat calculation, and projectile origin.

The `FleetController` tracks a two-step descent counter:

1. **Half-drop 1/2:** fleet drops visually by half a rank; no `GCIBoard` mutation, no crush checks, no logical rank change.
2. **Half-drop 2/2:** fleet drops visually by another half-rank; the two half-drops equal one full rank, so `FleetController` iterates all living black pieces and calls `board.forceSet(piece, square: newSquare)` — bypassing legality checks entirely.

This is intentional: fleet movement is an arcade event, not a chess move.

**Collision with white pieces:** Crush events are checked only on the second half-drop, when the full-rank logical descent is applied. If a black piece's new logical square is already occupied by a white piece, a **crush event** fires:

- The white piece is immediately removed from the board (no HP check — the crush is instant)
- A dedicated "crushed" animation plays: the black piece briefly enlarges and the white piece shatters outward in fragments, then the black piece settles on the square
- No points are awarded for a crushed white piece (it was the black fleet's advance, not the player's action)
- If the crushed piece was the **white King**, this triggers game over (defeat) immediately

**Architecture note — bypassing chess legality:** ChessKit enforces legal moves through its `move()` API. Fleet descent and fleet rush events must use a **direct board state mutation** (`forceSet` or equivalent) that bypasses legality validation. GCI maintains its own `GCIBoard` wrapper around ChessKit's position; all forced placements go through `GCIBoard.forcePlace(piece:at:)` which updates the internal bitboard directly. The chess engine (GKMinmaxStrategist) evaluates from the resulting position — it does not know or care how pieces arrived at their squares. This is by design: GCI's chess is a living, cheating game where the rules bend to serve the arcade action.

**Lateral sweep and first half-drop:** The lateral left-right oscillation does *not* update logical squares. The first visual half-drop after a wall bounce also does *not* update logical squares. A black piece remains logically on its last completed rank/file until the second half-drop applies the next full-rank descent. This keeps the chess engine stable between full-rank descents.

### 23.7 Castling

Not implemented for either side in v1.0. The King and rooks move as individual pieces only. The move generator never returns castling moves for White or Black. The UI never shows a castling reticle. The Black chess engine never evaluates or selects castling. Any castling rights present in imported FEN/library state are cleared before GCI move generation runs.

Rationale: castling moves two pieces, depends on historical movement rights, and creates unclear interactions with forced fleet descent, shooting destruction, regeneration, and the no-visible-grid presentation. It is more complexity than value for the arcade-chess pace.

### 23.8 En Passant

Not implemented for either side in v1.0. Pawns capture only by normal diagonal capture. The move generator never returns en passant moves for White or Black. The UI never shows an en passant reticle. The Black chess engine never evaluates or selects en passant. Any en-passant target square present in imported FEN/library state is cleared before GCI move generation runs.

Rationale: en passant depends on the immediately previous pawn move and becomes hard to explain when the board can also change through fleet descent, shooting, crushes, and regeneration. Disabling it keeps pawn behavior readable under time pressure.

### 23.9 Piece Regeneration

From Level 4 onward, destroyed black pieces can regenerate. Rules:

- A regeneration triggers 10 seconds after a black piece is destroyed, subject to the level's regeneration slot cap.
- The regenerated piece is always a **Pawn**, regardless of what was originally destroyed. This is intentional: v1.0 regenerates only Pawns for simplicity and balance. Higher-value piece regeneration (Rook, Bishop in defensive mode) is introduced in later levels specifically and not as a general rule. It spawns at the back of the fleet at a random column position, with full Pawn HP (2).
- Regenerated Pawns are visually distinct — they arrive via a **transporter beam-in effect** (see below) and have a slightly dimmer glow afterwards, so the player can recognise them as respawned.
- Regenerated Pawns are valid chess pieces. They can advance, promote, and fire shots like any other Pawn.
- The black King never regenerates.
- If the level's regeneration slot cap is reached, no further regenerations occur for that level.
- **If the level ends while a regeneration timer is running, the timer is cancelled.** The board resets fresh at the start of each level — no pending regenerations carry over.

#### Transporter Beam-In Effect

All regenerating pieces materialise via a **Star Trek-style transporter animation** — a column of shimmering particles that resolves into the piece over ~2 seconds. No countdown, no warning box — the shimmering column is the warning.

**Visual sequence:**

1. At the target square, a narrow vertical column of sparkling cyan-white particles appears — random pixel-sized flecks flickering at ~20 Hz, contained to the piece's bounding box.
2. Over 1.8 seconds, the particle density increases and the piece sprite fades in from 0% to 100% opacity simultaneously — the piece assembles out of the shimmer.
3. On full materialisation: a single brief flash (one frame of full white) and the particles dissipate instantly.
4. The piece is now fully active: takes damage, fires, and is a valid chess target.

**Colour:** Standard regeneration — green-white shimmer. Defensive regeneration (King protection mode) — blue-white shimmer. The colour tells the player at a glance whether the new piece is random or targeted.

**The piece cannot be shot while beaming in.** Its physics body is inactive during the animation — lasers pass through. It becomes hittable on the frame the materialisation flash fires. This gives the player a readable "not yet real" state without requiring any special UI.

**Audio:** A synthesised transporter shimmer — an oscillating, harmonically-rich tone that rises and sustains for ~1.8 seconds, then cuts cleanly on materialisation. Not the copyrighted Paramount sound; a soundalike with the same shimmering character: amplitude-modulated sine wave, 800–1200 Hz band, with a slight pitch wobble (~4 Hz LFO). One `.caf` file, same asset for both standard and defensive spawns (colour difference handles the visual distinction). Volume: ~60% of master SFX — present but not dominating.

#### Defensive Respawn Mode (Level 4+)

From Level 4 onward, when the Black King reaches **Cracked or Critical HP**, the regeneration system shifts from random back-rank spawning to **targeted defensive formation**: regenerated pieces spawn in positions that directly shield the King rather than at random column positions.

- **Pawn:** spawns one square directly in front of the King (in its current logical column) — an immediate HP buffer between the open lane and the King.
- **Rook (Level 5+):** regenerates in the King's current column at the back rank. The chess engine can now legally move it to defend the file. A Rook in the King's column closes a laser lane entirely until destroyed.
- **Bishop (Level 6+):** regenerates on a diagonal square adjacent to the King, covering approach angles from the player's current ship position.

Defensively-respawned pieces use the same transporter beam-in effect as standard regeneration, but with a **blue-white column** instead of the standard green — a deliberate signal that these pieces are materialising to protect the King. The urgency of finishing off the King before defenses close is the intended reaction.

| Piece | Available from | Trigger |
|---|---|---|
| Pawn (defensive) | Level 4 | King at Cracked HP |
| Rook | Level 5 | King at Critical HP |
| Bishop | Level 6 | King at Critical HP |

Defensive spawns consume the same regeneration slot cap as standard regenerations. The Black King itself never regenerates.

### 23.10 Simultaneous Hits

If a player laser hits two sprites in the same frame (e.g., a projectile and a piece behind it), both take damage. Collision resolution processes all contacts in the frame before removing any nodes — no single-frame sequencing issues.

### 23.11 Score Multiplier

The score multiplier starts at 1.0× and increases by 0.5× at the start of each new level (Level 1: 1.0×, Level 2: 1.5×, Level 3: 2.0×, etc.). All points scored during a level are multiplied by that level's multiplier. The "WHITE PIECE SURVIVING" end-of-level bonus is also multiplied. The multiplier is never reset mid-game — it is a persistent reward for reaching higher levels.

---

## 24. Game Feel ("Juice")

These are the small details that make the game feel physically satisfying. None of them affect game logic — they are all purely presentational.

### 24.1 Screen Shake

| Event | Shake intensity | Duration |
|---|---|---|
| Player ship destroyed | Medium | 0.4s |
| Black Queen destroyed | Light | 0.2s |
| Black King destroyed | Heavy | 0.6s |
| Flagship destroyed | Medium | 0.3s |
| Player laser hits a piece | Micro-shake | 0.05s |

Shake is implemented as a rapid random offset on the camera node, decaying exponentially. It should feel punchy, not nauseating.

### 24.2 Hit Freeze

When a high-value piece is destroyed (Queen, King, Flagship), the game freezes for **2–4 frames** before the explosion animation plays. This is the classic "hit stop" or "hitstun" technique — it makes big impacts feel weighty. Small hits (Pawns, Scouts) get no freeze.

### 24.3 Score Pop

Every time points are awarded, the score value pops up at the location of the destroyed piece/target (+150, +500, etc.) in the piece's glow color, floats upward ~30 pixels, then fades out over 0.8 seconds. The HUD score simultaneously ticks upward digit by digit.

### 24.4 Turn Timer Pulse

The countdown timer pulses (briefly scales up ~10%) on each whole second tick. At 2 seconds remaining it turns red and pulses on every half-second. At 1 second it flashes rapidly. This makes the timer feel urgent without being distracting during calm moments.

### 24.5 Laser Impact Flash

When the player's laser hits anything, there is a single-frame white flash at the impact point — 1 frame only, no linger. Rapid-fire hits create a staccato strobe effect that reads as "I am definitely hitting this."

### 24.6 Piece Movement Trails

When a chess piece moves (either player or auto-move), it leaves a brief neon ghost trail along its path — the same color as its glow. The trail fades within 0.3 seconds. This makes chess moves visible even when the player is focused on shooting.

### 24.7 Fleet Heartbeat Pulse

The black pieces pulse very slightly in brightness (±15% opacity) in sync with the Space Invaders heartbeat bass notes. As the heartbeat speeds up, so does the pulse. This ties the audio and visual rhythm together subconsciously.

### 24.8 King in Danger — Visual Pulse

When the Black King reaches **Cracked damage state** (8 HP remaining — half its maximum), it begins a distinctive red heartbeat pulse overlaid on its magenta glow. This is implemented programmatically on the existing d2 sprite — no additional art asset required:

- The King's glow shifts from magenta (`#FF2060`) toward deep crimson (`#CC0030`), cycling back in a sine wave
- **Cracked state:** 1 Hz pulse (one beat per second)
- **Critical state:** 2 Hz pulse — doubles in urgency, matches the accelerating heartbeat rhythm
- The pulse frequency is intentionally synchronized with the fleet heartbeat sound — visual and audio urgency lock together
- A faint low-frequency hum (distinct from the standard heartbeat) accompanies the pulse as ambient audio — the King's "distress signal"

**What this communicates without words:** the King is now a viable primary target. A player focused on shooting pawns will notice the red pulse and understand instinctively that the objective has shifted. No tutorial overlay needed.

At 0 HP the King destruction is the most cinematic moment in the game: full-screen white flash, expanding ring shockwave sprite, debris particles drifting for ~2 seconds, 0.6-second screen shake, and a long dramatic explosion sweep — the level's climax, earned.

### 24.9 Pawn Promotion Sequence

The pawn promotion event (§25.6) gets a dedicated 0.5-second "moment":

1. All other action continues but dims slightly (80% opacity).
2. Targeting beam locks onto nearest black piece — a bright line drawn from the promoted queen to the target.
3. Target explodes.
4. "MULTI-SHOT ACTIVATED" banner sweeps across in hot white text.
5. Opacity returns to normal.

Total interruption: 0.5 seconds. Not a pause — the player can still move and shoot during it.

---

## 25. Design Decisions

### 25.1 Legal Move Indicators

**Decision:** Shown, but faint.

**Rule:** Select a white piece → dim neon-green crosshair reticles appear at every valid destination. Visible enough to be useful, unobtrusive enough not to dominate the screen during combat. Click any reticle to confirm the move. Press Escape, right-click, or left-click empty space to deselect. Reticles vanish the moment the piece moves or is deselected.

---

### 25.2 Auto-Move Quality

**Decision:** When the timer expires the computer makes a **reasonable chess move** for white using the same 1-2 ply engine that drives black. This is fairer than random — it won't throw away pieces — but it won't be inspired either. "AUTO" flashes orange above the moved piece for 0.5 seconds.

**Rule:** Timer expires → chess engine selects best available white move → executes it → "AUTO" indicator fires. The player is not punished by a blunder, but they lose control of that turn's chess decision.

---

### 25.3 Fleet Descent Rate

**Decision:** The fleet drops **one visual half-rank** per wall bounce, but black pieces stay on their current logical chess rank until the second sweep/drop completes. Two visual half-rank drops equal one full-rank logical descent. This gives 12 wall-bounce drops, or 6 full logical rank descents, before the fleet reaches the white back rank — more time to thin out the fleet by shooting before they get dangerously close. Lateral speed still increases as pieces are eliminated, maintaining escalating tension.

**Rule:** Fleet hits right wall → drops visual half-rank 1/2 with no logical board change → sweeps left → drops visual half-rank 2/2 and updates every black piece's logical rank by one → repeat. Game over trigger: any black piece reaches rank 1 after a full-rank logical descent. Descent rate is fixed across all levels; only lateral speed scales with level and remaining piece count.

---

### 25.4 Check Behavior

**Decision:** Timer extends to **8 seconds** when white is in check. The arcade action (invader shots, raider ships) continues unpaused. A red "CHECK" warning pulses in the HUD and the white king's sprite glows red.

**Rule:** Check detected → white's next turn timer becomes 8s. If the player fails to act, the auto-move engine fires but is constrained to moves that resolve check only. If no legal resolving move exists → checkmate → game over.

**Multi-move interaction:** When Black makes multiple chess moves per turn (Level 3+), check state is evaluated **once, after all Black moves have completed**. If White is in check at the start of White's turn, the 8s extension applies. An intermediate check mid-sequence that resolves by the final Black move does not trigger the extension — only the final board state matters.

---

### 25.5 Black Multi-Move Selection

**Decision:** Black multi-move turns should be simple, legal, and readable rather than perfectly optimal. From Level 3 onward, when Black gets 2 or 3 chess moves in the scheduled black-move phase, those moves must use **distinct source pieces** and **distinct destination squares**.

**Rule:** Generate candidate Black legal moves from the current board, score them with the normal material/aggression evaluation, then choose greedily:

1. Sort legal candidate moves from best to worst.
2. Select the best move whose source piece has not already been selected this turn and whose destination square has not already been claimed this turn.
3. Temporarily reserve that source piece and destination square.
4. Continue until the level's Black move count is reached, or until no legal non-conflicting candidate remains.

If fewer than the target number of non-conflicting legal moves exist, Black simply makes fewer moves that turn. Do not force a bad or illegal move just to hit the count.

**No same-piece repeats:** A piece that has already been selected for a multi-move turn cannot move again in that same black-move phase.

**No shared destinations:** Two Black pieces cannot move to the same destination square in the same black-move phase.

**Good-enough AI:** The selected set does not need to be globally optimal as a combined tactical sequence. It only needs to pass the normal legal-move filter, avoid obvious losing moves according to the existing evaluation, and satisfy the distinct-piece / distinct-destination constraints. This keeps the implementation stable and the on-screen action understandable.

---

### 25.6 Pawn Promotion — Power-Up Event

**Decision:** Promotion is a **dramatic power-up moment**, not just a piece swap.

**Rule:** White pawn reaches rank 8 →

1. Pawn instantly becomes a Queen (full 12 HP, Queen sprite with flash animation + ascending arpeggio).
2. The nearest black piece on screen is **destroyed automatically** — a targeting beam locks onto it and it explodes, no shot required. Points awarded at the **laser-shot rate** (not chess-capture rate) — e.g. 25 pts for a Pawn, 50 for a Knight or Bishop, 75 for a Rook, 150 for a Queen, 500 for the King. **Special case:** if the nearest piece is the Black King, the targeting beam counts as a King shot — the level ends immediately with Victory, and the +500 King shot bonus is awarded.
3. The player's spaceship laser cap increases by 1 for the remainder of the level. A "MULTI-SHOT ACTIVATED" banner briefly sweeps across the bottom of the screen showing the new cap.

**Multi-shot stacks with each promotion:**

| Promotions this level | Laser cap |
|---|---|
| 0 | 2 (default) |
| 1 | 3 |
| 2 | 4 |
| 3 | 5 |
| 4+ | 6 (hard cap — beyond this the screen becomes unmanageable) |

The cap resets to 2 at the start of each new level. Engineering multiple promotions in one level is a legitimate high-skill strategy — the reward is a significantly faster firing rate that can tear through the fleet. White has 8 pawns, so the theoretical maximum of 6 is achievable but requires reaching rank 8 with 4 pawns under fire.

*Black pawns reaching rank 1 auto-promote to Queen with no power-up effects — they simply add a second enemy Queen to the fleet.*

---

### 25.7 Friendly Fire

**Decision:** Always allowed, no warning, no prompt.

**Rule:** Player laser hits a white piece → piece loses 2 HP. If HP reaches 0 the piece is destroyed — no points awarded. A distinct low/mournful explosion sound plays to confirm it was your own piece. This is a deliberate tactical option for clearing firing lanes.

---

### 25.8 Black King Movement

**Decision:** The black King **moves with the fleet** left and right, exactly like all other black pieces. It is not special-cased. This makes it a moving target and harder to snipe — but it still scores 500 pts if shot.

**Rule:** Black King is a full member of the fleet parent node and participates in all lateral sweeps. It moves to a new chess square when the engine selects a king move (rare). The King is the highest-HP piece (16 HP) so shooting it down requires sustained fire or a clear lane — it won't die from a stray shot.

---

### 25.9 Spaceship Firing Rate

**Decision:** Up to **2 simultaneous lasers** on screen under normal conditions. Each white pawn promotion increases the cap by 1 (stacking), up to a hard cap of 6. Resets to 2 each level. See §25.6 for the full stacking table.

**Rule:** `Spaceship.activeLaserCount` tracks in-flight shots. Normal cap: 2. Post-promotion cap: 3. Each laser that exits the screen or hits a target decrements the count, freeing a slot. On macOS, pressing Space while at the cap does nothing; the next Space press after a slot opens fires normally. Future touch controls may choose to queue or dim fire input separately.

---

*End of resolved decisions — v0.2*

---

## 26. Automated Testing Strategy

The existing phase-by-phase testing notes in §20 cover manual verification — running the game and confirming behavior visually. This section defines the **automated test suite** that runs without a human: unit tests, integration tests, and performance benchmarks that can be executed via `xcodebuild test` in CI and before every significant merge.

The guiding principle matches the development phase order: **prove chess logic correct before adding animation; prove collision rules correct before adding physics.** A bug in `MoveGenerator.swift` discovered in Phase 1 is a one-hour fix. The same bug found in Phase 6 after SpriteKit rendering, fleet movement, and collision handling are all built on top of it is a day of archaeology.

---

### 26.1 Test Organization

```
GalacticChessInvaders/
└── Tests/
    ├── ChessLogicTests.swift        ← Phase 1 — legal moves, check, checkmate, HP
    ├── BoardStateTests.swift        ← Phase 1 — forcePlace, crush events, board integrity
    ├── ScoringTests.swift           ← Phase 1 — score math, multipliers, persistence
    ├── GameRulesTests.swift         ← Phase 2 — turn timer, auto-move, state transitions
    ├── CollisionRulesTests.swift    ← Phase 3 — damage resolution (not SpriteKit physics)
    ├── LevelProgressionTests.swift  ← Phase 7 — level parameters, escalation, multi-move
    └── PerformanceTests.swift       ← Phases 1+ — engine speed, pool allocation
```
All test targets import via `@testable import GalacticChessInvaders` — no symbols need to be made `public` just to test them.

---

### 26.2 Phase 1 — Chess Logic Tests (Highest Priority)

**Write these before any rendering code exists.** The chess logic layer is pure Swift with no SpriteKit imports — it compiles and runs in a test target with zero UI dependencies. All tests here should pass before Phase 2.1 begins.

#### Move Generation

Use FEN strings (Forsyth-Edwards Notation) to set up specific board positions. FEN encodes a complete board state as a single string — ChessKit accepts them directly.

```swift
// Every piece moves legally from a known position
func testKnightMovesFromCentre() {
    let board = GCIBoard(fen: "8/8/8/8/4N3/8/8/8 w - - 0 1")
    let moves = MoveGenerator.legalMoves(for: .knight, color: .white, at: "e4", on: board)
    XCTAssertEqual(moves.count, 8)  // knight in centre has 8 squares
}

func testPawnBlockedByOwnPiece() {
    let board = GCIBoard(fen: "8/8/8/8/4P3/4P3/8/8 w - - 0 1")
    let moves = MoveGenerator.legalMoves(for: .pawn, color: .white, at: "e3", on: board)
    XCTAssertTrue(moves.isEmpty)  // blocked by own pawn on e4
}

func testPinnedPieceCannotMove() {
    // White bishop on d3 pinned by black rook on d8 — cannot move off the d-file
    let board = GCIBoard(fen: "3r4/8/8/8/8/3B4/8/3K4 w - - 0 1")
    let moves = MoveGenerator.legalMoves(for: .bishop, color: .white, at: "d3", on: board)
    XCTAssertTrue(moves.isEmpty)
}
```
#### Check and Checkmate

```swift
func testCheckDetected() {
    // Black rook on e8 puts white king on e1 in check
    let board = GCIBoard(fen: "4r3/8/8/8/8/8/8/4K3 w - - 0 1")
    XCTAssertTrue(board.isInCheck(color: .white))
}

func testFoolsMate() {
    // Fool's mate — fastest checkmate in chess (2 moves for Black)
    let board = GCIBoard(fen: "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")
    XCTAssertTrue(board.isCheckmate(color: .white))
    XCTAssertEqual(MoveGenerator.legalMoves(color: .white, on: board).count, 0)
}

func testScholarsMate() {
    let board = GCIBoard(fen: "r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4")
    XCTAssertTrue(board.isCheckmate(color: .black))
}

func testStalemate_noGameOver() {
    // Stalemate: white has no legal moves but is not in check — GCI continues (§23.1)
    let board = GCIBoard(fen: "k7/8/1Q6/8/8/8/8/K7 b - - 0 1")
    XCTAssertFalse(board.isCheckmate(color: .black))
    XCTAssertFalse(board.isInCheck(color: .black))
    // GCI rule: game does not end on stalemate
}
```
#### HP and Damage System

```swift
func testPawnDiesInOneHit() {
    var piece = Piece(type: .pawn, color: .black)
    XCTAssertEqual(piece.hp, 2)
    piece.applyDamage(2)
    XCTAssertEqual(piece.hp, 0)
    XCTAssertTrue(piece.isDestroyed)
}

func testQueenReachesCriticalState() {
    var piece = Piece(type: .queen, color: .black)
    piece.applyDamage(9)
    XCTAssertEqual(piece.damageState, .critical)
    XCTAssertFalse(piece.isDestroyed)
}

func testDamageStates_allPieceTypes() {
    // Verify chipped/cracked/critical thresholds for every piece
    let cases: [(PieceType, Int, DamageState)] = [
        (.pawn,   1, .chipped),
        (.knight, 2, .chipped), (.knight, 4, .cracked), (.knight, 5, .critical),
        (.rook,   4, .cracked), (.rook,   6, .critical),
        (.queen,  6, .cracked), (.queen,  9, .critical),
        (.king,   8, .cracked), (.king,  12, .critical),
    ]
    for (type, damage, expectedState) in cases {
        var piece = Piece(type: type, color: .black)
        piece.applyDamage(damage)
        XCTAssertEqual(piece.damageState, expectedState,
            "\(type) after \(damage) damage should be \(expectedState)")
    }
}
```
#### Force-Place and Board Integrity

```swift
func testForcePlaceBypassesLegality() {
    var board = GCIBoard()
    board.forcePlace(.pawn, color: .black, at: "e3")  // illegal under chess rules
    XCTAssertNotNil(board.piece(at: "e3"))
    XCTAssertEqual(board.piece(at: "e3")?.type, .pawn)
}

func testCrushEvent_whitePieceRemoved() {
    var board = GCIBoard()
    board.place(.pawn, color: .white, at: "e4")
    board.forcePlace(.pawn, color: .black, at: "e4")  // black descends onto white
    // White pawn should be gone; black pawn should be present
    XCTAssertEqual(board.piece(at: "e4")?.color, .black)
    XCTAssertEqual(board.whitePieceCount, 15)
}
```
---

### 26.3 Phase 1 — Scoring Tests

```swift
func testBasePawnScore() {
    let score = ScoreManager()
    score.addPoints(for: .shootPawn, level: 1)
    XCTAssertEqual(score.total, 25)
}

func testMultiplierScaling() {
    let score = ScoreManager()
    score.addPoints(for: .shootPawn, level: 3)  // 2.0× multiplier (1.0 + 0.5×2)
    XCTAssertEqual(score.total, 50)             // 25 × 2.0
}

func testCheckmateAndShotKing_bothBonuses() {
    // King shot while in checkmate: 500 (shot) + 300 (checkmate) = 800
    let score = ScoreManager()
    score.addPoints(for: .shootKing, level: 1)
    score.addPoints(for: .checkmateBonus, level: 1)
    XCTAssertEqual(score.total, 800)
}

func testHighScorePersistence() {
    let mgr = ScoreManager()
    mgr.submit(score: 9999, level: 3, initials: "ZAC")
    let loaded = ScoreManager()  // fresh instance reads UserDefaults
    XCTAssertEqual(loaded.topScores().first?.score, 9999)
}
```
---

### 26.4 Phase 2 — Game Rules Tests

These test the state machine and turn logic without any SpriteKit. Extract turn-rule logic into a `GameRules` pure-Swift type that `GameScene` delegates to.

```swift
func testTimerExpiryTriggersAutoMove() {
    let rules = GameRules(board: GCIBoard.startingPosition())
    rules.simulateTimerExpiry()
    XCTAssertEqual(rules.lastMoveSource, .auto)
    XCTAssertTrue(rules.lastMove?.isLegal == true)
}

func testCheckExtendsTimer() {
    var rules = GameRules(board: GCIBoard(fen: "4r3/8/8/8/8/8/8/4K3 w - - 0 1"))
    XCTAssertEqual(rules.currentTimerDuration, 8.0)  // check → 8s not 5s
}

func testAutoMove_withPieceSelected_movesSelectedPiece() {
    var rules = GameRules(board: GCIBoard.startingPosition())
    rules.selectPiece(at: "e2")
    rules.simulateTimerExpiry()
    // Engine must move the e2 pawn, not any other piece
    XCTAssertEqual(rules.lastMove?.from, "e2")
}

func testFleetSweepDoesNotTriggerBlackMove() {
    var rules = GameRules(board: GCIBoard.startingPosition())
    rules.playerMove("e2", "e4")
    rules.simulateFleetSweepCompletion()
    XCTAssertEqual(rules.blackMovesThisBeat, 0)

    rules.advanceToBlackMovePhase()
    XCTAssertEqual(rules.blackMovesThisBeat, 1)
}

func testLevelAdvancesOnAllBlackPiecesDestroyed() {
    var state = GameState(level: 1)
    state.destroyAllBlackPieces()
    XCTAssertEqual(state.phase, .levelClear)
}
```
---

### 26.5 Phase 3 — Collision Resolution Tests

Test the **rules** of what happens when a collision fires, not the SpriteKit physics that detects it. Extract `CollisionResolver.resolve(laser:hitting:)` as a pure function.

```swift
func testPlayerLaserDamagesPawn_2HP() {
    let result = CollisionResolver.resolve(
        laser: .playerLaser,
        hitting: Piece(type: .pawn, color: .black, hp: 2)
    )
    XCTAssertEqual(result.damageDone, 2)
    XCTAssertTrue(result.pieceDestroyed)
    XCTAssertEqual(result.scoreAwarded, 25)
}

func testFriendlyFire_dealsTwoHP() {
    let result = CollisionResolver.resolve(
        laser: .playerLaser,
        hitting: Piece(type: .knight, color: .white, hp: 6)
    )
    XCTAssertEqual(result.damageDone, 2)
    XCTAssertFalse(result.pieceDestroyed)
    XCTAssertEqual(result.scoreAwarded, 0)  // no points for friendly fire
}

func testEnemyShot_dealsOneHP() {
    let result = CollisionResolver.resolve(
        laser: .invaderShot,
        hitting: Piece(type: .rook, color: .white, hp: 8)
    )
    XCTAssertEqual(result.damageDone, 1)
    XCTAssertFalse(result.pieceDestroyed)
}

func testShipHit_loadsLife() {
    var ship = SpaceshipState(lives: 3)
    ship.applyHit()
    XCTAssertEqual(ship.lives, 2)
    XCTAssertTrue(ship.isInvincible)  // 2s grace period
}

func testShipInvincible_noLifeLost() {
    var ship = SpaceshipState(lives: 2)
    ship.beginInvincibility()
    ship.applyHit()
    XCTAssertEqual(ship.lives, 2)  // hit ignored during grace period
}
```
---

### 26.6 Phase 7 — Level Escalation Tests

```swift
func testLevel3_twoBlackMovesPerTurn() {
    let params = LevelParameters(level: 3)
    XCTAssertEqual(params.blackMovesPerTurn, 2)
}

func testLevel5_threeBlackMovesPerTurn() {
    XCTAssertEqual(LevelParameters(level: 5).blackMovesPerTurn, 3)
}

func testMultiMoveEngine_returnsOnlyLegalMoves() {
    let board = GCIBoard.startingPosition()
    let moves = ChessEngine.multiMove(count: 2, for: .black, on: board)
    XCTAssertEqual(moves.count, 2)
    XCTAssertTrue(moves.allSatisfy { board.isLegal($0) })
}

func testMultiMoveEngine_usesDistinctPiecesAndDestinations() {
    let board = GCIBoard.startingPosition()
    let moves = ChessEngine.multiMove(count: 3, for: .black, on: board)
    XCTAssertEqual(Set(moves.map(\.from)).count, moves.count)
    XCTAssertEqual(Set(moves.map(\.to)).count, moves.count)
}

func testMultiMoveEngine_allowsFewerMovesWhenNonConflictingMovesRunOut() {
    let board = GCIBoard(fen: "8/8/8/8/8/8/7p/6Kk b - - 0 1")
    let moves = ChessEngine.multiMove(count: 3, for: .black, on: board)
    XCTAssertLessThanOrEqual(moves.count, 3)
    XCTAssertTrue(moves.allSatisfy { board.isLegal($0) })
    XCTAssertEqual(Set(moves.map(\.from)).count, moves.count)
    XCTAssertEqual(Set(moves.map(\.to)).count, moves.count)
}

func testPawnPromotion_laserCapIncreases() {
    var state = GameState(level: 1)
    XCTAssertEqual(state.laserCap, 2)
    state.applyPromotion()
    XCTAssertEqual(state.laserCap, 3)
    state.applyPromotion()
    XCTAssertEqual(state.laserCap, 4)
}

func testPawnPromotion_hardCapAt6() {
    var state = GameState(level: 1)
    for _ in 0..<10 { state.applyPromotion() }
    XCTAssertEqual(state.laserCap, 6)
}

func testLaserCap_resetsOnNewLevel() {
    var state = GameState(level: 2)
    state.applyPromotion(); state.applyPromotion()
    state.advanceLevel()
    XCTAssertEqual(state.laserCap, 2)
}
```
---

### 26.7 Performance Tests

These run continuously and catch regressions before they reach players.

```swift
func testMoveGenerationPerformance() {
    let board = GCIBoard.startingPosition()
    measure {
        for _ in 0..<1000 {
            _ = MoveGenerator.legalMoves(color: .white, on: board)
        }
    }
    // XCTest flags any run more than 10% slower than established baseline
}

func testEngineEvaluationUnder50ms() {
    let board = GCIBoard.startingPosition()
    let start = Date()
    _ = ChessEngine.bestMove(for: .black, on: board, depth: 2)
    XCTAssertLessThan(Date().timeIntervalSince(start), 0.05)
}

func testLaserPoolZeroAllocationDuringPlay() {
    let pool = LaserPool(capacity: 6)
    // Acquire and release 1000 times — should never allocate
    let baseline = pool.allocationCount
    for _ in 0..<1000 {
        let node = pool.acquire()
        pool.release(node)
    }
    XCTAssertEqual(pool.allocationCount, baseline)
}
```
---

### 26.8 What Not to Test

| Do not test | Why |
|---|---|
| `SKNode` positions, sizes, or visual states | Fragile, tests the framework not your code |
| `SKAction` animation timing | Framework responsibility |
| `GKMinmaxStrategist` move quality | You don't own the algorithm — just verify it returns a legal move |
| `AVFoundation` audio playback | Mock at the boundary; do not test Apple's audio engine |
| SpriteKit physics body contacts | Test the collision resolution *handler*, not the physics detection |
| Fleet pixel positions during sweep | Test logical square updates on descent, not screen coordinates |

---

### 26.9 AI-Assisted Test Generation

Each section of this design document is detailed enough to drive automated test generation. Workflow:

1. Copy a specific rule section (e.g. §7.1 Piece Hit Points, §9 Scoring) into a Claude prompt
2. Ask: *"Generate XCTest methods covering every case in this table, including boundary conditions and edge cases"*
3. Review generated tests for correctness — AI knows chess edge cases (pins, discovered check, promotion under check) that are easy to miss manually
4. Commit tests alongside the implementation they cover

**Regression workflow:** every bug found during playtesting gets a minimal failing XCTest before the fix is written. The fix makes the test pass. The test is committed. That bug cannot regress silently.

**Mutation testing with Muter:** periodically run [Muter](https://github.com/muter-mutation-testing/muter) against `Game/Logic/` — it introduces deliberate bugs (swaps `>=` to `>`, flips a boolean) and verifies your tests catch them. A mutation score below 80% means your test suite has blind spots in the logic layer.

---

### 26.10 Test Phase Gate Summary

| Gate | Tests must pass | Before starting |
|---|---|---|
| **Gate 1** | All `ChessLogicTests`, `BoardStateTests`, `ScoringTests`, all performance benchmarks | Phase 2.1 (wire chess to scene) |
| **Gate 2** | All `GameRulesTests` (turn timer, auto-move, state transitions) | Phase 3.1 (fleet movement) |
| **Gate 3** | All `CollisionRulesTests` | Phase 3.3 (damage states and juice) |
| **Gate 4** | All `LevelProgressionTests` | Phase 8 (visual polish) |
| **Gate 5** | Full suite green, all performance benchmarks pass | Phase 9 (App Store submission) |

The rule: **no phase begins until the previous gate is green.** This is not bureaucracy — it is the difference between finding a `forcePlace` bug in isolation versus finding it after six phases of arcade systems are built on top of it.

---

## Appendix A — iOS and iPadOS Portability

**Not scheduled.** The port is wanted eventually, not now. This appendix is kept

so the decision stays available: the architecture rules below have been followed

throughout the macOS build — logic layers import no SpriteKit or AppKit, and all

input arrives as a platform-agnostic `GameAction` — so the option is still open

and costs nothing to keep open.

Recovered from the superseded v1.0 design document, which was deleted once the

live document diverged from it. Section numbers have been rewritten; the content

is unchanged, and it predates the Special Scout power-up system in §13, the

ten-level ladder as built, and everything in `docs/implementation.md`.

### A.1 Port Considerations

- Replace keyboard controls with on-screen D-pad (move ship) + tap-to-fire button.
- Chess piece selection via tap-then-tap (tap piece, then tap destination).
- `UIAdaptivePresentationController` for split-screen iPad support.
- Use `UIRequiresFullScreen = false` in Info.plist to allow iPad multitasking.
- SpriteKit scenes scale cleanly to any screen size using `.aspectFill` + safe-area insets.

---

### A.2 Architecture

How the macOS codebase must be structured so that a port is a matter of adding

a platform layer rather than rewriting the game. Written when the port was

planned for Phase 2; the constraints have been followed regardless, and

`CLAUDE.md` states them as live architecture rules.

---

#### A.2.1 Core Principle: Separate Logic from Platform

Every system in the game belongs to one of three layers:

```
┌─────────────────────────────────────────┐
│           GAME LOGIC LAYER              │  ← Pure Swift. No UIKit, no AppKit,
│  Chess engine, board model, scoring,    │     no SpriteKit. Runs identically
│  level manager, fleet AI, collision     │     on macOS and iOS.
│  rules, HP system, turn timer           │
├─────────────────────────────────────────┤
│         RENDERING / SCENE LAYER         │  ← SpriteKit (shared macOS + iOS).
│  GameScene, PieceNode, HUDNode,         │     SKScene works on both platforms
│  particle effects, audio nodes          │     with zero changes.
├─────────────────────────────────────────┤
│        PLATFORM INPUT LAYER             │  ← Separate per platform.
│  macOS: keyboard + mouse handlers       │     Swapped out at compile time
│  iOS: touch, virtual joystick, buttons  │     using #if os(iOS) / os(macOS)
└─────────────────────────────────────────┘
```

**Rule:** The game logic layer must never import `AppKit`, `UIKit`, `SpriteKit`, or reference screen coordinates. It communicates with the scene layer through a clean protocol interface only.

---

#### A.2.2 Input Abstraction

The game must never respond directly to keyboard events or mouse clicks in the game logic. Instead, all input is translated into **abstract game actions** before being passed to the logic layer:

```swift
enum GameAction {
    case moveShipLeft
    case moveShipRight
    case fireShipLaser
    case selectPiece(position: BoardPosition)
    case movePiece(to: BoardPosition)
    case deselectPiece
    case pause
}
```

- On **macOS**: keyboard and mouse events are translated into `GameAction` values by a `MacInputHandler`.
- On **iOS**: touch events, virtual joystick deltas, and button taps are translated into `GameAction` values by a `TouchInputHandler`.
- The game logic layer receives only `GameAction` — it has no idea whether the source was a key press or a finger tap.

This means adding iOS controls in Phase 2 requires writing `TouchInputHandler` only — nothing in the game logic changes.

---

#### A.2.3 macOS Window Behavior

The game runs in a **standard resizable macOS window** — it does not take over the screen on launch. The user can optionally go full screen via the green traffic-light button or `⌃⌘F` as with any Mac app, but this is never forced.

**Default window size:** 900×700 points — large enough to see all pieces clearly, small enough to sit comfortably on a 13" laptop screen without dominating the desktop.

**Minimum window size:** 640×500 points — below this pieces become too small to click reliably.

**Resizing behavior:** the SpriteKit scene uses `scaleMode = .aspectFit` on macOS so the playfield scales cleanly inside any window size, with black letterbox bars if the window proportions differ from the scene's native ratio. The game never stretches or crops.

The app should **not** set `NSWindowStyleMask.fullSizeContentView` or hide the title bar — the standard macOS chrome (title bar, traffic lights, menu bar) remains visible at all times in windowed mode.

---

#### A.2.4 SpriteKit — Already Cross-Platform

SpriteKit runs on macOS, iOS, and iPadOS with the same API. The `GameScene`, all `SKSpriteNode` subclasses, `SKAction` animations, particle emitters, and `SKAudioNode` audio all work without modification. This is the main reason SpriteKit was chosen over a Mac-only framework.

The one exception: `SKView` is embedded differently on macOS (`NSView`) vs iOS (`UIView`). This is handled by a thin wrapper in `ContentView.swift` using `#if os(iOS)`.

---

#### A.2.4 Screen Size & Layout

The game must never use hardcoded pixel coordinates. All positions must be calculated relative to the scene size at runtime.

```swift
// Wrong — hardcoded
shipNode.position = CGPoint(x: 512, y: 40)

// Right — relative
shipNode.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.05)
```

**Key layout rules:**

- The playfield scales to fill the available screen using `SKScene.scaleMode = .aspectFill`
- The spaceship strip height is defined as a **percentage of scene height** (5%), not a fixed pixel value
- Piece sprite sizes (16–28px) are defined as a fraction of the square size, which is derived from scene width at runtime
- HUD elements anchor to screen edges using `SKNode` anchor points — top-left for score, top-right for lives
- Safe area insets are respected on iPhone (notch, home indicator) using `UIWindow.safeAreaInsets` on iOS

---

#### A.2.5 Audio

`AVFoundation` and `SKAudioNode` both work identically on macOS and iOS. No changes needed for audio in the port.

One consideration: iOS may interrupt audio for phone calls, Siri, etc. The game should observe `AVAudioSession` interruption notifications on iOS and auto-pause when audio is interrupted. On macOS this is not needed.

```swift
// iOS only — add to AppDelegate or scene setup
#if os(iOS)
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification, ...)
#endif
```

---

#### A.2.6 Asset Scaling — @1x / @2x / @3x

All sprite assets must be provided in three resolutions in `Assets.xcassets`:

- `@1x` — standard (older non-Retina, rarely used)
- `@2x` — Retina Mac, older iPhones
- `@3x` — iPhone Pro models, new iPads

The pixel-art aesthetic requires special handling: sprites must use **nearest-neighbour scaling** (no bilinear interpolation) or they will look blurry. Set this on the `SKTexture`:

```swift
texture.filteringMode = .nearest
```

This must be set on every piece sprite, projectile, and UI element. It is the single most important visual detail for the pixel-art look on Retina screens.

---

#### A.2.7 iOS-Specific UI Elements to Build in Phase 2

These do not exist on macOS and must be added for iOS:

| Element | Description |
|---|---|
| Virtual joystick | Left thumb zone — two arrow buttons or an analog stick for ship movement |
| Fire button | Large tap target, bottom-right, glows when laser is available |
| Pause button | Top-right corner, small, always accessible |
| Chess piece tap handling | Tap to select, tap reticle to move — replaces mouse click |
| Larger touch targets | Piece sprites may need slightly larger tap areas than their visual size on iPhone |
| Landscape-only lock | Game is landscape only on iPhone. Set `UISupportedInterfaceOrientations` to landscape in Info.plist |
| iPad layout | More screen real estate — HUD can be richer, pieces can be larger |

---

#### A.2.8 Persistence

`UserDefaults` works identically on macOS and iOS — no changes needed for high score storage.

For Phase 2 Game Center integration, the `ScoreManager` class should be designed with a protocol so the local `UserDefaults` implementation can be swapped for a `GameCenterScoreManager` without touching any other code:

```swift
protocol ScoreStorage {
    func submitScore(_ score: Int, level: Int, initials: String)
    func topScores() -> [ScoreEntry]
}

// v1.0
class LocalScoreManager: ScoreStorage { ... }

// Phase 2
class GameCenterScoreManager: ScoreStorage { ... }
```

---

#### A.2.9 Shared Codebase Structure

The project should use a **single Xcode target with conditional compilation** rather than two separate targets. Most files are shared; platform differences are handled inline with `#if os(iOS)`:

```
GalacticChessInvaders.xcodeproj
├── Targets:
│   ├── GCI-macOS        (macOS deployment target)
│   └── GCI-iOS          (iOS deployment target — Phase 2)
├── Shared/              ← Everything in here compiles for both
│   ├── Game/
│   ├── Chess/
│   ├── Arcade/
│   ├── Nodes/
│   └── Scores/
├── macOS/               ← macOS-only files
│   ├── MacInputHandler.swift
│   └── AppDelegate.swift
└── iOS/                 ← iOS-only files (Phase 2)
    ├── TouchInputHandler.swift
    ├── VirtualJoystick.swift
    └── AppDelegate.swift
```

This structure means the Phase 2 iOS port is primarily:

1. Write `TouchInputHandler.swift`
2. Write `VirtualJoystick.swift` and on-screen buttons
3. Test layout on iPhone and iPad screen sizes
4. Handle audio session interruptions
5. Submit to App Store

The game logic, chess engine, rendering, audio, and scoring require no changes.

---

### A.3 Touch Controls

| Action | Input |
|---|---|
| Move ship | Left virtual joystick (bottom-left zone) |
| Fire laser | Fire button (bottom-right zone) |
| Select + move chess piece | Tap piece, then tap destination reticle |
| Deselect piece | Tap empty space |
| Pause | Pause button (top-right corner) |

The left half of the screen drives the ship; the right half (and upper area) handles chess. The split is natural for two-thumb play on iPhone and iPad.

### A.4 Phased Plan

The original document scheduled these as Phases 10 and 11, after the macOS game

was complete. They are recorded here as a starting point, not a commitment.

#### iPad

**Goal:** Ship on iPad using the shared codebase. iPad first because its larger screen is closer to the Mac layout — lower risk than iPhone.

**Build:**

- New iOS target in Xcode project (shared `Shared/` folder unchanged)
- `TouchInputHandler.swift` — translates touch → `GameAction`
- `VirtualJoystick.swift` — left-thumb zone for ship movement
- On-screen fire button — large tap target, bottom-right
- Pause button — top-right corner
- iPad layout pass — pieces can be larger, HUD richer, more screen real estate
- Landscape-only lock (`UISupportedInterfaceOrientations`)
- Safe area insets handling
- Audio session interruption handling (phone calls, Siri)
- `scaleMode = .aspectFill` on iPad (fills the screen more fully than Mac's `.aspectFit`)

**Testing:**

- All Phase 1 chess logic unit tests pass unchanged
- Virtual joystick moves ship smoothly, fire button responsive
- Tap to select piece, tap reticle to move — works reliably on iPad Pro and iPad mini
- No misfire when tapping near piece vs. empty space
- Landscape lock — refuses portrait rotation
- Audio interruption — game pauses, resumes correctly after call ends
- 60 fps on iPad (8th gen) or newer
- Level 1–3 full playthrough on iPad — no control frustrations
- **Pass criteria:** complete playthrough on iPad Pro and iPad mini with no input errors

---

#### iPhone

**Goal:** Ship on iPhone. Smaller screen and narrower aspect ratio require the most layout work.

**Build:**

- iPhone layout pass — smaller piece sprites, compact HUD, tighter touch zones
- Larger touch targets for piece selection (pieces are smaller but tap area is padded)
- Virtual joystick and fire button scaled for one-thumb reach
- HUD condensed — score and lives on same line to save vertical space
- Test on smallest supported screen (iPhone SE 3rd gen, 4.7")
- App Store metadata for iPhone

**Testing:**

- All touch controls work on iPhone SE (smallest screen)
- Piece tap targets — no misfires at minimum sprite size
- HUD legible at iPhone screen size — score, timer, lives all readable
- No UI elements clipped by notch or home indicator safe areas
- 60 fps on iPhone 12 or newer
- Level 1–3 full playthrough on iPhone 15 and iPhone SE
- Chess piece selection under fire — tap accuracy acceptable given arcade pace
- **Pass criteria:** complete playthrough on both iPhone SE and iPhone 15 Pro with no missed taps on piece selection

---

| Feature | Phase | Notes |
|---|---|---|
| Game Center leaderboards | 2 | Online high scores by level; replaces local-only table |
| iCloud sync | 2 | High scores and settings across Mac and iPhone |
| Additional power-ups | 2 | Repair Drone, Smart Bomb, Speed Boost (designed in §13, not built in v1.0) |
| Chess960 mode | 2 | Randomized starting positions — changes fleet formation shape each game |
| Multiplayer (local) | 3 | Two players: one flies the ship, one makes chess moves |
| Deeper engine option | 3 | Optional 3-4 ply for "hard" difficulty setting |
| Piece skins / themes | 3 | Unlock alternate neon color schemes via score milestones |
| Replay system | 3 | Record and play back last game |
| Soundtrack volume reactivity | 2 | Full dynamic music system tied to game state (designed in §12, basic version in v1.0) |

---
