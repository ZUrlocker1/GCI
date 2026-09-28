// InputHandler.swift
// Turns a `KeyPress` or a click into a `GameAction`.
//
// No `NSEvent` here any more, and no `#if os(macOS)` either: the platform
// translation moved to `MacInputAdapter`, and this file now compiles unchanged
// on iOS. Game logic still consumes `GameAction` only.

import Foundation
import SpriteKit

@MainActor
final class InputHandler {
    static let shared = InputHandler()
    private init() {}

    // GameScene sets this to route actions into the state machine
    var actionHandler: ((GameAction) -> Void)?

    func handleKeyDown(_ key: KeyPress, inTitleScreen: Bool = false) {
        guard !key.isRepeat else { return }

        // I · ⌘I · ? open How To Play (§9). Matched on characters rather than
        // key code so "?" works regardless of keyboard layout.
        //
        // Tested before the title screen's any-key-starts rule, or the one place
        // a new player most wants the instructions is the one place they cannot
        // reach them.
        if key.isInfoShortcut {
            DiagnosticsLog.shared.log(.input, "Info shortcut → showInfo")
            dispatch(.showInfo)
            return
        }

        // In the title screen any other key starts the game
        if inTitleScreen {
            dispatch(.confirmStart)
            return
        }

        if let action = gameAction(for: key, isDown: true) {
            DiagnosticsLog.shared.log(.input, "KeyDown \(key.code) → \(action)")
            dispatch(action)
        }
    }

    /// Any key dismisses the How To Play overlay and resumes play (§10).
    func handleOverlayKeyDown() {
        dispatch(.dismissOverlay)
    }

    func handleKeyUp(_ key: KeyPress) {
        if let action = gameAction(for: key, isDown: false) { dispatch(action) }
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

    /// The mapping, exposed for tests. A and D have been on and off this table
    /// once already; pinning it is cheaper than finding out from a player.
    func actionForTesting(_ key: KeyPress, isDown: Bool) -> GameAction? {
        gameAction(for: key, isDown: isDown)
    }

    private func gameAction(for key: KeyPress, isDown: Bool) -> GameAction? {
        // Arrows and A / D, as §8.1 asks: arrows for an external keyboard, the
        // letters for a laptop where the left hand stays near the trackpad.
        //
        // A and D were dropped for a while because A was the Auto Mode toggle
        // and the scene reads hotkeys ahead of movement, so the letter could
        // not do both. Auto Mode now needs Test Mode first, which gives the
        // letters back.
        //
        // The arrows come through as codes and the letters as characters,
        // which is the whole reason `KeyPress` carries both.
        switch key.code {
        case .left:  return isDown ? .moveLeft : .stopMoving
        case .right: return isDown ? .moveRight : .stopMoving
        case .space: return isDown ? .fireLaser : .stopFiring
        // Escape only. §5 gives pause both Escape and P; P is now the hidden
        // power-up test key, and the scene's handler claims it ahead of this
        // one. Escape is the sole pause key, so it always pauses rather than
        // first cancelling a chess selection as §5 suggests — a pause key that
        // sometimes needs two presses is worse than one that never does.
        case .escape: return isDown ? .pause : nil
        case .enter:  return isDown ? .confirmStart : nil
        case .delete, .character: break
        }

        switch key.character {
        case "a": return isDown ? .moveLeft : .stopMoving
        case "d": return isDown ? .moveRight : .stopMoving
        case "l": return isDown ? .toggleDiagnostics : nil   // diagnostics sidebar
        default:  return nil
        }
    }

    private func dispatch(_ action: GameAction) {
        actionHandler?(action)
    }
}
