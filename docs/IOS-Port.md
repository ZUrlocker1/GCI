# Porting Galactic Chess Invaders to iPad and iPhone

*Written 13 September 2026 against v1.1. Rewritten 1 October 2026: the layout refactor
and Phase 1 are built and shipping, iPad is done, and the roads not taken have been cut
back to the reasoning that still earns its place. What is left is the phone.*

---

## The short version

The architecture rules in `CLAUDE.md` were followed, and they paid off. The Logic layer
imports no SpriteKit and no AppKit. Every input already arrives as a `GameAction`. The
whole of the macOS coupling is six call sites.

The obstacle is not platform APIs. It is **geometry**. The scene is a fixed 960×700
canvas scaled with `.aspectFit`, and every layout number in the game is a literal
measured against it — the board is 512pt because a square is 64pt, the gutter is at
x=112, the ship lane is at y=62. That works on one Mac window and on iPad landscape by
luck. It does not survive portrait, and it wastes a third of an iPhone screen.

So the port was one substantial refactor — make the scene lay itself out from its own
size — followed by increasingly fiddly device passes. **The refactor shipped in 1.2**
(§3), and **iPad is done**: the game plays by touch, Test Mode has a door that needs no
keyboard, and all five iPad sizes have been checked in both orientations (§5). iPad
portrait was closed as unnecessary rather than built, because the restructure it called
for turned out to be answering a gutter bug rather than a shape problem.

**What is left is the phone**, and it is where the geometry actually bites: 393pt has no
room for a left gutter at all, and that is the one case the uniform-scale approach could
never have served.

---

## 1. What is already portable

| Layer | State | Notes |
|---|---|---|
| `Game/Logic/` | **Clean** | 20 files import only Foundation and CoreGraphics. Zero SpriteKit, zero AppKit. |
| `GameAction` | **Clean** | 16 cases covering movement, firing, chess selection, menus. Platform-agnostic already. |
| `AudioManager` | Nearly | AVFoundation is cross-platform; needs an `AVAudioSession` on iOS (see §6). |
| Sprites | **Clean** | Flat PNGs at @2x, loaded by name. Scale to any square size. |
| Font | **Clean** | Press Start 2P is bundled, 116KB. |
| Assets | Fine | 27MB total, 22MB of it music. Comfortable for iOS. |

**One leak to fix:** `Game/Logic/GameState.swift` imports SpriteKit and GameplayKit,
which breaks the layer rule. It is there for `GKStateMachine`. GameplayKit is available
on iOS so it is not a portability blocker, but it is the one file that would stop the
Logic layer compiling into a pure-Swift target, and that matters if we ever want logic
tests without a rendering host.

### The complete macOS coupling

```
GameScene.swift          keyDown, keyUp, mouseDown, mouseDragged, mouseUp   (5 overrides)
HighScoreEntryNode.swift handleKey(_ event: NSEvent)                        (1 method)
HowToPlayNode.swift      NSColor.white, NSWorkspace link open               FIXED 13 Sep
InputHandler.swift       already wrapped in #if os(macOS)
App/                     ContentView, App, LogTextView — the shell, expected
```

Six things outside the app shell, and five of them are one method each.

---

## 2. The geometry problem

*Describes 1.1, which is what this was written against. 1.2 changed it — see §3,
including why, what it cost, and how to put it back.*

The scene was created once at 960×700 and scaled to fit:

```swift
let scene = GameScene(size: CGSize(width: 960, height: 700))
scene.scaleMode = .aspectFit
```

960×700 is an aspect ratio of **1.371**. Here is what `.aspectFit` does with that on
each target, in points:

| Device (landscape) | Screen | Ratio | Wasted |
|---|---|---|---|
| iPad Pro 13" | 1366×1024 | 1.334 | 3% — thin letterbox top and bottom |
| iPad Pro 11" | 1194×834 | 1.432 | 4% — thin pillarbox |
| iPad 10.9" | 1180×820 | 1.439 | 5% |
| iPad mini | 1133×744 | 1.523 | **10%** — noticeable pillarbox |
| iPhone 16 Pro | 852×393 | 2.168 | **37%** — a third of the screen is black |
| iPhone SE | 667×375 | 1.779 | 23% |

Portrait is worse. An iPhone 16 Pro in portrait is 393×852. Fitting a 1.371 landscape
canvas into it scales to 41%, leaving the game occupying 286pt of 852 — **66% of the
screen unused**, and every piece rendered at less than half size.

**This is the headline finding.** iPad landscape works almost by accident because 4:3-ish
tablets happen to sit near 1.371. Nothing else does. Portrait is not a scaling problem,
it is a *different layout*, and pretending otherwise will produce an unplayable phone
game.

### What the space is used for now

```
0        224                      736      960
├─gutter──┼────── board 512 ───────┼─gutter─┤
   left                              right
```

The left gutter carries the turn timer, check/checkmate banner, power-up alley and the
new Chess and Arcade Hints. The right gutter is empty in play — it exists because the
board is centred. On a phone in landscape those two gutters are where the extra width
should go; on a phone in portrait there is no room for either.

---

## 3. The core refactor: a layout value — **done, both stages**

*Shipped in 1.2. What follows describes the design as built; the lessons at the end
of this section are the ones that will repeat on iOS.*

`SceneLayout` is the single home for every position in the playfield, derived from
the size the scene actually has. `scaleMode` is `.resizeFill`, so the scene *is* the
view rather than a fixed canvas scaled into it. `didChangeSize` repositions.

**The rules the layout settled on**, all of which iOS inherits:

- **Three bands.** A HUD strip at the top and the ship's lane at the bottom stay
  fixed in points; only the board flexes between them. The chrome holds type and
  the ship, and neither should shrink because a window got shorter.
- **The board is capped at 96pt squares**, one and a half times the design 64.
  Letting it fill the space gave 176pt squares at 1900pt wide and the composition
  fell apart, because everything around it is a fixed size. Capping at the design
  64 went too far the other way and left most of a full-screen laptop black.
  Beyond the cap, extra space becomes gutter rather than board.
- **Only the left gutter is reserved** — 224pt — plus 24pt of breathing room on the
  right. Reserving a second full gutter on the right, where nothing is drawn, cost
  the board 200pt it never needed. This will matter more on a phone than it did on
  a Mac.
- **Square size floors to whole points**, or grid lines land on fractional spacing
  and alias into a dashed mess.
