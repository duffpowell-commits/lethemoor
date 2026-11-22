# Modular Harbor Masonry Builder

A standalone modular masonry study with geometry helper functions intended to be reused by future art-only scene assembly.

## Builder functions
- `build_wall(parent, origin, length, stone, cap, dark)`: creates a straight wall module with shallow staggered relief and coping.
- `build_corner(parent, origin, stone, cap, dark)`: composes two short wall runs into a rough corner.
- `build_door(parent, origin, opening, total, stone, cap)`: doorway piers, lintel and caps.

All builders attach geometry beneath the supplied parent and accept materials. They do not add cameras, lights, environments or gameplay systems. The attached script's `_ready` function creates a sample layout and preview rig for the standalone scene.

## Validation status
Godot 4.5 runtime validation is still outstanding. Corner placement is approximate; check orientation, seams and relief alignment in-engine before reuse.
