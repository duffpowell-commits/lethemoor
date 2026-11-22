# Player-scale harbor alley slice

A compact, cohesive scene intended to evaluate the modular 3D art conversion at player scale.

## Contents
- 5.2 x 9 m alley footprint with wet dark stone slab floor and gutter strips.
- 2.6 m walls with simple masonry band details and collision blockers.
- A dark framed doorway at the far end.
- Reusable crate, barrel, and bollard props.
- Warm lantern point light, restrained ambient fill, directional lighting.
- One preview camera and environment.

## Open
`scenes/prototypes/player_scale_harbor_alley_slice.tscn`

## Scope and limitations
This remains an isolated art prototype. It does not alter the main scene, grid gameplay, renderer, fog systems, or player simulation. The masonry is currently procedural box geometry and should be evaluated for silhouette, camera composition, collision clearances, and visual scale before replacing it with production assets. The lighting preview does not yet replicate gameplay fog or lantern visibility rules.

## Runtime
Add this scene to the smoke test workflow for import/parse and short headless launch validation.
