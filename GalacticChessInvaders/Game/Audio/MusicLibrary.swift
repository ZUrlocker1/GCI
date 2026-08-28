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

    /// A wave's pool. Bands rather than one track per level: ten distinct
    /// tracks is a lot of bundle for a game whose waves last a couple of
    /// minutes, and the escalation reads better in steps than in ten shades.
    static func pool(forLevel level: Int) -> [String] {
        switch max(1, level) {
        case 1, 2:   return ["GCI-intro"]
        case 3, 4:   return ["GCI-intro"]
        case 5, 6:   return ["GCI-intro"]
        case 7, 8:   return ["GCI-intro"]
        default:     return ["GCI-intro"]   // 9, 10
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
