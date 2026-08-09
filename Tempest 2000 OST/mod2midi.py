#!/usr/bin/env python3
"""
Convert Amiga MOD files to MIDI.
Assigns era-appropriate GM instruments (bass, lead, pad, drums) based on
sample name keywords, sample size, and per-channel pitch-range analysis.
"""

import struct, os, sys, glob
from collections import Counter

# ---------------------------------------------------------------------------
# Sample classification
# ---------------------------------------------------------------------------

DRUM_KEYS = ['drum', 'drm', 'beat', 'brk', 'break', 'kick', 'kik', 'bd',
             'snare', 'snar', 'hat', 'hh ', ' hh', 'perc', 'clap', 'tom',
             'crash', 'cym', 'rim', 'hit', 'sl2']
BASS_KEYS = ['bass', 'sub', 'bas ', 'bas.', 'res-bass', 'res_bass']
LEAD_KEYS = ['lead', 'ld.', 'mel', 'synth', 'saw', 'square', 'sqr',
             'bleep', 'techno', 'arp', 'riff']
PAD_KEYS  = ['pad', 'string', 'str.', 'choir', 'chord', 'd-50', 'd50',
             'res1', 'res2', 'res3', 'res4', 'res5', 'atmo']

def classify_sample(name, size):
    n = name.lower()
    if any(k in n for k in DRUM_KEYS):  return 'drums'
    if any(k in n for k in BASS_KEYS):  return 'bass'
    if any(k in n for k in LEAD_KEYS):  return 'lead'
    if any(k in n for k in PAD_KEYS):   return 'pad'
    # size-based fallback for unnamed samples
    if size < 300:    return 'drums'   # tiny = likely a single hit/blip
    if size < 1200:   return 'hit'     # short hit — percussion-adjacent
    if size > 28000:  return 'loop'    # big loop — likely breakbeat or bass loop
    return 'unknown'

# ---------------------------------------------------------------------------
# GM program numbers (0-indexed, General MIDI)
# ---------------------------------------------------------------------------

GM_PROGRAMS = {
    'bass':    38,   # Synth Bass 1
    'bass2':   39,   # Synth Bass 2
    'lead':    80,   # Lead 1 Square  — iconic 90s rave lead
    'lead2':   81,   # Lead 2 Sawtooth
    'pad':     89,   # Pad 2 Warm
    'pad2':    90,   # Pad 3 Polysynth
    'stab':    50,   # Synth Strings 1
    'arp':     87,   # Lead 8 Bass+Lead
    'hit':     55,   # Orchestra Hit  — short stab
    'default': 80,   # Square lead as safe fallback
}

# GM drum notes in priority order when mapping sample slots → percussion
DEFAULT_DRUM_NOTES = [36, 38, 42, 46, 39, 49, 37, 45, 47, 41, 51, 48]
# kick, snare, cl.hat, op.hat, clap, crash, rim, mid-tom, hi-tom, lo-tom, ride, hi-mid-tom

DRUM_NOTE_BY_KEYWORD = {
    'kick': 36, 'kik': 36, ' bd': 36,
    'snare': 38, 'snar': 38,
    'hihat': 42, 'hi-hat': 42, ' hh': 42, 'hh ': 42,
    'open hat': 46, 'op.hat': 46,
    'clap': 39, 'rim': 37,
    'tom': 45, 'crash': 49, 'ride': 51, 'cym': 49,
}

def drum_note_for_sample(name, slot_index):
    n = name.lower()
    for kw, note in DRUM_NOTE_BY_KEYWORD.items():
        if kw in n:
            return note
    return DEFAULT_DRUM_NOTES[slot_index % len(DEFAULT_DRUM_NOTES)]

# ---------------------------------------------------------------------------
# Amiga period → MIDI note
# ---------------------------------------------------------------------------

