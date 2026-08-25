// StarfieldTiling.swift
// Placement arithmetic for one parallax star tier.
//
// A tier is two identical copies of the same random star layout. They scroll
// together and swap slots every cycle. The whole illusion rests on one
// invariant: when copy B reaches the end of a cycle it must sit exactly where
// copy A started. If it does not, the field visibly jumps at the handoff.
//
// Factored out of GameScene so that invariant can be asserted in a test rather
// than trusted to a comment.

import CoreGraphics

struct StarfieldTiling {
    let sceneHeight: CGFloat
    /// Sideways travel across one screen-height fall, as a fraction of it.
    /// Zero scrolls straight down; 0.08 leans about 4.6°.
    let drift: CGFloat

    /// Horizontal travel per cycle.
    var dx: CGFloat { drift * sceneHeight }

    /// Copy A begins on screen.
    var slotA: CGPoint { .zero }

    /// Copy B begins one screen above and offset back along the drift, so that
    /// scrolling brings it to exactly `slotA`.
    var slotB: CGPoint { CGPoint(x: -dx, y: sceneHeight) }

    /// Applied over one cycle, then undone instantly to restart it.
    var scroll: CGVector { CGVector(dx: dx, dy: -sceneHeight) }

    func advanced(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + scroll.dx, y: point.y + scroll.dy)
    }

    func rewound(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - scroll.dx, y: point.y - scroll.dy)
    }

    /// The seam invariant. True when the handoff between copies is seamless.
    var isSeamless: Bool {
        let landed = advanced(slotB)
        return abs(landed.x - slotA.x) < 0.0001 && abs(landed.y - slotA.y) < 0.0001
    }
}
