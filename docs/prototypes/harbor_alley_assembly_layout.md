# Harbor Alley Assembly Layout v1

## Goal
A repeatable single-camera composition that can be assembled from the existing procedural modules without nesting their preview rigs.

## Layout coordinates
- Ground patch: 8 m long by 4 m wide, centered at the origin, Y = 0.
- Camera: player-eye-height approximation (1.65 m), looking along negative Z.
- Alley clear width: 2.4 m.
- Walls: 2.4 m high; keep modules on the same coordinate space.
- Opening: 1.0 m wide, placed in the left wall toward the far end.
- Lantern: one focal lantern on the right wall, near the far third of the corridor.
- Enemy: place the faceless thrall at the far end, centered but slightly offset from the lantern beam.
- Props: one bollard near the foreground edge, one crate/barrel cluster near the far wall; no clutter in the travel lane.

## Assembly rules
1. Use one root Node3D for the assembly.
2. Use a single ground mesh; never nest another prototype's ground or camera.
3. Build modular geometry as children of the assembly root.
4. Use a single camera, environment, and key light for the composition.
5. Keep props out of the central 1.2 m walking lane.
6. If the existing modules cannot be cleanly instantiated without preview rigs, duplicate the geometry helper logic temporarily rather than embedding preview scenes. Track that duplication for later refactoring.

## Camera framing
- Preview FOV: 70 degrees.
- Camera height: 1.65 m.
- Start near the mouth of the alley; look toward the far thrall.
- Capture both a normal-lit image and a lantern-focused image if runtime is available.

## Expected evaluation
This layout is a visual composition target, not a playable level. Validate geometry intersections, opening width, ground continuity, and lighting after opening in Godot.

## Known limitation
The procedural builders currently have no demonstrated runtime validation in this workflow. Coordinate values and framing are provisional.
