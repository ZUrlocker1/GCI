// ChessRules.swift
// Move generation, attack detection, check and mate.
//
// Adapted from ChessKit by Alexander Perechnev (MIT licence): the translation
// tables, the long-range ray scan, the pawn move/capture/promotion split and
// the "apply to a copy, then test for check" legality filter all follow its
// StandardRules / *Moving implementations.
//
// Two deliberate departures:
//  1. Attack detection is `isAttacked(_:by:in:)` — turn-independent, and it
//     includes enemy-king adjacency. ChessKit's `isCheck` reads the side to move
//     and handles king adjacency separately in KingMoving, which is easy to
//     desync. One function serves both check detection and legality here.
//  2. Castling and en passant are implemented — see `castlingMoves`/
//     `isCastling` and the `enPassant`-target handling throughout
//     `pawnMoves`/`apply`. An earlier version of GCI excluded both; this
//     comment is what's left of that decision after it was reversed.

import Foundation

enum ChessRules {

    // MARK: - Direction tables

    private static let diagonal      = [(-1, -1), (1, 1), (-1, 1), (1, -1)]
    private static let cross         = [(-1, 0), (0, 1), (1, 0), (0, -1)]
    private static let crossDiagonal = cross + diagonal
    private static let knightJumps   = [(-2, 1), (-1, 2), (1, 2), (2, 1),
                                        (2, -1), (1, -2), (-1, -2), (-2, -1)]

    // MARK: - Attack detection

    /// Is `target` attacked by any piece of colour `attacker`?
    ///
    /// Works outward from the target square rather than enumerating every enemy
    /// piece: cheaper, and it needs no notion of whose turn it is.
    static func isAttacked(_ target: Chess.Square,
                           by attacker: PieceColor,
                           in board: Chess.Board) -> Bool {
        guard target.isValid else { return false }
        let bb = board.bitboards
        let enemy = bb.mask(for: attacker)

        // Sliding pieces: first blocker along each ray decides.
        if scan(from: target, directions: diagonal, in: board,
                hitting: (bb.bishop | bb.queen) & enemy) { return true }
        if scan(from: target, directions: cross, in: board,
                hitting: (bb.rook | bb.queen) & enemy) { return true }

        // Knights.
        for jump in knightJumps {
            let square = target.translate(file: jump.0, rank: jump.1)
            if bb.knight & enemy & square.mask != 0 { return true }
        }

        // Kings — keeps the two kings from ever becoming adjacent.
        for step in crossDiagonal {
            let square = target.translate(file: step.0, rank: step.1)
            if bb.king & enemy & square.mask != 0 { return true }
        }

        // Pawns. A white pawn advances up the board, so it attacks `target`
        // from one rank *below* it; a black pawn from one rank above.
        let pawnRank = attacker == .white ? -1 : 1
        for df in [-1, 1] {
            let square = target.translate(file: df, rank: pawnRank)
            if bb.pawn & enemy & square.mask != 0 { return true }
        }

        return false
    }

    /// Every square holding a piece of `attacker` colour that attacks `target`.
    ///
    /// Same geometry as `isAttacked`, but collecting rather than short-circuiting,
    /// so the UI can show where a check comes from. Returns more than one square
    /// on a double check.
    static func attackers(of target: Chess.Square,
                          by attacker: PieceColor,
                          in board: Chess.Board) -> [Chess.Square] {
        guard target.isValid else { return [] }
        let bb = board.bitboards
        let enemy = bb.mask(for: attacker)
        let occupied = bb.occupied
        var found: [Chess.Square] = []

        // Sliding pieces: the first blocker along each ray, if it can strike this way.
        for (directions, sliders) in [(diagonal, (bb.bishop | bb.queen) & enemy),
                                      (cross, (bb.rook | bb.queen) & enemy)] {
            guard sliders != 0 else { continue }
            for direction in directions {
                var step = 1
                while true {
                    let square = target.translate(file: direction.0 * step,
                                                  rank: direction.1 * step)
                    guard square.isValid else { break }
                    let mask = square.mask
                    if occupied & mask != 0 {
                        if sliders & mask != 0 { found.append(square) }
                        break
                    }
                    step += 1
                }
            }
        }

        for jump in knightJumps {
            let square = target.translate(file: jump.0, rank: jump.1)
            if bb.knight & enemy & square.mask != 0 { found.append(square) }
        }

        for step in crossDiagonal {
            let square = target.translate(file: step.0, rank: step.1)
            if bb.king & enemy & square.mask != 0 { found.append(square) }
        }

        // A white pawn strikes from one rank below its target, a black pawn above.
        let pawnRank = attacker == .white ? -1 : 1
        for df in [-1, 1] {
            let square = target.translate(file: df, rank: pawnRank)
            if bb.pawn & enemy & square.mask != 0 { found.append(square) }
        }

        return found
    }

