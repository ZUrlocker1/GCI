// SoundKey.swift
// Maps every game event to a source audio file.
//
// NOTE: Kenney files are .ogg — convert to .caf before adding to Xcode:
//   ffmpeg -i input.ogg -ar 44100 output.caf
// GDC bundle files are .wav — afconvert handles these:
//   afconvert input.wav -f caff -d LEI16 output.caf
// All files live in assets/sfx/{kenney-digital,kenney-sci-fi,gdc-bundle}/

import Foundation

enum SoundKey: String, CaseIterable {

    // ── Player spaceship ─────────────────────────────────────────────────────
    case playerLaserFire        // laserRetro_001.ogg        (kenney-sci-fi)
    case playerShipDestroyed    // explosionCrunch_004.ogg   (kenney-sci-fi)
    case playerExtraLife        // powerUp11.ogg             (kenney-digital)

    // ── Chess UI ─────────────────────────────────────────────────────────────
    case pieceSelected          // pepSound1.ogg             (kenney-digital)
    case whitePieceMoves        // pepSound3.ogg             (kenney-digital) — placeholder; replace with jsfxr
    case blackPieceMoves        // pepSound4.ogg             (kenney-digital) — placeholder; replace with jsfxr
    case illegalMove            // Interface Deny Low Fat Dark.wav (gdc-bundle)
    case checkAlarm             // zapTwoTone.ogg            (kenney-digital)
    case pawnPromotion          // UIMisc_Kalimba 3 Up.wav   (gdc-bundle)
    case autoMoveTrigger        // lowDown.ogg               (kenney-digital)
    case turnTimerWarning       // tone1.ogg                 (kenney-digital) — rapid-fire in code

    // ── Piece destruction — one per type ──────────────────────────────────────
    case pawnDestroyed          // explosionCrunch_001.ogg   (kenney-sci-fi)
    case knightDestroyed        // explosionCrunch_003.ogg   (kenney-sci-fi)
    case bishopDestroyed        // explosionCrunch_001.ogg   (kenney-sci-fi)
    case rookDestroyed          // explosionCrunch_003.ogg   (kenney-sci-fi)
    case queenDestroyed         // explosionCrunch_003.ogg   (kenney-sci-fi)
    case kingDestroyed          // explosionCrunch_004.ogg   (kenney-sci-fi)

    // ── Piece hit (laser impact before HP reaches 0) ──────────────────────────
    case pieceHitLight          // impactMetal_001.ogg       (kenney-sci-fi)
    case pieceHitHeavy          // impactMetal_004.ogg       (kenney-sci-fi)

    // ── Critical HP crackle loops (fire with numberOfLoops = -1) ─────────────
    case criticalCrackleHigh    // zap1.ogg                  (kenney-digital)
    case criticalCrackleMid     // zap2.ogg                  (kenney-digital)
    case criticalCrackleLow     // zapThreeToneDown.ogg      (kenney-digital)
    case criticalCrackleEerie   // Psycho Glitched Screechy Tones Noise.wav (gdc-bundle)

    // ── Invader fleet ─────────────────────────────────────────────────────────
    case invaderLaserFire       // laserSmall_001.ogg        (kenney-sci-fi)
    case kingLaserFire          // laserLarge_001.ogg        (kenney-sci-fi) — §10.1 King Activated
    case crossfireLaserFire     // laserSmall_004.ogg        (kenney-sci-fi) — Level 7 bishops
    case invaderHitsShip        // explosionCrunch_001.ogg   (kenney-sci-fi)
    case invaderHitsPiece       // impactMetal_001.ogg       (kenney-sci-fi)  — reuse pieceHitLight
    case fleetWallBounce        // lowDown.ogg               (kenney-digital)
    case fleetRankDrop          // DSGNBass_Bass Drop & Downer Fast 12.wav (gdc-bundle)
    case fleetHeartbeat         // — generate with jsfxr (sub-bass double-thump, ~70 Hz)

    // ── Raider ships ──────────────────────────────────────────────────────────
    // The Escort, the Flagship and the Llama are cut (§6); their keys and their
    // files went with them.
    case scoutEnterLoop         // spaceEngine_000.ogg       (kenney-sci-fi) — loop
    case scoutLaserFire         // laserSmall_004.ogg        (kenney-sci-fi)
    case raiderDestroyed        // threeTone1.ogg            (kenney-digital)

