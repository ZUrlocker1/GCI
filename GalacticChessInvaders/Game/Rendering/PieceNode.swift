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
    private static let bobKey = "idleBob"
    /// Small enough to read as breathing rather than hovering.
    private static let bobAmplitude: CGFloat = 2.0
    private static let bobHalfPeriod: TimeInterval = 0.8
    private static let baseBlend: CGFloat = 0.22

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
        let body = SKPhysicsBody(rectangleOf: bodySize, center: centre)
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

    /// Re-reads `piece` and refreshes the texture and flicker to match it.
    /// Keys off `textureName`, so promotions (type change) and damage both apply.
    func refresh(with updated: Piece) {
        let previousTexture = piece.textureName
        piece = updated
        guard updated.textureName != previousTexture else { return }

        let next = SKTexture(imageNamed: updated.textureName)
        texture = next
        size = Self.fit(next, in: squareSize)
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
        let ring = SKShapeNode(circleOfRadius: squareSize * 0.42)
        ring.name = key
        ring.strokeColor = NeonPalette.cyan
        // Thin at rest so it reads as a field rather than a drawn circle;
        // `flareForcefield` thickens and brightens it on each absorbed hit.
        ring.lineWidth = 1
        ring.glowWidth = 4
        ring.fillColor = NeonPalette.cyan.withAlphaComponent(0.05)
        ring.zPosition = -1
        addChild(ring)
        ring.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.45, duration: 0.7), .scale(to: 1.06, duration: 0.7)]),
            .group([.fadeAlpha(to: 0.95, duration: 0.7), .scale(to: 1.00, duration: 0.7)]),
        ])))
    }

    /// Brightens the shield for a moment — called when it absorbs a hit, so
    /// the field visibly takes the impact instead of the sprite.
    func flareForcefield() {
        guard let ring = childNode(withName: "forcefield") as? SKShapeNode else { return }
        ring.removeAction(forKey: "flare")
        ring.run(.sequence([
            .run { ring.lineWidth = 3; ring.glowWidth = 12; ring.strokeColor = .white },
            .wait(forDuration: 0.09),
            .run { ring.lineWidth = 1; ring.glowWidth = 4; ring.strokeColor = NeonPalette.cyan },
        ]), withKey: "flare")
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

    private func stopIdleBob() {
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
