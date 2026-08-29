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
        DiagnosticsLog.shared.log(.audio, "alternates unlocked")
    }

    /// `X` is a clean slate, and that includes this: the player has to reach
    /// Level 3 again before anything varies. The ordinary way back from game
    /// over does *not* call this — reaching Level 3 once should keep the
    /// variation alive across the games that follow it.
    static func reset() {
        isUnlocked = false
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

    private static func pick(_ original: String) -> String {
        guard isUnlocked,
              let alternate = MusicLibrary.alternates[original],
              Double.random(in: 0..<1) < MusicLibrary.alternateChance
        else { return original }
        DiagnosticsLog.shared.log(.audio, "alternate \(alternate)")
        return alternate
    }
}
