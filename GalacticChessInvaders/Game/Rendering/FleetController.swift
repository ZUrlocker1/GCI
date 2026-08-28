// FleetController.swift
// Drives the black fleet's Space Invaders sweep and descent (§23.6).
//
// Every black piece node is a child of one `fleetNode`, so a single SKAction on
// that parent moves the whole formation — 16 pieces at the cost of one (§18).
// Each piece sits at its *logical* square centre in fleet-local coordinates; the
// parent's transform supplies the visual sweep and drop on top. That separation
// is what lets the chess engine keep seeing whole ranks while the fleet visually
// occupies the space between them.
//
// Decisions live in FleetRules; this file owns only the animation.

import SpriteKit

@MainActor
final class FleetController {

    /// Emitted when a full-rank descent lands a black piece on a white one.
    typealias CrushHandler = (CrushEvent) -> Void
    /// Emitted when a black piece is already on rank 1 and cannot descend —
    /// a lose condition in Phase 3.2.
    typealias BreachHandler = (String) -> Void
    /// Old → new squares for a completed rank descent, already in a safe order.
    typealias DescentHandler = ([(from: String, to: String)]) -> Void

    private let fleetNode = SKNode()
    private unowned let board: GCIBoard
    private let squareSize: CGFloat
    /// Half the total sweep width. Read from the level rather than fixed —
    /// Level 6 widens it deliberately (`FleetRules.wideSweepAmplitudeRatio`),
    /// and Blitz grows it lap by lap on top of that.
    private var amplitude: CGFloat {
        FleetRules.sweepAmplitude(squareSize: squareSize, ratio: amplitudeRatio)
    }

    private var amplitudeRatio: CGFloat {
        levelParameters.blitz
            ? FleetRules.blitzAmplitudeRatio(leftEdgeArrivals: leftEdgeArrivals)
            : levelParameters.sweepAmplitudeRatio
    }

    /// Laps completed at the left edge. Blitz escalates off this count, so it
    /// only matters there — but it is cheap and honest to keep for every level.
    private var leftEdgeArrivals = 0

    /// Squares the fleet still owns. Descent walks these rather than every black
    /// piece: a piece that has played a chess move has left the formation and is
    /// no longer swept or dropped.
    private var members: [String: SKNode] = [:]
    private var schedule: FleetRules.DescentSchedule
    private var direction: CGFloat = 1        // +1 right, -1 left
    private var isRunning = false
    /// Only logged when it changes — a leg is short, so per-leg lines would bury
    /// everything else in the diagnostics pane.
    private var lastLoggedSpeed: CGFloat = 0

    /// Current level parameters, re-read on every leg so escalation takes effect.
    var levelParameters: LevelParameters
    var onCrush: CrushHandler?
    var onBreach: BreachHandler?
    var onRankDescended: DescentHandler?

    /// One container per rank slot, all children of `fleetNode`, carrying the
    /// *horizontal* sweep and nothing else. Vertical drops and the descent
    /// stay on `fleetNode`, so the trickiest existing machinery is untouched.
    ///
    /// Slot 0 is the formation's rear. Nothing ever re-parents on a descent:
    /// every member moves down one rank together, so the *set* in each slot is
    /// unchanged and only its absolute rank shifts. That is what makes per-rank
    /// sweeping a contained change rather than a rewrite of the descent.
    private var rankNodes: [SKNode] = []
    /// Sweep direction per slot, since the ranks are no longer in step.
    private var directions: [CGFloat] = []
    private static let rankSlots = 8

    private static let sweepKey = "fleetSweep"
    private static let telegraphKey = "fleetTelegraph"
    private static let staggerKey = "rankStagger"
    private static let halfDropDuration: TimeInterval = 0.18

    init(board: GCIBoard, parent: SKNode, squareSize: CGFloat, level: LevelParameters) {
        self.board = board
        self.squareSize = squareSize
        self.schedule = FleetRules.descentSchedule(for: level.level)
        self.levelParameters = level
        fleetNode.zPosition = 5
        parent.addChild(fleetNode)
        buildRankNodes()
    }

    private func buildRankNodes() {
        rankNodes = (0..<Self.rankSlots).map { _ in
            let node = SKNode()
            fleetNode.addChild(node)
            return node
        }
        directions = Array(repeating: 1, count: Self.rankSlots)
    }

