// BoardNode.swift
// The 8×8 playfield's coordinate space, plus selection and legal-move feedback.
// Owns the square ↔ point mapping used for click hit-testing.
//
// §20 Phase 2.1 asked for "coordinate mapping, no visible grid": the fleet
// sweeps horizontally between squares like Space Invaders, so a lattice would
// have constantly disagreed with where the pieces actually were. That stopped
// being true once the sweep was capped below one file, and the grid, the
// deployment bands and the a-h/1-8 labels are all drawn now — but all three are
// on the player's Board Grid slider, and the top of its range is the only place
// the labels appear.
//
// Node origin is the bottom-left corner of a1, so local coordinates run
// 0…boardSize on both axes with rank 1 at the bottom.

import SpriteKit

final class BoardNode: SKNode {

    static let squareSize: CGFloat = 64
    static let boardSize: CGFloat = squareSize * 8
    /// Pool size for legal-move markers. A queen on an empty board reaches 27
    /// squares, so 32 covers every real case with headroom.
    static let markerPoolSize = 32
    private static let checkPathName = "checkPath"
    private static let tetherName = "fleetTether"

    private static let cyan    = NeonPalette.cyan
    private static let magenta = NeonPalette.magenta
    private static let files   = Array("abcdefgh")

    /// A pooled legal-move marker: one node holding both presentations, so
    /// switching between quiet move and capture is a visibility flip.
    private final class Marker: SKNode {
        let dot: SKShapeNode
        let ring: SKShapeNode

        init(squareSize: CGFloat) {
            dot = SKShapeNode(circleOfRadius: 6)
            dot.fillColor = BoardNode.cyan.withAlphaComponent(0.6)
            dot.strokeColor = BoardNode.cyan
            dot.lineWidth = 1
            dot.glowWidth = 4

            ring = SKShapeNode(circleOfRadius: squareSize / 2 - 5)
            ring.strokeColor = BoardNode.magenta.withAlphaComponent(0.85)
            ring.lineWidth = 2
            ring.glowWidth = 4
            ring.fillColor = .clear

            super.init()
            addChild(dot)
            addChild(ring)
            isHidden = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        func show(at point: CGPoint, isCapture: Bool) {
            position = point
            dot.isHidden = isCapture
            ring.isHidden = !isCapture
            isHidden = false
        }
    }

    private let selection = SKShapeNode()
    private let markers   = SKNode()
    /// Pre-allocated: a queen on an open board tops out well under this, and the
    /// pool means selecting a piece never allocates during play (§18).
    private var markerPool: [Marker] = []

    /// §12.3 ruled out a grid because the fleet slid beyond the board's edges, so
    /// any lattice would have contradicted where the pieces were. That stopped
    /// being true once the sweep was capped below one file — nothing ever leaves
    /// its square now, and without a lattice the eye has nothing to measure the
    /// remaining offset against. Set false to go back to open space.
    static let showsGrid = true

    /// Kept so the settings screen can dim the lattice without a rebuild.
    private var gridNode: SKShapeNode?
    private var zoneNodes: [SKShapeNode] = []
    private var coordinateNodes: [SKLabelNode] = []

    /// Coordinates are the last thing to arrive, and only at the very top of the
    /// slider. They are a chess player's aid rather than part of the arcade
    /// look, so they stay fully invisible across the whole ordinary range —
    /// nothing at all at the 50% default — and fade in over the final tenth.
    private static let coordinateThreshold: CGFloat = 0.9

