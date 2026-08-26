// LaserNode.swift
// Pooled laser projectile node (player lasers + enemy shots). Never removed
// from the scene graph — `fire`/`deactivate` toggle visibility and the flight
// action to avoid allocation during play (§18).
//
// No projectile art exists yet, so the beam is a solid tinted rect — the
// CIBloom filter already on `bloomNode` gives it a glow for free, the same
// trick the starfield dot texture uses.

import SpriteKit

final class LaserNode: SKSpriteNode {

    let owner: ProjectileState.Owner
    private(set) var state: ProjectileState?
    var isActive: Bool { state != nil }
    /// Fires exactly once, whether this laser reached the end of its flight or
    /// was consumed by a contact — the one place both paths converge. Set
    /// fresh before each `fire(...)` call; a stray earlier callback is cleared
    /// here so it can never double-fire on the next.
    var onDeactivate: (() -> Void)?

    private static let width: CGFloat = 4
    private static let flightKey = "fly"

    init(owner: ProjectileState.Owner) {
        self.owner = owner
        let height: CGFloat = owner == .player ? 18 : 14
        let tint = owner == .player ? NeonPalette.cyan : NeonPalette.magenta
        super.init(texture: Self.solidTexture, color: tint,
                   size: CGSize(width: Self.width, height: height))
        colorBlendFactor = 1.0
        zPosition = 7
        isHidden = true

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.usesPreciseCollisionDetection = true   // thin and fast — avoid tunnelling
        body.categoryBitMask = owner == .player ? PhysicsCategory.playerLaser : PhysicsCategory.enemyShot
        // §20 Phase 3.2 bitmask spec: player laser tests only pieces (not the
        // ship, not enemy shots); enemy shots test only white pieces + ship.
        body.contactTestBitMask = owner == .player
            ? (PhysicsCategory.enemyPiece | PhysicsCategory.friendlyPiece)
            : (PhysicsCategory.friendlyPiece | PhysicsCategory.ship)
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// A plain white pixel, stretched to `size` and tinted per instance.
    /// Built from a raw bitmap rather than `SKView.texture(from:)` — the latter
    /// can silently return nil before the view has ever rendered a frame, and
    /// this runs at class-load time. Same technique as the starfield's dot.
    private static let solidTexture: SKTexture = {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }()

    /// Fires straight up (player, from the ship) or down (enemy, from a fleet
    /// piece) from `origin`, dealing `state.damage` on contact. Deactivates on
    /// its own after `travelDistance` if nothing hits it first.
    func fire(from origin: CGPoint, damage: Int, speed: CGFloat, travelDistance: CGFloat) {
        state = ProjectileState(owner: owner, damage: damage, speed: speed)
        position = origin
        isHidden = false

        let dy = owner == .player ? travelDistance : -travelDistance
        let duration = TimeInterval(travelDistance / speed)
        let move = SKAction.moveBy(x: 0, y: dy, duration: duration)
        let finish = SKAction.run { [weak self] in self?.deactivate() }
        run(.sequence([move, finish]), withKey: Self.flightKey)
    }

    /// Stops the flight and returns the node to the pool. Safe to call whether
    /// the laser reached the end of its travel or was consumed by a contact.
    func deactivate() {
        guard isActive else { return }
        state = nil
        isHidden = true
        removeAction(forKey: Self.flightKey)
        physicsBody?.isDynamic = false
        let callback = onDeactivate
        onDeactivate = nil
        callback?()
    }
}
