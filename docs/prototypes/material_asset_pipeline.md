# Prototype Material and Asset Pipeline

This is a minimal, optional shader experiment for the isolated corridor only.

## Procedural stone material
Shader: `assets/materials/prototype_stone_noise.gdshader`

- Subtle UV-space grain breaks uniform flat colors.
- Roughness is adjustable.
- No baked light, glow, or directional highlights.
- Lightweight noise functions; still profile on target mobile hardware.
- Treat as a prototype. Replace with authored texture maps/trim sheets if noise looks tiled or costs too much.

## Suggested next asset pipeline
1. Block out modular wall/floor geometry in Godot or Blender.
2. Use a one-meter tile unit and verify scale against existing movement/map assumptions.
3. Create UVs and a shared material atlas; keep texture density consistent.
4. Export from Blender to glTF 2.0 binary (`.glb`), with mesh and material names preserved.
5. Import to Godot; verify GL Compatibility rendering.
6. Add simple collision as separate low-complexity shapes.
7. Capture a portrait screenshot, measure frame rate and memory on device.
8. Only then add rigging, animation or higher-resolution textures.

## Naming convention
- `env_wall_straight_01`
- `env_wall_corner_inner_01`
- `env_floor_stone_wet_01`
- `prop_bell_01`
- `enemy_thrall_dock_01`

## Budget guidance (starting targets, not engine limits)
- Static corridor modular mesh: prioritize few materials and reuse meshes.
- Thrall placeholder: under 10k triangles for a first mobile model experiment; target lower if silhouette permits.
- Texture maps: start 512–1024 px per shared atlas, avoid individual large textures for every piece.
- Transparent materials: avoid unless necessary; veil experiments should be isolated.
- Avoid additional realtime lights until the existing lighting/fog compatibility has been evaluated.
