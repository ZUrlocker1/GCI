// GameOverNode.swift
// End-of-game overlay: outcome, final score, and the NEW GAME? Y/N prompt.
// Centred like the PAUSED banner, over a dimmed playfield so the final position
// stays readable behind it.

import SpriteKit

@MainActor
final class GameOverNode: SKNode {

    enum Outcome: Equatable {
        case whiteMated                 // player lost — game over
        case blackMated                 // player won outright
        case stalemate
        case drawnByRepetition
        case drawnByMoveLimit
        /// Black checkmated but the run continues into the next wave.
        case waveCleared(next: Int)

        /// Speaks to the player, not the game model: "wave clear" is an internal
        /// notion and does not tell someone they just won.
        var headline: String {
            switch self {
            case .whiteMated: return "GAME OVER"
            case .blackMated, .waveCleared: return "YOU WIN"
            case .stalemate, .drawnByRepetition, .drawnByMoveLimit: return "DRAW"
            }
        }

        var detail: String {
            switch self {
            case .whiteMated: return "WHITE CHECKMATED"
            case .blackMated, .waveCleared: return "BLACK CHECKMATED"
            case .stalemate:         return "NO LEGAL MOVES"
            case .drawnByRepetition: return "SAME POSITION THREE TIMES"
            case .drawnByMoveLimit:  return "50 MOVES, NO CAPTURE"
            }
        }

        var prompt: String {
            switch self {
            case .waveCleared(let next): return "PRESS ANY KEY  ·  LEVEL \(next)"
            default:                     return "NEW GAME?   Y / N"
            }
        }

        /// Good news for the player gets the friendly colour.
        var isFavourable: Bool {
            switch self {
            case .blackMated, .waveCleared: return true
            case .whiteMated, .stalemate, .drawnByRepetition, .drawnByMoveLimit:
                return false
            }
        }
    }

    private static let cyan    = SKColor(red: 0.07, green: 0.88, blue: 1.00, alpha: 1)
    private static let magenta = SKColor(red: 1.00, green: 0.13, blue: 0.38, alpha: 1)
    private static let orange  = SKColor(red: 1.00, green: 0.73, blue: 0.12, alpha: 1)
    private static let font    = "PressStart2P-Regular"

    init(outcome: Outcome, score: Int, sceneSize: CGSize) {
        super.init()

        // Dim the board rather than hide it, so the mating position stays visible.
        let scrim = SKShapeNode(rect: CGRect(origin: .zero, size: sceneSize))
        scrim.fillColor = SKColor(white: 0, alpha: 0.72)
        scrim.strokeColor = .clear
        scrim.zPosition = 0
        addChild(scrim)

        let centre = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)

        let headline = label(outcome.headline, 40,
                             outcome.isFavourable ? Self.cyan : Self.magenta)
        headline.position = CGPoint(x: centre.x, y: centre.y + 78)
        addChild(headline)

        let detail = label(outcome.detail, 12, .white.withAlphaComponent(0.75))
        detail.position = CGPoint(x: centre.x, y: centre.y + 40)
        addChild(detail)

        let scoreLabel = label("FINAL SCORE  \(score)", 18, Self.orange)
        scoreLabel.position = CGPoint(x: centre.x, y: centre.y - 6)
        addChild(scoreLabel)

        let prompt = label(outcome.prompt, 20, Self.cyan)
        prompt.position = CGPoint(x: centre.x, y: centre.y - 62)
        addChild(prompt)
        // Blink like the title screen's start prompt, so it reads as the live control.
        prompt.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 0.6),
            SKAction.fadeAlpha(to: 0.25, duration: 0.15),
            SKAction.wait(forDuration: 0.4),
            SKAction.fadeAlpha(to: 1.0, duration: 0.15),
        ])))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func label(_ text: String, _ size: CGFloat, _ color: SKColor) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: Self.font)
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.horizontalAlignmentMode = .center
        node.verticalAlignmentMode = .center
        node.zPosition = 1
        return node
    }
}
