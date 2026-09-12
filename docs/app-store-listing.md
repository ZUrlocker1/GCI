# Galactic Chess Invaders — Mac App Store listing
### Free app, no in-app purchases · prepared 12 September 2026

---

## FIELD-BY-FIELD

### App Name *(30 char limit)*

```
Galactic Chess Invaders
```
23 characters.

### Subtitle *(30 char limit)*

```
Chess at arcade speed
```
20 characters. Alternates: `Play chess. Dodge the chess.` (28) · `An arcade game about chess` (26)

### Promotional Text *(170 char limit — editable without a new build)*

```
A real game of chess, except Black's pieces are also shooting at you. Move your pieces, fly your ship, and survive ten waves on a five-second clock. Free, no ads.
```
159 characters.

### Keywords *(100 char limit, comma-separated, no spaces after commas)*

```
chess,arcade,retro,shooter,puzzle,strategy,board,indie,space,80s,classic,single player,brain
```
92 characters. **Do not include "invaders"** — see Review Risks below.

### Description *(4000 char limit)*

```
A real game of chess plays out on screen — legal moves, real check and checkmate, a live engine
playing Black. Except Black's pieces are also a fleet, sweeping sideways, dropping a rank at a time,
and shooting at you.

You play both halves at once. The mouse commands White's pieces. The keyboard flies a laser ship
along the bottom of the board. A five-second clock runs on every turn. Reflex decides whether you
survive; the chess decides what you are surviving against.

The two halves are genuinely entangled. Shoot a black piece and it leaves the chess position. Let one
descend onto your rook and the rook is gone. Checkmate the black king to clear the wave — or just
shoot it. Walk a pawn to the eighth rank and you promote it and upgrade your guns at the same time,
which is the one moment the game asks you to do both jobs in the same second.

TEN WAVES, TEN IDEAS

Each level introduces a mechanic rather than a difficulty multiplier. Pawns start shooting back.
Black takes two chess moves a turn, then three. The fleet's sweep widens. Bishops open fire along the
diagonal. Regenerated pawns arrive armoured and shrug off lasers. The black king raises a forcefield
and draws a weapon of its own. Then Blitz — the last wave, which takes most of your advantages away
and drops the clock to three seconds.

POWER-UPS

Shoot the green scouts that drift across the board and you will pick up rapid fire, a gatling burst,
a shield, a freeze, or a nuke. Your laser cap rises as you go and resets with each wave.

MADE FOR PLAYERS, NOT CHESS PLAYERS

You do not need to be good at chess. The engine plays fast and shallow on purpose, the clock is short
enough that nobody is calculating, and Cadet mode gives you a longer clock, a slower fleet, five
lives and power-ups that carry between levels.

WHAT ELSE IS IN THERE

• Ten levels, each with a distinct mechanic
• Cadet and standard difficulty
• An original soundtrack — a track per level, escalating with the waves
• Full arcade audio
• A board grid you can dial from open space up to named rows and columns
• A nebula backdrop that deepens as the waves get harder, or switch it off
• Local high score table
• Universal binary, native on Apple Silicon and Intel
• No ads, no in-app purchases, no accounts, no data collected

FORTY YEARS IN THE MAKING

The first version was written in 1983 on an Apple II, in Applesoft BASIC run through a compiler to
make it fast enough to be playable. This is that game, finished.
```

Roughly 2,150 characters. Room to grow if you want more.

### What's New *(first release — leave blank, or:)*

```
First release on the Mac App Store.
```

### Category

**Primary:** Games → Strategy
**Secondary:** Games → Arcade

*Strategy first is the right call: it is a less crowded shelf than Arcade and the chess angle is the
differentiator. Arcade second catches the other half.*

### Copyright

```
© 2026 M. Zack Urlocker
```

### URLs

| Field | Value | Status |
|---|---|---|
| Support URL | `https://github.com/ZUrlocker1/GCI` | Works today |
| Marketing URL | `https://github.com/ZUrlocker1/GCI` | Optional |
| Privacy Policy URL | `https://www.mzurlocker.com/privacy` | Page exists — add the GCI section before submitting |

---

## APP PRIVACY

The questionnaire answer is **"Data Not Collected"** across the board. The game has no network code,
no analytics, no accounts. High scores and settings are local only.

**A Privacy Policy URL is still mandatory**, even for an app that collects nothing.
`https://www.mzurlocker.com/privacy` already exists and already carries per-app sections for Tahoe5,
Tahoe21 and Zudio. It needs a matching section for this game before submission — reviewers check
that the app is named in the policy it points at. The text to paste is in
[privacy-policy.md](privacy-policy.md).

---

## AGE RATING

Expect **4+**, or **9+** at worst.

The questionnaire asks about cartoon or fantasy violence. Chess pieces are shot and explode; there
are no human figures, no blood, no realistic violence. Answer "Infrequent/Mild" for Cartoon or
Fantasy Violence and "None" for everything else.

No gambling, no contests, no unrestricted web access, no user-generated content.

---

## REVIEW RISKS

