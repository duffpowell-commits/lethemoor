"""Turn a generated texture into a seamless, evenly lit tile.

    python3 tools/make_tile.py in.png out.png [size] [--tame]

1. Flatten lighting: divide out a heavy blur so baked highlights/shadows go (the engine lights it).
2. Make it wrap: blend the image with its half-offset copy, using a mask that hides the
   original edges (classic offset-and-feather), so edges match on every side.
3. --tame: squash bright spots (white mortar, salt) so the lantern doesn't make them glow.
4. Shrink to `size` (default 256: small for phones).
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
args = [x for x in sys.argv[3:] if not x.startswith('--')]
size = int(args[0]) if args else 256
tame = '--tame' in sys.argv
im = Image.open(src).convert("RGB")
n = min(im.size)
im = im.crop(((im.width - n) // 2, (im.height - n) // 2, (im.width - n) // 2 + n, (im.height - n) // 2 + n))
im = im.resize((1024, 1024), Image.LANCZOS)
a = np.asarray(im).astype(np.float32) / 255

# 1. flatten: keep detail, drop large-scale light falloff
low = np.asarray(im.filter(ImageFilter.GaussianBlur(160))).astype(np.float32) / 255
mean = a.reshape(-1, 3).mean(0)
a = np.clip(a / np.maximum(low, 0.02) * mean, 0, 1)

# 2. wrap: offset copy, mask = distance from the original edge
b = np.roll(a, (512, 512), (0, 1))
y, x = np.mgrid[0:1024, 0:1024] / 1023.0
d = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y))   # 0 at edges, .5 at centre
w = np.clip((d - 0.05) / 0.2, 0, 1)[..., None]               # original wins in the middle
out = a * w + b * (1 - w)

if tame:   # soft knee above 0.45 luminance, and pull those pixels toward grey-brown
    lum = out @ np.array([0.3, 0.59, 0.11])
    k = np.clip((lum - 0.45) / 0.55, 0, 1)[..., None]
    out = out * (1 - 0.55 * k) + np.array([0.33, 0.31, 0.28]) * 0.55 * k

Image.fromarray((out * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS).save(dst, optimize=True)
print(dst, size)