    override init() {
        super.init()
        if Self.showsGrid { buildGrid() }
        applyDisplaySettings()
        buildSelection()
        markers.zPosition = 2
        addChild(markers)
        buildMarkerPool()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Grid

    /// A fixed lattice. It never moves, scrolls or pulses — its entire job is to
    /// be the one thing on screen that is stationary, so a marching fleet can be
    /// read against it. Anything that animated here would defeat the purpose.
    ///
    /// One shape node for all 18 lines, so this is a single draw call.
    private func buildGrid() {
        let lines = CGMutablePath()
        for index in 0...8 {
            let offset = CGFloat(index) * Self.squareSize
            lines.move(to: CGPoint(x: offset, y: 0))
            lines.addLine(to: CGPoint(x: offset, y: Self.boardSize))
            lines.move(to: CGPoint(x: 0, y: offset))
            lines.addLine(to: CGPoint(x: Self.boardSize, y: offset))
        }
        let grid = SKShapeNode(path: lines)
        grid.zPosition = -1
        addChild(grid)
        gridNode = grid

        // The deployment zones §12.3 already allows: a touch more light at the
        // two ends, so the board reads as having a near side and a far side.
        for band in [CGFloat(0), Self.boardSize - Self.squareSize * 2] {
            let zone = SKShapeNode(rect: CGRect(x: 0, y: band,
                                                width: Self.boardSize,
                                                height: Self.squareSize * 2))
            zone.strokeColor = .clear
            zone.zPosition = -2
            addChild(zone)
            zoneNodes.append(zone)
        }

        buildCoordinates()
    }

    /// Files below the board and ranks to its left, both outside the playfield
    /// so they never sit under a piece. There is 58pt between the board's
    /// bottom edge and the ship's lane, and the left margin holds the power-up
    /// alley at x=112, so both labels clear their neighbours.
    private func buildCoordinates() {
        for index in 0..<8 {
            let file = label(String(UnicodeScalar(97 + index)!), align: .center)
            file.position = CGPoint(x: (CGFloat(index) + 0.5) * Self.squareSize, y: -16)
            addChild(file)
            coordinateNodes.append(file)

            let rank = label("\(index + 1)", align: .right)
            rank.verticalAlignmentMode = .center
            rank.position = CGPoint(x: -12, y: (CGFloat(index) + 0.5) * Self.squareSize)
            addChild(rank)
            coordinateNodes.append(rank)
        }
    }

    private func label(_ text: String, align: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: "PressStart2P-Regular")
        node.text = text
        node.fontSize = 8
        node.fontColor = Self.cyan
        node.horizontalAlignmentMode = align
        node.zPosition = -1
        return node
    }

    /// Applies the player's Display settings to the lattice and the deployment
    /// bands. The slider drives alpha and line width together — "more grid" is
    /// one idea, not two — and the shipped look sits at its midpoint, so 50%
    /// reproduces exactly what the game drew before the setting existed.
    func applyDisplaySettings() {
        let settings = GameSettings.shared
        let amount = min(max(settings.boardGrid, 0), 1)
        gridNode?.strokeColor = Self.cyan.withAlphaComponent(0.364 * amount)
        gridNode?.lineWidth = 0.75 + 0.5 * amount
        for zone in zoneNodes {
            zone.fillColor = Self.cyan.withAlphaComponent(settings.homeZones ? 0.0728 : 0)
        }
        let threshold = Self.coordinateThreshold
        let reveal = max(0, (amount - threshold) / (1 - threshold))
        for node in coordinateNodes { node.alpha = reveal * 0.7 }
    }

    // MARK: - Square ↔ point mapping

    /// Centre of `square` in this node's coordinate space, or nil if not a valid square.
    func center(of square: String) -> CGPoint? {
        guard let (file, rank) = Self.indices(of: square) else { return nil }
        let s = Self.squareSize
        return CGPoint(x: CGFloat(file) * s + s / 2, y: CGFloat(rank) * s + s / 2)
    }

    /// The square containing `point` (this node's coordinate space), or nil if outside the board.
    func square(at point: CGPoint) -> String? {
        let s = Self.squareSize
        guard point.x >= 0, point.y >= 0,
              point.x < Self.boardSize, point.y < Self.boardSize else { return nil }
        let file = Int(point.x / s)
        let rank = Int(point.y / s)
        return "\(Self.files[file])\(rank + 1)"
    }

    /// (fileIndex 0…7, rankIndex 0…7) for an algebraic square.
    private static func indices(of square: String) -> (Int, Int)? {
        let chars = Array(square)
        guard chars.count == 2,
              let file = files.firstIndex(of: chars[0]),
              let rank = chars[1].wholeNumberValue,
              (1...8).contains(rank) else { return nil }
        return (file, rank - 1)
    }

