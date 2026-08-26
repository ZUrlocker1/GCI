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

    /// General UI chrome — HUD text, menu highlights, headings.
    static let orange = SKColor(red: 1.00, green: 0.73, blue: 0.12, alpha: 1)

    /// A hotter, more saturated accent reserved for the title screen and
    /// transient in-game call-outs (TEST MODE's sibling AUTO flash, the title
    /// headline). Deliberately distinct from `orange` — not a duplicate to
    /// collapse.
    static let alertOrange = SKColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1)
}
