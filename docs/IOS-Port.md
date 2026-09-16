# Porting Galactic Chess Invaders to iPad and iPhone

*Written 13 September 2026 against v1.1. Updated for 1.2, in which §3 — the layout
refactor — was built and shipped on macOS. Everything else is still a plan.*

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
size — followed by four increasingly fiddly device passes. **The refactor is done**
as of 1.2; see §3, which also records why it was done, what it cost, the cheaper
option that was not considered at the time, and the one line that reverts macOS to
the 1.1 behaviour. The device passes remain.

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

Worth writing down, because the answer is not "the old way was broken".

**The old way could not break.** A fixed canvas under `.aspectFit` is one image
scaled uniformly, so fonts, banners, missiles and messages all resized together
by construction. There was no per-element work to get wrong because there was
none to do. Every resize bug listed above is a bug this change created.

**Where `.aspectFit` genuinely fails is legibility, not letterboxing.** A uniform
scale shrinks type along with the board, and the HUD and gutter already run at
8–11pt. The scale factors from §2's table, applied to 9pt gutter type:

| Target | Uniform scale | 9pt type renders at |
|---|---|---|
| iPad 12.9" landscape | 1.42× | 12.8pt |
| iPad mini landscape | 1.06× | 9.6pt |
| iPad portrait | 1.07× | 9.6pt, in a 45%-black screen |
| iPhone landscape | 0.56× | **5.0pt** |
| iPhone portrait | 0.41× | **3.7pt** |

So the refactor was **unnecessary for macOS, unnecessary for iPad landscape,
marginal for iPad portrait, and genuinely required for iPhone**. Below roughly
0.7× the game stops being readable however much screen is left over.

**The cheaper option, not taken.** Keep `.aspectFit` and swap the *design canvas*
per orientation — 960×700 landscape, something nearer 760×1000 portrait —
rebuilding the scene on rotation. Two or three fixed canvases, each internally
rigid and each scaled uniformly the way the Mac already did. That still requires
composing a portrait layout, which is the real work in §5, but it would not have
required parameterising every round, pop and dot. It reaches iPad fully and
iPhone acceptably for a fraction of the effort, and it was not on the table when
this was planned. If the phone passes turn out harder than §5 expects, this is
the fallback worth reconsidering.

**What it cost.** 1,502 lines across 19 files, and about sixteen of the
twenty-three commits after Stage 2 exist only to clean up after it — including
one regression that stopped the fleet sweeping horizontally from Level 02
onward, in a game that had already shipped twice.

**The sequencing was the mistake, more than the decision.** `scaleMode` is set in
one line per platform. macOS could have stayed on `.aspectFit` until an iOS
target existed and the responsive layout had been proven there. Doing it on the
shipping platform first meant paying the whole destabilisation cost where none of
the benefit lands.

**The fallback is still one line.** Setting `scene.scaleMode = .aspectFit` in
`GameScene.shared` pins the scene at 960×700 forever, so `SceneLayout` always
returns its design values and macOS renders exactly as 1.1 did. Everything in
this section goes dormant and stays available for iOS. Worth remembering if a
Mac release ever needs the safe path in a hurry.

---

## 3a. Original plan

Everything else depends on this, so it comes first and it is worth doing properly.

**Replace the fixed canvas with a scene that lays itself out.** Set
`scaleMode = .resizeFill`, implement `didChangeSize(_:)`, and derive every position from
a single computed value rather than from literals.

```swift
/// Every position in the scene, derived from the size it actually has.
struct SceneLayout {
    let size: CGSize
    let safeArea: UIEdgeInsets       // zero on macOS
    let mode: Mode                   // .wide, .tall

    var squareSize: CGFloat          // was BoardNode.squareSize = 64
    var boardOrigin: CGPoint         // was (224, 120)
    var shipLaneY: CGFloat           // was 62
    var readoutColumn: CGRect?       // the gutter, nil in portrait
    var readoutBar: CGRect?          // the portrait replacement
}
```

The constants it replaces, all currently literals in `GameScene` and `BoardNode`:

