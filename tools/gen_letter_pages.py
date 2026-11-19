"""Torn parchment scraps for the letter pages: assets/art/letters/page_<n>.png.

One look per page so no two notes match. All drawn in code (numpy + PIL, fixed seeds):
  1 water-stained : yellowed, tide-line rings, ragged torn bottom, soft grey bloom of damp
  2 perfumed      : paler laid paper, a fold crease, deckled edges, faint rose blot
  3 under seal    : dark brown, scorched top edge, broken red wax seal, sooty corners
The page is drawn as a 9-slice in game (StyleBoxTexture), so torn edges keep their shape
and the middle stretches with the text. Keep the busy detail in the outer EDGE px.
Run: python3 tools/gen_letter_pages.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 960, 1280
EDGE = 160  # 9-slice margin in px (game uses EDGE / 2 in UI units); chops must fit in it
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "letters")


def noise(rng, w, h, scale):
    """Smooth value noise: random grid upscaled with bicubic."""
    g = rng.random((max(2, h // scale), max(2, w // scale)))
    im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32) / 255.0


def fbm(rng, w, h, scales=(240, 90, 30, 8), weights=(0.45, 0.3, 0.17, 0.08)):
    return sum(wt * noise(rng, w, h, s) for s, wt in zip(scales, weights))


def torn_mask(rng, ragged, inset, bites=(), chops=()):
    """Alpha mask of a torn scrap. ragged/inset per side (top, right, bottom, left): fine jag
    and how far in the edge sits. bites: big low-frequency waviness per side. chops: corners
    torn off diagonally, as (corner 0-3 = TL TR BR BL, size px)."""
    bites = bites or (0, 0, 0, 0)
    m = Image.new("L", (W, H), 0)
    pts = []
    def edge(n, a, b, side):
        out = []
        amp, ins, big = ragged[side], inset[side], bites[side]
        jag = np.cumsum(rng.normal(0, amp * 0.35, n))
        jag = jag - np.linspace(jag[0], jag[-1], n)          # pin both ends
        jag = np.clip(jag + rng.normal(0, amp * 0.3, n), -amp, amp)
        t = np.linspace(0, 1, n)
        wave = big * (0.5 + 0.5 * np.sin(t * np.pi * rng.uniform(1.5, 3.5) + rng.uniform(0, 6)))
        wave *= np.sin(t * np.pi) ** 0.5                     # no bite at the very corners
        for i in range(n):
            x = a[0] + (b[0] - a[0]) * t[i]
            y = a[1] + (b[1] - a[1]) * t[i]
            d = ins + abs(jag[i]) + wave[i]
            if side == 0: y += d
            elif side == 1: x -= d
            elif side == 2: y -= d
            else: x += d
            out.append((x, y))
        return out
    pts += edge(160, (0, 0), (W, 0), 0)
    pts += edge(200, (W, 0), (W, H), 1)
    pts += edge(160, (W, H), (0, H), 2)
    pts += edge(200, (0, H), (0, 0), 3)
    d = ImageDraw.Draw(m)
    d.polygon(pts, fill=255)
    corners = [(0, 0), (W, 0), (W, H), (0, H)]
    for c, size in chops:
        cx, cy = corners[c]
        sx = 1 if cx == 0 else -1
        sy = 1 if cy == 0 else -1
        a = (cx + sx * size * rng.uniform(0.8, 1.3), cy)
        b = (cx, cy + sy * size * rng.uniform(0.8, 1.3))
        tear = [a]
        for k in range(1, 30):
            u = k / 30
            tear.append((a[0] + (b[0] - a[0]) * u + rng.normal(0, 7), a[1] + (b[1] - a[1]) * u + rng.normal(0, 7)))
        tear.append(b)
        d.polygon([(cx, cy)] + tear, fill=0)
    return np.asarray(m.filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32) / 255.0


def edge_dist(mask):
    """Rough distance (px) from the torn edge inward, via repeated blur of the mask."""
    m = Image.fromarray((mask * 255).astype(np.uint8))
    d = np.asarray(m.filter(ImageFilter.GaussianBlur(22)), dtype=np.float32) / 255.0
    return np.clip((d - 0.5) * 2.0, 0, 1)   # 0 at the edge, 1 well inside


def compose(base, tone_noise, mask, edge_dark, edge_col):
    rgb = base[None, None, :] * (0.82 + 0.3 * tone_noise[..., None])
    inner = edge_dist(mask)[..., None]
    rgb = rgb * (1 - edge_dark * (1 - inner)) + np.array(edge_col) * edge_dark * (1 - inner) * 0.6
    fibres = noise(np.random.default_rng(7), W, H, 2)[..., None]
    rgb = rgb * (0.95 + 0.1 * fibres)
    return rgb, inner


def stain_ring(rgb, cx, cy, r, col, width, alpha, rng):
    yy, xx = np.mgrid[0:H, 0:W]
    ang = np.arctan2(yy - cy, xx - cx)
    wob = 1 + 0.08 * np.sin(ang * 3 + rng.random() * 6) + 0.05 * np.sin(ang * 7 + rng.random() * 6)
    d = np.hypot(xx - cx, yy - cy) / (r * wob)
    fill = np.clip(1 - d, 0, 1) ** 0.6 * 0.35                       # faint inside
    ring = np.exp(-((d - 1) ** 2) / (2 * (width / r) ** 2))         # dark tide line
    a = np.clip((fill + ring) * alpha, 0, 1)[..., None]
    return rgb * (1 - a) + np.array(col) * a


def save(rgb, mask, name):
    a = np.clip(mask, 0, 1)
    img = np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name), optimize=True)
    print("wrote", name)


def page_water():
    rng = np.random.default_rng(11)
    mask = torn_mask(rng, ragged=(12, 10, 40, 14), inset=(10, 14, 40, 8), bites=(10, 30, 70, 20), chops=((1, 150), (3, 90)))
    rgb, inner = compose(np.array([222, 200, 150.0]), fbm(rng, W, H), mask, 0.55, (110, 80, 40))
    for cx, cy, r in [(760, 1040, 230), (180, 300, 150), (620, 190, 90), (300, 1120, 120)]:
        rgb = stain_ring(rgb, cx, cy, r, (150, 115, 60), 7, 0.38, rng)
    damp = np.clip((noise(rng, W, H, 160) - 0.55) * 4, 0, 1)[..., None] * 0.2
    rgb = rgb * (1 - damp) + np.array([120, 118, 105]) * damp
    save(rgb, mask, "page_1.png")


def page_perfumed():
    rng = np.random.default_rng(23)
    mask = torn_mask(rng, ragged=(16, 6, 8, 18), inset=(12, 10, 10, 12), bites=(18, 8, 14, 26), chops=((3, 150), (1, 60)))
    rgb, inner = compose(np.array([236, 224, 196.0]), fbm(rng, W, H) * 0.6, mask, 0.35, (150, 120, 90))
    # laid-paper lines
    yy = np.arange(H)[:, None]
    rgb = rgb * (1 - 0.035 * (np.sin(yy * 0.9) > 0.85))[..., None]
    # fold crease across the middle: a dark line with a light shoulder
    fy = int(H * 0.47)
    for dy, k in [(-3, 1.06), (-1, 0.82), (0, 0.72), (1, 0.82), (3, 1.04)]:
        rgb[fy + dy] = rgb[fy + dy] * k
    rgb[:fy] *= 0.985
    # faint rose blot (old scent, a drop of something)
    rgb = stain_ring(rgb, 770, 260, 85, (170, 110, 120), 6, 0.35, rng)
    rgb = stain_ring(rgb, 820, 330, 30, (160, 100, 110), 4, 0.3, rng)
    save(rgb, mask, "page_2.png")


def page_sealed():
    rng = np.random.default_rng(37)
    mask = torn_mask(rng, ragged=(34, 12, 10, 12), inset=(30, 10, 10, 10), bites=(110, 20, 16, 30), chops=((0, 140),))
    rgb, inner = compose(np.array([196, 168, 120.0]), fbm(rng, W, H), mask, 0.75, (40, 25, 12))
    # scorch along the top: blacken toward the burned edge
    yy = np.arange(H)[:, None].astype(np.float32)
    edge_in = 1 - edge_dist(mask)                                  # 1 at any torn edge
    top = np.clip(1 - (yy - 20) / 240, 0, 1)
    burn = np.clip(edge_in * top * 1.6 + top * 0.35, 0, 1) * (0.7 + 0.3 * noise(rng, W, H, 30))
    rgb = rgb * (1 - 0.9 * burn[..., None]) + np.array([26, 14, 5]) * 0.9 * burn[..., None]
    # a thin orange-brown char line right at the burned rim
    rim = np.clip(edge_in * 3 - 2.2, 0, 1) * top
    rgb = rgb * (1 - rim[..., None] * 0.6) + np.array([120, 50, 14]) * rim[..., None] * 0.6
    # broken wax seal bottom right
    im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    cx, cy, r = 170, 1150, 70        # bottom left: the signature runs along the right
    blob = [(cx + (r + rng.normal(0, 6)) * np.cos(t), cy + (r + rng.normal(0, 6)) * np.sin(t))
            for t in np.linspace(0, 2 * np.pi, 40, endpoint=False)]
    d.polygon(blob, fill=(118, 22, 18))
    d.ellipse((cx - 44, cy - 44, cx + 44, cy + 44), outline=(80, 12, 10), width=5)
    d.line((cx - 60, cy - 20, cx + 10, cy + 6, cx + 64, cy - 8), fill=(60, 30, 18), width=6)  # the crack
    d.line((cx - 10, cy - 30, cx, cy + 30), fill=(150, 40, 32), width=3)                       # highlight
    rgb = np.asarray(im, dtype=np.float32)
    save(rgb, mask, "page_3.png")


if __name__ == "__main__":
    page_water()
    page_perfumed()
    page_sealed()
