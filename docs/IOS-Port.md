# iPad and iPhone

*Updated 8 October 2026. iPad and iPhone both run in both orientations. What is
left is the iPhone Duo.*

---

## Status

| | State |
|---|---|
| macOS | Shipped. 1.3 is the current DMG; the App Store carries 1.2. |
| iPad | Done. Five sizes, both orientations. Not yet on the store. |
| iPhone | Done in 1.4, in testing. Three sizes, both orientations. |
| iPhone Duo | Open. No hardware; the simulator needs Xcode 27.1. |

**Minimum iOS 17.** `DiagnosticsLog` is `@Observable`, which is 17+; nothing
else in the codebase needed an availability check. That reaches the iPhone SE
2nd generation and the iPad mini 5.

`TARGETED_DEVICE_FAMILY` is `"1,2"` and `UIRequiresFullScreen` is `true`, so the
app is always full screen and never has to survive Split View or Stage Manager.

---

## How the scene lays itself out

`SceneLayout` is a value computed from the scene's size. Everything on screen is
derived from it; there are no hardcoded positions outside it.

The scene is three horizontal bands — a HUD strip along the top, the ship's lane
along the bottom, the board between them. The bands keep their full height above
500pt and shrink toward a compact size below 400pt.

### Where the readouts go

The readouts are the chess hint, the turn clock, the status line and the
power-up alley. They have three placements.

| Placement | When | Effect |
|---|---|---|
| Beside the board | 497pt wide or more | A gutter on the left; readouts centred in it. |
| Under the board | Narrower than 497pt, at least 614pt tall | A 170pt band below the ship's lane; readouts left-aligned. The board takes the full width. |
| Nowhere | Narrower than 497pt and shorter than 614pt | No readouts at all. The board takes the whole scene. |

497pt is the composition floor: a 145pt gutter at its smallest type, a 256pt
board at the 32pt square, and a 96pt right margin. 614pt is what a stacked
column costs in height — the two bands, its own band, and a board at the
minimum square.

Every phone in portrait stacks. The third placement is reachable only on a Mac,
whose minimum window is 640×500 and whose log sidebar takes 281pt of the width:
at 359×500 there is no room for a column anywhere, and the log panel beside it
is already showing what the column would have said.

`MacResizeSweepTests` walks 55 widths × 25 heights across everything a Mac
window can be dragged to, and checks that no two readouts collide, that the
column stays on screen and off the board, that the board fits between the
chrome, and that crossing a threshold does not make the board jump.

### The HUD bar

The bar was composed on a 960pt canvas. Its left block ends at 312 and the nav
cluster is 226 wide with a 70pt right margin, so it wants 608pt before LEVEL is
given a single point — and a phone has 375 to 440. The threshold is 700 rather
than 608 to keep a margin either side of the exact fit.

Below 700pt wide the bar reflows: five life sprites become one ship and a count,
the buttons lose their padding, the right margin goes from 70pt to 8, and LEVEL
shortens to `L 01` or hides when even that will not fit. Nothing is dropped.

### Safe areas

A phone in landscape puts the sensor housing on a side edge, where
`safeAreaInsets.top` is zero and nothing would otherwise move.

- Everything pinned to a screen edge — the bar's two blocks, the version badge,
  the Test Mode chips, a panel's BACK — steps in by that edge's inset.
- The inset is a **floor** on the margin the item already has, not an addition
  to it. The nav cluster sits 70pt in by design and does not move for a 59pt
  inset; the left block has 10pt and does.
- A phone on its side has a rounded corner at **each** end whether or not the
  housing is there, and iOS reports an inset only for the housing. Phone
  landscape therefore takes a 24pt floor on both edges.

### The board must stay flyable

The squares are sized so the ship can reach outside the a-file and the h-file at
every size, so the player is never forced to shoot through their own pieces.

---

## Touch input

Every input arrives as a `GameAction`, so the Logic layer is unchanged from the
Mac. `TouchInputAdapter` and `KeyboardInputAdapter` are the iOS halves, and the
whole of the macOS coupling is six things outside the app shell: five event
overrides in `GameScene` and one method on `HighScoreEntryNode`.

