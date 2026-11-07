# grok_art

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

## Turning it into a sprite (Claude runs this)
    python3 tools/import_sprite.py grok_art/<file> <name> --size 64 [--crop x0,y0,x1,y1]
    python3 tools/fixes/<name>.py        # hand fixes the shrink can't do (faces, hands)

Writes `assets/art/<name>.png`, `<name>_n.png` (normal map) and `<name>_glow.png` (flame).

## Log
| file | sprite | notes |
|---|---|---|
| `lantern_bearer.jpg` | `bearer48`, `bearer64` | screenshot source; skull face hand-fixed on 64 |
