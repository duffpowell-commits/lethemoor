# Lethemoor: Grok best-work showcase (Nov 7 2026)

A capability reference for Claude. All images came from the GenerateImage tool, with the approved
skull-faced lantern-bearer as the reference image (`../anchor_lantern_bearer_green.png`, the
1024 px original composited onto #00FF00). Each prompt starts with the section 1 game paragraph
and "match this exact character, style and palette". I regenerated each item and kept only the
best version. Weaker versions are in `rejected/`.

| Item | Kept file | 64/48 px conversion | Tries |
|---|---|---|---|
| (a) 4-frame side walk | `walk_v2.png` | `walk_v2_64px_strip.png`, `walk_v2_64px.gif` | 3 (v1 and v3 in rejected/) |
| (b) 4-direction turnaround | `turnaround_4dir.png` | `turnaround_4dir_64px.png` | 1 here + 3 in the T1 test |
| (c) Stalker idle | `stalker_idle.png` | `stalker_idle_64px.png` | 2 here + 3 in the T6 test |
| (d) Wet cobbles, 4 variants | `cobbles_wet_4variants.png` | `cobble_1..4_48px.png`, `cobbles_48px_tiled_preview.png` | 2 |
| (d) Oil flask prop | `oil_flask.png` | `oil_flask_48px.png` | 1 |

Contact sheet: `showcase_contact_sheet.png`. To rebuild the conversions, run `python3 ../tools/build_showcase.py`.

## Prompts that worked best (shortened; the full text is in the bot's run)
- **Walk (v2):** "Classic 16-bit RPG walk cycle sprite sheet, 4 frames left to right ... Frame 1: right foot
  forward, left foot back (wide stride). Frame 2: feet together. Frame 3: left foot forward, right foot back.
  Frame 4: feet together ... feet on one shared ground line. Evenly spaced, generous green gaps ..."
  This is far better than the PDF's T2 wording ("contact, passing, contact (other leg), passing"),
  which returned 4 copies of one pose every time.
- **Turnaround:** name the facings by screen edge ("face pointing to the LEFT edge of the image")
  and pin the lantern hand ("always held in his LEFT hand, the same physical hand in every view").
  This fixed the swapped and duplicated side views seen in T1.
- **Stalker:** spell out "face COMPLETELY covered by a curtain of wet hair ... no eyes, no skull" and
  "DIFFERENT creature, carries NOTHING". Without that, the base template's "ONE warm accent
  (lantern amber)" plus the anchor made every Stalker a skull-faced lantern-bearer clone.
- **Cobbles:** "small ROUNDED, irregular, dome-shaped setts ... NOT rectangular bricks". The first try
  produced bricks, with a whole lantern reflected in the puddle.

## Honest limitations
1. **There is no true walk cycle.** The best sheet alternates "stride" and "feet together", but frames 1 and 3 show
   the same leg forward. Grok never drew the opposite-leg contact pose, even when I described it explicitly. At
   64 px it reads as a shuffle or bob, not a stride. Use it as a 2-pose bob, or hand-edit a mirrored
   leg.
2. **The background is not pure #00FF00.** Output is JPEG, and the green averages about (4, 235, 12) with noise of ±5–20.
   It is flat and keys out easily, but it never matches the exact hex. Chroma-key by hue, not by exact colour.
3. **The palette is far over 16 colours.** Downscaled to 64 px, 90% of foreground pixels still use about 700–1,900 distinct
   colours. The images look like pixel art but carry painterly texture, so they need palette quantisation
   (for example to 16 colours) in the importer.
4. **The pixel grid does not line up with 64 px.** The "pixels" in the source are about 4–6 px blocks that sit off any grid, so the
   nearest-neighbour shrink produces some noisy, broken edges. The skull face needs hand fixes, as it did for bearer64.
5. **Cells are not square.** The tool only offers 16:9 at most, so a 4-cell row gives 256×576 cells.
   Figures sometimes drift up to about 12% of a cell's width off centre and occasionally touch cell edges.
6. **Each frame is redrawn.** Two frames that should be "the same but 1 px lower" come back as full repaints,
   so texture boils between frames. Subtle idles need code-driven offsets instead.
7. **The tiles are not seamless.** Each cobble tile is drawn as a framed square with rounded border stones, so a
   tiled floor shows a grid (see `cobbles_48px_tiled_preview.png`). Crop the inner area or ask
   for an "edge-to-edge" texture.
8. **The Stalker's face still peeks through the hair** at full size. At 64 px it reads as fully hidden.