- **Drag** the ship left and right.
- **Hold FIRE** to shoot. There is no auto-fire.
- **Tap** a piece and tap its square; dragging a piece works too.
- A hardware keyboard drives everything it does on the Mac — SPACE, arrows, ESC.

### Keyboard handlers stay; the affordances go

Every `keyDown` path is kept, so an iPad in a Magic Keyboard behaves exactly as
the Mac does — `⌘T` and the debug keys included. What comes off on iOS is the
*advertising*: the underlined hotkey letter in SET and INFO, because a button
that sometimes claims a shortcut is worse than one that never does.

The copy that named keys was rewritten for touch — `TAP TO START`, `TAP BACK TO
RESUME`, `TAP THE FIRE BUTTON!` — as one function returning either string
rather than two code paths, since the Mac wording is still better where a
keyboard is attached.

### Name entry

A touch-only player has to be able to type a high-score name, and this is the
one place that needs the system keyboard. `NameEntryField` is a 1×1
`UITextField` in clear colours holding first responder only while the entry
screen is up; input is uppercased and filtered to printable ASCII, because
Press Start 2P has glyphs for nothing else. The scene still draws the name —
the field is a keyboard, not a text box.

Four things about it are load-bearing, and all four were found on device:

1. **It is summoned by a tap, never automatically.** The first keyboard
   presentation in a session measured 690ms to 4.4s on an A12, main thread
   blocked and audio distorting throughout. That cannot land on the end of a
   winning run.
2. **The cost is paid at the title screen.** `warmKeyboard()` takes first
   responder and resigns in the same turn, two seconds after the title draws.
   The title screen specifically, because every run passes through it before a
   score exists.
3. **`claimKeyboard` stands down while name entry is active.** The view claims
   the keyboard on every SwiftUI pass, so without this every logged line took
   first responder straight back off the field.
4. **The overlay lifts clear of the keyboard** by half of what it covers, from
   `keyboardWillChangeFrameNotification` intersected against the view's bounds.
   That handles iPad's floating and split keyboards by the same path as the
   docked one.

A **DONE** button is the only way off the screen when no keyboard appears — a
connected but flat hardware keyboard is enough for iOS to suppress the software
one. It submits rather than discards, and an empty field falls back to PLAYER.

---

## Test Mode and the diagnostics log

**Hold the version badge** to arm Test Mode, tap it to clear. That is the only
door on a device with no keyboard; the Mac keeps `⌘T` as well.

Armed, `POWER · RAIDER · LEVEL` chips appear under the badge, and the log panel
and auto-chess switches join the Settings page.

The **diagnostics log is landscape only**, on every device including iPhone. The
rule is a plain orientation test in `GCIiOSApp.swift`; there is no device check.
On a phone the sidebar takes real width off the board, so it is a diagnostic
posture rather than a way to play.

---

## What iOS needs that the Mac does not

These have no macOS equivalent and are all built.

**The audio session.** `AVAudioPlayer` makes no sound on iOS until a session is
configured and active, and that is the most common reason a ported game ships
silent. GCI uses `.ambient` with `.mixWithOthers`: a game with a soundtrack
should let someone keep their own music playing underneath, and should respect
the ringer switch.

**Interruptions.** A phone call, Siri, or another app taking the route stops
every player without telling the game. Reactivating the session on return is
what brings the soundtrack back; without it the music simply never comes back.

**App lifecycle.** Backgrounding is aggressive and common on a phone, so a
`scenePhase` change pauses the beat clock and the fleet. The `maxFrameDelta`
clamp already protects against a huge `dt` on resume, but pausing is the
correct behaviour rather than relying on the clamp to absorb it.

**Not built, and optional: haptics.** A laser shot and a piece destroyed are
natural taps, and `CoreHaptics` is cheap to add. It would make the game feel
better on a phone and nothing depends on it.

---

## The sound engine

Worth understanding before touching audio, because the shape of it is what
holds the frame rate.

`AudioManager` plays every effect through one `AVAudioEngine`. Each sound is
decoded once at launch into an `AVAudioPCMBuffer`, and a fixed pool of **eight**
`AVAudioPlayerNode`s stays running for the life of the app. Firing a sound is
`scheduleBuffer` on a node that is already going.

The alternative — a pool of `AVAudioPlayer` per sound — costs far too much per
call. Medians of 20, file already loaded, player reused:

