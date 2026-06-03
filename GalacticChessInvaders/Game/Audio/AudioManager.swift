// AudioManager.swift
// Preloads all SFX at startup as AVAudioPlayer instances.
// SFX: .caf format (lowest latency). Music: .m4a (AAC streaming).
// All audio is preloaded — zero I/O during gameplay.

import AVFoundation
import Foundation

final class AudioManager {
    static let shared = AudioManager()
    private init() {}

    // SFX pools (multiple instances for polyphony)
    private var sfxPools: [String: [AVAudioPlayer]] = [:]
    private let sfxPoolSize = 4

    // Music players
    private var musicPlayer: AVAudioPlayer?
    private var currentTrackName: String?

    // MARK: - Startup Preload

    func preloadAll() {
        let sfxNames = [
            "laser-fire",
            "laser-hit-pawn",
            "laser-hit-piece",
            "laser-hit-king",
            "explosion-small",
            "explosion-medium",
            "explosion-large",
            "explosion-king",
            "piece-crush",
            "ship-destroyed",
            "ship-respawn",
            "level-clear",
            "game-over",
            "promotion",
            "multi-shot",
            "power-up",
            "check-alert",
            "ui-select",
            "ui-confirm"
        ]

        for name in sfxNames {
            preloadSFX(named: name)
        }

        DiagnosticsLog.shared.log(.audio, "Preloaded \(sfxPools.count) SFX pools (\(sfxPoolSize) instances each)")
    }

    private func preloadSFX(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
            DiagnosticsLog.shared.log(.error, "SFX not found: \(name).caf")
            return
        }
        var pool: [AVAudioPlayer] = []
        for _ in 0..<sfxPoolSize {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                pool.append(player)
            }
        }
        if !pool.isEmpty {
            sfxPools[name] = pool
        }
    }

    // MARK: - SFX Playback

    func playSFX(_ name: String) {
        guard let pool = sfxPools[name] else { return }
        // Round-robin: find a player that isn't playing
        let available = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        available.currentTime = 0
        available.play()
    }

    // MARK: - Music Playback

    /// Play a music track by filename (without extension). Loops indefinitely.
    func playMusic(_ trackName: String) {
        guard trackName != currentTrackName else { return }  // already playing

        guard let url = Bundle.main.url(forResource: trackName, withExtension: "m4a") else {
            DiagnosticsLog.shared.log(.error, "Music not found: \(trackName).m4a")
            return
        }

        musicPlayer?.stop()
        if let player = try? AVAudioPlayer(contentsOf: url) {
            player.numberOfLoops = -1   // infinite loop
            player.volume = 0.75
            player.prepareToPlay()
            player.play()
            musicPlayer = player
            currentTrackName = trackName
            DiagnosticsLog.shared.log(.audio, "Music → \(trackName)")
        }
    }

    func stopMusic(fadeDuration: TimeInterval = 0.5) {
        // Simple stop for now; fade can be added with a timer
        musicPlayer?.stop()
        musicPlayer = nil
        currentTrackName = nil
        DiagnosticsLog.shared.log(.audio, "Music stopped")
    }

    func setMusicVolume(_ volume: Float) {
        musicPlayer?.volume = volume
    }

    /// Duck music volume briefly (e.g. during loud SFX)
    func duckMusic(to volume: Float = 0.4, for duration: TimeInterval = 0.5) {
        let original = musicPlayer?.volume ?? 0.75
        musicPlayer?.volume = volume
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.musicPlayer?.volume = original
        }
    }
}
