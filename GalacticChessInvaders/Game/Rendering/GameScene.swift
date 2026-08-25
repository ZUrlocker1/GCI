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
    private var boardNode: BoardNode?
    private var ship: SpaceshipNode?
    private var hudNode: HUDNode?
    private var howToPlayNode: HowToPlayNode?

    /// Live piece sprites keyed by the square they occupy.
    private var pieceNodes: [String: PieceNode] = [:]

    // MARK: - State

    private(set) var stateMachine: GKStateMachine!
    private var lastUpdateTime: TimeInterval = 0

    private let board = GCIBoard()
    private let levels = LevelManager()
    private let turnTimer = TurnTimer()
    private var turnTimerNode: TurnTimerNode?
    private var statusNode: GameStatusNode?
    private var testModeLabel: SKLabelNode?
    private var gameOverNode: GameOverNode?
    private var highScoreEntry: HighScoreEntryNode?
    /// One name entry per game. `isHighScore` stays true while the table has free
    /// slots, so without this the prompt reappeared immediately after submitting
    /// and there was no way out of it. Set when the prompt is *shown*, not when it
    /// is submitted, so no path can produce a second one.
    private var hasOfferedHighScore = false
    /// True while the wave-clear overlay is up, waiting for a key to continue.
    private var isAwaitingWaveContinue = false
    /// How the last game ended, for the game-over overlay.
    private var outcome: GameOverNode.Outcome = .whiteMated
    /// Last banner state, so the check alarm fires on the transition only.
    private var lastStatus: GameStatusNode.Status = .none
    /// The king currently lit red, so it can be cleared when check resolves.
    private weak var glowingKing: PieceNode?
    /// Last countdown value sounded, so the warning ticks once per second.
    private var lastTickedSecond = -1
    private var selectedSquare: String?
    private var isEngineThinking = false

    /// True once White has moved in the current beat. White may move at any point
    /// during the beat, but Black always replies at the beat's end — moving early
    /// does not hand Black extra turns (§3).
    private var whiteHasMovedThisBeat = false
    /// Set while Black's moves are resolving, to lock out input.
    private var isResolvingBeat = false
    /// Set from mate/stalemate detection until the game-over screen appears, so
    /// the reveal is not interrupted by a new beat or stray input.
    private var isEndingGame = false

    // Board sits above the ship lane, below the HUD.
    private static let boardBottomY: CGFloat = 120
    private static let shipLaneY: CGFloat = 62
    private static let shipMargin: CGFloat = 30
    /// Time between detecting mate and showing the game-over screen. The mating
    /// path takes ~1.5s to draw and pulse; the remainder is stillness so the
    /// player can take in what happened before a menu replaces it.
    private static let gameEndRevealDelay: TimeInterval = 2.5
    /// Countdown for the end-of-game hold. Driven from `update` rather than an
    /// SKAction: an action on the scene can be cleared or stalled by unrelated
    /// scene work, and a plain deadline is both deterministic and testable.
    private var revealRemaining: TimeInterval = 0
    private var pendingReveal: (() -> Void)?
    /// Hidden test mode: White auto-moves on a short beat so a whole game plays
    /// out without waiting on the countdown, but slowly enough to follow.
    private static let testBeatDuration: TimeInterval = 1.0
    /// Awarded for checkmating Black (§Scoring), before the level multiplier.
    private static let checkmateBonus = 300
    private var isTestMode = false

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

        // One texture shared by every star. Sprites that share a texture and blend
        // mode batch into a single draw call; the SKShapeNode circles this replaced
        // could not batch at all, so ~170 stars cost ~170 draw calls (§18 budget: 5).
        let dot = Self.makeStarTexture()

        // Parallax tiers. `drift` is sideways travel per screen-height fall, as a
        // fraction of it: 0.30 leans about 17°. The distant tier falls straight
        // as a reference, and the two nearer tiers lean opposite ways so nothing
        // reads as a single uniform sheet.
        addStarLayer(texture: dot, count: 46, speed: 20,  alpha: 0.34,
                     starSize: 1.5, drift:  0.00, twinkleShare: 0.20)   // distant, vertical
        addStarLayer(texture: dot, count: 26, speed: 58,  alpha: 0.62,
                     starSize: 2.4, drift:  0.30, twinkleShare: 0.30)   // mid, leans right
        addStarLayer(texture: dot, count: 12, speed: 140, alpha: 0.92,
                     starSize: 3.4, drift: -0.16, twinkleShare: 0.45)   // near, leans left

        DiagnosticsLog.shared.log(.startup,
            "Starfield: 3 tiers, \(starfieldNode.children.reduce(0) { $0 + $1.children.count })"
            + " batched sprites, \(starfieldNode.children.count) scroll actions")
    }

    /// A soft round dot: solid core fading to transparent, drawn once at launch.
    /// Additive blending then makes overlapping stars brighten naturally.
    private static func makeStarTexture(diameter: CGFloat = 16) -> SKTexture {
        let pixels = Int(diameter)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }

        let colors = [
            CGColor(red: 1, green: 1, blue: 1, alpha: 1.0),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.75),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors,
                                       locations: [0.0, 0.4, 1.0]) else { return SKTexture() }

        let centre = CGPoint(x: diameter / 2, y: diameter / 2)
        context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                                   endCenter: centre, endRadius: diameter / 2,
                                   options: [])

        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }

    /// One parallax tier, built as two identical copies of a single random layout.
    ///
    /// The copies sit exactly one tier-period apart and swap slots each cycle. Both
    /// the positions *and* the twinkle phases are shared, so at the swap frame the
    /// two copies are pixel-identical and the handoff is invisible. (Giving them
    /// different layouts — as this did before — replaced the whole field in one
    /// frame, which read as the animation restarting.)
    private func addStarLayer(texture: SKTexture, count: Int, speed: CGFloat,
                              alpha: CGFloat, starSize: CGFloat,
                              drift: CGFloat, twinkleShare: Double) {
        let sceneW = size.width
        let sceneH = size.height

        // Neon palette: mostly white, accent cyan, hint of magenta
        let palette: [SKColor] = [
            .white, .white, .white, .white, .white,
            SKColor(red: 0.07, green: 0.88, blue: 1.00, alpha: 1),  // cyan
            SKColor(red: 0.07, green: 0.88, blue: 1.00, alpha: 1),  // cyan (doubled weight)
            SKColor(red: 1.00, green: 0.13, blue: 0.38, alpha: 1),  // magenta
        ]

        // Faster tiers twinkle more snappily.
        let twinklePeriod = max(0.4, 1.8 - Double(speed) / 160.0)

        struct Star {
            let position: CGPoint
            let color: SKColor
            let scale: CGFloat
            /// Fraction of the twinkle cycle to wait before starting, so stars are
            /// not in lockstep. Shared by both copies to keep them in phase.
            let twinklePhase: Double?
        }

        // A leaning tier offsets its two copies horizontally, which would leave
        // empty wedges at the screen edges mid-cycle. Spawn stars across a band
        // wider than the screen by the drift distance on each side, and scale the
        // count to keep density constant.
        let margin = abs(drift * sceneH)
        let spawnWidth = sceneW + margin * 2
        let scaledCount = Int((Double(count) * Double(spawnWidth / sceneW)).rounded())

        let layout: [Star] = (0..<scaledCount).map { _ in
            Star(
                position: CGPoint(x: .random(in: -margin...(sceneW + margin)),
                                  y: .random(in: 0...sceneH)),
                color: palette[Int.random(in: 0..<palette.count)],
                // Slight size jitter so a tier does not read as one uniform grade.
                scale: .random(in: 0.75...1.3),
                twinklePhase: Double.random(in: 0...1) < twinkleShare
                    ? Double.random(in: 0...(twinklePeriod * 2))
                    : nil
            )
        }

        let tiling = StarfieldTiling(sceneHeight: sceneH, drift: drift)
        let cycleDuration = Double(sceneH) / Double(speed)
        let scroll = SKAction.moveBy(x: tiling.scroll.dx, y: tiling.scroll.dy,
                                     duration: cycleDuration)
        let rewind = SKAction.moveBy(x: -tiling.scroll.dx, y: -tiling.scroll.dy,
                                     duration: 0)
        let loop = SKAction.repeatForever(SKAction.sequence([scroll, rewind]))

        for slot in [tiling.slotA, tiling.slotB] {
            let layer = SKNode()
            layer.position = slot

            for star in layout {
                let node = SKSpriteNode(texture: texture)
                let side = starSize * 2 * star.scale
                node.size = CGSize(width: side, height: side)
                node.position = star.position
                node.color = star.color
                node.colorBlendFactor = 1.0
                node.blendMode = .add
                node.alpha = alpha

                if let phase = star.twinklePhase {
                    node.run(SKAction.sequence([
                        SKAction.wait(forDuration: phase),
                        SKAction.repeatForever(SKAction.sequence([
                            SKAction.fadeAlpha(to: alpha * 0.25, duration: twinklePeriod),
                            SKAction.fadeAlpha(to: alpha,        duration: twinklePeriod)
                        ]))
                    ]))
                }
                layer.addChild(node)
            }

            starfieldNode.addChild(layer)
            layer.run(loop)
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

        case .moveLeft:   ship?.direction = -1
        case .moveRight:  ship?.direction =  1
        case .stopMoving: ship?.direction =  0

        case .selectPieceAt(let square):
            selectPiece(at: square)

        case .movePieceTo(let square):
            moveSelectedPiece(to: square)

        case .deselectPiece:
            clearSelection()

        case .showInfo:
            showHowToPlay()

        case .dismissOverlay:
            hideHowToPlay()

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
        // Defensive: remove any stale overlay before adding a new one (prevents double-overlay on restart)
        titleOverlay?.removeFromParent()
        titleOverlay = nil
        hideBoard()

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

    func showHUD() {
        guard hudNode == nil else { return }
        let hud = HUDNode(sceneWidth: size.width)
        hud.position = CGPoint(x: 0, y: size.height - HUDNode.height)
        hud.zPosition = 10
        addChild(hud)
        hudNode = hud
        hud.updateLives(3)
        hud.updateLevel(1)
        DiagnosticsLog.shared.log(.startup, "HUD displayed")
    }

    func hideHUD() {
        hudNode?.removeFromParent()
        hudNode = nil
    }

    func showHowToPlay() {
        guard howToPlayNode == nil else { return }
        let overlay = HowToPlayNode(sceneSize: size)
        overlay.position = .zero
        overlay.zPosition = 20
        addChild(overlay)
        howToPlayNode = overlay

        // Opening it during gameplay pauses immediately (§10): freeze the beat,
        // stop the ship drifting, and duck the music.
        if stateMachine.currentState is PlayingState {
            turnTimer.pause()
            ship?.direction = 0
            isPaused = true
            AudioManager.shared.pauseMusic()
        }
        DiagnosticsLog.shared.log(.startup, "How To Play shown (game paused)")
    }

    /// Dismisses the overlay and resumes from the exact state play was in (§10).
    func hideHowToPlay() {
        guard howToPlayNode != nil else { return }
        howToPlayNode?.removeFromParent()
        howToPlayNode = nil

        if stateMachine.currentState is PlayingState {
            isPaused = false
            turnTimer.resume()
            AudioManager.shared.resumeMusic()
            // Discard the frame the pause spanned so the beat doesn't jump.
            lastUpdateTime = 0
        }
        DiagnosticsLog.shared.log(.startup, "How To Play dismissed (resumed)")
    }

    func resetToTitle() {
        howToPlayNode?.removeFromParent(); howToPlayNode = nil
        titleOverlay?.removeFromParent(); titleOverlay = nil
        // Clear any pause the info overlay applied, or the title screen would
        // arrive with its animations frozen.
        isPaused = false
        lastUpdateTime = 0
        hideHUD()
        hideBoard()
        bloomNode.childNode(withName: "pausedLabel")?.removeFromParent()
        AudioManager.shared.stopMusic()
        DiagnosticsLog.shared.clear()
        DiagnosticsLog.shared.log(.restart, "")
        stateMachine.enter(TitleState.self)
    }

    /// Hidden developer aid: White stops waiting for the player and the beat
    /// collapses to a fraction of a second, so a whole game plays through quickly.
    private func toggleTestMode() {
        setTestMode(!isTestMode, retimingBeat: true)
    }

    /// Idempotent. `retimingBeat` restarts the beat in flight so a toggle takes
    /// effect immediately; the automatic switch-off at mate skips that, since the
    /// beat is about to stop anyway.
    private func setTestMode(_ on: Bool, retimingBeat: Bool) {
        guard on != isTestMode else { return }
        isTestMode = on
        testModeLabel?.isHidden = !on
        DiagnosticsLog.shared.log(.restart, on ? "TEST MODE ON" : "TEST MODE OFF")

        guard retimingBeat, turnTimer.isRunning, !isEndingGame else { return }
        turnTimer.start(level: levels.parameters,
                        inCheck: board.turn == .white && board.isCheck,
                        override: on ? Self.testBeatDuration : nil)
    }

    /// Straight into a fresh game, skipping the title screen — the Y answer to
    /// the game-over prompt.
    func startNewGame() {
        isPaused = false
        lastUpdateTime = 0
        hideHUD()
        hideBoard()
        bloomNode.childNode(withName: "pausedLabel")?.removeFromParent()
        // GameOverState stopped the music; start it fresh rather than leaving silence.
        AudioManager.shared.playMusic("GCI-intro")
        DiagnosticsLog.shared.log(.restart, "new game")
        stateMachine.enter(PlayingState.self)
    }

    // MARK: - Board & Ship

    /// A brand new game: score and level reset.
    func showBoard() {
        levels.reset()
        hasOfferedHighScore = false
        ScoreManager.shared.resetForNewGame()
        buildPlayfield()
        DiagnosticsLog.shared.log(.level, "State → PLAYING")
    }

    /// The next wave: level and multiplier step up, score carries over.
    private func startNextLevel() {
        levels.advance()
        ScoreManager.shared.advanceLevel()
        buildPlayfield()
        DiagnosticsLog.shared.log(.level,
            "Level \(levels.level) — beat \(Int(levels.parameters.turnTimer))s, "
            + "\(levels.parameters.blackMovesPerTurn) black move(s)/turn")
    }

    private func buildPlayfield() {
        hideBoard()
        board.setupStandardPosition()

        let node = BoardNode()
        node.position = CGPoint(x: (size.width - BoardNode.boardSize) / 2, y: Self.boardBottomY)
        bloomNode.addChild(node)
        boardNode = node

        for piece in board.allPieces() { addPieceNode(piece) }

        let player = SpaceshipNode()
        player.position = CGPoint(x: size.width / 2, y: Self.shipLaneY)
        bloomNode.addChild(player)
        ship = player

        // Countdown lives in the gutter left of the board (§19), with the
        // check/mate banner directly beneath it.
        let timerDisplay = TurnTimerNode()
        timerDisplay.position = CGPoint(x: 112, y: Self.boardBottomY + 46)
        timerDisplay.isHidden = true
        bloomNode.addChild(timerDisplay)
        turnTimerNode = timerDisplay

        let status = GameStatusNode()
        status.position = CGPoint(x: 112, y: Self.boardBottomY - 4)
        bloomNode.addChild(status)
        statusNode = status

        let testLabel = SKLabelNode(fontNamed: "PressStart2P-Regular")
        testLabel.text = "TEST MODE"
        testLabel.fontSize = 9
        testLabel.fontColor = SKColor(red: 1.00, green: 0.73, blue: 0.12, alpha: 1)
        testLabel.horizontalAlignmentMode = .center
        testLabel.verticalAlignmentMode = .center
        testLabel.position = CGPoint(x: 112, y: Self.boardBottomY + 46)
        testLabel.isHidden = !isTestMode
        testLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1.0, duration: 0.6),
        ])))
        bloomNode.addChild(testLabel)
        testModeLabel = testLabel

        refreshHUD()
        beginBeat()
    }

    private func refreshHUD() {
        hudNode?.updateLevel(levels.level)
        hudNode?.updateScore(ScoreManager.shared.currentScore)
        // Arcade convention: HI tracks the best ever, or your run once you pass it.
        let best = ScoreManager.shared.topHighScores(limit: 1).first?.score ?? 0
        hudNode?.updateHiScore(max(best, ScoreManager.shared.currentScore))
    }

    func hideBoard() {
        hideGameOverOverlay()
        boardNode?.clearCheckPaths()
        boardNode?.removeFromParent()
        boardNode = nil
        ship?.removeFromParent()
        ship = nil
        turnTimerNode?.removeFromParent()
        turnTimerNode = nil
        statusNode?.removeFromParent()
        statusNode = nil
        testModeLabel?.removeFromParent()
        testModeLabel = nil
        pieceNodes.removeAll()
        selectedSquare = nil
        isEngineThinking = false
        pendingReveal = nil
        revealRemaining = 0
        isAwaitingWaveContinue = false
        isEndingGame = false
        isResolvingBeat = false
        whiteHasMovedThisBeat = false
        // Reset, or a game that ended in check would swallow the next game's alarm.
        glowingKing?.setCheckGlow(false)
        glowingKing = nil
        lastStatus = .none
        lastTickedSecond = -1
        turnTimer.stop()
    }

    // MARK: - Chess Beat

    /// True only when the player can legally act on the current beat.
    private var isAwaitingWhiteMove: Bool {
        turnTimer.isRunning
            && !whiteHasMovedThisBeat
            && !isResolvingBeat
            && board.turn == .white
    }

    /// One tick per whole second through the final two seconds of the beat.
    private func tickTimerWarning() {
        guard turnTimer.isWarning else {
            lastTickedSecond = -1
            return
        }
        let second = turnTimer.displaySeconds
        guard second != lastTickedSecond else { return }
        lastTickedSecond = second
        AudioManager.shared.play(.turnTimerWarning)
    }

    /// Starts a beat. Check state is read once here, after Black has finished
    /// moving, which is what grants the 8-second extension (§25.4).
    private func beginBeat() {
        whiteHasMovedThisBeat = false
        let inCheck = board.turn == .white && board.isCheck
        turnTimer.start(level: levels.parameters, inCheck: inCheck,
                        override: isTestMode ? Self.testBeatDuration : nil)
        turnTimerNode?.refresh(from: turnTimer)
        if inCheck {
            // The timer already shows CHECK, so the extension needs no log line.
            DiagnosticsLog.shared.log(.white, "in check")
        }
    }

    /// Beat expired: auto-move White if the player didn't move, then let Black reply.
    private func resolveBeat() async {
        guard !isResolvingBeat else { return }
        isResolvingBeat = true
        defer { isResolvingBeat = false }

        if !whiteHasMovedThisBeat {
            let target = selectedSquare
            clearSelection()
            isEngineThinking = true
            let auto = await board.makeEngineMove(
                constraints: .init(restrictedTo: target),
                annotation: "auto")
            isEngineThinking = false

            if let auto {
                AudioManager.shared.play(.autoMoveTrigger)
                apply(auto)
                flashAuto(at: auto.to)
            } else if endGameIfDecided() {
                return
            }
        }

        await playBlackMoves()

        guard stateMachine.currentState is PlayingState else { return }
        if endGameIfDecided() { return }
        beginBeat()
    }

    /// Ends the game if the side to move has no legal moves. Returns true if it did.
    ///
    /// `board` reports mate for whoever must move, so this covers both directions:
    /// White mated is a loss, Black mated is the player's win.
    @discardableResult
    private func endGameIfDecided() -> Bool {
        let loser = board.turn
        guard board.isMate || board.isStalemate else { return false }

        // A test run has served its purpose once the game reaches a conclusion,
        // so it does not silently carry into the next one.
        setTestMode(false, retimingBeat: false)

        if board.isMate, loser == .black {
            clearWave()
            return true
        }
        if board.isMate {
            outcome = .whiteMated
        } else {
            outcome = .stalemate
        }
        DiagnosticsLog.shared.log(loser.logCategory, outcome.detail.lowercased())

        // Hold on the board first. `refreshStatus` has already drawn the mating
        // path and lit the king; let that play out, with the sting landing on the
        // reveal rather than on the menu.
        isEndingGame = true
        turnTimer.stop()
        clearSelection()
        AudioManager.shared.play(outcome == .blackMated ? .levelClear : .gameOver)

        scheduleAfterReveal { [weak self] in
            guard let self, self.stateMachine.currentState is PlayingState else { return }
            self.stateMachine.enter(GameOverState.self)
        }
        return true
    }

    /// Black is checkmated: the wave is cleared, not the game won (§4). Award the
    /// bonus, hold on the mating position, then start the next level.
    private func clearWave() {
        isEndingGame = true
        turnTimer.stop()
        clearSelection()

        ScoreManager.shared.addPoints(Self.checkmateBonus, source: "checkmate")
        refreshHUD()
        AudioManager.shared.play(.levelClear)
        DiagnosticsLog.shared.log(.level, "WAVE CLEAR — black is checkmated")

        scheduleAfterReveal { [weak self] in
            guard let self, self.stateMachine.currentState is PlayingState else { return }
            self.showWaveClearOverlay()
        }
    }

    /// A win deserves acknowledgement rather than rolling silently into the next
    /// wave. Any key continues.
    private func showWaveClearOverlay() {
        guard gameOverNode == nil else { return }
        outcome = .waveCleared(next: levels.level + 1)
        let overlay = GameOverNode(outcome: outcome,
                                   score: ScoreManager.shared.currentScore,
                                   sceneSize: size)
        overlay.zPosition = 25
        addChild(overlay)
        gameOverNode = overlay
        isAwaitingWaveContinue = true
        DiagnosticsLog.shared.log(.level, "wave clear — awaiting continue")
    }

    /// Holds on the final position for `gameEndRevealDelay` before running `action`.
    private func scheduleAfterReveal(_ action: @escaping () -> Void) {
        revealRemaining = Self.gameEndRevealDelay
        pendingReveal = action
        DiagnosticsLog.shared.log(.level,
            "holding \(String(format: "%.1f", Self.gameEndRevealDelay))s before continuing")
    }

    /// Ticks the hold. Returns true while it is still running.
    private func advanceReveal(_ dt: TimeInterval) -> Bool {
        guard let action = pendingReveal else { return false }
        revealRemaining -= dt
        guard revealRemaining <= 0 else { return true }
        pendingReveal = nil
        revealRemaining = 0
        action()
        return false
    }

    /// Black's moves for this beat. §25.5 forbids reusing a source piece or a
    /// destination square within the phase; if fewer non-conflicting moves exist,
    /// Black simply makes fewer.
    private func playBlackMoves() async {
        guard board.turn == .black else { return }
        var usedSources: Set<String> = []
        var usedDestinations: Set<String> = []

        isEngineThinking = true
        defer { isEngineThinking = false }

        for _ in 0..<levels.parameters.blackMovesPerTurn {
            guard board.turn == .black else { break }
            let outcome = await board.makeEngineMove(
                constraints: .init(excludedSources: usedSources,
                                   excludedDestinations: usedDestinations))
            guard let outcome else { break }
            apply(outcome)
            usedSources.insert(outcome.from)
            usedDestinations.insert(outcome.to)
        }
    }

    /// Orange "AUTO" over the piece the engine moved, 0.5s (§19).
    private func flashAuto(at square: String) {
        guard let boardNode, let point = boardNode.center(of: square) else { return }
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.text = "AUTO"
        label.fontSize = 12
        label.fontColor = SKColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: point.x, y: point.y + BoardNode.squareSize * 0.55)
        label.zPosition = 30
        boardNode.addChild(label)
        label.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
    }

    private func addPieceNode(_ piece: Piece) {
        guard let boardNode, let point = boardNode.center(of: piece.logicalSquare) else { return }
        let node = PieceNode(piece: piece, squareSize: BoardNode.squareSize)
        node.position = point
        boardNode.addChild(node)
        pieceNodes[piece.logicalSquare] = node
        // Staggered so the board breathes rather than pulsing as one block.
        node.startIdleBob(phase: TimeInterval.random(in: 0...0.8))
    }

    // MARK: - Chess Interaction

    private func selectPiece(at square: String) {
        guard canAcceptChessInput,
              let piece = board.piece(at: square),
              piece.color == .white else { return }

        selectedSquare = square
        let destinations = board.legalDestinations(from: square)
        let captures = Set(destinations.filter { board.piece(at: $0) != nil })
        boardNode?.showSelection(at: square)
        boardNode?.showLegalMoves(destinations, captures: captures)
        AudioManager.shared.play(.pieceSelected)
    }

    private func moveSelectedPiece(to square: String) {
        guard canAcceptChessInput, let from = selectedSquare else { return }

        // Clicking the selection again cancels it; clicking another own piece re-targets.
        if square == from {
            clearSelection()
            return
        }
        guard let outcome = board.applyChessMove(from: from, to: square) else {
            AudioManager.shared.play(.illegalMove)
            clearSelection()
            if board.piece(at: square)?.color == .white { selectPiece(at: square) }
            return
        }

        clearSelection()
        apply(outcome)
        whiteHasMovedThisBeat = true
        // Black replies when the beat ends, not now — moving early must not
        // hand Black extra turns (§3).
    }

    private func clearSelection() {
        selectedSquare = nil
        boardNode?.clearMarkers()
    }

    private var canAcceptChessInput: Bool {
        stateMachine.currentState is PlayingState
            && howToPlayNode == nil
            && !isEndingGame
            && !isEngineThinking
            && !isResolvingBeat
            && !whiteHasMovedThisBeat        // one White move per beat
            && board.turn == .white
    }

    /// Mirrors a logic-layer move onto the sprite layer.
    private func apply(_ outcome: MoveOutcome) {
        guard let boardNode, let point = boardNode.center(of: outcome.to) else { return }

        // Use the captured square, not the destination — en passant differs.
        if let capturedSquare = outcome.capturedSquare,
           let victim = pieceNodes.removeValue(forKey: capturedSquare) {
            victim.runDestructionAnimation {}
        }

        // Only the player's captures score; Black taking White pieces must not
        // reward the player.
        if let captured = outcome.captured, captured.color == .black {
            ScoreManager.shared.addPoints(captured.type.pointValue)
            refreshHUD()
            DiagnosticsLog.shared.log(.score,
                "Captured \(captured.type) +\(captured.type.pointValue) → \(ScoreManager.shared.currentScore)")
        }

        // Capture reads over the move, so play only the louder of the two.
        if outcome.captured != nil {
            AudioManager.shared.play(.pieceHitHeavy)
        } else {
            AudioManager.shared.play(outcome.moved.color == .white
                                     ? .whitePieceMoves : .blackPieceMoves)
        }

        guard let node = pieceNodes.removeValue(forKey: outcome.from) else { return }
        node.refresh(with: outcome.moved)
        node.animateMove(to: outcome.to, point: point)
        pieceNodes[outcome.to] = node

        // Castling: slide the rook across at the same time.
        if let rookMove = outcome.rookMove,
           let rook = pieceNodes.removeValue(forKey: rookMove.from),
           let rookPoint = boardNode.center(of: rookMove.to) {
            rook.animateMove(to: rookMove.to, point: rookPoint)
            pieceNodes[rookMove.to] = rook
        }

        if outcome.promotedTo != nil { AudioManager.shared.play(.pawnPromotion) }

        refreshStatus()
    }

    /// Lights the king of `side` red, clearing any previously lit king. Passing
    /// nil clears. The glow lives on the piece node, so it follows the king if it
    /// moves while still in check.
    private func setKingGlow(for side: PieceColor?) {
        glowingKing?.setCheckGlow(false)
        glowingKing = nil
        guard let side,
              let threat = board.checkThreat(against: side),
              let king = pieceNodes[threat.kingSquare] else { return }
        king.setCheckGlow(true)
        glowingKing = king
    }

    /// Traces each checking piece to the king, so the player can see where the
    /// threat comes from — the board draws no grid to read it off.
    private func showCheckPaths(against side: PieceColor, pulses: Int = 2) {
        guard let boardNode, let threat = board.checkThreat(against: side) else { return }
        let paths = threat.attackers.map {
            (from: $0.square, to: threat.kingSquare, isJump: $0.kind == .knight)
        }
        // Magenta when the player is the one in trouble, cyan when Black is.
        let color: SKColor = side == .white
            ? SKColor(red: 1.00, green: 0.13, blue: 0.38, alpha: 1)
            : SKColor(red: 0.07, green: 0.88, blue: 1.00, alpha: 1)
        boardNode.showCheckPaths(paths, color: color, pulses: pulses)
    }

    /// Check / mate banner. `board` reports all three for the side to move, so
    /// after a move it describes whoever must now respond.
    private func refreshStatus() {
        let status: GameStatusNode.Status
        if board.isMate {
            status = .checkmate(board.turn)
        } else if board.isCheck {
            status = .check(board.turn)
        } else if board.isStalemate {
            status = .stalemate
        } else {
            status = .none
        }
        // Only fire on the transition, not on every refresh.
        if status != lastStatus {
            switch status {
            case .check(let side):
                AudioManager.shared.play(.checkAlarm)
                showCheckPaths(against: side)
                setKingGlow(for: side)
            case .checkmate(let side):
                // Keep the king lit, and trace the mating piece with extra
                // pulses — this is the moment the game turns on.
                setKingGlow(for: side)
                showCheckPaths(against: side, pulses: 3)
            case .none, .stalemate:
                boardNode?.clearCheckPaths()
                setKingGlow(for: nil)
            }
            lastStatus = status
        }
        statusNode?.show(status)
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

    // MARK: - Game Over

    func showGameOverOverlay() {
        guard gameOverNode == nil, highScoreEntry == nil else { return }
        turnTimer.stop()
        clearSelection()
        ship?.direction = 0

        // A run that made the table gets to sign it — once — before the menu.
        if !hasOfferedHighScore,
           ScoreManager.shared.isHighScore,
           ScoreManager.shared.currentScore > 0 {
            showHighScoreEntry()
            return
        }

        let overlay = GameOverNode(outcome: outcome,
                                   score: ScoreManager.shared.currentScore,
                                   sceneSize: size)
        overlay.zPosition = 25
        addChild(overlay)
        gameOverNode = overlay
        DiagnosticsLog.shared.log(.level, "\(outcome.headline) — final score: \(ScoreManager.shared.currentScore)")
    }

    func hideGameOverOverlay() {
        gameOverNode?.removeFromParent()
        gameOverNode = nil
        highScoreEntry?.removeFromParent()
        highScoreEntry = nil
    }

    private func showHighScoreEntry() {
        // Claim the offer up front: `isHighScore` remains true after submitting,
        // so anything that re-enters this path would otherwise prompt again.
        hasOfferedHighScore = true

        let entry = HighScoreEntryNode(score: ScoreManager.shared.currentScore,
                                       level: levels.level,
                                       sceneSize: size)
        entry.zPosition = 26
        entry.onSubmit = { [weak self] name in
            guard let self else { return }
            ScoreManager.shared.submitHighScore(initials: name)
            self.highScoreEntry?.removeFromParent()
            self.highScoreEntry = nil
            self.refreshHUD()
            self.showGameOverOverlay()
        }
        addChild(entry)
        highScoreEntry = entry
        AudioManager.shared.play(.pawnPromotion)
        DiagnosticsLog.shared.log(.score, "high score — awaiting name")
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        stateMachine.update(deltaTime: currentTime)

        let dt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        if dt > 0, stateMachine.currentState is PlayingState {
            let lane = Self.shipMargin...(size.width - Self.shipMargin)
            ship?.update(deltaTime: dt, bounds: lane)

            // The end-of-game hold owns the beat while it runs.
            if advanceReveal(dt) {
                turnTimerNode?.isHidden = true
                #if DEBUG
                if dt > 0 {
                    DiagnosticsLog.shared.fps = (1.0 / dt).rounded()
                    DiagnosticsLog.shared.nodeCount = countAllNodes()
                }
                #endif
                return
            }

            // Invariant, enforced here rather than at every call site: if it is
            // White's move and no beat is running, start one. `resolveBeat` has
            // several early returns — pausing while Black was thinking used to
            // leave the game with no live beat and no way to move again.
            if !isEndingGame, !isResolvingBeat, board.turn == .white, !turnTimer.isRunning {
                beginBeat()
            }

            // The chess beat. Arcade action keeps running while it ticks —
            // the game never pauses for chess (§3).
            if turnTimer.update(deltaTime: dt) {
                Task { await self.resolveBeat() }
            }
            // The countdown is the player's own clock, so it appears only while
            // White may still move: not while Black is thinking, and not after
            // White has already moved this beat.
            // In test mode the beat is far too short to read, so the slot shows
            // TEST MODE instead of a countdown flickering on and off.
            let awaitingWhite = isAwaitingWhiteMove
            turnTimerNode?.isHidden = isTestMode || !awaitingWhite
            testModeLabel?.isHidden = !isTestMode
            if awaitingWhite, !isTestMode {
                tickTimerWarning()
                turnTimerNode?.refresh(from: turnTimer)
            } else {
                lastTickedSecond = -1
            }
        }

        #if DEBUG
        if dt > 0 {
            DiagnosticsLog.shared.fps = (1.0 / dt).rounded()
            DiagnosticsLog.shared.nodeCount = countAllNodes()
        }
        #endif
    }

    private func countAllNodes() -> Int {
        var count = 0
        var stack = Array(children)
        while !stack.isEmpty {
            let node = stack.removeLast()
            count += 1
            stack.append(contentsOf: node.children)
        }
        return count
    }

    // MARK: - Input Forwarding (macOS)

    override func keyDown(with event: NSEvent) {
        // X: hard restart — from How To Play, Pause, or straight out of play.
        // Deliberately does not touch the high score table.
        if howToPlayNode != nil
            || stateMachine.currentState is PausedState
            || stateMachine.currentState is PlayingState,
           event.charactersIgnoringModifiers?.lowercased() == "x" {
            resetToTitle()
            return
        }

        // While How To Play is open, any key dismisses it (§10).
        if howToPlayNode != nil {
            InputHandler.shared.handleOverlayKeyDown()
            return
        }

        // Name entry owns the keyboard while it is up.
        if let highScoreEntry {
            highScoreEntry.handleKey(event)
            return
        }

        // Wave clear: any key moves on to the next level.
        if isAwaitingWaveContinue {
            isAwaitingWaveContinue = false
            hideGameOverOverlay()
            startNextLevel()
            return
        }

        // Hidden test mode: T plays White automatically on a very short beat.
        if stateMachine.currentState is PlayingState,
           event.charactersIgnoringModifiers?.lowercased() == "t" {
            toggleTestMode()
            return
        }

        // Game over: Y starts a fresh game, anything else returns to the title.
        if stateMachine.currentState is GameOverState {
            if event.charactersIgnoringModifiers?.lowercased() == "y" {
                startNewGame()
            } else {
                resetToTitle()
            }
            return
        }

        let inTitle = stateMachine.currentState is TitleState
        InputHandler.shared.handleKeyDown(event, inTitleScreen: inTitle)
    }

    override func keyUp(with event: NSEvent) {
        InputHandler.shared.handleKeyUp(event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)

        // How To Play overlay intercepts all clicks; BACK closes it.
        if howToPlayNode != nil {
            let hit = atPoint(location)
            if hit.name == "backButton" || hit.parent?.name == "backButton" {
                AudioManager.shared.play(.uiButtonClick)
                hideHowToPlay()
            }
            return
        }

        // INFO button opens How To Play from any game state.
        let hit = atPoint(location)
        if hit.name == "infoButton" || hit.parent?.name == "infoButton" {
            AudioManager.shared.play(.uiButtonClick)
            showHowToPlay()
            return
        }

        // The scene owns the board geometry, so it resolves the click to a square
        // and lets the input layer decide whether that's a pick or a destination.
        if let boardNode, stateMachine.currentState is PlayingState {
            let square = boardNode.square(at: boardNode.convert(location, from: self))
            InputHandler.shared.handleBoardClick(square: square, hasSelection: selectedSquare != nil)
            return
        }

        let inTitle = stateMachine.currentState is TitleState
        InputHandler.shared.handleMouseDown(at: location, in: self, inTitleScreen: inTitle)
    }
}

// MARK: - Physics Contact

extension GameScene: @preconcurrency SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        // Phase 3+: laser/piece, shot/ship, ship/projectile contacts
    }
}
