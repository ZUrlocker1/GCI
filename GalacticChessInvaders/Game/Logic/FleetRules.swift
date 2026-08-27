// FleetRules.swift
// Pure rules for the black fleet's Space Invaders movement (design doc §23.6).
// No SpriteKit — the controller owns the animation, this owns the decisions.
//
// The central idea is that visual position and logical chess position are
// deliberately separated — but only ever by less than one square. The fleet
// shuffles and drops on screen while the chess engine sees whole-rank descents:
//
//   descent beat 1 → half-drop, board untouched
//   descent beat 2 → half-drop, and *now* every black piece descends one rank
//
// Two constraints keep that separation readable, and both were learned the hard
// way in playtest:
//
//  * The lateral sweep never exceeds ±0.4 of a square, so every piece stays over
//    its own file. Drift past that and the player can no longer look at a piece
//    and say which square it is on, which makes the chess half unplayable.
//  * Descent is paced by the chess beat, not by wall bounces. Tying it to bounces
//    couples difficulty to sweep width: narrowing the shuffle for readability
//    would silently make the fleet fall faster.

import Foundation

enum FleetRules {

    // MARK: - Descent

    /// What a chess beat does to the fleet's height.
    enum DescentStep: Equatable {
        case none
        /// Visual only — the board is untouched (§5.1).
        case halfDrop
        /// The second half-drop of the pair: every black piece descends a rank.
        case fullRank
    }

    /// Paces descent on chess beats rather than wall bounces, so sweep width and
    /// speed are free to be tuned for looks without changing difficulty.
    struct DescentSchedule {
        /// Beats the fleet holds completely still at the start of a level. The
        /// opening position should be legible as a chess position first; the
        /// arcade layer arrives once the player has had a look at it.
        let sweepBeats: Int
        /// Beats of quiet before anything descends. Later than `sweepBeats`, so
        /// the fleet is seen moving before it is seen taking ground.
        let graceBeats: Int
        /// Beats between half-drops. Two half-drops make a rank, so a rank costs
        /// twice this.
        let beatsPerHalfDrop: Int

        private var beats = 0
        private var halfDrops = 0

        init(sweepBeats: Int = 0, graceBeats: Int, beatsPerHalfDrop: Int) {
            self.sweepBeats = sweepBeats
            self.graceBeats = graceBeats
            self.beatsPerHalfDrop = max(1, beatsPerHalfDrop)
        }

        /// False while the fleet is still holding its opening position.
        var isSweeping: Bool { beats >= sweepBeats }

        /// Call once per resolved chess beat.
        mutating func registerBeat() -> DescentStep {
            beats += 1
            guard beats >= graceBeats,
                  (beats - graceBeats) % beatsPerHalfDrop == 0 else { return .none }
            halfDrops += 1
            return halfDrops.isMultiple(of: 2) ? .fullRank : .halfDrop
        }

        mutating func reset() { beats = 0; halfDrops = 0 }
    }

    /// Would the *next* beat descend? Used to telegraph the drop a beat ahead,
    /// so it arrives as an expected event rather than an unannounced lurch.
    /// In Space Invaders you see the drop coming because the fleet nears a wall;
    /// ours is paced by an invisible counter, so it has to be announced.
    static func descendsAfter(_ schedule: DescentSchedule) -> Bool {
        var lookahead = schedule
        return lookahead.registerBeat() != .none
    }

    /// Set false to remove the telegraph entirely — one flag, one call site.
    static let telegraphsDescent = true

    // MARK: - Drop shape

    /// The two half-drops are deliberately uneven. An even 0.5/0.5 split parks
    /// the whole fleet on a rank boundary for several beats, which is the exact
    /// ambiguity `baseSweepAmplitudeRatio` exists to prevent on the other axis —
    /// a piece halfway between two ranks belongs to neither. At 0.3 it reads as
    /// a piece leaning down off its own rank, which is unambiguous.
    static let firstDropRatio: CGFloat = 0.3
    static var secondDropRatio: CGFloat { 1 - firstDropRatio }

    // MARK: - Sweep shape

    /// The sweep is stepped, not continuous. Quantised motion reads as a
    /// formation marching on a rhythm; a smooth slide reads as drifting, and
    /// leaves a piece at any offset rather than one of a few known ones.
    static let sweepSteps = 8

    /// Descent pacing for a level. Later levels close the distance faster, but
    /// never so fast that a rank costs fewer than four beats.
    static func descentSchedule(for level: Int) -> DescentSchedule {
        let grace = Swift.max(2, 7 - level)
        // sweepBeats 0: the fleet sweeps immediately. It used to hold still for
        // the first few beats, which read nicely but made the opening
        // unplayable — a stationary fleet sits squarely behind White's own
        // pawns, and since a laser is consumed by the first thing it touches
        // there is no lane to any black piece at all. The sweep is what shifts
        // them off-centre far enough to be reachable past a pawn's edge.
        return DescentSchedule(sweepBeats: 0,
                               graceBeats: grace,
                               beatsPerHalfDrop: Swift.max(2, 4 - (level - 1) / 2))
    }

