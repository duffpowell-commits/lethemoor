"""Placeholder pixel art for the M0 render, drawn in code in the locked Amber-and-ink palette.

This is NOT the final art. The real pipeline (design doc, Stage 4) is generated sprites snapped
to the palette + hand cleanup + recoloured itch.io gothic packs. These exist so the lighting,
fog and scale can be judged on real screens right now.

    python3 tools/gen_placeholder_art.py      # writes assets/art/*.png (32x32 tiles)
"""
import random
from pathlib import Path

from PIL import Image

T = 32
OUT = Path(__file__).resolve().parent.parent / "assets" / "art"

# Amber and ink (style guide). Ink = the dark, amber = lantern light, blood = vampires/danger only.
INK = ["#05070c", "#0b111b", "#141d2b", "#202d40", "#33445a", "#4d6078"]
AMBER = ["#2a170a", "#5a3414", "#8f561f", "#c98a2e", "#f2c25a", "#ffe9a8"]
BLOOD = ["#4a0710", "#8a1020", "#c81e2e"]
BONE = ["#6f6656", "#a99c84", "#d9cdb4"]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def new():
    return Image.new("RGBA", (T, T), (0, 0, 0, 0))


def px(img, x, y, c):
    if 0 <= x < T and 0 <= y < T:
        img.putpixel((x, y), rgb(c) if isinstance(c, str) else c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def floor(seed):
    """Wet harbour cobbles: irregular stones, dark mortar, a few puddle glints."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (T, T), rgb(INK[1]))
    rows = [(0, 7), (8, 15), (16, 23), (24, 31)]
    for ri, (y0, y1) in enumerate(rows):
        x = -rnd.randint(0, 6) if ri % 2 else 0
        while x < T:
            w = rnd.randint(7, 11)
            shade = rnd.choice([INK[3], INK[3], INK[4], INK[2]])
            rect(img, x + 1, y0 + 1, x + w - 1, y1 - 1, shade)
            # top-left bevel catches light, bottom-right falls into shadow
            for xx in range(x + 1, x + w):
                px(img, xx, y0 + 1, INK[5] if shade != INK[2] else INK[3])
            for yy in range(y0 + 1, y1):
                px(img, x + w - 1, yy, INK[2])
            # grit
            for _ in range(2):
                px(img, rnd.randint(x + 2, x + w - 2), rnd.randint(y0 + 2, y1 - 2), INK[2])
            x += w
    for _ in range(rnd.randint(0, 2)):  # puddle glint
        gx, gy = rnd.randint(3, 28), rnd.randint(3, 28)
        px(img, gx, gy, INK[5])
        px(img, gx + 1, gy, BONE[0])
    return img


def wall_top():
    """Top of a wall seen from above: dark slate cap with a lighter rim."""
    img = Image.new("RGBA", (T, T), rgb(INK[0]))
    rect(img, 0, 0, T - 1, 2, INK[2])
    rnd = random.Random(7)
    for _ in range(14):
        px(img, rnd.randint(0, 31), rnd.randint(3, 31), INK[1])
    return img


def wall_face(seed):
    """Front face of a wall (drawn where the tile below is floor): old brick, moss in the joints."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (T, T), rgb(INK[1]))
    rect(img, 0, 0, T - 1, 5, INK[0])  # cap shadow
    for ri, y0 in enumerate(range(6, 32, 6)):
        off = 0 if ri % 2 == 0 else 8
        for x0 in range(-off, T, 16):
            c = rnd.choice([INK[3], INK[4], INK[3], AMBER[0]])
            rect(img, x0 + 1, y0 + 1, x0 + 14, y0 + 4, c)
            for xx in range(x0 + 1, x0 + 15):
                px(img, xx, y0 + 1, INK[5] if c == INK[4] else INK[4])
        if rnd.random() < 0.5:
            px(img, rnd.randint(0, 31), y0, "#2e3b26")
    return img


def hunter():
    """Hunter in a long coat and wide hat, lantern held out to the right."""
    img = new()
    coat, coat_lit, skin = INK[3], INK[4], BONE[1]
    rect(img, 9, 25, 22, 27, (0, 0, 0, 90))            # shadow on the ground
    rect(img, 12, 14, 19, 25, coat)                     # coat body
    rect(img, 11, 18, 20, 25, coat)
    rect(img, 12, 14, 12, 25, coat_lit)                 # rim light
    rect(img, 13, 26, 14, 27, INK[1]); rect(img, 17, 26, 18, 27, INK[1])  # boots
    rect(img, 13, 9, 18, 13, skin)                      # face
    rect(img, 14, 11, 14, 11, INK[0]); rect(img, 17, 11, 17, 11, INK[0])  # eyes
    rect(img, 10, 7, 21, 8, INK[1])                     # hat brim
    rect(img, 12, 3, 19, 7, INK[1])                     # hat crown
    rect(img, 12, 6, 19, 6, AMBER[1])                   # hat band
    rect(img, 20, 16, 23, 17, coat)                     # arm out
    rect(img, 23, 17, 23, 19, INK[5])                   # handle
    rect(img, 22, 20, 25, 24, AMBER[2])                 # lantern frame
    rect(img, 23, 21, 24, 23, AMBER[5])                 # flame
    rect(img, 22, 20, 25, 20, INK[0])
    return img


def thrall():
    """A thrall: stooped, grey-skinned, coat in rags. Red eyes = danger (blood is reserved for this)."""
    img = new()
    rect(img, 9, 25, 22, 27, (0, 0, 0, 90))
    rect(img, 11, 13, 20, 25, BONE[0])
    rect(img, 10, 17, 21, 24, INK[2])                   # rags
    for x in range(10, 22, 3):
        px(img, x, 25, INK[2])
    rect(img, 12, 7, 19, 13, BONE[0])                   # head, hunched forward
    rect(img, 13, 10, 13, 10, BLOOD[2]); rect(img, 17, 10, 17, 10, BLOOD[2])
    rect(img, 14, 12, 16, 12, INK[0])                   # mouth
    rect(img, 7, 15, 9, 21, BONE[0]); rect(img, 22, 15, 24, 21, BONE[0])  # long arms
    rect(img, 7, 22, 8, 23, INK[0]); rect(img, 23, 22, 24, 23, INK[0])    # claws
    return img


def lamp():
    """Unlit iron street lamp on a post. Relighting these is how you take the town back."""
    img = new()
    rect(img, 12, 27, 19, 28, (0, 0, 0, 90))
    rect(img, 15, 10, 16, 27, INK[2])
    rect(img, 13, 26, 18, 27, INK[3])
    rect(img, 12, 3, 19, 4, INK[3])                     # cap
    rect(img, 12, 5, 19, 10, INK[1])                    # dead glass
    rect(img, 13, 6, 13, 9, INK[4])
    rect(img, 15, 7, 16, 8, AMBER[0])                   # cold wick
    return img


def exit_grate():
    """Way out: an iron grate in the floor."""
    img = floor(99)
    rect(img, 6, 6, 25, 25, INK[0])
    for x in range(7, 25, 3):
        rect(img, x, 7, x, 24, INK[4])
    rect(img, 6, 6, 25, 6, INK[5])
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(4):
        floor(i).save(OUT / f"floor_{i}.png")
    wall_top().save(OUT / "wall_top.png")
    for i in range(2):
        wall_face(10 + i).save(OUT / f"wall_face_{i}.png")
    hunter().save(OUT / "hunter.png")
    thrall().save(OUT / "thrall.png")
    lamp().save(OUT / "lamp.png")
    exit_grate().save(OUT / "exit.png")
    print("wrote", len(list(OUT.glob("*.png"))), "tiles to", OUT)


if __name__ == "__main__":
    main()
