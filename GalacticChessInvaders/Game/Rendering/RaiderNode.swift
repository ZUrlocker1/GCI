// RaiderNode.swift
// A Raider Scout: §6's "Space Invaders mystery ship". Crosses the board, fires
// once on the way, exits the far side.
//
// Also the special scouts of §13.2, which are the same crossing wearing a
// different hull and flying a different path. One node type rather than five,
// because everything that differs between them — colour, silhouette, size,
// speed, HP, flight — is data on `PowerUp` and `RaiderRules`, and everything
// that does not differ is the crossing itself.
//
// Pooled like everything else that appears during play (§18): two nodes, which
// is `RaiderRules.maxOnScreen`, shown and hidden rather than allocated.

import SpriteKit

/// §13.2's per-type appearance. Kept beside the node rather than on `PowerUp`
/// itself, which lives in the logic layer and may not import SpriteKit.
extension PowerUp {
    var tint: SKColor {
        switch self {
        case .rapidFire: return NeonPalette.acidGreen
        case .shield:    return NeonPalette.transporterGreen
        case .freeze:    return NeonPalette.iceBlue
        case .gatling:   return NeonPalette.orange
        case .nuke:      return NeonPalette.crimson
        }
    }
}

@MainActor
final class RaiderNode: SKSpriteNode {

    /// A quarter smaller than the first pass, which read as *bigger* than the
    /// chess pieces it flies past — wrong for something that is meant to be a
    /// passing bonus rather than part of the fleet.
    private static let displayHeight: CGFloat = 30
    private static let crossKey = "cross"
    private static let damagedKey = "damaged"
    private static let hullName = "hull"

    /// Fired as the scout reaches its firing point, with its current position.
    var onFire: ((CGPoint) -> Void)?
    /// Fired when the crossing finishes or the scout is destroyed — either way
    /// the slot is free again.
    var onExit: (() -> Void)?

    private static let hullGrey = SKColor(red: 0.20, green: 0.30, blue: 0.24, alpha: 1)

    private(set) var isCrossing = false
    private(set) var hp = 0
    /// What this scout is carrying. Read by the scene when it dies, so the scene
    /// never has to remember which of the pooled nodes was which.
    private(set) var powerUp: PowerUp = .rapidFire

    /// A carrier's sprite scaled to its own display height, measured from the
    /// texture so each launch resizes from the source rather than compounding
    /// the last crossing's multipliers.
    private static func size(for powerUp: PowerUp) -> CGSize {
        let source = SKTexture(imageNamed: powerUp.spriteName).size()
        let height = displayHeight * CGFloat(powerUp.heightMultiplier)
        let scale = source.height > 0 ? height / source.height : 1
        return CGSize(width: source.width * scale, height: height)
    }

