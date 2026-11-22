# Harbor Alley 3D Kill-Test

## Purpose
Determine whether the current procedural masonry, wet-stone study, prop kit, and faceless enemy work together as a coherent first-person horror environment before investing in replacement art.

This is an art-and-composition test only. It is not a gameplay integration milestone.

## Test assembly
Use the existing isolated prototype scenes/builders on the `art/3d-art-conversion-blueprint` branch:
- Modular masonry builder
- Wet-stone ground study
- Harbor prop kit
- Faceless thrall study
- Shared-rig assembled harbor test

Treat the assembled shared-rig scene as the preferred composition starting point. Individual prototype scenes are reference material; their preview cameras, floors, and lighting may conflict when nested.

## Layout intent
Build a short, constrained alley with:
- One continuous ground plane, with no visible seams or duplicated floor slabs.
- Two masonry wall runs and a doorway or recessed opening.
- One lantern positioned as the key source of warm light.
- Two or three props only (bollard, barrel/crate, mooring detail) to prevent clutter.
- One thrall silhouette placed at the far end, with enough negative space to judge its shape.

## Evaluation procedure
Capture screenshots at a fixed camera position and resolution. Record the hardware and renderer if runtime tests are performed.

| Test | Pass criterion | Failure response |
|---|---|---|
| Composition | Alley direction and exit/doorway are immediately legible | Simplify prop placement |
| Wall modularity | No obvious gaps or doubled corner geometry | Revise module dimensions/pivots |
| Floor continuity | No overlapping preview slabs or conspicuous seam | Replace with one ground mesh |
| Lantern readability | Light source and lit region read distinctly | Adjust placement/value contrast |
| Wetness | Highlighting is selective; floor isn't mirror-like | Reduce specular/variation |
| Enemy silhouette | Thrall is readable against wall and fog | Adjust silhouette/value separation |
| Fog | Depth is visible without obscuring immediate navigation | Adjust density/range |
| Mobile legibility | Key forms survive small-screen viewing | Reduce fine detail |
| Performance | Record measured frame time and draw calls on target device | Simplify geometry/materials |

## Decision gate
Proceed to replacement art only if:
- The scene reads as a harbor alley at a glance.
- The wall module and ground can be assembled without obvious structural defects.
- Lantern contrast creates a useful visual focal point.
- Enemy silhouette remains legible under the intended lighting/fog.
- The test is reviewed on actual target hardware.

## Current status
This is a proposed validation procedure, not a report of tests completed. Godot runtime execution has not yet been performed in this workflow.
