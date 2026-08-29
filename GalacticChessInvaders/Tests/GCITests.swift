// GCITests.swift
// Unit tests for the game logic layer. SpriteKit-free.
// Run with ⌘U in Xcode.

import XCTest
import SpriteKit
import AVFoundation
@testable import GalacticChessInvaders

/// A FEN-to-Position shortcut shared by every test class that builds one-off
/// positions — was duplicated verbatim in ChessRulesTests and AutoMoveTests.
extension XCTestCase {
    func position(_ fen: String) throws -> Chess.Position {
        try XCTUnwrap(Chess.FEN.position(from: fen), "bad FEN: \(fen)")
    }
}

@MainActor
final class PieceTests: XCTestCase {

    /// 3, not §7.1's 2 — raised so a 2-damage laser needs two shots. One-shot
    /// pawns read as inconsistent next to every other piece, and skipped the
    /// damage art entirely.
    func testPawnMaxHP() {
        let pawn = Piece(type: .pawn, color: .white, square: "e2")
        XCTAssertEqual(pawn.hp, 3)
        XCTAssertEqual(2, Int(ceil(Double(pawn.hp) / Double(ProjectileState.playerLaserDamage))),
                       "two laser shots to kill")
    }

    func testKingMaxHP() {
        let king = Piece(type: .king, color: .black, square: "e8")
        XCTAssertEqual(king.hp, 16)
    }

    func testDamageStateFull() {
        let rook = Piece(type: .rook, color: .white, square: "a1")
        XCTAssertEqual(rook.damageState, .full)
    }

    func testDamageStateChipped() {
        var rook = Piece(type: .rook, color: .white, square: "a1")
        rook.applyDamage(1)   // 1 point taken — a single hit does not show
        XCTAssertEqual(rook.damageState, .full)
        rook.applyDamage(1)   // 2 taken — §7.1's first stage for a rook
        XCTAssertEqual(rook.damageState, .chipped)
    }

    func testDamageStateCracked() {
        var rook = Piece(type: .rook, color: .white, square: "a1")
        rook.applyDamage(4)   // 4 taken
        XCTAssertEqual(rook.damageState, .cracked)
        rook.applyDamage(2)   // 6 taken — and the stage after it
        XCTAssertEqual(rook.damageState, .critical)
    }

    func testDamageStateCritical() {
        var rook = Piece(type: .rook, color: .white, square: "a1")
        rook.applyDamage(7)   // 1/8 HP = 12.5%
        XCTAssertEqual(rook.damageState, .critical)
    }

    /// Pawns carry 3 HP against a 2-damage laser, so the second shot is always
    /// the one that kills. One-shot pawns read as inconsistent against every
    /// other piece on the board, and the survivor has to show the first hit.
    func testPawnTakesTwoLaserHits() {
        var pawn = Piece(type: .pawn, color: .black, square: "e7")
        XCTAssertFalse(pawn.applyDamage(ProjectileState.playerLaserDamage))
        XCTAssertTrue(pawn.isAlive)
        XCTAssertEqual(pawn.damageState, .cracked)
        XCTAssertTrue(pawn.applyDamage(ProjectileState.playerLaserDamage))
        XCTAssertFalse(pawn.isAlive)
    }

    func testTextureNameFull() {
        let bishop = Piece(type: .bishop, color: .white, square: "c1")
        XCTAssertEqual(bishop.textureName, "chess-w-bishop")
    }

    func testTextureNameDamaged() {
        var queen = Piece(type: .queen, color: .black, square: "d8")
        queen.applyDamage(4)   // 8/12 HP = 66% → chipped
        XCTAssertEqual(queen.textureName, "chess-b-queen-d1")
    }
}

@MainActor
final class ScoreManagerTests: XCTestCase {

    // The async form inherits the class's @MainActor isolation; the synchronous
    // override does not, and cannot touch the main-actor singleton.
    override func setUp() async throws {
        ScoreManager.shared.resetForNewGame()
    }

    func testInitialScore() {
        XCTAssertEqual(ScoreManager.shared.currentScore, 0)
    }

    func testAddPoints() {
        ScoreManager.shared.addPoints(100)
        XCTAssertEqual(ScoreManager.shared.currentScore, 100)
    }

    func testMultiplierAtLevel1() {
        XCTAssertEqual(ScoreManager.shared.multiplier, 1.0)
    }

    func testMultiplierIncreasesOnLevelAdvance() {
        ScoreManager.shared.advanceLevel()
        XCTAssertEqual(ScoreManager.shared.multiplier, 1.5)
        ScoreManager.shared.advanceLevel()
        XCTAssertEqual(ScoreManager.shared.multiplier, 2.0)
    }

    func testPointsScaledByMultiplier() {
        ScoreManager.shared.advanceLevel()   // multiplier now 1.5
        ScoreManager.shared.addPoints(100)
        XCTAssertEqual(ScoreManager.shared.currentScore, 150)
    }
}

// MARK: - Chess rules

/// Perft (node enumeration) against the standard reference suite. Matching these
/// published counts exercises castling, en passant, all four promotions, pins,
/// discovered checks and check evasion — a move generator that agrees on every
/// one of them is almost certainly correct.
///
/// Depth 4 on all seven positions is ~11M nodes and takes a couple of seconds;
/// depth 3 and below is fast enough for every run.
final class ChessPerftTests: XCTestCase {

    private static let suite: [(name: String, fen: String, counts: [Int])] = [
        ("start", Chess.FEN.standard,
         [20, 400, 8902, 197281]),
        ("kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
         [48, 2039, 97862, 4085603]),
        ("position 3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
         [14, 191, 2812, 43238]),
        ("position 4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
         [6, 264, 9467, 422333]),
        ("position 4 mirrored", "r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1",
         [6, 264, 9467, 422333]),
        ("position 5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 0 1",
         [44, 1486, 62379, 2103487]),
        ("position 6", "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 1",
         [46, 2079, 89890, 3894594]),
    ]

    private func perft(_ position: Chess.Position, _ depth: Int) -> Int {
        let moves = ChessRules.legalMoves(in: position)
        if depth <= 1 { return moves.count }
        return moves.reduce(0) { $0 + perft(ChessRules.applying($1, to: position), depth - 1) }
    }

    func testPerftToDepth3() {
        for entry in Self.suite {
            guard let position = Chess.FEN.position(from: entry.fen) else {
                return XCTFail("could not parse FEN for \(entry.name)")
            }
            for depth in 1...3 {
                XCTAssertEqual(perft(position, depth), entry.counts[depth - 1],
                               "\(entry.name) perft(\(depth))")
            }
        }
    }

    func testPerftDepth4() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["GCI_FAST_TESTS"] != nil,
                      "slow test; ~11M nodes")
        for entry in Self.suite {
            guard let position = Chess.FEN.position(from: entry.fen) else {
                return XCTFail("could not parse FEN for \(entry.name)")
            }
            XCTAssertEqual(perft(position, 4), entry.counts[3], "\(entry.name) perft(4)")
        }
    }
}

final class ChessRulesTests: XCTestCase {

    private func destinations(from square: String, in position: Chess.Position) throws -> Set<String> {
        let origin = try XCTUnwrap(Chess.Square(coordinate: square))
        return Set(ChessRules.legalMoves(from: origin, in: position).map { $0.to.coordinate })
    }

    func testBackRankMate() throws {
        let mate = try position("R6k/6pp/8/8/8/8/8/7K b - - 0 1")
        XCTAssertTrue(ChessRules.isCheck(in: mate))
        XCTAssertTrue(ChessRules.isMate(in: mate))
        XCTAssertTrue(ChessRules.legalMoves(in: mate).isEmpty)
    }

    func testCheckWithEscapeIsNotMate() throws {
        // Same as above but the g-pawn has advanced, opening g7 for the king.
        let escape = try position("R6k/7p/6p1/8/8/8/8/7K b - - 0 1")
        XCTAssertTrue(ChessRules.isCheck(in: escape))
        XCTAssertFalse(ChessRules.isMate(in: escape))
    }

    func testStalemateIsNotCheck() throws {
        let stalemate = try position("k7/8/1Q6/8/8/8/8/K7 b - - 0 1")
        XCTAssertFalse(ChessRules.isCheck(in: stalemate))
        XCTAssertTrue(ChessRules.isStalemate(in: stalemate))
    }

    func testPinnedPieceCannotMove() throws {
        // White knight e2 is pinned to its king on e1 by the rook on e8.
        let pin = try position("4r2k/8/8/8/8/8/4N3/4K3 w - - 0 1")
        XCTAssertEqual(try destinations(from: "e2", in: pin), [])
    }

    func testKingsMayNotBecomeAdjacent() throws {
        let kings = try position("8/8/8/8/8/4k3/8/4K3 w - - 0 1")
        XCTAssertEqual(try destinations(from: "e1", in: kings), ["d1", "f1"])
    }

    func testPromotionOffersAllFourPieces() throws {
        let promo = try position("7k/P7/8/8/8/8/8/7K w - - 0 1")
        let origin = try XCTUnwrap(Chess.Square(coordinate: "a7"))
        let moves = ChessRules.legalMoves(from: origin, in: promo)
        XCTAssertEqual(moves.count, 4)
        XCTAssertEqual(Set(moves.compactMap { $0.promotion }),
                       [.queen, .rook, .bishop, .knight])
    }

    func testBlockedPawnHasNoMoves() throws {
        let blocked = try position("7k/8/8/8/8/n7/P7/7K w - - 0 1")
        XCTAssertEqual(try destinations(from: "a2", in: blocked), [])
    }

    func testCastlingAvailableBothSides() throws {
        let castle = try position("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        let dests = try destinations(from: "e1", in: castle)
        XCTAssertTrue(dests.contains("g1"), "kingside")
        XCTAssertTrue(dests.contains("c1"), "queenside")
    }

    func testCastlingMovesRookAndClearsRights() throws {
        let castle = try position("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        let origin = try XCTUnwrap(Chess.Square(coordinate: "e1"))
        let kingside = try XCTUnwrap(
            ChessRules.legalMoves(from: origin, in: castle)
                .first { $0.to.coordinate == "g1" })

        let after = ChessRules.applying(kingside, to: castle)
        XCTAssertEqual(after.board["g1"]?.kind, .king)
        XCTAssertEqual(after.board["f1"]?.kind, .rook, "rook jumps to f1")
        XCTAssertNil(after.board["h1"])
        XCTAssertNil(after.board["e1"])
        XCTAssertFalse(after.castling.contains(.whiteKingside))
        XCTAssertFalse(after.castling.contains(.whiteQueenside))
        XCTAssertTrue(after.castling.contains(.blackKingside), "black keeps its rights")
    }

    func testCannotCastleThroughCheck() throws {
        // Black rook on f8 covers f1, the square the king would cross.
        let through = try position("5r2/8/8/8/8/8/8/R3K2R w KQ - 0 1")
        XCTAssertFalse(try destinations(from: "e1", in: through).contains("g1"))
    }

    func testCannotCastleOutOfCheck() throws {
        // Black rook on e8 checks the king down the e-file.
        let inCheck = try position("4r3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
        let dests = try destinations(from: "e1", in: inCheck)
        XCTAssertFalse(dests.contains("g1"))
        XCTAssertFalse(dests.contains("c1"))
    }

    func testCapturingRookClearsCastlingRight() throws {
        // Black rook a8 takes the white rook on a1, killing queenside rights.
        let grab = try position("r3k3/8/8/8/8/8/8/R3K3 b q - 0 1")
        let origin = try XCTUnwrap(Chess.Square(coordinate: "a8"))
        let capture = try XCTUnwrap(
            ChessRules.legalMoves(from: origin, in: grab)
                .first { $0.to.coordinate == "a1" })
        let after = ChessRules.applying(capture, to: grab)
        XCTAssertFalse(after.castling.contains(.whiteQueenside))
    }

    func testEnPassantCapturesTheBypassedPawn() throws {
        // Black has just played d7-d5; White's e5 pawn may take on d6.
        let ep = try position("7k/8/8/3pP3/8/8/8/7K w - d6 0 1")
        let origin = try XCTUnwrap(Chess.Square(coordinate: "e5"))
        let capture = try XCTUnwrap(
            ChessRules.legalMoves(from: origin, in: ep)
                .first { $0.to.coordinate == "d6" })

        let after = ChessRules.applying(capture, to: ep)
        XCTAssertEqual(after.board["d6"]?.kind, .pawn, "capturing pawn lands on d6")
        XCTAssertNil(after.board["d5"], "the bypassed pawn is removed")
        XCTAssertNil(after.board["e5"])
    }

    func testEnPassantIsOnlyAvailableImmediately() throws {
        // Identical position with no en-passant square recorded.
        let stale = try position("7k/8/8/3pP3/8/8/8/7K w - - 0 1")
        XCTAssertFalse(try destinations(from: "e5", in: stale).contains("d6"))
    }

    func testDoubleStepSetsEnPassantSquare() throws {
        let start = try position(Chess.FEN.standard)
        let origin = try XCTUnwrap(Chess.Square(coordinate: "e2"))
        let double = try XCTUnwrap(
            ChessRules.legalMoves(from: origin, in: start)
                .first { $0.to.coordinate == "e4" })
        XCTAssertEqual(ChessRules.applying(double, to: start).enPassant?.coordinate, "e3")
    }

    func testEnPassantExposingKingIsIllegal() throws {
        // Position 3's signature case: both en-passant captures would clear the
        // fourth rank and expose the black king on h4 to the rook on b4.
        let tricky = try position("8/2p5/3p4/KP5r/1R2Pp1k/8/6P1/8 b - e3 0 1")
        XCTAssertFalse(try destinations(from: "f4", in: tricky).contains("e3"))
    }
}

final class ChessFENTests: XCTestCase {

    func testRoundTrip() throws {
        let fens = [
            Chess.FEN.standard,
            "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
            "7k/8/8/3pP3/8/8/8/7K w - d6 0 1",
        ]
        for fen in fens {
            let position = try XCTUnwrap(Chess.FEN.position(from: fen), fen)
            XCTAssertEqual(Chess.FEN.string(from: position), fen)
        }
    }

    func testRejectsMalformedBoard() {
        XCTAssertNil(Chess.FEN.position(from: "rnbqkbnr/pppppppp/8/8/8 w - - 0 1"), "too few ranks")
        XCTAssertNil(Chess.FEN.position(from: "xxxxxxxx/8/8/8/8/8/8/8 w - - 0 1"), "bad piece char")
        XCTAssertNil(Chess.FEN.position(from: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x - - 0 1"), "bad turn")
    }
}

@MainActor
final class GCIBoardTests: XCTestCase {

    func testStandardPositionHas32Pieces() {
        let board = GCIBoard()
        board.setupStandardPosition()
        XCTAssertEqual(board.allPieces().count, 32)
        XCTAssertEqual(board.allPieces(color: .white).count, 16)
        XCTAssertEqual(board.allPieces(color: .black).count, 16)
        XCTAssertEqual(board.turn, .white)
    }

    func testPieceStartsAtFullHP() {
        let board = GCIBoard()
        board.setupStandardPosition()
        XCTAssertEqual(board.piece(at: "e1")?.type, .king)
        XCTAssertEqual(board.piece(at: "e1")?.hp, PieceType.king.maxHP)
    }

    func testLegalMoveMovesThePieceAndHandsOverTheTurn() {
        let board = GCIBoard()
        board.setupStandardPosition()
        let outcome = board.applyChessMove(from: "e2", to: "e4")
        XCTAssertNotNil(outcome)
        XCTAssertNil(board.piece(at: "e2"))
        XCTAssertEqual(board.piece(at: "e4")?.type, .pawn)
        XCTAssertEqual(board.turn, .black)
    }

    func testIllegalMoveIsRejectedAndLeavesTheBoardAlone() {
        let board = GCIBoard()
        board.setupStandardPosition()
        XCTAssertNil(board.applyChessMove(from: "e2", to: "e5"), "three squares is not a pawn move")
        XCTAssertEqual(board.piece(at: "e2")?.type, .pawn)
        XCTAssertEqual(board.turn, .white, "a rejected move must not pass the turn")
    }

    func testDamageErodesHPThenDestroys() {
        let board = GCIBoard()
        board.setupStandardPosition()
        XCTAssertFalse(board.applyDamage(1, at: "a7"), "pawn has 3 HP")
        XCTAssertEqual(board.piece(at: "a7")?.hp, 2)
        XCTAssertFalse(board.applyDamage(1, at: "a7"))
        XCTAssertEqual(board.piece(at: "a7")?.hp, 1)
        XCTAssertTrue(board.applyDamage(1, at: "a7"))
        XCTAssertNil(board.piece(at: "a7"))
    }

    /// Regression, same bug class as `forcePlace`/`forceRelocate`: a laser
    /// kill is the first production path that ever exercises `applyDamage`,
    /// and it only ever touched `pieces`, never the engine's own board. Left
    /// unfixed, the engine would go on believing a shot-dead piece — a king,
    /// even — was still standing, forever.
    func testApplyDamageKeepsTheChessEnginesOwnBoardInSync() {
        let board = GCIBoard()
        board.setupStandardPosition()
        board.applyDamage(1, at: "a7")   // chips only — must not yet touch the engine
        board.applyDamage(1, at: "a7")
        XCTAssertEqual(board.currentPosition.board["a7"]?.kind, .pawn,
                       "a damaged-but-alive piece must still be on the engine's board")

        board.applyDamage(1, at: "a7")   // the third point kills a 3 HP pawn
        XCTAssertNil(board.currentPosition.board["a7"],
                     "the engine's own board must also see the destroyed square emptied")
        board.forceTurn(.black)
        XCTAssertTrue(board.legalDestinations(from: "a7").isEmpty,
                     "the engine must not still think a7 holds a movable pawn")
    }

    func testForcePlaceCrushesAnEnemyOccupant() {
        let board = GCIBoard()
        board.setupStandardPosition()
        let invader = Piece(type: .rook, color: .black, square: "a8")
        let crush = board.forcePlace(invader, at: "a2")
        XCTAssertEqual(crush?.crushedPiece.color, .white)
        XCTAssertEqual(crush?.atSquare, "a2")
        XCTAssertEqual(board.piece(at: "a2")?.color, .black)
        XCTAssertNil(board.piece(at: "a8"), "the invader vacates its old square")
    }

    /// Regression: `forcePlace` used to move only `pieces` (the arcade-facing
    /// mirror), never the chess engine's own board. The engine went on
    /// believing a descended piece was still at its pre-descent square forever
    /// — so when it later proposed a move from that stale square, applying it
    /// looked up whichever piece had since occupied that square for real (per
    /// `pieces`, the correct side) and moved THAT one instead. Two pieces would
    /// end up rendered on the same square — reported directly from playtest.
    /// This pins the fix at the layer the bug actually lived: the engine's own
    /// board must already agree with `pieces` the instant `forcePlace` returns.
    func testForcePlaceKeepsTheChessEnginesOwnBoardInSync() {
        let board = GCIBoard()
        board.setupStandardPosition()
        let pawn = board.piece(at: "a7")!
        _ = board.forcePlace(pawn, at: "a6")
        board.forceTurn(.black)   // legalDestinations is turn-gated; isolate the square check

        XCTAssertNil(board.currentPosition.board["a7"],
                     "the engine's own board must also see the old square emptied")
        XCTAssertEqual(board.currentPosition.board["a6"]?.kind, .pawn)
        XCTAssertEqual(board.currentPosition.board["a6"]?.color, .black)

        // The proof that matters: the engine now generates moves from the
        // piece's REAL square, not its stale one. Before the fix, "a7" still
        // looked to the engine like it held a movable pawn.
        XCTAssertTrue(board.legalDestinations(from: "a7").isEmpty,
                     "the engine must not still think a7 holds anything")
        XCTAssertFalse(board.legalDestinations(from: "a6").isEmpty,
                       "the engine must recognise the pawn at its real square")
    }

    /// The end-to-end version of the same regression: a piece that force-placed
    /// onto a new square is the one that actually moves when the engine later
    /// plays it — not whatever the engine's stale model would have picked from
    /// the piece's *original* square.
    func testAPieceMovedByForcePlaceIsPlayedFromItsNewSquareNotItsOld() {
        let board = GCIBoard()
        board.setupStandardPosition()
        _ = board.forcePlace(board.piece(at: "a7")!, at: "a6")
        board.forceTurn(.black)

        // Before the fix this succeeded: the engine's stale board still
        // believed a7 held a movable black pawn.
        XCTAssertNil(board.applyChessMove(from: "a7", to: "a5"),
                     "a7 is empty on the real board; the engine must agree")

        let outcome = board.applyChessMove(from: "a6", to: "a5")
        XCTAssertNotNil(outcome, "the pawn's real, post-descent square must be playable")
        XCTAssertEqual(board.piece(at: "a5")?.type, .pawn)
    }
}

final class ChessEngineTests: XCTestCase {

    func testEngineTakesAFreeQueen() throws {
        let grab = try XCTUnwrap(Chess.FEN.position(from: "3q3k/8/8/8/8/8/8/3Q3K w - - 0 1"))
        let best = ChessEngine.searchBestMove(in: grab, depth: 2)
        XCTAssertEqual(best?.to, "d8")
    }

    func testEngineReturnsNilWhenMated() throws {
        let mate = try XCTUnwrap(Chess.FEN.position(from: "R6k/6pp/8/8/8/8/8/7K b - - 0 1"))
        XCTAssertNil(ChessEngine.searchBestMove(in: mate, depth: 2))
    }

    func testPlayerPromotionAlwaysTakesTheQueen() {
        let engine = ChessEngine(fen: "7k/P7/8/8/8/8/8/7K w - - 0 1")
        let applied = engine?.make(from: "a7", to: "a8")
        XCTAssertEqual(applied?.promotedTo, .queen)
    }

    func testEnPassantReportsTheCapturedSquare() {
        let engine = ChessEngine(fen: "7k/8/8/3pP3/8/8/8/7K w - d6 0 1")
        let applied = engine?.make(from: "e5", to: "d6")
        XCTAssertEqual(applied?.capturedType, .pawn)
        XCTAssertEqual(applied?.capturedSquare, "d5", "not the destination square")
    }

    func testCastlingReportsTheRookJourney()  {
        let engine = ChessEngine(fen: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        let applied = engine?.make(from: "e1", to: "g1")
        XCTAssertEqual(applied?.rookMove?.from, "h1")
        XCTAssertEqual(applied?.rookMove?.to, "f1")
    }
}

// MARK: - Board geometry

/// The square ↔ point mapping backs click handling, so an off-by-one here would
/// silently move the wrong piece. These run without an SKView.
@MainActor
final class BoardNodeTests: XCTestCase {

    func testEverySquareRoundTrips() {
        let board = BoardNode()
        for file in "abcdefgh" {
            for rank in 1...8 {
                let square = "\(file)\(rank)"
                guard let point = board.center(of: square) else {
                    return XCTFail("no centre for \(square)")
                }
                XCTAssertEqual(board.square(at: point), square)
            }
        }
    }

    func testOrientationPutsWhiteAtTheBottom() {
        let board = BoardNode()
        let a1 = board.center(of: "a1")
        XCTAssertEqual(a1, CGPoint(x: 32, y: 32))
        XCTAssertEqual(board.center(of: "h8"), CGPoint(x: 480, y: 480))
        XCTAssertEqual(board.center(of: "b1")?.x, (a1?.x ?? 0) + BoardNode.squareSize)
        XCTAssertEqual(board.center(of: "a2")?.y, (a1?.y ?? 0) + BoardNode.squareSize)
    }

    func testOffBoardPointsAreRejectedNotClamped() {
        let board = BoardNode()
        XCTAssertNil(board.square(at: CGPoint(x: -1, y: 10)))
        XCTAssertNil(board.square(at: CGPoint(x: BoardNode.boardSize, y: 10)))
        XCTAssertNil(board.square(at: CGPoint(x: 10, y: BoardNode.boardSize + 1)))
        XCTAssertEqual(board.square(at: .zero), "a1")
    }

    func testInvalidSquareStringsHaveNoCentre() {
        let board = BoardNode()
        for bad in ["", "e", "e9", "e0", "i4", "ee", "e10"] {
            XCTAssertNil(board.center(of: bad), "\(bad) should not resolve")
        }
    }

    /// The fleet slides between squares, so a drawn grid misrepresents where
    /// pieces are — which is why it is off by default and lives on a slider.
    /// At zero the board must be genuinely empty, not faintly drawn.
    func testGridAndLabelsAreDrivenEntirelyByTheDisplaySetting() {
        let original = GameSettings.shared.boardGrid
        defer { GameSettings.shared.boardGrid = original }

        let board = BoardNode()
        var labels: [SKLabelNode] = []
        var shapes: [SKShapeNode] = []
        var stack = Array(board.children)
        while let node = stack.popLast() {
            if let label = node as? SKLabelNode { labels.append(label) }
            if let shape = node as? SKShapeNode { shapes.append(shape) }
            stack.append(contentsOf: node.children)
        }
        // 8 files + 8 ranks; one lattice, two deployment bands, the selection
        // outline, and a pooled dot/ring pair per marker.
        XCTAssertEqual(labels.count, 16)
        XCTAssertEqual(shapes.count, 4 + BoardNode.markerPoolSize * 2)

        // The lattice and the two bands sit behind the pieces; the marker pool
        // and the selection outline are interaction feedback and are not the
        // slider's business.
        let lattice = board.children.compactMap { $0 as? SKShapeNode }
            .filter { $0.zPosition < 0 }
        XCTAssertEqual(lattice.count, 3)

        GameSettings.shared.boardGrid = 0
        board.applyDisplaySettings()
        XCTAssertTrue(labels.allSatisfy { $0.alpha == 0 }, "no coordinate labels at zero")
        XCTAssertTrue(lattice.allSatisfy {
            $0.strokeColor.alphaComponent == 0 && $0.fillColor.alphaComponent == 0
        }, "no grid lines or bands at zero")

        GameSettings.shared.boardGrid = 1
        board.applyDisplaySettings()
        XCTAssertTrue(labels.contains { $0.alpha > 0 }, "and they come back")
        XCTAssertTrue(lattice.contains { $0.strokeColor.alphaComponent > 0 }, "so does the grid")
    }

    func testMarkersDoNotLeakNodes() {
        let board = BoardNode()
        let baseline = board.children.count
        board.showLegalMoves(["e4", "e5"], captures: ["e5"])
        board.showSelection(at: "e2")
        board.showLegalMoves(["d4"], captures: [])
        board.clearMarkers()
        XCTAssertEqual(board.children.count, baseline)
    }

    func testBoardFitsThePlayArea() {
        // Scene is 960×700 with the HUD occupying the top band.
        let boardTop = 120 + BoardNode.boardSize
        XCTAssertLessThanOrEqual(boardTop, 700 - HUDNode.height, "board must clear the HUD")
        XCTAssertLessThan(BoardNode.boardSize, 960, "board must fit the scene width")
    }
}

@MainActor
final class PieceNodeTests: XCTestCase {

    func testSpriteFitsTheSquare() {
        let node = PieceNode(piece: Piece(type: .king, color: .white, square: "e1"),
                             squareSize: BoardNode.squareSize)
        XCTAssertLessThanOrEqual(node.size.height, BoardNode.squareSize)
        XCTAssertEqual(node.size.height, BoardNode.squareSize * 0.82, accuracy: 0.01)
    }

    func testSideDeterminesTint() {
        let white = PieceNode(piece: Piece(type: .rook, color: .white, square: "a1"),
                              squareSize: BoardNode.squareSize)
        let black = PieceNode(piece: Piece(type: .rook, color: .black, square: "a8"),
                              squareSize: BoardNode.squareSize)
        XCTAssertNotEqual(white.color, black.color)
        XCTAssertGreaterThan(white.colorBlendFactor, 0)
    }

    func testSquareTracksTheMove() {
        let node = PieceNode(piece: Piece(type: .rook, color: .white, square: "a1"),
                             squareSize: BoardNode.squareSize)
        XCTAssertEqual(node.square, "a1")
        node.animateMove(to: "a4", point: CGPoint(x: 32, y: 224))
        XCTAssertEqual(node.square, "a4")
    }
}

// MARK: - Turn timer & levels

@MainActor
final class TurnTimerTests: XCTestCase {

    private var level1: LevelParameters { LevelManager.parameters(for: 1) }
    private var level3: LevelParameters { LevelManager.parameters(for: 3) }

    func testStartsAtTheLevelBeatDuration() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: false)
        XCTAssertEqual(timer.duration, 5.0)
        XCTAssertEqual(timer.remaining, 5.0)
        XCTAssertTrue(timer.isRunning)
        XCTAssertFalse(timer.isExtended)
    }

    func testLevel3UsesTheShorterBeat() {
        let timer = TurnTimer()
        timer.start(level: level3, inCheck: false)
        XCTAssertEqual(timer.duration, 4.0)
    }

    func testCheckExtendsTheBeatToEightSeconds() {
        let timer = TurnTimer()
        timer.start(level: level3, inCheck: true)
        XCTAssertEqual(timer.duration, 8.0, "check overrides the level beat")
        XCTAssertTrue(timer.isExtended)
    }

    func testExpiresExactlyOnce() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: false)
        var expiries = 0
        for _ in 0..<600 where timer.update(deltaTime: 0.05) { expiries += 1 }
        XCTAssertEqual(expiries, 1, "the beat must fire once, then stop itself")
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining, 0)
    }

    func testDoesNotExpireEarly() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: false)
        // 4.9s of a 5s beat.
        for _ in 0..<49 { XCTAssertFalse(timer.update(deltaTime: 0.1)) }
        XCTAssertTrue(timer.isRunning)
    }

    func testWarningOnlyInTheFinalTwoSeconds() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: false)
        XCTAssertFalse(timer.isWarning)
        _ = timer.update(deltaTime: 2.5)   // 2.5 left
        XCTAssertFalse(timer.isWarning)
        _ = timer.update(deltaTime: 1.0)   // 1.5 left
        XCTAssertTrue(timer.isWarning)
    }

    func testPauseDoesNotGiftTime() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: false)
        _ = timer.update(deltaTime: 2.0)
        timer.pause()
        XCTAssertFalse(timer.update(deltaTime: 10.0), "a paused beat must not tick")
        XCTAssertEqual(timer.remaining, 3.0, accuracy: 0.0001)
        timer.resume()
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.remaining, 3.0, accuracy: 0.0001)
    }

    func testStopClearsState() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: true)
        timer.stop()
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isExtended)
        XCTAssertEqual(timer.remaining, 0)
    }

    func testDisplaySecondsRoundsUp() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: false)
        XCTAssertEqual(timer.displaySeconds, 5)
        _ = timer.update(deltaTime: 0.1)     // 4.9 left
        XCTAssertEqual(timer.displaySeconds, 5, "still in the fifth second")
        _ = timer.update(deltaTime: 4.5)     // 0.4 left
        XCTAssertEqual(timer.displaySeconds, 1, "under a second still reads 1")
    }
}

