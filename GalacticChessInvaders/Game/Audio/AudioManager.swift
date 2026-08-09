// AudioManager.swift
// Preloads all SFX at startup using SoundKey. Zero I/O during gameplay.
// SFX: .caf (lowest latency) via AVAudioPlayer pools.
// Looping sounds (ambient, critical crackle) use a single dedicated player.
// Music: .m4a via a separate streaming player.

import AVFoundation
import Foundation

final class AudioManager {
    static let shared = AudioManager()
    private init() {}

    // One pool per non-looping key (round-robin for polyphony)
    private var sfxPools:    [SoundKey: [AVAudioPlayer]] = [:]
    // One player per looping key
    private var loopPlayers: [SoundKey: AVAudioPlayer]   = [:]
    private var musicPlayer: AVAudioPlayer?
    private let poolSize = 4

    private var sfxBaseURL: URL? {
        Bundle.main.url(forResource: "sfx", withExtension: nil)
    }

    // MARK: - Startup

    func preloadAll() {
        for key in SoundKey.allCases {
            preload(key)
        }
        DiagnosticsLog.shared.log(.audio,
            "Preloaded \(sfxPools.count) SFX pools + \(loopPlayers.count) loop players")
    }

    private func preload(_ key: SoundKey) {
        guard let base = sfxBaseURL else {
            DiagnosticsLog.shared.log(.error, "sfx bundle directory not found")
            return
        }
        let url = base.appendingPathComponent(key.filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Stubs for generated/ sounds — expected to be absent until created
            if !key.filename.hasPrefix("generated/") {
                DiagnosticsLog.shared.log(.error, "SFX missing: \(key.filename)")
            }
            return
        }
        if key.loops {
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
            player.numberOfLoops = -1
            player.volume = key.defaultVolume
            player.prepareToPlay()
            loopPlayers[key] = player
        } else {
            var pool: [AVAudioPlayer] = []
            for _ in 0..<poolSize {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = key.defaultVolume
                    player.prepareToPlay()
                    pool.append(player)
                }
            }
            if !pool.isEmpty { sfxPools[key] = pool }
        }
    }

    // MARK: - Playback

    func play(_ key: SoundKey) {
        if key.loops {
            loopPlayers[key]?.play()
        } else {
            guard let pool = sfxPools[key] else { return }
            let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            player.currentTime = 0
            player.play()
        }
    }

    func stop(_ key: SoundKey) {
        if key.loops {
            loopPlayers[key]?.stop()
        }
    }

    func setVolume(_ volume: Float, for key: SoundKey) {
        loopPlayers[key]?.volume = volume
        sfxPools[key]?.forEach { $0.volume = volume }
    }

    // MARK: - Music

    func playMusic(_ trackName: String, volume: Float = 0.75) {
        guard let url = Bundle.main.url(forResource: trackName, withExtension: "m4a") else {
            DiagnosticsLog.shared.log(.error, "Music not found: \(trackName).m4a")
            return
        }
        musicPlayer?.stop()
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = volume
        player.prepareToPlay()
        player.play()
        musicPlayer = player
        DiagnosticsLog.shared.log(.audio, "Music → \(trackName)")
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    func setMusicVolume(_ volume: Float) {
        musicPlayer?.volume = volume
    }

    /// Temporarily duck music during loud SFX, then restore.
    func duckMusic(to volume: Float = 0.35, for duration: TimeInterval = 0.8) {
        guard let player = musicPlayer else { return }
        let original = player.volume
        player.volume = volume
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            player.volume = original
        }
    }
}
