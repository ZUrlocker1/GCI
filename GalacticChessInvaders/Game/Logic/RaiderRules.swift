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

    /// Where the scout crosses, held for the whole level so a player who has
    /// seen one crossing knows where the next will be.
    ///
    /// Early levels fly it *over* the board, above every piece — which is where
    /// Space Invaders' mystery ship flies, and what makes it read as a passing
    /// bonus rather than as part of the fleet. §6 asks for rank 4–5; that is
    /// where it drops to once the player has met it, and it is a real
    /// escalation, because down there it is firing into traffic.
    enum Crossing: Equatable {
        case overTheBoard
        case rank(Int)
    }

    static func crossing(for level: Int) -> Crossing {
        level <= aboveBoardThroughLevel ? .overTheBoard : .rank(Bool.random() ? 4 : 5)
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

    /// §6's Galaga precedent: the first scout of a level crosses without
    /// firing, so the player sees the attack pattern before being shot at.
    static func fires(isFirstOfLevel: Bool) -> Bool { !isFirstOfLevel }
}

/// The real-time spawn clock (§21.1's `raiderInterval`).
///
/// Held by the scene and ticked per frame, like `RegenerationQueue` — which
/// also means §23.9's rule about pending work dying with the level falls out of
/// teardown rather than needing to be written down twice.
@MainActor
struct RaiderSchedule {

    private var untilNext: TimeInterval = 0
    /// §6: reset to false at level start, set once the first scout has made its
    /// crossing. Scouts spawned while this is false do not fire.
    private(set) var firstScoutDone = false
    /// The height every scout in this level crosses at.
    private(set) var crossing = RaiderRules.Crossing.overTheBoard

    /// Restarts the clock for a new level. The first raider is not due
    /// immediately: a wave should open on the chess position, not on a UFO.
    mutating func reset(interval: TimeInterval, level: Int) {
        untilNext = interval
        firstScoutDone = false
        crossing = RaiderRules.crossing(for: level)
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

    /// Whether the scout being spawned right now fires, and records that the
    /// warning pass has been used.
    mutating func claimFiringPass() -> Bool {
        defer { firstScoutDone = true }
        return RaiderRules.fires(isFirstOfLevel: !firstScoutDone)
    }
}
