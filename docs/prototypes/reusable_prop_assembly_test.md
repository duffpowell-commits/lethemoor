# Reusable Prop Assembly Test

A composition-only preview that instantiates the extracted crate, barrel, and bollard scenes in one shared world.

- Individual props remain camera-, lighting-, and environment-free.
- One shared preview camera, directional light, and environment.
- A floor patch helps evaluate silhouette and scale.
- Blocker collision boxes are added as separate StaticBody3D nodes for rough interaction/scale review; they are deliberately not embedded in the prop scenes.

## Preview
Open `scenes/prototypes/reusable_prop_assembly_test.tscn`.

## Limitations
The blocker shapes are coarse, approximate and not intended as final collision. Scene/script review only; no Godot runtime validation was available.
