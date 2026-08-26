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
    /// partway through every level. Relative, "the back three ranks of the
    /// fleet" stays true however far it has descended.
    static func staysInFormation(afterMovingTo square: String,
                                 formationRearRank: Int,
                                 ranks: Int = formationRanks) -> Bool {
        guard let rank = Int(String(square.last ?? "0")) else { return false }
        // The band runs from the rear rank forward by `ranks`.
        return rank > formationRearRank - ranks && rank <= formationRearRank
    }

    // MARK: - King Activated (§10.1, Level 7+)

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
    static let kingShotDamage = 2

    /// How often the activated king fires, in beats. It shoots on its own
    /// cadence rather than as part of the volley, so it reads as a separate
    /// threat rather than one more pawn.
    static let kingShotInterval = 2

    // MARK: - Diagonal fire (§21.3, Level 8+)

    /// §21.3 fixes diagonal shots at 160 px/s along their path, whatever the
    /// level's straight-down speed is. They are a different threat, not a
    /// faster one — the danger is the angle.
    static let diagonalShotSpeed: CGFloat = 160

    /// Share of a volley that comes in angled once diagonals arrive. A mix is
    /// the point: all-diagonal is just a different fixed pattern to stand
    /// outside of, whereas mixed fire means no column is reliably safe.
    static let diagonalShotShare = 0.4

    /// Which way a diagonal shot leans: -1 left, +1 right, 0 for straight down.
    /// Aimed away from the board edge when the shooter is near one, so a
    /// diagonal from the a-file does not immediately fly out of play.
    static func diagonalLean(fromFile file: Int, isDiagonal: Bool) -> Int {
        guard isDiagonal else { return 0 }
        if file <= 1 { return 1 }
        if file >= 6 { return -1 }
        return Bool.random() ? 1 : -1
    }

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

    /// Level 10's sweep: 1.75 squares end to end, not 2.0.
    ///
    /// 2.0 would put the amplitude at exactly one file, which is the single
    /// worst width available — a piece at the extreme would sit dead centre on
    /// its neighbour's square, reading as a confident answer to the wrong
    /// question rather than as something in between. 0.875 of a file stays
    /// visibly off-grid.
    static let widestSweepAmplitudeRatio: CGFloat = 0.875

    static func sweepAmplitude(squareSize: CGFloat, ratio: CGFloat) -> CGFloat {
        squareSize * ratio
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
