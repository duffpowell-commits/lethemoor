# Faceless Thrall Silhouette Study

A self-contained visual-only enemy silhouette prototype. It does not connect to game turns, navigation, combat, camera, or enemy AI.

## Open
Open `scenes/prototypes/faceless_thrall_study.tscn` in Godot 4.5. The scene builds the model, preview lighting, environment and camera from GDScript.

## Design intent
- A narrow, hunched, uneven human silhouette in a long dark harbor coat.
- Hood and recessed face void; no eyes, glow, or readable facial features.
- Slight asymmetry in sleeves, coat panels, and stance.
- Grounded proportions and a thumbnail-readable outline, with restrained material contrast.
- Built from low-cost capsule and box primitives for fast iteration and mobile-friendly testing.

## Limits and next steps
This is a shape-language study, not final production art. Geometry is primitive, static and unrigged. Godot runtime, import, renderer and mobile performance have not been validated from this commit environment. Review the silhouette in Godot, then replace or refine individual components with authored meshes, texture details and animation before integrating any enemy into gameplay.