    // MARK: - Formation membership after a chess move

    /// The rearmost rank a black piece can move to and still march with the
    /// fleet. Ranks 7-8 are Black's own two starting rows.
    /// How many of the formation's own rearmost ranks keep a moving piece in
    /// step with it. Two by default; three from Level 10 (`deepFormationRanks`).
    static let formationRanks = 2
    static let deepFormationRanks = 3

    /// Does a black piece that just played a chess move stay in the formation?
    ///
    /// A piece that leaves the fleet stops sweeping, and a stationary black
    /// piece is usually parked directly behind one of White's own pawns — which
    /// makes it very hard to shoot, since a laser is consumed by the first thing
    /// it touches. Shuffling around the formation's own rear ranks therefore
    /// keeps a piece marching; genuinely advancing out in front detaches it.
    ///
    /// Measured relative to `formationRearRank` — the rearmost rank the fleet
    /// still occupies — not to absolute ranks 7 and 8. An absolute rule expired
    /// silently: after two rank descents nothing could satisfy "rank >= 7" any
    /// more, so the whole mechanic decayed back to "any chess move detaches"
    /// partway through every level.
    ///
    /// Only the *front* edge is bounded. There is no back edge, because there
    /// is nothing behind the fleet to be separated from: once the formation has
    /// descended, a king retreating to rank 8 is still at the back, and holding
    /// it to "within N of the rear rank" left it stranded off-grid on an empty
    /// rank while everything else marched — observed in play, on exactly the
    /// piece it matters most for. So the marching band is the fleet's rearmost
    /// `ranks` ranks *and everything behind them*, which means the formation
    /// can be deeper than `ranks` and should be.
    static func staysInFormation(afterMovingTo square: String,
                                 formationRearRank: Int,
                                 ranks: Int = formationRanks) -> Bool {
        guard let rank = Int(String(square.last ?? "0")) else { return false }
        return rank > formationRearRank - ranks
    }

    /// Black's back rank, where every formation starts.
    static let startingRearRank = 8

    // MARK: - King Activated (§10.1, Level 9)

    /// The forcefield makes the black king take 50% more hits to destroy.
    ///
    /// Implemented as bonus HP rather than reduced damage, because the laser
    /// deals a flat 2 and any per-hit division lands on fractions. 16 HP is 8
    /// hits; 24 is 12.
    static let kingForcefieldMultiplier = 1.5

    static func forcefieldHP(baseMaxHP: Int) -> Int {
        Int((Double(baseMaxHP) * kingForcefieldMultiplier).rounded())
    }

    /// The king's own weapon: faster and heavier than ordinary fleet fire.
    static let kingShotSpeedMultiplier: CGFloat = 1.6

    /// An angled king round travels 30% faster again.
    ///
    /// Only the angled one. A lean makes the path to the player longer — at 31°
    /// off vertical it is 17% further — so at a shared speed the angled shot
    /// simply arrives later and reads as the weaker of the two. This puts them
    /// back on equal footing and then some.
    static let kingAngledShotBoost: CGFloat = 1.3
    static let kingShotDamage = 2

    /// How often the activated king fires, in beats. It shoots on its own
    /// cadence rather than as part of the volley, so it reads as a separate
    /// threat rather than one more pawn.
    static let kingShotInterval = 2

    // MARK: - Diagonal fire (§21.3, Level 7 and Blitz)

    /// §21.3 fixes diagonal shots at 160 px/s along their path, whatever the
    /// level's straight-down speed is. They are a different threat, not a
    /// faster one — the danger is the angle.
    static let diagonalShotSpeed: CGFloat = 160

    /// Share of a volley that comes in angled once diagonals arrive. A mix is
    /// the point: all-diagonal is just a different fixed pattern to stand
    /// outside of, whereas mixed fire means no column is reliably safe.
    /// Crossfire is the bishops' cadence, not a dice roll on somebody else's
    /// shot: every second beat, every live black bishop fires at once. Two
    /// crossing diagonals in the same instant is what the level is named for,
    /// and a piece with its own weapon reads as a character where a 40% chance
    /// of an angled pawn shot read as noise.
    static let bishopShotInterval = 2

    // MARK: - Per-rank sweep phase (Blitz)

