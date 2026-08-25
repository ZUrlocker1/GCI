// Chess.swift
// Board representation for GCI: squares, pieces, moves, and a bitboard board.
//
// Adapted from ChessKit by Alexander Perechnev (MIT licence). The bitboard
// representation with incrementally maintained per-kind/per-colour masks, and
// the square indexing scheme, follow its design.
//
// The rules are standard chess, which is what makes the published perft suite
// usable as ground truth. Only SAN notation is omitted — GCI logs moves as
// "rook a2-b2" and never needs algebraic notation.
//
// Pure Swift, no SpriteKit. Everything here is a Sendable value type so a
// position can be handed to a detached task for engine search.

import Foundation

/// Namespace for the chess model, keeping `Square` / `Board` / `Piece` clear of
/// GCI's arcade-layer `Piece` (which carries HP and a sprite name).
enum Chess {

    typealias Bitboard = UInt64

    static let files: [Character] = ["a", "b", "c", "d", "e", "f", "g", "h"]
    static let ranks: [Character] = ["1", "2", "3", "4", "5", "6", "7", "8"]

    /// A piece as the chess rules see it — kind and colour, no HP.
    struct Piece: Hashable, Sendable {
        let kind: PieceType
        let color: PieceColor

        init(kind: PieceType, color: PieceColor) {
            self.kind = kind
            self.color = color
        }

        /// FEN character: uppercase for White, lowercase for Black.
        var fenCharacter: Character {
            let c = kind.fenCharacter
            return color == .white ? Character(c.uppercased()) : c
        }

        init?(fenCharacter: Character) {
            guard let kind = PieceType(fenCharacter: fenCharacter) else { return nil }
            self.init(kind: kind, color: fenCharacter.isUppercase ? .white : .black)
        }
    }

    /// A board square. Index is file-major (`file * 8 + rank`) to match the
    /// bitboard layout, so a file occupies one contiguous byte.
    struct Square: Hashable, Sendable {
        let file: Int   // 0…7 → a…h
        let rank: Int   // 0…7 → ranks 1…8

        init(file: Int, rank: Int) {
            self.file = file
            self.rank = rank
        }

        init(index: Int) {
            self.init(file: index / 8, rank: index % 8)
        }

        init?(coordinate: String) {
            let chars = Array(coordinate)
            guard chars.count == 2,
                  let file = Chess.files.firstIndex(of: chars[0]),
                  let rank = Chess.ranks.firstIndex(of: chars[1]) else { return nil }
            self.init(file: file, rank: rank)
        }

        /// The single set bit of `mask`, or nil if `mask` is empty.
        init?(mask: Bitboard) {
            guard mask != 0 else { return nil }
            let index = mask.trailingZeroBitCount
            guard index < 64 else { return nil }
            self.init(index: index)
        }

        var isValid: Bool { (0...7).contains(file) && (0...7).contains(rank) }
        var index: Int { file * 8 + rank }

        /// Zero for an off-board square, so callers can mask without bounds checks.
        var mask: Bitboard { isValid ? Bitboard(1) << Bitboard(index) : 0 }

        var coordinate: String {
            guard isValid else { return "??" }
            return "\(Chess.files[file])\(Chess.ranks[rank])"
        }

        func translate(file df: Int, rank dr: Int) -> Square {
            Square(file: file + df, rank: rank + dr)
        }
    }

    /// A move. `promotion` is non-nil only when a pawn reaches the far rank.
    struct Move: Hashable, Sendable {
        let from: Square
        let to: Square
        let promotion: PieceType?

        init(from: Square, to: Square, promotion: PieceType? = nil) {
            self.from = from
            self.to = to
            self.promotion = promotion
        }

        var coordinateNotation: String {
            "\(from.coordinate)\(to.coordinate)" + (promotion.map { String($0.fenCharacter) } ?? "")
        }
    }

    /// Occupancy masks, one per colour and one per kind. A square's piece is the
    /// intersection of the colour mask it appears in and the kind mask it appears in.
    struct Bitboards: Hashable, Sendable {
        var white: Bitboard = 0
        var black: Bitboard = 0
        var king: Bitboard = 0
        var queen: Bitboard = 0
        var rook: Bitboard = 0
        var bishop: Bitboard = 0
        var knight: Bitboard = 0
        var pawn: Bitboard = 0

        var occupied: Bitboard { white | black }

        func mask(for color: PieceColor) -> Bitboard {
            color == .white ? white : black
        }

        func mask(for kind: PieceType) -> Bitboard {
            switch kind {
            case .king:   return king
            case .queen:  return queen
            case .rook:   return rook
            case .bishop: return bishop
            case .knight: return knight
            case .pawn:   return pawn
            }
        }
    }

    /// An 8×8 board. Writing through a subscript keeps every mask in sync, so
    /// reads are pure bit tests and never scan.
    struct Board: Hashable, Sendable {
        private(set) var bitboards = Bitboards()

