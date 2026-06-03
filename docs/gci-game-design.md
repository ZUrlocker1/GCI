# Galactic Chess Invaders — Game Design Document
**Version 1.0**
*Target: macOS (Swift/SpriteKit), later iOS/iPadOS*
*"40 years in the making!"*

---

> ⚠️ **Naming:** In this document the word *Recharged* is occasionally used as a shorthand for the visual and audio aesthetic (neon glow, dark backgrounds, modern electronic music) inspired by the Atari Recharged game series. **"Recharged" is likely a trademark of Atari** and will not appear in the final product name. An alternative might be used such as: **Remastered, Evolved, Overdrive, Refueled, Supercharged, Reloaded, Reboot, Resurgence or Unleashed.** 

---

## Origin & History

Galactic Chess Invaders was first conceived and prototyped during **spring break 1983** by Zack Urlocker, then an undergraduate student, on an **Apple II**. The demo was written in Applesoft BASIC and compiled with **TASC — The Applesoft Compiler** for performance. Graphics were rendered using the **HRCG (High Res Character Generator)** with a dedicated chess font to animate the pieces in high-resolution mode. Startup music was produced through a simple Apple II synth routine; shot and hit sound effects were programmed directly in BASIC using the built-in speaker.

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

## 1. Concept

Galactic Chess Invaders (GCI) is an arcade-chess hybrid. A standard chess game plays out on-screen, but the black pieces also behave like Space Invaders: they slide left and right as a fleet, periodically descend, and fire projectiles at the player's pieces and spaceship. The player controls white's chess moves *and* a horizontally-moving spaceship at the bottom of the screen that can shoot up at any target — enemy pieces, invader projectiles, or even the player's own damaged white pieces.

The chess game is real but fast and shallow. Arcade reflex, not deep strategy, determines whether you survive.

---

## 2. Core Loop

```
[Timer counts down 5s]
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
│  [▼ 4s]   [──── SPACESHIP ────►]      │  ← Spaceship + timer strip
└───────────────────────────────────────┘
```

- The 8×8 chess board fills the center of the screen.
- Each square is large enough to render a piece sprite at its largest damage-frame size (28×28 px for the King).
- No column or row labels are shown on screen. Algebraic notation (a–h, 1–8) is used internally and in debug builds only.

### 3.2 Coordinate System

Standard algebraic notation internally. Rendering maps rank/file to screen pixels. The spaceship travels in a strip below rank 1.

---

## 4. Chess Rules & Modifications

### 4.1 Standard Chess — What Stays

- All standard piece moves (including promotion).
- Captures remove the captured piece.
- Check and checkmate are recognized.
- Castling and en passant are **not implemented** — kept simple for arcade pace.

### 4.2 What Changes

| Rule | Standard Chess | GCI |
|---|---|---|
| Turn time | Unlimited | 5 seconds; auto-move on expiry |
| Piece HP | N/A | Each piece has hit points; damage shown by outline erosion |
| Destroyed pieces | Only by capture | Also by shooting or HP reaching 0 |
| King loss | Illegal (checkmate ends game) | Shooting the king ends the chess game early |
| Promotion | Pawn reaches rank 8 | Still valid; promotes under fire |

### 4.3 Auto-Move on Timer Expiry

When the 5-second timer expires without a player move, the chess engine picks white's move (same 1-2 ply engine that drives black). A brief "AUTO" flash appears over the piece that moved. This keeps the game flowing and prevents the player from stalling to focus on shooting.

### 4.4 Chess Engine

- **Depth:** 1-2 ply minimax (fast, ~milliseconds).
- **Evaluation:** Material count only. No positional tables.
- **Personality:** Slightly biased to keep pieces alive (avoids trading into losing positions by more than ~1 pawn). Will not sacrifice pieces tactically.
- **Black also uses this engine** to choose its chess moves each turn — but black's movement on-screen follows the Invader pattern, not just chess rules (see §5).

**Aggressive mode (Level 2+):** From Level 2 onward the engine is weighted to prefer attacking moves. Specifically: captures are scored higher than positional moves, pawns are actively advanced, and the engine prefers moves that put white in check or threaten multiple pieces simultaneously. This is implemented as a score modifier in `GCIBoard.score(for:)` passed to `GKMinmaxStrategist`. The aggressive weighting increases each level (see §18.1).

---

## 5. The Invader Fleet — Black Pieces

### 5.1 Formation Movement

Black pieces maintain their starting chess positions *relative to each other* as they shift laterally, exactly like Space Invaders:

1. Shift right N pixels per frame until the rightmost piece reaches the right wall.
2. Drop down one half-rank.
3. Shift left until the leftmost piece hits the left wall.
4. Drop down one half-rank.
5. Repeat.

The fleet's lateral speed increases as pieces are eliminated (classic Invaders behavior).

### 5.2 Chess Moves vs. Fleet Movement

Black's chess move happens **after** the fleet completes a lateral sweep. The engine picks the best legal chess move; the selected piece slides to its new square with a brief animation. This ordering gives the player a moment to react to the fleet's new position before a chess threat materialises on top of it — fleet moves, then one piece makes a deliberate chess advance. The gap between sweep completion and the chess move may be padded at lower levels to avoid the game feeling overwhelming; at Level 1 black should not feel too reactive (see §18.1 for per-level timing).

*Design note:* Black's king will rarely move under normal chess engine logic, making it a hard but high-value shooting target.

### 5.3 Invader Firing

A "turn" is one complete white-move + black-move cycle, approximately 5 seconds. Once per turn, 1–3 random black pieces (weighted toward front-rank pawns) fire a projectile straight down. Projectiles travel at a fixed speed and can be:
- **Blocked** by a white piece with HP remaining (piece takes damage).
- **Shot down** by the player's spaceship laser.
- **Lethal** to the spaceship if they reach the bottom strip.

---

## 6. Raider Ships (Bonus Attackers)

Periodically, independent arcade ships swoop across the board on attack runs. These are not chess pieces — they have no chess identity, cannot be captured by chess moves, and do not affect the chess game state. They are pure arcade targets.

### 6.1 Ship Types

| Ship | Inspired by | Behavior | HP |
|---|---|---|---|
| **Raider Scout** | Space Invaders mystery ship | Flies straight across at mid-board height (rank 4–5), fires one shot straight down, exits the far side | 1 |
| **Galaxian Escort** | Galaxian escort fighter | Peels off from the *back* of the black fleet formation (rear rank), dives in a curved arc toward the player's spaceship, then exits or loops back up | 1 |
| **Galaxian Flagship** | Galaxian flagship | Dives in flanked by 2 Escorts (they die first); fires 2 shots on descent; worth most points | 2 (immune to first hit — flashes) |

### 6.2 Spawn Timing

- Raiders are independent of chess turns. They spawn on a real-time interval, slightly randomized.
- **Level 1:** one Raider Scout every ~20 seconds.
- **Level 2+:** mix of Scouts and Escorts; Flagship appears once per level minimum.
- Later levels: spawn rate increases, Flagships appear 2–3× per level.
- A maximum of 2 raider ships are on screen at once so they don't overwhelm the chess action.

### 6.3 Attack Behavior

- **Raider Scout:** fires one projectile straight down from its current x-position as it crosses the board. Projectile behaves like a black-piece shot — damages white pieces it hits, kills the spaceship on contact.
- **Galaxian Escort:** detaches from the back rank of the fleet (visually sliding out from behind the rearmost piece in its column), then swoops down in a curved arc toward the spaceship's last known position. Fires one shot at the apex of its dive. If it reaches the bottom strip without being shot, it costs the player one life (collision) or exits if the ship dodged. After exiting it does not return — a fresh Escort spawns next cycle. If all pieces in a column's back rank have been destroyed, the Escort spawns from the rearmost surviving piece in any adjacent column instead. If the entire fleet has been reduced to front-rank pieces only, the Escort spawns from the rearmost surviving piece on the board.
- **Galaxian Flagship:** dives with the same arc as Escorts but fires twice and requires 2 hits to destroy. On the first hit it flashes red (visual feedback) and accelerates its dive.
- **Kamikaze Escort** (Level 4+): A variant Escort that peels off with no shot — instead it dives straight and fast directly at the ship's current position with no warning audio cue. Requires a lateral dodge. Worth 200 pts if shot before impact. If it reaches the bottom strip it costs the player one life.

- **Galaxian Flagship escort shield:** While the Flagship's two flanking Escorts are alive, the Flagship is immune to player laser fire — shots pass through it. Once both Escorts are destroyed, the Flagship becomes vulnerable. A visual indicator (brief white flash + metallic clang SFX) plays when a shot hits the Flagship while it is still shielded, so the player learns the mechanic quickly.

### 6.4 Interaction with White Pieces

Raiders are not blocked by white chess pieces — they fly in the mid-board z-layer (visually above the board). Their **shots** do hit white pieces normally.