- **The layout clamps its own input** to a 480×360 minimum. Under `.resizeFill` a
  scene really is handed a zero size before its view lays out — the diagnostics log
  shows `Screen: 0×0` on every launch — and clamping once inside the layout beats
  guarding at every consumer.

**Rescaling is real, not deferred.** `BoardNode.relayout()` rebuilds the lattice,
bands, labels, selection ring and marker pool at a new square; `PieceNode.adopt()`
re-fits art, damage wedge and physics body. Pieces keep their squares, so a game in
progress survives a resize. It is debounced by 0.2s — a window drag would otherwise
remake the board sixty times a second.

### What this cost, and what iOS should expect

Three classes of bug came out of it, and every one will recur on a device that
rotates:

1. **Anything positioned once against the scene centre gets stranded.** The title
   screen, both panels, and then PAUSED / GAME OVER / LEVEL CLEARED / the quit
   prompt / the high-score entry. That is now a registry — `registerCentredOverlay`
   records a node's offset from the middle and a resize puts every one back — so a
   new overlay gets it for free. **Use it for anything new.**
2. **Anything composed at a fixed size needs scaling, not just moving.** The panels
   and the title are laid out against 960×700 and are scaled to fit with a black
   shade behind. Their own backdrops only ever covered their own design size, which
   is why the title used to show around them.
3. **Anything anchored to the left breaks on a narrow screen.** The SET / INFO pair
   was composed at fixed x against a 960-wide canvas, which anchored it to the left
   — invisible until the canvas stopped being fixed, then it clipped off a narrow
   scene and collided with the log sidebar's toggle. `HUDNode.navOriginX(forSceneWidth:)`
   anchors it right. **Portrait on a phone is the narrow case, repeatedly.**

4. **Anything drawn in design points on the playfield has to be told the scale.**
   Under `.aspectFit` every pixel of the game scaled together for free. Under
   `.resizeFill` only what reads the layout scales, and the rest silently keeps
   its 64pt-board size: the player ship, laser rounds, raider scouts, score pops,
   the power-up name flashed at a kill, AUTO over a moved piece, explosions and
   glass, the legal-move dots, the coordinate labels, the check path, the charge
   telegraph, the Nuke's shockwave — and the screen shake, whose 30pt is half a
   square at the design size and a third of one at 96. All of it now reads
   `SceneLayout.contentScale` (or `BoardNode.scale` for what is drawn on the
   board) **at the moment it draws**, which matters because the pools outlive any
   one board size. Anything new that is drawn in points rather than in squares
   needs the same treatment.

A fifth, subtler one: **a stored `static let` that reads the geometry freezes it.**
`gatlingCeiling` was computed once at first access and then insisted the seventh
rank was somewhere it was not. Making a constant variable turns every copy of its
value into a latent bug, and they only surface where something reads them.

### Why this was done at all, and why the Mac paid for it

The answer is not "the old way was broken". A fixed canvas under `.aspectFit` is one
image scaled uniformly, so fonts, banners and missiles resized together by construction
— there was no per-element work to get wrong. Every resize bug the refactor caused is a
bug it created.

**Where `.aspectFit` genuinely fails is legibility, not letterboxing.** A uniform scale
shrinks type along with the board, and the HUD and gutter already run at 8–11pt:

| Target | Uniform scale | 9pt type renders at |
|---|---|---|
| iPad 12.9" landscape | 1.42× | 12.8pt |
| iPad mini landscape | 1.06× | 9.6pt |
| iPhone landscape | 0.56× | **5.0pt** |
| iPhone portrait | 0.41× | **3.7pt** |

So the refactor was unnecessary for macOS and iPad landscape, marginal for iPad
portrait, and **genuinely required for iPhone**. Below roughly 0.7× the game stops
being readable however much screen is left.

**Two things worth carrying forward.**

*The sequencing was the mistake, more than the decision.* `scaleMode` is one line per
platform. macOS could have stayed on `.aspectFit` until an iOS target existed and the
responsive layout had been proven there; doing it on the shipping platform first paid
the destabilisation cost where none of the benefit lands.

*The fallback is still one line.* `scene.scaleMode = .aspectFit` in `GameScene.shared`
pins the scene at 960×700 forever, `SceneLayout` returns its design values, and macOS
renders exactly as 1.1 did. Worth remembering if a Mac release ever needs the safe path
in a hurry. The cheaper design never taken — keep `.aspectFit` and swap the *canvas*
per orientation, two or three rigid canvases each scaled uniformly — remains the
fallback to reconsider if the phone passes prove harder than §5 expects.

**Two stage-2 hazards that are still live constraints**, now that the layout is
size-dependent: `squareSize` must stay a whole number of points or a 1pt grid line
aliases (it is floored, with the remainder centred), and `didChangeSize` fires
continuously during a live window drag, so the layout has to be cheap to recompute
rather than rebuild nodes.

---

## 4. Input

The ask is narrow and that helps: horizontal ship movement, and fire. Two axes of one
stick and one button.

### What was considered, briefly

**`GCVirtualController`** (iOS 15+) was the obvious default: it disappears when a
physical controller connects, `GCKeyboard` comes free, and it needs no art. Not taken —
it is an unrestylable translucent grey system d-pad over a neon vector game, and the
scheme that shipped was comparable work. The input layer is one adapter either way and
`GameAction` means nothing downstream would know the difference, so this stays the
fallback if the built scheme ever needs replacing.

**What shipped touch conversions of one-axis shooters actually do** settled two
questions. Direct drag beat the virtual d-pad everywhere — a d-pad gives no tactile
edge, so a thumb drifts off it and the player finds out by dying — and most use *offset*
drag, where the ship tracks the finger's movement rather than sitting under it. Also
near-universal: **auto-fire**, which GCI cannot have. See below.

### Why GCI cannot just copy that

**The screen is also a chess board.** Drag-anywhere assumes the whole surface is a
movement pad; here taps on the board select and move pieces. So the drag region is
bounded to the ship's lane and the space below the board — `point.y < boardBottomY`,
which is the band the layout already reserves as `shipBandHeight`. That is a reason to
keep that band generous on a phone rather than trimming it to grow the board.

**Auto-fire would be actively harmful.** In every game that uses it, the only things in
front of you are enemies. In GCI your own pieces sit in your firing line on every shot
— that is what the friendly-fire hint exists to teach. Auto-fire would demolish White's
position without the player choosing to. So the dominant touch-shmup solution is not
available, and GCI keeps an explicit fire control.

