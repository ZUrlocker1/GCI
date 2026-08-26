// LaserPool.swift
// Pre-creates every laser node the game can have in flight at once — 6 player,
// 16 enemy (§20 Phase 3.2) — and hands one out on request. Zero allocation
// during play (§18): nodes are added to the parent once, at pool-build time,
// and only ever shown/hidden after that.

import SpriteKit

@MainActor
final class LaserPool {

    private static let playerCount = 6
    private static let enemyCount = 16

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
}
