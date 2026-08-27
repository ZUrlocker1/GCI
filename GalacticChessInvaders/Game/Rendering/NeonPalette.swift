// NeonPalette.swift
// The neon accent colors shared by every board/HUD/menu overlay node. These
// were previously the same SKColor literals copy-pasted into eight separate
// files; this just gives the copy one place to live. Each node keeps its own
// `private static let cyan`-style alias pointing here, so no call site changes.

import SpriteKit

enum NeonPalette {
    static let cyan    = SKColor(red: 0.07, green: 0.88, blue: 1.00, alpha: 1)
    static let magenta = SKColor(red: 1.00, green: 0.13, blue: 0.38, alpha: 1)

    /// `magenta` lifted 50% toward white, for Black's projectiles.
    ///
    /// A laser is 4px wide, so it carries almost no area for the bloom filter to
    /// work with — at full saturation the same magenta that reads as a bright
    /// outline on a piece reads as dark red on a bolt. This keeps it
    /// recognisably Black's colour while actually looking like it is glowing.
    static let magentaLight = SKColor(red: 1.00, green: 0.565, blue: 0.69, alpha: 1)

    /// Starfield accents. The field used to carry a few magenta stars, which
    /// read as dull red specks against black rather than as distant suns —
    /// blue sits far better beside the white majority and the cyan accents.
    static let starBlueDeep  = SKColor(red: 0.20, green: 0.34, blue: 0.85, alpha: 1)
    static let starBlueLight = SKColor(red: 0.60, green: 0.80, blue: 1.00, alpha: 1)

    /// §12's "deep purple glow" for angled invader fire, so an angled shot is
    /// distinguishable from a straight one at a glance.
    static let shotPurple = SKColor(red: 0.72, green: 0.45, blue: 1.00, alpha: 1)

    /// The activated king's beam. Light red so it reads as the king's own
    /// weapon rather than ordinary fleet fire, without going white-hot.
    static let kingBeamRed = SKColor(red: 1.00, green: 0.42, blue: 0.42, alpha: 1)

    /// General UI chrome — HUD text, menu highlights, headings.
    static let orange = SKColor(red: 1.00, green: 0.73, blue: 0.12, alpha: 1)

    /// §12's `#7DFF4D` for the Raider Scout and its shot — acid green, chosen
    /// to be unmistakable against both sides' fire. Cyan is the player's,
    /// magenta and purple are Black's; a raider belongs to neither.
    static let acidGreen = SKColor(red: 0.49, green: 1.00, blue: 0.30, alpha: 1)

    /// §23.9's standard transporter column: green-white. The defensive spawn
    /// uses `starBlueLight` instead, and the colour is the only thing telling
    /// the player whether the arriving pawn is random or shielding the king.
    static let transporterGreen = SKColor(red: 0.55, green: 1.00, blue: 0.72, alpha: 1)

    /// The fill inside an armored pawn (§10.1). The outline stays Black's own
    /// magenta — recolouring it silver, which is what the doc's "heavy silver
    /// metallic outline" suggested, made the piece read as a different piece
    /// rather than as the same pawn wearing something.
    ///
    /// Deliberately the *same* green the transporter column arrives in, not a
    /// near-match: armor only ever comes with a regenerated pawn, so the beam
    /// that delivers it and the shell it wears should be one colour and read as
    /// one event. It is also complementary to Black's magenta, which is why a
    /// translucent fill inside a magenta outline reads at a glance.
    static let armorFill = transporterGreen

    // MARK: - Special scouts (§13.2)
    //
    // Each power-up scout has to be identifiable in the fraction of a second
    // before the player commits to chasing it, which means the colour does the
    // work — the silhouettes differ too, but at 30 points tall against a busy
    // board the hue is what carries at a glance. All four are chosen to sit
    // outside the colours already spoken for: cyan is the player, magenta and
    // purple are Black, acid green is the ordinary scout.

    /// §13.2's Ice Scout: "pale icy blue-white". Cold enough to read as ice
    /// next to the player's cyan without being mistaken for it.
    static let iceBlue = SKColor(red: 0.72, green: 0.94, blue: 1.00, alpha: 1)

    /// §13.2's Bomb Scout: "crimson-red". Deeper and bluer than the king's
    /// beam red, which is the only other red on screen.
    static let crimson = SKColor(red: 1.00, green: 0.22, blue: 0.24, alpha: 1)

    /// A hotter, more saturated accent reserved for the title screen and
    /// transient in-game call-outs (the AUTO move flash, SKIP LEVEL, the title
    /// headline). Deliberately distinct from `orange` — not a duplicate to
    /// collapse.
    static let alertOrange = SKColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1)
}

extension SKColor {
    /// Mixes this colour toward `other`. Used where a colour has to be derived
    /// from a palette entry at runtime rather than named — a special scout's
    /// hull tint, the nuke ring fading from magenta to white — so those stay
    /// tied to the palette instead of becoming loose literals.
    func blended(toward other: SKColor, by amount: CGFloat) -> SKColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        #if canImport(AppKit)
        guard let lhs = usingColorSpace(.deviceRGB),
              let rhs = other.usingColorSpace(.deviceRGB) else { return self }
        lhs.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        rhs.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #else
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #endif
        let mix = max(0, min(1, amount))
        return SKColor(red: r1 + (r2 - r1) * mix,
                       green: g1 + (g2 - g1) * mix,
                       blue: b1 + (b2 - b1) * mix,
                       alpha: a1 + (a2 - a1) * mix)
    }
}