    /// How far each rank lags the rank behind it, in radians of the sweep
    /// cycle. **This one number is the whole feature**, and it is a dial rather
    /// than a switch:
    ///
    /// * `0` — every rank in step. Identical to the fleet's behaviour before
    ///   per-rank sweeping existed, so this is also the way to turn it off.
    /// * `.pi / 4` — a wave travelling down through the formation. Adjacent
    ///   ranks stay within about half a square of each other, so files still
    ///   read.
    /// * `.pi` — adjacent ranks exactly opposed, counter-marching. The most
    ///   dramatic and the least legible: relative shear between neighbouring
    ///   ranks is *twice* the amplitude, which at Blitz's widening reaches two
    ///   and a half squares. Worth trying in motion; expect the board to stop
    ///   reading as a grid.
    ///
    /// Blitz only. Everywhere else the fleet moves as one body, which is what
    /// makes it a fleet.
    static let rankPhaseLag: CGFloat = .pi / 4

    /// How long a gunner glows before its round leaves (§ the charge-up
    /// telegraph). Long enough to see and act on, short enough that it is a
    /// warning rather than a countdown.
    static let chargeUpDelay: TimeInterval = 0.35

    /// How steeply a bishop's round leans: files travelled per rank descended.
    /// 0 is straight down, 1.0 is a true 45° diagonal, and the sign is the
    /// direction.
    ///
    /// A fixed 45° does not work from the back ranks. A bishop on rank 8 firing
    /// at 45° covers seven files before it reaches White — it leaves the board
    /// entirely and lands nowhere near anything the player owns, so the level's
    /// threat arrives as a light show. The angle is instead taken from where
    /// White actually is, then clamped: shallower than `minDiagonalSlope` and it
    /// reads as a straight shot that missed, steeper than `maxDiagonalSlope`
    /// and it is back to flying off the side.
    static let minDiagonalSlope: CGFloat = 0.3    // ~17° off vertical
    static let maxDiagonalSlope: CGFloat = 1.0    // 45°

    /// Board coordinates throughout — files and ranks, not points. The squares
    /// are square, so the slope is the same number on screen.
    /// `targetFile`/`targetRank` name a white piece to lean toward; a target on
    /// or above the shooter's own rank cannot be aimed at and leans at random.
    static func diagonalSlope(fromFile file: Int, rank: Int,
                              towardFile targetFile: Int, rank targetRank: Int,
                              minSlope: CGFloat = minDiagonalSlope,
                              maxSlope: CGFloat = maxDiagonalSlope) -> CGFloat
    {
        let drop = rank - targetRank
        guard drop > 0 else { return Bool.random() ? maxSlope : -maxSlope }
        let wanted = CGFloat(targetFile - file) / CGFloat(drop)
        // A target directly below cannot say which way to lean; away from the
        // nearer edge keeps the round over the board for longer.
        guard wanted != 0 else { return file < 4 ? minSlope : -minSlope }
        let sign: CGFloat = wanted < 0 ? -1 : 1
        return sign * min(maxSlope, max(minSlope, abs(wanted)))
    }

    // MARK: - The activated king's weapon

    /// How often the king's heavy round leans rather than firing straight down.
    ///
    /// The king moves one square in *any* direction, so a weapon that only ever
    /// fires straight ahead reads as the wrong piece's. Not every shot, though:
    /// straight-down has to stay the king's default or the angled ones stop
    /// being a variation on anything.
    static let kingShotAngleShare = 0.45

    /// A shallower band than the bishops'. Crossfire is *about* the diagonal, so
    /// a bishop commits to one; the king only inflects, and a near-45° round
    /// from the king would read as a bishop's shot fired by the wrong piece.
    static let kingMinSlope: CGFloat = 0.15   // ~9° off vertical
    static let kingMaxSlope: CGFloat = 0.6    // ~31°

    // MARK: - Sweep width

    /// How far the fleet may drift from true, as a fraction of a square.
    ///
    /// Must stay below 0.5: at exactly half a square a piece sits on the boundary
    /// between two files and its square becomes genuinely ambiguous.
    /// 0.45 -> a 0.9-square total sweep. Widened from 0.35 to open bigger
    /// firing lanes past White's own pawns. Still under the 0.5 ceiling above,
    /// so a piece's centre never leaves its own file and the square it occupies
    /// stays unambiguous.
    static let baseSweepAmplitudeRatio: CGFloat = 0.45

    /// The wide sweep from Level 6 (§ level table): 1.5 squares end to end.
    ///
    /// This deliberately breaks the sub-half-square rule above. At 0.75 a
    /// piece's centre crosses into the neighbouring file, so its square really
    /// does become ambiguous — that is the cost, taken knowingly. By Level 6
    /// the player has had five waves to learn the board, the fleet is thinned,
    /// and the point of the level is that the game stops respecting its own
    /// limits. Levels 1-5 keep the readable width.
    static let wideSweepAmplitudeRatio: CGFloat = 0.75

