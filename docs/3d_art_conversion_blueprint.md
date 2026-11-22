# Lethemoor 3D Art Conversion Blueprint
Audit date: 2026-11-22
Repository: duffpowell-commits/lethemoor
Branch: art/3d-art-conversion-blueprint

## Goal
Modernize Lethemoor's art into a coherent modeled 3D first-person gothic-horror presentation while preserving the grid simulation, GL Compatibility renderer, mobile/web support and portrait-phone focus.

## Current snapshot
Godot 4.5, GL Compatibility; main first-person scene: scenes/fp_room.tscn; renderer script: scripts/fp_view.gd. Existing systems include grid movement, fog, lantern lighting and enemy billboard art. Keep simulation and visibility rules untouched.

## Principles
- Art-only changes until the playtest gate is cleared.
- Gameplay lantern light remains authoritative; no baked illumination in textures.
- Faceless enemies, readable silhouettes, painterly gothic harbor look.
- Mobile/web performance and portrait readability are primary.
- Limit initial work to one corridor prototype.

## Existing art conversion map
### Player and held objects
Refs: hand_lantern.png, hand_lantern_bright.png, hand_lantern_hooded.png, hand_hook.png, bearer/canva bearer variants.
Plan: model lantern with handle, shutter, body, glass and wick; state changes affect model and gameplay light, not prelit textures. Model hook and hand presentation; retain 2D art as fallback.

### Thralls
Refs: thrall_dock.png, thrall_dockwoman.png, thrall_netmender.png, thrall_clawed.png, thrall_hooded.png, thrall_wired.png, thrall_nightmare.png, thrall_lunge.png and thrall_lunge_nightmare.png.
Plan: one base rig, modular wardrobe/silhouette variants, concealed heads, basic idle/shamble/turn/hit/lunge/death animation set.

### Stalker
Refs: bride.png, stalker_bride.png.
Plan: unique silhouette and rig; layered veil/dress, subtle cloth motion; test alpha sorting on mobile early. Preserve the existing freeze-in-light gameplay rule.

### Environment
Refs: wall_stone/granite/paper/damask, wall_top, wall_face_0/1, floor_stone/wet, floor_0-3, sky_night.
Build reusable straight walls, inner/outer corners, junctions, coping, doorways, broken walls, pillars, drains and puddle decals. Use shared atlases/trim sheets and don't bake lantern highlights.

### Props
Refs: prop_bell, prop_boathook, prop_flask, prop_lamppost, letter_nailed, exit, lamp.
Model bell, lamp, flask, exit and hook; keep gameplay text/UI separate.

### 2D assets to retain
Blood/oil/fire decals and effects, HUD, parchment map, letter pages, title art and icons can remain 2D. They are not automatically improved by converting to meshes.

## Style
Stylized realism; gothic harbor town, wet stone, dark timber, worn iron, distressed cloth, old paper; cold ambient shadows, warm amber lantern light; neutral materials with no baked dramatic lighting; faceless enemies.

## Asset standards (provisional)
- 1 grid tile = 1 world unit, confirm against map logic.
- Existing wall height constant is approximately 2.4 units; verify before standardizing.
- Export assets as glTF/.glb.
- Floor props pivot at base; modular walls at tile-edge/corner; held items at grip.
- Shared materials, restrained polycounts, minimal transparent surfaces, simple collision.
- Naming convention examples: env_wall_straight_01, prop_bell_01, enemy_thrall_dock_01.

## First prototype: corridor only
1. Modular wall mesh family with three variations.
2. Corner, doorway and coping.
3. Dry and wet floor variants.
4. One fixture/lamp (no new gameplay light logic).
5. One static thrall, rig only after visual/performance approval.
6. Bell prop.
7. Render inside existing first-person scene with current lantern/fog.

Acceptance: simulation untouched; GL Compatibility; no visibility leaks; readable on portrait phone; validate on Android and web/iPhone; reasonable import/runtime size.

## Order
1. Corridor and environment kit.
2. Base thrall rig and variants.
3. Stalker.
4. Lantern and hook.
5. Props.
6. District modular expansion.
7. Optional effects upgrades.

## Risks
Mobile performance: shared materials and low/moderate polycounts. Veil transparency: alpha-cutout/layered opaque tests. Art drift: use existing art as anchor. Scope creep: corridor only. Playtest interruption: do not merge until gate. Main remains untouched.

## Next step
After playtest gate, create a small test scene and import pipeline for the corridor. Do not change STATUS.md, gameplay scripts or main scene in this documentation milestone.