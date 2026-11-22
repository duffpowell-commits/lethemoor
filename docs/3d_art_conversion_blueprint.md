# Lethemoor 3D Art Conversion Blueprint
Audit date: 2026-11-22
Repository: duffpowell-commits/lethemoor
Branch: `art/3d-art-conversion-blueprint` (created successfully; document pending commit)

## Goal
Modernize Lethemoor's art toward a coherent fully modeled 3D first-person gothic horror presentation while preserving its grid-based simulation, Compatibility renderer, portrait-phone focus, and web/iPhone tester compatibility.

## Audit snapshot
The repository contains a substantial existing art reference set under `assets/art/`, an active first-person renderer in `scripts/fp_view.gd`, and a main scene `scenes/fp_room.tscn`. `project.godot` uses Godot 4.5 and the GL Compatibility renderer. The first-person view has grid movement, lantern lighting, fog-driven visibility, enemy billboards, hand art, and other existing systems.

## Principles
- Preserve game simulation and turn rules; art changes should be visual-layer changes.
- Keep GL Compatibility and mobile/web constraints.
- Lantern light is authoritative gameplay truth; do not bake lighting into the geometry/materials.
- Enemy faces remain concealed.
- Keep a controlled visual style: painterly gothic horror, wet surfaces, restrained geometry detail, readable silhouettes, cold ambient shadows and warm lantern light.
- Asset dimensions, pivots, collisions and performance budgets should be standardized.
- Validate with real Godot renders and phone-sized readability, not only attractive asset previews.
- Avoid creating full-game systems or scope expansion while the One Night playtest is in progress. Prototype a bounded corridor only.

## Existing asset inventory and conversion mapping

### A. Player hands and held objects
Reference files:
- `hand_lantern.png`
- `hand_lantern_bright.png`
- `hand_lantern_hooded.png`
- `hand_hook.png`
- `bearer48/64.png`, `bearer48/64_n.png`, `bearer48/64_glow.png`
- `canva_bearer48/64/80/96.png` and associated normal/glow maps

Plan:
1. Make one real 3D lantern with shutter, handle, body, wick and glass.
2. Set up a hand/arm rig or hand-held presentation mesh for first-person positioning.
3. Lantern-state changes should alter shutter/wick, light range/energy, flame animation and sounds, not swap pre-lit artwork.
4. Boathook becomes a reusable held weapon model with separate handle and hook geometry.
5. Preserve current painted hand assets temporarily as a fallback and comparison reference.

Priority: high, but prototype only after playtest constraints permit.

### B. Enemy family
Reference files:
- `thrall_dock.png`
- `thrall_dockwoman.png`
- `thrall_netmender.png`
- `thrall_clawed.png`
- `thrall_hooded.png`
- `thrall_wired.png`
- `thrall_nightmare.png`
- `thrall_lunge.png`
- `thrall_lunge_nightmare.png`

Plan:
1. Establish a single base rig and humanoid proportion standard.
2. Create modular wardrobe and silhouette variation: wet dock coat, shawl, net/rope, clawed sleeves, wired bindings, torn nightmare variant.
3. All heads use non-face designs (hood, sack, veil, shadow void).
4. Build a small animation set: idle sway, walk/shamble, turn, hit, lunge, burn/death.
5. Generate variants by material/mesh additions, not separate incompatible rigs.

Priority: high.

### C. Stalker / bride
Reference files:
- `bride.png`
- `stalker_bride.png`

Plan:
1. Unique silhouette and rig, distinct from the thrall base.
2. Long veil and dress layers, subtle cloth motion within mobile limits.
3. Gameplay rule (freeze while lit and in view) stays in simulation; model/animation expresses it only.
4. Avoid transparent materials that are expensive or unstable on mobile; test veil layering and alpha sorting early.

Priority: high.

### D. Environment architecture
Reference files:
- `wall_stone.png`
- `wall_granite.png`
- `wall_paper.png`
- `wall_damask.png`
- `wall_top.png`
- `wall_face_0.png`, `wall_face_1.png`
- `floor_stone.png`
- `floor_wet.png`
- `floor_0.png` through `floor_3.png`
- `sky_night.png`

Plan: Build a modular kit with fixed grid footprint and reusable meshes:
- Straight wall segment
- Inner corner and outer corner
- T-junction and cross-junction
- Wall-top/coping piece
- Door opening and doorframe
- Floor tile variants
- Broken-wall module
- Pillar / column
- Grate or drain
- Wet-puddle tile/decal

Materials should share texture atlases or trim sheets where practical. Create normal/roughness textures from material references where useful, but don't bake lantern highlights. Use geometry for large silhouette details, not tiny ornament.

Priority: **highest ROI** for the 3D conversion because the corridor and walls dominate the player's view.