`squareSize 64` · `boardSize 512` · `boardBottomY 120` · `shipLaneY 62` ·
`shipMargin 30` · `gutterDrop 8` · `chessHintY 292` · `powerUpAlleyBottomY 196` ·
`powerUpAlleyStep 14` · `powerUpBarWidth 84` · `powerUpBarY` · and **eight** separate
uses of the literal `x: 112` for the gutter centre.

**`BoardNode.squareSize` must stop being a static constant.** It is the root of the
whole coordinate system — `boardSize` is `squareSize * 8`, piece sprites are fitted to
it, and `FleetController` sweeps in multiples of it. Making it an instance property
derived from available space is the single highest-leverage change in the port, and it
touches the most files.

**Do this on macOS first.** Ship it as a macOS point release that behaves identically at
960×700 but also lets the window resize properly. That way the refactor is validated
against a known-good build before any iOS variable enters.

### How risky is it?

Measured rather than estimated, and the answer is **less risky than it looks**, because
the architecture rules already did most of the work:

- **`PieceNode.squareSize` is already an instance property**, injected at construction.
  The piece layer never reads the static.
- **`FleetRules.sweepAmplitude(squareSize:ratio:)` already takes it as a parameter.** The
  Logic layer does not depend on the constant either.
- **58 test references** touch `squareSize` / `boardSize`. Geometry is not the untested
  part of this codebase.

So the usual hazard in a refactor like this — hidden couplings to a global — largely is
not there. The consumers were written to be parameterised and are simply being handed a
constant today.

What remains, in order of care needed:

| Area | Call sites | Note |
|---|---|---|
| `BoardNode` | 18 | Grid lines, rank/file labels, marker pool, selection |
| `GameScene` | 12 | Plus the eight `x: 112` literals |
| `FleetController` | 7 | Sweep and descent distances |
| `RaiderController` | 3 | Crossing height |

**Do it in two stages, and the first is near-zero risk:**

1. **Parameterise without changing numbers.** Route everything through `SceneLayout`,
   which returns exactly today's values. Behaviour-preserving by construction, verifiable
   by screenshot at 960×700, and the 388 tests pass unchanged.
2. **Make the values size-dependent.** Only now can behaviour change, and only when the
   window is not 960×700.

The genuine risks live in stage 2, and there are three:

- **Non-integer square sizes.** A 1pt grid line at 63.4pt spacing will alias. Rounding
  `squareSize` down to a whole point and centring the remainder is the fix, and it should
  be in the layout from the start rather than bolted on.
- **`didChangeSize` is a new code path.** On a Mac it fires continuously during a live
  window drag. Rebuilding nodes there rather than repositioning them would be visibly
  bad; the layout has to be cheap to recompute.
- **Visual regressions the tests cannot see.** Spacing and overlap are exactly what this
  session's bugs were made of. Screenshots before and after at 960×700, compared
  directly, are the only real check.

---

## 4. Input

The ask is narrow and that helps: horizontal ship movement, and fire. Two axes of one
stick and one button.

### Virtual controller

`GCVirtualController` (GameController, iOS 15+) is the right default:

```swift
let config = GCVirtualController.Configuration()
config.elements = [GCInputDirectionPad, GCInputButtonA]
```

Why it wins for this game:

- **It disappears on its own** when a physical controller connects, and comes back when
  it disconnects. No code.
- **Physical keyboards work for free** via `GCKeyboard` (iOS 14+), which satisfies the
  requirement that a hardware keyboard keeps working. Arrow keys and space map to the
  same `GameAction`s the Mac build already uses.
- It is the native, familiar, Apple-blessed control and needs no art.

Why it might not: you get very little say over how it looks. It is a translucent grey
system d-pad laid over a neon vector arcade game, and it may look borrowed. There is no
way to restyle it.

**Recommendation:** build against `GCVirtualController` first because it is hours rather
than days, and decide on looks with it running. If it clashes, a custom `SKNode` control
pair is a contained replacement — the input layer is one adapter either way, and
`GameAction` means nothing downstream knows the difference.

### What other arcade ports actually do

Worth settling by looking at what shipped and worked, rather than by reasoning from
first principles. The pattern across touch conversions of one-axis shooters is
fairly consistent:

