# Lantern and Fog Art Recipe

A restrained, renderer-conscious visual recipe for Lethemoor's harbor alley.

## Palette
- Ambient: muted blue-grey, kept low enough to preserve darkness.
- Stone: neutral grey with subtle cool tint; avoid uniform black shadows.
- Lantern: amber/yellow, not orange-white; bright core, softer surrounding spill.
- Wet ground: small broken highlights, never a mirror-like continuous reflection.
- Fog: grey-blue, close to background hue, with contrast reduced gradually.

## Composition
- Place the lantern near a wall corner, doorway, or landmark.
- Use one bright foreground pool, a dark mid-ground gap, and a readable far silhouette.
- Keep critical interactables out of the brightest bloom-like highlight.
- Avoid lighting the entire alley evenly.

## Practical implementation order
1. Establish unlit base materials and geometry.
2. Add low-intensity ambient contribution.
3. Add one directional source with restrained shadows.
4. Add one lantern light; verify falloff and scene readability.
5. Add distance haze using supported Environment fog settings.
6. Only after this baseline, test any renderer-specific fog technique.

## Compatibility/performance
- GL Compatibility is the project's current renderer.
- Godot volumetric fog is renderer-dependent and may not be suitable for Compatibility. Use non-volumetric environment fog or art-driven haze as the baseline; volumetric fog is an optional later experiment only after renderer validation.
- Avoid lots of overlapping transparent planes because sorting and performance can be troublesome.
- Keep a mobile screenshot comparison checklist and record actual device/runtime results separately.

## Acceptance criteria
- The doorway reads at thumbnail size.
- The thrall silhouette can be distinguished from the wall.
- The lantern pool has a visible boundary without obscuring gameplay cues.
- Stone highlights remain small and broken.
- The scene is legible in a grayscale screenshot.
