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
    /// §7.2's ceiling on promotion stacking. Six rounds in the air is already
    /// a near-continuous stream at the player's laser speed.
    static let maxLaserCap = 6
    /// Invincibility flash after a respawn (§8.4).
    static let invincibilityDuration: TimeInterval = 2.0
    /// §8.2's three lives, named so the HUD can show the right number before a
    /// run has started rather than assuming one.
    static let startingLives = 3

    private(set) var lives: Int
    private(set) var laserCap = SpaceshipState.baseLaserCap
    private(set) var activeLasers = 0
    private(set) var isInvincible = false
    private var invincibilityRemaining: TimeInterval = 0

    init(lives: Int = SpaceshipState.startingLives) {
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

    /// Starts the invincibility window without costing a life.
    ///
    /// §13.2's shield "absorbs the next single hit that would destroy the
    /// ship". Taken literally that is one hit and no more, which in a Level 7
    /// crossfire means the second round of the same volley kills you a frame
    /// later and the shield reads as having done nothing at all. The grace is
    /// what makes absorbing a hit mean surviving the moment.
    ///
    /// Shorter than a respawn's two seconds: this is a reprieve, not a reset.
    static let shieldGrace: TimeInterval = 0.8

    func beginGrace(_ duration: TimeInterval = SpaceshipState.shieldGrace) {
        isInvincible = true
        invincibilityRemaining = max(invincibilityRemaining, duration)
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
    /// §7.2's promotion reward: one more round allowed in the air at a time.
    ///
    /// The cap is *concurrency*, not ammunition or a cooldown — `canFire` is
    /// `activeLasers < laserCap`, and a slot frees the moment its round lands
    /// or leaves the screen. So this only pays when the player is *missing*: at
    /// two, a shot that flies the full board locks a slot for 1.2 seconds. That
    /// is the right shape for a reward, because missing is what happens at
    /// range and under pressure.
    ///
    /// Returns false when already at the ceiling, so the caller can stay quiet
    /// rather than announcing a reward that did not happen.
    @discardableResult
    func grantRapidFire() -> Bool {
        guard laserCap < Self.maxLaserCap else { return false }
        laserCap += 1
        return true
    }

    func resetForNewLevel() {
        activeLasers = 0
        isInvincible = false
        invincibilityRemaining = 0
        // §7.2: the stack does not carry between waves. Earned again or not at
        // all — otherwise a run that promoted early would coast on it. Cadet
        // inverts exactly that, because coasting is the point: every stack is
        // still earned from a green scout, it just is not confiscated at the
        // level break.
        if !GameSettings.shared.keepsPowerUps { laserCap = Self.baseLaserCap }
    }
}
