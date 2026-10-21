// Haptics.swift
// Touch feedback for the three moments that deserve it: a shot leaving the
// ship, a raider going down, a king being destroyed.
//
// iOS only. The generators are kept and `prepare()`d so the first tap after a
// quiet spell is not late; iPads and Macs without a Taptic Engine ignore the
// calls, and on macOS the file compiles to nothing.

#if os(iOS)
import UIKit

@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)

    /// Holding FIRE auto-repeats, so the laser can fire several times a
    /// second; a buzz on every one reads as a motor, not a shot.
    private static var lastFire: TimeInterval = 0
    private static let fireInterval: TimeInterval = 0.12

    static func prepare() {
        light.prepare(); medium.prepare(); heavy.prepare()
    }

    static func fire() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFire >= fireInterval else { return }
        lastFire = now
        light.impactOccurred(intensity: 0.5)
        light.prepare()
    }

    static func raiderShot() {
        medium.impactOccurred()
        medium.prepare()
    }

    static func kingDestroyed() {
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
    }
}
#else
@MainActor
enum Haptics {
    static func prepare() {}
    static func fire() {}
    static func raiderShot() {}
    static func kingDestroyed() {}
}
#endif
