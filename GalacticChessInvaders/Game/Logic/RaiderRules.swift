// RaiderRules.swift
// The raiders' decisions (§6, §21.1), as pure rules and a pure timer.
//
// Raiders run on a real-time clock, not on the chess beat. That is the point of
// them: everything else in GCI — the fleet's sweep, its descent, its fire, the
// regeneration — is paced off the turn, so the whole board pulses together and
// a player learns to think in beats. A raider ignores that rhythm entirely, and
// is the only thing on screen that does.

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
    /// construction. The cost of slowing it is frequency: a crossing is 5.6s,
    /// which is 28% of Level 1's interval but 94% of Level 10's, so by Blitz
    /// there is nearly always one on screen. Catchable is worth more than rare.
    static let scoutSpeed: CGFloat = 220
    static let scoutHP = 1
    /// §9's table.
    static let scoutPoints = 100
    /// §6: at most two raiders on screen; a third waits.
    static let maxOnScreen = 2

    /// The most of the time a raider may be on screen at all.
    ///
    /// §21.1's interval tightens to 6s, and a crossing takes 5.6s — which would
    /// have meant a scout up 94% of the time from Level 7, i.e. permanently.
    /// A raider that is always there stops being an event and becomes scenery,
    /// the same failure the screen shake had.
    static let maxScreenShare = 0.6

    /// The interval actually used: the level's, or whatever the share cap
    /// requires, whichever is longer.
    ///
    /// Derived from the crossing rather than written into the table, so
    /// changing the scout's speed cannot silently break the cap.
    static func interval(forLevel levelInterval: TimeInterval,
                         crossing: TimeInterval) -> TimeInterval {
        max(levelInterval, crossing / maxScreenShare)
    }

    /// How long one crossing takes, entry to exit, including the off-screen
    /// margin at both ends.
    static func crossingDuration(sceneWidth: CGFloat, scoutWidth: CGFloat) -> TimeInterval {
        TimeInterval((sceneWidth + scoutWidth * 2) / scoutSpeed)
    }

    /// Where the scout crosses, held for the whole level so a player who has
    /// seen one crossing knows where the next will be.
    ///
    /// Three patterns, each a real escalation on the last:
    ///
    /// * **over the board** (Levels 1–3) — above every piece, which is where
    ///   Space Invaders' mystery ship flies and what makes it read as a passing
    ///   bonus rather than as part of the fleet;
    /// * **piece height** (4–6) — §6's rank 4–5, where it is firing into
    ///   traffic;
    /// * **weaving** (7+) — the same crossing with the height no longer
    ///   constant, so aiming stops being a purely horizontal problem.
    ///
    /// Each earns its own warning pass the first time it appears in a run.
    enum Crossing: Equatable {
        case overTheBoard
        case rank(Int)
        /// Same crossing, but weaving up and down through it.
        case weaving(Int)

        /// What the player has to *learn*, as opposed to where exactly this
        /// one flies. Rank 4 and rank 5 are the same problem, so seeing one
        /// counts as having seen the other.
        var pattern: Pattern {
            switch self {
            case .overTheBoard: return .overTheBoard
            case .rank:         return .atPieceHeight
            case .weaving:      return .weaving
            }
        }

        /// How far it strays vertically from its line, in points.
        var weaveAmplitude: CGFloat {
            switch self {
            // Not zero even when flying straight: a few points of drift keeps
            // the disc hovering rather than sliding along a rail.
            case .overTheBoard, .rank: return 4
            case .weaving:             return RaiderRules.weaveAmplitude
            }
        }

        /// The rank it is centred on, if any.
        var rank: Int? {
            switch self {
            case .overTheBoard:        return nil
            case .rank(let r):         return r
            case .weaving(let r):      return r
            }
        }
    }

    enum Pattern: Hashable { case overTheBoard, atPieceHeight, weaving }

    /// Just under a square either side of the line, so the weave costs the
    /// player a vertical guess as well as a horizontal one without ever taking
    /// the scout somewhere it could not have been.
    static let weaveAmplitude: CGFloat = 55
    /// Half a cycle. About 2.7 full waves across a crossing — enough to read
    /// as a rhythm rather than as a wobble, slow enough to aim against.
    static let weaveHalfPeriod: TimeInterval = 0.9
    /// From here the scout stops flying in a straight line.
    static let weavesFromLevel = 7

    static func crossing(for level: Int) -> Crossing {
        let rank = Bool.random() ? 4 : 5
        if level <= aboveBoardThroughLevel { return .overTheBoard }
        return level >= weavesFromLevel ? .weaving(rank) : .rank(rank)
    }

    static let aboveBoardThroughLevel = 3

    /// Early levels hold the scout back until the fleet's rear rank has
    /// thinned.
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

    /// §6's Galaga precedent, tied to the *pattern* rather than to the level.
    ///
    /// §6 gives a free pass to the first scout of every level. That spends its
    /// rationale — "the player sees the attack pattern before being shot at" —
    /// the first time, and then keeps handing over a harmless raider forever:
    /// by Level 8 the player has seen thirty of them and still gets one a wave.
    ///
    /// A pass is now owed only while a pattern is genuinely new, which happens
    /// twice in a run: the first scout of the game, and the first one after it
    /// drops to piece height at Level 4, where it really is a different problem.
    static func fires(patternAlreadySeen: Bool) -> Bool { patternAlreadySeen }
}

/// The real-time spawn clock (§21.1's `raiderInterval`).
///
/// Held by the scene and ticked per frame, like `RegenerationQueue` — which
/// also means §23.9's rule about pending work dying with the level falls out of
/// teardown rather than needing to be written down twice.
@MainActor
struct RaiderSchedule {

    private var untilNext: TimeInterval = 0
    /// Whether this level's crossing pattern still owes the player a look at it.
    private(set) var owesWarningPass = false
    /// The height every scout in this level crosses at.
    private(set) var crossing = RaiderRules.Crossing.overTheBoard

    /// Restarts the clock for a new level. The first raider is not due
    /// immediately: a wave should open on the chess position, not on a UFO.
    mutating func reset(interval: TimeInterval, level: Int,
                        patternsSeen: Set<RaiderRules.Pattern> = []) {
        untilNext = interval
        crossing = RaiderRules.crossing(for: level)
        owesWarningPass = !patternsSeen.contains(crossing.pattern)
    }

    /// True when a raider is due. `onScreen` is the cap check, folded in here
    /// so a blocked spawn does not silently reset the clock and skip a turn —
    /// it stays due until there is room.
    mutating func tick(_ dt: TimeInterval, interval: TimeInterval,
                       onScreen: Int, blocked: Bool = false) -> Bool {
        untilNext -= dt
        guard untilNext <= 0 else { return false }
        // Due but capped, or held back by a crowded rear rank: leave the clock
        // expired so it launches the moment the way is clear. Resetting it here
        // would silently skip a raider.
        guard !blocked, onScreen < RaiderRules.maxOnScreen else { return false }
        untilNext = interval
        return true
    }

    /// Whether the scout being spawned right now fires, spending the warning
    /// pass if one was owed.
    mutating func claimFiringPass() -> Bool {
        let fires = RaiderRules.fires(patternAlreadySeen: !owesWarningPass)
        owesWarningPass = false
        return fires
    }
}
