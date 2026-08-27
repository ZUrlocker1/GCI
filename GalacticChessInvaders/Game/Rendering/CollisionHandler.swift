// CollisionHandler.swift
// Physics contact delegate. Its only job is to identify WHO collided, from the
// `PhysicsCategory` bitmasks, and report it through a callback — deciding what
// a collision actually means (damage, scoring, destruction) is
// `CollisionResolver`'s job, kept pure and SpriteKit-free.

import SpriteKit

@MainActor
final class CollisionHandler: NSObject, @preconcurrency SKPhysicsContactDelegate {

    /// A player laser touched something — the laser node, whatever it hit, and
    /// where, in scene coordinates. The impact point decides which side of a
    /// damaged piece survives (`PieceNode.noteHit`).
    var onPlayerLaserHit: ((LaserNode, SKNode, CGPoint) -> Void)?
    /// An enemy shot touched something — the shot node, what it hit, and where.
    var onEnemyShotHit: ((LaserNode, SKNode, CGPoint) -> Void)?
    /// Two rounds met in mid-air: the player's, Black's, and where.
    var onProjectilesCollided: ((LaserNode, LaserNode, CGPoint) -> Void)?

    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node, let nodeB = contact.bodyB.node else { return }

        // A spent round resolves nothing, whatever the bitmasks say.
        //
        // The masks are the first line and they were wrong once: a parked laser
        // cleared its contact *test* but kept its category, and a contact fires
        // when either body's test matches the other's category — so every dead
        // enemy shot sat invisible where it died and detonated the next player
        // laser to reach it. That is fixed at the source, in `deactivate`, but
        // the invariant belongs here too: nothing downstream is prepared for a
        // hit from a round that is not in flight, and a future mask change
        // should not be able to reintroduce the same failure.
        if let laser = nodeA as? LaserNode, !laser.isActive { return }
        if let laser = nodeB as? LaserNode, !laser.isActive { return }
        let categoryA = contact.bodyA.categoryBitMask
        let categoryB = contact.bodyB.categoryBitMask

        let at = contact.contactPoint
        // Round against round has to be tested first: both of the branches
        // below would otherwise match it and hand a laser to a handler
        // expecting a piece, which quietly ate the shot and drew nothing.
        if let a = nodeA as? LaserNode, let b = nodeB as? LaserNode {
            let player = a.owner == .player ? a : b
            let enemy   = a.owner == .player ? b : a
            guard player.owner == .player, enemy.owner == .enemy else { return }
            onProjectilesCollided?(player, enemy, at)
            return
        }
        if categoryA == PhysicsCategory.playerLaser, let laser = nodeA as? LaserNode {
            onPlayerLaserHit?(laser, nodeB, at)
        } else if categoryB == PhysicsCategory.playerLaser, let laser = nodeB as? LaserNode {
            onPlayerLaserHit?(laser, nodeA, at)
        } else if categoryA == PhysicsCategory.enemyShot, let shot = nodeA as? LaserNode {
            onEnemyShotHit?(shot, nodeB, at)
        } else if categoryB == PhysicsCategory.enemyShot, let shot = nodeB as? LaserNode {
            onEnemyShotHit?(shot, nodeA, at)
        }
    }
}
