// CheckPathNode.swift
// Shows where a check is coming from: a glowing line drawn from the attacking
// piece to the king, a brief double flash, then a fade out.
//
// This exists because the board deliberately draws no grid (see BoardNode), so
// "your king is attacked" otherwise gives the player no way to see from where.
//
// A knight does not travel its path, so its line is dashed — a solid line would
// imply squares the knight never crosses.

import SpriteKit

@MainActor
final class CheckPathNode: SKNode {

    /// Sweep, flash, flash, fade — a little over a second, so it is gone well
    /// before the next move lands.
    private static let sweep: TimeInterval = 0.22
    private static let flash: TimeInterval = 0.13
    private static let hold: TimeInterval = 0.18
    private static let fade: TimeInterval = 0.34

    /// Wall time for a given pulse count, so callers can pace around it.
    static func duration(pulses: Int = 2) -> TimeInterval {
        sweep + hold + flash * 2 * TimeInterval(pulses) + fade
    }

    static var totalDuration: TimeInterval { duration() }

    /// - Parameters:
    ///   - from: attacking piece's centre, in the parent's coordinate space
    ///   - to: the king's centre
    ///   - isJump: true for a knight, which gets a dashed line
    ///   - color: magenta when the player is checked, cyan when Black is
    ///   - pulses: flashes after the sweep; checkmate uses more so it lands harder
    init(from origin: CGPoint, to king: CGPoint, isJump: Bool, color: SKColor,
         pulses: Int = 2) {
        super.init()

        let delta = CGVector(dx: king.x - origin.x, dy: king.y - origin.y)
        let length = sqrt(delta.dx * delta.dx + delta.dy * delta.dy)
        guard length > 0 else { return }

        addChild(Self.makeLine(origin: origin, delta: delta, length: length,
                              isJump: isJump, color: color, pulses: pulses))
        addChild(Self.makeMarker(at: origin, radius: 15, color: color,
                                delay: 0, pulses: pulses))
        // The king's marker lands as the line arrives.
        addChild(Self.makeMarker(at: king, radius: 19, color: color,
                                delay: Self.sweep * 0.8, pulses: pulses))

        // Self-cleaning: nothing else has to remember to remove this.
        run(.sequence([.wait(forDuration: Self.duration(pulses: pulses)), .removeFromParent()]))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Built along +x and rotated into place, so growing it is an xScale animation.
    /// Scaling this way lengthens the line without thickening its stroke, which a
    /// uniform scale would.
    private static func makeLine(origin: CGPoint, delta: CGVector, length: CGFloat,
                                 isJump: Bool, color: SKColor, pulses: Int) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: length, y: 0))

        let line = SKShapeNode(path: isJump
            ? path.copy(dashingWithPhase: 0, lengths: [9, 7])
            : path)
        line.strokeColor = color
        line.lineWidth = 2.5
        line.lineCap = .round
        line.glowWidth = 3
        line.position = origin
        line.zRotation = atan2(delta.dy, delta.dx)
        line.xScale = 0.001          // zero would collapse the transform
        line.alpha = 0.95
        line.zPosition = 3

        let grow = SKAction.scaleX(to: 1, y: 1, duration: sweep)
        grow.timingMode = .easeOut

        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.35, duration: flash),
            .fadeAlpha(to: 0.95, duration: flash),
        ])

        line.run(.sequence([
            grow,
            .wait(forDuration: hold),
            .repeat(pulse, count: pulses),
            .fadeOut(withDuration: fade),
        ]))
        return line
    }

    /// A ring that pops outward and fades, marking each end of the path.
    private static func makeMarker(at point: CGPoint, radius: CGFloat, color: SKColor,
                                   delay: TimeInterval, pulses: Int) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = color
        ring.lineWidth = 2
        ring.glowWidth = 2
        ring.fillColor = .clear
        ring.position = point
        ring.alpha = 0
        ring.setScale(0.45)
        ring.zPosition = 3

        ring.run(.sequence([
            .wait(forDuration: delay),
            .group([
                .fadeAlpha(to: 0.9, duration: 0.12),
                .scale(to: 1.0, duration: 0.18),
            ]),
            .wait(forDuration: hold + flash * 2 * TimeInterval(pulses) - 0.18),
            .group([
                .fadeOut(withDuration: fade),
                .scale(to: 1.25, duration: fade),
            ]),
        ]))
        return ring
    }
}
