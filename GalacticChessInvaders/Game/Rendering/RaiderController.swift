// RaiderController.swift
// Spawns and owns the raiders (§6.1). Decisions live in `RaiderRules`; this
// file owns only the nodes and the timing.
//
// The architecture the rest of 6.x hangs off: escorts, the flagship and the
// special scouts all arrive through the same pool, cap and clock.

import SpriteKit

@MainActor
final class RaiderController {

    /// A raider left the board — shot down, or safely across.
    typealias ExitHandler = (RaiderNode, _ destroyed: Bool) -> Void
    /// A scout fired, from this point in scene coordinates.
    typealias FireHandler = (CGPoint) -> Void

    var onExit: ExitHandler?
    var onScoutFire: FireHandler?

    private let parent: SKNode
    private let sceneWidth: CGFloat
    private let boardBottomY: CGFloat
    private var scouts: [RaiderNode] = []
    private var schedule = RaiderSchedule()

    init(parent: SKNode, sceneWidth: CGFloat, boardBottomY: CGFloat) {
        self.parent = parent
        self.sceneWidth = sceneWidth
        self.boardBottomY = boardBottomY
        scouts = (0..<RaiderRules.maxOnScreen).map { _ in
            let node = RaiderNode()
            parent.addChild(node)
            return node
        }
    }

    var onScreen: Int { scouts.filter(\.isCrossing).count }

    func reset(interval: TimeInterval) {
        scouts.forEach { $0.stop() }
        schedule.reset(interval: interval)
    }

    /// Advances the real-time clock and launches a scout when one is due.
    func update(deltaTime: TimeInterval, interval: TimeInterval) {
        guard schedule.tick(deltaTime, interval: interval, onScreen: onScreen),
              let scout = scouts.first(where: { !$0.isCrossing }) else { return }
        launch(scout)
    }

    private func launch(_ scout: RaiderNode) {
        // Off-screen at both ends, so it slides in and out rather than
        // appearing at the edge.
        let margin = scout.size.width
        let leftToRight = Bool.random()
        let fromX = leftToRight ? -margin : sceneWidth + margin
        let toX = leftToRight ? sceneWidth + margin : -margin
        // §6: rank 4–5, the same height all level.
        let y = boardBottomY + (CGFloat(schedule.crossingRank) - 0.5) * BoardNode.squareSize

        let firing = schedule.claimFiringPass()
        scout.onFire = { [weak self] point in self?.onScoutFire?(point) }
        scout.onExit = { [weak self, weak scout] in
            guard let self, let scout else { return }
            // `hp` is zero only when a shot took it; a completed crossing
            // leaves it at one. That is what tells the two endings apart
            // without a second flag to keep in step.
            self.onExit?(scout, scout.hp <= 0)
        }
        scout.cross(fromX: fromX, toX: toX, y: y, firing: firing)

        DiagnosticsLog.shared.log(.raider,
            "scout \(leftToRight ? "→" : "←") rank \(schedule.crossingRank)"
            + (firing ? "" : " (warning pass)"))
    }

    func setPaused(_ paused: Bool) {
        scouts.forEach { $0.isPaused = paused }
    }
}
