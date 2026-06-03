// GameAction.swift
// Platform-agnostic input abstraction. All input sources (keyboard, mouse,
// touch, gamepad) translate to GameAction before reaching game logic.
// This is the iOS portability seam — game logic never sees a KeyboardShortcut.

import Foundation
import CoreGraphics

enum GameAction {
    // Ship movement
    case moveLeft
    case moveRight
    case stopMoving

    // Shooting
    case fireLaser

    // Chess input
    case selectPieceAt(boardSquare: String)   // algebraic e.g. "e2"
    case movePieceTo(boardSquare: String)      // algebraic e.g. "e4"
    case deselectPiece

    // Game control
    case pause
    case resume
    case confirmStart
    case confirmRestart
    case returnToMenu
}
