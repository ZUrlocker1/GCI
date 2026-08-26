// ChessFEN.swift
// FEN parsing and writing, adapted from ChessKit's FenSerialization
// by Alexander Perechnev (MIT licence).
//
// GCI keeps FEN because it makes positions expressible as a one-line string:
// useful for unit-test fixtures, diagnostics and future save/resume. The
// half-move and full-move counters are the only fields not represented — GCI
// does track a quiet-move limit and threefold repetition, but as separate
// counters on `ChessEngine` (`halfmoveClock`, `positionCounts`), not as part
// of `Chess.Position` itself, so there is nothing here for FEN to round-trip.

import Foundation

extension Chess {

    enum FEN {

        static let standard = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

        /// Parses a FEN string. Returns nil if the board or side-to-move field is malformed.
        static func position(from fen: String) -> Position? {
            let fields = fen.split(separator: " ")
            guard fields.count >= 2 else { return nil }

            guard let board = board(from: String(fields[0])) else { return nil }
            let turn: PieceColor
            switch fields[1] {
            case "w": turn = .white
            case "b": turn = .black
            default:  return nil
            }

            var castling: CastlingRights = []
            if fields.count > 2 {
                for character in fields[2] {
                    switch character {
                    case "K": castling.insert(.whiteKingside)
                    case "Q": castling.insert(.whiteQueenside)
                    case "k": castling.insert(.blackKingside)
                    case "q": castling.insert(.blackQueenside)
                    default: break          // "-" and anything unexpected
                    }
                }
            }

            let enPassant = fields.count > 3 ? Square(coordinate: String(fields[3])) : nil

            return Position(board: board, turn: turn, castling: castling, enPassant: enPassant)
        }

        /// FEN ranks are listed from 8 down to 1, files a→h within each rank.
        private static func board(from field: String) -> Board? {
            let rows = field.split(separator: "/")
            guard rows.count == 8 else { return nil }

            var board = Board()
            for (rowIndex, row) in rows.enumerated() {
                let rank = 7 - rowIndex
                var file = 0
                for character in row {
                    if let empty = character.wholeNumberValue, (1...8).contains(empty) {
                        file += empty
                    } else if let piece = Piece(fenCharacter: character) {
                        guard file < 8 else { return nil }
                        board[Square(file: file, rank: rank)] = piece
                        file += 1
                    } else {
                        return nil
                    }
                }
                guard file == 8 else { return nil }
            }
            return board
        }

        /// Writes a FEN string. The move counters are fixed placeholders, since
        /// GCI tracks neither.
        static func string(from position: Position) -> String {
            var rows: [String] = []
            for rank in stride(from: 7, through: 0, by: -1) {
                var row = ""
                var gap = 0
                for file in 0..<8 {
                    if let piece = position.board[Square(file: file, rank: rank)] {
                        if gap > 0 { row += "\(gap)"; gap = 0 }
                        row.append(piece.fenCharacter)
                    } else {
                        gap += 1
                    }
                }
                if gap > 0 { row += "\(gap)" }
                rows.append(row)
            }
            let turn = position.turn == .white ? "w" : "b"

            var castling = ""
            if position.castling.contains(.whiteKingside)  { castling += "K" }
            if position.castling.contains(.whiteQueenside) { castling += "Q" }
            if position.castling.contains(.blackKingside)  { castling += "k" }
            if position.castling.contains(.blackQueenside) { castling += "q" }
            if castling.isEmpty { castling = "-" }

            let enPassant = position.enPassant?.coordinate ?? "-"

            return "\(rows.joined(separator: "/")) \(turn) \(castling) \(enPassant) 0 1"
        }
    }
}
