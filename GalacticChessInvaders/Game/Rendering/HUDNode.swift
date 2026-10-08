import SpriteKit

@MainActor
final class HUDNode: SKNode {
    static let height: CGFloat = 36

    private let scoreValue = SKLabelNode()
    private let hiValue    = SKLabelNode()
    private let levelLabel = SKLabelNode()
    private var lifeShips: [SKSpriteNode] = []
    /// Stands in for the ships where there is no room for five of them.
    private let lifeCount = SKLabelNode()
    private let isCompact: Bool

    private static let cyan   = NeonPalette.cyan
    private static let orange = NeonPalette.orange
    private static let font   = "PressStart2P-Regular"

    // MARK: - Compact mode
    //
    // The bar was composed on a 960pt canvas and never reflowed. Its left block
    // ends at 312 and the nav cluster is 226 wide with a 70pt right margin, so
    // it wants 608pt before LEVEL is allocated a single point. A phone in
    // portrait has 393 or 440, and the result is PAUSE / SET / INFO drawn on
    // top of the life ships.
    //
    // Compact keeps every control and takes the width out of the three things
    // that are pure width: five ships become "x3", the buttons lose their
    // padding, and the 70pt right margin becomes 8. LEVEL keeps the behaviour
    // it already had — it shortens, and now it also hides when even the short
    // form will not fit, which Zack judged acceptable since it is the least
    // critical readout on the bar.

    /// Below this the bar cannot hold its design layout. 700 rather than 608:
    /// at exactly 608 LEVEL would be allocated nothing, and the margin above
    /// keeps a landscape phone out of a layout it does not need.
    static let compactBelowWidth: CGFloat = 700

    static func isCompact(sceneWidth: CGFloat) -> Bool { sceneWidth < compactBelowWidth }

    /// Compact geometry, in the same order as the design constants above.
    static let compactHiX: CGFloat = 84
    /// Moved left from 150 to pay for the ship glyph below, so LEVEL keeps the
    /// gap it needs on a Pro Max.
    static let compactLivesX: CGFloat = 126
    /// One ship, a gap, and a digit.
    static let compactLivesWidth: CGFloat = 35
    static let compactButtonWidth: CGFloat = 50
    static let compactButtonGap: CGFloat = 6
    static let compactNavRightMargin: CGFloat = 8
    /// "L 01" at 11pt, which is the shortest LEVEL ever renders.
    static let compactLevelMinWidth: CGFloat = 48

