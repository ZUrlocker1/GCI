// TitleOverlayNode.swift
// Full title screen. Added to the bloom SKEffectNode so text gets neon glow.
// Phase 0: all content. Phase 1+ extends with fleet animation and real high scores.
//
// Font: PressStart2P-Regular.ttf — must be added to the Xcode project bundle.
//   1. Download from https://fonts.google.com/specimen/Press+Start+2P (free / OFL)
//   2. Drag PressStart2P-Regular.ttf into Xcode → GalacticChessInvaders target
//   3. In Info.plist add key "Fonts provided by application" with the filename
// Until the font is bundled, SpriteKit falls back to the system monospaced font.

import SpriteKit

final class TitleOverlayNode: SKNode {

    private static let titleFont  = "PressStart2P-Regular"
    private static let cyan    = SKColor(red: 0.07, green: 0.88, blue: 1.00, alpha: 1)
    private static let magenta = SKColor(red: 1.00, green: 0.13, blue: 0.38, alpha: 1)
    private static let orange  = SKColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1)

    override init() {
        super.init()
        setupTitle()
        setupSubtitle()
        setupFleetPreview()
        setupPressStart()
        setupHighScores()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Title

    private func setupTitle() {
        // Two-line layout to stay within the scene width at a readable size
        let lines: [(text: String, yOffset: CGFloat, size: CGFloat)] = [
            ("GALACTIC",        190, 40),
            ("CHESS INVADERS",  130, 32),
        ]

        for (text, y, fontSize) in lines {
            let label = SKLabelNode(fontNamed: Self.titleFont)
            label.text = text
            label.fontSize = fontSize
            label.fontColor = Self.cyan
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: y)
            addChild(label)

            // Slow hue cycle: cyan → magenta → cyan
            label.run(colorCycleAction(period: 4.0 + Double(y.truncatingRemainder(dividingBy: 40)) * 0.01))
        }
    }

    // Cycles fontColor through the neon palette using a custom action.
    private func colorCycleAction(period: Double) -> SKAction {
        let colors: [SKColor] = [Self.cyan, Self.magenta, Self.cyan]
        let stepDuration = period / Double(colors.count - 1)
        var steps: [SKAction] = []
        for i in 0..<(colors.count - 1) {
            let from = colors[i]
            let to   = colors[i + 1]
            let tween = SKAction.customAction(withDuration: stepDuration) { node, t in
                guard let label = node as? SKLabelNode else { return }
                let progress = CGFloat(t / stepDuration)
                label.fontColor = Self.lerp(from: from, to: to, t: progress)
            }
            steps.append(tween)
        }
        return SKAction.repeatForever(SKAction.sequence(steps))
    }

    private static func lerp(from: SKColor, to: SKColor, t: CGFloat) -> SKColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let clamp = max(0, min(1, t))
        return SKColor(red: r1 + (r2 - r1) * clamp,
                       green: g1 + (g2 - g1) * clamp,
                       blue: b1 + (b2 - b1) * clamp,
                       alpha: 1)
    }

    // MARK: - Subtitle

    private func setupSubtitle() {
        let label = SKLabelNode(fontNamed: Self.titleFont)
        label.text = "\u{2605} 40 YEARS IN THE MAKING \u{2605}"   // ★ ... ★
        label.fontSize = 12
        label.fontColor = Self.orange
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 92)
        addChild(label)
    }

    // MARK: - Fleet Preview

    private func setupFleetPreview() {
        let fleetNode = SKNode()
        fleetNode.position = CGPoint(x: 0, y: 44)

        let count    = 8
        let spacing  = CGFloat(56)
        let startX   = -CGFloat(count - 1) * spacing / 2

        // Use simple rounded rectangles as piece stand-ins until sprites are ready
        let pieceSize = CGSize(width: 24, height: 30)
        for i in 0..<count {
            let rect = SKShapeNode(rectOf: pieceSize, cornerRadius: 3)
            rect.fillColor   = Self.magenta.withAlphaComponent(0.6)
            rect.strokeColor = Self.magenta
            rect.lineWidth   = 1.5
            rect.position    = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            fleetNode.addChild(rect)
        }

        // Classic Invaders left-right sweep
        let sweepRight = SKAction.moveBy(x: 96, y: 0, duration: 1.4)
        sweepRight.timingMode = .easeInEaseOut
        let sweepLeft = SKAction.moveBy(x: -96, y: 0, duration: 1.4)
        sweepLeft.timingMode = .easeInEaseOut
        fleetNode.run(SKAction.repeatForever(SKAction.sequence([sweepRight, sweepLeft])))

        addChild(fleetNode)
    }

    // MARK: - Press Any Key

    private func setupPressStart() {
        let label = SKLabelNode(fontNamed: Self.titleFont)
        label.text = "PRESS ANY KEY TO START"
        label.fontSize = 16
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -28)
        addChild(label)

        // Classic blink: visible 0.6s, invisible 0.4s
        let blink = SKAction.sequence([
            SKAction.wait(forDuration: 0.6),
            SKAction.hide(),
            SKAction.wait(forDuration: 0.4),
            SKAction.unhide(),
        ])
        label.run(SKAction.repeatForever(blink))
    }

    // MARK: - High Scores

    private func setupHighScores() {
        let header = SKLabelNode(fontNamed: Self.titleFont)
        header.text = "HIGH SCORES"
        header.fontSize = 13
        header.fontColor = Self.cyan
        header.horizontalAlignmentMode = .center
        header.verticalAlignmentMode = .center
        header.position = CGPoint(x: 0, y: -80)
        addChild(header)

        // Divider line
        let divider = SKShapeNode(rectOf: CGSize(width: 380, height: 1))
        divider.fillColor   = Self.cyan.withAlphaComponent(0.4)
        divider.strokeColor = .clear
        divider.position    = CGPoint(x: 0, y: -96)
        addChild(divider)

        // Top 5 entries from ScoreManager, falling back to placeholder dashes
        let entries = ScoreManager.shared.topHighScores(limit: 5)
        for i in 0..<5 {
            let y = CGFloat(-112 - i * 26)

            let rank = SKLabelNode(fontNamed: Self.titleFont)
            rank.text = "\(i + 1)."
            rank.fontSize = 11
            rank.fontColor = Self.orange
            rank.horizontalAlignmentMode = .left
            rank.verticalAlignmentMode = .center
            rank.position = CGPoint(x: -170, y: y)
            addChild(rank)

            let initials = SKLabelNode(fontNamed: Self.titleFont)
            initials.text = i < entries.count ? entries[i].initials.padding(toLength: 8, withPad: " ", startingAt: 0) : "---"
            initials.fontSize = 11
            initials.fontColor = .white
            initials.horizontalAlignmentMode = .left
            initials.verticalAlignmentMode = .center
            initials.position = CGPoint(x: -130, y: y)
            addChild(initials)

            let score = SKLabelNode(fontNamed: Self.titleFont)
            score.text = i < entries.count ? String(format: "%07d", entries[i].score) : "-------"
            score.fontSize = 11
            score.fontColor = .white
            score.horizontalAlignmentMode = .right
            score.verticalAlignmentMode = .center
            score.position = CGPoint(x: 60, y: y)
            addChild(score)

            let level = SKLabelNode(fontNamed: Self.titleFont)
            level.text = i < entries.count ? "L\(entries[i].level)" : ""
            level.fontSize = 11
            level.fontColor = Self.cyan.withAlphaComponent(0.7)
            level.horizontalAlignmentMode = .left
            level.verticalAlignmentMode = .center
            level.position = CGPoint(x: 74, y: y)
            addChild(level)
        }
    }
}
