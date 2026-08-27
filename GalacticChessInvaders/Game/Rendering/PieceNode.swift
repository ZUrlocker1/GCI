// PieceNode.swift
// One chess piece on the board. Scales its sprite to the square, tints by side
// (white = cyan, black = magenta), and swaps textures as HP erodes.
// At Critical the d2 art gains a programmatic alpha flicker.

import SpriteKit

final class PieceNode: SKSpriteNode {

    private static let cyan    = NeonPalette.cyan
    private static let magenta = NeonPalette.magenta
    /// Check warning. Black pieces are already magenta, so hue alone would not
    /// read on a black king — the halo and the pulse carry the signal.
    private static let danger  = SKColor(red: 1.00, green: 0.16, blue: 0.10, alpha: 1)
    private static let flickerKey = "criticalFlicker"
    private static let checkGlowKey = "checkGlow"
    private static let armorKey = "armor"
    private static let armorFillName = "armorFill"
    private static let chargeGlowName = "gunnerCharge"
    private static let ventName = "vent"
    private static let beamName = "beamIn"
    private static let bobKey = "idleBob"
    /// Small enough to read as breathing rather than hovering.
    private static let bobAmplitude: CGFloat = 2.0
    private static let bobHalfPeriod: TimeInterval = 0.8
    private static let baseBlend: CGFloat = 0.22

    /// The wedge is part of the piece, so it takes every tint the piece takes —
    /// the check glow, the hit flash, the base colour. Overriding here rather
    /// than touching all six call sites means a new one cannot forget.
    override var color: SKColor {
        didSet { wedgeNode?.color = color }
    }
    override var colorBlendFactor: CGFloat {
        didSet { wedgeNode?.colorBlendFactor = colorBlendFactor }
    }

    private(set) var piece: Piece
    private let squareSize: CGFloat
    private let baseColor: SKColor
    private var halo: SKShapeNode?

    /// True while this piece is drawn as the king in check.
    private(set) var isShowingCheck = false

    /// The square this node currently represents. Kept in sync by the scene.
    var square: String { piece.logicalSquare }

    init(piece: Piece, squareSize: CGFloat) {
        self.piece = piece
        self.squareSize = squareSize
        self.baseColor = piece.color == .white ? Self.cyan : Self.magenta
        let texture = SKTexture(imageNamed: piece.textureName)
        super.init(texture: texture, color: .clear, size: Self.fit(texture, in: squareSize))
        colorBlendFactor = Self.baseBlend
        color = baseColor
        zPosition = 5

        rebuildPhysicsBody()
    }

    // MARK: - Collision shape

    /// Ink bounds per texture, in unit coordinates of the texture box measured
    /// from the bottom-left. Computed once per sprite and cached: 36 sprites,
    /// each scanned a single time, and never during a frame that matters.
    private static var inkBoundsCache: [String: CGRect] = [:]
    private static var wedgeCache: [String: SKTexture] = [:]

    /// Which side of a damaged piece survives, and how much of it.
    ///
    /// The damage art erodes bottom-up, which takes the profile with it — and
    /// the profile is where a piece's identity lives. A Cracked pawn, bishop,
    /// queen and knight are all "a small blob with debris"; only the rook and
    /// king survive, because crenellations and a cross happen to be top-of-
    /// piece features. Keeping a full-height slice of one side gives the
    /// silhouette back without pretending the piece is whole: two thirds of it
    /// is still visibly gone.
    enum SurvivingSide { case left, right }
    static let wedgeShare: CGFloat = 0.34

    /// Fixed for the life of the piece once its first hit lands — the wedge
    /// must not jump sides when a piece moves or takes another hit.
    private(set) var survivingSide: SurvivingSide?
    private var wedgeNode: SKSpriteNode?

    /// A hit landing this close to the middle cannot say which side it took
    /// off, as a fraction of the half-width.
    private static let centreHitFraction: CGFloat = 0.2

