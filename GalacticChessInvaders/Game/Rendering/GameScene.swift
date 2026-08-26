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
    private var autoModeLabel: SKLabelNode?
    private var fleet: FleetController?
    private var shipState: SpaceshipState?
    private var laserPool: LaserPool?
    private var collisionHandler: CollisionHandler?
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
    /// The alarm still machine-gunned when a king was checked, stepped out and was
    /// checked again a ply later, which is the norm in a lopsided endgame.
    private var lastCheckAlarm: TimeInterval = 0
    private static let checkAlarmCooldown: TimeInterval = 3.0
    /// The king currently lit red, so it can be cleared when check resolves.
    private weak var glowingKing: PieceNode?
    /// Last countdown value sounded, so the warning ticks once per second.
    private var lastTickedSecond = -1
    /// Diagnostics are @Observable, so writing them invalidates the sidebar view.
    /// At 60fps that is 60 SwiftUI re-renders a second for numbers nobody can read
    /// that fast, plus a full node-tree walk each time.
    private var lastStatsUpdate: TimeInterval = 0
    private static let statsInterval: TimeInterval = 0.25
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
    /// Hidden Auto Mode: White auto-moves on a short beat so a whole game plays
    /// out without waiting on the countdown, but slowly enough to follow.
    private static let autoBeatDuration: TimeInterval = 1.0
    /// Awarded for checkmating Black (§Scoring), before the level multiplier.
    private static let checkmateBonus = 300
    private static let endBannerName = "endBanner"
    private static let gutterNoticeName = "gutterNotice"
    private static let levelAnnounceKey = "levelAnnounce"
    /// Gap between rounds in one beat's volley (§5.3 fires them as a group).
    private static let volleyStagger: TimeInterval = 0.18
    /// The Level 1 warning shot is once per level (§10.1).
    private var hasFiredWarningShot = false
    /// Beats elapsed this level, for the activated king's firing cadence.
    private var beatsThisLevel = 0
    /// True while the level's mechanic banner is on screen. The beat waits for
    /// it, so an escalation is announced before it is inflicted (§12.11).
    private var isAnnouncingLevel = false
    /// Awarded whenever the black king falls outside of checkmate — shot,
    /// captured, or crushed (§9). Stacks with `checkmateBonus` for the 800-pt
    /// combo when the king dies while a checkmate is also standing.
    private static let kingFallBonus = 500
    private var isAutoMode = false

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

        let handler = CollisionHandler()
        handler.onPlayerLaserHit = { [weak self] laser, node in self?.resolvePlayerLaserHit(laser: laser, node: node) }
        handler.onEnemyShotHit = { [weak self] shot, node in self?.resolveEnemyShotHit(shot: shot, node: node) }
        physicsWorld.contactDelegate = handler
        collisionHandler = handler

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

        // Mostly white, accented cyan, with a couple of blues. The magenta
        // star this replaces read as a dull red speck rather than a distant sun.
        let palette: [SKColor] = [
            .white, .white, .white, .white, .white,
            NeonPalette.cyan,
            NeonPalette.cyan,  // doubled weight
            NeonPalette.starBlueLight,
            NeonPalette.starBlueDeep,
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

        case .fireLaser:
            fireLaserFromShip()

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
            // Music keeps playing — the info screen is a glance, not a break.
        }
        DiagnosticsLog.shared.log(.info, "game paused")
    }

    /// Dismisses the overlay and resumes from the exact state play was in (§10).
    func hideHowToPlay() {
        guard howToPlayNode != nil else { return }
        howToPlayNode?.removeFromParent()
        howToPlayNode = nil

        if stateMachine.currentState is PlayingState {
            isPaused = false
            turnTimer.resume()
            // Discard the frame the pause spanned so the beat doesn't jump.
            lastUpdateTime = 0
        }
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
        removePausedOverlay()
        AudioManager.shared.stopMusic()
        DiagnosticsLog.shared.clear()
        DiagnosticsLog.shared.log(.restart, "")
        stateMachine.enter(TitleState.self)
    }

    /// Hidden developer aid: jump straight to the next level, keeping score and
    /// lives. Rebuilds the playfield exactly as finishing a wave does, but with
    /// no wave-clear overlay and no bonus — it is a shortcut for reaching a
    /// level, not a way to farm one.
    private func skipLevel() {
        guard stateMachine.currentState is PlayingState, !isEndingGame else { return }
        DiagnosticsLog.shared.log(.auto, "SKIP LEVEL → \(levels.level + 1)")
        // buildPlayfield tears the board down and back up, so the notice has to
        // be raised afterwards or it is removed with everything else. The
        // mechanic banner still shows, so a skip is a way to *see* a level's
        // announcement rather than a way past it.
        startNextLevel()
        flashGutterNotice("SKIP LEVEL")
    }

    /// A brief label in the gutter slot AUTO MODE uses, for developer actions
    /// that happen once rather than toggling.
    private func flashGutterNotice(_ text: String) {
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.name = Self.gutterNoticeName
        label.text = text
        label.fontSize = 9
        label.fontColor = NeonPalette.alertOrange
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        // Sits just under the AUTO MODE slot so both can show at once.
        label.position = CGPoint(x: 112, y: Self.boardBottomY + 30)
        label.zPosition = 12
        bloomNode.addChild(label)
        label.run(.sequence([
            .repeat(.sequence([.fadeAlpha(to: 0.35, duration: 0.18),
                               .fadeAlpha(to: 1.00, duration: 0.18)]), count: 3),
            .fadeOut(withDuration: 0.4),
            .removeFromParent(),
        ]))
    }

    /// Hidden developer aid: White stops waiting for the player and the beat
    /// collapses to a fraction of a second, so a whole game plays through quickly.
    private func toggleAutoMode() {
        setAutoMode(!isAutoMode, retimingBeat: true)
    }

    /// Idempotent. `retimingBeat` restarts the beat in flight so a toggle takes
    /// effect immediately; the automatic switch-off at mate skips that, since the
    /// beat is about to stop anyway.
    private func setAutoMode(_ on: Bool, retimingBeat: Bool) {
        guard on != isAutoMode else { return }
        isAutoMode = on
        autoModeLabel?.isHidden = !on
        DiagnosticsLog.shared.log(.auto, on ? "ON" : "OFF")

        guard retimingBeat, turnTimer.isRunning, !isEndingGame else { return }
        turnTimer.start(level: levels.parameters,
                        inCheck: board.turn == .white && board.isCheck,
                        override: on ? Self.autoBeatDuration : nil)
    }

    /// Straight into a fresh game, skipping the title screen — the Y answer to
    /// the game-over prompt.
    func startNewGame() {
        isPaused = false
        lastUpdateTime = 0
        hideHUD()
        hideBoard()
        removePausedOverlay()
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
        shipState = SpaceshipState()
        buildPlayfield()
        DiagnosticsLog.shared.log(.level, "State → PLAYING")
    }

    /// The next wave: level and multiplier step up, score carries over. Lives
    /// carry over too (§8.5) — only the laser cap and invincibility reset.
    private func startNextLevel(announce: Bool = true) {
        levels.advance()
        ScoreManager.shared.advanceLevel()
        shipState?.resetForNewLevel()
        buildPlayfield(announceLevel: announce)
        DiagnosticsLog.shared.log(.level,
            "Level \(levels.level) — beat \(Int(levels.parameters.turnTimer))s, "
            + "\(levels.parameters.blackMovesPerTurn) black move(s)/turn, "
            + "×\(ScoreManager.shared.multiplier)")
    }

    private func buildPlayfield(announceLevel: Bool = true) {
        hideBoard()
        board.setupStandardPosition()
        // §10.1: from Level 7 the black king carries a forcefield worth 50%
        // more hits. Applied here so the extra HP is in place before any node
        // reads it.
        if levels.parameters.kingActivated { board.applyKingForcefield() }

        let node = BoardNode()
        node.position = CGPoint(x: (size.width - BoardNode.boardSize) / 2, y: Self.boardBottomY)
        bloomNode.addChild(node)
        boardNode = node

        let controller = FleetController(board: board, parent: node,
                                         squareSize: BoardNode.squareSize,
                                         level: levels.parameters)
        fleet = controller
        controller.onRankDescended = { [weak self] moves in self?.applyFleetDescent(moves) }
        controller.onCrush = { [weak self] crush in self?.applyCrush(crush) }
        controller.onBreach = { [weak self] square in
            DiagnosticsLog.shared.log(.fleet, "breach — black reached rank 1 at \(square)")
            self?.fleet?.stop()
            self?.loseGame(outcome: .blackBreachedRank1)
        }

        for piece in board.allPieces() { addPieceNode(piece) }
        refreshKingForcefield()
        controller.start()

        let player = SpaceshipNode()
        player.position = CGPoint(x: size.width / 2, y: Self.shipLaneY)
        bloomNode.addChild(player)
        ship = player

        laserPool = LaserPool(parent: bloomNode)

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

        let autoLabel = SKLabelNode(fontNamed: "PressStart2P-Regular")
        autoLabel.text = "AUTO MODE"
        autoLabel.fontSize = 9
        autoLabel.fontColor = NeonPalette.orange
        autoLabel.horizontalAlignmentMode = .center
        autoLabel.verticalAlignmentMode = .center
        autoLabel.position = CGPoint(x: 112, y: Self.boardBottomY + 46)
        autoLabel.isHidden = !isAutoMode
        autoLabel.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1.0, duration: 0.6),
        ])))
        bloomNode.addChild(autoLabel)
        autoModeLabel = autoLabel

        refreshHUD()
        if announceLevel {
            announceLevelThenBegin()
        } else {
            beginBeat()
        }
    }

    /// Level 1 starts straight away; anything above it gets its mechanic banner
    /// first, with the board visible behind it and the beat held until it
    /// leaves (§12.11).
    /// Removes the level banner and cancels its pending timer. Called wherever
    /// the announcement is cut short — a restart, or a pause landing on top of
    /// it — so nothing is left half-shown or still counting down.
    private func dismissLevelBanner() {
        removeAction(forKey: Self.levelAnnounceKey)
        enumerateChildNodes(withName: LevelBannerNode.nodeName) { node, _ in
            node.removeFromParent()
        }
        isAnnouncingLevel = false
    }

    private func announceLevelThenBegin() {
        guard let announcement = LevelManager.announcement(for: levels.level) else {
            beginBeat()
            return
        }

        // Skipping levels with `V` can arrive mid-banner, so clear any previous
        // one rather than stacking illegibly on top of it.
        dismissLevelBanner()

        isAnnouncingLevel = true
        // Nothing should be advancing while the banner explains what is about
        // to happen — both of these run on SKActions and ignore the beat gate.
        fleet?.setPaused(true)
        laserPool?.setPaused(true)
        ship?.direction = 0

        let banner = LevelBannerNode(title: announcement.title,
                                     subtitle: announcement.subtitle,
                                     sceneSize: size)
        addChild(banner)
        DiagnosticsLog.shared.log(.level,
            "\(announcement.title) — \(announcement.subtitle)")

        // Keyed, so a second announcement replaces this timer instead of
        // running alongside it — otherwise the first one to elapse would clear
        // the flag and start the beat while the newer banner was still up.
        run(.sequence([
            .wait(forDuration: LevelBannerNode.totalDuration),
            .run { [weak self] in
                guard let self, self.isAnnouncingLevel else { return }
                self.isAnnouncingLevel = false
                guard self.stateMachine.currentState is PlayingState else { return }
                self.fleet?.setPaused(false)
                self.laserPool?.setPaused(false)
                self.beginBeat()
            },
        ]), withKey: Self.levelAnnounceKey)
    }

    private func refreshHUD() {
        hudNode?.updateLevel(levels.level)
        hudNode?.updateScore(ScoreManager.shared.currentScore)
        // Arcade convention: HI tracks the best ever, or your run once you pass it.
        let best = ScoreManager.shared.topHighScores(limit: 1).first?.score ?? 0
        hudNode?.updateHiScore(max(best, ScoreManager.shared.currentScore))
        if let shipState { hudNode?.updateLives(shipState.lives) }
    }

    func hideBoard() {
        removeEndBanner()
        dismissLevelBanner()
        for node in bloomNode.children where node.name == Self.gutterNoticeName {
            node.removeAllActions()
            node.removeFromParent()
        }
        hasFiredWarningShot = false
        beatsThisLevel = 0
        isAnnouncingLevel = false
        laserPool?.deactivateAll()
        laserPool = nil
        fleet?.reset()
        fleet = nil
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
        autoModeLabel?.removeFromParent()
        autoModeLabel = nil
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

    /// A full-rank descent moved every black piece, so the node map is re-keyed
    /// and each sprite slides to its new logical centre. The moves arrive lowest
    /// rank first, so no piece overwrites one that has not moved yet.
    private func applyFleetDescent(_ moves: [(from: String, to: String)]) {
        guard let boardNode else { return }
        for move in moves {
            guard let node = pieceNodes.removeValue(forKey: move.from),
                  let point = boardNode.center(of: move.to) else { continue }
            node.animateMove(to: move.to, point: point)
            pieceNodes[move.to] = node
        }
        refreshStatus()
    }

    /// A descending black piece landed on a white one: it is gone instantly, no
    /// HP check and no points, because the fleet took it rather than the player.
    private func applyCrush(_ crush: CrushEvent) {
        if let victim = pieceNodes.removeValue(forKey: crush.atSquare) {
            detachFromFleet(victim)
            victim.runDestructionAnimation {}
        }
        AudioManager.shared.play(.pieceHitHeavy)

        // Either king can end up the crush victim — a stalled piece at rank 1
        // is fair game for whatever descends onto it next, kings included.
        guard crush.crushedPiece.type == .king else { return }
        if crush.crushedPiece.color == .black {
            winLevel(bonus: Self.kingFallBonus, label: "king crushed",
                     banner: "BLACK KING DESTROYED")
        } else {
            loseGame(outcome: .whiteKingDestroyed)
        }
    }

    // MARK: - Chess Beat

    /// True when the beat must not advance at all: the game has been decided,
    /// a wave-clear prompt is waiting, or a level banner is still playing.
    ///
    /// Every path that ends a game — `endGameIfDecided`, `winLevel`,
    /// `loseGame` — sets `isEndingGame`, so gating on this one property covers
    /// checkmate, draws, a captured or shot king, lives running out and a rank-1
    /// breach alike.
    private var isBeatSuspended: Bool {
        isEndingGame || isAwaitingWaveContinue || isAnnouncingLevel
    }

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
        // winLevel/loseGame stop the timer; without this guard any caller that
        // runs afterwards silently restarts it and the game plays on.
        guard !isBeatSuspended else { return }
        whiteHasMovedThisBeat = false
        let inCheck = board.turn == .white && board.isCheck
        turnTimer.start(level: levels.parameters, inCheck: inCheck,
                        override: isAutoMode ? Self.autoBeatDuration : nil)
        turnTimerNode?.refresh(from: turnTimer)
        if inCheck {
            // The timer already shows CHECK, so the extension needs no log line.
            DiagnosticsLog.shared.log(.white, "in check")
        }
    }

    /// Beat expired: auto-move White if the player didn't move, then let Black reply.
    private func resolveBeat() async {
        guard !isResolvingBeat, !isBeatSuspended else { return }
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
                // `apply` can end the game outright — White's move may capture
                // the black king, or deliver a mate that `refreshStatus` picks
                // up. `endGameIfDecided` below would not catch a king *capture*,
                // since that is not a chess-legal terminal state, so the beat
                // has to stop here or it plays on over a finished game.
                if isBeatSuspended { return }
            } else if endGameIfDecided() {
                return
            }
        }

        await playBlackMoves()

        guard !isBeatSuspended, stateMachine.currentState is PlayingState else { return }
        if endGameIfDecided() { return }
        // The fleet descends on the chess beat, never on its wall bounces — so
        // the shuffle can be tuned for looks without changing how fast the board
        // is taken away. Fired after the position settles so a descent never
        // races a chess move for the same square.
        fleet?.registerBeat()
        // Once per beat (§5.3), same reasoning: after the position has
        // settled, not raced against a chess move landing on the same square.
        fireFleetShots()
        beginBeat()
    }

    /// Ends the game if the side to move has no legal moves. Returns true if it did.
    ///
    /// `board` reports mate for whoever must move, so this covers both directions:
    /// White mated is a loss, Black mated is the player's win.
    @discardableResult
    private func endGameIfDecided() -> Bool {
        let loser = board.turn
        guard board.isMate || board.isStalemate || board.isDrawn else { return false }

        // A test run has served its purpose once the game reaches a conclusion,
        // so it does not silently carry into the next one.
        setAutoMode(false, retimingBeat: false)

        if board.isMate, loser == .black {
            winLevel(bonus: Self.checkmateBonus, label: "checkmate")
            return true
        }
        if board.isMate {
            outcome = .whiteMated
        } else if board.isStalemate {
            outcome = .stalemate
        } else if board.isDrawnByRepetition {
            outcome = .drawnByRepetition
        } else {
            outcome = .drawnByMoveLimit
        }
        DiagnosticsLog.shared.log(loser.logCategory, outcome.detail.lowercased())

        // Hold on the board first. `refreshStatus` has already drawn the mating
        // path and lit the king; let that play out, with the sting landing on the
        // reveal rather than on the menu.
        isEndingGame = true
        turnTimer.stop()
        clearSelection()
        settleFleetForReveal(against: loser)
        AudioManager.shared.play(.gameOver)

        scheduleAfterReveal { [weak self] in
            guard let self, self.stateMachine.currentState is PlayingState else { return }
            self.stateMachine.enter(GameOverState.self)
        }
        return true
    }

    /// Black's king has fallen — by checkmate, chess capture, fleet crush, or
    /// the player's laser (§25.2: all four are the same win). Award the bonus,
    /// hold on the position, then start the next level. A no-op once the game
    /// is already ending, so a laser and a checkmate landing in the same
    /// instant cannot both try to end the level.
    private func winLevel(bonus: Int, label: String, banner: String? = nil) {
        guard stateMachine.currentState is PlayingState, !isEndingGame else { return }
        setAutoMode(false, retimingBeat: false)
        if let banner { showEndBanner(banner, color: NeonPalette.cyan) }
        isEndingGame = true
        turnTimer.stop()
        clearSelection()
        settleFleetForReveal(against: .black)

        ScoreManager.shared.addPoints(bonus, source: label)
        refreshHUD()
        AudioManager.shared.play(.levelClear)
        DiagnosticsLog.shared.log(.level, "WAVE CLEAR — \(label)")

        scheduleAfterReveal { [weak self] in
            guard let self, self.stateMachine.currentState is PlayingState else { return }
            self.showWaveClearOverlay()
        }
    }

    /// A loss outside of chess entirely — three lives gone, a black piece
    /// reached rank 1, or the white king was destroyed by something other
    /// than checkmate (shot, or crushed). Mirrors `endGameIfDecided`'s own
    /// ending flow, generalized for a cause that isn't a chess fact.
    private func loseGame(outcome newOutcome: GameOverNode.Outcome, banner: String? = nil) {
        guard stateMachine.currentState is PlayingState, !isEndingGame else { return }
        setAutoMode(false, retimingBeat: false)
        outcome = newOutcome
        DiagnosticsLog.shared.log(.white, newOutcome.detail.lowercased())

        if let banner { showEndBanner(banner, color: NeonPalette.magenta) }
        isEndingGame = true
        turnTimer.stop()
        clearSelection()
        ship?.direction = 0
        settleFleetForReveal(against: .white)
        AudioManager.shared.play(.gameOver)

        scheduleAfterReveal { [weak self] in
            guard let self, self.stateMachine.currentState is PlayingState else { return }
            self.stateMachine.enter(GameOverState.self)
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

    /// The game ends on a chess fact, so the reveal should show the position the
    /// engine actually sees. The fleet eases off its shuffle and half-rank onto
    /// its true squares, and the mating line is then redrawn to match — drawn
    /// before the snap it would point at where the pieces used to be.
    ///
    /// Costs ~0.32s of the 2.5s hold, leaving the full check-path animation room
    /// to play out afterwards.
    private func settleFleetForReveal(against side: PieceColor) {
        guard let fleet, fleet.isOffTruePosition else { return }
        fleet.snapToTruePosition()
        boardNode?.clearCheckPaths()
        DiagnosticsLog.shared.log(.fleet, "settling onto true squares for the reveal")

        let redraw = SKAction.run { [weak self] in
            guard let self, self.board.isCheck || self.board.isMate else { return }
            self.showCheckPaths(against: side, pulses: 3)
        }
        run(.sequence([.wait(forDuration: 0.32), redraw]))
    }

    /// A big centred banner for the 2.5s reveal hold. The gutter status node is
    /// only a small chip beside the board, and a king being *shot* is not a
    /// chess event so nothing else announced it: the hold played out over an
    /// unchanged board and then jumped to the high-score prompt, which read as
    /// the game skipping straight past the ending.
    private func showEndBanner(_ text: String, color: SKColor) {
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.name = Self.endBannerName
        label.text = text
        label.fontSize = 30
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode   = .center
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.zPosition = 24
        label.setScale(0.7)
        label.alpha = 0
        bloomNode.addChild(label)
        label.run(.group([
            .fadeIn(withDuration: 0.18),
            .scale(to: 1.0, duration: 0.22),
        ]))
        label.run(.sequence([
            .wait(forDuration: 0.4),
            .repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 0.5),
                .fadeAlpha(to: 1.00, duration: 0.5),
            ])),
        ]))
    }

    private func removeEndBanner() {
        for node in bloomNode.children where node.name == Self.endBannerName {
            node.removeAllActions()
            node.removeFromParent()
        }
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

        for index in 0..<levels.parameters.blackMovesPerTurn {
            // Chess hands the turn to White after every move, so an extra Black
            // move has to be granted explicitly. Without this the loop always
            // broke on its second pass and multi-move never ran at any level.
            if index > 0 {
                guard board.turn == .white, !board.isMate, !board.isStalemate else { break }
                board.forceTurn(.black)
            }
            guard board.turn == .black else { break }

            let outcome = await board.makeEngineMove(
                constraints: .init(excludedSources: usedSources,
                                   excludedDestinations: usedDestinations,
                                   avoidsKingCapture: index > 0))
            guard let outcome else {
                // Black has no move. On an extra move that just means fewer moves
                // this turn (§25.5), so hand the turn back. On the *first* move it
                // means mate or stalemate — the turn must stay with Black or
                // endGameIfDecided evaluates the wrong side and misses it.
                if index > 0 { board.forceTurn(.white) }
                break
            }
            apply(outcome)
            // Black's move can end the game too — capturing the white king, or
            // mating. Stop immediately rather than playing out the rest of the
            // multi-move phase over a decided board.
            if isBeatSuspended { return }
            // Exclude where it came from *and* where it landed: §25.5 forbids a
            // piece moving twice, and after moving it is sitting on `to`.
            usedSources.insert(outcome.from)
            usedSources.insert(outcome.to)
            usedDestinations.insert(outcome.to)
        }
    }

    /// Orange "AUTO" over the piece the engine moved, 0.5s (§19).
    private func flashAuto(at square: String) {
        guard let boardNode, let point = boardNode.center(of: square) else { return }
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.text = "AUTO"
        label.fontSize = 12
        label.fontColor = NeonPalette.alertOrange
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
        // Black pieces belong to the fleet so one action sweeps them all; their
        // local position stays the logical square centre.
        if piece.color == .black, let fleet {
            fleet.adopt(node, square: piece.logicalSquare, atLogicalCentre: point)
        } else {
            boardNode.addChild(node)
        }
        pieceNodes[piece.logicalSquare] = node
        // Staggered so the board breathes rather than pulsing as one block.
        node.startIdleBob(phase: TimeInterval.random(in: 0...0.8))
    }

    // MARK: - Chess Interaction

    /// Lifts a node out of the formation onto the board, keeping it exactly where
    /// it was drawn. Used both when a black piece plays chess — it stops being an
    /// invader — and when one dies, so the explosion does not ride the march.
    /// A no-op for pieces the fleet does not own.
    private func detachFromFleet(_ node: PieceNode) {
        guard let boardNode, let fleet, fleet.contains(node) else { return }
        let drawn = fleet.screenPosition(of: node)
        // By identity, not by `square`: the key can name a different piece by
        // the time a crush callback runs, and a key-based release then left
        // this node still parented — `addChild` below threw.
        fleet.release(node)
        node.position = drawn
        boardNode.addChild(node)
    }

    /// Where the piece on `square` is actually drawn, in board coordinates.
    /// White pieces sit on their square; fleet pieces carry the sweep offset.
    private func drawnPosition(of square: String) -> CGPoint? {
        guard let boardNode, let centre = boardNode.center(of: square) else { return nil }
        guard let node = pieceNodes[square], let fleet, fleet.contains(node) else { return centre }
        return fleet.screenPosition(of: node)
    }

    /// Hairlines from each threatened fleet piece to the square it occupies.
    /// Drawn only while a white piece is selected — it answers "which square is
    /// that?" exactly when the player is asking it.
    private func showCaptureTethers(for captures: Set<String>) {
        guard let boardNode, let fleet else { return }
        let tethers = captures.compactMap { square -> (from: CGPoint, to: CGPoint)? in
            guard let node = pieceNodes[square], fleet.contains(node),
                  let centre = boardNode.center(of: square) else { return nil }
            let drawn = fleet.screenPosition(of: node)
            // A piece sitting on its square needs no line to itself.
            guard hypot(drawn.x - centre.x, drawn.y - centre.y) > 2 else { return nil }
            return (from: drawn, to: centre)
        }
        guard !tethers.isEmpty else { return }
        boardNode.showTethers(tethers, color: NeonPalette.cyan)
    }

    private func selectPiece(at square: String) {
        guard canAcceptChessInput,
              let piece = board.piece(at: square),
              piece.color == .white else { return }

        selectedSquare = square
        let destinations = board.legalDestinations(from: square)
        let captures = Set(destinations.filter { board.piece(at: $0) != nil })
        boardNode?.showSelection(at: square)
        boardNode?.showLegalMoves(destinations, captures: captures)
        showCaptureTethers(for: captures)
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
        boardNode?.clearTethers()
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
            detachFromFleet(victim)
            victim.runDestructionAnimation {}
        }

        // Only the player's captures score; Black taking White pieces must not
        // reward the player. Chess captures score at the lower of the two
        // tables (§9) — pointValue is the higher, shoot-to-kill rate.
        if let captured = outcome.captured, captured.color == .black {
            ScoreManager.shared.addPoints(captured.type.chessCaptureValue,
                                          source: captured.type.rawValue)
            refreshHUD()
        }

        // Capture reads over the move, so play only the louder of the two.
        if outcome.captured != nil {
            AudioManager.shared.play(.pieceHitHeavy)
        } else {
            AudioManager.shared.play(outcome.moved.color == .white
                                     ? .whitePieceMoves : .blackPieceMoves)
        }

        guard let node = pieceNodes.removeValue(forKey: outcome.from) else { return }
        // A black piece that plays chess normally stops being an invader (§5.1
        // rework): it leaves the formation and stands on its square, so the two
        // populations read differently — things that march, and things that sit.
        //
        // The exception is a piece shuffling around Black's own two home ranks.
        // A parked black piece usually sits directly behind one of White's pawns
        // and is then nearly unshootable, so staying in the formation keeps it
        // moving and keeps it a target.
        if outcome.moved.color == .black,
           FleetRules.staysInFormation(afterMovingTo: outcome.to),
           let fleet, fleet.contains(node),
           fleet.rekey(from: outcome.from, to: outcome.to) {
            // Stays parented to the fleet; `animateMove` below still targets the
            // logical square centre, which is what a member's local position is.
        } else {
            detachFromFleet(node)
        }
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

        // The black king falling by chess capture is a win exactly like being
        // shot or checkmated (§25.2) — refreshStatus below would only ever see
        // checkmate, never a capture that skipped straight past it.
        if let captured = outcome.captured, captured.color == .black, captured.type == .king {
            winLevel(bonus: Self.kingFallBonus, label: "king captured",
                     banner: "BLACK KING DESTROYED")
            return
        }

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
        guard let king = drawnPosition(of: threat.kingSquare) else { return }
        let paths = threat.attackers.compactMap { attacker -> (from: CGPoint, to: CGPoint, isJump: Bool)? in
            guard let origin = drawnPosition(of: attacker.square) else { return nil }
            return (from: origin, to: king, isJump: attacker.kind == .knight)
        }
        // Magenta when the player is the one in trouble, cyan when Black is.
        let color: SKColor = side == .white ? NeonPalette.magenta : NeonPalette.cyan
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
                let now = CACurrentMediaTime()
                if now - lastCheckAlarm >= Self.checkAlarmCooldown {
                    lastCheckAlarm = now
                    AudioManager.shared.play(.checkAlarm)
                }
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

        // Say how to get out, the same way the title screen does — "any key"
        // is not discoverable otherwise.
        let hint = SKLabelNode(fontNamed: "PressStart2P-Regular")
        hint.name = "pausedLabel"
        hint.text = "PRESS ANY KEY TO RESUME"
        hint.fontSize = 11
        hint.fontColor = NeonPalette.cyan
        hint.horizontalAlignmentMode = .center
        hint.verticalAlignmentMode   = .center
        hint.position = CGPoint(x: size.width / 2, y: size.height / 2 - 34)
        hint.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.6), .fadeAlpha(to: 1.0, duration: 0.6),
        ])))
        bloomNode.addChild(hint)

        // A level banner sits in the same place at a similar size, so the two
        // overlap into mush. PAUSED wins — the announcement is forfeited, which
        // is a fair trade for the player having chosen to stop.
        dismissLevelBanner()

        // Both the fleet and in-flight lasers advance on SKActions, so they
        // ignore the update-loop gate and have to be stopped explicitly.
        fleet?.setPaused(true)
        laserPool?.setPaused(true)
        DiagnosticsLog.shared.log(.level, "State → PAUSED")
    }

    func hidePausedOverlay() {
        removePausedOverlay()
        fleet?.setPaused(false)
        laserPool?.setPaused(false)
    }

    /// The PAUSED banner is two labels (title + hint) sharing one name, so this
    /// clears every match — `childNode(withName:)` returns only the first, which
    /// would have stranded the hint on screen.
    private func removePausedOverlay() {
        for node in bloomNode.children where node.name == "pausedLabel" {
            node.removeAllActions()
            node.removeFromParent()
        }
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

    // MARK: - Shooting & Collision (§20 Phase 3.2)

    /// Space bar: one shot, straight up from the ship's current column, if
    /// the 2-laser cap allows it (§8.2). Held-key repeat is already filtered
    /// out in `InputHandler`, so this fires once per press.
    private func fireLaserFromShip() {
        // `isBeatSuspended` covers the level banner as well as a decided game.
        // Firing during the banner was not merely an out-of-place sound: the
        // laser pool is paused then, so the round was created, played its shot
        // sound, and sat frozen at the ship holding a slot that could not
        // resolve — two taps and the player started the level unable to fire.
        guard stateMachine.currentState is PlayingState, !isBeatSuspended,
              let ship, let shipState, shipState.canFire,
              let laserPool, let laser = laserPool.nextAvailable(owner: .player)
        else { return }

        shipState.laserFired()
        laser.onDeactivate = { [weak shipState] in shipState?.laserResolved() }
        let origin = CGPoint(x: ship.position.x, y: ship.position.y + ship.size.height / 2)
        laser.fire(from: origin, damage: ProjectileState.playerLaserDamage,
                  speed: ProjectileState.playerLaserSpeed,
                  travelDistance: size.height - origin.y)
        AudioManager.shared.play(.playerLaserFire)
        DiagnosticsLog.shared.log(.shoot, "ship fires (\(shipState.activeLasers)/\(shipState.laserCap))")
    }

    /// Once per beat, after the position has settled (§5.3): 0–`shotsPerTurn`
    /// fleet pieces fire straight down, weighted toward the front rank.
    /// One firing phase per chess beat (§5.3). Called from `resolveBeat` after
    /// the position has settled, so a shot never races a chess move landing on
    /// the same square.
    private func fireFleetShots() {
        guard laserPool != nil else { return }
        let level = levels.parameters

        // §10.1: Level 1 schedules nothing, but the black king fires one slow
        // warning round the first time it reaches Critical damage — the first
        // incoming fire the player ever sees.
        if FleetFiring.shouldFireWarningShot(level: levels.level,
                                             blackKing: blackKing(),
                                             alreadyFired: hasFiredWarningShot),
           let king = blackKing() {
            hasFiredWarningShot = true
            fireInvaderShot(from: king.logicalSquare,
                            speed: FleetFiring.warningShotSpeed,
                            note: "level 1 warning shot")
            return
        }

        // §10.1's activated king fires its own heavy round on its own cadence,
        // separate from the fleet volley, so it reads as a distinct threat
        // rather than one more pawn.
        beatsThisLevel += 1
        if level.kingActivated,
           beatsThisLevel % FleetRules.kingShotInterval == 0,
           let king = blackKing() {
            fireInvaderShot(from: king.logicalSquare,
                            speed: level.projectileSpeed * FleetRules.kingShotSpeedMultiplier,
                            damage: FleetRules.kingShotDamage,
                            heavy: true,
                            sound: .kingLaserFire,
                            note: "black king fires")
        }

        let count = FleetFiring.shotCount(for: level)
        guard count > 0 else { return }

        let candidates = board.allPieces(color: .black).map {
            FleetFiring.Candidate(square: $0.logicalSquare, type: $0.type)
        }
        let shooters = FleetFiring.chooseShooters(from: candidates, count: count)

        // Spread the volley across a fraction of a second rather than firing it
        // in one instant. Same rate, but three simultaneous rounds read as one
        // event, and staggered ones read as three pieces choosing to shoot.
        for (index, square) in shooters.enumerated() {
            let delay = Double(index) * Self.volleyStagger
            let lean = FleetRules.diagonalLean(
                fromFile: Self.fileIndex(of: square),
                isDiagonal: level.diagonalShots
                    && Double.random(in: 0..<1) < FleetRules.diagonalShotShare)
            guard delay > 0 else {
                fireInvaderShot(from: square, speed: level.projectileSpeed, lean: lean)
                continue
            }
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    guard let self, !self.isBeatSuspended,
                          self.stateMachine.currentState is PlayingState else { return }
                    self.fireInvaderShot(from: square, speed: level.projectileSpeed,
                                         lean: lean)
                },
            ]))
        }
    }

    /// Spawns one invader round from `square`, if the piece is still there and a
    /// pooled laser is free.
    private func fireInvaderShot(from square: String, speed: CGFloat,
                                 damage: Int = ProjectileState.enemyShotDamage,
                                 heavy: Bool = false,
                                 lean: Int = 0,
                                 sound: SoundKey = .invaderLaserFire,
                                 note: String? = nil) {
        guard let laserPool,
              let laser = laserPool.nextAvailable(owner: .enemy),
              // A staggered shot can arrive after its piece has been destroyed.
              board.piece(at: square)?.color == .black,
              let origin = laserOrigin(forFleetSquare: square) else { return }

        // Set the dressing before firing: `setHeavy` rebuilds the physics body,
        // which would otherwise wipe the live contact mask `fire` just set.
        laser.setHeavy(heavy)
        // A diagonal keeps §21.3's fixed 160 px/s whatever the level's
        // straight-down speed is — the threat is the angle, not extra pace.
        laser.fire(from: origin, damage: damage,
                   speed: lean == 0 ? speed : FleetRules.diagonalShotSpeed,
                   travelDistance: origin.y, lean: lean)
        flashMuzzle(at: square)
        AudioManager.shared.play(sound)
        DiagnosticsLog.shared.log(.shoot, note ?? "black \(square) fires")
    }

    /// 0 for the a-file through 7 for the h-file.
    private static func fileIndex(of square: String) -> Int {
        guard let first = square.first,
              let ascii = first.lowercased().unicodeScalars.first?.value else { return 0 }
        return max(0, min(7, Int(ascii) - Int(UnicodeScalar("a").value)))
    }

    private func blackKing() -> Piece? {
        board.allPieces(color: .black).first { $0.type == .king }
    }

    /// A brief flare on the piece that just fired, so the player can see where a
    /// round came from. Without it a shot simply appears mid-board and the fleet
    /// gives no clue which piece is shooting at them.
    private func flashMuzzle(at square: String) {
        guard let node = pieceNodes[square] else { return }
        let flare = SKShapeNode(circleOfRadius: BoardNode.squareSize * 0.16)
        flare.fillColor = NeonPalette.magenta
        flare.strokeColor = .white
        flare.lineWidth = 1.5
        flare.glowWidth = 5
        flare.zPosition = 2
        flare.position = CGPoint(x: 0, y: -node.size.height * 0.4)
        node.addChild(flare)
        flare.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.16), .fadeOut(withDuration: 0.16)]),
            .removeFromParent(),
        ]))
    }

    /// A fleet piece's firing point, converted into the lasers' own coordinate
    /// space. `drawnPosition` is board-local — correct for check paths and
    /// tethers, which are boardNode children — but lasers live in `bloomNode`,
    /// and the board is inset within it. Skipping this conversion spawned every
    /// enemy shot a board-origin's worth down and to the left, well off target.
    private func laserOrigin(forFleetSquare square: String) -> CGPoint? {
        guard let boardNode, let local = drawnPosition(of: square) else { return nil }
        return boardNode.convert(local, to: bloomNode)
    }

    /// The player's laser touched something. Always consumed on contact,
    /// whatever it hit — a laser doesn't pass through.
    private func resolvePlayerLaserHit(laser: LaserNode, node: SKNode) {
        laser.deactivate()
        guard let pieceNode = node as? PieceNode else { return }

        if pieceNode.piece.color == .black {
            guard let result = CollisionResolver.playerLaserHitBlackPiece(
                at: pieceNode.square, board: board) else { return }
            handleBlackPieceHit(result, node: pieceNode)
        } else if pieceNode.piece.type == .king {
            // The player's own king is armoured against the player's own fire.
            // Shooting it is almost always a mistake — the ship sits directly
            // below the back rank — and ending the run on a stray shot punishes
            // exactly the player who does not yet know the board. Invader fire
            // still kills it (that path is `resolveEnemyShotHit`), so the lose
            // condition is intact.
            pieceNode.flashDeflection()
            AudioManager.shared.play(.shieldAbsorbsHit)
            DiagnosticsLog.shared.log(.hit, "white king deflected friendly fire")
        } else {
            guard let result = CollisionResolver.playerLaserHitWhitePiece(
                at: pieceNode.square, board: board) else { return }
            handleWhitePieceHit(result, node: pieceNode)
        }
    }

    /// An invader shot touched something — either the ship, or a white piece
    /// blocking its lane.
    private func resolveEnemyShotHit(shot: LaserNode, node: SKNode) {
        shot.deactivate()
        if let ship, node === ship {
            handleShipHit()
        } else if let pieceNode = node as? PieceNode, pieceNode.piece.color == .white {
            guard let result = CollisionResolver.enemyShotHitWhitePiece(
                at: pieceNode.square, board: board) else { return }
            handleWhitePieceHit(result, node: pieceNode)
        }
    }

    /// Shows the shield ring only while the black king still has bonus HP, so
    /// the ring going out is the moment the king becomes killable.
    private func refreshKingForcefield() {
        guard levels.parameters.kingActivated,
              let king = board.allPieces(color: .black).first(where: { $0.type == .king }),
              let node = pieceNodes[king.logicalSquare] else { return }
        node.setForcefield(board.blackKingShieldIsUp())
    }

    /// Re-reads the damaged piece from the board and swaps the node onto its
    /// eroded sprite.
    ///
    /// Without this a surviving piece kept its full-HP art until something else
    /// happened to call `refresh` — in practice only a chess move — so hits
    /// registered in the model and in the score but were invisible on the
    /// board, and damage appeared to "arrive" later when the piece moved.
    /// `refresh` is a no-op when the texture name hasn't changed, so calling it
    /// on every hit costs nothing between damage stages.
    private func showDamage(on node: PieceNode, at square: String) {
        guard let updated = board.piece(at: square) else { return }
        node.refresh(with: updated)
    }

    private func handleBlackPieceHit(_ result: CollisionOutcome, node: PieceNode) {
        guard case .blackPieceHit(let square, let type, let destroyed, let points, let comboBonus) = result
        else { return }

        if !destroyed {
            showDamage(on: node, at: square)
            node.applyHitFlash()
            // While the king's forcefield still holds, a hit reads as absorbed
            // rather than as damage — which is also literally true, since the
            // bonus HP is being spent and the sprite has not eroded yet.
            if type == .king, board.blackKingShieldIsUp() {
                node.flareForcefield()
                AudioManager.shared.play(.shieldAbsorbsHit)
            } else {
                AudioManager.shared.play(.pieceHitLight)
            }
            refreshKingForcefield()
            return
        }

        pieceNodes.removeValue(forKey: square)
        detachFromFleet(node)
        node.runDestructionAnimation {}
        AudioManager.shared.play(destroyedSound(for: type))
        ScoreManager.shared.addPoints(points, source: "\(type.rawValue) (shot)")
        refreshHUD()

        guard type == .king else { return }
        // §9's 800-point line: the king died while already checkmated — the
        // beat this happened on hadn't formally resolved yet, so both bonuses
        // land in the same instant rather than one pre-empting the other.
        let bonus = points + (comboBonus ? Self.checkmateBonus : 0)
        winLevel(bonus: bonus,
                 label: comboBonus ? "king shot + checkmate" : "king shot",
                 banner: "BLACK KING DESTROYED")
    }

    private func handleWhitePieceHit(_ result: CollisionOutcome, node: PieceNode) {
        guard case .whitePieceHit(let square, let destroyed) = result else { return }

        if !destroyed {
            showDamage(on: node, at: square)
            node.applyHitFlash()
            AudioManager.shared.play(.pieceHitLight)
            return
        }

        pieceNodes.removeValue(forKey: square)
        node.runDestructionAnimation {}
        AudioManager.shared.play(destroyedSound(for: node.piece.type))

        if node.piece.type == .king {
            loseGame(outcome: .whiteKingDestroyed, banner: "WHITE KING DESTROYED")
        }
    }

    /// A life is lost only if the ship isn't currently invincible — `loseLife`
    /// reports that back, so an ignored hit during the grace window plays no
    /// sound and does nothing else.
    private func handleShipHit() {
        // Contacts can still be delivered while paused or during the end-game
        // reveal; neither should ever cost a life.
        guard stateMachine.currentState is PlayingState, !isEndingGame else { return }
        guard let shipState, shipState.loseLife() else { return }
        refreshHUD()
        ship?.direction = 0

        guard shipState.lives > 0 else {
            AudioManager.shared.play(.playerShipDestroyed)
            loseGame(outcome: .livesDepleted)
            return
        }

        AudioManager.shared.play(.invaderHitsShip)
        ship?.isHidden = true
        run(.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in self?.respawnShip() },
        ]))
    }

    /// Respawns at center-bottom (§8.4) with the invincibility flash.
    private func respawnShip() {
        guard let ship, stateMachine.currentState is PlayingState else { return }
        ship.position = CGPoint(x: size.width / 2, y: Self.shipLaneY)
        ship.isHidden = false
        ship.startRespawnInvincibility(duration: SpaceshipState.invincibilityDuration)
    }

    private func destroyedSound(for type: PieceType) -> SoundKey {
        switch type {
        case .pawn:   return .pawnDestroyed
        case .knight: return .knightDestroyed
        case .bishop: return .bishopDestroyed
        case .rook:   return .rookDestroyed
        case .queen:  return .queenDestroyed
        case .king:   return .kingDestroyed
        }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        stateMachine.update(deltaTime: currentTime)

        let dt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        if dt > 0, stateMachine.currentState is PlayingState {
            // Held still while a banner is up or the game is decided; §12.11
            // has gameplay beginning once the announcement leaves.
            if !isBeatSuspended {
                let lane = Self.shipMargin...(size.width - Self.shipMargin)
                ship?.update(deltaTime: dt, bounds: lane)
            }
            shipState?.update(deltaTime: dt)

            // The end-of-game hold owns the beat while it runs.
            if advanceReveal(dt) {
                turnTimerNode?.isHidden = true
                publishStats(dt: dt, now: currentTime)
                return
            }

            // Invariant, enforced here rather than at every call site: if it is
            // White's move and no beat is running, start one. `resolveBeat` has
            // several early returns — pausing while Black was thinking used to
            // leave the game with no live beat and no way to move again.
            if !isBeatSuspended, !isResolvingBeat,
               board.turn == .white, !turnTimer.isRunning {
                beginBeat()
            }

            // The chess beat. Arcade action keeps running while it ticks —
            // the game never pauses for chess (§3). But once the game is
            // decided the beat stops entirely: a timer left running would
            // expire and resolve another beat over a finished board.
            if !isBeatSuspended, turnTimer.update(deltaTime: dt) {
                Task { await self.resolveBeat() }
            }
            // The countdown is the player's own clock, so it appears only while
            // White may still move: not while Black is thinking, and not after
            // White has already moved this beat.
            // In Auto Mode the beat is far too short to read, so the slot shows
            // AUTO MODE instead of a countdown flickering on and off.
            let awaitingWhite = isAwaitingWhiteMove
            turnTimerNode?.isHidden = isAutoMode || !awaitingWhite
            autoModeLabel?.isHidden = !isAutoMode
            if awaitingWhite, !isAutoMode {
                tickTimerWarning()
                turnTimerNode?.refresh(from: turnTimer)
            } else {
                lastTickedSecond = -1
            }
        }

        publishStats(dt: dt, now: currentTime)
    }

    /// Four times a second is plenty for a readout, and it keeps both the node
    /// walk and the SwiftUI invalidation out of the per-frame path.
    private func publishStats(dt: TimeInterval, now: TimeInterval) {
        #if DEBUG
        guard dt > 0, now - lastStatsUpdate >= Self.statsInterval else { return }
        lastStatsUpdate = now
        DiagnosticsLog.shared.fps = (1.0 / dt).rounded()
        DiagnosticsLog.shared.nodeCount = countAllNodes()
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

        // Paused: any key resumes — except the Info shortcut, which opens How
        // To Play, and `X` (handled above), which restarts. Info has to be
        // tested before the catch-all or it could never fire while paused.
        if stateMachine.currentState is PausedState {
            if InputHandler.shared.isInfoShortcut(event) {
                showHowToPlay()
            } else {
                stateMachine.enter(PlayingState.self)
            }
            return
        }

        // Hidden Auto Mode: A plays White automatically on a very short beat.
        if stateMachine.currentState is PlayingState,
           event.charactersIgnoringModifiers?.lowercased() == "a" {
            toggleAutoMode()
            return
        }

        // Hidden: V skips to the next level, mid-game, with no fanfare.
        if stateMachine.currentState is PlayingState,
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            skipLevel()
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

        // Paused: a click resumes, same as any key. Checked before the board
        // hit-test so a click on the board resumes rather than being swallowed.
        if stateMachine.currentState is PausedState {
            stateMachine.enter(PlayingState.self)
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
