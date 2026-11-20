"""Makes every sound of the game from code (no downloads needed).

  python3 tools/make_sounds.py        -> assets/audio/*.wav

Sound effects, two music loops (base + battle, medieval style) and
gibberish "voice" syllables for the characters (like the funny
mumbling in many cartoon games). 22 kHz mono 16-bit WAV.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.1, curve=3.0):
    e = np.ones(n)
    na = max(1, int(SR * a))
    e[:na] = np.linspace(0, 1, na)
    x = np.linspace(0, 1, n)
    e *= (1 - x) ** curve if r is None else np.clip((1 - x) ** curve, 0, 1)
    return e


def tone(freq, d, kind="sine"):
    tt = t(d)
    f = np.full_like(tt, freq) if np.isscalar(freq) else freq
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if kind == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, k=0.1):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def save(name, x, vol=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1
    x = x / peak * vol
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, sec, total):
    out = np.zeros(int(SR * total))
    s = int(SR * sec)
    out[s: s + len(x)] += x[: max(0, len(out) - s)]
    return out


def note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def sfx():
    save("click", tone(900, 0.04, "square") * env(int(SR * 0.04), r=None, curve=4), 0.5)
    save("select", tone(np.linspace(600, 900, int(SR * 0.08)), 0.08, "tri") * env(int(SR * 0.08)), 0.5)
    save("order", mix(tone(520, 0.06, "tri") * env(int(SR * .06)), at(tone(780, 0.07, "tri") * env(int(SR * .07)), 0.05, 0.12)), 0.5)
    save("deny", tone(np.linspace(220, 150, int(SR * 0.2)), 0.2, "square") * env(int(SR * 0.2), curve=1.5), 0.45)
    d = 0.5
    save("summon", mix(tone(np.linspace(300, 1200, int(SR * d)), d, "tri") * env(int(SR * d), curve=1.2) * 0.6,
                       lowpass(noise(d), 0.3) * env(int(SR * d), curve=2) * 0.4), 0.6)
    # horn: two brassy notes
    hn = lambda f, dd: (tone(f, dd, "saw") * 0.6 + tone(f * 2, dd, "saw") * 0.2) * env(int(SR * dd), a=0.05, curve=0.6)
    save("horn", lowpass(mix(hn(196, 0.45), at(hn(294, 0.9), 0.4, 1.3)), 0.08), 0.7)
    save("hit", mix(lowpass(noise(0.12), 0.35) * env(int(SR * .12), a=0.001, curve=5), tone(np.linspace(180, 70, int(SR * .12)), .12) * env(int(SR * .12), curve=3) * 0.7), 0.6)
    save("bow", mix(tone(np.linspace(900, 300, int(SR * 0.12)), 0.12, "tri") * env(int(SR * .12)) * 0.5, lowpass(noise(0.15), 0.6) * env(int(SR * .15), curve=4) * 0.5), 0.45)
    save("zap", tone(np.linspace(1400, 400, int(SR * 0.18)), 0.18, "square") * env(int(SR * 0.18), curve=2) * (0.6 + 0.4 * tone(40, 0.18)), 0.4)
    save("poof", lowpass(noise(0.35), 0.15) * env(int(SR * 0.35), a=0.01, curve=2), 0.6)
    d = 1.2
    save("crash", mix(lowpass(noise(d), 0.12) * env(int(SR * d), a=0.002, curve=1.8),
                      tone(np.linspace(90, 40, int(SR * d)), d) * env(int(SR * d), curve=2) * 0.8), 0.9)
    save("coin", mix(tone(1320, 0.08, "square") * env(int(SR * .08)) * 0.5, at(tone(1760, 0.2, "square") * env(int(SR * .2)) * 0.5, 0.06, 0.28)), 0.35)
    d = 0.8
    sh = mix(*[at(tone(f, 0.5, "sine") * env(int(SR * .5), curve=2) * 0.3, i * 0.05, d) for i, f in enumerate([1800, 2400, 2100, 2900, 2600])])
    save("ice", mix(sh, lowpass(noise(d), 0.5) * env(int(SR * d), curve=3) * 0.3), 0.6)
    d = 1.0
    save("boom", mix(lowpass(noise(d), 0.08) * env(int(SR * d), a=0.002, curve=2.2), tone(np.linspace(110, 35, int(SR * d)), d) * env(int(SR * d), curve=2.5)), 0.95)
    d = 0.9
    save("heal", mix(*[at(tone(note(n), 0.5, "sine") * env(int(SR * .5), a=0.02, curve=1.5) * 0.4, i * 0.1, d) for i, n in enumerate([72, 76, 79, 84])]), 0.5)
    d = 0.6
    save("power", mix(tone(np.linspace(200, 800, int(SR * d)), d, "saw") * env(int(SR * d), a=0.05, curve=1.5) * 0.4, lowpass(noise(d), 0.25) * env(int(SR * d), curve=1.2) * 0.4), 0.55)
    d = 1.0
    save("upgrade", mix(*[at(tone(note(n), 0.4, "tri") * env(int(SR * .4)) * 0.5, i * 0.12, d) for i, n in enumerate([60, 64, 67, 72])], at(lowpass(noise(0.3), 0.3) * env(int(SR * .3)) * 0.2, 0.0, d)), 0.6)
    # fanfare (victory)
    d = 2.2
    seq = [(67, 0, .15), (67, .15, .15), (67, .3, .15), (72, .45, .9), (71, 1.1, .2), (72, 1.3, .9)]
    br = lambda n, dd: (tone(note(n), dd, "saw") * 0.5 + tone(note(n) * 2, dd, "saw") * 0.15) * env(int(SR * dd), a=0.02, curve=0.8)
    save("fanfare", lowpass(mix(*[at(br(n, dd), s, d) for n, s, dd in seq], *[at(br(n - 12, 1.0) * 0.5, 1.2, d) for n in [60, 64]]), 0.15), 0.8)
    d = 1.6
    seq = [(64, 0, .35), (63, .35, .35), (62, .7, .35), (61, 1.05, .55)]
    save("lose", lowpass(mix(*[at(tone(note(n - 12), dd, "saw") * env(int(SR * dd), a=0.02, curve=1.0), s, d) for n, s, dd in seq]), 0.1), 0.6)
    d = 0.9
    save("chest", mix(lowpass(noise(0.2), 0.2) * env(int(SR * .2)), at(mix(*[at(tone(note(n), 0.4, "square") * env(int(SR * .4)) * 0.3, i * 0.07, 0.8) for i, n in enumerate([76, 79, 83, 88])]), 0.15, d)), 0.6)
    save("reward", mix(*[at(tone(note(n), 0.3, "tri") * env(int(SR * .3)) * 0.4, i * 0.08, 0.6) for i, n in enumerate([84, 88, 91])]), 0.5)
    save("build", mix(*[at(lowpass(noise(0.08), 0.4) * env(int(SR * .08), a=0.001, curve=4) + tone(160, 0.08) * env(int(SR * .08), curve=4) * 0.5, i * 0.18, 0.7) for i in range(3)]), 0.7)


def voices():
    """Gibberish syllables: a short buzzy vowel with a formant, at several pitches."""
    formants = [(730, 1090), (270, 2290), (300, 870), (530, 1840), (570, 840), (440, 1020)]
    for i in range(10):
        d = rng.uniform(0.09, 0.16)
        n = int(SR * d)
        f0 = 220 * rng.uniform(0.85, 1.25) * np.linspace(1.0, rng.uniform(0.85, 1.2), n)
        src = tone(f0, d, "saw")
        f1, f2 = formants[i % len(formants)]
        x = src * (0.6 + 0.4 * np.sin(2 * np.pi * f1 * t(d))) + 0.3 * np.sin(2 * np.pi * f2 * t(d)) * src
        x = lowpass(x, 0.35) * env(n, a=0.01, curve=1.2)
        save("voice_%d" % i, x, 0.55)


def music(name, bpm, scale, chords, bars, lead_density, drums):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    n = int(SR * total)
    out = np.zeros(n)
    r = np.random.default_rng(len(name))
    for b in range(bars):
        root = chords[b % len(chords)]
        start = b * 4 * beat
        # drone / pad (fifth)
        for k, iv in enumerate([0, 7, 12]):
            p = tone(note(root - 12 + iv), 4 * beat, "tri") * env(int(SR * 4 * beat), a=0.3, curve=0.3) * (0.22 if k < 2 else 0.1)
            out += at(p, start, total)[:n]
        # lute-like plucks on the beat
        for q in range(8):
            if r.random() < lead_density:
                deg = r.integers(0, len(scale))
                nn = root + scale[deg] + (12 if r.random() < 0.4 else 0)
                dd = beat * 0.5
                pl = (tone(note(nn), dd * 1.6, "saw") * 0.4 + tone(note(nn) * 2, dd * 1.6, "sine") * 0.2) * env(int(SR * dd * 1.6), a=0.003, curve=3)
                out += at(lowpass(pl, 0.25), start + q * dd, total)[:n]
        if drums:
            for q in range(4):
                kick = tone(np.linspace(120, 45, int(SR * 0.18)), 0.18) * env(int(SR * .18), curve=3) * 0.7
                out += at(kick, start + q * beat, total)[:n]
                if q % 2 == 1:
                    sn = lowpass(noise(0.15), 0.5) * env(int(SR * .15), a=0.001, curve=4) * 0.35
                    out += at(sn, start + q * beat, total)[:n]
                if drums > 1:
                    hat = noise(0.05) * env(int(SR * .05), curve=5) * 0.12
                    out += at(hat, start + (q + 0.5) * beat, total)[:n]
    # smooth loop edges
    f = int(SR * 0.05)
    out[:f] *= np.linspace(0, 1, f)
    out[-f:] *= np.linspace(1, 0, f)
    save(name, out, 0.55)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    voices()
    dorian = [0, 2, 3, 5, 7, 9, 10]
    music("music_base", 92, dorian, [50, 50, 53, 48, 50, 55, 53, 48], 16, 0.45, 0)
    music("music_battle", 132, [0, 2, 3, 5, 7, 8, 10], [45, 45, 48, 43, 45, 41, 43, 40], 16, 0.7, 2)
    print("sounds written to", os.path.abspath(OUT))
