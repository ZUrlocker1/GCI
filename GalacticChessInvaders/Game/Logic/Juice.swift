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

    // Raised twice. The first pass was set cautiously and measured afterwards
    // at 1.5pt over three frames for a laser hit — below anyone's threshold.
    // These are the amplitudes that read, alongside `offset`'s change from a
    // random walk to an alternating displacement, which is most of why they
    // now land: the *displacement* is what the eye sees, and a random walk
    // spends most of its frames near the middle.
    static let micro  = Shake(amplitude: 4.0,  duration: 0.10)
    static let small  = Shake(amplitude: 7.0,  duration: 0.20)
    static let light  = Shake(amplitude: 10.0, duration: 0.26)
    static let medium = Shake(amplitude: 15.0, duration: 0.40)
    static let heavy  = Shake(amplitude: 24.0, duration: 0.60)

    /// Every player laser landing (§24.1's "micro-shake"). Fires constantly, so
    /// it has to be barely perceptible on its own and only register as weight.
    static let laserHit = micro
    static let shipDestroyed = medium
    /// §24.1 gives the flagship medium at a shorter 0.3s. Not built yet.
    static let flagshipDestroyed = Shake(amplitude: medium.amplitude, duration: 0.30)

    /// What destroying a piece is worth.
    ///
    /// §24.1 names only the queen and the king, and taken literally that leaves
    /// the feature all but absent: each of those dies at most once a wave, so a
    /// player can clear a whole level of pawns and rooks and never see the
    /// board move. The officers get a small shake so destruction has weight
    /// during ordinary play, and the gap to the queen and king is kept wide
    /// enough that those two still land as events.
    ///
    /// Pawns stay silent deliberately. They die constantly — eight a wave, two
    /// shots each — and a board that shakes on every pawn is a board that is
    /// always shaking, which is the same as never.
    static func shake(forDestroying type: PieceType) -> Shake {
        switch type {
        case .king:                    return heavy
        case .queen:                   return light
        case .rook, .bishop, .knight:  return small
        case .pawn:                    return .none
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
