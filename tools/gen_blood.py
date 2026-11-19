"""Blood, drawn with numpy noise (seeded, original):
- assets/art/fx_blood_screen.png 540x960: spatter thrown across the edges of sight, runs dripping down.
- assets/art/blood_pool.png 256x256: a dark pool with spatter, for the floor under the dead."""
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

def colour(a, rng, H, W):
    shade = gaussian_filter(rng.random((H, W)), 6)
    shade = (shade - shade.min()) / (np.ptp(shade) + 1e-6)
    r = 0.40 + 0.25 * shade
    g = 0.01 + 0.02 * shade
    b = 0.02 + 0.03 * shade
    # thin edges read wetter and brighter, thick middles nearly black
    thick = gaussian_filter(a, 3)
    k = 1.0 - 0.55 * np.clip(thick, 0, 1)
    return np.dstack([r * k, g * k, b * k, np.clip(a, 0, 1)])

def blob(a, cx, cy, r, rng, H, W, ragged=0.35):
    yy, xx = np.mgrid[0:H, 0:W]
    ang = np.arctan2(yy - cy, xx - cx)
    wob = 1 + ragged * sum(rng.random() * np.sin(k * ang + rng.random() * 6.28) / k for k in range(2, 9))
    d = np.hypot(xx - cx, yy - cy) / (r * wob)
    a += np.clip((1 - d) * 14, 0, 1)

def drip(a, x, y0, length, w, rng, H, W):
    y1 = min(H - 1, int(y0 + length))
    for y in range(int(y0), y1):
        ww = w * (0.7 + 0.3 * np.sin(y * 0.05 + x))
        x0 = int(x - ww); x1 = int(x + ww) + 1
        a[y, max(0, x0):min(W, x1)] = 1
    yy, xx = np.mgrid[0:H, 0:W]
    a += np.clip((1 - np.hypot(xx - x, yy - y1) / (w * 1.6)) * 4, 0, 1)   # the bead at the end

def screen():
    H, W = 960, 540
    rng = np.random.default_rng(66)
    a = np.zeros((H, W))
    # big throws in from the corners and sides, keeping the middle clear
    for cx, cy, r in [(-20, 120, 120), (W + 30, 260, 130), (-40, 700, 110), (W + 10, 820, 95), (260, -60, 90)]:
        blob(a, cx, cy, r, rng, H, W, 0.5)
    for _ in range(140):   # spatter, denser toward the edges
        e = rng.random()
        side = rng.integers(4)
        if side == 0: x, y = rng.random() * 110, rng.random() * H
        elif side == 1: x, y = W - rng.random() * 110, rng.random() * H
        elif side == 2: x, y = rng.random() * W, rng.random() * 120
        else: x, y = rng.random() * W, H - rng.random() * 140
        blob(a, x, y, 2 + 16 * e ** 3, rng, H, W, 0.3)
    for x, y0, L, w in [(40, 180, 260, 4), (90, 200, 150, 2.5), (W - 60, 360, 300, 5), (W - 25, 330, 180, 3), (230, 20, 120, 3), (300, 25, 70, 2), (20, 780, 160, 3)]:
        drip(a, x, y0, L, w, rng, H, W)
    a = gaussian_filter(np.clip(a, 0, 1), 1.1)
    Image.fromarray((colour(a, rng, H, W) * 255).astype(np.uint8), "RGBA").save("assets/art/fx_blood_screen.png")

def pool():
    N = 256
    rng = np.random.default_rng(77)
    a = np.zeros((N, N))
    blob(a, 128, 132, 70, rng, N, N, 0.45)
    blob(a, 90, 160, 34, rng, N, N, 0.4)
    blob(a, 170, 100, 26, rng, N, N, 0.4)
    for _ in range(60):
        ang = rng.random() * 6.28; dist = 70 + rng.random() * 50
        blob(a, 128 + np.cos(ang) * dist, 128 + np.sin(ang) * dist, 1.5 + 6 * rng.random() ** 3, rng, N, N, 0.2)
    a = gaussian_filter(np.clip(a, 0, 1), 1.2)
    yy, xx = np.mgrid[0:N, 0:N]
    a *= np.clip((126 - np.hypot(xx - 128, yy - 128)) / 8, 0, 1)
    Image.fromarray((colour(a, rng, N, N) * 255).astype(np.uint8), "RGBA").save("assets/art/blood_pool.png")

screen(); pool(); print("ok")
