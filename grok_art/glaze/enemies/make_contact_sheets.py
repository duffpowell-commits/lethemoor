import json, os, sys, numpy as np, textwrap
from PIL import Image, ImageDraw, ImageFont
R = sys.argv[1]
LABEL = sys.argv[2] if len(sys.argv) > 2 else 'Round 1'
C = json.load(open(f'{R}/candidates.json'))
fb = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 14)
fi = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 14)
def key(a):
    a = a.astype(int); return (a[..., 1] > 140) & (a[..., 1] - np.maximum(a[..., 0], a[..., 2]) > 70)
for grp, g in C.items():
    W, colw = 3 * 520 + 40, 520
    S = Image.new('RGB', (W, 740), (18, 20, 28)); d = ImageDraw.Draw(S)
    d.text((20, 12), f"Lethemoor - {LABEL} - {g['title']}   (source 1024px, right: 64 px nearest-neighbour, shown x3-4)", fill=(240, 220, 160), font=fb)
    for i, it in enumerate(g['items']):
        x = 20 + i * colw
        im = Image.open(f"{R}/{it['file']}").convert('RGB')
        S.paste(im.resize((300, 300), Image.LANCZOS), (x, 60))
        a = np.asarray(im); m = ~key(a); ys, xs = np.nonzero(m)
        crop = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        sm = crop.resize((max(1, round(crop.size[0] * 64 / crop.size[1])), 64), Image.NEAREST)
        sm.save(f"{R}/{it['id']}_64px.png")
        k = max(1, min(4, 205 // sm.size[0])); big = sm.resize((sm.size[0] * k, 64 * k), Image.NEAREST)
        bg = Image.new('RGB', (big.size[0], big.size[1]), (0, 255, 0)); bg.paste(big, ((bg.size[0] - big.size[0]) // 2, 0))
        S.paste(bg, (x + 310, 82))
        d.text((x, 370), it['id'], fill=(255, 200, 90), font=fb)
        y = 402
        for line in textwrap.wrap(it['concept'], 62):
            d.text((x, y), line, fill=(230, 230, 230), font=f); y += 19
        y += 8
        for line in textwrap.wrap('"' + it['flavor'] + '"', 60):
            d.text((x, y), line, fill=(200, 180, 140), font=fi); y += 19
    S.save(f"{R}/contact_sheet_{grp}.png")
print('ok')
