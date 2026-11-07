"""Hand fixes for bearer64 after tools/import_sprite.py (the shrink can't keep a skull's face).
    python3 tools/fixes/bearer64.py
"""
from PIL import Image
P = "assets/art/bearer64.png"
im = Image.open(P).convert("RGBA")
def c(h): return tuple(int(h[i:i+2], 16) for i in (1, 3, 5)) + (255,)
INK0, INK1, BONE0, BONE1, BONE2 = c("#05070c"), c("#0b111b"), c("#6f6656"), c("#a99c84"), c("#d9cdb4")
OLIVE = {c("#2e3b26")[:3], c("#3f4a2c")[:3]}
# jaw and cheekbones: the olive smear under the dome is bone in the design
for y in range(9, 14):
    for x in range(32, 38):
        if im.getpixel((x, y))[:3] in OLIVE:
            im.putpixel((x, y), BONE0)
for x, y in [(33, 10), (34, 10), (36, 10)]:      # deep sockets, head turned toward the lantern
    im.putpixel((x, y), INK0)
for x, y in [(33, 11), (36, 11)]:
    im.putpixel((x, y), INK1)
im.putpixel((35, 12), INK1)                      # nasal cavity
for x in (34, 35, 36):                           # teeth line
    im.putpixel((x, 13), BONE1)
im.putpixel((35, 14), INK0)
im.putpixel((34, 6), BONE2)                      # dome highlight
im.save(P)
print("fixed", P)
