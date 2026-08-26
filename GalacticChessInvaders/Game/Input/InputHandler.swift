// InputHandler.swift
// Translates macOS keyboard/mouse events into GameAction values.
// iOS touch events will have a separate implementation in Phase 10.
// Game logic consumes GameAction only — never raw NSEvent.

import Foundation
import SpriteKit

#if os(macOS)
import AppKit

@MainActor
final class InputHandler {
    static let shared = InputHandler()
    private init() {}

    // GameScene sets this to route actions into the state machine
    var actionHandler: ((GameAction) -> Void)?

    func handleKeyDown(_ event: NSEvent, inTitleScreen: Bool = false) {
        guard !event.isARepeat else { return }

        // I · ⌘I · ? open How To Play (§9). Matched on characters rather than
        // key code so "?" works regardless of keyboard layout.
        //
        // Tested before the title screen's any-key-starts rule, or the one place
        // a new player most wants the instructions is the one place they cannot
        // reach them.
        if isInfoShortcut(event) {
            DiagnosticsLog.shared.log(.input, "Info shortcut → showInfo")
            dispatch(.showInfo)
            return
        }

        // In the title screen any other key starts the game
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

    private func isInfoShortcut(_ event: NSEvent) -> Bool {
        // charactersIgnoringModifiers so ⇧/ reports "?" and ⌘I reports "i".
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }
        if characters == "?" { return true }
        if characters == "i" {
            // Plain I, or ⌘I. Ignore other modifier combinations.
            let relevant = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return relevant.isEmpty || relevant == .command
        }
        return false
    }

    /// Any key dismisses the How To Play overlay and resumes play (§10).
    func handleOverlayKeyDown() {
        dispatch(.dismissOverlay)
    }

    func handleKeyUp(_ event: NSEvent) {
        let action = gameAction(for: event.keyCode, isDown: false)
        if let action { dispatch(action) }
    }

    func handleMouseDown(at location: CGPoint, in scene: SKScene, inTitleScreen: Bool = false) {
        if inTitleScreen {
            dispatch(.confirmStart)
            return
        }
        DiagnosticsLog.shared.log(.input, "Click at (\(Int(location.x)), \(Int(location.y)))")
    }

    /// A click that the scene has already resolved to a board square (nil = off-board).
    /// `hasSelection` decides whether this reads as picking a piece or naming a destination.
    func handleBoardClick(square: String?, hasSelection: Bool) {
        guard let square else {
            if hasSelection { dispatch(.deselectPiece) }
            return
        }
        dispatch(hasSelection ? .movePieceTo(boardSquare: square)
                              : .selectPieceAt(boardSquare: square))
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
@MainActor
final class InputHandler {
    static let shared = InputHandler()
    private init() {}
    var actionHandler: ((GameAction) -> Void)?
}
#endif
