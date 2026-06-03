// HUDNode.swift
// Heads-up display: score, hi-score, level, lives, turn timer.
// Font: Press Start 2P. Timer pulses red on last 2 seconds.
// Phase 1+: full implementation.

import SpriteKit

final class HUDNode: SKNode {
    private var scoreLabel: SKLabelNode!
    private var hiScoreLabel: SKLabelNode!
    private var levelLabel: SKLabelNode!
    private var timerLabel: SKLabelNode!
    private var livesNodes: [SKSpriteNode] = []

    func setup(sceneSize: CGSize) {
        // Phase 1+: create and position all HUD elements using Press Start 2P font
    }

    func updateScore(_ score: Int) {
        scoreLabel?.text = String(format: "SCORE: %06d", score)
    }

    func updateHiScore(_ score: Int) {
        hiScoreLabel?.text = String(format: "HI: %06d", score)
    }

    func updateLevel(_ level: Int) {
        levelLabel?.text = "LEVEL \(String(format: "%02d", level))"
    }

    func updateTimer(_ seconds: Int) {
        timerLabel?.text = "\(seconds)"
        // Phase 1+: color green→yellow→red, pulse on ≤2
    }

    func updateLives(_ lives: Int) {
        // Phase 1+: show/hide ship silhouette icons
    }

    func flashAutoMove(at position: CGPoint) {
        // Phase 1+: "AUTO" label briefly appears above moved piece
    }
}
