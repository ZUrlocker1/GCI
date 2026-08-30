import SpriteKit

final class HowToPlayNode: SKNode {

    private static let cyan    = NeonPalette.cyan
    private static let magenta = NeonPalette.magenta
    private static let orange  = NeonPalette.orange
    private static let font    = "PressStart2P-Regular"
    /// The scene hit-tests for this to open the link.
    static let musicLinkName = "musicLink"
    /// The link's target, in this node's coordinates — the overlay sits at the
    /// scene's origin, so they are the scene's coordinates too. The hosting
    /// `SKView` reads it to lay a cursor rect over the word.
    private(set) var linkRect: CGRect = .zero

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

    // MARK: - Back button

    /// Exactly where the HUD's INFO button was a moment ago — same corner, same
    /// box, same type size. The control that opens the panel and the control
    /// that closes it are the same shape in the same place.
    static let navRect = CGRect(x: 820, y: 671, width: 70, height: 22)

    private func buildBackButton(w: CGFloat, h: CGFloat) {
        let btn = SKShapeNode(rect: Self.navRect, cornerRadius: 3)
        btn.fillColor   = Self.cyan.withAlphaComponent(0.18)
        btn.strokeColor = Self.cyan; btn.lineWidth = 1; btn.name = "backButton"
        addChild(btn)

        let lbl = label("• BACK", 8, Self.cyan, .center)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: Self.navRect.midX, y: Self.navRect.midY)
        lbl.name = "backButton"
        addChild(lbl)
    }

    // MARK: - Header

    private func buildHeader(w: CGFloat, h: CGFloat) {
        let hud = Self.hudBase

        // "HOW TO PLAY" is the eyebrow — it names the panel, so it comes first
        // and stays small. The game's name carries the weight underneath.
        let sub = label("HOW TO PLAY", 14, Self.cyan.withAlphaComponent(0.65), .center)
        sub.position = CGPoint(x: w / 2, y: hud - 20)
        addChild(sub)

        // 30pt over 23 characters is 690pt against 880pt of usable width, so it
        // fits with room either side. Baselines 42pt apart, which clears the
        // 30pt caps with 12pt of air between the two lines.
        let title = label("GALACTIC CHESS INVADERS", 30, Self.cyan, .center)
        title.position = CGPoint(x: w / 2, y: hud - 62)
        addChild(title)

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
        heading("CONTROLS", Self.cyan, x: x, y: 408)
        chip("← →",   "Arrows or A / D move the ship",     x: x, y: 388)
        chip("SPACE",  "Fire laser",                        x: x, y: 344)
        chip("CLICK",  "Pick piece, then new square",        x: x, y: 300)
        // Two keys on one row: a fifth chip would run into the HISTORY heading
        // below, and 25 characters at 12pt still clears the column.
        chip("ESC",    "Escape pauses  ·  Q quits",          x: x, y: 256)

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
        // "TEST MODE  ⌘T", drawn in two fonts. Press Start 2P has no U+2318, so
        // the command glyph comes from the system font — smooth among the pixel
        // caps, but the symbol everyone actually reads, which beats spelling it
        // out. Placed by the same em arithmetic as everything else: the pixel
        // font advances exactly one em per character, so "TEST MODE" plus two
        // spaces puts the glyph at 11 ems and the T at 12.
        let testDim = Self.cyan.withAlphaComponent(0.55)
        let testEm: CGFloat = 18
        heading("TEST MODE", testDim, x: x, y: 155)
        // 4pt above the pixel caps' baseline: the two fonts do not share one,
        // and the system glyph sat low against them.
        addChild(commandGlyph(size: testEm, color: testDim,
                              at: CGPoint(x: x + 11 * testEm, y: 155 + 4)))
        let testKey = label("T", testEm, testDim, .left)
        testKey.position = CGPoint(x: x + 12 * testEm, y: 155)
        addChild(testKey)
        // Two short lines rather than one long one — five key/label pairs on a
        // single row runs the width of the column and reads as a wall. A, P, R
        // and V do nothing until Command-T arms them; L works either way.
        //
        // Press Start 2P advances exactly one em per character, so the padding
        // after "Log" is counted rather than eyeballed: it puts `A` and `V` on
        // the same column, 16 characters in on both lines.
        for (i, line) in ["L  Log      ·   A  Auto   ·   P  Powerup",
                          "R  Raider   ·   V  Level"].enumerated() {
            // 10pt, not 11: at 11 the longer line is 440pt against a 410pt
            // column and runs off the panel.
            let keys = label(line, 10, SKColor.white.withAlphaComponent(0.6), .left)
            keys.position = CGPoint(x: x, y: 137 - CGFloat(i) * 17)
            addChild(keys)
        }

        // — CREDIT —
        // Two labels rather than one, so only the word that is a link looks
        // like one. The bare URL is gone; the underline is what says it is
        // clickable. 10pt to match the debug lines above it.
        //
        // Press Start 2P advances exactly one em per character, so "Music
        // created by" is 16 × 10 = 160pt and the word after it can be placed by
        // arithmetic rather than by measuring a node — with the em of space
        // between them counted rather than trusted to a trailing space.
        // At the left margin rather than in this column: at body size the line
        // is 480pt and the right column is 410. Below both columns it has the
        // full panel to run in, and it lines up with the resume hint under it.
        //
        // Body size and full white, not 10pt at 60%. This is the one credit on
        // the screen that names someone, and it was the quietest thing on it.
        let cx = Self.lx
        let em: CGFloat = 12
        let creditY: CGFloat = 83
        let credit = label("All music created by ", em, .white, .left)
        credit.position = CGPoint(x: cx, y: creditY)
        addChild(credit)

        // Press Start 2P advances exactly one em per character, so every
        // position on this line is arithmetic: 21 characters, then the link,
        // then the rest.
        let linkX = cx + 21 * em
        let linkW: CGFloat = 5 * em      // "Zudio"
        let link = label("Zudio", em, Self.cyan.withAlphaComponent(0.9), .left)
        link.position = CGPoint(x: linkX, y: creditY)
        addChild(link)

        // One line: the HISTORY block above ends around y=104 and the footer
        // rule is at 70, so there is room for one 12pt line here and not two.
        // 58 characters at 12pt runs to x=746, well inside the 910 margin.
        // The em of space is counted, not written: a leading space in an
        // SKLabelNode does not advance the first glyph, so "Zudio" and
        // "available" ran together. Same lesson as the debug key columns above.
        let tail = label("available on Mac, iPhone, iPad.", em, .white, .left)
        tail.position = CGPoint(x: linkX + linkW + em, y: creditY)
        addChild(tail)

        let underline = SKShapeNode(rect: CGRect(x: linkX, y: creditY - 3, width: linkW, height: 0.9))
        underline.fillColor = Self.cyan.withAlphaComponent(0.9)
        underline.strokeColor = .clear
        addChild(underline)

        // A padded, invisible target over the word — five characters at 10pt is
        // a 50×10 click box otherwise. Added last so `atPoint` returns it.
        // Stored as well as drawn, so the cursor rect and the click target are
        // the same rectangle rather than two that have to be kept in step.
        linkRect = CGRect(x: linkX - 6, y: creditY - 8, width: linkW + 12, height: 24)
        let hit = SKShapeNode(rect: linkRect)
        hit.fillColor = .clear
        hit.strokeColor = .clear
        hit.name = Self.musicLinkName
        addChild(hit)
    }

    // MARK: - Footer

    private func buildFooter(w: CGFloat) {
        addChild(hline(x: 40, y: 70, w: w - 80))

        // BACK has moved to the top right, so the footer starts at the margin.
        let hint = label("PRESS ANY KEY TO RESUME GAME", 10, Self.cyan.withAlphaComponent(0.65), .left)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: Self.lx, y: 39)
        addChild(hint)

        // Lower right, mirroring the left margin, and matched to the resume
        // hint's size so the two footer lines read as a pair.
        let copyright = label("Copyright (C) 1983-2026 M. Zack Urlocker", 10, .white, .right)
        copyright.verticalAlignmentMode = .center
        copyright.position = CGPoint(x: w - Self.lx, y: 39)
        addChild(copyright)
    }

    // MARK: - Scoring grid  (3 columns, 2 rows)

    private func scoringGrid(x: CGFloat, topY: CGFloat) {
        // Reading order is descending value, so the row you look at first is
        // the one worth most.
        let items: [(String, String)] = [
            ("king", "500"), ("queen", "150"), ("rook", "75"),
            ("knight", "50"), ("bishop", "50"), ("pawn", "25"),
        ]
        // Three across in a 410pt column. A cell is the icon plus three digits
        // at 16pt — 110pt of ink — so 135 leaves 25pt of air between cells and
        // the last one ends at 890, inside the 910pt margin.
        let colW: CGFloat = 135
        // 44 rather than 60. The icons are 34pt tall, so this leaves 10pt
        // between rows — enough to read as a grid.
        let rowH: CGFloat = 44
        let iconH: CGFloat = 34

        for (i, (piece, pts)) in items.enumerated() {
            let col = CGFloat(i % 3)
            let row = CGFloat(i / 3)
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

    /// The ⌘ symbol, in whatever font the system has for it.
    ///
    /// Press Start 2P stops at Latin-1 and has no U+2318. Naming no font lets
    /// CoreText substitute one that does. Scaled to 0.86 because a system face
    /// carries far more ink inside the same point size than a pixel font does,
    /// and at 1.0 the symbol towers over the capitals beside it.
    private func commandGlyph(size: CGFloat, color: SKColor, at point: CGPoint) -> SKLabelNode {
        let glyph = SKLabelNode(text: "⌘")
        glyph.fontSize = size * 0.86
        glyph.fontColor = color
        glyph.horizontalAlignmentMode = .left
        glyph.verticalAlignmentMode = .baseline
        glyph.position = point
        glyph.zPosition = -1
        return glyph
    }

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
