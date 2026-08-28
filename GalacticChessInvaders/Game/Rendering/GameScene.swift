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
    private var settingsNode: SettingsNode?
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
    private var scorePops: ScorePopPool?
    /// §23.9's pending regenerations. Lives here rather than in the board so it
    /// is torn down with the level, which is exactly what the spec asks for:
    /// "if the level ends while a regeneration timer is running, it is
    /// cancelled."
    private var regeneration = RegenerationQueue()
    /// Squares whose pawn is still beaming in, for the 1.8s that takes.
    ///
    /// It is on the board and in the engine from the first frame, because a
    /// white piece must not be able to move onto the square — but §23.9 has it
    /// "fires" only once materialised, and a shooter that cannot be shot back
    /// at is the definition of unfair.
    ///
    /// This is the *only* thing that stops a regenerated pawn firing. Armor
    /// does not: an armored pawn is a gunner like any other, and taking fire
    /// and returning it are separate questions.

    private var explosions: ExplosionPool?
    private var shatters: ShatterPool?
    private var raiders: RaiderController?
    /// Attack patterns the player has already been shown once, for the whole
    /// run — the controller is rebuilt every level and cannot remember.
    /// Which kinds of raider have already spent their free first pass, for
    /// the whole run rather than the level — the controller is rebuilt each
    /// wave, so it cannot remember this itself.
    private var raiderKindsSeen: Set<PowerUp> = []

    /// §24.1's shake, applied to `bloomNode` rather than to a camera.
    ///
    /// A camera would also change how a mouse point maps into the scene, and
    /// click-to-select depends on that mapping — shaking the playfield node
    /// keeps input untouched. It also leaves the starfield still, which reads
    /// as the board being hit rather than the universe wobbling.
    private var shake: Juice.Shake = .none
    private var shakeElapsed: TimeInterval = 0
    private var shakeAngle: CGFloat = 0

    /// §24.2's hit freeze. The scene's own `update` keeps running so it can
    /// time itself; everything under `bloomNode` is what actually stops.
    /// §8.4's one-second wait before the ship comes back. Zero when alive.
    private static let respawnDelay: TimeInterval = 1.0
    private var respawnRemaining: TimeInterval = 0
    /// The ship is destroyed and has not come back yet — it should not be
    /// drawn, moved or fired during that second.
    private var isShipDown: Bool { respawnRemaining > 0 }

    private var freezeRemaining: TimeInterval = 0
    private var afterFreeze: (() -> Void)?

    // MARK: - Slow motion (§13.2's Nuke)

    /// How long the blast's slow motion has left, in real seconds.
    private var slowMoRemaining: TimeInterval = 0
    private var appliedTimeScale: Double = 1
    /// Long enough for the ring to cross the board and the fragments to land
    /// inside it; short enough that it is a moment rather than an interlude.
    static let slowMoDuration: TimeInterval = 1.3
    /// Roughly a third speed. Deeper than this and the ship stops answering the
    /// keys in a way that reads as a hang rather than as an effect.
    static let slowMoFloor: Double = 0.3
    /// The share of the window spent at full slow before the ramp back begins.
    static let slowMoHold = 0.45

    /// The curve, as a pure function of how far into the window we are, so the
    /// shape can be checked without a running scene.
    static func slowMoScale(elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return slowMoFloor }
        guard elapsed < slowMoDuration else { return 1 }
        let hold = slowMoDuration * slowMoHold
        guard elapsed > hold else { return slowMoFloor }
        let progress = (elapsed - hold) / (slowMoDuration - hold)
        return slowMoFloor + (1 - slowMoFloor) * progress * progress
    }

    /// The clock everything else runs on: 1 normally, less during a blast.
    ///
    /// Holds at the floor and then accelerates back rather than easing out of
    /// it. Coming *out* of slow motion is the part that sells it — a linear
    /// return reads as the game recovering from a stall, where lingering low and
    /// then snapping back reads as a decision.
    private var timeScale: Double {
        guard slowMoRemaining > 0 else { return 1 }
        return Self.slowMoScale(elapsed: Self.slowMoDuration - slowMoRemaining)
    }

    /// Slows the SKAction world to match. `dt` covers everything the update loop
    /// drives — the ship, the beat, the raider clock — but the fleet's sweep,
    /// the lasers, the explosions and the blast's own ring are all actions, and
    /// `speed` is the only thing that reaches them.
    private func applyTimeScale() {
        let scale = timeScale
        guard abs(scale - appliedTimeScale) > 0.001 else { return }
        appliedTimeScale = scale
        bloomNode.speed = CGFloat(scale)
        starfieldNode.speed = CGFloat(scale)
        if scale >= 1 { endSlowMotionAudio() }
    }

    /// Drops the world into slow motion. Called by the Nuke, and deliberately
    /// not by anything else: it is what makes that one power-up a set piece.
    private func beginSlowMotion() {
        slowMoRemaining = Self.slowMoDuration
        applyTimeScale()
        // Same trick as Time Freeze, at a shallower depth so the two are not
        // mistaken for each other — that one stops the world, this one leans on
        // it. §13.2 sanctions `rate` for exactly this.
        AudioManager.shared.setMusicRate(0.7)
    }

    private func endSlowMotionAudio() {
        // Back to whatever the world is actually doing: a Time Freeze may still
        // be running underneath, and it owns 0.5 until it expires.
        AudioManager.shared.setMusicRate(powerUps.isFrozen ? 0.5 : 1.0)
    }

    private func cancelSlowMotion() {
        guard slowMoRemaining > 0 || appliedTimeScale != 1 else { return }
        slowMoRemaining = 0
        appliedTimeScale = 1
        bloomNode.speed = 1
        starfieldNode.speed = 1
        endSlowMotionAudio()
    }

    /// §13's power-ups. The clock and the shield charge; everything the effects
    /// actually *do* to the world lives in the Power-Ups section below.
    private var powerUps = PowerUpState()
    /// Time until the next Spread Fire round. Only meaningful while it is running.
    private var gatlingCooldown: TimeInterval = 0
    /// How far through its sweep the spray is, in seconds. Advances whenever the
    /// effect is up, held or not, so the hose keeps moving and a player who taps
    /// gets samples of the same arc a player who holds paints continuously.
    private var gatlingPhase: TimeInterval = 0
    /// Whether the fire key is currently down. Ordinary fire is one shot per
    /// press and ignores this; Spread Fire sprays for as long as it is held.
    private var isFireHeld = false
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
    /// Everything in the left gutter from the turn timer down sits this much
    /// lower than it used to, to open a gap between the chess readouts and the
    /// power-up block above them. Applied as one constant rather than four
    /// edited literals, because the four move together or the timer's digits
    /// land on the transient notice.
    private static let gutterDrop: CGFloat = 8
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

    /// Guards against `didMove` running twice.
    ///
    /// The scene is a singleton and `presentScene` is called from
    /// `makeNSView`, so anything that makes SwiftUI rebuild the representable —
    /// a window rebuild, a move to another display — presents the *same* scene
    /// again and SpriteKit calls this again. Nothing in `setupScene` was
    /// idempotent: it built a second `bloomNode` (a second full-screen CIBloom
    /// pass), a second starfield and a second set of pools, and left the first
    /// of each parented to the scene doing nothing but costing frames.
    private var isSceneBuilt = false

    override func didMove(to view: SKView) {
        guard !isSceneBuilt else { return }
        isSceneBuilt = true

        setupScene()
        setupInputHandler()
        setupStateMachine()

        DiagnosticsLog.shared.log(.startup, "Screen: \(Int(size.width))×\(Int(size.height))")
    }

    // MARK: - Scene Setup

    private func setupScene() {
        backgroundColor = SKColor(red: 0, green: 0, blue: 0, alpha: 1)
        physicsWorld.gravity = .zero

        let handler = CollisionHandler()
        handler.onPlayerLaserHit = { [weak self] laser, node, at in
            self?.resolvePlayerLaserHit(laser: laser, node: node, at: at)
        }
        handler.onEnemyShotHit = { [weak self] shot, node, at in
            self?.resolveEnemyShotHit(shot: shot, node: node, at: at)
        }
        handler.onProjectilesCollided = { [weak self] player, enemy, at in
            self?.resolveProjectileClash(player: player, enemy: enemy, at: at)
        }
        physicsWorld.contactDelegate = handler
        collisionHandler = handler

        setupBloomNode()
        setupPools()
        setupStarfield()
    }

    /// The object pools, built once for the life of the scene.
    ///
    /// They used to be rebuilt by `buildPlayfield`, which runs for every level
    /// *and* every skip — while their nodes are parented to `bloomNode`, which
    /// is not rebuilt. Resetting a pool hides its nodes; it does not unparent
    /// them. So each level orphaned a full set and left it in the scene graph
    /// for the rest of the run: roughly 400 nodes, 40 of them carrying physics
    /// bodies, all still walked every frame. That is the whole of "the CPU
    /// climbs the longer you play".
    ///
    /// Building them once is the right shape regardless: a pool exists so that
    /// allocation happens away from play, and rebuilding one per level is the
    /// opposite of that.
    private func setupPools() {
        laserPool = LaserPool(parent: bloomNode)
        scorePops = ScorePopPool(parent: bloomNode)
        explosions = ExplosionPool(parent: bloomNode)
        shatters = ShatterPool(parent: bloomNode)
    }

    private func setupBloomNode() {
        bloomNode = SKEffectNode()
        // Not rasterized. Rasterizing caches an effect node's rendered output
        // and invalidates it whenever the subtree changes — and every moving
        // thing in the game is a child of this node, so the cache is invalidated
        // every frame and never once read. Applying the CIFilter forces an
        // offscreen pass either way; what rasterizing added on top was a
        // retained buffer and the bookkeeping to throw it away again.
        //
        // Apple's own guidance is to rasterize only when contents rarely change.
        // §18.9 asked for it, written before there was anything moving inside.
        bloomNode.shouldRasterize = false
        applyGlowSetting()
        addChild(bloomNode)
    }

    /// The glow is a full-screen `CIBloom` and the single largest GPU cost in
    /// the game, so turning it off is the one switch that can rescue an older
    /// Mac. Detaching the filter — rather than zeroing its intensity — is what
    /// actually skips the offscreen pass.
    private func applyGlowSetting() {
        bloomNode.filter = GameSettings.shared.neonGlow
            ? CIFilter(name: "CIBloom", parameters: [
                "inputRadius": 6.0,
                "inputIntensity": 0.9
              ])
            : nil
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

        DiagnosticsLog.shared.log(.startup, "Starfield: 3 tiers")
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
            // `L` and the settings switch are the same control reached two
            // ways, so the key writes the setting rather than the view.
            GameSettings.shared.logPanel.toggle()
            NotificationCenter.default.post(name: .gciSidebarChanged, object: nil)

        case .moveLeft:   ship?.direction = -1
        case .moveRight:  ship?.direction =  1
        case .stopMoving: ship?.direction =  0

        case .fireLaser:
            isFireHeld = true
            fireLaserFromShip()

        case .stopFiring:
            isFireHeld = false

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

        // The title screen has no HUD, so it carries the nav pair itself. The
        // overlay is centred in the scene, so the container is offset back to
        // the scene's origin and then up to where the HUD would have been —
        // which puts SET and INFO in exactly the pixels they occupy in play.
        let nav = HUDNode.makeNavButtons()
        nav.position = CGPoint(x: -size.width / 2,
                               y: size.height - HUDNode.height - size.height / 2)
        overlay.addChild(nav)

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
        // The live values where they exist. Hardcoding 3 here was fine while
        // nothing could kill the ship; now a HUD built mid-run — the sidebar
        // toggling, a pause rebuild — would show three lives to a player on
        // their last.
        hud.updateLives(shipState?.lives ?? SpaceshipState.startingLives)
        hud.updateLevel(levels.level)
    }

    func hideHUD() {
        hudNode?.removeFromParent()
        hudNode = nil
    }

    /// The one thing on screen that should show a pointing hand: the Zudio
    /// link on the info panel. `KeyboardFocusedSKView` turns this into a cursor
    /// rect; nil means there is nothing to point at.
    var pointerCursorRect: CGRect? {
        guard let overlay = howToPlayNode, !overlay.linkRect.isEmpty else { return nil }
        return overlay.linkRect
    }

    /// Cursor rects are cached by the window until something says otherwise, so
    /// every path that opens or closes the info panel has to say so.
    private func refreshCursorRects() {
        guard let view else { return }
        view.window?.invalidateCursorRects(for: view)
    }

    func showHowToPlay() {
        guard howToPlayNode == nil else { return }

        // Here rather than at each entry point. There are five ways in — the
        // INFO button, `I`, `?`, ⌘I, and the shortcut while paused — and only
        // the button used to make a sound, so the same action was audible or
        // silent depending on how it was reached.
        AudioManager.shared.play(.uiButtonClick)

        // A level banner underneath shows through the panel's 0.97 ground and
        // is still counting down when the panel closes. End it rather than
        // stack on it — properly, via `endLevelAnnouncement`, because the
        // announcement is holding the fleet and the laser pool.
        endLevelAnnouncement()
        removeEndBanner()

        let overlay = HowToPlayNode(sceneSize: size)
        overlay.position = .zero
        overlay.zPosition = 20
        addChild(overlay)
        howToPlayNode = overlay
        refreshCursorRects()

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
        refreshCursorRects()

        if stateMachine.currentState is PlayingState {
            isPaused = false
            turnTimer.resume()
            // Discard the frame the pause spanned so the beat doesn't jump.
            lastUpdateTime = 0
        }
    }

    /// A button pushes in and springs back, then does its job.
    ///
    /// No colour change: the button is lit neon already, and re-tinting it read
    /// as a state change rather than a press. Two points down and back is the
    /// whole effect.
    ///
    /// Timer-driven rather than an `SKAction`, and that is not a style choice.
    /// Opening a panel sets `isPaused` on the scene, which stops actions for
    /// the entire tree — so an action-based press on a panel's own BACK button
    /// would never run a single frame. The delayed call also gives the push
    /// somewhere to be seen, since every one of these buttons is about to be
    /// covered by the panel it opens or torn down by the one it closes.
    private func pressButton(_ node: SKNode, then action: @escaping () -> Void) {
        guard let parent = node.parent, let name = node.name else { action(); return }
        // The box, its label and any icon are siblings sharing the button's
        // name, so they travel together.
        let group = parent.children.filter { $0.name == name }
        let homes = group.map(\.position)
        for part in group { part.position.y -= 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            for (part, home) in zip(group, homes) { part.position = home }
            action()
        }
    }

    // MARK: - Settings (§20 Phase 5)

    func showSettings() {
        guard settingsNode == nil, howToPlayNode == nil else { return }
        AudioManager.shared.play(.uiSettingsBlip)
        endLevelAnnouncement()
        removeEndBanner()

        let panel = SettingsNode()
        panel.position = .zero
        panel.zPosition = 20
        panel.onChange = { [weak self] in self?.applyLiveSettings() }
        addChild(panel)
        settingsNode = panel

        // Same hold as How To Play: freeze the beat and stop the ship drifting,
        // but leave the music alone — changing the volume is the main reason
        // anyone opens this, and it has to be audible while they do.
        if stateMachine.currentState is PlayingState {
            turnTimer.pause()
            ship?.direction = 0
            isPaused = true
        }
        DiagnosticsLog.shared.log(.info, "settings open")
    }

    /// BACK always returns to play — never to the title.
    func hideSettings() {
        guard settingsNode != nil else { return }
        settingsNode?.removeFromParent()
        settingsNode = nil
        applyLiveSettings()

        if stateMachine.currentState is PlayingState {
            isPaused = false
            turnTimer.resume()
            lastUpdateTime = 0
        }
    }

    /// Everything a settings change should show immediately. The values that
    /// cannot apply mid-run — lives, and the difficulty tuning already baked
    /// into the current wave — take effect at the next level or the next game,
    /// which is the honest place for them.
    private func applyLiveSettings() {
        applyGlowSetting()
        boardNode?.applyDisplaySettings()
        AudioManager.shared.applyMusicSettings()
        // Cheap and idempotent, so it rides along with every change rather than
        // needing the panel to know which switch was the sidebar's.
        NotificationCenter.default.post(name: .gciSidebarChanged, object: nil)
    }

    func resetToTitle() {
        howToPlayNode?.removeFromParent(); howToPlayNode = nil
        settingsNode?.removeFromParent(); settingsNode = nil
        refreshCursorRects()
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

    /// Where the `P` test key is up to in `PowerUp.allCases`. Reset with the
    /// level, so every wave starts the cycle at Rapid Fire rather than wherever
    /// the last one left off.
    private var testPowerUpCursor = 0

    /// Hidden developer aid: grant the next power-up outright.
    ///
    /// `R` sends the raider that carries one; this skips the raider. The two are
    /// different tests — `R` exercises the crossing, the flight path and the
    /// hitbox, and this exercises only the effect, which is the half that is
    /// hard to reach when the level's roster does not happen to offer it. Every
    /// power-up is reachable on any level, cycling and wrapping.
    ///
    /// Routed through `activate` — the same call the kill path makes — so a
    /// granted effect is indistinguishable from an earned one. No points are
    /// awarded: scoring belongs to the kill, not the effect.
    private func grantNextPowerUp() {
        guard stateMachine.currentState is PlayingState, !isEndingGame else { return }
        let powerUp = PowerUp.allCases[testPowerUpCursor % PowerUp.allCases.count]
        testPowerUpCursor += 1
        // Above the ship, so the §13.3 label lands where the player is looking
        // rather than wherever a scout happened to die.
        //
        // Except the Nuke, which detonates where it is granted: from the ship's
        // own rank the ring only ever expands upward and away, and the three
        // pieces nearest the bottom of the board are not what anyone wants to
        // watch it take. The middle of the board puts the fragments in every
        // direction, which is the whole thing worth looking at.
        let at = powerUp == .nuke
            ? CGPoint(x: size.width / 2,
                      y: Self.boardBottomY + BoardNode.boardSize / 2)
            : CGPoint(x: ship?.position.x ?? size.width / 2,
                      y: Self.boardBottomY + BoardNode.squareSize)
        activate(powerUp, at: at)
        DiagnosticsLog.shared.log(.auto, "granted \(powerUp.label.lowercased())")
    }

    /// Hidden developer aid: send the level's next raider in immediately.
    ///
    /// Raiders are on a ~28-second clock and most levels go quiet once one has
    /// been shot down, so testing a power-up otherwise means waiting for a
    /// crossing that may not come. Successive presses walk the level's whole
    /// list and wrap, and it keeps working after raids have ended for the wave —
    /// that override is most of the point, since re-checking a power-up already
    /// collected once is exactly when the clock has nothing left to send.
    ///
    /// Deliberately routed through the same launch path as the clock rather
    /// than a shortcut of its own: a test key that flies a raider differently
    /// from the real one is worse than no test key.
    private func summonRaider() {
        guard stateMachine.currentState is PlayingState, !isEndingGame,
              let raiders else { return }
        guard let launched = raiders.summonNext() else {
            DiagnosticsLog.shared.log(.raider, "nothing left to send")
            return
        }
        DiagnosticsLog.shared.log(.auto, "sent \(launched.shipName) scout")
    }

    /// Hidden developer aid: jump straight to the next level, keeping score and
    /// lives. Rebuilds the playfield exactly as finishing a wave does, but with
    /// no wave-clear overlay and no bonus — it is a shortcut for reaching a
    /// level, not a way to farm one.
    private func skipLevel() {
        guard stateMachine.currentState is PlayingState, !isEndingGame else { return }
        // Past the last level it wraps to the first, so holding `V` walks the
        // whole ladder round and round. It never builds an eleventh level —
        // there is no design for one — and it never ends the run, because
        // stopping the loop at the top is the opposite of what a test pass
        // wants. The score carries over; only the ladder restarts.
        let wrapping = levels.isFinalLevel
        DiagnosticsLog.shared.log(.auto,
            wrapping ? "skip wraps to 1" : "skip to \(levels.level + 1)")
        // buildPlayfield tears the board down and back up, so the notice has to
        // be raised afterwards or it is removed with everything else. The
        // mechanic banner still shows, so a skip is a way to *see* a level's
        // announcement rather than a way past it.
        if wrapping {
            restartLadder()
        } else {
            startNextLevel()
        }
        flashGutterNotice(wrapping ? "LEVEL 1" : "SKIP LEVEL")
    }

    /// Back to Level 1 with the run intact, for the `V` loop.
    private func restartLadder() {
        levels.reset()
        ScoreManager.shared.restartLadder()
        shipState?.resetForNewLevel()
        buildPlayfield(announceLevel: true)
        logLevel()
    }

    /// A brief label in the gutter slot AUTO MODE uses, for developer actions
    /// that happen once rather than toggling.
    private func flashGutterNotice(_ text: String,
                                   color: SKColor = NeonPalette.alertOrange) {
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.name = Self.gutterNoticeName
        label.text = text
        label.fontSize = 9
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        // Sits just under the AUTO MODE slot so both can show at once.
        label.position = CGPoint(x: 112, y: Self.boardBottomY + 30 - Self.gutterDrop)
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
        // A new run has seen nothing, so both patterns owe a warning pass again.
        raiderKindsSeen.removeAll()
        hasOfferedHighScore = false
        ScoreManager.shared.resetForNewGame()
        shipState = SpaceshipState(lives: GameSettings.shared.lives)
        buildPlayfield()
    }

    /// One line per level, in the same shape whether it is the first or the
    /// eleventh — the two used to differ, so "Level 1 started" and "Level 2 —
    /// beat 5s…" read as unrelated events.
    func logLevel() {
        let p = levels.parameters
        DiagnosticsLog.shared.log(.level,
            "\(levels.level) — \(Int(p.turnTimer))s beat, "
            + "\(p.blackMovesPerTurn) move/turn")
    }

    /// The next wave: level and multiplier step up, score carries over. Lives
    /// carry over too (§8.5) — only the laser cap and invincibility reset.
    private func startNextLevel(announce: Bool = true) {
        levels.advance()
        ScoreManager.shared.advanceLevel()
        shipState?.resetForNewLevel()
        buildPlayfield(announceLevel: announce)
        logLevel()
    }

    private func buildPlayfield(announceLevel: Bool = true) {
        hideBoard()
        board.setupStandardPosition()
        // §10.1: at Level 9 the black king carries a forcefield worth 50%
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
            DiagnosticsLog.shared.log(.fleet, "breach at \(square)")
            self?.fleet?.stop()
            self?.loseGame(outcome: .blackBreachedRank1)
        }

        for piece in board.allPieces() { addPieceNode(piece) }
        // Not here: the board is built before the KING ACTIVATED banner runs,
        // and a shield already sitting on the king while the announcement is
        // still explaining that he is about to get one reads as a mistake.
        // `beginBeat` raises it, once play actually starts.
        controller.start()

        let player = SpaceshipNode()
        player.position = CGPoint(x: size.width / 2, y: Self.shipLaneY)
        // The hull is a *view* of the laser cap, not a latch. It only ever gets
        // switched on at a promotion, and it reads correctly today because the
        // ship is rebuilt every level with the cap already reset — this line is
        // what keeps that true if the ship is ever built at some other moment.
        player.setRapidFire(stacks: (shipState?.laserCap ?? SpaceshipState.baseLaserCap)
                                        - SpaceshipState.baseLaserCap)
        bloomNode.addChild(player)
        ship = player

        let raiderController = RaiderController(parent: bloomNode, sceneWidth: size.width,
                                                boardBottomY: Self.boardBottomY)
        raiderController.onScoutFire = { [weak self] point in self?.fireScoutShot(from: point) }
        raiderController.onExit = { [weak self] node, destroyed in
            self?.resolveRaiderExit(node, destroyed: destroyed)
        }
        raiderController.onKindPreviewed = { [weak self] kind in
            self?.raiderKindsSeen.insert(kind)
        }
        raiderController.reset(interval: levels.parameters.raiderInterval,
                               level: levels.level,
                               kindsSeen: raiderKindsSeen)
        raiders = raiderController

        // Countdown lives in the gutter left of the board (§19), with the
        // check/mate banner directly beneath it.
        let timerDisplay = TurnTimerNode()
        timerDisplay.position = CGPoint(x: 112, y: Self.boardBottomY + 46 - Self.gutterDrop)
        timerDisplay.isHidden = true
        bloomNode.addChild(timerDisplay)
        turnTimerNode = timerDisplay

        let status = GameStatusNode()
        status.position = CGPoint(x: 112, y: Self.boardBottomY - 4 - Self.gutterDrop)
        bloomNode.addChild(status)
        statusNode = status

        let autoLabel = SKLabelNode(fontNamed: "PressStart2P-Regular")
        autoLabel.text = "AUTO MODE"
        autoLabel.fontSize = 9
        autoLabel.fontColor = NeonPalette.orange
        autoLabel.horizontalAlignmentMode = .center
        autoLabel.verticalAlignmentMode = .center
        autoLabel.position = CGPoint(x: 112, y: Self.boardBottomY + 46 - Self.gutterDrop)
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

    /// Ends the announcement early, doing everything its timer would have done.
    ///
    /// `dismissLevelBanner` on its own is not enough. The announcement pauses
    /// the fleet and the laser pool, and the keyed timer it cancels is the only
    /// thing that hands them back — cutting the banner without this is exactly
    /// how the lasers ended up frozen once already.
    private func endLevelAnnouncement() {
        guard isAnnouncingLevel else { return }
        dismissLevelBanner()
        guard stateMachine.currentState is PlayingState else { return }
        fleet?.setPaused(false)
        laserPool?.setPaused(false)
        beginBeat()
    }

    private func announceLevelThenBegin() {
        guard let announcement = LevelManager.announcement(for: levels.level) else {
            beginBeat()
            return
        }

        // Skipping levels with `V` can arrive mid-banner, or mid-reveal, so
        // clear whatever is up rather than stacking illegibly on top of it.
        clearCentredMessages()

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
        // The title alone. The subtitle is on screen at the same moment in
        // 26-point type, so repeating it here only pushed the lines either side
        // of it off the top of the panel.
        DiagnosticsLog.shared.log(.level, announcement.title)

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
        scorePops?.reset()
        explosions?.reset()
        shatters?.reset()
        regeneration.reset()
        // Torn down, not just reset: `buildPlayfield` makes a fresh controller
        // every level, so resetting the old one left its nodes parented.
        raiders?.teardown()
        raiders = nil
        for side in [PieceColor.black, .white] { setRespawnWarning(side, on: false) }
        clearPowerUpAlley()
        // §13.2: neither the shield nor a running clock carries to the next
        // level. Lifting the effect first puts the world back before the state
        // that describes it is thrown away.
        //
        // Cadet keeps an unused shield, which is the one part of that rule it
        // inverts. A *running* effect still ends either way — Freeze is three
        // seconds and Gatling seven, so carrying one across a level break would
        // mean nothing except a clock ticking over a board that no longer
        // exists.
        cancelSlowMotion()
        if let running = powerUps.cancel() { lift(running) }
        let keepsShield = GameSettings.shared.keepsPowerUps && powerUps.hasShield
        powerUps.reset()
        if keepsShield { powerUps.raiseShield() }
        gatlingCooldown = 0
        gatlingPhase = 0
        isFireHeld = false
        testPowerUpCursor = 0
        ship?.removeShield()
        shake = .none
        shakeElapsed = 0
        freezeRemaining = 0
        respawnRemaining = 0
        afterFreeze = nil
        bloomNode.isPaused = false
        starfieldNode.isPaused = false
        bloomNode.position = .zero
        removeEndBanner()
        dismissLevelBanner()
        for node in bloomNode.children where node.name == Self.gutterNoticeName {
            node.removeAllActions()
            node.removeFromParent()
        }
        hasFiredWarningShot = false
        beatsThisLevel = 0
        isAnnouncingLevel = false
        // Reset, never discarded: the pools outlive the level, and dropping the
        // reference would leave their nodes parented to `bloomNode` forever.
        // Which also means any pause applied to them has to be lifted here.
        laserPool?.deactivateAll()
        laserPool?.setPaused(false)
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
        reabsorbStrays()
        refreshStatus()
    }

    /// A descending black piece landed on a white one: it is gone instantly, no
    /// HP check and no points, because the fleet took it rather than the player.
    private func applyCrush(_ crush: CrushEvent) {
        if let victim = pieceNodes.removeValue(forKey: crush.atSquare) {
            if victim.piece.color == .black {
                scheduleRegeneration(after: victim.piece.type)
            }
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
        // Every route into live play passes through here — the banner ending,
        // the update loop's own restart invariant, a resume from pause — so
        // this is the one place the shield can be raised without missing a
        // path or beating the announcement to it. `setForcefield` is
        // idempotent, so running it every beat costs nothing.
        refreshKingForcefield()
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
            // White's auto-move leans toward pushing a pawn (§7.2's promotion
            // reward). Black's does not, and must not: Black promotes by
            // reaching rank 1, which is a breach, so the same bias would push
            // Black toward ending the run by a route the player cannot read.
            let auto = await board.makeEngineMove(
                constraints: .init(restrictedTo: target, favoursPawnAdvance: true),
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

        // §10.1 counts armor in White's moves, and by here White has moved this
        // beat one way or the other — by hand or by auto-move.
        advanceArmor()

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
        DiagnosticsLog.shared.log(.level, "LEVEL CLEARED — \(label)")

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
    /// wave. Any key continues — unless that was the last wave, in which case
    /// the run is over and won, and the normal game-over flow takes it (final
    /// score, the high-score table, NEW GAME?).
    private func showWaveClearOverlay() {
        guard gameOverNode == nil else { return }
        clearCentredMessages()
        if levels.isFinalLevel {
            outcome = .runCompleted
            DiagnosticsLog.shared.log(.level,
                "RUN COMPLETE — all \(LevelManager.finalLevel) waves cleared")
            stateMachine.enter(GameOverState.self)
            return
        }
        outcome = .waveCleared(next: levels.level + 1)
        let overlay = GameOverNode(outcome: outcome,
                                   score: ScoreManager.shared.currentScore,
                                   sceneSize: size)
        overlay.zPosition = 25
        addChild(overlay)
        gameOverNode = overlay
        isAwaitingWaveContinue = true
        DiagnosticsLog.shared.log(.level, "wave clear")
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
        DiagnosticsLog.shared.log(.fleet, "settling for reveal")

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
        clearCentredMessages()
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

    /// Clears every full-screen message before a new one goes up.
    ///
    /// The reveal banner ("BLACK KING DESTROYED") holds for 2.5s and was only
    /// ever removed when the board was torn down, so the wave-clear overlay
    /// arrived on top of it and LEVEL CLEARED! was read through the message
    /// underneath. Anything that puts up a centred message calls this first, so
    /// there is only ever one to read.
    private func clearCentredMessages() {
        removeEndBanner()
        dismissLevelBanner()
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
    /// Does a black piece standing on `square` belong in the formation?
    ///
    /// Measured against the fleet's own rear rank, which is derived from how
    /// far it has descended — so it holds even when the formation is empty and
    /// has to re-form from stragglers.
    private func marchesAfterMoving(to square: String) -> Bool {
        guard let fleet else { return false }
        return FleetRules.staysInFormation(afterMovingTo: square,
                                           formationRearRank: fleet.rearRank,
                                           ranks: levels.parameters.formationRanks)
    }

    /// Puts a stray black piece back in the formation, sliding it into step.
    private func rejoinFleet(_ node: PieceNode, at square: String) {
        guard let boardNode, let fleet, !fleet.contains(node),
              let centre = boardNode.center(of: square) else { return }
        // The bob owns `position` through a repeatForever; the slide has to.
        node.stopIdleBob()
        fleet.adopt(node, square: square, atLogicalCentre: centre,
                    slidingFrom: node.position)
        node.run(.sequence([.wait(forDuration: 0.2),
                            .run { node.startIdleBob() }]))
        DiagnosticsLog.shared.log(.fleet, "\(square) rejoins")
    }

    /// After a rank descent the formation has moved down onto the board, so any
    /// stray black piece now inside its band is swept up by it. The fleet reads
    /// as a body that reabsorbs stragglers rather than as a set that only ever
    /// shrinks.
    private func reabsorbStrays() {
        guard let fleet else { return }
        for (square, node) in pieceNodes
        where node.piece.color == .black && !fleet.contains(node) {
            guard marchesAfterMoving(to: square) else { continue }
            rejoinFleet(node, at: square)
        }
    }

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
            && settingsNode == nil
            // Auto Chess wires in here and nowhere else. It is not a mechanics
            // change — `resolveBeat` already engine-moves White whenever the
            // player doesn't — so refusing the input is the whole of it, and
            // selection, the legal-move dots and the capture tethers all fall
            // silent together because they all pass through this one gate.
            && !GameSettings.shared.autoChess
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
        // Where the victim stood, captured before its node goes: the score pop
        // below needs the position, and by then the node is out of `pieceNodes`.
        var victimPosition: CGPoint?
        if let capturedSquare = outcome.capturedSquare,
           let victim = pieceNodes.removeValue(forKey: capturedSquare) {
            victimPosition = bloomPosition(of: victim)
            // §23.9 regenerates "destroyed black pieces" — however they died.
            // This used to fire only on a laser kill, so taking a piece with a
            // chess move quietly bought the player a permanent removal that
            // shooting the same piece did not.
            if victim.piece.color == .black {
                scheduleRegeneration(after: victim.piece.type)
            }
            detachFromFleet(victim)
            victim.runDestructionAnimation {}
        }

        // Only the player's captures score; Black taking White pieces must not
        // reward the player. Chess captures score at the lower of the two
        // tables (§9) — pointValue is the higher, shoot-to-kill rate.
        if let captured = outcome.captured, captured.color == .black {
            if let victimPosition {
                scorePops?.pop(ScoreManager.shared.scaled(captured.type.chessCaptureValue),
                               at: victimPosition, color: NeonPalette.magenta)
            }
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
        if outcome.moved.color == .black, let fleet, marchesAfterMoving(to: outcome.to) {
            if fleet.contains(node) {
                // Stays parented to the fleet; `animateMove` below still targets
                // the logical square centre, which is a member's local position.
                if !fleet.rekey(from: outcome.from, to: outcome.to) {
                    detachFromFleet(node)
                }
            } else {
                // Membership used to be one-way: `adopt` ran only at board build
                // time, so a piece that stepped out of the band once was a
                // civilian for the rest of the level however far back it came.
                // That is worst for the king, which then parks behind White's
                // own pawns where it is nearly unshootable — the exact problem
                // the marching rule exists to prevent.
                rejoinFleet(node, at: outcome.to)
            }
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

        if outcome.promotedTo != nil {
            AudioManager.shared.play(.pawnPromotion)
        }

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


    /// How far the PAUSED banner sits above centre, and how far its hint sits
    /// below the banner.
    ///
    /// Pausing over a reveal banner used to bury it: both are centred, so
    /// "PAUSED" landed exactly on "BLACK KING DESTROYED" and neither could be
    /// read. Lifted clear, both are legible at once — which matters most in the
    /// case the player is most likely to pause in.
    ///
    /// The numbers are computed, not judged by eye. Press Start 2P draws about
    /// 0.7em of cap height and `.center` alignment centres that box on the
    /// node, so the 30pt reveal banner reaches 10.5pt above centre. At this
    /// lift the hint's lower edge lands at 22 — nearly 12pt of daylight — and
    /// the 36pt title clears it by another 9.
    /// Raised by 5 over the hint, which stays put: `pauseHintGap` moves with
    /// the lift so the extra separation lands between the two lines rather than
    /// pushing the pair up the screen.
    static let pauseLift: CGFloat = 57
    static let pauseHintGap: CGFloat = 31

    func showPausedOverlay() {
        // Phase 0: simple "PAUSED" label; proper pause menu in Phase 5
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.name = "pausedLabel"
        label.text = "PAUSED"
        label.fontSize = 36
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode   = .center
        label.position = CGPoint(x: size.width / 2,
                                 y: size.height / 2 + Self.pauseLift)
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
        hint.position = CGPoint(x: size.width / 2,
                                y: size.height / 2 + Self.pauseLift - Self.pauseHintGap)
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
        raiders?.setPaused(true)
        // The key-up that ends a spray is delivered to whatever is listening
        // when it happens. Releasing the trigger while paused would otherwise
        // never be seen, and the hose would still be running on resume.
        isFireHeld = false
        cancelSlowMotion()
        DiagnosticsLog.shared.log(.level, "PAUSED")
    }

    func hidePausedOverlay() {
        removePausedOverlay()
        laserPool?.setPaused(false)
        // A Time Freeze that was running when the player paused is still
        // running now — unpausing everything here would end it early and leave
        // its clock ticking against a world that had already resumed.
        fleet?.setPaused(isTimeFrozen)
        raiders?.setPaused(isTimeFrozen)
        laserPool?.setPaused(isTimeFrozen, owner: .enemy)
    }

    /// Whether the player has the game stopped. `lift` consults this so an
    /// effect expiring behind a PAUSED banner cannot resume the world.
    private var isGamePaused: Bool { stateMachine.currentState is PausedState }

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
        clearCentredMessages()
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
        DiagnosticsLog.shared.log(.level, "\(outcome.headline) — \(ScoreManager.shared.currentScore)")
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
        DiagnosticsLog.shared.log(.score, "high score — name?")
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
        // `isShipDown` covers the second between being destroyed and coming
        // back: a wreck should not be shooting, and firing from a hidden ship
        // is the tell that made the lost-respawn bug look like a rendering
        // fault rather than a state one.
        guard stateMachine.currentState is PlayingState, !isBeatSuspended, !isShipDown,
              let ship, let shipState, shipState.canFire,
              let laserPool, let laser = laserPool.nextAvailable(owner: .player)
        else { return }

        shipState.laserFired()
        laser.onDeactivate = { [weak shipState] in shipState?.laserResolved() }
        let origin = CGPoint(x: ship.position.x, y: ship.position.y + ship.size.height / 2)
        laser.fire(from: origin, damage: ProjectileState.playerLaserDamage,
                  speed: GameSettings.shared.playerLaserSpeed,
                  travelDistance: size.height - origin.y)
        AudioManager.shared.play(.playerLaserFire)
        DiagnosticsLog.shared.log(.shoot, "ship fires \(shipState.activeLasers)/\(shipState.laserCap)")
    }

    /// Once per beat, after the position has settled (§5.3): 0–`shotsPerTurn`
    /// fleet pieces fire straight down, weighted toward the front rank.
    /// One firing phase per chess beat (§5.3). Called from `resolveBeat` after
    /// the position has settled, so a shot never races a chess move landing on
    /// the same square.
    private func fireFleetShots() {
        // The board, not the laser pool: the pool now outlives the level, so its
        // presence no longer means a wave is in progress.
        guard boardNode != nil else { return }
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
            // Charged up like every other gunner, rather than appearing out of
            // nowhere. Without the telegraph the round had no visible source:
            // the fleet keeps sweeping while a shot falls straight, so by the
            // time the eye found the missile the king had already slid out
            // from behind it and the shot read as coming from off to one side.
            let lean = kingLean(from: king.logicalSquare)
            let speed = level.projectileSpeed * FleetRules.kingShotSpeedMultiplier
                * (lean == 0 ? 1 : FleetRules.kingAngledShotBoost)
            scheduleInvaderShot(
                from: king.logicalSquare, after: 0,
                speed: speed,
                lean: lean,
                sound: .kingLaserFire,
                damage: FleetRules.kingShotDamage,
                heavy: true,
                note: "black king fires")
        }

        let candidates = board.allPieces(color: .black)
            .filter { pieceNodes[$0.logicalSquare]?.isMaterialising != true }
            .map { FleetFiring.Candidate(square: $0.logicalSquare, type: $0.type) }

        // Crossfire: the bishops fire together on their own cadence, so two
        // diagonals cross in the same instant rather than one angled round
        // arriving at random.
        if level.diagonalShots, beatsThisLevel % FleetRules.bishopShotInterval == 0 {
            for square in FleetFiring.diagonalShooters(from: candidates) {
                scheduleInvaderShot(from: square, after: 0,
                                    speed: FleetRules.diagonalShotSpeed,
                                    lean: bishopLean(from: square),
                                    sound: .crossfireLaserFire)
            }
        }

        let gunners = FleetFiring.gunners(from: candidates)
        let count = FleetFiring.volleySize(FleetFiring.shotCount(for: level),
                                           gunners: gunners.count)
        guard count > 0 else { return }
        let shooters = FleetFiring.chooseShooters(from: gunners, count: count)

        // Spread the volley across a fraction of a second rather than firing it
        // in one instant. Same rate, but three simultaneous rounds read as one
        // event, and staggered ones read as three pieces choosing to shoot.
        for (index, square) in shooters.enumerated() {
            scheduleInvaderShot(from: square, after: Double(index) * Self.volleyStagger,
                                speed: level.projectileSpeed, lean: 0,
                                sound: .invaderLaserFire)
        }
    }

    /// The king inflects rather than committing: most rounds go straight down,
    /// and the rest lean gently toward one of White's pieces. A king that
    /// always fired straight ahead read as the wrong piece's weapon — the king
    /// is the one piece that moves in every direction.
    private func kingLean(from square: String) -> CGFloat {
        guard Double.random(in: 0..<1) < FleetRules.kingShotAngleShare else { return 0 }
        guard let target = board.allPieces(color: .white).randomElement() else { return 0 }
        return FleetRules.diagonalSlope(
            fromFile: Self.fileIndex(of: square), rank: Self.rankIndex(of: square),
            towardFile: Self.fileIndex(of: target.logicalSquare),
            rank: Self.rankIndex(of: target.logicalSquare),
            minSlope: FleetRules.kingMinSlope, maxSlope: FleetRules.kingMaxSlope)
    }

    /// The angle this bishop should fire at: leaning toward one of White's own
    /// pieces, picked fresh each time so the pair does not fire the same shape
    /// every beat. With nothing left to aim at, lean over the ship's lane —
    /// the board is empty, so that is where the player must be.
    private func bishopLean(from square: String) -> CGFloat {
        let rank = Self.rankIndex(of: square)
        let targets = board.allPieces(color: .white)
        guard let target = targets.randomElement() else {
            let originX = boardNode?.position.x ?? 0
            let lane = ship.map { Int(($0.position.x - originX) / BoardNode.squareSize) }
            return FleetRules.diagonalSlope(fromFile: Self.fileIndex(of: square), rank: rank,
                                            towardFile: lane ?? 4, rank: 0)
        }
        return FleetRules.diagonalSlope(
            fromFile: Self.fileIndex(of: square), rank: rank,
            towardFile: Self.fileIndex(of: target.logicalSquare),
            rank: Self.rankIndex(of: target.logicalSquare))
    }

    /// Charges a gunner up, then fires it.
    ///
    /// The charge-up is the whole point: a shot used to appear at the same
    /// instant as its muzzle flare, so the flare was a record of what had
    /// already happened rather than a warning. Now the piece glows for
    /// `chargeUpDelay` first, and the glow is drawn along the line the round
    /// will take — so at Crossfire the *angle* is readable before the missile
    /// exists, which is the part the player actually has to plan around.
    private func scheduleInvaderShot(from square: String, after delay: TimeInterval,
                                     speed: CGFloat, lean: CGFloat, sound: SoundKey,
                                     damage: Int = ProjectileState.enemyShotDamage,
                                     heavy: Bool = false,
                                     note: String? = nil) {
        let charge = SKAction.run { [weak self] in
            guard let self, self.isFiringLive else { return }
            self.telegraphShot(at: square, lean: lean, heavy: heavy)
        }
        let fire = SKAction.run { [weak self] in
            guard let self, self.isFiringLive else { return }
            self.fireInvaderShot(from: square, speed: speed, damage: damage,
                                 heavy: heavy, lean: lean, sound: sound, note: note)
        }
        run(.sequence([.wait(forDuration: delay), charge,
                       .wait(forDuration: FleetRules.chargeUpDelay), fire]))
    }

    /// Both halves of a scheduled shot check this: a volley is spread over most
    /// of a second, and the game can be paused, lost or won inside that window.
    private var isFiringLive: Bool {
        !isBeatSuspended && stateMachine.currentState is PlayingState
    }

    /// The charge-up cue: the gunner brightens, and a tick grows out of it
    /// along the line the shot will travel.
    private func telegraphShot(at square: String, lean: CGFloat, heavy: Bool = false) {
        guard let node = pieceNodes[square] else { return }
        let angled = lean != 0
        // The king's charge is white, matching the round it is about to throw.
        let tint = heavy ? SKColor.white
                 : angled ? NeonPalette.shotPurple : NeonPalette.magenta

        let tick = SKShapeNode(rectOf: CGSize(width: 2.5, height: BoardNode.squareSize * 0.42),
                               cornerRadius: 1.25)
        tick.fillColor = tint
        tick.strokeColor = .white
        tick.lineWidth = 0.75
        tick.glowWidth = 4
        tick.zPosition = 2
        // Grows out of the piece's foot, pointing exactly where the round will
        // go — the same `atan2(dx, -dy)` the round itself is aimed by, so the
        // cue cannot promise one angle and the missile take another.
        tick.zRotation = atan2(lean, 1)
        tick.position = CGPoint(x: lean * node.size.width * 0.22,
                                y: -node.size.height * 0.42)
        tick.setScale(0.2)
        tick.alpha = 0
        node.addChild(tick)
        tick.run(.sequence([
            .group([.scale(to: 1.0, duration: FleetRules.chargeUpDelay),
                    .fadeAlpha(to: 0.95, duration: FleetRules.chargeUpDelay * 0.6)]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent(),
        ]))
        node.flareGunner(tint: tint, duration: FleetRules.chargeUpDelay)
    }

    /// Spawns one invader round from `square`, if the piece is still there and a
    /// pooled laser is free.
    private func fireInvaderShot(from square: String, speed: CGFloat,
                                 damage: Int = ProjectileState.enemyShotDamage,
                                 heavy: Bool = false,
                                 lean: CGFloat = 0,
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
        // The caller owns the speed. This used to force *every* leaning round
        // to §21.3's 160 px/s, which was right when only bishops leaned — but
        // the king leans now too, and the override silently threw away its
        // weapon's speed and made its angled shot the slowest thing on screen.
        // The bishops pass `diagonalShotSpeed` themselves.
        laser.fire(from: origin, damage: damage, speed: speed,
                   travelDistance: origin.y, lean: lean)
        flashMuzzle(at: square)
        AudioManager.shared.play(sound)
        DiagnosticsLog.shared.log(.shoot, note ?? "black \(square) fires")
    }

    /// 1 through 8, or 0 for a square that does not parse.
    private static func rankIndex(of square: String) -> Int {
        Int(String(square.suffix(1))) ?? 0
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
    // MARK: - Regeneration (§23.9) and armored pawns (§10.1)

    private static let respawnWarningName = "respawnWarning"
    /// One line per active power-up: Rapid Fire, a shield, a running timed
    /// effect. Three at once is only reachable with the `P` test key in play —
    /// the shield is offered on Level 3 alone, where Rapid Fire is not — but
    /// each gets a line of its own regardless, because a shared line reads as
    /// one status rather than two.
    static let powerUpAlleyLines = 3
    private static let powerUpLineName = "powerUpLine"

    /// The left gutter is fuller than it looks. Measured at x=112, top down:
    ///
    /// | occupant | glyph band |
    /// |---|---|
    /// | turn-timer caption (8pt @ 184) | 180 – 188 |
    /// | turn-timer digits (22pt @ 166), or AUTO MODE (9pt) | 155 – 177 |
    /// | transient notice — SKIP LEVEL, RESPAWNING (9pt @ 150) | 146 – 155 |
    /// | status side label (10pt @ 133) | 128 – 138 |
    /// | status state label (15pt @ 116) | 109 – 124 |
    /// | the ship's own lane | 42 – 82 |
    ///
    /// Which leaves exactly one usable band — **82 to 109**, 27pt — and the gaps
    /// between the rest are 0.5 to 7.5pt, too narrow for a 9pt line. The first
    /// version of this readout sat at 182 and 198, chosen by eye against the
    /// timer's *centre* at 166 without accounting for its caption 18pt above it,
    /// so the bottom line landed straight on top of the caption. Hence the
    /// table: the next person to add a gutter line should not have to rediscover
    /// this.
    ///
    /// Three 9pt lines with 5pt of air between them need 37pt. The band under
    /// the status line is 27, which is why the readout lived there while it was
    /// two lines and cannot stay now: two lines at a 5pt gap already left only
    /// 1pt of clearance at the top.
    ///
    /// So it moves to the other side of the turn timer. Above the timer's caption
    /// the gutter is empty all the way to the HUD at y=664 — 476pt, against the
    /// 37 needed — so the block sits just clear of the caption and grows upward
    /// into space nothing else wants. `PowerUpAlleyLayoutTests` pins it against
    /// every neighbour, because eyeballing this is what produced the first
    /// collision.
    static let powerUpAlleyBottomY: CGFloat = 196
    static let powerUpAlleyStep: CGFloat = 14      // 9pt of type, 5pt of air
    static let powerUpAlleyFontSize: CGFloat = 9
    private static let powerUpBarName = "powerUpBar"
    static let powerUpBarWidth: CGFloat = 84
    /// The countdown bar sits under the bottom line, which is always the timed
    /// effect — it is appended last, and the block stacks upward from a fixed
    /// floor, so the bar never moves.
    static let powerUpBarY = GameScene.powerUpAlleyBottomY - 7
    /// The stack the notice is currently showing, so it only flares when the
    /// number actually changes rather than on every frame.
    private var shownRapidFireStacks = 0

    /// The standing power-up readout in the player's alley: what is up, and how
    /// long a timed effect has left.
    ///
    /// It used to be a one-second flash at the moment each was granted. These
    /// are rare and they last — a shield until it is spent, Rapid Fire for the
    /// rest of the wave — so the player needs to be able to *check* what they
    /// are carrying, not catch it in passing. Mirrors the state rather than
    /// latching, so no line can outlive the thing it describes.
    ///
    /// One line each, never shared: two statuses on one line read as one.
    private func syncPowerUpAlley() {
        var lines: [(text: String, color: SKColor)] = []

        let stacks = (shipState?.laserCap ?? SpaceshipState.baseLaserCap)
            - SpaceshipState.baseLaserCap
        if stacks > 0 {
            // The name only. The laser cap used to be appended, which turned a
            // status into a readout the player had to parse — and the number was
            // never actionable: what matters is that Rapid Fire is up, and the
            // ship's own hull already brightens with each stack.
            lines.append((PowerUp.rapidFire.label, NeonPalette.transporterGreen))
        }
        if powerUps.hasShield {
            lines.append((PowerUp.shield.label, PowerUp.shield.tint))
        }
        var countdown: (progress: CGFloat, color: SKColor)?
        if let active = powerUps.active, let duration = active.duration {
            lines.append((active.label, active.tint))
            // §13.2's countdown bar, back now that the block has moved somewhere
            // with a row to spare. A bar rather than the seconds it briefly
            // showed instead: a shrinking length is read without being read,
            // which is what a status in the corner of the eye needs to be.
            countdown = (CGFloat(max(0, powerUps.remaining) / duration), active.tint)
        }
        syncPowerUpBar(countdown)

        for index in 0..<Self.powerUpAlleyLines {
            let label = alleyLabel(index)
            guard index < lines.count else {
                label.isHidden = true
                continue
            }
            label.isHidden = false
            label.text = lines[index].text
            label.fontColor = lines[index].color
            // Bottom-up from a fixed floor, so the first line the player earns
            // stays where they last read it and later ones stack above it.
            label.position = CGPoint(
                x: 112,
                y: Self.powerUpAlleyBottomY
                    + CGFloat(lines.count - 1 - index) * Self.powerUpAlleyStep)
        }

        // The change is the event; the line itself is the reference.
        guard stacks != shownRapidFireStacks else { return }
        shownRapidFireStacks = stacks
        guard stacks > 0 else { return }
        let label = alleyLabel(0)
        label.removeAllActions()
        label.setScale(1)
        label.run(.sequence([
            .group([.scale(to: 1.4, duration: 0.12),
                    .colorize(with: .white, colorBlendFactor: 1, duration: 0.12)]),
            .group([.scale(to: 1.0, duration: 0.25),
                    .colorize(with: NeonPalette.transporterGreen,
                              colorBlendFactor: 1, duration: 0.25)]),
        ]))
    }

    /// The countdown bar under the bottom line, or nothing when no timed effect
    /// is running.
    private func syncPowerUpBar(_ countdown: (progress: CGFloat, color: SKColor)?) {
        let existing = bloomNode.childNode(withName: Self.powerUpBarName) as? SKSpriteNode
        guard let countdown else { return existing?.removeFromParent() ?? () }
        let bar = existing ?? {
            let fresh = SKSpriteNode(color: .white,
                                     size: CGSize(width: Self.powerUpBarWidth, height: 3))
            fresh.name = Self.powerUpBarName
            fresh.anchorPoint = CGPoint(x: 0, y: 0.5)
            fresh.position = CGPoint(x: 112 - Self.powerUpBarWidth / 2,
                                     y: Self.powerUpBarY)
            fresh.zPosition = 12
            bloomNode.addChild(fresh)
            return fresh
        }()
        bar.color = countdown.color
        bar.size.width = max(0, Self.powerUpBarWidth * countdown.progress)
    }

    /// Pooled, because these are rebuilt every frame and a readout is not worth
    /// a node churn.
    private func alleyLabel(_ index: Int) -> SKLabelNode {
        let name = "\(Self.powerUpLineName)\(index)"
        if let existing = bloomNode.childNode(withName: name) as? SKLabelNode {
            return existing
        }
        let fresh = SKLabelNode(fontNamed: "PressStart2P-Regular")
        fresh.name = name
        fresh.fontSize = Self.powerUpAlleyFontSize
        fresh.horizontalAlignmentMode = .center
        fresh.verticalAlignmentMode = .center
        fresh.zPosition = 12
        bloomNode.addChild(fresh)
        return fresh
    }

    private func clearPowerUpAlley() {
        for index in 0..<Self.powerUpAlleyLines {
            bloomNode.childNode(withName: "\(Self.powerUpLineName)\(index)")?
                .removeFromParent()
        }
        bloomNode.childNode(withName: Self.powerUpBarName)?.removeFromParent()
        shownRapidFireStacks = 0
    }

    /// A flashing green warning while anything is about to materialise.
    ///
    /// Mirrors state rather than reacting to events, so two arrivals due at
    /// once raise one warning and nothing can leave a stale one on screen. In
    /// the left gutter, high for Black and low for White, so the side it
    /// belongs to is readable without stopping to read it — White is unused
    /// today and waiting for a power-up that brings a piece back.
    private func syncRespawnWarnings() {
        setRespawnWarning(.black, on: regeneration.isWarning)
        // Nothing white regenerates yet. The ship's own one-second respawn is
        // deliberately silent — it is short, it is centre-screen, and the
        // player already knows they were hit. The white branch below stays in
        // place for the white-piece respawns a power-up would bring, which is
        // the only thing that would need it.
    }

    private func setRespawnWarning(_ side: PieceColor, on: Bool) {
        let name = "\(Self.respawnWarningName)-\(side)"
        let existing = bloomNode.childNode(withName: name)
        guard on else { return existing?.removeFromParent() ?? () }
        guard existing == nil else { return }

        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.name = name
        label.text = "RESPAWNING"
        label.fontSize = 9
        label.fontColor = NeonPalette.transporterGreen
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 12
        label.position = CGPoint(
            x: 112,
            y: side == .black ? Self.boardBottomY + BoardNode.boardSize - 40
                              : Self.boardBottomY - 40)
        label.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.28), .fadeAlpha(to: 1.0, duration: 0.28),
        ])))
        bloomNode.addChild(label)
    }

    // MARK: - Raiders (§6)

    /// How many black pieces still stand on the fleet's rear rank — the gate
    /// early levels hold the scout behind.
    private var rearRankPieces: Int {
        guard let fleet else { return 0 }
        let rear = fleet.rearRank
        return board.allPieces(color: .black)
            .filter { Self.rankIndex(of: $0.logicalSquare) == rear }
            .count
    }

    /// §6: "one projectile straight down from its current x-position", acid
    /// green, behaving like a black-piece shot — it damages white pieces and
    /// kills the ship. It comes out of the enemy pool for exactly that reason.
    private func fireScoutShot(from point: CGPoint) {
        guard let laserPool, let laser = laserPool.nextAvailable(owner: .enemy) else { return }
        // The scout is a child of `bloomNode` and so is the laser pool, so the
        // point needs no conversion — it is already in the right space.
        laser.fire(from: point, damage: ProjectileState.enemyShotDamage,
                   speed: RaiderRules.shotSpeed(level: levels.parameters),
                   travelDistance: point.y, tint: NeonPalette.acidGreen)
        AudioManager.shared.play(.scoutLaserFire)
        DiagnosticsLog.shared.log(.raider, "scout fires")
    }

    private func resolveRaiderExit(_ node: RaiderNode, destroyed: Bool) {
        guard destroyed else { return }
        let at = bloomPosition(of: node)
        let powerUp = node.powerUp
        let points = ScoreManager.shared.scaled(powerUp.points)
        // §13.3: a special goes up bigger than the plain green scout, in its own
        // colour, and says what it just handed over.
        explosions?.burst(at: at, color: powerUp.tint,
                          scale: powerUp == .rapidFire ? 1.4 : 2.2)
        scorePops?.pop(points, at: at, color: powerUp.tint)
        ScoreManager.shared.addPoints(powerUp.points, logged: false)
        refreshHUD()
        activate(powerUp, at: at)
        DiagnosticsLog.shared.log(.raider,
            "\(powerUp.shipName) scout destroyed (\(points))")
    }

    // MARK: - Power-ups (§13)

    /// §13.2's Time Freeze, holding the world but not the player.
    private var isTimeFrozen: Bool { powerUps.isFrozen }

    /// A special scout was shot. §13.1: the effect starts here, on the kill —
    /// there is no pickup to collect and nothing falls.
    private func activate(_ powerUp: PowerUp, at point: CGPoint) {
        flashPowerUpLabel(powerUp, at: point)

        switch powerUp {
        case .rapidFire:
            // §13.1 reserves power-ups for the special scouts; the plain green
            // one carries this instead. It was the promotion reward, and
            // crowning a pawn is far too rare to be the only source — most runs
            // never see one, so the reward effectively did not exist.
            AudioManager.shared.play(.raiderDestroyed)
            grantRapidFire()

        case .shield:
            powerUps.raiseShield()
            ship?.applyShield()
            AudioManager.shared.play(.repairScoutDestroyed)

        case .nuke:
            // Instant and over in 0.4s, so it never touches the effect clock —
            // a nuke does not displace a running freeze or barrage, and §13.1's
            // "one at a time" was never about it.
            AudioManager.shared.play(.bombShockwave)
            detonate(at: point)

        case .freeze, .gatling:
            // §13.1: a second effect replaces the first immediately. The one it
            // displaced has to have its world changes lifted first, or a freeze
            // cut short by a barrage would leave the fleet paused for the rest
            // of the wave.
            if let displaced = powerUps.begin(powerUp) { lift(displaced) }
            apply(powerUp)
        }
        syncPowerUpAlley()
    }

    /// Starts a timed effect's world changes.
    private func apply(_ powerUp: PowerUp) {
        switch powerUp {
        case .freeze:
            AudioManager.shared.play(.iceScoutDestroyed)
            // Everything that moves on an SKAction rather than through the
            // update loop has to be told; everything the update loop drives is
            // gated on `isTimeFrozen` where it is ticked.
            fleet?.setPaused(true)
            raiders?.setPaused(true)
            laserPool?.setPaused(true, owner: .enemy)
            starfieldNode.isPaused = true
            // §13.2's one sanctioned use of `rate`: the music slows and deepens
            // rather than a separate sound announcing the freeze.
            AudioManager.shared.setMusicRate(0.5)
            washScreen(NeonPalette.iceBlue)

        case .gatling:
            AudioManager.shared.play(.spreadScoutDestroyed)
            // Fires on the next frame rather than after a first interval: the
            // barrage should start the instant the scout dies.
            gatlingCooldown = 0

        case .rapidFire, .shield, .nuke:
            break
        }
    }

    /// Undoes a timed effect's world changes, whether it expired or was
    /// displaced. Deliberately does not consult `powerUps` — by the time this
    /// runs, `active` may already be the effect that replaced this one.
    private func lift(_ powerUp: PowerUp) {
        switch powerUp {
        case .freeze:
            AudioManager.shared.play(.iceEffectExpires)
            // Only if the player has not paused in the meantime, which owns
            // the same three switches and would otherwise be overruled here.
            if !isGamePaused {
                fleet?.setPaused(false)
                raiders?.setPaused(false)
                laserPool?.setPaused(false, owner: .enemy)
                starfieldNode.isPaused = false
            }
            AudioManager.shared.setMusicRate(1.0)

        case .gatling:
            AudioManager.shared.play(.uiSciFiPing)

        case .rapidFire, .shield, .nuke:
            break
        }
    }

    /// §13.2's Spread Fire, rebuilt as a sweeping hose: one stream, ten rounds a
    /// second, the angle oscillating through ±20° — Missile Command's spray
    /// rather than a fixed fan.
    ///
    /// It fires only while the player holds the fire key. §13.2 has the ship
    /// auto-fire for the duration, which sounds generous and plays badly: the
    /// power-up took the trigger away at the exact moment it handed over more
    /// firepower, so the most powerful thing in the game was also the one moment
    /// the player was not shooting. Holding the key is the whole difference
    /// between operating a hose and watching one.
    ///
    /// Fires outside `SpaceshipState` entirely rather than raising `laserCap`
    /// to some large number. The cap counts rounds in flight and frees a slot
    /// when each one resolves; a spray that borrowed those slots would leave
    /// the count wherever the last round happened to strand it when the effect
    /// ended, and the player would come out of the power-up unable to fire.
    /// Spray rounds are simply not the ship's rounds.
    /// Twelve rounds a second — genuinely rapid, and it can afford to be now
    /// that it is one stream rather than five. The old five-way volley at four a
    /// second put twenty rounds a second up; this puts twelve, and every one of
    /// them is somewhere slightly different.
    static let gatlingInterval: TimeInterval = 1.0 / 12

    /// The highest point a spray round reaches before it burns out.
    ///
    /// Expressed as a *ceiling* rather than a distance, because the constraint
    /// is which rank it may touch: ordinary player fire crosses the whole board
    /// and this deliberately does not. An uncapped spray cleared everything from
    /// the ship's rank to the eighth regardless of where the fleet was, so
    /// collecting it simply ended the wave.
    ///
    /// Rank 7 runs 504–568 with its pieces centred on 536, and rank 8 begins at
    /// 568. Burning out at 556 puts the spray past the middle of a rank-7 piece
    /// and 12pt clear of the nearest rank-8 one — so the seventh row is
    /// reachable and the eighth has to be earned the ordinary way.
    ///
    /// The distance this works out to is 7.4 squares, not the round 7 it looks
    /// like it should be: a flat "one more square" than the previous six landed
    /// at 530, which is 6pt *short* of rank 7's centre and would only ever have
    /// clipped the bottom of a piece there. Aiming at the rank rather than at a
    /// round number of squares is the difference between reaching it and nearly
    /// reaching it.
    static let gatlingCeiling: CGFloat =
        GameScene.boardBottomY + BoardNode.squareSize * 7 - 12

    /// The same thing as a travel distance, from the ship's muzzle. Derived, so
    /// the pool arithmetic and the tests cannot drift from the ceiling.
    static var gatlingReach: CGFloat {
        gatlingCeiling - (shipLaneY + SpaceshipNode.displayHeight / 2)
    }
    /// How far the spray swings either side of vertical, as a slope —
    /// `LaserNode.fire` takes sideways travel per unit of forward travel, not an
    /// angle. 0.364 is 20°.
    ///
    /// §13.2 built this as five simultaneous streams at fixed angles, which is
    /// what made it uncontrollable: five arms covering the board at once meant
    /// there was nothing to aim, and at its original ±40° a single round crossed
    /// 518pt sideways climbing a 618pt board — wider than the whole board.
    /// Narrowing the fan twice helped and never fixed the shape of the problem.
    ///
    /// One stream that *sweeps* is a different weapon. Only one round is ever on
    /// its way to a given place, so the player is pointing a hose rather than
    /// standing behind a wall of fire, and ±20° is generous precisely because
    /// coverage now costs time.
    static let gatlingMaxLean: CGFloat = 0.364

    /// How long one full left-right-left sweep takes.
    ///
    /// Chosen against the fire rate rather than by feel: at twelve rounds a
    /// second, 1.8s puts about eleven rounds in each half-sweep, so consecutive
    /// rounds leave under 4° apart and the arc reads as a ribbon rather than a
    /// row of separate shots. That ribbon is the whole effect. Sweep faster and
    /// it breaks into scatter; slower and it stops looking like spray.
    static let gatlingSweepPeriod: TimeInterval = 1.8

    private func advanceGatling(_ dt: TimeInterval) {
        guard powerUps.isGatling, !isBeatSuspended else { return }
        // The sweep runs whether or not the trigger is down, so releasing and
        // pressing again picks the hose up where it had got to rather than
        // restarting the arc from centre every time.
        gatlingPhase += dt
        guard isFireHeld, !isShipDown, let ship, let laserPool else { return }
        gatlingCooldown -= dt
        guard gatlingCooldown <= 0 else { return }
        gatlingCooldown = Self.gatlingInterval

        let origin = CGPoint(x: ship.position.x, y: ship.position.y + ship.size.height / 2)
        // From the ceiling rather than a fixed distance, so the burnout height
        // is the same wherever the muzzle happens to be.
        let reach = min(Self.gatlingCeiling - origin.y, size.height - origin.y)
        guard reach > 0 else { return }
        let sweep = sin(2 * .pi * gatlingPhase / Self.gatlingSweepPeriod)
        guard let laser = laserPool.nextAvailable(owner: .player) else { return }
        laser.onDeactivate = nil
        // Spray rounds pass straight through White's pieces. There are a great
        // many of them and the sweep aims them, not the player, so friendly fire
        // would make the reward demolish their own position for them.
        laser.fire(from: origin, damage: ProjectileState.playerLaserDamage,
                   speed: ProjectileState.playerLaserSpeed,
                   travelDistance: reach,
                   lean: Self.gatlingMaxLean * CGFloat(sweep),
                   tint: NeonPalette.orange, sparesFriendlies: true,
                   fadesOut: true)
        AudioManager.shared.play(.playerLaserFire)
    }

    /// §13.2's Nuke: a ring that clears every enemy round it passes over, and
    /// detonates the nearest black pieces on the way.
    ///
    /// The doc's version only cleared projectiles, which is invisible — the
    /// player saw a big ring and then an absence, and read it as some buff they
    /// could not identify. Deleting things is not an effect you can see. The
    /// kills are what make the ring legible; the projectile clear is what makes
    /// it useful, and it stays.
    ///
    /// Each victim gets a fragment thrown at it from the blast centre, timed to
    /// arrive exactly when the ring does. Without it the ring and the explosions
    /// are two things that happen near each other; with it there is a line drawn
    /// from cause to effect, which is the whole difference.
    private func detonate(at point: CGPoint) {
        beginSlowMotion()
        let reach = (size.width * size.width + size.height * size.height).squareRoot()
        // Twice the 0.4s it opened at, and then the slow-motion clock stretches
        // it again — a shockwave that crosses the board in a third of a second
        // is over before the eye has found it.
        let duration: TimeInterval = 0.85
        let ring = SKShapeNode(circleOfRadius: 1)
        ring.position = point
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.glowWidth = 6
        ring.zPosition = 14
        bloomNode.addChild(ring)

        ring.run(.sequence([
            .customAction(withDuration: duration) { [weak self] node, elapsed in
                guard let self, let shape = node as? SKShapeNode else { return }
                let progress = min(1, CGFloat(elapsed) / CGFloat(duration))
                let radius = reach * progress
                shape.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius,
                                                      width: radius * 2,
                                                      height: radius * 2),
                                    transform: nil)
                // §13.2's magenta → white → transparent, so the wave reads as
                // energy leaving rather than as a circle being drawn.
                shape.strokeColor = NeonPalette.magenta.blended(toward: .white,
                                                               by: progress)
                shape.alpha = 1 - progress * progress
                self.clearEnemyRounds(within: radius, of: point)
            },
            .removeFromParent(),
        ]))

        throwFragments(from: point, ringReach: reach, ringDuration: duration)
    }

    /// Picks the blast's victims and sends a fragment to each.
    private func throwFragments(from point: CGPoint, ringReach: CGFloat,
                                ringDuration: TimeInterval) {
        var candidates: [(square: String, distance: Double, isKing: Bool)] = []
        var found: [String: (at: CGPoint, distance: CGFloat)] = [:]
        for (square, node) in pieceNodes where node.piece.color == .black {
            let at = bloomPosition(of: node)
            let dx = at.x - point.x, dy = at.y - point.y
            let distance = (dx * dx + dy * dy).squareRoot()
            candidates.append((square, Double(distance), node.piece.type == .king))
            found[square] = (at, distance)
        }

        let victims = Shockwave.targets(from: candidates)
        guard !victims.isEmpty else {
            DiagnosticsLog.shared.log(.raider, "nuke — nothing in reach")
            return
        }

        for square in victims {
            guard let target = found[square], let victim = pieceNodes[square] else { continue }
            // The fragment travels at the ring's own speed, so it lands on the
            // frame the ring reaches the piece. Floored, because a piece almost
            // on top of the blast would otherwise be hit before anything has
            // been drawn at all.
            let travel = max(0.09, ringDuration
                             * TimeInterval(min(1, target.distance / ringReach)))
            launchFragment(from: point, to: target.at, duration: travel, victim: victim)
        }

        // The king was passed over. Say so on his own shield rather than
        // silently, or the blast looks like it missed the most obvious target on
        // the board — which is exactly what it did, on purpose.
        if let king = candidates.first(where: { $0.isKing }),
           let furthest = victims.compactMap({ found[$0]?.distance }).max(),
           CGFloat(king.distance) <= furthest,
           let node = pieceNodes[king.square] {
            node.flareForcefield()
            AudioManager.shared.play(.shieldAbsorbsHit)
        }

        DiagnosticsLog.shared.log(.raider, "nuke takes " + victims.joined(separator: " "))
    }

    /// One piece of shrapnel, with a fading streak behind it.
    ///
    /// Carries the victim as a node, not as a square. A fragment is in the air
    /// for up to a second of real time — longer, since the blast runs in slow
    /// motion — and the fleet descends on the chess beat, so a square captured
    /// at detonation can belong to a different piece by the time the fragment
    /// lands. The same trap that made regenerated pawns unshootable.
    private func launchFragment(from origin: CGPoint, to target: CGPoint,
                                duration: TimeInterval, victim: PieceNode) {
        let path = CGMutablePath()
        path.move(to: origin)
        path.addLine(to: target)
        let streak = SKShapeNode(path: path)
        streak.strokeColor = NeonPalette.crimson
        streak.lineWidth = 1.5
        streak.glowWidth = 3
        streak.alpha = 0
        streak.zPosition = 13
        bloomNode.addChild(streak)
        streak.run(.sequence([
            .fadeAlpha(to: 0.55, duration: duration * 0.4),
            .fadeOut(withDuration: duration * 0.6 + 0.1),
            .removeFromParent(),
        ]))

        let fragment = SKShapeNode(circleOfRadius: 3.5)
        fragment.position = origin
        fragment.fillColor = .white
        fragment.strokeColor = NeonPalette.crimson
        fragment.lineWidth = 1.5
        fragment.glowWidth = 4
        fragment.zPosition = 15
        bloomNode.addChild(fragment)
        let fly = SKAction.move(to: target, duration: duration)
        fly.timingMode = .linear      // matches the ring, which expands linearly
        fragment.run(.sequence([
            fly,
            .run { [weak self, weak victim] in
                guard let victim else { return }
                self?.applyShockwave(victim)
            },
            .removeFromParent(),
        ]))
    }

    /// A fragment landed. Routed through the ordinary black-piece hit handler,
    /// so the explosion, the score, the regeneration slot and the king's own win
    /// check all behave exactly as they do for a laser.
    private func applyShockwave(_ node: PieceNode) {
        // Its square now, not the one the blast picked: a descent may have moved
        // it while the fragment was in the air. And it may be gone entirely —
        // another fragment took it, or a chess move did — in which case the
        // scene no longer has it registered and there is nothing to hit.
        let square = node.square
        guard pieceNodes[square] === node,
              let result = CollisionResolver.shockwaveHitBlackPiece(at: square, board: board)
        else { return }
        // At where it actually is, so the burst does not appear on the square it
        // has just left.
        explosions?.burst(at: bloomPosition(of: node), color: NeonPalette.crimson,
                          scale: 1.2)
        handleBlackPieceHit(result, node: node, impact: nil)
    }

    private func clearEnemyRounds(within radius: CGFloat, of centre: CGPoint) {
        guard let laserPool else { return }
        for laser in laserPool.activeLasers(owner: .enemy) {
            let dx = laser.position.x - centre.x, dy = laser.position.y - centre.y
            guard dx * dx + dy * dy <= radius * radius else { continue }
            explosions?.burst(at: laser.position, color: NeonPalette.crimson, scale: 0.35)
            laser.deactivate()
        }
    }

    /// §13.3's type label, flashed at the destroy position for 0.8 seconds.
    private func flashPowerUpLabel(_ powerUp: PowerUp, at point: CGPoint) {
        let label = SKLabelNode(fontNamed: "PressStart2P-Regular")
        label.text = powerUp.label
        label.fontSize = 14
        label.fontColor = powerUp.tint
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        // Clamped inward so a scout shot near the edge does not put half the
        // word off-screen — the label is wider than the ship that earned it.
        let margin = CGFloat(powerUp.label.count) * 7 + 12
        label.position = CGPoint(x: min(max(point.x, margin), size.width - margin),
                                 y: point.y)
        label.zPosition = 16
        bloomNode.addChild(label)
        label.setScale(0.6)
        label.run(.sequence([
            .group([.scale(to: 1.15, duration: 0.14), .moveBy(x: 0, y: 12, duration: 0.14)]),
            .scale(to: 1.0, duration: 0.1),
            .wait(forDuration: 0.4),
            .fadeOut(withDuration: 0.16),
            .removeFromParent(),
        ]))
    }

    /// A brief tint over the whole playfield, for effects that change the state
    /// of the world rather than of the ship.
    private func washScreen(_ color: SKColor) {
        let wash = SKSpriteNode(color: color, size: size)
        wash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        wash.zPosition = 15
        wash.alpha = 0
        wash.blendMode = .add
        bloomNode.addChild(wash)
        wash.run(.sequence([
            .fadeAlpha(to: 0.16, duration: 0.08),
            .fadeOut(withDuration: 0.5),
            .removeFromParent(),
        ]))
    }

    /// One more laser in the air at a time, for shooting an ordinary scout.
    ///
    /// This was §7.2's promotion reward and is now the green scout's. The
    /// promotion still promotes — a pawn reaching the eighth rank becomes a
    /// queen, which is the whole reward chess itself offers — but the arcade
    /// half of the prize moved to the target the arcade half of the game can
    /// actually shoot at.
    ///
    /// Stacks to `maxLaserCap` and resets with the level, unchanged: the scout
    /// is a repeatable source where the promotion was a one-off, so the ceiling
    /// matters more now, not less.
    private func grantRapidFire() {
        guard let shipState, shipState.grantRapidFire() else { return }
        // No flash here: `syncPowerUpAlley` puts up a standing readout and
        // flares it when the number changes, so a separate one-second banner
        // would just be the same words twice in the same gutter.
        ship?.setRapidFire(stacks: shipState.laserCap - SpaceshipState.baseLaserCap)
        DiagnosticsLog.shared.log(.raider,
            "rapid fire — \(shipState.laserCap) lasers")
    }

    /// A black piece just died: queue its replacement, if the level still has a
    /// slot for one.
    private func scheduleRegeneration(after type: PieceType) {
        guard Regeneration.schedules(destroyed: type, color: .black,
                                     level: levels.parameters,
                                     slotsUsed: regeneration.slotsUsed) else { return }
        let delay = Regeneration.delay(for: levels.parameters)
        regeneration.schedule(after: delay)
        DiagnosticsLog.shared.log(.regen,
            "Pawn in \(String(format: "%.1f", delay))s "
            + "(slot \(regeneration.slotsUsed)/\(levels.parameters.regenSlots))")
    }

    /// Materialises everything whose ten seconds are up.
    private func advanceRegeneration(_ dt: TimeInterval) {
        let due = regeneration.tick(dt)
        guard due > 0 else { return }
        for _ in 0..<due { materialisePawn() }
    }

    private func materialisePawn() {
        guard let boardNode, let fleet else { return }
        let king = board.allPieces(color: .black).first { $0.type == .king }
        // §23.9's defensive mode: a badly hurt king gets a body in front of him
        // instead of another pawn scattered along the back rank.
        let defensive = king.map { Regeneration.isDefensive(kingDamage: $0.damageState) } ?? false
        let occupied = Set(board.allPieces().map(\.logicalSquare))
        guard let square = Regeneration.spawnSquare(defensive: defensive,
                                                    kingSquare: king?.logicalSquare,
                                                    rearRank: fleet.rearRank,
                                                    occupied: occupied),
              let centre = boardNode.center(of: square) else {
            // The slot goes back: the cap counts pawns that arrive, not
            // attempts that were made.
            regeneration.refund()
            DiagnosticsLog.shared.log(.regen, "no space, slot back")
            return
        }
        let armored = Regeneration.arrivesArmored(level: levels.parameters)
        guard let pawn = board.regeneratePawn(at: square, armored: armored) else { return }
        let node = PieceNode(piece: pawn, squareSize: BoardNode.squareSize)
        node.position = centre
        // No body until it has finished arriving — §23.9's "the piece cannot be
        // shot while beaming in", and the shimmer is the only warning the
        // player gets or needs.
        node.beginMaterialising()
        fleet.adopt(node, square: square, atLogicalCentre: centre)
        pieceNodes[square] = node

        // Green-white for a standard arrival, blue-white when it is shielding
        // the king (§23.9) — the colour is the whole tell.
        let tint = defensive ? NeonPalette.starBlueLight : NeonPalette.transporterGreen
        node.beamIn(duration: Regeneration.beamInDuration, tint: tint) {
            [weak self, weak node] in
            guard let self, let node else { return }
            // Its *current* square, not the one it arrived on. The fleet
            // descends on the chess beat and a beam-in lasts 1.8 seconds, so a
            // pawn that regenerates shortly before a descent finishes arriving
            // one rank lower than it started — and this used to check
            // `pieceNodes[<the original square>] === node`, which by then held
            // nothing. The guard failed, `becomeSolid` never ran, and the pawn
            // spent the rest of the wave visible, marching, firing, and
            // completely immune to laser fire with no hit ever logged.
            let landed = node.square
            guard self.pieceNodes[landed] === node else { return }
            // The hitbox is the whole point of the materialisation: until this
            // runs the pawn is on the board, in the engine and in the fleet,
            // and completely immune to being shot.
            node.becomeSolid()
            node.refresh(with: self.board.piece(at: landed) ?? pawn)
            if armored { node.setArmored(true) }
            node.startIdleBob(phase: .random(in: 0...0.8))
            // The board just gained a piece back. That deserves the same
            // vocabulary losing one gets, or the single most demoralising event
            // in the game is also its quietest.
            self.explosions?.burst(at: self.bloomPosition(of: node),
                                   color: tint, scale: 1.6)
            self.shatters?.shatter(at: self.bloomPosition(of: node), color: .white,
                                   along: CGVector(dx: 0, dy: 1), scale: 1.4)
            self.refreshStatus()
        }
        AudioManager.shared.play(.pieceRegenerates)
        DiagnosticsLog.shared.log(.regen,
            "\(armored ? "Armored Pawn" : "Pawn") at \(square)"
            + (defensive ? " (shield)" : ""))
    }

    /// §10.1 counts armor in White's moves, so this runs once per completed
    /// beat. Any pawn whose three turns are up cracks and loses its silver.
    private func advanceArmor() {
        for square in board.tickArmor() {
            guard let node = pieceNodes[square] else { continue }
            node.crackArmorAway { [weak self] in
                guard let self else { return }
                self.shatters?.shatter(at: self.bloomPosition(of: node),
                                       color: .white,
                                       along: CGVector(dx: 0, dy: 1), scale: 1.2)
                AudioManager.shared.play(.armorBreaks)
            }
        }
    }

    // MARK: - Juice (§24)

    /// Starts a shake, or replaces a weaker one already running. Never adds:
    /// a queen dying inside a king's shake must not double the amplitude, and
    /// the bigger event is the one the player should feel.
    private func startShake(_ next: Juice.Shake) {
        guard !next.isSilent else { return }
        let remaining = Juice.amplitude(shake, elapsed: shakeElapsed)
        guard next.amplitude >= remaining else { return }
        shake = next
        shakeElapsed = 0
        shakeAngle = .random(in: 0..<(2 * .pi))
    }

    private func advanceShake(_ dt: TimeInterval) {
        guard !shake.isSilent else { return }
        shakeElapsed += dt
        let amplitude = Juice.amplitude(shake, elapsed: shakeElapsed)
        guard amplitude > 0.05 else {
            shake = .none
            bloomNode.position = .zero      // always land back on true centre
            return
        }
        let (offset, angle) = Juice.offset(amplitude: amplitude, lastAngle: shakeAngle)
        shakeAngle = angle
        bloomNode.position = offset
    }

    /// §24.2: hold everything for a few frames, then run `then` — the explosion
    /// lands *after* the pause, which is what makes a big kill feel weighty
    /// rather than just slow.
    private func freeze(_ duration: TimeInterval, then: @escaping () -> Void) {
        guard duration > 0 else { return then() }
        freezeRemaining = duration
        afterFreeze = then
        bloomNode.isPaused = true
        // The starfield is a sibling of the playfield, not a child of it, so
        // pausing the playfield alone left the stars scrolling through the
        // freeze — which is most of what gives a hitstop away. Nothing may move.
        starfieldNode.isPaused = true
    }

    /// Where a round landed and which way it was going — enough to throw the
    /// glass the right way. Carried into the hit handlers rather than stashed,
    /// so a hit that arrives from somewhere without one (a chess capture) says
    /// so in its type instead of silently reusing the last shot's heading.
    struct Impact {
        let point: CGPoint
        /// Captured at the contact, not read back from the round: `deactivate`
        /// clears its rotation, and every one of these call sites deactivates
        /// before the handler runs. Read late, a player laser's glass sprayed
        /// downward.
        let heading: CGVector
    }

    /// §8.4's "when the spaceship is hit it explodes", and §24.1's medium
    /// 0.4s shake for it — both specified from the start, neither ever built:
    /// losing a life used to be a sound, a hidden sprite and a HUD icon going
    /// out. It is the single worst thing that can happen to the player and it
    /// was the quietest event on screen.
    ///
    /// Glass in two opposed sprays rather than one, because the ship is not
    /// being shot *through* — it is coming apart, and a directional spray would
    /// claim a direction the event does not have.
    private func blowUpSpaceship(final: Bool) {
        guard let ship else { return }
        let at = bloomPosition(of: ship)
        explosions?.burst(at: at, color: NeonPalette.cyan, scale: final ? 2.6 : 1.8)
        shatters?.shatter(at: at, color: NeonPalette.cyan,
                          along: CGVector(dx: 0, dy: 1), scale: 1.8)
        shatters?.shatter(at: at, color: .white,
                          along: CGVector(dx: 0, dy: -1), scale: 1.4)
        // The run ending earns more than another life lost: the heavy shake and
        // the white flash are otherwise reserved for a king dying.
        startShake(final ? Juice.heavy : Juice.shipDestroyed)
        if final { flashScreen() }
    }

    /// Black shot your shot out of the air.
    ///
    /// Both rounds die, and the collision gets the biggest glass in the game:
    /// two sprays in the two sides' own colours, thrown along the two headings,
    /// around a white core. Cyan going one way and magenta the other is what
    /// makes it read as a *collision* rather than as one more explosion — the
    /// event has two authors and the picture should say so.
    private func resolveProjectileClash(player: LaserNode, enemy: LaserNode,
                                        at point: CGPoint) {
        let playerHeading = player.travelDirection
        let enemyHeading = enemy.travelDirection
        player.deactivate()
        enemy.deactivate()

        let at = bloomNode.convert(point, from: self)
        explosions?.burst(at: at, color: .white, scale: 0.9)
        shatters?.shatter(at: at, color: NeonPalette.cyan,
                          along: playerHeading, scale: 1.6)
        shatters?.shatter(at: at, color: NeonPalette.magentaLight,
                          along: enemyHeading, scale: 1.6)
        AudioManager.shared.play(.pieceHitHeavy)
        DiagnosticsLog.shared.log(.shoot, "rounds collide")
    }

    /// Glass off a piece that took a hit and lived, thrown along the round's
    /// own heading. A destroyed piece gets the burst instead — two effects on
    /// the same frame would only muddy each other.
    private func shatterGlass(_ impact: Impact?, color: SKColor) {
        guard let impact else { return }
        shatters?.shatter(at: bloomNode.convert(impact.point, from: self),
                          color: color, along: impact.heading)
    }

    /// A destroyed piece's position in `bloomNode`'s space — pieces live under
    /// the board or the fleet, both of which are inset within it.
    private func bloomPosition(of node: SKNode) -> CGPoint {
        bloomNode.convert(.zero, from: node)
    }

    /// The full ceremony for a destroyed piece: freeze if it was worth one,
    /// then burst, pop the score, and shake.
    private func celebrateDestruction(of node: PieceNode, type: PieceType,
                                      points: Int, color: SKColor) {
        let at = bloomPosition(of: node)
        // King and queen get the pause; everything else fires immediately, or
        // a wave of pawn kills would read as the game stuttering.
        freeze(Juice.freezeDuration(forDestroying: type)) { [weak self] in
            guard let self else { return }
            // §24.8: the king's death is the level's climax — a bigger burst
            // and a white flash over the whole playfield.
            let scale: CGFloat = type == .king ? 2.4 : (type == .queen ? 1.5 : 1.0)
            self.explosions?.burst(at: at, color: color, scale: scale)
            if type == .king { self.flashScreen() }
            self.scorePops?.pop(points, at: at, color: color)
            self.startShake(Juice.shake(forDestroying: type))
        }
    }

    /// §24.8's full-screen white flash, for the king only. Brief and dim: a
    /// true white frame over a dark board is genuinely unpleasant.
    private func flashScreen() {
        let flash = SKSpriteNode(color: .white, size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 23
        flash.alpha = 0
        bloomNode.addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.05),
            .fadeOut(withDuration: 0.35),
            .removeFromParent(),
        ]))
    }

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
    private func resolvePlayerLaserHit(laser: LaserNode, node: SKNode, at point: CGPoint) {
        let impact = Impact(point: point, heading: laser.travelDirection)
        laser.deactivate()
        if let raider = node as? RaiderNode {
            // One HP (§6), so this always destroys it — but ask rather than
            // assume, since the flagship arriving in 6.2 will not.
            if !raider.takeHit() {
                // Its own colour, not the plain scout's green. Unreachable while
                // every carrier has 1 HP, and wrong the moment one does not.
                shatterGlass(impact, color: raider.powerUp.tint)
                AudioManager.shared.play(.pieceHitLight)
            }
            return
        }
        guard let pieceNode = node as? PieceNode else { return }
        // Before any damage is applied: the side the shot took off is the side
        // that stops being drawn, so the wedge has to know where it landed.
        pieceNode.noteHit(atLocalX: pieceNode.convert(point, from: self).x)

        if pieceNode.piece.color == .black {
            guard let result = CollisionResolver.playerLaserHitBlackPiece(
                at: pieceNode.square, board: board) else { return }
            handleBlackPieceHit(result, node: pieceNode, impact: impact)
        } else if pieceNode.piece.type == .king {
            // The player's own king is armoured against the player's own fire.
            // Shooting it is almost always a mistake — the ship sits directly
            // below the back rank — and ending the run on a stray shot punishes
            // exactly the player who does not yet know the board. Invader fire
            // still kills it (that path is `resolveEnemyShotHit`), so the lose
            // condition is intact.
            pieceNode.flashDeflection()
            AudioManager.shared.play(.shieldAbsorbsHit)
            DiagnosticsLog.shared.log(.hit, "white king deflects")
        } else {
            guard let result = CollisionResolver.playerLaserHitWhitePiece(
                at: pieceNode.square, board: board) else { return }
            handleWhitePieceHit(result, node: pieceNode, impact: impact)
        }
    }

    /// An invader shot touched something — either the ship, or a white piece
    /// blocking its lane.
    private func resolveEnemyShotHit(shot: LaserNode, node: SKNode, at point: CGPoint) {
        // The round's own damage, not a constant. The activated king's heavy
        // shot carries 2 and was landing 1: the resolver hardcoded
        // `enemyShotDamage`, so "double damage" never reached the board.
        let damage = shot.state?.damage ?? ProjectileState.enemyShotDamage
        let impact = Impact(point: point, heading: shot.travelDirection)

        if let ship, node === ship {
            shot.deactivate()
            handleShipHit()
        } else if let pieceNode = node as? PieceNode, pieceNode.piece.color == .white {
            pieceNode.noteHit(atLocalX: pieceNode.convert(point, from: self).x)
            guard let result = CollisionResolver.enemyShotHitWhitePiece(
                at: pieceNode.square, damage: damage, board: board) else {
                // The node's square no longer names a piece on the board — it
                // is mid-move, or already dead. Deactivating here would delete
                // the round in mid-air with no damage and no explosion, which
                // is exactly what "it hit but nothing happened" looks like. Let
                // it keep flying instead.
                DiagnosticsLog.shared.log(.hit,
                    "shot passed \(pieceNode.square) — no piece there on the board")
                return
            }
            shot.deactivate()
            handleWhitePieceHit(result, node: pieceNode, impact: impact)
        }
    }

    /// Shows the shield ring only while the black king still has bonus HP, so
    /// the ring going out is the moment the king becomes killable.
    /// The shield is raised only once play has actually begun.
    ///
    /// It used to appear during the KING ACTIVATED banner, which reads oddly:
    /// the announcement is still explaining that the king is about to be
    /// shielded while the shield is already sitting there. `isBeatSuspended`
    /// covers the banner, so gating on it also keeps the ring off during the
    /// end-of-game reveal, where a shield on a king that has just fallen would
    /// be worse still.
    private func refreshKingForcefield() {
        guard !isBeatSuspended else { return }
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

    private func handleBlackPieceHit(_ result: CollisionOutcome, node: PieceNode,
                                     impact: Impact?) {
        // §10.1: the round hit armor and stopped. Loud and yellow on purpose —
        // the player aimed correctly and needs to know that is not the problem.
        if case .ricochet(let square) = result {
            node.flashArmorHit()
            if let impact {
                shatters?.shatter(at: bloomNode.convert(impact.point, from: self),
                                  color: NeonPalette.orange,
                                  along: CGVector(dx: -impact.heading.dx,
                                                  dy: -impact.heading.dy),
                                  scale: 1.2)
            }
            AudioManager.shared.play(.armorRicochet)
            DiagnosticsLog.shared.log(.hit, "armor deflects \(square)")
            return
        }
        guard case .blackPieceHit(let square, let type, let destroyed, let points, let comboBonus) = result
        else { return }

        if !destroyed {
            showDamage(on: node, at: square)
            node.applyHitFlash()
            shatterGlass(impact, color: NeonPalette.magenta)
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
        scheduleRegeneration(after: type)
        celebrateDestruction(of: node, type: type,
                             points: ScoreManager.shared.scaled(points),
                             color: NeonPalette.magenta)
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

    private func handleWhitePieceHit(_ result: CollisionOutcome, node: PieceNode,
                                     impact: Impact?) {
        guard case .whitePieceHit(let square, let destroyed) = result else { return }

        if !destroyed {
            showDamage(on: node, at: square)
            node.applyHitFlash()
            shatterGlass(impact, color: NeonPalette.cyan)
            AudioManager.shared.play(.pieceHitLight)
            return
        }

        pieceNodes.removeValue(forKey: square)
        let at = bloomPosition(of: node)
        explosions?.burst(at: at, color: NeonPalette.cyan,
                          scale: node.piece.type == .king ? 2.4 : 1.0)
        if node.piece.type == .king { flashScreen() }
        startShake(Juice.shake(forDestroying: node.piece.type))
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
        guard let shipState else { return }
        // §13.2's Shield Bubble absorbs "the next single hit that would destroy
        // the ship". Checked after invincibility, not before: a hit during the
        // respawn grace window costs nothing anyway, and spending the shield on
        // it would take the reward away for free.
        if !shipState.isInvincible, powerUps.absorbHit() {
            shipState.beginGrace()
            ship?.removeShield(absorbed: true)
            AudioManager.shared.play(.shieldAbsorbsHit)
            AudioManager.shared.play(.shieldShatters)
            DiagnosticsLog.shared.log(.raider, "shield absorbed the hit")
            return
        }
        guard shipState.loseLife() else { return }
        refreshHUD()
        ship?.direction = 0
        isFireHeld = false

        let lastLife = shipState.lives == 0
        blowUpSpaceship(final: lastLife)

        guard !lastLife else {
            AudioManager.shared.play(.playerShipDestroyed)
            loseGame(outcome: .livesDepleted)
            return
        }

        AudioManager.shared.play(.invaderHitsShip)
        ship?.isHidden = true
        // A countdown the update loop owns, not a scene `SKAction`.
        //
        // The action fired after one second and then *bailed* if the game was
        // not PLAYING at that exact instant — and scene actions keep running
        // while paused, so pausing inside that second (having just died, which
        // is when a player is most likely to) threw the respawn away with
        // nothing to retry it. The ship stayed hidden for the rest of the run
        // while the state said it was alive: invisible, and still able to move
        // and fire. This timer only advances while playing, so it cannot be
        // spent on a frame that refuses to act on it.
        respawnRemaining = Self.respawnDelay
    }

    /// Respawns at center-bottom (§8.4) with the invincibility flash.
    private func respawnShip() {
        respawnRemaining = 0
        guard let ship else { return }
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

        let realDt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        // §13.2's Nuke runs in slow motion. The countdown burns *real* time —
        // scaled time would slow its own ending and it would never finish — and
        // everything after this line runs on the scaled clock.
        if slowMoRemaining > 0 { slowMoRemaining = max(0, slowMoRemaining - realDt) }
        applyTimeScale()
        let dt = realDt * timeScale

        // §24.2's hit freeze: the playfield stops, this loop does not — it is
        // what has to notice the freeze is over. Everything below is skipped,
        // so the ship, the beat and the reveal all hold with it.
        if freezeRemaining > 0 {
            freezeRemaining -= dt
            if freezeRemaining <= 0 {
                bloomNode.isPaused = false
                starfieldNode.isPaused = false
                let resume = afterFreeze
                afterFreeze = nil
                resume?()
            }
            return
        }
        advanceShake(dt)
        if !isBeatSuspended, !isTimeFrozen, stateMachine.currentState is PlayingState {
            advanceRegeneration(dt)
        }
        if stateMachine.currentState is PlayingState {
            syncRespawnWarnings()
            syncPowerUpAlley()
            // §13's effect clock. Ticked before the systems it gates, so the
            // frame a freeze ends on is already a running frame.
            if let expired = powerUps.tick(dt) {
                lift(expired)
                DiagnosticsLog.shared.log(.raider, "\(expired.label.lowercased()) ends")
            }
            advanceGatling(dt)
        }
        // Raiders run on their own clock, not the chess beat — that is the
        // whole point of them (§6) — but they still hold during a banner or
        // once the game is decided.
        if !isBeatSuspended, !isTimeFrozen, stateMachine.currentState is PlayingState {
            raiders?.update(deltaTime: dt, interval: levels.parameters.raiderInterval,
                            level: levels.level, rearRankPieces: rearRankPieces)
        }

        if dt > 0, stateMachine.currentState is PlayingState {
            // Held still while a banner is up or the game is decided; §12.11
            // has gameplay beginning once the announcement leaves.
            if !isBeatSuspended, !isShipDown {
                let lane = Self.shipMargin...(size.width - Self.shipMargin)
                ship?.update(deltaTime: dt, bounds: lane)
            }
            shipState?.update(deltaTime: dt)
            if isShipDown {
                respawnRemaining -= dt
                if respawnRemaining <= 0 { respawnShip() }
            }

            // The end-of-game hold owns the beat while it runs.
            if advanceReveal(dt) {
                turnTimerNode?.isHidden = true
                // Real time, not scaled: the FPS readout measures the frame,
                // not the game clock.
                publishStats(dt: realDt, now: currentTime)
                return
            }

            // Invariant, enforced here rather than at every call site: if it is
            // White's move and no beat is running, start one. `resolveBeat` has
            // several early returns — pausing while Black was thinking used to
            // leave the game with no live beat and no way to move again.
            if !isBeatSuspended, !isTimeFrozen, !isResolvingBeat,
               board.turn == .white, !turnTimer.isRunning {
                beginBeat()
            }

            // The chess beat. Arcade action keeps running while it ticks —
            // the game never pauses for chess (§3). But once the game is
            // decided the beat stops entirely: a timer left running would
            // expire and resolve another beat over a finished board.
            // §13.2's Time Freeze "pauses the chess turn timer" as well as the
            // fleet — the whole point is three seconds where only the player
            // acts, and a clock still running would spend them auto-moving.
            if !isBeatSuspended, !isTimeFrozen, turnTimer.update(deltaTime: dt) {
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

        publishStats(dt: realDt, now: currentTime)
    }

    /// Four times a second is plenty for a readout, and it keeps both the node
    /// walk and the SwiftUI invalidation out of the per-frame path.
    /// Frames seen since the last publish, and the real time they took.
    private var framesThisInterval = 0
    private var timeThisInterval: TimeInterval = 0

    /// Not debug-only. The diagnostics panel ships closed but available, so the
    /// figures behind it have to be real — and `auditHitboxes` repairs a class of
    /// bug that is otherwise silent. Four times a second either way.
    private func publishStats(dt: TimeInterval, now: TimeInterval) {
        guard dt > 0 else { return }
        framesThisInterval += 1
        timeThisInterval += dt
        guard now - lastStatsUpdate >= Self.statsInterval else { return }
        lastStatsUpdate = now
        auditHitboxes()
        // Averaged over the interval, not sampled from one frame.
        //
        // A single sample every 250ms is a wildly noisy estimator: it reads 75
        // off a short frame and 17 off one long one, while the other fourteen
        // frames in that quarter-second were fine — which is exactly how a
        // readout can swing from 75 to 17 on a game that plays smoothly. An
        // average over every frame in the window says what the player felt.
        DiagnosticsLog.shared.fps =
            (Double(framesThisInterval) / max(timeThisInterval, 0.0001)).rounded()
        framesThisInterval = 0
        timeThisInterval = 0
        DiagnosticsLog.shared.nodeCount = countAllNodes()
    }

    /// Catches a piece that is on the board with no hitbox and no beam-in
    /// running.
    ///
    /// That state is invisible by construction: no contact fires, so no hit is
    /// logged, no sound plays and nothing on screen looks wrong — the player
    /// simply shoots a piece over and over and nothing happens. It took a
    /// player noticing "that pawn never takes damage" to find it once, which is
    /// exactly the kind of bug worth spending four checks a second on.
    ///
    /// Repairs as well as reports: a wave that has already gone wrong is better
    /// off playable, and the log line is what says it happened.
    private func auditHitboxes() {
        for (square, node) in pieceNodes
        where node.physicsBody == nil && !node.isMaterialising {
            node.becomeSolid()
            DiagnosticsLog.shared.log(.error,
                "\(node.piece.color) \(node.piece.type) \(square) had no hitbox")
        }
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
        // It also puts the high score table back to ZACK/BEN/STEVE/WOZ/NOLAN,
        // which is the whole point of a clean slate: the title screen it drops
        // you on is where the table is displayed, so the reset is visible the
        // moment it happens.
        //
        // Here rather than in `resetToTitle`, which is also the ordinary way
        // back from game over — that path must leave the table alone.
        if howToPlayNode != nil
            || stateMachine.currentState is PausedState
            || stateMachine.currentState is PlayingState,
           event.charactersIgnoringModifiers?.lowercased() == "x" {
            ScoreManager.shared.clearHighScores()
            resetToTitle()
            return
        }

        // Any key returns to the game, the same as How To Play — the footer of
        // both panels says so, and two full-screen panels that dismiss
        // differently would be a worse trap than an accidental keystroke.
        if settingsNode != nil {
            hideSettings()
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

        // S opens Settings from anywhere. Its own key rather than a menu, in
        // the same spirit as `I` — and §12.9 is explicit that pause must never
        // become a settings menu.
        if event.charactersIgnoringModifiers?.lowercased() == "s" {
            showSettings()
            return
        }

        // M silences the music and brings it back, from anywhere. Ahead of the
        // "any key continues" branches below on purpose — reaching for the
        // volume should never also advance the game. Below name entry, though,
        // so a player with an M in their name can still type it.
        if event.charactersIgnoringModifiers?.lowercased() == "m" {
            AudioManager.shared.toggleMusic()
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

        // Hidden: P grants the next power-up outright, for testing.
        //
        // This claims `P` from §5's pause binding, which is now Escape alone —
        // note the handler order, since this runs *ahead* of `InputHandler` and
        // would shadow the pause key silently if that binding were still there.
        if stateMachine.currentState is PlayingState,
           event.charactersIgnoringModifiers?.lowercased() == "p" {
            grantNextPowerUp()
            return
        }

        // Hidden: R sends the level's next raider in now, for testing.
        if stateMachine.currentState is PlayingState,
           event.charactersIgnoringModifiers?.lowercased() == "r" {
            summonRaider()
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

    override func mouseDragged(with event: NSEvent) {
        settingsNode?.handleDrag(at: event.location(in: self))
    }

    override func mouseUp(with event: NSEvent) {
        settingsNode?.endDrag()
    }

    override func keyUp(with event: NSEvent) {
        InputHandler.shared.handleKeyUp(event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)

        // Settings intercepts all clicks: BACK first, then its own controls.
        if let panel = settingsNode {
            let hit = atPoint(location)
            if hit.name == "backButton" || hit.parent?.name == "backButton" {
                AudioManager.shared.play(.uiSettingsBlip)
                pressButton(hit) { [weak self] in self?.hideSettings() }
            } else {
                panel.handleClick(at: location)
            }
            return
        }

        // How To Play overlay intercepts all clicks; BACK closes it.
        if howToPlayNode != nil {
            let hit = atPoint(location)
            if hit.name == "backButton" || hit.parent?.name == "backButton" {
                AudioManager.shared.play(.uiButtonClick)
                pressButton(hit) { [weak self] in self?.hideHowToPlay() }
            } else if hit.name == HowToPlayNode.musicLinkName,
                      let url = URL(string: "https://www.mzurlocker.com/zudio") {
                AudioManager.shared.play(.uiButtonClick)
                NSWorkspace.shared.open(url)
            }
            return
        }

        // INFO button opens How To Play from any game state.
        let hit = atPoint(location)
        if hit.name == "infoButton" || hit.parent?.name == "infoButton" {
            pressButton(hit) { [weak self] in self?.showHowToPlay() }
            return
        }
        if hit.name == "settingsButton" || hit.parent?.name == "settingsButton" {
            pressButton(hit) { [weak self] in self?.showSettings() }
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
