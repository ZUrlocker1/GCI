# GCI design-session handover — 2026-10-15

Written for a fresh session with no memory of the design conversation. **Read this first, then the two living documents it points to.**

## Read these instead of expecting me to restate them

- `/Users/urlocker/Downloads/GCI/docs/gci-game-design.md` (3,938 lines) — the authoritative design. Every ruling below is recorded there.
- `/Users/urlocker/Downloads/GCI/CLAUDE.md` (285 lines) — the project brief Claude Code loads each session.
- `/Users/urlocker/Downloads/GCI/docs/implementation.md`, `change-log.md`, `art-handoff.md`, `IOS-Port.md`, `app-store-listing.md` — written by later sessions, not this one.

## State

**The repo is far ahead of this session.** This design session ended around the Phase 0 scaffold: I wrote stub Swift files, `CLAUDE.md`, `SETUP.md`, `README.md` and `.gitignore`. When the handover was requested (2026-10-15) the folder held an Xcode project, `project.yml`, `release-dmg.sh`, a `GCI-1.4.dmg`, a 285-line `CLAUDE.md`, an audio engine rewrite, a `KeyPress`/`MacInputAdapter` input layer and an iOS port doc. None of that is my work, and I read only fragments of it. Treat the code on disk as truth and anything I describe about Swift files as stale.

**Verified this session (I checked it):**
- The design doc's numbering is unique and sequential after the §19/20/21 fix (grep of `^## ` headings), though §15 and §18 sit out of document order.
- The stale items fixed in the audit are gone: heartbeat references, 3-character initials, "chipped sprite", 0.75s AUTO flash, King HP 10, promoted Queen HP 8.
- Sprite atlas at `/Users/urlocker/Downloads/GCI/assets/GCI.spriteatlas/` has 3 variants per piece (base, `-d1`, `-d2`) plus 4 ships; I viewed the white pieces. Queen was redrawn (orb crown) after I flagged it looked like the rook.
- `/Users/urlocker/Downloads/node_modules` no longer exists. `/Users/urlocker/Downloads/package.json` and `package-lock.json` still do (leftover from the docx skill; harmless).

**Claimed, not verified:**
- The final audit pass: a background agent reported all six doc-only fixes (aggressive-mode definition §4.4, Kamikaze Escort and Flagship shield §6.3, Escort fallback spawn §6.3, starfield phasing note §12.4, Phase 2.2 wording). I did not re-read them.
- The renumbering agent reported §23/24/25 subsections correct; I spot-checked headings only.
- The competitor and music-source research came from web searches. Licence terms (HydroGene CC0, Motion Monkey CC0) were read from search snippets and fetched pages, not from licence files.

## Decisions and rulings (Zack's, don't reopen)