    // ── Special scouts ────────────────────────────────────────────────────────
    // §13.2's Lightning Scout is retired — its "+1 laser slot" is what the
    // plain green scout now grants, so there is no ship left to make the sound.
    case iceScoutDestroyed        // — generate with jsfxr (reverberant whoosh)
    case iceEffectExpires         // — generate with jsfxr (iceScoutDestroyed reversed)
    case spreadScoutDestroyed     // phaseJump4.ogg          (kenney-digital)
    case bombShockwave            // EffectiveTrailer_Booms_Vol2_011.wav (gdc-bundle)
    case repairScoutDestroyed     // powerUp8.ogg            (kenney-digital)

    // ── Shield ────────────────────────────────────────────────────────────────
    case shieldAbsorbsHit       // forceField_002.ogg        (kenney-sci-fi)
    case shieldShatters         // forceField_004.ogg        (kenney-sci-fi)

    // ── Armored pawn ──────────────────────────────────────────────────────────
    case armorRicochet          // DSGNErie_NoiseBoxHit_10.wav (gdc-bundle)
    case armorBreaks            // zapThreeToneDown.ogg      (kenney-digital) — stand-in
    case pieceRegenerates       // forceField_000.ogg        (kenney-sci-fi) — stand-in

    // ── Game events ──────────────────────────────────────────────────────────
    case levelClear             // Interface Arp Reveal Down Long.wav (gdc-bundle)
    case gameOver               // DSGNBass_Bass Drop & Downer Slow 10.wav (gdc-bundle)
    case mechanicBannerTier1    // phaserUp7.ogg             (kenney-digital)
    case mechanicBannerTier2    // DSGNBram Cinematic Horn Braam -32.wav (gdc-bundle)
    case mechanicBannerTier3    // Transition Braam Slow Dark Creepy.wav (gdc-bundle)
    case uiButtonClick          // Button Arp Twinkle.wav    (gdc-bundle)
    case uiSciFiPing            // Interface Sci-Fi Ping Down.wav (gdc-bundle)
    case ambientSpaceLoop       // Roomtone Space Ship Interior Muted.wav (gdc-bundle) — loop

    // ── Jeff Minter tribute ships ─────────────────────────────────────────────
    // Only the Camel, which flies as the Nuke's carrier rather than as a flyover.
    case camelHonk              // — generate with jsfxr (synthesized honk ~180 Hz)
}

// MARK: - File resolution

