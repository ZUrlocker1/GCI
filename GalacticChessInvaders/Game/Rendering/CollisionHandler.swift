// CollisionHandler.swift
// Physics contact delegate. Its only job is to identify WHO collided, from the
// `PhysicsCategory` bitmasks, and report it through a callback — deciding what
// a collision actually means (damage, scoring, destruction) is
// `CollisionResolver`'s job, kept pure and SpriteKit-free.

import SpriteKit

@MainActor
final class CollisionHandler: NSObject, @preconcurrency SKPhysicsContactDelegate {

    /// A player laser touched something — the laser node, then whatever it hit.
    var onPlayerLaserHit: ((LaserNode, SKNode) -> Void)?
    /// An enemy shot touched something — the shot node, then whatever it hit.
    var onEnemyShotHit: ((LaserNode, SKNode) -> Void)?

    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node, let nodeB = contact.bodyB.node else { return }
        let categoryA = contact.bodyA.categoryBitMask
        let categoryB = contact.bodyB.categoryBitMask

        if categoryA == PhysicsCategory.playerLaser, let laser = nodeA as? LaserNode {
            onPlayerLaserHit?(laser, nodeB)
        } else if categoryB == PhysicsCategory.playerLaser, let laser = nodeB as? LaserNode {
            onPlayerLaserHit?(laser, nodeA)
        } else if categoryA == PhysicsCategory.enemyShot, let shot = nodeA as? LaserNode {
            onEnemyShotHit?(shot, nodeB)
        } else if categoryB == PhysicsCategory.enemyShot, let shot = nodeB as? LaserNode {
            onEnemyShotHit?(shot, nodeA)
        }
    }
}