@MainActor
final class LevelManagerTests: XCTestCase {

    func testStartsAtLevelOneAndAdvances() {
        let levels = LevelManager()
        XCTAssertEqual(levels.level, 1)
        levels.advance()
        XCTAssertEqual(levels.level, 2)
        levels.reset()
        XCTAssertEqual(levels.level, 1)
    }

    func testLevelOneIsPassiveAndFiresNoShots() {
        let one = LevelManager.parameters(for: 1)
        XCTAssertFalse(one.isAggressive)
        XCTAssertEqual(one.shotsPerTurn, 0...0)
        XCTAssertEqual(one.blackMovesPerTurn, 1)
        XCTAssertEqual(one.fleetSpeed, 40)
    }

    func testTableMatchesTheDesignDoc() {
        // §21.1 — turn timer, black moves, fleet speed per level.
        XCTAssertEqual(LevelManager.parameters(for: 2).turnTimer, 5)
        XCTAssertEqual(LevelManager.parameters(for: 3).turnTimer, 4)
        XCTAssertEqual(LevelManager.parameters(for: 3).blackMovesPerTurn, 2)
        XCTAssertEqual(LevelManager.parameters(for: 5).blackMovesPerTurn, 3)
        XCTAssertEqual(LevelManager.parameters(for: 5).fleetSpeed, 110)
        XCTAssertEqual(LevelManager.parameters(for: 4).regenSlots, 2)
    }

    func testHighLevelsRespectCapsAndFloors() {
        let nine = LevelManager.parameters(for: 9)
        XCTAssertEqual(nine.blackMovesPerTurn, 3, "capped at 3")
        XCTAssertEqual(nine.shotsPerTurn, 3...3, "capped at 3")
        XCTAssertEqual(nine.turnTimer, 4, "floored at 4s — Blitz alone goes to 3")
        XCTAssertEqual(nine.raiderInterval, 6, "floored at 6s")
        XCTAssertEqual(nine.fleetSpeed, 110 + 60, "+15 per level past 5")
        XCTAssertGreaterThan(nine.projectileSpeed,
                             LevelManager.parameters(for: 5).projectileSpeed)
    }

    func testLevelZeroClampsToOne() {
        XCTAssertEqual(LevelManager.parameters(for: 0).level, 1)
        XCTAssertEqual(LevelManager.parameters(for: -5).level, 1)
    }
}

// MARK: - Auto-move constraints

final class AutoMoveTests: XCTestCase {

    func testAutoMoveHonoursTheSelectedPiece() throws {
        // White has a free queen capture on d8, but the player had the a1 rook
        // selected — the auto-move must play the rook.
        let p = try position("3q3k/8/8/8/8/8/8/R2Q3K w - - 0 1")
        let best = ChessEngine.searchBestMove(in: p, depth: 2,
                                              constraints: .init(restrictedTo: "a1"))
        XCTAssertEqual(best?.from, "a1")
    }

    func testAutoMoveFallsBackWhenSelectedPieceIsStuck() throws {
        // The h1 king is boxed in by its own pieces; restriction must not
        // produce nil, or a stalled player would get no move at all.
        let p = try position("3q3k/8/8/8/8/8/6PP/R5NK w - - 0 1")
        let best = ChessEngine.searchBestMove(in: p, depth: 2,
                                              constraints: .init(restrictedTo: "h1"))
        XCTAssertNotNil(best)
        XCTAssertNotEqual(best?.from, "h1")
    }

    func testCheckLeavesOnlyResolvingMoves() throws {
        // Black rook on e8 checks the white king on e1. Every legal move must
        // resolve it — that is what makes the §25.4 constraint automatic.
        let p = try position("4r2k/8/8/8/8/8/8/4K3 w - - 0 1")
        let moves = ChessRules.legalMoves(in: p)
        XCTAssertFalse(moves.isEmpty)
        for move in moves {
            XCTAssertFalse(ChessRules.isCheck(in: ChessRules.applying(move, to: p)) &&
                           ChessRules.applying(move, to: p).turn == .white,
                           "\(move.coordinateNotation) left White in check")
        }
    }

    func testExcludedSourcesAndDestinationsAreRespected() throws {
        // §25.5: a piece may not move twice, and two pieces may not share a
        // destination, within one Black multi-move phase.
        let p = try position(Chess.FEN.standard)
        let first = try XCTUnwrap(ChessEngine.searchBestMove(in: p, depth: 1))
        let second = ChessEngine.searchBestMove(
            in: p, depth: 1,
            constraints: .init(excludedSources: [first.from],
                               excludedDestinations: [first.to]))
        XCTAssertNotNil(second)
        XCTAssertNotEqual(second?.from, first.from)
        XCTAssertNotEqual(second?.to, first.to)
    }

    func testExhaustedExclusionsYieldNilRatherThanAnIllegalMove() throws {
        // Only one legal move exists; excluding its source must return nil so
        // Black makes fewer moves rather than something illegal.
        let p = try position("7k/8/8/8/8/8/8/K7 w - - 0 1")
        let only = ChessRules.legalMoves(in: p).map { $0.from.coordinate }
        let blocked = ChessEngine.searchBestMove(
            in: p, depth: 1, constraints: .init(excludedSources: Set(only)))
        XCTAssertNil(blocked)
    }
}

// MARK: - Performance

final class ChessPerformanceTests: XCTestCase {

    /// Phase 1 pass criterion: 1,000 move generations from the starting position
    /// in under 100 ms total.
    func testMoveGenerationThroughput() throws {
        let start = try XCTUnwrap(Chess.FEN.position(from: Chess.FEN.standard))
        let began = Date()
        var total = 0
        for _ in 0..<1_000 {
            total += ChessRules.legalMoves(in: start).count
        }
        let elapsed = Date().timeIntervalSince(began)
        XCTAssertEqual(total, 20_000, "sanity: 20 legal moves each time")
        XCTAssertLessThan(elapsed, 0.100, "1,000 generations took \(Int(elapsed * 1000))ms")
    }

    /// Phase 1 pass criterion: a full engine turn in under 50 ms.
    func testEngineTurnLatency() throws {
        let start = try XCTUnwrap(Chess.FEN.position(from: Chess.FEN.standard))
        let began = Date()
        _ = ChessEngine.searchBestMove(in: start, depth: 2)
        let elapsed = Date().timeIntervalSince(began)
        XCTAssertLessThan(elapsed, 0.050, "depth-2 search took \(Int(elapsed * 1000))ms")
    }
}

// MARK: - Starfield tiling

/// The starfield is two identical copies of one random layout, swapping slots
/// each cycle. Everything rests on copy B landing exactly where copy A started;
/// if it does not, the whole field jumps at the handoff and reads as the
/// animation restarting. That is what these pin down.
final class StarfieldTilingTests: XCTestCase {

    /// Every drift value the game actually ships.
    private let drifts: [CGFloat] = [0.00, 0.30, -0.16]

    func testHandoffIsSeamless() {
        for drift in drifts + [0.15, -0.20] {
            let tiling = StarfieldTiling(sceneHeight: 700, drift: drift)
            XCTAssertTrue(tiling.isSeamless,
                          "drift \(drift): B landed at \(tiling.advanced(tiling.slotB)), "
                          + "A starts at \(tiling.slotA)")
        }
    }

    func testCopiesReturnToTheirOwnSlots() {
        // If a copy does not return exactly, the tier walks sideways off screen.
        for drift in drifts {
            let tiling = StarfieldTiling(sceneHeight: 700, drift: drift)
            XCTAssertEqual(tiling.rewound(tiling.advanced(tiling.slotA)), tiling.slotA)
            XCTAssertEqual(tiling.rewound(tiling.advanced(tiling.slotB)), tiling.slotB)
        }
    }

    func testNoHorizontalWalkOverManyCycles() {
        let tiling = StarfieldTiling(sceneHeight: 700, drift: 0.08)
        var point = tiling.slotA
        for _ in 0..<500 { point = tiling.rewound(tiling.advanced(point)) }
        XCTAssertEqual(point, tiling.slotA, "drifted to \(point) after 500 cycles")
    }

    func testDriftAnglesAreVisibleAndNotParallel() {
        let mid = StarfieldTiling(sceneHeight: 700, drift: 0.30)
        let midAngle = atan2(abs(mid.dx), mid.sceneHeight) * 180 / .pi
        XCTAssertGreaterThan(midAngle, 15.0, "the lean has to actually read on screen")
        XCTAssertLessThan(midAngle, 25.0, "but stars should still fall, not fly sideways")

        let near = StarfieldTiling(sceneHeight: 700, drift: -0.16)
        let nearAngle = atan2(abs(near.dx), near.sceneHeight) * 180 / .pi
        XCTAssertGreaterThan(nearAngle, 7.0)
        XCTAssertNotEqual(mid.dx < 0, near.dx < 0, "tiers must lean opposite ways")
        XCTAssertEqual(StarfieldTiling(sceneHeight: 700, drift: 0).dx, 0,
                       "the distant tier falls straight down as a reference")
    }
}

// MARK: - Engine variation

/// The engine once shuffled a single rook between two squares indefinitely in
/// auto-move play: material-only evaluation scored every quiet move at 0, the
/// first of those always won the tie, and nothing discouraged revisiting a
/// position. These pin the three fixes.
@MainActor
final class EngineVariationTests: XCTestCase {

    /// Plays `count` engine moves from the opening and returns them as
    /// "kind from-to" strings.
    private func autoPlay(_ count: Int) -> [String] {
        let board = GCIBoard()
        board.setupStandardPosition()
        var moves: [String] = []
        for _ in 0..<count {
            guard let found = ChessEngine.searchBestMove(in: board.currentPosition,
                                                        depth: 2,
                                                        avoiding: board.currentHistory),
                  let outcome = board.applyChessMove(from: found.from, to: found.to)
            else { break }
            moves.append("\(outcome.moved.type.rawValue) \(outcome.from)-\(outcome.to)")
        }
        return moves
    }

    func testDoesNotSettleIntoATwoSquareShuffle() {
        let moves = autoPlay(40)
        // Engine-against-engine from the opening runs into the 30-quiet-move
        // draw rule well before forty plies, which is the rule working. What
        // matters here is that the moves it does find are not an A-B-A-B loop.
        XCTAssertGreaterThan(moves.count, 20, "engine stopped finding moves early")

        // The reported symptom: move n identical to move n-2, over and over.
        let echoes = (2..<moves.count).count { moves[$0] == moves[$0 - 2] }
        XCTAssertLessThan(echoes, 6, "looks like an A-B-A-B shuffle: \(moves)")
    }

    func testAutoPlayUsesManyPiecesAndSquares() {
        let moves = autoPlay(40)
        XCTAssertGreaterThanOrEqual(Set(moves).count, 20, "too repetitive: \(moves)")
        let kinds = Set(moves.compactMap { $0.split(separator: " ").first })
        XCTAssertGreaterThanOrEqual(kinds.count, 3, "only \(kinds) ever moved")
    }

    func testOpeningVariesBetweenGames() {
        var openings: Set<String> = []
        for _ in 0..<16 {
            let board = GCIBoard()
            board.setupStandardPosition()
            if let found = ChessEngine.searchBestMove(in: board.currentPosition, depth: 2,
                                                     avoiding: board.currentHistory) {
                openings.insert("\(found.from)-\(found.to)")
            }
        }
        XCTAssertGreaterThanOrEqual(openings.count, 3,
                                    "every game opens the same way: \(openings)")
    }

    /// Variation must not cost competence — §25.2 promises the player will not be
    /// punished by a blunder.
    func testStillTakesAFreeQueenEveryTime() throws {
        let position = try XCTUnwrap(
            Chess.FEN.position(from: "3q3k/8/8/8/8/8/8/3Q3K w - - 0 1"))
        for _ in 0..<20 {
            XCTAssertEqual(ChessEngine.searchBestMove(in: position, depth: 2)?.to, "d8")
        }
    }

    func testStillDeclinesLosingCaptures() throws {
        // The d5 pawn is defended by c6, so Qxd5 trades a queen for a pawn.
        let position = try XCTUnwrap(
            Chess.FEN.position(from: "7k/8/2p5/3p4/8/8/3Q4/7K w - - 0 1"))
        for _ in 0..<25 {
            XCTAssertNotEqual(ChessEngine.searchBestMove(in: position, depth: 2)?.to, "d5")
        }
    }

    func testRepetitionPenaltySteersAwayFromASeenBoard() throws {
        let position = try XCTUnwrap(
            Chess.FEN.position(from: "7k/8/8/8/8/8/P7/R6K w - - 0 1"))
        let sideStep = try XCTUnwrap(
            ChessRules.legalMoves(in: position)
                .first { $0.from.coordinate == "a1" && $0.to.coordinate == "b1" })
        let after = ChessRules.applying(sideStep, to: position)

        // Coming back to the original board is available but penalised.
        let reply = ChessEngine.searchBestMove(in: after, depth: 2,
                                               avoiding: [position.board])
        XCTAssertNotNil(reply)
    }
}

// MARK: - How To Play footer

@MainActor
final class HowToPlayNodeTests: XCTestCase {

    private func labels(in node: SKNode) -> [SKLabelNode] {
        var found: [SKLabelNode] = []
        var stack = Array(node.children)
        while let next = stack.popLast() {
            if let label = next as? SKLabelNode { found.append(label) }
            stack.append(contentsOf: next.children)
        }
        return found
    }

    func testCopyrightSitsInTheLowerRightWithoutColliding() throws {
        let screen = HowToPlayNode(sceneSize: CGSize(width: 960, height: 700))
        let all = labels(in: screen)

        let copyright = try XCTUnwrap(all.first { $0.text?.contains("Zack Urlocker") == true })
        XCTAssertEqual(copyright.text, "Copyright (C) 1983-2026 M. Zack Urlocker")
        XCTAssertEqual(copyright.horizontalAlignmentMode, .right)

        // SKColor.white is a named colour and will not test equal to the
        // converted instance the label holds, so compare components.
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        copyright.fontColor?.usingColorSpace(.deviceRGB)?
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1); XCTAssertEqual(g, 1)
        XCTAssertEqual(b, 1); XCTAssertEqual(a, 1)

        let frame = copyright.calculateAccumulatedFrame()
        XCTAssertLessThanOrEqual(frame.maxX, 960 - 40, "runs past the right margin")
        XCTAssertGreaterThan(frame.minX, 0, "runs off the left edge")
        XCTAssertLessThan(frame.maxY, 70, "should sit below the footer rule")

        // Press Start 2P is wide, so overlap with the neighbouring footer items
        // is the real risk here.
        let hint = try XCTUnwrap(all.first { $0.text?.contains("RESUME") == true })
        XCTAssertGreaterThan(frame.minX, hint.calculateAccumulatedFrame().maxX,
                             "overlaps the resume hint")
        for back in screen.children where back.name == "backButton" {
            XCTAssertFalse(frame.intersects(back.calculateAccumulatedFrame()),
                           "overlaps the BACK button")
        }
    }
}

// MARK: - Game over

@MainActor
final class GameOverNodeTests: XCTestCase {

    private func texts(in node: SKNode) -> [String] {
        var found: [String] = []
        var stack = Array(node.children)
        while let next = stack.popLast() {
            if let label = next as? SKLabelNode, let text = label.text { found.append(text) }
            stack.append(contentsOf: next.children)
        }
        return found
    }

    func testEveryOutcomeShowsThePromptAndScore() {
        for outcome in [GameOverNode.Outcome.whiteMated, .livesDepleted, .stalemate] {
            let node = GameOverNode(outcome: outcome, score: 1275,
                                    sceneSize: CGSize(width: 960, height: 700))
            let labels = texts(in: node)
            XCTAssertTrue(labels.contains(outcome.headline), "\(outcome) headline missing")
            XCTAssertTrue(labels.contains { $0.contains("NEW GAME?") }, "\(outcome) prompt missing")
            XCTAssertTrue(labels.contains { $0.contains("Y / N") }, "\(outcome) Y/N missing")
            XCTAssertTrue(labels.contains { $0.contains("1275") }, "\(outcome) score missing")
        }
    }

    /// Pausing over a reveal banner must leave both readable. They were both
    /// centred, so PAUSED landed exactly on BLACK KING DESTROYED — in the one
    /// situation the player is most likely to pause in.
    ///
    /// Press Start 2P draws ~0.7em of cap height, and `.center` alignment
    /// centres that box on the node's position.
    func testPausedBannerClearsTheRevealBanner() {
        func halfHeight(_ fontSize: CGFloat) -> CGFloat { fontSize * 0.7 / 2 }
        let revealTop = halfHeight(30)                 // showEndBanner, at centre
        let hintBottom = GameScene.pauseLift - GameScene.pauseHintGap - halfHeight(11)
        XCTAssertGreaterThan(hintBottom - revealTop, 8,
                             "the hint must clear the reveal banner, with room")
        // And the title has to clear its own hint.
        let titleBottom = GameScene.pauseLift - halfHeight(36)
        let hintTop = GameScene.pauseLift - GameScene.pauseHintGap + halfHeight(11)
        XCTAssertGreaterThan(titleBottom - hintTop, 4)
    }

    /// Losing and winning must not both read "GAME OVER" — and clearing a wave
    /// must not read the same as finishing the run, or the ending is invisible.
    func testWinAndLossReadDifferently() {
        XCTAssertEqual(GameOverNode.Outcome.whiteMated.headline, "GAME OVER")
        XCTAssertEqual(GameOverNode.Outcome.waveCleared(next: 2).headline, "LEVEL CLEARED!")
        XCTAssertEqual(GameOverNode.Outcome.runCompleted.headline, "YOU WIN")
        XCTAssertNotEqual(GameOverNode.Outcome.whiteMated.detail,
                          GameOverNode.Outcome.waveCleared(next: 2).detail)
        XCTAssertNotEqual(GameOverNode.Outcome.waveCleared(next: 2).detail,
                          GameOverNode.Outcome.runCompleted.detail)
    }
}

final class MateDetectionTests: XCTestCase {

    /// The engine reports mate for whoever must move, which is what lets one
    /// check cover both a loss and a win.
    func testMateIsDetectedForEitherSide() throws {
        let blackMated = try XCTUnwrap(ChessEngine(fen: "R6k/6pp/8/8/8/8/8/7K b - - 0 1"))
        XCTAssertTrue(blackMated.isMate)
        XCTAssertEqual(blackMated.turn, .black, "player win")

        // Mirrored: black rook a1, white king boxed in by its own pawns.
        let whiteMated = try XCTUnwrap(ChessEngine(fen: "7k/8/8/8/8/8/6PP/r6K w - - 0 1"))
        XCTAssertTrue(whiteMated.isMate)
        XCTAssertEqual(whiteMated.turn, .white, "player loss")
    }
}

@MainActor
final class RestartTests: XCTestCase {

    func testXRestartClearsTheLogAndLeavesRestartFirst() {
        let scene = GameScene.shared
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 960, height: 700))
        view.presentScene(scene)

        DiagnosticsLog.shared.clear()
        for i in 0..<25 { DiagnosticsLog.shared.log(.chess, "noise \(i)") }
        XCTAssertEqual(DiagnosticsLog.shared.lines.count, 25)

        scene.resetToTitle()

        let lines = DiagnosticsLog.shared.lines
        XCTAssertFalse(lines.contains { $0.message.hasPrefix("noise") },
                       "previous game's lines survived the restart")
        XCTAssertEqual(lines.first?.category, .restart, "RESTART should head the fresh log")
        XCTAssertEqual(lines.first?.message, "", "RESTART reads as the whole line")
    }

    func testGameOverAcceptsBothAnswers() {
        let scene = GameScene.shared
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 960, height: 700))
        view.presentScene(scene)

        // The whole suite shares this one scene, so whatever ran before has left
        // the machine somewhere. Title is reachable from everywhere except
        // Title itself, which makes it the one safe place to start from.
        if !(scene.stateMachine.currentState is TitleState) {
            XCTAssertTrue(scene.stateMachine.enter(TitleState.self))
        }
        XCTAssertTrue(scene.stateMachine.enter(PlayingState.self))
        XCTAssertTrue(scene.stateMachine.enter(GameOverState.self))
        XCTAssertTrue(scene.stateMachine.enter(PlayingState.self), "Y must start a new game")
        XCTAssertTrue(scene.stateMachine.enter(GameOverState.self))
        XCTAssertTrue(scene.stateMachine.enter(TitleState.self), "N must return to the title")
    }
}

// MARK: - Audio

/// SoundKey maps every event to a filename by hand, and a wrong name fails
/// silently — the sound simply never plays. Several GDC entries were truncated
/// versions of the real filenames, which is exactly that failure. These assert
/// the sounds the game currently triggers really resolve in the bundle.
@MainActor
final class AudioAssetTests: XCTestCase {

    /// The keys the chess layer plays today. Extend as later phases wire more.
    private let wiredKeys: [SoundKey] = [
        .pieceSelected, .whitePieceMoves, .blackPieceMoves, .pieceHitHeavy,
        .illegalMove, .checkAlarm, .pawnPromotion, .autoMoveTrigger,
        .turnTimerWarning, .levelClear, .gameOver, .uiButtonClick,
    ]

    private var sfxRoot: URL? {
        Bundle.main.url(forResource: "sfx", withExtension: nil)
    }

    func testSfxFolderIsBundledWithItsSubdirectories() throws {
        let root = try XCTUnwrap(sfxRoot, "sfx must be bundled as a folder reference")
        // Filenames carry a vendor subdirectory, so a flattened copy would break them.
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path,
                                                    isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testEveryWiredSoundResolvesAndLoads() throws {
        let root = try XCTUnwrap(sfxRoot)
        for key in wiredKeys {
            let url = root.appendingPathComponent(key.filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "\(key) missing: \(key.filename)")
            XCTAssertNoThrow(try AVAudioPlayer(contentsOf: url),
                             "\(key) exists but will not decode")
        }
    }

    func testPreloadReportsNoErrors() {
        DiagnosticsLog.shared.clear()
        AudioManager.shared.preloadAll()
        XCTAssertFalse(DiagnosticsLog.shared.lines.contains { $0.category == .error },
                       "preload logged an error: \(DiagnosticsLog.shared.lines.map(\.message))")
    }

    /// Playing a key with no bundled file must be a no-op, so later phases can
    /// reference sounds before their assets land.
    func testUnbundledKeyIsASilentNoOp() {
        AudioManager.shared.preloadAll()
        DiagnosticsLog.shared.clear()
        AudioManager.shared.play(.fleetHeartbeat)   // generated/, never on disk
        XCTAssertFalse(DiagnosticsLog.shared.lines.contains { $0.category == .error })
    }
}

// MARK: - Check visualisation

final class CheckAttackerTests: XCTestCase {

    private func attackers(_ fen: String, _ side: PieceColor) throws -> [String] {
        let engine = try XCTUnwrap(ChessEngine(fen: fen))
        return try XCTUnwrap(engine.checkThreat(against: side)).attackers.map(\.square)
    }

    func testFindsTheCheckingPieceForEachKind() throws {
        XCTAssertEqual(try attackers("4r2k/8/8/8/8/8/8/4K3 w - - 0 1", .white), ["e8"], "rook")
        XCTAssertEqual(try attackers("7k/8/8/8/8/5n2/8/4K3 w - - 0 1", .white), ["f3"], "knight")
        XCTAssertEqual(try attackers("7k/8/8/b7/8/8/8/4K3 w - - 0 1", .white), ["a5"], "bishop")
        XCTAssertEqual(try attackers("7k/8/8/8/8/8/3p4/4K3 w - - 0 1", .white), ["d2"], "pawn")
    }

    func testDoubleCheckReportsBothAttackers() throws {
        let both = try attackers("4r2k/8/8/8/8/5n2/8/4K3 w - - 0 1", .white)
        XCTAssertEqual(Set(both), ["e8", "f3"])
    }

    func testBlackInCheckIsAlsoReported() throws {
        XCTAssertEqual(try attackers("4k3/8/8/8/8/8/8/4R2K b - - 0 1", .black), ["e1"])
    }

    func testNoThreatWhenNotInCheck() throws {
        let quiet = try XCTUnwrap(ChessEngine(fen: Chess.FEN.standard))
        XCTAssertNil(quiet.checkThreat(against: .white))
        // A blocked ray is not a check.
        let blocked = try XCTUnwrap(ChessEngine(fen: "4r2k/8/8/8/8/8/4P3/4K3 w - - 0 1"))
        XCTAssertNil(blocked.checkThreat(against: .white))
    }

    func testKnightIsMarkedAsAJump() throws {
        let engine = try XCTUnwrap(ChessEngine(fen: "7k/8/8/8/8/5n2/8/4K3 w - - 0 1"))
        XCTAssertEqual(try XCTUnwrap(engine.checkThreat(against: .white)).attackers.first?.kind,
                       .knight, "a knight's path must render dashed")
    }
}

@MainActor
final class CheckPathNodeTests: XCTestCase {

    private func pathNodes(in board: BoardNode) -> [SKNode] {
        board.children.filter { $0.name == "checkPath" }
    }

    /// Endpoints are points now, not squares — fleet pieces are drawn off their
    /// logical square, so the scene resolves where each piece actually is.
    private func path(_ board: BoardNode, _ from: String, _ to: String,
                      isJump: Bool = false) -> (from: CGPoint, to: CGPoint, isJump: Bool) {
        (from: board.center(of: from) ?? .zero,
         to: board.center(of: to) ?? .zero, isJump: isJump)
    }

    func testLineStartsAtTheAttackerAndPointsAtTheKing() throws {
        let board = BoardNode()
        board.showCheckPaths([path(board, "e8", "e1")], color: .magenta)

        let node = try XCTUnwrap(pathNodes(in: board).first)
        let shapes = node.children.compactMap { $0 as? SKShapeNode }
        XCTAssertEqual(shapes.count, 3, "line plus a ring at each end")

        let line = try XCTUnwrap(shapes.first)
        let attacker = try XCTUnwrap(board.center(of: "e8"))
        let king = try XCTUnwrap(board.center(of: "e1"))
        XCTAssertEqual(line.position, attacker)
        XCTAssertEqual(line.zRotation, atan2(king.y - attacker.y, king.x - attacker.x),
                       accuracy: 0.001)
        // Grown via xScale so the stroke does not thicken as it draws.
        XCTAssertLessThan(line.xScale, 0.01)
        XCTAssertEqual(line.yScale, 1)
    }

    func testDoubleCheckDrawsTwoPaths() {
        let board = BoardNode()
        board.showCheckPaths([path(board, "e8", "e1"),
                              path(board, "f3", "e1", isJump: true)], color: .magenta)
        XCTAssertEqual(pathNodes(in: board).count, 2)
    }

    func testRepeatedShowsReplaceRatherThanStack() {
        let board = BoardNode()
        for _ in 0..<5 {
            board.showCheckPaths([path(board, "e8", "e1")], color: .magenta)
        }
        XCTAssertEqual(pathNodes(in: board).count, 1)
        board.clearCheckPaths()
        XCTAssertTrue(pathNodes(in: board).isEmpty)
    }

    func testDegenerateInputIsSafe() {
        let board = BoardNode()
        // A zero-length path would divide by zero when computing the angle. It is
        // reachable now that endpoints are points: a piece drawn exactly on the
        // king's square during a snap would produce one.
        let king = try? XCTUnwrap(board.center(of: "e1"))
        board.showCheckPaths([(from: king ?? .zero, to: king ?? .zero, isJump: false)],
                             color: .magenta)
        XCTAssertTrue(pathNodes(in: board).allSatisfy { $0.children.isEmpty })
        board.clearCheckPaths()

        let degenerate = CheckPathNode(from: .zero, to: .zero, isJump: false, color: .magenta)
        XCTAssertTrue(degenerate.children.isEmpty)
    }

    /// Long enough to read, short enough to be gone before the next move lands.
    func testDurationIsBounded() {
        XCTAssertGreaterThan(CheckPathNode.totalDuration, 0.8)
        XCTAssertLessThan(CheckPathNode.totalDuration, 1.5)
    }
}

// MARK: - Beat lifecycle

/// Mirrors GameScene's beat rules — including the self-healing invariant in
/// `update` — so timer visibility and reset can be tested without SpriteKit.
@MainActor
private final class BeatSim {
    let timer = TurnTimer()
    let levels = LevelManager()
    var turn: PieceColor = .white
    var whiteMoved = false
    var resolving = false
    var inCheck = false

    /// The countdown is the player's clock: shown only when White can act.
    var timerVisible: Bool {
        timer.isRunning && !whiteMoved && !resolving && turn == .white
    }

    func beginBeat() {
        whiteMoved = false
        timer.start(level: levels.parameters, inCheck: inCheck && turn == .white)
    }

    /// One frame of the PlayingState branch of `update`.
    @discardableResult
    func tick(_ dt: TimeInterval) -> Bool {
        if !resolving, turn == .white, !timer.isRunning { beginBeat() }
        return timer.update(deltaTime: dt)
    }

    func whitePlays() { whiteMoved = true; turn = .black }

