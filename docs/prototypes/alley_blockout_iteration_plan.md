# Alley Blockout Iteration Plan

## Objective
Build a single repeatable alley composition that tests geometry modularity, first-person sightlines, and lantern-controlled contrast.

## Layout proposal
- Alley width: 3 grid units, excluding wall thickness.
- Test length: 8 grid units.
- Primary wall height: approximately 2.4 units.
- Door opening: approximately 1.2 units wide and 2.1 units tall.
- One lantern at roughly 2.2 units above ground, offset from doorway.
- One silhouette prop group near the far end, not centered on the walking path.

These are provisional blockout dimensions and must be checked against existing gameplay scale before integration.

## Iteration stages
### Stage A — geometry
- Straight wall run.
- One doorway.
- One inner and one outer corner.
- Confirm seams and grid alignment.

### Stage B — story props
- Add crate, barrel, rope, bollard, drain.
- Keep center path clear.
- Compare clutter density at screenshot thumbnail scale.

### Stage C — lighting
- One directional source.
- Low ambient fill.
- One lantern light.
- Add fog only after contrast and visibility work.

### Stage D — kill-test
The art direction fails or must be revised if:
- The doorway is hard to distinguish at thumbnail scale.
- The alley feels like a generic stone corridor rather than a wet harbor.
- Small props overwhelm navigation.
- Lantern lighting fails to establish a visible focal pool.
- The enemy silhouette disappears into the wall values.

## Scope
Standalone art prototype only. No gameplay logic, grid simulation, lantern mechanics, or main scene edits.
