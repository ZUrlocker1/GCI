// RaiderNode.swift
// A Raider Scout: §6's "Space Invaders mystery ship". Crosses the board at a
// fixed height, fires once straight down, exits the far side. 1 HP.
//
// Pooled like everything else that appears during play (§18): two nodes, which
// is `RaiderRules.maxOnScreen`, shown and hidden rather than allocated.

import SpriteKit

@MainActor
final class RaiderNode: SKSpriteNode {

    /// A quarter smaller than the first pass, which read as *bigger* than the
    /// chess pieces it flies past — wrong for something that is meant to be a
    /// passing bonus rather than part of the fleet.
    private static let displayHeight: CGFloat = 30
    private static let crossKey = "cross"

    /// Fired as the scout reaches its firing point, with its current position.
    var onFire: ((CGPoint) -> Void)?
    /// Fired when the crossing finishes or the scout is destroyed — either way
    /// the slot is free again.
    var onExit: (() -> Void)?

    private static let hullGrey = SKColor(red: 0.20, green: 0.30, blue: 0.24, alpha: 1)

    private(set) var isCrossing = false
    private(set) var hp = 0

    init() {
        let texture = SKTexture(imageNamed: "ship-scout")
        let source = texture.size()
        let scale = source.height > 0 ? Self.displayHeight / source.height : 1
        super.init(texture: texture, color: NeonPalette.acidGreen,
                   size: CGSize(width: source.width * scale, height: Self.displayHeight))
        colorBlendFactor = 0.55      // acid green over the sprite's own outline
        zPosition = 8                // over the fleet, under the HUD
        isHidden = true

        // A solid hull behind the outline. Every piece on this board is a
        // hollow outline, which is right for chess pieces standing on squares
        // — but a *ship* passing in front of them has to occlude them or it
        // reads as a decal rather than as something flying over. Grey-green so
        // it stays a machine and does not compete with the acid outline.
        let hull = SKSpriteNode(texture: Silhouette.filled(forTexture: "ship-scout"),
                                color: Self.hullGrey, size: size)
        hull.colorBlendFactor = 1
        hull.alpha = 0.96
        hull.zPosition = -0.1        // under this node's outline, still over the board
        addChild(hull)

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.none   // parked; set on launch
        body.contactTestBitMask = PhysicsCategory.none
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Sends the scout across from `from` to `to` at `y`, firing once on the
    /// way if `firing`.
    func cross(fromX: CGFloat, toX: CGFloat, y: CGFloat, firing: Bool,
               weave: CGFloat = 4) {
        stop()
        position = CGPoint(x: fromX, y: y)
        isHidden = false
        isCrossing = true
        hp = RaiderRules.scoutHP
        // Only a live scout is a target — the same rule the lasers learned the
        // hard way, where a parked body that kept its category was still hit.
        physicsBody?.categoryBitMask = PhysicsCategory.raider

        let distance = abs(toX - fromX)
        let duration = TimeInterval(distance / RaiderRules.scoutSpeed)
        let travel = SKAction.moveTo(x: toX, duration: duration)
        travel.timingMode = .linear

        var sequence: [SKAction] = [travel]
        if firing {
            // Split the crossing so the shot leaves from wherever the scout has
            // got to, rather than from a position decided in advance.
            let fraction = RaiderRules.fireFraction()
            let firingX = fromX + (toX - fromX) * fraction
            sequence = [
                .moveTo(x: firingX, duration: duration * TimeInterval(fraction)),
                .run { [weak self] in
                    guard let self else { return }
                    self.onFire?(CGPoint(x: self.position.x, y: self.position.y))
                },
                .moveTo(x: toX, duration: duration * TimeInterval(1 - fraction)),
            ]
        }
        run(.sequence(sequence + [.run { [weak self] in self?.finish() }]),
            withKey: Self.crossKey)

        // The vertical half of the path, running alongside the crossing.
        // A few points is a hover; a whole square is the weave later levels
        // fly, which makes aiming a vertical problem as well as a horizontal
        // one. Eased, so it turns rather than bouncing.
        let half = weave > 8 ? RaiderRules.weaveHalfPeriod : 0.5
        let up = SKAction.moveBy(x: 0, y: weave, duration: half)
        let down = SKAction.moveBy(x: 0, y: -weave, duration: half)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        // Starts half a swing in, so the scout enters mid-curve rather than
        // always at the top of one.
        run(.sequence([
            .moveBy(x: 0, y: weave / 2, duration: half / 2),
            .repeatForever(.sequence([down, down, up, up])),
        ]))

    }

    /// Takes a hit. Returns true if that destroyed it.
    func takeHit() -> Bool {
        guard isCrossing else { return false }
        hp -= 1
        guard hp <= 0 else { return false }
        finish()
        return true
    }

    /// Leaves play, whether shot or safely across.
    private func finish() {
        guard isCrossing else { return }
        stop()
        onExit?()
        onFire = nil
        onExit = nil
    }

    func stop() {
        removeAllActions()
        isCrossing = false
        isHidden = true
        physicsBody?.categoryBitMask = PhysicsCategory.none
    }
}
