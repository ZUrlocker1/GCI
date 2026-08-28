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
        // Only the sounds the game currently triggers are bundled; the rest
        // arrive with the phases that use them, and a missing file is a no-op
        // rather than an error. The count of absent files used to be reported
        // here; every sound the game actually plays is now bundled, so it only
        // ever counted files that are deliberately not there — a number that
        // never changes is not worth a line on every launch.
        for key in SoundKey.allCases { preload(key) }

        DiagnosticsLog.shared.log(.audio,
            "SFX ready: \(sfxPools.count) pools, \(loopPlayers.count) loops")
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

    /// `scale` is for the rare caller that wants this one cue quieter than its
    /// mix position — the title screen's flyby, which is decoration behind a
    /// menu rather than an event in a game.
    func play(_ key: SoundKey, scale: Float = 1) {
        let settings = GameSettings.shared
        guard settings.soundOn else { return }
        // Applied here rather than at preload: the player can move the slider
        // mid-game, and a level baked into a pooled `AVAudioPlayer` would stay
        // wherever it was when the app launched.
        let level = Self.volume(for: key) * settings.soundVolume * scale
        if key.loops {
            loopPlayers[key]?.volume = level
            loopPlayers[key]?.play()
        } else {
            guard let pool = sfxPools[key] else { return }
            let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            player.volume = level
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

    /// The `M` key and the settings screen's Music switch are the same state,
    /// held in `GameSettings` so it persists and so there is only ever one
    /// answer to "is the music on".
    var isMusicMuted: Bool { !GameSettings.shared.musicOn }
    /// The other, independent reason the music can be silent. Kept apart from
    /// the mute so neither one can resume over the top of the other: unmuting
    /// mid-pause must not start the music, and resuming from a pause must not
    /// undo a mute.
    private var pausedByGame = false

    /// Returns the new state — true when the music is now off.
    @discardableResult
    func toggleMusic() -> Bool {
        GameSettings.shared.musicOn.toggle()
        applyMusicSettings()
        DiagnosticsLog.shared.log(.audio, "Music \(isMusicMuted ? "off" : "on")")
        return isMusicMuted
    }

    /// Brings the running track into line with the settings — after a slider
    /// move, a switch, or a restore. Safe to call when nothing is playing.
    func applyMusicSettings() {
        musicPlayer?.volume = Self.musicVolume * GameSettings.shared.musicVolume
        if isMusicMuted {
            musicPlayer?.pause()
        } else if !pausedByGame {
            musicPlayer?.play()
        }
    }

    /// The track currently loaded, so a pool can avoid repeating it.
    private(set) var currentTrack: String?

    /// Starts a track from `pool`, avoiding whatever is playing. A pool of one
    /// that is already playing is left alone rather than restarted — otherwise
    /// every level break would cut the music back to bar one.
    func playMusic(from pool: [String]) {
        let next = MusicLibrary.choose(from: pool, avoiding: currentTrack)
        guard next != currentTrack || musicPlayer == nil else { return }
        playMusic(next)
    }

    /// Rising each time a fade is scheduled, so a panel opened and shut inside
    /// half a second cannot leave two hand-overs racing to start a track.
    private var fadeGeneration = 0

    /// Fades the current track out and starts `track` when it has gone.
    ///
    /// A fade rather than a cut because these hand-overs happen mid-bar, and
    /// half a second is long enough to not be a splice without being a wait.
    /// Timed with `asyncAfter`, not an `SKAction`: opening a panel pauses the
    /// scene, which stops actions for the whole tree.
    func fadeTo(track: String, over duration: TimeInterval = 0.5) {
        guard track != currentTrack else { return }
        guard let player = musicPlayer else { playMusic(track); return }
        fadeGeneration += 1
        let token = fadeGeneration
        player.setVolume(0, fadeDuration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.fadeGeneration == token else { return }
            self.playMusic(track)
        }
    }

    /// The same hand-over, choosing from a pool. Does nothing when the pool's
    /// pick is already playing, so a level break inside one band does not
    /// restart the track it is already on.
    func fadeTo(pool: [String], over duration: TimeInterval = 0.5) {
        fadeTo(track: MusicLibrary.choose(from: pool, avoiding: currentTrack),
               over: duration)
    }

    func playMusic(_ trackName: String, volume: Float = AudioManager.musicVolume) {
        guard let url = Bundle.main.url(forResource: trackName, withExtension: "m4a") else {
            DiagnosticsLog.shared.log(.error, "Music not found: \(trackName).m4a")
            return
        }
        musicPlayer?.stop()
        pausedByGame = false
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = volume * GameSettings.shared.musicVolume
        // §13.2's Time Freeze slows the music to 0.5×. `rate` is ignored unless
        // this is set *before* the player is prepared, so it has to be armed
        // here whether or not a freeze ever happens.
        player.enableRate = true
        player.prepareToPlay()
        // Loaded but left silent while muted, so unmuting picks up whatever
        // track the game has since switched to rather than the one playing when
        // the player hit `M`.
        if !isMusicMuted { player.play() }
        musicPlayer = player
        currentTrack = trackName
        DiagnosticsLog.shared.log(.audio, "Music → \(trackName)")
    }

    func pauseMusic() {
        pausedByGame = true
        musicPlayer?.pause()
    }

    func resumeMusic() {
        pausedByGame = false
        guard !isMusicMuted else { return }
        musicPlayer?.play()
    }

    func stopMusic() {
        pausedByGame = false
        musicPlayer?.stop()
        musicPlayer = nil
        currentTrack = nil
    }

    func setMusicVolume(_ volume: Float) {
        musicPlayer?.volume = volume
    }

    /// §13.2's Time Freeze: the music slows and deepens rather than a separate
    /// sound announcing the effect. The one place `rate` is used deliberately.
    func setMusicRate(_ rate: Float) {
        musicPlayer?.rate = rate
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
