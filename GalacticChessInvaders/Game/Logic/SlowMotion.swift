import Foundation

/// The Nuke's slow motion (§13.2), as a value rather than a pair of flags on
/// the scene.
///
/// Extracted from `GameScene` in October 2026. It qualified because it is the
/// rare part of that file that genuinely owns its state: two stored properties,
/// a tuning table and a curve, with nothing else reading them. Everything that
/// touches a *node* — `bloomNode.speed`, the starfield, the music rate — stayed
/// behind in the scene, because that is the scene's to own. What moved is the
/// arithmetic, which is now checkable without a running scene.
struct SlowMotion {

    /// Long enough for the ring to cross the board and the fragments to land
    /// inside it; short enough that it is a moment rather than an interlude.
    static let duration: TimeInterval = 1.3

    /// Roughly a third speed. Deeper than this and the ship stops answering the
    /// keys in a way that reads as a hang rather than as an effect.
    static let floor: Double = 0.3

    /// The share of the window spent at full slow before the ramp back begins.
    static let hold = 0.45

    /// How far the music slows under the Nuke and Time Freeze.
    ///
    /// 0.9, not §13.2's 0.5–0.7. Those were tuned against the single ambient
    /// track the game shipped with — an 88 BPM Kosmic pad barely registers a
    /// time-stretch. The Motorik Arcade soundtrack is built on a steady kick,
    /// and a 140 BPM track dropping to 98 does not read as slow motion; it
    /// reads as the machine struggling, which is a bad impression for this game
    /// in particular. One depth for both effects: this shallow there is no
    /// telling 0.9 from 0.85, and the blue wash, the ring and the world at 0.3x
    /// are what tell them apart.
    static let musicRate: Float = 0.9

    /// How long the blast's slow motion has left, in real seconds.
    private(set) var remaining: TimeInterval = 0

    /// The scale the world was last actually set to, which is what makes
    /// `advance` able to say whether anything needs touching.
    private(set) var applied: Double = 1

    /// The curve, as a pure function of how far into the window we are, so the
    /// shape can be checked without a running scene.
    static func scale(elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return floor }
        guard elapsed < duration else { return 1 }
        let holdFor = duration * hold
        guard elapsed > holdFor else { return floor }
        let progress = (elapsed - holdFor) / (duration - holdFor)
        // Smoothstep, not `progress * progress`.
        //
        // A squared ramp is an ease-*in*, which puts all of the acceleration at
        // the end: the scale was still climbing at 1.93 per second on the last
        // frame of the window and then went flat, a jerk discontinuity right at
        // the boundary. Held flat for 585ms and then whipped back, the blast
        // read as a drift that snapped rather than as slow motion — and the
        // shockwave ring, which runs on this clock, visibly sped up as it
        // expanded, which is backwards for a shockwave.
        //
        // Smoothstep leaves the floor and arrives at 1 with zero slope at both
        // ends, so nothing changes gear on a single frame.
        return floor + (1 - floor) * progress * progress * (3 - 2 * progress)
    }

    /// The clock everything else runs on: 1 normally, less during a blast.
    ///
    /// Holds at the floor, then eases back to speed at both ends. Coming *out*
    /// of slow motion is the part that sells it, and what sells it is that the
    /// recovery is never visible as an event: the moment the world audibly
    /// changes gear is the moment it reads as a stall being recovered from
    /// rather than as an effect ending.
    var scale: Double {
        guard remaining > 0 else { return 1 }
        return Self.scale(elapsed: Self.duration - remaining)
    }

    /// Drops the world into slow motion. Called by the Nuke, and deliberately
    /// not by anything else: it is what makes that one power-up a set piece.
    mutating func begin() { remaining = Self.duration }

    /// Spends real time. Separate from `advance` so the update loop reads in
    /// the order it always did: age the window, then act on where it landed.
    mutating func tick(realDt: TimeInterval) {
        if remaining > 0 { remaining = max(0, remaining - realDt) }
    }

    /// The new scale, or nil when it has not moved enough to be worth touching
    /// the nodes for. The 0.001 band is what stops a near-static value from
    /// reassigning `speed` on every frame of the hold.
    mutating func advance() -> Double? {
        let next = scale
        guard abs(next - applied) > 0.001 else { return nil }
        applied = next
        return next
    }

    /// Returns whether anything was actually running, so the caller can skip
    /// the node work when there was nothing to undo.
    mutating func cancel() -> Bool {
        guard remaining > 0 || applied != 1 else { return false }
        remaining = 0
        applied = 1
        return true
    }

    /// Whether *this* is slowing time. The scene ORs it with Time Freeze before
    /// deciding the music rate.
    var isSlowing: Bool { applied < 0.999 }
}
