#!/usr/bin/env python3
"""Generates GCI's explosion SFX into Resources/sfx/generated/.

Run:  python3 make_explosions.py

The library bundles we draw from have no usable explosion, and the metal-impact
placeholder that stood in for every destruction read as a light "tink" rather
than a kill. These are synthesised instead: a decaying noise burst pushed
through a falling low-pass, plus a pitch-dropping sine "thump" for body — the
standard recipe for an arcade explosion, and the same approach the design doc
assumes for the other `generated/` sounds (§12.12).

Stdlib only (no numpy), then afconvert to .caf, matching the pipeline documented
in SoundKey.swift. Deterministic: the RNG is seeded, so re-running reproduces
byte-identical audio.
"""

import array
import math
import os
import random
import struct
import subprocess
import wave

RATE = 44100
OUT_DIR = "GalacticChessInvaders/Resources/sfx/generated"


def synth(duration, tau, cut_hi, cut_lo, thump_hi, thump_lo, thump_amp, seed):
    """A noise burst + falling thump, low-passed with a sweeping cutoff.

    duration  seconds
    tau       envelope decay constant; smaller = snappier
    cut_hi/lo low-pass cutoff at start/end (Hz) — the sweep is what turns
              a hiss into a boom collapsing in on itself
    thump_*   the sine body: frequency start/end (Hz) and amplitude
    """
    rng = random.Random(seed)
    count = int(RATE * duration)
    samples = array.array("h")
    lowpassed = 0.0
    phase = 0.0

    for i in range(count):
        t = i / RATE
        progress = i / count
        env = math.exp(-t / tau)

        # Noise through a one-pole low-pass whose cutoff falls as it decays.
        cutoff = cut_hi + (cut_lo - cut_hi) * progress
        alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
        lowpassed += alpha * (rng.uniform(-1.0, 1.0) - lowpassed)

        # Sine body, frequency sliding down. Phase-accumulated rather than
        # sin(2*pi*f(t)*t), which would warp the pitch as f changes.
        freq = thump_hi + (thump_lo - thump_hi) * progress
        phase += 2.0 * math.pi * freq / RATE
        thump = math.sin(phase) * thump_amp * (env ** 1.5)

        value = (lowpassed * 2.4 * env) + thump
        # Soft clip for punch without hard digital edges.
        value = math.tanh(value * 1.3)
        samples.append(int(max(-1.0, min(1.0, value)) * 32000))

    return samples


def write_caf(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    wav_path = os.path.join(OUT_DIR, name + ".wav")
    caf_path = os.path.join(OUT_DIR, name + ".caf")

    with wave.open(wav_path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(samples.tobytes())

    subprocess.run(["afconvert", wav_path, "-f", "caff", "-d", "LEI16", caf_path],
                   check=True)
    os.remove(wav_path)
    size = os.path.getsize(caf_path)
    print(f"  {caf_path}  ({size/1024:.0f} KB, {len(samples)/RATE:.2f}s)")


VOICES = {
    # Pawn / knight / bishop — snappy, brighter, gets out of the way fast.
    "explosion-small": dict(duration=0.38, tau=0.075, cut_hi=5200, cut_lo=700,
                            thump_hi=190, thump_lo=70, thump_amp=0.55, seed=11),
    # Rook / queen — bigger, deeper, more weight behind it.
    "explosion-large": dict(duration=0.85, tau=0.20, cut_hi=3600, cut_lo=380,
                            thump_hi=140, thump_lo=48, thump_amp=0.75, seed=23),
    # King — §12: "long dramatic explosion, noise + falling pitch sweep, ~2s".
    "explosion-king": dict(duration=2.0, tau=0.62, cut_hi=2800, cut_lo=180,
                           thump_hi=120, thump_lo=32, thump_amp=0.9, seed=37),
    # The player's ship dying — harsher and more mechanical than a piece.
    "ship-destroyed": dict(duration=1.1, tau=0.28, cut_hi=4200, cut_lo=260,
                           thump_hi=210, thump_lo=40, thump_amp=0.8, seed=53),
}

if __name__ == "__main__":
    print("Generating explosion SFX:")
    for name, params in VOICES.items():
        write_caf(name, synth(**params))
    print("Done.")
