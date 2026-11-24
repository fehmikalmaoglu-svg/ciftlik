"""Çiftliğim 3D: ortam seslerini koddan üretir (telifsiz, tamamen sentez).

Kullanım: python tools/make_audio.py   ->  assets/audio/*.wav
Döngüler dikişsiz olsun diye her parçanın sonu başıyla çapraz geçişlenir.
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def env_adsr(n, a, d, s, r):
    t = np.arange(n) / SR
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na)
    nd = min(nd, n - na)
    e[na:na + nd] = np.linspace(1, s, nd)
    if nr > 0 and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def tone(freq, dur, kind="sine", decay=None, a=0.005, r=0.08):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ph = 2 * np.pi * freq * t
    if kind == "sine":
        w = np.sin(ph)
    elif kind == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(ph))
    elif kind == "pluck":   # sıcak, marimba benzeri
        w = np.sin(ph) + 0.3 * np.sin(2 * ph) * np.exp(-t * 9) + 0.15 * np.sin(4 * ph) * np.exp(-t * 20)
    else:
        w = np.sin(ph)
    e = np.exp(-t * decay) if decay else env_adsr(n, a, 0.1, 0.8, r)
    if decay:
        e *= np.minimum(1, t / max(a, 1e-4))
    return w * e


def add(buf, sig, start):
    i = int(start * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[:j - i]
    if i + len(sig) > len(buf):   # döngü: taşan kuyruk başa sarar
        rest = sig[len(buf) - i:]
        buf[:len(rest)] += rest


def seamless(sig, n, fade=0.3):
    """sig n + fade uzunluğunda: kuyruğu başa yumuşakça karıştır, n uzunluğunda dikişsiz döngü ver."""
    f = int(fade * SR)
    out = sig[:n].copy()
    ramp = np.linspace(0, 1, f)
    out[:f] = out[:f] * ramp + sig[n:n + f] * (1 - ramp)
    return out


def save(name, buf, peak=0.7):
    buf = buf / (np.max(np.abs(buf)) + 1e-9) * peak
    data = (np.clip(buf, -1, 1) * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, round(len(buf) / SR, 1), "sn")


def song(chords, bpm, bars_per_chord, octave, melody_density, seed, pad_gain, brightness):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * bars_per_chord * len(chords)
    buf = np.zeros(int(total * SR))
    penta = [0, 2, 4, 7, 9]
    t = 0.0
    last = 2
    for root, quality in chords:
        third = 3 if quality == "m" else 4
        dur = bar * bars_per_chord
        # yumuşak pad: kökten akor, hafif ayarsız iki ses
        for iv in [0, third, 7, 12]:
            f = midi(root + 12 * (octave - 1) + iv)
            for det in (-0.8, 0.8):
                add(buf, pad_gain * tone(f + det, dur, "sine", a=0.6, r=0.6) * 0.12, t)
        # bas: her ölçünün başında
        for b in range(bars_per_chord):
            add(buf, 0.35 * tone(midi(root + 12 * (octave - 2)), bar * 0.9, "pluck", decay=2.2), t + b * bar)
            add(buf, 0.2 * tone(midi(root + 12 * (octave - 2) + 7), bar * 0.45, "pluck", decay=3.0), t + b * bar + 2 * beat)
        # ezgi: pentatonik, akora uyan adımlar
        steps = int(dur / (beat / 2))
        for k in range(steps):
            if r.random() < melody_density and (k % 2 == 0 or r.random() < 0.35):
                last = int(np.clip(last + r.choice([-2, -1, 1, 2, 0]), 0, 9))
                deg = penta[last % 5] + 12 * (last // 5)
                note = 60 + 12 * (octave - 4) + deg
                if (note - root) % 12 in (1, 6, 10):
                    note += 1
                add(buf, 0.33 * tone(midi(note), beat * 1.6, "pluck", decay=brightness), t + k * beat / 2)
                if r.random() < 0.18:   # arada bir yankı notası
                    add(buf, 0.12 * tone(midi(note + 12), beat, "sine", decay=brightness * 1.5), t + k * beat / 2 + beat * 0.75)
        t += dur
    return buf


def soft(chords, bpm, seed, density, low=0):
    """Yumuşak ambiyans müziği: yavaş açılan geniş pad, sürekli hafif bas, seyrek ve yumuşak sinüs ezgi (vuruş yok)."""
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    dur = beat * 8
    buf = np.zeros(int(dur * len(chords) * SR))
    penta = [0, 2, 4, 7, 9]
    last = 4
    t = 0.0
    for root, q in chords:
        third = 3 if q == "m" else 4
        for iv in [0, third, 7, 12, 12 + third]:
            f = midi(root - 12 + low + iv)
            for det in (-0.6, 0.6):
                add(buf, 0.10 * tone(f + det, dur + 1.2, "sine", a=1.2, r=1.2), t)
        add(buf, 0.18 * tone(midi(root - 24 + low), dur + 0.8, "sine", a=0.8, r=1.0), t)
        for k in range(int(dur / beat)):
            if r.random() < density:
                last = int(np.clip(last + r.choice([-1, 1, 0, 2, -2]), 2, 9))
                note = 60 + low + penta[last % 5] + 12 * (last // 5)
                if (note - root) % 12 in (1, 6, 10):
                    note += 1
                add(buf, 0.16 * tone(midi(note), beat * 2.5, "sine", a=0.12, r=1.0), t + k * beat)
        t += dur
    return buf


def rain(sec=6.0):
    n0 = int(sec * SR)
    n = n0 + int(0.3 * SR)
    w = rng.standard_normal(n)
    # pembe/kahverengi gürültü karışımı + yumuşak alçak geçiren
    b = np.cumsum(w)
    b -= np.convolve(b, np.ones(400) / 400, mode="same")
    noise = 0.6 * b / np.max(np.abs(b)) + 0.4 * np.convolve(w, np.ones(6) / 6, mode="same") / 3
    buf = seamless(noise * (0.85 + 0.15 * np.sin(np.arange(n) / SR * 2 * np.pi * 0.25)), n0)
    for _ in range(int(sec * 18)):   # damla tıkırtıları
        add(buf, 0.25 * tone(rng.uniform(1800, 4200), 0.03, "sine", decay=160), rng.uniform(0, sec))
    return buf


def crickets(sec=6.0):
    n = int(sec * SR)
    buf = np.zeros(n)
    for voice in range(3):
        f = rng.uniform(4200, 5200)
        period = rng.uniform(0.55, 0.9)
        t = rng.uniform(0, period)
        while t < sec:
            for p in range(3):   # üç vuruşluk cırıltı
                add(buf, (0.25 - voice * 0.06) * tone(f, 0.035, "sine", decay=60) * np.sin(2 * np.pi * 30 * np.arange(int(0.035 * SR)) / SR) ** 2, t + p * 0.045)
            t += period
    hum = seamless(0.05 * np.convolve(rng.standard_normal(n + int(0.3 * SR)), np.ones(60) / 60, mode="same"), n)
    return buf + hum


def birds(sec=10.0):
    n = int(sec * SR)
    buf = seamless(0.04 * np.convolve(rng.standard_normal(n + int(0.3 * SR)), np.ones(80) / 80, mode="same"), n)   # hafif rüzgâr
    t = 0.4
    while t < sec - 0.2:
        kind = rng.integers(0, 3)
        base = rng.uniform(2200, 3800)
        for k in range(rng.integers(2, 6)):
            d = rng.uniform(0.06, 0.14)
            m = int(d * SR)
            tt = np.arange(m) / SR
            sweep = base * (1 + (0.35 if kind == 0 else -0.25) * tt / d) if kind < 2 else base * (1 + 0.08 * np.sin(2 * np.pi * 28 * tt))
            ph = 2 * np.pi * np.cumsum(sweep) / SR
            add(buf, 0.22 * np.sin(ph) * np.sin(np.pi * tt / d), t + k * (d + 0.03))
        t += rng.uniform(0.6, 2.2)
    return buf


if __name__ == "__main__":
    C, D, E, F, G, A = 60, 62, 64, 65, 67, 69
    # müzik artık üretilmiyor: assets/audio/music_*.ogg (CC0, bkz. CREDITS.md)
    save("amb_rain.wav", rain(), 0.55)
    save("amb_crickets.wav", crickets(), 0.4)
    save("amb_birds.wav", birds(), 0.45)