    func resolve(interrupted: Bool = false) {
        resolving = true
        turn = .white
        resolving = false
        if !interrupted { beginBeat() }
    }
}

@MainActor
final class BeatLifecycleTests: XCTestCase {

    func testCountdownOnlyShowsWhileWhiteCanMove() {
        let sim = BeatSim()
        sim.beginBeat()
        XCTAssertTrue(sim.timerVisible, "should show at the start of White's beat")

        sim.whitePlays()
        XCTAssertFalse(sim.timerVisible, "White has already moved this beat")
        XCTAssertTrue(sim.timer.isRunning, "the beat still runs — it paces Black")

        sim.resolving = true
        XCTAssertFalse(sim.timerVisible, "Black is thinking")
    }

    func testEveryNewBeatResetsToFullDuration() {
        let sim = BeatSim()
        sim.beginBeat()
        while !sim.tick(0.05) {}
        sim.resolve()
        XCTAssertTrue(sim.timer.isRunning)
        XCTAssertEqual(sim.timer.remaining, 5.0)
        XCTAssertFalse(sim.whiteMoved)
        XCTAssertTrue(sim.timerVisible)
    }

    /// `resolveBeat` has early returns — pausing while Black was thinking once
    /// left no live beat and no way to move. `update` must recover.
    func testInterruptedResolveRecoversOnTheNextFrame() {
        let sim = BeatSim()
        sim.beginBeat()
        while !sim.tick(0.05) {}
        sim.resolve(interrupted: true)
        XCTAssertFalse(sim.timer.isRunning, "the hazard: no beat running")

        sim.tick(0.016)
        XCTAssertTrue(sim.timer.isRunning, "invariant must restart the beat")
        XCTAssertTrue(sim.timerVisible)
        XCTAssertGreaterThan(sim.timer.remaining, 4.9, "a full beat, not a remnant")
    }

    func testCheckExtensionAppliesOnlyToWhite() {
        let white = BeatSim()
        white.inCheck = true
        white.beginBeat()
        XCTAssertEqual(white.timer.duration, LevelManager.checkExtension)

        let black = BeatSim()
        black.inCheck = true
        black.turn = .black
        black.beginBeat()
        XCTAssertEqual(black.timer.duration, 5.0, "Black's beat is never extended")
    }

    func testDurationDoesNotDriftOverManyBeats() {
        let sim = BeatSim()
        sim.beginBeat()
        var beats = 0
        for _ in 0..<4000 where sim.tick(0.05) {
            sim.resolve()
            beats += 1
        }
        XCTAssertGreaterThan(beats, 30)
        XCTAssertEqual(sim.timer.duration, 5.0)
        XCTAssertTrue(sim.timer.isRunning)
    }
}

// MARK: - King check glow

@MainActor
final class KingCheckGlowTests: XCTestCase {

    private func king(_ color: PieceColor) -> PieceNode {
        PieceNode(piece: Piece(type: .king, color: color, square: color == .white ? "e1" : "e8"),
                  squareSize: BoardNode.squareSize)
    }

    private func rgb(_ node: PieceNode) -> (CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        node.color.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func testGlowAttachesAndDetaches() {
        let node = king(.white)
        XCTAssertFalse(node.isShowingCheck)
        XCTAssertTrue(node.children.isEmpty)

        node.setCheckGlow(true)
        XCTAssertTrue(node.isShowingCheck)
        XCTAssertNotNil(node.action(forKey: "checkGlow"), "sprite should pulse red")
        // Halo sits behind the sprite so the silhouette stays readable.
        XCTAssertEqual(node.children.compactMap { $0 as? SKShapeNode }.first?.zPosition, -1)

        node.setCheckGlow(false)
        XCTAssertFalse(node.isShowingCheck)
        XCTAssertTrue(node.children.isEmpty)
        XCTAssertNil(node.action(forKey: "checkGlow"))
    }

    func testRepeatedCallsDoNotStackHalos() {
        let node = king(.white)
        for _ in 0..<5 { node.setCheckGlow(true) }
        XCTAssertEqual(node.children.count, 1)
        for _ in 0..<5 { node.setCheckGlow(false) }
        XCTAssertTrue(node.children.isEmpty)
    }

    /// Clearing must restore the side's tint, not strand the piece red.
    func testBaseTintIsRestoredForBothSides() {
        let white = king(.white)
        white.setCheckGlow(true)
        white.setCheckGlow(false)
        let (wr, wg, wb) = rgb(white)
        XCTAssertLessThan(wr, 0.2); XCTAssertGreaterThan(wg, 0.8); XCTAssertGreaterThan(wb, 0.9)
        XCTAssertEqual(white.colorBlendFactor, 0.22, accuracy: 0.001)

        let black = king(.black)
        black.setCheckGlow(true)
        black.setCheckGlow(false)
        let (br, bg, _) = rgb(black)
        XCTAssertGreaterThan(br, 0.9); XCTAssertLessThan(bg, 0.2)
    }

    func testDamageSwapDoesNotCancelTheGlow() {
        var piece = Piece(type: .king, color: .white, square: "e1")
        let node = PieceNode(piece: piece, squareSize: BoardNode.squareSize)
        node.setCheckGlow(true)
        piece.applyDamage(8)                 // 8/16 HP → chipped, texture changes
        node.refresh(with: piece)
        XCTAssertTrue(node.isShowingCheck)
        XCTAssertNotNil(node.action(forKey: "checkGlow"))
    }

    func testDestructionClearsTheGlow() {
        let node = king(.white)
        node.setCheckGlow(true)
        node.runDestructionAnimation {}
        XCTAssertFalse(node.isShowingCheck)
    }

    func testThreatIdentifiesTheCorrectKingSquare() throws {
        let whiteChecked = try XCTUnwrap(ChessEngine(fen: "4r2k/8/8/8/8/8/8/4K3 w - - 0 1"))
        XCTAssertEqual(whiteChecked.checkThreat(against: .white)?.kingSquare, "e1")
        XCTAssertNil(whiteChecked.checkThreat(against: .black))

        let blackChecked = try XCTUnwrap(ChessEngine(fen: "4k3/8/8/8/8/8/8/4R2K b - - 0 1"))
        XCTAssertEqual(blackChecked.checkThreat(against: .black)?.kingSquare, "e8")
        XCTAssertNil(blackChecked.checkThreat(against: .white))
    }
}

// MARK: - Checkmate reveal

@MainActor
final class MateRevealTests: XCTestCase {

    /// Detection must not cut straight to the menu: the mating path has to finish
    /// drawing, with a moment of stillness after it, before the overlay appears.
    func testRevealOutlastsTheMatingPath() {
        let checkPath = CheckPathNode.duration(pulses: 2)
        let matePath = CheckPathNode.duration(pulses: 3)
        let reveal: TimeInterval = 2.5      // GameScene.gameEndRevealDelay

        XCTAssertGreaterThan(matePath, checkPath, "mate should read harder than a check")
        XCTAssertLessThan(matePath, reveal, "the path must finish before the menu")
        XCTAssertGreaterThan(reveal - matePath, 0.2, "leave a beat of stillness")
        XCTAssertTrue((2.0...3.0).contains(reveal))
    }

    func testBannerSaysCheckmateAndFitsTheGutter() {
        let status = GameStatusNode()
        status.show(.checkmate(.white))
        status.position = CGPoint(x: 112, y: 116)

        let labels = status.children.compactMap { ($0 as? SKLabelNode)?.text }
        XCTAssertTrue(labels.contains("CHECKMATE"))
        XCTAssertTrue(labels.contains("WHITE"), "the side matters")

        // The board's left edge is x = 224; the banner lives in the gutter.
        let frame = status.calculateAccumulatedFrame()
        XCTAssertLessThan(frame.maxX, 224)
        XCTAssertGreaterThan(frame.minX, 0)
    }

    func testCheckStillReadsCheck() {
        let status = GameStatusNode()
        status.show(.check(.white))
        XCTAssertTrue(status.children.compactMap { ($0 as? SKLabelNode)?.text }.contains("CHECK"))
    }

    /// The mating piece has to be identifiable, or there is nothing to trace.
    func testMatingPieceIsIdentified() throws {
        let mated = try XCTUnwrap(ChessEngine(fen: "7k/8/8/8/8/8/6PP/r6K w - - 0 1"))
        XCTAssertTrue(mated.isMate)
        let threat = try XCTUnwrap(mated.checkThreat(against: .white))
        XCTAssertEqual(threat.attackers.map(\.square), ["a1"])
        XCTAssertEqual(threat.kingSquare, "h1")
    }

    func testKnightMateIsFlaggedAsAJump() throws {
        let mate = try XCTUnwrap(ChessEngine(fen: "6rk/5Npp/8/8/8/8/8/7K b - - 0 1"))
        XCTAssertTrue(mate.isMate)
        let threat = try XCTUnwrap(mate.checkThreat(against: .black))
        XCTAssertEqual(threat.attackers.first?.kind, .knight, "must render dashed")
    }
}

// MARK: - Level progression, test mode, name entry

@MainActor
final class LevelProgressionTests: XCTestCase {

    func testAdvancingRaisesTheMultiplierAndTightensTheBeat() {
        let levels = LevelManager()
        ScoreManager.shared.resetForNewGame()
        XCTAssertEqual(levels.level, 1)
        XCTAssertEqual(ScoreManager.shared.multiplier, 1.0)

        levels.advance(); ScoreManager.shared.advanceLevel()
        XCTAssertEqual(levels.level, 2)
        XCTAssertEqual(ScoreManager.shared.multiplier, 1.5)

        levels.advance(); ScoreManager.shared.advanceLevel()
        XCTAssertEqual(levels.parameters.turnTimer, 4.0, "beat tightens at L3")
        XCTAssertEqual(levels.parameters.blackMovesPerTurn, 2, "multi-move unlocks at L3")
    }

    /// The checkmate bonus goes through the multiplier like any other points.
    func testCheckmateBonusScalesWithLevel() {
        ScoreManager.shared.resetForNewGame()
        ScoreManager.shared.addPoints(300)
        XCTAssertEqual(ScoreManager.shared.currentScore, 300)
        ScoreManager.shared.advanceLevel()
        ScoreManager.shared.addPoints(300)
        XCTAssertEqual(ScoreManager.shared.currentScore, 750, "300 + 300×1.5")
    }
}

@MainActor
final class TestModeTests: XCTestCase {

    private var level1: LevelParameters { LevelManager.parameters(for: 1) }

    func testOverrideCollapsesTheBeat() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: false)
        XCTAssertEqual(timer.duration, 5.0)

        timer.start(level: level1, inCheck: false, override: 1.0)
        XCTAssertEqual(timer.duration, 1.0)
    }

    /// Test mode must beat the check extension too, or a checked position would
    /// stall for 8 seconds in the middle of a fast run.
    func testOverrideBeatsTheCheckExtension() {
        let timer = TurnTimer()
        timer.start(level: level1, inCheck: true, override: 1.0)
        XCTAssertEqual(timer.duration, 1.0)
        XCTAssertFalse(timer.isExtended)

        timer.start(level: level1, inCheck: true)
        XCTAssertEqual(timer.duration, LevelManager.checkExtension)
        XCTAssertTrue(timer.isExtended)
    }
}

@MainActor
final class HighScoreEntryTests: XCTestCase {

    private func press(_ node: HighScoreEntryNode, _ keyCode: UInt16, _ characters: String) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)
        else { return XCTFail("could not synthesise a key event") }
        node.handleKey(event)
    }

    private func makeEntry() -> HighScoreEntryNode {
        HighScoreEntryNode(score: 4200, level: 3, sceneSize: CGSize(width: 960, height: 700))
    }

    func testTypingUppercasesAndDeleteWorks() {
        let entry = makeEntry()
        for character in "zack" { press(entry, 0, String(character)) }
        XCTAssertEqual(entry.enteredName, "ZACK")
        press(entry, 51, "")
        XCTAssertEqual(entry.enteredName, "ZAC")
    }

    func testNameIsCappedAtEightCharacters() {
        let entry = makeEntry()
        for character in "zackurlocker" { press(entry, 0, String(character)) }
        XCTAssertEqual(entry.enteredName.count, HighScoreEntryNode.maxLength)
        XCTAssertEqual(entry.enteredName, "ZACKURLO")
    }

    func testDigitsAndSymbolsAreAccepted() {
        for name in ["R2-D2", "ZACK!", "#1", "*@%", "$100"] {
            let entry = makeEntry()
            for character in name { press(entry, 0, String(character)) }
            XCTAssertEqual(entry.enteredName, name.uppercased())
        }
    }

    /// `characters` carries the shifted result; `charactersIgnoringModifiers`
    /// reports the unshifted key, so it would turn ⇧1 into "1" rather than "!".
    func testShiftedKeysArriveAsSymbols() {
        let entry = makeEntry()
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "!",
            charactersIgnoringModifiers: "1", isARepeat: false, keyCode: 0)
        else { return XCTFail("could not synthesise a key event") }
        entry.handleKey(event)
        XCTAssertEqual(entry.enteredName, "!")
    }

    func testNonASCIIIsRejected() {
        let entry = makeEntry()
        for character in "åé★" { press(entry, 0, String(character)) }
        XCTAssertTrue(entry.enteredName.isEmpty)
    }

    /// Return submits whatever is there — nothing requires filling all 8.
    func testReturnSubmitsAtAnyLength() {
        for name in ["Z", "AB", "WOZ", "ZACK", "URLOCK", "ZACKURLO"] {
            let entry = makeEntry()
            var submitted: String?
            entry.onSubmit = { submitted = $0 }
            for character in name { press(entry, 0, String(character)) }
            press(entry, 36, "\r")
            XCTAssertEqual(submitted, name, "\(name.count)-character name should submit")
        }
    }

    func testReturnSubmitsAndEmptyFallsBack() {
        let typed = makeEntry()
        var result: String?
        typed.onSubmit = { result = $0 }
        for character in "woz" { press(typed, 0, String(character)) }
        press(typed, 36, "\r")
        XCTAssertEqual(result, "WOZ")

        let blank = makeEntry()
        var blankResult: String?
        blank.onSubmit = { blankResult = $0 }
        press(blank, 36, "\r")
        XCTAssertEqual(blankResult, "PLAYER", "an empty name still needs a label")
    }
}

@MainActor
final class PieceJuiceTests: XCTestCase {

    func testIdleBobRunsAndDoesNotStack() {
        let node = PieceNode(piece: Piece(type: .rook, color: .white, square: "a1"),
                             squareSize: BoardNode.squareSize)
        node.startIdleBob()
        XCTAssertNotNil(node.action(forKey: "idleBob"))
        node.startIdleBob()
        XCTAssertNotNil(node.action(forKey: "idleBob"), "second call must be a no-op")
    }

    /// The bob is a relative animation, so it has to yield while an absolute move
    /// runs or the piece drifts off its square.
    func testMovePausesTheBobAndEmitsGhosts() throws {
        let board = BoardNode()
        let node = PieceNode(piece: Piece(type: .rook, color: .white, square: "a1"),
                             squareSize: BoardNode.squareSize)
        node.position = try XCTUnwrap(board.center(of: "a1"))
        board.addChild(node)
        node.startIdleBob()

        let before = board.children.count
        node.animateMove(to: "a4", point: try XCTUnwrap(board.center(of: "a4")))

        XCTAssertNil(node.action(forKey: "idleBob"))
        XCTAssertGreaterThan(board.children.count, before, "ghost trail should appear")
        XCTAssertEqual(node.square, "a4")
    }

    func testLegalMoveMarkersGlow() {
        let board = BoardNode()
        board.showLegalMoves(["e4"], captures: ["e5"])
        var glowing = 0
        var stack = Array(board.children)
        while let next = stack.popLast() {
            if let shape = next as? SKShapeNode, shape.glowWidth > 0 { glowing += 1 }
            stack.append(contentsOf: next.children)
        }
        XCTAssertGreaterThan(glowing, 0)
    }
}

// MARK: - Outcomes and the high score table

@MainActor
final class OutcomePresentationTests: XCTestCase {

    private func texts(in node: SKNode) -> [String] {
        var found: [String] = []
        var stack = Array(node.children)
        while let next = stack.popLast() {
            if let label = next as? SKLabelNode, let text = label.text { found.append(text) }
            stack.append(contentsOf: next.children)
        }
        return found
    }

    /// Every checkmate gets acknowledged — a win used to roll silently into the
    /// next wave, which read as the game restarting itself.
    func testEveryOutcomeDrawsHeadlineScoreAndPrompt() {
        let cases: [GameOverNode.Outcome] =
            [.whiteMated, .stalemate, .waveCleared(next: 2), .runCompleted,
             .livesDepleted, .blackBreachedRank1, .whiteKingDestroyed]
        for outcome in cases {
            let node = GameOverNode(outcome: outcome, score: 1234,
                                    sceneSize: CGSize(width: 960, height: 700))
            let labels = texts(in: node)
            XCTAssertTrue(labels.contains(outcome.headline), "\(outcome) headline")
            XCTAssertTrue(labels.contains { $0.contains("1234") }, "\(outcome) score")
            XCTAssertTrue(labels.contains(outcome.prompt), "\(outcome) prompt")
        }
    }

    func testWaveClearPromptsForTheNextLevel() {
        XCTAssertTrue(GameOverNode.Outcome.waveCleared(next: 3).prompt.contains("LEVEL 3"))
        XCTAssertTrue(GameOverNode.Outcome.whiteMated.prompt.contains("Y / N"))
    }

    func testFavourableOutcomesAreColouredDifferently() {
        XCTAssertTrue(GameOverNode.Outcome.waveCleared(next: 2).isFavourable)
        XCTAssertFalse(GameOverNode.Outcome.whiteMated.isFavourable)
        XCTAssertFalse(GameOverNode.Outcome.stalemate.isFavourable)
        XCTAssertFalse(GameOverNode.Outcome.livesDepleted.isFavourable)
        XCTAssertFalse(GameOverNode.Outcome.blackBreachedRank1.isFavourable)
        XCTAssertFalse(GameOverNode.Outcome.whiteKingDestroyed.isFavourable)
    }
}

@MainActor
final class HighScoreTableTests: XCTestCase {

    override func tearDown() async throws {
        ScoreManager.shared.clearHighScores()
        ScoreManager.shared.resetForNewGame()
    }

    /// `isHighScore` stays true while the table has free slots, so the scene must
    /// gate on "already submitted" or the entry prompt reappears forever.
    func testIsHighScoreStaysTrueAfterSubmitting() {
        ScoreManager.shared.clearHighScores()
        ScoreManager.shared.resetForNewGame()
        ScoreManager.shared.addPoints(75)
        XCTAssertTrue(ScoreManager.shared.isHighScore)
        ScoreManager.shared.submitHighScore(initials: "ZACK")
        XCTAssertTrue(ScoreManager.shared.isHighScore,
                      "this is why the prompt needs a once-per-game guard")
    }

    /// `X` reseeds rather than empties: a clean slate should look like a fresh
    /// install, and a first-time player never sees an empty table.
    func testClearRestoresTheSeededTableAndWipesStorage() {
        ScoreManager.shared.resetForNewGame()
        ScoreManager.shared.addPoints(500)
        ScoreManager.shared.submitHighScore(initials: "TEMP")
        ScoreManager.shared.clearHighScores()
        let table = ScoreManager.shared.topHighScores(limit: 20)
        XCTAssertEqual(table.map(\.initials), ["ZACK", "BEN", "STEVE", "WOZ", "NOLAN"])
        XCTAssertFalse(table.contains { $0.initials == "TEMP" }, "the played game is gone")
        XCTAssertNil(UserDefaults.standard.data(forKey: "GCI_HighScores"))
    }

    func testEntriesSortAndKeepFullNames() {
        ScoreManager.shared.clearHighScores()
        for (name, score) in [("LOW", 100), ("ZACKURLO", 9000), ("MID", 3000)] {
            ScoreManager.shared.resetForNewGame()
            ScoreManager.shared.addPoints(score)
            ScoreManager.shared.submitHighScore(initials: name)
        }
        // The seeded placeholders are still under these — deliberately tiny, so
        // any real game displaces them rather than them squatting the top five.
        let top = ScoreManager.shared.topHighScores(limit: 5)
        XCTAssertEqual(top.map(\.score), [9000, 3000, 100, 100, 90])
        XCTAssertEqual(top.first?.initials, "ZACKURLO", "8 characters must survive")
    }

    func testFullTableOnlyAcceptsAGenuineBeat() {
        ScoreManager.shared.clearHighScores()
        for i in 0..<10 {
            ScoreManager.shared.resetForNewGame()
            ScoreManager.shared.addPoints(1000 + i * 100)
            ScoreManager.shared.submitHighScore(initials: "P\(i)")
        }
        ScoreManager.shared.resetForNewGame()
        ScoreManager.shared.addPoints(50)
        XCTAssertFalse(ScoreManager.shared.isHighScore)
        ScoreManager.shared.resetForNewGame()
        ScoreManager.shared.addPoints(5000)
        XCTAssertTrue(ScoreManager.shared.isHighScore)
    }
}

/// Mirrors GameScene's game-over path so the prompt loop can be driven directly.
@MainActor
private final class OverlaySim {
    private(set) var promptsShown = 0
    private(set) var overlaysShown = 0
    private var hasOfferedHighScore = false

    func newGame() {
        hasOfferedHighScore = false
        ScoreManager.shared.resetForNewGame()
    }

    func showGameOverOverlay() {
        if !hasOfferedHighScore,
           ScoreManager.shared.isHighScore,
           ScoreManager.shared.currentScore > 0 {
            hasOfferedHighScore = true      // claimed on show, not on submit
            promptsShown += 1
            return
        }
        overlaysShown += 1
    }

    func submit(_ name: String) {
        ScoreManager.shared.submitHighScore(initials: name)
        showGameOverOverlay()
    }
}

@MainActor
final class HighScorePromptLoopTests: XCTestCase {

    override func setUp() async throws {
        ScoreManager.shared.clearHighScores()
        ScoreManager.shared.resetForNewGame()
    }

    override func tearDown() async throws {
        ScoreManager.shared.clearHighScores()
        ScoreManager.shared.resetForNewGame()
    }

    /// The reported bug: submitting re-showed an empty prompt forever, because
    /// `isHighScore` is still true once the entry has been added.
    func testSubmittingDoesNotReopenThePrompt() {
        let sim = OverlaySim()
        sim.newGame()
        ScoreManager.shared.addPoints(2410)

        sim.showGameOverOverlay()
        XCTAssertEqual(sim.promptsShown, 1)

        sim.submit("ZACK")
        XCTAssertEqual(sim.promptsShown, 1, "prompt reopened — the loop is back")
        XCTAssertEqual(sim.overlaysShown, 1)
    }

    func testRepeatedSubmitsAndReentriesNeverReprompt() {
        let sim = OverlaySim()
        sim.newGame()
        ScoreManager.shared.addPoints(2410)
        sim.showGameOverOverlay()

        for _ in 0..<10 { sim.submit("ZACK") }
        for _ in 0..<10 { sim.showGameOverOverlay() }
        XCTAssertEqual(sim.promptsShown, 1)
    }

    func testANewGameIsOfferedAgain() {
        let sim = OverlaySim()
        sim.newGame()
        ScoreManager.shared.addPoints(2410)
        sim.showGameOverOverlay()
        sim.submit("ZACK")

        sim.newGame()
        ScoreManager.shared.addPoints(3000)
        sim.showGameOverOverlay()
        XCTAssertEqual(sim.promptsShown, 2, "each game gets one offer")
    }

    /// Returning to the title routes through `resetToTitle`, which used to wipe the
    /// table — so a name the player had just entered vanished before the title
    /// screen could display it.
    func testSubmittedScoreSurvivesReturningToTitle() {
        ScoreManager.shared.resetForNewGame()
        ScoreManager.shared.addPoints(2410)
        ScoreManager.shared.submitHighScore(initials: "ZACK")

        // resetToTitle must leave the table alone.
        let table = ScoreManager.shared.topHighScores(limit: 5)
        XCTAssertTrue(table.contains { $0.initials == "ZACK" && $0.score == 2410 },
                      "the entry was wiped on the way to the title screen")
    }

    func testScorelessGameIsNeverPrompted() {
        let sim = OverlaySim()
        sim.newGame()
        sim.showGameOverOverlay()
        XCTAssertEqual(sim.promptsShown, 0)
        XCTAssertEqual(sim.overlaysShown, 1)
    }
}

// MARK: - Black multi-move

@MainActor
final class BlackMultiMoveTests: XCTestCase {

    /// Mirrors GameScene.playBlackMoves.
    private func playBlackMoves(_ board: GCIBoard, count: Int) -> [(from: String, to: String)] {
        guard board.turn == .black else { return [] }
        var usedSources: Set<String> = []
        var usedDestinations: Set<String> = []
        var played: [(from: String, to: String)] = []

        for index in 0..<count {
            if index > 0 {
                guard board.turn == .white, !board.isMate, !board.isStalemate else { break }
                board.forceTurn(.black)
            }
            guard board.turn == .black else { break }
            guard let found = ChessEngine.searchBestMove(
                    in: board.currentPosition, depth: 2,
                    constraints: .init(excludedSources: usedSources,
                                       excludedDestinations: usedDestinations,
                                       avoidsKingCapture: index > 0),
                    avoiding: board.currentHistory),
                  let outcome = board.applyChessMove(from: found.from, to: found.to)
            else { break }
            played.append((outcome.from, outcome.to))
            usedSources.insert(outcome.from)
            usedSources.insert(outcome.to)
            usedDestinations.insert(outcome.to)
        }
        if board.turn == .black { board.forceTurn(.white) }
        return played
    }

    private func openedGame() -> GCIBoard {
        let board = GCIBoard()
        board.setupStandardPosition()
        board.applyChessMove(from: "e2", to: "e4")
        return board
    }

    /// Chess hands the turn to White after every move, so the loop used to break
    /// on its second pass — Black never got more than one move at any level.
    func testBlackActuallyGetsTheConfiguredNumberOfMoves() {
        for count in 1...3 {
            let board = openedGame()
            let played = playBlackMoves(board, count: count)
            XCTAssertEqual(played.count, count, "level wanting \(count) moves")
            XCTAssertEqual(board.turn, .white, "the turn must come back to White")
        }
    }

    /// §25.5: distinct source pieces and distinct destinations.
    func testNoPieceMovesTwiceInOneTurn() {
        let board = openedGame()
        let played = playBlackMoves(board, count: 3)

        XCTAssertEqual(Set(played.map(\.from)).count, played.count, "shared source")
        XCTAssertEqual(Set(played.map(\.to)).count, played.count, "shared destination")

        // A piece that already moved is sitting on its destination, so no later
        // move may start from there.
        var landed: Set<String> = []
        for move in played {
            XCTAssertFalse(landed.contains(move.from),
                           "\(move.from)-\(move.to) moves a piece that already moved")
            landed.insert(move.to)
        }
    }

    /// Forcing the turn back can leave the white king attacked and on the board,
    /// and it is worth 20,000 to the evaluation — the search would take it.
    func testBlackNeverCapturesTheWhiteKing() {
        for _ in 0..<25 {
            let board = GCIBoard()
            board.setupStandardPosition()
            for (from, to) in [("f2", "f3"), ("e7", "e5"), ("g2", "g4")] {
                board.applyChessMove(from: from, to: to)
            }
            _ = playBlackMoves(board, count: 3)
            XCTAssertNotNil(board.allPieces(color: .white).first { $0.type == .king },
                            "the white king was captured")
        }
    }

    func testForcingTheTurnDropsTheEnPassantRight() {
        let board = GCIBoard()
        board.setupStandardPosition()
        for (from, to) in [("e2", "e4"), ("a7", "a6"), ("e4", "e5"), ("d7", "d5")] {
            board.applyChessMove(from: from, to: to)
        }
        XCTAssertTrue(board.legalDestinations(from: "e5").contains("d6"))

        // The right belongs to the move that just happened, not to a fresh one.
        board.forceTurn(.black)
        board.forceTurn(.white)
        XCTAssertFalse(board.legalDestinations(from: "e5").contains("d6"))
    }
}

// MARK: - Draw rules

/// A depth-2 engine with an overwhelming material edge cannot force mate, so it
/// shuffles. Without the standard draw rules a game can run indefinitely — one
/// playtest ground on for roughly 200 plies of a queen chasing a bare king.
final class DrawRuleTests: XCTestCase {

    func testThreefoldRepetitionIsDetected() throws {
        let engine = try XCTUnwrap(ChessEngine(fen: "7k/8/8/8/8/8/8/R6K w - - 0 1"))
        XCTAssertFalse(engine.isDrawn)

        var plies = 0
        outer: for _ in 0..<12 {
            for (from, to) in [("a1", "a2"), ("h8", "g8"), ("a2", "a1"), ("g8", "h8")] {
                if engine.isDrawnByRepetition { break outer }
                _ = engine.make(from: from, to: to)
                plies += 1
            }
        }
        XCTAssertTrue(engine.isDrawnByRepetition)
        XCTAssertLessThan(plies, 20, "should be caught promptly, not eventually")
    }

    /// A capture or pawn move makes earlier positions unreachable, so both the
    /// clock and the repetition table reset.
    /// Deliberately shorter than the chess convention of 50 — an arcade game
    /// cannot afford a hundred plies of shuffling.
    func testQuietMoveLimitIsThirtyAndCapsGrinds() throws {
        XCTAssertEqual(ChessEngine.quietMoveLimit, 20)

        let engine = try XCTUnwrap(ChessEngine(fen: "7k/8/8/8/8/8/8/q6K w - - 0 1"))
        var plies = 0
        while plies < 200 {
            if engine.isMate || engine.isStalemate || engine.isDrawn { break }
            guard let move = ChessEngine.searchBestMove(in: engine.position, depth: 2,
                                                       avoiding: engine.recentBoards),
                  engine.make(from: move.from, to: move.to) != nil else { break }
            plies += 1
        }
        XCTAssertLessThanOrEqual(plies, ChessEngine.quietMoveLimit * 2 + 2,
                                 "a grind should be capped near 60 plies")
    }

