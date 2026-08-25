// ChessEngine.swift
// Facade over the chess model plus the search. Everything above this file speaks
// algebraic square strings and GCI's own PieceType / PieceColor, so the board
// representation stays an implementation detail.
//
// The search is negamax over material plus a coarse positional term, depth 2 by
// default. GCI wants a fast, shallow opponent (design doc §4: arcade reflex, not
// deep strategy), so there is no quiescence, no transposition table and no
// iterative deepening.
//
// Three things keep it watchable rather than merely legal. Material-only
// evaluation scored every quiet move identically, so the engine had no reason to
// prefer any of them and would shuffle one rook between two squares forever:
//  * `positionalValue` gives quiet moves genuinely different scores;
//  * a repetition penalty makes stepping back where it came from unattractive;
//  * near-equal moves are chosen between at random, so games differ.

import Foundation

final class ChessEngine {

    struct Occupant {
        let square: String
        let type: PieceType
        let color: PieceColor
    }

    /// A move that has been validated and played.
    struct AppliedMove {
        let from: String
        let to: String
        let type: PieceType
        let color: PieceColor
        let capturedType: PieceType?
        /// Where the captured piece stood. Equals `to` for an ordinary capture,
        /// but for en passant it is the square beside it.
        let capturedSquare: String?
        let promotedTo: PieceType?
        /// The rook's journey when this move was a castle.
        let rookMove: (from: String, to: String)?
    }

    private(set) var position: Chess.Position

    /// Recently occupied boards, newest last. The search consults this to avoid
    /// stepping straight back where it came from.
    private(set) var recentBoards: [Chess.Board] = []
    /// Deep enough to catch a two-piece shuffle, shallow enough that the engine
    /// is not fighting its own history in a cramped position.
    private static let historyDepth = 8

    /// How often each position has occurred, for the threefold-repetition draw.
    /// Keyed on the whole position — side to move, castling rights and the
    /// en-passant square all form part of "the same position".
    private var positionCounts: [Chess.Position: Int] = [:]
    /// Plies since the last capture or pawn move, for the fifty-move draw.
    private(set) var halfmoveClock = 0

    /// Both standard draw rules. GCI originally omitted them, but a depth-2
    /// engine with an overwhelming material edge cannot force mate: it shuffles,
    /// and without these the game never terminates. Observed running ~200 plies.
    var isDrawnByRepetition: Bool { (positionCounts[position] ?? 0) >= 3 }
    var isDrawnByMoveLimit: Bool { halfmoveClock >= 100 }   // 50 full moves
    var isDrawn: Bool { isDrawnByRepetition || isDrawnByMoveLimit }

    init() {
        // The standard FEN is a constant we control, so the parse cannot fail.
        position = Chess.FEN.position(from: Chess.FEN.standard)
            ?? Chess.Position(board: Chess.Board(), turn: .white)
        recentBoards = [position.board]
        positionCounts[position] = 1
    }

    init?(fen: String) {
        guard let parsed = Chess.FEN.position(from: fen) else { return nil }
        position = parsed
        recentBoards = [parsed.board]
        positionCounts[position] = 1
    }

    // MARK: - Position readout

    var turn: PieceColor { position.turn }
    var isCheck: Bool { ChessRules.isCheck(in: position) }
    var isMate: Bool { ChessRules.isMate(in: position) }
    var isStalemate: Bool { ChessRules.isStalemate(in: position) }
    var fen: String { Chess.FEN.string(from: position) }

    func occupants() -> [Occupant] {
        position.board.pieces().map {
            Occupant(square: $0.square.coordinate, type: $0.piece.kind, color: $0.piece.color)
        }
    }

    func occupant(at square: String) -> Occupant? {
        guard let piece = position.board[square] else { return nil }
        return Occupant(square: square, type: piece.kind, color: piece.color)
    }

    /// Where a check is coming from, so the board can show it.
    struct CheckThreat {
        let kingSquare: String
        /// One entry per checking piece — two on a double check.
        let attackers: [(square: String, kind: PieceType)]
    }

    /// Nil when `color` is not in check, or has no king on the board.
    func checkThreat(against color: PieceColor) -> CheckThreat? {
        guard let king = position.board.kingSquare(of: color) else { return nil }
        let squares = ChessRules.attackers(of: king, by: color.opponent, in: position.board)
        guard !squares.isEmpty else { return nil }
        return CheckThreat(
            kingSquare: king.coordinate,
            attackers: squares.compactMap { square in
                position.board[square].map { (square.coordinate, $0.kind) }
            })
    }

    // MARK: - Legal moves

    /// Destination squares the piece on `square` may legally reach, for the side to move.
    func legalDestinations(from square: String) -> [String] {
        guard let origin = Chess.Square(coordinate: square) else { return [] }
        return ChessRules.legalMoves(from: origin, in: position).map { $0.to.coordinate }
    }

    // MARK: - Making moves

