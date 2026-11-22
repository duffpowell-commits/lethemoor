# Assembled Harbor Shared-Rig Prototype

This scene is the next composition study in the art-only conversion branch.

## Purpose
Bring the harbor masonry, timber bracing, crate, bollard, lantern, bell and faceless thrall into a single coordinate space and render them through one camera, one environment and one directional light. The scene is deliberately self-contained and does not reference gameplay systems or the active first-person renderer.

## Open
Open `scenes/prototypes/assembled_harbor_shared_rig.tscn` in Godot 4.5. This is a new preview scene, not a replacement for the original assembled test or any game scene.

## Current state and limitations
- Geometry is built in one script, using shared helper functions and a common material set.
- One shared camera, environment and light rig; an additional lantern-area light is a visual fixture only.
- The thrall is faceless and is only a silhouette placeholder.
- Floor wetness is currently represented by simple patch meshes. The shader study is not yet wired into this composition.
- This composition is a rough staging pass, not a production modular kit. Wall faces, doorway placement and props need visual inspection and proportions iteration.
- Godot runtime/editor validation has not been performed here. Scene/script syntax and framing remain to be checked in the engine.

## Next validation
Run the scene in Godot, check framing and collisions visually (there are no gameplay collision nodes in this art study), inspect GL Compatibility shader/material behavior, and then separate reusable geometry builders into clean modules before wider assembly.
