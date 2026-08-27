// RaiderRules.swift
// The raiders' decisions (§6, §21.1), as pure rules and a pure timer.
//
// Raiders run on a real-time clock, not on the chess beat. That is the point of
// them: everything else in GCI — the fleet's sweep, its descent, its fire, the
// regeneration — is paced off the turn, so the whole board pulses together and
// a player learns to think in beats. A raider ignores that rhythm entirely, and
// is the only thing on screen that does.
//
// What flies on which level is `PowerUps.roster`. This file owns how it flies,
// how often, and whether it shoots.

import CoreGraphics
import Foundation

enum RaiderRules {

    // MARK: - Scout (§6, "Space Invaders mystery ship")

    /// Points per second across the board.
    ///
    /// The hard constraint is `SpaceshipNode.speed`: below it, and by enough to
    /// matter. A scout the ship cannot outrun is a scout the player can only
    /// hit by being in the right place already — seeing one and going after it
    /// has to be possible. At 220 against the ship's 294 the player closes at
    /// 74 px/s, so a missed pass is recoverable rather than final.
    ///
    /// It was 300 first, which is *faster than the ship*, and uncatchable by
    /// construction.
    static let scoutSpeed: CGFloat = 220
    static let scoutHP = 1
    /// §9's table.
    static let scoutPoints = 100

    /// The scout's round travels 25% faster than the fleet's.
    ///
    /// It also starts much higher — over the board for most kinds, a whole
    /// board above the ship — so at fleet speed it was the slowest thing on
    /// screen to arrive despite coming from the most exposed position. The
    /// scout is a raid; its shot should not amble.
    static let shotSpeedMultiplier: CGFloat = 1.25

    /// The floor under a scout's round, and the reason it is not simply the
    /// level's projectile speed.
    ///
    /// §21.1 gives Level 1 a projectile speed of *zero*, because the fleet does
    /// not fire there. Deriving the scout's shot from it therefore produced a
    /// round of speed zero, which `LaserNode.fire` refuses outright — so the
    /// scout could never shoot on Level 1, the one level where §6 makes it the
    /// player's only repeatable incoming fire. 180 is what the fleet fires at
    /// when it starts firing, at Level 2.
    static let baseShotSpeed: CGFloat = 180

    static func shotSpeed(level: LevelParameters) -> CGFloat {
        max(baseShotSpeed, level.projectileSpeed) * shotSpeedMultiplier
    }

    /// Nodes in the pool. Two, because §6 caps raiders on screen at two and the
    /// escorts and flagship still to come will want the second slot.
    static let maxOnScreen = 2

    /// How many scouts may be crossing at once — one.
    ///
    /// §6's cap is two, written for a mix of scouts, escorts and a flagship.
    /// With the roster offering one kind at a time, two of the same scout on
    /// screen is the same offer twice, and the gap between crossings — the thing
    /// that stops raiders becoming wallpaper — stops being clear sky at all.
    /// One at a time also makes "which raider is this level's" answerable by
    /// looking, which is the point of a fixed roster.
    static let maxScoutsOnScreen = 1

    // MARK: - Cadence

    /// Clear sky between one crossing and the next, by how many power-ups the
    /// level is offering.
    ///
    /// The gap is what the player feels, not the share of time a scout is up.
    /// Twenty-two seconds gives a crossing every ~28s: a wave sees two to four,
    /// so each is an event. (It was seven, which is a crossing every 12.6s and
    /// nine or ten in a wave — a constant presence rather than a raid.)
    ///
    /// It shortens where the roster is longer, because on those levels the
    /// player has to bring down two or three raiders in one wave and every miss
    /// costs a full gap. Without this, Levels 9 and 10 would advertise three
    /// power-ups and realistically hand over one.
    static func minimumGap(rosterCount: Int) -> TimeInterval {
        switch max(1, rosterCount) {
        case 1:  return 22
        case 2:  return 15
        default: return 12
        }
    }

    /// The first crossing of a level comes at a fraction of the full gap.
    ///
    /// At the full gap the opening scout arrived so late that on a short wave it
    /// never came at all — and the first crossing carries the level's first
    /// power-up, so a late first pass is an offer never made. The long gaps are
    /// what stop raiders becoming wallpaper; they are not needed before the
    /// first one has been seen.
    static let openingLead = 0.55

    /// The interval actually used: the level's, or one crossing plus the gap,
    /// whichever is longer.
    ///
    /// Derived from the crossing rather than written into §21.1's table, so
    /// changing a scout's speed cannot silently close the gap again. Note that
    /// this overrides §21.1's `raiderInterval` at every level — raider frequency
    /// is set by the roster, not by the level's own escalation.
    static func interval(forLevel levelInterval: TimeInterval,
                         crossing: TimeInterval,
                         rosterCount: Int = 1) -> TimeInterval {
        max(levelInterval, crossing + minimumGap(rosterCount: rosterCount))
    }

