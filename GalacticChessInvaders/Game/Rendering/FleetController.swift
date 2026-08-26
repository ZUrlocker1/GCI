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
    /// Half the total sweep width. The fleet oscillates between -amplitude and
    /// +amplitude around true position, and never further: a piece that drifts
    /// past half a square stops being readable as belonging to its file.
    private let amplitude: CGFloat

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

    private static let sweepKey = "fleetSweep"
    private static let halfDropDuration: TimeInterval = 0.18

    init(board: GCIBoard, parent: SKNode, squareSize: CGFloat, level: LevelParameters) {
        self.board = board
        self.squareSize = squareSize
        self.amplitude = FleetRules.sweepAmplitude(squareSize: squareSize)
        self.schedule = FleetRules.descentSchedule(for: level.level)
        self.levelParameters = level
        fleetNode.zPosition = 5
        parent.addChild(fleetNode)
    }

    // MARK: - Membership

    /// Black pieces are re-parented here; their local position is the logical
    /// square centre, never the on-screen position.
    func adopt(_ node: SKNode, atLogicalCentre centre: CGPoint) {
        node.removeFromParent()
        node.position = centre
        fleetNode.addChild(node)
    }

    func contains(_ node: SKNode) -> Bool { node.parent === fleetNode }

    var pieceCount: Int { fleetNode.children.count }

    /// Where a fleet piece actually appears, for hit detection and projectiles.
    func screenPosition(of node: SKNode) -> CGPoint {
        CGPoint(x: node.position.x + fleetNode.position.x,
                y: node.position.y + fleetNode.position.y)
    }

    // MARK: - Sweep

    /// Marks the fleet live. It holds its opening position until the schedule
    /// says to sweep — a fresh board should read as a chess position before it
    /// starts moving.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        if schedule.isSweeping { beginLeg() }
    }

    func stop() {
        isRunning = false
        fleetNode.removeAllActions()
    }

    /// Freezes the sweep and drop where they are. The beat is gated on
    /// `PlayingState` in the scene's update loop, but the fleet runs on SKActions
    /// which keep ticking regardless — so pausing has to reach it explicitly.
    func setPaused(_ paused: Bool) {
        fleetNode.isPaused = paused
    }

    func reset() {
        stop()
        fleetNode.removeAllChildren()
        fleetNode.position = .zero
        schedule.reset()
        direction = 1
        lastLoggedSpeed = 0
    }

    /// Eases the formation back onto its true squares and leaves it there.
    /// Used for the checkmate reveal: the final position should be exactly what
    /// the engine says it is, not a snapshot of the shuffle.
    func snapToTruePosition(duration: TimeInterval = 0.3) {
        isRunning = false
        fleetNode.removeAllActions()
        let settle = SKAction.move(to: .zero, duration: duration)
        settle.timingMode = .easeOut
        fleetNode.run(settle)
    }

    /// One left-or-right leg of the shuffle. Speed is recomputed per leg, so the
    /// fleet accelerates as it is thinned without rebuilding a repeating action.
    /// Reaching the end of a leg only reverses direction — it never descends.
    private func beginLeg() {
        guard isRunning, pieceCount > 0 else { return }

        let target = direction > 0 ? amplitude : -amplitude
        let distance = abs(target - fleetNode.position.x)
        let speed = FleetRules.sweepSpeed(level: levelParameters,
                                          piecesRemaining: pieceCount)
        guard speed > 0 else { return }

        if abs(speed - lastLoggedSpeed) > 0.5 {
            lastLoggedSpeed = speed
            DiagnosticsLog.shared.log(.fleet,
                "sweep \(Int(speed))px/s (\(pieceCount) pieces)")
        }

        let slide = SKAction.moveTo(x: target, duration: TimeInterval(distance / speed))
        let turn = SKAction.run { [weak self] in
            guard let self else { return }
            self.direction *= -1
            self.beginLeg()
        }
        fleetNode.run(.sequence([slide, turn]), withKey: Self.sweepKey)
    }

    // MARK: - Beat-paced descent

    /// Call once per resolved chess beat. Descent is deliberately not driven by
    /// wall bounces — see FleetRules.
    func registerBeat() {
        guard isRunning else { return }
        let wasHolding = !schedule.isSweeping
        let step = schedule.registerBeat()
        if wasHolding, schedule.isSweeping {
            DiagnosticsLog.shared.log(.fleet, "fleet begins its sweep")
            beginLeg()
        }
        switch step {
        case .none:
            return
        case .halfDrop:
            dropHalfRank { DiagnosticsLog.shared.log(.fleet, "half-drop 1/2 — ranks unchanged") }
        case .fullRank:
            dropHalfRank { [weak self] in self?.applyFullRankDescent() }
        }
    }

    /// The drop rides on the fleet parent alongside the sweep, so the shuffle
    /// keeps running underneath it rather than stuttering to a halt.
    private func dropHalfRank(then completion: @escaping () -> Void) {
        let drop = SKAction.moveBy(x: 0, y: -squareSize / 2, duration: Self.halfDropDuration)
        fleetNode.run(drop, completion: completion)
    }

    // MARK: - Logical descent

    /// The second half-drop has landed, so the board catches up: every black
    /// piece moves one rank toward White, bypassing chess legality entirely.
    ///
    /// The parent is raised by a full rank at the same time, because the pieces
    /// themselves have just moved down by one in local space — without this the
    /// fleet would appear to fall two ranks.
    private func applyFullRankDescent() {
        let squares = FleetRules.descentOrder(
            board.allPieces(color: .black).map(\.logicalSquare))

        var breached: [String] = []
        var crushes: [CrushEvent] = []
        var moved: [(from: String, to: String)] = []

        for square in squares {
            guard let piece = board.piece(at: square) else { continue }
            guard let next = FleetRules.descended(square) else {
                breached.append(square)
                continue
            }
            if let crush = board.forcePlace(piece, at: next) { crushes.append(crush) }
            moved.append((square, next))
        }

        fleetNode.position.y += squareSize
        DiagnosticsLog.shared.log(.fleet, "logical rank descended")

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

    /// How far the formation currently sits from its true squares.
    var lateralOffset: CGFloat { fleetNode.position.x }

    /// True while the formation is drawn anywhere other than on its own squares —
    /// mid-shuffle, or resting on a half-rank.
    var isOffTruePosition: Bool {
        abs(fleetNode.position.x) > 1 || abs(fleetNode.position.y) > 1
    }
}
