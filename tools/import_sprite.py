"""Turn a green-screen character design (Grok, any generator) into game-ready pixel art.

    python3 tools/import_sprite.py SRC NAME [--size 48] [--crop x0,y0,x1,y1]

Pipeline:
  1. cut out the green background (and remove green spill on the edges)
  2. shrink to SIZE px tall, averaging (not nearest) so detail turns into shading, not noise
  3. snap every pixel to the locked Amber-and-ink palette
  4. clean up: isolated speckle pixels take their neighbours' colour (the "black holes")
  5. one-pixel ink outline so the figure reads on dark cobbles
  6. write NAME.png, NAME_n.png (normal map for 2D lights) and NAME_glow.png (lantern flame only,
     drawn unshaded in Godot) to assets/art/

Design comes from the generator; this script is the art director. Hand-fix after if needed.
"""
import argparse
import math
from collections import Counter
from pathlib import Path

from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "art"

INK = ["#05070c", "#0b111b", "#141d2b", "#202d40", "#33445a", "#4d6078"]
AMBER = ["#2a170a", "#5a3414", "#8f561f", "#c98a2e", "#f2c25a", "#ffe9a8"]
BLOOD = ["#4a0710", "#8a1020", "#c81e2e"]
BONE = ["#6f6656", "#a99c84", "#d9cdb4"]
EXTRA = ["#2e3b26", "#3f4a2c", "#4a3a26"]  # moss, rotten olive, old leather: earthy darks for cloth
PALETTE = INK + AMBER + BONE + EXTRA       # blood is reserved for danger: never auto-snapped to
FLAME = set(AMBER[3:])


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


PAL = [(c, rgb(c)) for c in PALETTE]


def nearest(p, allow_flame=True):
    """Nearest palette colour, weighted toward how eyes judge brightness (green counts most)."""
    r, g, b = p
    best, bd = None, 1e18
    for name, (pr, pg, pb) in PAL:
        if not allow_flame and name in FLAME:
            continue
        rm = (r + pr) / 2
        d = (2 + rm / 256) * (r - pr) ** 2 + 4 * (g - pg) ** 2 + (2 + (255 - rm) / 256) * (b - pb) ** 2
        if d < bd:
            best, bd = name, d
    return best


def key_green(im):
    """RGB -> RGBA with the green screen removed and green spill pulled out of edge pixels."""
    im = im.convert("RGB")
    out = Image.new("RGBA", im.size)
    px, op = im.load(), out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            if g > 120 and g > r * 1.6 and g > b * 1.6:
                op[x, y] = (0, 0, 0, 0)
            else:
                g = min(g, max(r, b) + 10)  # despill
                op[x, y] = (r, g, b, 255)
    return out