    /// Walks each direction until the first occupied square. Returns true if any
    /// of those blockers is in `hitting`.
    private static func scan(from origin: Chess.Square,
                             directions: [(Int, Int)],
                             in board: Chess.Board,
                             hitting: Chess.Bitboard) -> Bool {
        guard hitting != 0 else { return false }
        let occupied = board.bitboards.occupied

        for direction in directions {
            var step = 1
            while true {
                let square = origin.translate(file: direction.0 * step, rank: direction.1 * step)
                guard square.isValid else { break }
                let mask = square.mask
                if occupied & mask != 0 {
                    if hitting & mask != 0 { return true }
                    break                       // blocked by something else
                }
                step += 1
            }
        }
        return false
    }

    // MARK: - Check / mate

    /// True if `color`'s king is under attack. False if that king is off the
    /// board — in GCI a king can be shot, and a missing king is not "in check".
    static func isCheck(_ color: PieceColor, in board: Chess.Board) -> Bool {
        guard let king = board.kingSquare(of: color) else { return false }
        return isAttacked(king, by: color.opponent, in: board)
    }

    static func isCheck(in position: Chess.Position) -> Bool {
        isCheck(position.turn, in: position.board)
    }

    static func isMate(in position: Chess.Position) -> Bool {
        isCheck(in: position) && legalMoves(in: position).isEmpty
    }

    static func isStalemate(in position: Chess.Position) -> Bool {
        !isCheck(in: position) && legalMoves(in: position).isEmpty
    }

    // MARK: - Legal moves

    /// Every legal move for the side to move.
    static func legalMoves(in position: Chess.Position) -> [Chess.Move] {
        pseudoLegalMoves(in: position).filter { isLegal($0, in: position) }
    }

    /// Legal moves originating from one square. Empty if the square is empty or
    /// holds a piece belonging to the side not to move.
    static func legalMoves(from square: Chess.Square, in position: Chess.Position) -> [Chess.Move] {
        guard let piece = position.board[square], piece.color == position.turn else { return [] }
        var candidates = moves(for: piece, from: square,
                               in: position.board, enPassant: position.enPassant)
        if piece.kind == .king {
            candidates += castlingMoves(for: position.turn, in: position)
        }
        return candidates.filter { isLegal($0, in: position) }
    }

    /// A move is legal if it does not leave the mover's own king attacked.
    /// A side whose king is already gone can never be self-checked.
    private static func isLegal(_ move: Chess.Move, in position: Chess.Position) -> Bool {
        var board = position.board
        apply(move, to: &board, turn: position.turn, enPassant: position.enPassant)
        guard let king = board.kingSquare(of: position.turn) else { return true }
        return !isAttacked(king, by: position.turn.opponent, in: board)
    }

    /// Moves ignoring self-check.
    private static func pseudoLegalMoves(in position: Chess.Position) -> [Chess.Move] {
        var result: [Chess.Move] = []
        result.reserveCapacity(48)
        for (square, piece) in position.board.pieces() where piece.color == position.turn {
            result.append(contentsOf: moves(for: piece, from: square,
                                            in: position.board, enPassant: position.enPassant))
        }
        result.append(contentsOf: castlingMoves(for: position.turn, in: position))
        return result
    }

    private static func moves(for piece: Chess.Piece,
                              from square: Chess.Square,
                              in board: Chess.Board,
                              enPassant: Chess.Square?) -> [Chess.Move] {
        switch piece.kind {
        case .king:   return shortRange(from: square, steps: crossDiagonal, piece: piece, board: board)
        case .knight: return shortRange(from: square, steps: knightJumps,   piece: piece, board: board)
        case .rook:   return longRange(from: square, directions: cross,         piece: piece, board: board)
        case .bishop: return longRange(from: square, directions: diagonal,      piece: piece, board: board)
        case .queen:  return longRange(from: square, directions: crossDiagonal, piece: piece, board: board)
        case .pawn:   return pawnMoves(from: square, piece: piece, board: board, enPassant: enPassant)
        }
    }

    // MARK: - Castling

