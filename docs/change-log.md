# Galactic Chess Invaders Change Log

## V 1.4 (Build 11)  iPhone — *in testing, not yet released*

*The game runs on iPhone, in both orientations. A phone is not a small iPad: the board
needs the whole width, so the column of hints that sits beside it on every other device
has nowhere to go, and a settings screen laid out in two columns renders at 5pt. Those
are the two problems this release is about.*

- **It runs on iPhone.** Portrait and landscape, tested on an iPhone SE, a 16e and a
  17 Pro Max — the smallest, middle and largest screens the game supports — in both
  orientations.

- **In portrait, the gutter moved under the board.** The chess hint, the turn count and
  the status line stack below the ship instead of beside the squares, which is what lets
  the board have the full width. Flush left, so they read as a column rather than three
  centred lines.

- **The board stays narrow enough to fly around.** The ship can reach outside the a-file
  and the h-file on every phone size, so you are never forced to shoot through your own
  pieces.

- **Settings and How To Play are one long column on a phone**, at full-size type. They
  were two columns scaled down to fit a 440pt screen, which drew body text at about 5.6pt
  — legible in a screenshot and not on a phone.

- **The top bar fits a phone.** Five ship sprites become one ship and a count, the buttons
  lose their padding, and LEVEL shortens to `L 01` or steps aside when there is no room
  for it. Everything that was on the bar is still on it.

- **Nothing hides under the camera housing.** The score, the buttons and the version badge
  all step in past the sensor housing and the rounded corners — in landscape, where the
  housing is on the side and the first two letters of SCORE used to be cut off.

- **Test Mode and the diagnostics log both work on a phone.** Hold the version badge to
  arm Test Mode, exactly as on iPad; the log panel opens in landscape.

- **Same controls in the same corner, everywhere.** SET, INFO and BACK sit in one place
  across gameplay, Settings and How To Play, on every device and orientation.

- **Minor bug fixes.**

  - *Rotation.* Turning the device mid-wave left the raiders flying against where the
    board used to be — one could end up below the player's ship — and left the fleet
    sweeping and descending in the old orientation's squares. Both now follow the board.
    iPhone and iPad; the Mac reaches the same path by resizing a window mid-game.
  - *End-of-run messages on a phone.* "LEVEL CLEARED!" and the rest ran off both edges in
    portrait. They wrap onto two lines now, each line centred under the one above, rather
    than shrinking to type smaller than the score beneath them.
  - *The FIRE button* sat under the home indicator in the bottom-right corner in
    portrait. It clears the hardware in both orientations now.

---

## V 1.3 (Build 10)  iPad, and Sound Without the Stutter

*Two things: the game runs on iPad, and it stopped doing file and codec work every time it played a sound.*

- **It runs on iPad.** The whole game is playable by touch — drag the ship, hold FIRE, tap or drag a piece to its square — and it has been checked on five iPad sizes in both orientations. The DMG here is macOS; the iPad build is in testing.

- **The frame rate, fixed.** Heavy fire used to drop the Mac into the 40s and the iPad mini into the 20s. Both now stay well above 50, Level 10 at full strength included. Every sound effect is decoded once at launch into memory and played from a pool of audio voices that are already running, instead of a player that reopened and re-prepared its file on the frame that fired the shot. Measured: **11.7ms a shot, down to 0.03ms.**
- **It was never the graphics.** The glow, the nebula and the board all had a turn as the suspect. Turning each of them off changed nothing, and the log is what settled it — the frame rate tracked the *sound*, not the picture. There is a note in [IOS-Port.md](IOS-Port.md) §6a about why the Mac profile pointed the wrong way for so long.
- **The NEON GLOW switch now actually turns the glow off.** It cleared the blur but left SpriteKit still rendering the playfield to an offscreen buffer and compositing it back — so the expensive half of the pass stayed. It does less work with it off now, on both platforms.
- **Test Mode is the same on Mac and iPad.** Click and hold the version badge on the play screen to arm it, tap it to clear, and `POWER · RAID · LEVEL` appear underneath. The Mac keeps `⌘T` and the `P` / `R` / `V` keys as well — the badge is the second door, not a replacement.
- **The last wave says so.** Clearing wave 10 held on a silent board for two and a half seconds before the high score panel appeared, which read as a crash. It announces "ALL 10 WAVES CLEARED" now, and a win by checkmate — the one route that never raised a banner — says so too.

---

## V 1.2 (Build 9)  Better Screen Resizing

*The release that gets the Mac game ready for iPad and iPhone. Most of the work is underneath: the playfield is laid out rather than scaled, everything drawn on it is sized against the board, and the game loop stopped doing several things sixty times a second that only needed doing when they changed.*

