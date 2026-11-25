#!/usr/bin/env python3
"""Lethemoor: real recordings in place of the synthesized clips where a recording matters most.

Duff, Nov 25: "Free library, I pick". Only CC0 or public-domain sources, so nothing needs a credit
or a licence file in the game; each one is still logged in assets/audio/SOURCES.md. The rest of the
kit stays synthesized (tools/gen_audio.py): stings, whispers, the death, the heartbeat, the UI.

    python3 tools/real_audio.py            # downloads the sources once, rewrites the clips below
    python3 tools/real_audio.py --only bell

Each new clip keeps the loudness (RMS) of the clip it replaces, so the mix in audio.gd stays put.
Reverb is baked in like the rest (the web build plays audio without bus effects).
Run gen_audio.py first if you rebuild everything: it would overwrite these clips with the old ones.
"""
import os
import subprocess
import sys
import urllib.request

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import gen_audio as G  # noqa: E402  (reverb, fade, loopify, write, SR)

SR = G.SR
CACHE = os.path.expanduser("~/.cache/lethemoor_real_audio")
OGA = "https://opengameart.org/sites/default/files/"
ARC = "https://archive.org/download/"

# name -> (url, licence, where it's from); every one CC0 or public domain
SOURCES = {
    "rocamadour.mp3": (ARC + "aporee_61861_71175/RocamadourBell01LR.mp3",
                       "Public Domain Mark", "Radio Aporee: Rocamadour church bell, France (kaoss012)"),
    "ploumanach.mp3": (ARC + "aporee_34708_39904/CAPSPloumanachPortnightCarillonboatswavesandwhistlingMEDIUMFAR.mp3",
                       "Public Domain Mark", "Radio Aporee: Ploumanac'h port at night (yponomeutaneko)"),
    "atmosbasement.flac": (OGA + "atmosbasement.mp3_.flac", "CC0", "OpenGameArt: Dripping water loop"),
    "fantozzi.7z": (OGA + "Fantozzi-footsteps.7z", "CC0", "OpenGameArt: Fantozzi's footsteps (grass/sand/stone)"),
    "fire.ogg": (OGA + "fire-1_0.ogg", "CC0", "OpenGameArt: Fire crackling"),
    "undead.zip": (OGA + "undead-moans.zip", "CC0", "OpenGameArt: Undead moans"),
    "zombie.ogg": (OGA + "darsycho__zombie-moans_0.ogg", "CC0", "OpenGameArt: Zombie moans (darsycho)"),
    "paper1.mp3": (OGA + "paper_sound_-_1.mp3", "CC0", "OpenGameArt: Various paper sound effects"),
    "paper3.mp3": (OGA + "paper_sound_-_3.mp3", "CC0", "OpenGameArt: Various paper sound effects"),
}