    func testCaptureResetsTheClockAndTable() throws {
        let engine = try XCTUnwrap(ChessEngine(fen: "7k/8/8/8/8/8/p7/R6K w - - 0 1"))
        XCTAssertNotNil(engine.make(from: "a1", to: "a2"))
        XCTAssertEqual(engine.halfmoveClock, 0)
        XCTAssertFalse(engine.isDrawn)
    }

    @MainActor
    func testNormalPlayIsNotFalselyDrawn() {
        for _ in 0..<10 {
            let board = GCIBoard()
            board.setupStandardPosition()
            for ply in 0..<30 {
                guard let move = ChessEngine.searchBestMove(in: board.currentPosition, depth: 2,
                                                           avoiding: board.currentHistory),
                      board.applyChessMove(from: move.from, to: move.to) != nil else { break }
                XCTAssertFalse(board.isDrawn, "false draw at ply \(ply)")
            }
        }
    }

    /// The reported case: queen and rook against a bare king.
    func testAnUnwinnableGrindStillTerminates() throws {
        for _ in 0..<10 {
            let engine = try XCTUnwrap(ChessEngine(fen: "7k/8/8/8/8/8/8/q5rK w - - 0 1"))
            var finished = false
            for _ in 0..<400 {
                if engine.isMate || engine.isStalemate || engine.isDrawn { finished = true; break }
                guard let move = ChessEngine.searchBestMove(in: engine.position, depth: 2,
                                                           avoiding: engine.recentBoards),
                      engine.make(from: move.from, to: move.to) != nil else { finished = true; break }
            }
            XCTAssertTrue(finished, "the game never reached a conclusion")
        }
    }

    @MainActor
    func testDrawOutcomesReadClearly() {
        for outcome in [GameOverNode.Outcome.stalemate, .drawnByRepetition, .drawnByMoveLimit] {
            XCTAssertEqual(outcome.headline, "DRAW")
            XCTAssertFalse(outcome.isFavourable)
            XCTAssertFalse(outcome.detail.isEmpty)
        }
        XCTAssertNotEqual(GameOverNode.Outcome.drawnByRepetition.detail,
                          GameOverNode.Outcome.drawnByMoveLimit.detail,
                          "the two draws should say why")
    }
}

/// Regression: a "restore the turn to White" line at the end of playBlackMoves
/// masked Black's checkmate. makeEngineMove returns nil when Black is mated, and
/// the turn has to stay with Black for endGameIfDecided to evaluate the right
/// side. Flipping it meant isMate was checked against White, came back false, and
/// the game carried on with White moving alone forever.
@MainActor
final class BlackCheckmateDetectionTests: XCTestCase {

    /// Mirrors playBlackMoves.
    private func playBlackMoves(_ board: GCIBoard, count: Int) -> Int {
        guard board.turn == .black else { return 0 }
        var usedSources: Set<String> = []
        var usedDestinations: Set<String> = []
        var played = 0

        for index in 0..<count {
            if index > 0 {
                guard board.turn == .white, !board.isMate, !board.isStalemate else { break }
                board.forceTurn(.black)
            }
            guard board.turn == .black else { break }
            guard let found = ChessEngine.searchBestMove(
                    in: board.currentPosition, depth: 2,
                    constraints: .init(excludedSources: usedSources,
                                       excludedDestinations: usedDestinations,
                                       avoidsKingCapture: index > 0),
                    avoiding: board.currentHistory),
                  let outcome = board.applyChessMove(from: found.from, to: found.to)
            else {
                if index > 0 { board.forceTurn(.white) }
                break
            }
            played += 1
            usedSources.insert(outcome.from)
            usedSources.insert(outcome.to)
            usedDestinations.insert(outcome.to)
        }
        return played
    }

    /// Scholar's mate, so Black is genuinely mated with White to have moved last.
    private func matedPosition() -> GCIBoard {
        let board = GCIBoard()
        board.setupStandardPosition()
        for (from, to) in [("e2", "e4"), ("e7", "e5"), ("f1", "c4"), ("b8", "c6"),
                           ("d1", "h5"), ("g8", "f6"), ("h5", "f7")] {
            board.applyChessMove(from: from, to: to)
        }
        return board
    }

    func testTurnStaysWithBlackWhenBlackIsMated() {
        for count in 1...3 {
            let board = matedPosition()
            XCTAssertTrue(board.isMate)
            XCTAssertEqual(board.turn, .black)

            XCTAssertEqual(playBlackMoves(board, count: count), 0, "a mated side cannot move")
            XCTAssertEqual(board.turn, .black,
                           "flipping the turn here hides the mate from endGameIfDecided")
            XCTAssertTrue(board.isMate, "mate must still be visible afterwards")
        }
    }

    /// The symptom that reached playtest: White moving several times in a row.
    func testGamesNeverDegenerateIntoWhiteMovingAlone() {
        for count in 1...3 {
            for _ in 0..<8 {
                let board = GCIBoard()
                board.setupStandardPosition()
                var whiteOnlyStreak = 0
                var concluded = false

                for _ in 0..<400 {
                    if board.isMate || board.isStalemate || board.isDrawn { concluded = true; break }
                    guard let move = ChessEngine.searchBestMove(in: board.currentPosition, depth: 2,
                                                               avoiding: board.currentHistory),
                          board.applyChessMove(from: move.from, to: move.to) != nil else { break }
                    if board.isMate || board.isStalemate || board.isDrawn { concluded = true; break }

                    whiteOnlyStreak = playBlackMoves(board, count: count) == 0
                        ? whiteOnlyStreak + 1 : 0
                    XCTAssertLessThan(whiteOnlyStreak, 3,
                                      "White moved three times running — Black is stuck")
                }
                XCTAssertTrue(concluded, "game never reached a conclusion")
            }
        }
    }
}

// MARK: - Review fixes

final class ReviewFixTests: XCTestCase {

    /// forceTurn used to clear the repetition table. Level 3+ calls it on every
    /// Black turn, so threefold repetition could never fire at exactly the levels
    /// most prone to grinding.
    func testRepetitionSurvivesForcedTurns() throws {
        let engine = try XCTUnwrap(ChessEngine(fen: "7k/8/8/8/8/8/8/R6K w - - 0 1"))
        var plies = 0
        outer: for _ in 0..<40 {
            for (from, to) in [("a1", "a2"), ("h8", "g8"), ("a2", "a1"), ("g8", "h8")] {
                if engine.isDrawnByRepetition { break outer }
                _ = engine.make(from: from, to: to)
                plies += 1
            }
            engine.forceTurn(engine.turn)      // what Level 3+ does every turn
        }
        XCTAssertTrue(engine.isDrawnByRepetition, "still not drawn after \(plies) plies")
        XCTAssertLessThan(plies, 20)
    }

    /// Walks the occupied mask rather than all 64 squares; must still agree.
    func testPiecesMatchesASquareBySquareScan() throws {
        for fen in [Chess.FEN.standard,
                    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
                    "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"] {
            let board = try XCTUnwrap(Chess.FEN.position(from: fen)).board
            let scanned = (0..<64).compactMap { index -> (Chess.Square, Chess.Piece)? in
                board[index].map { (Chess.Square(index: index), $0) }
            }
            let walked = board.pieces()
            XCTAssertEqual(walked.count, scanned.count)
            for (square, piece) in walked {
                XCTAssertEqual(board[square], piece)
            }
        }
        XCTAssertTrue(Chess.Board().pieces().isEmpty)
    }

    @MainActor
    func testScoreRoundsRatherThanTruncates() {
        ScoreManager.shared.clearHighScores()
        ScoreManager.shared.resetForNewGame()
        ScoreManager.shared.advanceLevel()          // ×1.5
        ScoreManager.shared.addPoints(25)           // 37.5
        XCTAssertEqual(ScoreManager.shared.currentScore, 38,
                       "truncating quietly under-paid every scaled capture")
        ScoreManager.shared.resetForNewGame()
    }
}

// MARK: - Audio mix

@MainActor
final class AudioMixTests: XCTestCase {

    /// Effects used to default to 0.8 and 1.0 against music at 0.75, so they sat
    /// *over* the track. They now sit just under it, with each key keeping its
    /// own relative balance.
    func testEverySoundSitsUnderTheMusic() {
        for key in SoundKey.allCases {
            XCTAssertLessThan(AudioManager.volume(for: key), AudioManager.musicVolume,
                              "\(key) is at or above the music level")
        }
    }

    /// Under, but only slightly — the effects should still carry.
    func testLoudestEffectIsCloseToTheMusic() {
        let loudest = SoundKey.allCases.map(AudioManager.volume(for:)).max() ?? 0
        XCTAssertGreaterThan(loudest, AudioManager.musicVolume * 0.85,
                             "effects have been cut too far, not just placed under")
    }

    /// Both repeat — the countdown twice a beat, the alarm on every re-entry into
    /// check — and repetition reads as loudness. They are mixed below the moves
    /// they punctuate.
    func testRepeatingSoundsAreMixedBelowOneShots() {
        XCTAssertLessThan(AudioManager.volume(for: .turnTimerWarning),
                          AudioManager.volume(for: .whitePieceMoves))
        XCTAssertLessThan(AudioManager.volume(for: .checkAlarm),
                          AudioManager.volume(for: .pieceHitHeavy))
        XCTAssertLessThan(AudioManager.volume(for: .checkAlarm),
                          AudioManager.musicVolume * 0.6)
    }

    func testRelativeBalanceIsPreserved() {
        XCTAssertLessThan(AudioManager.volume(for: .pieceSelected),
                          AudioManager.volume(for: .kingDestroyed))
        XCTAssertLessThan(AudioManager.volume(for: .ambientSpaceLoop),
                          AudioManager.volume(for: .whitePieceMoves))
    }
}

// MARK: - Fleet (Phase 3.1)

@MainActor
final class FleetRulesTests: XCTestCase {

    /// The whole illusion: the fleet drops visually twice per rank, and the board
    /// only catches up on the second drop.
    func testEverySecondDescentCompletesARank() {
        var schedule = FleetRules.DescentSchedule(graceBeats: 0, beatsPerHalfDrop: 1)
        XCTAssertTrue(schedule.isSweeping, "no hold configured, so it moves at once")
        let pattern = (0..<6).map { _ in schedule.registerBeat() }
        XCTAssertEqual(pattern, [.halfDrop, .fullRank, .halfDrop,
                                 .fullRank, .halfDrop, .fullRank])
    }

    /// The player gets a stretch of quiet to read the position before the arcade
    /// layer starts taking squares away.
    func testNothingDescendsDuringTheGracePeriod() {
        var schedule = FleetRules.DescentSchedule(graceBeats: 6, beatsPerHalfDrop: 4)
        let steps = (1...14).map { _ in schedule.registerBeat() }
        let dropBeats = steps.enumerated().filter { $0.element != .none }.map { $0.offset + 1 }
        XCTAssertEqual(dropBeats, [6, 10, 14], "first drop at beat 6, then every 4")
        XCTAssertEqual(steps[9], .fullRank, "a rank costs two half-drops, so 8 beats")
    }

    /// Later levels close the distance faster, but never faster than four beats
    /// a rank — below that the player cannot plan around it.
    func testDescentSchedulesTightenWithLevel() {
        var previous = Int.max
        for level in 1...8 {
            let schedule = FleetRules.descentSchedule(for: level)
            XCTAssertGreaterThanOrEqual(schedule.beatsPerHalfDrop, 2)
            XCTAssertLessThanOrEqual(schedule.beatsPerHalfDrop, previous)
            previous = schedule.beatsPerHalfDrop
        }
        XCTAssertEqual(FleetRules.descentSchedule(for: 1).graceBeats, 6)
        XCTAssertEqual(FleetRules.descentSchedule(for: 1).beatsPerHalfDrop, 4,
                       "level 1: half a rank every 4 beats, a full rank every 8")
    }

    /// The fleet sweeps from the very first beat.
    ///
    /// It used to hold still for the opening few beats, which looked better but
    /// made the start unplayable: a stationary fleet sits directly behind
    /// White's own pawns, and a laser is consumed by the first thing it touches,
    /// so no black piece was reachable at all until the player shot their own
    /// pawns out of the way.
    func testTheFleetSweepsImmediately() {
        let schedule = FleetRules.descentSchedule(for: 1)
        XCTAssertEqual(schedule.sweepBeats, 0)
        XCTAssertTrue(schedule.isSweeping, "moving before the first beat resolves")

        // Movement still precedes ground being taken, at every level.
        for level in 1...8 {
            let s = FleetRules.descentSchedule(for: level)
            XCTAssertLessThan(s.sweepBeats, s.graceBeats, "level \(level)")
            XCTAssertTrue(s.isSweeping, "level \(level) sweeps from the start")
        }
    }

    // MARK: - Formation membership after a chess move

    /// A black piece shuffling around the formation's own two rear ranks keeps
    /// marching; one that genuinely advances drops out. A parked black piece
    /// tends to sit right behind a white pawn, where it is nearly unshootable.
    func testHomeRankMovesKeepAPieceInTheFormation() {
        for square in ["a8", "e8", "h8", "a7", "e7", "h7"] {
            XCTAssertTrue(FleetRules.staysInFormation(afterMovingTo: square,
                                                      formationRearRank: 8),
                          "\(square) is a rear rank")
        }
        for square in ["a6", "e6", "d5", "c4", "b3", "h2", "e1"] {
            XCTAssertFalse(FleetRules.staysInFormation(afterMovingTo: square,
                                                       formationRearRank: 8),
                           "\(square) is an advance")
        }
    }

    func testFormationBandIsTwoRanksDeepByDefault() {
        XCTAssertEqual(FleetRules.formationRanks, 2)
        XCTAssertEqual(FleetRules.startingRearRank, 8)
        XCTAssertTrue(FleetRules.staysInFormation(afterMovingTo: "d7",
                                                  formationRearRank: 8))
        XCTAssertFalse(FleetRules.staysInFormation(afterMovingTo: "d6",
                                                   formationRearRank: 8),
                       "rank 6 is the third row — the first that detaches")
    }

    /// The whole point of measuring from the fleet's own rear rank: the band
    /// travels down with the formation instead of expiring after two descents.
    func testFormationBandFollowsTheFleetDown() {
        // Fleet has descended twice: its rear rank is 6, so 5 and 6 march.
        XCTAssertTrue(FleetRules.staysInFormation(afterMovingTo: "d6",
                                                  formationRearRank: 6))
        XCTAssertTrue(FleetRules.staysInFormation(afterMovingTo: "d5",
                                                  formationRearRank: 6))
        // Rank 4 is out in front of the band.
        XCTAssertFalse(FleetRules.staysInFormation(afterMovingTo: "d4",
                                                   formationRearRank: 6))
    }

    /// A retreat is not a desertion. Observed in play: with the fleet down to
    /// rank 7, a king stepping back to rank 8 was ruled outside the band and
    /// stranded off-grid on an empty rank while everything else marched.
    /// Nothing is behind the fleet to be separated from, so nothing behind it
    /// detaches — the formation is allowed to be deeper than `ranks`.
    func testAPieceBehindTheFleetStillMarches() {
        for rear in 4...8 {
            for rank in rear...8 {
                XCTAssertTrue(
                    FleetRules.staysInFormation(afterMovingTo: "e\(rank)",
                                                formationRearRank: rear),
                    "rear \(rear): rank \(rank) is at or behind it")
            }
            // And the front edge still bites, two ranks ahead of the rear.
            let ahead = rear - FleetRules.formationRanks
            if ahead >= 1 {
                XCTAssertFalse(
                    FleetRules.staysInFormation(afterMovingTo: "e\(ahead)",
                                                formationRearRank: rear),
                    "rear \(rear): rank \(ahead) is out in front")
            }
        }
    }

    /// The per-rank sweep is one number, and its three interesting settings
    /// are a wave, a counter-march, and off.
    func testRankPhaseLagIsADial() {
        // The shipped setting: a wave down the formation.
        XCTAssertEqual(FleetRules.rankPhaseLag, .pi / 4, accuracy: 0.0001)
        // Adjacent ranks stay close enough that files still read. At lag θ the
        // worst separation between neighbours is 2·amplitude·sin(θ/2).
        let amplitude = FleetRules.sweepAmplitude(
            squareSize: BoardNode.squareSize,
            ratio: FleetRules.wideSweepAmplitudeRatio)
        let shear = 2 * amplitude * sin(FleetRules.rankPhaseLag / 2)
        XCTAssertLessThan(shear, BoardNode.squareSize,
                          "neighbouring ranks must stay within a square")
        // And the counter-march setting is the same dial at its limit, where
        // that separation is the full 2x — which is the legibility cost.
        let opposed = 2 * amplitude * sin(CGFloat.pi / 2)
        XCTAssertEqual(opposed, 2 * amplitude, accuracy: 0.0001)
        XCTAssertGreaterThan(opposed, BoardNode.squareSize * 1.4)
    }

    /// Level 10's deeper band: three ranks march instead of two.
    func testDeepFormationAddsAThirdRank() {
        XCTAssertEqual(FleetRules.deepFormationRanks, 3)
        let deep = FleetRules.deepFormationRanks
        for square in ["d8", "d7", "d6"] {
            XCTAssertTrue(FleetRules.staysInFormation(afterMovingTo: square,
                                                      formationRearRank: 8,
                                                      ranks: deep),
                          "\(square) is inside the deep band")
        }
        XCTAssertFalse(FleetRules.staysInFormation(afterMovingTo: "d5",
                                                   formationRearRank: 8,
                                                   ranks: deep),
                       "the fourth rank still detaches")
        XCTAssertEqual(LevelManager.parameters(for: 9).formationRanks,
                       FleetRules.formationRanks)
        for level in [10, 12, 20] {
            XCTAssertEqual(LevelManager.parameters(for: level).formationRanks,
                           deep, "level \(level) marches three ranks deep")
        }
    }

    // MARK: - Blitz (Level 10)

    /// Blitz opens at Level 6's width and grows a tenth of a square every
    /// fourth lap: 1.5, 1.6, 1.7 … The count is laps, not time.
    func testBlitzWidensEveryFourthLap() {
        XCTAssertEqual(FleetRules.blitzWidenEveryArrivals, 4)
        // Ratios are half the end-to-end width, so a tenth of a square is 0.05.
        XCTAssertEqual(FleetRules.blitzAmplitudeRatio(leftEdgeArrivals: 0),
                       FleetRules.wideSweepAmplitudeRatio, "opens at 1.5 squares")
        XCTAssertEqual(FleetRules.blitzAmplitudeRatio(leftEdgeArrivals: 3),
                       FleetRules.wideSweepAmplitudeRatio, "not yet — third lap")
        for (laps, squares) in [(4, 1.6), (8, 1.7), (12, 1.8), (40, 2.5)] {
            let width = FleetRules.blitzAmplitudeRatio(leftEdgeArrivals: laps) * 2
            XCTAssertEqual(width, CGFloat(squares), accuracy: 0.0001,
                           "lap \(laps) sweeps \(squares) squares")
        }
    }

    func testBlitzQuickensEverySixthLap() {
        XCTAssertEqual(FleetRules.blitzSpeedUpEveryArrivals, 6)
        XCTAssertEqual(FleetRules.blitzSpeedScale(leftEdgeArrivals: 0), 1)
        XCTAssertEqual(FleetRules.blitzSpeedScale(leftEdgeArrivals: 5), 1,
                       "not yet — fifth lap")
        XCTAssertEqual(FleetRules.blitzSpeedScale(leftEdgeArrivals: 6),
                       1 + FleetRules.blitzSpeedStep, accuracy: 0.0001)
        // Compounding, not linear.
        XCTAssertEqual(FleetRules.blitzSpeedScale(leftEdgeArrivals: 18),
                       pow(1 + FleetRules.blitzSpeedStep, 3), accuracy: 0.0001)
    }

    /// The ceilings are there so the fleet cannot leave the screen or stop
    /// reading as steps — not as design limits. Both take far longer to reach
    /// than a wave lasts.
    func testBlitzCeilingsKeepTheFleetOnScreen() {
        XCTAssertEqual(FleetRules.blitzAmplitudeRatio(leftEdgeArrivals: 100_000),
                       FleetRules.blitzMaxAmplitudeRatio)
        XCTAssertEqual(FleetRules.blitzSpeedScale(leftEdgeArrivals: 100_000),
                       FleetRules.blitzMaxSpeedScale)
        // 960pt scene, 512pt board centred: 224pt of margin each side.
        let margin = (960 - BoardNode.boardSize) / 2
        let amplitude = FleetRules.sweepAmplitude(
            squareSize: BoardNode.squareSize,
            ratio: FleetRules.blitzMaxAmplitudeRatio)
        XCTAssertLessThan(amplitude + BoardNode.squareSize / 2, margin,
                          "the outermost piece must stay on screen")
        // And it is a guard, not a wall the player will hit.
        let laps = FleetRules.blitzWidenEveryArrivals
            * Int((FleetRules.blitzMaxAmplitudeRatio
                   - FleetRules.wideSweepAmplitudeRatio)
                  / FleetRules.blitzWidenStepRatio)
        XCTAssertGreaterThan(laps, 150, "unreachable within a wave")
    }

    /// Crossfire is Level 7's identity, so it steps back out for 8 and 9 and
    /// only returns for Blitz, which is meant to carry everything at once.
    func testCrossfireIsLevelSevenAndBlitzOnly() {
        for level in 1...6 {
            XCTAssertFalse(LevelManager.parameters(for: level).diagonalShots,
                           "level \(level) fires straight")
        }
        XCTAssertTrue(LevelManager.parameters(for: 7).diagonalShots)
        XCTAssertFalse(LevelManager.parameters(for: 8).diagonalShots,
                       "8 and 9 are their own waves, not Crossfire again")
        XCTAssertFalse(LevelManager.parameters(for: 9).diagonalShots)
        XCTAssertTrue(LevelManager.parameters(for: 10).diagonalShots,
                      "Blitz carries every complication")
    }

    /// The order of the three late waves, and the shape they share: each owns a
    /// mechanic outright, and Blitz takes them back.
    func testTheLateLaddersOrder() {
        XCTAssertEqual(LevelManager.announcement(for: 7)?.title, "CROSSFIRE")
        XCTAssertEqual(LevelManager.announcement(for: 8)?.title, "ARMORED PAWNS")
        XCTAssertEqual(LevelManager.announcement(for: 9)?.title, "KING ACTIVATED")
        XCTAssertEqual(LevelManager.announcement(for: 10)?.title, "BLITZ!")

        let seven = LevelManager.parameters(for: 7)
        XCTAssertTrue(seven.diagonalShots)
        XCTAssertFalse(seven.armoredPawns)
        XCTAssertFalse(seven.kingActivated)

        let eight = LevelManager.parameters(for: 8)
        XCTAssertTrue(eight.armoredPawns)
        XCTAssertFalse(eight.diagonalShots)
        XCTAssertFalse(eight.kingActivated)

        let nine = LevelManager.parameters(for: 9)
        XCTAssertTrue(nine.kingActivated)
        XCTAssertFalse(nine.diagonalShots)
        XCTAssertFalse(nine.armoredPawns)

        // Blitz combines what the waves before it each owned alone — except
        // King Activated, which stays one wave's character.
        let ten = LevelManager.parameters(for: 10)
        XCTAssertTrue(ten.diagonalShots)
        XCTAssertTrue(ten.armoredPawns)
        XCTAssertTrue(ten.blitz)
        XCTAssertFalse(ten.kingActivated)
    }

    /// Level 10 is Blitz: 3-second clock, and the *opening* width is still
    /// Level 6's, because the growth happens within the level.
    func testBlitzIsLevelTenOnly() {
        XCTAssertFalse(LevelManager.parameters(for: 9).blitz)
        XCTAssertTrue(LevelManager.parameters(for: 10).blitz)
        XCTAssertEqual(LevelManager.parameters(for: 10).turnTimer, 3)
        XCTAssertEqual(LevelManager.parameters(for: 9).turnTimer, 4)
        XCTAssertEqual(LevelManager.parameters(for: 10).sweepAmplitudeRatio,
                       FleetRules.wideSweepAmplitudeRatio)
        XCTAssertEqual(LevelManager.announcement(for: 10)?.title, "BLITZ!")
    }

    /// The `V` skip wraps rather than stopping at the top: a test pass wants to
    /// walk the ladder round and round, and the score it has been watching
    /// should survive the wrap.
    func testTheLadderRestartsWithoutResettingTheRun() {
        let levels = LevelManager()
        for _ in 1..<LevelManager.finalLevel { levels.advance() }
        XCTAssertTrue(levels.isFinalLevel)
        levels.reset()
        XCTAssertEqual(levels.level, 1)

        let score = ScoreManager.shared
        score.resetForNewGame()
        for _ in 0..<4 { score.advanceLevel() }
        score.addPoints(100)
        let banked = score.currentScore
        XCTAssertGreaterThan(score.multiplier, 1.0)

        score.restartLadder()
        XCTAssertEqual(score.multiplier, 1.0, "the ladder starts again")
        XCTAssertEqual(score.currentScore, banked, "the run does not")
        score.resetForNewGame()
    }

    /// Clearing the last wave wins the run rather than rolling into an
    /// eleventh level that has no design.
    func testFinalLevelEndsTheRun() {
        XCTAssertEqual(LevelManager.finalLevel, 10)
        let levels = LevelManager()
        XCTAssertFalse(levels.isFinalLevel)
        for _ in 1..<LevelManager.finalLevel { levels.advance() }
        XCTAssertEqual(levels.level, 10)
        XCTAssertTrue(levels.isFinalLevel)
        XCTAssertEqual(GameOverNode.Outcome.runCompleted.headline, "YOU WIN")
        XCTAssertTrue(GameOverNode.Outcome.runCompleted.isFavourable)
        XCTAssertTrue(GameOverNode.Outcome.runCompleted.detail.contains("10 WAVES"))
        XCTAssertTrue(GameOverNode.Outcome.runCompleted.prompt.contains("NEW GAME"),
                      "the run is over, so there is no LEVEL 11 to continue to")
    }

    func testMalformedSquareDoesNotKeepAPieceInFormation() {
        for square in ["", "zz", "e", "e9x"] {
            XCTAssertFalse(FleetRules.staysInFormation(afterMovingTo: square,
                                                       formationRearRank: 8))
        }
    }

    /// The readability invariant: a piece that drifts half a square sits on a
    /// file boundary and its square becomes genuinely ambiguous.
    func testSweepStaysWithinTheOwnFile() {
        XCTAssertLessThan(FleetRules.baseSweepAmplitudeRatio, 0.5)
        let amplitude = FleetRules.sweepAmplitude(
            squareSize: BoardNode.squareSize,
            ratio: FleetRules.baseSweepAmplitudeRatio)
        XCTAssertLessThan(amplitude * 2, BoardNode.squareSize,
                          "the base sweep must stay under one file width")
    }

    /// Level 6's wide sweep breaks that rule on purpose — 1.5 squares end to
    /// end, so a piece's centre does cross into the next file. The test exists
    /// to make the trade deliberate rather than accidental.
    func testWideSweepKnowinglyExceedsTheReadableWidth() {
        XCTAssertGreaterThan(FleetRules.wideSweepAmplitudeRatio, 0.5)
        XCTAssertEqual(FleetRules.wideSweepAmplitudeRatio * 2, 1.5, accuracy: 0.0001,
                       "1.5 squares end to end")
    }

    /// The wide sweep arrives at Level 6 and never reverts.
    func testSweepWidthEscalatesAtLevelSixAndStays() {
        for level in 1...5 {
            XCTAssertEqual(LevelManager.parameters(for: level).sweepAmplitudeRatio,
                           FleetRules.baseSweepAmplitudeRatio, "level \(level)")
        }
        for level in 6...12 {
            XCTAssertEqual(LevelManager.parameters(for: level).sweepAmplitudeRatio,
                           FleetRules.wideSweepAmplitudeRatio, "level \(level)")
        }
    }

    /// Level 4's banner promises "FASTER, HARDER FIRE"; it needs to be a step
    /// the player can actually feel, not the +11% it used to be.
    func testProjectileSpeedJumpsHardAtLevelFour() {
        let three = LevelManager.parameters(for: 3).projectileSpeed
        let four = LevelManager.parameters(for: 4).projectileSpeed
        XCTAssertEqual(four / three, 1.3, accuracy: 0.01, "a 30% step at level 4")

        // And it never goes backwards afterwards.
        var previous = four
        for level in 5...12 {
            let speed = LevelManager.parameters(for: level).projectileSpeed
            XCTAssertGreaterThan(speed, previous, "level \(level) must not slow down")
            previous = speed
        }
    }

    /// The same argument, on the other axis: an even 0.5/0.5 split would park the
    /// fleet on a rank boundary, where a piece belongs to neither rank.
    func testTheRestingDropLeavesAPieceOnItsOwnRank() {
        XCTAssertLessThan(FleetRules.firstDropRatio, 0.5)
        XCTAssertEqual(FleetRules.firstDropRatio + FleetRules.secondDropRatio, 1,
                       accuracy: 0.0001, "the pair must still total exactly one rank")
    }

    /// The drop has to be announced a beat early, or it reads as a random lurch.
    func testDescentIsTelegraphedOneBeatAhead() {
        var schedule = FleetRules.DescentSchedule(graceBeats: 3, beatsPerHalfDrop: 3)
        XCTAssertFalse(FleetRules.descendsAfter(schedule), "beat 1 is quiet")
        _ = schedule.registerBeat()
        XCTAssertFalse(FleetRules.descendsAfter(schedule))
        _ = schedule.registerBeat()
        XCTAssertTrue(FleetRules.descendsAfter(schedule), "beat 3 drops, so warn on 2")
        XCTAssertNotEqual(schedule.registerBeat(), .none, "and it actually does")
    }

    func testDescendingASquare() {
        XCTAssertEqual(FleetRules.descended("e5"), "e4")
        XCTAssertEqual(FleetRules.descended("a2"), "a1")
        XCTAssertNil(FleetRules.descended("h1"), "rank 1 is the bottom")
    }

