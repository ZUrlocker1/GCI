// SpaceshipState.swift
// Pure ship state: lives, laser cap, respawn invincibility. No SpriteKit — the
// node that renders the ship (SpaceshipNode) reads this, never owns it.
//
// Shield and multi-shot promotion stacking are power-ups (§25.9, §Gatling) not
// in scope for Phase 3.2; this only covers what that phase actually needs.

import Foundation

@MainActor
final class SpaceshipState {

    /// Up to 2 lasers in flight at once (§8.2). Promotions raise this in a
    /// later phase; nothing here assumes it is fixed.
    static let baseLaserCap = 2
    /// Invincibility flash after a respawn (§8.4).
    static let invincibilityDuration: TimeInterval = 2.0

    private(set) var lives: Int
    private(set) var laserCap = SpaceshipState.baseLaserCap
    private(set) var activeLasers = 0
    private(set) var isInvincible = false
    private var invincibilityRemaining: TimeInterval = 0

    init(lives: Int = 3) {
        self.lives = lives
    }

    var canFire: Bool { activeLasers < laserCap }

    func laserFired() {
        activeLasers = min(laserCap, activeLasers + 1)
    }

    /// Call when a fired laser leaves play — hit something, or flew off-screen.
    func laserResolved() {
        activeLasers = max(0, activeLasers - 1)
    }

    /// A projectile or an enemy piece reached the ship. Returns false, and does
    /// nothing, if the ship is currently invincible — the hit is absorbed for
    /// free. Returns true (a life was actually lost) otherwise, and starts the
    /// invincibility window unless that was the last life.
    @discardableResult
    func loseLife() -> Bool {
        guard !isInvincible else { return false }
        lives -= 1
        if lives > 0 {
            isInvincible = true
            invincibilityRemaining = Self.invincibilityDuration
        }
        return true
    }

    /// Ticks the invincibility countdown. Call every frame; a no-op when not
    /// invincible, so callers do not need to guard.
    func update(deltaTime: TimeInterval) {
        guard isInvincible else { return }
        invincibilityRemaining -= deltaTime
        if invincibilityRemaining <= 0 {
            isInvincible = false
            invincibilityRemaining = 0
        }
    }

    /// Lives carry across levels (§8.5); everything else resets.
    func resetForNewLevel() {
        activeLasers = 0
        isInvincible = false
        invincibilityRemaining = 0
    }
}