**Decided and built: drag in the ship's lane with the left thumb, a fire button under
the right, and no auto-fire.** Landscape puts both thumbs in the bottom corners already,
and the button sits in the right-hand margin — space the layout has spare and the Mac
uses for nothing.

*As built* (`TouchInputAdapter`, `FireButtonNode`):

- **Every touch is tracked by identity.** `touches.first` was the first version and it
  makes the two thumbs fight — a right thumb resting on FIRE becomes "first" and steals
  the left thumb's drag.
- **The drag is offset, not absolute**, fixed at the moment of the grab. Absolute
  mapping snaps the ship to the finger, so grabbing the thing you want to move puts your
  thumb over it. The ship travels on one axis, which makes the vertical half of the
  offset free: it stays in its lane however low you hold.
- **One to one with the finger**, clamped to `shipLane`, not routed through ship speed —
  dragging *is* the position, so a multiplier would leave the ship trailing the thumb.
  The Settings speed slider therefore governs the keyboard and a controller, not touch.
- **A finger that starts on FIRE keeps firing wherever it slides**; lifting stops it.
  Expecting a slide-off to stop is a desktop habit, and mid-fight it reads as a jam.
- **The button is sized to the margin, not the board** — 80pt portrait, 114 landscape.
  Scaling it by `contentScale` put a 114pt button in a 96pt margin and the screen edge
  cut it in half. Its touch target is half again the drawn circle.
- Both controls are live only during play and come and go with the HUD.

**Chess pieces drag too**, with tap-then-tap still working. It is what every phone chess
app has taught people, and one gesture instead of two while the clock runs. Which leaves
one consistent rule: **on iOS you drag things** — the ship in its lane, a piece to its
square. The only tap is the fire button.

### Testing for playability

Not a simulator job. The things that decide this cannot be seen on a desktop:

- **Occlusion.** In portrait a thumb covers the bottom rank. That is where White's
  back rank lives, and where the ship is. Worth checking before committing to
  portrait at all.
- **Thumb reach.** On a large phone the top of the board is not reachable one-handed.
  Chess selection may need the other hand, which changes the whole control scheme.
- **Tap targets.** Apple's floor is 44pt. A square below that fails; §4's layout has
  to enforce it and the port should measure the real number on each device.
- **A case.** Phones live in cases, which changes where the edges are.
- **The five-second clock is the real test.** The Mac build is playable because a
  mouse click is precise and instant. If selecting a piece on glass takes two
  attempts, the beat expires and the engine moves for you — which is a worse game,
  not a slower one. **If one metric decides whether the phone port ships, it is the
  proportion of beats where the player completes their own move.**
- **Cadet first.** Test on Cadet, which is the default and gives a seven-second beat.
  If it is not playable there it is not playable.
- **The 44pt floor is a layout requirement, not a guideline.** A square below it fails
  Apple's guidance, and on an iPhone in portrait a square could be 40pt. `SceneLayout`
  enforces `minSquareSize`, and a small tap-tolerance margin around each square is worth
  adding on touch.

### What becomes unreachable, and what shipped instead

Every hotkey is an `NSEvent` in `GameScene.keyDown` or `InputHandler`. On a phone there
is no keyboard; on an iPad there may or may not be one.

**Decided: the handlers stay, the affordances go.** Every `keyDown` path is kept, so an
iPad in a Magic Keyboard behaves exactly as the Mac does, `⌘T` and the test keys
included. What does not survive is the *advertising* — the underlined hotkey letter in
`SET` and `INFO` comes off on iOS unconditionally, because a button that sometimes
claims a shortcut is worse than one that never does.

**The copy that named keys was rewritten**: `TAP TO START`, `TAP TO RESUME`, `TAP BACK
TO RESUME`, `NEW GAME?` over `YES` / `NO`, `TAP THE FIRE BUTTON!`, `DRAG TO MOVE SHIP!`,
and a CONTROLS list that leads with `DRAG` / `FIRE` / `TAP` and relegates keys to
`Optional:`. Where a keyboard *is* attached the Mac wording is still better, so these are
one function returning either string rather than two code paths.

**One row of that audit was hiding a hole**, and the audit's own framing is what hid it:
every other line was a control that existed and was named wrongly, while
`HighScoreEntryNode` read `KeyPress` and nothing else. A touch-only player who made the
table could not enter a name at all — a tap fell through to `resetToTitle` and the run
recorded blank.

**Built: the system keyboard, via `NameEntryField`.** A 1×1 `UITextField` with clear
colours, holding first responder only while the entry screen is up; input uppercased and
filtered to printable ASCII, because Press Start 2P has glyphs for nothing else. The
scene still draws the name — the field is a keyboard, not a text box. Four things are
load-bearing, all found on device:

1. **It is summoned by a tap, never automatically.** iOS's *first* keyboard presentation
   in a session measured 690ms, 744ms and 4418ms on an A12 — main thread blocked, 5fps,
   audio distorting throughout. Asking for it while showing the panel put that on the end
   of a winning run.
2. **The cost is paid on the title screen.** `warmKeyboard()` becomes first responder and
   resigns in the same turn, two seconds after the title draws. The title screen
   specifically, because every run passes through it before a score exists — you can die
   on level 1 and make the table.
3. **`claimKeyboard` stands down while name entry is active.** `GameView.updateUIView`
   claims the keyboard on every SwiftUI pass and the log panel is `@Observable`, so every
   logged line took first responder straight back off the field.
4. **The overlay lifts clear of the keyboard** by half of what it covers, from
   `keyboardWillChangeFrameNotification` intersected against the view's bounds — which
   handles iPad's floating and split keyboards by the same path as the docked one.

A **DONE** button is the only way off the screen when no keyboard appears — a connected
but flat hardware keyboard is enough for iOS to suppress the software one. It submits
rather than discards, and an empty field falls back to PLAYER.

#### Test Mode without `⌘T`

**Built: click and hold the version badge, and Test Mode ships in the release build.**
The version is drawn on the play screen, **top-left in the band under the HUD bar**, as a
bordered chip. It earns its place twice: a tester reads the build number straight off the
screen, and the gesture has something real to aim at. The badge is also the indicator —
cyan at rest, orange while Test Mode is on, with a bar sweeping it while held.

