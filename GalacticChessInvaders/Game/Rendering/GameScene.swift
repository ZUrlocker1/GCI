// GameScene.swift
// Main SpriteKit scene. Hosts the bloom effect node, starfield, and all game content.
// Acts as the hub between the input handler, state machine, and rendering nodes.
//
// Phase 0: black background, starfield, title overlay, placeholder board, state machine.

import SpriteKit
import GameplayKit

class GameScene: SKScene {

    // MARK: - Singleton

    static let shared: GameScene = {
        let scene = GameScene(size: CGSize(width: 960, height: 700))
        scene.scaleMode = .aspectFit
        return scene
    }()

    // MARK: - Nodes

    // All glowing game content lives inside bloomNode so the CIBloom filter applies
    private var bloomNode: SKEffectNode!
    private var starfieldNode: SKNode!
    private var titleOverlay: TitleOverlayNode?
    private var placeholderBoard: PlaceholderBoardNode?

    // MARK: - State

    private(set) var stateMachine: GKStateMachine!

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        setupScene()
        setupInputHandler()
        setupStateMachine()

        DiagnosticsLog.shared.log(.startup, "App launched (macOS, debug build)")
        DiagnosticsLog.shared.log(.startup, "Scene size: \(Int(size.width))×\(Int(size.height))")
        DiagnosticsLog.shared.log(.startup, "Title screen displayed")
    }

    // MARK: - Scene Setup

    private func setupScene() {
        backgroundColor = SKColor(red: 0, green: 0, blue: 0, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupBloomNode()
        setupStarfield()
    }

    private func setupBloomNode() {
        bloomNode = SKEffectNode()
        bloomNode.shouldRasterize = true
        bloomNode.filter = CIFilter(name: "CIBloom", parameters: [
            "inputRadius": 6.0,
            "inputIntensity": 0.9
        ])
        addChild(bloomNode)
    }

    private func setupStarfield() {
        starfieldNode = SKNode()
        addChild(starfieldNode)   // behind bloomNode so stars don't get extra bloom

        addStarLayer(count: 60, speed: 8,  alpha: 0.35, size: 1.2)  // distant, slow
        addStarLayer(count: 30, speed: 15, alpha: 0.65, size: 2.0)  // closer, brighter

        DiagnosticsLog.shared.log(.startup, "Starfield: 2 layers, 90 stars")
    }

    private func addStarLayer(count: Int, speed: CGFloat, alpha: CGFloat, size starSize: CGFloat) {
        for _ in 0..<count {
            let star = SKShapeNode(circleOfRadius: starSize)
            star.fillColor   = .white
            star.strokeColor = .clear
            star.alpha = alpha
            star.position = CGPoint(
                x: CGFloat.random(in: 0...self.size.width),
                y: CGFloat.random(in: 0...self.size.height)
            )
            let twinkleDuration = Double.random(in: 1.0...2.5)
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: alpha * 0.2, duration: twinkleDuration),
                SKAction.fadeAlpha(to: alpha,       duration: twinkleDuration)
            ])
            star.run(SKAction.repeatForever(twinkle))
            starfieldNode.addChild(star)
        }
    }

    // MARK: - Input

    private func setupInputHandler() {
        InputHandler.shared.actionHandler = { [weak self] action in
            self?.handle(action)
        }
    }

    private func handle(_ action: GameAction) {
        switch action {
        case .toggleDiagnostics:
            NotificationCenter.default.post(name: .gciToggleSidebar, object: nil)

        case .pause:
            if stateMachine.currentState is PlayingState {
                stateMachine.enter(PausedState.self)
            } else if stateMachine.currentState is PausedState {
                stateMachine.enter(PlayingState.self)
            }

        case .confirmStart:
            if stateMachine.currentState is TitleState {
                stateMachine.enter(PlayingState.self)
            } else if stateMachine.currentState is GameOverState {
                stateMachine.enter(TitleState.self)
            }

        default:
            break   // Phase 2+: route movement, shooting, chess actions
        }
    }

    // MARK: - State Machine

    private func setupStateMachine() {
        let title    = TitleState(scene: self)
        let playing  = PlayingState(scene: self)
        let paused   = PausedState(scene: self)
        let gameOver = GameOverState(scene: self)

        stateMachine = GKStateMachine(states: [title, playing, paused, gameOver])
        stateMachine.enter(TitleState.self)
    }

    // MARK: - Screen Transitions (called by GKState subclasses)

    func showTitleScreen() {
        placeholderBoard?.removeFromParent()
        placeholderBoard = nil

        let overlay = TitleOverlayNode()
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bloomNode.addChild(overlay)
        titleOverlay = overlay

        DiagnosticsLog.shared.log(.level, "State → TITLE")
    }

    func hideTitleScreen() {
        titleOverlay?.removeFromParent()
        titleOverlay = nil
    }

    func showPlaceholderBoard() {
        let board = PlaceholderBoardNode()
        board.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bloomNode.addChild(board)
        placeholderBoard = board

        DiagnosticsLog.shared.log(.level, "State → PLAYING")
        DiagnosticsLog.shared.log(.startup, "Phase 0 placeholder board shown")
    }

    func showPausedOverlay() {
        // Phase 0: simple "PAUSED" label; proper pause menu in Phase 5
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.name = "pausedLabel"
        label.text = "PAUSED"
        label.fontSize = 36
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode   = .center
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bloomNode.addChild(label)
        DiagnosticsLog.shared.log(.level, "State → PAUSED")
    }

    func hidePausedOverlay() {
        bloomNode.childNode(withName: "pausedLabel")?.removeFromParent()
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        stateMachine.update(deltaTime: currentTime)   // Phase 2+: pass dt
    }

    // MARK: - Input Forwarding (macOS)

    override func keyDown(with event: NSEvent) {
        let inTitle = stateMachine.currentState is TitleState
        InputHandler.shared.handleKeyDown(event, inTitleScreen: inTitle)
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

@MainActor
extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        // Phase 3+: laser/piece, shot/ship, ship/projectile contacts
    }
}
