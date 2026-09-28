// KeyboardInputAdapter.swift
// A hardware keyboard on iOS, driving exactly the same keys as the Mac.
//
// An iPad in a Magic Keyboard has every key the Mac build reads, so it plays
// the same: arrows and A/D to steer, Space to fire, S, M, I, Q, X, the Test
// Mode gate and its four keys, and typing a high-score name. None of that
// needed writing twice — `MacInputAdapter` turns an `NSEvent` into a
// `KeyPress`, this turns a `UIKey` into the same thing, and the scene cannot
// tell which happened.
//
// **`UIPress`, not `GCKeyboard`.** This was written against `GCKeyboard`
// first, and the keys worked while the system *also* acted on them: Space
// opened Spotlight search over the game. `GCKeyboard` observes the keyboard,
// it does not claim it, so every press fell through to iPadOS as well.
// Overriding `pressesBegan`/`pressesEnded` and not calling `super` for a key
// the game reads is what consumes it.
//
// `UIKey` is also a closer match than `GCKeyCode` was: it carries
// `charactersIgnoringModifiers`, `characters` and `modifierFlags`, which is
// exactly the shape `NSEvent` has and exactly what `KeyPress` wants. The
// hand-written key-code-to-character table the first version needed is gone.

import SpriteKit

#if os(iOS)
import UIKit

extension GameScene {

    open override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first.flatMap(KeyPress.init) else {
            // Not a key the game reads — let the system have it.
            super.pressesBegan(presses, with: event)
            return
        }
        // Deliberately no `super`. That is what stops Space reaching iPadOS
        // and opening search on top of the game.
        handle(key: press)
    }

    open override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first.flatMap(KeyPress.init) else {
            super.pressesEnded(presses, with: event)
            return
        }
        handle(keyUp: press)
    }

    /// A press the system takes away — the app losing focus mid-hold. It has
    /// to read as a release, or the ship keeps moving after the keyboard has
    /// stopped talking to us.
    open override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let press = presses.first.flatMap(KeyPress.init) {
            handle(keyUp: press)
        } else {
            super.pressesCancelled(presses, with: event)
        }
    }
}

// MARK: - UIPress → KeyPress

extension KeyPress {

    /// `nil` for a press with no key, or a key the game has no use for.
    init?(_ press: UIPress) {
        guard let key = press.key else { return nil }

        var modifiers: Modifiers = .none
        if key.modifierFlags.contains(.command)   { modifiers.insert(.command) }
        if key.modifierFlags.contains(.shift)     { modifiers.insert(.shift) }
        if key.modifierFlags.contains(.alternate) { modifiers.insert(.option) }
        if key.modifierFlags.contains(.control)   { modifiers.insert(.control) }

        let code: Code
        switch key.keyCode {
        case .keyboardLeftArrow:         code = .left
        case .keyboardRightArrow:        code = .right
        case .keyboardSpacebar:          code = .space
        case .keyboardEscape:            code = .escape
        case .keyboardReturnOrEnter,
             .keypadEnter:               code = .enter
        case .keyboardDeleteOrBackspace: code = .delete
        default:                         code = .character
        }

        let unshifted = key.charactersIgnoringModifiers.lowercased().first
        // A modifier on its own reports no characters and no useful code.
        if code == .character, unshifted == nil { return nil }

        self.init(code: code,
                  character: unshifted,
                  typed: key.characters.first,
                  modifiers: modifiers,
                  // `UIPress` does not report auto-repeat. Holding a key
                  // therefore re-fires rather than being ignored, which the
                  // movement keys do not mind — they are down/up — and which
                  // nothing else in the game is held down long enough to
                  // notice.
                  isRepeat: false)
    }
}
#endif