    /// Castling moves available to `color`, encoded as the king stepping two files.
    ///
    /// Checks the three classical conditions: the right survives, the squares
    /// between king and rook are empty, and the king neither starts in check nor
    /// passes through an attacked square. Landing in check is caught by the
    /// ordinary self-check filter in `isLegal`.
    private static func castlingMoves(for color: PieceColor,
                                      in position: Chess.Position) -> [Chess.Move] {
        let rights = position.castling
        guard !rights.intersection(.both(color)).isEmpty else { return [] }

        let board = position.board
        let rank = color == .white ? 0 : 7
        let origin = Chess.Square(file: 4, rank: rank)

        // The king must actually be home, and not already in check.
        guard board[origin]?.kind == .king, board[origin]?.color == color,
              !isAttacked(origin, by: color.opponent, in: board) else { return [] }

        let occupied = board.bitboards.occupied
        var moves: [Chess.Move] = []

        // (right, rook file, files that must be empty, file the king crosses, king target)
        let options: [(Chess.CastlingRights, Int, [Int], Int, Int)] = [
            (.kingside(color),  7, [5, 6],    5, 6),
            (.queenside(color), 0, [1, 2, 3], 3, 2),
        ]

        for (right, rookFile, empties, crossFile, targetFile) in options {
            guard rights.contains(right) else { continue }

            let rookSquare = Chess.Square(file: rookFile, rank: rank)
            guard board[rookSquare]?.kind == .rook,
                  board[rookSquare]?.color == color else { continue }

            let clear = empties.allSatisfy {
                occupied & Chess.Square(file: $0, rank: rank).mask == 0
            }
            guard clear else { continue }

            let crossed = Chess.Square(file: crossFile, rank: rank)
            guard !isAttacked(crossed, by: color.opponent, in: board) else { continue }

            moves.append(Chess.Move(from: origin, to: Chess.Square(file: targetFile, rank: rank)))
        }
        return moves
    }

    /// True when `move` is a king stepping two files, i.e. a castle.
    static func isCastling(_ move: Chess.Move, in board: Chess.Board) -> Bool {
        board[move.from]?.kind == .king && abs(move.to.file - move.from.file) == 2
    }

    /// The square holding the piece `move` captures, or nil for a quiet move.
    /// For en passant this is beside the destination, not on it.
    static func capturedSquare(of move: Chess.Move, in position: Chess.Position) -> Chess.Square? {
        if position.board[move.to] != nil { return move.to }
        if let enPassant = position.enPassant,
           position.board[move.from]?.kind == .pawn,
           move.to == enPassant {
            return Chess.Square(file: enPassant.file, rank: move.from.rank)
        }
        return nil
    }

    // MARK: - Generators

    /// King and knight: one hop per direction, blocked only by own pieces.
    private static func shortRange(from square: Chess.Square,
                                   steps: [(Int, Int)],
                                   piece: Chess.Piece,
                                   board: Chess.Board) -> [Chess.Move] {
        let own = board.bitboards.mask(for: piece.color)
        return steps.compactMap { step in
            let destination = square.translate(file: step.0, rank: step.1)
            guard destination.isValid, own & destination.mask == 0 else { return nil }
            return Chess.Move(from: square, to: destination)
        }
    }

    /// Rook, bishop, queen: slide until blocked; an enemy blocker is capturable.
    private static func longRange(from square: Chess.Square,
                                  directions: [(Int, Int)],
                                  piece: Chess.Piece,
                                  board: Chess.Board) -> [Chess.Move] {
        let own   = board.bitboards.mask(for: piece.color)
        let enemy = board.bitboards.mask(for: piece.color.opponent)
        var moves: [Chess.Move] = []

        for direction in directions {
            var step = 1
            while true {
                let destination = square.translate(file: direction.0 * step, rank: direction.1 * step)
                guard destination.isValid else { break }
                let mask = destination.mask
                if own & mask != 0 { break }
                moves.append(Chess.Move(from: square, to: destination))
                if enemy & mask != 0 { break }      // capture ends the ray
                step += 1
            }
        }
        return moves
    }

    /// The pieces a pawn may become. Under-promotions are generated so the rules
    /// are standard and verifiable against reference move counts; GCI's own
    /// gameplay always takes the queen (see `ChessEngine.make`).
    private static let promotionPieces: [PieceType] = [.queen, .rook, .bishop, .knight]