    init() {
        let texture = SKTexture(imageNamed: PowerUp.rapidFire.spriteName)
        super.init(texture: texture, color: NeonPalette.acidGreen,
                   size: Self.size(for: .rapidFire))
        colorBlendFactor = 0.55      // the carrier's colour over the sprite's outline
        zPosition = 8                // over the fleet, under the HUD
        isHidden = true

        // A solid hull behind the outline. Every piece on this board is a
        // hollow outline, which is right for chess pieces standing on squares
        // — but a *ship* passing in front of them has to occlude them or it
        // reads as a decal rather than as something flying over. Grey-green so
        // it stays a machine and does not compete with the acid outline.
        let hull = SKSpriteNode(
            texture: Silhouette.filled(forTexture: PowerUp.rapidFire.spriteName),
            color: Self.hullGrey, size: size)
        hull.name = Self.hullName
        hull.colorBlendFactor = 1
        hull.alpha = 0.96
        hull.zPosition = -0.1        // under this node's outline, still over the board
        addChild(hull)

        physicsBody = Self.body(for: size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private static func body(for size: CGSize) -> SKPhysicsBody {
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.none   // parked; set on launch
        body.contactTestBitMask = PhysicsCategory.none
        body.collisionBitMask = PhysicsCategory.none
        return body
    }

    // MARK: - Appearance

    /// Dresses the node for the crossing it is about to make.
    ///
    /// Called once per launch rather than per frame, so rebuilding the physics
    /// body here is cheap — and it has to be rebuilt, because an `SKPhysicsBody`
    /// does not follow its node's size. A Spread Scout that looked 40% wider
    /// but kept the standard hitbox would be a scout you could visibly miss
    /// while aiming dead centre.
    private func dress(as powerUp: PowerUp) {
        self.powerUp = powerUp
        texture = SKTexture(imageNamed: powerUp.spriteName)
        size = Self.size(for: powerUp)
        color = powerUp.tint
        // The specials wear their colour nearly solid; the green scout keeps the
        // lighter 0.55 blend it was built with. At 0.55 a special's tint is
        // mixed half-and-half with the sprite's own art, which is close enough
        // to the acid green of the plain scout that crimson came out reading as
        // orange — and telling the five ships apart at a glance is the entire
        // reason they have colours.
        colorBlendFactor = powerUp == .rapidFire ? 0.55 : 0.85

        if let hull = childNode(withName: Self.hullName) as? SKSpriteNode {
            hull.texture = Silhouette.filled(forTexture: powerUp.spriteName)
            hull.size = size
            // A special's hull takes a wash of its own colour, so the ship reads
            // as its type even where the outline is thin. The green scout keeps
            // bare machinery — it is the baseline the others are read against.
            hull.color = powerUp == .rapidFire
                ? Self.hullGrey
                : powerUp.tint.blended(toward: Self.hullGrey, by: 0.72)
        }

        physicsBody = Self.body(for: size)
    }

    // MARK: - Crossing

    /// Sends the scout across from `fromX` to `toX`, entering at `y` and flying
    /// `flight`, firing once on the way if `firing`.
    ///
    /// `bounds` is the vertical strip a raider may occupy: below the HUD, and
    /// above the player's own lane. Every descending path is clamped to it here
    /// rather than at the point the path is chosen, so a lane change can never
    /// silently fly a raider through the ship.
    func cross(fromX: CGFloat, toX: CGFloat, y: CGFloat, firing: Bool,
               powerUp: PowerUp, flight: RaiderRules.Flight,
               bounds: ClosedRange<CGFloat>) {
        stop()
        dress(as: powerUp)
        position = CGPoint(x: fromX, y: y)
        isHidden = false
        isCrossing = true
        hp = powerUp.hp
        // Only a live scout is a target — the same rule the lasers learned the
        // hard way, where a parked body that kept its category was still hit.
        physicsBody?.categoryBitMask = PhysicsCategory.raider

        let speed = RaiderRules.scoutSpeed * CGFloat(powerUp.speedMultiplier)
        let distance = abs(toX - fromX)
        let duration = TimeInterval(distance / speed)
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

        flyVertically(flight, duration: duration, entryY: y, bounds: bounds)
    }

    /// The vertical half of the path, running alongside the crossing.
    private func flyVertically(_ flight: RaiderRules.Flight, duration: TimeInterval,
                               entryY: CGFloat, bounds: ClosedRange<CGFloat>) {
        let below = max(0, entryY - bounds.lowerBound)
        let above = max(0, bounds.upperBound - entryY)

        switch flight {
        case .straight:
            // Nothing at all. The green scout flies a true horizontal line —
            // it used to carry a 4pt hover to stop it reading as a rail, and
            // now that every other raider has a path of its own, the flat line
            // is what makes this one instantly identifiable.
            break

        case .weave(let amplitude, let halfPeriod):
            let room = min(amplitude, below, above)
            guard room > 1 else { break }
            // Symmetric about the lane: a quarter-cycle up to the crest, then
            // full swings of 2×room. The first version offset by half the
            // amplitude and then swung a full amplitude twice in each
            // direction, which put the centre of the weave half an amplitude
            // *below* the lane it was supposed to be flying and made the low
            // excursion three times the high one.
            let crest = SKAction.moveBy(x: 0, y: room, duration: halfPeriod / 2)
            let down = SKAction.moveBy(x: 0, y: -room * 2, duration: halfPeriod)
            let up = SKAction.moveBy(x: 0, y: room * 2, duration: halfPeriod)
            for action in [crest, down, up] { action.timingMode = .easeInEaseOut }
            run(.sequence([crest, .repeatForever(.sequence([down, up]))]))

        case .glide(let drop):
            let room = min(drop, below)
            guard room > 1 else { break }
            // Eased in, so it leaves the top gently and arrives with pace —
            // a linear glide reads as a ramp rather than as a descent.
            let glide = SKAction.moveBy(x: 0, y: -room, duration: duration)
            glide.timingMode = .easeIn
            run(glide)

        case .swoop(let depth):
            let room = min(depth, below)
            guard room > 1 else { break }
            let low = RaiderRules.swoopLowPoint
            let dive = SKAction.moveBy(x: 0, y: -room, duration: duration * low)
            let climb = SKAction.moveBy(x: 0, y: room, duration: duration * (1 - low))
            dive.timingMode = .easeIn      // gathers speed on the way down
            climb.timingMode = .easeOut    // and hangs at the bottom of the arc
            run(.sequence([dive, climb]))
        }
    }

    /// Takes a hit. Returns true if that destroyed it.
    func takeHit() -> Bool {
        guard isCrossing else { return false }
        hp -= 1
        guard hp <= 0 else {
            // Unreachable today: every carrier has 1 HP, so the guard above
            // always falls through. Kept for §6.1's Flagship, which has two and
            // is the one ship large and slow enough for a survivable hit to read
            // as a mechanic rather than as a miss.
            removeAction(forKey: Self.damagedKey)
            run(.repeat(.sequence([
                .colorize(with: .white, colorBlendFactor: 1, duration: 0.06),
                .colorize(with: powerUp.tint, colorBlendFactor: 0.55, duration: 0.12),
            ]), count: 2), withKey: Self.damagedKey)
            return false
        }
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