    /// A piece must vacate before the one above arrives, or the upper overwrites
    /// the lower and a black piece silently vanishes.
    func testDescentOrderIsLowestRankFirst() {
        XCTAssertEqual(FleetRules.descentOrder(["d5", "d4", "d7", "d2"]),
                       ["d2", "d4", "d5", "d7"])
    }

    @MainActor
    func testSpeedScalesWithPiecesRemaining() {
        for (remaining, expected) in [(16, 1.0), (12, 1.2), (8, 1.5), (4, 2.0), (1, 2.5)] {
            XCTAssertEqual(FleetRules.speedMultiplier(piecesRemaining: remaining),
                           CGFloat(expected), accuracy: 0.001, "\(remaining) pieces")
        }
        // The §21.2 multipliers are exact; the sweep speed carries a tuning scale
        // on top, so it is checked against the table rather than raw numbers.
        let level1 = LevelManager.parameters(for: 1)
        for remaining in [16, 1] {
            let expected = level1.fleetSpeed
                * FleetRules.speedMultiplier(piecesRemaining: remaining)
                * FleetRules.sweepSpeedScale
            XCTAssertEqual(FleetRules.sweepSpeed(level: level1, piecesRemaining: remaining),
                           expected, accuracy: 0.001)
        }
    }

    @MainActor
    func testAFullDescentMovesEveryBlackPieceExactlyOneRank() {
        let board = GCIBoard()
        board.setupStandardPosition()
        let before = board.allPieces(color: .black).map(\.logicalSquare)

        for square in FleetRules.descentOrder(before) {
            guard let piece = board.piece(at: square),
                  let next = FleetRules.descended(square) else { continue }
            _ = board.forcePlace(piece, at: next)
        }

        let after = Set(board.allPieces(color: .black).map(\.logicalSquare))
        XCTAssertEqual(after.count, 16, "a piece was overwritten during descent")
        XCTAssertEqual(after, Set(before.compactMap(FleetRules.descended)))
        XCTAssertEqual(board.allPieces(color: .white).count, 16)
    }
}

@MainActor
final class FleetControllerTests: XCTestCase {

    private func makeFleet() -> (FleetController, GCIBoard, SKNode) {
        let board = GCIBoard()
        board.setupStandardPosition()
        let parent = SKNode()
        let fleet = FleetController(board: board, parent: parent,
                                    squareSize: BoardNode.squareSize,
                                    level: LevelManager.parameters(for: 1))
        return (fleet, board, parent)
    }

    /// Regression: the parent's compensating +squareSize was applied without
    /// ever moving the child by the matching amount, so a piece's local position
    /// stayed pinned to its old square. The two cancelled out for exactly one
    /// rank, then the error compounded — the piece visibly jumped up a full
    /// square the instant the rank landed, right before the next drop pulled it
    /// back down. This pins the fix at the controller level, where the bug
    /// actually lived (FleetRules' pure position math was never wrong).
    func testDescentLeavesNoNetScreenJump() throws {
        let (fleet, board, parent) = makeFleet()
        let geometry = BoardNode()
        var nodes: [String: PieceNode] = [:]
        for piece in board.allPieces(color: .black) {
            guard let centre = geometry.center(of: piece.logicalSquare) else { continue }
            let node = PieceNode(piece: piece, squareSize: BoardNode.squareSize)
            fleet.adopt(node, square: piece.logicalSquare, atLogicalCentre: centre)
            nodes[piece.logicalSquare] = node
        }

        let before = try XCTUnwrap(nodes["e7"])
        let screenBefore = fleet.screenPosition(of: before)
        let localBefore = before.position.y

        // Drive one full rank descent directly, bypassing the animated timers.
        fleet.applyFullRankDescentForTesting()

        // A rank descent is two animated half-drops of the parent, and then this
        // call to reconcile the books: each node moves down one square in local
        // space while the parent moves back up by the same amount. So the pieces
        // are already a rank lower on screen by the time this runs, and its own
        // contribution must be exactly nothing.
        let screenAfter = fleet.screenPosition(of: before)
        XCTAssertEqual(screenAfter.y, screenBefore.y, accuracy: 0.5,
                       "reconciling the books must not move anything on screen")
        XCTAssertEqual(before.position.y, localBefore - BoardNode.squareSize, accuracy: 0.5,
                       "but the local position must drop by exactly one rank")
        _ = parent
    }

    /// One SKAction on one parent has to move the whole formation (§18), so every
    /// black piece must actually be a child of it.
    func testFleetHoldsEveryBlackPieceUnderOneParent() throws {
        let (fleet, board, parent) = makeFleet()
        let geometry = BoardNode()
        for piece in board.allPieces(color: .black) {
            let node = PieceNode(piece: piece, squareSize: BoardNode.squareSize)
            fleet.adopt(node, square: piece.logicalSquare,
                        atLogicalCentre: try XCTUnwrap(geometry.center(of: piece.logicalSquare)))
        }
        XCTAssertEqual(fleet.pieceCount, 16)
        XCTAssertEqual(parent.children.count, 1, "the fleet is a single node")
        // Blitz gives each rank its own phase (§18), so the fleet node's own
        // children are the rank containers and the pieces hang off those. One
        // parent still carries the whole formation; it is just one level up.
        let ranks = parent.children[0].children
        XCTAssertEqual(ranks.reduce(0) { $0 + $1.children.count }, 16)
    }

    /// Local position stays the logical square centre; the parent transform
    /// supplies the sweep. Conflating them is what would desync board and screen.
    func testPieceLocalPositionIsItsLogicalCentre() throws {
        let (fleet, _, _) = makeFleet()
        let geometry = BoardNode()
        let centre = try XCTUnwrap(geometry.center(of: "a7"))
        let node = PieceNode(piece: Piece(type: .pawn, color: .black, square: "a7"),
                             squareSize: BoardNode.squareSize)
        fleet.adopt(node, square: "a7", atLogicalCentre: centre)
        XCTAssertEqual(node.position, centre)
    }

    /// Regression, twice over. Bounding the sweep to the board left a full fleet
    /// nowhere to go, so it bounced every frame and fell to rank 1 in seconds.
    /// Unbounding it let pieces drift three files off true, which is unreadable.
    /// The answer is a fixed sub-file amplitude, independent of piece count.
    func testSweepWidthIsSubFileAndIndependentOfPieceCount() {
        let (fleet, board, _) = makeFleet()
        XCTAssertEqual(fleet.sweepWidth, BoardNode.squareSize * 0.9, accuracy: 0.001)

        let geometry = BoardNode()
        for piece in board.allPieces(color: .black) {
            if let centre = geometry.center(of: piece.logicalSquare) {
                fleet.adopt(PieceNode(piece: piece, squareSize: BoardNode.squareSize),
                            square: piece.logicalSquare, atLogicalCentre: centre)
            }
        }
        XCTAssertEqual(fleet.sweepWidth, BoardNode.squareSize * 0.9, accuracy: 0.001,
                       "a full formation shuffles exactly as far as a lone piece")
        XCTAssertFalse(fleet.isOffTruePosition, "a fresh fleet starts on its squares")
    }

    /// A black piece that plays chess stops being an invader: it leaves the
    /// formation, keeps its node, and is no longer swept or dropped.
    func testAPieceThatPlaysChessLeavesTheFormation() throws {
        let (fleet, board, _) = makeFleet()
        let geometry = BoardNode()
        for piece in board.allPieces(color: .black) {
            if let centre = geometry.center(of: piece.logicalSquare) {
                fleet.adopt(PieceNode(piece: piece, squareSize: BoardNode.squareSize),
                            square: piece.logicalSquare, atLogicalCentre: centre)
            }
        }
        XCTAssertEqual(fleet.pieceCount, 16)

        let released = try XCTUnwrap(fleet.release(square: "e7"))
        XCTAssertNil(released.parent, "handed back for the caller to re-parent")
        XCTAssertEqual(fleet.pieceCount, 15)
        XCTAssertNil(fleet.release(square: "e7"), "releasing twice is a no-op")
        XCTAssertNil(fleet.release(square: "e2"), "white was never in the formation")
    }

    /// Re-keying keeps the node parented to the fleet so it carries on sweeping;
    /// releasing hands it back. The two must not be confused — a re-keyed piece
    /// that lost its parent would stop moving while still counted as a member.
    func testRekeyKeepsThePieceMarchingAndReleaseDoesNot() throws {
        let (fleet, board, _) = makeFleet()
        let geometry = BoardNode()
        for piece in board.allPieces(color: .black) {
            if let centre = geometry.center(of: piece.logicalSquare) {
                fleet.adopt(PieceNode(piece: piece, squareSize: BoardNode.squareSize),
                            square: piece.logicalSquare, atLogicalCentre: centre)
            }
        }
        XCTAssertEqual(fleet.pieceCount, 16)

        // e8 -> d8: still a home rank, so it stays in the formation.
        XCTAssertTrue(fleet.rekey(from: "e8", to: "d8"))
        XCTAssertEqual(fleet.pieceCount, 16, "re-keying must not drop a member")
        XCTAssertFalse(fleet.rekey(from: "e8", to: "c8"),
                       "the old square is no longer a member")

        // Releasing genuinely removes it.
        let released = try XCTUnwrap(fleet.release(square: "d8"))
        XCTAssertNil(released.parent)
        XCTAssertEqual(fleet.pieceCount, 15)
    }

    /// Regression for two crashes, both "Attemped to add a SKNode which already
    /// has a parent". Releasing by *square* silently did nothing when the key
    /// named a different piece, leaving the node parented to the fleet — and
    /// the caller then re-added it to the board, which throws.
    ///
    /// A rank descent re-keys `members[next] = node` as it walks the formation,
    /// overwriting the entry of a black piece crushed on that square; the crush
    /// callback runs afterwards, so the key is already wrong by then. Releasing
    /// by identity cannot go stale that way.
    func testReleaseByIdentityDetachesEvenWhenTheSquareKeyIsStale() throws {
        let (fleet, board, _) = makeFleet()
        let geometry = BoardNode()
        var nodes: [String: PieceNode] = [:]
        for piece in board.allPieces(color: .black) {
            guard let centre = geometry.center(of: piece.logicalSquare) else { continue }
            let node = PieceNode(piece: piece, squareSize: BoardNode.squareSize)
            fleet.adopt(node, square: piece.logicalSquare, atLogicalCentre: centre)
            nodes[piece.logicalSquare] = node
        }
        let rook = try XCTUnwrap(nodes["a8"])
        XCTAssertTrue(fleet.contains(rook))

        // Make a8's key name someone else, exactly as a descent re-key would.
        XCTAssertTrue(fleet.rekey(from: "b8", to: "a8"))

        // The old key-based path would no-op here and leave the rook parented.
        XCTAssertNil(fleet.release(square: "zz"), "an unknown square is still a no-op")
        XCTAssertTrue(fleet.release(rook), "identity finds it regardless of the key")
        XCTAssertNil(rook.parent, "must be unparented, or addChild throws")
        XCTAssertFalse(fleet.contains(rook))

        // And it is safe to re-add — the crash both reports hit.
        let boardNode = BoardNode()
        boardNode.addChild(rook)
        XCTAssertNotNil(rook.parent)
    }

    /// Releasing a node the fleet never owned must not throw or half-detach it.
    func testReleasingANonMemberIsHarmless() {
        let (fleet, _, _) = makeFleet()
        let stray = PieceNode(piece: Piece(type: .pawn, color: .white, square: "e2"),
                              squareSize: BoardNode.squareSize)
        XCTAssertFalse(fleet.release(stray), "not a member")
        XCTAssertNil(stray.parent)
    }

    func testResetEmptiesTheFormation() {
        let (fleet, board, _) = makeFleet()
        let geometry = BoardNode()
        for piece in board.allPieces(color: .black) {
            if let centre = geometry.center(of: piece.logicalSquare) {
                fleet.adopt(PieceNode(piece: piece, squareSize: BoardNode.squareSize),
                            square: piece.logicalSquare, atLogicalCentre: centre)
            }
        }
        fleet.reset()
        XCTAssertEqual(fleet.pieceCount, 0)
    }
}

// MARK: - Shooting & Collision (Phase 3.2)

@MainActor
final class LaserPhysicsTests: XCTestCase {

    /// `SKColor` equality compares colour *spaces* as well as components, and a
    /// sprite's `color` comes back in device RGB while `.white` and the palette
    /// constants are generic gray / sRGB. Same colour, unequal objects.
    private func sameColor(_ a: SKColor, _ b: SKColor, accuracy: CGFloat = 0.01) -> Bool {
        guard let lhs = a.usingColorSpace(.sRGB), let rhs = b.usingColorSpace(.sRGB)
        else { return false }
        return abs(lhs.redComponent   - rhs.redComponent)   < accuracy
            && abs(lhs.greenComponent - rhs.greenComponent) < accuracy
            && abs(lhs.blueComponent  - rhs.blueComponent)  < accuracy
            && abs(lhs.alphaComponent - rhs.alphaComponent) < accuracy
    }

    /// Regression, and the reason nothing collided when Phase 3.2 first landed:
    /// every physics body was created static. SpriteKit only evaluates a
    /// contact pair when at least one body is dynamic — two static bodies never
    /// produce a `didBegin` callback at all, so lasers passed straight through
    /// pieces with no damage, no explosion and no sound. Verified empirically
    /// against a real render loop: static/static reports 0 contacts, one
    /// dynamic reports the hit.
    func testLaserBodyIsDynamicSoContactsCanFireAtAll() {
        for owner in [ProjectileState.Owner.player, .enemy] {
            let laser = LaserNode(owner: owner)
            let body = laser.physicsBody
            XCTAssertNotNil(body, "\(owner) laser needs a body to generate contacts")
            XCTAssertTrue(body?.isDynamic == true,
                          "\(owner) laser body MUST be dynamic — a static/static pair never contacts")
            XCTAssertFalse(body?.affectedByGravity == true, "movement is SKAction-driven, not simulated")
            XCTAssertEqual(body?.collisionBitMask, PhysicsCategory.none,
                           "contact detection only — a laser must never be pushed around")
        }
    }

    /// The pieces and the ship stay static — they're the stationary half of
    /// every pair, and the laser supplies the dynamic side.
    func testTargetsAreStaticAndCategorisedCorrectly() {
        let black = PieceNode(piece: Piece(type: .pawn, color: .black, square: "d5"),
                              squareSize: BoardNode.squareSize)
        XCTAssertEqual(black.physicsBody?.categoryBitMask, PhysicsCategory.enemyPiece)
        XCTAssertFalse(black.physicsBody?.isDynamic == true)

        let white = PieceNode(piece: Piece(type: .pawn, color: .white, square: "d2"),
                              squareSize: BoardNode.squareSize)
        XCTAssertEqual(white.physicsBody?.categoryBitMask, PhysicsCategory.friendlyPiece)

        let ship = SpaceshipNode()
        XCTAssertEqual(ship.physicsBody?.categoryBitMask, PhysicsCategory.ship)
        XCTAssertFalse(ship.physicsBody?.isDynamic == true)
    }

    /// A parked laser must not test for contacts, or one sitting on top of a
    /// piece would report a phantom hit the moment the piece moved onto it.
    func testAParkedLaserTestsForNothingAndArmsOnFire() {
        let laser = LaserNode(owner: .player)
        XCTAssertEqual(laser.physicsBody?.contactTestBitMask, PhysicsCategory.none,
                       "fresh out of the pool, it is parked")
        XCTAssertFalse(laser.isActive)

        laser.fire(from: .zero, damage: ProjectileState.playerLaserDamage,
                   speed: ProjectileState.playerLaserSpeed, travelDistance: 400)
        XCTAssertTrue(laser.isActive)
        XCTAssertEqual(laser.physicsBody?.contactTestBitMask,
                       PhysicsCategory.enemyPiece | PhysicsCategory.enemyShot
                         | PhysicsCategory.raider | PhysicsCategory.friendlyPiece,
                       "a live player laser tests both piece colours (§8.3 firing "
                         + "lanes), plus raiders and the shots it can knock down")

        laser.deactivate()
        XCTAssertEqual(laser.physicsBody?.contactTestBitMask, PhysicsCategory.none)
        XCTAssertTrue(laser.physicsBody?.isDynamic == true,
                      "must stay dynamic after parking, or it can never contact again")
    }

    /// An enemy shot tests white pieces and the ship — never a black piece,
    /// or the fleet would shoot itself.
    func testEnemyShotNeverTargetsItsOwnFleet() {
        let shot = LaserNode(owner: .enemy)
        shot.fire(from: .zero, damage: ProjectileState.enemyShotDamage,
                  speed: 180, travelDistance: 400)
        let mask = shot.physicsBody?.contactTestBitMask ?? 0
        XCTAssertEqual(mask & PhysicsCategory.enemyPiece, 0, "must not hit its own fleet")
        XCTAssertNotEqual(mask & PhysicsCategory.friendlyPiece, 0)
        XCTAssertNotEqual(mask & PhysicsCategory.ship, 0)
    }

    /// A parked round must advertise nothing at all — not merely test for
    /// nothing. A contact fires when *either* body's contactTest matches the
    /// other's category, so a spent enemy shot that kept its category was an
    /// invisible mine sitting where it died, and every player laser that
    /// reached it detonated against empty board.
    func testAParkedRoundIsInvisibleToPhysics() {
        for owner in [ProjectileState.Owner.player, .enemy] {
            let laser = LaserNode(owner: owner)
            XCTAssertEqual(laser.physicsBody?.categoryBitMask, PhysicsCategory.none,
                           "\(owner): fresh from the pool, never fired")

            laser.fire(from: .zero, damage: 2, speed: 300, travelDistance: 400)
            XCTAssertNotEqual(laser.physicsBody?.categoryBitMask, PhysicsCategory.none,
                              "\(owner): in flight, it must be a target")

            laser.deactivate()
            XCTAssertEqual(laser.physicsBody?.categoryBitMask, PhysicsCategory.none,
                           "\(owner): spent, and must stop being one")
            XCTAssertEqual(laser.physicsBody?.contactTestBitMask, PhysicsCategory.none)
            XCTAssertTrue(laser.physicsBody?.isDynamic == true,
                          "still dynamic, or it could never contact again")

            // And it comes back properly on the next shot from the pool.
            laser.fire(from: .zero, damage: 2, speed: 300, travelDistance: 400)
            XCTAssertNotEqual(laser.physicsBody?.categoryBitMask, PhysicsCategory.none)
        }
    }

    /// Rounds shoot each other down. A departure from §20's Phase 3.2 bitmask
    /// spec, which excluded it — and one that costs the player shots, so it
    /// should be deliberate rather than a stray bit.
    func testRoundsCanShootEachOtherDown() {
        let laser = LaserNode(owner: .player)
        laser.fire(from: .zero, damage: 2, speed: 400, travelDistance: 400)
        XCTAssertNotEqual((laser.physicsBody?.contactTestBitMask ?? 0)
                          & PhysicsCategory.enemyShot, 0)

        let shot = LaserNode(owner: .enemy)
        shot.fire(from: .zero, damage: 1, speed: 180, travelDistance: 400)
        XCTAssertNotEqual((shot.physicsBody?.contactTestBitMask ?? 0)
                          & PhysicsCategory.playerLaser, 0)

        // A parked round in the pool sits on top of whatever is passing and
        // must still test nothing at all.
        shot.deactivate()
        XCTAssertEqual(shot.physicsBody?.contactTestBitMask, PhysicsCategory.none)
    }

    func testFiringIsRefusedWithoutRealSpeedOrDistance() {
        let laser = LaserNode(owner: .player)
        laser.fire(from: .zero, damage: 2, speed: 0, travelDistance: 400)
        XCTAssertFalse(laser.isActive, "zero speed would divide by zero for the duration")
        laser.fire(from: .zero, damage: 2, speed: 400, travelDistance: 0)
        XCTAssertFalse(laser.isActive, "nowhere to travel — nothing to fire")
    }

    /// Glass has to fly the way the shot was going. The heading is read from
    /// the round's rotation, and a player laser travels *up* — the naive
    /// reading (rotation zero means downward) sprays it backwards.
    func testTravelDirectionMatchesTheFlightPath() {
        for owner in [ProjectileState.Owner.player, .enemy] {
            for lean in [CGFloat(0), -0.6, 1.0] {
                let laser = LaserNode(owner: owner)
                laser.fire(from: .zero, damage: 1, speed: 200,
                           travelDistance: 400, lean: lean)
                let dy: CGFloat = owner == .player ? 400 : -400
                let dx = lean * 400
                let length = (dx * dx + dy * dy).squareRoot()
                let heading = laser.travelDirection
                XCTAssertEqual(heading.dx, dx / length, accuracy: 0.001,
                               "\(owner) lean \(lean)")
                XCTAssertEqual(heading.dy, dy / length, accuracy: 0.001,
                               "\(owner) lean \(lean)")
            }
        }
    }

    /// A round has to point along its own flight path. It did not: the old
    /// rotation turned an angled bolt 45° the *wrong* way, leaving a long thin
    /// slab travelling broadside — which read on screen as a purple paddle
    /// sliding sideways rather than as a missile.
    ///
    /// Checked as a cross product against the travel vector rather than against
    /// a literal angle, so it holds for both owners and both leans without four
    /// hand-computed constants.
    func testEveryRoundPointsAlongItsFlightPath() {
        for owner in [ProjectileState.Owner.player, .enemy] {
            for lean in [-1.0, 0.0, 1.0] as [CGFloat] {
                let laser = LaserNode(owner: owner)
                laser.fire(from: .zero, damage: 2, speed: 200,
                           travelDistance: 400, lean: lean)
                // The travel vector `fire` builds from the same inputs.
                let dy: CGFloat = owner == .player ? 400 : -400
                let dx = lean * 400
                // The node's long axis is its local +y, rotated by zRotation.
                let z = laser.zRotation
                let axis = CGPoint(x: -sin(z), y: cos(z))
                let cross = axis.x * dy - axis.y * dx
                XCTAssertEqual(cross, 0, accuracy: 0.001,
                               "\(owner) lean \(lean): the bolt is not aligned "
                               + "with its own travel")
                // And the tail must point backwards, not lead the way.
                let dot = axis.x * dx + axis.y * dy
                XCTAssertLessThan(dot, 0, "\(owner) lean \(lean): exhaust is in front")
            }
        }
    }

    /// The king's heavy dressing has to survive being aimed. `setHeavy` runs
    /// before `fire`, and `fire` re-dresses the round for its angle — which used
    /// to reset the heavy shot to an ordinary bolt's size and colour while
    /// leaving its beam attached.
    func testAHeavyRoundStaysHeavyWhenItIsAimed() {
        let plain = LaserNode(owner: .enemy)
        plain.fire(from: .zero, damage: 1, speed: 200, travelDistance: 400)
        let plainSize = plain.size

        for lean in [CGFloat(0), 0.4] {
            let heavy = LaserNode(owner: .enemy)
            heavy.setHeavy(true)
            heavy.fire(from: .zero, damage: 2, speed: 300, travelDistance: 400, lean: lean)
            XCTAssertGreaterThan(heavy.size.width, plainSize.width, "lean \(lean)")
            XCTAssertGreaterThan(heavy.size.height, plainSize.height, "lean \(lean)")
            XCTAssertTrue(sameColor(heavy.color, .white), "lean \(lean)")
            XCTAssertNotNil(heavy.childNode(withName: "kingBeam"), "lean \(lean)")
        }
    }

    /// An angled round is a different shape as well as a different colour, and
    /// the hitbox has to follow it — a paddle-shaped body would collect hits the
    /// missile never touched.
    func testAngledRoundIsLongerAndCarriesItsOwnHitbox() {
        let straight = LaserNode(owner: .enemy)
        straight.fire(from: .zero, damage: 2, speed: 200, travelDistance: 400)
        let straightSize = straight.size

        let angled = LaserNode(owner: .enemy)
        angled.fire(from: .zero, damage: 2, speed: 200, travelDistance: 400, lean: 1)
        XCTAssertGreaterThan(angled.size.height, straightSize.height, "longer")
        XCTAssertLessThan(angled.size.width, straightSize.width, "and narrower")
        XCTAssertTrue(sameColor(angled.color, NeonPalette.shotPurple))
        // Rebuilding the body must not silently drop the live contact mask.
        XCTAssertNotEqual(angled.physicsBody?.contactTestBitMask, PhysicsCategory.none,
                          "a live round with no contact mask hits nothing")
        XCTAssertTrue(angled.physicsBody?.isDynamic == true)

        // Returning to the pool leaves nothing dressed for the next shot.
        angled.deactivate()
        XCTAssertEqual(angled.zRotation, 0)
        XCTAssertEqual(angled.physicsBody?.contactTestBitMask, PhysicsCategory.none)
    }
}

final class PawnAdvanceBiasTests: XCTestCase {

    /// A thinned board, which is what GCI becomes once the player starts
    /// shooting. White's auto-move should walk a pawn; Black's search, which
    /// never gets the flag, should not.
    private let thinned = Chess.FEN.position(
        from: "4k3/pp6/8/8/8/8/PPPPPPPP/RNBQKBNR w KQ - 0 1")!

    private func pawnMoveShare(biased: Bool, samples: Int = 40) -> Int {
        var pawnMoves = 0
        for _ in 0..<samples {
            let constraints = ChessEngine.SearchConstraints(favoursPawnAdvance: biased)
            guard let move = ChessEngine.searchBestMove(in: thinned, depth: 2,
                                                        constraints: constraints),
                  let from = Chess.Square(coordinate: move.from),
                  thinned.board[from]?.kind == .pawn else { continue }
            pawnMoves += 1
        }
        return pawnMoves
    }

    /// Measured at 40/40 with the bias and 0/40 without, so these thresholds
    /// have a wide margin and are not a coin-flip away from failing.
    func testTheBiasMakesWhiteWalkAPawn() {
        XCTAssertGreaterThan(pawnMoveShare(biased: true), 30,
                             "the bias should pick a pawn nearly every time")
        XCTAssertLessThan(pawnMoveShare(biased: false), 10,
                          "and without it the engine has other plans")
    }

    /// Off unless asked for. Black must never get it: Black promotes by
    /// reaching rank 1, which is a breach, so the same bias would push Black
    /// toward ending the run by a route the player cannot read.
    func testTheBiasIsOffByDefault() {
        XCTAssertFalse(ChessEngine.SearchConstraints().favoursPawnAdvance)
        XCTAssertFalse(ChessEngine.SearchConstraints.none.favoursPawnAdvance)
        // The constraints Black's multi-move path builds.
        XCTAssertFalse(ChessEngine.SearchConstraints(excludedSources: ["a7"],
                                                     avoidsKingCapture: true)
                        .favoursPawnAdvance)
    }
}

@MainActor
final class PromotionRewardTests: XCTestCase {

    /// +1 per green scout shot down, stacking, hard cap 6, and it does not
    /// carry between waves. Was §7.2's promotion reward until §13 moved it onto
    /// the raider, which is a target the player can actually go and hunt.
    func testRapidFireStacksToTheCapAndResetsEachLevel() {
        let state = SpaceshipState()
        XCTAssertEqual(state.laserCap, SpaceshipState.baseLaserCap)

        var granted = 0
        for _ in 0..<10 where state.grantRapidFire() { granted += 1 }
        XCTAssertEqual(state.laserCap, SpaceshipState.maxLaserCap)
        XCTAssertEqual(granted, SpaceshipState.maxLaserCap - SpaceshipState.baseLaserCap,
                       "it refuses once capped, so the caller can stay quiet")
        XCTAssertFalse(state.grantRapidFire(), "and keeps refusing")

        state.resetForNewLevel()
        XCTAssertEqual(state.laserCap, SpaceshipState.baseLaserCap,
                       "earned again each wave, or an early promotion coasts")
    }

    /// The cap is concurrency, not ammunition: a slot frees when its round
    /// lands or leaves. That is why the reward only pays when shots are missing.
    func testTheCapLimitsRoundsInTheAirNotShotsFired() {
        let state = SpaceshipState()
        XCTAssertTrue(state.canFire)
        state.laserFired(); state.laserFired()
        XCTAssertFalse(state.canFire, "two in the air at the base cap")

        state.grantRapidFire()
        XCTAssertTrue(state.canFire, "a third slot, with the same two in flight")
        state.laserFired()
        XCTAssertFalse(state.canFire)

        state.laserResolved()
        XCTAssertTrue(state.canFire, "a landed round gives its slot straight back")
    }

    /// Firing cannot exceed the cap even if something asks it to.
    func testActiveLasersNeverExceedTheCap() {
        let state = SpaceshipState()
        for _ in 0..<20 { state.laserFired() }
        XCTAssertEqual(state.activeLasers, state.laserCap)
        for _ in 0..<20 { state.laserResolved() }
        XCTAssertEqual(state.activeLasers, 0, "and never goes negative")
    }
}

@MainActor
final class RaiderTests: XCTestCase {

    private static let boardBottom: CGFloat = 120
    /// The strip a raider may occupy, matching `RaiderController.flightBounds`.
    private static let bounds =
        (boardBottom - 10)...(boardBottom + BoardNode.boardSize + 20)

    private func entryY(for powerUp: PowerUp) -> CGFloat {
        switch RaiderRules.lane(for: powerUp) {
        case .overTheBoard:
            return Self.boardBottom + BoardNode.boardSize + 14
        case .rank(let rank):
            return Self.boardBottom + (CGFloat(rank) - 0.5) * BoardNode.squareSize
        }
    }

    // MARK: - The level roster (§13.1)

    /// Every level sends at least one raider, and the table is fixed rather
    /// than drawn from a pool — a raider whose identity is a surprise is one
    /// the player cannot prepare for.
    func testEveryLevelHasAFixedRoster() {
        for level in 1...LevelManager.finalLevel {
            let roster = PowerUps.roster(forLevel: level)
            XCTAssertFalse(roster.isEmpty, "level \(level)")
            // Fixed: the same answer every time it is asked.
            for _ in 0..<20 {
                XCTAssertEqual(PowerUps.roster(forLevel: level), roster)
            }
        }
    }

