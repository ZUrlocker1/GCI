// PowerUps.swift
// §13's power-ups, as pure rules: which raider a level sends, what it carries,
// what it is worth, how long its effect runs. No SpriteKit — `RaiderNode` reads
// this to know what to look like and `GameScene` reads it to know what to do.
//
// §13.1's delivery rule is the whole design: there is no pickup to collect and
// nothing falls. Shooting the scout *is* the power-up. That keeps the reward on
// the arcade half of the game, where the player already has to aim, rather than
// adding a second thing to chase across a board that is busy enough.

import Foundation

/// The five power-ups, one per raider. §13.2 lists five special scouts plus a
/// plain one that grants nothing; this collapses that to five carriers, because
/// the plain green scout now carries Rapid Fire — §7.2's promotion reward, moved
/// to a target the player can actually go and hunt.
///
/// The Lightning Scout is retired. Its effect was "+1 laser slot", which is what
/// Rapid Fire is; two ships handing over the same reward is one ship too many.
enum PowerUp: String, CaseIterable {
    /// The green Raider Scout. +1 simultaneous laser, stacking.
    case rapidFire
    /// §13.2 Repair Scout — absorbs the next lethal hit.
    case shield
    /// §13.2 Ice Scout — three seconds where only the player moves.
    case freeze
    /// §13.2 Spread Scout — fifteen seconds of uncapped five-way auto-fire.
    case gatling
    /// §13.2 Bomb Scout — a shockwave that clears every enemy round in flight.
    case nuke

    /// §13.2's values. The Bomb is worth most because it is the only one that
    /// takes two hits; Rapid Fire pays §9's plain-scout rate.
    var points: Int {
        switch self {
        case .rapidFire: return RaiderRules.scoutPoints
        case .shield:    return 100
        case .freeze:    return 150
        case .gatling:   return 150
        case .nuke:      return 250
        }
    }

    /// §13.2: the Bomb Scout flashes on the first hit, like the flagship.
    var hp: Int { self == .nuke ? 2 : RaiderRules.scoutHP }

    /// Against `RaiderRules.scoutSpeed`.
    ///
    /// The Ice Scout drifts at 0.6× — §13.2's "drifting deliberately", which
    /// also makes the freeze the easiest of the five to collect, and it is the
    /// one whose value most depends on collecting it at a moment of your
    /// choosing.
    ///
    /// The Bomb Scout is 20% slower than standard, and it needs to be: it is the
    /// only carrier that takes two hits, and the only one that *swoops* — diving
    /// to rank 1–2 at mid-crossing and climbing out. A target moving fast
    /// vertically is far harder to lead with a vertical laser than one flying
    /// level, so at full speed two hits inside one crossing asked for more than
    /// the reward is worth.
    ///
    /// The green scout is 7% off standard, which sounds like nothing and is not:
    /// what the player feels is the *closing* speed, and the ship only has 74
    /// px/s of it at full scout speed. Taking 7% off the scout adds 15 to the
    /// closing rate — a fifth more — because the margin, not the speed, is what
    /// the chase is made of.
    var speedMultiplier: Double {
        switch self {
        case .freeze:    return 0.6
        case .nuke:      return 0.8
        case .rapidFire: return 0.93
        default:         return 1.0
        }
    }

    /// §13.2's Spread Scout is "visibly wider" — a fat squat disc with five
    /// exhaust ports. The only one whose silhouette changes proportion.
    var widthMultiplier: Double { self == .gatling ? 1.4 : 1.0 }

    /// §13.3's flash at the destroy position, and the standing line in the
    /// player's alley while the effect is up.
    var label: String {
        switch self {
        case .rapidFire: return "RAPID FIRE"
        case .shield:    return "SHIELD UP"
        case .freeze:    return "TIME FREEZE"
        case .gatling:   return "SPREAD FIRE"
        case .nuke:      return "NUKE"
        }
    }

    /// The ship, for the diagnostics log. `rawValue` names the *effect*, which
    /// makes for lines like "rapidFire scout destroyed" — the log should say
    /// which ship the player just shot, in the same words §13.2 uses for it.
    var shipName: String {
        switch self {
        case .rapidFire: return "green"
        case .shield:    return "repair"
        case .freeze:    return "ice"
        case .gatling:   return "spread"
        case .nuke:      return "bomb"
        }
    }

    /// How long the effect runs, or nil for the three that are not on a clock —
    /// Rapid Fire lasts the wave, the shield until it is spent, the nuke is over
    /// in its own 0.4 seconds.
    var duration: TimeInterval? {
        switch self {
        case .freeze:  return 3
        // §13.2 says fifteen seconds and flags its own doubt about it. Seven,
        // after playtesting: at fifteen the barrage did not so much reward the
        // player as end the wave, and a power moment that lasts long enough to
        // become the whole level stops being a moment.
        case .gatling: return 7
        case .rapidFire, .shield, .nuke: return nil
        }
    }

    /// Whether two of these can be up at once. §13.1 allows only one *effect* at
    /// a time, which is really a statement about the timed ones: a shield
    /// sitting unspent is not competing with anything, and neither is a laser
    /// cap that has already been raised.
    var isTimed: Bool { duration != nil }
}

@MainActor
enum PowerUps {

    /// Which raiders a level sends, in the order they arrive.
    ///
    /// A fixed table rather than an unlocking pool. The pool version let any
    /// unlocked type turn up on any later level, which meant a player could not
    /// answer "what is coming?" by knowing where they were — and a raider whose
    /// identity is a surprise is a raider you cannot prepare for, which is the
    /// opposite of what a rare reward should be. Here every level has one
    /// answer, the same answer every run:
    ///
    /// | Level | Roster |
    /// |---|---|
    /// | 1, 2 | green — Rapid Fire |
    /// | 3 | repair — Shield |
    /// | 4 | ice — Time Freeze |
    /// | 5 | green — Rapid Fire again, because it is the generally useful one |
    /// | 6 | spread — Gatling Barrage |
    /// | 7 | bomb — Nuke |
    /// | 8 | green, then spread |
    /// | 9 | green, then spread, then ice |
    /// | 10 | green, then spread, then ice, then bomb |
    ///
    /// One offer for most of the run, then two, three and four as the levels get
    /// hard enough to need them. The order within a level is cheapest first, so
    /// the player banks Rapid Fire before the spray arrives and has more shots
    /// to go after it with — and the bomb comes last on Blitz because it is the
    /// only two-hit carrier, so it belongs behind the ones that make hitting it
    /// easier.
    ///
    /// Blitz is also the only level that offers all four, which is what stops
    /// the Nuke from appearing exactly once in a run: the stacked levels are
    /// otherwise green/spread/ice, so without this the bomb scout showed up on
    /// Level 7 and never again.
    static func roster(forLevel level: Int) -> [PowerUp] {
        switch max(1, level) {
        case 1, 2: return [.rapidFire]
        case 3:    return [.shield]
        case 4:    return [.freeze]
        case 5:    return [.rapidFire]
        case 6:    return [.gatling]
        case 7:    return [.nuke]
        case 8:    return [.rapidFire, .gatling]
        case 9:    return [.rapidFire, .gatling, .freeze]
        default:   return [.rapidFire, .gatling, .freeze, .nuke]
        }
    }

    /// The level a power-up is first offered, for the record and for tests.
    static func firstLevel(offering powerUp: PowerUp) -> Int? {
        (1...LevelManager.finalLevel).first { roster(forLevel: $0).contains(powerUp) }
    }
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
