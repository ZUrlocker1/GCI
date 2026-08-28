// GameSettings.swift
// The player's preferences, persisted across launches (§20 Phase 5).
//
// Everything the settings screen can change lives here, along with what a
// difficulty preset *means* — so "Cadet" is defined in one place rather than
// spread across the scene, the level table and the ship.
//
// Deliberately not `@Observable`. Nothing in SwiftUI needs to re-render when a
// value changes — the one consumer that could (the diagnostics sidebar) reads
// its setting once at launch, and the live scene is told by `SettingsNode`. So
// this stays a plain class, out of the macro dance `typecheck.sh` works around.

import Foundation
import CoreGraphics

@MainActor
final class GameSettings {

    static let shared = GameSettings()

    /// §12.9's two tiers. There is no hard mode: §21 already aims Level 5+ at
    /// "overwhelming-but-survivable", so a rung above that has no one to serve
    /// until somebody has actually finished the game.
    enum Difficulty: String {
        case cadet
        case pilot
    }

    // MARK: - Audio

    var musicOn: Bool           { didSet { persist() } }
    /// 0...1, applied on top of `AudioManager.musicVolume`.
    var musicVolume: Float      { didSet { persist() } }
    var soundOn: Bool           { didSet { persist() } }
    /// 0...1, scaling the whole SFX bus. Per-key balance stays as tuned.
    var soundVolume: Float      { didSet { persist() } }

    // MARK: - Gameplay

    var difficulty: Difficulty  { didSet { persist() } }
    /// The engine plays White. Not a mechanics change — `resolveBeat` already
    /// auto-moves when the player doesn't — so this only suppresses the chess
    /// affordances and says so on the clock.
    var autoChess: Bool         { didSet { persist() } }

    // MARK: - Display

    var neonGlow: Bool          { didSet { persist() } }
    /// 0...1. Drives the lattice's stroke alpha and line width together; at 0
    /// it disappears, which is the look §12.3 originally specified.
    var boardGrid: CGFloat      { didSet { persist() } }
    var homeZones: Bool         { didSet { persist() } }
    /// Whether the diagnostics sidebar is open. The `L` key and the settings
    /// switch both write here and neither owns it, so the two can never
    /// disagree about what the panel is doing.
    var logPanel: Bool          { didSet { persist() } }

    // MARK: - Controls

    /// 0.75...1.25. Clamped narrow on purpose: `SpaceshipNode.speed` was 420 and
    /// was cut 30% after playtest because short taps overshot the file you were
    /// aiming at. A wide range would let a player undo that finding by accident.
    var shipSpeedScale: CGFloat { didSet { persist() } }

    static let shipSpeedRange: ClosedRange<CGFloat> = 0.75...1.25

    /// The audio sliders run past the shipped mix rather than stopping at it.
    ///
    /// Music plays at `0.75 x this` and effects are capped at 0.68, so there is
    /// real headroom above the level the game ships with — and a slider pinned
    /// to its own maximum can only ever be turned down. Somebody who wants more
    /// music should not have to reach it by quietening everything else.
    ///
    /// The shipped level is unchanged; it now sits at 75% of the scale, where
    /// the notch marks it. 4/3 is what puts it there, and it lands neatly: at
    /// the top of the slider the music reaches exactly 1.0, which is also the
    /// most `AVAudioPlayer.volume` will take.
    static let audioMax: Float = 4.0 / 3.0

    // MARK: - What a preset means

    /// §8.5's three, or five for a first run.
    var lives: Int { difficulty == .cadet ? 5 : 3 }

    /// Cadet scales the tuning directly rather than borrowing an earlier level's
    /// row. A row shift looked tidier, but the table caps moves and shots at
    /// Level 5, so from Level 6 up it did almost nothing — which is exactly
    /// where a struggling player needs it most.
    var fleetSpeedScale: CGFloat { difficulty == .cadet ? 0.80 : 1.0 }
    var enemyShotScale: CGFloat  { difficulty == .cadet ? 0.85 : 1.0 }
    /// Added to the level's beat. The clock is the single biggest lever for
    /// someone still learning to do both halves at once.
    var turnClockBonus: TimeInterval { difficulty == .cadet ? 1.0 : 0 }

