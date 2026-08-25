// PlaceholderBoardNode.swift
// Phase 0 placeholder: colored rectangles where pieces and the board will be.
// Replaced by real PieceNodes + BoardLayout in Phase 2.1.

import SpriteKit

final class PlaceholderBoardNode: SKNode {

    // Board geometry — will be owned by BoardLayout.swift in Phase 2.1
    private static let squareSize: CGFloat = 60
    private static let columns = 8
    private static let rows    = 8

    // Board occupies columns × squareSize wide, centred in the 960-wide scene
    private static let boardWidth  = CGFloat(columns) * squareSize     // 480
    private static let boardHeight = CGFloat(rows)    * squareSize     // 480

    override init() {
        super.init()
        setupGrid()
        setupPlaceholderPieces()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Faint Grid

    private func setupGrid() {
        let w = Self.boardWidth
        let h = Self.boardHeight
        let s = Self.squareSize
        let dim = SKColor.white.withAlphaComponent(0.06)

        // Vertical lines
        for col in 0...Self.columns {
            let x = CGFloat(col) * s - w / 2
            let line = SKShapeNode(rectOf: CGSize(width: 0.5, height: h))
            line.fillColor   = dim
            line.strokeColor = .clear
            line.position    = CGPoint(x: x, y: 0)
            addChild(line)
        }
        // Horizontal lines
        for row in 0...Self.rows {
            let y = CGFloat(row) * s - h / 2
            let line = SKShapeNode(rectOf: CGSize(width: w, height: 0.5))
            line.fillColor   = dim
            line.strokeColor = .clear
            line.position    = CGPoint(x: 0, y: y)
            addChild(line)
        }
    }

    // MARK: - Piece Placeholders

    // Standard starting positions as (col, row) 0-indexed from bottom-left
    private func setupPlaceholderPieces() {
        let cyan    = SKColor(red: 0.07, green: 0.88, blue: 1.00, alpha: 0.85)   // white side
        let magenta = SKColor(red: 1.00, green: 0.13, blue: 0.38, alpha: 0.85)  // black side

        // White pieces: rows 0 (back rank) and 1 (pawns)
        for col in 0..<8 {
            addPlaceholder(col: col, row: 1, color: cyan, label: "P")
        }
        let backRank = ["R", "N", "B", "Q", "K", "B", "N", "R"]
        for (col, name) in backRank.enumerated() {
            addPlaceholder(col: col, row: 0, color: cyan, label: name)
        }

        // Black pieces: rows 6 (pawns) and 7 (back rank)
        for col in 0..<8 {
            addPlaceholder(col: col, row: 6, color: magenta, label: "P")
        }
        for (col, name) in backRank.enumerated() {
            addPlaceholder(col: col, row: 7, color: magenta, label: name)
        }
    }

    private func addPlaceholder(col: Int, row: Int, color: SKColor, label: String) {
        let s = Self.squareSize
        let w = Self.boardWidth
        let h = Self.boardHeight
        let size = CGSize(width: s * 0.60, height: s * 0.72)

        let x = CGFloat(col) * s - w / 2 + s / 2
        let y = CGFloat(row) * s - h / 2 + s / 2

        let rect = SKShapeNode(rectOf: size, cornerRadius: 4)
        rect.fillColor   = color.withAlphaComponent(0.25)
        rect.strokeColor = color
        rect.lineWidth   = 1.5
        rect.position    = CGPoint(x: x, y: y)

        let tag = SKLabelNode(fontNamed: "PressStart2P-Regular")
        tag.text = label
        tag.fontSize = 11
        tag.fontColor = color
        tag.horizontalAlignmentMode = .center
        tag.verticalAlignmentMode = .center
        tag.position = .zero
        rect.addChild(tag)

        addChild(rect)
    }
}
