#!/usr/bin/env python3
"""Lethemoor sound kit, synthesized from scratch (no samples, no third-party audio).

Every sound in assets/audio/ comes out of this file: noise, sines, filters and a baked
cave reverb (web builds play audio in "sample" mode, where Godot bus effects don't run,
so the room sound has to be in the file). Deterministic: each clip has its own seed (1119 + its name), same files every run.

    python3 tools/gen_audio.py            # writes assets/audio/*.ogg (needs numpy + ffmpeg)

Licence: original work made for Lethemoor, owned by Duff. See assets/audio/SOURCES.md.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1119)


# ------------------------------------------------------------------ building blocks

def t(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def brown(dur):
    x = np.cumsum(rng.standard_normal(int(dur * SR)))
    x -= np.linspace(x[0], x[-1], len(x))   # no drift: loops cleanly
    return x / (np.abs(x).max() + 1e-9)


def fft_filter(x, lo=None, hi=None, slope=2.0):
    """Static band filter in the frequency domain (soft edges, no ringing)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1)) ** (2 * slope))
    if hi:
        g *= 1 / (1 + (f / hi) ** (2 * slope))
    return np.fft.irfft(np.fft.rfft(x) * g, n)


def onepole(x, cutoff):
    """Time-varying one-pole lowpass. cutoff: Hz, scalar or per-sample array."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a[i] * (x[i] - s)
        y[i] = s
    return y


def env(n, attack, decay, curve=4.0):
    """Attack (s) then exponential-ish decay over `decay` seconds, length n samples."""
    tt = np.arange(n) / SR
    a = np.clip(tt / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * np.maximum(tt - attack, 0) / max(decay, 1e-4))
    return a * d


def fit(x, dur):
    n = int(dur * SR)
    return x[:n] if len(x) >= n else np.pad(x, (0, n - len(x)))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(dst, src, at):
    i = int(at * SR)
    j = min(len(dst), i + len(src))
    dst[i:j] += src[: j - i]


def reverb(x, size=1.6, wet=0.35, damp=3500, pre=0.012):
    """Stone cave: exponentially decaying, darkened noise impulse, convolved via FFT."""
    ir = noise(size) * np.exp(-6.0 * t(size) / size)
    ir = fft_filter(ir, lo=120, hi=damp)
    ir = np.concatenate([np.zeros(int(pre * SR)), ir])
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    n = len(x) + len(ir)
    w = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    dry = np.pad(x, (0, len(ir)))
    return (1 - wet) * dry + wet * w * 0.5


def partials(f0, ratios, amps, decays, dur, detune=0.0):
    tt = t(dur)
    out = np.zeros_like(tt)
    for r, a, d in zip(ratios, amps, decays):
        f = f0 * r * (1 + detune * rng.uniform(-1, 1))
        out += a * np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.28)) * np.exp(-tt / d)
    return out


def norm(x, peak=0.9):
    return x * (peak / (np.abs(x).max() + 1e-9))


def fade(x, fin=0.003, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def loopify(x, xfade=1.5):
    """Make a seamless loop: the tail crossfades into the head."""
    n = int(xfade * SR)
    head, body, tail = x[:n], x[n:-n] if n else x, x[-n:]
    k = np.linspace(0, 1, n)
    seam = tail * (1 - k) + head * k
    if x.ndim == 1:
        return np.concatenate([body, seam])
    raise ValueError


def write(name, x, peak=0.9, stereo=None, q=3):
    """Mono (or a stereo pair via `stereo`) -> assets/audio/<name>.ogg."""
    os.makedirs(OUT, exist_ok=True)
    if stereo is not None:
        data = np.stack([x, stereo], axis=1)
        data = norm(data, peak)
        ch = 2
    else:
        data = norm(x, peak)[:, None]
        ch = 1
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", str(q), dst], check=True)
    os.unlink(tmp)
    print(f"{name:18s} {len(data) / SR:5.2f}s  {os.path.getsize(dst) // 1024} KB")


# ------------------------------------------------------------------ the sounds

def amb_moor():
    """The bed: low wind in stone, a drowned drone, water lapping, drips. 40 s loop, stereo."""
    dur = 41.5
    tt = t(dur)
    chans = []
    for side in (0, 1):
        wind = brown(dur)
        swell = 0.55 + 0.45 * np.sin(2 * np.pi * tt / 13.0 + side * 1.3) * np.sin(2 * np.pi * tt / 7.3 + 0.7)
        wind = onepole(wind, 180 + 260 * swell) * (0.4 + 0.6 * swell)
        moan = fft_filter(noise(dur), lo=300, hi=700, slope=3) * 0.05 * np.clip(swell - 0.6, 0, 1) * 2.5
        drone = sum(a * np.sin(2 * np.pi * f * tt + side * 0.4) for f, a in
                    [(43.65, 0.5), (43.9, 0.4), (65.4, 0.22), (87.3 + side * 0.2, 0.12), (130.6, 0.04)])
        drone *= 0.8 + 0.2 * np.sin(2 * np.pi * tt / 19.0)
        lap = fft_filter(noise(dur), lo=150, hi=900) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 3.7 + side)) ** 4 * 0.12
        drips = np.zeros_like(tt)
        for _ in range(26):
            at = rng.uniform(0.5, dur - 2.5)
            f = rng.uniform(900, 2200)
            d = t(0.18)
            plink = np.sin(2 * np.pi * (f * d + 900 * d * d * -2)) * np.exp(-d * 38)
            gain = rng.uniform(0.05, 0.22) * (1.0 if (rng.random() < 0.5) == bool(side) else 0.45)
            place(drips, plink * gain, at)
        drips = reverb(drips, size=2.4, wet=0.7, damp=3000)[: len(tt)]
        chans.append(wind * 0.55 + moan + drone * 0.22 + lap + drips)
    left, right = (loopify(c, 1.5) for c in chans)
    write("amb_moor", left, peak=0.6, stereo=right)


def heartbeat():
    """Lub-dub, one beat per file (pitch_scale speeds it up with dread). Loops."""
    dur = 0.92
    out = np.zeros(int(dur * SR))
    for at, f, g in [(0.0, 52, 1.0), (0.22, 44, 0.7)]:
        d = t(0.22)
        thump = np.sin(2 * np.pi * f * d * (1 - 0.35 * d / 0.22)) * env(len(d), 0.008, 0.09, 3)
        thump += fft_filter(noise(0.22), hi=160) * env(len(d), 0.003, 0.03) * 0.5
        place(out, thump * g, at)
    write("heartbeat", fade(out, 0, 0.01), peak=0.85)


def footstep(i):
    """Boot on wet stone: heel knock, a grit scuff, a little splash, cave tail."""
    dur = 0.55
    heel = np.sin(2 * np.pi * rng.uniform(85, 115) * t(0.09)) * env(int(0.09 * SR), 0.002, 0.03)
    knock = fft_filter(noise(0.06), lo=250, hi=1600) * env(int(0.06 * SR), 0.001, 0.018)
    scuff = fft_filter(noise(0.14), lo=1500, hi=6000) * env(int(0.14 * SR), 0.01, 0.05) * 0.25
    splash = fft_filter(noise(0.25), lo=2500, hi=9000) * env(int(0.25 * SR), 0.004, 0.08, 5)
    splash *= (0.5 + 0.5 * np.sin(2 * np.pi * 37 * t(0.25))) * rng.uniform(0.15, 0.35)
    x = mix(heel * 0.8, knock, np.pad(scuff, (int(0.015 * SR), 0)), splash)
    x = reverb(fit(x, dur), size=0.9, wet=0.28, damp=2500)
    write(f"step_{i}", fade(x[: int(0.8 * SR)], 0, 0.15), peak=0.8)


def turn():
    """Cloth and the lantern's handle as you turn: a soft swish with a creak."""
    dur = 0.45
    x = fft_filter(noise(dur), lo=600, hi=4000)
    grain = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 23 * t(dur)))
    sw = np.sin(np.pi * np.clip(t(dur) / dur, 0, 1)) ** 2
    creak = np.sin(2 * np.pi * (620 + 80 * np.sin(2 * np.pi * 9 * t(dur))) * t(dur)) * env(int(dur * SR), 0.12, 0.2) * 0.04
    write("turn", fade(reverb(x * grain * sw * 0.5 + creak, 0.6, 0.2)), peak=0.5)


