// GameState.swift
// GKStateMachine states for the game lifecycle.
// Each state owns its enter/exit/update logic.

import GameplayKit
import SpriteKit

// MARK: - Base State

class GCIState: GKState {
    weak var scene: SKScene?
    init(scene: SKScene) { self.scene = scene }
}

// MARK: - Title State

class TitleState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PlayingState.self
    }
    override func didEnter(from previousState: GKState?) {
        DiagnosticsLog.shared.log(.level, "State → TITLE")
        // Phase 0: show title text placeholder
        // Phase 1+: present TitleScene with fleet animation, high scores
    }
}

// MARK: - Playing State

class PlayingState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PausedState.self || stateClass == GameOverState.self
    }
    override func didEnter(from previousState: GKState?) {
        DiagnosticsLog.shared.log(.level, "State → PLAYING")
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
        DiagnosticsLog.shared.log(.level, "State → PAUSED")
    }
}

// MARK: - Game Over State

class GameOverState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == TitleState.self || stateClass == PlayingState.self
    }
    override func didEnter(from previousState: GKState?) {
        DiagnosticsLog.shared.log(.level, "State → GAME OVER — score: \(ScoreManager.shared.currentScore)")
        // Phase 1+: show GameOverScene
    }
}