    /// Which container a square belongs to, counted forward from the
    /// formation's rear. Clamped, so a straggler rejoining from behind the
    /// fleet lands in the rear slot rather than off the end.
    private func slot(forSquare square: String) -> Int {
        let rank = Int(String(square.suffix(1))) ?? rearRank
        return max(0, min(Self.rankSlots - 1, rearRank - rank))
    }

    /// Blitz gives each rank its own phase; everywhere else the fleet is one
    /// body, which is what makes it a fleet.
    private var phaseLag: CGFloat {
        levelParameters.blitz ? FleetRules.rankPhaseLag : 0
    }

    // MARK: - Membership

    /// Black pieces are re-parented here; their local position is the logical
    /// square centre, never the on-screen position.
    func adopt(_ node: SKNode, square: String, atLogicalCentre centre: CGPoint) {
        node.removeFromParent()
        node.position = centre
        node.alpha = 1
        rankNodes[slot(forSquare: square)].addChild(node)
        members[square] = node
    }

    /// Adopts a piece that is already drawn somewhere else, sliding it into
    /// formation instead of teleporting.
    ///
    /// The fleet transform is shared, so a joining piece necessarily lands at
    /// whatever offset the formation currently carries — it cannot keep its own
    /// position. The slide is what makes that read as falling in rather than as
    /// a jump: the node starts at its old screen position expressed in fleet
    /// space, and moves to the logical centre from there.
    func adopt(_ node: SKNode, square: String, atLogicalCentre centre: CGPoint,
               slidingFrom drawn: CGPoint, duration: TimeInterval = 0.2) {
        adopt(node, square: square, atLogicalCentre: centre)
        let carried = sweepOffset(of: node)
        node.position = CGPoint(x: drawn.x - carried.x, y: drawn.y - carried.y)
        let slide = SKAction.move(to: centre, duration: duration)
        slide.timingMode = .easeOut
        node.run(slide)
    }

    /// Is this node already marching?
    func isMember(_ node: SKNode) -> Bool { contains(node) }

    /// Everything between this node and the board: its rank's sweep plus the
    /// fleet's own drop.
    private func sweepOffset(of node: SKNode) -> CGPoint {
        let rank = node.parent?.position ?? .zero
        return CGPoint(x: rank.x + fleetNode.position.x,
                       y: rank.y + fleetNode.position.y)
    }

    /// The fleet's current sweep offset, for callers computing where a member
    /// will end up on screen.
    var sweepOffset: CGPoint { fleetNode.position }

    /// A piece that has played chess is no longer an invader: it stops sweeping
    /// and descending, and stands on its square like an ordinary chess piece.
    /// Returns the node so the caller can re-parent it onto the board.
    ///
    /// This is what keeps the two populations legible — things that move are the
    /// formation, things that stand still are chess — and it means engaging Black
    /// on the board defuses the arcade pressure rather than just stacking with it.
    @discardableResult
    func release(square: String) -> SKNode? {
        guard let node = members[square] else { return nil }
        release(node)
        DiagnosticsLog.shared.log(.fleet, "\(square) leaves")
        return node
    }

    /// Releases by node identity rather than by square, dropping every
    /// membership entry that points at it and always unparenting it.
    ///
    /// The square key cannot be trusted at the moment a piece leaves. A rank
    /// descent re-keys `members[next] = node` as it walks the formation, which
    /// overwrites the entry of a black piece being crushed on that very square
    /// — and the crush callback only fires afterwards. The key then names the
    /// *descending* piece, so a key-based release unparented the wrong node and
    /// left the caller holding one that still had a parent, which crashed
    /// SpriteKit on the next `addChild`. Identity cannot go stale that way.
    @discardableResult
    func release(_ node: SKNode) -> Bool {
        let wasMember = node.parent === fleetNode
        for (square, member) in members where member === node {
            members[square] = nil
        }
        node.removeAllActions()
        node.alpha = 1
        // And un-pause it. Time Freeze pauses `fleetNode`, and a piece released
        // during one carried that state out with it — its teardown was added
        // and never advanced a frame, leaving a fully opaque, unshootable piece
        // on the board for the rest of the run. Whatever was holding the fleet
        // still is not this node's business once it has left.
        node.isPaused = false
        node.removeFromParent()
        return wasMember
    }