    /// Cadet fires faster without touching the laser *cap*, which is what the
    /// green scout rewards. Rounds that clear the screen sooner free a
    /// concurrency slot sooner, so it fires faster and aims easier at once —
    /// and every point of cap is still earned.
    var playerLaserSpeed: CGFloat { difficulty == .cadet ? 650 : 520 }

    /// Cadet keeps the laser cap and an unused shield across a level break,
    /// inverting §13.2's "earned again or not at all". Coasting is the point.
    var keepsPowerUps: Bool { difficulty == .cadet }

    // MARK: - Persistence

    private enum Key {
        static let musicOn         = "GCI_MusicOn"
        static let musicVolume     = "GCI_MusicVolume"
        static let soundOn         = "GCI_SoundOn"
        static let soundVolume     = "GCI_SoundVolume"
        static let difficulty      = "GCI_Difficulty"
        static let autoChess       = "GCI_AutoChess"
        static let neonGlow        = "GCI_NeonGlow"
        static let boardGrid       = "GCI_BoardGrid"
        static let homeZones       = "GCI_HomeZones"
        static let logPanel        = "GCI_LogPanel"
        static let shipSpeedScale  = "GCI_ShipSpeedScale"
    }

    /// Guards the `didSet` observers during a bulk restore, so writing eleven
    /// values in a row saves the file once rather than eleven times.
    private var isPersisting = false

    private init() {
        let store = UserDefaults.standard
        // `object(forKey:)` rather than `bool(forKey:)`: the latter returns
        // false for a key that was never written, which would silently ship
        // the music muted on a first launch.
        func flag(_ key: String, default value: Bool) -> Bool {
            store.object(forKey: key) as? Bool ?? value
        }
        func number(_ key: String, default value: Double) -> Double {
            store.object(forKey: key) as? Double ?? value
        }

        musicOn         = flag(Key.musicOn, default: true)
        musicVolume     = Float(number(Key.musicVolume, default: 1.0))
        soundOn         = flag(Key.soundOn, default: true)
        soundVolume     = Float(number(Key.soundVolume, default: 1.0))
        difficulty      = Difficulty(rawValue: store.string(forKey: Key.difficulty) ?? "") ?? .pilot
        autoChess       = flag(Key.autoChess, default: false)
        neonGlow        = flag(Key.neonGlow, default: true)
        boardGrid       = CGFloat(number(Key.boardGrid, default: 0.5))
        homeZones       = flag(Key.homeZones, default: true)
        logPanel        = flag(Key.logPanel, default: false)
        shipSpeedScale  = CGFloat(number(Key.shipSpeedScale, default: 1.0))
    }

    private func persist() {
        guard !isPersisting else { return }
        let store = UserDefaults.standard
        store.set(musicOn,                 forKey: Key.musicOn)
        store.set(Double(musicVolume),     forKey: Key.musicVolume)
        store.set(soundOn,                 forKey: Key.soundOn)
        store.set(Double(soundVolume),     forKey: Key.soundVolume)
        store.set(difficulty.rawValue,     forKey: Key.difficulty)
        store.set(autoChess,               forKey: Key.autoChess)
        store.set(neonGlow,                forKey: Key.neonGlow)
        store.set(Double(boardGrid),       forKey: Key.boardGrid)
        store.set(homeZones,               forKey: Key.homeZones)
        store.set(logPanel,                forKey: Key.logPanel)
        store.set(Double(shipSpeedScale),  forKey: Key.shipSpeedScale)
    }

    /// Puts every setting back to its shipped value.
    func restoreDefaults() {
        isPersisting = true
        musicOn = true;         musicVolume = 1.0
        soundOn = true;         soundVolume = 1.0
        difficulty = .pilot;    autoChess = false
        neonGlow = true;        boardGrid = 0.5
        homeZones = true;       logPanel = false
        shipSpeedScale = 1.0
        isPersisting = false
        persist()
        DiagnosticsLog.shared.log(.startup, "settings restored to defaults")
    }
}