extension SoundKey {
    /// Filename (with extension) relative to assets/sfx/
    var filename: String {
        switch self {
        // Player
        case .playerLaserFire:          return "kenney-sci-fi/laserRetro_001.caf"
        case .playerShipDestroyed:      return "kenney-sci-fi/explosionCrunch_004.caf"
        case .playerExtraLife:          return "kenney-digital/powerUp11.caf"
        // Chess UI
        case .pieceSelected:            return "kenney-digital/pepSound1.caf"
        case .whitePieceMoves:          return "kenney-digital/pepSound3.caf"
        case .blackPieceMoves:          return "kenney-digital/pepSound4.caf"
        case .illegalMove:              return "gdc-bundle/Interface Deny Low Fat Dark.caf"
        case .checkAlarm:               return "kenney-digital/zapTwoTone.caf"
        case .pawnPromotion:            return "gdc-bundle/UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.caf"
        case .autoMoveTrigger:          return "kenney-digital/lowDown.caf"
        case .turnTimerWarning:         return "kenney-digital/tone1.caf"
        // Piece destruction — the kenney explosionCrunch set. _002 is unused:
        // it reads as gunfire rather than a blast, so the ladder runs
        // 000 / 001 / 003 / 004 (0.78s / 1.36s / 1.55s / 1.98s) and some pieces
        // share. The gdc alternatives are all 2-17s and 1.6-6.5 MB, which is
        // not a pawn death.
        // A bigger piece gets a longer boom, and _004 lands exactly on
        // §12's "~2 seconds" for the king. Four of these were specced to
        // gdc-bundle files that are 2.5-15.5 MB each — a 15 MB bishop death is
        // not a reasonable thing to ship, and these are both smaller and more
        // consistent with each other.
        case .pawnDestroyed:            return "kenney-sci-fi/explosionCrunch_001.caf"
        case .knightDestroyed:          return "kenney-sci-fi/explosionCrunch_003.caf"
        case .bishopDestroyed:          return "kenney-sci-fi/explosionCrunch_001.caf"
        case .rookDestroyed:            return "kenney-sci-fi/explosionCrunch_003.caf"
        case .queenDestroyed:           return "kenney-sci-fi/explosionCrunch_003.caf"
        case .kingDestroyed:            return "kenney-sci-fi/explosionCrunch_004.caf"
        // Hits — a non-fatal hit uses the *smallest* explosion rather than a
        // metal tick. Measured, the tick landed at effective RMS 0.067 against
        // the player's own laser at 0.119, so every hit was masked by the shot
        // that caused it: kills were audible (0.10-0.16) and everything else
        // sounded like nothing happened.
        case .pieceHitLight:            return "kenney-sci-fi/explosionCrunch_000.caf"
        case .pieceHitHeavy:            return "kenney-sci-fi/impactMetal_004.caf"
        // Critical crackle
        case .criticalCrackleHigh:      return "kenney-digital/zap1.caf"
        case .criticalCrackleMid:       return "kenney-digital/zap2.caf"
        case .criticalCrackleLow:       return "kenney-digital/zapThreeToneDown.caf"
        case .criticalCrackleEerie:     return "gdc-bundle/Psycho Glitched Screechy Tones Noise.caf"
        // Fleet
        case .invaderLaserFire:         return "kenney-sci-fi/laserSmall_001.caf"
        case .kingLaserFire:            return "kenney-sci-fi/laserLarge_001.caf"
        case .crossfireLaserFire:       return "kenney-sci-fi/laserSmall_004.caf"
        case .invaderHitsShip:          return "kenney-sci-fi/explosionCrunch_001.caf"
        case .invaderHitsPiece:         return "kenney-sci-fi/explosionCrunch_000.caf"
        case .fleetWallBounce:          return "kenney-digital/lowDown.caf"
        case .fleetRankDrop:            return "gdc-bundle/DSGNBass_Bass Drop & Downer Fast 12_344 Audio_Bass Drops & Downers Vol 2.caf"
        case .fleetHeartbeat:           return "generated/fleet-heartbeat.caf"
        // Raiders
        // A genuine loop, not repeated one-shots. Measured: its envelope
        // cycles about every 1.75s (RMS coefficient of variation 0.28), so it
        // *is* the warble — where a short two-tone fired on a timer was a
        // series of beeps, which is what it sounded like.
        case .scoutEnterLoop:           return "kenney-sci-fi/spaceEngine_000.caf"
        case .scoutLaserFire:           return "kenney-sci-fi/laserSmall_004.caf"
        case .raiderDestroyed:          return "kenney-digital/threeTone1.caf"
        // Special scouts
        case .iceScoutDestroyed:        return "generated/ice-scout-destroy.caf"
        case .iceEffectExpires:         return "generated/ice-scout-expire.caf"
        case .spreadScoutDestroyed:     return "kenney-digital/phaseJump4.caf"
        case .bombShockwave:            return "gdc-bundle/EffectiveTrailer_Booms_Vol2_011.caf"
        case .repairScoutDestroyed:     return "kenney-digital/powerUp8.caf"
        // Shield
        case .shieldAbsorbsHit:         return "kenney-sci-fi/forceField_002.caf"
        case .shieldShatters:           return "kenney-sci-fi/forceField_004.caf"
        // Armored pawn
        case .armorRicochet:            return "gdc-bundle/DSGNErie_NoiseBoxHit_10_InMotionAudio_SinisterTextures4.caf"
        // §23.9 asks for a synthesised transporter shimmer and §10.1 for a
        // brittle shatter, neither of which exists yet. These two stand in:
        // forceField_000 has the right sustained-shimmer character, and
        // zapThreeToneDown falls the way breaking armor should.
        case .armorBreaks:              return "kenney-digital/zapThreeToneDown.caf"
        case .pieceRegenerates:         return "kenney-sci-fi/forceField_000.caf"
        // Game events
        case .levelClear:               return "gdc-bundle/Interface Arp Reveal Down Long.caf"
        case .gameOver:                 return "gdc-bundle/DSGNBass_Bass Drop & Downer Slow 10_344 Audio_Bass Drops & Downers.caf"
        case .mechanicBannerTier1:      return "kenney-digital/phaserUp7.caf"
        case .mechanicBannerTier2:      return "gdc-bundle/DSGNBram____Cinematic Horn Braam, Epic, Cinematic, Dark, Instrument, Huge-32.caf"
        case .mechanicBannerTier3:      return "gdc-bundle/Transition Braam Slow Dark Creepy.caf"
        case .uiButtonClick:            return "gdc-bundle/Button Arp Twinkle.caf"
        case .uiSciFiPing:              return "gdc-bundle/Interface Sci-Fi Ping Down.caf"
        case .ambientSpaceLoop:         return "gdc-bundle/Roomtone Space Ship Interior Muted.caf"
        // Minter ships
        case .camelHonk:                return "generated/camel-honk.caf"
        }
    }

