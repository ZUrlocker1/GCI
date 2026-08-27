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

    /// Points per second across the board. Not specified by the doc, and it has
    /// to be derived from the interval rather than picked: at 175 px/s a
    /// crossing took 7.1s against a 6s interval from Level 7, so a scout was on
    /// screen 118% of the time — permanently, with the two-raider cap saturated
    /// and the interval meaning nothing. At 300 it is 4.1s, which is 21% of
    /// Level 1's interval and 69% of Level 10's: frequent late on, never
    /// constant.
    ///
    /// It is also fast enough to need leading. A laser takes about half a
    /// second to reach rank 4, in which the scout travels most of its own
    /// length — which is what makes a mystery ship worth 100 points.
    static let scoutSpeed: CGFloat = 300
    static let scoutHP = 1
    /// §9's table.
    static let scoutPoints = 100
    /// §6: at most two raiders on screen; a third waits.
    static let maxOnScreen = 2

    /// §6: "mid-board height (rank 4–5)".
    ///
    /// Picked once per level and held, so a player who has seen one crossing
    /// knows where the next will be. Varying it per raider would make the
    /// first sighting worth nothing.
    static func crossingRank() -> Int { Bool.random() ? 4 : 5 }

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
    private(set) var crossingRank = RaiderRules.crossingRank()

    /// Restarts the clock for a new level. The first raider is not due
    /// immediately: a wave should open on the chess position, not on a UFO.
    mutating func reset(interval: TimeInterval) {
        untilNext = interval
        firstScoutDone = false
        crossingRank = RaiderRules.crossingRank()
    }

    /// True when a raider is due. `onScreen` is the cap check, folded in here
    /// so a blocked spawn does not silently reset the clock and skip a turn —
    /// it stays due until there is room.
    mutating func tick(_ dt: TimeInterval, interval: TimeInterval,
                       onScreen: Int) -> Bool {
        untilNext -= dt
        guard untilNext <= 0 else { return false }
        // Due but capped: leave the clock expired so it launches the moment
        // there is room. Resetting it here would silently skip a raider.
        guard onScreen < RaiderRules.maxOnScreen else { return false }
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
