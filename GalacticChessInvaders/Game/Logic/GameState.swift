// GameState.swift
// GKStateMachine states for the game lifecycle.
// Each state owns its enter/exit/update logic.
// States call back into GameScene via the typed gameScene computed property.

import GameplayKit
import SpriteKit

// MARK: - Base State

// GCIState is always driven from GameScene.update() which is @MainActor.
// Override methods use MainActor.assumeIsolated because GKState's ObjC methods
// are nonisolated but callers always originate on the main actor.
@MainActor
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
        MainActor.assumeIsolated {
            gameScene?.showTitleScreen()
            // The one place the intro variant is decided. Everything inside the
            // run that follows — Settings, Info — reads what this settles on.
            MusicVariants.rollIntro()
            AudioManager.shared.playMusic(from: MusicVariants.introPool)
            DiagnosticsLog.shared.log(.startup, "Title screen")
        }
    }

    override func willExit(to nextState: GKState) {
        MainActor.assumeIsolated {
            gameScene?.hideTitleScreen()
        }
    }
}

// MARK: - Playing State

class PlayingState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PausedState.self || stateClass == GameOverState.self || stateClass == TitleState.self
    }

    override func didEnter(from previousState: GKState?) {
        // Resolve outside the closure: GKState is not Sendable, so capturing
        // previousState in a main-actor closure is a data-race risk. A Bool is fine.
        let isResumingFromPause = previousState is PausedState
        MainActor.assumeIsolated {
            // Resuming from pause re-enters this state — don't wipe the live board.
            guard !isResumingFromPause else { return }
            gameScene?.showBoard()
            gameScene?.showHUD()
            // The level line itself is the scene's — one shape for every level,
            // where this used to print a different one for the first.
            gameScene?.logLevel()
        }
    }

    override func update(deltaTime seconds: TimeInterval) {
        // Phase 2+: tick fleet controller, turn timer, etc.
    }
}

// MARK: - Paused State

class PausedState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PlayingState.self || stateClass == TitleState.self
    }

    override func didEnter(from previousState: GKState?) {
        MainActor.assumeIsolated {
            gameScene?.showPausedOverlay()
            AudioManager.shared.pauseMusic()
        }
    }

    override func willExit(to nextState: GKState) {
        MainActor.assumeIsolated {
            gameScene?.hidePausedOverlay()
            AudioManager.shared.resumeMusic()
        }
    }
}

// MARK: - Game Over State

class GameOverState: GCIState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == TitleState.self || stateClass == PlayingState.self
    }

    override func didEnter(from previousState: GKState?) {
        MainActor.assumeIsolated {
            // The music is not stopped here. The ending decided what should be
            // playing two and a half seconds ago — a stinger, or silence behind
            // a loss sting — and this used to cut whichever it was off the
            // moment the menu appeared.
            gameScene?.showGameOverOverlay()
        }
    }

    override func willExit(to nextState: GKState) {
        MainActor.assumeIsolated {
            gameScene?.hideGameOverOverlay()
        }
    }
}
