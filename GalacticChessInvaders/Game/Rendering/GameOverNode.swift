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
// **The same question, in touch form.** They were `NEW GAME` and `TITLE`
// first, which made the screen ask nothing and then offer two destinations —
// the player had to work out that one of them was "yes". Asking `NEW GAME?`
// and answering it `YES` / `NO` is what the Mac has always done, and the two
// platforms now differ only in whether you press the letter or the button.
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
    static let yesButtonName = "gameOverYes"
    static let noButtonName  = "gameOverNo"

    init(outcome: Outcome, score: Int, sceneSize: CGSize) {
        super.init()

        // Dim the board rather than hide it, so the mating position stays visible.
        let scrim = SKShapeNode(rect: CGRect(origin: .zero, size: sceneSize))
        scrim.fillColor = SKColor(white: 0, alpha: 0.72)
        scrim.strokeColor = .clear
        scrim.zPosition = 0
        addChild(scrim)

        let centre = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)

        // "LEVEL CLEARED!" is fourteen characters at 40pt, which wants 560 —
        // half as much again as an iPhone has. Wrapped rather than shrunk,
        // because shrinking the headline to fit a phone makes it smaller than
        // the score beneath it.
        //
        // Both grow *upward*: `liftForExtraLines` keeps the first line where it
        // was, so nothing below moves and the block stays composed around the
        // same centre however many lines the message runs to. There is nothing
        // above the headline but the scrim.
        let usable = sceneSize.width - Self.sideMargin * 2

        let headline = label(outcome.headline, 40,
                             outcome.isFavourable ? Self.cyan : Self.magenta)
        headline.position = CGPoint(x: centre.x, y: centre.y + 78)
        wrap(headline, to: usable)
        addChild(headline)

        let detail = label(outcome.detail, 12, .white.withAlphaComponent(0.75))
        detail.position = CGPoint(x: centre.x, y: centre.y + 40)
        wrap(detail, to: usable)
        addChild(detail)

        let scoreLabel = label("FINAL SCORE  \(score)", 18, Self.orange)
        scoreLabel.position = CGPoint(x: centre.x, y: centre.y - 6)
        addChild(scoreLabel)

        #if os(iOS)
        if case .waveCleared = outcome {
            addPrompt(outcome.prompt, at: centre, usable: usable)
        } else {
            addButtons(at: centre)
        }
        #else
        addPrompt(outcome.prompt, at: centre, usable: usable)
        #endif
    }

    private func addPrompt(_ text: String, at centre: CGPoint, usable: CGFloat) {
        let prompt = label(text, 20, Self.cyan)
        prompt.position = CGPoint(x: centre.x, y: centre.y - 62)
        // "PRESS ANY KEY  ·  LEVEL 2" is 500pt at 20 — wider than any phone and
        // wider than a Mac window with the log sidebar open.
        wrap(prompt, to: usable, growUpward: false)
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
    /// `NEW GAME?` over `YES` / `NO`, which is the Mac's prompt with the two
    /// keys turned into targets.
    ///
    /// YES is cyan and first; NO is the quieter of the two and goes to the
    /// title, exactly as any key other than Y does on the Mac.
    private func addButtons(at centre: CGPoint) {
        let question = label("NEW GAME?", 20, Self.cyan)
        question.position = CGPoint(x: centre.x, y: centre.y - 48)
        addChild(question)

        let gap: CGFloat = 24
        let yesW = Self.buttonWidth("YES")
        let noW = Self.buttonWidth("NO")
        let left = centre.x - (yesW + gap + noW) / 2
        let y = centre.y - 100

        button("YES", name: Self.yesButtonName,
               x: left, y: y, colour: Self.cyan)
        button("NO", name: Self.noButtonName,
               x: left + yesW + gap, y: y,
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

    /// Air either side of the widest line, so a wrapped message does not run
    /// to the bezel on a phone.
    private static let sideMargin: CGFloat = 24

    /// Wraps a label at spaces, and lifts it so the extra lines grow upward.
    ///
    /// Growing upward rather than from the centre is what keeps the rest of the
    /// block still: the first line stays on the baseline it was placed at, so a
    /// one-line message and a three-line one put the score and the prompt in
    /// exactly the same place.
    private func wrap(_ node: SKLabelNode, to width: CGFloat,
                      growUpward: Bool = true) {
        let before = node.frame.height
        node.wrapCentred(to: width, fontNamed: Self.font)
        // Whichever way the empty space is. The headline grows up into the gap
        // above it; the prompt grows down, because the score is above it.
        let extra = max(0, node.frame.height - before) / 2
        node.position.y += growUpward ? extra : -extra
    }

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