**Top-left rather than the bottom corner**, for a reason that still binds the iPhone
passes: `isInShipLane` claims *every* touch below the board across the full width
(`point.y < boardBottomY`), so a control down there never sees the press without its own
exception ahead of the lane test. The bottom-left also already holds `ERROR - SEE LOG` at
(50, 30), and the iOS host sets `ignoresSafeArea` so the scene runs under the home
indicator. The band under the HUD has none of that: `hudBandHeight` 68 against a 36pt bar
leaves a clear strip at every size, and nothing claims touches there.

**A ~1.5s hold to arm, a plain tap to clear.** The hold stops a player stumbling in, and
that argument is spent once they are in — asking them to hold again on the way out is
ceremony with nothing left to protect. Two implementation notes, both bugs that were
fixed: the direction has to be read at *touch-down*, since the hold fires while the
finger is still down and a lift that re-read the flag would toggle straight back; and the
deadline must not hang off an `SKAction`, or it only fires while the scene happens to be
ticking — on a freshly launched Mac it never did.

Counted taps, a multi-finger press, a shake and a Settings row were all considered and
rejected: respectively no mid-gesture feedback, nothing to aim at, fires by accident in a
game played in motion, and 1.2 moved the log panel *behind* Test Mode precisely because
players opened it by accident.

**`⌘T` stays wherever a keyboard is attached**, and both doors reach the same
`testMode.toggle()`. On iOS Test Mode doubles as a cheat code — a player stuck on a wave
can skip it rather than put the game down — which is the argument for shipping it rather
than hiding it in a separate configuration testers cannot report against.

#### The debug keys — `L`, `A`, `P`, `R`, `V`

They split by kind, and the split is the design:

- **Toggles.** `L` (diagnostics panel) and `A` (Auto Chess) persist, and **Settings
  already carries both** — the log row behind `SettingsNode(showsLogRow: testMode)` and
  the CHESS `YOU PLAY / AUTO` row. Nothing to build.
- **Momentary actions.** `P`, `R` and `V` fire *during play* and are meaningless from a
  modal panel. **Built as `TestModeStripNode`**: `POWER · RAID · LEVEL` chips under the
  badge, present only while Test Mode is on and greyed outside `PlayingState`, so a
  player never sees them and a tester never presses a dead one. They shorten to
  `PWR · RAID · LVL` when the gutter is too narrow for the words.

Both the badge and the chips ship on **macOS as well** — the behaviour is identical on
both platforms, which is why the Info screen describes one thing rather than two.

**Open for Pass 4:** the left gutter is gone in iPhone portrait, so the chips need a home
there, or a single `⚙` that expands.

---

## 5. The device passes

### Pass 1 — iPad landscape

The easy one, and the right place to prove the layout refactor. Range is 1.334 to 1.523,
all within reach of the existing composition. The board stays centred, the left gutter
stays where it is, and the extra width at the iPad mini end goes to the gutters rather
than to black bars.

Test on iPad Pro 13", iPad Pro 11", iPad 10.9" and iPad mini, in the simulator, then on
the physical mini — the mini is the tightest of the four and the one you own.

### Tested on — 1 October 2026

Five sizes, both orientations, after the gutter change. The simulators were
driven with `xcrun simctl`; the mini 5 is the physical device and the only one
with real hardware timings behind it.

| Device | | Portrait | Board, portrait | Board, landscape |
|---|---|---|---|---|
| iPad Pro 13-inch (M5) | simulator | 1032×1376 | 712 → **720** | 768 |
| iPad Pro 11-inch (M5) | simulator | 834×1210 | 512 → **560** | 640 |
| iPad (A16) | simulator | 820×1180 | 496 → **552** | 632 |
| iPad mini (6th gen) | simulator | 744×1133 | 424 → **488** | 552 |
| **iPad mini 5 (A12)** | **device** | 768×1024 | 448 → **512** | 576 |

Portrait figures are before → after the gutter change; landscape is unchanged
at every size, because the square is already at its 96pt cap and nothing was
over-reserved. The A16 was measured from a native capture rather than by eye:
board 552pt, left gutter 168, right margin 96 — both reservations are binding,
so there is nothing further to reclaim there.

Note the two minis are **not** the same size. The 6th generation is 744×1133;
the mini 5 is 768×1024, which is a different aspect as well as a different
width, so both are worth keeping in the sweep.

`UIRequiresFullScreen` is `true`, so none of this has to survive Split View,
Stage Manager or a resizable iPad window — the app is always full screen.

---

### Pass 2 — iPad portrait — **closed: not needed**

3:4 rather than 4:3. The board can stay large; what changes is that the vertical space
above and below it is generous and the horizontal space is not.

The plan here was to move the readouts from the left column to a **bar above the board**,
with the power-up alley and hints beneath it. **That is not being built.** It was written
when portrait meant a 424pt board inside a 744pt screen, and the reason it looked
necessary was a bug rather than a shape: `minGutterWidth` reserved a flat 224pt at every
size, which is what the gutter needs at the *largest* square the game allows. Portrait
draws the same readouts at the 0.9 scale floor, where they need about 145 — so roughly
80pt of every portrait screen was reserved for nothing and showed as dead space down the
left.

The reservation is now `130 * gutterScale + 28`, solved against the square it implies.
Portrait boards grew 48–64pt on every iPad from the mini to the 11-inch, 8pt on the
13-inch; landscape and the 960×700 design canvas are unchanged, because their square is
already at the 96pt cap and nothing was over-reserved. Nothing moved — the gutter keeps
its position and its contents.

So the restructure buys a second layout to maintain and an inconsistent look between
orientations, for a board that is already competitive. **Decision: keep one composition
across both orientations on iPad.** The top-bar idea is not wasted — it is what Pass 4
needs on iPhone, where 393pt genuinely has no room for a gutter.

`GeometryReader` still earns its place for the SwiftUI chrome and safe-area insets, not
for the scene, which reads its own size in `didChangeSize`.

`GutterFitTests` measures the real `ChessHintNode` and `GameStatusNode` at nine sizes and
pins 4pt of clearance from the board's rank labels — the guard against the earlier squeeze
that clipped "OR KNIGHT" off the left edge of an iPad.

### Pass 3 — iPhone landscape

2.17:1 on modern phones. Very wide, not very tall. The board is height-constrained, so
it will be small; the compensation is that both gutters become usable.

Layout: board centred, readouts in the left gutter as on the Mac, and the right gutter
finally earns its keep — power-ups, or the hints, or the score.