def bump():
    """Shoulder into a stone wall: a dull thud and a grit scrape."""
    d = t(0.5)
    thud = np.sin(2 * np.pi * 62 * d * (1 - 0.2 * d)) * env(len(d), 0.003, 0.12)
    body = fft_filter(noise(0.5), hi=400) * env(len(d), 0.002, 0.05)
    grit = fft_filter(noise(0.5), lo=1800, hi=7000) * env(len(d), 0.02, 0.15) * 0.2
    write("bump", fade(reverb(thud + body + grit, 0.8, 0.25)), peak=0.85)


def flame_loop():
    """The lantern burning: a soft hiss with crackles. 6 s loop."""
    dur = 7.0
    hiss = fft_filter(noise(dur), lo=900, hi=5000) * 0.04
    roar = fft_filter(noise(dur), lo=60, hi=300) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.6 * t(dur))) * 0.25
    cr = np.zeros(int(dur * SR))
    for _ in range(70):
        pop = fft_filter(noise(0.012), lo=1500, hi=9000) * env(int(0.012 * SR), 0.0005, 0.003)
        place(cr, pop * rng.uniform(0.1, 0.6) ** 2, rng.uniform(0, dur - 0.05))
    write("flame_loop", loopify(hiss + roar + cr, 1.0), peak=0.5)


