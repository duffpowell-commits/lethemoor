# Reusable Prop Assembly Test

A composition-only preview that instantiates the extracted crate, barrel, and bollard scenes in one shared world.

- Individual props remain camera-, lighting-, and environment-free.
- One shared preview camera, directional light, and environment.
- A floor patch helps evaluate silhouette and scale.
- Each standalone prop scene now carries a coarse StaticBody3D collision shape with the same transform as its geometry; composition no longer creates duplicate blockers.

## Preview
Open `scenes/prototypes/reusable_prop_assembly_test.tscn`.

## Collision scope
The crate, barrel and bollard use deliberately simple box collision volumes. They are suitable for prototyping navigation obstruction, but should be reviewed against player dimensions and interaction requirements before production.

## Validation
Godot 4.5.1 headless import/parse and the reusable-prop scene smoke launch passed on GitHub Actions (run 2).