    // MARK: - Selection & legal-move markers

    func showSelection(at square: String?) {
        guard let square, let point = center(of: square) else {
            selection.isHidden = true
            return
        }
        selection.position = point
        selection.isHidden = false
    }

    /// Shows a marker on each destination: a dot for a quiet move, a ring for a
    /// capture. Draws from the pool — nothing is added or removed from the tree.
    func showLegalMoves(_ destinations: [String], captures: Set<String>) {
        hideAllMarkers()
        var index = 0
        for square in destinations {
            guard index < markerPool.count, let point = center(of: square) else { continue }
            markerPool[index].show(at: point, isCapture: captures.contains(square))
            index += 1
        }
        if destinations.count > markerPool.count {
            DiagnosticsLog.shared.log(.error,
                "Legal-move markers exhausted: \(destinations.count) needed, \(markerPool.count) pooled")
        }
    }

    /// Draws the path from each checking piece to the king. Checks are rare, so
    /// these are created and self-remove rather than being pooled.
    ///
    /// Endpoints arrive as points, not squares: a black piece belongs to the
    /// fleet and is drawn offset from its logical square, so the caller resolves
    /// where each piece actually *is*. A line that visibly misses the piece it
    /// indicts defeats the whole purpose of drawing it.
    func showCheckPaths(_ paths: [(from: CGPoint, to: CGPoint, isJump: Bool)],
                        color: SKColor, pulses: Int = 2) {
        clearCheckPaths()
        for path in paths {
            let node = CheckPathNode(from: path.from, to: path.to, isJump: path.isJump,
                                     color: color, pulses: pulses)
            node.name = Self.checkPathName
            addChild(node)
        }
    }

    /// A hairline from where a fleet piece is drawn to the square it actually
    /// occupies. Only shown for pieces the player has just threatened, so it
    /// answers "which square is that?" at the moment the question is asked and
    /// stays out of the way otherwise.
    func showTethers(_ tethers: [(from: CGPoint, to: CGPoint)], color: SKColor) {
        clearTethers()
        for tether in tethers {
            let path = CGMutablePath()
            path.move(to: tether.from)
            path.addLine(to: tether.to)
            let line = SKShapeNode(path: path)
            line.strokeColor = color.withAlphaComponent(0.45)
            line.lineWidth = 1
            line.zPosition = 4
            line.name = Self.tetherName
            addChild(line)

            let foot = SKShapeNode(circleOfRadius: 3)
            foot.position = tether.to
            foot.strokeColor = .clear
            foot.fillColor = color.withAlphaComponent(0.55)
            foot.zPosition = 4
            foot.name = Self.tetherName
            addChild(foot)
        }
    }

    func clearTethers() {
        for node in children where node.name == Self.tetherName {
            node.removeFromParent()
        }
    }

    func clearCheckPaths() {
        for node in children where node.name == Self.checkPathName {
            node.removeAllActions()
            node.removeFromParent()
        }
    }

    func clearMarkers() {
        hideAllMarkers()
        selection.isHidden = true
    }

    private func hideAllMarkers() {
        for marker in markerPool { marker.isHidden = true }
    }

    private func buildMarkerPool() {
        markerPool = (0..<Self.markerPoolSize).map { _ in
            let marker = Marker(squareSize: Self.squareSize)
            markers.addChild(marker)
            return marker
        }
    }

    // MARK: - Construction





    private func buildSelection() {
        let s = Self.squareSize
        selection.path = CGPath(roundedRect: CGRect(x: -s / 2, y: -s / 2, width: s, height: s),
                                cornerWidth: 4, cornerHeight: 4, transform: nil)
        selection.strokeColor = Self.cyan
        selection.lineWidth = 2
        selection.fillColor = Self.cyan.withAlphaComponent(0.16)
        selection.zPosition = 2
        selection.isHidden = true
        selection.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.45, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0,  duration: 0.5)
        ])))
        addChild(selection)
    }
}
