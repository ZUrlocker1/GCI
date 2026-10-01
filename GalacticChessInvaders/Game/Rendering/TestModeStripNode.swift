// TestModeStripNode.swift
// `P`, `R` and `V` as buttons, for a device with no keyboard.
//
// docs/IOS-Port.md §4 splits the five test keys by kind, and the split is the
// design. `L` and `A` are states that persist, and Settings already carries
// both — the log row behind `SettingsNode(showsLogRow: testMode)`, and Auto
// Chess as the CHESS `YOU PLAY / AUTO` row. Nothing to build for those.
//
// These three are momentary. They fire *during* play and are meaningless from
// a modal panel: by the time Settings is closed, the power-up you wanted to
// watch land has landed. So they need to be reachable with the game running,
// which is what this is.
//
//   POWER · RAID · LEVEL
//
// **Top of the left gutter, under the version label**, which is also the
// Test Mode switch — indicator and controls in one place. The 32pt band
// beneath the HUD bar holds one line and the version label has it; below that
// the board begins, but only from `boardOriginX` rightward, and this row is
// about 166pt wide against a gutter that is never narrower than 224. So the
// chips sit beside the board at every size, never over it.
//
// Not in the ship's lane, though §4 suggested it as the band that survives
// every orientation. Everything below the board is a ship grab —
// `isInShipLane` is `point.y < boardBottomY`, the full width — so buttons
// down there would each need an exception ahead of the lane test, and they
// would sit exactly where a steering thumb lives.

import SpriteKit


@MainActor
final class TestModeStripNode: SKNode {

    /// What a chip does. The raw value is the label.
    ///
    /// Spelled out where there is room. The row costs 166pt at these lengths,
    /// which was free when this was iOS-only — the gutter was never narrower
    /// than 224. Both halves of that stopped being true: the gutter is sized
    /// to its own type now and reaches down to 145, and the row ships on a Mac
    /// whose window goes to 640pt, where the board's left edge comes in to 166
    /// and the spelled-out row ended at 176 — on the board. Hence `short`.
    enum Action: String, CaseIterable {
        case power  = "POWER"
        case raider = "RAID"
        case skip   = "LEVEL"

        /// For a gutter too narrow to carry the words. `RAID` is already as
        /// short as it goes, which is why it is not abbreviated further.
        var short: String {
            switch self {
            case .power:  return "PWR"
            case .raider: return "RAID"
            case .skip:   return "LVL"
            }
        }
    }

    private static let fontSize: CGFloat = 8
    private static let chipHeight: CGFloat = 22
    private static let chipGap: CGFloat = 6
    private static let padding: CGFloat = 7
    /// Press Start 2P is monospaced at one em per glyph, so a label's width is
    /// its character count — no measuring, and no drift if a label changes.
    private static let charWidth: CGFloat = fontSize

    private struct Chip {
        let action: Action
        let box: SKShapeNode
        let label: SKLabelNode
        /// In this node's own space, which is where hit tests land. Moves with
        /// the wording, so it is a `var` — a stale rect here would leave the
        /// hit targets where the old, wider chips used to be.
        var rect: CGRect
    }

    private var chips: [Chip] = []
    private var isLive = false
    private var isCompact = false

    /// What the row measures at a given wording, so a caller can decide which
    /// one fits before committing to it.
    static func width(compact: Bool) -> CGFloat {
        let titles = Action.allCases.map { compact ? $0.short : $0.rawValue }
        let boxes = titles.reduce(CGFloat(0)) {
            $0 + CGFloat($1.count) * charWidth + padding * 2
        }
        return boxes + chipGap * CGFloat(titles.count - 1)
    }

    /// Switches the row between `POWER RAID LEVEL` and `PWR RAID LVL`.
    func setCompact(_ compact: Bool) {
        guard compact != isCompact else { return }
        isCompact = compact
        layOutChips()
    }

    /// Lays the chips left to right from x = 0, hanging below the anchor.
    private func layOutChips() {
        var x: CGFloat = 0
        for index in chips.indices {
            let title = isCompact ? chips[index].action.short
                                  : chips[index].action.rawValue
            let width = CGFloat(title.count) * Self.charWidth + Self.padding * 2
            let rect = CGRect(x: x, y: -Self.chipHeight,
                              width: width, height: Self.chipHeight)
            chips[index].box.path = CGPath(roundedRect: rect, cornerWidth: 3,
                                           cornerHeight: 3, transform: nil)
            chips[index].label.text = title
            chips[index].label.position = CGPoint(x: rect.midX, y: rect.midY)
            chips[index].rect = rect
            x += width + Self.chipGap
        }
    }

    override init() {
        super.init()
        zPosition = 12          // just over the version label, under the panels

        var x: CGFloat = 0
        for action in Action.allCases {
            let width = CGFloat(action.rawValue.count) * Self.charWidth + Self.padding * 2
            let rect = CGRect(x: x, y: -Self.chipHeight,
                              width: width, height: Self.chipHeight)

            let box = SKShapeNode(rect: rect, cornerRadius: 3)
            box.lineWidth = 1
            addChild(box)

            let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
            label.text = action.rawValue
            label.fontSize = Self.fontSize
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: rect.midX, y: rect.midY)
            addChild(label)

            chips.append(Chip(action: action, box: box, label: label, rect: rect))
            x += width + Self.chipGap
        }
        restyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - State

    /// All three are dead outside `PlayingState`, and a chip that looks live
    /// and is not is worse than one that is visibly greyed.
    func setLive(_ live: Bool) {
        guard live != isLive else { return }
        isLive = live
        restyle()
    }

    /// Nothing here stays on, so a chip blinks once — otherwise a press that
    /// fired correctly looks like a press that missed.
    func flash(_ action: Action) {
        guard let chip = chips.first(where: { $0.action == action }) else { return }
        let lit = NeonPalette.cyan.withAlphaComponent(0.55)
        chip.box.removeAllActions()
        chip.box.fillColor = lit
        chip.box.run(.customAction(withDuration: 0.25) { node, elapsed in
            guard let shape = node as? SKShapeNode else { return }
            shape.fillColor = NeonPalette.cyan
                .withAlphaComponent(0.55 * (1 - elapsed / 0.25))
        })
    }

    private func restyle() {
        for chip in chips {
            chip.box.removeAllActions()
            chip.box.strokeColor = NeonPalette.cyan.withAlphaComponent(isLive ? 0.75 : 0.25)
            chip.box.fillColor = NeonPalette.cyan.withAlphaComponent(isLive ? 0.08 : 0.03)
            chip.label.fontColor = NeonPalette.cyan.withAlphaComponent(isLive ? 0.95 : 0.3)
        }
    }

    // MARK: - Hit testing

    /// Which chip a scene point is on, or nil.
    ///
    /// Padded a little, the way `FireButtonNode.contains(scenePoint:)` is —
    /// but only a little sideways, or neighbours would overlap.
    func action(atScenePoint point: CGPoint) -> Action? {
        guard !isHidden, isLive else { return nil }
        let local = CGPoint(x: point.x - position.x, y: point.y - position.y)
        return chips.first { $0.rect.insetBy(dx: -2, dy: -6).contains(local) }?.action
    }
}
