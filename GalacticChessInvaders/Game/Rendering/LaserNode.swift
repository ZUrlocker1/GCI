// LaserNode.swift
// Pooled laser projectile node (player lasers + enemy shots).
// Never removed from the scene graph — activated/deactivated to avoid allocation.
// Phase 1+: full implementation with physics bodies and bloom trail.

import SpriteKit

enum LaserOwner {
    case player   // cyan beam, fires upward
    case enemy    // magenta bolt, fires downward
    case raider   // acid-green or orange bolt (scout / escort)
}

final class LaserNode: SKSpriteNode {
    private(set) var owner: LaserOwner = .player
    private(set) var isActive = false

    func activate(at position: CGPoint, owner: LaserOwner) {
        self.position = position
        self.owner = owner
        self.isActive = true
        self.isHidden = false
        // Phase 1+: set physics body, apply velocity, start bloom trail
    }

    func deactivate() {
        isActive = false
        isHidden = true
        removeAllActions()
        physicsBody = nil
    }
}
