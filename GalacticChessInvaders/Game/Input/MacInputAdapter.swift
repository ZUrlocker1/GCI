// MacInputAdapter.swift
// The only file in the game that knows what an `NSEvent` is, besides the
// SwiftUI shell.
//
// §8 of docs/IOS-Port.md: "lift the five NSEvent overrides into a
// MacInputAdapter, and give the scene a platform-neutral entry point". This is
// that. The overrides stay where SpriteKit needs them — they have to be methods
// on the scene — but their bodies are now two lines of translation each, and
// everything they used to do lives in the neutral `handle(key:)`,
// `pointerDown(at:)`, `pointerDragged(to:)` and `pointerUp()` on `GameScene`.
//
// iOS adds a sibling of this file: `UITouch` into the same pointer calls, and
// `GCKeyboard` into the same `KeyPress`. Nothing in `GameScene` changes.

import SpriteKit

#if os(macOS)
import AppKit

// MARK: - NSEvent → KeyPress

extension KeyPress {

    /// macOS virtual key codes, which are physical and layout-independent.
    /// Only the keys the game reads without a character are listed; everything
    /// else is matched on `character` and arrives as `.character`.
    private static func code(forKeyCode keyCode: UInt16) -> Code {
        switch keyCode {
        case 123: return .left       // ← arrow. A is a character, see Code.
        case 124: return .right      // → arrow
        case 49:  return .space
        case 53:  return .escape
        case 36, 76: return .enter   // Return, numpad Enter
        case 51:  return .delete
        default:  return .character
        }
    }

    init(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Modifiers = .none
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift)   { modifiers.insert(.shift) }
        if flags.contains(.option)  { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }

        self.init(code: Self.code(forKeyCode: event.keyCode),
                  character: event.charactersIgnoringModifiers?.lowercased().first,
                  typed: event.characters?.first,
                  modifiers: modifiers,
                  isRepeat: event.isARepeat)
    }
}

// MARK: - The five overrides

extension GameScene {

    override func keyDown(with event: NSEvent) {
        handle(key: KeyPress(event))
    }

    override func keyUp(with event: NSEvent) {
        handle(keyUp: KeyPress(event))
    }

    override func mouseDown(with event: NSEvent) {
        pointerDown(at: event.location(in: self))
    }

    override func mouseDragged(with event: NSEvent) {
        pointerDragged(to: event.location(in: self))
    }

    override func mouseUp(with event: NSEvent) {
        pointerUp()
    }
}
#endif
