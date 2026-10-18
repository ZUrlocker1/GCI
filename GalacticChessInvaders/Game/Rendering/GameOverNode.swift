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
        /// One of each. The overlay sizes itself against the longest headline
        /// in here rather than the one it is showing, and the suite sweeps it.
        static let representatives: [Outcome] = [
            .whiteMated, .stalemate, .drawnByRepetition, .drawnByMoveLimit,
            .livesDepleted, .blackBreachedRank1, .whiteKingDestroyed,
            .waveCleared(next: 2), .runCompleted,
        ]

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
    private static let font    = NeonPalette.font

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
        // half as much again as an iPhone has, and more than a small Mac window
        // has either.
        //
        // The whole block rides `bannerScale`, so the headline shrinks *with*
        // the score and the prompt rather than against them. Shrinking the
        // headline alone to fit the width was rejected for exactly that reason:
        // it ends up smaller than the score beneath it. Scaling the block keeps
        // the hierarchy and loses only the absolute size, which is what a 400pt
        // scene wanted to lose.
        //
        // Wrapping stays as the backstop for the long terminal headlines, and
        // both wrapped labels grow *upward*: `liftForExtraLines` keeps the first
        // line where it was, so nothing below moves and the block stays composed
        // around the same centre however many lines the message runs to. There
        // is nothing above the headline but the scrim.
        let usable = sceneSize.width - Self.sideMargin * 2
        let s = Self.scale(in: sceneSize)

        let headline = label(outcome.headline, 40 * s,
                             outcome.isFavourable ? Self.cyan : Self.magenta)
        headline.position = CGPoint(x: centre.x, y: centre.y + 78 * s)
        wrap(headline, to: usable)
        addChild(headline)

        let detail = label(outcome.detail, 12 * s, .white.withAlphaComponent(0.75))
        detail.position = CGPoint(x: centre.x, y: centre.y + 40 * s)
        wrap(detail, to: usable)
        addChild(detail)

        let scoreLabel = label("FINAL SCORE  \(score)", 18 * s, Self.orange)
        scoreLabel.position = CGPoint(x: centre.x, y: centre.y - 6 * s)
        addChild(scoreLabel)

        #if os(iOS)
        if case .waveCleared = outcome {
            addPrompt(outcome.prompt, at: centre, usable: usable, scale: s)
        } else {
            // Deliberately unscaled: these are touch targets before they are
            // type, and 44pt is the floor regardless of how small the board got.
            addButtons(at: centre)
        }
        #else
        addPrompt(outcome.prompt, at: centre, usable: usable, scale: s)
        #endif
    }

    private func addPrompt(_ text: String, at centre: CGPoint, usable: CGFloat,
                           scale: CGFloat) {
        let prompt = label(text, 20 * scale, Self.cyan)
        prompt.position = CGPoint(x: centre.x, y: centre.y - 62 * scale)
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

    /// How much of the scene's width the headline may run to.
    ///
    /// `SceneLayout.bannerScale` follows the *board*, which is the right
    /// instinct on a Mac and on an iPad and the wrong one on a phone held
    /// upright: there the board is nearly the full width of the screen, so a
    /// banner tied to it is too. Measured at 88% of a Pro Max in portrait, which
    /// is a wall of text rather than a headline.
    private static let maxHeadlineFraction: CGFloat = 0.72

    /// The block's scale: the board's, pulled down further if the longest
    /// headline would still run past `maxHeadlineFraction`.
    ///
    /// Sized against the longest headline rather than the one being shown, so
    /// every end-of-run screen on a given device is set at the same size.
    /// Measuring each outcome's own string instead renders GAME OVER at 24pt
    /// and LEVEL CLEARED! at 20pt on the same phone, which reads as a bug.
    ///
    /// Measured rather than counted: Press Start 2P advances one em per
    /// character so the arithmetic would work, but it is the rendered width
    /// that has to fit.
    ///
    /// The whole block moves together — scaling only the headline is what makes
    /// it smaller than the score beneath it.
    private static func scale(in sceneSize: CGSize) -> CGFloat {
        let base = SceneLayout.bannerScale
        let allowed = sceneSize.width * maxHeadlineFraction
        guard allowed > 0 else { return base }

        let widest = Outcome.representatives
            .map(\.headline)
            .max { $0.count < $1.count } ?? ""
        let probe = SKLabelNode(fontNamed: font)
        probe.text = widest
        probe.fontSize = 40 * base

        guard probe.frame.width > allowed else { return base }
        return base * (allowed / probe.frame.width)
    }

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
        let node = SKLabelNode.neon(text, size: size, color: color, vertical: .center)
        node.zPosition = 1
        return node
    }
}
