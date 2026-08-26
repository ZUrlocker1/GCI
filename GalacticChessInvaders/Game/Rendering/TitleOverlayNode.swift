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
    private static let cyan    = NeonPalette.cyan
    private static let magenta = NeonPalette.magenta

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
            ("GALACTIC",        240, 60),
            ("CHESS INVADERS",  170, 48),
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
        label.fontSize = 18
        label.fontColor = Self.magenta
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 98)
        addChild(label)
    }

    // MARK: - Fleet Preview

    private func setupFleetPreview() {
        let fleetNode = SKNode()
        fleetNode.position = CGPoint(x: 0, y: 44)

        // Back rank — the fleet the player will face
        let pieces = ["rook","knight","bishop","queen","king","bishop","knight","rook"]
        let spacing: CGFloat = 76
        let targetHeight: CGFloat = 54       // scaled display height per piece
        let startX = -CGFloat(pieces.count - 1) * spacing / 2

        for (i, pieceName) in pieces.enumerated() {
            let textureName = "chess-b-\(pieceName)"
            let texture     = SKTexture(imageNamed: textureName)
            let texSize     = texture.size()
            let scale       = targetHeight / texSize.height
            let dispSize    = CGSize(width: texSize.width * scale, height: targetHeight)

            let sprite           = SKSpriteNode(texture: texture, size: dispSize)
            sprite.position      = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            sprite.color         = Self.magenta
            sprite.colorBlendFactor = 0.12
            fleetNode.addChild(sprite)
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
        header.position = CGPoint(x: 0, y: -130)
        addChild(header)

        // Divider line
        let divider = SKShapeNode(rectOf: CGSize(width: 380, height: 1))
        divider.fillColor   = Self.cyan.withAlphaComponent(0.4)
        divider.strokeColor = .clear
        divider.position    = CGPoint(x: 0, y: -146)
        addChild(divider)

        // Top 5 entries from ScoreManager (seeded with defaults if no real scores yet)
        let entries = ScoreManager.shared.topHighScores(limit: 5)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        for i in 0..<5 {
            let y = CGFloat(-162 - i * 26)

            let rank = SKLabelNode(fontNamed: Self.titleFont)
            rank.text = "\(i + 1)."
            rank.fontSize = 11; rank.fontColor = Self.magenta
            rank.horizontalAlignmentMode = .left; rank.verticalAlignmentMode = .center
            rank.position = CGPoint(x: -175, y: y)
            addChild(rank)

            let name = SKLabelNode(fontNamed: Self.titleFont)
            name.text = i < entries.count ? entries[i].initials : "---"
            name.fontSize = 11; name.fontColor = .white
            name.horizontalAlignmentMode = .left; name.verticalAlignmentMode = .center
            name.position = CGPoint(x: -140, y: y)
            addChild(name)

            let scoreStr = i < entries.count
                ? (formatter.string(from: NSNumber(value: entries[i].score)) ?? "\(entries[i].score)")
                : "---"
            let scoreLbl = SKLabelNode(fontNamed: Self.titleFont)
            scoreLbl.text = scoreStr
            scoreLbl.fontSize = 11; scoreLbl.fontColor = .white
            scoreLbl.horizontalAlignmentMode = .right; scoreLbl.verticalAlignmentMode = .center
            scoreLbl.position = CGPoint(x: 140, y: y)
            addChild(scoreLbl)
        }
    }
}
