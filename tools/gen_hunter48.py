"""First 'real art' test: a 48x48 HD-2D-style lantern-bearer, drawn in code.

Writes three images to assets/art/:
    hunter48.png        the sprite (Amber-and-ink palette, flat-ish shading)
    hunter48_n.png      its normal map, so Godot's 2D lights shade it (the HD-2D trick)
    hunter48_glow.png   only the flame pixels, drawn unshaded so the lantern glows in the dark

The sprite is kept fairly neutral on purpose: the engine light does the drama.
    python3 tools/gen_hunter48.py
"""
import math
from pathlib import Path

from PIL import Image, ImageFilter

S = 48
OUT = Path(__file__).resolve().parent.parent / "assets" / "art"

INK = ["#05070c", "#0b111b", "#141d2b", "#202d40", "#33445a", "#4d6078"]
AMBER = ["#2a170a", "#5a3414", "#8f561f", "#c98a2e", "#f2c25a", "#ffe9a8"]
BONE = ["#6f6656", "#a99c84", "#d9cdb4"]
MOSS = "#2e3b26"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# --- 1. part mask: which body part each pixel belongs to -------------------------------
EMPTY, COAT, HAT, SKIN, HAIR, BOOT, ARM, LANTERN, FLAME, CHAIN, SCARF = range(11)
part = [[EMPTY] * S for _ in range(S)]


def put(x, y, p):
    if 0 <= x < S and 0 <= y < S:
        part[y][x] = p


def fill(x0, y0, x1, y1, p):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(x, y, p)


def span(y, x0, x1, p):
    for x in range(x0, x1 + 1):
        put(x, y, p)


# Long coat: narrow shoulders, flares to a ragged hem. Slight stoop: torso leans left.
for y in range(19, 44):
    t = (y - 19) / 24.0
    half = 5 + t * 7.5                      # 5 px half-width at shoulders -> 12.5 at hem
    cx = 23.0 - (1.0 - t) * 1.0             # stoop
    span(y, int(cx - half), int(cx + half), COAT)
# ragged hem: teeth of uneven length
for x, drop in zip(range(11, 36), [2, 0, 1, 3, 1, 0, 2, 1, 0, 0, 3, 1, 0, 2, 0, 1, 3, 0, 1, 2, 0, 1, 2, 0, 1]):
    for d in range(drop):
        if part[43][x] == COAT:
            put(x, 44 + d - 1, COAT)
# torn notch in the coat
fill(14, 38, 15, 43, EMPTY)
put(16, 42, EMPTY)

# boots peeking out under the hem
fill(18, 44, 21, 46, BOOT)
fill(25, 44, 28, 46, BOOT)

# scarf / high collar
fill(18, 17, 27, 20, SCARF)
fill(16, 20, 18, 26, SCARF)                 # trailing end on the left

# head: gaunt, long, tilted forward
fill(19, 10, 26, 18, SKIN)
fill(20, 19, 25, 19, SKIN)                  # long chin
# stringy hair hanging past the face
for x, ln in [(18, 6), (19, 8), (26, 7), (27, 5)]:
    fill(x, 11, x, 11 + ln, HAIR)

# wide slouched hat: crown + brim drooping at both ends
fill(19, 3, 27, 9, HAT)
span(2, 21, 25, HAT)
span(9, 13, 33, HAT)
span(10, 12, 34, HAT)
span(11, 12, 14, HAT)
span(11, 32, 35, HAT)
put(12, 12, HAT)
put(35, 12, HAT)
fill(18, 3, 18, 8, HAT)                     # dent on the crown's left
put(27, 2, EMPTY)

# gaunt head: round off the corners, taper the jaw
for x, y in [(19, 10), (26, 10), (19, 17), (19, 18), (26, 18), (20, 19), (25, 19)]:
    put(x, y, EMPTY)
put(19, 10, HAIR)
put(26, 10, HAIR)

# sloped, bony shoulders
span(20, 15, 29, COAT)
span(21, 14, 30, COAT)

# left arm hangs dead at the side, long bony fingers
fill(12, 22, 14, 33, ARM)
fill(15, 23, 15, 33, EMPTY)                 # gap so the arm reads apart from the coat
for x, ln in [(12, 5), (13, 2), (14, 6)]:
    fill(x, 34, x, 33 + ln, SKIN)
put(13, 34, ARM)

# right arm out and down, holding the lantern low
fill(29, 21, 31, 26, ARM)
fill(31, 25, 35, 27, ARM)
fill(35, 26, 36, 28, SKIN)                  # hand
# chain
for y in range(29, 31):
    put(36, y, CHAIN)

# lantern: cap, cage, glass
fill(34, 31, 39, 31, LANTERN)
fill(33, 32, 40, 32, LANTERN)
for y in range(33, 39):
    put(33, y, LANTERN)
    put(40, y, LANTERN)
    put(36, y, LANTERN)
fill(33, 39, 40, 40, LANTERN)
fill(34, 33, 35, 38, FLAME)
fill(37, 33, 39, 38, FLAME)


def solid(x, y):
    return 0 <= x < S and 0 <= y < S and part[y][x] != EMPTY


# --- 2. colour ------------------------------------------------------------------------
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))

