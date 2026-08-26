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
    private static let solidTexture: SKTexture = {
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
