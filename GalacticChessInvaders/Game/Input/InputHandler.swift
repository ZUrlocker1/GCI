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

    // Track held keys for continuous movement
    private var leftHeld = false
    private var rightHeld = false

    func handleKeyDown(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        let action = gameAction(for: event.keyCode, isDown: true)
        if let action {
            DiagnosticsLog.shared.log(.input, "KeyDown: \(event.keyCode) → \(action)")
            dispatch(action)
        }
    }

    func handleKeyUp(_ event: NSEvent) {
        let action = gameAction(for: event.keyCode, isDown: false)
        if let action {
            dispatch(action)
        }
    }

    func handleMouseDown(at location: CGPoint, in scene: SKScene) {
        // Convert screen position to board square
        // Phase 1+: implement board coordinate mapping
        DiagnosticsLog.shared.log(.input, "Click at \(location)")
    }

    // MARK: - Key Mapping

    private func gameAction(for keyCode: UInt16, isDown: Bool) -> GameAction? {
        switch keyCode {
        case 123, 0:   // ← arrow, A
            return isDown ? .moveLeft : .stopMoving
        case 124, 2:   // → arrow, D
            return isDown ? .moveRight : .stopMoving
        case 49:        // Space
            return isDown ? .fireLaser : nil
        case 53:        // Escape
            return isDown ? .pause : nil
        case 36, 76:   // Return, numpad Enter
            return isDown ? .confirmStart : nil
        default:
            return nil
        }
    }

    private func dispatch(_ action: GameAction) {
        // Phase 1+: route to the active game state handler
        // For now, just log
        _ = action
    }
}

#else
// iOS stub — full implementation in Phase 10
final class InputHandler {
    static let shared = InputHandler()
    private init() {}
}
#endif
