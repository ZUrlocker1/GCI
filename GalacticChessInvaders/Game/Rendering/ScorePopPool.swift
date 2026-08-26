// ScorePopPool.swift
// §24.3's floating score labels: "+150" rising from wherever the points were
// earned, in that target's own glow colour, gone in 0.8s.
//
// Twenty pre-created labels (§20 Phase 3.3), added to the parent once and only
// ever shown and hidden after that — the same no-allocation-during-play rule
// LaserPool follows (§18). A volley that clears four pieces at once needs four
// of these in the same frame, and the pool exists so that costs nothing.

import SpriteKit

@MainActor
final class ScorePopPool {

    private static let count = 20
    private static let font = "PressStart2P-Regular"
    private static let riseKey = "rise"

    private var labels: [SKLabelNode] = []

    init(parent: SKNode) {
        labels = (0..<Self.count).map { _ in
            let label = SKLabelNode(fontNamed: Self.font)
            label.fontSize = 11
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 22          // above pieces and lasers, below overlays
            label.isHidden = true
            parent.addChild(label)
            return label
        }
    }

    /// Floats `points` up from `position`, in the parent's coordinate space.
    ///
    /// Silently does nothing when every label is already in the air. That is
    /// the right failure: twenty simultaneous pops is already unreadable, and
    /// dropping the twenty-first costs the player nothing — the HUD total is
    /// the authority, this is only the flourish.
    func pop(_ points: Int, at position: CGPoint, color: SKColor) {
        guard points != 0, let label = labels.first(where: { $0.isHidden }) else { return }
        label.text = points > 0 ? "+\(points)" : "\(points)"
        label.fontColor = color
        label.position = position
        label.alpha = 1
        label.setScale(0.6)
        label.isHidden = false
        label.removeAction(forKey: Self.riseKey)
        label.run(.sequence([
            // Pops to full size first, then drifts: the size change is what
            // catches the eye, and it has to happen before the fade starts or
            // the label is already half gone by the time it is legible.
            .scale(to: 1.0, duration: 0.12),
            .group([
                .moveBy(x: 0, y: Juice.popRise, duration: Juice.popDuration),
                .sequence([.wait(forDuration: Juice.popDuration * 0.45),
                           .fadeOut(withDuration: Juice.popDuration * 0.55)]),
            ]),
            .run { label.isHidden = true },
        ]), withKey: Self.riseKey)
    }

    /// Clears everything in flight — a level teardown must not leave a label
    /// drifting over the next wave's board.
    func reset() {
        for label in labels {
            label.removeAction(forKey: Self.riseKey)
            label.isHidden = true
        }
    }
}
