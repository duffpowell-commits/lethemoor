# HANDOFF: Glaze (Grok Bot) to Claude, Lethemoor art pipeline

Owner: Duff Powell. Written Nov 8 2026 (CST). Branch: `glaze-art`. Do not merge into main without Duff's OK.
Glaze designs and generates the art. Claude converts, cleans, lights and integrates it. Read this before touching anything in `grok_art/glaze/`.

> **Current game (read this first, 21 Nov 2026 CST).** Lethemoor is now a **first-person**
> grid crawler. Official art rules and the priority list live in the repo at
> `docs/art_needs.md` (Nov 19). The look is **painted, not pixel art**; textures are
> **512×512 seamless**; standing figures are ~190×500 and face the camera; light the
> art flat and let the in-game lantern do the lighting; enemies are faceless.
> Don't start full-game systems (safe room, satchel, corpse, Choir) before the
> One Night slice passes its kill test on **28 Nov**. The 64 px / 48 px pixel-art
> rules below are the old top-down pipeline and still describe work already in
> `glaze/final/`. New environment art follows the painted 512 spec. See
> **§11 Art needs (updated 2026-11-21)**.


## 1. The game (paste this to any image model at the start)
Lethemoor is a turn-based survival horror game for phones. 1890s Victorian harbour town sealed in fog.
One lone survivor with a lantern walks tile by tile; light is life (the lantern is your vision and oil
is your clock). Style: HD-2D pixel art like Final Fantasy Resonance and Octopath Traveler: crisp pixel
sprites, the mood comes from warm lantern light against blue-black darkness. Tone: gothic, Edgar Allan
Poe, quiet dread, slightly wrong anatomy. Palette: "Amber and ink": warm gold light, blue-black dark,
desaturated bone, moss, rust; blood red only for vampires and danger.

## 2. Hard rules for every image (from Duff's plan PDF)
- Solid flat #00FF00 green background. No scenery, no floor shadow, no text, no border.
- Pixel art: crisp hand-placed pixels, no anti-aliasing, no blur, no gradients, no painterly brushwork.
- The character fills about 80% of the frame height and is designed to downscale cleanly to 64 px tall.
- View: 3/4 top-down camera (like Octopath), lit by a single warm source low and to the right unless told otherwise.
- Max ~16 colours. Avoid chibi, cute, anime gloss, and the 3D-render look.
- Attach the approved style anchor (the skull-faced lantern-bearer, `anchor_lantern_bearer_green.png`) and say
  "match this exact character, style and palette".
- Save the ORIGINAL file, not a screenshot.

## 3. Base prompt template
```
Single game sprite, 2D pixel art, HD-2D style (Octopath Traveler-like): crisp hand-placed pixels,
no anti-aliasing, no blur, no gradients. Subject: [describe] View: 3/4 front-facing, full body, idle pose,
centered. Canvas: character fills ~80% of a square frame, designed to downscale cleanly to 64 px tall.
Palette: max 16 colors: desaturated bone, rust, moss green, ink black; ONE warm accent (lantern amber).
Lighting: single warm light source from the lantern, low and to the right; deep shadows, rim light.
Mood: gothic, Edgar Allan Poe, quiet dread, something slightly wrong with the anatomy. Background: flat
solid #00FF00, no scenery, no floor shadow, no text, no border. Avoid: chibi, cute, anime gloss, 3D render
look, painterly brushwork.
```

## 4. Movement test results (Nov 7 2026) and decision
There were 18 attempts (T1 to T6, 3 each). Each attempt is scored on six 0–2 checks after a 64 px nearest-neighbour shrink. A test passes when at least 2 of its 3 attempts score 10/12 or more.
Script: `tools/score_movement_test.py`. Raw numbers: `tests/scores.json`. Overview: `tests/contact_sheet.png`.

| Test | Totals (try1/2/3) | Result |
|---|---|---|
| T1 turnaround | 11 / 8 / 7 | FAIL |
| T2 walk sheet | 8 / 8 / 9 | FAIL (all 4 frames are the same stride pose) |
| T3 frame-by-frame walk | 9 / 9 / 10 | FAIL (frames identical, or one mirrored) |
| T4 idle | 10 / 9 / 9 | FAIL (2nd frame is a full repaint, so the image shimmers) |
| T5 hurt/death | 6 / 7 / 5 | FAIL (size and grid checks; the poses themselves read well) |
| T6 Stalker | 10 / 10 / 10 | PASS |

