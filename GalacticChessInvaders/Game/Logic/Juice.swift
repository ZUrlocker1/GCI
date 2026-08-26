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

    static let micro  = Shake(amplitude: 1.5, duration: 0.05)
    static let light  = Shake(amplitude: 3.0, duration: 0.20)
    static let medium = Shake(amplitude: 5.5, duration: 0.40)
    static let heavy  = Shake(amplitude: 9.0, duration: 0.60)

    /// Every player laser landing (§24.1's "micro-shake"). Fires constantly, so
    /// it has to be barely perceptible on its own and only register as weight.
    static let laserHit = micro
    static let shipDestroyed = medium
    /// §24.1 gives the flagship medium at a shorter 0.3s. Not built yet.
    static let flagshipDestroyed = Shake(amplitude: medium.amplitude, duration: 0.30)

    /// What destroying a piece is worth. §24.1 names only the queen and the
    /// king; everything else is silent on purpose, or a wave of pawn kills
    /// would rattle the board continuously and the two that matter would stop
    /// meaning anything.
    static func shake(forDestroying type: PieceType) -> Shake {
        switch type {
        case .king:  return heavy
        case .queen: return light
        default:     return .none
        }
    }

    /// Exponential decay, per §24.1. `exp(-5t)` is down to 0.7% of peak by the
    /// end of the window, so the tail is inaudible rather than a slow drift
    /// back to centre — which is the difference between punchy and nauseating.
    static func amplitude(_ shake: Shake, elapsed: TimeInterval) -> CGFloat {
        guard !shake.isSilent, elapsed >= 0, elapsed < shake.duration else { return 0 }
        return shake.amplitude * CGFloat(exp(-5 * elapsed / shake.duration))
    }

    // MARK: - Hit freeze (§24.2)

    /// 2–4 frames before the explosion on a high-value kill. Small hits get
    /// none: a freeze on every pawn would read as the game stuttering.
    static func freezeFrames(forDestroying type: PieceType) -> Int {
        switch type {
        case .king:  return 4
        case .queen: return 2
        default:     return 0
        }
    }

    static let frameDuration: TimeInterval = 1.0 / 60

    static func freezeDuration(forDestroying type: PieceType) -> TimeInterval {
        TimeInterval(freezeFrames(forDestroying: type)) * frameDuration
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
