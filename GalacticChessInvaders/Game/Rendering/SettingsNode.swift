// SettingsNode.swift
// The settings screen (§20 Phase 5).
//
// §20 asks for a SwiftUI `SettingsView`. This is a SpriteKit node instead, for
// the same reason How To Play is: every other full-screen panel in the game is
// one, and a SwiftUI sheet would arrive in system chrome in the middle of a
// neon arcade cabinet. The persistence §20 actually cares about lives in
// `GameSettings`, which is plain Swift either way.
//
// Layout is hardcoded against the 960x700 scene, matching `HowToPlayNode`.

import SpriteKit

@MainActor
final class SettingsNode: SKNode {

    private static let cyan    = NeonPalette.cyan
    private static let magenta = NeonPalette.magenta
    private static let font    = "PressStart2P-Regular"

    /// The panel's own composition. The scene scales and centres it, and
    /// paints its own backdrop behind — see `GameScene.layOutPanel`.
    static let designSize = CGSize(width: 960, height: 700)

    /// What this panel was actually built at — see `HowToPlayNode.designSize`
    /// for why the scene reads it off the node rather than off the type.
    private(set) var designSize: CGSize = SettingsNode.designSize

    /// One long column of full-size rows, for the same reason How To Play has
    /// one: two 410pt columns on a 440pt phone scale to about 0.46, and a
    /// settings row whose label renders at 5pt is not a settings row.
    private let isPortrait: Bool
    var isPortraitLayout: Bool { isPortrait }

    private static let pw: CGFloat = 430
    private static let pm: CGFloat = 22
    private static var pc: CGFloat { pw - pm * 2 }

    /// Where the portrait cursor is, measured down from the content's top.
    private var flowY: CGFloat = 0
    private static let W: CGFloat = 960
    private static let H: CGFloat = 700
    private static let hudBase: CGFloat = H - HUDNode.height   // 664
    private static let lx: CGFloat = 50    // left column x
    private static let rx: CGFloat = 510   // right column x
    private static let lw: CGFloat = 420   // left column width
    private static let rw: CGFloat = 410   // right column width

    /// Fires when a value changed, so the scene can apply the ones that show up
    /// immediately — the glow, the grid, the volumes.
    var onChange: (() -> Void)?

    /// Fires after every `rebuild`, which is every click on a control.
    ///
    /// A rebuild empties `content` and draws a *new* BACK button, and BACK is
    /// the one control the scene positions rather than this node — so without
    /// this, the first tap on any setting left the fresh button wherever it was
    /// drawn. The wide layout survived that because its drawn position is
    /// already the right one; the portrait panel is 430pt wide and BACK is
    /// drawn at x=820, so it simply vanished.
    var onRebuild: (() -> Void)?

    // MARK: - Hit targets
    //
    // Built during layout rather than looked up by node name. A settings screen
    // is a dozen small rectangles with a value behind each; carrying the rect
    // and the effect together is less to keep in step than a naming scheme the
    // scene would have to parse.

    private struct Hit {
        /// `var` so the portrait flow can shift a whole screen of them at once
        /// when it finds out how tall it came out — see `buildPortrait`.
        var rect: CGRect
        let isSlider: Bool
        /// Buttons push in when clicked; a toggle or a segment already shows
        /// what it did by lighting up in its new state. `parts` are the nodes
        /// that travel together for that push.
        var parts: [SKNode] = []
        var sound: SoundKey = .uiSettingsBlip
        /// Point is in this node's coordinates. Sliders read its x; everything
        /// else ignores it.
        let apply: (CGPoint) -> Void
    }

    private var hits: [Hit] = []
    private var dragging: Hit?
    /// Rebuilt wholesale on every change. A few dozen nodes, only on a click —
    /// far cheaper than the class of bug where one control's visual and its
    /// stored value drift apart.
    private let content = SKNode()

    private var settings: GameSettings { GameSettings.shared }

    /// Whether the LOG PANEL row is offered. True only in Test Mode.
    private let showsLogRow: Bool

