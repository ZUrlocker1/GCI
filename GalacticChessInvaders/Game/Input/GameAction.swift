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
    /// The fire key was released. Ordinary fire is one shot per press and does
    /// not need this; §13.2's Spread Fire does, because it sprays for as long as
    /// the player holds the key down.
    case stopFiring

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
    case showInfo         // I · ⌘I · ? — opens How To Play and pauses play
    case dismissOverlay   // any key while How To Play is open

    // Dev / debug
    case toggleDiagnostics   // L key — shows/hides the diagnostics sidebar
}
