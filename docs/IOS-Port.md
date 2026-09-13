# Porting Galactic Chess Invaders to iPad and iPhone

*Plan, not a commitment. Written 13 September 2026 against v1.1 (build 8). No code changed.*

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

So the port is one substantial refactor — make the scene lay itself out from its own
size — followed by four increasingly fiddly device passes.

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
HowToPlayNode.swift      NSColor.white                                      (1 literal)
InputHandler.swift       already wrapped in #if os(macOS)
App/                     ContentView, App, LogTextView — the shell, expected
```

That is the entire list. Seven things outside the app shell.

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

## 3. The core refactor: a layout value

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
against a known-good build before any iOS variable enters, and the regression suite
(388 tests) still applies.

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
- `HowToPlayNode`'s single `NSColor.white` should be `SKColor.white`.

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

## Open questions

1. **iPhone Duo.** I do not have dependable specifications for it. Folded and unfolded
   point dimensions, and whether it presents as one continuous display or two, changes
   Pass 5 completely. Can you point me at the numbers?
2. **Minimum iOS version.** `GCVirtualController` needs iOS 15, `GCKeyboard` iOS 14.
   Anything modern is fine, but it should be a decision — the Mac target is 14.0.
3. **One app or two?** A universal bundle sharing
   `com.zurlocker.GalacticChessInvaders` means one App Store listing, one price, one set
   of reviews, and buyers get both. A separate iOS app is cleaner to manage and easier to
   version independently. Zudio went universal within one project with separate targets,
   which is a third option.
4. **Free on iOS as well?** Assumed yes, but it affects nothing technical so it can wait.
5. **Drag-to-move for chess pieces**, in addition to tap-then-tap? It is the gesture
   people expect on a touch screen.
6. **Keep Test Mode and the diagnostics log on iOS?** Both are keyboard-gated today.
