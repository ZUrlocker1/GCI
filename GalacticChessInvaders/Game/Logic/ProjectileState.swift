// ProjectileState.swift
// Pure data describing an in-flight projectile — who fired it, how much
// damage it deals, how fast it travels. No SpriteKit; `LaserNode` (Rendering)
// holds one of these while active and reads it to resolve a hit.

import CoreGraphics

struct ProjectileState {
    enum Owner {
        case player
        case enemy
    }

    let owner: Owner
    let damage: Int
    let speed: CGFloat

    /// §20 Phase 3.2 testing spec: "Player laser fires, travels 400 px/s".
    /// Enemy shots use the level's own `projectileSpeed` instead (§21.1).
    static let playerLaserSpeed: CGFloat = 400
    static let playerLaserDamage = 2
    static let enemyShotDamage = 1
}
