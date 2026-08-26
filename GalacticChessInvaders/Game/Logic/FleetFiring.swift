// FleetFiring.swift
// Decides who fires an invader shot each beat, and how many (§5.3, §21.1).
// Pure decisions, no SpriteKit — GameScene spawns the actual LaserNode at
// whatever square this picks.
//
// Cadence is once per chess beat, deliberately (§5.3: "Once per turn, 0–3
// random black pieces … fire"). It is not tied to fleet sweeps or to real time,
// for the same reason descent isn't: the beat is the game's clock, and anything
// else drifts out of step with it.

import Foundation

enum FleetFiring {

    /// A piece eligible to fire, as far as this decision is concerned.
    struct Candidate: Equatable {
        let square: String
        let type: PieceType

        init(square: String, type: PieceType) {
            self.square = square
            self.type = type
        }
    }

    /// How many pieces fire this beat, from the level's `shotsPerTurn` range.
    /// Level 1's range is 0...0, so it fires nothing there with no special case.
    static func shotCount(for level: LevelParameters) -> Int {
        Int.random(in: level.shotsPerTurn)
    }

    /// §5.3 weights toward "front-rank pawns" — two separate biases, and the
    /// earlier version only implemented the first:
    ///
    ///  * **front rank**: closer to White fires more often, so the threat comes
    ///    from the pieces already bearing down on you;
    ///  * **pawns**: the fleet's rank and file, and the pieces §5.3 names.
    ///    Without this a back-rank rook outweighed an advanced pawn, which is
    ///    backwards — the queen and king should not be the ones peppering you.
    static func weight(forRank rank: Int, type: PieceType) -> Int {
        // Rank 8 (home) scores 1, rank 2 scores 7. Rank 1 is a breach and ends
        // the level, so it never actually appears here.
        let rankWeight = max(1, 9 - rank)
        // A pawn is worth three of any other piece on the same rank.
        let typeWeight = type == .pawn ? 3 : 1
        return rankWeight * typeWeight
    }

    /// Picks up to `count` *distinct* pieces to fire from. Returns fewer when
    /// there aren't enough candidates — a nearly-cleared fleet simply fires less.
    static func chooseShooters(from candidates: [Candidate], count: Int) -> [String] {
        guard count > 0, !candidates.isEmpty else { return [] }

        func rank(_ square: String) -> Int { Int(String(square.last ?? "1")) ?? 1 }

        var pool: [String] = []
        for candidate in candidates {
            let w = weight(forRank: rank(candidate.square), type: candidate.type)
            pool.append(contentsOf: Array(repeating: candidate.square, count: w))
        }

        var chosen: [String] = []
        while chosen.count < count, !pool.isEmpty {
            let pick = pool.remove(at: Int.random(in: 0..<pool.count))
            chosen.append(pick)
            // Drop every remaining copy too: one piece fires at most one shot a
            // beat, and this guarantees the loop shrinks the pool each pass.
            pool.removeAll { $0 == pick }
        }
        return chosen
    }

    // MARK: - Level 1 warning shot (§10.1)

    /// Level 1 schedules no fire at all, so the very first shot a player ever
    /// sees is this one: when the black king reaches Critical damage, it fires a
    /// single slow round. A preview, not a punishment — "Level 2 shoots back".
    ///
    /// Half of Level 2's projectile speed (§10.1), so it is easy to read, dodge
    /// or shoot down. The slowness *is* the telegraph.
    static let warningShotSpeed: CGFloat = 90

    /// True when the one-off Level 1 warning shot should fire now.
    /// `alreadyFired` makes it once per level; if the king dies before reaching
    /// Critical it simply never happens, which §10.1 explicitly allows.
    static func shouldFireWarningShot(level: Int,
                                      blackKing: Piece?,
                                      alreadyFired: Bool) -> Bool {
        guard level == 1, !alreadyFired, let king = blackKing else { return false }
        return king.damageState == .critical
    }
}
