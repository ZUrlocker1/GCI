// GCITests.swift
// Unit tests for the game logic layer. SpriteKit-free.
// Run with ⌘U in Xcode.

import XCTest
@testable import GalacticChessInvaders

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

final class ScoreManagerTests: XCTestCase {

    override func setUp() {
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