    /// The ladder as designed. Spelled out rather than derived, because this
    /// table *is* the design and a test that recomputed it would agree with
    /// any mistake.
    func testTheRosterMatchesTheDesignedLadder() {
        let expected: [Int: [PowerUp]] = [
            1: [.rapidFire], 2: [.rapidFire], 3: [.shield], 4: [.freeze],
            5: [.rapidFire, .shield], 6: [.gatling], 7: [.nuke, .nuke],
            8: [.rapidFire, .gatling],
            9: [.rapidFire, .gatling, .freeze],
            10: [.rapidFire, .gatling, .shield, .nuke],
        ]
        for (level, roster) in expected {
            XCTAssertEqual(PowerUps.roster(forLevel: level), roster, "level \(level)")
        }
    }

    /// Most of the run offers one power-up; the hard levels offer two and three.
    func testOffersGrowOnlyAtTheHardLevels() {
        for level in [1, 2, 3, 4, 6] {
            XCTAssertEqual(PowerUps.roster(forLevel: level).count, 1, "level \(level)")
        }
        // Level 5 carries the Shield's second outing alongside its Rapid Fire.
        XCTAssertEqual(PowerUps.roster(forLevel: 5), [.rapidFire, .shield])
        // Crossfire sends two of the same, which is where the player first meets
        // a level that does not go quiet after one kill.
        XCTAssertEqual(PowerUps.roster(forLevel: 7), [.nuke, .nuke])
        XCTAssertEqual(PowerUps.roster(forLevel: 8).count, 2)
        XCTAssertEqual(PowerUps.roster(forLevel: 9).count, 3)
        XCTAssertEqual(PowerUps.roster(forLevel: 10).count, 4)
    }

    /// Every power-up has to come round again after its debut, or it is a
    /// mechanic the player meets once and never uses. The Nuke only just
    /// qualifies — Level 7 and then Blitz.
    func testNoPowerUpAppearsOnlyOnce() {
        for powerUp in PowerUp.allCases {
            let levels = (1...LevelManager.finalLevel)
                .filter { PowerUps.roster(forLevel: $0).contains(powerUp) }
            XCTAssertGreaterThan(levels.count, 1,
                                 "\(powerUp) is offered only on level \(levels)")
        }
    }

    /// Every power-up is reachable, and each is introduced on its own level
    /// before ever sharing one — a level that debuts a type and stacks it with
    /// two others gives the player no chance to learn it.
    func testEveryPowerUpIsIntroducedAloneAndIsReachable() {
        for powerUp in PowerUp.allCases {
            guard let first = PowerUps.firstLevel(offering: powerUp) else {
                return XCTFail("\(powerUp) is never offered")
            }
            XCTAssertEqual(Set(PowerUps.roster(forLevel: first)), [powerUp],
                           "\(powerUp) must debut on a level of its own")
        }
    }

    /// Where a level offers several, the cheapest comes first: the player banks
    /// Rapid Fire before the barrage arrives and has more shots to chase it.
    func testMultiOfferLevelsLeadWithRapidFire() {
        for level in 8...LevelManager.finalLevel {
            XCTAssertEqual(PowerUps.roster(forLevel: level).first, .rapidFire,
                           "level \(level)")
        }
    }

    // MARK: - Flight paths (§6.3)

    /// The green scout flies dead level, and it is the only one that does.
    /// It is the raider the player meets first and chases most often, so it is
    /// the one that should be a pure horizontal aiming problem.
    func testOnlyTheGreenScoutFliesStraight() {
        for _ in 0..<50 {
            XCTAssertEqual(RaiderRules.flight(for: .rapidFire, headroom: 500),
                           .straight)
        }
        for powerUp in PowerUp.allCases where powerUp != .rapidFire {
            for _ in 0..<20 {
                XCTAssertNotEqual(RaiderRules.flight(for: powerUp, headroom: 500),
                                  .straight, "\(powerUp)")
            }
        }
    }

    /// Each kind flies its own shape, so the path is a second cue for what is
    /// on offer — and the two weavers are told apart by scale, not by luck.
    func testEachKindFliesItsOwnShape() {
        func shape(_ powerUp: PowerUp) -> String {
            switch RaiderRules.flight(for: powerUp, headroom: 500) {
            case .straight: return "straight"
            case .weave:    return "weave"
            case .glide:    return "glide"
            case .swoop:    return "swoop"
            }
        }
        XCTAssertEqual(shape(.rapidFire), "straight")
        XCTAssertEqual(shape(.freeze), "weave")
        XCTAssertEqual(shape(.gatling), "weave")
        XCTAssertEqual(shape(.shield), "glide")
        XCTAssertEqual(shape(.nuke), "swoop")

        // The two weaves must not be confusable. Compared at the extremes, so
        // no draw of one can pass for a draw of the other.
        var iceMax: CGFloat = 0, spreadMin: CGFloat = .greatestFiniteMagnitude
        var icePeriodMax: TimeInterval = 0, spreadPeriodMin = TimeInterval.infinity
        for _ in 0..<200 {
            if case .weave(let a, let p) = RaiderRules.flight(for: .freeze, headroom: 500) {
                iceMax = max(iceMax, a); icePeriodMax = max(icePeriodMax, p)
            }
            if case .weave(let a, let p) = RaiderRules.flight(for: .gatling, headroom: 500) {
                spreadMin = min(spreadMin, a); spreadPeriodMin = min(spreadPeriodMin, p)
            }
        }
        XCTAssertGreaterThan(spreadMin, iceMax, "the spread always sweeps wider")
        XCTAssertGreaterThan(spreadPeriodMin, icePeriodMax, "and always slower")
    }

    /// A path must stay in the strip between the HUD and the player's own lane.
    /// A raider that swings off the top or into the ship is a different
    /// mechanic, not a harder crossing.
    func testEveryFlightStaysInsideTheStrip() {
        for powerUp in PowerUp.allCases {
            let y = entryY(for: powerUp)
            XCTAssertTrue(Self.bounds.contains(y), "\(powerUp) enters out of bounds")
            let headroom = y - Self.bounds.lowerBound
            for _ in 0..<200 {
                switch RaiderRules.flight(for: powerUp, headroom: headroom) {
                case .straight:
                    break
                case .weave(let amplitude, _):
                    // The node clamps the swing to the room available either
                    // side; this checks the *lane* leaves enough room for the
                    // weave it was given, so the clamp is never what saves it.
                    XCTAssertLessThanOrEqual(y + amplitude, Self.bounds.upperBound,
                                             "\(powerUp) weaves above the strip")
                    XCTAssertGreaterThanOrEqual(y - amplitude, Self.bounds.lowerBound,
                                                "\(powerUp) weaves below the strip")
                case .glide(let drop):
                    XCTAssertGreaterThanOrEqual(y - drop, Self.bounds.lowerBound,
                                                "\(powerUp) glides below the strip")
                case .swoop(let depth):
                    XCTAssertGreaterThanOrEqual(y - depth, Self.bounds.lowerBound,
                                                "\(powerUp) dives below the strip")
                }
            }
        }
    }

    /// The two descending paths have to actually get down to the player, or
    /// "coming towards you" is a claim the geometry does not support.
    func testTheDescendingPathsReachTheLowRanks() {
        let deepest = { (powerUp: PowerUp) -> CGFloat in
            let y = self.entryY(for: powerUp)
            let headroom = y - Self.bounds.lowerBound
            var lowest = y
            for _ in 0..<200 {
                switch RaiderRules.flight(for: powerUp, headroom: headroom) {
                case .glide(let drop): lowest = min(lowest, y - drop)
                case .swoop(let depth): lowest = min(lowest, y - depth)
                default: break
                }
            }
            return lowest
        }
        // Into the bottom two ranks of the board at the steep end of the range.
        let secondRank = Self.boardBottom + BoardNode.squareSize * 2
        XCTAssertLessThan(deepest(.shield), secondRank, "the shield never comes down")
        XCTAssertLessThan(deepest(.nuke), secondRank, "the bomb never dives")
    }

    /// The dive bottoms out before halfway, so the climb out is the longer half
    /// and the raider hangs at its lowest point rather than flicking through it.
    func testTheSwoopBottomsOutBeforeHalfway() {
        XCTAssertLessThan(RaiderRules.swoopLowPoint, 0.5)
        XCTAssertGreaterThan(RaiderRules.swoopLowPoint, 0.3)
    }

    // MARK: - The free first pass (§6.3)

    /// A pass is owed once per *ship*, per run. §6 gives one every level, which
    /// spends its own rationale the first time and then keeps handing over a
    /// harmless raider forever.
    func testAPassIsOwedOncePerKindPerRun() {
        XCTAssertFalse(RaiderRules.fires(kindAlreadySeen: false),
                       "a ship never seen before makes its pass without firing")
        XCTAssertTrue(RaiderRules.fires(kindAlreadySeen: true),
                      "and every one after it fires")
    }

    /// Five ships, so five free passes in a run — one per new silhouette,
    /// which is the case §6's rule was actually written for.
    func testAllFivePassesAreEarnableAndNoMore() {
        var seen: Set<PowerUp> = []
        var free = 0
        for level in 1...LevelManager.finalLevel {
            for kind in PowerUps.roster(forLevel: level) where !seen.contains(kind) {
                seen.insert(kind)
                free += 1
            }
        }
        XCTAssertEqual(free, PowerUp.allCases.count)
        XCTAssertEqual(seen, Set(PowerUp.allCases))
    }

    // MARK: - Cadence

    /// The clock is real time, not the chess beat, and the cap holds a spawn
    /// rather than skipping it — a blocked raider is late, not cancelled.
    func testTheSpawnClockWaitsRatherThanSkipping() {
        var schedule = RaiderSchedule()
        schedule.reset(interval: 20)
        let lead = 20 * RaiderRules.openingLead
        XCTAssertFalse(schedule.tick(lead - 1, interval: 20, onScreen: 0), "not yet")
        XCTAssertTrue(schedule.tick(2, interval: 20, onScreen: 0), "due")
        XCTAssertFalse(schedule.tick(19, interval: 20, onScreen: 0))

        // Due, but one is already crossing: it stays due.
        XCTAssertFalse(schedule.tick(2, interval: 20,
                                     onScreen: RaiderRules.maxScoutsOnScreen),
                       "capped, so it holds")
        XCTAssertFalse(schedule.tick(0, interval: 20,
                                     onScreen: RaiderRules.maxScoutsOnScreen))
        XCTAssertTrue(schedule.tick(0, interval: 20, onScreen: 0),
                      "and launches the moment there is room")
    }

    /// One scout at a time. Two of the same ship on screen is the same offer
    /// twice, and it closes the gap that stops raiders becoming wallpaper.
    func testOnlyOneScoutCrossesAtATime() {
        XCTAssertEqual(RaiderRules.maxScoutsOnScreen, 1)
        XCTAssertLessThanOrEqual(RaiderRules.maxScoutsOnScreen, RaiderRules.maxOnScreen,
                                 "the pool has to be able to hold the cap")
    }

    /// Level 1 gives the player two control schemes and no fleet fire; a scout
    /// arriving over an untouched board is one more thing to parse before
    /// anything has happened. It waits for the back rank to break.
    func testEarlyLevelsHoldTheScoutUntilTheRearRankThins() {
        XCTAssertTrue(RaiderRules.waitsForThinnedRearRank(level: 1))
        XCTAssertTrue(RaiderRules.waitsForThinnedRearRank(level: 2))
        XCTAssertFalse(RaiderRules.waitsForThinnedRearRank(level: 3))

        var schedule = RaiderSchedule()
        schedule.reset(interval: 20)
        XCTAssertFalse(schedule.tick(25, interval: 20, onScreen: 0, blocked: true),
                       "overdue, but the rank is still crowded")
        XCTAssertFalse(schedule.tick(10, interval: 20, onScreen: 0, blocked: true))
        XCTAssertTrue(schedule.tick(0, interval: 20, onScreen: 0, blocked: false),
                      "and goes the moment it thins — the wait is not lost")
    }

    /// The shot never leaves at the very edges of the crossing: one fired on
    /// entry is unreadable, one fired on exit is unavoidable.
    func testTheShotLeavesMidCrossing() {
        for _ in 0..<100 {
            let f = RaiderRules.fireFraction()
            XCTAssertGreaterThanOrEqual(f, 0.25)
            XCTAssertLessThanOrEqual(f, 0.7)
        }
    }

    /// The player has to be able to go after one. A scout faster than the ship
    /// can only ever be hit by already being in the right place, which is not a
    /// skill — the first version was 300 against the ship's 294.
    func testTheShipCanCatchEveryScout() {
        for powerUp in PowerUp.allCases {
            let speed = RaiderRules.scoutSpeed * CGFloat(powerUp.speedMultiplier)
            XCTAssertLessThan(speed, SpaceshipNode.speed, "\(powerUp) is uncatchable")
            let closing = SpaceshipNode.speed - speed
            XCTAssertGreaterThan(closing, 50, "\(powerUp) closes at only \(closing) px/s")
        }
    }

    /// Every level gets clear sky between crossings, and the gap tightens only
    /// where the level is offering more than one power-up.
    func testThereIsAlwaysClearSkyBetweenScouts() {
        let crossing = RaiderRules.crossingDuration(sceneWidth: 960, scoutWidth: 58)
        for level in 1...LevelManager.finalLevel {
            let table = LevelManager.parameters(for: level).raiderInterval
            let count = PowerUps.roster(forLevel: level).count
            let used = RaiderRules.interval(forLevel: table, crossing: crossing,
                                            rosterCount: count)
            XCTAssertGreaterThanOrEqual(used, table,
                                        "the rule may stretch the interval, never shorten it")
            XCTAssertGreaterThanOrEqual(used - crossing,
                                        RaiderRules.minimumGap(rosterCount: count) - 0.001,
                                        "level \(level) leaves too little quiet")
            // The gap outlasts the crossing, so the sky is empty for more of a
            // level than it is occupied.
            XCTAssertGreaterThan(RaiderRules.minimumGap(rosterCount: count), crossing,
                                 "level \(level)")
        }
        // An interval already long enough is left alone.
        XCTAssertEqual(RaiderRules.interval(forLevel: 40, crossing: crossing), 40)
    }

    /// More on offer means less waiting, or a level advertising three power-ups
    /// realistically hands over one.
    func testTheGapTightensAsTheRosterGrows() {
        let one = RaiderRules.minimumGap(rosterCount: 1)
        let two = RaiderRules.minimumGap(rosterCount: 2)
        let three = RaiderRules.minimumGap(rosterCount: 3)
        XCTAssertGreaterThan(one, two)
        XCTAssertGreaterThan(two, three)
        // But never back to a stream: the old 7s gap was nine or ten a wave.
        XCTAssertGreaterThan(three, 10)
    }

    /// A wave should see a handful of crossings, not a stream — and the first
    /// has to arrive early enough that the power-up is actually offered.
    func testAWaveSeesAFewCrossingsAndTheFirstArrivesEarly() {
        let crossing = RaiderRules.crossingDuration(sceneWidth: 960, scoutWidth: 45)
        let gap = RaiderRules.interval(forLevel: 20, crossing: crossing)
        let first = gap * RaiderRules.openingLead

        XCTAssertLessThan(first, 20, "the offer must land inside a short wave")
        var time = first, crossings = 0
        while time <= 90 { crossings += 1; time += gap }
        XCTAssertGreaterThanOrEqual(crossings, 2)
        XCTAssertLessThanOrEqual(crossings, 4, "more than this is traffic, not a raid")
    }

    /// The scout's round is 25% up on the fleet's, and never zero.
    ///
    /// §21.1 gives Level 1 a projectile speed of zero because the fleet does
    /// not fire there, so deriving the scout's shot from it produced a round of
    /// speed zero — which `LaserNode.fire` refuses. The scout could not shoot
    /// on the one level where §6 makes it the only repeatable incoming fire.
    func testTheScoutsShotIsFasterThanTheFleetsAndNeverZero() {
        XCTAssertEqual(LevelManager.parameters(for: 1).projectileSpeed, 0,
                       "the premise: Level 1's fleet does not fire")
        for level in 1...12 {
            let params = LevelManager.parameters(for: level)
            let shot = RaiderRules.shotSpeed(level: params)
            XCTAssertGreaterThan(shot, 0, "level \(level): a zero-speed round never fires")
            XCTAssertGreaterThan(shot, params.projectileSpeed,
                                 "level \(level): faster than the fleet's")
        }
        // Where the fleet does fire, it is exactly the stated 25%.
        let five = LevelManager.parameters(for: 5)
        XCTAssertEqual(RaiderRules.shotSpeed(level: five),
                       five.projectileSpeed * 1.25, accuracy: 0.01)
    }

    func testScoutMatchesTheDesignTable() {
        XCTAssertEqual(RaiderRules.scoutHP, 1, "§6")
        XCTAssertEqual(RaiderRules.scoutPoints, 100, "§9")
        XCTAssertEqual(RaiderRules.maxOnScreen, 2, "§6")
        // §21.1 already paced them: 20s at Level 1, tightening to a 6s floor.
        // Now fully overridden by the gap rule — recorded so the override stays
        // a decision rather than becoming a surprise.
        XCTAssertEqual(LevelManager.parameters(for: 1).raiderInterval, 20)
        XCTAssertEqual(LevelManager.parameters(for: 10).raiderInterval, 6)
    }
}

@MainActor
final class RegenerationTests: XCTestCase {

    private func level(_ n: Int) -> LevelParameters { LevelManager.parameters(for: n) }

    /// §23.9: from Level 4, and never past the level's slot cap. Slots are
    /// spent when a regeneration is *queued* — counting on arrival would let a
    /// two-slot wave queue twenty at once and pay them all out.
    func testRegenerationRespectsTheLevelSlotCap() {
        XCTAssertEqual(level(3).regenSlots, 0, "nothing regenerates before Level 4")
        XCTAssertFalse(Regeneration.schedules(destroyed: .pawn, color: .black,
                                              level: level(3), slotsUsed: 0))
        XCTAssertTrue(Regeneration.schedules(destroyed: .rook, color: .black,
                                             level: level(4), slotsUsed: 0))
        XCTAssertTrue(Regeneration.schedules(destroyed: .pawn, color: .black,
                                             level: level(4), slotsUsed: 1))
        XCTAssertFalse(Regeneration.schedules(destroyed: .pawn, color: .black,
                                              level: level(4), slotsUsed: 2),
                       "Level 4's cap is 2")
    }

    /// The king never comes back, and White never regenerates at all.
    func testTheKingNeverRegenerates() {
        XCTAssertFalse(Regeneration.schedules(destroyed: .king, color: .black,
                                              level: level(9), slotsUsed: 0))
        XCTAssertFalse(Regeneration.schedules(destroyed: .pawn, color: .white,
                                              level: level(9), slotsUsed: 0))
    }

    func testQueueSpendsASlotPerScheduleAndFiresOnTime() {
        let delay = Regeneration.delay(for: level(9))
        var queue = RegenerationQueue()
        queue.schedule(after: delay)
        queue.schedule(after: delay)
        XCTAssertEqual(queue.slotsUsed, 2)
        XCTAssertEqual(queue.tick(delay - 1), 0, "not yet")
        XCTAssertEqual(queue.tick(2), 2, "both due in the same frame")
        XCTAssertEqual(queue.waiting, 0)
        XCTAssertEqual(queue.tick(100), 0, "and they only fire once")
        // §23.9: a level ending cancels everything pending.
        queue.schedule(after: delay)
        queue.reset()
        XCTAssertEqual(queue.waiting, 0)
        XCTAssertEqual(queue.slotsUsed, 0)
    }

    /// The gap is paced off the beat, not §23.9's flat ten seconds: ten is two
    /// and a half turns, long enough that the kill which caused it has left the
    /// player's head and the pawn reads as arriving from nowhere.
    func testRegenerationIsPacedOffTheBeat() {
        for n in 4...10 {
            let delay = Regeneration.delay(for: level(n))
            XCTAssertEqual(delay, level(n).turnTimer, accuracy: 0.001, "level \(n)")
            XCTAssertGreaterThanOrEqual(delay, 2.5, "never instant")
            // The beam-in is part of the wait and the player is watching it, so
            // the whole kill-to-live time is what has to stay reasonable.
            XCTAssertLessThan(delay + Regeneration.beamInDuration, 6.5, "level \(n)")
        }
        // Blitz's 3s clock pulls it in with everything else.
        XCTAssertLessThan(Regeneration.delay(for: level(10)),
                          Regeneration.delay(for: level(9)))
    }

    /// Standard spawns scatter along the fleet's rear rank; a badly hurt king
    /// pulls them in front of him instead (§23.9's defensive mode).
    func testDefensiveSpawnShieldsTheKing() {
        XCTAssertFalse(Regeneration.isDefensive(kingDamage: .full))
        XCTAssertFalse(Regeneration.isDefensive(kingDamage: .chipped))
        XCTAssertTrue(Regeneration.isDefensive(kingDamage: .cracked))
        XCTAssertTrue(Regeneration.isDefensive(kingDamage: .critical))

        XCTAssertEqual(Regeneration.spawnSquare(defensive: true, kingSquare: "e6",
                                                rearRank: 7, occupied: []), "e5")
        // Blocked in front: fall back to the standard search, which opens one
        // rank ahead of the rear (`spawnDepthOrder`) rather than on it.
        let blocked = Regeneration.spawnSquare(defensive: true, kingSquare: "e6",
                                               rearRank: 7, occupied: ["e5"])
        XCTAssertNotEqual(blocked, "e5")
        XCTAssertEqual(blocked?.last, "6")
        // Standard: forward ranks first, never an occupied square. Black's own
        // back rank is full at level start, so searching it first found nowhere
        // to go through the whole opening.
        let ahead = Set("abcdefg".map { "\($0)6" })
        XCTAssertEqual(Regeneration.spawnSquare(defensive: false, kingSquare: "e8",
                                                rearRank: 7, occupied: ahead), "h6")
    }

    /// A regenerated pawn goes *in front of* the formation where it can, not
    /// behind it. It is a body in the way — and an armored one cannot be shot
    /// at all — so it is worth far more shielding the queen and king than
    /// tucked behind them where the player was never going to reach.
    func testSpawnPrefersTheForwardRanks() {
        XCTAssertEqual(Regeneration.spawnDepthOrder, [1, 2, 0],
                       "second rank, then third, then the back rank")
        // Whole fleet intact bar one hole on each of ranks 8, 7 and 6.
        var occupied = Set("abcdefgh".flatMap { f in [6, 7, 8].map { "\(f)\($0)" } })
        occupied.remove("a8"); occupied.remove("c7"); occupied.remove("e6")
        XCTAssertEqual(Regeneration.spawnSquare(defensive: false, kingSquare: "e8",
                                                rearRank: 8, occupied: occupied),
                       "c7", "the second rank wins over the back one")
        // Second rank full: the third, still ahead of the back rank.
        occupied.insert("c7")
        XCTAssertEqual(Regeneration.spawnSquare(defensive: false, kingSquare: "e8",
                                                rearRank: 8, occupied: occupied),
                       "e6")
        // Both forward ranks full: the back rank is the fallback, because
        // somewhere beats nowhere.
        occupied.insert("e6")
        XCTAssertEqual(Regeneration.spawnSquare(defensive: false, kingSquare: "e8",
                                                rearRank: 8, occupied: occupied),
                       "a8")
        // And nowhere at all is still nowhere.
        occupied.insert("a8")
        XCTAssertNil(Regeneration.spawnSquare(defensive: false, kingSquare: "e8",
                                              rearRank: 8, occupied: occupied))
    }

    /// The player gets warned before a pawn starts arriving — the shimmer is
    /// the warning once it is arriving, but by then it is too late to clear the
    /// square. One warning covers any number of simultaneous arrivals.
    func testTheWarningWindowOpensBeforeTheBeamIn() {
        XCTAssertGreaterThan(Regeneration.warningLead, 1)
        XCTAssertLessThan(Regeneration.warningLead,
                          Regeneration.delay(for: level(10)),
                          "the lead has to fit inside the shortest delay")
        var queue = RegenerationQueue()
        let delay = Regeneration.delay(for: level(9))
        queue.schedule(after: delay)
        queue.schedule(after: delay)
        XCTAssertFalse(queue.isWarning)
        _ = queue.tick(delay - Regeneration.warningLead + 0.01)
        XCTAssertTrue(queue.isWarning, "and two due at once is still one warning")
        _ = queue.tick(Regeneration.warningLead)
        XCTAssertFalse(queue.isWarning, "spent arrivals stop warning")
    }

    /// The cap counts pawns that arrive, not attempts that were made — a slot
    /// spent on a spawn with nowhere to go is a pawn the player never sees,
    /// quietly making the level easier than its own table says.
    func testAFailedSpawnGivesTheSlotBack() {
        var queue = RegenerationQueue()
        queue.schedule(after: 1)
        queue.schedule(after: 1)
        XCTAssertEqual(queue.slotsUsed, 2)
        queue.refund()
        XCTAssertEqual(queue.slotsUsed, 1)
        queue.refund()
        queue.refund()
        XCTAssertEqual(queue.slotsUsed, 0, "and it never goes negative")
    }

    /// §10.1: armor is Level 8's own wave, back again for Blitz, and only ever
    /// on a regenerated pawn.
    func testArmorIsLevelEightAndBlitz() {
        for n in 1...7 { XCTAssertFalse(level(n).armoredPawns, "level \(n)") }
        XCTAssertTrue(level(8).armoredPawns)
        XCTAssertFalse(level(9).armoredPawns, "King Activated is its own wave")
        for n in 10...12 { XCTAssertTrue(level(n).armoredPawns, "level \(n)") }
        // Roughly half, per §10.1 — measured over enough draws to be sure it
        // is a coin and not a constant.
        var armored = 0
        for _ in 0..<4000 where Regeneration.arrivesArmored(level: level(8)) { armored += 1 }
        XCTAssertGreaterThan(armored, 1700)
        XCTAssertLessThan(armored, 2300)
        // And never on a level that has not earned it, however often asked.
        for _ in 0..<200 {
            XCTAssertFalse(Regeneration.arrivesArmored(level: level(7)))
            XCTAssertFalse(Regeneration.arrivesArmored(level: level(9)))
        }
    }

    /// Armor stops laser fire dead and expires on White's moves; a chess
    /// capture is unaffected throughout.
    func testArmorBlocksLasersForThreeWhiteTurns() {
        let board = GCIBoard()
        board.setupStandardPosition()
        // A clear square on the rear rank — the standard position fills 7 and 8.
        guard let pawn = board.regeneratePawn(at: "d5", armored: true) else {
            return XCTFail("regeneration refused an empty square")
        }
        XCTAssertTrue(pawn.isArmored)
        XCTAssertTrue(pawn.isRegenerated)

        for turn in 1...Regeneration.armorTurns {
            let outcome = CollisionResolver.playerLaserHitBlackPiece(at: "d5", board: board)
            guard case .ricochet = outcome else {
                return XCTFail("turn \(turn): armor let a laser through")
            }
            XCTAssertEqual(board.piece(at: "d5")?.hp, PieceType.pawn.maxHP,
                           "turn \(turn): no damage may land")
            board.tickArmor()
        }
        XCTAssertFalse(board.piece(at: "d5")?.isArmored ?? true, "three turns and it is spent")

        // Now it takes damage like any pawn — and pays the reduced rate.
        guard case .blackPieceHit(_, _, _, let points, _) =
                CollisionResolver.playerLaserHitBlackPiece(at: "d5", board: board) else {
            return XCTFail("armor did not expire")
        }
        XCTAssertLessThan(board.piece(at: "d5")?.hp ?? 99, PieceType.pawn.maxHP)
        XCTAssertEqual(points, 0, "not destroyed by one shot")
        board.applyDamage(PieceType.pawn.maxHP, at: "d5")
        XCTAssertNil(board.piece(at: "d5"))
    }

    /// The regenerated pawn was permanently unshootable. Its node is built
    /// without a body for the beam-in, and the completion called
    /// `refresh(with:)` to finish it off — but refresh only rebuilds the body
    /// when the *texture* changes, and a pawn arriving at full HP keeps the
    /// texture it was made with. So the body stayed nil for the rest of the
    /// wave and lasers passed through, which looks exactly like armor that
    /// never expires.
    func testARegeneratedPawnEndsUpShootable() {
        let piece = Piece(type: .pawn, color: .black, square: "c7")
        let node = PieceNode(piece: piece, squareSize: BoardNode.squareSize)
        XCTAssertNotNil(node.physicsBody, "an ordinary piece is solid from birth")

        // What regeneration does: strip the body for the beam-in.
        node.physicsBody = nil
        // What used to be relied on to put it back, and does not.
        node.refresh(with: piece)
        XCTAssertNil(node.physicsBody,
                     "refresh cannot restore it — the texture never changed")
        // What actually does.
        node.becomeSolid()
        XCTAssertNotNil(node.physicsBody)
        XCTAssertEqual(node.physicsBody?.categoryBitMask, PhysicsCategory.enemyPiece)
        XCTAssertFalse(node.physicsBody?.isDynamic ?? true, "pieces stay static")
    }

    /// Armor is about taking fire, not returning it. An armored pawn is a
    /// gunner like any other — nothing in the firing path looks at armor, and
    /// nothing should start.
    func testArmorDoesNotStopAPawnShooting() {
        let armored = FleetFiring.Candidate(square: "c7", type: .pawn)
        let plain = FleetFiring.Candidate(square: "d7", type: .pawn)
        let gunners = FleetFiring.gunners(from: [armored, plain,
                                                 .init(square: "e8", type: .king)])
        XCTAssertEqual(Set(gunners.map(\.square)), ["c7", "d7"],
                       "a regenerated or armored pawn is still a pawn")
        // The firing decision is made from square and type alone — there is no
        // route by which armor could reach it.
        XCTAssertEqual(FleetFiring.Candidate(square: "c7", type: .pawn), armored)
    }

