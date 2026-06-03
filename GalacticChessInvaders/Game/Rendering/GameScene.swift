// GameScene.swift
// Main SpriteKit scene. Hosts the bloom effect node, starfield,
// and all game content. Delegates physics to SKPhysicsContactDelegate.
//
// Phase 0: black background + starfield + GKStateMachine wired.
// Later phases add piece nodes, fleet controller, HUD, etc.

import SpriteKit
import GameplayKit

class GameScene: SKScene {

    // MARK: - Singleton (for SwiftUI SpriteView access)
    static let shared: GameScene = {
        let scene = GameScene(size: CGSize(width: 960, height: 700))
        scene.scaleMode = .aspectFit
        return scene
    }()

    // MARK: - Nodes
    private var bloomNode: SKEffectNode!      // parent of all glowing content
    private var starfieldNode: SKNode!        // parallax starfield (Phase 0: 2 layers)

    // MARK: - State
    private var stateMachine: GKStateMachine!

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        setupScene()
        setupStateMachine()
        DiagnosticsLog.shared.log(.startup, "GalacticChessInvaders initialised")
        DiagnosticsLog.shared.log(.startup, "Scene size: \(size.width)×\(size.height)")
    }

    // MARK: - Setup

    private func setupScene() {
        backgroundColor = SKColor(red: 0, green: 0, blue: 0, alpha: 1)  // #000000 void
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupBloomNode()
        setupStarfield()
    }

    private func setupBloomNode() {
        bloomNode = SKEffectNode()
        bloomNode.shouldRasterize = true
        bloomNode.filter = CIFilter(name: "CIBloom", parameters: [
            "inputRadius": 8.0,
            "inputIntensity": 1.0
        ])
        addChild(bloomNode)
    }

    private func setupStarfield() {
        starfieldNode = SKNode()
        addChild(starfieldNode)   // starfield behind bloom content

        // Phase 0: 2 placeholder star layers (expanded to 4 in Phase 8)
        addStarLayer(count: 60, speed: 8, alpha: 0.4, size: 1.5)
        addStarLayer(count: 30, speed: 15, alpha: 0.7, size: 2.0)

        DiagnosticsLog.shared.log(.startup, "Starfield: 2 layers (90 stars)")
    }

    private func addStarLayer(count: Int, speed: CGFloat, alpha: CGFloat, size: CGFloat) {
        for _ in 0..<count {
            let star = SKShapeNode(circleOfRadius: size)
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = alpha
            star.position = CGPoint(
                x: CGFloat.random(in: 0...self.size.width),
                y: CGFloat.random(in: 0...self.size.height)
            )
            // Gentle twinkle
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: alpha * 0.3, duration: Double.random(in: 0.8...2.0)),
                SKAction.fadeAlpha(to: alpha, duration: Double.random(in: 0.8...2.0))
            ])
            star.run(SKAction.repeatForever(twinkle))
            starfieldNode.addChild(star)
        }
    }

    private func setupStateMachine() {
        let title   = TitleState(scene: self)
        let playing = PlayingState(scene: self)
        let paused  = PausedState(scene: self)
        let gameOver = GameOverState(scene: self)

        stateMachine = GKStateMachine(states: [title, playing, paused, gameOver])
        stateMachine.enter(TitleState.self)
        DiagnosticsLog.shared.log(.startup, "State machine → TITLE")
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        // dt-based updates will go here as phases progress
    }

    // MARK: - Input (macOS)

    override func keyDown(with event: NSEvent) {
        InputHandler.shared.handleKeyDown(event)
    }

    override func keyUp(with event: NSEvent) {
        InputHandler.shared.handleKeyUp(event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        InputHandler.shared.handleMouseDown(at: location, in: self)
    }
}

// MARK: - Physics Contact

extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        // Phase 3+: handle laser/piece, shot/piece, ship/shot contacts
    }
}