    /// `forcePortrait`: see `HowToPlayNode.init`.
    init(showsLogRow: Bool = false, sceneSize: CGSize = SettingsNode.designSize,
         forcePortrait: Bool = false) {
        self.showsLogRow = showsLogRow
        isPortrait = forcePortrait
            || HowToPlayNode.usesPortraitLayout(sceneSize: sceneSize)
        super.init()
        addChild(content)
        rebuild()
        // After `rebuild`, because in portrait the panel is as tall as whatever
        // the rows came to and the background has to match.
        buildBackground()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Input

    /// Returns true when the click landed on a control, so the scene knows
    /// whether it still has to consider BACK or a dismissal.
    @discardableResult
    func handleClick(at point: CGPoint) -> Bool {
        guard let hit = hits.first(where: { $0.rect.contains(point) }) else { return false }
        dragging = hit.isSlider ? hit : nil
        hit.apply(point)
        AudioManager.shared.play(hit.sound)
        guard !hit.parts.isEmpty else {
            rebuild()
            onChange?()
            return true
        }
        // Two points down and back, then the redraw. Deferred because `rebuild`
        // empties `content` on the very click that asks for the push, and timed
        // rather than animated because the settings panel runs with the scene
        // paused, where SKActions do not advance at all.
        for part in hit.parts { part.position.y -= 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            self?.rebuild()
            self?.onChange?()
        }
        return true
    }

    /// Sliders keep tracking while the button is down, including past the ends
    /// of the bar — releasing outside a control should not snap the value back.
    func handleDrag(at point: CGPoint) {
        guard let hit = dragging else { return }
        hit.apply(point)
        rebuild()
        onChange?()
    }

    /// Redraw from the stored settings. Needed when something outside the
    /// panel changes one — the sidebar's own chevron is the case that exists.
    func refresh() { rebuild() }

    func endDrag() {
        // Dragging is silent while it runs — a click per pixel would be
        // unbearable — but landing plays one note. On the two volume sliders
        // that note is the only way to hear what you just set, since `play`
        // reads the level at play time rather than at preload.
        guard dragging != nil else { return }
        dragging = nil
        AudioManager.shared.play(.uiSettingsBlip)
    }

    // MARK: - Layout

    private func buildBackground() {
        let bg = SKShapeNode(rect: CGRect(origin: .zero, size: designSize))
        bg.fillColor = SKColor(white: 0, alpha: 0.97)
        bg.strokeColor = .clear
        bg.zPosition = -1
        addChild(bg)
    }

    // MARK: - The controls, declared once
    //
    // Two compositions draw this screen — two columns on a Mac or an iPad, one
    // long column on a phone in portrait — and each used to restate every row:
    // its label, its value, its setter and the grey line under it, fourteen
    // times over. Adding a setting meant two edits, and nothing made them agree.
    //
    // Only the *geometry* is per-layout now. Each builder below says where a row
    // goes; what the row is lives here.

    private enum ControlID {
        case difficulty, chess, chessHints
        case music, musicVolume, soundFX, soundVolume
        case neonGlow, boardGrid, nebula, logPanel
        case shipSpeed, highScores, allSettings
    }

    private struct Control {
        enum Kind {
            case segment(options: [String], selected: Int, set: (Int) -> Void)
            case toggle(value: Bool, set: (Bool) -> Void)
            case slider(fraction: CGFloat, readout: String, dimmed: Bool,
                        defaultMark: CGFloat, set: (CGFloat) -> Void)
            case button(title: String, tint: SKColor, action: () -> Void)
        }
        let label: String
        let kind: Kind
        /// The grey line under the row, where there is one.
        let explain: String?
    }

    private func control(_ id: ControlID) -> Control {
        // Both audio sliders are shown as a fraction of `audioMax`, so the
        // shipped level reads as 75% with room above it.
        let top = CGFloat(GameSettings.audioMax)
        let shipped = 1.0 / top

        switch id {
        case .difficulty:
            return Control(label: "DIFFICULTY",
                           kind: .segment(options: ["CADET", "ACE"],
                                          selected: settings.difficulty == .cadet ? 0 : 1) { index in
                               self.settings.difficulty = index == 0 ? .cadet : .ace
                           },
                           explain: "SELECT CADET FOR AN EASIER ON RAMP.")

        case .chess:
            return Control(label: "CHESS",
                           kind: .segment(options: ["YOU PLAY", "AUTO"],
                                          selected: settings.autoChess ? 1 : 0) { index in
                               self.settings.autoChess = index == 1
                           },
                           explain: "AUTOMATIC FAST CHESS PLAY FOR WHITE.")

        case .chessHints:
            return Control(label: "CHESS HINTS",
                           kind: .toggle(value: settings.chessHints) {
                               // Throwing the switch is what claims it from
                               // difficulty. Set first, so the assignment below
                               // does not look like difficulty's doing.
                               self.settings.chessHintsUserSet = true
                               self.settings.chessHints = $0
                           },
                           explain: "PULSE THE BEST PIECES TO MOVE")

        case .music:
            return Control(label: "MUSIC",
                           kind: .toggle(value: settings.musicOn) { self.settings.musicOn = $0 },
                           explain: nil)

        case .musicVolume:
            let fraction = CGFloat(settings.musicVolume) / top
            return Control(label: "VOLUME",
                           kind: .slider(fraction: fraction, readout: percent(fraction),
                                         dimmed: !settings.musicOn, defaultMark: shipped) {
                               self.settings.musicVolume = Float($0 * top)
                           },
                           explain: nil)

        case .soundFX:
            return Control(label: "SOUND FX",
                           kind: .toggle(value: settings.soundOn) { self.settings.soundOn = $0 },
                           explain: nil)

        case .soundVolume:
            let fraction = CGFloat(settings.soundVolume) / top
            return Control(label: "VOLUME",
                           kind: .slider(fraction: fraction, readout: percent(fraction),
                                         dimmed: !settings.soundOn, defaultMark: shipped) {
                               self.settings.soundVolume = Float($0 * top)
                           },
                           explain: nil)

        case .neonGlow:
            #if os(macOS)
            let why = "TURN OFF ON A SLOWER MAC"
            #else
            let why = "TURN OFF ON A SLOWER DEVICE"
            #endif
            return Control(label: "NEON GLOW",
                           kind: .toggle(value: settings.neonGlow) { self.settings.neonGlow = $0 },
                           explain: why)

        case .boardGrid:
            return Control(label: "BOARD GRID",
                           kind: .slider(fraction: settings.boardGrid,
                                         readout: percent(settings.boardGrid),
                                         dimmed: false, defaultMark: 0.5) {
                               self.settings.boardGrid = $0
                           },
                           explain: "0% OPEN SPACE · 100% ROWS AND COLS")

        case .nebula:
            return Control(label: "NEBULA",
                           kind: .toggle(value: settings.nebula) { self.settings.nebula = $0 },
                           explain: "COLORED HAZE IN LATER LEVELS")

        case .logPanel:
            #if os(macOS)
            let why = "SAME AS THE L KEY"
            #else
            let why = "LANDSCAPE ONLY · ALSO THE L KEY"
            #endif
            return Control(label: "LOG PANEL",
                           kind: .toggle(value: settings.logPanel) { self.settings.logPanel = $0 },
                           explain: why)

        case .shipSpeed:
            let range = GameSettings.shipSpeedRange
            let span = range.upperBound - range.lowerBound
            return Control(label: "SHIP SPEED",
                           kind: .slider(fraction: (settings.shipSpeedScale - range.lowerBound) / span,
                                         readout: percent(settings.shipSpeedScale),
                                         dimmed: false, defaultMark: 0.5) { fraction in
                               self.settings.shipSpeedScale = range.lowerBound + fraction * span
                           },
                           explain: "DEFAULT IS PLAYTESTED")

        case .highScores:
            return Control(label: "HIGH SCORES",
                           kind: .button(title: "RESET", tint: Self.magenta) {
                               ScoreManager.shared.clearHighScores()
                           },
                           explain: "BACK TO ORIGINAL SCORES")

        case .allSettings:
            return Control(label: "ALL SETTINGS",
                           kind: .button(title: "RESTORE", tint: Self.cyan) {
                               self.settings.restoreDefaults()
                           },
                           explain: nil)
        }
    }

    /// Draws one control at the position the caller chose.
    private func place(_ id: ControlID, x: CGFloat, w: CGFloat, y: CGFloat) {
        let c = control(id)
        switch c.kind {
        case let .segment(options, selected, set):
            segmentRow(c.label, x: x, w: w, y: y, options: options, selected: selected, set: set)
        case let .toggle(value, set):
            toggleRow(c.label, x: x, w: w, y: y, value: value, set: set)
        case let .slider(fraction, readout, dimmed, defaultMark, set):
            sliderRow(c.label, x: x, w: w, y: y, fraction: fraction, readout: readout,
                      dimmed: dimmed, defaultMark: defaultMark, set: set)
        case let .button(title, tint, action):
            buttonRow(c.label, title, x: x, w: w, y: y, tint: tint, run: action)
        }
    }

    /// The grey line under a control, where the caller wants one drawn.
    private func explain(_ id: ControlID, x: CGFloat, y: CGFloat) {
        guard let text = control(id).explain else { return }
        explain(text, x: x, y: y)
    }

    private func rebuild() {
        content.removeAllChildren()
        hits.removeAll()
        guard !isPortrait else { buildPortrait(); onRebuild?(); return }
        buildHeader()
        buildLeftColumn()
        buildRightColumn()
        buildFooter()
        onRebuild?()
    }

    // MARK: - Portrait: one long column
    //
    // Every row builder already takes `x:`, `w:` and `y:`, so this is the same
    // controls in the same order driven by a cursor instead of by hand-written
    // y values. Nothing about a row's behaviour changes — the hit rects are
    // built from the same geometry, so the controls stay live.

    private func buildPortrait() {
        let x = Self.pm, w = Self.pc
        flowY = 0

        // Same treatment as How To Play's: less lead, and a panel name big
        // enough to read as one.
        flowY += 12
        let sub = label("SETTINGS", 14, Self.cyan.withAlphaComponent(0.65), .center)
        sub.position = CGPoint(x: Self.pw / 2, y: -flowY)
        content.addChild(sub)
        flowY += 28
        // 17, which is the ceiling: 23 characters at 18 is 414pt against 408 of
        // content, and at 19 the title visibly ran off both edges of the panel.
        // The panel name above it carries the increase instead.
        let title = label("GALACTIC CHESS INVADERS", 17, Self.cyan, .center)
        title.position = CGPoint(x: Self.pw / 2, y: -flowY)
        content.addChild(title)
        flowY += 14
        content.addChild(hline(x: x, y: -flowY, w: w))

        // The same order as the two-column layout read in, down one column.
        flowHeading("GAMEPLAY", Self.magenta, x: x)
        flowControl(.difficulty, x: x, w: w)
        flowControl(.chess, x: x, w: w)
        flowControl(.chessHints, x: x, w: w)

        flowHeading("AUDIO", Self.cyan, x: x)
        flowControl(.music, x: x, w: w)
        flowControl(.musicVolume, x: x, w: w)
        flowControl(.soundFX, x: x, w: w)
        flowControl(.soundVolume, x: x, w: w)

        flowHeading("DISPLAY", Self.cyan, x: x)
        flowControl(.neonGlow, x: x, w: w)
        flowControl(.boardGrid, x: x, w: w)
        flowControl(.nebula, x: x, w: w)
        if showsLogRow { flowControl(.logPanel, x: x, w: w) }

        flowHeading("CONTROLS", Self.cyan, x: x)
        flowControl(.shipSpeed, x: x, w: w)

        flowHeading("DATA", Self.magenta, x: x)
        flowControl(.highScores, x: x, w: w)
        flowControl(.allSettings, x: x, w: w)

        flowY += 26
        content.addChild(hline(x: x, y: -flowY, w: w))
        flowY += 18
        let hint = label(InputPrompts.resumeFromPanel, 9,
                         Self.cyan.withAlphaComponent(0.65), .left)
        hint.position = CGPoint(x: x, y: -flowY)
        content.addChild(hint)
        let saved = label("SAVED AUTOMATICALLY", 9,
                          Self.cyan.withAlphaComponent(0.65), .right)
        saved.position = CGPoint(x: Self.pw - x, y: -flowY)
        content.addChild(saved)
        flowY += 9 + Self.pm

        let h = flowY
        designSize = CGSize(width: Self.pw, height: h)

        // The flow laid itself out downward from zero because it could not know
        // its own height until it finished. Now it does, so everything it drew
        // moves up into the panel — the drawing *and* the hit rects, which were
        // built from the same y values and have to keep matching them.
        //
        // Moving `content` instead would have been one line, and wrong: the
        // scene anchors BACK by setting the position of whatever node carries
        // `backNavName`, and that arithmetic assumes the node's parent sits at
        // the panel's origin. Offsetting `content` silently cost the panel its
        // BACK button.
        for child in content.children { child.position.y += h }
        hits = hits.map { var hit = $0; hit.rect.origin.y += h; return hit }

        // After the shift, so it lands where it is put rather than being moved
        // with the rows.
        buildPortraitBackButton()
    }

    /// One control and its explanatory line, placed at the cursor.
    private func flowControl(_ id: ControlID, x: CGFloat, w: CGFloat) {
        flowY += 20
        place(id, x: x, w: w, y: -flowY)
        flowY += 12
        if control(id).explain != nil {
            flowY += 18
            explain(id, x: x, y: -flowY)
        }
    }

    private func flowHeading(_ text: String, _ color: SKColor, x: CGFloat) {
        flowY += 32
        heading(text, color, x: x, y: -flowY)
    }

    private func buildPortraitBackButton() {
        let rect = HowToPlayNode.navRect(designHeight: designSize.height)
        let nav = SKNode()
        nav.name = HowToPlayNode.backNavName
        content.addChild(nav)

        let box = SKShapeNode(rect: rect, cornerRadius: 3)
        box.fillColor   = Self.cyan.withAlphaComponent(0.18)
        box.strokeColor = Self.cyan
        box.lineWidth   = 1
        box.name        = "backButton"
        nav.addChild(box)

        let lbl = label("• BACK", 8, Self.cyan, .center)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: rect.midX, y: rect.midY)
        lbl.name = "backButton"
        nav.addChild(lbl)
    }