Galaxian Escorts that dive can clip white pieces in their flight path: each white piece in the path takes 1 damage as the raider passes through (the raider is not destroyed by this).

### 6.5 Visual & Audio

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

| Piece | Max HP | Hits to reach each damage state |
|---|---|---|
| Pawn | 2 | Full→Chipped at 1 hit; destroyed at 2 |
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

### 8.2 Spaceship Properties

- Moves horizontally only, confined to the bottom strip below rank 1.
- Two-shot laser cap under normal conditions — up to 2 lasers on screen simultaneously. This increases with pawn promotions (see §15.8).
- Has **3 lives** (shown as ship icons in HUD). Loses a life when an invader projectile reaches the bottom strip and hits the ship, or when an enemy piece advances to rank 1.
- No HP on the spaceship — one hit = one life lost, then respawn at center.

### 8.3 Firing Lanes

The laser fires straight up from the ship's current column. White pieces in the same column act as obstacles unless already destroyed. This creates a strategic reason to clear your own pieces for a clean shot — but at the cost of your own defense.

### 8.4 Losing a Life & Respawn

When the spaceship is hit it explodes, a life icon is removed from the HUD, and the ship respawns at the horizontal center of the bottom strip after a 1-second delay. The respawned ship is **invincible for 2 seconds**, flashing rapidly to signal the grace period. It can still move and fire during those 2 seconds. After 2 seconds invincibility ends with a final bright flash.

If the last life is lost the game ends immediately — no respawn.

### 8.5 Lives & HP Between Levels

- **Lives carry over** between levels. Losing a life on level 2 means starting level 3 with 2 lives. Lives are never replenished except via a future power-up (Phase 2).
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
| Shoot down invader projectile | 5 |
| Shoot Raider Scout (Space Invader ship) | 100 |
| Shoot Galaxian Escort | 150 |
| Shoot Galaxian Flagship | 300 |
| Destroy regenerated black Pawn | 15 (reduced — it came back) |
| Checkmate (king still alive) | 300 bonus |
| Shoot King that is simultaneously in checkmate | 500 (shot) + 300 (checkmate) = **800 total** — both bonuses awarded, logged separately |
| Clear a wave (all black pieces gone) | Level × 200 bonus |
| White piece surviving at level end | 10 × piece value |

Score multiplier increases by 0.5× for each level completed.

---

## 10. Level Structure

### 10.1 Wave Progression

Each level begins with a fresh standard chess setup and full white piece HP. Escalation happens across two tracks simultaneously: the chess engine gets more aggressive and the arcade action gets more intense.

#### Level 1 — Tutorial Wave
- Fleet speed: slow (40 px/s)
- Black chess moves: 1 per turn, passive engine (avoids losses)
- Invader shots: **none** — black pieces do not fire in Level 1
- Raiders: Scouts only, 1 every 20s
- No Escorts, no Flagship
- Turn timer: 5s
- *Feel: learnable. Player figures out the dual controls without being shot at by the fleet. Raiders provide the only incoming fire.*

#### Level 2 — Pressure Builds
- Fleet speed: medium (55 px/s)
- Black chess moves: 1 per turn, engine shifts to **aggressive** — actively advances pawns, prefers attacking moves over passive ones
- Invader shots: 1–2 per turn
- Raiders: Scouts + single Escorts begin appearing
- Turn timer: 5s
- *Feel: chess starts mattering. Black pieces advance toward you with intent.*

#### Level 3 — Double Trouble
- Fleet speed: medium-fast (70 px/s)
- Black chess moves: **2 per turn** — both pieces animate simultaneously, creating a dramatic visual surge that makes the formation suddenly unpredictable. Both moves are chosen by the engine at once before either animates; they execute in parallel with a shared animation trigger
- Invader shots: 2 per turn; diagonal shots introduced
- Raiders: Escorts now dive in **synchronized pairs**
- Flagship appears for the first time (once per level)
- Turn timer: 4s
- *Feel: the player is constantly reacting. Two chess moves per turn means the board shifts rapidly.*
- *Implementation note: for 2 (and 3) simultaneous moves, the engine evaluates and selects all moves before any animation begins, then triggers all piece animations with a shared `SKAction` group so they fire in parallel. This looks dramatic — multiple pieces surging at once — and is simpler to implement than sequential re-evaluation.*

#### Level 4 — Relentless
- Fleet speed: fast (90 px/s)
- Black chess moves: 2 per turn, fully aggressive engine
- **Piece regeneration begins:** destroyed black pieces occasionally respawn as Pawns at the back of the fleet after ~10 seconds. Maximum 2 regenerations per level.
- Invader shots: 2–3 per turn, fire rate spikes when fewer than 5 pieces remain
- Raiders: Escorts **loop back** after diving — they arc up and attack a second time before exiting. Flagship appears 1–2× per level.
- **Kamikaze Escorts** introduced: fast no-shot dive straight at the ship. No warning, requires a lateral dodge.
- Turn timer: 4s
- *Feel: the fleet never fully dies. Regeneration makes clearing the board feel urgent.*

#### Level 5 — Overwhelming
- Fleet speed: very fast (110 px/s)
- Black chess moves: **3 per turn** — all three animate simultaneously, the board reshuffles dramatically every sweep
- Piece regeneration: up to 4 regenerations per level
- Invader shots: 3 per turn (cap); projectile speed increases by 20%
- Raiders: mix of paired Escorts, looping Escorts, Kamikazes, and 2–3 Flagship appearances
- Random black piece "rushes" — once per fleet sweep, one black piece jumps 2 ranks forward
- Turn timer: 3s
- *Feel: barely controlled chaos. Chess moves are survival decisions, not strategy.*

#### Level 6+ — Infinite Escalation
- Each level beyond 5 adds: +15 px/s fleet speed, +10% projectile speed, one additional regeneration slot
- Chess moves per turn stays at 3 (cap)
- Turn timer stays at 3s (floor)
- Flagship appears 3× per level minimum
- Kamikaze frequency increases each level
- *No ceiling — the game continues until the player dies.*

### 10.2 Level End Conditions