    /// How long one crossing takes, entry to exit, including the off-screen
    /// margin at both ends.
    static func crossingDuration(sceneWidth: CGFloat, scoutWidth: CGFloat,
                                 speedMultiplier: Double = 1) -> TimeInterval {
        TimeInterval((sceneWidth + scoutWidth * 2) / (scoutSpeed * CGFloat(speedMultiplier)))
    }

    // MARK: - Flight paths (§6.3)

    /// The vertical shape of a crossing. Tied to the *kind* of raider rather
    /// than to the level, so the path is part of the ship's identity: once the
    /// player has seen an ice scout weave, every ice scout weaves on every
    /// level, and the path becomes a second cue for what is on offer.
    ///
    /// Each case carries its own numbers rather than reading shared constants,
    /// because they are randomised per crossing — the same ship, flown a little
    /// differently each time.
    enum Flight: Equatable {
        /// Dead level, all the way across. The green scout's, and deliberately
        /// the only one: it is the raider the player meets first and chases most
        /// often, so it should be a pure horizontal aiming problem with nothing
        /// else going on.
        case straight
        /// A sine weave: how far it strays either side of its lane, and how long
        /// half a cycle takes.
        case weave(amplitude: CGFloat, halfPeriod: TimeInterval)
        /// Enters high and descends steadily across the whole crossing, exiting
        /// low. Reads as coming down to meet the player.
        case glide(drop: CGFloat)
        /// One dive and climb: down to `depth` below the entry lane by
        /// mid-crossing, back out by the far edge.
        case swoop(depth: CGFloat)
    }

    /// Where a crossing begins.
    enum Lane: Equatable {
        /// Above every piece however far the fleet has descended — where Space
        /// Invaders' mystery ship flies, and what makes a raider read as a
        /// passing bonus rather than as part of the fleet.
        case overTheBoard
        /// Centred on a board rank, in among the pieces (§6's rank 4-5).
        case rank(Int)
    }

    /// The lane each kind enters on.
    static func lane(for powerUp: PowerUp) -> Lane {
        switch powerUp {
        // The two that come down to the player start from the top, so the
        // descent has the whole screen to be visible in.
        case .rapidFire, .shield, .nuke: return .overTheBoard
        // The two weavers fly in traffic, which is where a weave costs the
        // player something: the pieces are the reason a vertical guess is hard.
        case .freeze:  return .rank(Bool.random() ? 4 : 5)
        case .gatling: return .rank(Bool.random() ? 5 : 6)
        }
    }

    /// A fresh flight path for one crossing. Randomised inside each kind's
    /// character, so a player who has learned the shape still has to read this
    /// particular one.
    ///
    /// `headroom` is how far the entry lane sits above the lowest point a raider
    /// may reach, so the descending paths use the space that actually exists
    /// rather than a number that assumes a lane.
    static func flight(for powerUp: PowerUp, headroom: CGFloat) -> Flight {
        switch powerUp {
        case .rapidFire:
            return .straight

        case .freeze:
            // Tight and quick against its slow travel: about three full waves
            // across a crossing, so it reads as a rhythm you can aim against.
            // Just under a square either side, so it never goes anywhere it
            // could not have been.
            return .weave(amplitude: .random(in: 46...60),
                          halfPeriod: .random(in: 0.75...1.05))

        case .gatling:
            // The same idea at a different scale — nearly twice the amplitude
            // over more than twice the period, so it sweeps rather than
            // ripples. Distinct from the ice scout at a glance, which is the
            // requirement: two weavers that look alike are one wasted path.
            return .weave(amplitude: .random(in: 74...104),
                          halfPeriod: .random(in: 1.9...2.6))

        case .shield:
            // A long shallow diagonal. The angle is the variation: at the
            // shallow end it barely leaves the top of the board, at the steep
            // end it arrives in the player's own strip by the far edge.
            return .glide(drop: headroom * .random(in: 0.55...0.95))

        case .nuke:
            // The aggressive one, and the only one that comes at the player and
            // leaves again. Two hits to kill, so the dive is what makes the
            // second one gettable: it is closest at mid-crossing, which is also
            // when it is moving most steeply and hardest to lead.
            return .swoop(depth: headroom * .random(in: 0.7...0.95))
        }
    }

