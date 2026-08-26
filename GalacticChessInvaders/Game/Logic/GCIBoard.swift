// GCIBoard.swift
// Authoritative game state: the chess position (via ChessEngine) plus the
// arcade layer chess does not model — per-piece HP and force-placement.
//
// Pure Swift; no SpriteKit. The rendering layer reads from here, never writes.

import Foundation

@MainActor
final class GCIBoard {

    private var engine = ChessEngine()

    /// Arcade state keyed by algebraic square. Mirrors the engine position,
    /// but carries HP, which the chess engine knows nothing about.
    private var pieces: [String: Piece] = [:]

    /// Exposed for the engine search and for tests.
    var currentPosition: Chess.Position { engine.position }
    var currentHistory: [Chess.Board] { engine.recentBoards }

    /// All three refer to the side whose turn it is.
    var turn: PieceColor { engine.turn }
    var isCheck: Bool { engine.isCheck }
    var isMate: Bool { engine.isMate }
    var isStalemate: Bool { engine.isStalemate }
    var isDrawnByRepetition: Bool { engine.isDrawnByRepetition }
    var isDrawnByMoveLimit: Bool { engine.isDrawnByMoveLimit }
    var isDrawn: Bool { engine.isDrawn }

    // MARK: - Setup

    func setupStandardPosition() {
        engine = ChessEngine()
        pieces = [:]
        for occupant in engine.occupants() {
            pieces[occupant.square] = Piece(type: occupant.type,
                                            color: occupant.color,
                                            square: occupant.square)
        }
        DiagnosticsLog.shared.log(.chess, "Board: standard position set (\(pieces.count) pieces)")
    }

    /// Where a check against `color` originates, for the board to visualise.
    func checkThreat(against color: PieceColor) -> ChessEngine.CheckThreat? {
        engine.checkThreat(against: color)
    }

    // MARK: - Piece access

    func piece(at square: String) -> Piece? { pieces[square] }

    func allPieces() -> [Piece] { Array(pieces.values) }

    func allPieces(color: PieceColor) -> [Piece] {
        pieces.values.filter { $0.color == color }
    }

    // MARK: - Chess moves

    func legalDestinations(from square: String) -> [String] {
        engine.legalDestinations(from: square)
    }

    /// Plays a move for the side to move. Returns the captured piece, if any.
    /// Returns nil overall if the move was rejected as illegal.
    /// `annotation` is appended to the log line — used to mark auto-moves.
    @discardableResult
    func applyChessMove(from: String, to: String, annotation: String? = nil) -> MoveOutcome? {
        guard let applied = engine.make(from: from, to: to) else {
            DiagnosticsLog.shared.log(.input, "illegal move \(from)-\(to) rejected")
            return nil
        }
        guard var moving = pieces[from] else { return nil }

        // For en passant the captured pawn is not on the destination square.
        let captured = applied.capturedSquare.flatMap { pieces[$0] }
        if let capturedSquare = applied.capturedSquare { pieces[capturedSquare] = nil }
        pieces[from] = nil

        if let promoted = applied.promotedTo {
            // Promotion replaces the piece outright, so it arrives at full HP.
            moving = Piece(type: promoted, color: moving.color, square: to)
        } else {
            moving.logicalSquare = to
        }
        pieces[to] = moving

        // Castling moves the rook as well, keeping its accumulated HP.
        if let rookMove = applied.rookMove, var rook = pieces[rookMove.from] {
            pieces[rookMove.from] = nil
            rook.logicalSquare = rookMove.to
            pieces[rookMove.to] = rook
        }

        // "rook a2-b2", tagged WHITE or BLACK so the side is obvious at a glance.
        var line = "\(applied.type.rawValue) \(from)-\(to)"
        if let captured, applied.capturedSquare != to {
            line += " takes \(captured.type.rawValue) en passant"
        } else if let captured {
            line += " takes \(captured.type.rawValue)"
        } else if applied.rookMove != nil {
            line += " castles"
        }
        if let annotation { line += "  (\(annotation))" }
        DiagnosticsLog.shared.log(applied.color.logCategory, line)

        if let promoted = applied.promotedTo {
            DiagnosticsLog.shared.log(.promote, "pawn promoted to \(promoted.rawValue) at \(to)")
        }

        return MoveOutcome(from: from, to: to,
                           moved: moving,
                           captured: captured,
                           capturedSquare: applied.capturedSquare,
                           rookMove: applied.rookMove,
                           promotedTo: applied.promotedTo)
    }

    /// Searches for a move off the main thread, then applies it here.
    func makeEngineMove(depth: Int = 2,
                        constraints: ChessEngine.SearchConstraints = .none,
                        annotation: String? = nil) async -> MoveOutcome? {
        let position = engine.position
        let history = engine.recentBoards
        let found = await Task.detached(priority: .userInitiated) {
            ChessEngine.searchBestMove(in: position, depth: depth,
                                       constraints: constraints, avoiding: history)
        }.value

        guard let found else {
            // Normal at mate or stalemate; the caller decides what it means.
            return nil
        }
        return applyChessMove(from: found.from, to: found.to, annotation: annotation)
    }

    /// Hands the move back to `color` so Black can play several moves in one turn.
    func forceTurn(_ color: PieceColor) {
        engine.forceTurn(color)
    }

    // MARK: - Force placement (fleet descent)

    /// Place a piece on a square, bypassing all chess legality checks.
    /// Used by FleetController on every descent step.
    func forcePlace(_ piece: Piece, at square: String) -> CrushEvent? {
        var crush: CrushEvent? = nil

        // Any occupant, not just an enemy one. Restricting this to opposite
        // colours meant a descending piece landing on a stalled friendly one
        // silently overwrote it: the board lost a piece, no event fired, and the
        // scene kept a node for something that no longer existed.
        if let occupant = pieces[square] {
            crush = CrushEvent(crushedPiece: occupant, atSquare: square)
            DiagnosticsLog.shared.log(.fleet, "CRUSH: \(occupant.color) \(occupant.type) at \(square) crushed by \(piece.type)")
        }

        pieces[piece.logicalSquare] = nil
        var moved = piece
        moved.logicalSquare = square
        pieces[square] = moved

        return crush
    }

    // MARK: - Damage

    /// Apply damage to the piece at `square`. Returns true if it was destroyed.
    @discardableResult
    func applyDamage(_ amount: Int, at square: String) -> Bool {
        guard var target = pieces[square] else { return false }
        let destroyed = target.applyDamage(amount)
        if destroyed {
            pieces[square] = nil
            DiagnosticsLog.shared.log(.destroy, "\(target.color) \(target.type.rawValue) at \(square) destroyed")
        } else {
            pieces[square] = target
            DiagnosticsLog.shared.log(.hit, "\(target.color) \(target.type.rawValue) \(square) hit -\(amount) → \(target.hp)HP")
        }
        return destroyed
    }
}

// MARK: - Supporting Types

struct MoveOutcome {
    let from: String
    let to: String
    let moved: Piece
    let captured: Piece?
    /// Where the captured piece stood — differs from `to` for en passant.
    let capturedSquare: String?
    /// The rook's journey when this move was a castle.
    let rookMove: (from: String, to: String)?
    /// What a pawn became, when this move was a promotion.
    let promotedTo: PieceType?
}

struct CrushEvent {
    let crushedPiece: Piece
    let atSquare: String
}