| Game | Movement | Firing |
|---|---|---|
| Sky Force Reloaded | drag anywhere | auto |
| Phoenix 2 | drag anywhere | auto |
| Galaga Wars | drag anywhere | auto |
| Space Invaders (Taito) | virtual d-pad, later direct touch | button |
| Geometry Wars 3 | twin virtual sticks | auto / stick |
| Super Hexagon | tap left or right half | n/a |

Two things stand out. **Direct drag beat the virtual d-pad**, everywhere, and the
ports that kept a d-pad are the ones people complain about — a d-pad gives no
tactile edge, so a thumb drifts off it and the player finds out by dying. And
**auto-fire is close to universal**, because it removes the second input entirely
and leaves one thumb doing everything.

Most implementations also use **offset drag**: the ship tracks the finger's
*movement* rather than sitting under it, so the finger never covers the thing you
are aiming.

### Why GCI cannot just copy that

Two complications, and the second is the interesting one.

**The screen is also a chess board.** A drag-anywhere scheme assumes the whole
surface is a movement pad. Here, taps on the board select and move pieces. So the
drag region has to be bounded — most likely the ship's own lane and the space below
the board, which is exactly the band the layout already reserves as
`shipBandHeight`. That is a reason to keep that band generous on a phone rather
than trimming it to make the board bigger.

**Auto-fire would be actively harmful.** In every game in that table, the only
things in front of you are enemies. In GCI your own pieces sit in your firing line
on every shot — that is what the friendly-fire hint exists to teach. Auto-fire would
demolish White's position without the player ever choosing to. So GCI keeps an
explicit fire control, and the dominant touch-shmup solution is not available to it.

That leaves the two-input problem that auto-fire usually solves. Options, roughly in
order of how much they ask of the player:

1. **Drag in the ship lane to move, tap anywhere in the lane to fire.** One thumb,
   no on-screen furniture, no chrome over the art. Risk: a tap and the start of a
   drag are hard to tell apart, so firing may trigger on movement.
2. **Drag to move with the left thumb, a fire button under the right.** Two thumbs,
   which is the natural landscape grip anyway, and it is unambiguous.
3. **`GCVirtualController`** — the d-pad the table above says people dislike, but it
   is free, native, and disappears when a real controller connects.

**Decided: 2, and no auto-fire.** Drag in the ship's lane with the left thumb, a
fire button under the right. Landscape puts both thumbs in the bottom corners
already, and the fire button can sit in the right-hand gutter — space the layout
has spare and the Mac build uses for nothing. Option 1 is the thing to test it
against, not the thing to build.

**Chess pieces drag too.** Tap-then-tap still works, but drag is the default: it is
what every chess app on a phone has taught people, and it is one gesture instead of
two at a moment when the clock is running. That matters more here than the
convention does — see the metric under *Testing* below.

Which leaves the port with one consistent rule: **on iOS you drag things.** The ship
in its lane, a piece to its square. The only tap is the fire button.

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

### Touch for chess

The existing flow is click piece, click destination. That maps to tap-then-tap with no
change in logic. Two things need attention:

- **Hit targets.** A 64pt square is comfortable; the same square on an iPhone in portrait
  could be 40pt, below Apple's 44pt guidance. The layout must enforce a floor on
  `squareSize`, and the port should consider a small tap-tolerance margin around each
  square.
- **Drag as an alternative.** Worth adding on touch — dragging a piece is the gesture
  people expect from every chess app they have used. The `selectPieceAt` / `movePieceTo`
  actions already support it; it is a gesture recogniser, not a rules change.

### What becomes unreachable

Every hotkey in the game is an `NSEvent` in `GameScene.keyDown` or `InputHandler`. On a
phone there is no keyboard at all; on an iPad there may or may not be one. Three
separate problems, and they want different answers.

#### 1. The player-facing hotkeys, and the promises the UI makes about them