**DECISION (plan B, locked):** use one pose per character, flipped for left/right. Move between tiles with a
2-frame bob that Claude does in code. There are no up/down facings (T1 failed), so the game uses **left/right only**.
Only the Motion score was assigned by hand (by Glaze). Duff makes the final yes/no on animation.

## 5. Prompting lessons learned (use these)
- **Name the feet in every frame.** For example: "Frame 1: right foot forward, left foot back. Frame 2: feet together ..."
  The PDF's "contact / passing" wording produced 4 copies of the same pose. Even with the feet named, Grok draws
  stride / together / stride / together with the SAME leg forward. It never mirrors the leg.
- **Name facings by screen edge.** Write "face pointing to the LEFT edge of the image", not "facing left".
- **Pin the lantern hand.** Write "lantern always in his LEFT hand, the same physical hand in every view".
- **Hidden faces:** write "face COMPLETELY covered by wet hair, no eyes, no skull ... carries NOTHING".
- **Anchor bleed (new, round 1 enemies):** with the lantern-bearer attached, new creatures often come back with a
  lantern and/or a skull face, even when the prompt says "carries nothing". This happened to B1, B2, B3 and A3.
  The wording that fixed it (C1, C2, B3b): *"Copy ONLY the pixel technique and colour palette of the attached
  image; do NOT copy its character, skull or lantern. There is NO lantern anywhere in this image."* C3 was made
  with no anchor at all and still matched the style well enough.
- **Digitigrade (backward) knees (round 2, A3 docker):** "knees bend backward" or "digitigrade legs" alone gives
  normal human knees. Attaching the lantern-bearer anchor on top of that also brought back the skull face. What worked:
  *"SATYR / GOAT hind legs, trousers torn off at mid-thigh, sharp backward-pointing HOCK joint, small cloven hooves,
  exaggerate so it reads at 64 px"*, with NO style anchor attached. Alternatively attach the character's own earlier
  passing image and ask for "deep crouch, legs spread". Grok draws true goat anatomy (short thigh, long backward
  hock), so always check the 64 px downscale: a near-vertical shin reads as a bent human knee (that is why A3 v2 is only partial).
- **Fusing a held prop into the body (round 2, B2 stages):** "the lamp fuses into his body" still came back as a held
  lantern 2 of 3 times. Say what REPLACES the hand: *"his right hand is GONE; the brass lamp has grown INTO the
  forearm, flesh and veins wrapped over the brass, no handle, no fingers"*. For the final stage, name a new
  anatomical home for the prop (for example "the lamp is now his HEART, glowing inside a fanged chest").
- **Palette at 64 px:** plain median-cut quantize to 16 colours drops small accents (Red Death lost its white mask
  and blood red). Pin accent colours (brightest, most saturated red, darkest) and k-means the rest. See
  `enemies/round2/red_death_cleanup/cleanup_64.py`.
- **The Revenant (anchor attached on purpose):** with the anchor attached, Grok still invented a hat (a fedora, then a top hat) 2 times out of 3. Write "BALD SKULL HEAD, NO HAT, exactly like the attached character". Words like "nailed into his chest" and "maggots" got the request blocked by the provider's content policy. "Sits inside his open ribcage like a heart" went through.
- **Wound wording gets blocked:** with the anchor attached, any prompt containing "fatal wound", "killing blow", "blood", "driven / jammed into", "crater" or "caved in" was blocked by the image provider (6 blocks). What worked was attaching the earlier R3-B image and asking to "redraw the attached ghoul with these changes: lantern LIT ... tilted crooked ... too big for the ribcage, ribs cracked and bent outward like a burst cage, dark red stains ... slumped". Phrase changes as edits to an existing image, and say "dark red stains", not "blood".
- **Ground shadows:** Grok sometimes adds a dark-green floor shadow or puddles. `cleanup_64.py ... --shadow` keys out green-tinted dark pixels and stray specks.
- **Cobbles:** write "small ROUNDED, irregular, dome-shaped setts ... NOT rectangular bricks".

