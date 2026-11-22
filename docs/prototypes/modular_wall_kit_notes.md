# Modular Wall Kit Prototype Notes

Branch: `art/3d-art-conversion-blueprint`

## Current test pieces

The script `scripts/prototypes/modular_wall_kit_test.gd` builds a visual-only kit from shared material instances and box meshes:

- Straight wall section: configurable length, fixed provisional height/thickness.
- Surface-relief masonry courses: shallow face blocks on both sides.
- Coping strip.
- Doorway module with side piers, lintel, and cap pieces.
- Corner sample.
- Camera, environment and floor for preview.

The scene is deliberately isolated from the active game scene and renderer. These pieces are a geometry study, not production modular assets.

## Integration rules

- Maintain 1 grid tile ~= 1 world unit as a provisional scale.
- Keep wall height around 2.4 units pending comparison against the existing renderer and character proportions.
- Use modular dimensions and shared materials. Avoid creating unique material instances per stone.
- Keep surface relief shallow and collision-free in this art-only preview.
- Use the existing gameplay lantern and fog systems as the authoritative lighting and visibility. Do not bake lantern effects into wall materials.
- Mobile/web renderer and memory budgets remain primary constraints.

## Validation checklist

Before treating this kit as usable:

1. Open the scene in Godot 4.5 and confirm there are no script parse errors.
2. Inspect the doorway width, corner junction and block relief from first-person and oblique views.
3. Check face blocks for clipping, z-fighting, and uneven course spacing.
4. Test under the game's lantern lighting, not just the prototype preview environment.
5. Compare wall scale with player/enemy dimensions and the existing tile simulation.
6. Capture GL Compatibility screenshots on desktop and mobile.
7. Revisit material variation and geometry density only after the silhouette and proportions work.

## Known limitation

The corner and doorway assembly are early layout tests. The corner is an approximate junction, and the demo arrangement should not be considered a validated architectural prefab. It has not been run in the Godot runtime during this work.
