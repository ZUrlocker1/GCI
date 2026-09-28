// KeyboardInputAdapter.swift
// A hardware keyboard on iOS, driving exactly the same keys as the Mac.
//
// An iPad in a Magic Keyboard has every key the Mac build reads, so it should
// play the same: arrows and A/D to steer, Space to fire, S, M, I, Q, X, the
// Test Mode gate and its four keys, and typing a high-score name. None of
// that needed writing twice — `MacInputAdapter` turns an `NSEvent` into a
// `KeyPress` and this turns a `GCKeyCode` into the same thing, and the scene
// cannot tell which happened.
//
// `GCKeyCode` is a *physical* key, like the macOS virtual key codes it
// replaces — `.keyA` is the key where A sits on a US layout regardless of
// what it types. That is the same behaviour the Mac had before `KeyPress`,
// and it is why the table below maps codes to characters rather than asking
// the system what the key would type.

import Foundation
import GameController

#if os(iOS)

@MainActor
enum KeyboardInputAdapter {

    /// Whether a hardware keyboard is attached right now. `InputPrompts` asks,
    /// so an iPad with a keyboard is told to press a key and one without is
    /// told to tap.
    static var isAttached: Bool { GCKeyboard.coalesced != nil }

    private static var observers: [NSObjectProtocol] = []

    /// Called once at launch. Keyboards come and go while the app runs — a
    /// Magic Keyboard is a case the iPad is attached to and detached from
    /// constantly — so this watches rather than checking once.
    static func start() {
        guard observers.isEmpty else { return }
        let centre = NotificationCenter.default
        // `GCKeyboard.coalesced` rather than the notification's object: a
        // `Notification` is not `Sendable`, and coalesced is the one the rest
        // of this file reads anyway — it merges every attached keyboard.
        observers.append(centre.addObserver(forName: .GCKeyboardDidConnect,
                                            object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                attach(GCKeyboard.coalesced)
                DiagnosticsLog.shared.log(.input, "keyboard connected")
            }
        })
        observers.append(centre.addObserver(forName: .GCKeyboardDidDisconnect,
                                            object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                DiagnosticsLog.shared.log(.input, "keyboard disconnected")
            }
        })
        // One may already be attached at launch, in which case no notification
        // is ever posted.
        attach(GCKeyboard.coalesced)
    }

    private static func attach(_ keyboard: GCKeyboard?) {
        guard let input = keyboard?.keyboardInput else { return }
        input.keyChangedHandler = { input, _, keyCode, pressed in
            MainActor.assumeIsolated {
                guard let press = KeyPress(keyCode, input: input) else { return }
                if pressed {
                    GameScene.shared.handle(key: press)
                } else {
                    GameScene.shared.handle(keyUp: press)
                }
            }
        }
    }
}

// MARK: - GCKeyCode → KeyPress

extension KeyPress {

    /// `nil` for a key the game has no use for — including the modifiers
    /// themselves, which are read off the keyboard rather than delivered.
    init?(_ keyCode: GCKeyCode, input: GCKeyboardInput) {
        var modifiers: Modifiers = .none
        func held(_ codes: GCKeyCode...) -> Bool {
            codes.contains { input.button(forKeyCode: $0)?.isPressed == true }
        }
        if held(.leftGUI, .rightGUI)          { modifiers.insert(.command) }
        if held(.leftShift, .rightShift)      { modifiers.insert(.shift) }
        if held(.leftAlt, .rightAlt)          { modifiers.insert(.option) }
        if held(.leftControl, .rightControl)  { modifiers.insert(.control) }

        let shifted = modifiers.contains(.shift)

        // The keys with no character first.
        let code: Code?
        switch keyCode {
        case .leftArrow:                   code = .left
        case .rightArrow:                  code = .right
        case .spacebar:                    code = .space
        case .escape:                      code = .escape
        case .returnOrEnter, .keypadEnter: code = .enter
        case .deleteOrBackspace:           code = .delete
        default:                           code = nil
        }
        if let code {
            self.init(code: code, character: nil, typed: nil, modifiers: modifiers)
            return
        }

        guard let character = Self.character(for: keyCode) else { return nil }
        // `?` is the one symbol the game reads, and it is Shift-/.
        let typed: Character
        if keyCode == .slash, shifted {
            typed = "?"
        } else {
            typed = shifted ? Character(String(character).uppercased()) : character
        }
        // `character` is the unshifted key, the way `charactersIgnoringModifiers`
        // reports it — except for "?", which the shortcut matches on directly.
        self.init(code: .character,
                  character: typed == "?" ? "?" : character,
                  typed: typed,
                  modifiers: modifiers)
    }

    /// The unshifted character each physical key types on a US layout.
    ///
    /// Letters and digits cover the shortcuts and the high-score name entry
    /// between them; the handful of symbols are the ones the name entry's
    /// ASCII range would accept and a player might reach for.
    private static func character(for keyCode: GCKeyCode) -> Character? {
        switch keyCode {
        case .keyA: return "a"; case .keyB: return "b"; case .keyC: return "c"
        case .keyD: return "d"; case .keyE: return "e"; case .keyF: return "f"
        case .keyG: return "g"; case .keyH: return "h"; case .keyI: return "i"
        case .keyJ: return "j"; case .keyK: return "k"; case .keyL: return "l"
        case .keyM: return "m"; case .keyN: return "n"; case .keyO: return "o"
        case .keyP: return "p"; case .keyQ: return "q"; case .keyR: return "r"
        case .keyS: return "s"; case .keyT: return "t"; case .keyU: return "u"
        case .keyV: return "v"; case .keyW: return "w"; case .keyX: return "x"
        case .keyY: return "y"; case .keyZ: return "z"
        case .one: return "1"; case .two: return "2"; case .three: return "3"
        case .four: return "4"; case .five: return "5"; case .six: return "6"
        case .seven: return "7"; case .eight: return "8"; case .nine: return "9"
        case .zero: return "0"
        case .hyphen: return "-"; case .slash: return "/"; case .period: return "."
        default: return nil
        }
    }
}
#endif
