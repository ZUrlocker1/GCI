// SpaceshipNode.swift
// The player ship: horizontal movement, respawn invincibility, shield state.
// Movement is driven by a signed direction set from GameAction, integrated in
// update(deltaTime:bounds:) so travel is frame-rate independent.

import SpriteKit

final class SpaceshipNode: SKSpriteNode {

    /// Points per second. 420 originally; 30% slower after playtest — at full
    /// speed the shortest tap overshot the file you were aiming at, and aiming
    /// is the whole game once the fleet sweep opens narrow lanes.
    static let speed: CGFloat = 294
    private static let displayHeight: CGFloat = 40
    private static let rapidFireName = "rapidFire"

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

    func applyShield() {
        hasShield = true
        // Phase 2+: add shield bubble child node
    }

    func removeShield(absorbed: Bool = false) {
        hasShield = false
        // Phase 2+: shield-shatter particle burst if absorbed
    }
}
