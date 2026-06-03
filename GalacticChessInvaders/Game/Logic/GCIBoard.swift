// GCIBoard.swift
// Wraps ChessKit to add GCI-specific features:
//   - HP tracking per piece
//   - forcePlace() for fleet descent (bypasses chess legality)
//   - GKGameModel conformance for GKMinmaxStrategist
//
// This is the bridge between the chess library and GCI's arcade rules.
// Phase 0: stub. Flesh out in Phase 1 (chess engine integration).

import Foundation
// import ChessKit   ← uncomment once ChessKit SPM package is added in Xcode

final class GCIBoard {

    // MARK: - Board State
    // Phase 1: replace with ChessKit Position
    private var pieces: [String: Piece] = [:]   // key: algebraic square e.g. "e2"

    // MARK: - Setup

    func setupStandardPosition() {
        // Phase 1: initialise from ChessKit starting position
        // For now, place pieces manually for testing
        DiagnosticsLog.shared.log(.chess, "Board: standard position set")
    }

    // MARK: - Piece Access

    func piece(at square: String) -> Piece? {
        pieces[square]
    }

    func allPieces(color: PieceColor) -> [Piece] {
        pieces.values.filter { $0.color == color }
    }

    // MARK: - Chess Moves (via ChessKit)

    /// Apply a legal chess move. Updates logical square.
    func applyChessMove(from: String, to: String) {
        guard var piece = pieces[from] else { return }
        pieces[from] = nil
        piece.logicalSquare = to
        pieces[to] = piece
        DiagnosticsLog.shared.log(.chess, "\(piece.color) \(piece.type) \(from)→\(to)")
    }

    // MARK: - Force Placement (Fleet Descent)

    /// Place a piece on a square, bypassing all chess legality checks.
    /// Used by FleetController on every descent step.
    /// If a white piece occupies the target square, a crush event fires.
    func forcePlace(_ piece: Piece, at square: String) -> CrushEvent? {
        var crush: CrushEvent? = nil

        if let occupant = pieces[square], occupant.color != piece.color {
            // Crush event: black piece lands on white piece's square
            crush = CrushEvent(crushedPiece: occupant, atSquare: square)
            DiagnosticsLog.shared.log(.fleet, "CRUSH: \(occupant.color) \(occupant.type) at \(square) crushed by \(piece.type)")
        }

        var movedPiece = piece
        movedPiece.logicalSquare = square
        pieces[square] = movedPiece

        return crush
    }

    // MARK: - Damage

    /// Apply damage to piece at square. Returns true if piece is destroyed.
    @discardableResult
    func applyDamage(_ amount: Int, at square: String) -> Bool {
        guard pieces[square] != nil else { return false }
        let destroyed = pieces[square]!.applyDamage(amount)
        if destroyed {
            pieces[square] = nil
            DiagnosticsLog.shared.log(.destroy, "Piece at \(square) destroyed (HP exhausted)")
        }
        return destroyed
    }
}

// MARK: - Supporting Types

struct CrushEvent {
    let crushedPiece: Piece
    let atSquare: String
}