    /// Validates and plays a move. Returns nil if it isn't legal.
    ///
    /// A promotion destination yields four candidate moves; GCI always takes the
    /// queen, since nothing in the game distinguishes the other pieces and the
    /// player is never asked to choose.
    func make(from: String, to: String) -> AppliedMove? {
        guard let origin = Chess.Square(coordinate: from),
              let target = Chess.Square(coordinate: to),
              let mover = position.board[origin]
        else { return nil }

        let candidates = ChessRules.legalMoves(from: origin, in: position)
            .filter { $0.to == target }
        guard let move = candidates.first(where: { $0.promotion == .queen })
                      ?? candidates.first
        else { return nil }

        let capturedSquare = ChessRules.capturedSquare(of: move, in: position)
        let captured = capturedSquare.flatMap { position.board[$0] }

        // Castling relocates the rook too; the renderer needs both journeys.
        var rookMove: (from: String, to: String)?
        if ChessRules.isCastling(move, in: position.board) {
            let rank = origin.rank
            let (rookFrom, rookTo) = target.file == 6 ? (7, 5) : (0, 3)
            rookMove = (Chess.Square(file: rookFrom, rank: rank).coordinate,
                        Chess.Square(file: rookTo,   rank: rank).coordinate)
        }

        // A capture or a pawn move makes the position irreversible, which is what
        // resets the fifty-move clock and makes earlier positions unrepeatable.
        let isIrreversible = mover.kind == .pawn || captured != nil
        position = ChessRules.applying(move, to: position)

        if isIrreversible {
            halfmoveClock = 0
            positionCounts.removeAll(keepingCapacity: true)
        } else {
            halfmoveClock += 1
        }
        positionCounts[position, default: 0] += 1

        recentBoards.append(position.board)
        if recentBoards.count > Self.historyDepth { recentBoards.removeFirst() }

        return AppliedMove(
            from: from,
            to: to,
            type: mover.kind,
            color: mover.color,
            capturedType: captured?.kind,
            capturedSquare: capturedSquare?.coordinate,
            promotedTo: move.promotion,
            rookMove: rookMove
        )
    }

    /// Hands the move back to `color`, bypassing normal alternation.
    ///
    /// GCI lets Black play several chess moves in one turn from Level 3 (§21.1),
    /// which ordinary chess cannot express. Any en-passant right is dropped: it
    /// belongs to the move that just happened, not to a fresh one by the same side.
    func forceTurn(_ color: PieceColor) {
        position.turn = color
        position.enPassant = nil
        // Consecutive moves by one side are not a chess position sequence, so
        // they must not feed the repetition table.
        positionCounts.removeAll(keepingCapacity: true)
        positionCounts[position] = 1
    }

    // MARK: - Search

    /// Narrows what the search may consider.
    struct SearchConstraints: Sendable {
        /// Limit to moves from this square. Used when the beat expires with a
        /// piece selected (§4.3), so the auto-move plays the piece the player
        /// was aiming with rather than something unrelated.
        var restrictedTo: String?
        /// Squares already moved from this turn — §25.5 forbids a piece moving
        /// twice within one Black multi-move phase.
        var excludedSources: Set<String>
        /// Destinations already claimed this turn (§25.5, no shared destinations).
        var excludedDestinations: Set<String>
        /// Forbid capturing the enemy king.
        ///
        /// Only needed for Black's extra moves: forcing the turn back can leave
        /// the opposing king attacked and still on the board, and the king is
        /// worth 20,000 to the evaluation, so the search would take it every time.
        /// Chess never allows that — check has to be answered first.
        var avoidsKingCapture: Bool

        init(restrictedTo: String? = nil,
             excludedSources: Set<String> = [],
             excludedDestinations: Set<String> = [],
             avoidsKingCapture: Bool = false) {
            self.restrictedTo = restrictedTo
            self.excludedSources = excludedSources
            self.excludedDestinations = excludedDestinations
            self.avoidsKingCapture = avoidsKingCapture
        }

        static let none = SearchConstraints()
    }

