# Final env art (Duff, 21 Nov 2026)

Painted, lit flat (no baked lantern light). Names match the repo where it already has a path.

| File | Pick | From |
|---|---|---|
| `wall_top.png` | v1 mossy coping | `env/round1/wall_top_v1_mossy_coping_512.png` (512×512) |
| `floor_wet.png` | v2 flooded | `env/round1/floor_wet_v2_flooded_512.png` (512×512, lit flat) |
| `drain_grate.png` | v1 square iron | `env/round1/floor_grate_v1_square_iron_512.png` (512×512) |
| `prop_belltower.png` | v1 parish, keep the cross | `env/round2/prop_belltower_v1_parish.png` (442×1024, transparent) |

`docs/art_needs.md` names wall tops (`wall_top.png`) and a wet-puddle floor (`floor_wet.png` already exists in the repo as an unused 256 px baked leftover). It does not name the drain grate or the bell-tower landmark; `drain_grate.png` sits beside `floor_wet`, and `prop_belltower.png` matches `prop_bell` / `prop_lamppost`.

Wiring note for Claude (the bell tower): there is no skyline layer; walls are 2.4-high boxes against `sky_night`. Add a Sprite3D billboard at the bell tile, base at the bottom, about 5–7 world units tall so the belfry peeks over the wall tops. Leave the close `prop_bell` as the ringable bell. Nothing here is wired into the game yet (art only).