| Binding | What it does | On iOS |
|---|---|---|
| `S` | Settings | Button exists; **drop the hotkey affordance** |
| `I`, `⌘I`, `?` | How To Play | Button exists; **drop the affordance** |
| `M` | Mute music | Needs a Settings row — it already has one |
| `Escape` | Pause | Needs a touch target |
| `Q` | Leave the run | Needs a touch target |
| `Return` / any key | Start, dismiss, continue | Tap anywhere already works for most of these |
| `Y` / `N` | Quit prompt, new game | On-screen buttons |
| `Space`, `←` `→`, `A` `D` | Fire and steer | §4's virtual controller |

**Decided: the handlers stay, the affordances go.** Every `keyDown` path is kept, so an
iPad in a Magic Keyboard behaves exactly as the Mac does today — including `⌘T` and the
test keys. What does not survive is the *advertising*: the underlined hotkey letter in
`SET` and `INFO` comes off on iOS unconditionally, not conditionally, because a button
that sometimes claims a shortcut and sometimes does not is worse than one that never
does. `GCKeyboard.coalesced` (iOS 14+, with connect/disconnect notifications) is still
worth knowing about for the *copy* below, but the underlines are simply gone.

**The copy has to change, because it names keys.** Every string, and what it should say
on a touch device:

| Where | Today | On iOS |
|---|---|---|
| `TitleOverlayNode` | `PRESS ANY KEY TO START` | `TAP TO START` |
| `GameScene.showPausedOverlay` | `PRESS ANY KEY TO RESUME` | `TAP TO RESUME` |
| `HowToPlayNode`, `SettingsNode` | `PRESS ANY KEY TO RESUME GAME` | `TAP BACK TO RESUME` |
| `GameOverNode` | `PRESS ANY KEY  ·  LEVEL n` | `TAP FOR LEVEL n` |
| `GameOverNode` | `NEW GAME?   Y / N` | `NEW GAME?` with two buttons |
| `GameScene` quit prompt | `Y / N` | two buttons — `QUIT` / `KEEP PLAYING` |
| Arcade Hint, fire | `PRESS SPACE` / `TO FIRE!` | `TAP THE` / `FIRE BUTTON!` |
| Arcade Hint, steer | `USE ARROWS` / `TO MOVE!` | `DRAG TO` / `MOVE SHIP!` |
| `HighScoreEntryNode` | `RETURN WHEN DONE  ·  UP TO 3 CHARACTERS` | `DONE  ·  UP TO 3 CHARACTERS` |
| How To Play, controls | chips `← →` / `SPACE` / `CLICK` / `ESC` | `DRAG` / `FIRE` / `TAP` / `PAUSE`, naming the on-screen controls |
| `SettingsNode`, log row | `SAME AS THE L KEY` | drop the line |
| Test Mode gate | `⌘T FIRST` | `TEST MODE FIRST` |

Two notes on that table. The Arcade Hints are the constrained ones —
`ChessHintNode.ControlPrompt` returns two lines and the column fits about eleven
characters at 9pt, which the suggestions above respect. And where a keyboard *is*
attached, the Mac wording is still the better wording, so these want to be a
`GCKeyboard`-aware lookup rather than a hard swap — one function returning either
string, not two code paths.

#### 2. Getting into Test Mode without `⌘T`

`⌘T` is deliberately Command-modified so it cannot collide with gameplay, and it is
per-session so nobody leaves it on. Neither property survives onto a touch device.

**Decided: a long press on the version label, and Test Mode ships.** On iOS the version
moves out of the Settings screen — where it sits today, `SettingsNode` line 277 — and
onto the play screen, bottom-left corner, small and dim. That earns its place twice
over: a tester reporting a bug can read the build number straight off the screen, and it
gives the gesture something real to aim at.

A **single ~1.5-second press** on it, rather than a tap count. Counted taps were the
first idea — seven is the Android developer-mode convention — but seven is slow, gives
no feedback while you are doing it, and feels broken until it suddenly works. A long
press is one deliberate action, impossible to trigger by accident in a corner nothing
else uses, and it can show its own progress: dim the label up to full brightness over
the hold, so the gesture explains itself halfway through. The confirmation already
exists — `flashGutterNotice("TEST MODE ON")`.

The other conventions considered, and why not:

1. **Seven taps on the version.** Slow, no feedback mid-gesture. The convention people
   know, but the worse interaction.
2. **Two- or three-finger long press anywhere.** No accidental triggers, but nothing on
   screen to aim at, so nobody finds it without being told.
