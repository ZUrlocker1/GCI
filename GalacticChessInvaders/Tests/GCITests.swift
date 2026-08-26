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

    func testPawnMaxHP() {
        let pawn = Piece(type: .pawn, color: .white, square: "e2")
        XCTAssertEqual(pawn.hp, 2)
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
        rook.applyDamage(2)   // 6/8 HP = 75% — should still be full
        XCTAssertEqual(rook.damageState, .full)
        rook.applyDamage(2)   // 4/8 HP = 50% — chipped
        XCTAssertEqual(rook.damageState, .chipped)
    }

    func testDamageStateCracked() {
        var rook = Piece(type: .rook, color: .white, square: "a1")
        rook.applyDamage(4)   // 4/8 HP = 50%
        rook.applyDamage(2)   // 2/8 HP = 25%
        XCTAssertEqual(rook.damageState, .cracked)
    }

    func testDamageStateCritical() {
        var rook = Piece(type: .rook, color: .white, square: "a1")
        rook.applyDamage(7)   // 1/8 HP = 12.5%
        XCTAssertEqual(rook.damageState, .critical)
    }

    func testPawnDestroyedByOneLaserHit() {
        // Pawn HP=2, laser deals 2 damage → destroyed in 1 hit
        var pawn = Piece(type: .pawn, color: .black, square: "e7")
        let destroyed = pawn.applyDamage(2)
        XCTAssertTrue(destroyed)
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
        XCTAssertFalse(board.applyDamage(1, at: "a7"), "pawn has 2 HP")
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
        board.applyDamage(1, at: "a7")   // chip only — must not yet touch the engine
        XCTAssertEqual(board.currentPosition.board["a7"]?.kind, .pawn,
                       "a damaged-but-alive piece must still be on the engine's board")

        board.applyDamage(1, at: "a7")   // now destroyed
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

    /// The fleet slides between squares, so a drawn grid would misrepresent
    /// where pieces are. Nothing but interaction feedback may be rendered.
    func testDrawsNoGridOrLabels() {
        let board = BoardNode()
        var labels = 0
        var shapes = 0
        var stack = Array(board.children)
        while let node = stack.popLast() {
            if node is SKLabelNode { labels += 1 }
            if node is SKShapeNode { shapes += 1 }
            stack.append(contentsOf: node.children)
        }
        XCTAssertEqual(labels, 0, "no coordinate labels")
        // Only the selection outline plus the pooled dot/ring pair per marker.
        XCTAssertEqual(shapes, 1 + BoardNode.markerPoolSize * 2,
                       "no square fills, grid lines or border")
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
        let ten = LevelManager.parameters(for: 10)
        XCTAssertEqual(ten.blackMovesPerTurn, 3, "capped at 3")
        XCTAssertEqual(ten.shotsPerTurn, 3...3, "capped at 3")
        XCTAssertEqual(ten.turnTimer, 4, "floored at 4s")
        XCTAssertEqual(ten.raiderInterval, 6, "floored at 6s")
        XCTAssertEqual(ten.fleetSpeed, 110 + 75, "+15 per level past 5")
        XCTAssertGreaterThan(ten.projectileSpeed, LevelManager.parameters(for: 5).projectileSpeed)
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
        XCTAssertEqual(moves.count, 40, "engine stopped finding moves")

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
            XCTAssertTrue(labels.contains { $0.contains("001275") }, "\(outcome) score missing")
        }
    }

    /// Losing and winning must not both read "GAME OVER".
    func testWinAndLossReadDifferently() {
        XCTAssertEqual(GameOverNode.Outcome.whiteMated.headline, "GAME OVER")
        XCTAssertEqual(GameOverNode.Outcome.waveCleared(next: 2).headline, "YOU WIN")
        XCTAssertNotEqual(GameOverNode.Outcome.whiteMated.detail,
                          GameOverNode.Outcome.waveCleared(next: 2).detail)
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
            [.whiteMated, .stalemate, .waveCleared(next: 2),
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

    func testClearWipesTableAndStorage() {
        ScoreManager.shared.resetForNewGame()
        ScoreManager.shared.addPoints(500)
        ScoreManager.shared.submitHighScore(initials: "TEMP")
        ScoreManager.shared.clearHighScores()
        XCTAssertTrue(ScoreManager.shared.topHighScores(limit: 20).isEmpty)
        XCTAssertNil(UserDefaults.standard.data(forKey: "GCI_HighScores"))
    }

    func testEntriesSortAndKeepFullNames() {
        ScoreManager.shared.clearHighScores()
        for (name, score) in [("LOW", 100), ("ZACKURLO", 9000), ("MID", 3000)] {
            ScoreManager.shared.resetForNewGame()
            ScoreManager.shared.addPoints(score)
            ScoreManager.shared.submitHighScore(initials: name)
        }
        let top = ScoreManager.shared.topHighScores(limit: 5)
        XCTAssertEqual(top.map(\.score), [9000, 3000, 100])
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

    /// The readability invariant: a piece that drifts half a square sits on a
    /// file boundary and its square becomes genuinely ambiguous.
    func testSweepStaysWithinTheOwnFile() {
        XCTAssertLessThan(FleetRules.sweepAmplitudeRatio, 0.5)
        let amplitude = FleetRules.sweepAmplitude(squareSize: BoardNode.squareSize)
        XCTAssertLessThan(amplitude * 2, BoardNode.squareSize,
                          "total sweep must stay under one file width")
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

        // Drive one full rank descent directly, bypassing the animated timers.
        fleet.applyFullRankDescentForTesting()

        // e7's piece is now keyed at e6; the node is the same instance.
        let screenAfter = fleet.screenPosition(of: before)
        XCTAssertEqual(screenAfter.y, screenBefore.y - BoardNode.squareSize, accuracy: 0.5,
                       "should land exactly one rank lower on screen, with no extra jump")
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
        XCTAssertEqual(parent.children[0].children.count, 16)
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
        XCTAssertEqual(fleet.sweepWidth, BoardNode.squareSize * 0.7, accuracy: 0.001)

        let geometry = BoardNode()
        for piece in board.allPieces(color: .black) {
            if let centre = geometry.center(of: piece.logicalSquare) {
                fleet.adopt(PieceNode(piece: piece, squareSize: BoardNode.squareSize),
                            square: piece.logicalSquare, atLogicalCentre: centre)
            }
        }
        XCTAssertEqual(fleet.sweepWidth, BoardNode.squareSize * 0.7, accuracy: 0.001,
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
                       PhysicsCategory.enemyPiece | PhysicsCategory.friendlyPiece,
                       "a live player laser tests both piece colours (§8.3 firing lanes)")

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

    func testFiringIsRefusedWithoutRealSpeedOrDistance() {
        let laser = LaserNode(owner: .player)
        laser.fire(from: .zero, damage: 2, speed: 0, travelDistance: 400)
        XCTAssertFalse(laser.isActive, "zero speed would divide by zero for the duration")
        laser.fire(from: .zero, damage: 2, speed: 400, travelDistance: 0)
        XCTAssertFalse(laser.isActive, "nowhere to travel — nothing to fire")
    }
}

@MainActor
final class DamageStateTests: XCTestCase {

    /// §7.1's table, verbatim, as (piece, damage-taken, expected state). The
    /// ratio approximation this replaced was a full stage late on rook, queen
    /// and king — a rook's first hit still read as undamaged — so damage was
    /// invisible on exactly the pieces the player shoots most.
    func testDamageStatesMatchTheDesignTable() {
        let expectations: [(PieceType, Int, DamageState)] = [
            (.pawn, 0, .full), (.pawn, 1, .chipped),
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

        // Pawn has 2 HP; the laser deals 2, so one hit is already lethal.
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
        XCTAssertFalse(destroyed, "a pawn has 2 HP; one invader shot must not kill it")
        XCTAssertEqual(board.piece(at: "a2")?.hp, 1)
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
final class FleetFiringTests: XCTestCase {

    func testLevel1NeverFires() {
        let level = LevelManager.parameters(for: 1)
        for _ in 0..<50 {
            XCTAssertEqual(FleetFiring.shotCount(for: level), 0)
        }
    }

    func testShotCountStaysWithinTheLevelsRange() {
        let level = LevelManager.parameters(for: 4)   // 2...3
        for _ in 0..<100 {
            let count = FleetFiring.shotCount(for: level)
            XCTAssertTrue(level.shotsPerTurn.contains(count))
        }
    }

    func testChooseShootersNeverExceedsWhatsAvailable() {
        let squares = ["a7", "b6", "c5"]
        XCTAssertEqual(FleetFiring.chooseShooters(from: squares, count: 10).count, squares.count,
                       "can't choose more shooters than pieces exist")
        XCTAssertTrue(FleetFiring.chooseShooters(from: [], count: 3).isEmpty)
        XCTAssertTrue(FleetFiring.chooseShooters(from: squares, count: 0).isEmpty)
    }

    func testChooseShootersNeverPicksTheSameSquareTwice() {
        let squares = ["a5", "b4", "c3", "d2"]
        let chosen = FleetFiring.chooseShooters(from: squares, count: 4)
        XCTAssertEqual(Set(chosen).count, chosen.count)
    }

    /// Weighting is probabilistic, not absolute — pin the trend over many
    /// draws rather than a single outcome.
    func testChooseShootersLeansTowardTheFrontRank() {
        var frontRankPicks = 0
        var backRankPicks = 0
        let trials = 400
        for _ in 0..<trials {
            let picked = FleetFiring.chooseShooters(from: ["a2", "a8"], count: 1)
            if picked == ["a2"] { frontRankPicks += 1 }
            if picked == ["a8"] { backRankPicks += 1 }
        }
        XCTAssertGreaterThan(frontRankPicks, backRankPicks,
                             "rank 2 (weight 7) should be picked far more than rank 8 (weight 1)")
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