def lantern_bright():
    """Wick wound up: a rising whoosh of flame."""
    dur = 0.9
    tt = t(dur)
    x = onepole(noise(dur), 200 + 3000 * (tt / dur) ** 1.5) * env(len(tt), 0.35, 0.3)
    click = np.sin(2 * np.pi * 2400 * t(0.03)) * env(int(0.03 * SR), 0.0005, 0.006) * 0.4
    write("lantern_bright", fade(reverb(mix(click, x), 0.8, 0.2)), peak=0.75)


def lantern_normal():
    """Wick wound down: a tick of the brass wheel, the flame settles."""
    click = mix(*[np.pad(np.sin(2 * np.pi * f * t(0.04)) * env(int(0.04 * SR), 0.0005, 0.008), (int(o * SR), 0))
                  for f, o in [(2100, 0), (2600, 0.06)]])
    settle = onepole(noise(0.5), 1500 - 1300 * t(0.5) / 0.5) * env(int(0.5 * SR), 0.05, 0.2) * 0.5
    write("lantern_normal", fade(reverb(mix(click, settle), 0.7, 0.2)), peak=0.6)


def lantern_hood():
    """Shutter slammed over the glass: a metal clack, the light smothered."""
    clack = partials(1, [1830, 2770, 4120, 5390], [1, 0.6, 0.4, 0.25], [0.05, 0.04, 0.025, 0.02], 0.3, 0.02)
    clack += fft_filter(noise(0.3), lo=800, hi=5000) * env(int(0.3 * SR), 0.0005, 0.01)
    muffle = fft_filter(noise(0.4), hi=500) * env(int(0.4 * SR), 0.01, 0.12) * 0.6
    write("lantern_hood", fade(reverb(mix(clack * 0.6, np.pad(muffle, (int(0.02 * SR), 0))), 0.9, 0.3)), peak=0.75)


def oil():
    """A corked flask: glass clink, cork pop, the lantern drinks (glug glug)."""
    out = np.zeros(int(1.4 * SR))
    place(out, partials(1, [3150, 4710, 6890], [1, 0.5, 0.3], [0.25, 0.15, 0.08], 0.6, 0.01) * 0.4, 0)
    pop = np.sin(2 * np.pi * 520 * t(0.05) * (1 + 3 * t(0.05))) * env(int(0.05 * SR), 0.001, 0.015)
    place(out, pop * 0.6, 0.28)
    for k in range(4):
        d = t(0.14)
        f = 180 + 60 * k + rng.uniform(-15, 15)
        glug = np.sin(2 * np.pi * (f * d + 900 * d * d)) * env(len(d), 0.01, 0.05)
        place(out, glug * 0.7, 0.45 + 0.16 * k)
    write("oil", fade(reverb(out, 0.8, 0.25)), peak=0.75)