    /// A one-in-five chance the crossing doubles back on itself before carrying
    /// on the way it was going — for the two carriers that are allowed to.
    ///
    /// Returns where to turn and how far back to go, or nil for a straight
    /// crossing. The point is not difficulty: a raider that doubles back is on
    /// screen *longer* and is marginally easier to catch. It is that a crossing
    /// the player has already read stops being fully predictable.
    ///
    /// One in five is often enough to make the player watch and rare enough that
    /// the straight crossing stays the thing they are watching *for*.
    static let feintChance = 0.2
    /// How far back it comes, as a fraction of the crossing.
    static let feintDepth: ClosedRange<CGFloat> = 0.10...0.20

    /// Only the Spread and Bomb carriers double back.
    ///
    /// It was every carrier first, which spread the surprise so thin it became
    /// the weather — a tax on the player's aim everywhere rather than a moment
    /// anywhere. Tied to two ships it is a *tell*: the fat orange disc and the
    /// honking camel are the ones that might not go where they are pointed, and
    /// the other three stay clean to read.
    static func doublesBack(_ powerUp: PowerUp) -> Bool {
        powerUp == .gatling || powerUp == .nuke
    }

    static func feint(for powerUp: PowerUp, span: CGFloat, from cursor: CGFloat,
                      to toX: CGFloat) -> (turn: CGFloat, back: CGFloat)? {
        guard doublesBack(powerUp) else { return nil }
        guard Double.random(in: 0..<1) < feintChance else { return nil }
        // Somewhere in the middle of what is left: a feint in the first moments
        // is not yet a change of mind, and one at the far edge is not seen.
        let turn = cursor + (toX - cursor) * .random(in: 0.35...0.6)
        let back = turn - span * .random(in: feintDepth)
        // Never back past where it came in, which would read as a second entry.
        let limited = span > 0 ? max(back, cursor) : min(back, cursor)
        guard abs(limited - turn) > 8 else { return nil }
        return (turn, limited)
    }

    /// Where a dive bottoms out, as a fraction of the crossing. Just before
    /// halfway, so the climb out is longer than the dive in and the raider
    /// spends its slowest moment low, near the player.
    static let swoopLowPoint = 0.45

    // MARK: - Firing

    /// Early levels hold the scout back until the fleet's rear rank has thinned.
    ///
    /// Level 1 is where the player is learning two control schemes at once, and
    /// §21.1 already gives it no fleet fire at all — a scout arriving over an
    /// untouched board is one more thing to parse before anything has happened.
    /// Waiting until the back rank is broken means the first one shows up as a
    /// reward for making progress.
    static func waitsForThinnedRearRank(level: Int) -> Bool { level <= 2 }

    /// More than this many pieces still on the fleet's rear rank counts as
    /// crowded — half of a full rank.
    static let crowdedRearRank = 4

    /// Where in the crossing the single shot leaves, as a fraction of the way
    /// across. Never at the very edges: a shot fired as the scout enters is
    /// unreadable, and one fired as it leaves is unavoidable.
    static func fireFraction() -> CGFloat { .random(in: 0.25...0.7) }

    /// §6's Galaga precedent, tied to the *kind* of raider.
    ///
    /// §6 gives a free pass to the first scout of every level. That spends its
    /// rationale — "the player sees the attack pattern before being shot at" —
    /// the first time, and then keeps handing over a harmless raider forever: by
    /// Level 8 the player has seen thirty of them and still gets one a wave.
    ///
    /// A pass is owed once per *ship*, per run: the first green scout, the first
    /// repair scout, the first ice scout, and so on. Five in a run, each one
    /// genuinely the first sight of a new silhouette flying a new path — which
    /// is exactly the case §6's rule was written for.
    static func fires(kindAlreadySeen: Bool) -> Bool { kindAlreadySeen }
}

/// The real-time spawn clock (§21.1's `raiderInterval`).
///
/// Held by the controller and ticked per frame, like `RegenerationQueue` — which
/// also means §23.9's rule about pending work dying with the level falls out of
/// teardown rather than needing to be written down twice.
@MainActor
struct RaiderSchedule {

    private var untilNext: TimeInterval = 0

    /// Restarts the clock for a new level. The first raider is not due
    /// immediately: a wave should open on the chess position, not on a UFO.
    mutating func reset(interval: TimeInterval) {
        untilNext = interval * RaiderRules.openingLead
    }

    /// True when a raider is due. `onScreen` is the cap check, folded in here so
    /// a blocked spawn does not silently reset the clock and skip a turn — it
    /// stays due until there is room.
    mutating func tick(_ dt: TimeInterval, interval: TimeInterval,
                       onScreen: Int, blocked: Bool = false) -> Bool {
        untilNext -= dt
        guard untilNext <= 0 else { return false }
        // Due but capped, or held back by a crowded rear rank: leave the clock
        // expired so it launches the moment the way is clear. Resetting it here
        // would silently skip a raider.
        guard !blocked, onScreen < RaiderRules.maxScoutsOnScreen else { return false }
        untilNext = interval
        return true
    }
}