    /// Fits the collision box to the sprite's visible ink rather than its whole
    /// frame.
    ///
    /// The art erodes from the bottom up — measured across all six pieces, ink
    /// fills ~84% of the box when intact, ~49% at Chipped and ~27% at Cracked —
    /// so a full-frame rectangle left a tall band of empty space below a damaged
    /// piece that still absorbed shots. A laser aimed at a half-destroyed king
    /// died in blank space under it.
    ///
    /// A rectangle over the ink bounds, not a texture-derived (alpha) body:
    /// these are neon outlines covering only ~10% of their box even intact, so
    /// an alpha body would be hollow and shots would sail through the middle of
    /// a healthy piece.
    /// The horizontal slice of the *undamaged* texture that survives, in
    /// normalized texture coordinates. Nil while the piece is whole.
    private var wedgeSpan: (x0: CGFloat, x1: CGFloat)? {
        guard piece.damageState != .full, let side = survivingSide else { return nil }
        let ink = Self.inkBounds(forTexture: piece.fullTextureName)
        let width = ink.width * Self.wedgeShare
        switch side {
        case .left:  return (ink.minX, ink.minX + width)
        case .right: return (ink.maxX - width, ink.maxX)
        }
    }

    /// Shows, moves or removes the surviving slice of the whole piece.
    ///
    /// A sub-texture of the full-HP art rather than new artwork: every damage
    /// state shares the full sprite's canvas, so a slice cut from it lands
    /// exactly where that part of the piece would have been.
    private func updateWedge() {
        guard let span = wedgeSpan else {
            wedgeNode?.removeFromParent()
            wedgeNode = nil
            return
        }
        let key = "\(piece.fullTextureName)|\(span.x0)"
        let slice = Self.wedgeCache[key] ?? {
            let cut = SKTexture(rect: CGRect(x: span.x0, y: 0,
                                             width: span.x1 - span.x0, height: 1),
                                in: SKTexture(imageNamed: piece.fullTextureName))
            Self.wedgeCache[key] = cut
            return cut
        }()

        let node = wedgeNode ?? {
            let fresh = SKSpriteNode()
            fresh.zPosition = -0.5      // under the damaged art, over the board
            addChild(fresh)
            wedgeNode = fresh
            return fresh
        }()
        node.texture = slice
        node.size = CGSize(width: (span.x1 - span.x0) * size.width, height: size.height)
        node.position = CGPoint(x: ((span.x0 + span.x1) / 2 - 0.5) * size.width, y: 0)
        node.color = color
        node.colorBlendFactor = colorBlendFactor
    }