def out_of_oil():
    """The flame sputters and dies: crackles thinning out, a last gasp of air."""
    dur = 1.8
    out = np.zeros(int(dur * SR))
    for k in range(18):
        at = 1.3 * (k / 18) ** 0.7
        pop = fft_filter(noise(0.03), lo=600, hi=6000) * env(int(0.03 * SR), 0.001, 0.008)
        place(out, pop * (1 - k / 20), at)
    gasp = onepole(noise(0.7), 2500 - 2300 * t(0.7) / 0.7) * env(int(0.7 * SR), 0.05, 0.3)
    place(out, gasp * 0.5, 1.0)
    write("out_of_oil", fade(reverb(out, 1.2, 0.35)), peak=0.75)


def paper(name, dur, crisp):
    """Old paper handled: crackly broadband rustles."""
    out = np.zeros(int(dur * SR))
    for _ in range(int(dur * 40)):
        g = fft_filter(noise(0.025), lo=1200, hi=9000 if crisp else 5000)
        place(out, g * env(len(g), 0.002, 0.01) * rng.uniform(0.2, 1), rng.uniform(0, dur - 0.05))
    out *= np.sin(np.pi * t(dur) / dur) ** 0.7
    write(name, fade(reverb(out, 0.6, 0.15)), peak=0.55 if crisp else 0.4)


def bell():
    """The tower bell: a big bronze strike, inharmonic partials, the hum rings on. 9 s."""
    f0 = 98.0   # hum ~G2: a big bell, felt more than heard
    ratios = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166, 5.433, 6.796]
    amps = [0.9, 0.7, 0.55, 0.3, 0.5, 0.25, 0.2, 0.15, 0.12, 0.08, 0.05]
    decs = [6.5, 4.5, 3.2, 2.2, 2.4, 1.4, 1.2, 0.9, 0.6, 0.4, 0.3]
    dur = 9.0
    tt = t(dur)
    out = np.zeros_like(tt)
    for r, a, d in zip(ratios, amps, decs):
        for beat in (-0.6, 0.6):   # each partial is a slightly split pair: the bell "wows"
            out += 0.5 * a * np.sin(2 * np.pi * (f0 * r + beat * r ** 0.5) * tt) * np.exp(-tt / d)
    strike = fft_filter(noise(0.08), lo=300, hi=4000) * env(int(0.08 * SR), 0.0005, 0.02) * 0.8
    out[: len(strike)] += strike
    out *= np.clip(tt / 0.004, 0, 1)
    write("bell", fade(reverb(out, 3.5, 0.45, damp=2500)[: int(10.5 * SR)], 0, 1.5), peak=0.9)


def death():
    """Taken: a hit in the chest, the lantern glass breaks, a falling dissonance, then nothing."""
    dur = 4.0
    tt = t(dur)
    out = np.zeros_like(tt)
    boom = np.sin(2 * np.pi * 45 * tt * (1 - 0.25 * tt / dur)) * np.exp(-tt / 0.6)
    out += boom + fft_filter(noise(dur), hi=200) * np.exp(-tt / 0.15) * 0.6
    glass = np.zeros_like(tt)
    for _ in range(40):
        g = partials(1, [rng.uniform(3000, 9000)], [1], [rng.uniform(0.03, 0.12)], 0.3)
        place(glass, g * rng.uniform(0.05, 0.2), 0.05 + rng.exponential(0.12))
    out += glass + fft_filter(noise(dur), lo=3000, hi=10000) * np.exp(-tt / 0.08) * 0.3
    for f in (220, 233.1, 246.9, 311.1):   # a cluster that sags as you go down
        bend = f * (1 - 0.18 * (tt / dur) ** 1.4)
        out += 0.09 * np.sign(np.sin(2 * np.pi * np.cumsum(bend) / SR)) * np.clip((tt - 0.15) / 0.4, 0, 1) * np.exp(-tt / 1.6)
    out = fft_filter(out, hi=5000)
    write("death", fade(reverb(out, 3.0, 0.4)[: int(5.5 * SR)], 0, 1.0), peak=0.9)


