// RaiderController.swift
// Spawns and owns the raiders (§6.1). Decisions live in `RaiderRules` and
// `PowerUps`; this file owns only the nodes and the timing.
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
    /// A kind of raider was seen for the first time and spent its free pass.
    /// The controller is rebuilt every level, so the scene keeps the record for
    /// the whole run.
    var onKindPreviewed: ((PowerUp) -> Void)?

    var onExit: ExitHandler?
    var onScoutFire: FireHandler?

    private let parent: SKNode
    private let sceneWidth: CGFloat
    private let boardBottomY: CGFloat
    private var scouts: [RaiderNode] = []
    private var schedule = RaiderSchedule()

    /// The vertical strip a raider may occupy: from just below the board's
    /// bottom edge — under the pieces but clear of the ship's own lane at y=62 —
    /// up to just above the board's top. Every descending path is clamped to it.
    private var flightBounds: ClosedRange<CGFloat> {
        (boardBottomY - 10)...(boardBottomY + BoardNode.boardSize + 20)
    }

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

    // MARK: - The level's roster

    /// What this level still has to offer, in order. Emptied from the front:
    /// the raider at index 0 keeps crossing until the player shoots it down, and
    /// only then does the next one start arriving.
    ///
    /// That is the whole cadence rule. A level with one entry sends raiders
    /// until one is hit and then goes quiet, which is what most levels want. A
    /// level with three sends three in sequence, each earned. And *missing*
    /// costs nothing but time — the same offer comes round again — so how many
    /// raiders a wave sees depends on how long the player takes to hit them,
    /// which is the right thing for it to depend on.
    private var remaining: [PowerUp] = []
    /// The level's roster as it started, kept alongside `remaining` so the `R`
    /// test key has something to walk after the clock has gone quiet.
    private var fullRoster: [PowerUp] = []
    /// Where the `R` test key is up to. Its own cursor rather than the roster
    /// itself, so walking the list to look at something never reorders what the
    /// clock will actually send.
    private var summonCursor = 0
    /// Kept for the cadence, which stretches or tightens with how much the level
    /// is offering rather than with the level number.
    private var rosterCount = 1

    /// Which kinds have already spent their free pass this run.
    private var kindsSeen: Set<PowerUp> = []

    func reset(interval: TimeInterval, level: Int, kindsSeen: Set<PowerUp> = []) {
        scouts.forEach { $0.stop() }
        setWarble(false)
        remaining = PowerUps.roster(forLevel: level)
        fullRoster = remaining
        rosterCount = remaining.count
        summonCursor = 0
        self.kindsSeen = kindsSeen
        schedule.reset(interval: paced(interval))
    }

    /// The level's interval, stretched to keep clear sky between crossings.
    private func paced(_ levelInterval: TimeInterval) -> TimeInterval {
        let width = scouts.first?.size.width ?? 0
        return RaiderRules.interval(
            forLevel: levelInterval,
            crossing: RaiderRules.crossingDuration(sceneWidth: sceneWidth,
                                                   scoutWidth: width),
            rosterCount: rosterCount)
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
        guard let offering = remaining.first else { return }
        let blocked = RaiderRules.waitsForThinnedRearRank(level: level)
            && rearRankPieces > RaiderRules.crowdedRearRank
        guard schedule.tick(deltaTime, interval: paced(interval),
                            onScreen: onScreen, blocked: blocked),
              let scout = scouts.first(where: { !$0.isCrossing }) else { return }
        launch(scout, carrying: offering)
    }

    private func launch(_ scout: RaiderNode, carrying powerUp: PowerUp) {
        // Off-screen at both ends, so it slides in and out rather than
        // appearing at the edge.
        let margin = scout.size.width
        let leftToRight = Bool.random()
        let fromX = leftToRight ? -margin : sceneWidth + margin
        let toX = leftToRight ? sceneWidth + margin : -margin

        let bounds = flightBounds
        let entryY: CGFloat
        switch RaiderRules.lane(for: powerUp) {
        case .overTheBoard:
            // Between the board's top edge and the HUD, so it clears every
            // piece however far the fleet has descended.
            entryY = boardBottomY + BoardNode.boardSize + 14
        case .rank(let rank):
            entryY = boardBottomY + (CGFloat(rank) - 0.5) * BoardNode.squareSize
        }
        let flight = RaiderRules.flight(for: powerUp,
                                       headroom: entryY - bounds.lowerBound)

        // §6.3's free pass, once per kind per run: the first sight of a new
        // silhouette flying a new path is exactly the case the rule is for.
        let owed = !kindsSeen.contains(powerUp)
        let firing = RaiderRules.fires(kindAlreadySeen: !owed)
        if owed {
            kindsSeen.insert(powerUp)
            onKindPreviewed?(powerUp)
        }

        scout.onFire = { [weak self] point in self?.onScoutFire?(point) }
        scout.onExit = { [weak self, weak scout] in
            guard let self, let scout else { return }
            // `isCrossing` is already false by here, so this counts what is
            // actually left in the air.
            if self.onScreen == 0 { self.setWarble(false) }
            // `hp` is zero only when a shot took it; a completed crossing
            // leaves it above zero. That is what tells the two endings apart
            // without a second flag to keep in step.
            let destroyed = scout.hp <= 0
            // Removed by identity rather than position: the `R` test key can
            // send an entry out of order, so the one that just died is not
            // necessarily the one at the head of the queue.
            if destroyed, let index = self.remaining.firstIndex(of: powerUp) {
                self.remaining.remove(at: index)
                DiagnosticsLog.shared.log(.raider, self.remaining.isEmpty
                    ? "raids over for this level"
                    : "next up: \(self.remaining[0].shipName) scout")
            }
            self.onExit?(scout, destroyed)
        }
        scout.cross(fromX: fromX, toX: toX, y: entryY, firing: firing,
                    powerUp: powerUp, flight: flight, bounds: bounds)
        setWarble(true)

        DiagnosticsLog.shared.log(.raider,
            "\(powerUp.shipName) scout \(firing ? "firing" : "warning") pass")
    }

    /// Launches one of the level's raiders immediately, for the `R` test key.
    ///
    /// Successive presses walk the level's whole list — green, then spread, then
    /// ice on Level 9 — and wrap, so every raider a level can send is reachable
    /// without having to shoot the one in front of it first.
    ///
    /// It walks `fullRoster`, not `remaining`, which makes it a genuine
    /// override: the level's raids normally end once the player brings one down
    /// (`RaiderRules.endsAfterAKill`), and a test key that went quiet at exactly
    /// the same moment would be useless for the case it exists to test —
    /// checking a power-up you have *already* collected once this wave. Its own
    /// cursor, too, so walking the list never reorders what the clock sends next
    /// or what a kill advances past.
    ///
    /// Returns what went up, or nil if there is nothing to send: the level has
    /// no roster at all, or one is already crossing.
    @discardableResult
    func summonNext() -> PowerUp? {
        guard !fullRoster.isEmpty,
              let scout = scouts.first(where: { !$0.isCrossing }),
              onScreen < RaiderRules.maxScoutsOnScreen else { return nil }
        let index = summonCursor % fullRoster.count
        summonCursor = index + 1
        launch(scout, carrying: fullRoster[index])
        return fullRoster[index]
    }

    func setPaused(_ paused: Bool) {
        scouts.forEach { $0.isPaused = paused }
        // The warble is audio, not an action — pausing the nodes does nothing
        // to it, so it has to be stopped and restarted by hand.
        setWarble(paused ? false : onScreen > 0)
    }
}
