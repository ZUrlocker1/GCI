// TurnTimer.swift
// The chess beat countdown. Pure logic — no SpriteKit, no timers, no callbacks:
// the caller ticks it from the game loop and reacts to the returned expiry.
//
// Chess turns are paced by this fixed beat, never by fleet sweep completion
// (design doc §3). White may move at any point during the beat; if the beat
// expires first, the engine auto-moves White. Black then plays its move or moves
// for that beat, and the next beat begins.

import Foundation

@MainActor
final class TurnTimer {

    /// Seconds left in the current beat.
    private(set) var remaining: TimeInterval = 0
    /// The beat length this cycle started with — 8s when White was in check.
    private(set) var duration: TimeInterval = 0
    private(set) var isRunning = false
    /// True when this beat was extended because White is in check.
    private(set) var isExtended = false

    /// The last two seconds, when the HUD ticks and pulses (§19).
    static let warningThreshold: TimeInterval = 2.0

    var isWarning: Bool { isRunning && remaining <= Self.warningThreshold }

    /// Progress remaining, 1.0 at the start of the beat down to 0.0 at expiry.
    var fraction: Double {
        guard duration > 0 else { return 0 }
        return max(0, min(1, remaining / duration))
    }

    /// Whole seconds shown on the countdown, rounded up so "1" means "under a second left".
    var displaySeconds: Int { max(0, Int(remaining.rounded(.up))) }

    // MARK: - Control

    /// Begins a beat. Pass `inCheck` to grant the 8-second extension (§25.4);
    /// check state is evaluated once, after all of Black's moves have completed.
    /// `override` shortens the beat for the hidden test mode, so the rest of the
    /// beat machinery — expiry, the countdown, the self-healing invariant — keeps
    /// working unchanged instead of needing a parallel path.
    func start(level: LevelParameters, inCheck: Bool, override: TimeInterval? = nil) {
        isExtended = inCheck && override == nil
        duration = override ?? (inCheck ? LevelManager.checkExtension : level.turnTimer)
        remaining = duration
        isRunning = true
    }

    func stop() {
        isRunning = false
        remaining = 0
        duration = 0
        isExtended = false
    }

    func pause() { isRunning = false }

    /// Resumes without restarting the beat, so pausing does not gift the player time.
    func resume() { if remaining > 0 { isRunning = true } }

    /// Advances the beat. Returns true on the tick the beat expires — exactly
    /// once, since the timer stops itself.
    func update(deltaTime: TimeInterval) -> Bool {
        guard isRunning, deltaTime > 0 else { return false }
        remaining -= deltaTime
        guard remaining <= 0 else { return false }
        remaining = 0
        isRunning = false
        return true
    }
}
