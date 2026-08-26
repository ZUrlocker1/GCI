// AudioManager.swift
// Preloads all SFX at startup using SoundKey. Zero I/O during gameplay.
// SFX: .caf (lowest latency) via AVAudioPlayer pools.
// Looping sounds (ambient, critical crackle) use a single dedicated player.
// Music: .m4a via a separate streaming player.

import AVFoundation
import Foundation

@MainActor
final class AudioManager {
    static let shared = AudioManager()
    private init() {}

    // One pool per non-looping key (round-robin for polyphony)
    private var sfxPools:    [SoundKey: [AVAudioPlayer]] = [:]
    // One player per looping key
    private var loopPlayers: [SoundKey: AVAudioPlayer]   = [:]
    private var musicPlayer: AVAudioPlayer?
    private let poolSize = 4

    /// Music sits on top; effects sit just under it. Each SoundKey keeps its own
    /// relative balance and the whole SFX bus is scaled, so the mix is tuned here
    /// rather than across 120 cases. The ceiling matters because a few keys are
    /// authored at 1.0 and would otherwise punch through the track.
    static let musicVolume: Float = 0.75
    private static let sfxGain: Float = 0.82
    private static let sfxCeiling: Float = 0.68

    /// Final mixer level for a key: its own balance, scaled and capped under the music.
    static func volume(for key: SoundKey) -> Float {
        min(key.defaultVolume * sfxGain, sfxCeiling)
    }

    private var sfxBaseURL: URL? {
        Bundle.main.url(forResource: "sfx", withExtension: nil)
    }

    // MARK: - Startup

    func preloadAll() {
        guard sfxBaseURL != nil else {
            DiagnosticsLog.shared.log(.error, "sfx bundle directory not found — no SFX will play")
            return
        }
        // Only the sounds the game currently triggers are bundled; the rest arrive
        // with the phases that use them. Report those as one summary line rather
        // than dozens of errors, so the log stays readable.
        var absent = 0
        for key in SoundKey.allCases where !preload(key) { absent += 1 }

        DiagnosticsLog.shared.log(.audio,
            "SFX ready: \(sfxPools.count) pools, \(loopPlayers.count) loops"
            + (absent > 0 ? " (\(absent) not yet bundled)" : ""))
    }

    /// Returns false if the sound is not available to load.
    @discardableResult
    private func preload(_ key: SoundKey) -> Bool {
        guard let base = sfxBaseURL else { return false }
        let url = base.appendingPathComponent(key.filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        if key.loops {
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
            player.numberOfLoops = -1
            player.volume = Self.volume(for: key)
            player.prepareToPlay()
            loopPlayers[key] = player
            return true
        }

        var pool: [AVAudioPlayer] = []
        for _ in 0..<poolSize {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = Self.volume(for: key)
                player.prepareToPlay()
                pool.append(player)
            }
        }
        guard !pool.isEmpty else { return false }
        sfxPools[key] = pool
        return true
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

    // MARK: - Music

    func playMusic(_ trackName: String, volume: Float = AudioManager.musicVolume) {
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

    func pauseMusic() {
        musicPlayer?.pause()
    }

    func resumeMusic() {
        musicPlayer?.play()
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