    private func buildHeader() {
        let hud = Self.hudBase
        // Panel name small and first, game name large underneath — the same
        // order as How To Play.
        let sub = label("SETTINGS", 14, Self.cyan.withAlphaComponent(0.65), .center)
        sub.position = CGPoint(x: Self.W / 2, y: hud - 20)
        content.addChild(sub)

        let title = label("GALACTIC CHESS INVADERS", 30, Self.cyan, .center)
        title.position = CGPoint(x: Self.W / 2, y: hud - 62)
        content.addChild(title)

        content.addChild(hline(x: 40, y: hud - 84, w: Self.W - 80))
    }

    private func buildLeftColumn() {
        let x = Self.lx, w = Self.lw

        // Gameplay leads. Difficulty is the most consequential control on the
        // screen, and it used to sit underneath two volume sliders.
        heading("GAMEPLAY", Self.magenta, x: x, y: 540)
        place(.difficulty, x: x, w: w, y: 512);   explain(.difficulty, x: x, y: 488)
        place(.chess, x: x, w: w, y: 456);        explain(.chess, x: x, y: 432)
        place(.chessHints, x: x, w: w, y: 400);   explain(.chessHints, x: x, y: 376)

        heading("AUDIO", Self.cyan, x: x, y: 340)
        place(.music, x: x, w: w, y: 312)
        place(.musicVolume, x: x, w: w, y: 280)
        place(.soundFX, x: x, w: w, y: 244)
        place(.soundVolume, x: x, w: w, y: 212)
    }

