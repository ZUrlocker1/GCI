// BackdropNode.swift
// §12.5's per-level background evolution: a void colour and a coloured haze
// behind the starfield, changing with the wave.
//
// §12.5 gives a table ramping the void from #07070F to #160304. Those differ by
// a handful of RGB points against black, under a bloom layer — measured against
// each other they are essentially the same colour. So the void here stays close
// to black and the *haze* carries the change: it has shape and edges, which is
// what the eye actually reads.
//
// Keyed to each level's own mechanic rather than ramped cold-to-hot. A monotonic
// red ramp says "later"; Crossfire's diagonal and Armored Pawns' green say
// *which* wave you are on, which is how the rest of the game is built.
//
// Performance, against §12.4's rule that the background may not cost a shader:
// one procedurally drawn texture, shared by at most two sprites, so at most two
// draw calls. Colour and alpha are static properties set once per level, and the
// drift is two `SKAction`s on one node. Nothing here runs per frame.

import SpriteKit

@MainActor
final class BackdropNode: SKNode {

    /// One wave's sky.
    struct Look {
        let void: SKColor
        /// nil for the opening levels, which stay pure black.
        let haze: Haze?
    }

    struct Haze {
        let color: SKColor
        let alpha: CGFloat
        /// Fraction of the scene: where the blob sits and how big it is.
        let center: CGPoint
        let scale: CGSize
        let rotation: CGFloat
    }

