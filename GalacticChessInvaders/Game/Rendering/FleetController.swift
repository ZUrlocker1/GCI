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
    private let boardWidth: CGFloat

    private var descent = FleetRules.DescentCounter()
    private var direction: CGFloat = 1        // +1 right, -1 left
    private var isRunning = false

    /// Current level parameters, re-read on every leg so escalation takes effect.
    var levelParameters: LevelParameters
    var onCrush: CrushHandler?
    var onBreach: BreachHandler?
    var onRankDescended: DescentHandler?

    private static let sweepKey = "fleetSweep"
    private static let halfDropDuration: TimeInterval = 0.18

    init(board: GCIBoard, parent: SKNode, squareSize: CGFloat, boardWidth: CGFloat,
         level: LevelParameters) {
        self.board = board
        self.squareSize = squareSize
        self.boardWidth = boardWidth
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

    func start() {
        guard !isRunning else { return }
        isRunning = true
        beginLeg()
    }

    func stop() {
        isRunning = false
        fleetNode.removeAllActions()
    }

    func reset() {
        stop()
        fleetNode.removeAllChildren()
        fleetNode.position = .zero
        descent.reset()
        direction = 1
    }

    /// One left-or-right leg, ending at the wall. Speed and extent are recomputed
    /// per leg, so the fleet accelerates as it is thinned without rebuilding a
    /// repeating action.
    private func beginLeg() {
        guard isRunning, pieceCount > 0 else { return }

        let (minX, maxX) = localExtent()
        // The parent may slide until the leading piece touches a board edge.
        let lowerBound = -minX
        let upperBound = boardWidth - maxX
        guard upperBound > lowerBound else { return }   // fleet wider than the board

        let target = direction > 0 ? upperBound : lowerBound
        let distance = abs(target - fleetNode.position.x)
        let speed = FleetRules.sweepSpeed(level: levelParameters,
                                          piecesRemaining: pieceCount)

        guard distance > 0.5, speed > 0 else {
            handleWallBounce()
            return
        }

        DiagnosticsLog.shared.log(.fleet,
            "swept \(direction > 0 ? "right" : "left") (\(Int(speed))px/s)")

        let slide = SKAction.moveTo(x: target, duration: TimeInterval(distance / speed))
        let bounce = SKAction.run { [weak self] in self?.handleWallBounce() }
        fleetNode.run(.sequence([slide, bounce]), withKey: Self.sweepKey)
    }

    private func handleWallBounce() {
        guard isRunning else { return }
        direction *= -1

        let completesRank = descent.registerBounce()
        let drop = SKAction.moveBy(x: 0, y: -squareSize / 2, duration: Self.halfDropDuration)

        fleetNode.run(drop) { [weak self] in
            guard let self else { return }
            if completesRank {
                self.applyFullRankDescent()
            } else {
                DiagnosticsLog.shared.log(.fleet, "visual half-drop 1/2; logical ranks unchanged")
            }
            self.beginLeg()
        }
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

    /// Horizontal span of the living formation, in fleet-local coordinates.
    private func localExtent() -> (min: CGFloat, max: CGFloat) {
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        for child in fleetNode.children {
            let half = child.calculateAccumulatedFrame().width / 2
            minX = Swift.min(minX, child.position.x - half)
            maxX = Swift.max(maxX, child.position.x + half)
        }
        guard minX <= maxX else { return (0, 0) }
        return (minX, maxX)
    }
}
