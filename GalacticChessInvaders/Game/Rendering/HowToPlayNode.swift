import SpriteKit

final class HowToPlayNode: SKNode {

    private static let cyan    = NeonPalette.cyan
    private static let magenta = NeonPalette.magenta
    private static let orange  = NeonPalette.orange
    private static let font    = "PressStart2P-Regular"
    /// The scene hit-tests for this to open the link.
    static let musicLinkName = "musicLink"

    // Hardcoded layout coordinates derived from 960×700 scene with 36px HUD at top.
    // All y values are scene-space (0 = bottom, 700 = top).
    private static let W: CGFloat = 960
    private static let H: CGFloat = 700
    private static let hudBase: CGFloat = H - HUDNode.height   // 664
    private static let lx: CGFloat = 50    // left column x
    private static let rx: CGFloat = 510   // right column x
    private static let lw: CGFloat = 420   // left column max text width
    private static let rw: CGFloat = 410   // right column max text width

    init(sceneSize: CGSize) {
        super.init()
        let w = Self.W, h = Self.H
        buildBackground(w: w, h: h)
        buildBackButton(w: w, h: h)
        buildHeader(w: w, h: h)
        buildLeftColumn()
        buildRightColumn()
        buildFooter(w: w)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Background

    private func buildBackground(w: CGFloat, h: CGFloat) {
        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: w, height: h))
        bg.fillColor = SKColor(white: 0, alpha: 0.97)
        bg.strokeColor = .clear
        bg.zPosition = -1
        addChild(bg)
    }

    // MARK: - Back button — lower-left of the screen (§10)

    private func buildBackButton(w: CGFloat, h: CGFloat) {
        let by: CGFloat = 26
        let btn = SKShapeNode(rect: CGRect(x: Self.lx, y: by, width: 102, height: 26), cornerRadius: 3)
        btn.fillColor   = Self.cyan.withAlphaComponent(0.18)
        btn.strokeColor = Self.cyan; btn.lineWidth = 1; btn.name = "backButton"
        addChild(btn)

        let lbl = label("• BACK", 10, Self.cyan, .center)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: Self.lx + 51, y: by + 13)
        lbl.name = "backButton"
        addChild(lbl)
    }

    // MARK: - Header

    private func buildHeader(w: CGFloat, h: CGFloat) {
        let hud = Self.hudBase

        // The game's name leads; "HOW TO PLAY" is what the panel is, not what it
        // is about. 30pt over 23 characters is 690pt against 880pt of usable
        // width, so it fits with room either side.
        let title = label("GALACTIC CHESS INVADERS", 30, Self.cyan, .center)
        title.position = CGPoint(x: w / 2, y: hud - 36)
        addChild(title)

        let sub = label("HOW TO PLAY", 14, Self.cyan.withAlphaComponent(0.65), .center)
        sub.position = CGPoint(x: w / 2, y: hud - 68)
        addChild(sub)

        addChild(hline(x: 40, y: hud - 84, w: w - 80))
    }

    // MARK: - Left column

    private func buildLeftColumn() {
        let x = Self.lx
        // — THE TWIST —
        heading("THE TWIST", Self.cyan, x: x, y: 562)
        multiline("A real chess game plays out — but Black's army is also a Space Invaders fleet. It slides sideways, drops down, and fires at you. You command White's moves and a laser ship at the bottom of the screen.",
                  size: 12, maxW: Self.lw, x: x, y: 548)

        // — CONTROLS —
        heading("CONTROLS", Self.cyan, x: x, y: 413)
        chip("← →",   "Move your ship",                    x: x, y: 393)
        chip("SPACE",  "Fire laser",                        x: x, y: 349)
        chip("CLICK",  "Pick piece, then new square",        x: x, y: 305)
        chip("ESC",    "Press Escape to pause",             x: x, y: 261)

        // — HISTORY —
        heading("HISTORY", Self.magenta, x: x, y: 203)
        multiline("GCI began as a prototype in 1983 on the Apple II, written in TASC compiled BASIC. Now, with the help of Claude, you can experience a modern recharged version.",
                  size: 12, maxW: Self.lw, x: x, y: 189)
    }

    // MARK: - Right column

    private func buildRightColumn() {
        let x = Self.rx
        // — HOW TO WIN —
        heading("HOW TO WIN", Self.cyan, x: x, y: 562)
        multiline("Clear the board: destroy every black piece by shooting it or capturing it in chess. Landing a shot on the black King ends the wave with a huge bonus.",
                  size: 12, maxW: Self.rw, x: x, y: 548)

        // — STAY ALIVE —
        heading("STAY ALIVE", Self.magenta, x: x, y: 428)
        multiline("Guard your White King and your ship. You have 3 lives — lose one if a shot hits your ship or an invader reaches the bottom row.",
                  size: 12, maxW: Self.rw, x: x, y: 414)

        // — SCORING —
        heading("SCORING", Self.magenta, x: x, y: 310)
        scoringGrid(x: x, topY: 280)

        // — DEBUG KEYS —
        // Deliberately plain, and last. The panel ships, so these are reachable
        // by anyone — but they are a way to look behind the game, not part of
        // playing it, and the layout should say so.
        heading("DEBUG MODE", Self.cyan.withAlphaComponent(0.55), x: x, y: 145)
        // Two short lines rather than one long one — five key/label pairs on a
        // single row runs the width of the column and reads as a wall.
        //
        // Press Start 2P advances exactly one em per character, so the padding
        // after "Log" is counted rather than eyeballed: it puts `A` and `V` on
        // the same column, 16 characters in on both lines.
        for (i, line) in ["L  Log      ·   A  Auto   ·   P  Powerup",
                          "R  Raider   ·   V  Level"].enumerated() {
            // 10pt, not 11: at 11 the longer line is 440pt against a 410pt
            // column and runs off the panel.
            let keys = label(line, 10, SKColor.white.withAlphaComponent(0.6), .left)
            keys.position = CGPoint(x: x, y: 127 - CGFloat(i) * 17)
            addChild(keys)
        }

        // — CREDIT —
        // Cyan and named, because the scene opens the URL when it is clicked;
        // 9pt because the line with the domain on it is 396pt against a 410pt
        // column and 10pt would run off the panel.
        let music = label("Music created by Zudio · mzurlocker.com/zudio",
                          9, Self.cyan.withAlphaComponent(0.8), .left)
        music.name = Self.musicLinkName
        music.position = CGPoint(x: x, y: 88)
        addChild(music)
    }

    // MARK: - Footer

    private func buildFooter(w: CGFloat) {
        addChild(hline(x: 40, y: 70, w: w - 80))

        // BACK now occupies the lower-left, so the hint sits to its right.
        let hint = label("PRESS ANY KEY TO RESUME", 10, Self.cyan.withAlphaComponent(0.65), .left)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: Self.lx + 122, y: 39)
        addChild(hint)

        // Lower right, mirroring the left margin, and matched to the resume
        // hint's size so the two footer lines read as a pair.
        let copyright = label("Copyright (C) 1983-2026 M. Zack Urlocker", 10, .white, .right)
        copyright.verticalAlignmentMode = .center
        copyright.position = CGPoint(x: w - Self.lx, y: 39)
        addChild(copyright)
    }

    // MARK: - Scoring grid  (2 columns, 3 rows, 60 pt row height)

    private func scoringGrid(x: CGFloat, topY: CGFloat) {
        let items: [(String, String)] = [
            ("king", "500"), ("queen", "150"),
            ("rook",  "75"), ("knight",  "50"),
            ("bishop","50"), ("pawn",    "25"),
        ]
        let colW: CGFloat = 200
        // 44 rather than 60. The icons are 34pt tall, so this leaves 10pt
        // between rows — enough to read as a grid, and it reclaims 48pt for the
        // debug key line underneath.
        let rowH: CGFloat = 44
        let iconH: CGFloat = 34

        for (i, (piece, pts)) in items.enumerated() {
            let col = CGFloat(i % 2)
            let row = CGFloat(i / 2)
            let px = x + col * colW
            let py = topY - row * rowH

            let tex  = SKTexture(imageNamed: "chess-b-\(piece)")
            let ts   = tex.size()
            let sc   = ts.height > 0 ? iconH / ts.height : 1
            let node = SKSpriteNode(texture: tex, size: CGSize(width: ts.width * sc, height: iconH))
            node.position = CGPoint(x: px + 26, y: py)
            node.color = Self.magenta; node.colorBlendFactor = 0.15
            addChild(node)

            let ptLbl = label(pts, 16, .white, .left)
            ptLbl.position = CGPoint(x: px + 62, y: py - 9)
            addChild(ptLbl)
        }
    }

    // MARK: - Primitive helpers

    private func heading(_ text: String, _ color: SKColor, x: CGFloat, y: CGFloat) {
        let node = label(text, 18, color, .left)
        node.position = CGPoint(x: x, y: y)
        addChild(node)
    }

    private func multiline(_ text: String, size: CGFloat, maxW: CGFloat, x: CGFloat, y: CGFloat) {
        let node = SKLabelNode(fontNamed: Self.font)
        node.numberOfLines = 0
        node.preferredMaxLayoutWidth = maxW
        node.horizontalAlignmentMode = .left
        node.verticalAlignmentMode   = .top
        node.position = CGPoint(x: x, y: y)

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4.0
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: Self.font, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85),
            .paragraphStyle: style
        ]
        node.attributedText = NSAttributedString(string: text, attributes: attrs)
        addChild(node)
    }

    private func chip(_ key: String, _ desc: String, x: CGFloat, y: CGFloat) {
        // Box sized to the key text, centered on y
        let chipW = CGFloat(key.count) * 10 + 18
        let chipH: CGFloat = 30
        let box = SKShapeNode(rect: CGRect(x: 0, y: -chipH / 2, width: chipW, height: chipH),
                              cornerRadius: 3)
        box.fillColor   = Self.cyan.withAlphaComponent(0.14)
        box.strokeColor = Self.cyan.withAlphaComponent(0.65); box.lineWidth = 0.75
        box.position    = CGPoint(x: x, y: y); addChild(box)

        // Key label — centered horizontally and vertically inside the chip
        let kLbl = label(key, 12, Self.cyan, .center)
        kLbl.verticalAlignmentMode = .center
        kLbl.position = CGPoint(x: x + chipW / 2, y: y)
        addChild(kLbl)

        // Description — vertically centred with the chip
        let dLbl = label(desc, 12, SKColor.white.withAlphaComponent(0.88), .left)
        dLbl.verticalAlignmentMode = .center
        dLbl.position = CGPoint(x: x + chipW + 16, y: y)
        addChild(dLbl)
    }

    private func label(_ text: String, _ size: CGFloat, _ color: SKColor,
                       _ align: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let n = SKLabelNode(fontNamed: Self.font)
        n.text = text; n.fontSize = size; n.fontColor = color
        n.horizontalAlignmentMode = align; n.verticalAlignmentMode = .baseline
        return n
    }

    private func hline(x: CGFloat, y: CGFloat, w: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y)); path.addLine(to: CGPoint(x: x + w, y: y))
        let s = SKShapeNode(path: path)
        s.strokeColor = Self.cyan.withAlphaComponent(0.28); s.lineWidth = 0.5
        return s
    }
}