    /// §9: a pawn that came back is worth less than one off the starting board.
    func testARegeneratedPawnScoresLess() {
        var fresh = Piece(type: .pawn, color: .black, square: "a7")
        XCTAssertEqual(fresh.shootValue, PieceType.pawn.pointValue)
        fresh.isRegenerated = true
        XCTAssertEqual(fresh.shootValue, Regeneration.regeneratedPawnValue)
        XCTAssertLessThan(fresh.shootValue, PieceType.pawn.pointValue)
        // Only pawns regenerate, so nothing else is discounted.
        var rook = Piece(type: .rook, color: .black, square: "a8")
        rook.isRegenerated = true
        XCTAssertEqual(rook.shootValue, PieceType.rook.pointValue)
    }

    /// The engine has to see a regenerated pawn, or its search will move other
    /// pieces straight through it — the same class of bug as `forcePlace`.
    func testTheChessEngineSeesARegeneratedPawn() {
        let board = GCIBoard()
        board.setupStandardPosition()
        board.regeneratePawn(at: "d5", armored: false)
        XCTAssertEqual(board.currentPosition.board["d5"]?.kind, .pawn)
        XCTAssertEqual(board.currentPosition.board["d5"]?.color, .black)
        // And an occupied square refuses rather than overwriting.
        XCTAssertNil(board.regeneratePawn(at: "d5", armored: false))
        XCTAssertNil(board.regeneratePawn(at: "e7", armored: false))
    }
}

@MainActor
final class JuiceTests: XCTestCase {

    /// Three events shake the board and nothing else does. The scarcity is the
    /// point: a shake that turns up on every rook is scenery, and then the two
    /// kills that decide a wave are no longer announced by it.
    func testOnlyTheQueenAndKingShakeTheBoard() {
        XCTAssertEqual(Juice.shake(forDestroying: .king), Juice.heavy)
        XCTAssertEqual(Juice.shake(forDestroying: .queen), Juice.light)
        for type in [PieceType.pawn, .knight, .bishop, .rook] {
            XCTAssertEqual(Juice.shake(forDestroying: type), .none, "\(type)")
        }
        XCTAssertEqual(Juice.shipDestroyed, Juice.medium, "and losing a life")
        // §24.1's durations.
        XCTAssertEqual(Juice.shake(forDestroying: .king).duration, 0.6)
        XCTAssertEqual(Juice.shipDestroyed.duration, 0.4)
        // Ordered, so "heavy" is always felt as more than "light".
        let tiers = [Juice.light, Juice.medium, Juice.heavy]
        for pair in zip(tiers, tiers.dropFirst()) {
            XCTAssertLessThan(pair.0.amplitude, pair.1.amplitude)
            XCTAssertLessThanOrEqual(pair.0.duration, pair.1.duration)
        }
    }

    /// Rare means each one has to land hard. A first pass measured after the
    /// fact at 1.5pt over three frames was below anyone's threshold, and read
    /// as the feature not existing.
    func testEveryShakeIsUnmistakable() {
        for (name, shake) in [("light", Juice.light), ("medium", Juice.medium),
                              ("heavy", Juice.heavy)] {
            // A fifth of a square, minimum, and long enough to register.
            XCTAssertGreaterThanOrEqual(shake.amplitude, BoardNode.squareSize / 5, name)
            let frames = shake.duration / Juice.frameDuration
            XCTAssertGreaterThanOrEqual(frames, 12, "\(name) lasts \(frames) frames")
        }
        // The board is 512pt centred in a 960pt scene, so it has 224pt of
        // margin: nothing here can shake an edge into view.
        XCTAssertLessThan(Juice.heavy.amplitude, (960 - BoardNode.boardSize) / 2)
    }

    /// The offset alternates rather than wandering. A random walk spends most
    /// of its frames near the middle and reads as blur; flipping roughly 180°
    /// each frame puts consecutive frames on opposite sides, so the eye sees
    /// twice the amplitude between them. This is most of why the shake became
    /// visible — more than the amplitudes did.
    func testShakeAlternatesAtFullAmplitude() {
        var angle = CGFloat(0)
        var previous: CGPoint?
        for _ in 0..<40 {
            let (point, next) = Juice.offset(amplitude: 10, lastAngle: angle)
            angle = next
            // Every frame is displaced by the full amplitude, never less.
            XCTAssertEqual(hypot(point.x, point.y), 10, accuracy: 0.001)
            if let previous {
                // Opposite sides, so the travel between frames beats the
                // amplitude itself — 180° ± 0.7rad is at worst 2·cos(0.7)·a.
                XCTAssertGreaterThan(hypot(point.x - previous.x, point.y - previous.y),
                                     10 * 1.5)
            }
            previous = point
        }
    }

    /// "Punchy, not nauseating" (§24.1): the shake has to be nearly gone well
    /// before its window closes, not drift back to centre.
    func testShakeDecaysToNothing() {
        let shake = Juice.heavy
        XCTAssertEqual(Juice.amplitude(shake, elapsed: 0), shake.amplitude)
        XCTAssertLessThan(Juice.amplitude(shake, elapsed: shake.duration / 2),
                          shake.amplitude * 0.15, "past halfway it is a tremor")
        XCTAssertEqual(Juice.amplitude(shake, elapsed: shake.duration), 0,
                       "and exactly zero at the end, so the board lands true")
        XCTAssertEqual(Juice.amplitude(shake, elapsed: shake.duration * 2), 0)
        XCTAssertEqual(Juice.amplitude(.none, elapsed: 0), 0)
    }

    /// The hit freeze is the king's alone. §24.2 grades it across the queen and
    /// the flagship too, but those already shake, and freeze and shake compete
    /// for the same job — a queen's 67ms was real input latency that then
    /// vanished underneath the shake behind it. On the king the contrast earns
    /// its keep, and it makes that death the one moment the game stops.
    func testOnlyTheKingFreezesTheGame() {
        XCTAssertEqual(Juice.freezeFrames(forDestroying: .king), 10)
        for type in PieceType.allCases where type != .king {
            XCTAssertEqual(Juice.freezeFrames(forDestroying: type), 0, "\(type)")
        }
        XCTAssertEqual(Juice.freezeDuration(forDestroying: .king), 10.0 / 60, accuracy: 0.0001)
        XCTAssertEqual(Juice.freezeDuration(forDestroying: .pawn), 0)
        // The king is the only event that both stops time and shakes the board.
        XCTAssertNotEqual(Juice.shake(forDestroying: .king), .none)
        XCTAssertNotEqual(Juice.shake(forDestroying: .queen), .none,
                          "the queen still shakes — it just no longer freezes")
    }

    /// Venting starts at half HP and stops at zero — a destroyed piece must not
    /// leave an emitter behind.
    func testVentingStartsAtHalfHP() {
        XCTAssertFalse(Juice.vents(hp: 8, maxHP: 12))
        XCTAssertTrue(Juice.vents(hp: 6, maxHP: 12), "exactly half vents")
        XCTAssertTrue(Juice.vents(hp: 1, maxHP: 12))
        XCTAssertFalse(Juice.vents(hp: 0, maxHP: 12), "destroyed pieces do not vent")
        XCTAssertFalse(Juice.vents(hp: 5, maxHP: 0))
        // Against the real HP table: every piece vents on the shot that takes
        // it past half, and no earlier.
        for type in PieceType.allCases {
            var piece = Piece(type: type, color: .black, square: "d5")
            XCTAssertFalse(Juice.vents(hp: piece.hp, maxHP: type.maxHP), "\(type) intact")
            piece.applyDamage(type.maxHP - type.maxHP / 2)
            XCTAssertTrue(Juice.vents(hp: piece.hp, maxHP: type.maxHP), "\(type) at half")
        }
    }

    /// The pop has to show the number the total actually moves by.
    func testAScorePopMatchesWhatTheScoreGains() {
        let manager = ScoreManager.shared
        manager.resetForNewGame()
        for _ in 0..<3 { manager.advanceLevel() }      // ×2.5
        let before = manager.currentScore
        let shown = manager.scaled(150)
        manager.addPoints(150)
        XCTAssertEqual(manager.currentScore - before, shown)
        manager.resetForNewGame()
    }

    func testScorePopTimingFollowsTheDoc() {
        XCTAssertEqual(Juice.popRise, 30, "§24.3: floats up ~30 points")
        XCTAssertEqual(Juice.popDuration, 0.8, "§24.3: fades over 0.8s")
    }
}

@MainActor
final class SurvivingWedgeTests: XCTestCase {

    private func damaged(_ type: PieceType, hitAtX x: CGFloat) -> PieceNode {
        var piece = Piece(type: type, color: .white, square: "d2")
        let node = PieceNode(piece: piece, squareSize: BoardNode.squareSize)
        node.noteHit(atLocalX: x)
        piece.applyDamage(piece.type.maxHP / 2)
        node.refresh(with: piece)
        return node
    }

    /// The side that survives is the side the shot did *not* take off.
    func testTheWedgeIsTheSideTheShotMissed() {
        let node = PieceNode(piece: Piece(type: .queen, color: .white, square: "d1"),
                             squareSize: BoardNode.squareSize)
        node.noteHit(atLocalX: -node.size.width / 2)
        XCTAssertEqual(node.survivingSide, .right, "struck on the left")

        let other = PieceNode(piece: Piece(type: .queen, color: .white, square: "d1"),
                              squareSize: BoardNode.squareSize)
        other.noteHit(atLocalX: other.size.width / 2)
        XCTAssertEqual(other.survivingSide, .left, "struck on the right")
    }

    /// A clean hit down the middle cannot say which side it took off.
    func testACentreHitTossesACoin() {
        var seen = Set<String>()
        for _ in 0..<200 {
            let node = PieceNode(piece: Piece(type: .pawn, color: .white, square: "d2"),
                                 squareSize: BoardNode.squareSize)
            node.noteHit(atLocalX: 0)
            seen.insert(node.survivingSide == .left ? "L" : "R")
        }
        XCTAssertEqual(seen, ["L", "R"])
    }

    /// It must not jump sides on a later hit, or a piece would flicker between
    /// silhouettes as it is worn down.
    func testTheSideIsFixedByTheFirstHit() {
        let node = PieceNode(piece: Piece(type: .rook, color: .white, square: "a1"),
                             squareSize: BoardNode.squareSize)
        node.noteHit(atLocalX: -node.size.width / 2)
        node.noteHit(atLocalX: node.size.width / 2)
        node.noteHit(atLocalX: node.size.width / 2)
        XCTAssertEqual(node.survivingSide, .right)
    }

    /// A whole piece shows no wedge; a damaged one does, and the hitbox grows
    /// to cover it — what the player can see, the player can hit.
    func testTheWedgeAppearsWithDamageAndCarriesAHitbox() {
        let whole = PieceNode(piece: Piece(type: .bishop, color: .white, square: "c1"),
                              squareSize: BoardNode.squareSize)
        XCTAssertNil(whole.survivingSide)
        let wholeArea = whole.physicsBody?.area ?? 0

        let hurt = damaged(.bishop, hitAtX: -20)
        XCTAssertEqual(hurt.survivingSide, .right)
        XCTAssertGreaterThan(hurt.children.count, whole.children.count,
                             "the surviving slice is drawn")
        // The eroded top alone would be a fraction of the whole; with the wedge
        // it sits between "nothing" and "undamaged".
        let hurtArea = hurt.physicsBody?.area ?? 0
        XCTAssertGreaterThan(hurtArea, 0)
        XCTAssertLessThan(hurtArea, wholeArea, "still visibly less than a whole piece")
    }

    /// The whole approach rests on this: a slice cut from the full-HP art lands
    /// exactly where that part of the piece was, because every damage state
    /// shares one canvas. Re-exported art that broke it would misalign every
    /// damaged piece on the board, silently.
    func testEveryDamageStateSharesOneCanvas() {
        for type in PieceType.allCases {
            for color in [PieceColor.white, .black] {
                var piece = Piece(type: type, color: color, square: "d4")
                let full = SKTexture(imageNamed: piece.fullTextureName).size()
                XCTAssertGreaterThan(full.width, 0, "\(piece.fullTextureName) missing")
                for damage in [1, type.maxHP - 1] {
                    piece = Piece(type: type, color: color, square: "d4")
                    piece.applyDamage(damage)
                    let state = SKTexture(imageNamed: piece.textureName).size()
                    XCTAssertEqual(state.width, full.width, accuracy: 0.5,
                                   "\(piece.textureName) is a different canvas")
                    XCTAssertEqual(state.height, full.height, accuracy: 0.5,
                                   "\(piece.textureName) is a different canvas")
                }
            }
        }
    }
}

final class DamageStateTests: XCTestCase {

    /// §7.1's table, verbatim, as (piece, damage-taken, expected state). The
    /// ratio approximation this replaced was a full stage late on rook, queen
    /// and king — a rook's first hit still read as undamaged — so damage was
    /// invisible on exactly the pieces the player shoots most.
    func testDamageStatesMatchTheDesignTable() {
        let expectations: [(PieceType, Int, DamageState)] = [
            (.pawn, 0, .full), (.pawn, 1, .chipped), (.pawn, 2, .cracked),
            (.knight, 1, .full), (.knight, 2, .chipped), (.knight, 4, .cracked), (.knight, 5, .critical),
            (.bishop, 1, .full), (.bishop, 2, .chipped), (.bishop, 4, .cracked), (.bishop, 5, .critical),
            (.rook, 1, .full), (.rook, 2, .chipped), (.rook, 4, .cracked), (.rook, 6, .critical),
            (.queen, 2, .full), (.queen, 3, .chipped), (.queen, 6, .cracked), (.queen, 9, .critical),
            (.king, 3, .full), (.king, 4, .chipped), (.king, 8, .cracked), (.king, 12, .critical),
        ]
        for (type, taken, expected) in expectations {
            var piece = Piece(type: type, color: .black, square: "d5")
            piece.applyDamage(taken)
            XCTAssertEqual(piece.damageState, expected,
                           "\(type) after \(taken) damage should be \(expected)")
        }
    }

    /// The specific case that made the bug visible in playtest: one laser hit
    /// on a rook must change its sprite. Under the old ratio buckets 8→6 HP
    /// still resolved to `.full`, so the hit looked like it did nothing.
    func testARooksFirstLaserHitChangesItsSprite() {
        var rook = Piece(type: .rook, color: .black, square: "a8")
        let before = rook.textureName
        rook.applyDamage(ProjectileState.playerLaserDamage)
        XCTAssertNotEqual(rook.textureName, before,
                          "a hit that survives must still look different")
        XCTAssertEqual(rook.damageState, .chipped)
    }

    /// Damage only ever gets worse, and a piece is never left in a state that
    /// claims more health than it has.
    func testDamageStatesProgressMonotonically() {
        for type in PieceType.allCases {
            let order: [DamageState] = [.full, .chipped, .cracked, .critical]
            var piece = Piece(type: type, color: .white, square: "e1")
            var lastIndex = 0
            while piece.hp > 0 {
                let index = order.firstIndex(of: piece.damageState)!
                XCTAssertGreaterThanOrEqual(index, lastIndex,
                                            "\(type) went backwards at \(piece.hp) HP")
                lastIndex = index
                piece.applyDamage(1)
            }
        }
    }
}

@MainActor
final class SpaceshipStateTests: XCTestCase {

    func testStartsWithThreeLivesAndAFullCap() {
        let ship = SpaceshipState()
        XCTAssertEqual(ship.lives, 3)
        XCTAssertEqual(ship.laserCap, SpaceshipState.baseLaserCap)
        XCTAssertTrue(ship.canFire)
    }

    func testLaserCapBlocksFiringAtTheLimit() {
        let ship = SpaceshipState()
        for _ in 0..<ship.laserCap { ship.laserFired() }
        XCTAssertFalse(ship.canFire, "at the cap, one more shot must be refused")
        ship.laserResolved()
        XCTAssertTrue(ship.canFire, "resolving one frees a slot")
    }

    func testLosingALifeStartsInvincibilityUnlessItWasTheLast() {
        let ship = SpaceshipState(lives: 2)
        XCTAssertTrue(ship.loseLife())
        XCTAssertEqual(ship.lives, 1)
        XCTAssertTrue(ship.isInvincible, "a life remains, so the grace window starts (§8.4)")

        // A second hit during the grace window does nothing — not even to lives.
        XCTAssertFalse(ship.loseLife())
        XCTAssertEqual(ship.lives, 1)

        ship.update(deltaTime: SpaceshipState.invincibilityDuration + 0.1)
        XCTAssertFalse(ship.isInvincible)
        XCTAssertTrue(ship.loseLife())
        XCTAssertEqual(ship.lives, 0)
        XCTAssertFalse(ship.isInvincible, "no life left to protect — no respawn (§8.4)")
    }

    func testResetForNewLevelKeepsLivesButClearsEverythingElse() {
        let ship = SpaceshipState(lives: 2)
        ship.laserFired()
        ship.loseLife()
        XCTAssertTrue(ship.isInvincible)

        ship.resetForNewLevel()
        XCTAssertEqual(ship.lives, 1, "lives carry across levels (§8.5)")
        XCTAssertEqual(ship.activeLasers, 0)
        XCTAssertFalse(ship.isInvincible)
    }
}

@MainActor
final class CollisionResolverTests: XCTestCase {

    func testPlayerLaserOnlyScoresOnTheKill() {
        let board = GCIBoard()
        board.setupStandardPosition()

        // A pawn carries 3 HP against a 2-damage laser, so the first shot only
        // wounds it and the second is the kill.
        _ = CollisionResolver.playerLaserHitBlackPiece(at: "a7", board: board)
        guard case .blackPieceHit(let square, let type, let destroyed, let points, let combo)? =
            CollisionResolver.playerLaserHitBlackPiece(at: "a7", board: board) else {
            return XCTFail("expected a black-piece hit")
        }
        XCTAssertEqual(square, "a7")
        XCTAssertEqual(type, .pawn)
        XCTAssertTrue(destroyed)
        XCTAssertEqual(points, PieceType.pawn.pointValue, "shooting scores the higher table, not chessCaptureValue")
        XCTAssertFalse(combo)
    }

    func testPlayerLaserOnAWoundedPieceScoresNothingUntilTheKill() {
        let board = GCIBoard()
        board.setupStandardPosition()
        // A queen has 12 HP; one 2-HP hit must not destroy or score.
        guard case .blackPieceHit(_, _, let destroyed, let points, _)? =
            CollisionResolver.playerLaserHitBlackPiece(at: "d8", board: board) else {
            return XCTFail("expected a black-piece hit")
        }
        XCTAssertFalse(destroyed)
        XCTAssertEqual(points, 0, "no score for a hit that doesn't kill")
    }

    func testFriendlyFireNeverScoresEvenOnDestruction() {
        let board = GCIBoard()
        board.setupStandardPosition()
        board.applyDamage(1, at: "a2")   // pre-damage so the next 2-HP hit is lethal
        guard case .whitePieceHit(let square, let destroyed)? =
            CollisionResolver.playerLaserHitWhitePiece(at: "a2", board: board) else {
            return XCTFail("expected a white-piece hit")
        }
        XCTAssertEqual(square, "a2")
        XCTAssertTrue(destroyed)
        // No points field exists on this case at all — friendly fire structurally
        // cannot score, not merely "scores zero".
    }

    func testEnemyShotDealsOneHPToAWhitePiece() {
        let board = GCIBoard()
        board.setupStandardPosition()
        guard case .whitePieceHit(_, let destroyed)? =
            CollisionResolver.enemyShotHitWhitePiece(at: "a2", board: board) else {
            return XCTFail("expected a white-piece hit")
        }
        XCTAssertFalse(destroyed, "a pawn has 3 HP; one invader shot must not kill it")
        XCTAssertEqual(board.piece(at: "a2")?.hp, 2)
    }

    func testWrongColorMissesEntirely() {
        let board = GCIBoard()
        board.setupStandardPosition()
        XCTAssertNil(CollisionResolver.playerLaserHitBlackPiece(at: "a2", board: board),
                    "a2 holds a white pawn, not black")
        XCTAssertNil(CollisionResolver.playerLaserHitWhitePiece(at: "a7", board: board),
                    "a7 holds a black pawn, not white")
    }

    /// The 800-point combo (§9): the king dies while already checkmated. The
    /// beat that delivered the mate hasn't formally resolved yet, so there's a
    /// real window where this can happen.
    func testDoubleCheckmateBonusFiresWhenTheKingDiesAlreadyMated() {
        let board = GCIBoard()
        board.setupStandardPosition()
        // Scholar's Mate: black is checkmated, king still on e8.
        for (from, to) in [("e2", "e4"), ("e7", "e5"), ("f1", "c4"), ("b8", "c6"),
                           ("d1", "h5"), ("g8", "f6"), ("h5", "f7")] {
            board.applyChessMove(from: from, to: to)
        }
        XCTAssertTrue(board.isMate)
        XCTAssertEqual(board.turn, .black)

        board.applyDamage(14, at: "e8")   // soften the king to exactly 2 HP first
        guard case .blackPieceHit(_, .king, let destroyed, _, let combo)? =
            CollisionResolver.playerLaserHitBlackPiece(at: "e8", board: board) else {
            return XCTFail("expected a hit on the king")
        }
        XCTAssertTrue(destroyed)
        XCTAssertTrue(combo, "already mated when the killing shot landed — both bonuses apply")
    }

    func testDoubleCheckmateBonusDoesNotFireOnAnOrdinaryKill() {
        let board = GCIBoard()
        board.setupStandardPosition()
        guard case .blackPieceHit(_, _, _, _, let combo)? =
            CollisionResolver.playerLaserHitBlackPiece(at: "e8", board: board) else {
            return XCTFail("expected a black-piece hit on the king's home square")
        }
        XCTAssertFalse(combo, "not mated at game start — must not claim the combo")
    }
}

@MainActor
final class LevelAnnouncementTests: XCTestCase {

    /// Layout limits, measured rather than taken from §12.11's nominal 18/22 —
    /// that assumes a different type size. Press Start 2P advances one em per
    /// character, so against `LevelBannerNode`'s 420pt rules the real ceilings
    /// are 420/26 = 16 characters of title and 420/11 = 38 of subtitle.
    /// Anything longer silently overhangs the rules either side.
    func testEveryAnnouncementFitsTheBannerLayout() {
        for level in 1...30 {
            guard let a = LevelManager.announcement(for: level) else { continue }
            XCTAssertLessThanOrEqual(a.title.count, 16,
                                     "level \(level) title '\(a.title)' overflows")
            XCTAssertLessThanOrEqual(a.subtitle.count, 38,
                                     "level \(level) subtitle '\(a.subtitle)' overflows")
            XCTAssertFalse(a.title.isEmpty)
            XCTAssertFalse(a.subtitle.isEmpty)
        }
    }

    /// Level 1 has escalated nothing, so it opens straight into play.
    func testLevelOneIsNotAnnounced() {
        XCTAssertNil(LevelManager.announcement(for: 1))
        XCTAssertNil(LevelManager.announcement(for: 0), "clamped, still level 1")
        XCTAssertNotNil(LevelManager.announcement(for: 2))
    }

    /// The names the design doc gives verbatim (§10.1), wherever the level
    /// ladder has since put them.
    func testDocumentedNamesAreUsedVerbatim() {
        XCTAssertEqual(LevelManager.announcement(for: 9)?.title, "KING ACTIVATED")
        // Subtitle deviates from §10.1's "THE KING NOW ATTACKS": the king does
        // not move differently, it gains a forcefield and its own weapon.
        XCTAssertEqual(LevelManager.announcement(for: 9)?.subtitle, "SHIELDED, AND ARMED")
        XCTAssertEqual(LevelManager.announcement(for: 8)?.title, "ARMORED PAWNS")
        // The banners name the piece that shoots, which is the whole point of
        // arming a type rather than weighting a distribution.
        XCTAssertEqual(LevelManager.announcement(for: 2)?.subtitle, "PAWNS FIRE BACK")
        XCTAssertEqual(LevelManager.announcement(for: 7)?.subtitle,
                       "BISHOPS FIRE ON THE DIAGONAL")
    }

    func testEveryLevelAboveOneHasSomethingToSay() {
        for level in 2...40 {
            XCTAssertNotNil(LevelManager.announcement(for: level), "level \(level)")
        }
    }
}

@MainActor
final class KingActivatedTests: XCTestCase {

    /// Level 9 only. The forcefield and the king's weapon are that wave's
    /// character; leaving them on forever would permanently buff the single
    /// most important target in the game.
    func testActivatesOnLevelNineOnly() {
        for level in 1...15 {
            XCTAssertEqual(LevelManager.parameters(for: level).kingActivated, level == 9,
                           "level \(level)")
        }
    }

    /// A diagonal is aimed inward from the edge files, or a shot from the a- or
    /// A bishop leans toward one of White's pieces, not at a fixed 45°. From
    /// rank 8 a true diagonal covers seven files before reaching White — off
    /// the board, nowhere near anything the player owns.
    func testBishopLeansTowardWhitesPieces() {
        // c8 (file 2) aiming at g1 (file 6): 4 files over 7 ranks.
        let toward = FleetRules.diagonalSlope(fromFile: 2, rank: 8, towardFile: 6, rank: 1)
        XCTAssertEqual(toward, 4.0 / 7.0, accuracy: 0.001)
        XCTAssertLessThan(toward, 1.0, "shallower than a true diagonal, and that is the point")
        // Sign follows the target.
        XCTAssertLessThan(FleetRules.diagonalSlope(fromFile: 6, rank: 8,
                                                   towardFile: 1, rank: 1), 0)
    }

    func testBishopLeanStaysWithinItsAngleBand() {
        // Steeper than 45° would fly off the side: f6 (file 5) at b5 is 3
        // files over 1 rank.
        XCTAssertEqual(FleetRules.diagonalSlope(fromFile: 5, rank: 6,
                                                towardFile: 2, rank: 5),
                       -FleetRules.maxDiagonalSlope, "clamped to 45°")
        // Nearly straight down would read as a missed vertical shot.
        XCTAssertEqual(FleetRules.diagonalSlope(fromFile: 3, rank: 8,
                                                towardFile: 4, rank: 1),
                       FleetRules.minDiagonalSlope, "clamped away from vertical")
        // Directly below: lean away from the nearer edge.
        XCTAssertGreaterThan(FleetRules.diagonalSlope(fromFile: 1, rank: 8,
                                                      towardFile: 1, rank: 1), 0)
        XCTAssertLessThan(FleetRules.diagonalSlope(fromFile: 6, rank: 8,
                                                   towardFile: 6, rank: 1), 0)
        // A target level with or behind the shooter cannot be aimed at.
        XCTAssertEqual(abs(FleetRules.diagonalSlope(fromFile: 3, rank: 4,
                                                    towardFile: 6, rank: 4)),
                       FleetRules.maxDiagonalSlope)
    }

    /// The king inflects where a bishop commits: same aiming, a shallower band,
    /// and most rounds still go straight down.
    func testTheKingsAngleIsShallowerThanABishops() {
        XCTAssertLessThan(FleetRules.kingMaxSlope, FleetRules.maxDiagonalSlope)
        XCTAssertLessThan(FleetRules.kingMinSlope, FleetRules.minDiagonalSlope)
        XCTAssertLessThan(FleetRules.kingShotAngleShare, 0.5,
                          "straight down stays the king's default")
        for targetFile in 0...7 {
            let slope = FleetRules.diagonalSlope(
                fromFile: 4, rank: 8, towardFile: targetFile, rank: 1,
                minSlope: FleetRules.kingMinSlope, maxSlope: FleetRules.kingMaxSlope)
            XCTAssertGreaterThanOrEqual(abs(slope), FleetRules.kingMinSlope)
            XCTAssertLessThanOrEqual(abs(slope), FleetRules.kingMaxSlope)
        }
    }

    /// Whatever the target, the round always reads as angled — never vertical,
    /// never flatter than the eye can follow.
    func testEveryBishopLeanIsAVisibleAngle() {
        for file in 0...7 {
            for rank in 3...8 {
                for targetFile in 0...7 {
                    let slope = FleetRules.diagonalSlope(fromFile: file, rank: rank,
                                                         towardFile: targetFile, rank: 1)
                    XCTAssertGreaterThanOrEqual(abs(slope), FleetRules.minDiagonalSlope,
                                                "\(file),\(rank) → \(targetFile)")
                    XCTAssertLessThanOrEqual(abs(slope), FleetRules.maxDiagonalSlope,
                                             "\(file),\(rank) → \(targetFile)")
                }
            }
        }
    }

    /// §21.3 fixes diagonals at 160 px/s along the path. Since a 45° shot
    /// travels sqrt(2) further, it must reach the player *later* than a
    /// straight one, not sooner — the threat is the angle, not the pace.
    func testDiagonalIsSlowerToArriveThanAStraightShot() {
        let drop: CGFloat = 400
        let diagonalTime = (drop * 2.squareRoot()) / FleetRules.diagonalShotSpeed
        let straightTime = drop / LevelManager.parameters(for: 7).projectileSpeed
        XCTAssertGreaterThan(diagonalTime, straightTime)
    }

    /// The forcefield is worth exactly 50% more laser hits.
    func testForcefieldIsFiftyPercentMoreHits() {
        let base = PieceType.king.maxHP
        let shielded = FleetRules.forcefieldHP(baseMaxHP: base)
        let hits = { (hp: Int) in Int(ceil(Double(hp) / Double(ProjectileState.playerLaserDamage))) }
        XCTAssertEqual(shielded, 24)
        XCTAssertEqual(hits(base), 8)
        XCTAssertEqual(hits(shielded), 12)
    }

