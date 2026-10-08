import SpriteKit
#if os(macOS)
import AppKit
/// SpriteKit ships `SKColor` for exactly this reason, but no font equivalent.
private typealias PlatformFont = NSFont
#else
import UIKit
private typealias PlatformFont = UIFont
#endif

final class HowToPlayNode: SKNode {

    /// Where the "Zudio" credit in How To Play goes, and how to open it.
    ///
    /// One link for every platform. Zudio is a universal app with native Mac,
    /// iPhone and iPad builds under a single App Store record, so the store
    /// routes this to the right one by itself — a Mac opens it in the Mac App
    /// Store and gets the Mac build. Hardcoding a per-platform URL here would
    /// be second-guessing that, and would go stale the moment the listing
    /// gains a platform.
    ///
    /// The region is left out deliberately: `/app/id…` without a country code
    /// resolves to the visitor's own storefront. `/us/app/…` sends everyone to
    /// the American store.
    ///
    /// Only the *opener* is platform-specific, and it has to be — `NSWorkspace`
    /// does not exist on iOS. When GCI itself ships there, this compiles as is.
    enum MusicCredit {
        static let url = URL(string: "https://apps.apple.com/app/id6762574335")

        static func open() {
            guard let url else { return }
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }

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
    /// The panel's own composition. The scene scales and centres it, and
    /// paints its own backdrop behind — see `GameScene.layOutPanel`.
    /// The two-column composition, which is what every screen but a phone in
    /// portrait gets.
    static let designSize = CGSize(width: 960, height: 700)

    /// What this particular panel was actually built at. A phone in portrait
    /// reflows into one tall column and is nothing like 960×700, and the scene
    /// scales whatever it is handed — so the size has to travel with the node
    /// rather than being read off the type.
    private(set) var designSize: CGSize = HowToPlayNode.designSize

    /// One long column, larger type. Two 410pt columns scaled to fit a 440pt
    /// phone land at about 0.46, which renders 12pt body text at 5.6pt — too
    /// small to read and the reason this exists. Portrait has the height to
    /// spend instead, so the panel spends it.
    private let isPortrait: Bool

    /// What the scene asks on a rotation, to decide whether this node still
    /// matches the screen it is on.
    var isPortraitLayout: Bool { isPortrait }

    static func usesPortraitLayout(sceneSize: CGSize) -> Bool {
        sceneSize.height > sceneSize.width && HUDNode.isCompact(sceneWidth: sceneSize.width)
    }

    /// Wider than the phone on purpose.
    ///
    /// The panel is scaled to fit, and on a column this long it is the *height*
    /// that binds — so a narrow design does not mean narrow margins, it means a
    /// small scale and two fat black bands down the sides. At 430 the panel
    /// rendered 304pt wide inside a 440pt phone: 65pt of black each side, which
    /// is what Zack was looking at.
    ///
    /// More width means more characters to a line, which means fewer lines,
    /// which means less height to fit into, which means a bigger scale. 560 is
    /// where the two constraints meet — the panel fills the width almost
    /// exactly at the scale the height allows — and it buys a point and a half
    /// of rendered type on top of the margins it reclaims.
    private static let pw: CGFloat = 560
    private static let pm: CGFloat = 11            // side margin
    private static var pc: CGFloat { pw - pm * 2 } // content width
    private static let W: CGFloat = 960
    private static let H: CGFloat = 700
    private static let hudBase: CGFloat = H - HUDNode.height   // 664
    private static let lx: CGFloat = 50    // left column x
    private static let rx: CGFloat = 510   // right column x
    private static let lw: CGFloat = 420   // left column max text width
    private static let rw: CGFloat = 410   // right column max text width