    /// Sounds that should loop (pass numberOfLoops: -1 to AVAudioPlayer)
    var loops: Bool {
        switch self {
        case .scoutEnterLoop, .ambientSpaceLoop,
             .criticalCrackleHigh, .criticalCrackleMid,
             .criticalCrackleLow, .criticalCrackleEerie:
            return true
        default:
            return false
        }
    }

    /// Default playback volume (0.0–1.0)
    var defaultVolume: Float {
        switch self {
        case .ambientSpaceLoop:                     return 0.12
        // §23.9 puts the transporter at ~60% of master: present, not dominant.
        case .pieceRegenerates:                     return 0.6
        case .fleetHeartbeat:                       return 0.55
        case .criticalCrackleHigh, .criticalCrackleMid,
             .criticalCrackleLow, .criticalCrackleEerie: return 0.25
        // Destruction is rare and should always read over the hit that caused
        // it, so the whole family runs at full balance and the mixer's ceiling
        // does the limiting. Measured effective RMS lands at 0.10-0.17 against
        // a 0.10 hit and a 0.08 laser.
        case .pawnDestroyed, .knightDestroyed, .bishopDestroyed,
             .rookDestroyed, .queenDestroyed, .kingDestroyed,
             .playerShipDestroyed, .bombShockwave:  return 1.0
        // Every hit, fatal or not. Sits above the laser so it is never masked
        // by the shot that caused it, and below destruction.
        case .pieceHitLight, .invaderHitsPiece:     return 0.62
        case .pieceSelected, .whitePieceMoves,
             .blackPieceMoves:                      return 0.5
        // A ricochet repeats for as long as the player keeps firing at an
        // armored pawn, which is the same repetition problem as the countdown
        // and the alarm below. It also measures far quieter than it sounds:
        // effective RMS 0.065 against a 0.104 piece hit, but a peak of 0.83 —
        // a crest factor of 8.4 where its neighbours sit near 4. A sharp
        // metallic transient is heard at its peak, not its average. 30% down
        // from the 0.8 default.
        case .armorRicochet:                        return 0.56
        // These two repeat — the countdown twice a beat, the alarm on every
        // re-entry into check — so they are mixed well down. Repetition reads as
        // loudness even when the level is modest.
        case .turnTimerWarning:                     return 0.28
        case .checkAlarm:                           return 0.40
        // Fired several times a second, so the same reasoning applies twice
        // over: at the default 0.8 it sat level with the music and dominated
        // the mix purely through repetition.
        case .playerLaserFire:                      return 0.24
        // Not a repetition problem — laserSmall_001 is simply a quiet file
        // (RMS 0.081 against the player laser's 0.425), and at a matching
        // balance it vanished. Full balance still lands under the player's own
        // shot, which is the right order for a threat cue you must not miss.
        case .invaderLaserFire:                     return 1.0
        // The king's own weapon should cut over ordinary fleet fire.
        case .kingLaserFire:                        return 1.0
        case .crossfireLaserFire:                   return 1.0
        // 30% down from the default. UI clicks are the one family the player
        // triggers deliberately and hears in isolation, with no gunfire under
        // them, so the default balance read as a shout.
        case .uiButtonClick:                        return 0.40
        default:                                    return 0.8
        }
    }
}
