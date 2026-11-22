# Corridor Prototype: Validation & Art Brief
Branch: `art/3d-art-conversion-blueprint`

## Open the prototype
Run the scene directly from the Godot editor or command line:
```sh
godot --path . res://scenes/prototypes/three_d_corridor.tscn
```
The scene is intentionally isolated from the main scene and simulation.

## Validation checklist
- [ ] Godot 4.5 imports and parses the script without errors.
- [ ] Scene opens and renders in GL Compatibility.
- [ ] Walls, floor, doorway and lamp are visible.
- [ ] Camera faces down the corridor and the thrall silhouette is visible.
- [ ] Light and shadow are legible without baked texture highlights.
- [ ] Check render on Android at portrait aspect ratio.
- [ ] Check web build / iPhone Safari.
- [ ] Profile FPS and memory before adding animation or detailed meshes.
- [ ] Check visual contrast at phone-width, not only desktop.
- [ ] Record screenshots before and after any material/geometry change.

## Thrall modeling brief
**Silhouette:** tall, narrow, slightly forward-leaning dock-worker silhouette; uneven shoulders and hanging coat hem; concealed face beneath a deep hood. No eyes, mouth or exposed facial features.

**Material:** cold, waterlogged charcoal wool; slightly differentiated leather straps and salt-stained cloth; no baked highlights. Keep contrast against background stones.

**Geometry:** use a single simple rig, low/moderate polygon budget; shape hood and shoulders to create a distinct silhouette. Separate hands, forearms, lower coat and head/hood only where rigging needs them. No facial geometry.

**Pose:** arms loosely hanging but asymmetric, head slightly lowered. Avoid the generic zombie arms-forward pose.

**Animation target:** idle sway and weight shift first. Walk/shamble, hit reaction and lunge are deferred until the static model is approved.

## Environment modeling brief
- Modular pieces snap to a one-unit tile grid.
- Wall modules should include straight, inner/outer corners, doorway and coping.
- Masonry shapes are irregular but restrained; large silhouette details only.
- Use material atlases and repeated shared materials where possible.
- Wetness comes from roughness variation and gameplay lighting, not bright baked reflections.
- Avoid alpha-blended materials unless a specific visual need justifies performance/sorting costs.

## Do not merge into the live game yet
This remains a visual test. Keep simulation, lantern rules, fog, movement and playtest balance untouched until the corridor art passes the kill-test gate.
