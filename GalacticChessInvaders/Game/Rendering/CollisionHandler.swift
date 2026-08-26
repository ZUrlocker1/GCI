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

    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node, let nodeB = contact.bodyB.node else { return }
        let categoryA = contact.bodyA.categoryBitMask
        let categoryB = contact.bodyB.categoryBitMask

        let at = contact.contactPoint
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
