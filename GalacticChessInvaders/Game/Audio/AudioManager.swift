// AudioManager.swift
// Preloads all SFX at startup using SoundKey.
// SFX: .caf (lowest latency) via AVAudioPlayer pools.
//
// This header used to say "Zero I/O during gameplay". It was not true, and on
// 30 Sep it cost an iPad half its frame rate. `prepareToPlay()` is called once
// at preload, but **an AVAudioPlayer releases its buffers when it finishes** —
// so the second and every later use of a pooled player re-prepared inline on
// the main thread: file open, read, decoder setup, per shot.
//
// Measured by Zack on an iPad mini 5: SOUND FX off held 53–60fps with glow
// *and* nebula on, against dips into the 20s with them off and sound on. That
// is the whole of it. §6a's "GPU-bound, the bloom is why" was a Mac finding
// and does not transfer; the Mac simply had the headroom to absorb this.
//
// `rearmFinishedPlayers()` puts the buffers back on a 250ms tick instead, so
// the cost lands away from the frame that fires the shot.
// Looping sounds (ambient, critical crackle) use a single dedicated player.
// Music: .m4a via a separate streaming player.

import AVFoundation
import Foundation

@MainActor
final class AudioManager {
    static let shared = AudioManager()
    private init() {}

    /// The worst single `play(_:)` call since the last time this was read, in
    /// milliseconds. The log panel shows it beside fps.
    ///
    /// Here because the frame-rate question kept being answered with
    /// impressions. A number that says "4ms" or "0.1ms" ends the argument in
    /// one run; three separate A/B rounds did not.
    private(set) var worstPlayMs: Double = 0

    func takeWorstPlayMs() -> Double {
        defer { worstPlayMs = 0 }
        return worstPlayMs
    }

    /// Silent under XCTest, and not negotiable.
    ///
    /// The suite launches the app as its test host, so the app starts, the
    /// soundtrack starts, and seventy seconds of it plays out of whoever is
    /// running the tests. Muting by hand is a thing to forget; muting through
    /// `GameSettings` writes the player's own settings; and passing
    /// `-GCI_MusicOn NO` through the scheme does not work, because Xcode
    /// sends it as a single argv element and `NSArgumentDomain` never parses
    /// it into a key and a value.
    ///
    /// So the check lives here, at the one place sound is produced.
    /// `XCTestConfigurationFilePath` is set by XCTest in the host process and
    /// by nothing else, so a real launch is unaffected.
    static let isUnderTest =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// The one place a sound actually starts, so the test guard is the one
    /// line in it.
    ///
    /// Deliberately *here* rather than at the top of `play` and `preloadAll`,
    /// which was the first cut and broke `AudioAssetTests`: those methods also
    /// load the assets and record how long a sting runs, and the suite reads
    /// that bookkeeping. Loading a file is silent; only playback is not.
    private func start(_ player: AVAudioPlayer?) {
        guard !Self.isUnderTest else { return }
        player?.play()
    }

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
    /// Bundled as a folder reference, like `sfx`, so the twenty tracks are not
    /// loose in the bundle root beside the icon and the font. A folder
    /// reference keeps the directory, so every lookup names it.
    static let musicDirectory = "music"

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
        // rather than an error. Neither the count of absent files nor the pool
        // and loop counts are reported here any more: all three only change
        // when `SoundKey` does, so they said the same thing on every launch
        // while taking up the one line that says the audio came up at all.
        for key in SoundKey.allCases { preload(key) }

        DiagnosticsLog.shared.log(.audio, "SFX ready")
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
    /// The eight keys that sum into a wall. Each has its own pool of four, so a
    /// rank clearing could put 32 voices into the mixer at once.
    private static let destructionKeys: Set<SoundKey> = [
        .pawnDestroyed, .knightDestroyed, .bishopDestroyed, .rookDestroyed,
        .queenDestroyed, .kingDestroyed, .playerShipDestroyed, .bombShockwave,
    ]
    /// §12 caps critical crackle at three for the same reason: past that the
    /// ear cannot separate them, and the screen is carrying it anyway.
    private static let destructionVoiceCap = 3

