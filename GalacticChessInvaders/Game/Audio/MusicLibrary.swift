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

enum MusicLibrary {

    /// The track bundled since the beginning, and the fallback for every pool.
    static let fallback = "GCI-intro"

    /// What plays over Settings and How To Play, at any point in a run. The
    /// panels are a step out of the game, and the title theme is what the game
    /// sounds like when you are not in it. It opens on a fade of its own, which
    /// is why the hand-over only has to fade the outgoing track.
    static let panelTrack = "GCI-intro"

    /// The title screen and the attract-free menu behind it.
    static var titlePool: [String] { ["GCI-intro"] }

    /// One track per wave, ordered so the music escalates with the game.
    ///
    /// Tempo climbs 125 to 156 BPM, with a deliberate dip at Wide Orbit — that
    /// level widens the sweep but is no harder than the one before it, so it
    /// gets the brightest mode in the set and a slower beat, as a breath before
    /// Crossfire. The modes alternate major-feeling and minor-feeling and never
    /// run three the same way, so no stretch of the game sounds like one long
    /// piece. Crossfire's harmonic minor is the most unsettled thing here, and
    /// Blitz gets the fastest track and the darkest mode.
    ///
    /// Written by Zudio in its Motorik Arcade style, re-encoded to 80k/32kHz to
    /// match GCI-intro — 128k/44.1k would have put 28MB of music in a 7MB app.
    static func pool(forLevel level: Int) -> [String] {
        switch max(1, level) {
        case 1:  return ["Leise-Dunkels"]        // 125 E Mixolydian, relaxed
        case 2:  return ["WelleZ-Machine"]       // 134 E Aeolian, intense
        case 3:  return ["BlitzSchnork"]         // 138 C Mixolydian, peppy
        case 4:  return ["ZeigSchnork-Zero"]     // 139 B Dorian, focused
        case 5:  return ["Frankfurt-Overdrive"]  // 140 A Dorian, intense
        case 6:  return ["KraftSchmaltz"]        // 137 A Lydian, peppy — the breath
        case 7:  return ["BierWunderwaffe"]      // 140 G HarmonicMinor, intense
        case 8:  return ["SchnorkPunkt"]         // 147 B Mixolydian, focused
        case 9:  return ["Leipzig-1999"]         // 147 B Aeolian, focused
        default: return ["Bochum-Level"]         // 156 C Phrygian — Blitz
        }
    }

    /// Picks from a pool, avoiding `previous` when there is anything else to
    /// choose. Returns the fallback for an empty pool, so a typo in the table
    /// costs a wrong track rather than silence.
    static func choose(from pool: [String], avoiding previous: String?) -> String {
        guard !pool.isEmpty else { return fallback }
        let fresh = pool.filter { $0 != previous }
        return (fresh.isEmpty ? pool : fresh).randomElement() ?? fallback
    }
}