    private func buildRightColumn() {
        let x = Self.rx, w = Self.rw

        heading("DISPLAY", Self.cyan, x: x, y: 540)
        place(.neonGlow, x: x, w: w, y: 512);  explain(.neonGlow, x: x, y: 490)
        place(.boardGrid, x: x, w: w, y: 460); explain(.boardGrid, x: x, y: 435)
        place(.nebula, x: x, w: w, y: 408);    explain(.nebula, x: x, y: 386)

        // Only inside Test Mode — see `GameScene.toggleDiagnostics`. The row
        // is omitted rather than dimmed, because a disabled switch invites the
        // question "how do I enable this?" for a control nobody outside
        // testing wants.
        if showsLogRow {
            place(.logPanel, x: x, w: w, y: 358); explain(.logPanel, x: x, y: 336)
        }

        // The right column closes up when the LOG PANEL row is absent, so Test
        // Mode does not leave a hole in the middle of Display.
        let drop: CGFloat = showsLogRow ? 0 : 52

        heading("CONTROLS", Self.cyan, x: x, y: 305 + drop)
        place(.shipSpeed, x: x, w: w, y: 277 + drop)
        explain(.shipSpeed, x: x, y: 252 + drop)

        heading("DATA", Self.magenta, x: x, y: 199 + drop)
        place(.highScores, x: x, w: w, y: 171 + drop)
        explain(.highScores, x: x, y: 149 + drop)
        place(.allSettings, x: x, w: w, y: 121 + drop)
    }

