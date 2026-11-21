"""64 px cleanup pass: chroma-key green (hue tolerance), crop, nearest-neighbour to 64 px tall,
de-spill, quantize to <=16 colours (k-means seeded by median cut + forced accent colours so the
porcelain-mask white, blood red and near-black survive), drop orphan pixels. Usage: cleanup_64.py src.png out_prefix [height=64] [--shadow]
--shadow also keys out dark-green ground shadows (green-dominant pixels of any brightness)."""
import sys, numpy as np
from PIL import Image
args = [x for x in sys.argv[1:] if not x.startswith('--')]
src, out = args[0], args[1]
H = int(args[2]) if len(args) > 2 else 64
SHADOW = '--shadow' in sys.argv
im = Image.open(src).convert('RGB'); a = np.asarray(im).astype(int)
g = (a[..., 1] > 140) & (a[..., 1] - np.maximum(a[..., 0], a[..., 2]) > 70)
if SHADOW:
    g |= (a[..., 1] - np.maximum(a[..., 0], a[..., 2]) > 12) & (a[..., 1] > 35)
    # drop leftover shadow specks: opaque pixels with < 5 opaque neighbours in a 5x5 window
    for _ in range(2):
        fg = (~g).astype(int); p = np.pad(fg, 2)
        cnt = sum(p[2 + dy:p.shape[0] - 2 + dy, 2 + dx:p.shape[1] - 2 + dx] for dy in range(-2, 3) for dx in range(-2, 3))
        g |= (fg == 1) & (cnt < 6)
ys, xs = np.nonzero(~g); box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
crop = im.crop(box); mask = Image.fromarray(((~g) * 255).astype('uint8')).crop(box)
w = round(crop.size[0] * H / crop.size[1])
arr = np.asarray(crop.resize((w, H), Image.NEAREST)).astype(float)
mk = np.asarray(mask.resize((w, H), Image.NEAREST)) > 127
r, gg, b = arr[..., 0], arr[..., 1], arr[..., 2]
arr[..., 1] = np.where(gg > np.maximum(r, b), np.maximum(r, b), gg)          # de-spill
px = arr[mk]
# forced accents: brightest (bone/porcelain) and most saturated red
lum = px @ [0.3, 0.59, 0.11]; red = px[:, 0] - np.maximum(px[:, 1], px[:, 2])
bright = px[lum >= np.percentile(lum, 97)].mean(0)
blood = px[red >= np.percentile(red, 96)].mean(0)
dark = px[lum <= np.percentile(lum, 4)].mean(0)
seed = np.asarray(Image.fromarray(px.reshape(-1, 1, 3).astype('uint8')).quantize(13, method=Image.Quantize.MEDIANCUT).getpalette()[:39]).reshape(13, 3).astype(float)
C = np.vstack([seed, bright, blood, dark])
for _ in range(15):                                   # k-means, accents stay fixed
    lab = ((px[:, None, :] - C[None]) ** 2).sum(2).argmin(1)
    for k in range(13):
        if (lab == k).any(): C[k] = px[lab == k].mean(0)
lab = ((px[:, None, :] - C[None]) ** 2).sum(2).argmin(1)
o = np.zeros((H, w, 4), 'uint8'); o[mk, :3] = C[lab].round().astype('uint8'); o[mk, 3] = 255
al = o[..., 3] > 0; p = np.pad(al, 1); nb = p[:-2, 1:-1].astype(int) + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]
o[al & (nb == 0)] = 0
img = Image.fromarray(o, 'RGBA'); img.save(out + f'_{H}px_q16.png')
gb = Image.new('RGBA', img.size, (0, 255, 0, 255)); gb.alpha_composite(img); gb.convert('RGB').save(out + f'_{H}px_q16_green.png')
cols = np.unique(o[o[..., 3] > 0][:, :3], axis=0)
pal = Image.new('RGB', (16 * len(cols), 16))
for i, c in enumerate(cols): pal.paste(tuple(int(x) for x in c), (i * 16, 0, i * 16 + 16, 16))
pal.save(out + '_palette16.png')
before = Image.fromarray(np.asarray(crop.resize((w, H), Image.NEAREST)))
prev = Image.new('RGB', (w * 12 + 30, H * 6), (18, 20, 28))
prev.paste(before.resize((w * 6, H * 6), Image.NEAREST), (0, 0)); prev.paste(gb.convert('RGB').resize((w * 6, H * 6), Image.NEAREST), (w * 6 + 30, 0))
prev.save(out + '_before_after_x6.png')
print(img.size, 'colours', len(cols))