PERIOD_TABLE = [
    856,808,762,720,678,640,604,570,538,508,480,453,  # C-1..B-1
    428,404,381,360,339,320,302,285,269,254,240,226,  # C-2..B-2
    214,202,190,180,170,160,151,143,135,127,120,113,  # C-3..B-3
]
# C-1 (period 856) → MIDI note 36 (C2)
def period_to_midi(period):
    if period == 0: return None
    best = min(PERIOD_TABLE, key=lambda p: abs(p - period))
    return max(0, min(127, 36 + PERIOD_TABLE.index(best)))

# ---------------------------------------------------------------------------
# MIDI writer helpers
# ---------------------------------------------------------------------------

def var_len(v):
    r = [v & 0x7F]; v >>= 7
    while v: r.insert(0, (v & 0x7F) | 0x80); v >>= 7
    return bytes(r)

def build_track(events):
    events = sorted(events, key=lambda e: e[0])
    data = b''; last = 0
    for tick, msg in events:
        data += var_len(tick - last) + bytes(msg); last = tick
    data += var_len(0) + b'\xff\x2f\x00'
    return b'MTrk' + struct.pack('>I', len(data)) + data

def write_midi(path, tracks, tpb=480):
    hdr = b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), tpb)
    with open(path, 'wb') as f:
        f.write(hdr + b''.join(build_track(t) for t in tracks))

# ---------------------------------------------------------------------------
# Core converter
# ---------------------------------------------------------------------------