    static func sweepAmplitude(squareSize: CGFloat, ratio: CGFloat) -> CGFloat {
        squareSize * ratio
    }

    // MARK: - Blitz (Level 10)

    /// Level 10 does not hold a width at all: the sweep starts where Level 6
    /// left it (1.5 squares) and grows a tenth of a square every fourth time
    /// the fleet reaches the left edge, with the march speeding up every sixth.
    /// Nothing else in the game escalates *within* a level, which is the point
    /// — the last wave stops being a chess position under pressure and becomes
    /// a shooting gallery that is coming apart.
    ///
    /// Counted on left-edge arrivals rather than on time so the escalation is
    /// tied to something the player can see happening. It is self-damping:
    /// every widening makes the next lap longer, so arrivals come further apart
    /// as the sweep grows.
    static let blitzWidenEveryArrivals = 4
    static let blitzSpeedUpEveryArrivals = 6
    /// A tenth of a square *end to end*, so half that in amplitude.
    static let blitzWidenStepRatio: CGFloat = 0.05
    /// 6% per step, compounding. Small enough that no single step is the moment
    /// the level got unfair, and the sweep is lengthening at the same time.
    static let blitzSpeedStep: CGFloat = 0.06

    /// Ceilings are safety limits, not design ones.
    ///
    /// The board is 512pt centred in a 960pt scene, so there are 224pt of margin
    /// either side. At ratio 2.75 the amplitude is 176pt and the outermost piece
    /// still has ~16pt of screen left; measured, not guessed — see
    /// `testBlitzCeilingsKeepTheFleetOnScreen`. Reaching it takes 160 left-edge
    /// arrivals, about five minutes in one wave, so within a real game the
    /// widening reads as unbounded. `blitzMaxSpeedScale` is the same kind of
    /// guard: past ~1.75x on top of the thinning bonus the march stops reading
    /// as steps at all.
    static let blitzMaxAmplitudeRatio: CGFloat = 2.75
    static let blitzMaxSpeedScale: CGFloat = 1.75

    static func blitzAmplitudeRatio(leftEdgeArrivals: Int) -> CGFloat {
        let steps = max(0, leftEdgeArrivals) / blitzWidenEveryArrivals
        return min(blitzMaxAmplitudeRatio,
                   wideSweepAmplitudeRatio + blitzWidenStepRatio * CGFloat(steps))
    }

    static func blitzSpeedScale(leftEdgeArrivals: Int) -> CGFloat {
        let steps = max(0, leftEdgeArrivals) / blitzSpeedUpEveryArrivals
        return min(blitzMaxSpeedScale,
                   pow(1 + blitzSpeedStep, CGFloat(steps)))
    }

    /// The square one rank toward White, or nil if already on rank 1.
    /// A black piece that cannot descend has reached the bottom, which is a lose
    /// condition (§4) — wired up in Phase 3.2.
    static func descended(_ square: String) -> String? {
        let chars = Array(square)
        guard chars.count == 2,
              let rank = chars[1].wholeNumberValue,
              rank > 1 else { return nil }
        return "\(chars[0])\(rank - 1)"
    }

    /// Descent order matters: a piece must vacate its square before the piece
    /// above it arrives, or the upper one overwrites the lower. Lowest rank first.
    static func descentOrder(_ squares: [String]) -> [String] {
        squares.sorted { lhs, rhs in
            (Array(lhs)[1].wholeNumberValue ?? 0) < (Array(rhs)[1].wholeNumberValue ?? 0)
        }
    }

    // MARK: - Speed

    /// §21.2 — the fleet accelerates as it is thinned out, classic Invaders style.
    static func speedMultiplier(piecesRemaining: Int) -> CGFloat {
        switch piecesRemaining {
        case ...1:   return 2.5
        case 2...4:  return 2.0
        case 5...8:  return 1.5
        case 9...12: return 1.2
        default:     return 1.0
        }
    }

    /// Applied on top of the §21.2 table. The spec's speeds were written for a
    /// fleet that crossed the whole board; the sweep is a sub-file march now, and
    /// at full speed it read as twitchy rather than deliberate. Kept as a scale
    /// rather than folded into the per-level numbers so the table still matches
    /// the document it came from.
    static let sweepSpeedScale: CGFloat = 0.63

    /// Points per second for a level, after thinning is taken into account.
    static func sweepSpeed(level: LevelParameters, piecesRemaining: Int) -> CGFloat {
        level.fleetSpeed * speedMultiplier(piecesRemaining: piecesRemaining) * sweepSpeedScale
    }
}
