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
as of 1.2; see §3. The device passes remain.

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

The scene is created once at 960×700 and scaled to fit:

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
- **The board never grows past the design 64pt square.** Letting it fill the space
  gave 176pt squares at 1900pt wide and the composition fell apart, because
  everything around it is a fixed size. Extra space becomes gutter, not board.
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

A fourth, subtler one: **a stored `static let` that reads the geometry freezes it.**
`gatlingCeiling` was computed once at first access and then insisted the seventh
rank was somewhere it was not. Making a constant variable turns every copy of its
value into a latent bug, and they only surface where something reads them.

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

My reading is that **2 is the one to build first** and 1 is the one to test against
it. Landscape on a phone puts both thumbs at the bottom corners already, and the
fire button can sit in the right-hand gutter — space the layout has spare, and which
the Mac build does not use for anything.

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

`⌘T` Test Mode and the `L` diagnostics panel are keyboard-only. On a device without a
keyboard they are gone. That is arguably fine for Test Mode. The diagnostics log is more
useful than it sounds for tester reports, so it wants a gesture — a three-finger tap, or
a long press on the title screen.

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
- **Drag-to-move for chess pieces**, alongside tap-then-tap.
- **Press Start 2P is the title screen only.** Everywhere else on iOS, use whatever is
  most legible. This removes a real problem: Press Start 2P is a pixel font, and under
  any non-integer scale it turns to mush. A system font at a sensible weight solves the
  gutter and Settings text at a stroke, and also makes Dynamic Type possible.
- **Test Mode stays.** The diagnostics log is **landscape only** — it does not fit in
  portrait and repositioning it to the bottom is not worth the work.

## Still open

1. **iPhone Duo.** I do not have dependable specifications. Folded and unfolded point
   dimensions, and whether it presents as one continuous display or two, changes Pass 5
   completely.
2. **One app or two?** A universal bundle means one listing, one set of reviews, and
   users get every platform. A separate iOS app versions independently. Zudio is a third
   model — one project, separate targets, one App Store record.
