// TurnTimerNode.swift
// The chess beat countdown, shown in the gutter to the left of the board
// (§19: lower-left of the board area).
//
// Held at a single colour — neon green, so it never competes with the cyan of
// White's pieces or the magenta of the fleet. Urgency in the last two seconds is
// carried by a scale pulse rather than a colour shift.

import SpriteKit

@MainActor
final class TurnTimerNode: SKNode {

    private static let green    = SKColor(red: 0.30, green: 1.00, blue: 0.45, alpha: 1)
    private static let font     = "PressStart2P-Regular"
    private static let pulseKey = "timerPulse"

    private let caption = SKLabelNode(fontNamed: TurnTimerNode.font)
    private let digits  = SKLabelNode(fontNamed: TurnTimerNode.font)

    /// Tracked so the pulse is started and stopped once, not every frame.
    private var isPulsing = false
    /// What the two labels currently say. `refresh` runs on every frame of
    /// every beat, and the digits change once a second.
    private var shownSeconds = -1
    private var shownExtended: Bool?

    override init() {
        super.init()

        caption.text = "YOUR MOVE"
        caption.fontSize = 8
        caption.fontColor = Self.green.withAlphaComponent(0.7)
        caption.horizontalAlignmentMode = .center
        caption.verticalAlignmentMode = .center
        caption.position = CGPoint(x: 0, y: 18)
        addChild(caption)

        digits.text = "5"
        digits.fontSize = 22
        digits.fontColor = Self.green
        digits.horizontalAlignmentMode = .center
        digits.verticalAlignmentMode = .center
        addChild(digits)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Refreshed from the game loop, so it is called sixty times a second for
    /// a readout that changes once. Both labels are written only when what
    /// they say changes: assigning `SKLabelNode.text` marks the label for
    /// re-layout whether or not the string differs, and interpolating the
    /// digits allocated a `String` on every frame of every beat.
    func refresh(from timer: TurnTimer) {
        let seconds = timer.displaySeconds
        if seconds != shownSeconds {
            shownSeconds = seconds
            digits.text = String(seconds)
        }
        // The caption, not the colour, says the beat was extended for check.
        if timer.isExtended != shownExtended {
            shownExtended = timer.isExtended
            caption.text = timer.isExtended ? "CHECK" : "YOUR MOVE"
        }
        setPulsing(timer.isWarning)
    }

    private func setPulsing(_ shouldPulse: Bool) {
        guard shouldPulse != isPulsing else { return }
        isPulsing = shouldPulse

        if shouldPulse {
            digits.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.20, duration: 0.25),
                SKAction.scale(to: 1.00, duration: 0.25)
            ])), withKey: Self.pulseKey)
        } else {
            digits.removeAction(forKey: Self.pulseKey)
            digits.setScale(1.0)
        }
    }
}
