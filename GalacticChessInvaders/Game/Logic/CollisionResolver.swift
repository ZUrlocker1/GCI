// CollisionResolver.swift
// Pure damage/scoring/destruction outcomes for a laser hit (§7.2, §9). Takes
// the board and a square, mutates HP through `GCIBoard`, and reports what
// happened. SpriteKit-free — `CollisionHandler` (Rendering) is the only
// caller, once it has identified which two physics bodies touched.

import Foundation

enum CollisionOutcome {
    /// A black piece was hit by the player's laser.
    case blackPieceHit(square: String, type: PieceType, destroyed: Bool,
                       points: Int, doubleCheckmateBonus: Bool)
    /// A white piece was hit — friendly fire from the player, or an invader
    /// shot it blocked. Never scores either way.
    case whitePieceHit(square: String, destroyed: Bool)
    /// The laser struck an armored pawn and did nothing (§10.1). Not a miss —
    /// the player hit exactly what they aimed at, and needs to be told that
    /// the answer is "not with that".
    case ricochet(square: String)
}

@MainActor
enum CollisionResolver {

    /// Player laser hits a black piece: 2 HP, scores on the kill (§9).
    ///
    /// `doubleCheckmateBonus` covers §9's 800-point line: the beat that
    /// delivers checkmate doesn't formally end play until it resolves, so
    /// there's a real window where the king is already checkmated but still
    /// standing — killing it there is both a kill and a checkmate.
    static func playerLaserHitBlackPiece(at square: String, board: GCIBoard) -> CollisionOutcome? {
        guard let piece = board.piece(at: square), piece.color == .black else { return nil }
        // §10.1: armor is absolute while it lasts. Only a chess capture
        // removes the pawn, which is the whole point — the level asks the
        // player to solve something with the board instead of the trigger.
        guard !piece.isArmored else { return .ricochet(square: square) }
        let wasAlreadyCheckmated = piece.type == .king && board.turn == .black && board.isMate
        let destroyed = board.applyDamage(ProjectileState.playerLaserDamage, at: square)
        return .blackPieceHit(square: square, type: piece.type, destroyed: destroyed,
                              points: destroyed ? piece.shootValue : 0,
                              doubleCheckmateBonus: destroyed && wasAlreadyCheckmated)
    }

    /// Player laser hits a white piece — friendly fire, 2 HP, never scores
    /// (§7.2: "useful to clear a blocked firing lane intentionally").
    static func playerLaserHitWhitePiece(at square: String, board: GCIBoard) -> CollisionOutcome? {
        guard let piece = board.piece(at: square), piece.color == .white else { return nil }
        let destroyed = board.applyDamage(ProjectileState.playerLaserDamage, at: square)
        return .whitePieceHit(square: square, destroyed: destroyed)
    }

    /// An invader shot is blocked by a white piece: 1 HP (§5.3, §7.2).
    static func enemyShotHitWhitePiece(at square: String,
                                       damage: Int = ProjectileState.enemyShotDamage,
                                       board: GCIBoard) -> CollisionOutcome? {
        guard let piece = board.piece(at: square), piece.color == .white else { return nil }
        let destroyed = board.applyDamage(damage, at: square)
        return .whitePieceHit(square: square, destroyed: destroyed)
    }
}
