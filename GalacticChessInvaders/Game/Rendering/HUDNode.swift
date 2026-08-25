import SpriteKit

@MainActor
final class HUDNode: SKNode {
    static let height: CGFloat = 36

    private let scoreValue = SKLabelNode()
    private let hiValue    = SKLabelNode()
    private let levelLabel = SKLabelNode()
    private var lifeShips: [SKSpriteNode] = []

    private static let cyan   = SKColor(red: 0.07, green: 0.88, blue: 1.00, alpha: 1)
    private static let orange = SKColor(red: 1.00, green: 0.73, blue: 0.12, alpha: 1)
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

        // Info button
        let btn = SKShapeNode(rect: CGRect(x: 820, y: 7, width: 70, height: 22), cornerRadius: 3)
        btn.fillColor = HUDNode.cyan.withAlphaComponent(0.12)
        btn.strokeColor = HUDNode.cyan; btn.lineWidth = 1; btn.name = "infoButton"; addChild(btn)
        let btnLbl = SKLabelNode()
        place(btnLbl, "? INFO", HUDNode.cyan, 8, 855, 18, align: .center)
        btnLbl.verticalAlignmentMode = .center; btnLbl.name = "infoButton"

        // Bottom separator
        let sep = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: .zero); path.addLine(to: CGPoint(x: sceneWidth, y: 0))
        sep.path = path
        sep.strokeColor = HUDNode.cyan.withAlphaComponent(0.25); sep.lineWidth = 0.5
        addChild(sep)
    }

    required init?(coder: NSCoder) { fatalError() }

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
