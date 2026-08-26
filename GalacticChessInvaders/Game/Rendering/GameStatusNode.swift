// GameStatusNode.swift
// Check / checkmate banner, shown in the left gutter below the turn timer.
// Names the side that is in trouble, so "BLACK CHECK" and "WHITE CHECK" are
// never confusable.

import SpriteKit

@MainActor
final class GameStatusNode: SKNode {

    enum Status: Equatable {
        case none
        case check(PieceColor)
        case checkmate(PieceColor)
        case stalemate
    }

    private static let cyan    = NeonPalette.cyan
    private static let magenta = NeonPalette.magenta
    private static let orange  = NeonPalette.orange
    private static let font    = "PressStart2P-Regular"
    private static let pulseKey = "statusPulse"
    private static let stateFontSize: CGFloat = 15
    /// "CHECKMATE" is nearly twice as wide as "CHECK", so it is stepped down to
    /// stay inside the gutter left of the board.
    private static let longStateFontSize: CGFloat = 11

    private let sideLabel  = SKLabelNode(fontNamed: GameStatusNode.font)
    private let stateLabel = SKLabelNode(fontNamed: GameStatusNode.font)

    private var current: Status = .none

    override init() {
        super.init()
        sideLabel.fontSize = 10
        sideLabel.horizontalAlignmentMode = .center
        sideLabel.verticalAlignmentMode = .center
        sideLabel.position = CGPoint(x: 0, y: 17)
        addChild(sideLabel)

        stateLabel.fontSize = Self.stateFontSize
        stateLabel.horizontalAlignmentMode = .center
        stateLabel.verticalAlignmentMode = .center
        addChild(stateLabel)

        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Idempotent — safe to call every frame; only acts when the status changes.
    func show(_ status: Status) {
        guard status != current else { return }
        current = status

        switch status {
        case .none:
            isHidden = true
            removeAction(forKey: Self.pulseKey)
            alpha = 1
            return

        case .check(let side):
            sideLabel.text = side == .white ? "WHITE" : "BLACK"
            stateLabel.text = "CHECK"
            // Red for the player's own peril, magenta when Black is the one in check.
            let color = side == .white ? Self.magenta : Self.cyan
            sideLabel.fontColor = color.withAlphaComponent(0.8)
            stateLabel.fontColor = color

        case .checkmate(let side):
            sideLabel.text = side == .white ? "WHITE" : "BLACK"
            stateLabel.text = "CHECKMATE"
            let color = side == .white ? Self.magenta : Self.orange
            sideLabel.fontColor = color.withAlphaComponent(0.8)
            stateLabel.fontColor = color

        case .stalemate:
            sideLabel.text = "DRAW"
            stateLabel.text = "STALE"
            sideLabel.fontColor = Self.orange.withAlphaComponent(0.8)
            stateLabel.fontColor = Self.orange
        }

        stateLabel.fontSize = (stateLabel.text?.count ?? 0) > 6
            ? Self.longStateFontSize : Self.stateFontSize

        isHidden = false
        removeAction(forKey: Self.pulseKey)
        alpha = 1
        // Checkmate is terminal, so it holds steady; check pulses for attention.
        if case .check = status {
            run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.35, duration: 0.45),
                SKAction.fadeAlpha(to: 1.00, duration: 0.45)
            ])), withKey: Self.pulseKey)
        }
    }
}
