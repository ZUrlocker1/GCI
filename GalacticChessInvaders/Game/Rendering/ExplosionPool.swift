// ExplosionPool.swift
// The burst a destroyed piece leaves behind (§20 Phase 3.3's "placeholder
// single burst"; per-piece animations are Phase 8).
//
// Built from the same vocabulary as the rest of the board rather than from a
// particle system: an expanding ring and a handful of shards, in the target's
// own glow colour, riding the bloom filter that is already on the parent. A
// grey smoke puff would read as mud against neon on black.
//
// Pooled like everything else that appears during play (§18) — eight bursts,
// pre-built with their shards, shown and hidden rather than allocated.

import SpriteKit

@MainActor
final class ExplosionPool {

    private static let count = 8
    private var bursts: [ExplosionNode] = []

    init(parent: SKNode) {
        bursts = (0..<Self.count).map { _ in
            let node = ExplosionNode()
            parent.addChild(node)
            return node
        }
    }

    /// `scale` is the size of the event: 1.0 for an ordinary piece, larger for
    /// a king. Does nothing if all eight are already burning, which needs eight
    /// destructions inside half a second.
    func burst(at position: CGPoint, color: SKColor, scale: CGFloat = 1.0) {
        guard let node = bursts.first(where: { !$0.isBurning }) else { return }
        node.burst(at: position, color: color, scale: scale)
    }

    func reset() { bursts.forEach { $0.stop() } }
}

/// The spray a *survivable* hit throws off: §24.5's single-frame impact flash,
/// plus a handful of glass slivers.
///
/// Sized at twice the first attempt, which was too quiet to register against a
/// board already carrying bloom, a starfield and charge-up glows — every
/// dimension doubled, plus two more shards and a slightly longer life so the
/// spray has time to travel the extra distance.
///
/// Separate from `ExplosionPool` rather than a smaller mode of it, and pooled
/// deeper, because these fire on every landed shot — sharing one pool would let
/// a burst of hits starve the destruction bursts, which are the ones that
/// matter. A piece is a neon outline, so what comes off it when struck is
/// shards of bright glass, not debris.
@MainActor
final class ShatterPool {

    private static let count = 14
    private var sprays: [ShatterNode] = []

    init(parent: SKNode) {
        sprays = (0..<Self.count).map { _ in
            let node = ShatterNode()
            parent.addChild(node)
            return node
        }
    }

    /// `along` is the direction the shot was travelling. Glass sprays forward
    /// in a wide cone from there, the way it actually would — a symmetric
    /// starburst reads as an explosion, which is the wrong size of event.
    func shatter(at position: CGPoint, color: SKColor, along direction: CGVector,
                 scale: CGFloat = 1) {
        guard let node = sprays.first(where: { !$0.isBusy }) else { return }
        node.shatter(at: position, color: color, along: direction, scale: scale)
    }

    func reset() { sprays.forEach { $0.stop() } }
}

@MainActor
final class ShatterNode: SKNode {

    fileprivate static let shardCount = 9
    private static let life: TimeInterval = 0.36

    private let flash = SKSpriteNode(texture: ExplosionNode.solidTexture,
                                     color: .white, size: CGSize(width: 14, height: 14))
    private var shards: [SKSpriteNode] = []
    private(set) var isBusy = false

