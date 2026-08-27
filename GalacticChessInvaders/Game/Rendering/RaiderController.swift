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
    /// A warning pass was spent on this pattern. The controller is rebuilt
    /// every level, so the scene keeps the record for the whole run.
    var onPatternPreviewed: ((RaiderRules.Pattern) -> Void)?

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

    /// §13.1: the one special scout this level carries, and the crossing it
    /// takes over. Nil once it has flown — a level offers the power-up once,
    /// whether or not the player took it.
    private var pendingSpecial: PowerUp?
    private var crossingsThisLevel = 0
    /// Set the moment a raider is shot down. `RaiderRules.endsAfterAKill`: the
    /// level offers one power-up, and once it has been taken there is nothing
    /// left for another crossing to give.
    private var huntOver = false
    private var endsAfterAKill = true

    func reset(interval: TimeInterval, level: Int,
               patternsSeen: Set<RaiderRules.Pattern> = []) {
        scouts.forEach { $0.stop() }
        setWarble(false)
        schedule.reset(interval: paced(interval), level: level,
                       patternsSeen: patternsSeen)
        crossingsThisLevel = 0
        huntOver = false
        endsAfterAKill = RaiderRules.endsAfterAKill(level: level)
        pendingSpecial = PowerUps.special(forLevel: level)
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
        guard !huntOver else { return }
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
        // Over the board: between the board's top edge and the HUD, so it
        // clears every piece however far the fleet has descended.
        let y = schedule.crossing.rank.map {
            boardBottomY + (CGFloat($0) - 0.5) * BoardNode.squareSize
        } ?? boardBottomY + BoardNode.boardSize + 14

        // §13.1: the special *replaces* a standard crossing rather than adding
        // one, so it is chosen here, at the point a scout was going to launch
        // anyway. Always the level's first crossing — see
        // `PowerUps.specialCrossingIndex` for why.
        let special: PowerUp? = crossingsThisLevel == PowerUps.specialCrossingIndex
            ? pendingSpecial : nil
        if special != nil { pendingSpecial = nil }
        crossingsThisLevel += 1

        let owed = schedule.owesWarningPass
        let firing = schedule.claimFiringPass()
        if owed { onPatternPreviewed?(schedule.crossing.pattern) }
        scout.onFire = { [weak self] point in self?.onScoutFire?(point) }
        scout.onExit = { [weak self, weak scout] in
            guard let self, let scout else { return }
            // `isCrossing` is already false by here, so this counts what is
            // actually left in the air.
            if self.onScreen == 0 { self.setWarble(false) }
            // `hp` is zero only when a shot took it; a completed crossing
            // leaves it at one. That is what tells the two endings apart
            // without a second flag to keep in step.
            let destroyed = scout.hp <= 0
            if destroyed, self.endsAfterAKill {
                self.huntOver = true
                self.pendingSpecial = nil
                DiagnosticsLog.shared.log(.raider, "raids over for this level")
            }
            self.onExit?(scout, destroyed)
        }
        scout.cross(fromX: fromX, toX: toX, y: y, firing: firing,
                    weave: schedule.crossing.weaveAmplitude, powerUp: special)
        setWarble(true)

        let weaving = schedule.crossing.pattern == .weaving ? " weaving" : ""
        let kind = special.map { "\($0.rawValue) scout" } ?? "scout"
        DiagnosticsLog.shared.log(.raider,
            "\(kind)\(weaving) \(firing ? "firing" : "warning") pass")
    }

    func setPaused(_ paused: Bool) {
        scouts.forEach { $0.isPaused = paused }
        // The warble is audio, not an action — pausing the nodes does nothing
        // to it, so it has to be stopped and restarted by hand.
        setWarble(paused ? false : onScreen > 0)
    }
}