def fetch(name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        req = urllib.request.Request(SOURCES[name][0], headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
            f.write(r.read())
    return path


def unpack(name, member):
    """A file from inside a zip or 7z source."""
    path = fetch(name)
    out = os.path.join(CACHE, name + ".d")
    if not os.path.isdir(out):
        if name.endswith(".zip"):
            import zipfile
            zipfile.ZipFile(path).extractall(out)
        else:
            import py7zr  # pip install py7zr
            py7zr.SevenZipFile(path).extractall(out)
    for root, _dirs, files in os.walk(out):
        if member in files:
            return os.path.join(root, member)
    raise FileNotFoundError(member)


def load(path, start=0.0, dur=None, channels=1):
    cmd = ["ffmpeg", "-v", "quiet", "-ss", str(start)] + (["-t", str(dur)] if dur else []) + [
        "-i", path, "-ac", str(channels), "-ar", str(SR), "-f", "f32le", "-"]
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)
    return x.reshape(-1, channels).T if channels > 1 else x


## Loudness (RMS dB; the stereo bed per channel) of the synthesized clips these replace, measured once
## (Nov 25) and fixed here, so the game's mix doesn't move and a re-run doesn't creep louder.
LOUD = {"bell": -18.6, "amb_moor": -15.2, "step_0": -27.9, "step_1": -27.9, "step_2": -29.5,
        "step_3": -28.8, "fire_loop": -22.6, "shuffle_0": -25.2, "shuffle_2": -25.2,
        "letter": -33.3, "letter_dim": -35.9}


def highpass(x, f):
    return G.fft_filter(x, lo=f)


def put(name, x, stereo=None, target=None):
    """Write `name` at the loudness of the clip it replaces (LOUD; peaks soft-limited)."""
    target = LOUD[name] if target is None else target
    both = x if stereo is None else np.concatenate([x, stereo])   # stereo: per-channel RMS
    gain = 10 ** (target / 20) / (np.sqrt(np.mean(both ** 2)) + 1e-12)
    lim = lambda v: 0.8 * np.tanh(v * gain / 0.8)     # soft knee: real transients (a mast knocking) stay under 0 dB after Vorbis
    x = lim(x)
    if stereo is not None:
        stereo = lim(stereo)
    peak = max(np.abs(x).max(), np.abs(stereo).max() if stereo is not None else 0)
    G.write(name, x, peak=min(0.98, peak), stereo=stereo)


# ------------------------------------------------------------------ the clips

def bell():
    """The win: a real church bell peal, far over the town. Also the toll (pitched down in audio.gd)."""
    x = load(fetch("rocamadour.mp3"), 12.9, 10.5)
    x = highpass(x, 70)
    x = G.reverb(x, size=2.2, wet=0.25, damp=4000)[: len(x)]
    put("bell", G.fade(x, 0.004, 3.0))


def amb_moor():
    """40 s stereo bed: a harbour at night, boats knocking, wind in the rigging, plus slow drips."""
    l, r = load(fetch("ploumanach.mp3"), 24.0, 42.0, channels=2)
    l, r = G.fft_filter(l, lo=45, hi=9000), G.fft_filter(r, lo=45, hi=9000)   # no mic thumps or fizz
    drips = load(fetch("atmosbasement.flac"), 0.0, 20.0)
    drips = np.tile(drips, 3)[: len(l)] * 0.35
    l, r = G.loopify(l + drips, 2.0), G.loopify(r + np.roll(drips, SR // 3), 2.0)
    put("amb_moor", l, stereo=r)


def steps():
    """Boots on stone, four takes, with the small cave tail the old ones had."""
    for i, f in enumerate(["Fantozzi-StoneL1.ogg", "Fantozzi-StoneR1.ogg", "Fantozzi-StoneL2.ogg", "Fantozzi-StoneR3.ogg"]):
        x = load(unpack("fantozzi.7z", f))
        x = highpass(x, 60)
        x = G.reverb(G.fit(x, 0.8), size=0.9, wet=0.28, damp=2500)[: int(0.8 * SR)]
        put(f"step_{i}", G.fade(x, 0.002, 0.15))


def fire_loop():
    """Oil burning on stone, a seamless 5 s loop."""
    x = load(fetch("fire.ogg"))
    x = np.concatenate([x, x[::-1], x])[: int(6.5 * SR)]
    put("fire_loop", G.loopify(G.reverb(x, 0.8, 0.2)[: len(x)], 1.5))


def thrall_moans():
    """Two of the three shuffle takes get a real moan over the dragged foot; the third stays a bare drag."""
    drag = load(os.path.join(G.OUT, "shuffle_1.ogg"))     # the take without a groan
    for i, (src, start, dur) in enumerate([(("undead.zip", "undead-1.ogg"), 0.0, 1.6),
                                           (("zombie.ogg", None), 2.0, 1.6)]):
        path = unpack(*src) if src[1] else fetch(src[0])
        m = load(path, start, dur)
        m = G.fft_filter(m, lo=90, hi=3500) * np.sin(np.pi * np.clip(np.arange(len(m)) / (0.25 * SR), 0, 1)) ** 2
        m = G.reverb(m, 1.2, 0.3)[: len(m)]
        n = max(len(drag), len(m) + int(0.25 * SR))
        out = np.zeros(n)
        out[: len(drag)] += drag
        out[int(0.25 * SR): int(0.25 * SR) + len(m)] += m * 0.6
        put(f"shuffle_{0 if i == 0 else 2}", G.fade(out, 0.003, 0.1))


def letters():
    """Old paper handled: the letter read, and the softer touch when it's too dim to read."""
    for name, src in [("letter", "paper1.mp3"), ("letter_dim", "paper3.mp3")]:
        x = load(fetch(src))
        x = G.reverb(G.fit(x, len(x) / SR + 0.5), 0.6, 0.15)
        put(name, G.fade(x, 0.003, 0.2))


CLIPS = {"bell": bell, "amb_moor": amb_moor, "steps": steps, "fire_loop": fire_loop,
         "thrall_moans": thrall_moans, "letters": letters}


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    for name, fn in CLIPS.items():
        if only is None or only == name:
            fn()


if __name__ == "__main__":
    main()
