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
    private static let exhaustKey = "exhaust"

    /// An angled round is longer and narrower than a straight bolt: its whole
    /// job is to read as travelling *along* a line the player has to judge.
    private static let diagonalSize = CGSize(width: 3.4, height: 22)
    /// Slightly wider than a straight bolt's 4pt, so an angled shot is no
    /// harder to land than a vertical one.
    private static let diagonalHitRadius: CGFloat = 4.5

    /// Whether the current body is the angled round's circle. Tracked because
    /// `size` alone cannot tell the two apart on a re-fire.
    private var bodyIsRound = false
    private var isHeavy = false
    private var isDiagonal = false

    /// The angled round's dressing — a bright nose and a two-stage exhaust.
    /// Built once and shown or hidden per shot rather than created per shot
    /// (§18: no allocation during play). Laid out along local ±y, which
    /// `aim(dx:dy:)` then points down the flight path.
    private let missileRig = SKNode()

    init(owner: ProjectileState.Owner) {
        self.owner = owner
        let height: CGFloat = owner == .player ? 18 : 14
        let tint = owner == .player ? NeonPalette.cyan : NeonPalette.magentaLight
        super.init(texture: Self.solidTexture, color: tint,
                   size: CGSize(width: Self.width, height: height))
        colorBlendFactor = 1.0
        zPosition = 7
        isHidden = true

        installBody(for: size)
        buildMissileRig()
    }

    /// Fits a fresh contact-only body to `size`, preserving whether this round
    /// is currently live. Every place that changes the node's size has to go
    /// through here, or a re-dressed round keeps the previous shape's hitbox —
    /// and rebuilding a body silently drops the contact mask, which is why it
    /// is re-derived from `isActive` rather than copied.
    private func installBody(for size: CGSize) {
        let body = bodyIsRound
            ? SKPhysicsBody(circleOfRadius: Self.diagonalHitRadius)
            : SKPhysicsBody(rectangleOf: size)
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
        // Both halves are gated on being in flight. A contact is reported when
        // *either* body's test matches the other's category, so a parked round
        // that keeps its category is still a target even with its own test
        // cleared — see `deactivate`.
        body.categoryBitMask = isActive ? liveCategory : PhysicsCategory.none
        body.contactTestBitMask = isActive ? liveContactMask : PhysicsCategory.none
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    /// A nose cone and a tapering two-stage exhaust, so an angled round reads
    /// as a missile pointed somewhere rather than as a tumbling slab. Local -y
    /// is the nose; `aim(dx:dy:)` turns that into the direction of travel.
    private func buildMissileRig() {
        let half = Self.diagonalSize.height / 2
        func part(_ size: CGSize, y: CGFloat, color: SKColor, alpha: CGFloat) -> SKSpriteNode {
            let node = SKSpriteNode(texture: Self.solidTexture, color: color, size: size)
            node.colorBlendFactor = 1.0
            node.alpha = alpha
            node.position = CGPoint(x: 0, y: y)
            return node
        }
        // A hot white tip overhanging the head slightly: the point of the round
        // is where it is going, so that is what should be brightest.
        missileRig.addChild(part(CGSize(width: 2.2, height: 7),
                                 y: -half - 1.5, color: .white, alpha: 0.95))
        // Exhaust, behind the head and fading as it goes.
        let trail = owner == .player ? NeonPalette.cyan : NeonPalette.shotPurple
        let near = part(CGSize(width: 2.6, height: 12), y: half + 5, color: trail, alpha: 0.55)
        let far  = part(CGSize(width: 1.6, height: 12), y: half + 17, color: trail, alpha: 0.22)
        missileRig.addChild(near)
        missileRig.addChild(far)
        missileRig.zPosition = -1
        missileRig.isHidden = true
        addChild(missileRig)
    }

    /// The unit vector this round is travelling along.
    ///
    /// Local +y is the tail (see `setDiagonal`), so the heading is the opposite
    /// of the rotated +y axis. Read it *before* `deactivate`, which resets the
    /// rotation — a spent round has no heading.
    var travelDirection: CGVector {
        CGVector(dx: sin(zRotation), dy: -cos(zRotation))
    }

    /// §20 Phase 3.2's bitmask spec, plus one addition: rounds now test each
    /// other, so Black's fire can shoot your shot out of the air. The spec
    /// explicitly excluded that; it is a deliberate departure, and it costs the
    /// player real shots, because a laser eaten in flight still counted against
    /// the two-round cap until it cleared.
    /// What this round *is*, while it is in flight. A parked one advertises
    /// nothing (see `deactivate`).
    private var liveCategory: UInt32 {
        owner == .player ? PhysicsCategory.playerLaser : PhysicsCategory.enemyShot
    }

    /// Set on a round that must not touch White's own pieces.
    ///
    /// §13.2's Gatling Barrage sprays five rounds at once without the player
    /// aiming any of them, so ordinary friendly fire would have the power-up
    /// demolish White's position as a side effect of being used. Handled by
    /// dropping `friendlyPiece` from the contact mask rather than by ignoring
    /// the hit in the resolver: a round that is not going to do anything should
    /// fly *through*, not be consumed by a piece it left unharmed.
    private var sparesFriendlies = false

    private var liveContactMask: UInt32 {
        guard owner == .player else {
            return PhysicsCategory.friendlyPiece | PhysicsCategory.ship
                 | PhysicsCategory.playerLaser
        }
        var mask = PhysicsCategory.enemyPiece | PhysicsCategory.enemyShot
                 | PhysicsCategory.raider
        if !sparesFriendlies { mask |= PhysicsCategory.friendlyPiece }
        return mask
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
    /// `lean` is the slope: sideways travel per unit of forward travel, 0 for
    /// straight, negative left. An angled shot therefore covers a longer path
    /// than `travelDistance`, and the duration is taken from the real path
    /// length — otherwise an angled round would cross the board faster than its
    /// stated speed (§21.3).
    /// `tint` overrides the round's own colour — a raider's shot is acid green
    /// (§12) whoever's pool it came out of.
    func fire(from origin: CGPoint, damage: Int, speed: CGFloat,
              travelDistance: CGFloat, lean: CGFloat = 0, tint: SKColor? = nil,
              sparesFriendlies: Bool = false) {
        guard speed > 0, travelDistance > 0 else { return }
        state = ProjectileState(owner: owner, damage: damage, speed: speed)
        // Before the masks are read below.
        self.sparesFriendlies = sparesFriendlies
        position = origin
        isHidden = false
        // Only a live laser tests for contacts, so a parked one sitting on top
        // of a piece cannot fire a spurious hit.
        physicsBody?.categoryBitMask = liveCategory
        physicsBody?.contactTestBitMask = liveContactMask

        let dy = owner == .player ? travelDistance : -travelDistance
        let dx = lean * travelDistance
        let path = (dx * dx + dy * dy).squareRoot()
        let duration = TimeInterval(path / speed)

        setDiagonal(lean != 0, dx: dx, dy: dy)
        if let tint { color = tint }

        let move = SKAction.moveBy(x: dx, y: dy, duration: duration)
        let finish = SKAction.run { [weak self] in self?.deactivate() }
        run(.sequence([move, finish]), withKey: Self.flightKey)
    }

    /// Dresses this round as §21.3's angled missile, or back to a straight
    /// bolt: longer, narrower, deep purple, with a nose and an exhaust.
    ///
    /// The rotation is the part that was wrong. `zRotation` turns the node's
    /// *own* axes, and a bolt's length is its y axis — so rotating an angled
    /// shot by 45° left the slab broadside to its own flight path, sliding
    /// sideways through the air. That is what read as a purple paddle rather
    /// than a missile. It is now aimed from the actual travel vector, which is
    /// also correct for a straight shot and for either owner.
    ///
    /// Heavy and diagonal never co-occur — the king's weapon is Level 9 and
    /// angled fire is Levels 7 and 10 — and this runs after `setHeavy`, so if
    /// they ever did meet, the diagonal dressing would win.
    private func setDiagonal(_ diagonal: Bool, dx: CGFloat, dy: CGFloat) {
        // Local +y is the tail, so +y must point *opposite* the travel.
        // R(z)·(0,1) = (-sin z, cos z), so z = atan2(dx, -dy).
        zRotation = atan2(dx, -dy)
        isDiagonal = diagonal
        applyDressing()

        missileRig.removeAction(forKey: Self.exhaustKey)
        if diagonal {
            // A slow flicker, so the exhaust reads as burning rather than drawn.
            missileRig.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.7, duration: 0.09),
                .fadeAlpha(to: 1.0, duration: 0.09),
            ])), withKey: Self.exhaustKey)
        } else {
            missileRig.alpha = 1
        }
    }

    /// Redresses this round as the activated king's heavy shot — wider, longer
    /// and white-hot — or back to an ordinary bolt. Purely cosmetic; speed and
    /// damage are the caller's.
    func setHeavy(_ heavy: Bool) {
        isHeavy = heavy
        let baseHeight: CGFloat = owner == .player ? 18 : 14
        applyDressing()

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
    }

    /// Size, colour and hitbox from `isHeavy` and `isDiagonal` together.
    ///
    /// These used to be set in two places that each assumed the other had not
    /// run. `setHeavy` is called before `fire`, and `fire` then re-dressed the
    /// round for its angle — which reset the king's heavy shot back to an
    /// ordinary bolt's size and colour while leaving its beam attached. One
    /// function owns the whole look now.
    private func applyDressing() {
        let baseHeight: CGFloat = owner == .player ? 18 : 14
        let target: CGSize
        if isHeavy {
            // Only slightly bigger than an ordinary bolt. At 2.5x width it read
            // as a blocky rectangle rather than a projectile — the beam is what
            // carries the "this is the king's weapon" signal.
            target = CGSize(width: Self.width * 1.3, height: baseHeight * 1.4)
        } else if isDiagonal {
            target = Self.diagonalSize
        } else {
            target = CGSize(width: Self.width, height: baseHeight)
        }
        size = target
        color = isHeavy ? .white
              : isDiagonal ? NeonPalette.shotPurple
              : (owner == .player ? NeonPalette.cyan : NeonPalette.magentaLight)
        missileRig.isHidden = !isDiagonal || isHeavy   // the beam is the king's trail
        // An angled round gets a *round* body, so its hitbox cannot depend on
        // the angle it happens to be travelling at. A rect aligned with the
        // flight path presents only its 3.4pt width to whatever it is aimed at,
        // and a bolt that thin grazes past corners the player reads as hits.
        bodyIsRound = isDiagonal
        installBody(for: target)
    }

    /// Stops the flight and returns the node to the pool. Safe to call whether
    /// the laser reached the end of its travel or was consumed by a contact.
    func deactivate() {
        guard isActive else { return }
        state = nil
        isHidden = true
        removeAction(forKey: Self.flightKey)
        zRotation = 0
        missileRig.isHidden = true
        missileRig.removeAction(forKey: Self.exhaustKey)
        missileRig.alpha = 1
        isHeavy = false
        isDiagonal = false
        childNode(withName: Self.beamName)?.removeFromParent()
        // Both masks, not just the test. A contact fires when *either* body's
        // contactTest matches the other's category — so a parked round that
        // still advertises `enemyShot` is a live target for any player laser
        // flying past, even though it tests for nothing itself and is hidden.
        //
        // That was harmless while the player's laser only tested pieces. The
        // moment rounds could shoot each other down it turned every spent
        // enemy shot into an invisible mine, sitting exactly where it died —
        // on a white piece, two squares above the firing line — and every
        // player shot that reached it detonated against nothing.
        //
        // `isDynamic` stays true: the body has to remain dynamic to generate a
        // contact again when re-fired.
        physicsBody?.categoryBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.none
        let callback = onDeactivate
        onDeactivate = nil
        callback?()
    }
}
