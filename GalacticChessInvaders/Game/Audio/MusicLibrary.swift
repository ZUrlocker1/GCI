// MusicLibrary.swift
// Which music plays where (§5, §20 Phase 5).
//
// One table. Adding tracks means adding filenames here and dropping the `.m4a`
// into `Resources/` — no other file changes. Every pool falls back to the one
// track that has always been bundled, so an incomplete set degrades to the
// current behaviour rather than to silence.
//
// §5 asks for a pool per level, picked from at random, avoiding the track that
// just played. That last part only bites once a pool has more than one entry,
// which is why the picking lives here rather than at each call site.

import Foundation

/// Tables only, and deliberately so: `typecheck.sh` treats **every string
/// literal in this file** as a track name that must be bundled, which is what
/// catches a typo in the tables below. A log message or any other incidental
/// string here would be read as a missing track — which is why the stateful
/// half of this lives in `MusicVariants.swift`.
enum MusicLibrary {

    /// The track bundled since the beginning, and the fallback for every pool.
    /// Named for its Zudio source, like every other track here — it was
    /// `GCI-intro` while it was the only one.
    static let fallback = "Pre-Solstice"

    /// What plays over Settings and How To Play, at any point in a run. The
    /// panels are a step out of the game, and the title theme is what the game
    /// sounds like when you are not in it. It opens on a fade of its own, which
    /// is why the hand-over only has to fade the outgoing track.
    static let panelTrack = "Pre-Solstice"

    /// The one alternate for each track heard often enough to wear out: the
    /// intro (title, Settings, Info) and the first two waves, which every run
    /// passes through. Levels 3-10 are not in here — a player reaches them
    /// rarely enough that the track is still a novelty.
    ///
    /// Keyed by the original, so a track with no entry simply never varies and
    /// an incomplete set degrades to the shipped behaviour rather than to
    /// silence — the same rule the pools follow.
    static let alternates: [String: String] = [
        // Kosmic, like Pre-Solstice itself — B Dorian / 118 BPM against
        // E Dorian / 88, so it is the same room at a slightly brisker walk.
        "Pre-Solstice": "Zephyron",
        // "Leise-Dunkels":  "…",   // L1
        // "WelleZ-Machine": "…",   // L2
    ]

    /// How often the alternate wins, once unlocked.
    static let alternateChance = 0.35

    /// Nothing varies until the player has reached this level in the session.
    /// A first run should sound the way the game sounds; the variation is for
    /// someone who has now heard the opening several times.
    static let alternateUnlockLevel = 3

    /// Where a panel-opening track may start, and how it gets there.
    ///
    /// An experiment that stuck: half the time the intro opens partway in
    /// rather than at the top, so a player who checks Settings four times in a
    /// run does not hear the same opening bars four times.
    ///
    /// The window is measured per track and the fade with it. Neither window is
    /// especially quiet — both sit within 0.2dB of their own track's average —
    /// so what the fade is really covering is arriving mid-texture. Zephyron
    /// gets twice the fade because its window carries the hotter transients
    /// (peaks to -6.4dB against Pre-Solstice's -13.0), and dropping into one of
    /// those at full level reads as a glitch rather than as a cut.
    private static let panelEntries:
        [String: (window: ClosedRange<TimeInterval>, fadeIn: TimeInterval)] = [
        "Pre-Solstice": (57...72,   1.0),
        "Zephyron":     (100...110, 2.0),
    ]

    /// A track with no window always opens at the top, which is also the other
    /// half of the coin toss for one that has a window.
    static func panelEntry(for track: String) -> (startAt: TimeInterval, fadeIn: TimeInterval) {
        guard let entry = panelEntries[track], Bool.random() else { return (0, 0) }
        return (.random(in: entry.window), entry.fadeIn)
    }

    /// How a wave's music takes over. Slower than the panel hand-over, with a
    /// beat of silence in the middle: a level start is a bigger seam than
    /// stepping into a menu, and cutting straight from one arcade track to
    /// another sounds like a mistake. The gap is what makes it read as
    /// deliberate rather than as a glitch.
    static let levelFade: TimeInterval = 1.2
    static let levelGap: TimeInterval = 0.5

    /// The title screen and the attract-free menu behind it.
    static var titlePool: [String] { [panelTrack] }

    /// One track per wave, ordered so the music escalates with the game.
    ///
    /// Tempo climbs 125 to 156 BPM, with a deliberate dip at Wide Orbit — that
    /// level widens the sweep but is no harder than the one before it, so it
    /// gets the brightest mode in the set and a slower beat, as a breath before
    /// Crossfire. The modes alternate major-feeling and minor-feeling and never
    /// run three the same way, so no stretch of the game sounds like one long
    /// piece.
    ///
    /// Blitz takes the harmonic minor — the most unsettled thing in the set —
    /// rather than the fastest track. Both tracks above 150 BPM are hinted
    /// "peppy", so nothing here is fast *and* dark, and a bright finale would
    /// undercut a three-second clock worse than a slower menacing one does. The
    /// last three waves fall 156 to 147 to 140 while getting darker, which is
    /// the trade this library forces.
    ///
    /// Written by Zudio in its Motorik Arcade style, re-encoded to 80k/32kHz to
    /// match Pre-Solstice — 128k/44.1k would have put 28MB of music in a 7MB app.
    static func pool(forLevel level: Int) -> [String] {
        switch max(1, level) {
        case 1:  return ["Leise-Dunkels"]        // 125 E Mixolydian, relaxed
        case 2:  return ["WelleZ-Machine"]       // 134 E Aeolian, intense
        case 3:  return ["BlitzSchnork"]         // 138 C Mixolydian, peppy
        case 4:  return ["Rattert-Z-Machine"]    // 140 C Lydian, peppy
        case 5:  return ["Frankfurt-Overdrive"]  // 140 A Dorian, intense
        case 6:  return ["KraftSchmaltz"]        // 137 A Lydian, peppy — the breath
        case 7:  return ["Bochum-Level"]         // 156 C Phrygian, peppy — the jolt
        case 8:  return ["SchnorkPunkt"]         // 147 B Mixolydian, focused
        case 9:  return ["Leipzig-1999"]         // 147 B Aeolian, focused
        default: return ["BierWunderwaffe"]      // 140 G HarmonicMinor, intense — Blitz
        }
    }

    /// Backups, if a wave's track turns out not to fit. Each matches its slot's
    /// mode and tempo band, so a swap does not break the alternation or the
    /// climb. All are in `~/Downloads/GCI Zudio Songs` and need the same
    /// 80k/32kHz re-encode.
    ///
    ///   L1      Dora               135 C Ionian, intense — the only other slow major
    ///   L6      Rattert-Z-Machine  140 C Lydian, peppy — the other brightest mode
    ///   L7      Blank-Knall        138 B Phrygian, focused — darker, less exotic
    ///   L10     Outer-Koln         154 E Mixolydian, peppy — fast and bright
    ///   L3/L8   Neu-Leipzig        140 A Mixolydian, focused — the sixth green flag
    ///
    /// L1 and L10 have almost no room: nothing else is under 134 or over 150.
    /// L5's cleanest like-for-like is Weit-Z-Maschine, 140 E Dorian.

    /// Picks from a pool, avoiding `previous` when there is anything else to
    /// choose. Returns the fallback for an empty pool, so a typo in the table
    /// costs a wrong track rather than silence.
    static func choose(from pool: [String], avoiding previous: String?) -> String {
        guard !pool.isEmpty else { return fallback }
        let fresh = pool.filter { $0 != previous }
        return (fresh.isEmpty ? pool : fresh).randomElement() ?? fallback
    }
}
