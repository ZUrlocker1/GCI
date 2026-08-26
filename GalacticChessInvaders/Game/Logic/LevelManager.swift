// LevelManager.swift
// Per-level tuning parameters and level progression.
// Pure Swift — the table from design doc §21.1, in one place so balance changes
// never require hunting through gameplay code.

import Foundation

struct LevelParameters {
    let level: Int
    /// Fleet lateral sweep speed in points per second, before the
    /// pieces-remaining multiplier from §21.2 is applied.
    let fleetSpeed: CGFloat
    let blackMovesPerTurn: Int
    /// Invader shots fired per turn, as an inclusive range (Level 1 fires none).
    let shotsPerTurn: ClosedRange<Int>
    /// Straight-down invader projectile speed. Diagonal shots are always 160.
    let projectileSpeed: CGFloat
    /// The chess beat: how long White has before the engine auto-moves.
    let turnTimer: TimeInterval
    let regenSlots: Int
    let raiderInterval: TimeInterval
    /// Level 1 Black plays passively; every level above it plays aggressively.
    let isAggressive: Bool
    /// Half the fleet's lateral sweep, as a fraction of a square. Widens at
    /// Level 6 (see `FleetRules.wideSweepAmplitudeRatio`).
    let sweepAmplitudeRatio: CGFloat
    /// §10.1 King Activated — Level 8 *only*. The black king gains a forcefield
    /// and its own heavy weapon for that wave and reverts afterwards, so the
    /// level has a character of its own rather than permanently buffing the
    /// most important target in the game.
    var kingActivated: Bool { level == 8 }
    /// Diagonal invader fire (§21.3). Level 7 is its own wave, and it comes
    /// back for Blitz — but Levels 8 and 9 get it out of the way again, so
    /// CROSSFIRE stays that level's identity rather than becoming permanent
    /// furniture. Blitz carries it because Blitz is meant to carry everything.
    var diagonalShots: Bool { level == 7 || level >= 10 }
    /// Level 10 "Blitz": the sweep widens and quickens as the wave runs, and
    /// the beat clock is cut to 3s (`FleetRules.blitz*`).
    var blitz: Bool { level >= 10 }
    /// §10.1 Armored Pawns, Level 9 onward: half of every regenerated pawn
    /// arrives immune to laser fire for three chess turns.
    var armoredPawns: Bool { level >= 9 }
    /// How many of the fleet's rear ranks march. Widens at Level 10, so more of
    /// Black's board keeps moving — and keeps being shootable.
    var formationRanks: Int {
        level >= 10 ? FleetRules.deepFormationRanks : FleetRules.formationRanks
    }
}

@MainActor
final class LevelManager {

    /// Timer granted to White when in check, replacing the level's beat (§25.4).
    static let checkExtension: TimeInterval = 8.0

    private(set) var level: Int = 1

    var parameters: LevelParameters { Self.parameters(for: level) }

    /// The last wave. Clearing it wins the run outright rather than rolling into
    /// another generically-harder level — §10.1's "no ceiling" gave the game no
    /// ending at all, and Level 10 (Blitz) is built to be one.
    nonisolated static let finalLevel = 10
    var isFinalLevel: Bool { level >= Self.finalLevel }

    func reset() { level = 1 }

    func advance() { level += 1 }

    /// What the mechanic banner says at the start of a level (§12.11).
    ///
    /// Nil for Level 1 — nothing has escalated yet, and the tutorial wave has
    /// its own first-play hints. Names follow the design doc's own level titles
    /// where it gives them, and describe what actually changes otherwise.
    ///
    /// §12.11 nominally caps the layout at 18/22 characters, but that assumes a
    /// different type size. Measured against the real font at the sizes
    /// `LevelBannerNode` uses, the 420pt rules fit 16 characters of title at
    /// 26pt and 38 of subtitle at 11pt — Press Start 2P advances exactly one
    /// em per character. `LevelAnnouncementTests` holds those measured limits.
    static func announcement(for level: Int) -> (title: String, subtitle: String)? {
        switch max(1, level) {
        case 1:  return nil
        case 2:  return ("FIRE POWER",     "PAWNS FIRE BACK")
        case 3:  return ("DOUBLE TROUBLE", "BLACK MOVES TWICE")
        case 4:  return ("RELENTLESS",     "FASTER, HARDER FIRE")
        case 5:  return ("TRIPLE THREAT",  "BLACK MOVES THREE TIMES")
        case 6:  return ("WIDE ORBIT",     "THE FLEET SWEEPS WIDER")
        // Crossfire comes first: it is the wave that teaches the player to
        // watch the angles, and King Activated is more interesting once they
        // already have to. §10.1 puts them the other way round and gives both
        // names verbatim; only the order moved.
        case 7:  return ("CROSSFIRE",       "BISHOPS FIRE ON THE DIAGONAL")
        case 8:  return ("KING ACTIVATED",  "SHIELDED, AND ARMED")
        case 9:  return ("ARMORED PAWNS",  "REGENERATED PAWNS SHRUG OFF LASERS")
        // The last wave. Named for both the chess variation and the Cray
        // Blitz that won the 1983 world computer championship.
        case 10: return ("BLITZ!",         "3-SECOND CLOCK · THE FLEET RUNS WILD")
        default: return ("LEVEL \(level)",  "NO LET UP")
        }
    }