def shrink(im, size):
    bbox = im.getchannel("A").point(lambda a: 255 if a > 0 else 0).getbbox()
    im = im.crop(bbox)
    scale = (size - 2) / im.height        # 1 px top + bottom left for the outline
    w = max(1, round(im.width * scale))
    h = size - 2
    # premultiply so transparent green doesn't bleed into edge colours while averaging
    small = im.resize((w, h), Image.BOX, reducing_gap=3.0)
    # blend in a "darkest pixel per block" pass so eye sockets, seams and folds survive
    dark = im.filter(ImageFilter.MinFilter(max(3, (int(1 / scale) // 2) * 2 + 1))).resize((w, h), Image.BOX)
    small = Image.blend(small, dark, 0.12)
    canvas = Image.new("RGBA", (max(size, w + 2), size), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((canvas.width - w) // 2, 1))
    return canvas


def run(src, name, size, crop):
    im = Image.open(src)
    if crop:
        im = im.crop(crop)
    im = shrink(key_green(im), size)
    W, H = im.size
    grid = [[None] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            r, g, b, a = im.getpixel((x, y))
            if a >= 128:
                # bright amber is the lantern's alone: elsewhere it becomes bone/ink
                grid[y][x] = nearest((r, g, b), x > W * 0.55 and y > H * 0.4)

    def n4(x, y):
        return [grid[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if 0 <= x + dx < W and 0 <= y + dy < H]

    # speckle cleanup, two passes: a pixel that matches none of its neighbours and is darker
    # than them takes the most common neighbour colour. Bright details (eyes, flame) survive.
    lum = {c: sum(v * k for v, k in zip(rgb(c), (0.3, 0.59, 0.11))) for c in PALETTE}
    for _ in range(2):
        changed = []
        for y in range(H):
            for x in range(W):
                c = grid[y][x]
                if c is None:
                    continue
                nb = [n for n in n4(x, y) if n is not None]
                if len(nb) == 4 and c not in nb and lum[c] < min(lum[n] for n in nb):
                    changed.append((x, y, Counter(nb).most_common(1)[0][0]))
        for x, y, c in changed:
            grid[y][x] = c

    def n8(x, y):
        return [grid[y + dy][x + dx] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                if (dx or dy) and 0 <= x + dx < W and 0 <= y + dy < H]

    changed = []
    for y in range(H):
        for x in range(W):
            c = grid[y][x]
            if c is None or c in FLAME or c in BONE:
                continue
            nb = [n for n in n8(x, y) if n is not None]
            if len(nb) >= 7 and nb.count(c) == 0:
                top, cnt = Counter(nb).most_common(1)[0]
                if cnt >= 4:
                    changed.append((x, y, top))
    for x, y, c in changed:
        grid[y][x] = c

    # trim lone pixels hanging off the silhouette
    for y in range(H):
        for x in range(W):
            if grid[y][x] and sum(n is not None for n in n4(x, y)) <= 1:
                grid[y][x] = None

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            c = grid[y][x]
            if c:
                img.putpixel((x, y), rgb(c) + (255,))
                # flame = bright amber in the right half (where the lantern hangs)
                if c in FLAME and x > W * 0.55:
                    glow.putpixel((x, y), rgb(c) + (255,))
    for y in range(H):
        for x in range(W):
            if grid[y][x] is None and any(n is not None for n in n4(x, y)):
                img.putpixel((x, y), rgb(INK[0]) + (255,))

    # normal map: rounded "pillow" height from distance to the silhouette edge
    alpha = img.getchannel("A")
    height = alpha.filter(ImageFilter.GaussianBlur(max(1.5, H / 22)))
    hp = [[height.getpixel((x, y)) / 255.0 for x in range(W)] for y in range(H)]
    normal = Image.new("RGBA", (W, H), (128, 128, 255, 0))
    k = 3.0
    for y in range(H):
        for x in range(W):
            a = alpha.getpixel((x, y))
            if not a:
                continue
            hx = lambda xx: hp[y][min(max(xx, 0), W - 1)]
            hy = lambda yy: hp[min(max(yy, 0), H - 1)][x]
            nx, ny, nz = -(hx(x + 1) - hx(x - 1)) * k, (hy(y + 1) - hy(y - 1)) * k, 1.0
            ln = math.sqrt(nx * nx + ny * ny + nz * nz)
            normal.putpixel((x, y), (int((nx / ln * 0.5 + 0.5) * 255), int((ny / ln * 0.5 + 0.5) * 255),
                                     int((nz / ln * 0.5 + 0.5) * 255), a))

    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")
    normal.save(OUT / f"{name}_n.png")
    glow.save(OUT / f"{name}_glow.png")
    print(f"wrote {name}.png ({W}x{H}), {name}_n.png, {name}_glow.png "
          f"({sum(1 for y in range(H) for x in range(W) if glow.getpixel((x, y))[3])} flame px)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("name")
    ap.add_argument("--size", type=int, default=48)
    ap.add_argument("--crop", type=lambda s: tuple(int(v) for v in s.split(",")))
    a = ap.parse_args()
    run(a.src, a.name, a.size, a.crop)
