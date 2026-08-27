# Art & UI Handoff — Galactic Chess Invaders

> This was the repository's original README: the visual handoff written before
> any code existed — the look, the screen layouts, the HUD, the FX language and
> the design tokens. It is kept as reference for how the game was meant to look.
> Where it and the built game disagree, `docs/implementation.md` records which
> way the deviation went and why.

## Overview
Galactic Chess Invaders is a macOS arcade–chess hybrid. A real chess game plays out, but Black's
pieces double as a *Space Invaders*-style fleet — sliding sideways, descending, and firing — while the
player simultaneously commands White's moves **and** a laser ship at the bottom of the screen. This
package is the **visual + art handoff**: the look, the screen layouts, the HUD, the FX language, the
design tokens, and the production-ready sprite assets. The full game-design / mechanics spec is included
separately (`gci-game-design.md`).

Target platform from the design doc: **macOS, SpriteKit**, default window 900×700 (≈9:7).

---

## About the Design Files
The `.html` / `.jsx` / `.js` files in this bundle are **design references**, not production code to ship.
They are an HTML/Canvas prototype that defines exactly how the game should look and behave. Your job is to
**recreate these designs natively in the target environment (SpriteKit / Swift)** using its idioms (SKScene,
SKSpriteNode, SKEffectNode, SKAction, SKLabelNode), not to embed the HTML.

Two of the bundled artifacts ARE meant to flow into the build directly, though:
- **`GCI.spriteatlas/`** — a drop-in Xcode Asset Catalog sprite atlas (clean transparent PNGs).
- **`sprites.js`** — the authoritative sprite *logic* (pixel maps + the contour→vector algorithm). You can
  either (a) just use the pre-rendered atlas, or (b) port the algorithm to generate textures at runtime.
  Read "Sprite system" below before deciding.

## Fidelity
**High-fidelity (hifi).** Colors, typography, spacing, layout coordinates, and FX are final and exact.
Recreate the screens pixel-accurately at the 900×700 design resolution, then scale the SKScene to fit the
window. Every hex value and coordinate in this README is authoritative.

---

## Design Tokens

### Core palette (`PAL`)
| Token    | Hex       | Use |
|----------|-----------|-----|
| bg       | `#000000` | The void. Pure-black background everywhere. |
| white    | `#e8f4ff` | Primary HUD text |
| cyan     | `#00dfff` | **Player / White side** accent, lasers, UI chrome |
| magenta  | `#ff2060` | **Enemy / Black side** accent, enemy fire, "GAME OVER" |
| green    | `#7dff4d` | Raider Scout |
| orange   | `#ff8a1e` | Galaxian Escort, explosions |
| blue     | `#3aa2ff` | Galaxian Flagship |
| yellow   | `#ffd24d` | Hi-score, scoring highlights, debris sparks |
| dim      | `#5a6b78` | Secondary/label text |

### Sprite stroke colors (neon vector edges)
Pieces (`VEC_PIECE`):
- White: edge `#e8f7ff`, glow `#1ce4ff`, accent `#7fe9ff`
- Black: edge `#ff7aa6`, glow `#ff2a66`, accent `#ff9ec2`

Ships (`VEC_SHIP`): edge / glow / accent
- player: `#e8f7ff` / `#1ce4ff` / `#1ce4ff`
- scout: `#a6ff66` / `#7dff4d` / `#e8ff45`
- escort: `#ffb05a` / `#ff8a1e` / `#19e6ff`
- flagship: `#74b8ff` / `#3aa2ff` / `#ffd24d`

### Typography
- **Display / titles / HUD / scores:** `Press Start 2P` (Google Fonts, bitmap arcade face). Bundle the TTF
  in-app; don't rely on a system fallback.
- **Body / specs / labels:** `SF Mono` (or any system monospace). Used for help text and small labels.
- Letter-spacing on display text is generous (title ≈4px tracking at 52px). HUD numbers are zero-padded
  (`SCORE 000000`, `LEVEL 01`).

### Layout grid (900×700 canvas)
- Board is **not** drawn as a grid — pieces float in space.
- File→x: `x = 219 + file * 66`  (file 0–7 = a–h)
- Rank→y: `y = 140 + (8 - rank) * 64`  (rank 1–8; y grows downward)
- This leaves a **fly-in lane** (~y 52–118) above the black fleet for raider ships, and lateral margin
  (~219px each side) so the fleet can slide to the screen edges.