- **Better resizing** — The board and gutters lay themselves out from the window's actual size, instead of a fixed 960×700 canvas scaled into place with black bars around it. A smaller window shrinks the board to fit rather than letting it run off the edge.
- **"SHOOT SOMETHING!"** — Three beats without firing *and* four hits on your pieces in that time raises a red reminder in the gutter. Both conditions, so it only speaks when going quiet is actually costing you.
- **`M` mutes the music**, from anywhere. It always did; it was never written down. Now on the How To Play screen beside pause and quit.
- **The Nuke shake** — The blast shakes the board on its own account now, instead of borrowing whatever its victims happened to produce. The slow motion no longer snaps as it comes back up to speed.
- **The log panel is now a Test Mode feature** — `L` and the Settings row both require ⌘T first. Leaving Test Mode closes it.
- **Everything on the playfield scales with the board.** The ship, laser rounds, raider scouts, score pops, explosions, the move dots and the screen shake all follow the squares now.
- **A pass over the game loop.** The turn clock, the power-up alley and the fleet's back rank were all recomputed sixty times a second to say what they already said. They are driven by change now.
- **The title screen.** Its two cycling words re-rendered their type every frame, which cost more than playing the game did. Same look, 53% CPU down to under 40%, a steady 60fps in play.
- **The sky is back.** The starfield and the nebula sometimes never appeared at launch. Both rebuild whenever the window changes size now.
- **Groundwork for iPad and iPhone** — the refactor ahead of the iOS port. The plan is in [IOS-Port.md](IOS-Port.md).

---

## V 1.1 (Build 8)  Chess Hints

- **Chess Hints** — The three pieces worth moving glow, and the gutter names them: "MOVE A PAWN", or "MOVE A PAWN / OR QUEEN" or similar. Aimed at the large share of players who may not know chess.
- **Near-equal moves are shown whole** — At the opening the eight pawns and both knights glow and the text says "MOVE A PAWN OR KNIGHT". Where one move is genuinely better, the usual shortlist of three stands.
- **Cadet is now the default difficulty** — The game asks a new player to run two control schemes at once against a five-second clock. The user can change to Ace mode for a harder game.
- **The hard mode is now called Ace**, not Pilot — Anyone upgrading from 1.0 will find their difficulty back at Cadet, since the old setting no longer parses.
- **Hints on for Cadet mode** — And are off for Ace. However, the player can set Hints independently.
- **Arcade Hints** — The other half of the game gets the same treatment. Three beats without firing raises "PRESS SPACE TO FIRE!"  Ten seconds of firing without steering raises "USE ARROWS TO MOVE!" Hints rearm at each level.
- **Friendly fire is called out** — The second time one of your own lasers damages one of your own pieces, a red "YOU HIT / YOUR ROOK!" names the piece for three seconds. Your own pieces sit in your firing line on every shot, and nothing on screen said so. Not the first hit, because a stray shot is the game being played, and clearing a nearly-dead piece out of your own lane is a real move.
- **Under the hood** — The hint search runs at depth 2, matching the engine that plays Black. At depth 1 nothing sees Black's reply, every quiet move scored the same, and the promotion bias became the only term separating them — so the hint said "MOVE A PAWN" every single beat. The hint ranks distinct source squares rather than moves, because the top four entries in an open position are routinely one knight going to four squares. It orders strictly rather than picking at random among near-equal moves the way the engine does, since advice that reshuffled every beat would read as a bug. Eight new tests cover the ranking and the gutter text.

---

## V 1.0 (Build 7)  First official release

- **Feature complete, and submitted to App Store Connect for approval** — free, no in-app purchases, no data collected.
- Universal binary, signed, notarized and stapled. Release signing moved to automatic so the same archive can produce both the notarized DMG and an App Store build.
- Privacy policy published at [mzurlocker.com/privacy](https://www.mzurlocker.com/privacy). The app is sandboxed with no network entitlement, so "collects nothing" is literally true rather than a promise.
- Minor edits throughout.

---

## V 0.6 (Build 6)  Standard Mac menus

- **Standard Mac menus** alongside the hotkeys, and ⌘Q now asks before discarding a game in progress.
- **A / D steer the ship**, alongside the arrow keys.
- **Test Mode is ⌘T**, with the same A, P, R and V options behind it.
- Misc bug fixes, an updated title music track, and a fix for a broken download link.

---

## V 0.5  Soundtrack expanded and a test harness

- **Nine more tracks** from [Zudio](https://www.mzurlocker.com/zudio), including music for the end of a game.
- **A built-in test harness** — covering the chess rules, the fleet, scoring and the audio, run from Xcode with ⌘U.

---

## V 0.4  A soundtrack, and the game watches itself

- **A soundtrack** — ten tracks, one per level, generated by [Zudio](https://www.mzurlocker.com/zudio) in a Motorik Arcade style written for this game. The music escalates with the waves, and hands over to the title theme whenever Settings or How To Play is open.
- **Better error handling** — the game watches itself while you play. Anything that goes wrong is said on screen rather than failing quietly, and the diagnostics log records enough to work out why.

---

## V 0.3  Nebula background

- **Nebula background** — a coloured haze that changes with the level, faint at first and building as the waves get harder. Can be switched off in Settings.

---

## V 0.2  Settings panel and Cadet mode

- **Settings panel** — music and sound each get a switch and a volume slider, and the display settings include a board grid that dials from open space up to named rows and columns. Settings persist between sessions.
- **Cadet mode** — an easier on ramp. The chess clock runs long, the fleet and its shots are slower, you get five lives, and power-ups carry across levels.