**1. The word "Invaders."** Taito owns the *Space Invaders* trademark and is known to enforce it.
The app name itself is defensible — "invaders" is a common noun and the game is not a clone of the
1978 layout. What is **not** defensible is metadata that invites the comparison.

- Do **not** put "invaders" in the keywords field
- Do **not** write "Space Invaders" anywhere in the description, promotional text or screenshots
- The repo was scrubbed on 12 Sep 2026: README, CLAUDE.md, the design doc, the art handoff and the
  Swift source now say "arcade invader fleet." The shipped How To Play screen said "a Space Invaders
  fleet" and now says "an invader fleet." Three mentions remain in `gci-game-design.md`, all in the
  prior-art comparison, where naming the real product is factual and necessary — leave them.

**2. Test Mode.** ⌘T unlocks A, P, R and V — auto-play, free power-up, summon raider, skip level.
Reviewers sometimes treat hidden developer features as undocumented functionality. It is behind a
deliberate gate and is documented on the How To Play screen, which should be enough, but be ready to
explain it in the review notes.

**3. The diagnostics log.** `L` opens a developer panel in the shipping build. Harmless, but mention
it in the review notes rather than letting a reviewer find it and wonder.

**Suggested App Review notes:**

> Galactic Chess Invaders is a single-player arcade/chess hybrid. It is free, has no in-app
> purchases, collects no data and makes no network requests.
>
> Two features are worth flagging so they do not look undocumented. ⌘T toggles a Test Mode that
> enables four keys (A, P, R, V) for auto-play, power-ups, raiders and level skip — it is documented
> on the in-app How To Play screen. The L key opens a diagnostics log panel, which ships
> deliberately so that players can report problems with detail.

---

## SCREENSHOTS — WHAT TO CAPTURE

**Accepted sizes (pick one and be consistent):** 1280×800 · 1440×900 · 2560×1600 · 2880×1800.
2880×1800 is the safest — it downsamples cleanly and looks sharp on Retina.

Two to three is plenty for a free game. Order matters; the first is the one most people see.

### Shot 1 — mid-wave, the whole premise in one frame

The most important one. It has to show **both halves happening at once**, so it needs:

- A partly cleared board — black pieces missing, some visibly damaged
- At least one laser in flight
- The ship at the bottom, not centred
- The turn clock visibly running
- A mid-range level (4–7) so the nebula has colour and the board is not pristine

Best captured a few seconds into a wave, just after you have taken a piece or two.

### Shot 2 — Blitz, Level 10

The intensity shot. Full fleet, three-second clock, deepest nebula. The `BLITZ!` banner moment works
if you can catch it, but a busy mid-Blitz frame is better than the banner, because the banner hides
the board.

*Note: `docs/GCI blitz.jpg` is a YouTube thumbnail with a play button burned into it — do not use it.*

### Shot 3 — the title screen *(optional)*

Clean, shows the name and the high score table, and gives the set somewhere to rest. Skip it if you
would rather use both slots on gameplay; store listings reward action over menus.

### How to capture

1. Set the window to the size you want before you start — App Store screenshots cannot have rounded
   corners, drop shadows or a title bar, so capture the **window content only**.
2. `⇧⌘4`, then `Space`, then click the window captures the window — but it includes the shadow. Hold
   `⌥` while clicking to drop the shadow.
3. Or capture the full screen with `⇧⌘3` and crop to the game area.
4. Turn the diagnostics log **off** (`L`) before capturing.
5. Save into `~/Downloads/AppStoreScreenshots/GCI/`.

Capture them larger than you need and hand them to me — I will crop, resize to an accepted size and
check them against the requirements.

---

## PRE-SUBMISSION CHECKLIST

- [ ] **GCI section added to https://www.mzurlocker.com/privacy** — the only hard blocker; text in `docs/privacy-policy.md`
- [ ] Bundle ID registered in the developer portal — `com.zurlocker.GalacticChessInvaders`, team `K66MA9TR8Z`, no capabilities
- [ ] App Store Connect record created — macOS, name `Galactic Chess Invaders`, SKU `GCI-001`, English, then Pricing → Free
- [x] **Version bumped** — `MARKETING_VERSION` 0.6 → **1.0**, `CURRENT_PROJECT_VERSION` 6 → **7**
- [x] **Signing switched to Automatic** — Release no longer pins `CODE_SIGN_IDENTITY`; `CODE_SIGN_STYLE = Automatic`, team `K66MA9TR8Z`. Matches the ZudioiOS App Store target. Verified: Release builds and signs as "Apple Development: Zack Urlocker (DKP93R82F9)", universal, hardened runtime, sandboxed
- [ ] Archive and upload via Xcode Organizer
- [ ] App icon — `Resources/AppIcon.icns` carries a 1024×1024 rep, so this is covered. It is missing the 16pt and 32pt @1x members, which is cosmetic, not a blocker
- [ ] Screenshots at a single accepted size
- [ ] App Privacy questionnaire completed as "Data Not Collected"
- [ ] Age rating questionnaire completed
- [ ] Review notes pasted in — **left blank on the 1.0 submission (12 Sep 2026).** Paste it on any resubmission
- [ ] Sandbox entitlement — the Release build is sandboxed; confirm it still is