3. **A shake gesture.** The classic debug trigger, and wrong for this game — it is
   played in motion and would fire by accident.
4. **A visible Settings row.** Rejected once already: 1.2 moved the log panel *behind*
   Test Mode precisely because players opened it by accident and had no idea what they
   were looking at. Putting the gate itself in plain sight undoes that.
5. **A Konami-style sequence on the virtual stick** — ↑↑↓↓←→←→ and fire. Thematically
   perfect for an arcade game, and genuinely tempting given what Test Mode now is, but
   fiddly on a thumbstick and slow to enter. Worth keeping in the back pocket as an
   easter egg rather than as the only door.
6. **A URL scheme, `gci://testmode`.** Not a substitute for a gesture, but worth adding
   alongside one: it is the easiest thing to put in a TestFlight email, and it gives
   automation a way in.

**`⌘T` stays** wherever a keyboard is attached, and all routes land in the same
`testMode.toggle()`.

**Test Mode ships in the release build.** This is a decision, not an open question: on
iOS it doubles as a cheat code. A player stuck on a wave can skip it rather than put the
game down, and `V` is a better answer to frustration than a difficulty setting. That
changes how findable it should be — an undocumented gesture nobody discovers helps
nobody — so the sequence worth considering is: silent at first, then a one-line nudge
after the player loses the same level three times. App Review sees whatever is behind
the gesture either way, which is an argument for it being a cheat code rather than a
developer tool.

#### 3. The debug keys themselves — `L`, `A`, `P`, `R`, `V`

These split cleanly by kind, and the split is the design:

- **Toggles** — `L` (diagnostics panel) and `A` (Auto Chess) are states that persist.
  They belong in **Settings rows shown only in Test Mode**, which is exactly how the log
  row already works (`SettingsNode(showsLogRow: testMode)`). Auto Chess joins it.
- **Momentary actions** — `P` (grant the next power-up), `R` (send a raider now) and
  `V` (skip the level) all fire *during play* and are meaningless from a modal panel: by
  the time you have closed Settings, the thing you wanted to observe has moved on. They
  need to be reachable with the game running, which means a **Test Mode strip on the
  playfield**: a compact row of small buttons — `PWR · RAID · SKIP` — drawn only while
  Test Mode is on, and therefore never seen by a player.

Two placement constraints for that strip. The left gutter is gone in portrait on a phone
(§5, Pass 4), so it cannot live there; and the diagnostics panel is landscape-only for
the same reason, so `L` should be hidden outright in portrait rather than offered and
then disappointing. The ship's lane along the bottom is the one band that survives every
orientation, which makes it the likely home — or a single `⚙` that expands, on a phone.

The keyboard path stays for all five on an iPad with a keyboard, so nothing here is a
regression for the way the game is tested today.

---

## 5. The four device passes

### Pass 1 — iPad landscape

The easy one, and the right place to prove the layout refactor. Range is 1.334 to 1.523,
all within reach of the existing composition. The board stays centred, the left gutter
stays where it is, and the extra width at the iPad mini end goes to the gutters rather
than to black bars.

Test on iPad Pro 13", iPad Pro 11", iPad 10.9" and iPad mini, in the simulator, then on
the physical mini — the mini is the tightest of the four and the one you own.

### Pass 2 — iPad portrait

3:4 rather than 4:3. The board can stay large; what changes is that the vertical space
above and below it is generous and the horizontal space is not.

Move the readouts from a left column to a **bar above the board**. Turn timer, score and
level read naturally as a top strip, and the power-up alley and hints can sit beneath the
board, above the ship lane.

This is also where `GeometryReader` earns its place — not for the scene itself, which
should read its own size in `didChangeSize`, but for the SwiftUI chrome around it and for
safe-area insets.

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

I do not have reliable specifications for this device — see the open questions at the
end. Structurally, if it is a fold, the port needs to handle a **live size change while
running**, not just at launch. That is exactly what `didChangeSize` is for, and it is
another argument for doing the layout refactor properly rather than caching a layout at
startup.

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

