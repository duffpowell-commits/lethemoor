# grok_art

**Running plan for all Grok generation (Duff's Google Drive):** [Lethemoor — Grok Generation Plan](https://docs.google.com/document/d/1O5_Zuh04_8OyXE7tYRbBtHHvX15tgi36CqbCpnOs-1A/edit)
Style rules, prompts, the movement test (T1–T6, scoring), the asset shopping list and the log live there. Keep it updated each session (Google Drive connector).

Duff's character and prop designs from Grok, waiting to become game art. Nothing in this
folder ships (`.gdignore`). Duff designs, Claude turns designs into sprites.

## Adding a design (from the phone)
GitHub app → lethemoor → `grok_art` → Add file → Upload, or just send it to Claude in chat
and Claude saves it here.

Name it what it is: `lantern_bearer.jpg`, `thrall.jpg`, `drowned_priest.jpg`.

## What a design needs
- **Solid bright green background** (#00FF00). The importer cuts it out.
- **One character, one pose, full body**, 3/4 front view, standing on nothing.
- **Original file**, not a screenshot, if you can (screenshots work, just softer).
- Lantern or other light sources glowing amber, so the importer can find the flame.

## Grok prompt template (Grok's chat writes/refines prompts, Grok Imagine renders)
```
Single game sprite, 2D pixel art, HD-2D style (Octopath Traveler-like): crisp hand-placed pixels,
no anti-aliasing, no blur, no gradients.
Subject: [describe the character]
View: 3/4 front-facing, full body, idle pose, centered.
Canvas: character fills ~80% of a square frame, designed to downscale cleanly to 64x64.
Palette: max 16 colors — desaturated bone, rust, moss green, ink black; ONE warm accent (lantern amber).
Lighting: single warm light source from the lantern, low and to the right; deep shadows, rim light.
Mood: gothic, Edgar Allan Poe, quiet dread, something slightly wrong with the anatomy.
Background: flat solid #00FF00, no scenery, no floor shadow, no text, no border.
Avoid: chibi, cute, anime gloss, 3D render look, painterly brushwork.
```
Attach an approved design as a style anchor ("match this exact style and palette"). One pose per
image; Grok can't hold a character consistent across a whole animation sheet.

## Turning it into a sprite (Claude runs this)
    python3 tools/import_sprite.py grok_art/<file> <name> --size 64 [--crop x0,y0,x1,y1]
    python3 tools/fixes/<name>.py        # hand fixes the shrink can't do (faces, hands)

Writes `assets/art/<name>.png`, `<name>_n.png` (normal map) and `<name>_glow.png` (flame).

## Log
| file | sprite | notes |
|---|---|---|
| `lantern_bearer.jpg` | `bearer48`, `bearer64` | screenshot source; skull face hand-fixed on 64 |
| `canva_lantern_bearer.png` | `canva_bearer64` | Canva generate-image, Nov 11; connector only returns a 200px preview; mirrored before import so the lantern sits lower-right; face + lantern smear at 64 |
