// SpaceshipNode.swift
// The player ship: horizontal movement, respawn invincibility, shield state.
// Movement is driven by a signed direction set from GameAction, integrated in
// update(deltaTime:bounds:) so travel is frame-rate independent.

import SpriteKit

final class SpaceshipNode: SKSpriteNode {

    static let speed: CGFloat = 420          // points per second
    private static let displayHeight: CGFloat = 40

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