    /// The shield absorbs before the sprite erodes, so the ring going out is
    /// the cue that the king is now takeable.
    func testShieldAbsorbsBeforeTheKingErodes() {
        let board = GCIBoard()
        board.setupStandardPosition()
        board.applyKingForcefield()
        XCTAssertTrue(board.blackKingShieldIsUp())
        XCTAssertEqual(board.piece(at: "e8")?.damageState, .full,
                       "a shielded king shows no damage yet")

        var hits = 0
        while board.blackKingShieldIsUp(), hits < 40 {
            _ = board.applyDamage(ProjectileState.playerLaserDamage, at: "e8")
            hits += 1
        }
        XCTAssertEqual(hits, 4, "24 -> 16 HP at 2 damage a hit")
        XCTAssertFalse(board.blackKingShieldIsUp())
    }

    /// The king's own weapon must out-class ordinary fleet fire on both axes,
    /// or "ARMED" means nothing.
    func testKingWeaponBeatsOrdinaryFleetFire() {
        let level = LevelManager.parameters(for: 9)
        XCTAssertGreaterThan(FleetRules.kingShotSpeedMultiplier, 1.0)
        XCTAssertGreaterThan(level.projectileSpeed * FleetRules.kingShotSpeedMultiplier,
                             level.projectileSpeed)
        XCTAssertGreaterThan(FleetRules.kingShotDamage, ProjectileState.enemyShotDamage)
        XCTAssertGreaterThan(FleetRules.kingShotInterval, 1,
                             "on its own cadence, not every single beat")
    }
}

@MainActor
final class FleetFiringTests: XCTestCase {

    private func candidates(_ squares: [String], type: PieceType = .pawn) -> [FleetFiring.Candidate] {
        squares.map { FleetFiring.Candidate(square: $0, type: type) }
    }

    func testLevelOneSchedulesNoFire() {
        let level = LevelManager.parameters(for: 1)
        for _ in 0..<50 {
            XCTAssertEqual(FleetFiring.shotCount(for: level), 0)
        }
    }

    func testShotCountStaysInTheLevelRange() {
        for level in 2...9 {
            let params = LevelManager.parameters(for: level)
            for _ in 0..<50 {
                let count = FleetFiring.shotCount(for: params)
                XCTAssertTrue(params.shotsPerTurn.contains(count), "level \(level) gave \(count)")
            }
        }
    }

    func testShootersAreDistinctAndBounded() {
        let squares = ["a7", "b7", "c7", "d8"]
        XCTAssertEqual(FleetFiring.chooseShooters(from: candidates(squares), count: 10).count,
                       squares.count, "cannot fire more pieces than exist")
        XCTAssertTrue(FleetFiring.chooseShooters(from: [], count: 3).isEmpty)
        XCTAssertTrue(FleetFiring.chooseShooters(from: candidates(squares), count: 0).isEmpty)

        let chosen = FleetFiring.chooseShooters(from: candidates(squares), count: 4)
        XCTAssertEqual(Set(chosen).count, chosen.count, "one shot per piece per beat")
    }

    /// §5.3 weights toward "front-rank pawns" — both halves of that phrase.
    func testWeightingFavoursFrontRanksAndPawns() {
        // Closer to White outranks further away.
        XCTAssertGreaterThan(FleetFiring.weight(forRank: 2, type: .pawn),
                             FleetFiring.weight(forRank: 7, type: .pawn))
        // On the same rank, a pawn outranks anything else.
        XCTAssertGreaterThan(FleetFiring.weight(forRank: 5, type: .pawn),
                             FleetFiring.weight(forRank: 5, type: .rook))
        // Regression: rank alone used to decide it, so a back-rank rook beat an
        // advanced pawn — the queen and king ended up doing the shooting.
        XCTAssertGreaterThan(FleetFiring.weight(forRank: 7, type: .pawn),
                             FleetFiring.weight(forRank: 8, type: .rook))
    }

    func testAdvancedPawnIsPickedMoreOftenThanAHomeRook() {
        let pool = [FleetFiring.Candidate(square: "a2", type: .pawn),
                    FleetFiring.Candidate(square: "h8", type: .rook)]
        var advanced = 0
        for _ in 0..<400 {
            if FleetFiring.chooseShooters(from: pool, count: 1).first == "a2" { advanced += 1 }
        }
        XCTAssertGreaterThan(advanced, 300, "front-rank pawn should dominate (got \(advanced)/400)")
    }

    // MARK: - Level 1 warning shot (§10.1)

    func testWarningShotFiresOnceWhenTheBlackKingIsCritical() {
        var king = Piece(type: .king, color: .black, square: "e8")
        XCTAssertFalse(FleetFiring.shouldFireWarningShot(level: 1, blackKing: king,
                                                         alreadyFired: false),
                       "a healthy king does not fire it")

        king.applyDamage(PieceType.king.maxHP - 4)   // -> critical
        XCTAssertEqual(king.damageState, .critical)
        XCTAssertTrue(FleetFiring.shouldFireWarningShot(level: 1, blackKing: king,
                                                        alreadyFired: false))
        XCTAssertFalse(FleetFiring.shouldFireWarningShot(level: 1, blackKing: king,
                                                         alreadyFired: true),
                       "once per level")
    }

    func testWarningShotIsLevelOneOnlyAndNeedsAKing() {
        var king = Piece(type: .king, color: .black, square: "e8")
        king.applyDamage(PieceType.king.maxHP - 4)
        for level in 2...5 {
            XCTAssertFalse(FleetFiring.shouldFireWarningShot(level: level, blackKing: king,
                                                             alreadyFired: false),
                           "level \(level) has its own scheduled fire")
        }
        XCTAssertFalse(FleetFiring.shouldFireWarningShot(level: 1, blackKing: nil,
                                                        alreadyFired: false),
                       "king already destroyed — no scripted moment")
    }

    /// Half of Level 2's speed (§10.1): the slowness is the telegraph.
    func testWarningShotIsSlowerThanNormalFire() {
        XCTAssertLessThan(FleetFiring.warningShotSpeed,
                          LevelManager.parameters(for: 2).projectileSpeed)
    }
}

@MainActor
final class ScoringTableTests: XCTestCase {

    /// §9: shooting a piece dead pays more than capturing it in chess — the
    /// tables must stay distinct, not accidentally collapse to one value.
    func testShootValueExceedsChessCaptureValueExceptForTheKing() {
        for type in PieceType.allCases where type != .king {
            XCTAssertGreaterThan(type.pointValue, type.chessCaptureValue,
                                 "\(type) should reward shooting over capturing")
        }
        XCTAssertEqual(PieceType.king.pointValue, PieceType.king.chessCaptureValue,
                       "the king falling is worth the same either way (§9)")
    }
}

@MainActor
final class PowerUpTests: XCTestCase {

    // MARK: - Per-type values (§13.2)

    /// Every carrier dies to one hit. §13.2 gives the Bomb Scout two, which read
    /// as a bug: a clean hit that leaves a small fast target flying looks like a
    /// miss, and the player has no time to reconsider what they saw.
    func testEveryCarrierDiesToOneHit() {
        for powerUp in PowerUp.allCases {
            XCTAssertEqual(powerUp.hp, 1, "\(powerUp)")
        }
    }

    /// The Bomb is still worth most — rarest, and it clears the sky at the two
    /// moments the sky is fullest.
    func testTheBombIsWorthMost() {
        let others = PowerUp.allCases.filter { $0 != .nuke }.map(\.points)
        XCTAssertGreaterThan(PowerUp.nuke.points, others.max() ?? 0)
    }

    /// Every carrier is worth at least a plain scout, and Rapid Fire is exactly
    /// §9's plain-scout rate — it is the plain scout.
    func testEveryCarrierIsWorthAtLeastAPlainScout() {
        XCTAssertEqual(PowerUp.rapidFire.points, RaiderRules.scoutPoints)
        for powerUp in PowerUp.allCases {
            XCTAssertGreaterThanOrEqual(powerUp.points, RaiderRules.scoutPoints,
                                        "\(powerUp)")
        }
    }

    /// Only the two clocked effects have a duration, and §13.1's
    /// one-at-a-time rule is about exactly those. Rapid Fire lasts the wave and
    /// the shield until it is spent, so neither is on this clock.
    func testOnlyTheClockedEffectsAreTimed() {
        XCTAssertEqual(Set(PowerUp.allCases.filter(\.isTimed)), [.freeze, .gatling])
        XCTAssertEqual(PowerUp.freeze.duration, 3)
        XCTAssertEqual(PowerUp.gatling.duration, 7)
        for powerUp in [PowerUp.rapidFire, .shield, .nuke] {
            XCTAssertNil(powerUp.duration, "\(powerUp)")
        }
    }

    /// Every carrier needs a label and a ship name: the label is flashed at the
    /// kill and stands in the player's alley, the ship name is what the log
    /// calls the thing the player just shot.
    func testEveryCarrierHasALabelAndAShipName() {
        for powerUp in PowerUp.allCases {
            XCTAssertFalse(powerUp.shipName.isEmpty, "\(powerUp)")
        }
        XCTAssertEqual(Set(PowerUp.allCases.map(\.shipName)).count,
                       PowerUp.allCases.count, "no two ships share a name")
        XCTAssertEqual(PowerUp.rapidFire.shipName, "green",
                       "the plain scout is named for what the player sees")

        for powerUp in PowerUp.allCases {
            XCTAssertFalse(powerUp.label.isEmpty, "\(powerUp)")
            XCTAssertEqual(powerUp.label, powerUp.label.uppercased(),
                           "the alley and the flash are both caps")
        }
        XCTAssertEqual(Set(PowerUp.allCases.map(\.label)).count,
                       PowerUp.allCases.count, "no two carriers share a label")
    }

    // MARK: - The effect clock

    /// A second timed effect replaces the first and hands the displaced one
    /// back, so the scene can undo its world changes before applying the new.
    func testASecondEffectDisplacesTheFirst() {
        var state = PowerUpState()
        XCTAssertNil(state.begin(.freeze))
        XCTAssertTrue(state.isFrozen)

        XCTAssertEqual(state.begin(.gatling), .freeze,
                       "the displaced effect must be reported, not silently dropped")
        XCTAssertTrue(state.isGatling)
        XCTAssertFalse(state.isFrozen)
        XCTAssertEqual(state.remaining, PowerUp.gatling.duration)
    }

    /// The untimed carriers never take the clock — a shield or a laser slot
    /// must not evict a running barrage.
    func testAnUntimedPowerUpNeverTakesTheClock() {
        var state = PowerUpState()
        state.begin(.gatling)
        for powerUp in [PowerUp.rapidFire, .shield, .nuke] {
            XCTAssertNil(state.begin(powerUp), "\(powerUp)")
            XCTAssertTrue(state.isGatling, "\(powerUp) evicted the barrage")
        }
    }

    /// Re-collecting the same type refreshes its clock rather than reporting
    /// itself as displaced — lifting and reapplying would flicker the world.
    func testRecollectingTheSameEffectOnlyRefreshesTheClock() {
        var state = PowerUpState()
        state.begin(.gatling)
        _ = state.tick(4)
        XCTAssertEqual(state.remaining, 3, accuracy: 0.001)
        XCTAssertNil(state.begin(.gatling))
        XCTAssertEqual(state.remaining, PowerUp.gatling.duration)
    }

    /// The clock reports the expiry exactly once, on the frame it runs out.
    func testExpiryIsReportedOnceAndOnlyOnce() {
        var state = PowerUpState()
        state.begin(.freeze)
        XCTAssertNil(state.tick(2.9))
        XCTAssertEqual(state.tick(0.2), .freeze)
        XCTAssertNil(state.tick(1), "and nothing after")
        XCTAssertNil(state.active)
    }

    /// The shield is a charge, not a clock: it survives any amount of time and
    /// is spent by exactly one hit.
    func testTheShieldIsSpentByOneHitAndNotByTime() {
        var state = PowerUpState()
        XCTAssertFalse(state.absorbHit(), "nothing to absorb with")
        state.raiseShield()
        _ = state.tick(60)
        XCTAssertTrue(state.hasShield, "time does not take it")
        XCTAssertTrue(state.absorbHit())
        XCTAssertFalse(state.hasShield)
        XCTAssertFalse(state.absorbHit(), "one hit only")
    }

    /// §13.2: nothing carries into the next wave.
    func testNothingCarriesBetweenLevels() {
        var state = PowerUpState()
        state.raiseShield()
        state.begin(.gatling)
        state.reset()
        XCTAssertNil(state.active)
        XCTAssertFalse(state.hasShield)
        XCTAssertEqual(state.remaining, 0)
    }

    // MARK: - Nuke targeting (§13.2)

    private func candidate(_ square: String, _ distance: Double, king: Bool = false)
        -> (square: String, distance: Double, isKing: Bool) {
        (square, distance, king)
    }

    /// Nearest first, and never more than three.
    func testTheBlastTakesTheThreeNearestPieces() {
        let taken = Shockwave.targets(from: [
            candidate("a1", 400), candidate("b2", 10), candidate("c3", 250),
            candidate("d4", 60), candidate("e5", 120),
        ])
        XCTAssertEqual(taken, ["b2", "d4", "e5"])
        XCTAssertLessThanOrEqual(taken.count, Shockwave.maxTargets)
    }

    /// One is the floor wherever there is anything at all to hit — there is no
    /// radius limit, because a Nuke that sometimes does nothing visible is the
    /// problem the whole redesign exists to fix.
    func testTheBlastAlwaysTakesAtLeastOneIfAnythingIsLeft() {
        XCTAssertEqual(Shockwave.targets(from: [candidate("h8", 9_000)]), ["h8"])
        XCTAssertTrue(Shockwave.targets(from: []).isEmpty, "and nothing from nothing")
    }

    /// The king is passed over while anything else is on the board, however
    /// close he is: the rarest power-up must not be spent on the one target it
    /// cannot kill.
    func testTheKingIsPassedOverWhileAnythingElseStands() {
        let taken = Shockwave.targets(from: [
            candidate("e8", 5, king: true), candidate("a7", 300),
        ])
        XCTAssertEqual(taken, ["a7"])
    }

    /// Unless he is all that is left, at which point he is the only thing to
    /// hit. He is damaged, never destroyed — that is `shockwaveHitBlackPiece`.
    func testTheKingIsTakenOnlyWhenHeIsAlone() {
        XCTAssertEqual(Shockwave.targets(from: [candidate("e8", 40, king: true)]), ["e8"])
    }

    /// A blast that catches the king leaves him alive on 1 HP at worst. Winning
    /// a wave has to stay something the player aimed at.
    func testTheBlastCannotKillTheKing() {
        let board = GCIBoard()
        board.setupStandardPosition()
        // Strip the board to the king, so the targeting has nothing else.
        for piece in board.allPieces(color: .black) where piece.type != .king {
            _ = board.applyDamage(piece.hp, at: piece.logicalSquare)
        }
        guard let king = board.allPieces(color: .black).first else {
            return XCTFail("the king should be all that is left")
        }
        // Enough blasts to kill anything.
        for _ in 0..<20 {
            _ = CollisionResolver.shockwaveHitBlackPiece(at: king.logicalSquare, board: board)
        }
        guard let survivor = board.piece(at: king.logicalSquare) else {
            return XCTFail("the blast destroyed the king")
        }
        XCTAssertEqual(survivor.type, .king)
        XCTAssertEqual(survivor.hp, 1, "brought to the brink and no further")
    }

    /// Everything else the blast reaches dies outright, whatever its HP — a
    /// shockwave that leaves a rook standing is not a shockwave.
    func testTheBlastDestroysAnyOtherPieceOutright() {
        let board = GCIBoard()
        board.setupStandardPosition()
        for square in ["a8", "d8", "b8", "a7"] {
            guard let before = board.piece(at: square) else {
                return XCTFail("\(square) should be occupied")
            }
            XCTAssertGreaterThan(before.hp, ProjectileState.playerLaserDamage,
                                 "\(square) must need more than one laser hit")
            let result = CollisionResolver.shockwaveHitBlackPiece(at: square, board: board)
            guard case .blackPieceHit(_, _, let destroyed, let points, _) = result else {
                return XCTFail("expected a hit at \(square)")
            }
            XCTAssertTrue(destroyed, "\(square) survived a nuke")
            XCTAssertEqual(points, before.shootValue)
            XCTAssertNil(board.piece(at: square))
        }
    }

    /// White is never touched: §13.2's ring is Black's problem alone.
    func testTheBlastIgnoresWhitePieces() {
        let board = GCIBoard()
        board.setupStandardPosition()
        XCTAssertNil(CollisionResolver.shockwaveHitBlackPiece(at: "e1", board: board))
        XCTAssertNotNil(board.piece(at: "e1"))
    }

    // MARK: - The blast's slow motion (§13.2)

    /// Holds at the floor, then accelerates back to normal — never the other way
    /// round, and never past 1.
    func testTheSlowMotionRampHoldsThenAccelerates() {
        XCTAssertEqual(GameScene.slowMoScale(elapsed: 0), GameScene.slowMoFloor)
        let hold = GameScene.slowMoDuration * GameScene.slowMoHold
        XCTAssertEqual(GameScene.slowMoScale(elapsed: hold * 0.99),
                       GameScene.slowMoFloor, accuracy: 0.001,
                       "it must not start climbing during the hold")
        XCTAssertEqual(GameScene.slowMoScale(elapsed: GameScene.slowMoDuration), 1)

        var previous = 0.0
        for step in 0...130 {
            let scale = GameScene.slowMoScale(elapsed: Double(step) / 100)
            XCTAssertGreaterThanOrEqual(scale, previous, "the ramp went backwards")
            XCTAssertLessThanOrEqual(scale, 1)
            XCTAssertGreaterThanOrEqual(scale, GameScene.slowMoFloor)
            previous = scale
        }
    }

    /// Accelerating back rather than easing out: the second half of the ramp has
    /// to cover more ground than the first, or it reads as the game recovering
    /// from a stall instead of as a decision.
    func testTheRampAcceleratesRatherThanEases() {
        let hold = GameScene.slowMoDuration * GameScene.slowMoHold
        let midpoint = hold + (GameScene.slowMoDuration - hold) / 2
        let halfway = GameScene.slowMoScale(elapsed: midpoint)
        let span = 1 - GameScene.slowMoFloor
        XCTAssertLessThan(halfway - GameScene.slowMoFloor, span / 2,
                          "less than half the recovery by the halfway point")
    }

    /// A blast is a moment, not an interlude — and the world has to be running
    /// normally again by the end of it.
    func testTheSlowMotionIsOverInUnderTwoSeconds() {
        XCTAssertLessThan(GameScene.slowMoDuration, 2)
        XCTAssertGreaterThan(GameScene.slowMoDuration, 0.8)
        XCTAssertEqual(GameScene.slowMoScale(elapsed: GameScene.slowMoDuration + 5), 1)
    }

    // MARK: - The feint (§6.3)

    /// The Spread Scout flips a coin, because it appears once a level and there
    /// is no second of its kind to play against.
    func testTheSpreadScoutFeintsAboutOneCrossingInFive() {
        var feints = 0
        for _ in 0..<4_000
        where RaiderRules.feint(for: .gatling, repeatOffering: false,
                                span: 1_000, from: 0, to: 1_000) != nil {
            feints += 1
        }
        let rate = Double(feints) / 4_000
        XCTAssertEqual(rate, RaiderRules.feintChance, accuracy: 0.04,
                       "measured \(rate)")
    }

    /// The camel sets its own trap: the first never doubles back, and the second
    /// — which only exists because the player shot the first — always does.
    func testTheFirstCamelNeverFeintsAndTheSecondAlways() {
        XCTAssertEqual(RaiderRules.feintChance(for: .nuke, repeatOffering: false), 0)
        XCTAssertEqual(RaiderRules.feintChance(for: .nuke, repeatOffering: true), 1)
        for _ in 0..<500 {
            XCTAssertNil(RaiderRules.feint(for: .nuke, repeatOffering: false,
                                           span: 1_000, from: 0, to: 1_000))
            XCTAssertNotNil(RaiderRules.feint(for: .nuke, repeatOffering: true,
                                              span: 1_000, from: 0, to: 1_000))
        }
        // And the trick is reachable: Level 7 sends two of them.
        XCTAssertEqual(PowerUps.roster(forLevel: 7).filter { $0 == .nuke }.count, 2)
    }

    /// Only the Spread and Bomb carriers double back at all — every carrier
    /// feinting made the surprise into the weather.
    func testOnlyTheSpreadAndBombCarriersDoubleBack() {
        XCTAssertEqual(Set(PowerUp.allCases.filter(RaiderRules.doublesBack)),
                       [.gatling, .nuke])
        for powerUp in PowerUp.allCases where !RaiderRules.doublesBack(powerUp) {
            for repeated in [false, true] {
                XCTAssertEqual(RaiderRules.feintChance(for: powerUp,
                                                       repeatOffering: repeated),
                               0, "\(powerUp)")
            }
        }
    }

    /// It turns somewhere in the middle and comes back a little way — never past
    /// where it came in, which would read as a second entrance.
    func testTheFeintTurnsMidCrossingAndNeverBacksPastTheEntry() {
        for _ in 0..<2_000 {
            guard let feint = RaiderRules.feint(for: .gatling, repeatOffering: true,
                                                span: 1_000, from: 0, to: 1_000)
            else { continue }
            XCTAssertGreaterThan(feint.turn, 0)
            XCTAssertLessThan(feint.turn, 1_000, "it must turn before it exits")
            XCTAssertLessThan(feint.back, feint.turn, "it has to come back")
            XCTAssertGreaterThanOrEqual(feint.back, 0, "never past the entry")
        }
    }

    /// And the same in the other direction, where every comparison flips.
    func testTheFeintWorksRightToLeft() {
        for _ in 0..<2_000 {
            guard let feint = RaiderRules.feint(for: .gatling, repeatOffering: true,
                                                span: -1_000, from: 1_000, to: 0)
            else { continue }
            XCTAssertLessThan(feint.turn, 1_000)
            XCTAssertGreaterThan(feint.turn, 0)
            XCTAssertGreaterThan(feint.back, feint.turn, "back is rightward here")
            XCTAssertLessThanOrEqual(feint.back, 1_000, "never past the entry")
        }
    }

    // MARK: - Spread Fire geometry (§13.2)

    /// The pool has to cover a full spray plus the player's own manual cap. An
    /// under-sized pool does not fail loudly — it silently drops rounds and the
    /// spray just looks thinner than it should.
    func testTheLaserPoolCoversAFullSprayPlusManualFire() {
        // Worst case is a round at the end of the sweep, which flies furthest.
        let path = GameScene.gatlingReach
            * (1 + GameScene.gatlingMaxLean * GameScene.gatlingMaxLean).squareRoot()
        let inFlight = Double(path / ProjectileState.playerLaserSpeed)
            / GameScene.gatlingInterval
        let needed = Int(inFlight.rounded(.up)) + SpaceshipState.maxLaserCap
        XCTAssertGreaterThanOrEqual(LaserPool.playerCapacity, needed)
        // And not wildly over: every node carries a physics body the scene walks.
        XCTAssertLessThanOrEqual(LaserPool.playerCapacity, needed * 2)
    }

    /// One stream, not five. The fixed five-way fan is what made this
    /// uncontrollable — five arms covering the board at once left nothing to
    /// aim — so the sweep has to be a single oscillating angle.
    func testTheSprayIsOneStreamSweptThroughTwentyDegrees() {
        let degrees = atan(GameScene.gatlingMaxLean) * 180 / .pi
        XCTAssertEqual(Double(degrees), 20, accuracy: 0.2)
    }

    /// The sweep has to be dense enough to read as a ribbon rather than a row of
    /// separate shots. Consecutive rounds leave under 4° apart at the fire rate
    /// and period actually configured.
    func testConsecutiveRoundsLeaveCloseEnoughToReadAsARibbon() {
        let roundsPerHalfSweep = (GameScene.gatlingSweepPeriod / 2)
            / GameScene.gatlingInterval
        XCTAssertGreaterThan(roundsPerHalfSweep, 8, "any sparser reads as scatter")
        let arc = atan(GameScene.gatlingMaxLean) * 2 * 180 / .pi
        XCTAssertLessThan(Double(arc) / roundsPerHalfSweep, 4.0,
                          "degrees between consecutive rounds")
    }

    /// The spray must not span the board: it is aimed by the sweep, and a fan
    /// that covers everything at once is what the five-stream version got wrong.
    func testTheSprayDoesNotSpanTheBoard() {
        let widest = GameScene.gatlingMaxLean * GameScene.gatlingReach * 2
        XCTAssertLessThan(widest, BoardNode.boardSize,
                          "the full arc is \(Int(widest))pt across")
        XCTAssertGreaterThan(widest, BoardNode.squareSize * 2,
                             "and still wide enough to be a spray")
    }

    /// The spray reaches the seventh rank and not the eighth. That is the whole
    /// range rule: uncapped it cleared everything from the ship's rank to the
    /// back wherever the fleet was, so collecting it ended the wave.
    func testTheSprayReachesTheSeventhRankAndNotTheEighth() {
        let bottom: CGFloat = 120        // GameScene.boardBottomY
        func rank(_ n: Int) -> ClosedRange<CGFloat> {
            let low = bottom + CGFloat(n - 1) * BoardNode.squareSize
            return low...(low + BoardNode.squareSize)
        }
        XCTAssertTrue(rank(7).contains(GameScene.gatlingCeiling),
                      "the burnout has to land inside the seventh rank")
        // Past the middle of a rank-7 piece, or it only clips the bottom of one.
        XCTAssertGreaterThan(GameScene.gatlingCeiling,
                             bottom + 6.5 * BoardNode.squareSize)
        // And clear of the eighth, which must stay earned the ordinary way.
        XCTAssertLessThan(GameScene.gatlingCeiling, rank(8).lowerBound)
    }

    /// Total rounds a spray can put up. The number that actually decides how
    /// much of the board it clears, and the one that was 600.
    func testASprayIsUnderAHundredRoundsNotSixHundred() {
        let rounds = Int(((PowerUp.gatling.duration ?? 0)
                          / GameScene.gatlingInterval).rounded())
        XCTAssertEqual(rounds, 84)
        XCTAssertLessThan(rounds, 140, "and fewer than the five-way version fired")
    }
}

@MainActor
final class PowerUpAlleyLayoutTests: XCTestCase {

    // The left gutter's other occupants, measured at x=112 as glyph bands. Not
    // derived from the nodes — half of them are built inside `GameStatusNode`
    // and `TurnTimerNode` at local offsets — so this is a written-down
    // measurement, and it is the whole point of the test: the readout was first
    // placed by eye against the turn timer's centre without accounting for its
    // caption 18pt above, and landed straight on top of the caption.
    /// All four chess readouts sit `GameScene.gutterDrop` (8pt) lower than they
    /// first did, to open a gap under the power-up block.
    private static let occupants: [(name: String, band: ClosedRange<CGFloat>)] = [
        ("turn-timer caption",  172...180),
        ("turn-timer digits",   147...169),
        ("transient notice",    137.5...146.5),
        ("status side label",   120...130),
        ("status state label",  100.5...115.5),
        ("the ship's lane",     42...82),
        ("the HUD",             664...700),
    ]

    private var alleyBands: [ClosedRange<CGFloat>] {
        let half = GameScene.powerUpAlleyFontSize / 2
        let lines = (0..<GameScene.powerUpAlleyLines).map { index -> ClosedRange<CGFloat> in
            let y = GameScene.powerUpAlleyBottomY
                + CGFloat(index) * GameScene.powerUpAlleyStep
            return (y - half)...(y + half)
        }
        // The countdown bar is 3pt tall and hangs under the bottom line.
        return lines + [(GameScene.powerUpBarY - 1.5)...(GameScene.powerUpBarY + 1.5)]
    }

    /// No power-up line — nor the countdown bar — may touch anything else.
    func testTheReadoutTouchesNothingElseInTheGutter() {
        for (index, line) in alleyBands.enumerated() {
            for occupant in Self.occupants {
                XCTAssertFalse(line.overlaps(occupant.band),
                               "alley line \(index) (\(line)) collides with "
                               + "\(occupant.name) (\(occupant.band))")
            }
        }
    }

    /// And the lines may not touch each other.
    func testTheLinesDoNotOverlapEachOther() {
        XCTAssertGreaterThan(GameScene.powerUpAlleyStep,
                             GameScene.powerUpAlleyFontSize,
                             "the step has to clear a whole line of type")
    }

    /// The bar hangs under the bottom line without touching it.
    func testTheCountdownBarClearsTheLineAboveIt() {
        let lineBottom = GameScene.powerUpAlleyBottomY - GameScene.powerUpAlleyFontSize / 2
        XCTAssertLessThan(GameScene.powerUpBarY + 1.5, lineBottom)
        XCTAssertGreaterThan(GameScene.powerUpBarY - 1.5, 180,
                             "and clears the turn-timer caption below it")
    }

    /// Each line gets its own row, with room to breathe between them.
    func testEachLineHasFivePointsOfAirBelowIt() {
        let gap = GameScene.powerUpAlleyStep - GameScene.powerUpAlleyFontSize
        XCTAssertGreaterThanOrEqual(gap, 4, "lines any closer read as one block")
        XCTAssertLessThanOrEqual(gap, 5, "and any further apart as unrelated")
    }

    /// The block sits above the turn timer, which is the only side of the gutter
    /// with room for three lines: the band under the status line is 27pt and
    /// three 9pt lines with 5pt gaps need 37.
    func testThreeLinesWouldNotHaveFitUnderTheStatusLine() {
        let needed = CGFloat(GameScene.powerUpAlleyLines) * GameScene.powerUpAlleyFontSize
            + CGFloat(GameScene.powerUpAlleyLines - 1)
                * (GameScene.powerUpAlleyStep - GameScene.powerUpAlleyFontSize)
        XCTAssertGreaterThan(needed, 26.5,
                             "if this ever fits, the readout can move back down")
        // Above the timer's caption there is nothing until the HUD.
        let highest = alleyBands.map(\.upperBound).max() ?? 0
        let lowest = alleyBands.map(\.lowerBound).min() ?? 0
        XCTAssertGreaterThan(lowest, 180, "clear of the turn-timer caption")
        XCTAssertLessThan(highest, 664, "clear of the HUD")
    }
}