    /// The rank the formation's own rear sits on: 8 at the start of a level,
    /// one lower after each rank descent. The anchor "the back N ranks" is
    /// measured from (`FleetRules.staysInFormation`).
    ///
    /// Derived from the descent count rather than from where the members
    /// actually are. Reading `max(member rank)` was wrong in two ways: an empty
    /// fleet had no answer at all, and — since a straggler can now rejoin
    /// *behind* the formation — one king retreating to rank 8 would drag the
    /// notional rear back to 8 and evict the real front rank from its own band.
    var rearRank: Int { max(1, FleetRules.startingRearRank - ranksDescended) }
    private(set) var ranksDescended = 0

    /// Moves an existing member to a new square without it leaving the
    /// formation — a black piece shuffling around its home ranks (§FleetRules
    /// .staysInFormation). The node keeps its fleet parent, so the caller still
    /// animates it to the *logical* square centre and the parent transform
    /// supplies the sweep, exactly as for any other member.
    ///
    /// Returns false when the square isn't a member, so the caller can fall
    /// back to detaching.
    @discardableResult
    func rekey(from: String, to square: String) -> Bool {
        guard let node = members.removeValue(forKey: from) else { return false }
        members[square] = node
        // A piece that changed rank has to change rhythm with it, or it marches
        // visibly out of step with the rank it is standing in.
        let destination = rankNodes[slot(forSquare: square)]
        if node.parent !== destination {
            node.removeFromParent()
            destination.addChild(node)
        }
        DiagnosticsLog.shared.log(.fleet, "\(from)-\(square) in formation")
        return true
    }

    func contains(_ node: SKNode) -> Bool {
        guard let parent = node.parent else { return false }
        return rankNodes.contains { $0 === parent }
    }

    /// Marching pieces, not scene-graph children: only `PieceNode`s count, so
    /// anything else that ends up parented here cannot inflate the number the
    /// sweep speed is derived from.
    var pieceCount: Int {
        rankNodes.reduce(0) { $0 + $1.children.filter { $0 is PieceNode }.count }
    }

    /// Where a fleet piece actually appears, for hit detection and projectiles.
    func screenPosition(of node: SKNode) -> CGPoint {
        let carried = sweepOffset(of: node)
        return CGPoint(x: node.position.x + carried.x, y: node.position.y + carried.y)
    }

    // MARK: - Sweep

