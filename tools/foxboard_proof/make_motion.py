#!/usr/bin/env python3
"""Assemble GIFs from the nine Godot samples per clip (not a phone recording)."""
from pathlib import Path
import sys
from PIL import Image

src, dest = map(Path, sys.argv[1:3])
dest.mkdir(parents=True, exist_ok=True)
for state, duration in [('idle', 4.033), ('walk', 4.867), ('crouch', 2.833), ('lunge', 2.833), ('dead', 3), ('down', 3), ('rise', 1.867)]:
    frames = [Image.open(src/f'{state}_{i:02d}.png').convert('RGB').resize((360,640), Image.Resampling.LANCZOS) for i in range(9)]
    frames[0].save(dest/f'{state}.gif', save_all=True, append_images=frames[1:], duration=round(duration*1000/8), loop=0, optimize=True)
    (dest/f'{state}.png').write_bytes((src/f'{state}.png').read_bytes())
