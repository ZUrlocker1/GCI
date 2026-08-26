// GameOverNode.swift
// End-of-game overlay: outcome, final score, and the NEW GAME? Y/N prompt.
// Centred like the PAUSED banner, over a dimmed playfield so the final position
// stays readable behind it.

import SpriteKit

@MainActor
final class GameOverNode: SKNode {

    enum Outcome: Equatable {
        case whiteMated                 // player lost — game over
        case stalemate
        case drawnByRepetition
        case drawnByMoveLimit
        /// Lost outside of chess entirely: three lives gone, a black piece
        /// reached rank 1, or the white king was shot to 0 HP (§Lose conditions).
        case livesDepleted
        case blackBreachedRank1
        case whiteKingDestroyed
        /// Black's king has fallen — by checkmate, chess capture, fleet crush,
        /// or the player's laser (§25.2: all four are the same win). The run
        /// continues into the next wave.
        case waveCleared(next: Int)
        /// The last wave (`LevelManager.finalLevel`) has fallen — the run is
        /// won outright, not continued.
        case runCompleted

        /// Speaks to the player, not the game model: "wave clear" is an internal
        /// notion and does not tell someone they just won.
        var headline: String {
            switch self {
            case .runCompleted: return "YOU WIN"
            case .waveCleared: return "WAVE CLEAR"
            case .stalemate, .drawnByRepetition, .drawnByMoveLimit: return "DRAW"
            case .whiteMated, .livesDepleted, .blackBreachedRank1, .whiteKingDestroyed:
                return "GAME OVER"
            }
        }

        var detail: String {
            switch self {
            case .whiteMated:            return "WHITE CHECKMATED"
            case .waveCleared:           return "BLACK KING DEFEATED"
            case .runCompleted:          return "ALL \(LevelManager.finalLevel) WAVES CLEARED"
            case .stalemate:             return "NO LEGAL MOVES"
            case .drawnByRepetition:     return "SAME POSITION THREE TIMES"
            case .drawnByMoveLimit:      return "\(ChessEngine.quietMoveLimit) MOVES, NO CAPTURE"
            case .livesDepleted:         return "OUT OF LIVES"
            case .blackBreachedRank1:    return "THE FLEET BROKE THROUGH"
            case .whiteKingDestroyed:    return "WHITE KING DESTROYED"
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
            case .waveCleared, .runCompleted: return true
            case .whiteMated, .stalemate, .drawnByRepetition, .drawnByMoveLimit,
                 .livesDepleted, .blackBreachedRank1, .whiteKingDestroyed:
                return false
            }
        }
    }

    private static let cyan    = NeonPalette.cyan
    private static let magenta = NeonPalette.magenta
    private static let orange  = NeonPalette.orange
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