def ui_click():
    d = t(0.12)
    x = np.sin(2 * np.pi * 1300 * d) * env(len(d), 0.0005, 0.012) + fft_filter(noise(0.12), lo=2000, hi=6000) * env(len(d), 0.0005, 0.004) * 0.5
    write("ui_click", fade(reverb(x, 0.4, 0.15)), peak=0.5)


def strings_stab(name, notes, dur, peak):
    """Dissonant string stab: detuned saws with bow noise and tremolo, through the cave."""
    tt = t(dur)
    out = np.zeros_like(tt)
    for f in notes:
        for det in (-0.004, 0.0, 0.0045):
            ph = np.cumsum(f * (1 + det) * (1 + 0.003 * np.sin(2 * np.pi * 5.5 * tt + rng.uniform(0, 6))) / SR)
            out += ((ph % 1.0) * 2 - 1) * 0.2
    out = fft_filter(out, lo=180, hi=4000)
    out *= (0.8 + 0.2 * np.sin(2 * np.pi * 13 * tt)) * env(len(tt), 0.015, dur * 0.55, 3)
    out += fft_filter(noise(dur), lo=2000, hi=8000) * env(len(tt), 0.01, 0.2) * 0.1
    sub = np.sin(2 * np.pi * 40 * tt) * np.exp(-tt / 0.3) * 0.8
    write(name, fade(reverb(out + sub, 2.5, 0.45)[: int((dur + 1.5) * SR)], 0, 0.8), peak=peak)


def stalker_silk():
    """Lace dragging on stone, close, with a breath inside it."""
    dur = 1.6
    tt = t(dur)
    sw = np.sin(np.pi * np.clip(tt / dur, 0, 1)) ** 1.5
    silk = onepole(noise(dur), 2500 + 2000 * sw) - onepole(noise(dur), 700)
    silk *= sw * (0.7 + 0.3 * np.sin(2 * np.pi * 11 * tt))
    breath = fft_filter(noise(dur), lo=400, hi=1400, slope=3) * np.sin(np.pi * np.clip((tt - 0.4) / 0.9, 0, 1)) ** 2 * 0.6
    write("stalker_silk", fade(reverb(silk * 0.5 + breath, 1.4, 0.35)), peak=0.75)


def shuffle(i):
    """A thrall's foot dragging, and a wet breath. Plays where it stands."""
    dur = 1.1
    tt = t(dur)
    drag = fft_filter(noise(dur), lo=300, hi=2500) * np.sin(np.pi * np.clip(tt / 0.7, 0, 1)) ** 2
    drag *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * rng.uniform(14, 22) * tt))
    knock = np.sin(2 * np.pi * 75 * t(0.08)) * env(int(0.08 * SR), 0.002, 0.03)
    groan_f = rng.uniform(85, 120)
    groan = sum(np.sin(2 * np.pi * groan_f * k * tt * (1 - 0.06 * tt)) / k for k in range(1, 7))
    groan = fft_filter(groan, lo=200, hi=900) * np.sin(np.pi * np.clip((tt - 0.3) / 0.8, 0, 1)) ** 2 * (0.25 if i != 1 else 0.0)
    out = mix(drag * 0.5, np.pad(knock, (int(0.62 * SR), 0)) * 0.7, groan)
    write(f"shuffle_{i}", fade(reverb(fit(out, dur), 1.2, 0.3)), peak=0.75)


def breath_behind():
    """A wet, slow exhale right at your neck: something close you are not looking at.
    Nearly dry (it's beside your ear, not down the alley), low, with a click of a throat."""
    dur = 1.5
    tt = t(dur)
    shape = np.sin(np.pi * np.clip(tt / 1.25, 0, 1)) ** 1.5 * np.exp(-tt * 0.6)
    air = onepole(noise(dur), 300 + 900 * np.sin(np.pi * np.clip(tt / 1.25, 0, 1)))
    rasp = fft_filter(noise(dur), lo=900, hi=2600) * (0.5 + 0.5 * np.sin(2 * np.pi * 31 * tt)) * 0.25
    wet = np.zeros_like(tt)
    for _ in range(14):
        g = fft_filter(noise(0.012), lo=1500, hi=6000) * env(int(0.012 * SR), 0.0005, 0.004)
        place(wet, g * rng.uniform(0.1, 0.4), rng.uniform(0.2, 1.1))
    click = np.sin(2 * np.pi * 140 * t(0.03)) * env(int(0.03 * SR), 0.001, 0.01)
    out = mix(air * shape, rasp * shape, wet, np.pad(click, (int(0.05 * SR), 0)) * 0.4)
    write("breath_behind", fade(reverb(fit(out, dur), 0.5, 0.08)), peak=0.7)


