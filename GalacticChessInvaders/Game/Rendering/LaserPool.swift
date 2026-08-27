// LaserPool.swift
// Pre-creates every laser node the game can have in flight at once and hands
// one out on request. Zero allocation during play (§18): nodes are added to the
// parent once, at pool-build time, and only ever shown/hidden after that.

import SpriteKit

@MainActor
final class LaserPool {

    /// §20 Phase 3.2 sized this at 6, which is `SpaceshipState.maxLaserCap`.
    ///
    /// §13.2's Gatling Barrage removes the cap entirely and auto-fires a 5-way
    /// spread, so the pool has to cover its steady state. Measured rather than
    /// guessed: a round covers `GameScene.gatlingReach` (384pt) at 520pt/s and
    /// the angled ones a little further, so one volley is 3.77 round-seconds
    /// and four volleys a second put 15.1 in the air. 32 clears that with room
    /// for the player's own manual shots on top.
    ///
    /// It was briefly 72, sized for the barrage before it was cut back — eight
    /// volleys a second of full-board rounds is 54.6 in the air. Worth keeping
    /// the arithmetic visible: an under-sized pool does not fail loudly, it
    /// silently drops arms of the spread and the barrage just looks thinner.
    private static let playerCount = 32
    private static let enemyCount = 16

    /// Exposed so the barrage arithmetic can be pinned by a test rather than
    /// rediscovered the next time the spread or the laser speed changes.
    static var playerCapacity: Int { playerCount }

    private var playerLasers: [LaserNode] = []
    private var enemyLasers: [LaserNode] = []

    init(parent: SKNode) {
        playerLasers = (0..<Self.playerCount).map { _ in
            let node = LaserNode(owner: .player)
            parent.addChild(node)
            return node
        }
        enemyLasers = (0..<Self.enemyCount).map { _ in
            let node = LaserNode(owner: .enemy)
            parent.addChild(node)
            return node
        }
    }

    /// The next free laser of the given ownership, or nil if the pool is fully
    /// committed — the caller simply doesn't fire that shot.
    func nextAvailable(owner: ProjectileState.Owner) -> LaserNode? {
        let pool = owner == .player ? playerLasers : enemyLasers
        return pool.first { !$0.isActive }
    }

    /// Every currently in-flight laser, for per-frame bookkeeping (e.g. the
    /// ship's active-laser count) that has to react to lasers landing on
    /// their own, not just to a collision.
    func activeLasers(owner: ProjectileState.Owner) -> [LaserNode] {
        (owner == .player ? playerLasers : enemyLasers).filter { $0.isActive }
    }

    func deactivateAll() {
        (playerLasers + enemyLasers).forEach { $0.deactivate() }
    }

    /// Freezes every in-flight round where it is.
    ///
    /// Lasers are parented alongside the board rather than under the fleet, so
    /// `FleetController.setPaused` never reached them: pausing stopped the
    /// formation while shots carried on across a frozen board — and since
    /// contacts kept firing too, a paused player could still lose a life.
    func setPaused(_ paused: Bool) {
        (playerLasers + enemyLasers).forEach { $0.isPaused = paused }
    }

    /// Freezes one side's rounds only.
    ///
    /// §13.2's Time Freeze stops the world but explicitly not the player: "all
    /// enemy projectiles in flight freeze in place... the player can still move
    /// and fire normally". Without this the freeze would also strand the
    /// player's own shots mid-flight, which turns a power-up into three seconds
    /// of being unable to do the one thing it leaves you able to do.
    func setPaused(_ paused: Bool, owner: ProjectileState.Owner) {
        (owner == .player ? playerLasers : enemyLasers).forEach { $0.isPaused = paused }
    }

}