    /// Best move for the side to move in `position`.
    ///
    /// `Chess.Position` is a Sendable value type, so this is safe to call from a
    /// detached task — the engine must never run on the main thread.
    ///
    /// No explicit check constraint is needed: `legalMoves` already excludes
    /// anything leaving the king attacked, so when White is in check every
    /// candidate necessarily resolves it (§25.4).
    nonisolated static func searchBestMove(in position: Chess.Position,
                                           depth: Int,
                                           constraints: SearchConstraints = .none,
                                           avoiding history: [Chess.Board] = []) -> (from: String, to: String)? {
        var moves = ChessRules.legalMoves(in: position)

        if let origin = constraints.restrictedTo {
            let restricted = moves.filter { $0.from.coordinate == origin }
            // Fall back to the full list if the selected piece is stuck, so a
            // stalled player still gets a move rather than nothing at all.
            if !restricted.isEmpty { moves = restricted }
        }
        if !constraints.excludedSources.isEmpty || !constraints.excludedDestinations.isEmpty {
            // Never narrow to nothing: if the exclusions rule out every move,
            // Black simply makes fewer moves (§25.5) — the caller sees nil.
            moves = moves.filter {
                !constraints.excludedSources.contains($0.from.coordinate)
                    && !constraints.excludedDestinations.contains($0.to.coordinate)
            }
        }
        if constraints.avoidsKingCapture {
            moves = moves.filter { position.board[$0.to]?.kind != .king }
        }
        guard !moves.isEmpty else { return nil }

        var scored: [(move: Chess.Move, score: Int)] = []
        scored.reserveCapacity(moves.count)

        for move in moves {
            let child = ChessRules.applying(move, to: position)
            var score = -negamax(child, depth: depth - 1)
            // Returning to a position we just came from is how the engine ends up
            // shuffling a rook forever. Penalise it at the root, where the choice
            // is actually made, and steeply enough to outweigh positional noise
            // but not a real material gain.
            if history.contains(child.board) { score -= repetitionPenalty }
            scored.append((move, score))
        }

        let bestScore = scored.map(\.score).max() ?? 0
        // Pick at random among moves that are near-equally good. With a single
        // deterministic winner the engine replays the same game every time; this
        // is what makes successive auto-moves and Black replies vary.
        let contenders = scored.filter { $0.score >= bestScore - tieBreakEpsilon }
        let choice = contenders.randomElement() ?? scored[0]
        return (choice.move.from.coordinate, choice.move.to.coordinate)
    }

    private static let infinity = 1_000_000
    private static let mateScore = 100_000
    /// Centipawns deducted for stepping back into a recently occupied position.
    /// Above the positional spread, well below a pawn.
    private static let repetitionPenalty = 45
    /// Moves within this many centipawns of the best are treated as equally good
    /// and chosen between at random. A quarter of a pawn: wide enough that
    /// successive games open differently, far too narrow to give away material,
    /// which matches §25.2's "reasonable, not inspired".
    private static let tieBreakEpsilon = 25

    private nonisolated static func negamax(_ position: Chess.Position, depth: Int) -> Int {
        guard depth > 0 else { return evaluate(position) }

        let moves = ChessRules.legalMoves(in: position)
        guard !moves.isEmpty else {
            // Mated: worst possible. Stalemate: neutral.
            return ChessRules.isCheck(in: position) ? -mateScore : 0
        }

        var best = -infinity
        for move in moves {
            best = max(best, -negamax(ChessRules.applying(move, to: position), depth: depth - 1))
        }
        return best
    }

    /// Material plus a positional term, from the perspective of the side to move.
    private nonisolated static func evaluate(_ position: Chess.Position) -> Int {
        var score = 0
        for (square, piece) in position.board.pieces() {
            let value = materialValue(piece.kind) + positionalValue(piece, at: square)
            score += piece.color == position.turn ? value : -value
        }
        return score
    }

    /// Positional preference in centipawns.
    ///
    /// Without this, material-only evaluation scored every quiet move identically,
    /// so the engine had no reason to prefer any of them and shuffled a rook back
    /// and forth indefinitely. These terms are deliberately coarse — §25.2 asks
    /// for a "reasonable" move, not an inspired one — but they give quiet moves
    /// genuinely different values, which is what breaks the shuffle.
    private nonisolated static func positionalValue(_ piece: Chess.Piece,
                                                    at square: Chess.Square) -> Int {
        // How far the piece has advanced from its own back rank, 0…7.
        let advance = piece.color == .white ? square.rank : 7 - square.rank
        // 0 at a corner, up to 6 in the centre.
        let centrality = min(square.file, 7 - square.file) + min(square.rank, 7 - square.rank)
        let fileCentrality = min(square.file, 7 - square.file)

        switch piece.kind {
        case .pawn:
            // Push pawns; prefer central ones.
            return advance * 8 + fileCentrality * 3
        case .knight:
            // Knights want the centre and do nothing on the back rank.
            return centrality * 8 + (advance == 0 ? -25 : 0)
        case .bishop:
            return centrality * 5 + (advance == 0 ? -20 : 0)
        case .rook:
            // A small advance gradient is what stops a1-a2-a1 looking free.
            return advance * 3 + fileCentrality * 2
        case .queen:
            return centrality * 3 + (advance == 0 ? -10 : 0)
        case .king:
            // Keep the king home — GCI has no endgame where it should march up.
            return advance * -12 - centrality * 4
        }
    }

    /// Standard centipawn values. Not GCI's arcade point values — those score the
    /// player, these guide the engine, and conflating them makes it play oddly.
    private nonisolated static func materialValue(_ kind: PieceType) -> Int {
        switch kind {
        case .pawn:   return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook:   return 500
        case .queen:  return 900
        case .king:   return 20_000
        }
    }
}