def whisper():
    """Breath shaped like words, too quiet to make out (the flame gutters)."""
    dur = 1.6
    tt = t(dur)
    src = noise(dur)
    out = np.zeros_like(tt)
    for lo, hi, g in [(500, 900, 1.0), (1300, 2100, 0.7), (2600, 3400, 0.4), (5000, 8000, 0.25)]:
        out += fft_filter(src, lo=lo, hi=hi, slope=4) * g
    syll = np.clip(np.sin(2 * np.pi * 3.1 * tt + 0.3) + 0.2 * np.sin(2 * np.pi * 7 * tt), 0, 1) ** 2
    out *= syll * np.sin(np.pi * tt / dur)
    write("whisper", fade(reverb(out, 2.0, 0.5)), peak=0.55)


def panic():
    """Hands shaking: a breath sucked in, oil spilling and hissing on the stones."""
    dur = 2.2
    tt = t(dur)
    gasp = onepole(noise(dur), 600 + 2200 * np.clip(tt / 0.5, 0, 1)) * np.sin(np.pi * np.clip(tt / 0.6, 0, 1)) ** 2
    hiss = fft_filter(noise(dur), lo=3000, hi=10000) * np.clip((tt - 0.45) / 0.05, 0, 1) * np.exp(-np.maximum(tt - 0.5, 0) / 0.6) * 0.5
    sizzle = np.zeros_like(tt)
    for _ in range(60):
        g = fft_filter(noise(0.01), lo=2000, hi=9000) * env(int(0.01 * SR), 0.0005, 0.002)
        place(sizzle, g * rng.uniform(0, 0.6), rng.uniform(0.5, 1.8))
    write("panic", fade(reverb(gasp * 0.7 + hiss + sizzle, 1.2, 0.3)), peak=0.8)


def night_start():
    """The night begins: a low swell and a distant bell-less toll (the goal is out there)."""
    dur = 4.0
    tt = t(dur)
    swell = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(55, 0.6), (82.4, 0.3), (110.3, 0.15)])
    swell *= np.sin(np.pi * tt / dur) ** 2
    far = partials(1, [196 * r for r in (0.5, 1, 1.183, 1.506, 2)], [0.5, 0.4, 0.3, 0.2, 0.2], [2.5, 1.8, 1.2, 0.9, 0.8], dur)
    far = fft_filter(far, hi=900) * 0.25
    out = swell + np.pad(far, (int(0.6 * SR), 0))[: len(tt)]
    write("night_start", fade(reverb(out, 3.5, 0.6)[: int(5.5 * SR)], 0.2, 1.2), peak=0.6)


def hook_swing():
    """The boathook through the air: a heavy, falling whoosh."""
    dur = 0.5
    tt = t(dur)
    x = onepole(noise(dur), 300 + 2200 * np.sin(np.pi * np.clip(tt / 0.32, 0, 1)) ** 2)
    x *= np.sin(np.pi * np.clip(tt / 0.22, 0, 1)) ** 2
    # Three short, irregular iron rattles under a descending spectral breath.
    rattle = np.zeros_like(tt)
    for at in (0.008, 0.032, 0.063):
        d = np.maximum(tt - at, 0)
        rattle += (tt >= at) * np.exp(-d * 95) * (
            np.sin(2 * np.pi * 1430 * d) + 0.6 * np.sin(2 * np.pi * 2273 * d))
    breath = np.sin(2 * np.pi * (320 * tt - 260 * tt ** 2)) * np.sin(np.pi * np.clip(tt / 0.3, 0, 1)) ** 2
    write("hook_swing", fade(reverb(x + 0.16 * rattle + 0.12 * breath, 0.7, 0.2)), peak=0.7)