## 6. Known output limitations (Claude must handle these)
1. **The background is not pure #00FF00.** The images are JPEG, and the green averages about (4, 235, 12) with ±5–20 noise.
   Chroma-key by hue with a tolerance (`g > 140 and g - max(r, b) > 70` works). Never key on the exact colour.
2. **There are far too many colours.** Even at 64 px, 90% of the pixels use 700–1,900 distinct colours. Claude must
   **palette-quantize to 16 colours or fewer** (ideally to one shared Amber-and-ink master palette).
3. **The tool's widest aspect ratio is 16:9**, so cells in a row are never square (a 4-cell row gives 256×576 cells).
   Figures drift up to about 12% of a cell's width off centre. Re-centre each frame on its sprite bounding box and baseline.
4. **The tiles are not seamless.** Each tile is drawn with a border or bevel. Crop inside the border, or regenerate with
   "edge-to-edge texture".
5. **Two-frame animations shimmer.** "Same image but 1 px lower" comes back fully repainted. Do idles and bobs in code.
6. The source "pixels" are 4–6 px blocks that don't line up with any grid, so the 64 px shrink is noisy. Faces need a
   hand fix (as with bearer64).

## 7. Art direction (new, from Duff, Nov 8 2026)
- **Silent Hill:** fog that hides things, rust, wet flesh, body horror wrapped in the everyday. Nurses, bandages,
  straitjacket-like bindings, faces that are absent or wrong. Enemies feel like a town's guilt made physical.
- **Resident Evil G-virus bosses:** multi-stage, mutating bosses. Eyes erupt from tissue (shoulder, chest,
  neck, along limbs). Growth is asymmetric, one limb outgrowing the body. Each stage visibly loses more of the
  human, but keeps one recognisable human detail (cap, spectacles, buttons) until the last stage.
- **Edgar Allan Poe:** the Raven, the Tell-Tale Heart, the Masque of the Red Death, premature burial, guilt and
  obsession, the beating thing under the floor.
- **Palette stays Amber and ink.** Raw tissue is grey-pink or bone, not bright. **Blood red only for vampires and
  danger** (wounds, the Tell-Tale heart, the Red Death). Don't let red take over a whole sprite (A1 is borderline).