    private func buildFooter() {
        // Above the rule, opposite SAVED AUTOMATICALLY. On the Mac this is the
        // screen someone opens to look the app over, so it is where the build
        // number belongs.
        //
        // Not on iOS: `VersionBadgeNode` carries it on the play screen there,
        // where it is also the way into Test Mode. Printing it twice made the
        // Settings copy the stale-looking one — it is the only place a tester
        // could read the build without being able to press it.
        // No version line here on either platform. It moved to the badge on
        // the play screen when iOS got one, and the Mac followed: a build
        // number two panels deep is the wrong place for the thing a bug
        // report needs, and the badge is on screen the whole time.

        content.addChild(hline(x: 40, y: 70, w: Self.W - 80))

        // Top right, in the same box the HUD's SETTINGS button occupies.
        let rect = HowToPlayNode.navRect(designHeight: Self.H)
        let nav = SKNode()
        nav.name = HowToPlayNode.backNavName
        content.addChild(nav)

        let box = SKShapeNode(rect: rect, cornerRadius: 3)
        box.fillColor   = Self.cyan.withAlphaComponent(0.18)
        box.strokeColor = Self.cyan
        box.lineWidth   = 1
        box.name        = "backButton"
        nav.addChild(box)

        let lbl = label("• BACK", 8, Self.cyan, .center)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: rect.midX, y: rect.midY)
        lbl.name = "backButton"
        nav.addChild(lbl)