### E. World props
Reference files:
- `prop_bell.png`
- `prop_boathook.png`
- `prop_flask.png`
- `prop_lamppost.png`
- `letter_nailed.png`
- `exit.png`
- `lamp.png`

Plan:
- Bell: modeled bell, mount and clapper; possible simple animation on ringing.
- Lamp post: modular base, post, lantern housing; lights remain game-controlled.
- Flask: low-poly glass or opaque stylized material with clear silhouette.
- Letters: paper geometry or texture card, gameplay text remains UI/texture.
- Exit: build a consistent door/portal prop.
- Hook: mesh version shared between held and world versions where possible.

Priority: medium.

### F. Effects and UI/story art (retain as 2D where appropriate)
Reference files:
- `blood_pool.png`
- `decal_fire.png`
- `decal_oilslick.png`
- `fire_sheet.png`
- `fx_blood_screen.png`
- `map_parchment.png`
- `assets/art/letters/page_1.png`, `page_2.png`, `page_3.png`
- `title_keyart.png`, app icons

Plan:
- Keep HUD, maps, letter pages, title key art and screen effects as 2D.
- Use 2D decals for blood, oil and small surface details; these are not inherently improved by full 3D meshes.
- Fire can remain animated sprites/particles or a small particle system.
- UI art is not part of the 3D asset migration.

Priority: low for full 3D; preserve existing assets.

## Suggested style specification
- Gothic harbor town, wet stone, dark timber, worn iron, distressed cloth, old paper.
- Stylized realism rather than photorealism; expressive shapes, readable materials and silhouette.
- Lantern: warm amber key light. Environment: cool slate/blue ambient darkness.
- Geometry and materials should be neutral and unlit by baked dramatic highlights.
- Enemies are faceless.
- Phone-first: avoid tiny detail that disappears at portrait gameplay scale.
- Target GL Compatibility, web and Android.

## Asset standards (provisional)
- World scale: 1 grid tile = 1 Godot world unit, aligned with current map logic.
- Wall height: start from existing `WALL_H` (~2.4 world units in the first-person renderer); verify camera and current wall mesh before standardizing.
- Export: `.glb`/glTF, preferably one scene per modular asset or asset group.
- Pivots: floor props at base center; modular walls at tile-edge or corner pivots; held items at grip point.
- Meshes: minimize material count, draw calls and transparent layers.
- Materials: mobile-friendly; avoid unnecessary high-cost shader effects.
- Collision: simple collision shapes separate from render geometry.
- Naming: `env_wall_straight_01`, `env_wall_corner_inner_01`, `prop_bell_01`, `enemy_thrall_dock_01`, etc.
- Keep the source blend file outside the shipped runtime asset folder or alongside each asset in a non-exported source directory.

## Proposed first prototype: one corridor
Bounded prototype, no new game systems:
1. Three wall variations using one modular wall mesh/material family.
2. One corner and one doorway.
3. Two floor materials: dry stone and wet stone.
4. Wall top/coping.
5. One modeled lamp fixture (no extra gameplay lighting logic).
6. One thrall model, static at first, then rigged if the look/performance passes.
7. One bell prop.
8. Render from the existing first-person scene with the lantern and current fog/visibility logic.

Acceptance criteria:
- Existing grid movement, turn rules, fog and gameplay remain unchanged.
- Materials and models render under the current GL Compatibility renderer.
- No gameplay visibility information leaks from models/materials.
- Portrait-screen silhouettes and surfaces read clearly.
- Corridor render is captured and reviewed on Android and web/iPhone.
- Asset import and export size remain acceptable.

## Production order
1. **Visual baseline & corridor prototype** (walls, floor, doorway, lantern light compatibility)
2. **Thrall model + rig** (one base model, then variant kit)
3. **Stalker model**
4. **Player lantern and hook**
5. **World prop kit** (bell, lamp, flask, letter, exit)
6. **District modular expansion** (dock, alleys, interiors)
7. **Optional 3D upgrades for effects**, only where they improve readability

## Risks and mitigations
- **Mobile performance:** use low-to-moderate polycounts, shared materials, trim sheets, limited transparent surfaces and profile on device.
- **Transparency sorting:** test veils and glass early; consider layered opaque/alpha-cutout veil designs.
- **Art drift:** enforce style guide and use existing assets as visual anchors.
- **Scope creep:** corridor only; no gameplay feature changes.
- **Playtest interruption:** work is preparatory and should not merge into the gameplay branch until the kill test decision permits.
- **Repository write access:** Branch creation has now succeeded. This documentation-only milestone will be committed to the feature branch; main remains untouched.

## Next implementation step
Place this document at `docs/3d_art_conversion_blueprint.md` on the feature branch. Then, after the playtest gate, create a small Godot test scene and asset import pipeline for the corridor prototype. Avoid changing `STATUS.md`, gameplay scripts or the main scene in this first documentation-only milestone.