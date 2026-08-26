// LevelBannerNode.swift
// The mechanic announcement banner shown at the start of an escalated level
// (§12.11): two centred lines of pixel text between hairline rules, sliding in
// from the left with a slight elastic overshoot.
//
// It exists to frame an escalation as a reveal rather than a surprise attack —
// the board is already visible behind it, and play only starts once it leaves.

import SpriteKit

@MainActor
final class LevelBannerNode: SKNode {

    /// Slide, hold, fade. The caller waits this long before starting the beat.
    static let slideIn: TimeInterval = 0.35
    static let hold: TimeInterval = 1.8
    static let fadeOut: TimeInterval = 0.3
    static var totalDuration: TimeInterval { slideIn + hold + fadeOut }

    private static let font = "PressStart2P-Regular"
    /// So the scene can clear a previous banner before showing another.
    static let nodeName = "levelBanner"

    /// `title` is the mechanic name, `subtitle` the one-line explanation.
    ///
    /// Press Start 2P advances one em per character, so `ruleWidth` sets the
    /// real text limits: 16 characters of title at 26pt, 38 of subtitle at 11pt.
    /// `LevelAnnouncementTests` enforces those.
    init(title: String, subtitle: String, sceneSize: CGSize) {
        super.init()
        name = Self.nodeName
        zPosition = 22

        let centre = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        let ruleWidth: CGFloat = 420

        let titleLabel = SKLabelNode(fontNamed: Self.font)
        titleLabel.text = title
        titleLabel.fontSize = 26
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: centre.x, y: centre.y + 12)
        addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: Self.font)
        subtitleLabel.text = subtitle
        subtitleLabel.fontSize = 11
        subtitleLabel.fontColor = NeonPalette.cyan.withAlphaComponent(0.75)
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.position = CGPoint(x: centre.x, y: centre.y - 18)
        addChild(subtitleLabel)

        for offset in [CGFloat(44), -44] {
            let rule = SKShapeNode(rect: CGRect(x: centre.x - ruleWidth / 2,
                                                y: centre.y + offset,
                                                width: ruleWidth, height: 1))
            rule.fillColor = NeonPalette.magenta.withAlphaComponent(0.8)
            rule.strokeColor = .clear
            addChild(rule)
        }

        // Enters from off-screen left. `.easeOut` past the target then settling
        // is what reads as the elastic overshoot §12.11 asks for; a single
        // tween arrives too politely for an escalation announcement.
        position = CGPoint(x: -sceneSize.width, y: 0)
        let overshoot = SKAction.move(to: CGPoint(x: 18, y: 0), duration: Self.slideIn * 0.75)
        overshoot.timingMode = .easeOut
        let settle = SKAction.move(to: .zero, duration: Self.slideIn * 0.25)
        settle.timingMode = .easeOut

        let glowPulse = SKAction.sequence([
            .fadeAlpha(to: 0.55, duration: 0.09),
            .fadeAlpha(to: 1.00, duration: 0.09),
        ])
        run(.sequence([
            overshoot, settle, glowPulse,
            .wait(forDuration: Self.hold),
            .fadeOut(withDuration: Self.fadeOut),
            .removeFromParent(),
        ]))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