def hook_hit():
    """Iron into something wet and heavy: thud, a ring of the hook, a shove."""
    d = t(1.0)
    thud = np.sin(2 * np.pi * 70 * d * (1 - 0.3 * d)) * env(len(d), 0.002, 0.08)
    meat = fft_filter(noise(1.0), lo=120, hi=900) * env(len(d), 0.002, 0.06)
    ring = partials(1, [740, 1931, 3310], [0.5, 0.3, 0.15], [0.35, 0.2, 0.1], 1.0, 0.01) * 0.35
    write("hook_hit", fade(reverb(1.35 * thud + meat + ring, 1.0, 0.3)), peak=0.9)


def hook_broke():
    """The hook's shaft bends and the head snaps: a creak and a dull crack."""
    d = t(1.0)
    creak = np.sin(2 * np.pi * (180 + 120 * d) * d + 3 * np.sin(2 * np.pi * 31 * d)) * env(len(d), 0.15, 0.25) * 0.4
    snap = fft_filter(noise(1.0), lo=500, hi=6000) * np.exp(-np.maximum(d - 0.35, 0) / 0.02) * (d > 0.35)
    clank = np.pad(partials(1, [1210, 2650, 4100], [0.6, 0.4, 0.2], [0.15, 0.1, 0.06], 0.5, 0.02), (int(0.55 * SR), 0))[: len(d)]
    write("hook_broke", fade(reverb(creak + snap + clank * 0.5, 1.0, 0.3)), peak=0.85)


def hook_found():
    """Iron dragged off wet stone and taken up."""
    d = t(0.8)
    scrape = fft_filter(noise(0.8), lo=1500, hi=6000) * np.sin(np.pi * np.clip(d / 0.5, 0, 1)) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 40 * d))
    ring = np.pad(partials(1, [880, 2290], [0.4, 0.2], [0.3, 0.15], 0.6, 0.01), (int(0.45 * SR), 0))[: len(d)]
    write("hook_found", fade(reverb(scrape * 0.4 + ring, 0.9, 0.3)), peak=0.7)


def pour():
    """Oil glugged out of the lantern's reservoir onto stone, spreading."""
    dur = 1.6
    tt = t(dur)
    out = np.zeros_like(tt)
    for k in range(7):
        d = t(0.12)
        f = rng.uniform(160, 260)
        place(out, np.sin(2 * np.pi * (f * d + 700 * d * d)) * env(len(d), 0.008, 0.04) * 0.6, 0.08 + 0.13 * k)
    out += fft_filter(noise(dur), lo=1500, hi=7000) * np.sin(np.pi * np.clip((tt - 0.1) / 1.3, 0, 1)) ** 2 * 0.12
    write("pour", fade(reverb(out, 0.9, 0.3)), peak=0.7)


def ignite():
    """Flint struck, then the slick goes up: a roar that blooms and crackles."""
    dur = 2.6
    tt = t(dur)
    strike = fft_filter(noise(0.04), lo=2500, hi=10000) * env(int(0.04 * SR), 0.0005, 0.006)
    roar = onepole(noise(dur), 150 + 900 * np.clip((tt - 0.08) / 0.3, 0, 1)) * np.clip((tt - 0.08) / 0.15, 0, 1) * np.exp(-np.maximum(tt - 0.6, 0) / 1.2)
    cr = np.zeros_like(tt)
    for _ in range(90):
        pop = fft_filter(noise(0.012), lo=1500, hi=9000) * env(int(0.012 * SR), 0.0005, 0.003)
        place(cr, pop * rng.uniform(0.1, 0.7) ** 2, rng.uniform(0.15, dur - 0.1))
    write("ignite", fade(reverb(mix(strike, roar * 0.9 + cr), 1.5, 0.3)), peak=0.9)


