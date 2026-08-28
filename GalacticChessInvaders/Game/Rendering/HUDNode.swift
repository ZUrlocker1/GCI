import SpriteKit

@MainActor
final class HUDNode: SKNode {
    static let height: CGFloat = 36

    private let scoreValue = SKLabelNode()
    private let hiValue    = SKLabelNode()
    private let levelLabel = SKLabelNode()
    private var lifeShips: [SKSpriteNode] = []

    private static let cyan   = NeonPalette.cyan
    private static let orange = NeonPalette.orange
    private static let font   = "PressStart2P-Regular"

    init(sceneWidth: CGFloat) {
        super.init()

        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: sceneWidth, height: HUDNode.height))
        bg.fillColor = SKColor(white: 0, alpha: 0.55); bg.strokeColor = .clear; bg.zPosition = -1
        addChild(bg)

        // Score
        let scoreTitleLbl = SKLabelNode()
        place(scoreTitleLbl, "SCORE", HUDNode.orange, 8,  10,  24)
        place(scoreValue,    "0",      .white,         11, 10,  10)
        scoreValue.name = "scoreValue"

        // Hi-score
        let hiTitleLbl = SKLabelNode()
        place(hiTitleLbl, "HI",     HUDNode.orange, 8,  200, 24)
        place(hiValue,    "0",      HUDNode.orange, 11, 200, 10)
        hiValue.name = "hiValue"

        // Level
        place(levelLabel, "LEVEL 01", HUDNode.cyan, 11, 480, 18, align: .center)
        levelLabel.verticalAlignmentMode = .center
        levelLabel.name = "levelLabel"

        // Life ships
        for (i, xPos) in [630, 660, 690].enumerated() {
            let ship = SKSpriteNode(imageNamed: "ship-player")
            if ship.size.height > 0 { ship.setScale(18 / ship.size.height) }
            ship.color = HUDNode.cyan; ship.colorBlendFactor = 0.2
            ship.position = CGPoint(x: CGFloat(xPos), y: 18)
            ship.name = "lifeShip\(i)"; addChild(ship); lifeShips.append(ship)
        }

        addChild(HUDNode.makeNavButtons())

        // Bottom separator
        let sep = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: .zero); path.addLine(to: CGPoint(x: sceneWidth, y: 0))
        sep.path = path
        sep.strokeColor = HUDNode.cyan.withAlphaComponent(0.25); sep.lineWidth = 0.5
        addChild(sep)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// SET and INFO, in the top right corner and nowhere else — the same corner
    /// a panel's BACK returns to, so the control that gets you in and the one
    /// that gets you out are in one place.
    ///
    /// Built here rather than inline because the title screen needs the same
    /// pair and has no HUD: two hand-placed copies of a corner drift apart, and
    /// the whole point of the corner is that it does not move. Laid out in
    /// HUD-local coordinates, so the title screen offsets the container rather
    /// than repeating the numbers.
    static func makeNavButtons() -> SKNode {
        let nav = SKNode()
        // `hotkey` is the index of the character that is also the keyboard
        // shortcut. Press Start 2P advances exactly one em per character, so
        // the rule under it is arithmetic rather than a measured guess.
        for (name, text, x, centre, hotkey) in
            [("settingsButton", "SET",    CGFloat(742), CGFloat(44), 0),
             ("infoButton",     "? INFO", CGFloat(820), CGFloat(35), 2)] {
            let btn = SKShapeNode(rect: CGRect(x: x, y: 7, width: 70, height: 22), cornerRadius: 3)
            btn.fillColor = HUDNode.cyan.withAlphaComponent(0.12)
            btn.strokeColor = HUDNode.cyan; btn.lineWidth = 1; btn.name = name
            nav.addChild(btn)

            let lbl = SKLabelNode(fontNamed: HUDNode.font)
            lbl.text = text; lbl.fontSize = 8; lbl.fontColor = HUDNode.cyan
            lbl.horizontalAlignmentMode = .center; lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: x + centre, y: 18)
            lbl.name = name
            nav.addChild(lbl)

            let charX = x + centre - CGFloat(text.count) * 4 + CGFloat(hotkey) * 8
            let rule = SKShapeNode(rect: CGRect(x: charX + 0.5, y: 11, width: 7, height: 1))
            rule.fillColor = HUDNode.cyan
            rule.strokeColor = .clear
            rule.name = name
            nav.addChild(rule)

            if name == "settingsButton" {
                let gear = HUDNode.gearIcon()
                gear.position = CGPoint(x: x + 17, y: 18)
                gear.name = name
                nav.addChild(gear)
            }
        }
        return nav
    }

    /// A gear, drawn rather than typed: Press Start 2P has no such glyph, and a
    /// Unicode one would fall back to a system font in the middle of a row of
    /// arcade type. A ring, a hub and eight teeth — the least that still reads
    /// as a gear at this size rather than as a sun.
    static func gearIcon(radius r: CGFloat = 4.2) -> SKShapeNode {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        path.addEllipse(in: CGRect(x: -r * 0.34, y: -r * 0.34,
                                   width: r * 0.68, height: r * 0.68))
        for tooth in 0..<8 {
            let angle = CGFloat(tooth) * .pi / 4
            path.move(to: CGPoint(x: cos(angle) * r, y: sin(angle) * r))
            path.addLine(to: CGPoint(x: cos(angle) * (r + 2.2), y: sin(angle) * (r + 2.2)))
        }
        let node = SKShapeNode(path: path)
        node.strokeColor = HUDNode.cyan
        node.lineWidth = 1.3
        node.fillColor = .clear
        return node
    }

    private func place(_ node: SKLabelNode, _ text: String, _ color: SKColor,
                       _ size: CGFloat, _ x: CGFloat, _ y: CGFloat,
                       align: SKLabelHorizontalAlignmentMode = .left) {
        node.fontName = HUDNode.font; node.fontSize = size
        node.fontColor = color; node.text = text
        node.horizontalAlignmentMode = align; node.verticalAlignmentMode = .baseline
        node.position = CGPoint(x: x, y: y); addChild(node)
    }

    func updateScore(_ score: Int)   { scoreValue.text  = "\(score)" }
    func updateHiScore(_ score: Int) { hiValue.text     = "\(score)" }
    func updateLevel(_ level: Int)   { levelLabel.text  = String(format: "LEVEL %02d", level) }
    func updateLives(_ count: Int)   { lifeShips.enumerated().forEach { $1.isHidden = $0 >= count } }
}
