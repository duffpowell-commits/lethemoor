#!/usr/bin/env python3
"""Original small procedural textures for the visual-only harbor atmosphere pass."""
from pathlib import Path
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'art'

# A reflection broken by ripples, deliberately incomplete and faceless.
im = Image.new('RGBA', (128, 128))
draw = ImageDraw.Draw(im)
draw.ellipse((50, 19, 77, 43), fill=(160, 176, 184, 220))
draw.polygon([(63, 40), (42, 48), (28, 69), (40, 75), (52, 61), (52, 83),
              (44, 112), (57, 118), (65, 91), (76, 117), (86, 110), (74, 80),
              (73, 60), (87, 75), (98, 68), (79, 47), (72, 40)], fill=(138, 157, 168, 210))
for y in [39, 57, 71, 84, 99]:
    draw.rectangle((20, y, 108, y + 2), fill=(0, 0, 0, 0))
im.filter(ImageFilter.GaussianBlur(1.6)).save(OUT / 'puddle_reflection.png')

# Weathered planks on the existing stacked pots/crates, not a new prop or mesh.
rng = random.Random(1519)
wood = Image.new('RGB', (128, 128))
pixels = wood.load()
for y in range(128):
    band = (y // 32) % 4
    grain = rng.uniform(-0.13, 0.13)
    for x in range(128):
        v = (0.81, 0.91, 0.73, 0.86)[band] + grain + rng.uniform(-0.055, 0.055)
        if y % 32 <= 2:
            v *= 0.46
        pixels[x, y] = tuple(int(max(0, min(255, c * v))) for c in (232, 212, 186))
wood = wood.filter(ImageFilter.GaussianBlur(0.4))
wood.save(OUT / 'harbor_crate_wood.png')
