# Foxboard nightmare Thrall replacement proof — Nov 27, 2026

**Decision: not a replacement yet.** This test branch does not modify any shipped scene, asset, rules, save, or build. Keep the Meshy GLB. The recovered original can be skinned to the existing skeleton and play the existing clips, but the automatic transfer produces material distortion, especially crouch/lunge/dead. Do not merge as a model swap. No paid generation or new creature.

## Provenance and reproduction

- Base main: `88ea9c1b1b9257b6553c3521bc0a522006359ce1`; both live web HTML and Android release `version.json` confirmed build 199, `e17a537`.
- Foxboard TripoSR draft/Blender-cleaned rigid source: `13aee05:assets/models/thrall.glb`; mobile geometry revision `ef7d28d:assets/models/thrall.glb` used here (SHA256 `fe33c6f22be7df8e2061362617f1ecc562a80a00d60aaf5f7db46b5688d863ff`). Historical render confirms it has a visible face, which was why #45 removed it.
- Meshy fallback: `assets/models/rig_nightmare.glb`, `rig_nightmare_clips.res`. These files and their already shipped clips are reused unchanged. Original clip GLBs are documented in `lethemoor-3d/meshy_source/`, not in git; no rebake/download required for this comparison.
- Candidate is generated outside the project, not shipped. Same rigid design/rope, no generated substitute. Existing UVs preserved; 1K JPEG; +X facing rotated to +Z; exact Meshy node hierarchy and inverse bind matrices copied. Weight transfer uses four nearest reference vertices, then seam-welded topology smoothing and four normalized influences. Rope attached to hips. Experimental black material on the historical face is **not** approved finished art; silhouette/mask needs visual refinement. No topology reduction beyond the existing historical revision.

```sh
git show ef7d28d:assets/models/thrall.glb > /tmp/fox-thrall.glb
python3 tools/foxboard_proof/build_candidate.py /tmp/fox-thrall.glb assets/models/rig_nightmare.glb /tmp/foxboard-candidate.glb
# Requires numpy, scipy, Pillow. Godot 4.7.2, Compatibility, working X display.
godot --headless --path . --import
godot --path . --audio-driver Dummy --rendering-driver opengl3 --resolution 540x960 \
  --script tools/foxboard_proof/compare.gd -- /tmp/foxboard-candidate.glb /tmp/fox-compare motion
python3 tools/foxboard_proof/make_motion.py /tmp/fox-compare docs/renders/foxboard_proof
```

For initial unsmoothed baseline, append `--smooth 0` to the generator. Smoothed candidate SHA256 `e43a40c08d085302c778754e4b3b2b14ad4febbe05443ad2b0636af31ad291c1` on this environment; JPEG and floating implementation variations may change byte hash. Offline bind took ~0.55 seconds including command overhead for the smoothed run. No credits or service costs incurred; engineering time not separately metered. Prior Meshy total of 250 credits covered multiple monsters and hands, not attributable to this one creature.

## Size and rig evidence

| Model | Triangles | GLB bytes | Embedded albedo | Texture bytes |
|---|---:|---:|---|---:|
| Foxboard rigid | 6,832 | 3,381,448 | 2048² PNG | 3,151,289 |
| Meshy current | 7,631 | 823,508 | 1024² JPEG | 246,274 |
| Foxboard skinned proof | 6,832 | 567,848 | 1024² JPEG | 207,962 |

Both rigged models have 24 bones, identical `Armature/Skeleton3D` paths and shared clip library. Generator normalizes weights; all joints resolve by design and Godot clip track names were resolved. `down` uses `dead` fallback. Idle/walk/crouch/lunge hips are horizontally pinned; dead and rise intentionally travel (existing clips). Hip displacements are printed in raw skeleton units (centimeters) and identical for models; actor positions stay fixed. No new audio, animation licenses or paid generation.

## Deformation and visual gate — FAIL

Sampled edge lengths relative to skinned rest mesh; edges shorter than 0.01 model units omitted. 95th percentile stretch ratio (1.0 = unchanged); one sample per state, dead/down at end. Smoothed candidate improves considerably on initial unsmoothed maximum 23.27x in dead, but still does not meet a no-distortion bar.

| State | Meshy p95 | Foxboard p95 | Foxboard max |
|---|---:|---:|---:|
| Idle | 1.11 | 1.30 | 4.10 |
| Walk | 1.11 | 1.27 | 4.41 |
| Crouch | 1.17 | 1.40 | 5.66 |
| Lunge | 1.22 | 1.69 | 6.84 |
| Dead / down | 1.16 | 1.88 | 7.31 |
| Rise | 1.19 | 1.48 | 4.79 |

See `docs/renders/foxboard_proof/` (Meshy left, Foxboard right, same scene, floor, camera and lights). 540×960 stills, nine sampled frames per action assembled as 360×640 GIFs (not continuous video). Idle/walk/crouch loop endpoint repeats by design. The candidate's shoulders/coat and rope still need manually supervised weighting, topology cleanup and face concealment refinement. The nearest transfer is from a markedly thinner character, so this failure is expected; do not mistake successful clip binding for acceptance. Next: artist-supervised shoulder/hip and coat topology repairs, isolated rope behavior, and repeat this same benchmark, then phone A/B. No game scene integration until proof passes.

## Cloud benchmark (not device results)

Godot 4.7.2 Compatibility, Mesa llvmpipe software OpenGL, shared cloud Xorg dummy display, 540×960, same floor, environment, camera, light/pose, 10 warmup frames, then 60 process frames. One isolated run (`compare-smooth.log`); not a statistical speedup claim. Meshy and Foxboard benchmark separately; the candidate has extra material surfaces. Timing excludes import/build.

| Actors | Meshy ms/60 frames | Foxboard ms/60 frames | Meshy derived FPS | Foxboard derived FPS |
|---:|---:|---:|---:|---:|
| 1 | 999.950 | 1017.743 | 60.0 | 59.0 |
| 4 | 1501.231 | 1438.614 | 40.0 | 41.7 |
| 8 | 2509.870 | 2412.455 | 23.9 | 24.9 |

No real Android/iPhone FPS measured. Repeat multiple trials on devices before performance acceptance.

## One Night baseline, no live changes

- `tools/test.sh`: 84 passed, 0 failed. Import repeated with writable config (no errors); `fp_view.gd` and proof script parse checked. Baseline real Godot capture completed `ART PASS`, including harbor, lunge, head look and corpse. The capture's scripted verdict is not a human score. Logs alongside this README.
- Newcomer simulation 200 nights: 81 won, 106 died, 13 lost/out of time; expert 300: 144 won, 154 died, 2 stuck. Simulations are not human playtests.
- P0 wall-top source: current `assets/art/wall_top.png` is the old 32×32 scaffold (not approved painted harbor coping); current granite is wall-face material, not a dedicated coping texture. No matching 512² wall-top delivery found in `grok_art/`. Leave current harbor untouched and request exact approved painted coping art through Foxboard. `live-harbor.png` is baseline capture, not a P0 fix.
- Nov 28 gate: build 199 Android + web human tester median fun >=6 and voluntary replay; collect FPS, lunge/corpse/kill-shot readability, swipes and sound. 8.5 separate release-quality target remains unverified. No itch release or safe-room/satchel/revenant/Choir expansion.

Resume at this README and `tools/foxboard_proof/`; keep `assets/models/rig_nightmare.glb` live fallback. Do not merge without required independent review and statuses.
