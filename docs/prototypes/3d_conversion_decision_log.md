# 3D Conversion Decision Log

## Current direction
- Godot 4.5.
- GL Compatibility renderer as the baseline.
- Grid-based scale retained for art alignment.
- Reusable modular environment pieces rather than one-off scene meshes.
- First-person camera readability is the primary art test.
- Mobile performance is a constraint, not a final optimization claim.

## Decisions
- **D-001:** Keep prototypes isolated from gameplay scenes and systems.
- **D-002:** Use environment fog / art-driven haze as baseline; volumetric fog is optional and renderer-dependent.
- **D-003:** Keep collision separate and simplified.
- **D-004:** Use shared materials where possible and avoid shadow-casting on small clutter.
- **D-005:** Test at thumbnail and grayscale scale for readability.
- **D-006:** Replace placeholders in order of visual impact, starting with masonry and lanterns.

## Open risks
- Prototypes are not yet validated in Godot runtime.
- Provisional scale may differ from current gameplay dimensions.
- GL Compatibility lighting and fog behavior needs target-device confirmation.
- Mobile frame pacing and shadow cost remain unknown.

## Next evidence needed
- Godot screenshots from the composition scene.
- Device / renderer / resolution notes.
- A gameplay-scale reference to verify wall height and doorway dimensions.