    /// Marks the fleet live. It holds its opening position until the schedule
    /// says to sweep — a fresh board should read as a chess position before it
    /// starts moving.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        if schedule.isSweeping { beginSweep() }
    }

    /// Sets every rank marching, each one lagging the rank behind it.
    ///
    /// The lag is applied as a staggered *start* rather than a phase offset in
    /// a shared clock: every rank runs the same leg at the same speed, so once
    /// they are staggered they stay that way, and there is no shared clock to
    /// drift against. At `phaseLag == 0` every stagger is zero and all eight
    /// ranks move as one — which is the fleet's original behaviour, exactly.
    private func beginSweep() {
        let cycle = legDuration * 2          // left and back is one full cycle
        for slot in rankNodes.indices {
            let stagger = TimeInterval(phaseLag / (2 * .pi)) * cycle * TimeInterval(slot)
            guard stagger > 0 else { beginLeg(slot: slot); continue }
            rankNodes[slot].run(.sequence([
                .wait(forDuration: stagger),
                .run { [weak self] in self?.beginLeg(slot: slot) },
            ]), withKey: Self.staggerKey)
        }
    }

    /// How long one leg takes at the current speed — only used to size the
    /// stagger, so an estimate from the opening speed is enough.
    private var legDuration: TimeInterval {
        let speed = FleetRules.sweepSpeed(level: levelParameters,
                                          piecesRemaining: max(1, pieceCount))
        guard speed > 0 else { return 1 }
        return TimeInterval(amplitude * 2 / speed)
    }

    func stop() {
        isRunning = false
        fleetNode.removeAllActions()
        rankNodes.forEach { $0.removeAllActions() }
    }

    /// Freezes the sweep and drop where they are. The beat is gated on
    /// `PlayingState` in the scene's update loop, but the fleet runs on SKActions
    /// which keep ticking regardless — so pausing has to reach it explicitly.
    func setPaused(_ paused: Bool) {
        fleetNode.isPaused = paused
    }

    func reset() {
        stop()
        members.removeAll()
        fleetNode.alpha = 1
        fleetNode.removeAllChildren()
        fleetNode.position = .zero
        buildRankNodes()
        schedule.reset()
        direction = 1
        ranksDescended = 0
        leftEdgeArrivals = 0
        lastLoggedSpeed = 0
    }

    /// Eases the formation back onto its true squares and leaves it there.
    /// Used for the checkmate reveal: the final position should be exactly what
    /// the engine says it is, not a snapshot of the shuffle.
    func snapToTruePosition(duration: TimeInterval = 0.3) {
        isRunning = false
        fleetNode.removeAllActions()
        rankNodes.forEach { $0.removeAllActions() }
        fleetNode.alpha = 1
        let settle = SKAction.move(to: .zero, duration: duration)
        settle.timingMode = .easeOut
        fleetNode.run(settle)
        // Every rank has its own offset now, so every rank has to come home.
        rankNodes.forEach { $0.run(settle) }
    }

    /// One left-or-right leg of the shuffle. Speed is recomputed per leg, so the
    /// fleet accelerates as it is thinned without rebuilding a repeating action.
    /// Reaching the end of a leg only reverses direction — it never descends.
    private func beginLeg(slot: Int) {
        guard isRunning, pieceCount > 0, rankNodes.indices.contains(slot) else { return }
        let rankNode = rankNodes[slot]
        let direction = directions[slot]

        let target = direction > 0 ? amplitude : -amplitude
        var speed = FleetRules.sweepSpeed(level: levelParameters,
                                          piecesRemaining: pieceCount)
        if levelParameters.blitz {
            speed *= FleetRules.blitzSpeedScale(leftEdgeArrivals: leftEdgeArrivals)
        }
        guard speed > 0 else { return }

        if slot == 0, abs(speed - lastLoggedSpeed) > 0.5 {
            lastLoggedSpeed = speed
            DiagnosticsLog.shared.log(.fleet,
                "sweep \(Int(speed))px/s, \(pieceCount) pieces")
        }

        // Stepped rather than smooth: the formation jumps an eighth of the sweep
        // and holds, so it marches instead of drifting. Overall pace is unchanged
        // — the hold is sized from the same points-per-second.
        let steps = FleetRules.sweepSteps
        let delta = (target - rankNode.position.x) / CGFloat(steps)
        let hold = TimeInterval(abs(delta) / speed)
        let step = SKAction.sequence([.moveBy(x: delta, y: 0, duration: 0),
                                      .wait(forDuration: hold)])
        let turn = SKAction.run { [weak self] in
            guard let self else { return }
            // Land exactly on the amplitude: eight divisions of a float would
            // otherwise let the rank creep off true over a long level.
            rankNode.position.x = target
            // Counted from the rear rank alone. Every rank arriving at its own
            // left edge would multiply Blitz's widening by eight.
            if slot == 0, direction < 0 { self.registerLeftEdgeArrival() }
            self.directions[slot] = -direction
            self.beginLeg(slot: slot)
        }
        rankNode.run(.sequence([.repeat(step, count: steps), turn]), withKey: Self.sweepKey)
    }

    /// Blitz's escalation, driven by laps rather than by the clock so the
    /// player can see what is causing it. Logged only on the beats where
    /// something actually changes — a lap is barely a second and per-lap lines
    /// would bury the rest of the diagnostics pane.
    private func registerLeftEdgeArrival() {
        leftEdgeArrivals += 1
        guard levelParameters.blitz else { return }
        if leftEdgeArrivals % FleetRules.blitzWidenEveryArrivals == 0 {
            let squares = amplitudeRatio * 2
            DiagnosticsLog.shared.log(.fleet,
                "BLITZ: sweep \(String(format: "%.1f", squares)) squares "
                + "(lap \(leftEdgeArrivals))")
        }
        if leftEdgeArrivals % FleetRules.blitzSpeedUpEveryArrivals == 0 {
            let scale = FleetRules.blitzSpeedScale(leftEdgeArrivals: leftEdgeArrivals)
            DiagnosticsLog.shared.log(.fleet,
                "BLITZ: march ×\(String(format: "%.2f", scale))")
        }
    }

    // MARK: - Beat-paced descent

    /// Call once per resolved chess beat. Descent is deliberately not driven by
    /// wall bounces — see FleetRules.
    func registerBeat() {
        guard isRunning else { return }
        let wasHolding = !schedule.isSweeping
        let step = schedule.registerBeat()
        if wasHolding, schedule.isSweeping {
            DiagnosticsLog.shared.log(.fleet, "sweep begins")
            beginSweep()
        }
        switch step {
        case .none:
            break
        case .halfDrop:
            drop(ratio: FleetRules.firstDropRatio) {
                DiagnosticsLog.shared.log(.fleet, "half-drop")
            }
        case .fullRank:
            drop(ratio: FleetRules.secondDropRatio) { [weak self] in
                self?.applyFullRankDescent()
            }
        }

        if FleetRules.telegraphsDescent, FleetRules.descendsAfter(schedule) {
            runDescentTelegraph()
        }
    }

    /// The drop rides on the fleet parent alongside the sweep, so the march keeps
    /// running underneath it rather than stuttering to a halt.
    ///
    /// The two drops are uneven — see FleetRules.firstDropRatio.
    private func drop(ratio: CGFloat, then completion: @escaping () -> Void) {
        let action = SKAction.moveBy(x: 0, y: -squareSize * ratio,
                                     duration: Self.halfDropDuration)
        fleetNode.run(action, completion: completion)
    }

    /// Announces next beat's drop with two dips of the whole formation. Alpha
    /// rather than scale or position, so it cannot be mistaken for the drop
    /// itself and cannot desync the sweep.
    ///
    /// Delete this method and its one call site to remove the telegraph.
    private func runDescentTelegraph() {
        fleetNode.removeAction(forKey: Self.telegraphKey)
        let pulse = SKAction.sequence([.fadeAlpha(to: 0.45, duration: 0.12),
                                       .fadeAlpha(to: 1.0, duration: 0.12)])
        fleetNode.run(.repeat(pulse, count: 2), withKey: Self.telegraphKey)
        DiagnosticsLog.shared.log(.fleet, "descent next beat")
    }

    // MARK: - Logical descent

    /// The second half-drop has landed, so the board catches up: every black
    /// piece moves one rank toward White, bypassing chess legality entirely.
    ///
    /// The parent is raised by a full rank at the same time, because the pieces
    /// themselves have just moved down by one in local space — without this the
    /// fleet would appear to fall two ranks.
    /// Test-only synchronous entry point, reachable via `@testable import`. The
    /// real path runs `applyFullRankDescent` as the completion of a timed drop
    /// `SKAction`; tests need to trigger the same board/position mutation
    /// without waiting on a run loop.
    func applyFullRankDescentForTesting() { applyFullRankDescent() }

    private func applyFullRankDescent() {
        ranksDescended += 1
        var breached: [String] = []
        var crushes: [CrushEvent] = []
        var moved: [(from: String, to: String)] = []

        for square in FleetRules.descentOrder(Array(members.keys)) {
            guard let piece = board.piece(at: square) else {
                members[square] = nil          // destroyed since the last descent
                continue
            }
            guard let next = FleetRules.descended(square) else {
                breached.append(square)
                continue
            }
            if let crush = board.forcePlace(piece, at: next) { crushes.append(crush) }
            if let node = members.removeValue(forKey: square) {
                // The node's *local* position is supposed to always equal its
                // logical square's centre (see the header comment) — but a rank
                // descent had only ever adjusted the parent, never the child.
                // The two cancelled out on screen for exactly one rank, then the
                // next descent compounded the error: the piece would appear to
                // jump up a full square the instant the rank completed, right
                // before the next drop pulled it back down. Moving the node here
                // by the same amount the parent is about to be moved back keeps
                // the screen position continuous across the transition.
                node.position.y -= squareSize
                members[next] = node
            }
            moved.append((square, next))
        }

        // Undoes the two half-drops now that the pieces themselves have moved
        // down a rank in local space, so the net screen position is unchanged.
        fleetNode.position.y += squareSize
        DiagnosticsLog.shared.log(.fleet, "rank descended")

        // Crushes first: the victim is still keyed at that square, and the black
        // piece is about to be re-keyed onto it. Reversing these destroys the
        // arriving black piece instead of the white one it landed on.
        crushes.forEach { onCrush?($0) }
        onRankDescended?(moved)
        breached.forEach { onBreach?($0) }
    }

    /// Total width of the shuffle. Kept below one square by construction; the
    /// test pins it, because the failure is silent and ruins readability.
    var sweepWidth: CGFloat { amplitude * 2 }

    /// How far the formation currently sits from its true squares — the widest
    /// any single rank has strayed.
    var lateralOffset: CGFloat {
        rankNodes.map { abs($0.position.x + fleetNode.position.x) }.max() ?? 0
    }

    /// True while the formation is drawn anywhere other than on its own squares —
    /// mid-shuffle, or resting on a half-rank.
    var isOffTruePosition: Bool {
        abs(fleetNode.position.y) > 1 || lateralOffset > 1
    }
}
