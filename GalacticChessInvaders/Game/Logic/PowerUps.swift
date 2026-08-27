// PowerUps.swift
// §13's power-ups, as pure rules. Which special scout a level carries, what it
// is worth, how long its effect runs. No SpriteKit — `RaiderNode` reads this to
// know what to look like and `GameScene` reads it to know what to do.
//
// §13.1's delivery rule is the whole design: there is no pickup to collect and
// nothing falls. Shooting the scout *is* the power-up. That keeps the reward on
// the arcade half of the game, where the player already has to aim, rather than
// adding a second thing to chase across a board that is busy enough.

import Foundation

/// The four special scouts. §13.2 specifies five; Lightning is retired —
/// its effect was "+1 laser slot", which is now what the ordinary green scout
/// grants, and two scouts handing over the same reward is one scout too many.
enum PowerUp: String, CaseIterable {
    /// §13.2 Repair Scout — absorbs the next lethal hit.
    case shield
    /// §13.2 Ice Scout — three seconds where only the player moves.
    case freeze
    /// §13.2 Bomb Scout — a shockwave that clears every enemy round in flight.
    case nuke
    /// §13.2 Spread Scout — fifteen seconds of uncapped five-way auto-fire.
    case gatling

    /// The level the type first appears, and from then on it stays in the pool.
    ///
    /// Each debut lands one level *before* the wave its effect answers, so the
    /// player meets a power-up while they can still experiment with it and
    /// already knows what it does by the time they need it:
    ///
    /// | Debut | Learned on | Paid off on |
    /// |---|---|---|
    /// | 2 | FIRE POWER — the first level that shoots back | every level after |
    /// | 4 | RELENTLESS — faster, harder fire | 5, TRIPLE THREAT |
    /// | 6 | WIDE ORBIT — a wider sweep | 7, CROSSFIRE |
    /// | 8 | ARMORED PAWNS | 9, KING ACTIVATED, and Blitz |
    ///
    /// Level 1 has no special at all. It is the level where the player is
    /// learning two control schemes at once, and the ordinary green scout —
    /// which now carries Rapid Fire — is the only reward it needs.
    var debutLevel: Int {
        switch self {
        case .shield:  return 2
        case .freeze:  return 4
        case .nuke:    return 6
        case .gatling: return 8
        }
    }

    /// §13.2's values. The Bomb is worth most because it is the only one that
    /// takes two hits.
    var points: Int {
        switch self {
        case .shield:  return 100
        case .freeze:  return 150
        case .nuke:    return 250
        case .gatling: return 150
        }
    }

    /// §13.2: the Bomb Scout flashes on the first hit, like the flagship.
    var hp: Int { self == .nuke ? 2 : 1 }

    /// Against `RaiderRules.scoutSpeed`. Only the Ice Scout differs — §13.2 has
    /// it "drifting deliberately", which also makes the freeze the easiest of
    /// the four to actually collect, and it is the one whose value most depends
    /// on collecting it at a moment of your choosing.
    var speedMultiplier: Double { self == .freeze ? 0.6 : 1.0 }

    /// §13.2's Spread Scout is "visibly wider" — a fat squat disc with five
    /// exhaust ports. The only one whose silhouette changes proportion.
    var widthMultiplier: Double { self == .gatling ? 1.4 : 1.0 }

    /// §13.3's flash at the destroy position.
    var label: String {
        switch self {
        case .shield:  return "SHIELD UP"
        case .freeze:  return "TIME FREEZE"
        case .nuke:    return "NUKE"
        case .gatling: return "SPREAD FIRE"
        }
    }

    /// How long the effect runs, or nil for the two that are not on a clock —
    /// the shield lasts until it is spent, the nuke is over in its own 0.4s.
    var duration: TimeInterval? {
        switch self {
        case .freeze:  return 3
        case .gatling: return 15
        case .shield, .nuke: return nil
        }
    }

    /// Whether two of these can be up at once. §13.1 allows only one *effect*
    /// at a time, which is really a statement about the timed ones: a shield
    /// sitting unspent is not competing with anything.
    var isTimed: Bool { duration != nil }
}

@MainActor
enum PowerUps {

    /// Every type available on a level, newest last.
    static func unlocked(atLevel level: Int) -> [PowerUp] {
        PowerUp.allCases
            .filter { level >= $0.debutLevel }
            .sorted { $0.debutLevel < $1.debutLevel }
    }

    /// The one special scout this level carries, or nil below Level 2.
    ///
    /// A debut level always shows its new type rather than drawing for it. A
    /// random draw would let a type the banner has effectively just promised
    /// sit out the whole wave, and the first sight of a power-up is the only
    /// chance the game gets to teach it.
    static func special(forLevel level: Int) -> PowerUp? {
        let pool = unlocked(atLevel: level)
        guard !pool.isEmpty else { return nil }
        if let debuting = pool.last, debuting.debutLevel == level { return debuting }
        return pool.randomElement()
    }

    /// Which crossing of the level is the special one, counting from zero.
    ///
    /// The first, always — and it has to be the first, because raids end when
    /// the player shoots a raider down (`RaiderRules.endsAfterAKill`). Put the
    /// special second and a player who shoots the opening green scout, which is
    /// the reflex the whole game trains, ends the raids having never seen the
    /// power-up the level was built around.
    ///
    /// First also makes the fallback the right way round: the special is the
    /// offer, and the ordinary green scouts that follow if it gets away are the
    /// consolation — still worth shooting, because Rapid Fire is still a
    /// reward, just not the one that was on the table.
    static let specialCrossingIndex = 0
}

/// The one timed effect that can be running, and its clock.
///
/// Held by the scene and ticked per frame, like `RegenerationQueue` and
/// `RaiderSchedule` — so §13.1's "a second effect replaces the first" is a
/// single assignment, and an effect dying with its level falls out of teardown.
@MainActor
struct PowerUpState {

    private(set) var active: PowerUp?
    private(set) var remaining: TimeInterval = 0

    /// Set when the shield is up. Not a duration: §13.2 has it last until it
    /// absorbs a hit, and not carry between levels.
    private(set) var hasShield = false

    var isFrozen: Bool { active == .freeze }
    var isGatling: Bool { active == .gatling }

    /// Starts a timed effect, replacing whatever was running (§13.1). Returns
    /// the effect it displaced so the scene can undo that one's world changes
    /// before applying the new one's.
    @discardableResult
    mutating func begin(_ powerUp: PowerUp) -> PowerUp? {
        guard let duration = powerUp.duration else { return nil }
        let displaced = active
        active = powerUp
        remaining = duration
        return displaced == powerUp ? nil : displaced
    }

    mutating func raiseShield() { hasShield = true }

    /// Spends the shield on a hit that would otherwise have cost a life.
    mutating func absorbHit() -> Bool {
        guard hasShield else { return false }
        hasShield = false
        return true
    }

    /// Advances the clock. Returns the effect that just ended, if one did.
    mutating func tick(_ dt: TimeInterval) -> PowerUp? {
        guard let running = active else { return nil }
        remaining -= dt
        guard remaining <= 0 else { return nil }
        active = nil
        remaining = 0
        return running
    }

    /// Ends the running effect early. Returns it, so the scene can lift its
    /// world changes on the same path a natural expiry takes.
    @discardableResult
    mutating func cancel() -> PowerUp? {
        let running = active
        active = nil
        remaining = 0
        return running
    }

    /// §13.2: the shield does not carry over to the next level, and neither
    /// does a running clock.
    mutating func reset() {
        active = nil
        remaining = 0
        hasShield = false
    }
}