    init(sceneWidth: CGFloat) {
        isCompact = HUDNode.isCompact(sceneWidth: sceneWidth)
        super.init()

        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: sceneWidth, height: HUDNode.height))
        bg.fillColor = SKColor(white: 0, alpha: 0.55); bg.strokeColor = .clear; bg.zPosition = -1
        addChild(bg)

        // Score
        let scoreTitleLbl = SKLabelNode()
        place(scoreTitleLbl, "SCORE", HUDNode.orange, 8,  10,  24)
        place(scoreValue,    "0",      .white,         11, 10,  10)
        scoreValue.name = "scoreValue"

        // Hi-score
        let hiX = isCompact ? HUDNode.compactHiX : HUDNode.hiX
        let hiTitleLbl = SKLabelNode()
        place(hiTitleLbl, "HI",     HUDNode.orange, 8,  hiX, 24)
        place(hiValue,    "0",      HUDNode.orange, 11, hiX, 10)
        hiValue.name = "hiValue"

        // Level
        // Life ships sit between HI and LEVEL, left-anchored with the rest of
        // the block, so nothing downstream of them has to move when a life is
        // lost.
        if isCompact {
            // One ship and a number rather than five ships: 88pt of fixed width
            // becomes 35, which is most of what the bar needed to find.
            //
            // A ship and a numeral, not "x5" — Zack's call, and he is right that
            // the multiplication sign reads as arithmetic on a bar that already
            // carries a score. The glyph says what the number counts.
            let ship = SKSpriteNode(imageNamed: "ship-player")
            if ship.size.height > 0 { ship.setScale(18 / ship.size.height) }
            ship.color = HUDNode.cyan; ship.colorBlendFactor = 0.2
            ship.position = CGPoint(x: HUDNode.compactLivesX + 9, y: 18)
            ship.name = "lifeCountShip"
            addChild(ship)

            place(lifeCount, "3", HUDNode.cyan, 11, HUDNode.compactLivesX + 24, 12)
            lifeCount.name = "lifeCount"
        } else {
            for i in 0..<HUDNode.maxLives {
                let ship = SKSpriteNode(imageNamed: "ship-player")
                if ship.size.height > 0 { ship.setScale(18 / ship.size.height) }
                ship.color = HUDNode.cyan; ship.colorBlendFactor = 0.2
                ship.position = CGPoint(x: HUDNode.livesX + CGFloat(i) * HUDNode.livesStep, y: 18)
                ship.name = "lifeShip\(i)"; addChild(ship); lifeShips.append(ship)
            }
        }

        // LEVEL takes the gap between the lives and the nav, centred in it, and
        // drops to "L 01" when that gap will not hold the long form.
        let livesRight = isCompact
            ? HUDNode.compactLivesX + HUDNode.compactLivesWidth
            : HUDNode.livesX + CGFloat(HUDNode.maxLives - 1) * HUDNode.livesStep + 9
        let navLeft = HUDNode.navLeftEdge(forSceneWidth: sceneWidth)
        let gapLeft = livesRight + HUDNode.levelGap
        let gapRight = navLeft - HUDNode.levelGap
        let gap = gapRight - gapLeft
        levelIsAbbreviated = gap < HUDNode.levelFullWidth

        place(levelLabel, "LEVEL 01", HUDNode.cyan, 11,
              max(gapLeft, (gapLeft + gapRight) / 2), 18, align: .center)
        levelLabel.verticalAlignmentMode = .center
        levelLabel.name = "levelLabel"
        // Hidden rather than overlapped where even "L 01" will not fit.
        levelLabel.isHidden = gap < HUDNode.compactLevelMinWidth

        // The gameplay HUD carries PAUSE; the title screen's copy does not,
        // because there is no game to pause or leave.
        let nav = HUDNode.makeNavButtons(includePause: HUDNode.includesPauseButton,
                                         compact: isCompact)
        nav.name = HUDNode.navName
        nav.position.x = isCompact
            ? HUDNode.navLeftEdge(forSceneWidth: sceneWidth)
            : HUDNode.navOriginX(forSceneWidth: sceneWidth)
        addChild(nav)

        // Bottom separator
        let sep = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: .zero); path.addLine(to: CGPoint(x: sceneWidth, y: 0))
        sep.path = path
        sep.strokeColor = HUDNode.cyan.withAlphaComponent(0.25); sep.lineWidth = 0.5
        addChild(sep)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// SET and INFO, in the top right corner and nowhere else — the same corner
    /// a panel's BACK returns to, so the control that gets you in and the one
    /// that gets you out are in one place.
    ///
    /// Built here rather than inline because the title screen needs the same
    /// pair and has no HUD: two hand-placed copies of a corner drift apart, and
    /// the whole point of the corner is that it does not move. Laid out in
    /// HUD-local coordinates, so the title screen offsets the container rather
    /// than repeating the numbers.
    /// So the scene can hide the pair while a full-screen panel is over it.
    static let navName = "hudNav"

    /// The right edge of the INFO button in the pair's own coordinates, and the
    /// margin the design leaves beyond it.
    ///
    /// The pair is composed at fixed x — SET at 742, INFO at 820 to 890 —
    /// against the 960-wide design canvas, which anchors it to the *left*. That
    /// was invisible while the canvas was fixed and wrong the moment it was
    /// not: on a narrow scene the INFO button ran off the edge and the log
    /// sidebar's toggle sat on top of it; on a wide one the pair would have
    /// been stranded in the middle. Anchoring to the right keeps it in the
    /// corner at any width, and reproduces the design exactly at 960.
    static let navDesignRight: CGFloat = 890
    static let navRightMargin: CGFloat = 70

    /// SET's left edge in the pair's own coordinates.
    static let navDesignLeft: CGFloat = 742
    /// Where the nav cluster starts once PAUSE is in front of SET. The LEVEL
    /// readout measures its gap against this, or it would run underneath.
    static let navDesignLeftWithPause: CGFloat = 664
    static let pauseButtonName = "pauseButton"

    /// PAUSE only where there is no Escape key to press.
    static var includesPauseButton: Bool {
        #if os(macOS)
        false
        #else
        true
        #endif
    }

    // The left block runs SCORE · HI · lives · LEVEL, in that order, tight
    // against the left edge. Only LEVEL has any give in it: everything to its
    // left is a fixed width, and the nav owns the right edge, so LEVEL takes
    // whatever is between and shortens itself when that is not enough.
    static let hiX: CGFloat = 120
    static let livesX: CGFloat = 215
    static let livesStep: CGFloat = 22
    /// Cadet gets five (`GameSettings.lives`), so five are built and the unused
    /// ones hidden. Three were built before, which silently capped the display.
    static let maxLives = 5
    /// Air either side of LEVEL.
    static let levelGap: CGFloat = 24
    /// Below this, "LEVEL 01" does not fit and it becomes "L 01".
    static let levelFullWidth: CGFloat = 100

    /// Total width of the compact cluster, buttons and gaps.
    static func compactNavWidth(includePause: Bool) -> CGFloat {
        let n = CGFloat(includePause ? 3 : 2)
        return n * compactButtonWidth + (n - 1) * compactButtonGap
    }

    /// Where the leftmost button starts on screen, in either mode. LEVEL
    /// measures its gap against this, so the two cannot disagree.
    static func navLeftEdge(forSceneWidth width: CGFloat) -> CGFloat {
        if isCompact(sceneWidth: width) {
            return width - compactNavWidth(includePause: includesPauseButton)
                 - compactNavRightMargin
        }
        return navOriginX(forSceneWidth: width)
             + (includesPauseButton ? navDesignLeftWithPause : navDesignLeft)
    }

    static func navOriginX(forSceneWidth width: CGFloat) -> CGFloat {
        width - navDesignRight - navRightMargin      // 0 at the design width
    }

    /// Hides or shows the SET / INFO pair.
    func setNavHidden(_ hidden: Bool) {
        childNode(withName: HUDNode.navName)?.isHidden = hidden
    }

    /// The label on the pause button, which doubles as the way out of a run:
    /// PAUSE while playing, QUIT once paused, as decided with Zack.
    func setPauseButtonTitle(_ title: String) {
        guard let nav = childNode(withName: HUDNode.navName) else { return }
        for case let label as SKLabelNode in nav.children
        where label.name == HUDNode.pauseButtonName {
            label.text = title
        }
    }

    static func makeNavButtons(includePause: Bool = false,
                               compact: Bool = false) -> SKNode {
        let nav = SKNode()
        if compact { return makeCompactNavButtons(includePause: includePause) }
        // `hotkey` is the index of the character that is also the keyboard
        // shortcut. Press Start 2P advances exactly one em per character, so
        // the rule under it is arithmetic rather than a measured guess.
        // PAUSE sits in front of SET, so the pair keeps the position it has
        // always had and the cluster grows leftward into space the HUD has.
        var buttons: [(String, String, CGFloat, CGFloat, Int)] =
            [("settingsButton", "SET",    CGFloat(742), CGFloat(44), 0),
             ("infoButton",     "? INFO", CGFloat(820), CGFloat(35), 2)]
        if includePause {
            buttons.insert((pauseButtonName, "PAUSE", CGFloat(664), CGFloat(35), 0), at: 0)
        }
        for (name, text, x, centre, hotkey) in buttons {
            let btn = SKShapeNode(rect: CGRect(x: x, y: 7, width: 70, height: 22), cornerRadius: 3)
            btn.fillColor = HUDNode.cyan.withAlphaComponent(0.12)
            btn.strokeColor = HUDNode.cyan; btn.lineWidth = 1; btn.name = name
            nav.addChild(btn)

            let lbl = SKLabelNode(fontNamed: HUDNode.font)
            lbl.text = text; lbl.fontSize = 8; lbl.fontColor = HUDNode.cyan
            lbl.horizontalAlignmentMode = .center; lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: x + centre, y: 18)
            lbl.name = name
            nav.addChild(lbl)

            // The rule under the hotkey letter is a promise about a key, so
            // it comes off where there is no keyboard — Zack's call, and the
            // same reasoning as the copy in `InputPrompts`. How To Play names
            // the keys for anyone who has plugged one in.
            #if os(macOS)
            let charX = x + centre - CGFloat(text.count) * 4 + CGFloat(hotkey) * 8
            let rule = SKShapeNode(rect: CGRect(x: charX + 0.5, y: 11, width: 7, height: 1))
            rule.fillColor = HUDNode.cyan
            rule.strokeColor = .clear
            rule.name = name
            nav.addChild(rule)
            #endif

            if name == "settingsButton" {
                let gear = HUDNode.gearIcon()
                gear.position = CGPoint(x: x + 17, y: 18)
                gear.name = name
                nav.addChild(gear)
            }
        }
        return nav
    }

    /// A gear, drawn rather than typed: Press Start 2P has no such glyph, and a
    /// Unicode one would fall back to a system font in the middle of a row of
    /// arcade type. A ring, a hub and eight teeth — the least that still reads
    /// as a gear at this size rather than as a sun.
    static func gearIcon(radius r: CGFloat = 4.2) -> SKShapeNode {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        path.addEllipse(in: CGRect(x: -r * 0.34, y: -r * 0.34,
                                   width: r * 0.68, height: r * 0.68))
        for tooth in 0..<8 {
            let angle = CGFloat(tooth) * .pi / 4
            path.move(to: CGPoint(x: cos(angle) * r, y: sin(angle) * r))
            path.addLine(to: CGPoint(x: cos(angle) * (r + 2.2), y: sin(angle) * (r + 2.2)))
        }
        let node = SKShapeNode(path: path)
        node.strokeColor = HUDNode.cyan
        node.lineWidth = 1.3
        node.fillColor = .clear
        return node
    }

    /// Laid out from x = 0 rather than against the design canvas, so the caller
    /// positions the whole cluster and the buttons need no absolute numbers.
    ///
    /// "? INFO" loses its question mark here: six characters at 8pt is 48, which
    /// does not fit a 50pt button with any padding left. The gear stays, because
    /// it is the one button people find by its icon rather than its word.
    private static func makeCompactNavButtons(includePause: Bool) -> SKNode {
        let nav = SKNode()
        var specs: [(String, String)] = [("settingsButton", "SET"),
                                         ("infoButton", "INFO")]
        if includePause { specs.insert((pauseButtonName, "PAUSE"), at: 0) }

        for (index, spec) in specs.enumerated() {
            let x = CGFloat(index) * (compactButtonWidth + compactButtonGap)
            let btn = SKShapeNode(rect: CGRect(x: x, y: 7,
                                               width: compactButtonWidth, height: 22),
                                  cornerRadius: 3)
            btn.fillColor = cyan.withAlphaComponent(0.12)
            btn.strokeColor = cyan; btn.lineWidth = 1; btn.name = spec.0
            nav.addChild(btn)

            let lbl = SKLabelNode(fontNamed: font)
            lbl.text = spec.1; lbl.fontSize = 8; lbl.fontColor = cyan
            lbl.horizontalAlignmentMode = .center; lbl.verticalAlignmentMode = .center
            // SET shares its button with the gear, so its text sits right of centre.
            lbl.position = CGPoint(x: x + compactButtonWidth / 2 + (spec.0 == "settingsButton" ? 6 : 0),
                                   y: 18)
            lbl.name = spec.0
            nav.addChild(lbl)

            if spec.0 == "settingsButton" {
                let gear = gearIcon()
                gear.position = CGPoint(x: x + 12, y: 18)
                gear.name = spec.0
                nav.addChild(gear)
            }
        }
        return nav
    }

    private func place(_ node: SKLabelNode, _ text: String, _ color: SKColor,
                       _ size: CGFloat, _ x: CGFloat, _ y: CGFloat,
                       align: SKLabelHorizontalAlignmentMode = .left) {
        node.fontName = HUDNode.font; node.fontSize = size
        node.fontColor = color; node.text = text
        node.horizontalAlignmentMode = align; node.verticalAlignmentMode = .baseline
        node.position = CGPoint(x: x, y: y); addChild(node)
    }

    func updateScore(_ score: Int)   { scoreValue.text  = "\(score)" }
    func updateHiScore(_ score: Int) { hiValue.text     = "\(score)" }
    /// Set at construction from the width available between the lives and the
    /// nav, so the level number never lands on either.
    private var levelIsAbbreviated = false

    func updateLevel(_ level: Int) {
        levelLabel.text = String(format: levelIsAbbreviated ? "L %02d" : "LEVEL %02d", level)
    }
    func updateLives(_ count: Int) {
        lifeShips.enumerated().forEach { $1.isHidden = $0 >= count }
        lifeCount.text = "\(max(0, count))"
    }
}