Watch the safe areas. In landscape, the Dynamic Island eats one end and the home
indicator the bottom edge, and the ship lane lives exactly where the home indicator
wants to be. The ship lane needs to respect `safeAreaInsets.bottom` or people will
swipe the app away mid-wave.

### Pass 4 — iPhone portrait

The hard one, and the one to decide honestly rather than force.

At 393pt wide, a 44pt minimum square gives 352pt of board — it fits, just. But there is
no room for a left gutter at all, which is what you already suspected.

Three options:

1. **Top bar for everything.** Score, level and turn timer in a compact strip above the
   board; hints and power-ups in a strip below it. Most information preserved, tightest
   fit.
2. **Drop the gutter text, keep the signals.** Check and checkmate become a brief banner
   over the board rather than a persistent readout. Chess Hints keep the glow and lose
   the words — the glow is the more useful half anyway, as this week's work showed.
3. **Do not ship portrait on iPhone.** Lock the phone build to landscape. Plenty of
   arcade games do. It costs nothing and avoids a cramped mode that reviews badly.

**My recommendation is 2, with 3 as a legitimate fallback.** The pulsing pieces survive
losing their caption; the caption does not survive losing its space.

### Pass 5 — iPhone Duo

Announced September 2026, **shipping 23 October 2026** — so this is no longer guesswork,
and a simulator already exists. **Decided: GCI runs full screen on whichever display is
active.** No two-screen mode, no side-by-side, no treating the fold as multitasking.
`UIRequiresFullScreen` stays `true`.

**The simulator shipped in the Xcode 27.1 beta on 18 September**, five weeks ahead of the
hardware — the Vision Pro pattern rather than the usual few-days-ahead one. It needs
Apple silicon and macOS 26.6 or later, which this machine meets. Three things about it
change the work below:

- **It simulates *poses*, not two sizes.** Open, closed, rotation and *partial* folding,
  driven from on-screen controls. The four-state table below is therefore the corners of
  a continuum, not the whole story — see "folding while running".
- **The controls live in Device Hub**, which is the component that would not launch on
  this machine after the Xcode 27 install went wrong. Fixing that is a prerequisite for
  any Duo work, not an optional tidy-up.
- **SDK floor.** Apps built against the iOS 26 SDK need rebuilding against iOS 27 for
  basic Duo support, and against **iOS 27.1 or later** to take full advantage of the
  larger display. GCI 1.3 was built with Xcode 27.0, so it should have basic support;
  what "full advantage" buys has to be confirmed rather than assumed.

#### The numbers

From Apple's own specifications:

| | Diagonal | Pixels | ppi |
|---|---|---|---|
| Outer (cover) | 5.4" | 1398 × 2034 | 460 |
| Inner (unfolded) | 7.6" | 1878 × 2670 | 430 |

Folded 117.8 × 84.1 × 11.3 mm; open 164.6 × 117.8 × 5.2 mm.

**In points, at ×3 — which is an inference, not an Apple figure:**

- **Outer: 466 × 678 pt**
- **Inner: 626 × 890 pt**

Apple has not published point dimensions. The scale factor is derived from the pixel
counts and the density used on its 460-ppi iPhones; an independent developer write-up
reaches the same numbers. Everything below rests on it, so it is the first thing to
confirm when the simulator ships.

#### Where the current layout stands

GCI's composition cannot go below **497 × 444 pt** — a 145pt gutter at its smallest
type, a 256pt board at the 32pt square floor, and a 96pt right margin.

| State | Size | Square | Board | Verdict |
|---|---|---|---|---|
| Outer portrait | 466 × 678 | 32 | 256 | **overflows by 31pt** |
| Outer landscape | 678 × 466 | 34 | 272 | fits, 165pt spare |
| Inner portrait | 626 × 890 | 48 | 384 | fits — 129pt above the minimum |
| Inner landscape | 890 × 626 | 54 | 432 | fits, 217pt spare |

**Three of the four states already work**, and the inner display — where the game will
actually be played — is comfortable in both orientations. A 48pt square in inner
portrait is larger than an iPad mini gave before the gutter change in 1.3.

**Only the folded cover display fails, and only by 31pt.** That is a third of iPhone
portrait's 104pt shortfall. Folded, the Duo is a slightly roomier iPhone, and it is the
same problem Pass 4 exists to solve.

#### Why the cheap fixes are not good enough

The obvious tweaks all land in the same uncomfortable place:

| Remedy | Spare at 466pt | Square |
|---|---|---|
| Right margin 96 → 80 | −15pt | still fails |
| Right margin 96 → 65 | 0pt | 32 |
| Min square 32 → 28 | +1pt | 28 |
| Min square 28 + margin 80 | +17pt | 28 |

Every one of them buys the fit by shrinking the square to 28–32pt. Apple's touch
guidance is 44pt, and GCI punishes a mis-tap specifically: the five-second clock expires
and the engine moves for you. A 28pt chess square under a running clock is a worse game,
not a smaller one.

**Pass 4's restructure is the answer**, and the gap is not close:

| Side margins | Board | Square |
|---|---|---|
| 16pt | 432pt | **54pt** |
| 24pt | 416pt | **52pt** |
| 32pt | 400pt | **50pt** |

Moving the readouts to a bar above the board turns a 28pt square into a 50–54pt one on
the same display. So the cover display is not separate work — **solve iPhone portrait
and the Duo's folded state comes free**, with far more headroom than the phone has.

#### The genuinely new work: folding while running

This is the part no other device asks for, and it is the real risk. `SceneLayout`
recomputes from whatever size it is handed and `didChangeSize` is wired, so the geometry
is in good shape. The rebuild code *around* it is not proven:

Three bugs in the resize path turned up in a single day on 1 Oct, all found by resizing
a Mac window by hand — `applyLayout()` rebuilding the HUD and resurrecting the nav
buttons and FIRE over open panels; the version badge's sweep bar drawing 134,000pt wide
because a sprite's `size` was assigned while its `xScale` was mid-animation; the Test
Mode chips running onto the board once the gutter narrowed.

A folding phone exercises that path several times a session, mid-game and mid-panel, not
once at launch. Worse than that: the simulator exposes *partial* folds, so the scene may
be resized continuously through a hinge movement rather than jumping between two sizes.
That is the same shape as a live Mac window drag, which is exactly how all three of
those bugs were found.

Hardening it is the Duo-specific work:

- Every `applyLayout()` path must be idempotent and safe while a panel is open.
- Anything cached against size — `rebuildSky()`, the node pools, the version badge's
  wording, the chip row's compact/full choice — has to survive repeated flips.
