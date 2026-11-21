"""NOTE: the plus-shaped Gaussian seam heal in an earlier draft left a dark cross on every join.
The delivered *_512.png files were remade with a thin opposite-edge average (wrap_edges, band 28; light 14px rim on hero grates). Do not re-run the blur path on the finished tiles.
"""
#!/usr/bin/env python3
"""Resize painted env textures to 512, fix seams, build 3x3 repeats and a contact sheet."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
OUT = ROOT
TILES = ROOT / "tiles_3x3"
DETAIL = ROOT / "detail"
REF_FLOOR = Path("/workspace/lethemoor/repo_refs/floor_stone.png")
SIZE = 512
BAND = 28  # thin opposite-edge blend at 512 (a plus-shaped blur left a dark grid; do not use it)

TILES.mkdir(exist_ok=True)
DETAIL.mkdir(exist_ok=True)


def smoothstep(t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def make_seamless(im: Image.Image, band: int = BAND, unique: bool = False) -> Image.Image:
    """Make opposite edges meet by averaging toward each other in a thin rim. Interior stays sharp.
    unique=True uses a narrower rim so a centered grate is not touched. Do NOT blur a plus
    across the rolled seam: that left a dark smeared grid in every 3x3.
    """
    arr = np.asarray(im.convert("RGB")).astype(np.float32)
    h, w, _ = arr.shape
    use = 14 if unique else band
    out = arr.copy()
    for i in range(use):
        a = 0.5 * (1.0 - i / use)
        L, R = arr[:, i], arr[:, w - 1 - i]
        mix = (L + R) * 0.5
        out[:, i] = L * (1 - a) + mix * a
        out[:, w - 1 - i] = R * (1 - a) + mix * a
    arr = out.copy()
    for i in range(use):
        a = 0.5 * (1.0 - i / use)
        T, B = arr[i, :], arr[h - 1 - i, :]
        mix = (T + B) * 0.5
        out[i, :] = T * (1 - a) + mix * a
        out[h - 1 - i, :] = B * (1 - a) + mix * a
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def patch_leaves(im: Image.Image, boxes: list[tuple[int, int, int, int]]) -> Image.Image:
    """Stamp each box with a nearby mortar patch, then slight blur on the stamp edge."""
    out = im.copy()
    for x0, y0, x1, y1, sx, sy in boxes:
        w, h = x1 - x0, y1 - y0
        src = out.crop((sx, sy, sx + w, sy + h))
        # feathered paste
        mask = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(mask)
        inset = max(2, min(w, h) // 6)
        d.ellipse((inset, inset, w - inset, h - inset), fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(radius=inset))
        out.paste(src, (x0, y0), mask)
    return out


def find_leafish(im: Image.Image) -> list[tuple[int, int]]:
    """Debug: locate brown/olive leaf pixels."""
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    # leaves are darker brown/olive, more chromatic than wet grey stone
    avg = (r + g + b) / 3
    # brown: r and g close, b lower, not too bright
    brown = (r > 40) & (r < 120) & (g > 30) & (g < 100) & (b < g - 8) & (avg < 90) & ((r - b) > 12)
    ys, xs = np.where(brown)
    return list(zip(xs.tolist(), ys.tolist()))


def resize_512(im: Image.Image, crop: int = 0) -> Image.Image:
    if crop:
        w, h = im.size
        im = im.crop((crop, crop, w - crop, h - crop))
    return im.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def repeat3(im: Image.Image) -> Image.Image:
    w, h = im.size
    out = Image.new("RGB", (w * 3, h * 3))
    for y in range(3):
        for x in range(3):
            out.paste(im, (x * w, y * h))
    return out


def context3(hero: Image.Image, floor: Image.Image) -> Image.Image:
    w, h = hero.size
    out = Image.new("RGB", (w * 3, h * 3))
    for y in range(3):
        for x in range(3):
            out.paste(floor if (x, y) != (1, 1) else hero, (x * w, y * h))
    return out


def font(size: int):
    for p in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
    ):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def main():
    jobs = [
        # name, raw, unique, crop, leaf boxes at 1024 (x0,y0,x1,y1, srcx, srcy) — filled after inspect
        ("wall_top_v1_mossy_coping", "wall_top_v1_mossy_coping.jpg", False, 0, []),
        ("wall_top_v2_broken_brick", "wall_top_v2_broken_brick.jpg", False, 0, []),
        ("floor_wet_v1_puddles", "floor_wet_v1_puddles.jpg", False, 0, "leaves"),
        ("floor_wet_v2_flooded", "floor_wet_v2_flooded.jpg", False, 0, "leaves"),
        ("floor_grate_v1_square_iron", "floor_grate_v1_square_iron.jpg", True, 0, []),
        ("floor_grate_v2_manhole", "floor_grate_v2_manhole.jpg", True, 6, []),
    ]

    # Inspect leaves at 1024 first, print clusters
    for name, raw, unique, crop, leaves in jobs:
        if leaves != "leaves":
            continue
        im = Image.open(RAW / raw)
        pts = find_leafish(im)
        print(f"{name}: {len(pts)} leafish pixels")
        if pts:
            xs, ys = zip(*pts)
            print(f"  bbox {min(xs)},{min(ys)}-{max(xs)},{max(ys)} n={len(pts)}")
            # cluster roughly by 40px bins
            from collections import defaultdict
            bins = defaultdict(list)
            for x, y in pts:
                bins[(x // 40, y // 40)].append((x, y))
            for k, v in sorted(bins.items(), key=lambda kv: -len(kv[1]))[:12]:
                xs, ys = zip(*v)
                print(f"  cluster {k} n={len(v)} bbox {min(xs)},{min(ys)}-{max(xs)},{max(ys)}")

    # Hand-chosen leaf patches at 1024, then scaled after resize? We'll patch at 1024 then resize.
    # Filled from the printout in a second pass if needed; include obvious top-joint leaves.
    leaf_boxes = {
        # will patch after we print; placeholder empty then a second run sets them
    }

    floor = Image.open(REF_FLOOR).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    processed = {}
    for name, raw, unique, crop, leaves in jobs:
        src = Image.open(RAW / raw).convert("RGB")
        if leaves == "leaves":
            # generic: cover small brown leaf-like blobs by inpainting from a 16px offset
            pts = find_leafish(src)
            if pts:
                # dilate and fill each cluster
                from collections import defaultdict
                bins = defaultdict(list)
                for x, y in pts:
                    bins[(x // 32, y // 32)].append((x, y))
                boxes = []
                for v in bins.values():
                    if len(v) < 8:
                        continue
                    xs, ys = zip(*v)
                    pad = 10
                    x0, y0 = max(0, min(xs) - pad), max(0, min(ys) - pad)
                    x1, y1 = min(src.size[0], max(xs) + pad), min(src.size[1], max(ys) + pad)
                    # source mortar: shift down if near top, else left
                    w, h = x1 - x0, y1 - y0
                    if y0 < 80:
                        sx, sy = x0, min(src.size[1] - h, y1 + 8)
                    else:
                        sx, sy = max(0, x0 - w - 4) if x0 > w else min(src.size[0] - w, x1 + 4), y0
                    boxes.append((x0, y0, x1, y1, sx, sy))
                print(f"patching {name} boxes={boxes}")
                src = patch_leaves(src, boxes)
        tile = resize_512(src, crop=crop)
        tile = make_seamless(tile, band=BAND if not unique else 16, unique=unique)
        dest = OUT / f"{name}_512.png"
        tile.save(dest, "PNG")
        processed[name] = tile
        r = repeat3(tile)
        r.save(TILES / f"{name}_3x3.png", "PNG")
        if unique:
            context3(tile, floor).save(TILES / f"{name}_in_floor_stone_3x3.png", "PNG")
        # 4x detail of the centre (128px crop -> 512)
        cx, cy = SIZE // 2 - 64, SIZE // 2 - 64
        det = tile.crop((cx, cy, cx + 128, cy + 128)).resize((512, 512), Image.Resampling.NEAREST)
        det.save(DETAIL / f"{name}_detail4x.png", "PNG")
        print(f"wrote {dest} {tile.size}")

    # Contact sheet
    labels = [
        ("P0 wall tops 512 (seamless)", "wall_top_v1_mossy_coping", "wall_top_v2_broken_brick",
         "v1 mossy coping", "v2 broken brick"),
        ("P2 wet floor 512 (seamless, lit flat)", "floor_wet_v1_puddles", "floor_wet_v2_flooded",
         "v1 puddles", "v2 flooded"),
        ("P2 drain grate 512 (hero tile; shown in floor_stone)", "floor_grate_v1_square_iron", "floor_grate_v2_manhole",
         "v1 square iron", "v2 manhole"),
    ]
    pad = 24
    label_h = 56
    cell = 512
    # each row: two (tile + 3x3 scaled to 512)
    # 4 columns: v1 tile, v1 3x3, v2 tile, v2 3x3
    cols = 4
    rows = 3
    W = pad + cols * (cell + pad)
    H = pad + rows * (label_h + cell + pad) + 90
    sheet = Image.new("RGB", (W, H), (12, 16, 22))
    draw = ImageDraw.Draw(sheet)
    title_f = font(28)
    lab_f = font(20)
    small_f = font(16)
    draw.text((pad, 16), "Lethemoor env round 1  —  painted 512 tiles  —  21 Nov 2026", font=title_f, fill=(217, 205, 180))
    y = 70
    for title, a, b, la, lb in labels:
        draw.text((pad, y), title, font=lab_f, fill=(242, 194, 90))
        y += label_h
        for i, (key, lab) in enumerate(((a, la), (b, lb))):
            tile = processed[key]
            if key.startswith("floor_grate"):
                grid = Image.open(TILES / f"{key}_in_floor_stone_3x3.png").resize((cell, cell), Image.Resampling.LANCZOS)
            else:
                grid = Image.open(TILES / f"{key}_3x3.png").resize((cell, cell), Image.Resampling.LANCZOS)
            x = pad + i * 2 * (cell + pad)
            sheet.paste(tile, (x, y))
            sheet.paste(grid, (x + cell + pad, y))
            draw.text((x, y + cell - 2), "", font=small_f, fill=(180, 180, 180))
            # captions under? put over a bar at top of each cell
            draw.rectangle((x, y, x + cell, y + 26), fill=(8, 10, 14))
            draw.text((x + 8, y + 3), lab, font=small_f, fill=(217, 205, 180))
            draw.rectangle((x + cell + pad, y, x + cell + pad + cell, y + 26), fill=(8, 10, 14))
            cap = "3x3 in floor_stone" if key.startswith("floor_grate") else "3x3 repeat"
            draw.text((x + cell + pad + 8, y + 3), cap, font=small_f, fill=(217, 205, 180))
        y += cell + pad

    path = OUT / "contact_sheet_round1.png"
    sheet.save(path, "PNG")
    print("contact", path, sheet.size)


if __name__ == "__main__":
    main()
