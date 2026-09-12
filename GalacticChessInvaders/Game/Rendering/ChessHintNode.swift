// ChessHintNode.swift
// Chess Hints banner, shown in the left gutter above the turn timer.
// Names the kinds of piece worth moving; the glowing pieces on the board say
// which ones. "MOVE A PAWN" when the shortlist is all pawns, "MOVE A PAWN OR
// QUEEN" when it is not.
//
// At most two kinds are named even when three pieces are lit. Three names is a
// list to read rather than a hint to act on, and the beat is five seconds.

import SpriteKit

@MainActor
final class ChessHintNode: SKNode {

    private static let cyan = NeonPalette.cyan
    private static let font = "PressStart2P-Regular"
    /// Six characters is the widest a name gets — "KNIGHT", "BISHOP" — and the
    /// joined lines reach nine, "OR KNIGHT". GameStatusNode fits "CHECKMATE" at
    /// 11pt in the same gutter, so nine at 13 is inside it.
    private static let leadSize: CGFloat = 9
    private static let kindSize: CGFloat = 13
    private static let lineStep: CGFloat = 16
    /// Eleven characters — "PRESS SPACE" — at 9pt is about 99pt of monospace,
    /// the same width GameStatusNode already fits with "CHECKMATE" at 11.
    private static let promptSize: CGFloat = 9
    private static let promptPulseKey = "firePrompt"

    /// Two names at most, however many pieces are lit — see the note above.
    private static let maxKinds = 2

    private let leadLabel = SKLabelNode(fontNamed: ChessHintNode.font)
    private var kindLabels: [SKLabelNode] = []
    /// Two lines, below the hint block. Independent of it: a player who has
    /// turned Chess Hints off can still be the one who has not found the fire
    /// key, and that is the more basic thing to be missing.
    private let firePromptTop    = SKLabelNode(fontNamed: ChessHintNode.font)
    private let firePromptBottom = SKLabelNode(fontNamed: ChessHintNode.font)

    private var current: [PieceType]?
    private var isPromptingFire = false

    override init() {
        super.init()

        leadLabel.fontSize = Self.leadSize
        leadLabel.fontColor = Self.cyan.withAlphaComponent(0.70)
        leadLabel.horizontalAlignmentMode = .center
        leadLabel.verticalAlignmentMode = .center
        leadLabel.text = "MOVE A"
        addChild(leadLabel)

        for _ in 0..<Self.maxKinds {
            let label = SKLabelNode(fontNamed: Self.font)
            label.fontSize = Self.kindSize
            label.fontColor = Self.cyan
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.isHidden = true
            addChild(label)
            kindLabels.append(label)
        }

        for (index, label) in [firePromptTop, firePromptBottom].enumerated() {
            label.fontSize = Self.promptSize
            label.fontColor = NeonPalette.orange
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            // Below the hint block, which grows upward from y = 0.
            label.position = CGPoint(x: 0, y: -Self.lineStep * CGFloat(index + 1))
            label.isHidden = true
            addChild(label)
        }
        firePromptTop.text = "PRESS SPACE"
        firePromptBottom.text = "TO FIRE!"

        setHintVisible(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// `kinds` is the distinct piece kinds of the shortlist, best first.
    /// Idempotent — only touches the tree when the advice changes, so the caller
    /// can drive it from a refresh that runs every beat.
    func show(_ kinds: [PieceType]?) {
        guard kinds != current else { return }
        current = kinds

        guard let kinds, !kinds.isEmpty else {
            setHintVisible(false)
            return
        }

        let lines = Self.lines(for: kinds)
        for (index, label) in kindLabels.enumerated() {
            guard index < lines.count else {
                label.isHidden = true
                continue
            }
            label.text = lines[index]
            label.isHidden = false
        }

        // Laid out from a fixed bottom upward, so a three-kind hint grows away
        // from the power-up alley below rather than down into it.
        for index in lines.indices {
            kindLabels[index].position =
                CGPoint(x: 0, y: CGFloat(lines.count - 1 - index) * Self.lineStep)
        }
        leadLabel.position = CGPoint(x: 0, y: CGFloat(lines.count) * Self.lineStep)

        setHintVisible(true)
    }

    /// Shows "PRESS SPACE / TO FIRE!" under the hint. Orange, because it is not
    /// chess advice — it is the half of the game the player has not touched.
    func showFirePrompt(_ showing: Bool) {
        guard showing != isPromptingFire else { return }
        isPromptingFire = showing
        firePromptTop.isHidden = !showing
        firePromptBottom.isHidden = !showing
        guard showing else {
            [firePromptTop, firePromptBottom].forEach {
                $0.removeAction(forKey: Self.promptPulseKey)
                $0.alpha = 1
            }
            return
        }
        for label in [firePromptTop, firePromptBottom] {
            label.alpha = 1
            label.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: 0.55),
                .fadeAlpha(to: 1.00, duration: 0.55),
            ])), withKey: Self.promptPulseKey)
        }
    }

    private func setHintVisible(_ visible: Bool) {
        leadLabel.isHidden = !visible
        kindLabels.forEach { $0.isHidden = !visible }
    }

    /// "PAWN", or "PAWN" / "OR QUEEN". Anything past the second kind is
    /// dropped rather than crammed in.
    private static func lines(for kinds: [PieceType]) -> [String] {
        let names = kinds.prefix(maxKinds).map(name(for:))
        guard names.count > 1 else { return names }
        return names.enumerated().map { index, name in
            index == names.count - 1 ? "OR \(name)" : name
        }
    }

    private static func name(for kind: PieceType) -> String {
        switch kind {
        case .pawn:   return "PAWN"
        case .knight: return "KNIGHT"
        case .bishop: return "BISHOP"
        case .rook:   return "ROOK"
        case .queen:  return "QUEEN"
        case .king:   return "KING"
        }
    }
}