| | |
|---|---|
| `AVAudioPlayer.play()` | **11.7ms**, every call |
| starting a stopped `AVAudioPlayerNode` | 10.9ms |
| `scheduleBuffer` on a running node | **0.000ms** |

Two sounds in a frame was the whole 16.7ms budget. Four things about the design
are load-bearing:

- **One canonical format** — mono, 44.1kHz, float32 — converted at load. The
  source assets are not uniform and a node is wired to the mixer in a single
  format, so converting once is what buys a *shared* pool. Resident cost is
  8.2MB for 48.9 seconds of audio.
- **Eight voices, not more.** Every running node is pulled by the render thread
  each cycle and summed whether or not it has anything to play, so an idle pool
  is not free. Twenty-four overloaded an A12, audible as distortion at the title
  screen with nothing playing. They cannot be started on demand instead — that
  is the 10.9ms above.
- **Dropped, not stolen, when the pool is full.** Stealing a live voice measured
  23ms.
- **The engine stops when SOUND FX is off**, rather than mixing eight silent
  voices every cycle.

`AudioEnginePathTests` pins both halves: firing costs under 1ms, and voices come
back when a sound ends. A pool that leaks them goes silent after eight sounds
and nothing else would notice.

---

## Devices tested

### iPad — 1 October 2026

| Device | | Portrait | Board, portrait | Board, landscape |
|---|---|---|---|---|
| iPad Pro 13-inch (M5) | simulator | 1032×1376 | 720 | 768 |
| iPad Pro 11-inch (M5) | simulator | 834×1210 | 560 | 640 |
| iPad (A16) | simulator | 820×1180 | 552 | 632 |
| iPad mini (6th gen) | simulator | 744×1133 | 488 | 552 |
| **iPad mini 5 (A12)** | **device** | 768×1024 | 512 | 576 |

The two minis are not the same size or the same aspect, so both are worth
keeping in the sweep.

### iPhone — 8 October 2026

Three sizes cover the range. Measured from the simulators rather than quoted.

| Device | Portrait | Landscape | Why this one |
|---|---|---|---|
| iPhone SE (3rd gen) | 375 × 667 | 667 × 375 | The floor, and the only supported phone with no safe-area insets at all. |
| iPhone 16e | 390 × 844 | 844 × 390 | The modern baseline: notch, standard insets. |
| iPhone 17 Pro Max | 440 × 956 | 956 × 440 | The ceiling, and the deepest insets. |

All three pass in both orientations. Everything else falls between the last two
— iPhone 17 and 16 Pro are 402 × 874, the Plus and non-Pro Max models 430 × 932
— and the two rules that bite, the 700pt HUD threshold and the 497pt stacking
threshold, are both far below this range.

Test in **both orientations**: they are different compositions, not scaled
versions of each other.

---

## The two panels

How To Play and Settings have two compositions.

**Two columns**, on a 960×700 canvas, scaled to fit. Used on the Mac at every
window size and on every iPad.

**One column**, composed at its own width so it scales up rather than down.
Used on a phone in portrait only. Two 410pt columns squeezed onto a 440pt phone
draw body text at about 5.6pt; the column draws it at about 10.

The one-column builder writes the touch wording, so it is gated to iOS rather
than to the shape — a Mac window dragged tall and narrow is the same shape as a
phone and is not a phone.

A panel is anchored under the HUD's safe-area inset, and BACK is placed 29pt
below the panel's own top so it lands in the column SET and INFO occupy during
play. On a phone the content drops a further 34pt to clear BACK.

### Open: iPad portrait panel legibility

iPad portrait draws panel body text at 9.3–12pt, depending on size. Reflowing
iPad to one column would buy a couple of points and pay for it with a
phone-shaped column down the middle of a tablet — on the Pro 13" nearly half the
width left black. iPad landscape is already at full size and is not affected.

The mini is the only size where this is a real question. **Zack is checking the
physical mini 5 on Sunday 11 October 2026.**

If it does not read well, the fix is *not* one column. It is to compose the two
columns at the device's own width, which stops the scale-down entirely: about
340pt a column on a mini, body text at full size, the screen still filled, and
no side bands at any size.

---

## iPhone Duo

