# Faceless Thrall Silhouette Iteration Plan

## Existing study
The current procedural thrall is a hooded humanoid with a dark facial void, uneven shoulders, hanging sleeves, coat panels and boots. It is a shape study, not a final enemy mesh.

## Three silhouette variants to evaluate
### A — Narrow, drifting
- Reduce shoulder width and remove visible belt/boot contrast.
- Extend coat hem unevenly.
- Keep arms close to the body, with one wrist lower.
- Goal: distant shape feels quiet and difficult to read.

### B — Wide, bent
- Increase shoulder asymmetry and forward lean.
- One shoulder raised; opposite arm hangs long.
- Hood and torso silhouette overlap.
- Goal: unmistakably wrong posture without relying on facial detail.

### C — Tall, trailing
- Increase apparent height through hood and upper-body proportions, not scaling the whole model.
- Long coat tails taper behind.
- Keep legs visually subordinate to the coat.
- Goal: silhouette catches lantern edge light while remaining mostly dark.

## Evaluation
Compare against a neutral grey wall and against the lantern/fog alley scene. Use identical camera framing and lighting for each variant. Evaluate at full size and thumbnail/mobile size.

| Criterion | Score 1–5 |
|---|---:|
| Readable silhouette at 5 m | |
| Distinct from generic humanoid | |
| Dark-face/no-eyes concept preserved | |
| Edge-light response | |
| Unsettling asymmetry | |
| Mobile-size readability | |

## Design guardrails
- No glowing eyes, bright face details, or gore as a shortcut.
- Keep materials dark but not uniformly black; edge lighting should reveal shape.
- Distinctive posture and silhouette should carry the design.
- Do not introduce animation, collision, combat, or AI in this art-only test.

## Status
Design iteration proposal. No variants have yet been runtime-rendered or scored.
