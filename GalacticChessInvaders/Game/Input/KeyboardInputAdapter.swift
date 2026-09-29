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
// Two false starts, both worth recording because each looked right:
//
// **`GCKeyboard` observes a keyboard; it does not claim it.** The keys worked
// and the system acted on them as well — Space opened Spotlight search over
// the game. Consuming a key means being in the responder chain and declining
// to pass it on, which `GCKeyboard` has no way to do.
//
// **`SKScene` is a `UIResponder`, but it is not in that chain.** Overriding
// `pressesBegan` on the scene therefore did nothing at all: SpriteKit
// forwards touches to the scene explicitly and presses not at all. The view
// is what the window talks to, so the view is where this has to live — which
// is also where macOS puts it, in `KeyboardFocusedSKView`, whose comment
// describes this exact symptom from the other side.

import SpriteKit

#if os(iOS)
import UIKit

/// An `SKView` that claims the keyboard as soon as it has a window, and turns
/// what it receives into the same `KeyPress` the Mac produces.
///
/// The iOS twin of `KeyboardFocusedSKView` in the AppKit shell, down to the
/// name and the reason for it.
final class KeyboardFocusedSKView: SKView {

    override var canBecomeFirstResponder: Bool { true }

    private var keyWindowObserver: NSObjectProtocol?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        claimKeyboard()
        observeKeyWindow()
    }

    /// The event that was missing.
    ///
    /// `didMoveToWindow` fires when the view *has* a window, which is earlier
    /// than that window being **key** — and a view cannot hold first responder
    /// until then. Asking again on the next run-loop turn happened to work in
    /// the simulator and did not on a real iPad, where the gap is longer.
    ///
    /// `didBecomeKeyNotification` is the moment itself rather than a guess at
    /// how long it takes, so there is nothing left to race.
    private func observeKeyWindow() {
        guard keyWindowObserver == nil else { return }
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.claimKeyboard() }
        }
    }

    // No `deinit` unregistering the observer: Swift 6 will not let a
    // nonisolated `deinit` touch it, and it does not need to. The block holds
    // the view weakly, and this view lives as long as the game does.


    /// Asks for the keyboard, and keeps asking.
    ///
    /// One call in `didMoveToWindow` is not enough, which is the bug behind
    /// "space still opens Spotlight when gameplay first starts". At that
    /// moment the view has a window but the window is not yet key, so
    /// `becomeFirstResponder` returns false and the press goes to iPadOS
    /// instead — and SwiftUI may hand focus elsewhere while it settles. Every
    /// route back into the app asks again:
    ///
    ///   · the view gaining a window
    ///   · the next run-loop turn, by which time the window is key
    ///   · `updateUIView`, which SwiftUI calls as state settles
    ///   · the app returning to the foreground
    ///
    /// Cheap, because `becomeFirstResponder` on the current first responder
    /// is a no-op.
    func claimKeyboard(attempt: Int = 0) {
        guard window != nil, !isFirstResponder else { return }
        if becomeFirstResponder() {
            DiagnosticsLog.shared.log(.input,
                attempt == 0 ? "keyboard focus" : "keyboard focus (attempt \(attempt + 1))")
            return
        }
        // A bounded retry behind the notification above, for whatever order
        // SwiftUI settles its own focus in. Five turns over half a second,
        // then it gives up and says so rather than retrying forever.
        guard attempt < 5 else {
            DiagnosticsLog.shared.log(.error, "could not claim the keyboard")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            MainActor.assumeIsolated { self?.claimKeyboard(attempt: attempt + 1) }
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        claimKeyboard()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first.flatMap(KeyPress.init) else {
            // Not a key the game reads — let the system have it.
            super.pressesBegan(presses, with: event)
            return
        }
        // Deliberately no `super`. That is what stops Space reaching iPadOS
        // and opening search on top of the game.
        gameScene?.handle(key: press)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first.flatMap(KeyPress.init) else {
            super.pressesEnded(presses, with: event)
            return
        }
        gameScene?.handle(keyUp: press)
    }

    /// A press the system takes away — the app losing focus mid-hold. It has
    /// to read as a release, or the ship keeps moving after the keyboard has
    /// stopped talking to us.
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let press = presses.first.flatMap(KeyPress.init) {
            gameScene?.handle(keyUp: press)
        } else {
            super.pressesCancelled(presses, with: event)
        }
    }

    private var gameScene: GameScene? { scene as? GameScene }
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
        // A modifier held on its own reports no characters and no useful code.
        if code == .character, unshifted == nil { return nil }

        self.init(code: code,
                  character: unshifted,
                  typed: key.characters.first,
                  modifiers: modifiers,
                  // `UIPress` does not report auto-repeat. Holding a key
                  // therefore re-fires rather than being ignored, which the
                  // movement keys do not mind — they are down/up — and which
                  // nothing else is held long enough to notice.
                  isRepeat: false)
    }
}
#endif
