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

    /// §5.3's "front rank" bias: the closer a gunner is to White, the more
    /// often it fires, so the threat comes from the pieces already bearing down
    /// on you. Which *types* are armed is `gunners(from:)`'s decision now, but
    /// the pawn weight stays here — it still separates an advanced pawn from a
    /// back-rank straggler in the fallback case, once the pawns are gone.
    static func weight(forRank rank: Int, type: PieceType) -> Int {
        // Rank 8 (home) scores 1, rank 2 scores 7. Rank 1 is a breach and ends
        // the level, so it never actually appears here.
        let rankWeight = max(1, 9 - rank)
        // A pawn is worth three of any other piece on the same rank.
        let typeWeight = type == .pawn ? 3 : 1
        return rankWeight * typeWeight
    }

    /// Pawns are the fleet's gunners, from Level 2 on ("PAWNS FIRE BACK").
    ///
    /// This replaces a weighting. §5.3 only ever asked for a *bias* toward
    /// pawns, and the bias was real — 84% of shots at level start — but a
    /// probability is invisible: to a player, 84% still reads as "anything can
    /// shoot". A hard rule reads as a rule, and it is the only thing a level
    /// banner can honestly promise. It also gives shooting a pawn a visible
    /// consequence: it removes a gun.
    ///
    /// Fallback: with the pawns gone the fleet would fall silent for the rest
    /// of the wave — exactly when the player is hunting the king and the
    /// pressure should be at its highest — so everything left takes over, still
    /// weighted forward. The banner promises pawns shoot, not that nothing else
    /// ever will.
    static func gunners(from candidates: [Candidate]) -> [Candidate] {
        let pawns = candidates.filter { $0.type == .pawn }
        return pawns.isEmpty ? candidates : pawns
    }

    /// At most half the gunners fire in one beat.
    ///
    /// Without this the charge-up telegraph eats itself: three shots from three
    /// surviving pawns lights every pawn on the board, and a warning that
    /// covers everything is not a warning. Capping keeps "these are about to
    /// fire" distinguishable from "the rank exists" all the way down — and a
    /// thinning fleet still gets harder, because each survivor fires more often.
    static func volleySize(_ requested: Int, gunners: Int) -> Int {
        guard gunners > 0, requested > 0 else { return 0 }
        return max(1, min(requested, gunners / 2))
    }

    /// Crossfire's shooters: every live black bishop, on `bishopShotInterval`.
    /// The piece that moves diagonally is the one that shoots diagonally, which
    /// is a rule a player already knows before the banner explains it.
    static func diagonalShooters(from candidates: [Candidate]) -> [String] {
        candidates.filter { $0.type == .bishop }.map(\.square)
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