- A fold during the high-score keyboard, during a wave banner, or mid-explosion are all
  states worth trying deliberately.

#### To verify when the simulator ships

Nothing below can be settled from published specifications.

1. **The point dimensions and scale factor.** Everything above assumes ×3. Confirm
   466 × 678 and 626 × 890 from `UIScreen` rather than arithmetic.
2. **One display or two.** Whether the Duo presents as a single `UIScreen` that changes
   size, or two screens. A resize is a layout problem; two screens is an architecture
   problem. This decides whether any of the above holds.
3. **What the app actually receives on a fold.** A `didChangeSize`, a scene disconnect
   and reconnect, or a full relaunch. Each needs different handling, and only the first
   is already covered.
4. **Safe-area insets on both displays** — the crease, any camera cutout, the home
   indicator. The ship lane lives exactly where a home indicator wants to be; §5 Pass 3
   already flags this for iPhone.
5. **Whether `UIRequiresFullScreen` is honoured** on a folding device, or quietly
   ignored the way iPadOS 26 windowing might.
6. **The size class the cover display reports.** Compact width would change what UIKit
   hands the SwiftUI chrome around the scene.
7. **Whether the cover display rotates at all**, or is portrait-locked by the hardware.
   The table above assumes both orientations are reachable.
8. **Touch-target reality on the cover display** at 460 ppi — whether a 44pt target is
   genuinely comfortable there, since the whole argument against the cheap fixes rests
   on it.

All of it is answerable today: install the Xcode 27.1 beta alongside the release Xcode
and run the Duo simulator. The sequencing argument is unchanged, though — Pass 4 is what
the cover display actually needs, and the phone needs it anyway.

---

## 6. iOS platform work that has no macOS equivalent

These are the things that are not in the current codebase at all because the Mac does not
need them.

**Audio session.** `AVAudioPlayer` on iOS needs an `AVAudioSession` configured and
activated. Decide between `.ambient` (respects the silent switch, mixes with other audio)
and `.playback` (ignores the switch, interrupts music apps). For a game with a
commissioned soundtrack, `.ambient` is the polite default with a Settings override.

Then handle **interruptions** — a phone call, a timer, Siri — via
`AVAudioSession.interruptionNotification`, and pause the game with the audio. None of
this exists today.

**App lifecycle.** Backgrounding on iOS is aggressive and common. `scenePhase` changes
must pause the beat clock and the fleet. The existing `maxFrameDelta` clamp already
protects against a large `dt` on resume, which is a good sign, but the game should pause
rather than rely on the clamp.

**Safe areas.** Every layout number needs to respect them. The ship lane, the gutters and
the HUD all currently assume a rectangle with no intrusions.

**ProMotion.** 120Hz displays on Pro devices. SpriteKit handles this, but every animation
using `SKAction` with hardcoded durations is fine while anything integrating `dt` needs
checking. The codebase is disciplined about `dt` already.

**Haptics.** Not required, but a laser fire and a piece destruction are natural taps.
`CoreHaptics` is cheap to add and makes an arcade game feel considerably better on a
phone.

**Diagnostics sidebar.** `LogTextView` is an `NSTextView` wrapped for SwiftUI. It needs a
UIKit twin or, more simply, a SwiftUI `ScrollView` of `Text` on both platforms.

---

## 6a. Render cost, and what to turn off on a small screen

> **The headline for iOS: it was the audio, not the graphics.** Everything below about
> the bloom is a *Mac* finding and it does not transfer. On an iPad mini 5 the frame
> rate was pinned by sound effects, and the graphics switches barely moved it. See
> **The SFX engine** immediately below before reading the rest of this section.

### The SFX engine

`AudioManager` plays effects through one `AVAudioEngine`, with every sound decoded once
at launch into an `AVAudioPCMBuffer` and a fixed pool of **8** `AVAudioPlayerNode`s left
running for the life of the app. Firing a sound is `scheduleBuffer` on a node that is
already going.

It replaced per-key pools of `AVAudioPlayer`, and the numbers are the reason — medians
of 20 on an M-series Mac, file already loaded, player reused:

| | |
|---|---|
| `AVAudioPlayer.play()` | **11.7ms**, every call, prepared or not |
| `prepareToPlay()` | 6.4ms, and saves 0.2ms off the next `play()` |
| starting a stopped `AVAudioPlayerNode` | 10.9ms |
| `scheduleBuffer` on a running node | **0.000ms** |

Two sounds in a frame was the entire 16.7ms budget. On the device, with effects on
under sustained fire at wave 10, `play()` went from that to **0.1–0.3ms**, holding
53–60fps where the Mac had been dropping to 45 and the iPad into the 20s.

Four things about the design are load-bearing:

- **One canonical format** — mono, 44.1kHz, float32 — converted at load. The assets are
  not uniform (two stereo, one 48kHz, one 96kHz) and a node is wired to the mixer in a
  single format, so converting once is what buys a *shared* pool. Per-key pools would
  need 134 keys' worth of nodes for the same polyphony. Resident cost: **8.2MB** for
  48.9 seconds of audio.
- **Eight voices, not more.** Every *running* node is pulled by the render thread each
  cycle and summed whether it has anything to play or not, so an idle pool is not free.
  24 overloaded an A12 — `HALC_ProxyIOContext: skipping cycle due to overload`, audible
  as distortion at the title screen with nothing playing. And they cannot be started on
  demand instead: that is the 10.9ms above.
- **Dropped, not stolen, when the pool is full.** Stealing a live voice measured 23ms.
- **The engine stops when SOUND FX is off**, rather than mixing eight silent voices
  every cycle.

`AudioEnginePathTests` pins both halves: firing costs under 1ms, and voices come back
when a sound ends — a pool that leaks them goes silent after eight sounds and nothing
else would notice.

### The Mac profile

Measured on an M-series Mac in ordinary play: **35–38% of one core**, holding 60fps —
about 6ms per 16.7ms frame, and the figure to carry into the port as the thing to beat.

**On the Mac the game is GPU-bound, and the bloom is why.** A 60-second Time Profiler
run of the Release build on a fanless MacBook Air, Blitz with Rapid Fire: over a third of
the main thread sits in an IOKit trap with CoreImage on the stack — the CPU submitting
the full-screen `CIBloom` and waiting on the driver — with a second thread spending 2.38s
more in GPU submission. SpriteKit's own self time is 8.5% of the main thread against the
bloom's 35%. None of our own Swift has measurable self time, and the log panel is 0.7%.

