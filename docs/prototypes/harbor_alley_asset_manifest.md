# Harbor Alley Asset Manifest

This manifest converts the alley prototype into an asset checklist for future production replacements.

## Required modular pieces
| Asset | Approximate footprint | Pivot / origin | Priority |
|---|---|---|---|
| Straight masonry wall | 2 x 1 grid units | bottom-center | High |
| Short wall | 1 x 1 | bottom-center | High |
| Inner corner | 1 x 1 | corner junction | High |
| Outer corner | 1 x 1 | corner junction | High |
| Door jamb pair | opening-width dependent | bottom-center | High |
| Stone lintel | opening-width dependent | bottom-center | High |
| Wall cap | modular segment | bottom-center | Medium |
| Lantern bracket | wall-mounted | mounting point | High |
| Bollard | 0.35 x 0.35 | ground-center | Medium |
| Mooring rope coil | 0.6 x 0.6 | ground-center | Medium |
| Crate | 0.8 x 0.8 | ground-center | Medium |
| Barrel | 0.6 diameter | ground-center | Medium |
| Drain grate | 1 x 0.5 | ground-center | Medium |
| Wet ground patch | 2 x 2 tileable | top plane | High |

## Naming
Use lowercase snake_case. Prefix harbor-specific assets with `harbor_`. Use suffixes `_mesh`, `_collision`, `_material`, and `_texture` only when the resource type is clear.

## Replacement order
1. Wall and corner modules.
2. Door surround and lintel.
3. Lantern.
4. Wet-ground surface.
5. Large silhouette props.
6. Small clutter.

## Export / integration rules
- Keep visuals and collision separate.
- Align pivots to the stated origin.
- Avoid scene-specific scripting inside reusable asset scenes.
- Keep each asset independently previewable.
- Use material overrides sparingly and document any exception.
