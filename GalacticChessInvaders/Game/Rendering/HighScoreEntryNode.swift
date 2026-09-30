// HighScoreEntryNode.swift
// Name entry shown when a finished game makes the table. Up to 8 characters,
// typed directly, Return to confirm.
//
// Purely a view: it collects keystrokes and reports the result. The scene decides
// when to show it and what to do with the name.

import SpriteKit

@MainActor
final class HighScoreEntryNode: SKNode {

    static let maxLength = 8

    private static let cyan   = NeonPalette.cyan
    private static let orange = NeonPalette.orange
    private static let font   = "PressStart2P-Regular"

    /// Called with the trimmed name once Return is pressed, or with an empty
    /// string if the player cancels with Escape.
    var onSubmit: ((String) -> Void)?

    private(set) var enteredName = ""

    /// Puts a partly typed name back after the node has been rebuilt at a new
    /// scene size. Rebuilding is how a resize is handled — these contents are
    /// laid out against the size they were given, so there is no transform that
    /// makes them right at another one.
    func restore(name: String) {
        enteredName = String(name.prefix(Self.maxLength))
        refresh()
    }
    private let nameLabel = SKLabelNode(fontNamed: HighScoreEntryNode.font)
    private let caret = SKLabelNode(fontNamed: HighScoreEntryNode.font)

    init(score: Int, level: Int, sceneSize: CGSize) {
        super.init()

        let scrim = SKShapeNode(rect: CGRect(origin: .zero, size: sceneSize))
        scrim.fillColor = SKColor(white: 0, alpha: 0.82)
        scrim.strokeColor = .clear
        addChild(scrim)

        let centre = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)

        let headline = label("NEW HIGH SCORE", 28, Self.orange)
        headline.position = CGPoint(x: centre.x, y: centre.y + 92)
        addChild(headline)
        headline.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.5), .fadeAlpha(to: 1.0, duration: 0.5),
        ])))

        let scoreLabel = label("\(score)   ·   LEVEL \(level)", 16, .white)
        scoreLabel.position = CGPoint(x: centre.x, y: centre.y + 52)
        addChild(scoreLabel)

        let prompt = label("ENTER YOUR NAME", 11, Self.cyan.withAlphaComponent(0.8))
        prompt.position = CGPoint(x: centre.x, y: centre.y + 6)
        addChild(prompt)

        // Left-aligned with a trailing caret, so the text grows rightward from a
        // fixed point instead of the whole field shifting on every keystroke.
        nameLabel.fontSize = 30
        nameLabel.fontColor = Self.cyan
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: centre.x - 140, y: centre.y - 40)
        addChild(nameLabel)

        caret.text = "_"
        caret.fontSize = 30
        caret.fontColor = Self.cyan
        caret.horizontalAlignmentMode = .left
        caret.verticalAlignmentMode = .center
        addChild(caret)
        caret.run(.repeatForever(.sequence([
            .wait(forDuration: 0.4), .hide(), .wait(forDuration: 0.4), .unhide(),
        ])))

        // Submits whatever has been typed — any length, no need to fill it.
        let hint = label(InputPrompts.nameEntryHint(max: Self.maxLength), 9,
                         Self.cyan.withAlphaComponent(0.55))
        hint.position = CGPoint(x: centre.x, y: centre.y - 92)
        addChild(hint)

        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Key handling

    /// Hands over whatever has been typed. Shared by Return on a keyboard and
    /// Done on the software one, so the two cannot drift — including the
    /// fallback, which is what stops a row reading as blank.
    func submit() {
        let trimmed = enteredName.trimmingCharacters(in: .whitespaces)
        onSubmit?(trimmed.isEmpty ? "PLAYER" : trimmed)
    }

    /// Returns true if the press was consumed.
    @discardableResult
    func handleKey(_ key: KeyPress) -> Bool {
        switch key.code {
        case .enter:
            submit()
            return true
        case .delete:
            if !enteredName.isEmpty { enteredName.removeLast(); refresh() }
            return true
        case .escape:                                  // record the entry with a blank name
            onSubmit?("")
            return true
        case .left, .right, .space, .character:
            break
        }

        // `typed`, not `character`: the latter is the unshifted key, so ⇧1
        // would arrive as "1" instead of "!".
        //
        // Accepts anything printable in ASCII — letters, digits, space and
        // symbols — which is also exactly what Press Start 2P has glyphs for.
        guard enteredName.count < Self.maxLength,
              let typed = key.typed,
              let character = String(typed).uppercased().first,
              let scalar = character.unicodeScalars.first,
              (0x20...0x7E).contains(scalar.value)
        else { return true }

        enteredName.append(character)
        refresh()
        return true
    }

    private func refresh() {
        nameLabel.text = enteredName
        // Park the caret just past the last character.
        let width = nameLabel.text?.isEmpty == false
            ? nameLabel.calculateAccumulatedFrame().width : 0
        caret.position = CGPoint(x: nameLabel.position.x + width + (enteredName.isEmpty ? 0 : 6),
                                 y: nameLabel.position.y)
        caret.isHidden = enteredName.count >= Self.maxLength
    }

    private func label(_ text: String, _ size: CGFloat, _ color: SKColor) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: Self.font)
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.horizontalAlignmentMode = .center
        node.verticalAlignmentMode = .center
        return node
    }
}
