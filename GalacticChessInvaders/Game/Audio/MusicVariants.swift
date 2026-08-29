// MusicVariants.swift
// Which variant of the frequently-heard tracks is in force (§5).
//
// Split from `MusicLibrary` because that file is pure data — see its header.

import Foundation

/// Which variant of the frequently-heard tracks is in force (§5).
///
/// The rule has two halves. The *unlock* is per session: nothing varies until
/// the player has reached Level 3, so a first run always sounds like the game.
/// The *latch* is what keeps it coherent — the intro is heard on the title
/// screen and again in Settings and Info, and those must never disagree, so the
/// choice is made once on the way to the title and then held for the whole run.
/// A panel opening mid-run reads the latched value rather than rolling again.
///
/// The levels latch too, for a smaller reason: closing a panel calls
/// `restoreScreenMusic`, and a fresh roll there would swap the wave's track
/// underneath the player.
@MainActor
enum MusicVariants {

    /// Has the player reached the unlock level this session?
    private static var isUnlocked = false

    /// The intro variant in force, fixed for the length of a run.
    private static var intro = MusicLibrary.panelTrack

    /// The wave's track, fixed from the moment the wave starts.
    private static var levelTrack = MusicLibrary.fallback

    // MARK: - Session

    /// Unlocks once the player reaches Level 3. Called on every wave start, so
    /// it also covers a player who gets there, dies, and starts again.
    static func noteLevelStarted(_ level: Int) {
        guard !isUnlocked, level >= MusicLibrary.alternateUnlockLevel else { return }
        isUnlocked = true
        DiagnosticsLog.shared.log(.music, "alternates unlocked")
    }

    /// `X` is a clean slate, and that includes this: the player has to reach
    /// Level 3 again before anything varies. The ordinary way back from game
    /// over does *not* call this — reaching Level 3 once should keep the
    /// variation alive across the games that follow it.
    static func reset() {
        isUnlocked = false
        stingerCursor = 0
        intro = MusicLibrary.panelTrack
        levelTrack = MusicLibrary.fallback
    }

    // MARK: - The intro

    /// Re-rolled on the way to the title screen and nowhere else, so every
    /// return to the title is a fresh chance and everything inside a run agrees.
    static func rollIntro() {
        intro = pick(MusicLibrary.panelTrack)
    }

    /// What the title screen, Settings and Info all play.
    static var introTrack: String { intro }
    static var introPool: [String] { [intro] }

    // MARK: - The waves

    /// Rolls this wave's track and latches it. Call once, as the wave is built.
    static func beginLevel(_ level: Int) -> [String] {
        noteLevelStarted(level)
        let pool = MusicLibrary.pool(forLevel: level)
        levelTrack = pick(MusicLibrary.choose(from: pool, avoiding: nil))
        return [levelTrack]
    }

    /// The latched wave track, for handing the music back after a panel closes.
    static var currentLevelPool: [String] { [levelTrack] }

    // MARK: -

    // MARK: - End of run

    /// Round-robin rather than random: with four in the pool a random pick
    /// repeats often enough to read as a bug rather than as variety.
    private static var stingerCursor = 0

    /// What should see the player out, or nil if this run has not earned a
    /// piece of music and should get one of the loss stings instead.
    ///
    /// - `won`: the run is complete — its own track.
    /// - `odd`: a draw or stalemate — its own track, because the ending is
    ///   neither good nor bad and should not sound like either.
    /// - otherwise: a rotation, provided the player got past the first wave or
    ///   charted. Losing on Level 1 without troubling the table is the one
    ///   ending that has not earned anything, and it keeps the downer.
    static func endOfRunStinger(won: Bool, odd: Bool,
                                level: Int, madeTheTable: Bool) -> String? {
        if won { return MusicLibrary.winStinger }
        if odd { return MusicLibrary.oddEndingStinger }
        guard level > 1 || madeTheTable else { return nil }
        guard !MusicLibrary.runStingers.isEmpty else { return nil }
        let track = MusicLibrary.runStingers[stingerCursor % MusicLibrary.runStingers.count]
        stingerCursor += 1
        return track
    }

    /// `X` starts the rotation over with everything else.
    static func resetStingerRotation() { stingerCursor = 0 }

    // MARK: - Reading the log back

    /// Names a track the way someone reading the log wants to see it —
    /// `Intro Pre-Solstice`, `L1 Leise-Dunkels`, `Alt L2 Cycle-3-Midnight`.
    ///
    /// Derived from the tables rather than from what was rolled, so it stays
    /// right whoever started the track. Lives here rather than in
    /// `MusicLibrary` because it needs string literals that are not track
    /// names, which that file's guard forbids.
    static func describe(_ track: String) -> String {
        if track == MusicLibrary.panelTrack { return "Intro \(track)" }
        if MusicLibrary.alternates[MusicLibrary.panelTrack] == track {
            return "Alt Intro \(track)"
        }
        for level in 1...LevelManager.finalLevel {
            for original in MusicLibrary.pool(forLevel: level) {
                if track == original { return "L\(level) \(track)" }
                if MusicLibrary.alternates[original] == track {
                    return "Alt L\(level) \(track)"
                }
            }
        }
        if track == MusicLibrary.winStinger { return "Win \(track)" }
        if track == MusicLibrary.oddEndingStinger { return "Draw \(track)" }
        if MusicLibrary.runStingers.contains(track) { return "Sting \(track)" }
        return track
    }

    private static func pick(_ original: String) -> String {
        guard isUnlocked,
              let alternate = MusicLibrary.alternates[original],
              Double.random(in: 0..<1) < MusicLibrary.alternateChance
        else { return original }
        // Not logged here — the line that matters is the one AudioManager
        // writes when the track actually starts, and it says "Alt" itself.
        return alternate
    }
}