    private func rebuildPhysicsBody() {
        let unit = Self.inkBounds(forTexture: piece.textureName)
        let boxWidth = size.width, boxHeight = size.height

        // `unit` is measured from the image's TOP-left, while the node's +y is
        // up, so the vertical axis inverts and the horizontal one does not.
        // Getting this backwards puts the hitbox at the wrong end of the piece
        // and makes the very problem it fixes worse, so it is worth being
        // explicit: a Cracked piece's ink is near the top of its box, and the
        // body must end up near the top too.
        let bodySize = CGSize(width: unit.width * boxWidth,
                              height: unit.height * boxHeight)
        let centre = CGPoint(x: (unit.midX - 0.5) * boxWidth,
                             y: (0.5 - unit.midY) * boxHeight)

        // Contact detection only — no physical push. The laser side owns
        // contactTestBitMask, so this only needs the right categoryBitMask.
        //
        // Compound when a wedge is showing, rather than one box around both:
        // what the player can see, the player can hit, but a single rectangle
        // spanning the eroded top *and* a full-height slice would also cover
        // the empty two thirds between them — which is the bug the ink-bounds
        // measurement fixed in the first place.
        let top = SKPhysicsBody(rectangleOf: bodySize, center: centre)
        let body: SKPhysicsBody
        if let span = wedgeSpan {
            let full = Self.inkBounds(forTexture: piece.fullTextureName)
            let wedge = SKPhysicsBody(
                rectangleOf: CGSize(width: (span.x1 - span.x0) * boxWidth,
                                    height: full.height * boxHeight),
                center: CGPoint(x: ((span.x0 + span.x1) / 2 - 0.5) * boxWidth,
                                y: (0.5 - full.midY) * boxHeight))
            body = SKPhysicsBody(bodies: [top, wedge])
        } else {
            body = top
        }
        body.isDynamic = false
        body.categoryBitMask = piece.color == .white
            ? PhysicsCategory.friendlyPiece : PhysicsCategory.enemyPiece
        body.contactTestBitMask = PhysicsCategory.none
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    private static func inkBounds(forTexture name: String) -> CGRect {
        if let cached = inkBoundsCache[name] { return cached }
        let bounds = measureInkBounds(forTexture: name)
            ?? CGRect(x: 0, y: 0, width: 1, height: 1)   // fall back to the full frame
        inkBoundsCache[name] = bounds
        return bounds
    }

    /// Scans the texture's alpha for its bounding box, returned in unit
    /// coordinates measured from the image's **top**-left (the natural bitmap
    /// order — the caller flips y). Nil if the image can't be read, in
    /// which case the caller keeps the full frame — a slightly generous hitbox
    /// is much better than none.
    private static func measureInkBounds(forTexture name: String) -> CGRect? {
        guard let image = SKTexture(imageNamed: name).cgImage() as CGImage?,
              image.width > 0, image.height > 0 else { return nil }
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Row 0 of the buffer is the image's top row. Verified against an
        // independent raw-PNG scan: both report the Cracked king's ink at
        // 7.3%-58% of the box, so this is top-down, not bottom-up.
        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h {
            let row = y * w * 4
            for x in 0..<w where pixels[row + x * 4 + 3] > 20 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }   // fully transparent
        return CGRect(x: CGFloat(minX) / CGFloat(w),
                      y: CGFloat(minY) / CGFloat(h),
                      width: CGFloat(maxX - minX + 1) / CGFloat(w),
                      height: CGFloat(maxY - minY + 1) / CGFloat(h))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Sprites are tall (e.g. 192×288 @2x), so fit by height and leave a small margin.
    private static func fit(_ texture: SKTexture, in squareSize: CGFloat) -> CGSize {
        let source = texture.size()
        guard source.height > 0 else { return CGSize(width: squareSize, height: squareSize) }
        let target = squareSize * 0.82
        return CGSize(width: source.width * (target / source.height), height: target)
    }

    // MARK: - Check warning

    /// Marks this piece as the king in check: a pulsing red halo behind it and a
    /// red wash over the sprite (§25.4). Idempotent, so the scene can call it
    /// freely; the glow travels with the node when the king moves.
    func setCheckGlow(_ active: Bool) {
        guard active != isShowingCheck else { return }
        isShowingCheck = active
        active ? startCheckGlow() : stopCheckGlow()
    }

    private func startCheckGlow() {
        let ring = halo ?? {
            // Behind the sprite, so the piece silhouette stays readable.
            let node = SKShapeNode(circleOfRadius: squareSize * 0.40)
            node.strokeColor = Self.danger
            node.lineWidth = 2.5
            node.glowWidth = 6
            node.fillColor = Self.danger.withAlphaComponent(0.12)
            node.zPosition = -1
            addChild(node)
            halo = node
            return node
        }()

        ring.alpha = 0.9
        ring.setScale(0.92)
        ring.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.35, duration: 0.45), .scale(to: 1.14, duration: 0.45)]),
            .group([.fadeAlpha(to: 0.90, duration: 0.45), .scale(to: 0.92, duration: 0.45)]),
        ])), withKey: Self.checkGlowKey)

        run(.repeatForever(.sequence([
            .colorize(with: Self.danger, colorBlendFactor: 0.95, duration: 0.45),
            .colorize(with: Self.danger, colorBlendFactor: 0.45, duration: 0.45),
        ])), withKey: Self.checkGlowKey)
    }

    private func stopCheckGlow() {
        removeAction(forKey: Self.checkGlowKey)
        halo?.removeAction(forKey: Self.checkGlowKey)
        halo?.removeFromParent()
        halo = nil
        color = baseColor
        colorBlendFactor = Self.baseBlend
    }

    // MARK: - Damage

    /// Records where a shot struck, in this node's own coordinates, so the
    /// surviving side can be the one the shot did *not* take off. Only the
    /// first hit decides; a clean centre hit tosses a coin.
    func noteHit(atLocalX x: CGFloat) {
        guard survivingSide == nil else { return }
        let half = size.width / 2
        let offset = half > 0 ? x / half : 0
        if offset < -Self.centreHitFraction {
            survivingSide = .right          // struck on the left, so the right stands
        } else if offset > Self.centreHitFraction {
            survivingSide = .left
        } else {
            survivingSide = Bool.random() ? .left : .right
        }
    }

    /// Re-reads `piece` and refreshes the texture and flicker to match it.
    /// Keys off `textureName`, so promotions (type change) and damage both apply.
    func refresh(with updated: Piece) {
        let previousTexture = piece.textureName
        piece = updated
        // Venting keys off raw HP, not the texture, so it starts on the hit
        // that crosses half rather than on the next art change.
        updateVenting()
        guard updated.textureName != previousTexture else { return }

        let next = SKTexture(imageNamed: updated.textureName)
        texture = next
        size = Self.fit(next, in: squareSize)
        updateWedge()
        // The eroded art is a different shape, so the hitbox has to follow it.
        rebuildPhysicsBody()

        if updated.damageState == .critical {
            guard action(forKey: Self.flickerKey) == nil else { return }
            run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.35, duration: 0.18),
                SKAction.fadeAlpha(to: 1.0,  duration: 0.18)
            ])), withKey: Self.flickerKey)
        } else {
            removeAction(forKey: Self.flickerKey)
            alpha = 1.0
        }
    }

    /// A steady shield bubble, for the activated black king's forcefield
    /// (§10.1). Idempotent, and removed once the shield is spent — so the ring
    /// vanishing is the cue that the king is now takeable.
    func setForcefield(_ active: Bool) {
        let key = "forcefield"
        if !active {
            childNode(withName: key)?.removeFromParent()
            return
        }
        guard childNode(withName: key) == nil else { return }
        // Tight to the king rather than filling the square. At 0.42 it was
        // wider than the check halo (0.40) and read as a drawn circle sitting
        // on the board; close in, thin and dim, it reads as a field the piece
        // is wearing. `flareForcefield` is what makes it visible, on each hit
        // it absorbs — at rest it should be easy to overlook.
        let ring = SKShapeNode(circleOfRadius: squareSize * 0.33)
        ring.name = key
        ring.strokeColor = NeonPalette.cyan
        ring.lineWidth = 0.8
        ring.glowWidth = 2.5
        ring.fillColor = NeonPalette.cyan.withAlphaComponent(0.03)
        ring.zPosition = -1
        addChild(ring)
        ring.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.30, duration: 0.9), .scale(to: 1.03, duration: 0.9)]),
            .group([.fadeAlpha(to: 0.65, duration: 0.9), .scale(to: 1.00, duration: 0.9)]),
        ])))
    }

    /// Brightens the shield for a moment — called when it absorbs a hit, so
    /// the field visibly takes the impact instead of the sprite.
    func flareForcefield() {
        guard let ring = childNode(withName: "forcefield") as? SKShapeNode else { return }
        ring.removeAction(forKey: "flare")
        ring.run(.sequence([
            .run { ring.lineWidth = 2.5; ring.glowWidth = 10; ring.strokeColor = .white },
            .wait(forDuration: 0.09),
            .run { ring.lineWidth = 0.8; ring.glowWidth = 2.5; ring.strokeColor = NeonPalette.cyan },
        ]), withKey: "flare")
    }

    // MARK: - Armored pawns (§10.1)

    /// Dresses this pawn as armored, or strips the armor off.
    ///
    /// The outline stays exactly as it was — Black's own magenta — and the
    /// *interior* fills with a lighter translucent red. Recolouring the outline
    /// silver, which is what §10.1's "heavy silver metallic outline" suggested
    /// and what this did first, made the pawn read as some other piece rather
    /// than as the same pawn wearing something. Filling it keeps the silhouette
    /// and the colour language intact and still says, unmistakably, that this
    /// one is different.
    ///
    /// The fill is a silhouette texture derived from the sprite's own outline
    /// (`filledSilhouette`), drawn behind it so the outline stays crisp on top.
    func setArmored(_ armored: Bool) {
        childNode(withName: Self.armorFillName)?.removeFromParent()
        guard armored else { return }

        let fill = SKSpriteNode(texture: Silhouette.filled(forTexture: piece.textureName),
                                color: NeonPalette.armorFill, size: size)
        fill.name = Self.armorFillName
        fill.colorBlendFactor = 1
        fill.alpha = 0.42
        fill.zPosition = -0.4          // inside the outline, over the board
        addChild(fill)
        // A slow breath, so it reads as something holding rather than as a
        // sprite that was simply drawn wrong.
        fill.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.28, duration: 0.8),
            .fadeAlpha(to: 0.5, duration: 0.8),
        ])), withKey: Self.armorKey)
    }

    /// A laser bounced off (§10.1): the fill flares white for a moment, so a
    /// no-damage hit cannot be mistaken for a miss.
    func flashArmorHit() {
        guard let fill = childNode(withName: Self.armorFillName) as? SKSpriteNode else { return }
        fill.removeAction(forKey: Self.armorKey)
        fill.run(.sequence([
            .group([.colorize(with: .white, colorBlendFactor: 1, duration: 0),
                    .fadeAlpha(to: 0.95, duration: 0)]),
            .wait(forDuration: 0.06),
            .group([.colorize(with: NeonPalette.armorFill, colorBlendFactor: 1,
                              duration: 0.14),
                    .fadeAlpha(to: 0.42, duration: 0.14)]),
            .run { [weak self] in self?.setArmored(true) },
        ]))
    }

    /// §10.1's expiry: the fill cracks — a stutter — and then drains away,
    /// leaving an ordinary pawn.
    func crackArmorAway(completion: @escaping () -> Void) {
        guard let fill = childNode(withName: Self.armorFillName) else {
            return completion()
        }
        fill.removeAction(forKey: Self.armorKey)
        fill.run(.sequence([
            .repeat(.sequence([.fadeAlpha(to: 0.9, duration: 0.05),
                               .fadeAlpha(to: 0.2, duration: 0.08)]), count: 3),
            .fadeOut(withDuration: 0.12),
            .removeFromParent(),
        ]))
        run(.sequence([.wait(forDuration: 0.51), .run(completion)]))
    }

    /// Gives this piece a hitbox, for a node that was created without one.
    ///
    /// Regeneration needs its own door here. It withholds the body for the
    /// beam-in and then has to restore it, and `refresh(with:)` cannot do that
    /// job: it rebuilds the body only when the *texture* changes, and a pawn
    /// arriving at full HP has the same texture it will keep. The regenerated
    /// pawn was therefore left with `physicsBody == nil` permanently — lasers
    /// passed straight through it for the rest of the wave, which reads exactly
    /// like armor that never expires.
    func becomeSolid() { rebuildPhysicsBody() }

    // MARK: - Transporter beam-in (§23.9)

    /// Materialises this piece out of a column of shimmer.
    ///
    /// Nothing about the piece is real until it finishes: the caller withholds
    /// the physics body, so lasers pass straight through, and §23.9's "the
    /// shimmering column is the warning" is the whole UI for that state.
    func beamIn(duration: TimeInterval, tint: SKColor,
                completion: @escaping () -> Void) {
        alpha = 0
        let column = SKNode()
        column.name = Self.beamName
        // Behind the sprite. In front — where this started — the shaft is
        // bright enough to hide the very thing it is delivering, and the
        // assembling piece is the part the player needs to read.
        column.zPosition = -1
        addChild(column)

        // A shaft of light four squares tall, striking down into the square.
        // The first version was flecks confined to the piece's own box, which
        // is what §23.9 describes and was far too quiet to notice across a busy
        // board — a piece coming *back* is one of the worst things that can
        // happen to the player, and it was the most easily missed event in the
        // game. The shaft is what makes it visible from anywhere.
        // Narrower than the piece, so its silhouette always shows past both
        // edges of the beam rather than being swallowed by it.
        let shaft = SKSpriteNode(texture: Self.beamTexture, color: tint,
                                 size: CGSize(width: size.width * 0.8,
                                              height: squareSize * 4))
        shaft.colorBlendFactor = 1
        shaft.blendMode = .add
        shaft.anchorPoint = CGPoint(x: 0.5, y: 0)      // grows upward from the square
        shaft.position = CGPoint(x: 0, y: -size.height * 0.45)
        shaft.alpha = 0
        column.addChild(shaft)
        shaft.run(.sequence([
            .group([.fadeAlpha(to: 0.7, duration: 0.12),
                    .scaleY(to: 1.0, duration: 0.12)]),
            // Then it breathes for the rest of the arrival.
            .repeatForever(.sequence([.fadeAlpha(to: 0.38, duration: 0.11),
                                      .fadeAlpha(to: 0.7, duration: 0.11)])),
        ]))
        shaft.yScale = 0.05

        // Flecks over the whole shaft, not just the piece — denser and brighter
        // than the first pass, and falling, so the column reads as pouring the
        // piece into place.
        let spawn = SKAction.run { [weak self, weak column] in
            guard let self, let column else { return }
            let fleck = SKSpriteNode(texture: Self.emberTexture, color: tint,
                                     size: CGSize(width: 4, height: 4))
            fleck.colorBlendFactor = 1
            fleck.blendMode = .add
            let top = self.squareSize * 3.2
            fleck.position = CGPoint(
                x: .random(in: -self.size.width * 0.5...self.size.width * 0.5),
                y: .random(in: 0...top))
            column.addChild(fleck)
            fleck.run(.sequence([
                .group([.moveBy(x: 0, y: -CGFloat.random(in: 20...60), duration: 0.3),
                        .fadeOut(withDuration: 0.3)]),
                .removeFromParent(),
            ]))
        }
        column.run(.repeatForever(.sequence([spawn, .wait(forDuration: 0.025)])))

        // The piece strobes into existence rather than fading up. A linear fade
        // spends most of its time as a faint ghost, which is exactly the part
        // nobody sees; a stutter is visible from the first step.
        let steps: [CGFloat] = [0.15, 0.02, 0.35, 0.05, 0.6, 0.15, 0.85, 0.4, 1.0]
        let stepTime = duration / TimeInterval(steps.count)
        var flicker: [SKAction] = []
        for step in steps {
            flicker.append(.fadeAlpha(to: step, duration: stepTime * 0.35))
            flicker.append(.wait(forDuration: stepTime * 0.65))
        }

        run(.sequence(flicker + [
            // One white frame as it resolves, and the shaft collapses at once.
            .run { [weak self] in
                guard let self else { return }
                self.alpha = 1
                if let column = self.childNode(withName: Self.beamName) {
                    column.run(.sequence([.scaleY(to: 0, duration: 0.1),
                                          .removeFromParent()]))
                }
                self.run(.sequence([
                    .colorize(with: .white, colorBlendFactor: 1, duration: 0),
                    .wait(forDuration: Juice.frameDuration * 3),
                    .colorize(with: self.baseColor,
                              colorBlendFactor: Self.baseBlend, duration: 0.14),
                ]))
                completion()
            },
        ]))
    }

    /// A soft-edged vertical bar: solid down the middle, falling away to
    /// nothing at both sides, so the shaft reads as light rather than as a
    /// painted rectangle.
    private static let beamTexture: SKTexture = {
        let width = 32, height = 4
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        let centre = CGFloat(width) / 2
        for x in 0..<width {
            let distance = abs(CGFloat(x) + 0.5 - centre) / centre
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1,
                                         alpha: pow(1 - distance, 1.6)))
            context.fill(CGRect(x: CGFloat(x), y: 0, width: 1, height: CGFloat(height)))
        }
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }()

    /// Embers drifting off a piece below half HP (§20 Phase 3.3's smoke trail).
    ///
    /// Not grey smoke: this board is neon on black, and grey reads as mud. A
    /// sparse drift in the piece's own glow colour says "this one is failing"
    /// in the vocabulary the rest of the board already uses.
    ///
    /// Idempotent — driven from `refresh`, which runs on every damage change.
    private func updateVenting() {
        let venting = Juice.vents(hp: piece.hp, maxHP: piece.type.maxHP)
        guard venting else {
            childNode(withName: Self.ventName)?.removeFromParent()
            return
        }
        guard childNode(withName: Self.ventName) == nil else { return }

        let vent = SKNode()
        vent.name = Self.ventName
        vent.zPosition = -0.6            // behind the piece, above the board
        addChild(vent)

        // One ember every 0.28s, each drifting up and out and fading. Cheap
        // enough at a handful of damaged pieces, and self-limiting: an ember
        // removes itself, so the node count cannot grow.
        let emit = SKAction.run { [weak self, weak vent] in
            guard let self, let vent else { return }
            let ember = SKSpriteNode(texture: Self.emberTexture, color: self.baseColor,
                                     size: CGSize(width: 3, height: 3))
            ember.colorBlendFactor = 1
            ember.alpha = 0.7
            ember.position = CGPoint(x: CGFloat.random(in: -self.size.width * 0.2
                                                       ... self.size.width * 0.2),
                                     y: -self.size.height * 0.1)
            vent.addChild(ember)
            ember.run(.sequence([
                .group([
                    .moveBy(x: CGFloat.random(in: -6...6), y: CGFloat.random(in: 14...24),
                            duration: 0.9),
                    .fadeOut(withDuration: 0.9),
                    .scale(to: 0.3, duration: 0.9),
                ]),
                .removeFromParent(),
            ]))
        }
        vent.run(.repeatForever(.sequence([emit, .wait(forDuration: 0.28)])))
    }

    /// A soft round dot, shared by every ember so they batch into one draw
    /// call — the same trick the starfield uses.
    private static let emberTexture: SKTexture = {
        let size = 8
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        let centre = CGFloat(size) / 2
        for step in stride(from: centre, to: 0, by: -0.5) {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1,
                                         alpha: 1 - step / centre))
            context.fillEllipse(in: CGRect(x: centre - step, y: centre - step,
                                           width: step * 2, height: step * 2))
        }
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }()

    /// This gunner is charging a round: the piece lights up from the inside.
    ///
    /// A copy of the piece's own texture, tinted and additively blended over
    /// the sprite, so what brightens is the silhouette itself — no new shape
    /// appears. The first version was a swelling ring behind the piece, which
    /// was very nearly the check halo (`startCheckGlow`, also a pulsing ring
    /// behind the sprite): two unrelated states drawn the same way. Ring
    /// vocabulary is spoken for — check, the king's shield, deflection — so a
    /// gunner charging has to look like something else entirely.
    ///
    /// Never touches `color`: a piece can be in check, damaged and charging at
    /// the same time, and `color` already belongs to the check glow and the hit
    /// flash.
    func flareGunner(tint: SKColor, duration: TimeInterval) {
        childNode(withName: Self.chargeGlowName)?.removeFromParent()
        let glow = SKSpriteNode(texture: texture, size: size)
        glow.name = Self.chargeGlowName
        glow.color = tint
        glow.colorBlendFactor = 1
        glow.blendMode = .add        // burns the existing outline brighter
        glow.zPosition = 1           // over the sprite, exactly on top of it
        glow.alpha = 0
        addChild(glow)
        // Swells to the shot and drops away with it, so the brightest instant
        // is the moment the round leaves. The slight scale-up spreads the same
        // silhouette a few points past its own edge — still the piece's shape,
        // never a ring.
        glow.run(.sequence([
            .group([.fadeAlpha(to: 0.9, duration: duration * 0.85),
                    .scale(to: 1.06, duration: duration * 0.85)]),
            .fadeOut(withDuration: 0.12),
            .removeFromParent(),
        ]))
    }

    /// A shot bounced off. Used when the player's own laser hits their king,
    /// which is refused rather than damaging (§Lose conditions would otherwise
    /// end the run on a stray shot).
    ///
    /// Deliberately a separate, self-removing node rather than reusing `halo`:
    /// the king can be in check at the same time, and that halo is owned by
    /// `setCheckGlow` — sharing one node would leave the red glow stranded.
    func flashDeflection() {
        let ring = SKShapeNode(circleOfRadius: squareSize * 0.34)
        ring.strokeColor = .white
        ring.lineWidth = 3
        ring.glowWidth = 8
        ring.fillColor = .clear
        ring.zPosition = 3
        ring.alpha = 0.95
        ring.setScale(0.6)
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.5, duration: 0.28), .fadeOut(withDuration: 0.28)]),
            .removeFromParent(),
        ]))
    }

    func applyHitFlash() {
        // A hit flash and the check glow both drive `color`, so restart the glow
        // afterwards rather than letting the flash strand the piece on its base tint.
        let wasShowingCheck = isShowingCheck
        if wasShowingCheck { removeAction(forKey: Self.checkGlowKey) }

        run(SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05),
            SKAction.colorize(with: baseColor, colorBlendFactor: Self.baseBlend, duration: 0.12)
        ])) { [weak self] in
            guard let self, wasShowingCheck, self.isShowingCheck else { return }
            self.startCheckGlow()
        }
    }

    func runDestructionAnimation(completion: @escaping () -> Void) {
        removeAction(forKey: Self.flickerKey)
        setCheckGlow(false)
        childNode(withName: Self.ventName)?.removeFromParent()
        // Drop the physics body immediately, not when the animation ends. The
        // node lingers for 0.18s while it scales and fades, and a body left in
        // place keeps generating contacts for a piece the board no longer has —
        // so a laser hitting the corpse was consumed, scored nothing, and did
        // no damage. With a 2-shot cap that also stalls the fire rate, which
        // reads as shots randomly not counting.
        physicsBody = nil
        run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.35, duration: 0.18),
                SKAction.fadeOut(withDuration: 0.18)
            ]),
            SKAction.removeFromParent()
        ]), completion: completion)
    }

    // MARK: - Idle bob

    /// A slow vertical float so the board is not perfectly static between moves.
    /// `phase` staggers pieces so they do not breathe in lockstep.
    func startIdleBob(phase: TimeInterval = 0) {
        guard action(forKey: Self.bobKey) == nil else { return }
        let up = SKAction.moveBy(x: 0, y: Self.bobAmplitude, duration: Self.bobHalfPeriod)
        up.timingMode = .easeInEaseOut
        let down = SKAction.moveBy(x: 0, y: -Self.bobAmplitude, duration: Self.bobHalfPeriod)
        down.timingMode = .easeInEaseOut
        run(.sequence([.wait(forDuration: phase),
                       .repeatForever(.sequence([up, down]))]), withKey: Self.bobKey)
    }

    /// Stops the bob so something else can own `position` for a moment — it is
    /// a `repeatForever` of `moveBy` pairs, so a concurrent `move(to:)` would be
    /// fighting it every frame. Internal now that a piece can slide back into
    /// the fleet formation as well as move between squares.
    func stopIdleBob() {
        removeAction(forKey: Self.bobKey)
    }

    // MARK: - Movement

    /// Slides to a new square centre and updates the logical square.
    ///
    /// The bob is a relative animation, so it is stopped for the duration and the
    /// node is snapped to the exact target afterwards — otherwise a part-finished
    /// bob would leave the piece a pixel or two off its square forever.
    func animateMove(to square: String, point: CGPoint, duration: TimeInterval = 0.22) {
        piece.logicalSquare = square
        stopIdleBob()
        emitGhostTrail(to: point, over: duration)

        let move = SKAction.move(to: point, duration: duration)
        move.timingMode = .easeInEaseOut
        run(move) { [weak self] in
            guard let self else { return }
            self.position = point
            self.startIdleBob(phase: TimeInterval.random(in: 0...Self.bobHalfPeriod))
        }
    }

    /// A few fading copies along the path — a cheap neon motion streak (§Phase 2.2).
    private func emitGhostTrail(to point: CGPoint, over duration: TimeInterval) {
        guard let parent, let texture else { return }
        let start = position
        let steps = 3
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps + 1)
            let ghost = SKSpriteNode(texture: texture)
            ghost.size = size
            ghost.position = CGPoint(x: start.x + (point.x - start.x) * t,
                                     y: start.y + (point.y - start.y) * t)
            ghost.color = baseColor
            ghost.colorBlendFactor = 0.85
            ghost.alpha = 0
            ghost.zPosition = zPosition - 1
            parent.addChild(ghost)
            ghost.run(.sequence([
                .wait(forDuration: duration * TimeInterval(t) * 0.6),
                .fadeAlpha(to: 0.34, duration: 0.04),
                .fadeOut(withDuration: 0.3),
                .removeFromParent(),
            ]))
        }
    }
}