    /// The §21.1 table. Levels 1–5 are explicit; 6+ scales by formula with the
    /// stated caps and floors.
    static func parameters(for level: Int) -> LevelParameters {
        let clamped = max(1, level)
        switch clamped {
        case 1:
            return LevelParameters(level: 1, fleetSpeed: 40, blackMovesPerTurn: 1,
                                   shotsPerTurn: 0...0, projectileSpeed: 0,
                                   turnTimer: 5, regenSlots: 0, raiderInterval: 20,
                                   isAggressive: false,
                                   sweepAmplitudeRatio: FleetRules.baseSweepAmplitudeRatio)
        case 2:
            return LevelParameters(level: 2, fleetSpeed: 55, blackMovesPerTurn: 1,
                                   shotsPerTurn: 1...2, projectileSpeed: 180,
                                   turnTimer: 5, regenSlots: 0, raiderInterval: 15,
                                   isAggressive: true,
                                   sweepAmplitudeRatio: FleetRules.baseSweepAmplitudeRatio)
        case 3:
            return LevelParameters(level: 3, fleetSpeed: 70, blackMovesPerTurn: 2,
                                   shotsPerTurn: 2...2, projectileSpeed: 180,
                                   turnTimer: 4, regenSlots: 0, raiderInterval: 12,
                                   isAggressive: true,
                                   sweepAmplitudeRatio: FleetRules.baseSweepAmplitudeRatio)
        case 4:
            // 234, not §21.1's 200. Level 4's banner already promises "FASTER,
            // HARDER FIRE" and +11% is imperceptible; +30% over Levels 2-3
            // makes the announcement honest. Later levels scale from here.
            return LevelParameters(level: 4, fleetSpeed: 90, blackMovesPerTurn: 2,
                                   shotsPerTurn: 2...3, projectileSpeed: 234,
                                   turnTimer: 4, regenSlots: 2, raiderInterval: 10,
                                   isAggressive: true,
                                   sweepAmplitudeRatio: FleetRules.baseSweepAmplitudeRatio)
        case 5:
            return LevelParameters(level: 5, fleetSpeed: 110, blackMovesPerTurn: 3,
                                   shotsPerTurn: 3...3, projectileSpeed: 253,
                                   turnTimer: 4, regenSlots: 4, raiderInterval: 8,
                                   isAggressive: true,
                                   sweepAmplitudeRatio: FleetRules.baseSweepAmplitudeRatio)
        default:
            // 6+: fleet +15/level, projectile +10%/level compounding from L5,
            // moves and shots capped at 3, timer floored at 4s (3s at Blitz),
            // raiders at 6s.
            let over = clamped - 5
            let projectile = 253.0 * pow(1.1, Double(over))
            return LevelParameters(
                level: clamped,
                fleetSpeed: 110 + CGFloat(15 * over),
                blackMovesPerTurn: 3,
                shotsPerTurn: 3...3,
                projectileSpeed: CGFloat(projectile),
                // Blitz cuts the clock to 3s. There is barely time to think
                // about chess, which is the intent: the last wave is a
                // shoot-em-up with a chess board still underneath it.
                turnTimer: clamped >= 10 ? 3 : 4,
                regenSlots: 4 + over,
                raiderInterval: max(6, 8 - TimeInterval(over)),
                isAggressive: true,
                // Wide from Level 6. Blitz starts here too and grows from it
                // lap by lap, so this stays the *opening* width at Level 10.
                sweepAmplitudeRatio: FleetRules.wideSweepAmplitudeRatio
            )
        }
    }
}
