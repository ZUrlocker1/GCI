// SpaceshipNode.swift
// Player ship SKSpriteNode. Tracks invincibility state and shield bubble.
// Respawn flash, shield visual, and shield-break animation handled here.
// Phase 1+: full implementation.

import SpriteKit

final class SpaceshipNode: SKSpriteNode {
    private(set) var isInvincible = false
    private(set) var hasShield = false

    func startRespawnInvincibility(duration: TimeInterval = 2.0) {
        // Phase 1+: rapid alpha flicker for `duration` seconds, then stop
        isInvincible = true
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        let flicker = SKAction.repeat(flash, count: Int(duration / 0.2))
        run(flicker) { [weak self] in
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
