// VersionBadgeNode.swift
// The version string, boxed, because it is also a button.
//
// It reads the build number for a bug report and it is the way into Test Mode
// on a device with no ⌘T — docs/IOS-Port.md §4. As bare text it did the first
// job and hid the second: nothing about dim type in a corner says "hold me".
// So it is drawn as a chip, matching `TestModeStripNode` directly below it,
// and the press has three states instead of one fade:
//
//   rest        cyan, or orange once Test Mode is on
//   holding     white, with a bar sweeping the box left to right
//   done        back to rest, in the new Test Mode colour
//
// The sweep is the part that matters. A 1.5-second hold with no feedback
// feels broken right up until it works, which is the same objection that
// ruled out counted taps; a bar that fills says both "this is happening" and
// "this is how much longer".
//
// **In and out are not symmetric, deliberately.** The hold exists to stop a
// player stumbling into Test Mode, and that argument is spent the moment
// they are in it: anyone looking at an orange badge has already found the
// control and knows what it does. So leaving is a plain tap — `beginTap()`
// rather than `beginPress` — and only the way in is guarded.

import SpriteKit

#if os(iOS)

@MainActor
final class VersionBadgeNode: SKNode {

    static let height: CGFloat = 24
    private static let fontSize: CGFloat = 10
    private static let padding: CGFloat = 8
    /// Press Start 2P is monospaced at one em per glyph.
    private static let charWidth: CGFloat = fontSize

    private let box: SKShapeNode
    private let fill: SKSpriteNode
    private let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
    private static let sweepKey = "sweep"

    /// Whole width, so the caller can place the strip beneath it.
    let width: CGFloat

    private var isTestMode = false
    private var isPressed = false

    init(text: String) {
        width = CGFloat(text.count) * Self.charWidth + Self.padding * 2
        let rect = CGRect(x: 0, y: -Self.height / 2, width: width, height: Self.height)
        box = SKShapeNode(rect: rect, cornerRadius: 3)

        // Anchored left so growing `xScale` sweeps rather than stretches from
        // the middle. Inset a point so it does not spill past the corners,
        // which is cheaper than cropping to a rounded path.
        fill = SKSpriteNode(color: .white, size: CGSize(width: rect.width - 2,
                                                       height: rect.height - 2))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: 1, y: 0)
        fill.xScale = 0.001
        fill.alpha = 0

        super.init()
        zPosition = 11          // over the playfield, under the panels

        box.lineWidth = 1
        addChild(box)
        addChild(fill)

        label.text = text
        label.fontSize = Self.fontSize
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: rect.midX, y: 0)
        addChild(label)

        restyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - State

    /// Orange once Test Mode is on, and lit rather than dim, so the state is
    /// legible without opening anything. The gutter notice says it once; this
    /// keeps saying it.
    func setTestMode(_ on: Bool) {
        guard on != isTestMode else { return }
        isTestMode = on
        restyle()
    }

    /// Quiet at rest. The box made it far more present than the bare label
    /// was, and this is chrome a player should be able to ignore — so the
    /// resting weight came back down once the frame was there to carry it.
    /// Test Mode and the press both still read at a glance.
    private func restyle() {
        let colour = isPressed ? SKColor.white
            : (isTestMode ? NeonPalette.alertOrange : NeonPalette.cyan)
        box.strokeColor = colour.withAlphaComponent(isPressed ? 1.0 : 0.38)
        box.fillColor = colour.withAlphaComponent(isTestMode ? 0.10 : 0.04)
        label.fontColor = colour.withAlphaComponent(
            isPressed ? 1.0 : (isTestMode ? 0.9 : 0.62))
    }

    // MARK: - The hold

    /// Runs the sweep and calls `then` if it finishes. Everything is under one
    /// key so `cancelPress()` takes the callback with it — a finger lifted
    /// early must not toggle anything.
    func beginPress(duration: TimeInterval, then: @escaping () -> Void) {
        isPressed = true
        restyle()
        fill.removeAllActions()
        fill.xScale = 0.001
        fill.alpha = 0.3
        fill.color = .white
        fill.run(.sequence([
            .scaleX(to: 1, duration: duration),
            .run(then),
        ]), withKey: Self.sweepKey)
    }

    /// Down, with nothing to wait for — the caller acts on the lift instead.
    /// Fills at once rather than sweeping: a bar that completes instantly is
    /// a flicker, and there is no duration here to describe.
    func beginTap() {
        isPressed = true
        restyle()
        fill.removeAllActions()
        fill.xScale = 1
        fill.alpha = 0.3
    }

    /// Lifted, or slid off. `true` if a press really was in progress, which
    /// is what tells the caller a lift is a completed tap rather than a
    /// stray touch ending somewhere else.
    @discardableResult
    func cancelPress() -> Bool {
        guard isPressed else { return false }
        isPressed = false
        fill.removeAction(forKey: Self.sweepKey)
        fill.run(.fadeAlpha(to: 0, duration: 0.15))
        restyle()
        return true
    }

    // MARK: - Hit testing

    /// The box, with a little air. It is already a large target — the text is
    /// twenty-odd characters — so this is only for the edges.
    func contains(scenePoint point: CGPoint) -> Bool {
        guard !isHidden else { return false }
        let local = CGPoint(x: point.x - position.x, y: point.y - position.y)
        return box.frame.insetBy(dx: -6, dy: -6).contains(local)
    }
}
#endif