    init(sceneSize: CGSize) {
        isPortrait = HowToPlayNode.usesPortraitLayout(sceneSize: sceneSize)
        super.init()
        if isPortrait {
            buildPortrait()
        } else {
            let w = Self.W, h = Self.H
            designSize = Self.designSize
            buildBackground(w: w, h: h)
            buildBackButton(w: w, h: h)
            buildHeader(w: w, h: h)
            buildLeftColumn()
            buildRightColumn()
            buildFooter(w: w)
        }
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
    /// Measured from the panel's *top*, not from its origin: the scene anchors
    /// this container by the panel's top edge, so a 1,200pt portrait panel has
    /// to put BACK 29pt below its own top exactly as a 700pt one does. The x is
    /// deliberately left at the wide design's 820 — the container is positioned
    /// by the scene and is not clipped to the panel, and `HUDNode.navDesignRight`
    /// is the constant both ends agree on.
    static func navRect(designHeight h: CGFloat) -> CGRect {
        CGRect(x: 820, y: h - 29, width: 70, height: 22)
    }

    /// The container holding BACK, so the scene can anchor it to the same
    /// corner the HUD's INFO button occupies rather than leaving it adrift in
    /// the middle of a centred panel.
    static let backNavName = "backNav"

    private func buildBackButton(w: CGFloat, h: CGFloat) {
        let nav = SKNode()
        nav.name = Self.backNavName
        addChild(nav)

        let rect = Self.navRect(designHeight: h)
        let btn = SKShapeNode(rect: rect, cornerRadius: 3)
        btn.fillColor   = Self.cyan.withAlphaComponent(0.18)
        btn.strokeColor = Self.cyan; btn.lineWidth = 1; btn.name = "backButton"
        nav.addChild(btn)

        let lbl = label("• BACK", 8, Self.cyan, .center)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: rect.midX, y: rect.midY)
        lbl.name = "backButton"
        nav.addChild(lbl)
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

    // MARK: - Portrait: one long column

    // Built with a cursor rather than the hardcoded y values the wide layout
    // uses, because the height is an output here, not an input: the panel is as
    // tall as its content, and the scene scales whatever that comes to. Every
    // primitive below returns what it consumed so the cursor can advance.
    //
    // Reading order is not the two-column order read down one side and then the
    // other. CONTROLS comes second, straight after the premise — on a phone it
    // is the thing you opened this screen to find.

    /// Where the cursor is, measured down from the content's top.
    private var flowY: CGFloat = 0

    private func buildPortrait() {
        let w = Self.pw, x = Self.pm, cw = Self.pc

        // Laid out downward from 0, then shifted into place once the height is
        // known. Everything the flow draws goes in here; the background, BACK
        // and the footer are drawn in panel space around it.
        let flow = SKNode()
        addChild(flow)
        flowY = 0

        flowHeader(flow, w: w)
        flowRule(flow, x: x, w: cw)

        flowHeading(flow, "THE TWIST", Self.cyan, x: x)
        flowBody(flow, "A real chess game plays out — but Black's army is also an invader fleet. It slides sideways, drops down, and fires at you. You command White's moves and a laser ship at the bottom of the screen.", x: x, w: cw)

        flowHeading(flow, "CONTROLS", Self.cyan, x: x)
        let keys = ["DRAG", "FIRE", "TAP", "KEYS"]
        let kw = keys.map(\.count).max() ?? 1
        flowChip(flow, keys[0], "Move the ship",      keyChars: kw, x: x)
        flowChip(flow, keys[1], "Hold to shoot",      keyChars: kw, x: x)
        flowChip(flow, keys[2], "Piece, then square", keyChars: kw, x: x)
        flowChip(flow, keys[3], "SPACE, ARROWS, ESC", keyChars: kw, x: x)

        flowHeading(flow, "HOW TO WIN", Self.cyan, x: x)
        flowBody(flow, "Clear the board: destroy every black piece by shooting it or capturing it in chess. Landing a shot on the black King ends the wave with a huge bonus.", x: x, w: cw)

        flowHeading(flow, "STAY ALIVE", Self.magenta, x: x)
        // Read, not written — `GameSettings.lives` gives Cadet five and Ace
        // three, exactly as the wide layout does.
        let lives = GameSettings.shared.lives
        flowBody(flow, "Guard your White King and your ship. You have \(lives) lives — lose one if a shot hits your ship or an invader reaches the bottom row.", x: x, w: cw)

        flowHeading(flow, "SCORING", Self.magenta, x: x)
        flowScoring(flow, x: x, w: cw)

        flowHeading(flow, "HISTORY", Self.magenta, x: x)
        flowBody(flow, "GCI began as a prototype in 1983 on the Apple II, written in TASC compiled BASIC. Now, with the help of Claude, you can experience a modern recharged version.", x: x, w: cw)

        flowHeading(flow, "TEST MODE", Self.cyan.withAlphaComponent(0.55), x: x)
        for line in ["HOLD THE VERSION BOX  ·  TAP TO CLEAR",
                     "POWER, RAIDER AND LEVEL BUTTONS APPEAR",
                     "LOG AND AUTO CHESS JOIN SETTINGS"] {
            flowSmall(flow, line, SKColor.white.withAlphaComponent(0.6), x: x)
        }

        flowY += 16
        flowCredit(flow, x: x)

        // The footer rule and its two lines, then the panel is as tall as all
        // of it plus a margin.
        flowY += 20
        flowRule(flow, x: x, w: cw)
        flowY += 16
        let hint = label(InputPrompts.resumeFromPanel, 11,
                         Self.cyan.withAlphaComponent(0.65), .left)
        hint.position = CGPoint(x: x, y: -flowY)
        flow.addChild(hint)
        // 18 characters and 27 at 11pt is 495pt against 538 of content, so at
        // this width the two fit on one line after all — opposite ends of it,
        // as the wide layout has always drawn them. The middle initial goes:
        // with it the pair came to 528 and read as one run-on line.
        let copyright = label("(C) 1983-2026 Zack Urlocker", 11,
                              SKColor.white.withAlphaComponent(0.75), .right)
        copyright.position = CGPoint(x: w - x, y: -flowY)
        flow.addChild(copyright)
        flowY += 11 + Self.pm

        let h = flowY
        designSize = CGSize(width: w, height: h)
        flow.position = CGPoint(x: 0, y: h)
        // The flow laid itself out downward from its own origin; now that the
        // origin is known, the link's rect moves with it. The *click* goes
        // through the named node and was always right — this is the Mac's
        // cursor rect, which is a plain rectangle and has to be told.
        linkRect.origin.y += h
        buildBackground(w: w, h: h)
        buildBackButton(w: w, h: h)
    }

    // MARK: - Portrait primitives
    //
    // Each draws at the cursor and advances it by what it used, so inserting or
    // reordering a block needs no arithmetic anywhere else.

    private static let pBody: CGFloat = 14
    private static let pHeading: CGFloat = 18

    private func flowHeader(_ flow: SKNode, w: CGFloat) {
        // Half the lead it had: with the panel's top gap also cut, the column
        // starts where the eye already is rather than below a band of nothing.
        flowY += 12
        // Half again the size — this names the screen, and at 12pt it was the
        // quietest thing on a page it is supposed to introduce.
        let sub = label("HOW TO PLAY", 18, Self.cyan.withAlphaComponent(0.65), .center)
        sub.position = CGPoint(x: w / 2, y: -flowY)
        flow.addChild(sub)
        flowY += 30
        // 20pt over 23 characters is 460pt against 538 of content.
        let title = label("GALACTIC CHESS INVADERS", 20, Self.cyan, .center)
        title.position = CGPoint(x: w / 2, y: -flowY)
        flow.addChild(title)
        flowY += 16
    }

    private func flowRule(_ flow: SKNode, x: CGFloat, w: CGFloat) {
        flowY += 10
        flow.addChild(hline(x: x, y: -flowY, w: w))
    }

    private func flowHeading(_ flow: SKNode, _ text: String, _ color: SKColor, x: CGFloat) {
        flowY += 32
        let node = label(text, Self.pHeading, color, .left)
        node.position = CGPoint(x: x, y: -flowY)
        flow.addChild(node)
        flowY += 10
    }

    /// Measured rather than predicted: the node is created, added and then
    /// asked how tall it came out, so a wrap that lands on a different number
    /// of lines than expected cannot push the rest of the column out of step.
    private func flowBody(_ flow: SKNode, _ text: String, x: CGFloat, w: CGFloat) {
        let node = SKLabelNode(fontNamed: Self.font)
        node.numberOfLines = 0
        node.preferredMaxLayoutWidth = w
        node.horizontalAlignmentMode = .left
        node.verticalAlignmentMode   = .top
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4.0
        node.attributedText = NSAttributedString(string: text, attributes: [
            .font: PlatformFont(name: Self.font, size: Self.pBody)
                ?? PlatformFont.monospacedSystemFont(ofSize: Self.pBody, weight: .regular),
            .foregroundColor: SKColor.white.withAlphaComponent(0.85),
            .paragraphStyle: style,
        ])
        flowY += 8
        node.position = CGPoint(x: x, y: -flowY)
        flow.addChild(node)
        flowY += node.frame.height
    }

    private func flowSmall(_ flow: SKNode, _ text: String, _ color: SKColor, x: CGFloat) {
        flowY += 17
        // 37 characters at 11pt is 407pt against 538 of content.
        let node = label(text, 11, color, .left)
        node.position = CGPoint(x: x, y: -flowY)
        flow.addChild(node)
    }

    private func flowChip(_ flow: SKNode, _ key: String, _ desc: String,
                          keyChars: Int, x: CGFloat) {
        let size: CGFloat = 12
        // See `chip` above for why this is a width rather than a padded string.
        let chipW = CGFloat(keyChars) * size + 14
        let chipH: CGFloat = 26
        flowY += chipH / 2 + 8
        let y = -flowY

        let box = SKShapeNode(rect: CGRect(x: 0, y: -chipH / 2, width: chipW, height: chipH),
                              cornerRadius: 3)
        box.fillColor   = Self.cyan.withAlphaComponent(0.14)
        box.strokeColor = Self.cyan.withAlphaComponent(0.65); box.lineWidth = 0.75
        box.position    = CGPoint(x: x, y: y)
        flow.addChild(box)

        let k = label(key, size, Self.cyan, .center)
        k.verticalAlignmentMode = .center
        k.position = CGPoint(x: x + chipW / 2, y: y)
        flow.addChild(k)

        let d = label(desc, size, SKColor.white.withAlphaComponent(0.88), .left)
        d.verticalAlignmentMode = .center
        d.position = CGPoint(x: x + chipW + 12, y: y)
        flow.addChild(d)
        flowY += chipH / 2
    }

    /// Three across, two rows, same as the wide layout — the grid is already
    /// the compact form of this information and does not want unstacking.
    private func flowScoring(_ flow: SKNode, x: CGFloat, w: CGFloat) {
        let items: [(String, String)] = [
            ("king", "500"), ("queen", "150"), ("rook", "75"),
            ("knight", "50"), ("bishop", "50"), ("pawn", "25"),
        ]
        let colW = w / 3
        let rowH: CGFloat = 44
        let iconH: CGFloat = 32
        flowY += 24
        let topY = -flowY
        for (i, (piece, pts)) in items.enumerated() {
            let px = x + CGFloat(i % 3) * colW
            let py = topY - CGFloat(i / 3) * rowH

            let tex = SKTexture(imageNamed: "chess-b-\(piece)")
            let ts  = tex.size()
            let sc  = ts.height > 0 ? iconH / ts.height : 1
            let node = SKSpriteNode(texture: tex,
                                    size: CGSize(width: ts.width * sc, height: iconH))
            node.position = CGPoint(x: px + 24, y: py)
            node.color = Self.magenta; node.colorBlendFactor = 0.15
            flow.addChild(node)

            let lbl = label(pts, 16, .white, .left)
            lbl.position = CGPoint(x: px + 52, y: py - 8)
            flow.addChild(lbl)
        }
        flowY += rowH + 14
    }

    /// Two lines here rather than the wide layout's one: "All music created by
    /// Zudio available on Mac, iPhone, iPad." is 58 characters, which at 12pt
    /// is 696pt against 538 of column. The link keeps its own hit target.
    private func flowCredit(_ flow: SKNode, x: CGFloat) {
        let em: CGFloat = 12
        flowY += 18
        let lead = label("All music created by ", em, .white, .left)
        lead.position = CGPoint(x: x, y: -flowY)
        flow.addChild(lead)

        let linkX = x + 21 * em
        let linkW = 5 * em
        let link = label("Zudio", em, Self.cyan.withAlphaComponent(0.9), .left)
        link.position = CGPoint(x: linkX, y: -flowY)
        flow.addChild(link)

        let underline = SKShapeNode(rect: CGRect(x: linkX, y: -flowY - 3,
                                                 width: linkW, height: 0.9))
        underline.fillColor = Self.cyan.withAlphaComponent(0.9)
        underline.strokeColor = .clear
        flow.addChild(underline)

        // Held in the node's own space and converted once the flow is placed,
        // so the hit target cannot drift from the word it covers.
        linkRect = CGRect(x: linkX - 6, y: -flowY - 8, width: linkW + 12, height: 24)
        let hit = SKShapeNode(rect: linkRect)
        hit.fillColor = .clear; hit.strokeColor = .clear
        hit.name = Self.musicLinkName
        flow.addChild(hit)

        flowY += 18
        let tail = label("available on Mac, iPhone, iPad.", em, .white, .left)
        tail.position = CGPoint(x: x, y: -flowY)
        flow.addChild(tail)
    }

    // MARK: - Left column

    private func buildLeftColumn() {
        let x = Self.lx
        // — THE TWIST —
        heading("THE TWIST", Self.cyan, x: x, y: 562)
        multiline("A real chess game plays out — but Black's army is also an invader fleet. It slides sideways, drops down, and fires at you. You command White's moves and a laser ship at the bottom of the screen.",
                  size: 12, maxW: Self.lw, x: x, y: 548)

        // — CONTROLS —
        //
        // The keys are listed on iOS too, and deliberately. A hardware
        // keyboard drives every one of them there — see `KeyboardInputAdapter`
        // — and this screen is where someone who has plugged one in will look
        // for them. The prompts elsewhere stay simple and say "tap"; this is
        // the one place that carries the detail.
        heading("CONTROLS", Self.cyan, x: x, y: 408)
        #if os(macOS)
        let keys = ["← →", "SPACE", "CLICK", "ESC"]
        let kw = keys.map(\.count).max() ?? 1
        chip(keys[0], "Arrows or A / D move the ship", keyChars: kw, x: x, y: 388)
        chip(keys[1], "Fire laser",                    keyChars: kw, x: x, y: 344)
        chip(keys[2], "Pick piece, then new square",   keyChars: kw, x: x, y: 300)
        // Two keys on one row: a fifth chip would run into the HISTORY heading
        // below, and 25 characters at 12pt still clears the column.
        chip(keys[3], "Pause  ·  Q quits  ·  M mutes", keyChars: kw, x: x, y: 256)
        #else
        // Touch first. This list used to lead with arrows and SPACE, which
        // named a keyboard an iPad may not have while leaving the two
        // controls it definitely does have — the drag and the FIRE button —
        // unmentioned.
        //
        // The keyboard line is down to the three keys that do something no
        // on-screen control does. Q, M, S and I all have buttons now: PAUSE
        // twice quits, mute is a Settings row, and SET and INFO are in the
        // HUD — so listing them named a second way to do things the player
        // can already see.
        let keys = ["DRAG", "FIRE", "TAP", "KEYS"]
        let kw = keys.map(\.count).max() ?? 1      // TAP is the short one
        chip(keys[0], "Move the ship left or right",  keyChars: kw, x: x, y: 388)
        chip(keys[1], "Hold the button to shoot",     keyChars: kw, x: x, y: 344)
        chip(keys[2], "Pick piece, then new square",  keyChars: kw, x: x, y: 300)
        chip(keys[3], "Optional: SPACE, ARROWS, ESC", keyChars: kw, x: x, y: 256)
        #endif

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
        // Read, not written: `GameSettings.lives` gives Cadet five and Ace
        // three, and this said "3" flatly — wrong on Cadet, which is both the
        // default for a fresh install and where a stale 1.0 "pilot" setting
        // lands. The HUD has always drawn the real number; this screen was the
        // only place claiming otherwise.
        let lives = GameSettings.shared.lives
        multiline("Guard your White King and your ship. You have \(lives) lives — lose one if a shot hits your ship or an invader reaches the bottom row.",
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
        #if os(macOS)
        // 4pt above the pixel caps' baseline: the two fonts do not share one,
        // and the system glyph sat low against them.
        addChild(commandGlyph(size: testEm, color: testDim,
                              at: CGPoint(x: x + 11 * testEm, y: 155 + 4)))
        let testKey = label("T", testEm, testDim, .left)
        testKey.position = CGPoint(x: x + 12 * testEm, y: 155)
        addChild(testKey)
        #endif
        // Two short lines rather than one long one — five key/label pairs on a
        // single row runs the width of the column and reads as a wall. A, P, R
        // and V do nothing until Command-T arms them; L works either way.
        //
        // Press Start 2P advances exactly one em per character, so the padding
        // after "Log" is counted rather than eyeballed: it puts `A` and `V` on
        // the same column, 16 characters in on both lines.
        // iOS says something else entirely, because none of the above is true
        // there: an iPad has no ⌘T, and P, R and V are the POWER, RAID and
        // LEVEL chips. L and A are not buttons at all — Settings already
        // carries both — so the honest instruction is where to look rather
        // than which key to press.
        let testBody = SKColor.white.withAlphaComponent(0.6)
        let bodyEm: CGFloat = 10
        // Three lines is the ceiling: they run 137, 120, 103 and the music
        // credit sits at 83.
        #if os(macOS)
        // The Mac block listed five keys and nothing else, which was true
        // until the badge shipped here. The first line is the other door, and
        // it leans on the ⌘T already in the heading rather than repeating it —
        // printing the shortcut twice on one block read as sloppy.
        //
        // "Click and hold" rather than "long press": that is the Mac's own
        // phrasing for holding the pointer down, the gesture that opens a Dock
        // menu. "Long press" is an iOS API term and means nothing here.
        //
        // The keys are grouped the way the controls actually divide, not four
        // per row: `L` and `A` are persistent toggles that Settings also
        // carries, and `P`, `R` and `V` are the three chips. The third line
        // reads in the same order as the chip row beside the board.
        let testLines = ["Or click and hold the Version Box",
                         "L  Log  ·  A  Auto",
                         "P  PowerUp  ·  R  Raider  ·  V  Level"]
        #else
        let testLines = ["HOLD THE VERSION BOX  ·  TAP TO CLEAR",
                         "POWER, RAIDER AND LEVEL BUTTONS APPEAR",
                         "LOG AND AUTO CHESS JOIN SETTINGS"]
        #endif
        for (i, line) in testLines.enumerated() {
            // 10pt, not 11: at 11 the longer line is 440pt against a 410pt
            // column and runs off the panel.
            let keys = label(line, bodyEm, testBody, .left)
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
        let hint = label(InputPrompts.resumeFromPanel, 10, Self.cyan.withAlphaComponent(0.65), .left)
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
            .font: PlatformFont(name: Self.font, size: size)
                ?? PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular),
            .foregroundColor: SKColor.white.withAlphaComponent(0.85),
            .paragraphStyle: style
        ]
        node.attributedText = NSAttributedString(string: text, attributes: attrs)
        addChild(node)
    }

    /// Every chip in a block is the width of the longest key in it, so the
    /// descriptions start on one column instead of stepping in and out with the
    /// length of the word beside them. Zack's note, and it is the difference
    /// between a list and four loose rows.
    ///
    /// Sized rather than padded: a trailing space in an `SKLabelNode` does not
    /// advance the glyph, so " TAP " would have widened the box without moving
    /// the word inside it. The key is centred in whatever width it is given.
    private func chip(_ key: String, _ desc: String, keyChars: Int,
                      x: CGFloat, y: CGFloat) {
        let chipW = CGFloat(keyChars) * 10 + 18
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