    override init() {
        super.init()
        zPosition = 20
        isHidden = true
        flash.colorBlendFactor = 1
        flash.blendMode = .add
        addChild(flash)
        shards = (0..<Self.shardCount).map { _ in
            // Thin slivers rather than dots: a shard of a broken outline has a
            // long axis, and it is the long axis catching the light that reads
            // as glass rather than as sparks.
            let shard = SKSpriteNode(texture: ExplosionNode.solidTexture,
                                     color: .white, size: CGSize(width: 2.8, height: 10))
            shard.colorBlendFactor = 1
            addChild(shard)
            return shard
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func shatter(at point: CGPoint, color: SKColor, along direction: CGVector,
                 scale: CGFloat = 1) {
        stop()
        position = point
        isHidden = false
        isBusy = true

        // §24.5 asks for one frame, no linger. Two frames of fade reads the
        // same and survives a dropped frame.
        flash.alpha = 0.9
        flash.setScale(scale)
        flash.run(.sequence([.wait(forDuration: Juice.frameDuration),
                             .fadeOut(withDuration: Juice.frameDuration * 2)]))

        let heading = atan2(direction.dy, direction.dx)
        for shard in shards {
            // A 150° cone around the shot's heading: mostly forward, with a
            // little backscatter, which is what makes it look like something
            // broke rather than something fired.
            let angle = heading + CGFloat.random(in: -1.3...1.3)
            let distance = CGFloat.random(in: 18...40) * scale
            shard.color = color
            shard.position = .zero
            shard.zRotation = angle
            shard.alpha = 1
            shard.setScale(CGFloat.random(in: 0.7...1.3) * scale)
            shard.run(.group([
                .sequence([
                    .move(by: CGVector(dx: cos(angle) * distance,
                                       dy: sin(angle) * distance),
                          duration: Self.life * 0.7),
                    // A short fall at the end: glass does not hang in the air.
                    .moveBy(x: 0, y: -10, duration: Self.life * 0.3),
                ]),
                .rotate(byAngle: CGFloat.random(in: -2.5...2.5), duration: Self.life),
                .sequence([.wait(forDuration: Self.life * 0.35),
                           .fadeOut(withDuration: Self.life * 0.65)]),
            ]))
        }
        run(.sequence([.wait(forDuration: Self.life + 0.02),
                       .run { [weak self] in self?.stop() }]))
    }

    func stop() {
        removeAllActions()
        flash.removeAllActions()
        flash.alpha = 0
        shards.forEach { $0.removeAllActions() }
        isHidden = true
        isBusy = false
    }
}

@MainActor
final class ExplosionNode: SKNode {

    fileprivate static let shardCount = 8
    fileprivate static let baseRadius: CGFloat = 9

    private let ring = SKShapeNode(circleOfRadius: ExplosionNode.baseRadius)
    private var shards: [SKSpriteNode] = []
    private(set) var isBurning = false

    override init() {
        super.init()
        zPosition = 21           // over the board and the pieces, under the HUD
        isHidden = true

        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 5
        addChild(ring)

        // Shards are sprites, not shape nodes: they share one texture and one
        // blend mode, so the eight of them batch into a single draw call.
        shards = (0..<Self.shardCount).map { index in
            let shard = SKSpriteNode(texture: Self.solidTexture, color: .white,
                                     size: CGSize(width: 2.2, height: 7))
            shard.colorBlendFactor = 1
            // Fanned evenly, then jittered per burst so no two look stamped.
            shard.zRotation = CGFloat(index) / CGFloat(Self.shardCount) * 2 * .pi
            addChild(shard)
            return shard
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func burst(at point: CGPoint, color: SKColor, scale: CGFloat) {
        stop()
        position = point
        isHidden = false
        isBurning = true

        let life = 0.32 * TimeInterval(min(scale, 2.5))
        ring.strokeColor = color
        ring.setScale(0.35)
        ring.alpha = 0.95
        ring.run(.group([
            .scale(to: 2.6 * scale, duration: life),
            .sequence([.wait(forDuration: life * 0.3),
                       .fadeOut(withDuration: life * 0.7)]),
        ]))

        for (index, shard) in shards.enumerated() {
            // A fresh spread each time, so a second kill on the same square
            // does not look like a replay of the first.
            let angle = (CGFloat(index) + CGFloat.random(in: -0.3...0.3))
                / CGFloat(Self.shardCount) * 2 * .pi
            let distance = CGFloat.random(in: 14...26) * scale
            shard.color = color
            shard.position = .zero
            shard.zRotation = angle
            shard.alpha = 1
            shard.setScale(scale)
            shard.isHidden = false
            shard.run(.group([
                .move(by: CGVector(dx: cos(angle) * distance,
                                   dy: sin(angle) * distance), duration: life),
                .fadeOut(withDuration: life),
            ]))
        }

        run(.sequence([.wait(forDuration: life + 0.02),
                       .run { [weak self] in self?.stop() }]))
    }

    func stop() {
        removeAllActions()
        ring.removeAllActions()
        shards.forEach { $0.removeAllActions() }
        isHidden = true
        isBurning = false
    }

    /// A white pixel, stretched per shard and tinted. Built from a raw bitmap
    /// for the same reason LaserNode's is: `SKView.texture(from:)` can return
    /// nil before the view has rendered a frame, and this runs at class load.
    fileprivate static let solidTexture: SKTexture = {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }()
}
