# Galactic Chess Invaders Change Log

## V 1.1 (Build 8)  Chess Hints

- **Chess Hints** — The three pieces worth moving glow, and the gutter names them: "MOVE A PAWN", or "MOVE A PAWN / OR QUEEN" when the shortlist is mixed. The advice stands for the whole beat, from the moment it becomes White's move until that move is made, whether the player makes it or the clock runs out and makes it for them. Aimed at the large share of players who will download a free chess game without reading chess.
- **Near-equal moves are shown whole** — At the opening the eight pawn moves score 31 apiece and the knights 0, but that gap is entirely the promotion bias: turn it off and the knights score 0 while the pawns score −33, reversing the order. A gap a tuning constant can flip is not a recommendation, so the hint declines to rank inside it — the opening lights all eight pawns and both knights, and says "MOVE A PAWN OR KNIGHT". Where one move is genuinely better, the usual shortlist of three stands.
- **Cadet is now the default difficulty** — The game asks a new player to run two control schemes at once against a five-second clock. A free download that beats someone in ninety seconds is uninstalled rather than persevered with, and anyone who wants the harder game finds Ace in the first row of Settings. An existing player's saved choice is untouched.
- **Hints follow difficulty, until you disagree** — On for Cadet, off for Ace. Once the player throws the Chess Hints switch themselves it is theirs, and changing difficulty never moves it again.
- **Arcade Hints** — The other half of the game gets the same treatment. Three beats without firing raises "PRESS SPACE TO FIRE!" under the hint. Ten seconds of firing without steering raises "USE ARROWS TO MOVE!". Both go the instant the control is used.
- **Friendly fire is now called out** — The second time one of your own lasers damages one of your own pieces — the same piece twice, or two different ones — a red "YOU HIT / YOUR ROOK!" names the piece for three seconds. Ordinary player lasers carry White's pieces in their contact mask (only Gatling Barrage drops it, so the power-up cannot demolish your own position), which means your pieces sit in your firing line on every shot — a standing rule with nothing on screen to teach it. Not the first hit, because a stray shot is the game being played and clearing a nearly-dead piece out of your own lane is a real move; and it names what just happened rather than advising about the future, which is the wrong tense for a shot that has already landed.
- **Arcade Hints re-arm at each level** — A run is long and a wave break is a natural place to forget. They cost nothing to a player who remembers: the firing hint waits three beats, and by Level 2 anyone still playing is firing within one. All three are independent of the Chess Hints switch — someone who turned chess hints off can still be the one who has not found the trigger.
- **The hard mode is now called Ace**, not Pilot — Ace reads as earned skill where Pilot is only a rank, and reflexes are what the mode actually asks for. Deliberately not "Grandmaster": the game does not require chess ability and its own description says so, and a name implying otherwise would turn away the player the Cadet default exists to welcome. A saved "pilot" no longer parses and falls through to Cadet.
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