A level ends when:
- **Victory:** All black pieces are destroyed (by shooting or chess captures).
- **Defeat:** White king is destroyed, or the spaceship loses all 3 lives, or any black piece reaches rank 1 (they've "landed").

On victory, a brief score-tally screen appears before the next level loads.

---

## 11. Game States

```
MAIN_MENU
    └─► NEW_GAME → PLAYING
                      ├─► LEVEL_CLEAR → SCORE_TALLY → PLAYING (next level)
                      └─► GAME_OVER → SCORE_TALLY → MAIN_MENU
PLAYING ──► PAUSED ──► PLAYING
```

---

## 12. Visuals & Audio

### 12.1 Overall Art Direction

The visual style is **neon-vector Recharged** — smooth glowing outlines on a pure black void, with bloom added live at runtime. The aesthetic is retro-inspired but modern: Tron-like neon line art, not a blown-up low-resolution game. Think Atari Recharged, not Intellivision.

**The key visual rule:** sprites must look sharp and smooth at their display size on any screen — Retina Mac, standard display, or iOS. The danger to avoid is low-resolution assets scaled up 2× or 3×, which produces blocky, jagged, stairstepped edges. Sprites should be authored at sufficient resolution that they look clean when scaled *down* to fit the board, never scaled up.

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

Actual asset dimensions from `GCI.spriteatlas` (PNG size at @2x; logical display size on Retina is half):

| Piece | Silhouette | PNG size (@2x) | Logical size |
|---|---|---|---|
| **Pawn** | Round head, short neck, flared base — smallest piece | 160×232 px | ~80×116 pt |
| **Bishop** | Tall stepped mitre, narrow waist, flared base | 176×264 px | ~88×132 pt |
| **Rook** | Squat fortress tower, flat 3-merlon battlements, wide base | 192×256 px | ~96×128 pt |
| **Queen** | Rounded orb crown top, wide flared shoulders, hourglass waist | 192×272 px | ~96×136 pt |
| **King** | Cross finial top, wide layered base — tallest piece | 192×288 px | ~96×144 pt |
| **Knight** | Horse head in profile, mane and neck detail — only asymmetric piece | 208×264 px | ~104×132 pt |

Ships (for reference):

| Ship | PNG size (@2x) | Logical size |
|---|---|---|
| Player Fighter | 232×200 px | ~116×100 pt |
| Raider Scout | 280×144 px | ~140×72 pt |
| Galaxian Escort | 224×176 px | ~112×88 pt |
| Galaxian Flagship | 272×160 px | ~136×80 pt |

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

The scene has **4 parallax layers**, back to front. (Phase 2.2 implements 2 layers; the remaining 2 layers are added in Phase 8 — see §22.)

| Layer | Content | Scroll speed |
|---|---|---|
| 0 (furthest) | Dense starfield — tiny 1px white dots, pure black bg | 0.2× |
| 1 | Mid stars — slightly larger, occasional neon blue/cyan tint | 0.5× |
| 2 | Neon nebula wisps — thin glowing streaks of cyan and magenta, very faint | 0.3× horizontal drift |
| 3 (closest) | Occasional geometric debris — wireframe polygon shapes (Recharged style) drifting past | 0.8× |

All layers scroll **downward** very slowly. During level-clear the scroll accelerates into a **hyperspace jump**: stars stretch into lines, white flash, then new level fades in. The wireframe debris chunks in layer 3 should feel like Asteroids Recharged geometry — vector outlines with a soft glow, not solid filled shapes.

---

### 12.5 HUD Design

```
┌─────────────────────────────────────────────────────┐
│  SCORE: 004750   HI: 012300   LEVEL 03   ♠ ♠ ♠     │
└─────────────────────────────────────────────────────┘
```

- **Font:** monospace pixel font (e.g., Press Start 2P or a custom 8×8 bitmap font). All caps.
- **Score:** left-aligned, white. Digits roll up arcade-style when points are added.
- **Hi-Score:** center, dim yellow — flashes briefly when beaten.
- **Level:** right of center, white.
- **Lives:** right-aligned, shown as small spaceship silhouette icons (♠ placeholder above).
- **Turn timer:** large digital countdown in the lower-left corner of the board area. Green → yellow → red as it counts down. Pulses on the last 2 seconds.
- **Auto-move indicator:** when the engine moves white, "AUTO" flashes in orange over the piece for 0.5 seconds.
- **Chess notation log:** debug/development builds only. Not shown in release builds — it would expose algebraic notation labels (a–h, 1–8) which are intentionally hidden from the player.

---

### 12.6 Lasers & Projectiles

| Projectile | Visual |
|---|---|
| Player laser | Bright cyan-white vertical beam, 2px core + bloom halo. Leaves a fading neon trail. |
| Invader shot (straight) | Hot magenta/red bolt, 3px, wobble animation, strong glow |
| Invader shot (diagonal, Level 3+) | Same bolt, rotated 45°, deep purple glow |
| Raider Scout shot | Acid green bolt — distinct from all other projectiles for readability |
| Escort/Flagship shot | Wide orange bolt with a trailing comet tail of particles |

All projectiles have a **neon bloom halo** (blur-and-add shader) and leave a **fading ghost trail** 4–6 pixels long. The overall effect should look like the projectiles in Asteroids Recharged or Tempest — bright cores with soft halos burning against pure black.

---

### 12.7 Explosions & Particle Effects

- **Small explosion** (Pawn, Escort): 8-frame sprite burst, ~24×24 px, orange/yellow
- **Medium explosion** (Knight, Bishop, Rook): same but ~36×36 px, adds white flash frame
- **Large explosion** (Queen, Flagship): ~48×48 px, multi-color (red → orange → white center), screen briefly flashes
- **King/Mothership destruction**: full-screen white flash, then an expanding ring shockwave sprite, then debris particles that drift and fade over ~2 seconds. Screen shakes for 0.3 seconds.
- **Ship destroyed**: same as medium explosion centered on the ship, followed by a respawn animation (ship fades in at center-bottom)
- **Piece damaged (not destroyed)**: small spark burst at impact point, 3-frame, no lingering particles
- **Smoke trail**: looping 4-frame animation attached to damaged pieces at ≤50% HP (complements the chipped sprite rather than replacing it)

---

### 12.8 Raider Ship Visuals

- **Raider Scout**: classic flying-saucer disc, 24×16 px. Wireframe-style outline with a spinning inner ring animation. Glows acid green, blinking underbelly light. Recharged-style — geometric, minimal, luminous.
- **Galaxian Escort**: narrow dart shape, 16×20 px. Hot orange outline, cyan engine glow at the tail. Wing-flap 2-frame animation in formation; elongated dive silhouette when attacking.
- **Galaxian Flagship**: wide and imposing, 32×24 px. Electric blue outline with gold/white center detailing. On first hit: full-body white flash and a shield-ring ripple effect before it accelerates. The most visually striking ship on screen.

---

### 12.9 Menus & Screens

- **Title screen:** "GALACTIC CHESS INVADERS" in large cyan neon (Press Start 2P), "★ 40 YEARS IN THE MAKING ★" in orange beneath it. A single row of 8 magenta chess pieces slides slowly left and right as a preview. "PRESS ANY KEY TO START" blinks below. Top 5 high scores displayed with initials, score, and level reached.
- **How To Play screen:** accessible from title. Covers controls, the twist, how to win, stay alive, scoring table (piece icons with point values), and the history note.
- **High score entry:** 8-character initial entry using up/down arrows per character, classic arcade style.
- **Pause screen:** game blurs/dims, "PAUSED" centered in large text. No menu — just resume on keypress.
- **Level clear screen:** score tally animates upward (points counting up sound effect), then "LEVEL X CLEAR" banner sweeps across.
- **Game over screen:** "GAME OVER" in large magenta neon. Three stats centered below: FINAL SCORE | HI-SCORE (in orange if beaten) | LEVEL REACHED. A large explosion fireball lingers and fades at center-bottom — the player ship's last moment. "PRESS FIRE TO PLAY AGAIN" blinks; "ESC → MAIN MENU" beneath it.

### 12.10 Audio Design

**SFX:** 8-bit / chiptune style — short synthesized tones. Generated with jsfxr or similar, exported as `.caf` for minimum latency (see §19.3).

**Music:** Modern electronic / dark synthpop in the Atari Recharged vein — not classic 8-bit beeps. Think driving synth with 80s/90s flavor: melodic, punchy, loopable. See §19.4 for sources and workflow.

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
| Castling | Double-move sound played in quick succession | |
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

- Master volume slider
- Music volume (separate)
- SFX volume (separate)
- Toggle: Music on/off

---

## 13. Power-Ups

### 13.1 Overview

Power-ups drop from destroyed enemies at random. They are glowing pickup items that fall slowly downward toward the spaceship strip. The player collects them by moving the ship under them — no shooting required. If a pickup reaches the bottom of the screen uncollected it disappears with a small fade.

Only one power-up can be active on screen at a time. If a new one would drop while an existing one is falling, it is discarded (no stacking drops mid-air). This keeps the screen readable.

### 13.2 Drop Probability

| Source destroyed | Drop chance |
|---|---|
| Black Pawn | 8% |
| Black Knight / Bishop | 15% |
| Black Rook | 20% |
| Black Queen | 35% |
| Raider Scout | 25% |
| Galaxian Escort | 30% |
| Galaxian Flagship | 50% (guaranteed on first Flagship per level) |
| Black King | Always drops a power-up (random type) |

### 13.3 Power-Up Types

#### Shield Bubble
- **Visual:** cyan hexagonal force-field outline that snaps around the spaceship on collection. Pulses softly.
- **Effect:** absorbs the next single hit that would destroy the ship. After absorbing one hit the shield shatters (particle burst) and the ship is unprotected again.
- **Duration:** indefinite — lasts until hit. **Resets at level end** — the shield does not carry over to the next level. It is a tactical tool for the current wave, not a persistent upgrade.
- **Pickup icon:** small glowing hexagon, cyan.

*(Shield Bubble is the only power-up for v1.0. Additional types — Repair Drone, Smart Bomb, Speed Boost — are reserved for a later update once core gameplay is balanced.)*

### 13.4 Pickup Visuals

All pickups share the same falling behavior and visual language:
- Icon is a small neon-vector glyph inside a glowing diamond outline.
- Rotates slowly while falling.
- Emits a faint light trail behind it as it descends.
- A brief "collect" flash and chime sound plays on pickup.
- Color-coded by type: Shield = cyan, (future: Repair = green, Smart Bomb = orange, Speed = yellow).

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
| 3 | 4s | **Power-up** — Shield Bubble pickup shown falling, ship collecting it, then absorbing a hit. "COLLECT POWER-UPS" text. |
| 4 | 4s | **Pawn promotion** — pawn advancing to rank 8, triple-event animation (queen swap, nearest piece explosion, "MULTI-SHOT" banner). "PROMOTE YOUR PAWNS" text. |
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

---

## 16. Technical Architecture (Swift / macOS)

### 16.1 Recommended Stack

| Component | Technology |
|---|---|
| Game rendering | **SpriteKit** (native macOS/iOS) |
| UI (menus, HUD) | **SwiftUI** overlaid on SpriteKit scene |
| Chess engine | Pure Swift module (`ChessEngine`) |
| State management | Swift actors / structured concurrency |
| Audio | **AVFoundation** or **SKAudioNode** |
| Data persistence | **UserDefaults** (high scores, settings) |

### 16.2 Module Breakdown

```
GalacticChessInvaders/
├── App/
│   ├── GCIApp.swift               ← SwiftUI entry point
│   └── ContentView.swift          ← SpriteKit scene host
├── Game/
│   ├── GameScene.swift            ← Main SpriteKit scene, game loop
│   ├── GameState.swift            ← Turn state machine
│   ├── TurnTimer.swift            ← 5-second countdown, check extension
│   ├── LevelManager.swift         ← Wave/level progression
│   └── AttractMode.swift          ← Title screen + attract mode sequencer
├── Chess/
│   ├── Board.swift                ← 8×8 board model (logical only, not rendered)
│   ├── Piece.swift                ← Piece type, color, HP
│   ├── MoveGenerator.swift        ← Legal move generation
│   ├── ChessEngine.swift          ← 1-2 ply minimax
│   └── ChessNotation.swift        ← Algebraic notation helpers
├── Arcade/
│   ├── Spaceship.swift            ← Player ship node, laser cap, shield state
│   ├── Laser.swift                ← Projectile nodes (player + enemy)
│   ├── FleetController.swift      ← Invader formation movement + descent
│   ├── RaiderController.swift     ← Scout / Escort / Flagship spawn + AI
│   ├── PowerUpController.swift    ← Drop logic, pickup collection, shield effect
│   └── CollisionHandler.swift     ← Physics contact delegate, all hit resolution
├── Nodes/
│   ├── PieceNode.swift            ← SKSpriteNode subclass, damage states, smoke
│   ├── HUDNode.swift              ← Score, timer, lives, check warning, auto flash
│   ├── ReticleNode.swift          ← Legal move crosshair indicators
│   └── PowerUpNode.swift          ← Falling pickup sprite + collect animation
├── Scores/
│   ├── ScoreManager.swift         ← Local top-10 table, UserDefaults persistence
│   └── InitialsEntryScene.swift   ← 8-character classic arcade name entry
└── Assets.xcassets/
```

### 16.3 Rendering the Dual Systems

- **Chess moves** are discrete events: a piece moves from square A to square B via a smooth `SKAction.move`. Square coordinates are converted to screen positions by a `BoardLayout` helper — the grid is pure math, never rendered.
- **Fleet movement** runs continuously via `SKAction.repeatForever` on a fleet parent node — all piece nodes are children, so they shift together. On each descent step, logical squares are updated via `GCIBoard.forcePlace()` — bypassing chess legality. The chess engine always evaluates from the current descended position. See §20.5 for full rules including crush events.
- **Collision detection** uses SpriteKit's physics bodies and `SKPhysicsContactDelegate`. Categories: `laser`, `enemyPiece`, `friendlyPiece`, `enemyProjectile`, `ship`.

### 16.4 iOS Port Considerations

- Replace keyboard controls with on-screen D-pad (move ship) + tap-to-fire button.
- Chess piece selection via tap-then-tap (tap piece, then tap destination).
- `UIAdaptivePresentationController` for split-screen iPad support.
- Use `UIRequiresFullScreen = false` in Info.plist to allow iPad multitasking.
- SpriteKit scenes scale cleanly to any screen size using `.aspectFill` + safe-area insets.

---

## 17. iOS Portability Architecture

This section defines how the macOS codebase must be structured from day one so that the iOS port in Phase 2 is a matter of adding a platform layer — not rewriting the game.

---

### 17.1 Core Principle: Separate Logic from Platform

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

### 17.2 Input Abstraction

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

### 17.3 macOS Window Behavior

The game runs in a **standard resizable macOS window** — it does not take over the screen on launch. The user can optionally go full screen via the green traffic-light button or `⌃⌘F` as with any Mac app, but this is never forced.

**Default window size:** 900×700 points — large enough to see all pieces clearly, small enough to sit comfortably on a 13" laptop screen without dominating the desktop.

**Minimum window size:** 640×500 points — below this pieces become too small to click reliably.

**Resizing behavior:** the SpriteKit scene uses `scaleMode = .aspectFit` on macOS so the playfield scales cleanly inside any window size, with black letterbox bars if the window proportions differ from the scene's native ratio. The game never stretches or crops.

The app should **not** set `NSWindowStyleMask.fullSizeContentView` or hide the title bar — the standard macOS chrome (title bar, traffic lights, menu bar) remains visible at all times in windowed mode.

---

### 17.4 SpriteKit — Already Cross-Platform

SpriteKit runs on macOS, iOS, and iPadOS with the same API. The `GameScene`, all `SKSpriteNode` subclasses, `SKAction` animations, particle emitters, and `SKAudioNode` audio all work without modification. This is the main reason SpriteKit was chosen over a Mac-only framework.

The one exception: `SKView` is embedded differently on macOS (`NSView`) vs iOS (`UIView`). This is handled by a thin wrapper in `ContentView.swift` using `#if os(iOS)`.

---

### 17.4 Screen Size & Layout

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

### 17.5 Audio

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

### 17.6 Asset Scaling — @1x / @2x / @3x

All sprite assets must be provided in three resolutions in `Assets.xcassets`:
- `@1x` — standard (older non-Retina, rarely used)
- `@2x` — Retina Mac, older iPhones
- `@3x` — iPhone Pro models, new iPads

The neon-vector aesthetic uses smooth outlines — **do not set `filteringMode = .nearest`** on piece sprites (that is for pixel art and would introduce no benefit here). Sprite textures should use the default linear filtering so smooth vector shapes scale cleanly on Retina displays. The bloom glow from `SKEffectNode` renders at screen resolution automatically.

---

### 17.7 iOS-Specific UI Elements to Build in Phase 2

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

### 17.8 Persistence

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

### 17.9 Shared Codebase Structure

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

## 19. Libraries & Tools

All dependencies are chosen to be lightweight, actively maintained, MIT/BSD licensed, and Swift Package Manager compatible. The goal is a small, auditable dependency tree — not a framework graveyard.

---

### 19.1 Chess Logic — ChessKit

**Package:** `https://github.com/aperechnev/ChessKit`
**License:** MIT
**Swift Package Manager:** Yes — add as a package dependency in Xcode
**Status:** Active. v2.0.0 released September 2025, Swift 6 compatible.

ChessKit is a pure Swift chess logic library with no UIKit or AppKit dependencies. It uses UInt64 bitboards internally for fast move generation and handles legal moves, check, checkmate, FEN notation, and PGN. Castling and en passant are supported but will not be called — they are simply ignored.

**What we use it for:**
- `MoveGenerator` — all legal moves for a given board position
- Check and checkmate detection
- Board state management

**What we write ourselves on top of it:**
- The minimax evaluation loop (1-2 ply, material count only)
- The "aggressive mode" weighting for Level 2+
- HP tracking (ChessKit has no concept of piece health)
- Multi-move-per-turn logic (Level 3+)

ChessKit replaces writing a move generator from scratch — the most tedious and bug-prone part of a chess engine. The AI evaluation on top of it is small and straightforward.

**Alternative:** `chesskit-app/chesskit-swift` — nearly identical quality, good fallback if integration issues arise.

**Do not use:** `SteveBarnegren/SwiftChess` (abandoned), `nvzqz/Sage` (explicitly abandoned by author).

---

### 19.2 Chess AI — Apple GameplayKit (built-in)

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

`GKMinmaxStrategist` runs synchronously but fast at depth 2 — wrap in `Task.detached` as per §19 performance rules. This is also used for `GKStateMachine` (game states: title, playing, paused, level clear, game over).

---

### 19.3 Sound Effects — pre-made library + generators + AVFoundation (built-in)

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
| Level / screen events | New level, game over, power-up collected |
| Arcade speech | "Game Over", "Power Up", "Bonus" stings |

Download the full pack, audition everything, and map the best candidates to GCI events. Many sounds work for multiple purposes.

#### Custom SFX Generator — jsfxr / ChipTone

For any sounds not covered by the library, or to create a unique signature sound (e.g. the player's specific laser tone):

- **[jsfxr](https://sfxr.me)** — browser-based, instant, no install. One-click randomise for laser/explosion/pickup/hit categories, then tweak parameters. Export as `.wav`.
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

### 19.4 Music — AVFoundation (built-in) + curated tracks

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

---

### 19.5 Game Math — simd (built-in)

**Framework:** `simd` — part of the Swift standard library, no dependency.

Use `SIMD2<Float>` for 2D positions and velocities, `simd_float2x2` for transforms. This is faster than `CGPoint` arithmetic for game logic calculations and is what SpriteKit uses internally.

No third-party math library is needed or recommended.

---

### 19.6 Full Dependency Summary

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

### 19.7 Adding ChessKit to the Xcode Project

In Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/aperechnev/ChessKit`
3. Select version rule: Up to Next Major from `2.0.0`
4. Add to the `GCI-macOS` target (and `GCI-iOS` when Phase 10 begins)

Then in `MoveGenerator.swift`:
```swift
import ChessKit
// Board, Position, Move, Piece types are now available
```

---

## 20. Performance Architecture

This section defines the performance rules that must be followed from Phase 0 onward. Violating these patterns produces games that run fine early and degrade as features are added — exactly what we want to avoid. None of these require exotic techniques; they are standard SpriteKit/Swift practices applied consistently.

**Target:** 60 fps on a 2019 MacBook Pro and iPhone 12 at all times, including during the most chaotic moments (fleet at full speed, multiple raiders, projectiles in flight, explosions active simultaneously).

---

### 20.1 Never Block the Main Thread

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

### 20.2 Object Pooling for Frequently Created Nodes

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

### 20.3 Texture Atlases — One Draw Call Per Atlas

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

### 20.4 Keep the Node Tree Shallow and Small

SpriteKit traverses the entire node tree every frame. Deep hierarchies and large node counts slow this traversal.

**Rules:**
- Maximum node count during gameplay: **~150 nodes**. This is generous — a full board has 32 pieces + projectiles + HUD + background = well under 150 if managed correctly.
- Never add child nodes inside `update()` — only in response to discrete game events.
- Destroyed pieces are **removed from the scene graph immediately** after their explosion animation completes — not kept hidden.
- Background parallax layers use **a small number of large sprites** that wrap/tile, not hundreds of individual star sprites. Use an `SKTileMapNode` or a single scrolling texture for the starfield.

---

### 20.5 Use SKAction for All Animations

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

### 20.6 Simple Physics Bodies

SpriteKit's physics engine is accurate but not free. Complex polygon bodies are significantly more expensive than primitive shapes.

**Rules:**
- All collision bodies are **circles or rectangles only** — no polygon paths.
- Piece collision bodies: circle, radius = half the sprite width.
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

### 20.7 Preload All Audio at Startup

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

### 20.8 Delta-Time Based Movement

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

### 20.9 The Bloom Shader — Use Once, Apply Everywhere

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

### 20.10 Profiling Schedule

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

## 21. Developer Diagnostics Log

### 21.1 Overview

The game includes a built-in live diagnostics log — a scrollable console view showing real-time events as they happen. It is the primary tool for understanding what the game is doing during development and playtesting without attaching Xcode's debugger.

The log is:
- **On by default in debug builds**, off by default in release builds
- Togglable at runtime with `L` on Mac or a button on iOS regardless of build type
- Monospace green text on black background — visually distinct from the game, reads like a classic terminal

---

### 21.2 Log Layout — macOS

The log appears as a **right sidebar** within the game window. The game scene occupies the left portion; the log occupies a fixed-width right panel.

```
┌──────────────────────────────┬─────────────────────────┐
│                              │ GALACTIC CHESS INVADERS │
│                              │ ─── DIAGNOSTIC LOG ──── │
│                              │                         │
│        GAME SCENE            │ STARTUP  Splash screen  │
│                              │ STARTUP  Music started  │
│                              │ INIT     Board created  │
│                              │ INIT     Pieces placed  │
│                              │ WHITE    e2→e4          │
│                              │ BLACK    e7→e5          │
│                              │ HIT      White Pawn d4  │
│                              │          -2HP (4→2)     │
│                              │ FLEET    Swept right    │
│                              │ RAIDER   Scout entered  │
│                              │ ...                     │
│                              │ [scroll up for history] │
└──────────────────────────────┴─────────────────────────┘
```

- **Sidebar width:** 280 points — wide enough for readable log lines, narrow enough to leave the game playable
- **Font:** SF Mono or system monospace, 11pt, bright green (`#00ff44`) on pure black
- **Auto-scrolls** to the latest entry. The player can scroll up to read history — auto-scroll resumes when they scroll back to the bottom
- **Full session history retained** — all events since launch are kept in memory (capped at 2,000 lines to prevent memory growth in long sessions)
- A thin neon separator line divides the game scene from the log panel
- Log panel can be shown/hidden with `L` — game scene expands to fill the full window width when hidden

---

### 21.3 Log Layout — iPhone

On iPhone the screen is too small for a sidebar. The log is a **separate full-screen view** toggled by a small `[LOG]` button in the corner of the game screen.

```
┌─────────────────────────┐       ┌─────────────────────────┐
│                         │  ←→   │ ─── DIAGNOSTIC LOG ───  │
│      GAME SCREEN        │       │ STARTUP  Splash screen  │
│                    [LOG]│       │ INIT     Pieces placed  │
│                         │       │ WHITE    e2→e4          │
└─────────────────────────┘       │ BLACK    e7→e5          │
                                  │ ...                     │
                                  │                  [GAME] │
                                  └─────────────────────────┘
```

- Tapping `[LOG]` switches to the log view (game is paused automatically)
- Tapping `[GAME]` returns to the game (resumes from pause)
- The log view is scrollable — full history visible
- Same monospace green-on-black styling

---

### 21.4 Log Categories & Format

Every log line follows the format:

```
CATEGORY    message text
```

Categories are fixed-width (8 chars), padded with spaces. This keeps columns aligned for easy reading.

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
| `POWERUP ` | Power-up drop, collection, effect |
| `PROMOTE ` | Pawn promotion event |
| `SCORE   ` | Points awarded |
| `TIMER   ` | Turn timer events (expiry, check extension) |
| `CHECK   ` | Check or checkmate detected |
| `LEVEL   ` | Level start, clear, game over |
| `AUDIO   ` | Music state changes, SFX triggers |
| `INPUT   ` | Player input events (debug only, very verbose) |
| `ERROR   ` | Unexpected states, assertion failures |

**Color scheme:** category label is always **green** (`#00ff44`), description text is always **white** (`#ffffff`). This applies uniformly to all categories. Exceptions for specific categories (e.g. ERROR label in red, CHECK label in red) can be added later once the log is running and we see which events need to stand out during playtesting.

`INPUT` events are suppressed by default even in debug builds — they are too frequent. Enable with a separate flag `logInput = true` in `DiagnosticsLog.swift`.

---

### 21.5 Example Log Output

```
STARTUP  App launched (macOS 15.2, debug build)
STARTUP  Window created 900×700
STARTUP  GameScene loaded
STARTUP  Intro music started
STARTUP  Title screen displayed
INPUT    Key pressed → GameAction.startGame
LEVEL    Level 1 started
INIT     Board reset, 16 white + 16 black pieces placed
INIT     Spaceship positioned at centre
TIMER    Turn 1 started (5.0s)
INPUT    Mouse click → BoardPosition(e2)
WHITE    Piece selected: White Pawn at e2
INPUT    Mouse click → BoardPosition(e4)
WHITE    Pawn moved e2→e4
TIMER    Turn 1 completed in 2.3s
TIMER    Turn 2 started (5.0s)
BLACK    Engine chose: Pawn e7→e5 (eval: +0.0)
FLEET    Fleet swept right (speed: 40px/s)
FLEET    Fleet fired: Black Pawn d7 → projectile spawned
TIMER    Turn 2 completed (auto)
HIT      White Pawn d2 hit by projectile (-1 HP → 3HP→2HP)
RAIDER   Scout entered from left at rank 4
RAIDER   Scout fired projectile at x=340
RAIDER   Scout exited right (not destroyed)
SCORE    +5 pts (projectile shot down) → total: 5
HIT      White Pawn d2 hit by projectile (-1 HP → 2HP→1HP)
HIT      White Pawn d2 hit by projectile (-1 HP → 1HP→0HP)
DESTROY  White Pawn d2 destroyed (HP exhausted)
BLACK    Engine chose: Pawn d7→d5 (eval: +0.2)
CHECK    White King in check from Black Bishop c5
TIMER    Check detected — timer extended to 8.0s
WHITE    Pawn moved e4→e5 (resolves check)
CHECK    Check resolved
PROMOTE  White Pawn reached rank 8 at e8
PROMOTE  Pawn→Queen (HP set to 12)
PROMOTE  Auto-destroy: nearest Black Pawn at f7 (500→0 HP)
DESTROY  Black Pawn f7 destroyed (promotion bonus)
PROMOTE  Multi-shot +1 (laser cap now: 3)
SCORE    +25 pts (promotion capture) → total: 475
LEVEL    Level 1 cleared — all black pieces destroyed
SCORE    Level clear bonus: 200 pts → total: 675
LEVEL    Level 2 started
```

---

### 21.6 Implementation

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
        let line = LogLine(category: category, message: message)
        DispatchQueue.main.async {
            self.lines.append(line)
            if self.lines.count > self.maxLines {
                self.lines.removeFirst()
            }
        }
    }
}

// Usage anywhere in the codebase:
DiagnosticsLog.shared.log(.white, "Pawn moved e2→e4")
DiagnosticsLog.shared.log(.hit, "White Pawn d2 hit (-1 HP → 2HP)")
DiagnosticsLog.shared.log(.check, "White King in check from Black Bishop c5")
```

The `DiagnosticsLog` is a singleton `ObservableObject`. The SwiftUI log panel observes it and updates automatically as new lines arrive. The game logic layer calls `DiagnosticsLog.shared.log(...)` directly — no coupling to the view layer.

---

### 21.7 Log Panel in Phase 0

The log panel should be built in **Phase 0** alongside the skeleton app — it is a development tool, not a game feature, and it pays dividends from the very first line of game code written. By the time chess logic and arcade systems are added, every event will already be flowing into the log automatically.

---

## 22. Development Phases & Testing

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
- `DiagnosticsLog.swift` — singleton log, category system, 2,000-line cap
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
- `TurnTimer.swift` — countdown logic, expiry callback, 8s check extension
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
- ⚡ Performance test: 1,000 move generations complete in under 100ms
- ⚡ Performance test: full 1-2 ply engine evaluation completes in under 50ms per turn
- **Pass criteria:** all unit tests green; chess engine plays a complete game to conclusion with no illegal moves; performance benchmarks pass

---

### Phase 2.1 — Playfield: Chess Functional

**Goal:** Wire the chess logic to the scene so chess is fully playable. Sprites are simple neon-colored shapes — correct size and color, not final art. Input, game state, HUD, and coordinate system all established correctly here.

**Build:**
- `BoardNode.swift` — coordinate mapping, no visible grid. `boardLayout.screenPosition(for: square)` helper, all positions as fractions of scene size — no hardcoded pixels
- `PieceNode.swift` — simple colored rectangles at correct sizes (16–28px), correct glow colors (white=cyan, black=magenta); damage frames stubbed as progressively dimmer/thinner outlines (will be replaced by final neon-vector damage states in Phase 2.2)
- `HUDNode.swift` — score, level, lives, turn timer in pixel font
- `ReticleNode.swift` — plain crosshair markers, no glow yet
- `MacInputHandler.swift` — keyboard + mouse → `GameAction` abstraction
- `GameState.swift` — turn state machine connecting logic to scene
- Piece move animation — smooth `SKAction.move` slide
- Auto-move "AUTO" flash indicator
- Check warning — king flashes, HUD warning
- ⚡ **All piece sprites in `Pieces.spriteatlas`** from day one
- ⚡ **Chess engine called via `Task.detached`** — never on main thread, verified from first move
- ⚡ **`ReticleNode` pool** — 32 nodes pre-created, shown/hidden not added/removed

**Testing:**
- Click white piece — reticles appear at correct legal destinations
- Click reticle — piece slides to new position
- Timer counts down, expiry fires auto-move, "AUTO" appears
- Timer expiry with piece selected — engine moves that specific piece
- Check detected — timer extends to 8s
- Checkmate — game over state reached
- Window resize — pieces stay in correct positions at 3 different sizes
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
- `FleetController.swift` — lateral sweep via `SKAction.repeatForever` on fleet parent node, half-rank descent, wall detection, speed scaling by piece count
- Fleet speed multiplier table wired to piece count
- ⚡ **Fleet movement is one `SKAction` on the parent node** — 16 pieces move at zero per-piece cost
- Log entries: `FLEET Swept right (40px/s)`, `FLEET Dropped half-rank`, `FLEET Speed 1.2× (12 pieces remain)`

**Testing:**
- Fleet sweeps right, hits wall, drops half a rank, sweeps left, repeats
- Fleet speeds up correctly as pieces are eliminated — verify all 5 multiplier steps
- Fleet movement does not affect chess logic — pieces snap to correct logical squares for move generation
- Chess game remains fully playable while fleet is sweeping
- ⚡ 60fps with full fleet sweeping continuously
- **Pass criteria:** fleet sweeps indefinitely without drift, chess still fully playable alongside it

---

### Phase 3.2 — Arcade Layer: Shooting & Collision

**Goal:** Add the spaceship, player laser, invader shots, HP damage, and lives. The core shoot-em-up loop.

**Build:**
- `Spaceship.swift` — horizontal movement, 2-shot laser cap, 3 lives, respawn + 2s invincibility
- `Laser.swift` — player and enemy projectile nodes
- `CollisionHandler.swift` — physics contact delegate. Physics bodies circles/rects only, bitmasks set correctly
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
- Screen shake per event (intensities per §21.1)
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
- Chess piece move (white) — soft click/thud
- Chess piece move (black) — same, slightly lower pitch
- Check warning — two-note alarm stab
- Auto-move fired — buzzer + move sound
- Turn timer warning (≤2s) — rapid ticking

**Testing:**
- Every listed sound plays on its correct trigger
- No sounds play when they shouldn't (e.g. no explosion on a non-destroying hit)
- Sounds don't stack into a wall of noise when many events happen simultaneously
- Ship destruction sound is clearly distinct from piece destruction
- Game feels noticeably more alive than silent Phase 3
- **Pass criteria:** a full level playthrough with no jarring silences on any major event

---

### Phase 5 — Background Music

**Goal:** Add the chiptune soundtrack. Music should loop cleanly and respond to basic game state changes — at minimum it stops on game over and plays a fanfare on level clear.

**Build:**
- Main gameplay chiptune loop — looping cleanly with no audible gap
- Per-level music track — pick randomly from level pool, loop for duration of wave
- Level clear fanfare — short 3–4 second jingle
- Game over riff — descending death riff
- Title screen music — plays on the title/attract screen, stops when game starts
- Basic music/SFX volume balance — music ducked slightly under loud SFX
- Volume settings in pause menu — master, music, SFX sliders

**Testing:**
- Music loops without a gap or click
- Music track loops cleanly throughout the wave without pops or gaps
- Level clear fanfare plays on victory, then next level music resumes
- Game over riff plays on defeat, does not loop
- Title music stops cleanly when game starts
- Music and SFX do not clash at default volume levels
- Volume sliders work correctly and persist across sessions
- **Pass criteria:** a full playthrough with music feels like a complete arcade experience; music energy matches the level's intensity target

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
- Scout enters from left or right edge, crosses at correct height, fires one shot, exits
- Scout shot is acid green — visually distinct from fleet shots
- Escort peels off from back rank, not a random position
- Escort dives toward ship's last known position (not current position)
- Escort collision with ship costs one life
- Maximum 2 raiders on screen — third queued until one exits
- All Scout and Escort SFX trigger correctly
- ⚡ No frame drop when both raiders are on screen simultaneously with full fleet
- **Pass criteria:** Scout and Escort behave correctly with audio; frame rate unaffected

---

### Phase 6.2 — Raiders: Flagship, Variants & Power-Up

**Goal:** Add the Flagship and the three Escort variants (Kamikaze, Paired, Looping), plus the shield bubble power-up.

**Build:**
- Galaxian Flagship — flanked dive with 2 Escorts, 2 HP, first-hit flash + clang, second hit destroys. 300 pts.
- Kamikaze Escort — fast no-shot straight dive at ship, no audio warning
- Paired Escorts — two Escorts dive in synchronized formation
- Looping Escort — dives, arcs back up, dives a second time before exiting
- `PowerUpController.swift` — drop probability table, falling pickup
- `PowerUpNode.swift` — rotating pickup sprite, collection detection
- Shield bubble effect — hex outline snaps to ship, absorbs one hit, shatters
- Flagship SFX: metallic clang on first hit, raider explosion on second
- Power-up SFX: soft chime on spawn, ascending ding on collect, crunch+shatter on absorption
- Flagship added to `Raiders.spriteatlas`

**Testing:**
- Flagship flanked by 2 Escorts — Escorts must die before Flagship takes damage
- Flagship first hit — flashes, clangs, accelerates; does not die
- Flagship second hit — dies, 300 pts
- Kamikaze — no shot, fast straight dive, requires lateral dodge
- Paired Escorts — two dive in formation simultaneously
- Looping Escort — dives, loops up, dives again before exiting
- Shield drop ~50% from Flagship — verify over 20 kills
- Shield collects on ship flyunder, absorbs one hit, shatters visually and aurally
- Shield does not stack — second pickup ignored while active
- All new SFX trigger correctly
- ⚡ 60fps with Flagship + 2 Escorts + full fleet + projectiles simultaneously
- **Pass criteria:** all raider types and power-up behave correctly with audio across 5+ levels of play

---

### Phase 7.1 — Level Escalation: Chess AI

**Goal:** Make black play smarter and faster as levels increase. These are changes to the chess engine and turn structure only — no new arcade content.

**Build:**
- Aggressive engine mode (Level 2+) — engine weights pawn advancement and attacking moves over passive play
- 2 chess moves per turn (Level 3) — two pieces relocate each turn
- 3 chess moves per turn (Level 5) — three pieces relocate
- Score multiplier wired to level — 1.0× at Level 1, +0.5× per level

**Testing:**
- Level 2: engine demonstrably prefers advancing pawns — log BLACK moves over 10 turns and verify advancement bias
- Level 3: exactly 2 BLACK log entries per turn
- Level 5: exactly 3 BLACK log entries per turn
- Score multiplier — verify +25 pawn capture scores 25 on Level 1, 37 on Level 2, 50 on Level 3
- Chess game remains legal throughout — no illegal moves produced by multi-move turns
- **Pass criteria:** AI escalation verified by log output across Levels 1–5; no illegal chess states

---

### Phase 7.2 — Level Escalation: Arcade Mechanics

**Goal:** Add the arcade escalation features — diagonal shots, piece regeneration, fleet rush, and the pawn promotion power-up event.

**Build:**
- Diagonal invader shots (Level 3+) — 45° projectiles, purple glow, 160 px/s. Collision detection uses SpriteKit physics bodies (not strict geometric 45° line intersection) — the shot hits any piece whose physics body it overlaps during travel
- Piece regeneration (Level 4+) — destroyed black pieces respawn as Pawns after 10s, dimmer glow, slot cap per level
- Fleet rush mechanic (Level 5+) — one random piece jumps 2 ranks forward per fleet sweep
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
- "AUTO", "CHECK", "MULTI-SHOT" banner animations
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
- All banner animations ("AUTO", "CHECK", "MULTI-SHOT") trigger correctly
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

### Phase 10 — iPad Port

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

### Phase 11 — iPhone Port

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

## 18. Difficulty Tuning

All values below are starting points for playtesting — they should be adjusted once the game is running. The key feel target: Level 1 should be learnable, Level 3 should feel urgent, Level 5+ should feel overwhelming-but-survivable.

### 18.1 Per-Level Parameters

| Level | Fleet speed (px/s) | Black moves/turn | Shots/turn | Proj. speed | Turn timer | Regen slots | Raider interval |
|---|---|---|---|---|---|---|---|
| 1 | 40 | 1 (passive) | **0** | — | 5s | 0 | 20s, Scouts only |
| 2 | 55 | 1 (aggressive) | 1–2 | 180 px/s | 5s | 0 | 15s, Escorts begin |
| 3 | 70 | 2 (aggressive) | 2 | 180 px/s | 4s | 0 | 12s, paired Escorts, Flagship ×1 |
| 4 | 90 | 2 (aggressive) | 2–3 | 200 px/s | 4s | 2 | 10s, looping + Kamikaze Escorts |
| 5 | 110 | 3 (aggressive) | 3 | 216 px/s | 3s | 4 | 8s, all raider types |
| 6+ | +15/level | 3 (cap) | 3 (cap) | +10%/level | 3s (floor) | +1/level | 6s (floor) |

### 18.2 Speed Scaling Within a Level

As black pieces are eliminated the fleet speeds up, classic Invaders-style:

| Black pieces remaining | Speed multiplier |
|---|---|
| 16 (full fleet) | 1.0× |
| 12 | 1.2× |
| 8 | 1.5× |
| 4 | 2.0× |
| 1 | 2.5× |

### 18.3 Projectile Speeds

| Projectile | Speed (px/s) |
|---|---|
| Invader shot (straight) | 180 |
| Invader shot (diagonal, Level 3+) | 160 |
| Raider Scout shot | 200 |
| Escort / Flagship shot | 220 |
| Player laser | 400 |

Player laser is always faster than any incoming projectile so shooting down enemy shots is reliably possible.

---

## 23. Controls Reference

### 23.1 macOS (Keyboard + Mouse / Trackpad)

The player operates two systems simultaneously — the spaceship with the keyboard (left hand) and chess with the mouse or trackpad (right hand). This split is intentional and central to the game's tension. Both inputs are always live; selecting a chess piece never freezes the ship.

| Action | Input |
|---|---|
| Move ship left | `←` or `A` |
| Move ship right | `→` or `D` |
| Fire laser | `Space` |
| Select white chess piece | Left-click on piece |
| Confirm chess move | Left-click on destination reticle |
| Deselect piece | Right-click or `Escape` (when piece selected) |
| Pause / unpause | `P` or `Escape` (when nothing selected) |
| Quit to title | `⌘Q` |

Both `←/→` arrow keys **and** `A/D` keys are supported simultaneously with no configuration — the player uses whichever feels natural. This makes the game comfortable on both external keyboards (arrow keys) and laptop keyboards where WASD keeps the left hand centred on the trackpad.

#### Timer expiry with a piece selected

If the 5-second turn timer expires while the player has a white piece selected, the chess engine picks the **best available move for that specific piece** and executes it automatically. The reticles flash once before the move fires, giving a half-second visual warning. This rewards partial intent — the player chose a piece, the engine completes the thought.

If no legal move exists for the selected piece (e.g. it is pinned), the engine deselects it and picks any legal white move instead.

### 23.2 iOS / iPadOS (Touch)

| Action | Input |
|---|---|
| Move ship | Left virtual joystick (bottom-left zone) |
| Fire laser | Fire button (bottom-right zone) |
| Select + move chess piece | Tap piece, then tap destination reticle |
| Deselect piece | Tap empty space |
| Pause | Pause button (top-right corner) |

The left half of the screen drives the ship; the right half (and upper area) handles chess. The split is natural for two-thumb play on iPhone and iPad.

### 23.3 Dual-Input Design Note

The game is explicitly designed around the difficulty of doing two things at once: flying and shooting with one hand while making timed chess decisions with the other. This is the core skill loop. Controls should never be simplified to remove this tension.

---

## 24. Edge Cases & Rules Clarifications

### 24.1 Stalemate

Chess stalemate (no legal moves for white, not in check) is **ignored**. The spaceship can always act — shoot, dodge — even if no chess move is currently legal. The turn timer still runs; when it expires the auto-move engine will find that no chess move is available and simply does nothing. The game continues. This situation is rare in practice given that pieces are being destroyed throughout the game.

### 24.2 Game Over Conditions — Complete List

The game ends immediately under any of the following:

| Condition | Result |
|---|---|
| White king HP reaches 0 (shot) | Defeat |
| White king is checkmated | Defeat |
| Spaceship loses all 3 lives | Defeat |
| Any black piece reaches rank 1 | Defeat |
| Black king is checkmated | Victory — level clear |
| Black king HP reaches 0 (shot) | Victory — level clear, bonus points |

> **Open question — win condition:** The primary intended win condition is **checkmate** (black king in check with no legal moves), consistent with real chess. The design brief mockup suggested "clear the board — destroy every black piece," but this is not the intended design. However, this is worth playtesting: in an arcade game where pieces can be shot down, a full-board-clear condition may feel more natural and satisfying than a pure checkmate ending. Both should be prototyped and tested in Phase 3 before committing. For now, **checkmate is the target**, with board-clear as a secondary path if the black king is shot.

### 24.3 Continues

None. Game over is permanent — the player returns to the title screen. Score is submitted to the local high score table. No mid-game saves.

### 24.4 Pause

Pressing `P` (macOS) or the pause button (iOS) freezes everything: fleet movement, projectiles in flight, timers, raider ships, particles, music. The screen dims and "PAUSED" appears centered. Pressing `P` again or tapping "Resume" restores exactly the state that was frozen — no input is processed while paused.

### 24.5 Piece Logical Position During Fleet Sweep

**The fleet sweep is not purely cosmetic — it advances the chess game.**

As the black fleet sweeps laterally and descends, each piece's logical chess square updates to match its new board position. After each half-rank descent, every black piece's logical square is updated. This means the chess engine always works from the fleet's current board position, not the starting position. Black's pieces are genuinely advancing on the board — threatening new squares, exerting new pressure on white's position — not just drifting across the screen decoratively.

The analogy: it is as if the black player has secretly moved all their pieces forward while white wasn't looking. White has no recourse — the new positions are simply where the army is now.

**Two positions, one canonical:**

- **Visual position:** the sprite's actual screen coordinates, updated continuously by `SKAction` on the fleet parent node. Used for shooting hit detection and rendering.
- **Logical position:** the chess square (a1–h8), updated at each descent step and after each chess move. Used for all move generation, threat calculation, and projectile origin.

After each half-rank descent the `FleetController` iterates all living black pieces and calls `board.forceSet(piece, square: newSquare)` — bypassing legality checks entirely. This is intentional: fleet movement is an arcade event, not a chess move.

**Collision with white pieces:** When the fleet descends and a black piece's new logical square is already occupied by a white piece, a **crush event** fires:
- The white piece is immediately removed from the board (no HP check — the crush is instant)
- A dedicated "crushed" animation plays: the black piece briefly enlarges and the white piece shatters outward in fragments, then the black piece settles on the square
- No points are awarded for a crushed white piece (it was the black fleet's advance, not the player's action)
- If the crushed piece was the **white King**, this triggers game over (defeat) immediately

**Architecture note — bypassing chess legality:** ChessKit enforces legal moves through its `move()` API. Fleet descent and fleet rush events must use a **direct board state mutation** (`forceSet` or equivalent) that bypasses legality validation. GCI maintains its own `GCIBoard` wrapper around ChessKit's position; all forced placements go through `GCIBoard.forcePlace(piece:at:)` which updates the internal bitboard directly. The chess engine (GKMinmaxStrategist) evaluates from the resulting position — it does not know or care how pieces arrived at their squares. This is by design: GCI's chess is a living, cheating game where the rules bend to serve the arcade action.

**Lateral sweep (same rank):** The lateral left-right oscillation does *not* update logical squares — file (column) changes happen only on descent. A piece sweeping horizontally is visually in motion but logically still on its last-descended rank/file until the next downward step. This keeps the chess engine stable between descents.

### 24.6 Castling

Not implemented. The king and rooks move as individual pieces only. The chess engine will never attempt to castle, and the move generator does not generate castling as a legal move.

### 24.7 En Passant

Not implemented. Pawns capture only by standard diagonal capture. The move generator does not generate en passant.

### 24.8 Piece Regeneration

From Level 4 onward, destroyed black pieces can regenerate. Rules:
- A regeneration triggers 10 seconds after a black piece is destroyed, subject to the level's regeneration slot cap.
- The regenerated piece is always a **Pawn**, regardless of what was originally destroyed. It spawns at the back of the fleet at a random column position, with full Pawn HP (2).
- Regenerated Pawns are visually distinct — they appear with a brief green flash on spawn and have a slightly dimmer glow, so the player can recognize them.
- Regenerated Pawns are valid chess pieces. They can advance, promote, and fire shots like any other Pawn.
- The black King never regenerates.
- If the level's regeneration slot cap is reached, no further regenerations occur for that level.
- **If the level ends while a regeneration timer is running, the timer is cancelled.** The board resets fresh at the start of each level — no pending regenerations carry over.

### 24.9 Simultaneous Hits

If a player laser hits two sprites in the same frame (e.g., a projectile and a piece behind it), both take damage. Collision resolution processes all contacts in the frame before removing any nodes — no single-frame sequencing issues.

### 24.10 Score Multiplier

The score multiplier starts at 1.0× and increases by 0.5× at the start of each new level (Level 1: 1.0×, Level 2: 1.5×, Level 3: 2.0×, etc.). All points scored during a level are multiplied by that level's multiplier. The "WHITE PIECE SURVIVING" end-of-level bonus is also multiplied. The multiplier is never reset mid-game — it is a persistent reward for reaching higher levels.

---

## 25. Game Feel ("Juice")

These are the small details that make the game feel physically satisfying. None of them affect game logic — they are all purely presentational.

### 25.1 Screen Shake

| Event | Shake intensity | Duration |
|---|---|---|
| Player ship destroyed | Medium | 0.4s |
| Black Queen destroyed | Light | 0.2s |
| Black King destroyed | Heavy | 0.6s |
| Flagship destroyed | Medium | 0.3s |
| Player laser hits a piece | Micro-shake | 0.05s |

Shake is implemented as a rapid random offset on the camera node, decaying exponentially. It should feel punchy, not nauseating.

### 25.2 Hit Freeze

When a high-value piece is destroyed (Queen, King, Flagship), the game freezes for **2–4 frames** before the explosion animation plays. This is the classic "hit stop" or "hitstun" technique — it makes big impacts feel weighty. Small hits (Pawns, Scouts) get no freeze.

### 25.3 Score Pop

Every time points are awarded, the score value pops up at the location of the destroyed piece/target (+150, +500, etc.) in the piece's glow color, floats upward ~30 pixels, then fades out over 0.8 seconds. The HUD score simultaneously ticks upward digit by digit.

### 25.4 Turn Timer Pulse

The countdown timer pulses (briefly scales up ~10%) on each whole second tick. At 2 seconds remaining it turns red and pulses on every half-second. At 1 second it flashes rapidly. This makes the timer feel urgent without being distracting during calm moments.

### 25.5 Laser Impact Flash

When the player's laser hits anything, there is a single-frame white flash at the impact point — 1 frame only, no linger. Rapid-fire hits create a staccato strobe effect that reads as "I am definitely hitting this."

### 25.6 Piece Movement Trails

When a chess piece moves (either player or auto-move), it leaves a brief neon ghost trail along its path — the same color as its glow. The trail fades within 0.3 seconds. This makes chess moves visible even when the player is focused on shooting.

### 25.7 Fleet Heartbeat Pulse

The black pieces pulse very slightly in brightness (±15% opacity) in sync with the Space Invaders heartbeat bass notes. As the heartbeat speeds up, so does the pulse. This ties the audio and visual rhythm together subconsciously.

### 25.8 Pawn Promotion Sequence

The pawn promotion event (§15.5) gets a dedicated 0.5-second "moment":
1. All other action continues but dims slightly (80% opacity).
2. Targeting beam locks onto nearest black piece — a bright line drawn from the promoted queen to the target.
3. Target explodes.
4. "MULTI-SHOT ACTIVATED" banner sweeps across in hot white text.
5. Opacity returns to normal.

Total interruption: 0.5 seconds. Not a pause — the player can still move and shoot during it.

---

## 15. Design Decisions

### 15.1 Legal Move Indicators

**Decision:** Shown, but faint.

**Rule:** Select a white piece → dim neon-green crosshair reticles appear at every valid destination. Visible enough to be useful, unobtrusive enough not to dominate the screen during combat. Click any reticle to confirm the move. Click elsewhere or press Escape to deselect. Reticles vanish the moment the piece moves or is deselected.

---

### 15.2 Auto-Move Quality

**Decision:** When the timer expires the computer makes a **reasonable chess move** for white using the same 1-2 ply engine that drives black. This is fairer than random — it won't throw away pieces — but it won't be inspired either. "AUTO" flashes orange above the moved piece for 0.5 seconds.

**Rule:** Timer expires → chess engine selects best available white move → executes it → "AUTO" indicator fires. The player is not punished by a blunder, but they lose control of that turn's chess decision.

---

### 15.3 Fleet Descent Rate

**Decision:** The fleet drops **half a rank** per wall bounce. This gives 12 bounces before the fleet reaches the white piece zone — more time to thin out the fleet by shooting before they get dangerously close. Lateral speed still increases as pieces are eliminated, maintaining escalating tension.

**Rule:** Fleet hits right wall → drops half a rank → sweeps left → drops half a rank → repeat. Game over trigger: any black piece reaches rank 1. Descent rate is fixed across all levels; only lateral speed scales with level and remaining piece count.

---

### 15.4 Check Behavior

**Decision:** Timer extends to **8 seconds** when white is in check. The arcade action (invader shots, raider ships) continues unpaused. A red "CHECK" warning pulses in the HUD and the white king's sprite glows red.

**Rule:** Check detected → white's next turn timer becomes 8s. If the player fails to act, the auto-move engine fires but is constrained to moves that resolve check only. If no legal resolving move exists → checkmate → game over.

---

### 15.5 Pawn Promotion — Power-Up Event

**Decision:** Promotion is a **dramatic power-up moment**, not just a piece swap.

**Rule:** White pawn reaches rank 8 →
1. Pawn instantly becomes a Queen (full 12 HP, Queen sprite with flash animation + ascending arpeggio).
2. The nearest black piece on screen is **destroyed automatically** — a targeting beam locks onto it and it explodes, no shot required. Points awarded as normal.
3. The player's spaceship laser cap increases by 1 for the remainder of the level. A "MULTI-SHOT" banner briefly sweeps across the bottom of the screen showing the new cap.

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

### 15.6 Friendly Fire

**Decision:** Always allowed, no warning, no prompt.

**Rule:** Player laser hits a white piece → piece loses 2 HP. If HP reaches 0 the piece is destroyed — no points awarded. A distinct low/mournful explosion sound plays to confirm it was your own piece. This is a deliberate tactical option for clearing firing lanes.

---

### 15.7 Black King Movement

**Decision:** The black King **moves with the fleet** left and right, exactly like all other black pieces. It is not special-cased. This makes it a moving target and harder to snipe — but it still scores 500 pts if shot.

**Rule:** Black King is a full member of the fleet parent node and participates in all lateral sweeps. It moves to a new chess square when the engine selects a king move (rare). The King is the highest-HP piece (16 HP) so shooting it down requires sustained fire or a clear lane — it won't die from a stray shot.

---

### 15.8 Spaceship Firing Rate

**Decision:** Up to **2 simultaneous lasers** on screen under normal conditions. Each white pawn promotion increases the cap by 1 (stacking), up to a hard cap of 6. Resets to 2 each level. See §15.5 for the full stacking table.

**Rule:** `Spaceship.activeLaserCount` tracks in-flight shots. Normal cap: 2. Post-promotion cap: 3. Each laser that exits the screen or hits a target decrements the count, freeing a slot. On iOS the fire button dims (not disables) when at the cap — tapping still queues a shot for the instant a slot opens.

---

*End of resolved decisions — v0.2*