BASE = {
    COAT: [INK[2], INK[3], INK[4]],
    HAT: [INK[1], INK[2], INK[3]],
    SKIN: [BONE[0], BONE[1], BONE[2]],
    HAIR: [INK[0], INK[1], INK[2]],
    BOOT: [INK[0], INK[1], INK[1]],
    ARM: [INK[2], INK[3], INK[4]],
    LANTERN: [AMBER[0], AMBER[1], AMBER[2]],
    CHAIN: [INK[3], INK[4], INK[5]],
    SCARF: [AMBER[0], AMBER[1], AMBER[1]],
}

for y in range(S):
    for x in range(S):
        p = part[y][x]
        if p == EMPTY:
            continue
        if p == FLAME:
            # hot core in the middle of each pane, amber at the edges
            core = (y in (35, 36)) and x in (34, 35, 37, 38)
            c = AMBER[5] if core else (AMBER[4] if 34 <= y <= 37 else AMBER[3])
            img.putpixel((x, y), rgb(c) + (255,))
            glow.putpixel((x, y), rgb(c) + (255,))
            continue
        shades = BASE[p]
        # baked form shading only: light from upper right (the engine adds the lantern)
        lit = solid(x - 1, y) and not solid(x + 1, y)          # right silhouette edge
        dark = not solid(x - 1, y) or not solid(x, y + 1)      # left edge / underside
        i = 2 if lit else (0 if dark else 1)
        img.putpixel((x, y), rgb(shades[i]) + (255,))

# details on top of the base
P = img.putpixel
for x, y in [(21, 13), (24, 13)]:                       # hollow eye sockets
    P((x, y), rgb(INK[0]) + (255,))
    P((x, y + 1), rgb(INK[1]) + (255,))
P((24, 13), rgb(AMBER[3]) + (255,))                     # one eye catches the lantern
for x in range(21, 25):                                 # thin mouth line
    P((x, 17), rgb(BONE[0]) + (255,))
P((22, 17), rgb(INK[0]) + (255,))
for y in range(11, 13):                                  # brim shadow on the brow
    for x in range(19, 27):
        P((x, y), rgb(BONE[0]) + (255,))
P((20, 15), rgb(BONE[0]) + (255,))                       # sunken cheeks
P((25, 15), rgb(BONE[0]) + (255,))
for x in range(19, 28):                                  # hat band
    P((x, 8), rgb(AMBER[1]) + (255,))
for y in (24, 28, 32):                                   # coat buttons, one missing
    if y != 28:
        P((25, y), rgb(INK[5]) + (255,))
for x, y in [(19, 41), (27, 40), (30, 42)]:              # moss and mud on the hem
    P((x, y), rgb(MOSS) + (255,))
for y in range(22, 42):                                  # coat seam, front opening
    if solid(24, y) and part[y][24] == COAT:
        P((24 if y < 32 else 25, y), rgb(INK[1]) + (255,))

# selective outline: one ink pixel around the silhouette (keeps it readable on dark ground)
outline = []
for y in range(S):
    for x in range(S):
        if not solid(x, y) and any(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            outline.append((x, y))
for x, y in outline:
    P((x, y), rgb(INK[0]) + (255,))

# soft ground shadow under the feet (drawn last, only on empty pixels)
for y in range(45, 48):
    for x in range(12, 37):
        if img.getpixel((x, y))[3] == 0:
            dx = (x - 24) / 12.5
            dy = (y - 46) / 1.6
            if dx * dx + dy * dy <= 1.0:
                P((x, y), (0, 0, 0, 110))

# --- 3. normal map --------------------------------------------------------------------
# Height = how far a pixel is from the silhouette edge (rounded "pillow" bodies), with the
# hat brim and lantern raised a bit. Normals come from the height gradient.
alpha = Image.new("L", (S, S), 0)
for y in range(S):
    for x in range(S):
        if part[y][x] != EMPTY:
            alpha.putpixel((x, y), 255)
height = alpha.filter(ImageFilter.GaussianBlur(2.2))
hp = [[height.getpixel((x, y)) / 255.0 for x in range(S)] for y in range(S)]
for y in range(S):
    for x in range(S):
        if part[y][x] in (HAT, LANTERN, FLAME):
            hp[y][x] += 0.25

normal = Image.new("RGBA", (S, S), (128, 128, 255, 0))
STRENGTH = 3.0
for y in range(S):
    for x in range(S):
        a = img.getpixel((x, y))[3]
        if a == 0:
            continue
        def h(xx, yy):
            xx = min(max(xx, 0), S - 1)
            yy = min(max(yy, 0), S - 1)
            return hp[yy][xx]
        dx = (h(x + 1, y) - h(x - 1, y)) * STRENGTH
        dy = (h(x, y + 1) - h(x, y - 1)) * STRENGTH
        nx, ny, nz = -dx, dy, 1.0             # Godot 2D: green = up (screen y flipped)
        ln = math.sqrt(nx * nx + ny * ny + nz * nz)
        nx, ny, nz = nx / ln, ny / ln, nz / ln
        normal.putpixel((x, y), (int((nx * 0.5 + 0.5) * 255), int((ny * 0.5 + 0.5) * 255),
                                 int((nz * 0.5 + 0.5) * 255), a))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / "hunter48.png")
    normal.save(OUT / "hunter48_n.png")
    glow.save(OUT / "hunter48_glow.png")
    print("wrote hunter48.png, hunter48_n.png, hunter48_glow.png to", OUT)


if __name__ == "__main__":
    main()
