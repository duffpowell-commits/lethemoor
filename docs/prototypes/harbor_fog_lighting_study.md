# Harbor Fog and Lighting Study

## Purpose
Isolate how fog depth and warm point lights interact with stone geometry in the Godot GL Compatibility renderer.

## Scene
- Narrow 4 m wide test corridor with depth markers at 2 m intervals.
- Cool ambient and directional fill.
- Three warm point lights at staggered distances.
- Environment fog enabled, with a modest starting density.

## Suggested tuning sequence
1. Run with fog density at 0.035 and capture a baseline.
2. Reduce density to 0.015 and 0.025, then increase to 0.05 and 0.07.
3. Keep ambient energy fixed while comparing fog values.
4. Repeat with one light at a time to isolate light falloff.
5. Judge marker visibility and silhouettes at a small-screen capture size.

## Decision guidance
Favor fog that hides distant clutter while preserving near-ground navigation cues. If warm light blooms into a uniform haze or near objects lose contrast, lower density or light energy. Avoid using fog to conceal geometry defects.

## Status
Prototype parameters are exploratory. The scene is not runtime-tested in Godot in this workflow; renderer support and actual appearance must be checked in the engine.
