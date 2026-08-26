// Juice.swift
// §24's game feel, as data: shake intensities and decay, hit-freeze lengths,
// score-pop timings, the venting threshold. Pure Swift — the rendering layer
// obeys this table rather than carrying its own numbers, so "how hard does a
// queen shake the board" is answerable and testable in one place.
//
// The governing constraint is §24's own: "punchy, not nauseating". This board
// is already busy — bloom, starfield, charge-up glows, eroded pieces — so the
// amplitudes here are deliberately restrained, and only the two events §24.1
// actually names shake at all on a piece kill.

import CoreGraphics
import Foundation

enum Juice {

    // MARK: - Screen shake (§24.1)

    struct Shake: Equatable {
        /// Peak offset in points, before decay.
        let amplitude: CGFloat
        let duration: TimeInterval

        static let none = Shake(amplitude: 0, duration: 0)
        var isSilent: Bool { amplitude <= 0 || duration <= 0 }
    }

    // Three tiers, and nothing below them. §24.1 also gives a "micro-shake" to
    // every laser landing; that was built and removed. A cue that fires several
    // times a second cannot be obvious without being constant, and a board
    // that is always moving carries no information — spending the shake on the
    // rare events is what lets them be unmistakable.
    //
    // Large, deliberately. These now happen a handful of times in a wave, so
    // "punchy, not nauseating" (§24.1) has room: heavy is 30pt of displacement
    // on a board with 224pt of margin, roughly half a square.
    static let light  = Shake(amplitude: 14.0, duration: 0.26)
    static let medium = Shake(amplitude: 20.0, duration: 0.40)
    static let heavy  = Shake(amplitude: 30.0, duration: 0.60)

    static let shipDestroyed = medium
    /// §24.1 gives the flagship medium at a shorter 0.3s. Not built yet.
    static let flagshipDestroyed = Shake(amplitude: medium.amplitude, duration: 0.30)

    /// What destroying a piece is worth: the queen and the king, and nothing
    /// else — §24.1's own list.
    ///
    /// The officers had a tier of their own for a while, on the reasoning that
    /// the queen and king die at most once a wave each and the feature would
    /// otherwise go unseen. Backwards: a shake that turns up on every rook is
    /// scenery, and the two kills that decide a wave stop being announced by
    /// it. Rarity is what the effect is *for*, so the answer was to make the
    /// rare ones unmissable rather than to add more of them.
    static func shake(forDestroying type: PieceType) -> Shake {
        switch type {
        case .king:                              return heavy
        case .queen:                             return light
        case .rook, .bishop, .knight, .pawn:     return .none
        }
    }

    /// Exponential decay, per §24.1. `exp(-5t)` is down to 0.7% of peak by the
    /// end of the window, so the tail is inaudible rather than a slow drift
    /// back to centre — which is the difference between punchy and nauseating.
    static func amplitude(_ shake: Shake, elapsed: TimeInterval) -> CGFloat {
        guard !shake.isSilent, elapsed >= 0, elapsed < shake.duration else { return 0 }
        return shake.amplitude * CGFloat(exp(-5 * elapsed / shake.duration))
    }

    /// Where to put the playfield this frame, given the last frame's angle.
    /// Returns the offset and the angle to carry forward.
    ///
    /// Two things here matter more than the amplitude did:
    ///
    /// *Full displacement.* Picking x and y independently from `-a...a` — the
    /// obvious way, and the first way — averages 0.5a and lands near the centre
    /// on a good fraction of frames. Choosing a *direction* and moving the full
    /// distance means every frame is displaced by exactly the amplitude.
    ///
    /// *Alternation.* Turning roughly 180° each frame makes consecutive frames
    /// land on opposite sides, so the eye sees a displacement of 2a between
    /// them. A random walk instead reads as blur or noise — it is doing
    /// something, but nothing that looks like an impact.
    static func offset(amplitude: CGFloat, lastAngle: CGFloat) -> (CGPoint, CGFloat) {
        let angle = lastAngle + .pi + CGFloat.random(in: -0.7...0.7)
        return (CGPoint(x: cos(angle) * amplitude, y: sin(angle) * amplitude), angle)
    }

    // MARK: - Hit freeze (§24.2)

    /// The pause before the explosion on a high-value kill. Small hits get
    /// none: a freeze on every pawn would read as the game stuttering.
    ///
    /// §24.2 asks for 2–4 frames. Two is 33ms — under the threshold at which a
    /// pause registers as anything, so the queen's freeze was doing nothing.
    /// The king's is longer than the doc's ceiling on purpose: its death is the
    /// level's climax, arriving with a 0.6s shake, a white flash and a 2.4x
    /// burst, and 67ms of stillness disappears underneath all that. A sixth of
    /// a second does not.
    static func freezeFrames(forDestroying type: PieceType) -> Int {
        switch type {
        case .king:  return 10      // 167ms
        case .queen: return 4       // 67ms
        default:     return 0
        }
    }

    /// Losing a life. Not in §24.2's list, which names only pieces — but this
    /// is the player's own death, and it should land at least as hard as the
    /// queen's.
    static let shipLossFreezeFrames = 6     // 100ms

    static let frameDuration: TimeInterval = 1.0 / 60

    static func freezeDuration(forDestroying type: PieceType) -> TimeInterval {
        TimeInterval(freezeFrames(forDestroying: type)) * frameDuration
    }

    static var shipLossFreezeDuration: TimeInterval {
        TimeInterval(shipLossFreezeFrames) * frameDuration
    }

    // MARK: - Score pop (§24.3)

    static let popRise: CGFloat = 30
    static let popDuration: TimeInterval = 0.8

    // MARK: - Venting (Phase 3.3)

    /// §20's "smoke particle trail on pieces at ≤50% HP". Rendered as drifting
    /// embers in the piece's own glow colour rather than grey smoke — grey
    /// reads as mud against a neon-on-black board, and the point is to show a
    /// piece is failing, not to simulate combustion.
    static let ventThreshold = 0.5

    static func vents(hp: Int, maxHP: Int) -> Bool {
        guard maxHP > 0, hp > 0 else { return false }
        return Double(hp) / Double(maxHP) <= ventThreshold
    }
}
