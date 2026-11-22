# Wet Stone Ground Test

This standalone study uses a spatial shader to create stone tile/mortar separation, subtle per-cell tonal variation and localized wetness variation.

## Intended use
- Art-only preview of the harbor-town ground material.
- Not attached to gameplay or the active renderer.
- No baked illumination; lantern light remains controlled by the game's lighting systems.
- Shader parameters are exposed for roughness, wetness, color and scale.

## Validation
Open the scene in Godot 4.5 and inspect shader compilation, UV tiling, visual scale, puddle breakup and mobile performance under GL Compatibility. This file has not been engine-validated. If shader compatibility issues occur, reduce procedural layers and test on target devices.
