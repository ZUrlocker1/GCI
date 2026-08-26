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

    /// §20 Phase 3.2 specs 400 px/s; running 30% above that (520) after
    /// playtest — at 400 the shot lingers long enough to feel floaty, and the
    /// 2-shot cap means a slow round also throttles the fire rate.
    /// Enemy shots use the level's own `projectileSpeed` instead (§21.1).
    static let playerLaserSpeed: CGFloat = 520
    static let playerLaserDamage = 2
    static let enemyShotDamage = 1
}
