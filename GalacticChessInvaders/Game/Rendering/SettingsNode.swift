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

    // MARK: - Hit targets
    //
    // Built during layout rather than looked up by node name. A settings screen
    // is a dozen small rectangles with a value behind each; carrying the rect
    // and the effect together is less to keep in step than a naming scheme the
    // scene would have to parse.

    private struct Hit {
        let rect: CGRect
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

    override init() {
        super.init()
        buildBackground()
        addChild(content)
        rebuild()
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
        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: Self.W, height: Self.H))
        bg.fillColor = SKColor(white: 0, alpha: 0.97)
        bg.strokeColor = .clear
        bg.zPosition = -1
        addChild(bg)
    }

    private func rebuild() {
        content.removeAllChildren()
        hits.removeAll()
        buildHeader()
        buildLeftColumn()
        buildRightColumn()
        buildFooter()
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
        segmentRow("DIFFICULTY", x: x, w: w, y: 512,
                   options: ["CADET", "PILOT"],
                   selected: settings.difficulty == .cadet ? 0 : 1) { index in
            self.settings.difficulty = index == 0 ? .cadet : .pilot
        }
        explain("SELECT CADET FOR AN EASIER ON RAMP.", x: x, y: 488)

        segmentRow("CHESS", x: x, w: w, y: 456,
                   options: ["YOU PLAY", "AUTO"],
                   selected: settings.autoChess ? 1 : 0) { index in
            self.settings.autoChess = index == 1
        }
        explain("AUTOMATIC FAST CHESS PLAY FOR WHITE.", x: x, y: 432)

        heading("AUDIO", Self.cyan, x: x, y: 376)
        // Both audio sliders are shown as a fraction of `audioMax`, so the
        // shipped level reads as 75% with room above it — see `audioMax`.
        let top = CGFloat(GameSettings.audioMax)
        let shipped = 1.0 / top

        toggleRow("MUSIC", x: x, w: w, y: 348, value: settings.musicOn) {
            self.settings.musicOn = $0
        }
        let music = CGFloat(settings.musicVolume) / top
        sliderRow("VOLUME", x: x, w: w, y: 316, fraction: music,
                  readout: percent(music), dimmed: !settings.musicOn,
                  defaultMark: shipped) {
            self.settings.musicVolume = Float($0 * top)
        }
        toggleRow("SOUND FX", x: x, w: w, y: 280, value: settings.soundOn) {
            self.settings.soundOn = $0
        }
        let effects = CGFloat(settings.soundVolume) / top
        sliderRow("VOLUME", x: x, w: w, y: 248, fraction: effects,
                  readout: percent(effects), dimmed: !settings.soundOn,
                  defaultMark: shipped) {
            self.settings.soundVolume = Float($0 * top)
        }
    }

    private func buildRightColumn() {
        let x = Self.rx, w = Self.rw

        heading("DISPLAY", Self.cyan, x: x, y: 540)
        toggleRow("NEON GLOW", x: x, w: w, y: 512, value: settings.neonGlow) {
            self.settings.neonGlow = $0
        }
        explain("TURN OFF ON A SLOWER MAC", x: x, y: 490)

        sliderRow("BOARD GRID", x: x, w: w, y: 460, fraction: settings.boardGrid,
                  readout: percent(settings.boardGrid), dimmed: false, defaultMark: 0.5) {
            self.settings.boardGrid = $0
        }
        explain("0% = OPEN SPACE, 100% = NAMED ROWS, COLS", x: x, y: 435)

        toggleRow("NEBULA", x: x, w: w, y: 408, value: settings.nebula) {
            self.settings.nebula = $0
        }
        explain("COLORED HAZE BACKGROUND IN LATER LEVELS", x: x, y: 386)

        toggleRow("LOG PANEL", x: x, w: w, y: 358, value: settings.logPanel) {
            self.settings.logPanel = $0
        }
        explain("SAME AS THE L KEY", x: x, y: 336)

        heading("CONTROLS", Self.cyan, x: x, y: 310)
        let range = GameSettings.shipSpeedRange
        let span = range.upperBound - range.lowerBound
        sliderRow("SHIP SPEED", x: x, w: w, y: 282,
                  fraction: (settings.shipSpeedScale - range.lowerBound) / span,
                  readout: percent(settings.shipSpeedScale), dimmed: false,
                  defaultMark: 0.5) { fraction in
            self.settings.shipSpeedScale = range.lowerBound + fraction * span
        }
        explain("DEFAULT IS PLAYTESTED", x: x, y: 257)

        heading("DATA", Self.magenta, x: x, y: 204)
        buttonRow("HIGH SCORES", "RESET", x: x, w: w, y: 176, tint: Self.magenta) {
            ScoreManager.shared.clearHighScores()
        }
        explain("BACK TO ORIGINAL SCORES", x: x, y: 154)
        buttonRow("ALL SETTINGS", "RESTORE", x: x, w: w, y: 126, tint: Self.cyan) {
            self.settings.restoreDefaults()
        }
    }

    private func buildFooter() {
        // Above the rule, opposite SAVED AUTOMATICALLY. This is the screen
        // someone opens to look the app over, so it is where the build number
        // belongs.
        let build = label("VERSION \(Bundle.main.appVersion)  BUILD \(Bundle.main.appBuild)",
                          9, SKColor.white.withAlphaComponent(0.45), .left)
        build.position = CGPoint(x: Self.lx, y: 88)
        content.addChild(build)

        content.addChild(hline(x: 40, y: 70, w: Self.W - 80))

        // Top right, in the same box the HUD's SETTINGS button occupies.
        let rect = HowToPlayNode.navRect
        let box = SKShapeNode(rect: rect, cornerRadius: 3)
        box.fillColor   = Self.cyan.withAlphaComponent(0.18)
        box.strokeColor = Self.cyan
        box.lineWidth   = 1
        box.name        = "backButton"
        content.addChild(box)

        let lbl = label("• BACK", 8, Self.cyan, .center)
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: rect.midX, y: rect.midY)
        lbl.name = "backButton"
        content.addChild(lbl)

        let hint = label("PRESS ANY KEY TO RESUME GAME", 10,
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
        let node = label(text, 9, SKColor.white.withAlphaComponent(dimmed ? 0.32 : 0.88), .left)
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: x, y: y)
        content.addChild(node)
    }

    private func heading(_ text: String, _ color: SKColor, x: CGFloat, y: CGFloat) {
        let node = label(text, 14, color, .left)
        node.position = CGPoint(x: x, y: y)
        content.addChild(node)
    }

    private func explain(_ text: String, x: CGFloat, y: CGFloat) {
        let node = label(text, 8, SKColor.white.withAlphaComponent(0.38), .left)
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