**Two lessons from that trace worth more than the numbers.**

*A process CPU total cannot see GPU work.* Switching `NEON GLOW` off moved Activity
Monitor by 0.5–1%, which looked like proof the bloom was cheap. The work is GPU work and
the CPU's share of it is *waiting* — remove the bloom and the main thread waits on vsync
instead of the driver, so the wait moves and the percentage does not. Reading a CPU total
produced two wrong calls during 1.2. Any future measurement has to be frame time or GPU
counters.

*Anything that animates a label's colour or text per frame is a bug.* The title screen
measured *higher* than gameplay, 53%, and the cause was two `SKLabelNode`s having
`fontColor` written every frame by a colour-cycling action — writing it re-renders the
glyphs, and at 60pt inside the bloom node that was the most expensive thing in the game.
It is `SKAction.colorize` on white glyphs now.

**On iOS the conclusion does not transfer: the bottleneck was audio, not the GPU** — see
the SFX engine above. The glow switch does now clear both the filter *and*
`SKEffectNode.shouldEnableEffects`, which is what makes it actually cheaper (with effects
enabled, SpriteKit renders the subtree offscreen and composites it back whether there is
a filter or not). With that fixed, turning the glow off on an iPad mini 5 changes the
frame rate very little. The remaining question is only the **default** on iPhone, where
the sprites are neon outlines on black and lose atmosphere rather than legibility without
it.

**Node count is second-order but worth knowing**, because traversal is CPU work a slower
core feels: ~624 of 711 nodes on the title screen are pooled objects drawing nothing —
200 laser, 154 shatter, ~170 starfield, 80 explosion, 20 score pops — all built at launch
and hidden, and hidden nodes are still walked. The cheap fix if a phone needs it: park
each pool under a container detached while idle, so 154 nodes leave every frame with no
glass in it without allocating during play.

---

## 7. Reducing the text-heavy screens

**How To Play** is 365 lines of Swift holding roughly 636 characters of body copy in four
blocks, plus headings and key legends. On an iPhone that is a wall.

**Settings** is 480 lines and about fourteen rows across two columns — difficulty, chess
mode, hints, four audio controls, four display controls, ship speed, and two data
buttons. Two columns do not exist on a phone.

Suggested restructuring:

- **How To Play → paged.** Three or four swipeable cards: *the board*, *the ship*, *the
  waves*, *the controls*. One idea per card, one illustration each. This reads better on
  iPad too.
- **Settings → sectioned list.** A single scrolling column with headers, which is what
  every iOS user expects. The existing two-column layout becomes one column on compact
  width and stays two on regular.
- **Control legends become contextual.** The Mac screen lists keys. On a touch device the
  Arcade Hints built this week already teach the controls in play, which is better than a
  legend nobody reads. Show the key list only when a hardware keyboard is attached.
- **Drop Press Start 2P outside the title screen.** It is a pixel font and it is the
  reason small text on a phone would be unreadable. A system font here also unlocks
  Dynamic Type, which matters more on iOS than it does on a Mac.

---

## 7a. The two panels are landscape-shaped

Audited against the code first, which said both screens were fine on iOS: the
strings are accurate, `CADET / ACE` matches the rename, `LANDSCAPE ONLY` for the
log panel is enforced at `GCIiOSApp.swift:149`, and the version line is correctly
Mac-only. One real error turned up and is fixed — How To Play claimed "3 lives"
as a flat string, where `GameSettings.lives` gives Cadet five and Ace three, and
Cadet is both the default for a fresh install and where a stale 1.0 "pilot"
setting lands. It reads the value now.

**Rendering them was the part that mattered.** On an iPad Pro 13" in portrait,
both panels occupy only the top ~45% of the screen and leave the bottom half
empty. Their content is laid out against the 960×700 landscape canvas, and
neither reflows. In landscape both look right.

So the restructure Phase 4 was written for is **not** closed — it is closed for
landscape, which is the orientation they were designed in. What remains is
portrait, and it is the same problem as Pass 4 on iPhone rather than a separate
one: content that has to reflow rather than sit in a fixed composition. Worth
doing once, for both.

Consequence for the store listing: How To Play and Settings are shot in
landscape. Portrait screenshots are the title and gameplay, which do fill it.

---

## 8. Refactoring worth doing regardless

**`GameScene.swift` is 6,228 lines** — it was 4,826 when this was written, so the
problem has grown rather than shrunk. It is the single biggest obstacle to a clean port
and the thing most likely to make the iOS work painful. It currently holds the update
loop, all input entry points, layout, chess flow, fleet coordination, power-ups,
effects, banners, high-score prompting and game-over handling.

Proposed split, in the order that pays off soonest:

1. ~~**`SceneLayout`**~~ — done in 1.2.
2. ~~**Input adapters**~~ — done: `MacInputAdapter`, `TouchInputAdapter`,
   `KeyboardInputAdapter` and `NameEntryField` all live in `Game/Input` and emit
   `GameAction`. A `ControllerInputAdapter` would slot in beside them.
3. **`HUDCoordinator`** — the turn timer, status banner, power-up alley, Chess Hints and
   Arcade Hints are all gutter furniture with their own lifecycle. They are the parts
   that move most between layouts, and they are currently interleaved with gameplay.
4. **`BeatCoordinator`** — `beginBeat` / `resolveBeat` / `playBlackMoves` are the game's
   clock and the least visual part of the scene.

**Two smaller items:**

- ~~`HighScoreEntryNode.handleKey(_ event: NSEvent)`~~ — done; it takes a `KeyPress`.
- ~~`HowToPlayNode`'s single `NSColor.white`~~ — done, along with the Zudio credit link.
  `HowToPlayNode.MusicCredit` now owns both the URL and the opener, so the scene's click
  handler is platform-free. One universal App Store link serves every platform, since
  Zudio is a universal app and the store routes it; only the opener needs an `#if`,
  because `NSWorkspace` does not exist on iOS. That is the pattern the rest of the port
  wants — the `#if` lives with the thing it describes, not at the call site.

**A note on tests.** The suite is 442 tests and most of it is platform-agnostic. Two
are known-flaky by design (`EngineVariationTests.testAutoPlayUsesManyPiecesAndSquares`
and `DrawRuleTests.testNormalPlayIsNotFalselyDrawn`) because they assert statistically
over the engine's random tie-break. **This is no longer hypothetical** — the first was
observed failing on 1 Oct, asserting 20 distinct moves and getting 15 while the engine
shuffled knights. Seed the RNG under test, so a port failure is never confused with a
coin flip.