## 8. Writing tone (all in-game text: flavor, item descriptions, death screens)
Poe's gothic dread crossed with Chuck Palahniuk:
- terse, second person ("you"), blunt;
- darkly funny, deadpan;
- repetitive refrains ("Keep walking." / "Neither will you." / "Count them again.");
- clinical body detail (ribs, knuckles, the eye that doesn't blink);
- 2–3 short lines per entity. End on the punch. Never explain the monster.
Examples are in `enemies/round1/candidates.json`.

## 9. File manifest (grok_art/glaze/)
| Path | What |
|---|---|
| `HANDOFF.md` | this file |
| `anchor_lantern_bearer_green.png` | approved style anchor (1024 px, on green) |
| `tests/` | movement test: 27 attempt PNGs (`t1_turnaround_tryN` ... `t6_stalker_lurch_tryN`), 18 GIFs, `contact_sheet.png`, `scores.json`, `motion_scores.json` |
| `tools/score_movement_test.py` | scorer (6 checks, 64 px nearest-neighbour) |
| `tools/motion_scores.json` | Glaze's provisional Motion calls |
| `tools/build_showcase.py` | builds the showcase conversions and contact sheet |
| `showcase/` | best walk / turnaround / Stalker / cobbles / oil flask, with 64 and 48 px versions, `showcase_contact_sheet.png`, `README.md`, and `rejected/` |
| `enemies/round1/` | 9 enemy candidates (A1–A3 grunt, B1–B3 boss stage 1, C1–C3 Poe), each with `_64px.png`, `contact_sheet_{A,B,C}.png`, `candidates.json` (concept and flavor text), and `alts/` |
| `enemies/round2/` | A3 Faceless Docker re-do with backward knees: `a3_docker_v1..v3.png` + `_64px.png`, `contact_sheet_A3.png`, `candidates_a3.json`, `rejected/` |
| `enemies/round2/b2_stages/` | B2 Lighthouse Keeper stage 2 (`b2_stage2_v1/v2`) and stage 3 (`b2_stage3_v1/v2`) candidates + `_64px.png`, `b2_stage1_chosen.png`, `contact_sheet_b2_stages.png` (all four plus stage 1), per-stage sheets, `candidates.json`, `rejected/` |
| `enemies/round2/red_death_cleanup/` | C3 Red Death 64 px cleanup: `C3_red_death_64px_q16.png` (transparent, 16 colours), `_green.png`, `_palette16.png`, `_before_after_x6.png`, `cleanup_64.py` (reusable for any sprite) |
| `enemies/round3/` | Revenant candidates `R3A/R3B/R3C_*.png` + `_64px.png`, `contact_sheet_round3_revenant.png`, `candidates.json`, `rejected/` (versions that added a hat) |
| `enemies/round3/r3b_v2/` | R3-B v2 (lit lantern, fatal chest wound): `r3b_v2_1_wedged`, `_2_bled_out`, `_3_slumped` + `_64px.png`, `contact_sheet_r3b_v2.png`, `candidates.json` (flavor) |
| `final/` | GAME-READY sprites (incl. Revenant `r3b_revenant_64px*.png`). `sprites/*_left.png` / `*_right.png` (transparent, 16 colours), `bob_gifs/*_bob.gif` (2-frame, 1 px bob, x4 preview), `final_before_after_x6.png`, `work/` (green versions, palettes, before/after per sprite), `cleanup_64.py`, `README.md` |
| `enemies/make_contact_sheets.py` | rebuilds the round contact sheets (`python3 make_contact_sheets.py round1 [label]`) |
| `final/env/` | GAME-READY painted env, Duff's 21 Nov picks: `wall_top.png` (v1 mossy coping), `floor_wet.png` (v2 flooded, lit flat, no baked lantern), `drain_grate.png` (v1 square iron), `prop_belltower.png` (v1 parish, 442×1024, transparent, cross kept). Names match the repo where it already has a path |
| `env/round2/` | Bell-tower landmark candidates (21 Nov): `prop_belltower_v1_parish.png` (442×1024, transparent), `prop_belltower_v2_harbour_watch.png` (262×1024, transparent), `contact_sheet_belltower.png`, `raw/`, `work/` |
| `env/round1/` | painted 512 env tiles (Nov 21): wall tops, wet floor, drain grates; `contact_sheet_round1.png`, `_512.png` files, `tiles_3x3/`, `detail/` 4x crops, `raw/`, `rejected/`, `process_tiles.py`, `candidates.json` |

## 10. Decisions log
| Date (CST) | Decision | By |
|---|---|---|
| Nov 7 2026 | Skull-faced lantern-bearer approved as the style anchor | Duff |
| Nov 7 2026 | Pivot to turn-based survival horror: 64 px characters, 48 px tiles | Duff |
| Nov 7 2026 | Movement test: T2 and T3 fail, so plan B (flip + code bob). T1 fails, so left/right only. T6 Stalker passes | Test (Duff to confirm Motion) |
| Nov 8 2026 | New art direction: Silent Hill + RE G-virus bosses + Poe. Writing: Poe x Palahniuk | Duff |
| Nov 8 2026 | Glaze's art lives in `grok_art/glaze/` on branch `glaze-art` | Duff |
| Nov 8 2026 | Round 1 enemy concepts: 3 per type | Done (picks below) |
| Nov 8 2026 | **Grunt = A3 Faceless Docker.** Backward (digitigrade) knees are a REQUIRED trait. Membrane face, flat cap, dock clothes, NO lantern. Round 2: v1 and v3 pass (clear backward hock at full size and 64 px), v2 partial (reads as a bent human knee at 64 px) | Duff |
| Nov 8 2026 | **Boss = B2 Lighthouse Keeper** (G-virus style, 3 stages; the lamp is his core) | Duff |
| Nov 8 2026 | **Poe enemy = C3 Red Death** | Duff |
| Nov 8 2026 | **Grunt base = A3 v3** (`enemies/round2/a3_docker_v3.png`) | Duff |
| Nov 8 2026 | **Keeper stage 2 = `b2_stage2_v1`** (lamp grown into the right forearm) | Duff |
| Nov 8 2026 | **Keeper stage 3 = `b2_stage3_v1`** (lamp-heart brute). The skull-like face is APPROVED, keep it | Duff |
| Nov 8 2026 | Final sprites in `final/`: A3 and Keeper stages 1 and 2 at 64 px tall. **Keeper stage 3 at 96 px tall** (boss scale, 1.5x a normal character, 2 tiles high at 48 px; Claude can scale the encounter around it). Stage 3 floor shadow removed. Left and right copies made by flipping (plan B) | Glaze |
| Nov 8 2026 | **Revenant = R3-B Lantern Heart.** Feedback: (1) the old flavor text did not match the picture; (2) the lantern must be LIT with a warm amber flame like the lantern-bearer's, and must look FORCED into his chest, obviously what killed him: ribs broken outward, chest caved in, lantern lodged crooked, coat torn, dried blood (blood red allowed here), posture slumped around the wound. Bald skull, no hat, empty clawed hands | Duff |
| Nov 8 2026 | R3-B v2: 3 variants in `enemies/round3/r3b_v2/` (v1 wedged, v2 bled out, v3 slumped), all lit; new flavor text describes exactly what is drawn | Done |
| Nov 8 2026 | **Revenant final = R3-B v2 Bled Out** (`r3b_v2_2_bled_out.png`) with ribs HAND-PUSHED at 64 px: 4 ribs per side fan out from the lit lantern like a burst cage, tips past the coat edge, bone with an ink outline, blood red at the break points, still 16 colours. Final: `final/r3b_revenant_64px.png` (36x64), `sprites/r3b_revenant_64px_left/right.png`, `bob_gifs/r3b_revenant_64px_bob.gif`; edit script `final/work/r3b_rib_edit.py`. Flavor: "You know exactly how much blood a man holds now. It's all on the coat. The lantern drank the rest and kept burning. Lean in. It leans too. It always wanted to be closer to you." | Duff |
| Nov 8 2026 | Defaults while unanswered: Keeper stage 3 stays 96 px; left-facing = simple mirror | Default |
| Nov 8 2026 | Red Death 64 px cleanup: green keyed out, 16-colour palette, accents pinned | Done (Glaze) |
| Nov 21 2026 | **The game on main is first-person painted art, not 48 px pixel tiles.** Official list: `docs/art_needs.md` (Nov 19). Style: painted, lit flat, 512×512 floors/walls, standing figures ~190×500 facing you, faceless enemies. Claude skipped wiring wall tops (eye 0.82 vs walls 2.4, top faces never seen). Don't start full-game art (safe room, satchel, keys, lamp keeper) before the Nov 28 kill test | Repo / Claude handoff |
| Nov 21 2026 | Env round 1 (painted 512, 2 variants each) in `env/round1/`: wall tops v1 mossy coping / v2 broken brick; wet floor v1 puddles / v2 flooded (lit flat; replaces the unused 256 px baked `floor_wet.png`); drain grate v1 square iron / v2 manhole (hero tiles). Duff to pick. 48 px pixel floor/prop list was not made; repo specs won | Glaze |
| Nov 21 2026 | **Env picks:** wall tops = v1 mossy coping (`final/env/wall_top.png`); wet floor = v2 flooded (`final/env/floor_wet.png`, lit flat, no baked lantern light); drain grate = v1 square iron (`final/env/drain_grate.png`). `docs/art_needs.md` names wall tops and the wet floor; it does not name the grate file | Duff |
| Nov 21 2026 | Bell-tower landmark, 2 variants (no exact filename in art_needs; named `prop_belltower_*` to match `prop_bell` / `prop_lamppost`). v1 parish tower (granite, arched belfry, small cross); v2 harbour watch (taller, thinner, open cupola, mixed brick). Transparent PNGs, ~1024 px tall, lit flat. There is no skyline layer today: walls are 2.4-high boxes against `sky_night` (2048×1024 panorama). A Sprite3D at the bell tile, taller than 2.4, would peek over the wall tops. Duff to pick | Glaze |
| Nov 21 2026 | **Bell tower = v1 parish, keep the cross** → `final/env/prop_belltower.png` (442×1024, transparent). v2 kept as alt. **Wiring note for Claude (art only, no code from Glaze):** there is no skyline layer; walls are 2.4-high boxes against `sky_night`. Add a Sprite3D billboard (`_prop_sprite` / FIXED_Y) at the bell tile, base at the bottom, about 5–7 world units tall so the belfry peeks over the wall tops. Leave the close `prop_bell` as the ringable bell | Duff |


## 11. Art needs (updated 2026-11-21)

Audited against **main** at `7191080d` (20 Nov 2026, 8:29 PM America/Chicago). Official list: `docs/art_needs.md`. The live view is `scripts/fp_view.gd` (first person). Old 2D/HD-2D views are reference only. `docs/art_needs.md` is a few days behind the assets: several P1 items are already wired but not ticked off.

**Big change from our earlier assumptions (Duff, Nov 19: "Switch fully now"):** the slice is a first-person grid crawler with **painted** art, not 48 px pixel tiles. House rules now: painted, moody, wet, gothic; light it flat (the lantern lights the scene); faceless enemies; PNG with transparent backgrounds for world/HUD props; phone-first (~390 px wide). Sizes: standing figure ~190×500, floor/wall 512×512 seamless, floor prop 100–400 px tall, HUD hands ~660×665, letters ~600×800, icon 1024×1024.

### Still needed for the One Night slice (before / during Nov 20–28 playtests)

| Pri | Asset | Path / name the game expects | Size / frames / facing | Status |
|---|---|---|---|---|
| P0 | Wall tops | `assets/art/wall_top.png` (placeholder only). FP view does **not** load it: walls use `wall_granite` / `wall_damask` on every face of a 2.4-tall box | 512×512 seamless. Art-needs copy: mossy coping or broken brick edges | **Art picked, not wired yet** (repo file is still the 32×32 placeholder). **Picked 21 Nov: v1 mossy coping** → `final/env/wall_top.png` (from `env/round1/wall_top_v1_mossy_coping_512.png`). v2 kept as alt. **Conflict:** Claude skipped wiring (HANDOFF_LOG: eye height 0.82 vs walls 2.4, top faces never seen). Distant walls in `docs/renders/fp_start.png` only show a hard box-mesh skyline. A top-face texture alone will not fix that; a coping trim / alpha silhouette would |
| P2 | Wet-puddle floor | no dedicated path yet; all floors are `floor_stone`. Unused leftover: `floor_wet.png` | 512×512 seamless, lit flat | **Art picked, not wired yet.** Existing repo `floor_wet.png` is **256×256** with baked orange lantern reflections (breaks "light it flat") and is not loaded. **Picked 21 Nov: v2 flooded** → `final/env/floor_wet.png` (lit flat, no baked lantern). v1 kept as alt. Replaces the unused 256 px baked `floor_wet.png` in the repo once Claude wires it |
| P2 | Drain grate floor | no path yet. Old placeholder `exit.png` is a 32×32 pixel grate; FP would use it on `E` tiles, but the One Night map has **no E** (the goal is the bell `B`) | 512×512 hero tile | **Art picked, not wired yet.** **Picked 21 Nov: v1 square iron** → `final/env/drain_grate.png` (art_needs had no exact filename; named to sit beside `floor_wet`). v2 manhole kept as alt |
| P2 | Bell tower landmark | not in FP view | tall silhouette prop seen over the walls | **Picked 21 Nov: v1 parish, keep the cross** → `final/env/prop_belltower.png` (442×1024, transparent). Close bell `prop_bell.png` stays. **Wiring for Claude:** Sprite3D billboard at the bell tile, base at the bottom, about 5–7 world units tall, so the belfry peeks over the 2.4-high wall boxes against `sky_night`. No skyline layer exists today |
| P2 | End screen art | end card is a dark ColorRect + text only (`fp_view.gd`); no illustration path | two images ~540×300: "bell rings" and "the dark took you" | **Missing** |
| P2 | Title card logo | title uses `title_keyart.png` as a full-bleed background (576×1024 painted alley, no wordmark) | ~900×250 transparent "LETHEMOOR" lettering | **Missing** (key art is done; the lettering logo is not) |

### Done in the game (painted, already wired on main)

| Asset | Path | Size | Notes |
|---|---|---|---|
| App icon | `app_icon.png` + Android 192 / adaptive 432 | 1024×1024 | Art is in the repo. CLAUDE.md still says the installed APK / iPhone home screen may show the Godot robot — that's a wiring/export issue, not missing art |
| Night sky | `sky_night.png` | panorama strip | P0 #2 done |
| Walls | `wall_granite.png`, `wall_damask.png` | 512×512 | live FP materials. Older 256 px `wall_stone.png` / `wall_paper.png` are leftovers |
| Floor | `floor_stone.png` | 512×512 | live FP floor (wet flagstones already). `floor_0..3.png` are leftover 32 px placeholders |
| Stalker | `stalker_bride.png` | standing figure | P1 done. Not our old T6 pixel Stalker |
| Thrall variants | `thrall_dock`, `_netmender`, `_dockwoman`, plus scarier `thrall_nightmare`, `_clawed`, `_hooded`, `_wired`; lunge `thrall_lunge_nightmare` | ~190×500, facing you, faceless | P1 #5 is done (net-mender + dock woman) and more besides; `docs/art_needs.md` was not ticked off |
| Oil slick + fire | `decal_oilslick.png`, `decal_fire.png`, `fire_sheet.png` | decal + 8-frame flipbook | P1 done |
| Lantern hands | `hand_lantern.png`, `_hooded`, `_bright`; left hand `hand_hook.png` | ~HUD 660 | P1 done |
| Lamp post, nailed letter, flask, boathook, bell | `prop_lamppost`, `letter_nailed`, `prop_flask`, `prop_boathook`, `prop_bell` | standing / wall props | P1 / slice props done. We did **not** remake these |
| Title key art, letters, map, blood FX | `title_keyart.png`, `letters/page_1..3.png`, `map_parchment.png`, `blood_pool.png`, `fx_blood_screen.png` | various | done |

### Our earlier pixel deliveries vs the current game

These are finished on our side (64/96 px, left/right flip, 16 colours, plan B bob) but **they are not what `fp_view.gd` loads**. The slice uses painted standing figures and HUD hands.

| Our sprite | Local final | In the current FP game |
|---|---|---|
| Lantern-bearer style anchor | `anchor_lantern_bearer_green.png` (and old `bearer48`/`bearer64` in assets, tiny pixel shrinks) | Replaced by painted `hand_lantern_*` |
| A3 Faceless Docker | `final/sprites/a3_docker_64px_{left,right}.png` | Not used. Dock thrall is painted `thrall_dock.png` |
| B2 Lighthouse Keeper stages 1–3 | `final/sprites/b2_keeper_stage{1,2}_64px_*`, `b2_keeper_stage3_96px_*` | Not used. Full-game Lamp Keeper is listed under L1/L5, after Nov 28 |
| C3 Red Death | `enemies/round2/red_death_cleanup/C3_red_death_64px_q16.png` | Not used |
| R3-B Revenant | `final/sprites/r3b_revenant_64px_{left,right}.png` | Not used. Full-game "your corpse" is L2, after Nov 28 |
| T6 Stalker (pixel, test pass) | `tests/` / showcase | Replaced by `stalker_bride.png` |

**New conflict:** the current faceless rule (no enemy shows a face) clashes with our skull-faced Keeper, Revenant and lantern-bearer. If those characters come back for the full game, they need a painted ~190×500 facing-you pass, and a faceless (or veiled) call from Duff.

### Later (full game — do not start before the Nov 28 kill test)

From `docs/art_needs.md` L1–L6 and `docs/design/first_person_design.md`: dawn safe room background; lamp keeper 4–5 stages; ferryman; satchel 3×3 + item icons (matches, bread, rope, hook, salt, oil flask, knife, flare gun, iron bell, teeth, eyes, keys); night journal pages; your revenant corpse (your coat, your lit lantern); the Choir; Hollow (breathing door); notes from past selves; free-hand weapon HUD (boathook, knife, flare gun, bell — hook hand already exists); trap props (bait lantern, tripwire, collapsing shelf, salt line); Carrion Row and Cathedral 512 tile sets; wallpaper-that-forms-words; bosses (Drowned Bride, Quay Master, Rat King, Lamp Keeper final, Choir's Conductor); store graphics.

Locked door + key + safe-room lamp were on our old 48 px shopping list; they belong to this later bucket now, not the slice.

### Leftover placeholders still in `assets/art/` (not used by the FP view)

`wall_top.png`, `wall_face_0/1.png`, `floor_0..3.png`, `exit.png`, `hunter.png`, `thrall.png`, `lamp.png` — all 32×32 from `tools/gen_placeholder_art.py`. Fine to ignore unless Claude wires them.
