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
    private static let beamName = "kingBeam"

    init(owner: ProjectileState.Owner) {
        self.owner = owner
        let height: CGFloat = owner == .player ? 18 : 14
        let tint = owner == .player ? NeonPalette.cyan : NeonPalette.magentaLight
        super.init(texture: Self.solidTexture, color: tint,
                   size: CGSize(width: Self.width, height: height))
        colorBlendFactor = 1.0
        zPosition = 7
        isHidden = true

        let body = SKPhysicsBody(rectangleOf: size)
        // MUST be dynamic. SpriteKit only evaluates a contact pair when at
        // least one body is dynamic — two static bodies never produce a
        // didBegin callback at all, which is exactly why nothing collided when
        // this was first written. Pieces and the ship stay static; the laser is
        // the moving half, so it carries the dynamic flag.
        //
        // It is still driven entirely by SKAction, not by the simulation:
        // gravity off, no collision response, no damping or rotation. The body
        // exists only to generate contacts.
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.friction = 0
        body.restitution = 0
        body.usesPreciseCollisionDetection = true   // thin and fast — avoid tunnelling
        body.categoryBitMask = owner == .player ? PhysicsCategory.playerLaser : PhysicsCategory.enemyShot
        body.contactTestBitMask = PhysicsCategory.none   // parked; set on fire
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    /// §20 Phase 3.2 bitmask spec: player laser tests only pieces (not the
    /// ship, not enemy shots); enemy shots test only white pieces + ship.
    private var liveContactMask: UInt32 {
        owner == .player
            ? (PhysicsCategory.enemyPiece | PhysicsCategory.friendlyPiece)
            : (PhysicsCategory.friendlyPiece | PhysicsCategory.ship)
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
        guard speed > 0, travelDistance > 0 else { return }
        state = ProjectileState(owner: owner, damage: damage, speed: speed)
        position = origin
        isHidden = false
        // Only a live laser tests for contacts, so a parked one sitting on top
        // of a piece cannot fire a spurious hit.
        physicsBody?.contactTestBitMask = liveContactMask

        let dy = owner == .player ? travelDistance : -travelDistance
        let duration = TimeInterval(travelDistance / speed)
        let move = SKAction.moveBy(x: 0, y: dy, duration: duration)
        let finish = SKAction.run { [weak self] in self?.deactivate() }
        run(.sequence([move, finish]), withKey: Self.flightKey)
    }

    /// Redresses this round as the activated king's heavy shot — wider, longer
    /// and white-hot — or back to an ordinary bolt. Purely cosmetic; speed and
    /// damage are the caller's.
    func setHeavy(_ heavy: Bool) {
        let baseHeight: CGFloat = owner == .player ? 18 : 14
        // Only slightly bigger than an ordinary bolt. At 2.5x width it read as
        // a blocky rectangle rather than a projectile — the beam below is what
        // now carries the "this is the king's weapon" signal.
        size = heavy ? CGSize(width: Self.width * 1.3, height: baseHeight * 1.4)
                     : CGSize(width: Self.width, height: baseHeight)
        color = heavy ? .white
                      : (owner == .player ? NeonPalette.cyan : NeonPalette.magentaLight)

        childNode(withName: Self.beamName)?.removeFromParent()
        if heavy {
            // A long, thin light-red beam behind the head, so the shot reads as
            // a lance rather than a brick. Drawn as a child so the head keeps
            // its own crisp shape and the physics body stays small.
            let beam = SKSpriteNode(texture: Self.solidTexture,
                                    color: NeonPalette.kingBeamRed,
                                    size: CGSize(width: Self.width * 0.9,
                                                 height: baseHeight * 5))
            beam.name = Self.beamName
            beam.colorBlendFactor = 1.0
            beam.alpha = 0.75
            beam.zPosition = -1
            // Trails upward behind a downward-travelling enemy shot.
            beam.position = CGPoint(x: 0, y: beam.size.height / 2)
            addChild(beam)
            beam.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 0.07),
                .fadeAlpha(to: 0.85, duration: 0.07),
            ])))
        }
        // The body must follow, or a heavy round keeps a thin bolt's hitbox.
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = owner == .player ? PhysicsCategory.playerLaser : PhysicsCategory.enemyShot
        body.contactTestBitMask = isActive ? liveContactMask : PhysicsCategory.none
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    /// Stops the flight and returns the node to the pool. Safe to call whether
    /// the laser reached the end of its travel or was consumed by a contact.
    func deactivate() {
        guard isActive else { return }
        state = nil
        isHidden = true
        removeAction(forKey: Self.flightKey)
        childNode(withName: Self.beamName)?.removeFromParent()
        // Stop testing for contacts rather than clearing `isDynamic` — the body
        // has to stay dynamic to ever generate a contact again when re-fired.
        physicsBody?.contactTestBitMask = PhysicsCategory.none
        let callback = onDeactivate
        onDeactivate = nil
        callback?()
    }
}
