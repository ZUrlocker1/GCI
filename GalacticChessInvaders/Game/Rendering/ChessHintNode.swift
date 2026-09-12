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

    /// Two names at most, however many pieces are lit — see the note above.
    private static let maxKinds = 2

    private let leadLabel = SKLabelNode(fontNamed: ChessHintNode.font)
    private var kindLabels: [SKLabelNode] = []

    private var current: [PieceType]?

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

        isHidden = true
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
            isHidden = true
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

        isHidden = false
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