        init() {}

        subscript(index: Int) -> Piece? {
            get {
                let m = Bitboard(1) << Bitboard(index)
                let color: PieceColor
                if bitboards.white & m != 0 {
                    color = .white
                } else if bitboards.black & m != 0 {
                    color = .black
                } else {
                    return nil
                }
                for kind in PieceType.allCases where bitboards.mask(for: kind) & m != 0 {
                    return Piece(kind: kind, color: color)
                }
                return nil
            }
            set {
                let m = Bitboard(1) << Bitboard(index)
                let clear = ~m
                bitboards.white  &= clear
                bitboards.black  &= clear
                bitboards.king   &= clear
                bitboards.queen  &= clear
                bitboards.rook   &= clear
                bitboards.bishop &= clear
                bitboards.knight &= clear
                bitboards.pawn   &= clear

                guard let piece = newValue else { return }

                switch piece.color {
                case .white: bitboards.white |= m
                case .black: bitboards.black |= m
                }
                switch piece.kind {
                case .king:   bitboards.king   |= m
                case .queen:  bitboards.queen  |= m
                case .rook:   bitboards.rook   |= m
                case .bishop: bitboards.bishop |= m
                case .knight: bitboards.knight |= m
                case .pawn:   bitboards.pawn   |= m
                }
            }
        }

        subscript(square: Square) -> Piece? {
            get { square.isValid ? self[square.index] : nil }
            set { if square.isValid { self[square.index] = newValue } }
        }

        subscript(coordinate: String) -> Piece? {
            get { Square(coordinate: coordinate).flatMap { self[$0] } }
            set { if let square = Square(coordinate: coordinate) { self[square] = newValue } }
        }

        /// Square of `color`'s king, or nil if it has been destroyed —
        /// which GCI allows, since a king can be shot off the board.
        func kingSquare(of color: PieceColor) -> Square? {
            Square(mask: bitboards.king & bitboards.mask(for: color))
        }

        /// Walks the occupied mask rather than all 64 squares, and reads each
        /// square once instead of twice — this runs at every search leaf.
        func pieces() -> [(square: Square, piece: Piece)] {
            var result: [(Square, Piece)] = []
            result.reserveCapacity(32)
            var remaining = bitboards.occupied
            while remaining != 0 {
                let index = remaining.trailingZeroBitCount
                remaining &= remaining &- 1        // clear the lowest set bit
                if let piece = self[index] {
                    result.append((Square(index: index), piece))
                }
            }
            return result
        }
    }

    /// Which castles remain available. Cleared as kings and rooks move or are captured.
    struct CastlingRights: OptionSet, Hashable, Sendable {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }

        static let whiteKingside  = CastlingRights(rawValue: 1 << 0)
        static let whiteQueenside = CastlingRights(rawValue: 1 << 1)
        static let blackKingside  = CastlingRights(rawValue: 1 << 2)
        static let blackQueenside = CastlingRights(rawValue: 1 << 3)

        static let all: CastlingRights = [.whiteKingside, .whiteQueenside,
                                          .blackKingside, .blackQueenside]

        static func kingside(_ color: PieceColor) -> CastlingRights {
            color == .white ? .whiteKingside : .blackKingside
        }
        static func queenside(_ color: PieceColor) -> CastlingRights {
            color == .white ? .whiteQueenside : .blackQueenside
        }
        static func both(_ color: PieceColor) -> CastlingRights {
            [kingside(color), queenside(color)]
        }
    }

    /// A complete position: board, side to move, castling rights and the
    /// en-passant target square. Move counters are omitted — GCI has no
    /// fifty-move rule or threefold repetition.
    struct Position: Hashable, Sendable {
        var board: Board
        var turn: PieceColor
        var castling: CastlingRights
        /// The square a pawn just skipped over, and so may be captured on.
        var enPassant: Square?

        init(board: Board,
             turn: PieceColor,
             castling: CastlingRights = [],
             enPassant: Square? = nil) {
            self.board = board
            self.turn = turn
            self.castling = castling
            self.enPassant = enPassant
        }
    }
}

// MARK: - FEN characters for GCI piece types

extension PieceType {
    var fenCharacter: Character {
        switch self {
        case .king:   return "k"
        case .queen:  return "q"
        case .rook:   return "r"
        case .bishop: return "b"
        case .knight: return "n"
        case .pawn:   return "p"
        }
    }

    init?(fenCharacter: Character) {
        switch Character(fenCharacter.lowercased()) {
        case "k": self = .king
        case "q": self = .queen
        case "r": self = .rook
        case "b": self = .bishop
        case "n": self = .knight
        case "p": self = .pawn
        default:  return nil
        }
    }
}

extension PieceColor {
    var opponent: PieceColor { self == .white ? .black : .white }
}
