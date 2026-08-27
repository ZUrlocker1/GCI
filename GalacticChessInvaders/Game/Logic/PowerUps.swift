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

    /// §13.2's values. Rapid Fire pays §9's plain-scout rate.
    ///
    /// The Bomb is still worth most, though no longer for §13.2's stated reason
    /// (it no longer takes two hits). It earns the top value by being the
    /// rarest — two levels in a run — and by clearing every round in flight at
    /// exactly the moments the sky is fullest, Crossfire and Blitz.
    var points: Int {
        switch self {
        case .rapidFire: return RaiderRules.scoutPoints
        case .shield:    return 100
        case .freeze:    return 150
        case .gatling:   return 150
        case .nuke:      return 250
        }
    }

    /// One hit, every carrier.
    ///
    /// §13.2 gives the Bomb Scout two, "like the Flagship", to make it "a
    /// meaningful challenge for the reward". In play it read as a bug rather
    /// than as a challenge: a clean hit that leaves the target flying looks like
    /// the shot missed, and a scout is small, fast and briefly on screen — the
    /// player has no time to reconsider what they just saw. The Flagship can
    /// carry that mechanic because it is large, slow and announced.
    var hp: Int { RaiderRules.scoutHP }

    /// Against `RaiderRules.scoutSpeed`.
    ///
    /// The Ice Scout drifts at 0.6× — §13.2's "drifting deliberately", which
    /// also makes the freeze the easiest of the five to collect, and it is the
    /// one whose value most depends on collecting it at a moment of your
    /// choosing.
    ///
    /// The Bomb Scout is 20% slower than standard, and stays so now that it only
    /// takes one hit: it is the only carrier that *swoops* — diving to rank 1–2
    /// at mid-crossing and climbing out — and a target moving fast vertically is
    /// far harder to lead with a vertical laser than one flying level.
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

    /// The sprite each carrier flies, all of them already in `GCI.spriteatlas`.
    ///
    /// These were sitting in the atlas unused while the specials were being
    /// drawn as shape overlays on the plain scout — a hexagonal grid, some
    /// spikes, a row of exhaust ports. Purpose-built art beats anything sketched
    /// over a disc at 30 points tall, and it was already there.
    ///
    /// The Nuke flies §6.4's Mutant Camel rather than `ship-scout-bomb`. The
    /// bomb sprite is a competent red mine and the camel is a Jeff Minter
    /// tribute with legs, and one of those is the right thing to see swooping at
    /// you carrying a nuclear weapon.
    ///
    /// Every other carrier stays on the plain scout disc with `RaiderNode`'s
    /// drawn overlays — the hexagonal grid, the crystalline facets, the row of
    /// exhaust ports. All three have purpose-built sprites in the atlas
    /// (`ship-scout-repair`, `-ice`, `-spread`, and `-bomb` besides) and all
    /// three were tried that way; the drawn versions read better in play, which
    /// is the only test that counts. The sprites stay in the atlas, unused.
    var spriteName: String { self == .nuke ? "ship-camel" : "ship-scout" }

    /// The camel's walk cycle, in order. Empty for everything else — a disc has
    /// no legs to move.
    ///
    /// Three drawings and four frames: the two swung poses are separated by the
    /// neutral one, which is the passing pose every walk cycle needs. Cycling
    /// B→C directly reads as a twitch, because the legs cross the middle without
    /// ever being seen there.
    ///
    /// The two swung frames are generated from the atlas sprite rather than
    /// drawn: the legs are sheared about the hip line, by an offset proportional
    /// to how far below the hip each row sits, so the leg pivots instead of
    /// sliding and stays attached. Front and rear swing in opposite phase, which
    /// is the part that reads as walking rather than as leaning.
    var walkCycle: [String] {
        guard self == .nuke else { return [] }
        return ["ship-camel", "ship-camel-b", "ship-camel", "ship-camel-c"]
    }

    /// A plodding trot: 0.8s for a full cycle. Faster looks like a scuttle, and
    /// this is a camel.
    var walkFrameDuration: TimeInterval { 0.2 }

    /// Against the standard 30pt scout height.
    ///
    /// Not 1.0 for everything, because the sprites do not fill their canvases
    /// equally: the plain scout is a wide 280×144 disc, and the four specials
    /// are compact shapes on 200×200 squares. Scaled by canvas alone the
    /// specials present *half* the target the green scout does, which is the
    /// wrong way round — they are rarer and more valuable, so they must not also
    /// be harder to hit by accident of how the art was cropped.
    ///
    /// Measured instead: each multiplier is the one that makes the sprite's
    /// visible ink cover the same area as the scout's 49.6 × 21.2pt.
    ///
    /// Both are applied to the sprite scaled to the standard 30pt height, so
    /// equal multipliers preserve its aspect and unequal ones distort on
    /// purpose.
    ///
    /// The Spread Scout is the distortion: §13.2 calls it "visibly wider", a
    /// "fat, squat disc", so it is 1.4 wide against 0.85 tall. The camel takes
    /// 1.5 on both — §6.4 makes it the larger of the two tribute ships, and a
    /// nuke carrier that reads as *big* is worth more than one that reads as
    /// consistent.
    var heightMultiplier: Double {
        switch self {
        case .gatling: return 0.85
        case .nuke:    return 1.5
        default:       return 1.0
        }
    }

    var widthMultiplier: Double {
        switch self {
        case .gatling: return 1.4
        case .nuke:    return 1.5
        default:       return 1.0
        }
    }

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
    /// | 7 | bomb, then bomb again — Nuke twice |
    /// | 8 | green, then spread |
    /// | 9 | green, then spread, then ice |
    /// | 10 | green, then spread, then ice, then bomb |
    ///
    /// One offer for most of the run, then two, three and four as the levels get
    /// hard enough to need them. The order within a level is cheapest first, so
    /// the player banks Rapid Fire before the spray arrives and has more shots
    /// to go after it with — and the bomb comes last on Blitz because clearing
    /// the sky is worth most once the sky is at its fullest.
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
        // Two camels. Crossfire is the hardest wave that had a single offer, so
        // one quick Nuke kill left the rest of it silent — and a second raider
        // arriving where the player has learned to expect none is also the
        // gentlest possible warning that Levels 8 and up send more than one.
        case 7:    return [.nuke, .nuke]
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

