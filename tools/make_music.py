"""Knightly, epic music made from code (no downloads):

  music_battle.wav  - the action phase: war drums, timpani, fast strings,
                      a heroic horn melody and brass fanfares (D minor, 132 bpm)
  music_plan.wav    - the planning phase: a tense, thinking march - heartbeat
                      drums, harp arpeggios, low strings, distant horn calls
  music_base.wav    - the village: a medieval folk tune on lute and recorder
                      over a hurdy-gurdy drone, with tambourine
  fanfare.wav / lose.wav - brass victory fanfare and a sad defeat call

  python3 tools/make_music.py
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(11)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lowpass(x, cutoff):
    """One-pole low-pass, vectorised through an exponential filter in blocks."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    # simple loop is fast enough for our lengths when done on chunks
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.1):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na)
    nd2 = min(nd, max(0, n - na))
    e[na:na + nd2] = np.linspace(1, s, nd2)
    if nr > 0 and n > nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def saw(f, n, detune=0.0):
    t = np.arange(n) / SR
    ph = (f * (1 + detune)) * t
    return 2 * (ph % 1) - 1


# ---------------------------------------------------------------- instruments

def brass(m, dur, vel=1.0):
    """A section of horns: 3 detuned saws, slow attack, vibrato, warm filter."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.3, 0, 1)
    f = hz(m)
    x = sum(2 * ((np.cumsum(np.full(n, f * (1 + d)) * vib) / SR) % 1) - 1 for d in (-0.004, 0.0, 0.005)) / 3
    x = lowpass(x, 900 + 1500 * vel)
    return x * adsr(n, 0.06, 0.15, 0.85, min(0.2, dur * 0.3)) * vel


def strings(m, dur, vel=1.0, attack=0.01):
    n = int(dur * SR)
    x = (saw(hz(m), n, -0.003) + saw(hz(m), n, 0.004)) / 2
    x = lowpass(x, 1800)
    return x * adsr(n, attack, 0.05, 0.75, min(0.06, dur * 0.4)) * vel


def pluck(m, dur, vel=1.0, bright=0.5):
    """Karplus-Strong plucked string (lute / harp)."""
    n = int(dur * SR)
    p = max(2, int(SR / hz(m)))
    buf = rng.uniform(-1, 1, p)
    out = np.empty(n)
    damp = 0.996 - (1 - bright) * 0.01
    for i in range(n):
        j = i % p
        out[i] = buf[j]
        buf[j] = damp * 0.5 * (buf[j] + buf[(j + 1) % p])
    return out * vel * adsr(n, 0.001, 0.02, 1.0, 0.03)


def recorder(m, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 + 0.003 * np.sin(2 * np.pi * 5 * t))
    ph = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * ph) + 0.2 * np.sin(4 * np.pi * ph) + 0.05 * rng.uniform(-1, 1, n)
    return x * adsr(n, 0.04, 0.05, 0.8, 0.05) * vel


def drone(m, dur, vel=1.0):
    n = int(dur * SR)
    x = (saw(hz(m), n) + 0.6 * saw(hz(m + 7), n, 0.002)) / 1.6
    return lowpass(x, 700) * vel * adsr(n, 0.2, 0.1, 1.0, 0.2)


def timpani(m, vel=1.0):
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 + 0.15 * np.exp(-t * 25))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR)
    x += lowpass(rng.uniform(-1, 1, n), 400) * np.exp(-t * 30) * 2
    return x * np.exp(-t * 4.5) * vel


def war_drum(vel=1.0):
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    f = 70 * (1 + 1.5 * np.exp(-t * 40))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + lowpass(rng.uniform(-1, 1, n), 300) * np.exp(-t * 20)
    return x * np.exp(-t * 7) * vel


def snare(vel=1.0):
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    x = lowpass(rng.uniform(-1, 1, n), 4000) * 0.8 + 0.4 * np.sin(2 * np.pi * 190 * t)
    return x * np.exp(-t * 22) * vel


def tambourine(vel=1.0):
    n = int(0.15 * SR)
    t = np.arange(n) / SR
    x = rng.uniform(-1, 1, n)
    x = x - lowpass(x, 5000)
    return x * np.exp(-t * 25) * vel


# ---------------------------------------------------------------- mixing

class Track:
    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * SR) + SR)

    def add(self, x, at, gain=1.0):
        s = int(at * SR)
        e = min(len(self.buf), s + len(x))
        if e > s:
            self.buf[s:e] += x[: e - s] * gain

    def render(self, seconds):
        out = self.buf[: int(seconds * SR)].copy()
        # simple room: a few soft echoes
        for d, g in ((0.031, 0.25), (0.053, 0.18), (0.097, 0.12), (0.149, 0.08)):
            k = int(d * SR)
            out[k:] += out[:-k] * g
        return out


def save(name, x, vol=0.85, fade=0.03):
    f = int(SR * fade)
    x = x.copy()
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    x = np.tanh(x / (np.max(np.abs(x)) or 1) * 1.4) / np.tanh(1.4) * vol
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, round(len(x) / SR, 1), "s")


MINOR = {"Dm": [50, 53, 57], "C": [48, 52, 55], "Bb": [46, 50, 53], "A": [45, 49, 52], "F": [41, 45, 48],
         "G": [43, 47, 50], "Gm": [43, 46, 50], "Am": [45, 48, 52], "D": [50, 54, 57]}


def battle():
    bpm = 132
    b = 60 / bpm
    prog = ["Dm", "C", "Bb", "A"] * 2 + ["Dm", "Bb", "C", "A"] * 2   # 16 bars
    total = len(prog) * 4 * b
    tr = Track(total)
    melody_a = [(74, 1), (69, .5), (74, .5), (77, 1), (76, .5), (74, .5), (72, 1), (74, .5), (76, .5), (77, 1.5), (None, .5),
                (79, 1), (77, .5), (76, .5), (74, 1), (72, 1), (73, 3), (None, 1)]
    melody_b = [(69, .5), (74, .5), (77, 1), (81, 2), (79, .5), (77, .5), (76, 1), (72, 2), (70, .5), (74, .5), (77, 1), (82, 1.5), (81, .5),
                (81, 2), (79, 1), (73, 1)]
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * b
        root = MINOR[ch][0]
        # fast strings ostinato (8ths)
        pat = [0, 0, 12, 0, 7, 0, 12, 7]
        for i, iv in enumerate(pat):
            tr.add(strings(root - 12 + iv, b * 0.45, 0.5), t0 + i * b / 2, 0.55)
        # drums: boom on 1 and 3, snare on 2 and 4, a roll every 4 bars
        tr.add(timpani(root - 12, 1.0), t0, 0.9)
        tr.add(war_drum(0.9), t0 + 2 * b, 0.8)
        for q in (1, 3):
            tr.add(snare(0.6), t0 + q * b, 0.5)
        if bar % 4 == 3:
            for k in range(8):
                tr.add(snare(0.3 + k * 0.08), t0 + 3 * b + k * b / 8, 0.45)
        # brass chords swell in the second half
        if bar >= 8:
            for m in MINOR[ch]:
                tr.add(brass(m + 12, 4 * b * 0.95, 0.55), t0, 0.35)
        else:
            tr.add(brass(root, 4 * b * 0.95, 0.45), t0, 0.3)
    # heroic horn melody: A over bars 0-3 and 4-7, fanfare B over 8-11 and 12-15
    for start_bar, mel, octv in ((0, melody_a, -12), (4, melody_a, 0), (8, melody_b, 0), (12, melody_b, 0)):
        t = start_bar * 4 * b
        for m, beats in mel:
            if m is not None:
                tr.add(brass(m + octv, beats * b * 0.95, 1.0), t, 0.7)
            t += beats * b
    save("music_battle", tr.render(total), 0.8)


def plan():
    bpm = 84
    b = 60 / bpm
    prog = ["Dm", "F", "C", "G", "Dm", "Bb", "Gm", "A"] * 2
    total = len(prog) * 4 * b
    tr = Track(total)
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * b
        notes = MINOR[ch]
        # low strings pad
        for m in notes[:2]:
            tr.add(strings(m - 12, 4 * b, 0.35, attack=0.4), t0, 0.5)
        # harp arpeggio up and down
        arp = [notes[0], notes[1], notes[2], notes[0] + 12, notes[2] + 12, notes[0] + 12, notes[2], notes[1]]
        for i, m in enumerate(arp):
            tr.add(pluck(m + 12, b * 1.5, 0.6, 0.7), t0 + i * b / 2, 0.45)
        # heartbeat drum
        tr.add(war_drum(0.7), t0, 0.6)
        tr.add(war_drum(0.45), t0 + 0.6 * b, 0.5)
        tr.add(war_drum(0.7), t0 + 2 * b, 0.6)
        tr.add(war_drum(0.45), t0 + 2.6 * b, 0.5)
        # distant horn call every 4 bars
        if bar % 4 == 0:
            tr.add(brass(notes[0] + 12, b * 1.2, 0.6), t0 + b, 0.35)
            tr.add(brass(notes[0] + 19, b * 2.2, 0.6), t0 + 2.2 * b, 0.35)
    save("music_plan", tr.render(total), 0.65)


def base():
    bpm = 104
    b = 60 / bpm
    prog = ["G", "G", "F", "G", "G", "C", "F", "G"] * 2
    total = len(prog) * 4 * b
    tr = Track(total)
    tune = [(67, 1), (71, .5), (72, .5), (74, 1), (72, .5), (71, .5), (69, 1), (67, .5), (69, .5), (71, 2),
            (72, 1), (71, .5), (69, .5), (67, 1), (65, 1), (67, 3), (None, 1),
            (74, 1), (76, .5), (77, .5), (79, 1), (77, .5), (76, .5), (74, 1), (72, .5), (71, .5), (72, 2),
            (71, 1), (69, .5), (67, .5), (65, 1), (69, 1), (67, 3), (None, 1)]
    tr.add(drone(43, total, 0.5), 0, 0.35)
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * b
        notes = MINOR[ch]
        for q in range(4):
            tr.add(pluck(notes[q % 3] - 12, b * 1.2, 0.5, 0.4), t0 + q * b, 0.35)   # lute strums
        tr.add(tambourine(0.6), t0 + b, 0.3)
        tr.add(tambourine(0.6), t0 + 3 * b, 0.3)
        tr.add(tambourine(0.3), t0 + 3.5 * b, 0.25)
        tr.add(war_drum(0.35), t0, 0.35)
    # tune: lute the first time, recorder the second
    for rep in range(2):
        t = rep * 8 * 4 * b
        for m, beats in tune:
            if m is not None:
                if rep == 0:
                    tr.add(pluck(m, beats * b * 1.4, 0.9, 0.6), t, 0.7)
                else:
                    tr.add(recorder(m + 12, beats * b * 0.95, 0.8), t, 0.45)
                    tr.add(pluck(m, beats * b * 1.2, 0.5, 0.6), t, 0.3)
            t += beats * b
    save("music_base", tr.render(total), 0.6)


def stings():
    b = 60 / 120
    tr = Track(3.2)
    seq = [(67, 0, .3), (67, .33, .3), (67, .66, .3), (72, 1.0, 1.0), (71, 1.9, .3), (72, 2.2, 1.0)]
    for m, s, d in seq:
        tr.add(brass(m, d * 1.1, 1.0), s, 0.7)
        tr.add(brass(m - 12, d * 1.1, 0.6), s, 0.4)
    for m in (48, 52, 55):
        tr.add(brass(m + 12, 1.2, 0.6), 2.0, 0.35)
    tr.add(timpani(36, 1.0), 1.0, 0.8)
    tr.add(timpani(36, 1.0), 2.2, 0.9)
    save("fanfare", tr.render(3.2), 0.8, fade=0.01)
    tr = Track(2.6)
    for i, m in enumerate([62, 61, 60, 57]):
        tr.add(brass(m, 0.55 if i < 3 else 1.3, 0.7), i * 0.5, 0.6)
    tr.add(timpani(38, 0.7), 1.5, 0.6)
    save("lose", tr.render(2.6), 0.6, fade=0.01)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    battle()
    plan()
    base()
    stings()
