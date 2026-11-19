"""Round scrap of old chart paper for the corner map: assets/art/map_parchment.png (256x256, alpha).
Aged, water-stained, scorched at the rim. Original, drawn with numpy noise (seed fixed)."""
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

N = 256
rng = np.random.default_rng(1919)
yy, xx = np.mgrid[0:N, 0:N]
d = np.hypot(xx - N / 2 + 0.5, yy - N / 2 + 0.5) / (N / 2)

def noise(s, amp):
    n = gaussian_filter(rng.random((N, N)), s)
    return (n - n.mean()) / n.std() * amp

base = np.array([0.50, 0.42, 0.30])
tone = noise(18, 0.06) + noise(4, 0.025) + noise(1, 0.02)
img = np.clip(base[None, None, :] * (1 + tone[..., None]), 0, 1)
# tide marks: a few soft rings of darker stain
for cx, cy, r in [(80, 150, 46), (175, 90, 34), (150, 190, 26)]:
    rr = np.hypot(xx - cx, yy - cy)
    ring = np.exp(-((rr - r) / 3.0) ** 2) * 0.12 + np.clip(1 - rr / r, 0, 1) * 0.04
    img *= (1 - ring[..., None])
# scorched rim: darker and redder toward the edge, ragged
rim = np.clip((d + noise(6, 0.035) - 0.78) / 0.22, 0, 1) ** 1.6
img = img * (1 - 0.7 * rim[..., None]) + np.array([0.12, 0.06, 0.03]) * 0.7 * rim[..., None]
alpha = np.clip((1.0 - d + noise(3, 0.01)) / 0.03, 0, 1)
out = np.dstack([img, alpha])
Image.fromarray((out * 255).astype(np.uint8), "RGBA").save("assets/art/map_parchment.png")
print("assets/art/map_parchment.png")
