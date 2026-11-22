# 3D Prototype Asset Contract

This document establishes a repeatable handoff for prototype meshes and future replacement assets. It is deliberately conservative: the gameplay simulation and renderer remain untouched.

## Coordinate and scale
- Godot 4.5, GL Compatibility renderer.
- 1 grid cell = 1 world unit (provisional).
- World up: +Y. Ground plane: X/Z. Forward-facing modular walls: local Z.
- Wall target height: 2.4 units; masonry thickness: 0.22 units.
- Keep asset roots at the logical placement point; use child transforms for visual offsets.

## Naming
Use descriptive snake_case filenames and PascalCase node names:
- `harbor_wall_straight_1m.glb`
- `harbor_wall_corner.glb`
- `harbor_wall_doorway_1m.glb`
- `harbor_bollard.glb`
- `harbor_lantern.glb`
- `harbor_thrall.glb`

## Mesh and material budgets (prototype targets, not measured limits)
| Asset class | Target triangles | Materials | Notes |
|---|---:|---:|---|
| Repeated masonry module | 500–1,500 | 1–2 | Favor baked detail over many relief meshes |
| Small harbor prop | 300–1,200 | 1–3 | Silhouette must read at gameplay distance |
| Enemy prototype | 1,500–4,000 | 1–3 | Strong shape language; face detail intentionally absent |
| Large focal prop | 2,000–6,000 | 2–4 | Reserve complexity for lantern-lit close views |

Targets should be revisited after profiling on representative mobile hardware. Avoid premature claims about frame rate.

## Materials and textures
- Prefer shared materials and trim sheets for repeated masonry/wood/metal.
- Use tiling textures with consistent texel density within an environment set.
- Detail should be readable at a distance; avoid relying on tiny high-frequency roughness noise.
- Wetness is expressed through restrained roughness variation and light-catching accents, not uniformly mirror-like surfaces.
- Keep material feature choices compatible with Godot GL Compatibility; verify shader behavior in-engine.

## Pivot, collision, and placement
- Root pivot at module center or documented connection point.
- Repeated wall modules align to whole/half grid increments.
- Keep visual meshes separate from collision meshes where practical.
- Collision should be simple and gameplay-driven, not a copy of render geometry.
- Doors, corners, and junctions must be tested for gaps and overlaps.

## Readability test
Test each asset at:
1. Close inspection (approximately 1–2 units).
2. Normal player view (approximately 3–6 units).
3. Lantern falloff / fog boundary.
4. Mobile-sized screen, with UI-safe contrast.

A silhouette or value pattern that disappears at normal view should be simplified or strengthened.

## Conversion checklist
- [ ] Scale and pivot documented
- [ ] Filename and root node conform
- [ ] Shared material use reviewed
- [ ] Collision reviewed separately
- [ ] GL Compatibility shader/material check
- [ ] Normal gameplay distance readability
- [ ] Fog and lantern lighting readability
- [ ] Mobile performance test recorded
- [ ] Source file retained alongside exported asset where possible

## Scope guard
This contract is for isolated art prototypes and asset conversion. Do not change gameplay movement, grid logic, lantern simulation, fog logic, combat, UI, or the main scene as part of these experiments.