    /// How long a bundled track runs, without starting it. Used to hand the
    /// end-of-run stinger back to the intro when it finishes.
    func duration(ofTrack name: String) -> TimeInterval? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a",
                                        subdirectory: Self.musicDirectory),
              let probe = try? AVAudioPlayer(contentsOf: url) else { return nil }
        return probe.duration
    }

    /// When the last sting played through `play(oneOf:)` finishes.
    private var stingEnds = Date.distantPast
    /// When the last destruction one-shot finishes.
    private var destructionEnds = Date.distantPast

    /// How long the explosion still has to run, or zero if none is sounding.
    ///
    /// The level clear cue used to fire in the same frame as the king's
    /// destruction and lose to it by 9dB — audible in isolation, inaudible in
    /// place. A caller with something to say after the bang can wait this out.
    var destructionRemaining: TimeInterval { max(0, destructionEnds.timeIntervalSinceNow) }

    /// How long that sting still has to run, or zero if none is sounding.
    ///
    /// The loss sting is three seconds and the end-of-game hold is two and a
    /// half, so the high score prompt opened over its last half second and
    /// talked across it. A caller with a cue of its own can wait this out.
    var stingRemaining: TimeInterval { max(0, stingEnds.timeIntervalSinceNow) }

    /// Plays one of `pool` at random. For events that would wear out if they
    /// always sounded the same — see `SoundKey.gameOverPool`.
    func play(oneOf pool: [SoundKey], scale: Float = 1) {
        guard let key = pool.randomElement() else { return }
        play(key, scale: scale)
        // Read off the player rather than hard-coded: these are trimmed assets
        // and the number would rot the moment one is re-cut.
        if GameSettings.shared.soundOn, let length = sfxPools[key]?.first?.duration {
            stingEnds = Date().addingTimeInterval(length)
        }
    }

    func play(_ key: SoundKey, scale: Float = 1) {
        let settings = GameSettings.shared
        guard settings.soundOn else { return }
        let began = CACurrentMediaTime()
        defer {
            worstPlayMs = max(worstPlayMs, (CACurrentMediaTime() - began) * 1000)
        }

        // Dropped rather than queued. A late explosion is worse than a missing
        // one — the sound would arrive after the thing it belongs to is gone.
        if Self.destructionKeys.contains(key) {
            let live = Self.destructionKeys.reduce(0) { total, other in
                total + (sfxPools[other]?.count(where: \.isPlaying) ?? 0)
            }
            guard live < Self.destructionVoiceCap else { return }
        }
        // Applied here rather than at preload: the player can move the slider
        // mid-game, and a level baked into a pooled `AVAudioPlayer` would stay
        // wherever it was when the app launched.
        let level = Self.volume(for: key) * settings.soundVolume * scale
        if key.loops {
            loopPlayers[key]?.volume = level
            start(loopPlayers[key])
        } else {
            guard let pool = sfxPools[key] else { return }
            let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            player.volume = level
            player.currentTime = 0
            start(player)
            if Self.destructionKeys.contains(key) {
                destructionEnds = max(destructionEnds,
                                      Date().addingTimeInterval(player.duration))
            }
        }
    }

    /// Puts the buffers back on players that have finished.
    ///
    /// An `AVAudioPlayer` releases them when playback ends, and `play()` then
    /// re-prepares synchronously — file I/O on the frame that fired the shot.
    /// Called from the same 250ms tick that samples fps, so the work is
    /// bounded, predictable, and nowhere near a trigger pull.
    ///
    /// Capped per tick so a wave of finishing sounds cannot turn one tick into
    /// the hitch this is meant to remove. Eight per tick is 32 a second,
    /// comfortably ahead of how fast the pools can be cycled.
    func rearmFinishedPlayers(limit: Int = 8) {
        var done = 0
        for pool in sfxPools.values {
            for player in pool where !player.isPlaying && player.currentTime != 0 {
                player.currentTime = 0
                player.prepareToPlay()
                done += 1
                if done >= limit { return }
            }
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
        musicPlayer?.volume = musicTarget
        if isMusicMuted {
            musicPlayer?.pause()
        } else if !pausedByGame {
            musicPlayer?.play()
        }
    }

    /// What the music should be playing at: the mix position scaled by the
    /// player's own setting. Computed in one place because four paths set it —
    /// starting a track, resuming, a settings change, and undoing a fade.
    private var musicTarget: Float {
        Self.musicVolume * GameSettings.shared.musicVolume
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
    func fadeTo(track: String, over duration: TimeInterval = 0.5,
                gap: TimeInterval = 0,
                startAt: TimeInterval = 0, fadeIn: TimeInterval = 0,
                loops: Bool = true) {
        // Before the guard, not after. A hand-over already scheduled has to be
        // cancelled even when this call decides it has nothing to do — closing
        // a panel queues the level track 1.7s out, and reopening inside that
        // window used to return early on "already playing the intro" and leave
        // the level track to land on top of the open panel.
        fadeGeneration += 1
        let token = fadeGeneration
        guard track != currentTrack else {
            // Already playing it — but a hand-over cancelled a line above may
            // have left this player mid-fade to zero, and nothing else would
            // ever bring it back. Closing a panel starts a 1.2s fade out;
            // reopening inside that window landed here and went silent.
            musicPlayer?.setVolume(musicTarget, fadeDuration: 0.3)
            return
        }
        guard let player = musicPlayer else {
            playMusic(track, startAt: startAt, fadeIn: fadeIn, loops: loops); return
        }
        player.setVolume(0, fadeDuration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + gap) { [weak self] in
            guard let self, self.fadeGeneration == token else { return }
            self.playMusic(track, startAt: startAt, fadeIn: fadeIn, loops: loops)
        }
    }

    /// The same hand-over, choosing from a pool. Does nothing when the pool's
    /// pick is already playing, so a level break inside one band does not
    /// restart the track it is already on.
    func fadeTo(pool: [String], over duration: TimeInterval = 0.5,
                gap: TimeInterval = 0) {
        fadeTo(track: MusicLibrary.choose(from: pool, avoiding: currentTrack),
               over: duration, gap: gap)
    }

    /// `loops` is true for everything that plays under the game — a wave's
    /// track, the title theme — and false for the one-shot pieces that see a
    /// run out. An end-of-run stinger left to loop reached its own fade-out and
    /// then started again from its opening bars, which reads as a new level
    /// beginning on the game over screen.
    func playMusic(_ trackName: String, volume: Float = AudioManager.musicVolume,
                   startAt: TimeInterval = 0, fadeIn: TimeInterval = 0,
                   loops: Bool = true) {
        // Every route to the soundtrack ends here — `fadeTo`, `playMusic(from:)`
        // and the direct calls — so this one guard is the whole of it.
        guard !Self.isUnderTest else { return }
        guard let url = Bundle.main.url(forResource: trackName, withExtension: "m4a",
                                        subdirectory: Self.musicDirectory) else {
            DiagnosticsLog.shared.log(.error, "Music not found: \(trackName).m4a")
            return
        }
        // Cancels anything a fade has queued. Without this a hand-over
        // scheduled 1.7s out survived the trip back to the title — X during a
        // level change stopped the music, started the intro, and then let the
        // queued level track land on the title screen.
        fadeGeneration += 1
        musicPlayer?.stop()
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = loops ? -1 : 0
        player.volume = volume * GameSettings.shared.musicVolume
        // `rate` is ignored unless this is armed before the player is prepared,
        // so it goes on whether or not a slow-motion effect ever fires.
        player.enableRate = true
        player.prepareToPlay()
        // Set after preparing; before it the duration is not known and the
        // seek is silently ignored.
        if startAt > 0, startAt < player.duration { player.currentTime = startAt }
        // Loaded but left silent while muted, so unmuting picks up whatever
        // track the game has since switched to rather than the one playing when
        // the player hit `M`. Same for a pause: a hand-over scheduled before
        // the player hit Escape lands during it — a level change fades over
        // 1.7s and the banner is up for three — and used to start playing over
        // a paused game.
        if !isMusicMuted && !pausedByGame {
            let target = player.volume
            if fadeIn > 0 { player.volume = 0 }
            player.play()
            if fadeIn > 0 { player.setVolume(target, fadeDuration: fadeIn) }
        }
        musicPlayer = player
        currentTrack = trackName
        DiagnosticsLog.shared.log(.music, MusicVariants.describe(trackName))
    }

    /// A third of a second, not a cut. Fast enough for the reason people pause
    /// mid-game — a phone call — and short of the click a hard stop makes
    /// mid-bar.
    func pauseMusic() {
        pausedByGame = true
        guard let player = musicPlayer else { return }
        player.setVolume(0, fadeDuration: 0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            // Still paused? A quick unpause inside the fade must not silence
            // the music it has already brought back.
            guard self?.pausedByGame == true else { return }
            player.pause()
        }
    }

    func resumeMusic() {
        pausedByGame = false
        guard !isMusicMuted, let player = musicPlayer else { return }
        player.volume = 0
        player.play()
        player.setVolume(musicTarget, fadeDuration: 0.3)
    }

    func stopMusic() {
        fadeGeneration += 1
        pausedByGame = false
        musicPlayer?.stop()
        musicPlayer = nil
        currentTrack = nil
    }

    func setMusicVolume(_ volume: Float) {
        musicPlayer?.volume = volume
    }

    /// §13.2's slow-motion cue. Shallow on purpose — see `slowMoMusicRate`.
    func setMusicRate(_ rate: Float) {
        musicPlayer?.rate = rate
    }

    /// Temporarily duck music during loud SFX, then restore.
}
