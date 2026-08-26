// Regeneration.swift
// §23.9's piece regeneration and §10.1's armored pawns, as pure rules and a
// pure timer. The rendering layer asks this what should materialise and where;
// it owns none of the decisions.
//
// The two features are one system: armored pawns arrive *only* through
// regeneration (§10.1), so Level 9's banner is a promise that Level 4's
// regeneration has to be built to keep.

import Foundation

enum Regeneration {

    /// How long after a kill the replacement arrives.
    ///
    /// §23.9 says a flat ten seconds. That was written before the beat settled
    /// at four, and ten seconds is two and a half beats — long enough that the
    /// kill which caused it has left the player's head, so the pawn reads as
    /// arriving from nowhere rather than as a consequence.
    ///
    /// Paced off the beat instead, like the descent and the firing: one and a
    /// half turns, so it lands on the turn after next. That is six seconds at
    /// most levels and four and a half at Blitz, and it stays in proportion
    /// when the clock changes rather than becoming a different mechanic.
    static func delay(for level: LevelParameters) -> TimeInterval {
        max(4, level.turnTimer * 1.5)
    }
    /// §23.9's transporter beam-in. The piece cannot be shot while it runs.
    static let beamInDuration: TimeInterval = 1.8
    /// §10.1: half of the pawns regenerated from Level 9 arrive armored.
    static let armoredShare = 0.5
    /// §10.1: armor lasts three chess turns, counted on White's moves.
    static let armorTurns = 3
    /// §9: a pawn that came back is worth less than one off the starting board.
    static let regeneratedPawnValue = 15

    /// Whether the piece just destroyed schedules a regeneration.
    ///
    /// The king never comes back (§23.9) — the level ends when it falls, so the
    /// question never really arises, but a slot spent on it would be a bug that
    /// only shows up in the one position that matters.
    static func schedules(destroyed type: PieceType, color: PieceColor,
                          level: LevelParameters, slotsUsed: Int) -> Bool {
        guard color == .black, type != .king else { return false }
        return slotsUsed < level.regenSlots
    }

    /// §23.9's defensive mode: once the black king is badly hurt, regeneration
    /// stops scattering pawns along the back rank and starts putting them in
    /// front of him. The player's reaction — finish the king before the wall
    /// closes — is the point of it.
    static func isDefensive(kingDamage: DamageState) -> Bool {
        kingDamage == .cracked || kingDamage == .critical
    }

    /// Where a regenerated pawn materialises.
    ///
    /// Defensive: the square directly in front of the king, toward White.
    /// Standard: a random free file on the fleet's rear rank. Returns nil when
    /// there is nowhere legal, which is a real outcome late in a wave — a full
    /// rear rank simply means nothing arrives.
    static func spawnSquare(defensive: Bool, kingSquare: String?,
                            rearRank: Int, occupied: Set<String>) -> String? {
        if defensive, let kingSquare, let shielded = squareAhead(of: kingSquare),
           !occupied.contains(shielded) {
            return shielded
        }
        let files = "abcdefgh".map { "\($0)\(rearRank)" }.filter { !occupied.contains($0) }
        return files.randomElement()
    }

    /// One rank toward White, or nil off the board.
    static func squareAhead(of square: String) -> String? {
        let chars = Array(square)
        guard chars.count == 2, let rank = chars[1].wholeNumberValue, rank > 1
        else { return nil }
        return "\(chars[0])\(rank - 1)"
    }

    /// §10.1: armor arrives with Level 9 and only on regenerated pawns.
    static func arrivesArmored(level: LevelParameters) -> Bool {
        level.armoredPawns && Double.random(in: 0..<1) < armoredShare
    }
}

/// A regeneration waiting to happen. Held by the scene, ticked per frame.
///
/// §23.9: "if the level ends while a regeneration timer is running, the timer
/// is cancelled" — which falls out of the queue living on the scene and being
/// cleared with the board, rather than needing its own rule.
@MainActor
struct RegenerationQueue {

    private struct Pending {
        var remaining: TimeInterval
    }

    private var pending: [Pending] = []
    /// Slots are consumed when a regeneration is *scheduled*, not when it
    /// lands. Counting on arrival would let a wave with a 2-slot cap queue
    /// twenty at once and pay them all out.
    private(set) var slotsUsed = 0

    var waiting: Int { pending.count }

    mutating func schedule(after delay: TimeInterval) {
        pending.append(Pending(remaining: delay))
        slotsUsed += 1
    }

    /// Advances every timer and returns how many are due this frame.
    mutating func tick(_ dt: TimeInterval) -> Int {
        guard !pending.isEmpty else { return 0 }
        for index in pending.indices { pending[index].remaining -= dt }
        let due = pending.filter { $0.remaining <= 0 }.count
        pending.removeAll { $0.remaining <= 0 }
        return due
    }

    mutating func reset() {
        pending.removeAll()
        slotsUsed = 0
    }
}
