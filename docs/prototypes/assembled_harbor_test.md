# Assembled Harbor Prototype Scene

Scene: `scenes/prototypes/assembled_harbor_test.tscn`

This is a first composition experiment referencing the corridor and harbor prop studies. It is an experimental scene only; it is not intended for gameplay integration.

## Caveat
The referenced prototype scripts currently build their own preview cameras, lights, floor/background, and environment. As a result, this composition may have overlapping preview infrastructure and is not a clean integrated environment yet. The purpose of this scene is to establish a composition entry point while the individual scripts are being modularized.

## Next cleanup
- Extract geometry builders from each prototype's preview setup.
- Replace duplicate preview cameras and floor/environment nodes with a single composition rig.
- Place assets in tile-aligned positions.
- Validate script parsing and scene rendering in Godot 4.5.