A third flake was fixed on 1 Oct and is worth not reintroducing: six classes each
presented the singleton `GameScene` into their own throwaway `SKView`, which the app
never does — it presents once and keeps the view. `GlowSwitchTests` crashed the host on
2 of 9 suite runs on that arrangement. `SharedSceneHost` presents once and holds it.

---

## 9. Suggested sequence

| Phase | Work | Ships? |
|---|---|---|
| 0 | `SceneLayout` refactor, validated on macOS at the existing size | macOS 1.2 |
| 1 | iOS target, audio session, lifecycle, touch controls, touch chess | **done** |
| 2 | iPad landscape, all four sizes + physical mini | TestFlight |
| 3 | ~~iPad portrait~~ — **closed, not needed**; see Pass 2 | — |
| 4 | How To Play and Settings — **landscape done**; both are short in portrait (§7a); revisit for iPhone | — |
| 5 | iPhone landscape | TestFlight |
| 6 | iPhone portrait, or the decision not to | — |
| 7 | iPhone Duo | — |

Phase 0 is the one that is easy to skip and expensive to skip.

**Where Phase 1 landed.** The target exists and the game plays on an iPad by touch:
tap to start, drag the ship in its lane, hold FIRE in the right-hand margin, tap a
piece and tap its destination, the panels and the Settings sliders. `AVAudioSession`,
the interruption path and `scenePhase` are in. A hardware keyboard drives every key the
Mac reads, through `KeyboardInputAdapter`. Three things in `Game/` that were quietly
macOS-only — the notification names, an `NSFont`, one `invalidateCursorRects` — are not
any more.

Built beyond the original Phase 1 list, all of it on device:

- **Test Mode has a door and controls.** Hold the version badge to arm, tap it to
  clear; `POWER · RAID · LEVEL` chips appear under it. `L` and `A` stay in Settings,
  which already carried both.
- **Name entry works without a keyboard** — the system keyboard on a tap, warmed on the
  title screen, with a DONE button as the way out when no keyboard appears.
- **Two real buttons at the end of a run**, `NEW GAME?` over `YES` / `NO`, and the last
  wave announces itself instead of holding on a silent board.
- **The SFX engine**, which is what actually fixed the frame rate — see §6a.
- **Settings and the Info screen say true things on iOS**: no `⌘T`, no `Y / N`, no
  "SLOWER MAC", the controls list leading with DRAG and FIRE, and larger body type.

The four-size sweep is **done** — see the table under §5. Five sizes in the end,
both orientations, including the physical mini 5. Phase 1 is complete and the
build is TestFlight-able.

---

## Decisions taken

- **Minimum iOS 17**, not the 15 first planned. `DiagnosticsLog` is `@Observable`,
  which is 17+, and shimming it back to `ObservableObject` is the only thing standing
  between the two — nothing else in the codebase needed an availability check at 17.
  iOS 17 is from September 2023, three releases back; it reaches iPhone XS and iPad
  mini 5, so the hardware it excludes is 2015–2017 and would struggle with the bloom
  anyway. Zack's own test iPad is a mini 5 on iOS 18. Still clears
  `GCVirtualController` (15) and `GCKeyboard` (14) with room to spare.
- **Free on iOS**, as on the Mac.
- **Drag-to-move for chess pieces**, as the default, with tap-then-tap still
  working. Combined with drag-to-move for the ship, the rule on iOS is that you
  drag things and the only tap is the fire button.
- **No auto-fire**, and an explicit fire button — see §4.
- **Press Start 2P is the title screen only.** Everywhere else on iOS, use whatever is
  most legible. This removes a real problem: Press Start 2P is a pixel font, and under
  any non-integer scale it turns to mush. A system font at a sensible weight solves the
  gutter and Settings text at a stroke, and also makes Dynamic Type possible.
- **Test Mode stays.** The diagnostics log is **landscape only** — it does not fit in
  portrait and repositioning it to the bottom is not worth the work.
- **The SFX engine is `AVAudioEngine` with pre-decoded buffers**, not `AVAudioPlayer`
  pools, and the voice pool is eight. §6a has the measurements; the short version is
  that `AVAudioPlayer.play()` costs 11.7ms a call and `scheduleBuffer` costs nothing.
- **Name entry uses the system keyboard, on a tap, warmed at the title screen.** Not a
  bespoke A–Z picker, and not summoned automatically.
- **Test Mode needs a way in without a keyboard.** As of 1.2 it is ⌘T on the Mac, and
  the log panel sits behind it. Neither exists on a device with no hardware keyboard,
  so iOS needs its own door. Options: a row at the bottom of Settings, which is
  discoverable and therefore slightly defeats the point of hiding the log; or a
  gesture — a long press on the version string in Settings is the convention, and
  keeps it out of a casual player's way. **Prefer the gesture**, and keep ⌘T working
  when a keyboard is attached.

## Still open

1. ~~**iPhone Duo specifications.**~~ **Shipped Sept 2026; measured in §5 Pass 5.**
   466 × 678 outer and 626 × 890 inner, at an inferred ×3. Decided: full screen on
   whichever display is active, never two screens or multitasking. What is still open is
   narrower — whether it presents as one `UIScreen` or two, and what the app receives on
   a fold. Pass 5 lists eight things to confirm when the simulator ships.
2. **One app or two?** A universal bundle means one listing, one set of reviews, and
   users get every platform. A separate iOS app versions independently. Zudio is a third
   model — one project, separate targets, one App Store record.
3. ~~**A version label on the title screen.**~~ ~~**The play screen, bottom-left.**~~
   **Shipped upper-left**, under the HUD at (10, height − 84). Bottom-left collided with
   the `ERROR - SEE LOG` flag at (50, 30); upper-left avoids that and keeps the badge
   clear of the ship lane. It is a bordered box — hold to arm Test Mode, tap to clear —
   with the `POWER · RAID · LEVEL` chips directly beneath it.
4. ~~**Does a Test Mode strip ship at all?**~~ **Decided: yes.** On iOS Test Mode is
   also a cheat code — see §4 — so it belongs in the shipping binary rather than in a
   separate configuration testers cannot report against. What remains open is only
   *how findable* the gesture should be.
