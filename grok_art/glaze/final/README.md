# final/ : game-ready sprites (Nov 8 2026)

| Sprite | Source | Size | Notes |
|---|---|---|---|
| `a3_docker_64px_left/right.png` | enemies/round2/a3_docker_v3.png | 46x64 | drawn facing left; right = mirror |
| `b2_keeper_stage1_64px_left/right.png` | enemies/round1/B2_lighthouse_keeper_stage1.png | 45x64 | drawn near-front 3/4; treated as right, left = mirror (lamp swaps hands) |
| `b2_keeper_stage2_64px_left/right.png` | enemies/round2/b2_stages/b2_stage2_v1.png | 46x64 | same facing rule as stage 1 |
| `b2_keeper_stage3_96px_left/right.png` | enemies/round2/b2_stages/b2_stage3_v1.png | 86x96 | BOSS SCALE 96 px tall (1.5x a character, 2 tiles at 48 px); floor shadow keyed out (`--shadow`) |

All are transparent PNGs with at most 16 colours. They were made with `cleanup_64.py`: the green is keyed out, then the colours are reduced to 16 with four accent colours locked in (bone white, blood red, near-black, lamp glow).
`bob_gifs/` holds previews only: 2 frames, 400 ms each, the sprite moves down 1 px on frame 2, both facings side by side, shown at x4. In the game, do the bob in code (plan B); do not ship the GIFs.
To rebuild: `python3 cleanup_64.py <src.png> work/<name> [height] [--shadow]`, then mirror the result with PIL `ImageOps.mirror`.