Measured on an M-series Mac in ordinary play: **35–38% of one core**, holding 60fps.
That is around 6ms of CPU per 16.7ms frame — comfortable on a desktop, and the figure
to carry into the port as the thing to beat, because a phone has nothing like that
headroom.

**The bloom is the largest GPU item, and almost nothing on the CPU.** One
`SKEffectNode` wraps the whole playfield and carries a `CIBloom` at radius 6, intensity
0.9, re-filtered every frame — `shouldRasterize` is off because the subtree changes
constantly, so the cache would be invalidated before it was ever read. Switching
`NEON GLOW` off moves the CPU figure by **0.5–1%**, measured: the filter runs on the
GPU, and Activity Monitor's CPU percentage never counted it. A full-screen Core Image
pass per frame is still exactly the kind of thing that throttles a phone and drains its
battery, so it remains the trade-off the port has to make consciously — but it is a GPU
and power question, not a frame-time one, and it has to be measured on device with the
GPU counters rather than inferred from a process total.

**Measured, not inferred.** A 60-second Time Profiler run of the Release build on a
MacBook Air (fanless), Blitz with Rapid Fire, thermal state Nominal throughout —
`Documents/GCI 09-14-26.trace`:

| | CPU over 60s | Share |
|---|---|---|
| **Everything** | 24.25s | 40% of one core — matches Activity Monitor |
| Main thread | 12.46s | 21% of one core |
| &nbsp;&nbsp;→ in the kernel, `mach_msg2_trap` from IOKit | 4.37s | **35% of the main thread** |
| &nbsp;&nbsp;→ kernel time with CoreImage on the stack | 4.23s | 34% |
| &nbsp;&nbsp;→ SpriteKit, self | 1.06s | 8.5% |
| GPU submission thread, `iokit_user_client_trap` | 2.38s | 10% of all CPU |
| SwiftUI + AttributeGraph, self — **the log panel** | 0.09s | 0.7% |
| Our own Swift, self | ~0 | below the sampling floor |

**The game is GPU-bound, and the bloom is why.** Over a third of the main thread is
spent in an IOKit trap with CoreImage on the stack — the CPU submitting the filter and
waiting on the driver — and a second thread spends 2.38s more in GPU submission traps.
That is what the frame rate is paying for, and it is why a 60-second capture on a
fanless Air shows fps dipping toward 28 while the CPU sits at a comfortable 40%.

**It also explains why switching `NEON GLOW` off barely moved Activity Monitor.** The
work is GPU work; the CPU's share of it is *waiting*. Remove the bloom and the main
thread waits on vsync instead of on the driver — the wait moves, the percentage does
not. Any future measurement of this has to be frame time or GPU counters. A process
CPU total cannot see it, and reading one is what produced two wrong calls during 1.2.

**Our own code does not appear.** No function we wrote has measurable self time. The
largest inclusive entries are `AudioManager.play` at 0.48s (3.9% of the main thread —
Blitz fires a great many laser sounds), `GameScene.update` at 0.30s (2.4%) and
`CollisionHandler.didBegin` at 0.28s (2.2%). The loop work done for 1.2 was worth
doing and is worth keeping, but it was never where the time was.

**The log panel is not expensive**, at 0.7% of the main thread — measured, because it
was assumed otherwise.

**Everything else the trace turned up, ranked.** All of it is small, because the
machine is not CPU-bound — but a phone core is slower, so the order is worth keeping:

1. **`SKCShapeNode::getBoundingBox()` — 0.40s, 3.2% of the main thread.** The largest
   identifiable non-GPU item. SpriteKit re-measures a shape node's path on the CPU, and
   the scene holds roughly seventy `SKShapeNode`s all the time: the legal-move marker
   pool alone is 32 markers × (dot + ring) = 64, plus the grid, the selection ring and
   the deployment bands. The fix is the trick the starfield already uses — draw the dot
   and ring once into a texture and use sprites — or detach the marker pool while
   nothing is selected. Another 0.45s of main-thread `malloc` sits mostly underneath
   this, building `CG::Path` point vectors.
