// Silhouette.swift
// Turns one of GCI's hollow neon outlines into a solid shape that can be
// tinted — the interior an outline encloses, plus the outline itself.
//
// The sprites carry alpha only on the stroke, so there is nothing to fill. This
// finds the fill by flooding inward from the image border: any transparent
// pixel the flood can reach is outside the piece, and any transparent pixel it
// cannot reach is enclosed by the outline, which is exactly the region wanted.
//
// Shared, because two unrelated things want the same trick — an armored pawn's
// green core (§10.1) and the ship's while Rapid Fire is up (§7.2) — and a
// second copy of a flood fill is a second place for it to be wrong.

import SpriteKit

@MainActor
enum Silhouette {

    private static var cache: [String: SKTexture] = [:]

    /// The filled shape for an atlas texture, measured once and cached.
    /// Falls back to the outline itself if the image cannot be read, which
    /// renders as the ordinary sprite rather than as nothing.
    static func filled(forTexture name: String) -> SKTexture {
        if let cached = cache[name] { return cached }
        let texture = build(name) ?? SKTexture(imageNamed: name)
        cache[name] = texture
        return texture
    }

    private static func build(_ name: String) -> SKTexture? {
        guard let image = SKTexture(imageNamed: name).cgImage() as CGImage?,
              image.width > 0, image.height > 0 else { return nil }
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(
            data: &pixels, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var outside = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        func consider(_ index: Int) {
            guard !outside[index], pixels[index * 4 + 3] <= 20 else { return }
            outside[index] = true
            stack.append(index)
        }
        for x in 0..<w { consider(x); consider((h - 1) * w + x) }
        for y in 0..<h { consider(y * w); consider(y * w + w - 1) }
        while let index = stack.popLast() {
            let x = index % w, y = index / w
            if x > 0 { consider(index - 1) }
            if x < w - 1 { consider(index + 1) }
            if y > 0 { consider(index - w) }
            if y < h - 1 { consider(index + w) }
        }

        var fill = [UInt8](repeating: 0, count: w * h * 4)
        for index in 0..<(w * h) where !outside[index] {
            // Enclosed, or the outline itself: both belong to the silhouette.
            fill[index * 4] = 255
            fill[index * 4 + 1] = 255
            fill[index * 4 + 2] = 255
            fill[index * 4 + 3] = 255
        }
        guard let out = CGContext(
            data: &fill, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.makeImage() else { return nil }
        return SKTexture(cgImage: out)
    }
}
