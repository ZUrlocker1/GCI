// InputHandler.swift
// Translates macOS keyboard/mouse events into GameAction values.
// iOS touch events will have a separate implementation in Phase 10.
// Game logic consumes GameAction only — never raw NSEvent.

import Foundation
import SpriteKit

#if os(macOS)
import AppKit

final class InputHandler {
    static let shared = InputHandler()
    private init() {}

    // GameScene sets this to route actions into the state machine
    var actionHandler: ((GameAction) -> Void)?

    func handleKeyDown(_ event: NSEvent, inTitleScreen: Bool = false) {
        guard !event.isARepeat else { return }

        // In the title screen any key starts the game
        if inTitleScreen {
            dispatch(.confirmStart)
            return
        }

        let action = gameAction(for: event.keyCode, isDown: true)
        if let action {
            DiagnosticsLog.shared.log(.input, "KeyDown \(event.keyCode) → \(action)")
            dispatch(action)
        }
    }

    func handleKeyUp(_ event: NSEvent) {
        let action = gameAction(for: event.keyCode, isDown: false)
        if let action { dispatch(action) }
    }

    func handleMouseDown(at location: CGPoint, in scene: SKScene) {
        // Phase 2.1: convert screen position to board square via BoardLayout
        DiagnosticsLog.shared.log(.input, "Click at (\(Int(location.x)), \(Int(location.y)))")
    }

    // MARK: - Key Mapping

    private func gameAction(for keyCode: UInt16, isDown: Bool) -> GameAction? {
        switch keyCode {
        case 123, 0:    // ← arrow, A
            return isDown ? .moveLeft : .stopMoving
        case 124, 2:    // → arrow, D
            return isDown ? .moveRight : .stopMoving
        case 49:        // Space
            return isDown ? .fireLaser : nil
        case 53:        // Escape
            return isDown ? .pause : nil
        case 35:        // P
            return isDown ? .pause : nil
        case 36, 76:    // Return, numpad Enter
            return isDown ? .confirmStart : nil
        case 37:        // L — toggle diagnostics sidebar
            return isDown ? .toggleDiagnostics : nil
        default:
            return nil
        }
    }

    private func dispatch(_ action: GameAction) {
        actionHandler?(action)
    }
}

#else
// iOS stub — full implementation in Phase 10
final class InputHandler {
    static let shared = InputHandler()
    private init() {}
    var actionHandler: ((GameAction) -> Void)?
}
#endif