Ships 23 October 2026. **Decided: GCI runs full screen on whichever display is
active** — no two-screen mode, no side-by-side, no treating the fold as
multitasking. `UIRequiresFullScreen` stays `true`.

### The numbers

| | Diagonal | Pixels | ppi |
|---|---|---|---|
| Outer (cover) | 5.4" | 1398 × 2034 | 460 |
| Inner (unfolded) | 7.6" | 1878 × 2670 | 430 |

**In points, at ×3 — inferred, not an Apple figure: outer 466 × 678, inner
626 × 890.** Confirming this from `UIScreen` is the first job.

At those sizes the inner display is comfortable in both orientations and the
outer display behaves like a roomier iPhone, which the phone work already
covers.

### The work that is genuinely new

Folding while running. `SceneLayout` recomputes from whatever size it is handed
and `didChangeSize` is wired, but a folding phone exercises that path several
times a session — mid-game, mid-panel — and the simulator exposes *partial*
folds, so the scene may be resized continuously through a hinge movement.

- Every `applyLayout()` path has to be idempotent and safe while a panel is open.
- Anything cached against size — the sky, the node pools, the badge's wording,
  the chip row's compact choice — has to survive repeated flips.
- A fold during name entry, during a wave banner, and mid-explosion are all
  worth trying deliberately.

### To confirm when the simulator runs

1. The point dimensions and scale factor, from `UIScreen`.
2. Whether it presents as one `UIScreen` that resizes or two screens. A resize
   is a layout problem; two screens is an architecture problem.
3. What the app receives on a fold — a `didChangeSize`, a scene reconnect, or a
   relaunch. Only the first is already handled.
4. Safe-area insets on both displays: the crease, the Dynamic Island that Apple
   lists on both screens, and the home indicator.
5. Whether `UIRequiresFullScreen` is honoured on a folding device.
6. Whether the cover display rotates at all, or is portrait-locked.
7. Touch-target reality on the cover display at 460 ppi.

The simulator needs the Xcode 27.1 beta and its controls live in Device Hub.
Apps built against the iOS 26 SDK need rebuilding against 27 for basic support
and 27.1 to use the larger display fully.

---

## Refactoring: measured and declined

`GameScene.swift` is about 6,400 lines. An earlier plan proposed splitting it
into `HUDCoordinator` and `BeatCoordinator`. **That plan is withdrawn**, on
measurement rather than taste:

- 203 of 279 private members are referenced across section boundaries, so
  splitting into extension files would have to open almost the whole class.
  Widening 47 of them frees only 448 lines.
- The `// MARK:` headers are unreliable — two of them describe the wrong code —
  so any plan written by reading them is planning against labels.
- The extractable logic already left. `Game/Logic/` holds twenty-one files, 103
  of the scene's methods touch SpriteKit directly, and the largest method that
  touches none is 71 lines.

Chess Beat and Board & Ship, the two the old plan aimed at, have 45 and 80
references out — the most entangled regions in the file, not the least.

**Stop here.** If this is reopened, the bar is a measurement showing a seam — a
region whose references out are in single figures — not a reading of the section
headers. What is cheap and worth doing at any time: fix the stale `// MARK:`
headers, and take genuinely pure helpers out to `Game/Logic/` as they are
written.

---

## Decisions

- **Free on iOS**, as on the Mac.
- **Drag to move**, for both the ship and the pieces. The only tap is FIRE.
- **No auto-fire.**
- **Test Mode ships** in the release binary. On iOS it is also a cheat code, so
  it belongs where testers can report against it.
- **iPad portrait needs no special layout.** The gutter change in 1.3 gave the
  board what it was missing; no restructure was required.

## Open

1. **The Duo**, as above.
2. **One app or two.** A universal bundle means one listing and one set of
   reviews; a separate iOS app versions independently.
3. **iPad portrait panel legibility**, pending the mini 5.

---

## A note on the tests

The suite is 480 tests and most of it is platform-agnostic. Two tests assert
statistically over the engine's random tie-break and both seed the RNG, so a
port failure is never confused with a coin flip.

Scene tests share one presented scene (`SharedSceneHost`). Six classes once
presented the singleton into their own throwaway `SKView`, which the app never
does, and that crashed the host on 2 of 9 runs.