        let hint = label(InputPrompts.resumeFromPanel, 10,
                         Self.cyan.withAlphaComponent(0.65), .left)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: Self.lx, y: 39)
        content.addChild(hint)

        let saved = label("SAVED AUTOMATICALLY", 10, Self.cyan.withAlphaComponent(0.40), .right)
        saved.verticalAlignmentMode = .center
        saved.position = CGPoint(x: Self.W - Self.lx, y: 39)
        content.addChild(saved)
    }

    // MARK: - Controls

    private func toggleRow(_ text: String, x: CGFloat, w: CGFloat, y: CGFloat,
                           value: Bool, set: @escaping (Bool) -> Void) {
        rowLabel(text, x: x, y: y)

        // Sized to the wider word so the pair reads as one switch, and pinned to
        // the column's right edge so every toggle on the screen lines up.
        let cell: CGFloat = 40, h: CGFloat = 22
        let right = x + w
        for (index, option) in ["ON", "OFF"].enumerated() {
            let on = (option == "ON") == value
            let cx = right - cell * CGFloat(2 - index)
            let rect = CGRect(x: cx, y: y - h / 2, width: cell, height: h)

            let box = SKShapeNode(rect: rect)
            box.fillColor   = on ? Self.cyan : .clear
            box.strokeColor = Self.cyan.withAlphaComponent(on ? 1 : 0.38)
            box.lineWidth   = 1
            content.addChild(box)

            let lbl = label(option, 8, on ? SKColor.black : Self.cyan.withAlphaComponent(0.55), .center)
            lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: rect.midX, y: rect.midY)
            content.addChild(lbl)

            let wants = (option == "ON")
            hits.append(Hit(rect: rect, isSlider: false) { _ in set(wants) })
        }
    }

    private func segmentRow(_ text: String, x: CGFloat, w: CGFloat, y: CGFloat,
                            options: [String], selected: Int,
                            set: @escaping (Int) -> Void) {
        rowLabel(text, x: x, y: y)

        // Press Start 2P advances exactly one em per character, so a cell can be
        // sized from the string rather than measured off a node.
        let h: CGFloat = 22, pad: CGFloat = 14
        let widths = options.map { CGFloat($0.count) * 8 + pad * 2 }
        var cx = x + w - widths.reduce(0, +)

        for (index, option) in options.enumerated() {
            let on = index == selected
            let rect = CGRect(x: cx, y: y - h / 2, width: widths[index], height: h)

            let box = SKShapeNode(rect: rect)
            box.fillColor   = on ? Self.cyan : .clear
            box.strokeColor = Self.cyan.withAlphaComponent(on ? 1 : 0.38)
            box.lineWidth   = 1
            content.addChild(box)

            let lbl = label(option, 8, on ? SKColor.black : Self.cyan.withAlphaComponent(0.55), .center)
            lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: rect.midX, y: rect.midY)
            content.addChild(lbl)

            hits.append(Hit(rect: rect, isSlider: false) { _ in set(index) })
            cx += widths[index]
        }
    }

    /// `defaultMark` is where this slider shipped, as a fraction of the bar. A
    /// tick under the track means the player can always find their way back to
    /// the tuned value by eye, without a reset button or a remembered number.
    private func sliderRow(_ text: String, x: CGFloat, w: CGFloat, y: CGFloat,
                           fraction: CGFloat, readout: String, dimmed: Bool,
                           defaultMark: CGFloat,
                           set: @escaping (CGFloat) -> Void) {
        rowLabel(text, x: x, y: y, dimmed: dimmed)

        let barW: CGFloat = 150, barH: CGFloat = 8, gap: CGFloat = 12
        let pctW: CGFloat = 40
        let barX = x + w - pctW - gap - barW
        let value = min(max(fraction, 0), 1)
        let live = Self.cyan.withAlphaComponent(dimmed ? 0.22 : 1)

        let track = SKShapeNode(rect: CGRect(x: barX, y: y - barH / 2, width: barW, height: barH))
        track.fillColor   = Self.cyan.withAlphaComponent(0.10)
        track.strokeColor = Self.cyan.withAlphaComponent(dimmed ? 0.14 : 0.30)
        track.lineWidth   = 1
        content.addChild(track)

        if value > 0 {
            let fill = SKShapeNode(rect: CGRect(x: barX, y: y - barH / 2,
                                                width: barW * value, height: barH))
            fill.fillColor   = Self.cyan.withAlphaComponent(dimmed ? 0.16 : 0.42)
            fill.strokeColor = .clear
            content.addChild(fill)
        }

        // A tick above and below, framing the track. Both sit outside the
        // knob's 8x16 footprint, or the mark would vanish at exactly the value
        // it marks — where the knob rests by default, and where it matters
        // most.
        for top in [y + 8, y - 15] {
            let notch = SKShapeNode(rect: CGRect(x: barX + barW * defaultMark - 1.5, y: top,
                                                 width: 3, height: 7))
            notch.fillColor   = Self.cyan.withAlphaComponent(dimmed ? 0.30 : 0.85)
            notch.strokeColor = .clear
            content.addChild(notch)
        }

        let knob = SKShapeNode(rect: CGRect(x: barX + barW * value - 4, y: y - 8,
                                            width: 8, height: 16))
        knob.fillColor   = live
        knob.strokeColor = .clear
        content.addChild(knob)

        let pct = label(readout, 8, live, .right)
        pct.verticalAlignmentMode = .center
        pct.position = CGPoint(x: x + w, y: y)
        content.addChild(pct)

        // The grab area is taller than the 8pt track — an 8pt-high click target
        // is a miss most of the time.
        let grab = CGRect(x: barX - 6, y: y - 14, width: barW + 12, height: 28)
        hits.append(Hit(rect: grab, isSlider: true) { point in
            set(min(max((point.x - barX) / barW, 0), 1))
        })
    }

    private func buttonRow(_ text: String, _ action: String, x: CGFloat, w: CGFloat,
                           y: CGFloat, tint: SKColor, run: @escaping () -> Void) {
        // Both buttons here change something outside the panel, so they get the
        // plain bip rather than the blip every control on the screen makes.
        rowLabel(text, x: x, y: y)

        let bw = CGFloat(action.count) * 8 + 24, h: CGFloat = 22
        let rect = CGRect(x: x + w - bw, y: y - h / 2, width: bw, height: h)

        let box = SKShapeNode(rect: rect, cornerRadius: 2)
        box.fillColor   = tint.withAlphaComponent(0.12)
        box.strokeColor = tint
        box.lineWidth   = 1
        content.addChild(box)

        let lbl = label(action, 8, tint, .center)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: rect.midX, y: rect.midY)
        content.addChild(lbl)

        hits.append(Hit(rect: rect, isSlider: false, parts: [box, lbl],
                        sound: .uiConfirm) { _ in run() })
    }

    // MARK: - Primitives

    private func rowLabel(_ text: String, x: CGFloat, y: CGFloat, dimmed: Bool = false) {
        let node = label(text, 10, SKColor.white.withAlphaComponent(dimmed ? 0.36 : 0.92), .left)
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: x, y: y)
        content.addChild(node)
    }

    private func heading(_ text: String, _ color: SKColor, x: CGFloat, y: CGFloat) {
        let node = label(text, 14, color, .left)
        node.position = CGPoint(x: x, y: y)
        content.addChild(node)
    }

    /// The grey line under a row, explaining what it does.
    ///
    /// 10pt and 0.55, up from 8pt and 0.38. Two things made the old setting
    /// hard to read and only one of them was the size: at 0.38 on black this
    /// was nearly as faint as the panel's hairlines.
    ///
    /// 10 is the ceiling, not a preference. Press Start 2P advances one em
    /// per character and the left column is 420pt, so the longest line here
    /// may be 42 characters — two of them had to be cut to fit. And the panel
    /// is composed at 960 wide and scaled to fit, so in portrait on an iPad
    /// mini every size here renders at 0.775 of itself: 10pt lands at 7.8.
    /// Genuinely comfortable portrait type needs the panel restructure in
    /// §7, not a larger number here.
    private func explain(_ text: String, x: CGFloat, y: CGFloat) {
        let node = label(text, 10, SKColor.white.withAlphaComponent(0.55), .left)
        node.position = CGPoint(x: x, y: y)
        content.addChild(node)
    }

    private func percent(_ value: CGFloat) -> String {
        "\(Int((value * 100).rounded()))%"
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