    private static func rgb(_ hex: UInt32) -> SKColor {
        SKColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// The table from `docs/implementation.md`. Level 1 is deliberately
    /// untouched — it is the reference every later wave is read against — and no
    /// blob sits dead centre, which reads as staged rather than as weather.
    static func look(forLevel level: Int) -> Look {
        let black = SKColor.black
        switch max(1, level) {
        case 1:   // The reference every later wave is read against
            return Look(void: black, haze: nil)
        case 2:   // FIRE POWER — the faintest first hint, barely there
            return Look(void: rgb(0x03040A), haze: Haze(
                color: rgb(0x2E3A9E), alpha: 0.10,
                center: CGPoint(x: 0.58, y: 0.12), scale: CGSize(width: 1.4, height: 0.45),
                rotation: 0))
        case 3:   // DOUBLE TROUBLE
            return Look(void: rgb(0x04050C), haze: Haze(
                color: rgb(0x3A46B4), alpha: 0.16,
                center: CGPoint(x: 0.42, y: 0.18), scale: CGSize(width: 1.5, height: 0.55),
                rotation: 0))
        case 4:   // RELENTLESS — the same, deeper
            return Look(void: rgb(0x06050E), haze: Haze(
                color: rgb(0x4040C0), alpha: 0.20,
                center: CGPoint(x: 0.61, y: 0.24), scale: CGSize(width: 1.5, height: 0.7),
                rotation: 0))
        case 5:   // TRIPLE THREAT
            return Look(void: rgb(0x08040F), haze: Haze(
                color: rgb(0x6A32C0), alpha: 0.20,
                center: CGPoint(x: 0.45, y: 0.35), scale: CGSize(width: 1.4, height: 0.9),
                rotation: 0))
        case 6:   // WIDE ORBIT — the haze widens as the sweep does
            return Look(void: rgb(0x0A0410), haze: Haze(
                color: rgb(0x7A2EC8), alpha: 0.20,
                center: CGPoint(x: 0.44, y: 0.47), scale: CGSize(width: 2.1, height: 0.8),
                rotation: 0))
        case 7:   // CROSSFIRE — the grain lies along the bishops' own diagonals
            // A broad swathe, not a stripe: at 0.30 it read as a drawn band
            // with edges. Held off the centre in both axes, because a diagonal
            // through the middle of a square screen is the most symmetric thing
            // it could possibly be.
            return Look(void: rgb(0x0D0412), haze: Haze(
                color: rgb(0xC02A78), alpha: 0.15,
                center: CGPoint(x: 0.37, y: 0.58), scale: CGSize(width: 2.6, height: 1.05),
                rotation: .pi / 5))
        case 8:   // ARMORED PAWNS — the armour's green, deliberately off the ramp
            // Lightened and pulled toward aqua. The armour's own #35B45A is a
            // saturated grass green, which on black at this size read as sickly
            // rather than as armour; blue in the mix cools it and lifts it.
            return Look(void: rgb(0x0A0C08), haze: Haze(
                color: rgb(0x8ADCC4), alpha: 0.10,
                center: CGPoint(x: 0.58, y: 0.60), scale: CGSize(width: 1.7, height: 0.9),
                rotation: 0))
        case 9:   // KING ACTIVATED — the light comes from where he sits
            return Look(void: rgb(0x100509), haze: Haze(
                color: rgb(0xD08828), alpha: 0.20,
                center: CGPoint(x: 0.46, y: 0.94), scale: CGSize(width: 1.8, height: 0.7),
                rotation: 0))
        default:  // BLITZ
            // Faded. A pure hot red at 0.24 competed with the magenta pieces
            // it sits behind, which are the thing that has to be read.
            return Look(void: rgb(0x140306), haze: Haze(
                color: rgb(0xC4606C), alpha: 0.11,
                center: CGPoint(x: 0.55, y: 0.46), scale: CGSize(width: 2.2, height: 1.4),
                rotation: 0))
        }
    }

    /// Blitz runs the starfield faster. The only level that touches it.
    static func starfieldSpeed(forLevel level: Int) -> CGFloat {
        level >= 10 ? 1.35 : 1
    }

    private let sceneSize: CGSize
    private let blob: SKSpriteNode

    init(sceneSize: CGSize) {
        self.sceneSize = sceneSize
        blob = SKSpriteNode(texture: Self.hazeTexture())
        super.init()

        // Additive, so a haze on near-black can only add light. Alpha blending
        // at this opacity would grey the void instead of colouring it.
        blob.blendMode = .add
        blob.alpha = 0
        addChild(blob)

        // A slow wander, so the sky is not a static gradient. 26pt was
        // imperceptible on a blob wider than the screen; this travels further
        // and takes longer, and the vertical leg is a different period from the
        // horizontal one so the path never repeats a straight line.
        blob.run(.repeatForever(.sequence([
            .moveBy(x: 44, y: 0, duration: 26).withTimingMode(.easeInEaseOut),
            .moveBy(x: -44, y: 0, duration: 26).withTimingMode(.easeInEaseOut),
        ])))
        blob.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 18, duration: 37).withTimingMode(.easeInEaseOut),
            .moveBy(x: 0, y: -18, duration: 37).withTimingMode(.easeInEaseOut),
        ])))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Applies a wave's sky. Returns the void colour for the caller to set on
    /// the scene, since a node cannot set its own scene's background.
    @discardableResult
    func apply(level: Int) -> SKColor {
        let look = Self.look(forLevel: level)
        guard GameSettings.shared.nebula, let haze = look.haze else {
            blob.alpha = 0
            return GameSettings.shared.nebula ? look.void : .black
        }
        blob.color = haze.color
        blob.colorBlendFactor = 1
        blob.alpha = haze.alpha
        blob.zRotation = haze.rotation
        blob.size = CGSize(width: sceneSize.width * haze.scale.width,
                           height: sceneSize.height * haze.scale.height)
        blob.position = CGPoint(x: sceneSize.width * haze.center.x,
                                y: sceneSize.height * haze.center.y)
        return look.void
    }

    /// A soft elliptical falloff, drawn once at launch and shared. White, so the
    /// sprite's own `color` decides the hue.
    private static func hazeTexture(diameter: CGFloat = 256) -> SKTexture {
        let pixels = Int(diameter)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            // A gentler curve than the star dot's: the midpoint sits low so the
            // blob has a wide, weak skirt rather than a defined edge.
            let gradient = CGGradient(
                colorsSpace: space,
                // Four stops, not three, and the midpoint pulled in and down:
                // the core stays small and the skirt runs most of the radius,
                // so the blob has no edge to find. Three stops left a visible
                // shoulder where the falloff changed slope.
                colors: [SKColor.white.withAlphaComponent(1).cgColor,
                         SKColor.white.withAlphaComponent(0.42).cgColor,
                         SKColor.white.withAlphaComponent(0.11).cgColor,
                         SKColor.white.withAlphaComponent(0).cgColor] as CFArray,
                locations: [0, 0.28, 0.62, 1])
        else { return SKTexture() }

        let mid = CGPoint(x: diameter / 2, y: diameter / 2)
        context.drawRadialGradient(gradient, startCenter: mid, startRadius: 0,
                                   endCenter: mid, endRadius: diameter / 2,
                                   options: [])
        guard let image = context.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }
}

private extension SKAction {
    func withTimingMode(_ mode: SKActionTimingMode) -> SKAction {
        timingMode = mode
        return self
    }
}