/// §13.2's Nuke: which pieces the shockwave claims.
///
/// The doc's version only cleared projectiles in flight, which is invisible —
/// the player saw a large ring and then an absence, and read it as some buff
/// they could not identify. Deleting things is not an effect you can see. So the
/// ring now also detonates the pieces it passes over, and the kills are the
/// visible half while the projectile clear stays the useful half.
@MainActor
enum Shockwave {

    /// At most three, and at least one wherever there is anything to hit.
    ///
    /// There is deliberately no radius limit. A cap on range would make the
    /// reward depend on where the bomb scout happened to die — which the player
    /// only partly controls, since the scout is swooping — and a Nuke that
    /// sometimes does nothing visible is the problem this was built to fix. The
    /// ring simply keeps expanding until it has found its targets.
    static let maxTargets = 3

    /// What the blast does to the black king, which it can never destroy.
    ///
    /// Half a rook. Enough that catching the king in a blast is worth something,
    /// far from enough to end a wave with it — the king has 16 HP, or 24 with
    /// Level 9's forcefield.
    static let kingDamage = 6

    /// Which pieces the blast claims, nearest first.
    ///
    /// Non-kings fill every slot before the king is considered at all, so the
    /// rarest power-up in the game is never spent on the one target it cannot
    /// kill. The king is only ever the target when he is the last black piece
    /// standing — at which point hitting him is the only thing left to do.
    static func targets(from candidates: [(square: String, distance: Double, isKing: Bool)])
        -> [String] {
        let ordered = candidates.sorted { $0.distance < $1.distance }
        let others = ordered.filter { !$0.isKing }
        guard others.isEmpty else { return others.prefix(maxTargets).map(\.square) }
        return ordered.first.map { [$0.square] } ?? []
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
