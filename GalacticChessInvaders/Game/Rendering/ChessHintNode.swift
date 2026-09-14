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
    /// The gutter is wider than it looks. The board starts at x=224 and this
    /// node is centred at x=112, so there is ~200pt to play with once the rank
    /// labels at x=212 are cleared — "FRIENDLY FIRE!" is fourteen characters of
    /// 9pt monospace, about 126pt, and sits well inside it.
    private static let leadSize: CGFloat = 9
    private static let kindSize: CGFloat = 13
    private static let lineStep: CGFloat = 16
    /// Eleven characters — "PRESS SPACE" — at 9pt is about 99pt of monospace,
    /// the same width GameStatusNode already fits with "CHECKMATE" at 11.
    private static let promptSize: CGFloat = 9
    /// Clear air between the hint block and the prompt, so the two read as
    /// separate advice rather than one four-line paragraph.
    private static let promptGap: CGFloat = 22
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

    /// The control the player has not used yet. Both occupy the same slot
    /// under the hint, and they never overlap in practice — the move prompt
    /// only starts counting once the player has fired.
    enum ControlPrompt: Equatable {
        case fire
        case move
        /// Fired, then stopped — see `beatsSinceLastShot`.
        case shootSomething
        /// Carries the piece that was hit, so the notice can name it.
        case friendlyFire(PieceType)

        /// Uppercase name of a piece, for both the hint lines and the
        /// friendly-fire notice. On the enum rather than the node because the
        /// enum is reachable from outside the main actor and the node is not.
        static func name(for kind: PieceType) -> String {
            switch kind {
            case .pawn:   return "PAWN"
            case .knight: return "KNIGHT"
            case .bishop: return "BISHOP"
            case .rook:   return "ROOK"
            case .queen:  return "QUEEN"
            case .king:   return "KING"
            }
        }

        /// Red for friendly fire — it is a cost, not a nudge. The other two
        /// are orange, which is the game's colour for "here is something you
        /// have not tried yet".
        var color: SKColor {
            switch self {
            case .fire, .move:              return NeonPalette.orange
            case .shootSomething, .friendlyFire: return NeonPalette.crimson
            }
        }

        var lines: (String, String) {
            switch self {
            // Twelve characters would be "PRESS ARROWS", wider than anything
            // GameStatusNode fits in this gutter. Ten is safe.
            case .fire: return ("PRESS SPACE", "TO FIRE!")
            case .move: return ("USE ARROWS", "TO MOVE!")
            // No "PRESS SPACE" — this only ever shows to someone who has
            // already fired this level, so they know where the trigger is.
            // What they have stopped doing is using it.
            case .shootSomething: return ("SHOOT", "SOMETHING!")
            // Names the piece actually hit. Advice about the future — "watch
            // your own pieces" — is the wrong tense: by the time this shows,
            // the shot has landed, and a player who did not realise their own
            // fire counts needs telling what just happened, not what to do
            // next. "YOUR KNIGHT!" is the longest at twelve characters.
            case .friendlyFire(let kind): return ("YOU HIT", "YOUR \(Self.name(for: kind))!")
            }
        }
    }

    private var current: [PieceType]?
    private var prompt: ControlPrompt?

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
            // Below the hint block, which grows upward from y = 0, with a
            // little more air than one line step gives on its own.
            label.position = CGPoint(x: 0,
                                     y: -Self.promptGap - Self.lineStep * CGFloat(index))
            label.isHidden = true
            addChild(label)
        }
        clearLabels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// `kinds` is the distinct piece kinds of the shortlist, best first.
    /// Idempotent — only touches the tree when the advice changes, so the caller
    /// can drive it from a refresh that runs every beat.
    func show(_ kinds: [PieceType]?) {
        guard kinds != current else { return }
        current = kinds

        // Blank the whole block first, so every path through here starts from
        // an empty message area. Hiding only the lines past the new count was
        // not enough: the old code then unhid every label in one go, which
        // brought a stale second line back, positioned on top of the first.
        // "MOVE A / PAWN / OR QUEEN" followed by "MOVE A / PAWN" printed
        // "OR QUEEN" over "PAWN".
        clearLabels()

        guard let kinds, !kinds.isEmpty else { return }

        // Laid out from a fixed bottom upward, so a two-kind hint grows away
        // from the power-up alley below rather than down into it.
        let lines = Self.lines(for: kinds)
        for (index, text) in lines.enumerated() {
            let label = kindLabels[index]
            label.text = text
            label.position = CGPoint(x: 0,
                                     y: CGFloat(lines.count - 1 - index) * Self.lineStep)
            label.isHidden = false
        }
        leadLabel.position = CGPoint(x: 0, y: CGFloat(lines.count) * Self.lineStep)
        leadLabel.isHidden = false
    }

    private func clearLabels() {
        leadLabel.isHidden = true
        for label in kindLabels {
            label.text = ""
            label.isHidden = true
        }
    }

    /// The hint lines currently on screen, top line first. Empty when no hint
    /// is showing. Exposed so a test can pin the clearing above.
    var visibleHintLinesForTesting: [String] {
        kindLabels.filter { !$0.isHidden }.map { $0.text ?? "" }
    }

    /// Shows a control prompt under the hint, or nothing. Orange, because it
    /// is not chess advice — it is the half of the game the player has not
    /// touched.
    func showPrompt(_ next: ControlPrompt?) {
        guard next != prompt else { return }
        prompt = next
        firePromptTop.isHidden = next == nil
        firePromptBottom.isHidden = next == nil
        guard let next else {
            [firePromptTop, firePromptBottom].forEach {
                $0.removeAction(forKey: Self.promptPulseKey)
                $0.alpha = 1
            }
            return
        }
        (firePromptTop.text, firePromptBottom.text) = next.lines
        for label in [firePromptTop, firePromptBottom] {
            label.fontColor = next.color
            label.alpha = 1
            label.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: 0.55),
                .fadeAlpha(to: 1.00, duration: 0.55),
            ])), withKey: Self.promptPulseKey)
        }
    }


    /// "PAWN", or "PAWN" / "OR QUEEN". Anything past the second kind is
    /// dropped rather than crammed in.
    private static func lines(for kinds: [PieceType]) -> [String] {
        let names = kinds.prefix(maxKinds).map(ControlPrompt.name(for:))
        guard names.count > 1 else { return names }
        return names.enumerated().map { index, name in
            index == names.count - 1 ? "OR \(name)" : name
        }
    }

}