def burn_shriek():
    """Something burning that isn't quite a person anymore: a cracked, falling shriek in fire."""
    dur = 2.0
    tt = t(dur)
    f = 620 * (1 - 0.45 * (tt / dur) ** 1.3) * (1 + 0.02 * np.sin(2 * np.pi * 9 * tt))
    ph = np.cumsum(f) / SR
    voice = sum(np.sin(2 * np.pi * ph * k + k) / k ** 0.8 for k in range(1, 9))
    voice += 0.4 * np.sign(np.sin(2 * np.pi * ph * 1.007))
    voice = fft_filter(voice, lo=400, hi=4500) * np.sin(np.pi * np.clip(tt / dur, 0, 1)) ** 0.6 * np.clip(tt / 0.05, 0, 1)
    fire = onepole(noise(dur), 900) * 0.5
    write("burn_shriek", fade(reverb(voice * 0.5 + fire, 1.8, 0.4)), peak=0.8)


def heard_turn():
    """A horror stops dead and turns toward a sound: the drag cuts off, a wet click in the throat."""
    dur = 1.2
    tt = t(dur)
    drag = fft_filter(noise(dur), lo=300, hi=2200) * np.clip(1 - tt / 0.25, 0, 1) ** 2 * 0.6
    pivot = fft_filter(noise(dur), lo=900, hi=4000) * np.exp(-np.abs(tt - 0.45) / 0.06) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * tt)) * 0.5
    click = fit(np.pad(np.sin(2 * np.pi * 380 * t(0.05)) * env(int(0.05 * SR), 0.001, 0.01), (int(0.62 * SR), 0)), dur)
    f = 95
    grunt = sum(np.sin(2 * np.pi * f * k * tt) / k for k in range(1, 6))
    grunt = fft_filter(grunt, lo=150, hi=800) * np.sin(np.pi * np.clip((tt - 0.65) / 0.45, 0, 1)) ** 2 * 0.35
    write("heard_turn", fade(reverb(drag + pivot + click * 0.6 + grunt, 1.4, 0.4)), peak=0.75)


def fire_loop():
    """Oil burning on stone: low roar, dense crackle. 5 s loop, played where the fire is."""
    dur = 6.0
    tt = t(dur)
    roar = onepole(noise(dur), 350) * (0.75 + 0.25 * np.sin(2 * np.pi * 0.7 * tt))
    cr = np.zeros_like(tt)
    for _ in range(160):
        pop = fft_filter(noise(0.015), lo=1200, hi=9000) * env(int(0.015 * SR), 0.0005, 0.004)
        place(cr, pop * rng.uniform(0.1, 0.8) ** 2, rng.uniform(0, dur - 0.05))
    write("fire_loop", loopify(roar * 0.8 + cr, 1.0), peak=0.7)


def main():
    if "--only" in sys.argv:
        names = sys.argv[sys.argv.index("--only") + 1:]
    else:
        names = None
    jobs = {
        "amb_moor": amb_moor, "heartbeat": heartbeat, "turn": turn, "bump": bump,
        "flame_loop": flame_loop, "lantern_bright": lantern_bright, "lantern_normal": lantern_normal,
        "lantern_hood": lantern_hood, "oil": oil, "out_of_oil": out_of_oil,
        "letter": lambda: paper("letter", 0.9, True), "letter_dim": lambda: paper("letter_dim", 0.5, False),
        "bell": bell, "death": death, "ui_click": ui_click,
        "sting_horror": lambda: strings_stab("sting_horror", [233.1, 246.9, 349.2, 370.0, 523.3], 2.2, 0.8),
        "sting_dread": lambda: strings_stab("sting_dread", [61.7, 65.4, 92.5], 3.0, 0.7),
        "stalker_silk": stalker_silk, "whisper": whisper, "panic": panic, "night_start": night_start,
        "hook_swing": hook_swing, "hook_hit": hook_hit, "hook_broke": hook_broke, "hook_found": hook_found,
        "pour": pour, "ignite": ignite, "burn_shriek": burn_shriek,
        "heard_turn": heard_turn, "fire_loop": fire_loop, "breath_behind": breath_behind,
    }
    for i in range(4):
        jobs[f"step_{i}"] = lambda i=i: footstep(i)
    for i in range(3):
        jobs[f"shuffle_{i}"] = lambda i=i: shuffle(i)
    global rng
    for name, fn in jobs.items():
        if names is None or name in names:
            rng = np.random.default_rng([1119, *name.encode()])   # per clip: --only is reproducible
            fn()


if __name__ == "__main__":
    main()