def mod_to_midi(mod_path, midi_path):
    with open(mod_path, 'rb') as f:
        data = f.read()

    tag = data[1080:1084]
    num_samples  = 31
    num_channels = 8 if tag in (b'8CHN', b'FLT8') else \
                   6 if tag == b'6CHN' else 4

    # --- read sample metadata ---
    samples = {}  # sample_num (1-based) → dict
    for i in range(num_samples):
        off = 20 + i * 30
        name   = data[off:off+22].rstrip(b'\x00').decode('ascii', errors='replace').strip()
        length = struct.unpack('>H', data[off+22:off+24])[0] * 2
        vol    = data[off+25] if off+25 < len(data) else 64
        if length > 0:
            samples[i+1] = {
                'name': name, 'size': length, 'vol': vol,
                'type': classify_sample(name, length),
            }

    song_length   = data[950]
    pattern_order = list(data[952:952+128])
    pattern_start = 1084
    pattern_size  = 64 * num_channels * 4
    tpb           = 480
    ticks_per_row = 120   # ~125 BPM at MOD default speed 6

    # --- first pass: collect per-channel stats ---
    ch_sample_counts = [Counter() for _ in range(num_channels)]
    ch_periods       = [[] for _ in range(num_channels)]

    for order_pos in range(song_length):
        pat_off = pattern_start + pattern_order[order_pos] * pattern_size
        if pat_off + pattern_size > len(data): break
        for row in range(64):
            for ch in range(num_channels):
                cell = pat_off + (row * num_channels + ch) * 4
                b0,b1,b2,b3 = data[cell:cell+4]
                snum   = (b0 & 0xF0) | ((b2 & 0xF0) >> 4)
                period = ((b0 & 0x0F) << 8) | b1
                if snum > 0 and snum in samples:
                    ch_sample_counts[ch][snum] += 1
                if period > 0:
                    ch_periods[ch].append(period)

    # --- classify each channel ---
    # Compute pitch stats for every channel first, used in classification
    ch_stats = []
    for ch in range(num_channels):
        periods = ch_periods[ch]
        if not periods:
            ch_stats.append({'n': 0, 'median': 0, 'p75': 0, 'distinct': 0})
            continue
        s = sorted(periods)
        n = len(s)
        ch_stats.append({
            'n':       n,
            'median':  s[n // 2],
            'p75':     s[3 * n // 4],
            'distinct': len(set(periods)),
        })

    def channel_type_raw(ch):
        counts = ch_sample_counts[ch]
        if not counts:
            return 'unknown'

        # Name-based: if dominant sample has a keyword-matched type, trust it
        dominant_snum = counts.most_common(1)[0][0]
        s = samples.get(dominant_snum, {})
        name_type = s.get('type', 'unknown')
        if name_type in ('drums', 'bass', 'lead', 'pad'):
            return name_type

        # Pitch-variance drums heuristic:
        # Very few distinct pitches + many notes + small dominant sample → rhythm trigger
        st = ch_stats[ch]
        dom_size = s.get('size', 9999)
        if st['distinct'] <= 4 and st['n'] > 80 and dom_size < 2500:
            return 'drums'

        # Sparse low-register channel → pad accent
        if st['n'] < 100 and st['median'] > 320:
            return 'pad'

        # Pitch-range for everything else (bass / lead)
        # p75 > 380 means the lower 75% of notes sit in the bass register
        if st['p75'] > 380:
            return 'bass'
        if st['median'] < 210:
            return 'lead_high'   # upper octave arp/lead
        return 'lead'

    raw_types = [channel_type_raw(ch) for ch in range(num_channels)]

    # Enforce at most one bass channel per file:
    # If multiple raw 'bass', keep the one with the highest p75; demote others to 'lead'.
    bass_chs = [ch for ch, t in enumerate(raw_types) if t == 'bass']
    if len(bass_chs) > 1:
        best_bass = max(bass_chs, key=lambda ch: ch_stats[ch]['p75'])
        for ch in bass_chs:
            if ch != best_bass:
                raw_types[ch] = 'lead'

    ch_types = raw_types

    # assign GM programs and MIDI channels
    # drums → MIDI ch 9; melodic → 0,1,2,... (skip 9)
    lead_count = 0
    pad_count  = 0
    midi_ch_map   = {}  # MOD channel → MIDI channel
    midi_prog_map = {}  # MOD channel → GM program (None = drums ch 9)
    melodic_midi_ch = 0

    for ch, t in enumerate(ch_types):
        if t == 'drums':
            midi_ch_map[ch]   = 9
            midi_prog_map[ch] = None
        elif t == 'bass':
            if melodic_midi_ch == 9: melodic_midi_ch += 1
            midi_ch_map[ch]   = melodic_midi_ch; melodic_midi_ch += 1
            midi_prog_map[ch] = GM_PROGRAMS['bass']
        elif t == 'pad':
            if melodic_midi_ch == 9: melodic_midi_ch += 1
            midi_ch_map[ch]   = melodic_midi_ch; melodic_midi_ch += 1
            midi_prog_map[ch] = GM_PROGRAMS['pad'] if pad_count == 0 else GM_PROGRAMS['pad2']
            pad_count += 1
        elif t == 'lead_high':
            if melodic_midi_ch == 9: melodic_midi_ch += 1
            midi_ch_map[ch]   = melodic_midi_ch; melodic_midi_ch += 1
            midi_prog_map[ch] = GM_PROGRAMS['arp']   # Lead 8 Bass+Lead — good for high arps
            lead_count += 1
        else:  # lead, unknown, loop, hit, default
            if melodic_midi_ch == 9: melodic_midi_ch += 1
            midi_ch_map[ch]   = melodic_midi_ch; melodic_midi_ch += 1
            midi_prog_map[ch] = GM_PROGRAMS['lead'] if lead_count == 0 else GM_PROGRAMS['lead2']
            lead_count += 1
        if melodic_midi_ch > 15: melodic_midi_ch = 0  # safety wrap

    # build drum note map: sample_num → GM drum note
    drum_samples_ordered = []
    for ch in range(num_channels):
        if midi_ch_map[ch] == 9:
            for snum, _ in ch_sample_counts[ch].most_common():
                if snum not in drum_samples_ordered:
                    drum_samples_ordered.append(snum)
    drum_note_map = {}
    for slot, snum in enumerate(drum_samples_ordered):
        name = samples[snum]['name'] if snum in samples else ''
        drum_note_map[snum] = drum_note_for_sample(name, slot)

    # --- second pass: generate MIDI events ---
    ch_events  = [[] for _ in range(num_channels)]
    active     = [None] * num_channels
    cur_tpr    = ticks_per_row

    for order_pos in range(song_length):
        pat_off = pattern_start + pattern_order[order_pos] * pattern_size
        if pat_off + pattern_size > len(data): break

        for row in range(64):
            tick = order_pos * 64 * cur_tpr + row * cur_tpr

            for ch in range(num_channels):
                cell = pat_off + (row * num_channels + ch) * 4
                b0,b1,b2,b3 = data[cell:cell+4]
                snum   = (b0 & 0xF0) | ((b2 & 0xF0) >> 4)
                period = ((b0 & 0x0F) << 8) | b1
                effect = b2 & 0x0F
                param  = b3

                # Fxx: set speed/BPM
                if effect == 0xF and param > 0:
                    cur_tpr = max(10, tpb * param // 24) if param <= 0x1F \
                              else max(10, tpb * 6 * 60 // (param * 24))

                if period == 0: continue
                midi_ch = midi_ch_map[ch]
                is_drum = (midi_ch == 9)

                if is_drum:
                    note = drum_note_map.get(snum, 36)
                    vel  = min(127, max(30, samples[snum]['vol'] * 2)) if snum in samples else 90
                    # drums: short notes
                    ch_events[ch].append((tick,          [0x99, note, vel]))
                    ch_events[ch].append((tick + cur_tpr//2, [0x89, note, 0]))
                else:
                    note = period_to_midi(period)
                    if note is None: continue
                    vel  = min(127, max(30, samples[snum]['vol'] * 2)) if snum in samples else 90

                    if active[ch] is not None:
                        ch_events[ch].append((tick, [0x80 | midi_ch, active[ch], 0]))
                    ch_events[ch].append((tick, [0x90 | midi_ch, note, vel]))
                    active[ch] = note

    # close open notes
    end_tick = song_length * 64 * cur_tpr
    for ch in range(num_channels):
        if active[ch] is not None:
            midi_ch = midi_ch_map[ch]
            ch_events[ch].append((end_tick, [0x80 | midi_ch, active[ch], 0]))

    # --- assemble tracks ---
    tempo_us = 500000  # 120 BPM
    tempo_track = [(0, [0xFF, 0x51, 0x03,
                        (tempo_us>>16)&0xFF, (tempo_us>>8)&0xFF, tempo_us&0xFF])]

    tracks = [tempo_track]
    for ch in range(num_channels):
        midi_ch = midi_ch_map[ch]
        prog    = midi_prog_map[ch]
        evts    = []
        if prog is not None:
            evts.append((0, [0xC0 | midi_ch, prog]))
        evts += ch_events[ch]
        tracks.append(evts)

    write_midi(midi_path, tracks, tpb)

    # summary
    ch_summary = ', '.join(
        f'ch{i}={ch_types[i]}(midi{midi_ch_map[i]}' +
        (f'/prog{midi_prog_map[i]})' if midi_prog_map[i] is not None else '/drums)')
        for i in range(num_channels)
    )
    return song_length, num_channels, ch_summary


if __name__ == '__main__':
    target = os.path.dirname(os.path.abspath(__file__))
    files  = sorted(glob.glob(os.path.join(target, '*.mod')))
    if not files:
        print('No .mod files found.'); sys.exit(1)

    for mod_path in files:
        midi_path = os.path.splitext(mod_path)[0] + '.mid'
        name = os.path.basename(mod_path)
        try:
            length, channels, summary = mod_to_midi(mod_path, midi_path)
            size = os.path.getsize(midi_path)
            print(f'OK  {name}  ({size} bytes)')
            print(f'    {summary}')
        except Exception as e:
            import traceback
            print(f'ERR {name}: {e}')
            traceback.print_exc()
