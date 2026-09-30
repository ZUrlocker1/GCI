// NameEntryField.swift
// The system keyboard, borrowed for the one screen that needs typing.
//
// `HighScoreEntryNode` was keyboard-only — `handleKey` and nothing else — so
// on a touch iPad a player who made the table could not enter a name at all.
// docs/IOS-Port.md §4 only changed that screen's *copy*, which fixed the
// wording of a control that did not exist.
//
// A bespoke A–Z picker is the arcade convention and was the first plan. The
// system keyboard is better here for one reason that outweighs the idiom:
// **it serves both kinds of input from one path.** With a hardware keyboard
// attached no software keyboard appears and typing simply works; without one,
// iOS puts the keyboard up. A picker would be redundant chrome for anyone on
// a Magic Keyboard, and four more layouts to get right.
//
// SpriteKit has no text input, so this is the usual shim: a `UITextField`
// sized 1×1 with clear colours, living in the `SKView`, first responder only
// while the entry screen is up. It is not `isHidden` — a hidden view cannot
// become first responder — and not `alpha: 0`, which is a documented grey
// area. One point of transparent nothing is neither.
//
// The scene draws the name itself, in Press Start 2P, exactly as it does on
// the Mac. The field is a keyboard, not a text box.

#if os(iOS)
import UIKit

@MainActor
final class NameEntryField: NSObject, UITextFieldDelegate {

    private let field = UITextField(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    private var maxLength = 0
    private var onChange: ((String) -> Void)?
    private var onDone: ((String) -> Void)?
    private var onCoveredHeight: ((CGFloat) -> Void)?
    private var frameObserver: NSObjectProtocol?

    override init() {
        super.init()
        field.delegate = self
        // Invisible, but present. Clearing `tintColor` kills the caret, which
        // would otherwise blink in the corner of the screen.
        field.backgroundColor = .clear
        field.textColor = .clear
        field.tintColor = .clear
        field.borderStyle = .none

        // Initials, not prose. Autocorrect suggesting a dictionary word for
        // someone's name is the worst of these to leave on.
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.keyboardType = .asciiCapable
        field.keyboardAppearance = .dark
        field.returnKeyType = .done
        // The iPad shortcut bar — undo, paste, formatting — over an arcade
        // screen, for a field the player cannot even see.
        field.inputAssistantItem.leadingBarButtonGroups = []
        field.inputAssistantItem.trailingBarButtonGroups = []
    }

    // MARK: - Lifecycle

    /// Puts the keyboard up and starts reporting what is typed.
    ///
    /// `onCoveredHeight` is how much of the bottom of the screen the keyboard
    /// takes, in points — which is the same as scene points, since the scene
    /// is `.resizeFill`. It fires on every frame change, so the floating and
    /// split keyboards on iPad are handled by the same path as the docked one.
    func begin(in host: UIView,
               initial: String,
               maxLength: Int,
               onChange: @escaping (String) -> Void,
               onDone: @escaping (String) -> Void,
               onCoveredHeight: @escaping (CGFloat) -> Void) {
        self.maxLength = maxLength
        self.onChange = onChange
        self.onDone = onDone
        self.onCoveredHeight = onCoveredHeight

        field.text = initial
        if field.superview !== host { host.addSubview(field) }
        observeKeyboardFrame()
        field.becomeFirstResponder()
    }

    /// Takes the keyboard away. The caller hands first responder back to the
    /// game view afterwards, or the hardware keys stop arriving.
    func end() {
        onChange = nil
        onDone = nil
        onCoveredHeight = nil
        if let frameObserver {
            NotificationCenter.default.removeObserver(frameObserver)
            self.frameObserver = nil
        }
        field.resignFirstResponder()
        field.removeFromSuperview()
    }

    private func observeKeyboardFrame() {
        guard frameObserver == nil else { return }
        frameObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil, queue: .main) { note in
                // Read out here, in the nonisolated closure, because
                // `Notification` is not `Sendable` and cannot cross into the
                // actor. A `CGRect` can. The host comes from `field` inside,
                // for the same reason — a `UIView` cannot be captured here.
                let endFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                    as? CGRect
                MainActor.assumeIsolated { [weak self] in
                    guard let self, let endFrame,
                          let host = self.field.superview else { return }
                    // In the host's own coordinates, then intersected: a
                    // floating keyboard may not touch the bottom edge at all,
                    // and an off-screen end frame means it is leaving.
                    let local = host.convert(endFrame, from: nil)
                    let overlap = host.bounds.intersection(local)
                    self.onCoveredHeight?(overlap.isNull ? 0 : overlap.height)
                }
            }
    }

    // MARK: - UITextFieldDelegate

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        guard let swiftRange = Range(range, in: current) else { return false }

        // Filtered to what the font can draw. Press Start 2P has printable
        // ASCII and nothing else, so an emoji from the keyboard would be a
        // blank box in the high score table forever.
        let cleaned = string.uppercased().filter {
            guard let scalar = $0.unicodeScalars.first, $0.unicodeScalars.count == 1
            else { return false }
            return (0x20...0x7E).contains(scalar.value)
        }
        let proposed = current.replacingCharacters(in: swiftRange, with: cleaned)
        guard proposed.count <= maxLength else { return false }

        textField.text = proposed
        onChange?(proposed)
        return false        // the text is set here, uppercased and filtered
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onDone?(textField.text ?? "")
        return false
    }
}
#endif