- **Aesthetic:** retro-inspired but modern. Neon outlines, Tron-like, bloom at runtime via `SKEffectNode`. Never low-res art scaled up. Sprites are high-res (160×232 up to 208×264 px @2x). Default linear filtering, not `.nearest`.
- **Win condition:** checkmate, by capture or by shooting the king. Clearing every piece also wins. Zack wants this playtested against "must clear the board". A departure from classic invaders, by design.
- **High scores:** 8-character initials (the mockup's 3 is wrong). Top 10 stored, top 5 shown, with level reached.
- **Auto-move on timer expiry:** constrained to the selected piece; unconstrained only if that piece has no legal move.
- **Black chess move timing:** fires after the fleet's lateral sweep. Fleet sweep must always be smooth; padding black's move delay is fine, especially at Level 1.
- **Multi-move turns (Level 3 and 5):** all moves chosen together, animated simultaneously.
- **Fleet descent changes the chess game.** Logical squares update on each descent via a force-place that bypasses legality. A black piece landing on a white piece's square crushes it (instant removal, animation, no points; crushing the white king loses).
- **Multi-shot stacks:** laser cap 2, +1 per pawn promotion, hard cap 6, resets each level.
- **Shield resets at level end. Regen timer cancels when the level ends.** Diagonal shots use physics bodies. Shooting the king at checkmate scores both bonuses (800).
- **AUTO flash:** 0.5s.
- **Music:** adaptive-tempo "heartbeat" dropped (rate-shifting causes pitch artefacts). Instead a per-level track pool: L1 three, L2–4 two, L5+ one; BPM bands in §19.4. Sources in priority order: purchased itch.io MIDI re-rendered in Logic Pro, Zudio Motorik/Kosmic `.m4a`, free CC0/CC-BY libraries. **No commercial licences.**
- **SFX:** Motion Monkey CC0 pack as the base; jsfxr/ChipTone/Bfxr for gaps.
- **Trademark:** never use "Recharged" in public-facing text (Atari mark). Candidates listed at the top of the design doc, including Resurgence. Internal docs may keep it.
- **Tagline:** "40 years in the making!" Origin story (spring 1983, Apple II, TASC, HRCG chess font) is in the doc's Origin & History section.

## Gotchas and corrections

- Each chat-session Edit failure so far was an em-dash or whitespace mismatch; Read the exact lines first.
- The `docx` skill dropped `node_modules` into `~/Downloads`. Don't run it with Downloads as the working directory.
- `GameScene.shared` singleton and `Piece` code I wrote are superseded; don't rebuild from my stubs.
- The design brief PDF's mockups are wrong in two places (3-char initials, clear-the-board win). Doc rulings override the PDF.
- The working directory was `/Users/urlocker/Downloads` (a parent holding unrelated projects, per global memory). It is now `/Users/urlocker/Downloads/GCI`; memory is scoped to the directory, so memory saved here will not follow a session opened in the parent.

## Open items, in order

1. **Confirm what the doc and code agree on.** The doc is 3,938 lines; later sessions edited it. Diff any section you rely on against the code before trusting either.
2. Playtest the win-condition hypothesis (checkmate vs clear-the-board), per Zack.
3. Remaining low-priority audit items not explicitly ruled on: regenerated-pawn capture vs regen cap; shooting your own promoted Queen scores nothing (confirm intent); Level 5 "fleet rush" now follows the force-place rule.
4. Settle the public product subtitle word (Resurgence, Overdrive, etc.) before App Store copy.

## Pointers

- Project root: `/Users/urlocker/Downloads/GCI`
- Mockups: `/Users/urlocker/Downloads/GCI/mockups/`; brief: `/Users/urlocker/Downloads/GCI/docs/gci-design-brief.pdf`
- Music: `/Users/urlocker/Downloads/GCI/assets/music/` (zips)
- Per global memory: commit locally, never push; never touch version/build numbers; run the test suite before a DMG or submission, not every edit; mute with M before running the app.

## Kickoff prompt

```text
Working directory: /Users/urlocker/Downloads/GCI

Read in full, in this order:
1. /Users/urlocker/Downloads/GCI/docs/2026-10-15-design-session-handover.md
2. /Users/urlocker/Downloads/GCI/CLAUDE.md
3. /Users/urlocker/Downloads/GCI/docs/gci-game-design.md

Galactic Chess Invaders is a macOS SpriteKit arcade-chess hybrid (1983 Apple II origin). The design is settled and recorded in the design doc; the handover lists the rulings not to reopen. The repo has moved well past the stubs the design session wrote, so trust the code on disk over anything the handover says about Swift files. Task: reconcile the design doc against the current code for the sections I name next, and flag any place they disagree rather than silently changing either.

Constraints: commit locally, never push; never touch version or build numbers; do not use the word "Recharged" in anything public-facing; free/CC0/CC-BY music and SFX only.
```

## Model recommendation

Opus for the reconciliation work (judgment across a 3,900-line doc and a live codebase). Sonnet subagents are fine for mechanical grep-and-compare passes once the criteria are fixed.
