// GameState.swift
// GKStateMachine states for the game lifecycle.
// Each state owns its enter/exit/update logic.
// States call back into GameScene via the typed gameScene computed property.

import GameplayKit
import SpriteKit

// MARK: - Base State

class GCIState: GKState {
    weak var scene: SKScene?
    init(scene: SKScene) { self.scene = scene }

    var gameScene: GameScene? { scene as? GameScene }
}

// MARK: - Title State

class TitleState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PlayingState.self
    }

    override func didEnter(from previousState: GKState?) {
        gameScene?.showTitleScreen()
        DiagnosticsLog.shared.log(.startup, "Title screen displayed")
    }

    override func willExit(to nextState: GKState) {
        gameScene?.hideTitleScreen()
    }
}

// MARK: - Playing State

class PlayingState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PausedState.self || stateClass == GameOverState.self
    }

    override func didEnter(from previousState: GKState?) {
        gameScene?.showPlaceholderBoard()   // Phase 0: placeholder; Phase 2.1: real board
        DiagnosticsLog.shared.log(.level, "Level 1 started")
        DiagnosticsLog.shared.log(.startup, "Board reset, 16 white + 16 black pieces placed")
        DiagnosticsLog.shared.log(.startup, "Spaceship positioned at centre")
    }

    override func update(deltaTime seconds: TimeInterval) {
        // Phase 2+: tick fleet controller, turn timer, etc.
    }
}

// MARK: - Paused State

class PausedState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PlayingState.self
    }

    override func didEnter(from previousState: GKState?) {
        gameScene?.showPausedOverlay()
    }

    override func willExit(to nextState: GKState) {
        gameScene?.hidePausedOverlay()
    }
}

// MARK: - Game Over State

class GameOverState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == TitleState.self || stateClass == PlayingState.self
    }

    override func didEnter(from previousState: GKState?) {
        let score = ScoreManager.shared.currentScore
        DiagnosticsLog.shared.log(.level, "GAME OVER — final score: \(score)")
        // Phase 2+: show GameOverScene with score tally and explosion
    }
}