- HUD bar: top 46px. Player ship sits near y≈658.

### Radii / chrome
- UI chips (INFO / BACK): border `1.5px` of cyan@~60%, radius 6px, bg `rgba(0,30,45,0.5)`,
  glow `0 0 8px cyan@27%`. Located **top-right corner**, right of the HUD lives icons.

---

## Sprite system (the important part)

Every piece and ship is defined as a **pixel map** (a grid of `#`/`@`/`.` strings) in `sprites.js`. These are
NOT rendered as pixels in the final look. The renderer:
1. Traces the filled cells into closed contours (marching-squares boundary).
2. Smooths them with 3 iterations of Chaikin subdivision → smooth vector outline.
3. Strokes that outline in layered neon (wide glow stroke → bright edge → white-hot core line), with a
   faint interior gradient. This is the modern Atari "Recharged" look — **smooth glowing outlines, not 8-bit
   blocks.**

**Bloom is applied at runtime, never baked.** In SpriteKit: render/import the clean outline sprite, then
put it (or a layer of them) under an `SKEffectNode` with a `CIGaussianBlur` + additive blend for the glow.
The atlas PNGs are intentionally clean (no glow) so you control bloom live.

### Two integration paths
**Path A — use the pre-rendered atlas (fastest).** Drop `GCI.spriteatlas` into `Assets.xcassets`. Load with
`SKTexture(imageNamed: "chess-w-king")`. These are smooth high-res vector PNGs, so use **linear** filtering
(default) — do *not* set `.nearest` (that's only for true pixel art). Add the bloom via `SKEffectNode`.
Damage tiers ship as separate textures (see naming).

**Path B — port the renderer (most flexible).** Reimplement the pixel-map → contour → Chaikin → stroke
pipeline in Swift/Core Graphics so you can render any piece at any size, recolor per-side, and animate the
"omit lower outline" damage continuously. The full algorithm lives in `sprites.js`
(`traceContours`, `chaikin`, `vectorFromMap`). Pixel maps are in the `MAPS` and `SHIPS` objects.

### Atlas naming convention
Clean transparent PNGs, 1× (high-res native), no glow baked in:
- Pieces: `chess-<side>-<type>` where side ∈ {`w`,`b`}, type ∈ {`king`,`queen`,`rook`,`bishop`,`knight`,`pawn`}
  - e.g. `chess-w-king`, `chess-b-queen`
- Damage tiers: append `-d1` (chipped, ~32%) and `-d2` (critical, ~58%)
  - e.g. `chess-b-rook-d1`, `chess-b-rook-d2`  (full-HP is the base name, no suffix)
- Ships: `ship-player`, `ship-scout`, `ship-escort`, `ship-flagship`
- Bonus ships (Jeff Minter tributes, flyover after Level 1): `ship-llama`, `ship-camel`
- 42 imagesets total (6 types × 2 sides × 3 damage tiers = 36 pieces + 4 ships + 2 bonus).

### Piece silhouettes (so they read distinctly)
- **King** — tallest; cross finial on top.
- **Queen** — just under king height; **orb finial** + wide collar, tapered body (no cross, no battlements).
- **Rook** — square crenellated turret top.
- **Bishop** — mitre with the diagonal slit.
- **Knight** — horse-head profile; **faces right for White (player), left for Black (enemy)**.
- **Pawn** — shortest; round head on a flared base.

### Bonus ships (Jeff Minter tributes)
Rare top-lane flyovers that appear after Level 1 — shoot for big bonus points. Side-profile, face right.
- **Llama** (*Llamatron*) — upright neck, perky ears; purple neon (glow `#a64dff`). ~1000 pts.
- **Mutant Camel** (*Attack of the Mutant Camels*) — two humps, long neck; gold neon (glow `#ffb01e`). ~2000 pts.

Note on facing: the knight map is authored facing right and horizontally flipped for the black side. If you
mirror sprites in engine, only the knight needs it.

---

## Screens / Views

All screens are 900×700, pure-black, with a parallax starfield + faint nebula behind everything (see "Starfield").

### 1. Title Screen
- **Purpose:** Attract screen / entry point.
- **Layout:** Centered stacked logo "GALACTIC / CHESS / INVADERS" (Press Start 2P, ~52px, ~4px tracking,
  cyan with a slow color-cycle through cyan→magenta→white). Tagline "★ 40 YEARS IN THE MAKING ★" in yellow.
  A row of the black back-rank pieces slides side-to-side as a fleet teaser. Blinking "PRESS ANY KEY TO START"
  (white, cyan glow, 1s blink). Below: a "HIGH SCORES" table (rank / initials / score / level), initials in
  cyan, scores white, level yellow.
- **Behavior:** Logo hue-cycles (~6s loop). "Press any key" blinks. Fleet drifts ±36px (~5s ease loop).

### 2. How To Play (Help / Info)
- **Purpose:** Rules + controls + scoring + history. Reached via the **INFO** chip on gameplay screens.
- **Layout:** Header "HOW TO PLAY". Two columns:
  - Left: **THE TWIST** (the dual chess+invaders concept), then **CONTROLS** with key-cap glyphs:
    `◄ ►` / `A D` = move ship, `SPACE` = fire, `CLICK` = select piece & target square, `▼ 5s` = turn timer.
  - Right: **HOW TO WIN** (clear the board / shoot the black King), **STAY ALIVE** (guard your King + ship,
    3 lives), **SCORING** — a grid of neon piece icons with point values: King 500, Queen 150, Rook 75,
    Knight 50, Bishop 50, Pawn 25.
  - Full-width **HISTORY** block (yellow heading): "Galactic Chess Invaders began as a demo prototype in
    1983 on the Apple II, written in TASC compiled BASIC. Now, with the help of Claude, you can experience a
    modern, recharged version."
  - Footer: color legend `● YOU · WHITE` (cyan) / `● ENEMY · BLACK` (magenta) and an `ESC OR ◄ BACK TO RETURN`
    hint.
- **Chrome:** A **◄ BACK** chip in the **top-right corner** (same position as the gameplay INFO chip, so the
  eye doesn't travel). ESC also returns.

### 3. Gameplay — Level 1 / Wave Start
- **Purpose:** Start-of-level clean state.
- **Layout:** Full chess opening position (all 32 pieces) at the grid coords above. HUD top bar:
  `SCORE 000000` (left, cyan glow), `HI 012300` (yellow), `LEVEL 01` (center), and 1–3 player-ship life icons
  (right). A lone green Raider Scout cruises the top fly-in lane. Player ship centered near the bottom.
  Turn-timer indicator (▼ + seconds) bottom-left, green when full. **INFO chip** top-right.
- **HUD bar:** 46px tall, subtle cyan bottom-border, faint top-down gradient.

### 4. Gameplay — Piece Selected
- **Purpose:** Shows the chess move-selection affordance + timer pressure.
- **Layout:** A mid-game position. One piece (e.g. a bishop) shows a **pulsing cyan selection halo**; its
  legal destination squares are marked with **green crosshair reticles**. The last move shows a fading orange
  motion-trail. The turn timer is in its **warning state** (red, pulsing, ~1s left). INFO chip top-right.

### 5. Gameplay — Mid-Combat (Level 3)
- **Purpose:** Peak-action vignette.
- **Layout:** A descended, thinned black fleet (fewer pieces, some **battle-damaged** — outline partially
  blown away, fracture lines, sparks). Player laser **beam** striking and destroying an advancing black pawn
  (capsule-tipped cyan trail + fireball). Incoming **enemy bolts** (magenta, including a diagonal). A diving
  Galaxian Escort with an orange comet-tail shot. A falling **shield power-up** (cyan diamond/hex). Timer red.
  Score/level reflect deeper progress (e.g. SCORE 047250 / LEVEL 03 / 2 lives). INFO chip top-right.

### 6. Game Over
- **Purpose:** End state.
- **Layout:** Large red "GAME OVER" (Press Start 2P, magenta glow, slow pulse). A stats row:
  **FINAL SCORE** (white), **HI-SCORE** (yellow), **LEVEL REACHED** (cyan). The player ship's final **fireball**
  + drifting debris near the bottom. Blinking "PRESS FIRE TO PLAY AGAIN" (white) and an "ESC — MAIN MENU" hint.

---

## FX language (recreate as SKEffectNode / SKAction / SKEmitterNode)
- **Neon bloom:** every glowing element = clean shape under a gaussian-blur effect node, additive. Multi-pass
  (wide soft + tight bright) reads best.
- **Player laser (Beam):** a luminous vertical line, white-hot core, with an outlined **capsule head** at the
  impact point. Cyan.
- **Projectiles (Bolt):** outlined capsule head + a fading line trail behind it, oriented along travel dir.
  Enemy = magenta; escort shot = orange; some diagonal.
- **Explosion:** traditional arcade **fireball** — white-hot core, billowing orange→red flame lobes, soft
  outer glow, radial yellow **debris dashes**. King/mothership blast adds a shockwave ring. (Deliberately
  *less* strict-vector than the pieces — it should look like a real "boom".)
- **Damage (progressive):** as a piece takes hits, **omit/erase the lower portion of its outline** along a
  ragged break line that rises each hit (don't just poke interior holes), add bright **fracture/“shattered
  glass” lines** through the remaining upper body, and **dash sparks** along the broken edge. Tiers d1/d2 are
  pre-baked in the atlas; Path B can do this continuously.
- **Reticle:** pulsing green crosshair circle on legal move squares.
- **Selection halo:** pulsing cyan ring around the selected piece.
- **Shield pickup:** slowly bobbing cyan diamond/hexagon outline.
- **Turn timer:** ▼ + integer seconds, green→yellow→red as it runs down, pulses red in warning.

## Starfield / background
- Pure-black base. Two parallax star layers (far: ~150 white 1px dots scrolling slowly; mid: ~60 larger
  cyan/white 2px dots scrolling faster), looped vertically.
- Faint nebula: a few large blurred radial gradients (cyan, magenta, blue) at low opacity, slowly drifting.
- A couple of slowly-rotating wireframe debris polygons (Asteroids-Recharged flavor), very low opacity.
- Optional: a subtle perspective grid that gently warps (mentioned as a future-nice-to-have).

## Interactions & Behavior
- **Dual control:** chess move input (click piece → click destination) AND real-time ship control
  (left/right + fire) are both live. A **turn timer** (default ~5s) forces the chess side forward; if it
  expires the CPU moves.
- **Win a wave:** destroy all black pieces (by laser or chess capture); shooting the black King ends the wave
  with a bonus.
- **Lose a life:** ship hit by enemy fire, or an invader reaches the bottom row. 3 lives.
- **Navigation:** Title → (any key) → Gameplay. Gameplay → INFO chip / dedicated key → How To Play → BACK/ESC
  → Gameplay. Game Over → Fire → restart; ESC → Title.
- **Reduced motion:** the prototype disables animations under `prefers-reduced-motion`; honor the macOS
  "Reduce Motion" accessibility setting.

## State Management (suggested, see full design doc for authoritative rules)
- Board state (piece positions + per-piece HP — pieces have hit points; HP resets each level).
- Fleet motion state (sweep direction, descent step, fire cadence).
- Player: position, lives, active power-ups (e.g. shield), score, hi-score, current level.
- Turn timer; whose chess turn; selected piece + legal moves.
- Screen/route: title / playing / help / gameover.

## Assets
- `GCI.spriteatlas/` — all pieces (both sides + damage tiers) and ships, clean PNGs. Drop into Xcode.
- `assets/1983-title.jpg`, `assets/1983-game.jpg` — the original 1983 Apple II screenshots (history page only).
- **Fonts to bundle:** Press Start 2P (OFL, free) + a monospace (SF Mono ships with macOS).
- No other raster art — everything else is drawn procedurally (starfield, FX, chrome).

## Files in this bundle
- `README.md` — this document (self-sufficient).
- `docs/gci-game-design.md` — full game-design spec (mechanics, scoring, levels, audio).
- `Galactic Chess Invaders - Screens.html` — all six screens on a pan/zoom canvas (the master visual ref).
- `GCI Sprite Sheet.html` — every piece/ship + damage states + explosions, labeled.
- `sprites.js` — pixel maps + the vector/contour/damage renderer (authoritative sprite logic).
- `gci-shared.jsx` — palette, layout constants, starfield, HUD, FX components (React/Canvas reference).
- `screens.jsx` — the six screen compositions (layout reference).
- `GCI.spriteatlas/` — the production sprite atlas.
- `assets/` — the 1983 reference screenshots.

> Tip for the Claude Code session: start by reading `README.md` and `docs/gci-game-design.md`,
> open `Galactic Chess Invaders - Screens.html` in a browser to see the target, then drop `GCI.spriteatlas`
> into the Xcode project and build screen-by-screen (Title → Gameplay → HUD → FX → Help → Game Over).
