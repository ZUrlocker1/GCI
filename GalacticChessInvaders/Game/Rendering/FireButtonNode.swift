// FireButtonNode.swift
// The one tap in the game.
//
// docs/IOS-Port.md §4 settles the control scheme: drag in the ship's lane
// with the left thumb, fire with the right. Auto-fire is out — in GCI your
// own pieces sit in your firing line on every shot, so firing has to be a
// decision — which is what makes an explicit control necessary rather than
// merely conventional.
//
// It lives in the right-hand margin, which is the only part of the layout
// carrying nothing: every readout in the game is in the left gutter. That
// margin exists at 96pt precisely so the board is not shoved against the
// edge, and it turns out to be exactly where a right thumb already is in
// landscape.
//
// Drawn rather than imaged, so it scales with the board like everything else
// and needs no asset.

import SpriteKit

@MainActor
final class FireButtonNode: SKNode {

    /// Big enough for a thumb without crowding the 96pt margin it sits in.
    static let diameter: CGFloat = 76

    private let ring = SKShapeNode(circleOfRadius: FireButtonNode.diameter / 2)
    private let label = SKLabelNode(fontNamed: "PressStart2P-Regular")

    /// Held down. The scene reads this rather than the node tracking its own
    /// firing, so the button stays a control and the game stays the game.
    private(set) var isHeld = false

    override init() {
        super.init()
        zPosition = 30      // over the playfield, under every panel

        ring.fillColor = NeonPalette.cyan.withAlphaComponent(0.10)
        ring.strokeColor = NeonPalette.cyan.withAlphaComponent(0.55)
        ring.lineWidth = 2
        ring.glowWidth = 3
        addChild(ring)

        label.text = "FIRE"
        label.fontSize = 10
        label.fontColor = NeonPalette.cyan.withAlphaComponent(0.8)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Scaled with the board, so it is the same size relative to the ship on
    /// every device rather than shrinking to nothing on a large screen.
    func adopt(scale: CGFloat) {
        setScale(scale)
    }

    /// Whether a point in the scene is on the button.
    ///
    /// Generous: `diameter` is the drawn circle, and the target is half as
    /// much again. A thumb is wider than what it is aiming at, and a missed
    /// shot in this game is a piece of White's that survives.
    func contains(scenePoint: CGPoint) -> Bool {
        let radius = (Self.diameter / 2) * 1.5 * xScale
        let dx = scenePoint.x - position.x, dy = scenePoint.y - position.y
        return dx * dx + dy * dy <= radius * radius
    }

    func setHeld(_ held: Bool) {
        guard held != isHeld else { return }
        isHeld = held
        ring.fillColor = NeonPalette.cyan.withAlphaComponent(held ? 0.32 : 0.10)
        ring.strokeColor = NeonPalette.cyan.withAlphaComponent(held ? 0.95 : 0.55)
        label.fontColor = NeonPalette.cyan.withAlphaComponent(held ? 1.0 : 0.8)
    }
}
