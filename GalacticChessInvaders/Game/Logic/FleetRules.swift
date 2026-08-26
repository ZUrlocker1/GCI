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
    /// ambiguity `sweepAmplitudeRatio` exists to prevent on the other axis —
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
        return DescentSchedule(sweepBeats: Swift.max(1, grace / 2),
                               graceBeats: grace,
                               beatsPerHalfDrop: Swift.max(2, 4 - (level - 1) / 2))
    }

    // MARK: - Sweep width

    /// How far the fleet may drift from true, as a fraction of a square.
    ///
    /// Must stay below 0.5: at exactly half a square a piece sits on the boundary
    /// between two files and its square becomes genuinely ambiguous.
    static let sweepAmplitudeRatio: CGFloat = 0.4

    static func sweepAmplitude(squareSize: CGFloat) -> CGFloat {
        squareSize * sweepAmplitudeRatio
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
    static let sweepSpeedScale: CGFloat = 0.7

    /// Points per second for a level, after thinning is taken into account.
    static func sweepSpeed(level: LevelParameters, piecesRemaining: Int) -> CGFloat {
        level.fleetSpeed * speedMultiplier(piecesRemaining: piecesRemaining) * sweepSpeedScale
    }
}