    /// Pawns: single step, double step from the home rank, diagonal captures and
    /// en passant. Reaching the far rank promotes.
    private static func pawnMoves(from square: Chess.Square,
                                  piece: Chess.Piece,
                                  board: Chess.Board,
                                  enPassant: Chess.Square?) -> [Chess.Move] {
        let bb = board.bitboards
        let forward   = piece.color == .white ? 1 : -1
        let homeRank  = piece.color == .white ? 1 : 6
        let lastRank  = piece.color == .white ? 7 : 0
        let enemy     = bb.mask(for: piece.color.opponent)
        var destinations: [Chess.Square] = []

        let oneStep = square.translate(file: 0, rank: forward)
        if oneStep.isValid, bb.occupied & oneStep.mask == 0 {
            destinations.append(oneStep)

            // The double step is only available if the single step was clear.
            if square.rank == homeRank {
                let twoStep = square.translate(file: 0, rank: forward * 2)
                if twoStep.isValid, bb.occupied & twoStep.mask == 0 {
                    destinations.append(twoStep)
                }
            }
        }

        for df in [-1, 1] {
            let target = square.translate(file: df, rank: forward)
            if target.isValid, enemy & target.mask != 0 {
                destinations.append(target)
            }
        }

        // En passant: the target square is empty, so it needs its own test.
        if let enPassant, enPassant.rank == square.rank + forward,
           abs(enPassant.file - square.file) == 1 {
            destinations.append(enPassant)
        }

        return destinations.flatMap { destination -> [Chess.Move] in
            guard destination.rank == lastRank else {
                return [Chess.Move(from: square, to: destination)]
            }
            return promotionPieces.map {
                Chess.Move(from: square, to: destination, promotion: $0)
            }
        }
    }

    // MARK: - Applying moves

    /// Writes `move` onto `board`. Assumes the move is legal for `turn`.
    static func apply(_ move: Chess.Move,
                      to board: inout Chess.Board,
                      turn: PieceColor,
                      enPassant: Chess.Square?) {
        let moved = board[move.from]

        // En passant: the captured pawn is beside the destination, so clear it
        // explicitly — overwriting the destination alone would leave it standing.
        if let enPassant, moved?.kind == .pawn, move.to == enPassant, board[move.to] == nil {
            board[Chess.Square(file: enPassant.file, rank: move.from.rank)] = nil
        }

        // Castling: the rook jumps to the far side of the king.
        if moved?.kind == .king, abs(move.to.file - move.from.file) == 2 {
            let rank = move.from.rank
            let (rookFrom, rookTo) = move.to.file == 6 ? (7, 5) : (0, 3)
            board[Chess.Square(file: rookTo, rank: rank)] = board[Chess.Square(file: rookFrom, rank: rank)]
            board[Chess.Square(file: rookFrom, rank: rank)] = nil
        }

        board[move.from] = nil
        if let promotion = move.promotion {
            board[move.to] = Chess.Piece(kind: promotion, color: turn)
        } else {
            board[move.to] = moved
        }
    }

    /// Returns the position after `move`: board updated, rights and en-passant
    /// square recomputed, turn handed over.
    static func applying(_ move: Chess.Move, to position: Chess.Position) -> Chess.Position {
        var next = position
        apply(move, to: &next.board, turn: position.turn, enPassant: position.enPassant)
        next.enPassant = enPassantSquare(after: move, board: position.board)
        next.castling = castlingRights(after: move, board: position.board,
                                       from: position.castling)
        next.turn = position.turn.opponent
        return next
    }

    /// The square a double-stepping pawn skipped over. Nil after any other move.
    private static func enPassantSquare(after move: Chess.Move,
                                        board: Chess.Board) -> Chess.Square? {
        guard board[move.from]?.kind == .pawn,
              abs(move.to.rank - move.from.rank) == 2 else { return nil }
        return Chess.Square(file: move.from.file,
                            rank: (move.from.rank + move.to.rank) / 2)
    }

    /// Rights are lost when a king or rook leaves home, and when a rook is
    /// captured on its home square — hence checking `to` as well as `from`.
    private static func castlingRights(after move: Chess.Move,
                                       board: Chess.Board,
                                       from rights: Chess.CastlingRights) -> Chess.CastlingRights {
        var next = rights
        guard let moved = board[move.from] else { return next }

        if moved.kind == .king {
            next.subtract(.both(moved.color))
        }

        for square in [move.from, move.to] {
            switch (square.file, square.rank) {
            case (0, 0): next.subtract(.whiteQueenside)
            case (7, 0): next.subtract(.whiteKingside)
            case (0, 7): next.subtract(.blackQueenside)
            case (7, 7): next.subtract(.blackKingside)
            default: break
            }
        }
        return next
    }
}
