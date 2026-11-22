# Mobile Visual Budget — Lethemoor 3D Prototype

Status: design guardrails, not runtime measurements.

## Goal
Keep the first-person harbor art legible and performant on mobile/web while retaining a moody Gothic atmosphere. Prefer GL Compatibility-safe techniques and predictable material counts.

## Budgets for the alley kill-test
- **Drawn geometry:** favor shared modular meshes; avoid unique meshes for every stone.
- **Materials:** target 6–10 distinct materials in the alley composition; reuse material instances where practical.
- **Lighting:** one primary directional light plus one meaningful lantern light; decorative lamps should not all cast shadows.
- **Shadow casting:** reserve shadows for hero objects and the primary light. Disable shadow casting on small clutter.
- **Transparency:** use sparingly; avoid stacked transparent fog planes.
- **Texture sizes:** start at 512px for tileable surfaces and 256px for small props; increase only when close-up tests show a visible need.
- **Collision:** collision meshes separate from art; simplified shapes and no decorative stone collision.
- **Silhouette:** thrall and props should read at thumbnail scale and in a low-luminance scene.

## Visual hierarchy
1. Navigation landmarks and doorway silhouettes.
2. Lantern pools and their transition into darkness.
3. Enemy silhouettes.
4. Foreground debris and wet surface highlights.

## Test procedure
1. Capture at target mobile resolution.
2. View at 50% scale and thumbnail scale.
3. Toggle lantern and ambient contribution.
4. Remove half of the small props and compare.
5. If detail disappears or performance cost is disproportionate, simplify.

## Compatibility note
The existing prototype uses Godot's GL Compatibility renderer. Do not assume volumetric fog is available or economical. Favor environment fog and carefully controlled material/light cues until tested on target devices.
