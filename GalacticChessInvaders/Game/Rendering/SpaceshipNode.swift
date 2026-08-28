// SpaceshipNode.swift
// The player ship: horizontal movement, respawn invincibility, shield state.
// Movement is driven by a signed direction set from GameAction, integrated in
// update(deltaTime:bounds:) so travel is frame-rate independent.

import SpriteKit

final class SpaceshipNode: SKSpriteNode {

    /// Points per second. 420 originally; 30% slower after playtest — at full
    /// speed the shortest tap overshot the file you were aiming at, and aiming
    /// is the whole game once the fleet sweep opens narrow lanes.
    static let baseSpeed: CGFloat = 294
    /// The playtested speed with the player's own adjustment applied. The
    /// slider is clamped narrow in `GameSettings` so the finding above cannot
    /// be undone wholesale.
    @MainActor
    static var speed: CGFloat { baseSpeed * GameSettings.shared.shipSpeedScale }
    /// Not private: the spray's ceiling is derived from where the muzzle sits,
    /// which is the ship's lane plus half its hull.
    static let displayHeight: CGFloat = 40
    private static let rapidFireName = "rapidFire"
    private static let shieldName = "shieldBubble"

    private(set) var isInvincible = false
    private(set) var hasShield = false

    /// -1 left, 0 stopped, +1 right.
    var direction: CGFloat = 0

    init() {
        let texture = SKTexture(imageNamed: "ship-player")
        let source = texture.size()
        let scale = source.height > 0 ? Self.displayHeight / source.height : 1
        super.init(texture: texture,
                   color: .clear,
                   size: CGSize(width: source.width * scale, height: Self.displayHeight))
        colorBlendFactor = 0.15
        color = NeonPalette.cyan
        zPosition = 6

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ship
        body.contactTestBitMask = PhysicsCategory.none   // the enemy shot side tests for this
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Fills the hull green while Rapid Fire is up (§7.2), the same green an
    /// armored pawn wears and the transporter arrives in.
    ///
    /// The gutter notice announces each promotion but is gone in a second; this
    /// is the standing reminder of what the ship is currently carrying. It
    /// brightens with the stack, so four promotions look like more than one
    /// without needing a number on screen.
    ///
    /// `stacks` is how many the player has earned — zero clears it.
    func setRapidFire(stacks: Int) {
        childNode(withName: Self.rapidFireName)?.removeFromParent()
        guard stacks > 0 else { return }

        let fill = SKSpriteNode(texture: Silhouette.filled(forTexture: "ship-player"),
                                color: NeonPalette.armorFill, size: size)
        fill.name = Self.rapidFireName
        fill.colorBlendFactor = 1
        fill.zPosition = -0.4          // inside the hull, behind its outline
        let maximum = SpaceshipState.maxLaserCap - SpaceshipState.baseLaserCap
        let depth = CGFloat(min(stacks, maximum)) / CGFloat(max(1, maximum))
        let peak = 0.3 + 0.3 * depth
        fill.alpha = peak
        addChild(fill)
        // A faster pulse than the pawn's, because this one is about rate of
        // fire and should read as running hot rather than as holding.
        fill.run(.repeatForever(.sequence([
            .fadeAlpha(to: peak * 0.5, duration: 0.4),
            .fadeAlpha(to: peak, duration: 0.4),
        ])))
    }

    /// Integrate movement, clamped to `bounds` (x range of the travel lane).
    func update(deltaTime: TimeInterval, bounds: ClosedRange<CGFloat>) {
        guard direction != 0 else { return }
        let next = position.x + direction * Self.speed * CGFloat(deltaTime)
        position.x = min(max(next, bounds.lowerBound), bounds.upperBound)
    }

    // MARK: - States

    func startRespawnInvincibility(duration: TimeInterval = 2.0) {
        isInvincible = true
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        run(SKAction.repeat(flash, count: Int(duration / 0.2))) { [weak self] in
            self?.isInvincible = false
            self?.alpha = 1.0
        }
    }

    /// §13.2's Repair Scout reward: "a cyan hexagonal outline softly pulses
    /// around the ship while active".
    ///
    /// A hexagon rather than a circle on purpose — a circle around the ship
    /// reads as the same ring the black king wears when its forcefield is up
    /// (§10.1), and the two must never be confusable: one means the player is
    /// protected, the other means the target is not shootable.
    func applyShield() {
        guard !hasShield else { return }
        hasShield = true

        let radius = max(size.width, size.height) * 0.78
        let path = CGMutablePath()
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3 + .pi / 6
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.82)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()

        let bubble = SKShapeNode(path: path)
        bubble.name = Self.shieldName
        bubble.strokeColor = NeonPalette.cyan
        bubble.fillColor = NeonPalette.cyan.withAlphaComponent(0.06)
        bubble.lineWidth = 1.6
        bubble.glowWidth = 2.5
        bubble.zPosition = 0.5
        addChild(bubble)
        bubble.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.45, duration: 0.7),
            .fadeAlpha(to: 1.0, duration: 0.7),
        ])))
    }

    func removeShield(absorbed: Bool = false) {
        hasShield = false
        guard let bubble = childNode(withName: Self.shieldName) else { return }
        bubble.removeAllActions()
        guard absorbed else { return bubble.removeFromParent() }
        // §13.2: "the shield shatters in a particle burst". A hard flash to
        // white and a fast expansion outward — the player has just survived
        // something that would have killed them and should be in no doubt.
        bubble.run(.sequence([
            .group([.scale(to: 1.7, duration: 0.22), .fadeOut(withDuration: 0.22)]),
            .removeFromParent(),
        ]))
        if let shape = bubble as? SKShapeNode {
            shape.strokeColor = .white
            shape.lineWidth = 3
        }
    }
}
