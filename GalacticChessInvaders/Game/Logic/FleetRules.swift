// FleetRules.swift
// Pure rules for the black fleet's Space Invaders movement (design doc §23.6).
// No SpriteKit — the controller owns the animation, this owns the decisions.
//
// The central idea is that visual position and logical chess position are
// deliberately separated. The fleet slides and drops continuously on screen, but
// the chess engine only ever sees whole-rank descents:
//
//   wall bounce 1 → half-drop, board untouched
//   wall bounce 2 → half-drop, and *now* every black piece descends one rank
//
// So the engine always evaluates a legal-looking position, while the fleet
// visually occupies the space between ranks.

import Foundation

enum FleetRules {

    // MARK: - Descent

    /// Counts wall bounces so that every second one completes a full rank.
    struct DescentCounter {
        /// 0 when the fleet sits on a rank, 1 when it is halfway between.
        private(set) var halfDrops = 0

        /// Records a wall bounce. Returns true when the fleet has now fallen a
        /// full rank and the board must be updated.
        mutating func registerBounce() -> Bool {
            halfDrops += 1
            guard halfDrops >= 2 else { return false }
            halfDrops = 0
            return true
        }

        mutating func reset() { halfDrops = 0 }
    }

    /// The square one rank toward White, or nil if already on rank 1.
    /// A black piece that cannot descend has reached the bottom, which is a lose
    /// condition (§4) — wired up in Phase 3.2.
    static func descended(_ square: String) -> String? {
        let chars = Array(square)
        guard chars.count == 2,
              let rank = chars[1].wholeNumberValue,
              rank > 1 else { return nil }
        return "\(chars[0])\(rank - 1)"
    }

    /// Descent order matters: a piece must vacate its square before the piece
    /// above it arrives, or the upper one overwrites the lower. Lowest rank first.
    static func descentOrder(_ squares: [String]) -> [String] {
        squares.sorted { lhs, rhs in
            (Array(lhs)[1].wholeNumberValue ?? 0) < (Array(rhs)[1].wholeNumberValue ?? 0)
        }
    }

    // MARK: - Speed

    /// §21.2 — the fleet accelerates as it is thinned out, classic Invaders style.
    static func speedMultiplier(piecesRemaining: Int) -> CGFloat {
        switch piecesRemaining {
        case ...1:   return 2.5
        case 2...4:  return 2.0
        case 5...8:  return 1.5
        case 9...12: return 1.2
        default:     return 1.0
        }
    }

    /// Points per second for a level, after thinning is taken into account.
    static func sweepSpeed(level: LevelParameters, piecesRemaining: Int) -> CGFloat {
        level.fleetSpeed * speedMultiplier(piecesRemaining: piecesRemaining)
    }
}
