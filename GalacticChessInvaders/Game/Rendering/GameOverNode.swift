// GameOverNode.swift
// End-of-game overlay: outcome, final score, and the way on.
// Centred like the PAUSED banner, over a dimmed playfield so the final position
// stays readable behind it.
//
// The way on differs by platform, and has to. On the Mac it is the prompt
// `NEW GAME?  Y / N`. On iOS there is no Y, so 1.2's stopgap was a single
// `TAP TO CONTINUE` that always went to the title — a player who wanted
// another run had to tap twice and pass through the title screen to do it.
// docs/IOS-Port.md §4 called two real buttons the right answer; these are
// them.
//
// Only for the terminal outcomes. A cleared wave is one choice, not two, so
// it keeps its tap-anywhere prompt — a button there would be ceremony around
// the single thing you can do.

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
            case .waveCleared: return "LEVEL CLEARED!"
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
            case .waveCleared(let next): return InputPrompts.nextLevel(next)
            default:                     return InputPrompts.gameOver
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

    /// The scene hit-tests for these. Both the box and its label carry the
    /// name, which is what `GameScene.pressButton` needs to move them
    /// together.
    static let newGameButtonName = "gameOverNewGame"
    static let titleButtonName   = "gameOverTitle"

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

        #if os(iOS)
        if case .waveCleared = outcome {
            addPrompt(outcome.prompt, at: centre)
        } else {
            addButtons(at: centre)
        }
        #else
        addPrompt(outcome.prompt, at: centre)
        #endif
    }

    private func addPrompt(_ text: String, at centre: CGPoint) {
        let prompt = label(text, 20, Self.cyan)
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

    #if os(iOS)
    /// NEW GAME and TITLE, side by side and centred as a pair.
    ///
    /// NEW GAME first because it is what most people want after a run, and
    /// because it is the one the Mac's `Y` reaches with a single key.
    private func addButtons(at centre: CGPoint) {
        let gap: CGFloat = 24
        let newW = Self.buttonWidth("NEW GAME")
        let titleW = Self.buttonWidth("TITLE")
        let left = centre.x - (newW + gap + titleW) / 2
        let y = centre.y - 66

        button("NEW GAME", name: Self.newGameButtonName,
               x: left, y: y, colour: Self.cyan)
        button("TITLE", name: Self.titleButtonName,
               x: left + newW + gap, y: y,
               colour: SKColor.white.withAlphaComponent(0.7))
    }

    /// Press Start 2P advances exactly one em per character, the same
    /// arithmetic the rest of the game's chrome is placed by.
    private static func buttonWidth(_ text: String) -> CGFloat {
        CGFloat(text.count) * 14 + 36
    }

    private func button(_ text: String, name: String,
                        x: CGFloat, y: CGFloat, colour: SKColor) {
        let width = Self.buttonWidth(text)
        let height: CGFloat = 44        // a comfortable touch target

        let box = SKShapeNode(rect: CGRect(x: x, y: y - height / 2,
                                           width: width, height: height),
                              cornerRadius: 4)
        box.strokeColor = colour
        box.fillColor = colour.withAlphaComponent(0.14)
        box.lineWidth = 2
        box.name = name
        box.zPosition = 1
        addChild(box)

        let lbl = label(text, 14, colour)
        lbl.position = CGPoint(x: x + width / 2, y: y)
        lbl.name = name
        addChild(lbl)
    }
    #endif

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
