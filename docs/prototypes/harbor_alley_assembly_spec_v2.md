# Harbor Alley Assembly Spec v2

## Target
A restrained, repeatable alley segment with modular walls and a clear navigable path, to replace the earlier overlapping-scene composition.

## Layout
- Footprint: 3 units wide x 8 units long (provisional).
- Walls: two parallel 8-unit runs, assembled from 2-unit modules.
- Entrance: partial opening on one side to break the corridor symmetry.
- Terminus: doorway or arch silhouette with an enemy placement zone behind/near it.
- Path: keep the central 1.2 units clear of large props.

## Assembly zones
- **Zone A / entrance:** one bollard and a small rope coil, placed against the wall.
- **Zone B / mid:** one wall-mounted lantern, mounted at approximately 2.2 units high.
- **Zone C / far end:** barrel/crate cluster with an offset thrall silhouette; avoid blocking the threshold.

## Modular wall constraints
- Straight modules must share dimensions and material assignment.
- Corner pieces must not overlap straight-run faces.
- Door surround is a separate module; do not bake it into the wall mesh.
- Cap and lintel pieces should be independently replaceable.
- Use simple collision primitives or a collision-only mesh.

## Readability
- Doorway and lantern must remain visible in a screenshot at 50% scale.
- Props must not occlude the center walking path.
- Enemy contrast should be checked against both lit and unlit wall values.

## Validation checklist
- [ ] Inspect seams at every module junction.
- [ ] Verify doorway dimensions against current game grid.
- [ ] Test grayscale and thumbnail readability.
- [ ] Confirm compatibility with GL Compatibility renderer.
- [ ] Test on target mobile device.
- [ ] Record actual performance; no assumed FPS.

## Scope
This document defines the assembly, not gameplay changes. The prototype remains isolated from main simulation and renderer logic.
