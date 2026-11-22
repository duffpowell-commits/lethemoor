# Reusable Harbor Props: First Extraction

This extraction begins separating reusable geometry from presentation rigs.

## Scope
- Shared script factory for crate, barrel, bollard geometry.
- Prop-only scene shells. These have no camera, lights, floor, environment, or collision.
- Local materials are deliberately simple and replaceable.

## Integration caveat
The scene shells currently serve as asset containers; geometry factory methods should be invoked by a small per-asset wrapper script or a composition script that adds the returned Node3D. This keeps the asset geometry camera-free and avoids duplicated rigs.

## Suggested next step
Convert each factory into an individual self-contained scene with exported material overrides and collision options, then compose the alley and test the assets in the game renderer.

No runtime validation: Godot is not available in the connector environment.
