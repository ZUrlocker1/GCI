// KeyPress.swift
// A key press with no platform type in it.
//
// The game used to read `NSEvent` directly in `GameScene.keyDown` — 170 lines
// of it, reaching into `charactersIgnoringModifiers` and `modifierFlags` at
// fifteen separate sites, plus raw key codes in the name entry. That is the
// largest piece of AppKit in the rendering layer, and porting it meant either
// duplicating the chain for UIKit or wrapping it in `#if os(iOS)` and hoping.
//
// So the scene speaks this instead. `MacInputAdapter` turns an `NSEvent` into
// one of these; on iOS a `GCKeyboard` handler will produce the same value from
// a `GCKeyCode`, and nothing downstream has to know which happened.
//
// Pure Swift, no SpriteKit and no AppKit — it belongs to the Input layer, which
// CLAUDE.md makes the only place allowed to know about platform events.

import Foundation

struct KeyPress: Equatable {

    /// The keys the game reads that have no character to match on.
    ///
    /// Printing keys are matched by `character` instead, so this stays short.
    /// `left` and `right` are the arrows only: A and D also steer, but they
    /// arrive as characters and `InputHandler` maps them, because Test Mode
    /// needs `A` to mean something else while it is on.
    enum Code: Equatable {
        case left, right, space, escape, enter, delete
        /// Anything whose meaning comes from its character, or nothing at all.
        case character
    }

    struct Modifiers: OptionSet, Equatable {
        let rawValue: Int
        static let command = Modifiers(rawValue: 1 << 0)
        static let shift   = Modifiers(rawValue: 1 << 1)
        static let option  = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)
        static let none: Modifiers = []
    }

    let code: Code

    /// Lower-cased and ignoring modifiers, so ⇧/ is "?" and ⌘I is "i" — which
    /// is what the shortcuts match on.
    let character: Character?

    /// What the key would actually type, shift honoured and case preserved.
    ///
    /// Separate from `character` because the high-score name entry needs the
    /// shifted value — the unshifted one turns ⇧1 into "1" rather than "!" —
    /// while every shortcut in the game wants the unshifted one.
    let typed: Character?

    let modifiers: Modifiers

    /// Key repeat. The movement keys ignore it; holding a key should not fire
    /// the same action sixty times a second.
    let isRepeat: Bool

    init(code: Code = .character, character: Character? = nil,
         typed: Character? = nil, modifiers: Modifiers = .none,
         isRepeat: Bool = false) {
        self.code = code
        self.character = character
        self.typed = typed
        self.modifiers = modifiers
        self.isRepeat = isRepeat
    }

    /// The Info shortcut: `?`, plain `I`, or ⌘I — and nothing else.
    ///
    /// Tested before the "any key resumes" branches, since a paused game would
    /// otherwise swallow it and Info could never open from Pause.
    var isInfoShortcut: Bool {
        if character == "?" { return true }
        guard character == "i" else { return false }
        return modifiers.isEmpty || modifiers == .command
    }

    /// Convenience for the scene's many `key == "x"` tests.
    func `is`(_ character: Character) -> Bool { self.character == character }

    /// The same, with Command held — ⌘T and ⌘Q.
    func isCommand(_ character: Character) -> Bool {
        self.character == character && modifiers.contains(.command)
    }
}
