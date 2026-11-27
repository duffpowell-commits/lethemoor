# One Night atmosphere verification — 2026-11-27

Scope: approved [PR #74](https://github.com/duffpowell-commits/lethemoor/pull/74). No new game systems, enemies, damage, paid assets, or simulation RNG calls. The final presentation changes are outside `scripts/sim/`. Android and web remain on Godot 4.7.2 Compatibility. Existing GLB/geometry assets and the encrypted Lethemoor signing key are unchanged.

## What is built

| Beat | Runtime behavior |
|---|---|
| Harbor remembers | At most one top-crate shift. Only a subset of positive seeds (25% upper limit), after a pot landmark has been lit and in the view cone, eight turns have elapsed, and the player is at least seven grid tiles away, outside light and view. The same mesh instance and map cell remain. |
| Sound before sight | At most one original 4.21-second bowed-metal undertone in eligible nights (25% upper limit). It uses a seeded window at turns 25–70, waits for a quiet opportunity for up to eight turns, plays spatially at -18 dB, and captions the note while the voice is active. Suppressed for essential cues, visible/near horrors, flicker, high dread, hook/downed-horror hints, modal, or the intentional Bride silence; the tracked voice stops when a conflicting cue, lantern change, modal or end arrives. Active priority voices (including the full previous bell toll) also block starts, and unseen stationary hunters suppress the cue even when their randomized shuffle is silent. |
| Beautiful decay | Olive patina on the existing coping stones and muted upper masonry tint using vertex colors, with geometry/UVs retained. Existing stacked pots have original procedural wood texture and no extra collision. |
| Unreliable reflections | At most one 0.85-second, ripple-broken, low-alpha faceless silhouette on an already lit wet floor tile ahead. 20% of positive seeds are scheduled; the same quiet-opportunity checks, fog, and occupancy gates can suppress it. It avoids essential prop/chalk cells and extinguishes immediately when fog no longer marks its tile LIT, the view changes, the player acts or a modal appears. No actual character, map marker, shadow, collision, light, or hit is spawned. One lazy plane, no reflection render target. |
| Fragments of a forgotten life | Martha's letter refers to the lobster pots; Ada's to the oar under the boat. Existing reading rules, page order and grade points stay unchanged. |
| A different nightmare | `scripts/atmosphere.gd` selects bounded windows using the run seed, without a random generator. Seed zero is quiet for normal captures. The new effects do not change sim RNG or `Night`. |
| Dawn feels wrong | Existing success card retains grade, score, feedback, replay and title controls. Seed-specific unsettling line and a quiet 0.8-second cold wash; no delayed controls or new dawn room. |

Art: `tools/gen_atmosphere_art.py` reproduces the two small original textures. `tools/gen_audio.py --only harbor_undertone` reproduces the original clip; provenance is in `assets/audio/SOURCES.md`. FFprobe: Vorbis mono, 44.1 kHz, 4.212 s, 23,443 bytes. Decoded mean -20.5 dBFS, peak -8.8 dBFS before the -18 dB playback gain. No external audio/asset purchase.

## Real engine evidence

The following PNGs are actual 1080×1920 Godot viewport renders using OpenGL 4.5 Compatibility on Mesa llvmpipe, not mockups. The rare-event captures deliberately stage seed/turn/position inputs so the presentation can be examined deterministically; they are not organic playthroughs.

- [Wet tile, no reflection](renders/atmosphere_puddle_before.png) / [fleeting silhouette at peak](renders/atmosphere_puddle_reflection.png).
- [Crate before](renders/atmosphere_pots_before.png) / [return after unseen shift](renders/atmosphere_pots_return.png). The independent review of PR #79 also inspected the [exact-head prototype before](renders/atmosphere_prototype_crate_before.png) / [return](renders/atmosphere_prototype_crate_return.png) at `77a8956a45c37adbf5bcd34ee92517bc42d71b87`.
- [Spatial audio caption](renders/atmosphere_sound_caption.png).
- [Dawn verdict](renders/atmosphere_dawn.png).
- [Coping before](renders/atmosphere_wall_before.png) / [coping after](renders/atmosphere_wall_after.png) — matched seed-zero camera and lighting.
- [Portrait HUD](renders/atmosphere_hud_portrait.png) / [landscape HUD](renders/atmosphere_hud_landscape.png) / [letter rendering](renders/atmosphere_letter.png).
- LOW graphics at 540×960: [silhouette](renders/atmosphere_reflection_low.png) and [dawn](renders/atmosphere_dawn_low.png).

Reproduce: `godot --audio-driver Dummy --path . --rendering-driver opengl3 --resolution 1080x1920 res://scenes/fp_room.tscn -- --capture --atmosphere-only` on a real or virtual X display. The staged run logged `REFLECTION PASS hooded_hidden=true`, `ATMOSPHERE SOUND PASS` (active player and caption), `ATMOSPHERE PRIORITY PASS ringing_toll_blocks=true` (toll cancels the player and its active tail blocks restart), `LANDMARK MEMORY PASS`, `DAWN PASS`, `ATMOSPHERE PASS` at seed 3. The actual audio mix was not heard on a phone; the dummy backend validates dispatch and caption, not subjective acoustic quality.

The full after-pass runs finished `ART PASS`, exit 0, without `SCRIPT ERROR`, `FAIL` or renderer errors. It covered OPEN, FWD, TURN, SWIPE, PAD (tall/plates/slim), QUEUE, HOLD, ABOUT, ROTATE (centered/tap/back), BELL, LETTER/PAGES, KILL3D, DEATH, VERDICT, STALKER, SLICK, HOOK, HARBOR, TOWER, VIEWMODEL, PHANTOM. An earlier full run had only the host VSync warning; the final exact-head full run also reported 12 ObjectDB instances / 6 resources still in use after `ART PASS` (active OGG teardown, not rendering). No physical touch device was attached; the scripted capture sends actual Godot input events.

LOW graphics staging at 540×960 separately finished `ATMOSPHERE PASS`. Software-only llvmpipe logged 19–30 fps, 34–54 ms mean frame time, 132–225 draws across staged scenes. This is not a phone FPS benchmark.

## Benchmarks

Godot 4.7.2, 88-test stacked baseline and 92-test atmosphere branch. Both 500-night runs returned identical metrics:

| Metric | Baseline | Atmosphere |
|---|---:|---:|
| Newcomer wins (200 gentle nights) | 81 | 81 |
| Newcomer deaths | 106 | 106 |
| Newcomer lost/out of time | 13 | 13 |
| Expert wins (300 nights) | 148 | 148 |
| Expert deaths | 152 | 152 |
| Expert stuck | 0 | 0 |
| Deaths by turn 20 (both groups) | 0 | 0 |
| Expert mean oil at bell | 20.6 | 20.6 |
| Expert nights with no encounter | 7% | 7% |

Commands: `tools/test.sh`; `BOT_GENTLE=1 godot --headless --path . --script tools/first_timer_bot.gd -- 200`; `godot --headless --path . --script tools/balance_bot.gd -- 300`. The 7% no-encounter rate is unchanged; this is presentation work, not a claim of improved balance.

## Warning investigation

- The full pre-pass renderer capture reached `ART PASS` with exit 0. The real renderer reported a host VSync unsupported warning and audio-device absence (ALSA fell back to Dummy), not a Godot material failure. The staged atmosphere capture used Dummy explicitly and reported no rendering/material errors. A separate 60-frame `--headless` startup on both the integrated 88-test stack and the 92-test branch reproduced `Parameter "material" is null` at `servers/rendering/dummy/storage/material_storage.cpp:264`. It is specific to the dummy renderer path in these runs; neither actual Compatibility capture produced that warning.
- A verbose staged immediate quit identified retained `AudioStreamOggVorbis`, `AudioStreamPlaybackOggVorbis` and `OggPacketSequence` resources for **amb_moor** and **flame_loop**, not the new undertone. This is an active-loop-at-exit issue, not a corrupt OGG file. A single playing loop outside any scene reproduces it with `tools/ogg_shutdown_probe.gd`; adding `-- --stop` stops it, waits 0.25 s for the mixer, clears its stream and exits without the OGG warnings on this backend. No speculative production lifecycle change was made, since a process shutdown is different on Android/web and the normal full capture already exits cleanly. The corrected high staged run can still report active OGG cleanup on immediate exit (12 objects / 6 resources); an earlier LOW staged run exited without cleanup warnings, while the final immediate LOW exit also reported retained active streams. This is timing-dependent mixer teardown. The probe is not shipped.

## Automated quality versus human enjoyment

Engine tests, scripted touch interactions, rendered screenshots, audio dispatch, exports and bots measure correctness, not fun. The old capture's synthetic 7/10 verdict tests the feedback control only. No human enjoyment score, replay intent, actual Android FPS, Safari runtime, or subjective sound mix is asserted from automated evidence. Duff is not required to personally playtest. Volunteer feedback can still inform the separate Nov 28 viability decision.


## Integration and final export

| PR | Merged commit |
|---|---|
| [#76](https://github.com/duffpowell-commits/lethemoor/pull/76) | `64e27fd214f4bf6c8f3855bd238bb70f82484dc5` |
| [#77](https://github.com/duffpowell-commits/lethemoor/pull/77) | `a5befeb48348bc6087b1bf5d8652c633b6d8b7b3` |
| [#78](https://github.com/duffpowell-commits/lethemoor/pull/78) | `ff0bd05d880834f238d40837d16a3f0b310ae9ce` |
| [#79](https://github.com/duffpowell-commits/lethemoor/pull/79) | `e31f818f66dc49b683ef3358c86807ffca176899` |
| [#80](https://github.com/duffpowell-commits/lethemoor/pull/80) | `ab65ef570a709fd97ff80fa8b9d1304bd2ff6acf` |

Final exact head `00cb67786ef024025a456f52b1b808b1d746d1bd`: [CI build #215](https://github.com/duffpowell-commits/lethemoor/actions/runs/46038899848) test job `140641265080` logged **92 passed, zero failed** and **ART PASS**; export job `140643928422` produced web and Android artifacts, fixed-key signing and APK update permissions/versionCode 215. Gitleaks, rule-lock and exact-head fresh-eyes all green. The encrypted key blob remains `45e41c5b8b60f90aa70e133f1246b0226b78833d`; existing approved 3D asset files unchanged. The exact-head repeat of the 500-night benchmark matched every table metric above.

Main publication: [build #216](https://github.com/duffpowell-commits/lethemoor/actions/runs/46040084387), in progress at handoff preparation.
