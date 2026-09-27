"""Synthesises every sound in Pigeon Bakery Tycoon (no samples, just numpy).

Run with Python 3.13:  py -3.13 tools/gen_audio.py
Writes 16-bit mono WAVs to assets/sfx/.
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 44100
rng = np.random.default_rng(7)


def write(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, f"{len(x) / SR:.2f}s")


def t_arr(dur):
    return np.arange(int(dur * SR)) / SR


def env_exp(dur, decay, attack=0.004):
    t = t_arr(dur)
    e = np.exp(-t / decay)
    a = np.clip(t / attack, 0, 1)
    return e * a


def sweep(f0, f1, dur, curve=1.0):
    t = t_arr(dur)
    k = (t / dur) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def pad(x, dur):
    n = int(dur * SR)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, offset, total):
    out = np.zeros(int(total * SR))
    i = int(offset * SR)
    seg = x[: max(0, len(out) - i)]
    out[i : i + len(seg)] += seg
    return out


def bell(freq, dur, decay=0.25, partials=((1, 1), (2.76, 0.35), (5.4, 0.12))):
    t = t_arr(dur)
    x = np.zeros_like(t)
    for mult, amp in partials:
        x += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-t / (decay / mult ** 0.5))
    return x * np.clip(t / 0.002, 0, 1)


def note_freq(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[n] + (o - 4) * 12 - 9) / 12)


# ------------------------------------------------------------------ sfx ---
def sfx():
    # item picked up: bubbly upward blip
    write("pop", sweep(520, 1150, 0.09, 0.6) * env_exp(0.09, 0.04), 0.6)
    # item placed: soft downward bloop + tiny thump
    thump = lowpass(noise(0.05), 600) * env_exp(0.05, 0.015)
    write("drop", mix(sweep(620, 300, 0.1, 0.8) * env_exp(0.1, 0.045), thump * 2), 0.6)
    # cash bill collected: bright coin ting
    write("coin", mix(bell(1976, 0.28, 0.12), 0.6 * bell(2637, 0.25, 0.08)), 0.55)
    # register ka-ching
    click = highpass(noise(0.03), 2000) * env_exp(0.03, 0.006)
    ching = mix(bell(2093, 0.7, 0.28), bell(2637, 0.7, 0.25) * 0.8, bell(3136, 0.7, 0.2) * 0.6)
    write("kaching", mix(click * 1.5, at(ching, 0.05, 0.75)), 0.7)
    # money pouring into a buy zone
    write("tick", bell(1500, 0.05, 0.015, ((1, 1), (2.1, 0.3))), 0.4)
    # unlock: happy arpeggio + sparkle
    arp = np.zeros(int(0.9 * SR))
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        f = note_freq(n)
        t = t_arr(0.5)
        tone = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)) * np.exp(-t / 0.18)
        arp += at(tone, i * 0.07, 0.9)
    spark = np.zeros(int(0.9 * SR))
    for i in range(10):
        spark += at(bell(rng.uniform(3000, 6000), 0.2, 0.05) * 0.25, 0.25 + i * 0.05, 0.9)
    write("unlock", mix(arp, spark), 0.7)
    # big fanfare for new products / milestones
    fan = np.zeros(int(1.6 * SR))
    seq = [("G4", 0.0), ("C5", 0.12), ("E5", 0.24), ("G5", 0.36), ("E5", 0.5), ("G5", 0.62)]
    for n, o in seq:
        f = note_freq(n)
        t = t_arr(0.35)
        sq = np.sign(np.sin(2 * np.pi * f * t)) * 0.25 + np.sin(2 * np.pi * f * t)
        fan += at(lowpass(sq, 3500) * np.exp(-t / 0.2), o, 1.6)
    t = t_arr(0.85)
    chord = sum(np.sin(2 * np.pi * note_freq(n) * t) for n in ["C5", "E5", "G5", "C6"]) * np.exp(-t / 0.45)
    fan += at(chord * 0.6, 0.74, 1.6)
    write("fanfare", fan, 0.7)
    # pigeon coos (3 variants): "coo-RRoo-coo"
    for k, (base, dur) in enumerate([(300, 0.75), (340, 0.65), (270, 0.85)]):
        t = t_arr(dur)
        u = t / dur
        f = base * (1 + 0.18 * np.sin(np.pi * u) - 0.12 * u)
        roll = 1 + 0.6 * np.sin(2 * np.pi * 32 * t) * ((u > 0.35) & (u < 0.62))
        ph = 2 * np.pi * np.cumsum(f) / SR
        x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
        amp = (np.exp(-((u - 0.18) / 0.12) ** 2) + 1.2 * np.exp(-((u - 0.5) / 0.14) ** 2)
               + 0.7 * np.exp(-((u - 0.82) / 0.1) ** 2))
        x = lowpass(x * amp * roll, 1400)
        write(f"coo{k + 1}", x, 0.55)
    # wing flaps
    flap = np.zeros(int(0.55 * SR))
    for i in range(6):
        b = highpass(lowpass(noise(0.07), 3000), 500) * env_exp(0.07, 0.02)
        flap += at(b * (1 - i * 0.1), i * 0.08, 0.55)
    write("flap", flap, 0.5)
    # crow caw
    caw = np.zeros(int(0.8 * SR))
    for o in (0.0, 0.38):
        t = t_arr(0.3)
        f = 650 - 250 * (t / 0.3)
        ph = 2 * np.pi * np.cumsum(f) / SR
        saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
        x = lowpass(saw + 0.4 * noise(0.3), 2500) * np.sin(np.pi * t / 0.3) ** 0.6
        caw += at(x, o, 0.8)
    write("caw", caw, 0.6)
    # whoosh (camera pan / popups)
    t = t_arr(0.5)
    wn = noise(0.5) * np.sin(np.pi * t / 0.5) ** 2
    write("whoosh", highpass(lowpass(wn, 1800), 300), 0.35)
    # ui click
    write("click", mix(sweep(1400, 900, 0.04) * env_exp(0.04, 0.012)), 0.45)
    # sparkle (cleaning, happy)
    sp = np.zeros(int(0.6 * SR))
    for i in range(7):
        sp += at(bell(rng.uniform(2500, 5000), 0.25, 0.06) * 0.5, i * 0.05, 0.6)
    write("sparkle", sp, 0.45)
    # harvest snip
    sn = highpass(noise(0.07), 2500) * env_exp(0.07, 0.02)
    write("harvest", mix(sn, 0.5 * sweep(900, 1300, 0.07) * env_exp(0.07, 0.03)), 0.5)
    # machine finished an item
    write("ding", bell(1318, 0.35, 0.12), 0.35)
    # not enough money
    t = t_arr(0.22)
    nope = np.sign(np.sin(2 * np.pi * 140 * t)) * np.exp(-t / 0.1)
    write("nope", lowpass(nope, 900), 0.4)
    # thud for a building popping into existence
    t = t_arr(0.35)
    boom = np.sin(2 * np.pi * np.cumsum(120 - 70 * t / 0.35) / SR) * np.exp(-t / 0.12)
    write("thud", mix(boom, lowpass(noise(0.35), 400) * np.exp(-t / 0.05) * 0.6), 0.75)
    # trash
    write("trash", lowpass(noise(0.25), 1500) * env_exp(0.25, 0.08), 0.5)
    # eating nom
    nom = np.zeros(int(0.4 * SR))
    for i in range(3):
        nom += at(sweep(500, 380, 0.08) * env_exp(0.08, 0.03), i * 0.12, 0.4)
    write("nom", nom, 0.4)


# ---------------------------------------------------------------- music ---
def pluck(freq, dur, bright=0.5):
    """Karplus-Strong pluck, vectorised per period."""
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    y = np.zeros(n + p + 1)
    y[: p + 1] = lowpass(rng.uniform(-1, 1, p + 1) * 0.9, 2000 + 6000 * bright)
    decay = 0.996
    i = p + 1
    while i < n:
        j = min(i + p, n)
        y[i:j] = decay * 0.5 * (y[i - p : j - p] + y[i - p - 1 : j - p - 1])
        i = j
    return y[:n] * np.clip(np.arange(n) / 30, 0, 1)


def marimba(freq, dur):
    t = t_arr(dur)
    x = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.35)
    x += 0.25 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / 0.05)
    x += 0.1 * np.sin(2 * np.pi * freq * 10 * t) * np.exp(-t / 0.015)
    return x * np.clip(t / 0.002, 0, 1)


def music():
    bpm = 112.0
    beat = 60.0 / bpm
    bars = 8
    total = bars * 4 * beat
    tail = 1.5
    n = int((total + tail) * SR)
    out = np.zeros(n)

    def put(x, when, gain):
        i = int(when * SR)
        j = min(n, i + len(x))
        out[i:j] += x[: j - i] * gain

    chords = [
        ["C3", "E3", "G3", "C4", "E4"], ["G2", "D3", "G3", "B3", "D4"],
        ["A2", "E3", "A3", "C4", "E4"], ["F2", "C3", "F3", "A3", "C4"],
    ] * 2
    roots = ["C2", "G2", "A2", "F2"] * 2
    # ukulele-ish strums: down on 1, up on 2&, down 3, up 3&, down 4
    strum_beats = [0.0, 1.5, 2.0, 2.5, 3.0]
    for b in range(bars):
        for sb in strum_beats:
            when = (b * 4 + sb) * beat
            notes = chords[b]
            for k, nn in enumerate(notes):
                put(pluck(note_freq(nn), 1.2, 0.4), when + k * 0.012, 0.16 if sb == 0 else 0.1)
        # bass: root on 1 and 3, fifth-ish on the & of 4
        f = note_freq(roots[b])
        for sb, mult in ((0.0, 1), (2.0, 1), (3.5, 1.5)):
            t = t_arr(beat * 0.9)
            x = np.sin(2 * np.pi * f * mult * t) + 0.2 * np.sin(4 * np.pi * f * mult * t)
            x *= np.exp(-t / 0.35) * np.clip(t / 0.01, 0, 1)
            put(x, (b * 4 + sb) * beat, 0.32)
    # melody (8th notes, '-' = rest)
    mel = [
        "E5 - G5 - A5 G5 E5 -", "D5 - D5 E5 G5 - D5 -", "C5 - E5 - A5 - G5 E5", "F5 - E5 - C5 - - -",
        "E5 - G5 - C6 - A5 G5", "G5 - A5 G5 D5 - E5 -", "E5 - A5 - C6 - A5 G5", "F5 E5 D5 - C5 - - -",
    ]
    for b, line in enumerate(mel):
        for k, tok in enumerate(line.split()):
            if tok == "-":
                continue
            put(marimba(note_freq(tok), 0.6), (b * 4 + k * 0.5) * beat, 0.22)
    # drums
    for b in range(bars):
        for q in range(4):
            when = (b * 4 + q) * beat
            if q in (0, 2):
                t = t_arr(0.25)
                kick = np.sin(2 * np.pi * np.cumsum(110 * np.exp(-t / 0.05) + 45) / SR) * np.exp(-t / 0.12)
                put(kick, when, 0.45)
            else:
                t = t_arr(0.18)
                clap = highpass(lowpass(noise(0.18), 3500), 900) * np.exp(-t / 0.04)
                put(clap, when, 0.12)
            for e in (0.0, 0.5):
                t = t_arr(0.05)
                sh = highpass(noise(0.05), 5000) * np.exp(-t / 0.015)
                put(sh, when + e * beat, 0.05 if e == 0 else 0.08)
    # wrap the tail into the start so the loop is seamless
    loop_n = int(total * SR)
    looped = out[:loop_n].copy()
    looped[: n - loop_n] += out[loop_n:]
    write("music_loop", looped, 0.6)


if __name__ == "__main__":
    sfx()
    music()