2. **`AudioManager` — 0.71s, 5.7%, but weaker evidence.** The leaves are `__open`,
   `pread`, `__sysctl` and `AudioComponentMgr_Base::match`, which is what re-priming an
   `AVAudioPlayer` looks like: the pool reuses players, but `currentTime = 0` followed
   by `play()` makes AVFoundation re-buffer from the file. Calling `prepareToPlay()` on
   a finished player would move that off the frame. Some of the attribution is to
   unresolved binaries, so confirm before acting.
3. **`SKCLabelNode::rebuildText()` — 0.05s.** Down from being the most expensive thing
   in the game before the title fix. Nothing left to take.

**Zero hangs and zero hang risks in 60 seconds**, which matches playing it: the frame
rate dips without the game ever stuttering, because it is GPU-paced rather than
stalling.

**What this means for the port.** The single decision that matters on a phone is the
bloom, and it should be made on measured frame time on the device, not on a CPU
percentage. If a fanless MacBook Air cannot hold 60fps with it on at Blitz, an iPhone
will not either. Options 1–3 above stand; option 2 — glow off by default on a phone —
now looks less like a power optimisation and more like the thing that makes the frame
rate.

**Node count is a second-order concern.** The census below is still worth knowing,
because traversal is CPU work that a slower core will feel more than this Air did, but
the profile puts SpriteKit's self time at 8.5% of the main thread against the bloom's
35%. Fix the glow first; only then is this worth touching.

| On the title screen, drawing nothing | Nodes |
|---|---|
| Laser pool — 40 rounds × (sprite + rig + 3 rig parts) | 200 |
| Shatter pool — 14 sprays × (flash + 9 shards) | 154 |
| Starfield — 3 tiers × 2 tiled copies | ~170 |
| Explosion pool — 8 bursts × (flash + 8 shards) | 80 |
| Score pops | 20 |
| **Total** | **~624 of 711** |

All of those are built at launch and hidden until needed, and hidden nodes are still
walked. The cheap fix, if a phone needs it: park each pool under a container that is
detached while the pool is idle and re-attached on first use — one `addChild` when
glass first flies, and 154 nodes leave every frame that has no glass in it, without
allocating during play.

**The switch already exists.** `GameSettings.neonGlow` detaches the filter entirely
rather than zeroing its intensity, which is what actually skips the offscreen pass —
see `GameScene.applyGlowSetting()`. So the iOS work is not building a toggle, it is
choosing the **default**:

1. **Glow on** for iPad, which has the die and the thermal envelope for it.
2. **Glow off by default on iPhone**, or on any scene below some width, with the
   setting still there for anyone who wants it. The sprites are neon outlines on black
   and read perfectly well without the bloom; they lose atmosphere, not legibility.
3. If losing it entirely is too much, the cheaper substitutes are a **pre-blurred
   sprite behind each piece** (a texture, drawn once, no per-frame filter) or simply a
   smaller `inputRadius`. Both are worth measuring before accepting option 2.

**The other two per-frame costs, in order.** The starfield is 84 sprites in three
parallax tiers, batched into one draw call because they share a texture — cheap, but
84 nodes is 84 nodes on a phone, and the tier counts are the obvious dial. The nebula
is a single additive sprite on slow `SKAction`s, which costs almost nothing and can
stay. Both are rebuilt by `rebuildSky()` when the scene's size changes, which is also
where a per-device star count would belong if one is wanted.

**A caution from the Mac.** The title screen measured *higher* than gameplay — 53% —
and the cause was not the bloom but two `SKLabelNode`s having their `fontColor` written
every frame by a colour-cycling `customAction`. Writing `fontColor` re-renders the
glyphs; at 60pt and 48pt, inside the bloom node, that was the most expensive thing in
the game. It is `SKAction.colorize` on white glyphs now. **Anything that animates a
label's colour or text per frame is a bug**, and a phone will punish it far harder than
a Mac did.

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

## 8. Refactoring worth doing regardless

**`GameScene.swift` is 4,826 lines.** It is the single biggest obstacle to a clean port
and the thing most likely to make the iOS work painful. It currently holds the update
loop, all input entry points, layout, chess flow, fleet coordination, power-ups,
effects, banners, high-score prompting and game-over handling.

Proposed split, in the order that pays off soonest:

1. **`SceneLayout`** — §3. Do this first; everything else is easier afterwards.
2. **Input adapters** — lift the five `NSEvent` overrides into a `MacInputAdapter`, and
   add `TouchInputAdapter` and `ControllerInputAdapter` beside it. All three emit
   `GameAction`. `InputHandler` already has the `#if os(macOS)` seam.
3. **`HUDCoordinator`** — the turn timer, status banner, power-up alley, Chess Hints and
   Arcade Hints are all gutter furniture with their own lifecycle. They are the parts
   that move most between layouts, and they are currently interleaved with gameplay.
4. **`BeatCoordinator`** — `beginBeat` / `resolveBeat` / `playBlackMoves` are the game's
   clock and the least visual part of the scene.

**Two smaller items:**

- `HighScoreEntryNode.handleKey(_ event: NSEvent)` should take a character and a key
  code, not an `NSEvent`. It is the only node that reads raw events.
- ~~`HowToPlayNode`'s single `NSColor.white`~~ — done, along with the Zudio credit link.
  `HowToPlayNode.MusicCredit` now owns both the URL and the opener, so the scene's click
  handler is platform-free. One universal App Store link serves every platform, since
  Zudio is a universal app and the store routes it; only the opener needs an `#if`,
  because `NSWorkspace` does not exist on iOS. That is the pattern the rest of the port
  wants — the `#if` lives with the thing it describes, not at the call site.

**A note on tests.** The 388-test suite is a real asset here and most of it is
platform-agnostic. Two tests are known-flaky by design
(`EngineVariationTests.testAutoPlayUsesManyPiecesAndSquares` and
`DrawRuleTests.testNormalPlayIsNotFalselyDrawn`) because they make statistical
assertions over the engine's random tie-break. Worth seeding the RNG under test before
this work starts, so that a port failure is never confused with a coin flip.

---

## 9. Suggested sequence

| Phase | Work | Ships? |
|---|---|---|
| 0 | `SceneLayout` refactor, validated on macOS at the existing size | macOS 1.2 |
| 1 | iOS target, audio session, lifecycle, `GCVirtualController`, touch chess | — |
| 2 | iPad landscape, all four sizes + physical mini | TestFlight |
| 3 | iPad portrait | TestFlight |
| 4 | How To Play and Settings restructure | — |
| 5 | iPhone landscape | TestFlight |
| 6 | iPhone portrait, or the decision not to | — |
| 7 | iPhone Duo | — |

Phase 0 is the one that is easy to skip and expensive to skip.

---

## Decisions taken

- **Minimum iOS 15.** Clears `GCVirtualController` (15) and `GCKeyboard` (14) with no
  availability checks.
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
- **Test Mode needs a way in without a keyboard.** As of 1.2 it is ⌘T on the Mac, and
  the log panel sits behind it. Neither exists on a device with no hardware keyboard,
  so iOS needs its own door. Options: a row at the bottom of Settings, which is
  discoverable and therefore slightly defeats the point of hiding the log; or a
  gesture — a long press on the version string in Settings is the convention, and
  keeps it out of a casual player's way. **Prefer the gesture**, and keep ⌘T working
  when a keyboard is attached.

## Still open

1. **iPhone Duo.** I do not have dependable specifications. Folded and unfolded point
   dimensions, and whether it presents as one continuous display or two, changes Pass 5
   completely.
2. **One app or two?** A universal bundle means one listing, one set of reviews, and
   users get every platform. A separate iOS app versions independently. Zudio is a third
   model — one project, separate targets, one App Store record.
3. ~~**A version label on the title screen.**~~ **Decided: the play screen, bottom-left
   corner.** It moves off the Settings panel on iOS and becomes the long-press target
   for Test Mode (§4). It shares that corner with the `ERROR - SEE LOG` flag, which sits
   at (50, 30) today — one of the two has to move, and that is a Pass 1 layout detail.
4. ~~**Does a Test Mode strip ship at all?**~~ **Decided: yes.** On iOS Test Mode is
   also a cheat code — see §4 — so it belongs in the shipping binary rather than in a
   separate configuration testers cannot report against. What remains open is only
   *how findable* the gesture should be.
