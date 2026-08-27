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

    /// The scout's warble, owned here rather than on the node.
    ///
    /// It is a looping `AVAudioPlayer`, which has nothing to do with SpriteKit:
    /// `SKNode.isPaused` does not touch it, `removeAllActions` does not stop
    /// it, and tearing the node down does not either. Every path that should
    /// silence it has to say so explicitly, which is what the first version got
    /// wrong — it started an endless loop every 0.85s and never stopped one, so
    /// the beeping outlived the pause, the level and the scout.
    private var warbling = false

    private func setWarble(_ on: Bool) {
        guard on != warbling else { return }
        warbling = on
        on ? AudioManager.shared.play(.scoutEnterLoop)
           : AudioManager.shared.stop(.scoutEnterLoop)
    }

    func reset(interval: TimeInterval, level: Int) {
        scouts.forEach { $0.stop() }
        setWarble(false)
        schedule.reset(interval: paced(interval), level: level)
    }

    /// The level's interval, stretched if it would put a raider on screen more
    /// than `maxScreenShare` of the time.
    private func paced(_ levelInterval: TimeInterval) -> TimeInterval {
        let width = scouts.first?.size.width ?? 0
        return RaiderRules.interval(
            forLevel: levelInterval,
            crossing: RaiderRules.crossingDuration(sceneWidth: sceneWidth,
                                                   scoutWidth: width))
    }

    /// Removes the raiders from the scene. The controller is rebuilt per level,
    /// so without this each level left two more nodes parented and forgotten.
    func teardown() {
        setWarble(false)
        scouts.forEach { $0.stop(); $0.removeFromParent() }
        scouts.removeAll()
    }

    /// Advances the real-time clock and launches a scout when one is due.
    ///
    /// `rearRankPieces` gates the early levels: the first scout waits until the
    /// player has broken into the fleet's back rank, so it arrives as a reward
    /// for progress rather than as one more thing to parse on a full board.
    func update(deltaTime: TimeInterval, interval: TimeInterval,
                level: Int, rearRankPieces: Int) {
        let blocked = RaiderRules.waitsForThinnedRearRank(level: level)
            && rearRankPieces > RaiderRules.crowdedRearRank
        guard schedule.tick(deltaTime, interval: paced(interval),
                            onScreen: onScreen, blocked: blocked),
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
        let y: CGFloat
        switch schedule.crossing {
        case .overTheBoard:
            // Between the board's top edge and the HUD, so it clears every
            // piece however far the fleet has descended.
            y = boardBottomY + BoardNode.boardSize + 14
        case .rank(let rank):
            y = boardBottomY + (CGFloat(rank) - 0.5) * BoardNode.squareSize
        }

        let firing = schedule.claimFiringPass()
        scout.onFire = { [weak self] point in self?.onScoutFire?(point) }
        scout.onExit = { [weak self, weak scout] in
            guard let self, let scout else { return }
            // `isCrossing` is already false by here, so this counts what is
            // actually left in the air.
            if self.onScreen == 0 { self.setWarble(false) }
            // `hp` is zero only when a shot took it; a completed crossing
            // leaves it at one. That is what tells the two endings apart
            // without a second flag to keep in step.
            self.onExit?(scout, scout.hp <= 0)
        }
        scout.cross(fromX: fromX, toX: toX, y: y, firing: firing)
        setWarble(true)

        DiagnosticsLog.shared.log(.raider,
            firing ? "scout \(leftToRight ? "→" : "←")" : "scout warning pass")
    }

    func setPaused(_ paused: Bool) {
        scouts.forEach { $0.isPaused = paused }
        // The warble is audio, not an action — pausing the nodes does nothing
        // to it, so it has to be stopped and restarted by hand.
        setWarble(paused ? false : onScreen > 0)
    }
}
