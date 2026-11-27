Shared handoff: read and update [STATUS.md](../STATUS.md) first and last. This file is the long record.

# Lethemoor handoff log (everything built, newest at the bottom)

Moved word for word out of CLAUDE.md on Nov 21 2026 (lean harness: CLAUDE.md loads into every session; this log is read on demand). Search it for a system before changing it.

> **PIVOT (Nov 7): no longer squad tactics.** Read `docs/design/survival_horror_pivot.md` FIRST.
> It overrides anything below (and the design doc) about roster, classes, intent previews,
> saving, 32 px tiles, 360×640 and the slice definition. One survivor, step-based, fixed map that
> reshuffles each night, revenant = your own corpse, 64 px characters on 48 px tiles at 540×960.
> Next job: do the resize (see the pivot doc's "Size and screen"), then the new slice.
> Grok plan (Drive): https://docs.google.com/document/d/1O5_Zuh04_8OyXE7tYRbBtHHvX15tgi36CqbCpnOs-1A/edit — movement test T1–T6 pending; results land in `grok_art/tests/`,
> score them with a script (pivot doc + plan doc section 4), make GIFs, Duff gives the final yes/no.
> Two open calls for Duff are listed there (skill tree: rec. no; sound spend: rec. small).


## Where things stand
- **This is the active game** (Nov 7, 2026). Chaos Is the Mother of Order is paused in its own repo.
- Design is locked (Stages 1–5) in the Claude Doc:
  https://claude.ai/artifact/6S3KvEG9LYLggwKtko4cs8 (read it with the Claude Docs tools).
  Pillars: **Light is life** (lantern radius = vision, oil = clock), **Every slot matters**
  (RE-style grid inventory), **The dead don't stay gone** (revenants).
- Version 1 scope: Drowned Quay + Carrion Row + short Cathedral finale, ~15 nights,
  3 classes (no Cutthroat), 4 enemies (no Hollow), endings Burn + Dawn.
- **Kill criteria:** vertical slice takes more than 3 weeks (from Nov 7 → Nov 28); testers
  don't choose to replay it; median fun below 6/10 after two rounds of fixes.
- **Done — M0 (Nov 7): scaffold + first lit room.** Fog rules (`scripts/sim/fog.gd`: LIT /
  REMEMBERED / DARK, round radius, Bresenham line of sight, oil burn, flicker) with tests;
  room `rooms/quay_01.txt`; `scenes/room.tscn` draws it with real Godot 2D light + wall shadows,
  a soft fog layer, tap-to-move (4 tiles, placeholder) and the three lantern buttons.
  Renders: `docs/renders/m0_*.png` (`m0_sheet.png` = all four lantern states; `m0_web_chrome.png`
  = the web build running in headless Chrome). CI builds a web zip + debug APK on pushes to `main` and on PRs
  (not plain branch pushes or docs/*.md-only changes, to save Actions minutes), and every push to `main` refreshes the **`dev` release** (Releases → dev → tap the APK):
  https://github.com/duffpowell-commits/lethemoor/releases/tag/dev. Web zip is 9.5 MB
  (engine wasm is most of it; game data is ~30 KB).
- Web gotcha: no system fonts on web, so symbols like ■ show as boxes. Draw them or ship a font.
- **Art is placeholder**, drawn in code by `tools/gen_placeholder_art.py` in the locked palette.
  Real art comes next (see below).
- **Art test (Nov 7, M1 prep):** first 48x48 HD-2D-style sprite, `assets/art/hunter48.png`
  (+ `_n` normal map, `_glow` unshaded flame), drawn in code by `tools/gen_hunter48.py`.
  `scenes/art_test.tscn` lights it with a low warm PointLight2D, optional cold moon, vignette;
  thrall eyes are unshaded red pinpricks. Renders: `docs/renders/m1_art_*.png`
  (`m1_art_closeup.png` is the one to judge; `_moon` vs `_flat` = normal map on/off, subtle).
  Render: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/art_test.tscn -- --capture`.
  Not wired into the room yet. HD-2D idea: sprites stay simple, engine light does the mood.
- **Foxboard inbox (Nov 18):** Duff's phone art editor Foxboard (repo `duffpowell-commits/Foxboard`) has a
  Send to game button that commits art into `grok_art/<date>-foxboard/` (base64 first; `foxboard_decode.yml`
  decodes it to PNG/GIF and pushes as github-actions[bot]). `build.yml` ignores `grok_art/**`, so a drop never
  builds or ships. Expect bot commits on main: `git fetch` before pushing, as always.
- **Art pipeline (Nov 7): Grok designs, Claude converts.** Duff drops green-screen designs in
  `grok_art/` (see its README). `tools/import_sprite.py` keys the green, shrinks, snaps to the
  palette, cleans speckle, outlines, writes sprite + normal map + flame glow. Hand fixes live in
  `tools/fixes/<name>.py`. First import: `bearer48` / `bearer64` from `grok_art/lantern_bearer.jpg`
  (WIP: not yet rendered in the art test scene; 64 reads far better than 48).
  See "Art session notes (Nov 7)" below before touching art.
- **HD-2D 3D test (Nov 11):** Duff asked how far Godot 3D goes (he'd asked about Unreal on
  phone; answer: Unreal can't run on Android, Godot is the tool). `scenes/hd2d_test.tscn` +
  `scripts/hd2d_test_view.gd`: a real 3D alley (existing 32 px tiles on boxes), bearer64 and
  thralls as upright billboard sprites, a 3D OmniLight3D lantern with shadows, depth fog, glow,
  filmic tonemap, vignette, high tilted 44° camera. **Compatibility renderer only** (so no
  volumetric fog, SSAO, DOF: this IS the ceiling for an iPhone-Safari-safe build).
  Renders: `docs/renders/hd2d_sheet.png` (normal / bright / hooded); Bright lights a thrall
  that Normal leaves as eyes only. Render cmd: `xvfb-run -a godot --path . --rendering-driver
  opengl3 res://scenes/hd2d_test.tscn -- --capture`. Lessons: portrait needs a 3-tile alley and
  fov ~44 or the walls fall off-screen; full wet-floor specular reads as a second light (keep
  `metallic_specular` ~0.2); sprites must not cast shadows from a lantern in front of them.
  Weakest part is the placeholder floor tile, not the engine. Not wired into gameplay.
- **DECIDED (Duff, Nov 11): the game is 3D. HD-2D = pixel sprites as billboards in a 3D world,
  3D lights, Compatibility renderer.** The flat 2D room (`room.tscn`, 2D lights) is now the old
  renderer. Rules stay grid-only in `scripts/sim/` (unchanged); only the view gets swapped.
  A parallel session built a Canva-bearer look test on branch `art-canva-test`
  (`scenes/look_test_3d.tscn`, `docs/renders/look_*.png`, Canva sprite Duff prefers over Grok's).
  Merge or harvest that branch before building the 3D room; use the Canva bearer.
- **Done — M1a (Nov 12): 3D room view, now the main scene.** `scenes/room3d.tscn` +
  `scripts/room3d_view.gd` draw `rooms/quay_01.txt` in 3D (1 tile = 1 unit, grid (x,y) at world
  (x,0,y)), Canva bearer billboard (`canva_bearer64`, flips left/right when walking), 3D
  OmniLight3D lantern with shadows + flame bloom + flicker, thralls shown only when LIT (eyes
  too: no info leaks from the dark), tap a tile → camera ray onto the floor → shortest path →
  slide tile by tile with a 2-frame bob, oil burns once per move (same rules as 2D). Fog drives
  surface brightness (`SHADE`: DARK 0, REMEMBERED 0.2, LIT 1); the light is only the look.
  Camera: fov 50, offset (0, 10.5, 8) from the hunter, follows smoothly (~9 tiles across).
  Rules moved to sim: `room.reachable()` + `room.path_in()` (tested; the test was seen failing).
  Renders + a real tap test (taps go through Input in window pixels; prints `TAP PASS/FAIL`):
  `xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3
  --resolution 1080x1920 res://scenes/room3d.tscn -- --capture` → `docs/renders/m1a_*.png`
  (`m1a_sheet.png` = normal / bright / hooded / walked). Gotcha: `unproject_position` gives UI
  coords (540×960); real touches arrive in window pixels → multiply by
  `get_viewport().get_final_transform()` when faking taps.
  **Display changed:** 540×960 base, `stretch/mode=canvas_items`, `aspect=expand` (3D renders
  at full phone res). The old 2D `room.tscn` still assumes 360×640 and now draws in the top-left
  corner: it's the old renderer, kept for reference only. Canva bearer art harvested from branch
  `art-canva-test` (its renderer change to "mobile" and Three.js test were NOT taken: repo rule
  is Compatibility everywhere).
  Weak spots: placeholder 32 px floor/wall textures read as big bricks (art job: 3D-ready tiles,
  wall tops); remembered tiles go flat/textureless at 0.2 (fine for "layout known"); the
  canva_bearer64 face smears at 64 px.
- **Done — M1b (Nov 13): the game exists.** Design review (Claude Doc, Duff approved "go"):
  https://claude.ai/artifact/CV5byZkc6gHebMJgQVm6xE (dread as second clock, Thrall + Stalker,
  throwable oil, lamps as paid checkpoints, web cut "Lethemoor: One Night" for CrazyGames/Poki,
  faceless-character art rule, prompt kit). `scripts/sim/night.gd` runs the turns: one tile per
  turn (or wait), oil per step (start 30), dread +4/turn hooded or dry, -2 lit, +15 when a thrall
  enters your light, 100 = panic (spill 5 oil, back to 60), 50+ = hallucinating (fake flickers in
  the view). Thralls: adjacent on their turn = you die; notice your lantern by LOS within 1/5/8
  tiles (hooded/normal/bright), walk to where they last saw it, then stand there. Walking into an
  unseen thrall = death. Exit tile = dawn. 11 new tests (19 total). View: tap a tile to walk there
  step by step (each tile is a turn, stops on horror/panic/new flicker/death), tap yourself to wait,
  dread bar in the top bar, thralls slide with you, end screen with one-tap retry.
  `quay_01` thrall moved (6,10) → (8,7) so the first turn isn't a death. Renders
  `docs/renders/m1b_*.png` (`m1b_sheet.png` = start / horror / hooded / dead); capture prints
  TAP/STEP/HORROR/DEATH PASS. Not tuned on a phone yet: equal speed means fleeing in the open
  always works; deaths come from dead ends, hooding without moving, and walking blind.
- **DECIDED (Duff, Nov 19): first person, fully.** Lethemoor is now a first-person, turn-based
  grid crawler (Duff: "Switch fully now"). Rules unchanged in `scripts/sim/`; `night.gd` gained
  `facing`, `turn_by(side)` (a 90-degree turn costs a turn), `step_dir(d)` (backing up keeps your
  facing) and per-thrall `last_seen` (where you last saw it; it can be stale). 22 tests.
  **Main scene is `scenes/fp_room.tscn`** (`scripts/fp_view.gd`): eye-height camera, frustum
  shifted so the view centres between the top bar and the 330 px bottom panel, hand lantern
  low right (placeholder box + flame, light inside it), thralls as billboards only when LIT.
  Controls: swipe on the view (up forward, down back, left/right turn; 50 UI px minimum),
  buttons as backup (TURN L / FORWARD / TURN R / WAIT / BACK), keyboard WASD/arrows, space,
  1-2-3. Corner map top right: remembered tiles, lit thralls red, last-seen marks as dim red X.
  Top bar TOP-DOWN / FIRST PERSON buttons switch views (the top-down `room3d.tscn` stays).
  Capture (prints FWD/TURN/SWIPE/HORROR/DEATH PASS, real input events):
  `xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3
  --resolution 1080x1920 res://scenes/fp_room.tscn -- --capture` -> `docs/renders/fp_*.png`
  (`fp_sheet.png` = start / horror / hooded / dead).
  Still to do for first person: sound cues (behind you matters more now), real art to match
  `/mnt/project-files/foxboard-concepts/lethemoor_first_person.png` (wet stone walls/floor,
  peeling wallpaper, veiled faceless front-facing enemies, gloved hand + brass lantern).
  Design gaps listed to Duff Nov 19: loop between nights, progression (rec. no skill tree),
  inventory in first person, meeting your own revenant corpse (rec. design first, with sound),
  enemy roster looks, story delivery, One Night end condition.
- **Done — slice step 1 (Nov 19): One Night goal.** Locked design: `docs/design/first_person_design.md`
  (beats older docs). Map `rooms/one_night.txt` (15x21; new tiles `B` bell, `N` letter, `O` oil
  flask +10). Step on the bell = night won (`rang`), graded by `points()` = oil + 5 per letter
  read, `GRADES` S>=20 / A>=14 / B>=8 / C>=3 / D. Letters read only when you stand on them with
  BRIGHT. **Thralls now shamble (`THRALL_EVERY` = 2, move every other turn):** with turns costing
  a turn, equal speed meant any chaser caught you at the first corner. Bot walking fully lit
  straight to the bell rings it with ~0 oil (D); hooding and letters reach S. 26 tests.
  Capture runs two passes (static `capture_phase`): FWD/TURN/SWIPE/HORROR/BELL, then
  LETTER/DEATH; sheet `docs/renders/fp_onenight_sheet.png`. Known look issue: standing on a
  letter tile puts the page in your face; move pages onto the wall face later.
  Slice order (proposed to Duff Nov 19, no objection yet): bell+grade (done), Stalker (done), boathook + oil slick trap,
  noise + sound pass, letters, art pass. After slice: corpse, satchel/crafting, bosses, ferryman.
- **Done — slice step 2 (Nov 19): the Stalker** (`S` tile; thralls entries now carry `kind`).
  Frozen only while LIT *and* in your view cone (`in_view`, ~50 degrees each side of `facing`);
  otherwise 2 steps a turn toward where she last saw your light, and adjacent + unwatched =
  death. So turning away from her (a turn) is how she gets you; backing up keeps her in view.
  On One Night she guards the letter/flask corridor at (7,6), off the direct bell route.
  Placeholder look: the thrall sprite, pale and taller. Capture pass 2 prints STALKER PASS
  (`fp_stalker.png`). 29 tests.
- **Art (Nov 19): painted look from Duff's mockup** (`grok_art/2026-11-19-mockup/`, cut by hand
  in Python): `assets/art/bride.png` (all enemies for now; thralls tinted dark, Stalker pale and
  taller), `hand_lantern.png` (HUD overlay low right, dims when hooded, breathes with the flame;
  the 3D placeholder lantern is hidden, its light stays), `wall_stone.png` / `wall_paper.png` /
  `floor_wet.png` (linear filtering: these are painted, not pixel art). Lantern colour cooled to
  #ffbe7a and energy lowered so blue stone reads as stone. Letters now hang on an adjacent wall.
  **Duff, Nov 18 10:40 PM: Foxboard is the preferred art tool** (see project memory `foxboard`):
  new art goes to his Foxboard Shared library first; finished art comes back via Send to game.
  Render sheet: `docs/renders/fp_art_sheet.png`.
- **Done — playtest pass (Nov 19, after Duff's first phone run):** the "can't move" bug was
  `act()` reading a quiet step (no events) as a wall bump: camera froze, status said Stone.
  Now only an unspent turn is a bump. You start facing the longest open run (`night.open_way`).
  START_OIL 30 -> 45 (direct route is ~47 moves incl. turns). Title screen, one-time field-note
  cards per system (`scripts/lessons.gd`, tested; seen list + hints toggle in
  `user://lethemoor.cfg`), field guide, pause MENU, **REPORT A BUG** (title + menu: prefilled
  GitHub issue or copy-to-clipboard; adds build from CI's `build.txt`, device, game state).
  HUD restyled (`scripts/ui_style.gd`: Cinzel + IM Fell English, OFL, in `assets/fonts/`;
  brass trim; lantern buttons show their oil cost). Tall phones fixed (no hardcoded 960).
  TOP-DOWN button removed. Buried walls skipped, tiles culled past 10. **CI now plays the
  capture under xvfb** and fails on any FAIL. **Web build for iPhone testers:
  https://duffpowell-commits.github.io/lethemoor/** (gh-pages branch, pushed by CI on main).
  Audit with the remaining risks: `/mnt/project-files/lethemoor/audit_2026-11-19.md`
  (sound is in a separate thread; FPS on a real phone still unmeasured).
- **Done — slice step 3 (Nov 19): boathook + oil-slick trap** (`night.gd`, 12 new tests, 41 total).
  Boathook = `K` tile (One Night: (8,18), on the direct route, so it costs no detour). `hook()`
  costs a turn: first enemy 1-2 tiles straight ahead is shoved back a tile and stunned
  `HOOK_STUN` 2 turns (no move, no grab); each hit bends it, `HOOK_WEAR` 3 hits; a miss costs
  only the turn. `pour()`: turn + `SLICK_OIL` 3, soaks the tile ahead. `spark()`: turn +
  `SPARK_OIL` 1, lights soaked tiles that are lit, in view, within 3; fire runs along touching
  slicks, burns `FIRE_TURNS` 3, lights like NORMAL (so it can freeze the Stalker), blocks you,
  and anything in it burns (`gone`: stays in `thralls` so view indexes hold; use
  `live_positions()` for rules). Spark oil under your feet = death. A full trap is ~6 oil
  (3 + 1 + the lantern's burn on the 2 extra turns). View: HOOK / POUR OIL / SPARK column at the
  left edge above the panel (keys H/P/F), placeholder slick/fire/hook meshes (art via Foxboard),
  field-note cards `hook` + `slick`. Capture pass 3 prints HOOKFIND/SLICK/HOOK PASS
  (`docs/renders/fp_trap_sheet.png`).
- **Done — sound (Nov 19, audit #9):** `scripts/audio.gd` is the autoload `Audio`; the view
  only calls 4 static hooks (`Sound.hook_night/turn/lantern/track`, `const Sound = preload(...)`
  so `--check-only` works without autoloads). Bed (`amb_moor`, stereo loop), heartbeat follows
  dread, flame loop follows the lantern, steps/turn/bump, lantern sounds, oil, letters, bell,
  death, panic, stingers, flicker whispers, UI clicks (every Button, skipped when the press
  already made a game sound). Thralls shuffle + Stalker silk in **3D at their tile, seen or
  not**; bed goes quiet the turn before the Stalker can move (silent bell). 37 clips (~1.3 MB)
  are **original, synthesized by `tools/gen_audio.py`** (numpy + ffmpeg, one seed per clip;
  boathook/slick sounds, `heard_turn` at `heard_by` horrors, `fire_loop` on burning tiles);
  `assets/audio/SOURCES.md` lists every clip and must list any new one (a test checks).
  Reverb is baked in: web plays audio in "sample" mode where bus effects don't run.
  Web unlock: `html/head_include` in the Web preset wraps AudioContext and resumes it on the
  first tap/click/key (verified in Chromium: suspended before tap, running after).
  `LM_AUDIO_LOG=1` prints every sound played (use with the capture run). M mutes (saved).
  Not yet heard on a real phone: levels are a first mix.
- **Done — letters content (Nov 19):** `scripts/letters.gd` holds the written pages (Poe voice,
  <= 80 words each so they fit a phone, tested). Pages come in the order you READ them, not by
  tile, so the story reads I, II, III however the map reshuffles. One Night's three: a dockhand's
  wife (her husband came home drowned: the thralls), Ada the bride's wedding-eve note (hints the
  Stalker rule: "look upon me and I will be still"), and the Watch's sealed order to keep the bell
  silent so the town keeps forgetting, signed in the Captain's own hand (tone C: the rot is
  personal; ringing the bell is defying yourself). Reading one pops a parchment page
  (`_show_page`, PUT IT AWAY); read pages are listed again in the FIELD GUIDE. Capture's LETTER
  check now also needs the page up (`fp_letter.png`). Add pages for new maps to `PAGES`.
  **Each page is its own torn parchment scrap** (Duff: no two notes alike): `assets/art/letters/
  page_<n>.png` drawn by `tools/gen_letter_pages.py` (water-stained / perfumed + folded / scorched
  + broken seal), plus per-page ink colour, tilt and width in `PAGES`. Button sits under the paper.
  Capture renders every page (`fp_letter_2/3.png`, prints PAGES PASS); sheet `fp_letters_sheet.png`.
- **Done — slice step 4 (Nov 19): noise** (`night.gd` `NOISE`, 5 new tests, 49 total). A sound of
  level N is heard by every horror within N tiles of *walking* distance (round corners, not
  through walls); it heads for the loudest one unless it sees your light (light wins). Walking,
  turning and waiting are silent, so plain routes play exactly as before (capture bell run
  unchanged: B, 10 oil, 55 turns). Levels: hook hit 4, hook miss 3, spark 3, pour 2, each burning
  tile 3 per turn (fire lures them into it; with shamblers and 3-turn fire only close ones make
  it). **Sound hook:** each action resets `noises` ([{pos, level, kind}]) and `heard_by`
  (thrall indexes drawn this turn); event `"heard"` when anything turned toward a sound. Field
  note `noise`. Running / rummaging / ringing levels get added when those actions exist.
- **Audit (Nov 19, evening):** rules + capture were clean; fixed in the view layer: Android
  Back/back-gesture quit the game instantly (now `quit_on_go_back=false` + `go_back()` closes
  the top sheet or opens the menu; capture prints BACK PASS), burned horrors stayed on the
  corner map + in two field-note checks, retry left the flame loop silent (`Sound.hook_night()`
  now runs before the first `_refresh`), fire crackle kept playing over the death screen,
  lantern keys worked under the menu/mid-step, frustum assumed a 540-wide screen, bumping fire
  or a visible horror said "Stone". Also fixed: every event of a turn now reaches `_teach` (`turn_events`),
  painted HUD art (hand lantern, title bride, letter paper) uses linear filtering, and on web
  REPORT A BUG queues the open/copy in `window.lmQueue` (head_include) so the NEXT tap runs it
  inside a real gesture (Safari blocks it otherwise; label says "tap anywhere once more").
  PRs #7 (frame rate) and #8 (art pass) were merged with this. **Rotation (Nov 19):** the HUD
  is a 540-wide column (`_column()`) centred by anchors; top/bottom bars, sheets and the end
  screen get a screen-wide backing (`_wing`), brass rules run edge to edge, the vignette covers
  the whole screen. `_fit_camera()` scales the frustum so the column always shows the same view
  (wide screens see more to the sides). `size_changed` -> `_on_resize()`: camera, item buttons,
  hand, title/guide rebuilt, end card, perf readout offset. Capture prints ROTATE PASS (goes
  sideways mid-night, taps MENU, comes back; `fp_sideways.png`). Android stays locked portrait
  (`handheld/orientation=1`); this is for Safari, tablets, desktop. Known: sideways, the
  hand-lantern art's edge shows at the column. (Hints-save-wipes-mute: fixed by the frame-rate work below.)
- **Done — phone frame rate (Nov 19):** `scripts/perf.gd` (child of the fp view). MENU -> SHOW FPS
  (or F3) puts a readout under the top bar: `fps  ms  worst  |  draws  |  quality`, saved in
  `user://lethemoor.cfg` [perf]. MENU -> GRAPHICS cycles AUTO / HIGH / MEDIUM / LOW. AUTO starts
  HIGH and steps down one level after 4 s under 45 fps (never back up in a run). MEDIUM = glow
  off; LOW = also lantern shadows off + 3D at 70% res. Measured in a software-GPU capture run:
  HIGH ~80 ms/frame, MEDIUM ~47, LOW ~39 (glow was the big cost; resolution barely mattered).
  Captures force HIGH (`LM_PERF_QUALITY=MEDIUM|LOW` overrides); `LM_PERF_LOG=1` prints the
  readout every second. Also: floor/wall tiles share ~12 materials (by texture + fog shade)
  instead of one each; `run/max_fps=60` (turn-based, no need for 90/120 Hz); `_save_hints` no
  longer wipes the audio mute (it saved a fresh cfg). Real phone numbers: still from Duff.
- **Move pad restyle (Nov 19, Duff: "more visually appealing"):** bottom buttons are engraved
  plates (`_plate` / `_plate_style`: iron face, brass rim, raised lip that drops and glows amber
  when held) with signs drawn in code (`_glyph` / `_draw_sign`: arrows, curved turn arrows,
  hourglass, book, flames that grow HOODED -> BRIGHT); no symbol fonts on web. Tool buttons use
  the same plate. **Web cache:** CI exports `lethemoor-<sha>.*` and copies the page to
  index.html, so a phone can't mix a new page with an old cached pack. Duff's Nov 19 phone
  screenshot showed a build from before the playtest pass: an old tab never reloaded.
- **Done — slice step 5 (Nov 19): every night dealt fresh + tester verdict.** `room.shuffle(seed)`
  (via `Night.start(text, seed)`): horrors, flasks and letters move up to `SHUFFLE_REACH` 3 steps
  from where the map draws them; no horror within `SAFE_START` 7 of the start, next to another,
  or nearer the start or the bell road than drawn; Stalker never on the road; letters beside a
  wall. Seed 0 = map as drawn (tests + capture). 3 tests. Measured with a walker bot over 8
  opening delays: handmade night 50% deaths, dealt nights 62% (77% of seeds play exactly as
  hard; the rest harder): tune from playtests. Random seed 1-9999 per run; `?night=N` on the
  web link or `LM_NIGHT=N` replays one; night number on the end card, bug reports, verdicts.
  **End card verdict:** fun 1-10, play again yes/no, then TEXT IT TO DUFF (`sms:?&body=`, Messages
  opens with the words; on web via `window.lmQueue` -> `location.href`) or COPY; a copy is kept in
  `user://lethemoor.cfg` [verdicts]. Capture prints VERDICT PASS (`fp_verdict.png`). Oil slick =
  glossy ragged puddle (generated texture), fire = additive flame particles + guttering light.
- **Done — after the IGN-style review (Nov 19): more oil, bigger map, swipe-first.** START_OIL 45 -> 60;
  `GRADES` +15 (S 35 / A 29 / B 23 / C 18) so grades mean the same. `one_night.txt` is now 27x21: the old
  15 columns kept every coordinate (captures, tests, art views still hit the same tiles) plus an east wing
  joined at (14,4) and (14,19), a second road north, 4 more flasks (9 total), 2 more thralls (6 + Stalker).
  Thrall indexes DO shift with map edits (thralls[2] is now (5,11)): the capture picks by kind or sets positions by hand.
  **Swipes are the controls:** the bottom panel is `SLIM_H` 132 (status + HOODED/NORMAL/BRIGHT + WAIT);
  the view gets ~200 px back. MENU -> MOVE BUTTONS: ON brings back the old pad (`PAD_H` 330), saved in
  `user://lethemoor.cfg` [controls] pad. `_bh()` is the panel height everywhere; `_layout_bottom()` lays
  it out. The capture now moves by real swipes (`_go(kind)`), prints PAD PASS (`fp_pad.png`); bell run:
  B, 23 oil, 57 turns. Field guide lives in MENU. Sheet: `docs/renders/fp_swipe_sheet.png`.
- **Done — scarier thralls (Nov 19, Duff: "add all of those ideas").** `night.gd` (8 new tests, 61):
  **crouch + lunge**: a thrall 2 walking tiles off that sees your light crouches a turn (event `crouch`,
  the tell), then if you're still 2 off it lunges a tile on any turn (`lunge`), then rests
  `LUNGE_COOLDOWN` 3. **Rousing**: held under BRIGHT light `ROUSE_LOOK` 2 turns running, it stops
  shambling (`roused`) till it loses you (NORMAL can't rouse: that made a death spiral). **Silence**:
  `silent(th)` within `QUIET_NEAR` 3 tiles, no shuffle sound. **Corpses** (`C` tile, `room.corpses`,
  appended LAST to `thralls` with `lying`): no flicker, no horror, no hearing; rise (`rose`) when you're
  within `CORPSE_WAKE` 2 and it's outside your view cone, or when you walk into one in the dark (you don't
  move, you live); rising costs it `RISE_TURNS` 1. Dealt only onto dead ends (`room.dead_end`), never
  across a corridor. One Night: (17,12) at the end of a flask passage, (17,19) in a south alcove.
  **Wet prints**: `prints` tile -> turns (`PRINT_TURNS` 10) where a thrall stepped from; the view shows
  lit ones as glossy decals that fade. View: thralls hunched (squat/wide) and twitch, corpses lie flat,
  grey body on the corner map, **kill shot** (`_kill_shot`: it fills the screen, red flash, shake,
  `fp_killshot.png`), new status lines + field notes `lunge` / `rose`, sounds. `GRADE_LINE` fixed to the
  new bands. **Balance bot** `tools/balance_bot.gd` (`-- 300 [night_script]`, `BOT_FIRST=0` for the
  handmade night, `BOT_TRACE=1`): careful-but-crude policy. Corpses in corridors took it to 0% wins;
  the (1,16) thrall made a pincer with (3,12) on the main road, so it moved to (5,11): 54% wins over
  300 dealt nights, avg 4 oil at the bell (it wanders; a person should do better). Capture bot keeps
  2 tiles clear and evades (`_evade`); CORPSE PASS (`fp_art_corpse.png`).
- **Done — art pass (Nov 19, PRs #10-#19):** painted Foxboard/Forge art in every slot: faceless thralls in
  three looks (`THRALL_LOOKS`: dock worker, net-mender, dock woman, by thrall order), Stalker bride, bell,
  flask, boathook, lamppost, oil slick + burning pool, fire flipbook (`fire_sheet.png`), night sky panorama
  (`sky_night.png`, `fog_sky_affect` 0.35), nailed letters, hand lantern per light state (`HAND_ART`), title
  key art, app icon (project + Android launcher/adaptive). Capture pass 4 shoots `fp_art_*.png`. Wall tops
  skipped: eye height 0.82 vs walls 2.4, never seen. Not yet checked by Duff on his phone.
- **Audit after the thrall merge (Nov 19, PR #21):** CI now requires the capture's last line `ART PASS`
  (it used to stay green if passes 3-4 crashed or hung) and fails on load/node errors; mipmaps on every
  3D-world texture; at most 2 fire lights; kill shot ignores burned/lying horrors. The capture's bell
  walk clears the thralls after the HORROR shot: it checks input, `tools/balance_bot.gd` checks balance.
  Not yet seen on a phone: lunge timing, corpse readability, kill shot, swipe-only controls.
- **In-app updates (Nov 19, Duff: "a way to update an installed apk"):** autoload `Updater`
  (`scripts/updater.gd`, Android only). On launch / resume it reads `version.json` from the `dev`
  release; if its `code` beats `res://build_code.txt` it offers UPDATE NOW, downloads the APK to
  `user://update.apk` and opens it with `OS.shell_open` (Godot's built-in FileProvider). Android
  always asks to confirm; first time also "allow from this source". CI stamps `version/code` =
  run number, checks the APK has REQUEST_INSTALL_PACKAGES + INTERNET + the right versionCode, and
  uploads version.json after the APK. **Signing key must never change:** the key is committed encrypted
  (`signing/lethemoor.keystore.enc`, alias androiddebugkey, pass android, cert SHA-256 DE:71:98:0E...)
  and CI unlocks it with the `LM_KEYSTORE_PASS` repo secret (Duff has the passphrase; the session
  proxy can't write Actions secrets). Without it a throwaway key is used and that APK can't update. Old APKs (random key per build) need one last uninstall.
  Off-phone check: `LM_UPDATER_TEST=1 LM_UPDATER_CODE=40 LM_UPDATER_URL=<json> LM_UPDATER_SHOT=<png>`
  (`docs/renders/updater_offer.png`).
- **Scarier update (Nov 19, Duff: "scarier, more fierce, more blood, weapon in the left hand, minimap looks terrible"):**
  `THRALL_LOOKS` now leads with `thrall_clawed` + `thrall_wired` (Forge, bloody claws, sack hoods; FLUX painted faces, so
  faces are darkened to a void by hand: faceless rule) and `thrall_hooded`; `thrall_lunge` shows the turn one lunges and in
  the kill shot. Blood: `fx_blood_screen.png` spatter on lunge (`blood_screen`, by `lunge_hit`) and at the kill, `blood_pool.png`
  under lying corpses (`pool_nodes`, LIT only), prints tinted blood red (`tools/gen_blood.py`). Left hand: `hand_hook.png`
  (`hook_art`) shows while `hook_wear > 0`, jabs on hook events. Corner map: round parchment chart (`map_parchment.png`,
  `tools/gen_map_parchment.py`, drawn as a TextureRect under the map: drawing it with draw_texture_rect lost its alpha in
  the capture), inked walls + hatching, brass compass ring, turns with you (`map_rot`); MENU -> MAP: NORTH UP, saved in
  [controls] map_north_up.
- **Nightmare thrall (Nov 19, Duff: "make that sprite the most horrifying thing you can"):** `thrall_nightmare` (first in
  `THRALL_LOOKS`, 2.2 tall via meta `tall`: sack head stitched with fishhooks, ribs torn open, claws) and `thrall_lunge_nightmare`
  (now `THRALL_LUNGE`: sack mouth split open, ribs like a jaw; lunge + kill shot). Forge's auto magenta key ate dark bodies, so
  these were rendered WITHOUT `key` and cut out with rembg `isnet-general-use` (pip install "rembg[cpu]"): clean on painted backdrops.
- **Fluid moves (Nov 20, Duff: "make the movement more fluid"):** a swipe fires as soon as the finger passes
  `SWIPE_MIN` (drag events, not lift); a move made mid-glide is `queued` and runs the moment the step lands;
  keep the finger down after a forward/back swipe and you keep walking (`hold_kind`), one turn per tile. Any
  `STOP_EVENTS` event, a new flicker, a bump or a card drops the queue and the walk. Chained steps keep their
  speed (`glide()` cubic Hermite, v0/v1) instead of stopping on every tile; head dips + sways per foot, turns
  lean slightly (camera roll), hand lantern bobs with the step (`step_k`). Rules unchanged: still one turn per
  move. Capture prints QUEUE / HOLD PASS (seen failing with the features off).
- **Sound + about-face (Nov 20, Duff picked "1 and 4"):** footsteps play `STEP_SYNC` 0.09 s into the glide (boot lands
  on the head dip). **Breath at your neck:** `Audio.behind(game)` = live horrors within `BEHIND_NEAR` 2 walking tiles and
  outside your view cone; `breath_behind` plays at its tile every turn it stays there (Duff: "keep breaths playing"), +1.5 dB and a little lower each turn it lingers, up to 3 (`was_behind` counts turns). Shuffles still go
  silent within 3, so it's silence, then a breath. **About-face:** two-finger swipe down (or X) = `act("about")`, two
  `turn_by(1)` in one 0.32 s spin (`ABOUT_TIME`), second half skipped on a stop event; `touches` tracks fingers, only
  finger 0 steers. Guide text updated. 65 tests; capture prints ABOUT / BREATH PASS (seen failing with them off).
- **First minute (Nov 20):** balance bot now prints deaths by turn 20 (0% over 300 nights) and when the first
  horror is seen (median turn 16, always by 20), so the opening is a readability job, not balance. Goal card cut
  to the controls that matter (<260 chars, tested); spin round + MOVE BUTTONS moved to a new `behind` card that
  shows the first time a horror is within 2 walking tiles outside your view (same rule as the breath). POUR OIL
  is hidden until a horror has been lit, the hook found or a slick poured (`tools_shown`).
- **Art needs: `docs/art_needs.md`** (prioritized P0/P1/P2 for the slice, then the full game, with
  sizes and why). Shared copy for Duff's art team: Claude Doc https://claude.ai/artifact/1UXeTCHVCWkMg9qgRMq6bj.
  P0 = app icon (APK + home screen still show the Godot robot), sky over the alleys, wall tops.
  Tick items off in the md as art lands.
- **Slice status (Nov 19):** all slice features built. Left before expanding: one playtest round
  (Duff on Android, iPhone testers on the web build) collecting verdicts, FPS and sound notes; tune oil,
  thrall speed, Stalker spot from it; second round. Kill test by Nov 28: median fun 6+, testers
  replay. Don't start the full-game systems (safe room, satchel, corpse, Choir) before it passes.
- Older plan: **M1 = new slice** (pivot doc #12): 2–3 rooms, locked door + key, one Stalker, one safe
  room, real sound. Also: real tile art for 3D, and one-step-per-tap vs the 4-tile placeholder
  move (pivot says step-based; decide with Duff on the phone build).


## Eyes: Claude plays the running game (Nov 24)
- Duff: "Add eyes to lethemoor". Same tool as godot-game-starter (PRs #22-#24): godot-mcp-runtime
  4.0.1 (MIT, pinned in `tools/eyes/package-lock.json`) driven by `tools/eyes/eyes.mjs` under xvfb.
  Steps: list UI, click by text, keys, waits, screenshots, live GDScript. `docs/EYES.md`.
- Nothing ships: `tools/` and `docs/` are outside the export. The runtime adds a temporary autoload
  while the game runs and removes it on exit (scratch in `.mcp/`, git-ignored).
- Smoke: BEGIN THE NIGHT, up to three Field Notes dismissed (fresh save only), WAIT, step (`Up`).
  Oil 60 -> 59 -> 58 confirms turns advance. Swipes aren't a step type; arrow keys work.
- Gotcha it found: `fp_view.gd:1502` (`_build_hud`) sets a size on a node with unequal anchors, so
  Godot warns "size will be overridden" every launch. Harmless today; warnings are listed, not fatal.

## Art session notes (Nov 7, end of session; Duff is about to change the game "a bit")
Duff's change happened: see the pivot doc. Size is now decided (64 px characters, 48 px tiles).
- **Target look:** Final Fantasy Resonance (Square Enix, HD-2D, out Oct 22 2026). HD-2D =
  simple pixel sprites + modern engine light (glow, depth, fog, vignette). So: keep sprites
  clean, put the mood in Godot lights. Duff wants it "overall more creepy".
- **Roles (Duff's call):** Grok designs characters, Claude is "the head": converts, cleans,
  lights, integrates, and pushes back on quality. Grok's design >> code-drawn `hunter48`
  (Duff and Claude agree). Pasteable image prompts stay in the Drive plan, not in this repo.
- **Importer lessons** (`tools/import_sprite.py`): BOX shrink + palette snap + speckle and 3x3
  majority cleanup + ink outline works. A min-filter "keep the darks" blend at 0.35 made it
  muddy; it's at 0.12 now. Bright amber is only allowed in the lower-right lantern zone
  (else the skull got an amber dot). Faces die in the shrink: hand-fix per sprite in
  `tools/fixes/`. Grok's own 48px downscale is noisy and off-palette; don't use it.
- **`tools/fixes/bearer64.py` was applied but never visually checked** (sockets, jaw, teeth on
  the skull). Look at a zoomed `assets/art/bearer64.png` first and adjust.
- **Source** `grok_art/lantern_bearer.jpg` is a phone screenshot; crop `50,559,1030,1539`.
  The original Grok file would be sharper: ask Duff for it.
- **Next art step:** render `bearer64` in `scenes/art_test.tscn`. `art_test_view.gd` hardcodes
  `hunter48` and `FLAME_OFFSET (12.5, 11.5)`; make the sprite name a parameter and compute the
  flame offset from the `_glow` image's centroid. Then capture `docs/renders/m1_bearer_*.png`.
- **Size decided (Nov 7):** 64 px character frame on 48 px tiles, 540×960 base.
- **Paid/blocked options:** SpriteCook needs desktop setup (not possible, phone-only).
  Creative Claw had 4 credits, ~16 per image. Default to the free Grok → importer path.

## Decisions (Duff, Nov 7)
- Visuals first: every milestone ships something Duff can see, rendered to `docs/renders/`.
- Test channels: **web build** for iPhone testers (they open a link in
  Safari, no install). **APK** for Duff's Android. iOS native is later (needs a Mac build
  machine + $99/yr Apple account); avoid Android-only plugins so a port stays a build job.
- Hosting: code here (public GitHub). Builds = CI artifacts. Web playtests on an **itch.io
  draft page** (Duff still has to make the itch account; then add a `BUTLER_API_KEY` repo
  secret and an upload step). Not Netlify: free credits ran out on Chaos.
- Store later: Google Play, $25. New personal accounts need **12 testers opted in for 14 days**
  of closed testing before production. Line testers up early.
- Release signing key (when we get there) must be backed up outside the sandbox. Lose it and
  the app can't be updated.

## Open questions for Duff
- Real art source: SpriteCook is NOT connectable from phone (needs a desktop setup; not in the
  connector directory). Creative Claw costs ~16 credits/image (Duff had 4 on Nov 7). Free paths:
  code-drawn sprites (as hunter48) or Duff generates in Grok, we downscale + palette-snap.
- Skill tree or not, and sound spend: see the pivot doc's Open questions.
- Is the M0 lantern look (warm pool, black beyond, soft edge) the right direction?


- **Public repo guardrails (Nov 21):** rules at the top of `CLAUDE.md`. gitleaks runs on pull requests and pushes to main. Tester names and the committed image-prompt template are off the branch tip. Older commits and the `glaze-art` and `grok/art-generation-guide` branches still have prompt and handoff text; removing that from history needs Duff's approval. No passphrase was found in the tree.

## Old Layout / Commands / Tech / House rules (CLAUDE.md before Nov 21, kept verbatim)

### Layout
- `scripts/sim/` pure rules, no nodes: `fog.gd`, `room.gd`. Tests drive these headless.
- `scripts/room_view.gd` the playable room (draws rules, takes taps, HUD built in code).
- `rooms/*.txt` handmade rooms: `#` wall, `.` floor, `H` hunter, `T` thrall, `L` lamp, `E` exit.
  Exported via the presets' include filter (`rooms/*.txt`); new data folders need adding there.
- `grok_art/` design sources from Duff (never ships). `tools/fixes/` per-sprite hand fixes.
- `assets/art/` 32×32 tiles. `tools/` scripts that never ship. `docs/` never ships.

### Commands
- Godot in the cloud sandbox: download the 4.5-stable Linux zip from GitHub releases with
  curl, move it to `/usr/local/bin/godot`. Fresh clone: `godot --headless --path . --import`.
- Tests (before every push): `godot --headless --path . --script tests/run_tests.gd`
- Parse check one script: `godot --headless --path . --check-only --script <file>` (a parse
  error makes a scene hang instead of failing).
- Renders: `xvfb-run -a godot --path . --rendering-driver opengl3 -- --capture`
  → `docs/renders/m0_*.png` (720×1280, 2× the 360×640 base).
- Placeholder art: `python3 tools/gen_placeholder_art.py`
- CI: `.github/workflows/build.yml` (tests, then web + debug APK artifacts + `dev` release).
  `gh` GraphQL is blocked in Claude sessions: use `gh run ...` or `gh api repos/...` (REST). Check with
  `gh run list -L 3` before calling a milestone done. Exports run in CI only (templates are big).

### Tech rules
- Renderer is **Compatibility** everywhere: the only one that runs in iPhone Safari.
- UI base 540×960 portrait, canvas_items stretch (3D at full phone res), nearest filtering on
  sprites/tiles. 3D room: top bar 72 px, thumb zone (status + lantern buttons) bottom 216 px.
- Fog is gameplay truth (sim grid); lights are the look. Never let the look decide rules.
- Game logic stays grid-only so a later isometric renderer is a renderer swap, not a rewrite.

### House rules
- **One Claude session per repo at a time.** `git fetch` before starting and before pushing.
- Duff is phone-only (Godot Android editor). No desktop-only tools. GDScript only.
- Push after every chunk of work; merge to `main` at the end of every milestone.
- Up to three milestones per session; update this handoff and merge after EACH one.
- Save renders to `docs/renders/`, don't paste lots of images into chat.
- Visual decisions need real engine renders shown to Duff, not sketches.
- Every feature must serve a pillar or it gets cut.

## Publisher branding (Nov 23)

The startup scene displays the approved 3 Eyed Fox Studios primary weathered logo from the studio
Drive folder while the existing first-person scene loads. Skip splash, Enter, Escape, or Android
Back dismisses the card. The Field Guide lists the publisher under Credits.

## One Night 3D harbor environment (Nov 23)

- The live first-person scene builds the harbor kit in `scripts/harbor_geometry.gd`. It adapts the masonry, coping, and harbor-fixture studies from PR #36 to the existing 1-unit grid. The active view retains the painted stone and sky assets and existing lantern rig.
- Wall segments place relief on the faces that border open cells and share meshes by exposed sides and ruin profile. Deck boards, slabs, bell steps, wet stone, and lintels dress traversable tiles. The street lamp and bell use opaque 3D meshes. The grid still resolves movement and contact. Fog drives visibility.
- The four-pass capture now checks that the starting dock and wall use geometry, the bell and lamp are modeled, and the bell is gated by fog. See `docs/renders/harbor_entry.png`, `harbor_bell.png`, and `harbor_lamp.png`.

## First modeled Thrall (Nov 23)

The approved drowned dockworker is the nightmare Thrall variant in the first-person view. Foxboard's TripoSR worker produced the draft. Blender restored the face and rebuilt the rope, baked the albedo, and exported the textured GLB with the texture embedded. The pose uses the existing crouch and lunge states to lower and lean the model. Standing and attack poses use a rigid mesh. Other standing variants, the Stalker, corpse poses, and the death-card artwork retain their current artwork.

The art pass checks that the modeled variant is visible when lit, hides its standing sprite, drops for the crouch tell, and leans on a lunge. See `docs/renders/fp_art_thrall_3d.png`.

### Stalker model preview (Nov 23)

- The veiled bride uses a 6,193-triangle, opaque textured GLB derived from the existing bride reference and cleaned in Blender. The first-person view places it on the existing Stalker holder, which shares the simulation fog gate and turn interpolation. The model keeps its facing until she moves to another tile. The death card still uses its painted close-up.
- Owner review is pending. See `docs/renders/fp_stalker_3d.png` for the lantern encounter and `docs/renders/stalker_3d_turnaround.jpg` for three model views. This preview uses rigid movement.

## Fully 3D horrors and hands (Nov 25, PR #45)

Duff (Nov 24): "start making what we need to pull that game fully three-dimensional and terrifying". Budget he
picked: ~260 Meshy credits ("Monsters + hands"). Spent 250 (705 -> 455).

- Heights (Nov 24 evening, Duff: "Why are the monsters so big?"): `RIGS` crown heights are thralls
  0.88-1.0 tiles, bride 1.1, against eye 0.82 (were 1.8-2.15, carried over from the painted cards).
- `scripts/rig_horror.gd`: a horror on Meshy's 24-bone humanoid rig. The view sets a state from the rules
  (idle, walk, crouch, lunge, dead, rise); missing clips fall back. `fp_view.gd` `RIGS` maps a look to
  `assets/models/rig_<name>.glb` (+ height, + optional yaw fix; the bride needs none, the old quarter turn left her side-on). `_drive_rig` picks the
  state each frame; `_pose` lays corpses in the dead clip's last frame and plays "rise" when they get up.
  The bride breathes at quarter speed and squares up to you only when she has moved.
- Clips per thrall (Meshy action ids): idle 0, walk 113 Mummy Stagger, crouch (the tell) 386 Zombie Scream,
  lunge 4 Attack, dead 8 Dead, rise 3 Arise. Bride: idle 0, lunge 4, walk = the rig's free walk.
- Clip GLBs are not in git (each carries a mesh copy): project files `lethemoor-3d/meshy_source/`. Copy them to
  `tools/clips_src/` as `rig_<who>_<clip>.glb`, then
  `godot --headless --path . --script tools/bake_clips.gd -- rig_nightmare rig_hooded rig_dockwoman rig_bride`.
- Meshy ships 2K/4K textures: run `python3 tools/shrink_glb.py <meshy.glb> assets/models/<name>.glb` (1K JPEG,
  ~0.8 MB a body). Bodies are ~9k triangles (smart topology).
- Viewmodel (`_build_viewmodel`, `_sway_viewmodel`): `fp_glove.glb` right arm holding `fp_lantern.glb` by the bail,
  the OmniLight and an additive glow quad inside the globe, lantern emission follows the flame (HOODED goes dark),
  a damped pendulum swing kicked by steps. Left arm + `fp_boathook.glb` (short gaff head + a code pole) shows
  while `hook_wear > 0`. The painted hand column is hidden, kept as a fallback.
- Removed: `thrall.glb` (had a face, broke the faceless rule) and the rigid `stalker.glb`. Painted looks
  clawed/wired/dock/net-mender left `THRALL_LOOKS`.
- Lantern gutters at <= 12 oil (`LOW_OIL_SPUTTER`, light only).
- Capture: THRALL MODEL checks the scream/attack states, CORPSE checks the dead clip, VIEWMODEL checks the hands.
- Meshy tasks: models nightmare 01a21023-edea, hooded 01a21023-fd20, dockwoman 01a21024-09b2, bride 01a21024-171d;
  rigs 01a21025-dfdd / -eecc / 01a21026-0339 / -10c9; lantern refine 01a21026-1f8c, glove 01a21026-296e,
  boathook 01a21027-c3cf. Login: `meshy auth login --device` (Duff approves the code on his phone).
- Not checked yet: 60 fps on Duff's phone with four skinned bodies on screen. Perf LOW could drop rigs to sprites.

## More scary (Nov 25, Duff: "Lets get more scary")

All look only, no rule changes, no Meshy credits.
- Heads (`scripts/head_look.gd`, a SkeletonModifier3D on each rig's skeleton): the Head bone turns to the camera
  on top of the clip, in skeleton space from the body's +Z, so it doesn't care how the bone is oriented. It holds,
  then snaps (0.35-1.1 s) instead of gliding. Thralls 75 degrees either way; the bride 112, slower to let go
  (her veil isn't weighted to the head, so it barely shows on her). A standing body follows its head round at
  `BODY_TURN`; crouch and lunge face you at once. The bride's body turns only when her tile changes.
- 3D kill (`_kill_shot_3d`): if the killer has a rig, its body comes off its tile to `KILL_REACH` in front of your
  eyes, replays the attack, head locked on you, while the camera tips back (`KILL_LOOK_UP`, `KILL_ROLL`) and drops
  (`KILL_DROP`): you look up at it in your own lantern light. Red flash + blood screen as before. No rig: the
  painted 2D kill still runs. `kill_rig` stops the rules driving that body meanwhile.
- The figure that isn't there (`_haunt`, `_show_phantom`): at dread >= 50 (`hallucinating()`, which already lets
  the view lie), every 7-16 s a still hooded body, unlit and grey-blue (`PHANTOM_TINT`, fog off), stands on the
  first unlit tile 3-6 ahead down your corridor for 0.9 s with a low whisper, head turning to you. Not on the map.
- `Audio.hook_sfx(name, db, pitch)`: one-shot from outside the autoload.
- Capture: KILL3D, HEAD LOOK, PHANTOM (+ renders `fp_killshot`, `fp_art_bride_face`, `fp_art_bride_head`,
  `fp_art_phantom`). `--art-only` after `--capture` jumps straight to the art pass for quick looks.

## All four: toll, early thrall, hunting bride, oil (Nov 25)

Duff asked Claude to play the build and rank fixes. Claude's night (seed 4242): 66 turns, no horror seen, bell never
found, oil out. The bot on main: 54% win, about 4 oil left at the bell, and the bride killed 4 of 300. Duff picked "All four".
- Toll (`night.gd` `BELL_EVERY` 10): on turn 1 and every 10 turns the bell rings by itself. The turn's events
  get "toll" and `bell_heard` is set. `audio.gd` `_toll` plays the bell from where it hangs, as a long-range
  AudioStreamPlayer3D, panned. The map draws the bell once heard: where it hangs, or on the rim with a pointer.
  Capture: BELL MAP, render `fp_art_bell_map`.
- Early thrall (`room.gd` `_early_thrall`, `EARLY` 9-12): on dealt nights only (seed 0 is unchanged), the thrall
  dealt nearest the start moves to a tile 9-12 steps in, 2-3 tiles off the road to the bell, clear of other horrors.
  At 1-2 tiles off the road it killed too often in the bot runs.
- Bride (`night.gd`): from `STALKER_WAKES` (30) she hunts blind, a step every `STALKER_HUNT_EVERY` (3) turns,
  until she is `STALKER_SHADOW` (6) walking tiles from you. Then she waits for your light, as before. She now
  takes 1 step a turn (`STALKER_STEPS`, was 2); at 2 she killed in about 3 nights of 4 by closing from beyond
  NORMAL's 2-tile light. Held lit and looked at for `STALKER_RECOIL` (3) turns running, she recoils (`_recoil`):
  she is gone to the nearest unlit tile at least SHADOW + 1 from you. The view snaps her there, with no slide.
  `Audio.stalker_free` (the silence) is now also on while she hunts within SHADOW + 2.
- Oil: `FLASK_OIL` 12 (was 10).
- Balance bot (now looks at the bride when it hears her or she's lit within 4, and stares her down): 50% win,
  24 oil left at the bell, deaths 101 thrall, 31 walked into one, 19 bride. Median death turn 84.
- Field notes: the goal card says the bell tolls; the bride card says to hold the light on her and that silence
  means she's close; the flask card says +12; the map card mentions the bell.


## New walls every night + unlocks (Nov 25, Duff: "Lets do 2 and 4 now")
From the mock review: one map with fixed walls got learned by night three, and nothing was earned.
- **New walls** (`scripts/sim/ward.gd`, pure): `Night.start_dealt(text, seed, deeper)` carves a fresh
  27x21 ward from the seed when seed > 0. Depth-first maze on odd tiles, `LOOPS` 12% of inner walls
  knocked through, `HALLS` 3 open 3x3 rooms. Start on the bottom corridor; the bell a walk of the
  template's +`BELL_EXTRA` (6) +-`BELL_SLACK` (3), at a dead end if one fits. Everything else in
  `one_night.txt` is placed at the same fraction of the road as the template has it, with the
  dealer's rules (horrors >= `HORROR_NEAR` 13 from the start, apart, as near the road as the template,
  bride never on the road, bodies in dead ends, letters on walls, lamp on the road, hook beside it).
  Then `room.shuffle` deals on top as before. Same seed = same ward, so reported nights replay.
  Night 0 (capture, most tests) keeps the handmade walls. `Night.start` is unchanged.
- **Early thrall** (room.gd `_early_thrall`) now waits down a side passage: a walk of `EARLY_OFF` 3+
  from the road and in a straight line from it within `EARLY_SIGHT` 5, 10-15 steps in. Walk 2 killed
  the bot by turn 20 in 13% of nights; Manhattan 2-3 (the old rule) did 8% on wards.
- **Bot** (`BOT_WALLS=0` = old walls, `BOT_DEEP=1` = Deeper): wards 54% win, 29.1 oil at the bell,
  60 turns, 2% dead by turn 20. Deeper 48% win but 12.4 oil at the bell (grades are the hard part).
- **Record** (`scripts/sim/record.gd`, saved in `user://lethemoor.cfg` [record]): nights, bells rung,
  best grade per mode, unlocks. First bell -> DEEPER NIGHT (title toggle beside HINTS; reloads to
  deal a new night): bride wakes turn 18 (not 30), flasks +8 (not 12), start oil 50 (not 60).
  Grade B / A / S -> keepsakes I / II / III, short letters listed under KEEPSAKES in the Field Guide
  (locked ones say what they need). The end card names anything unlocked that night. The title shows
  "BELLS RUNG n · BEST g". Capture never reads or writes the record.


## Real recorded sound (Nov 25, Duff: "Free library, I pick")
- `tools/real_audio.py` swaps the clips where a recording matters most for CC0 or public-domain recordings. The sources are listed in `assets/audio/SOURCES.md`, so the game needs no credits.
  - bell: a Rocamadour church peal. The toll is the same file played at pitch 0.8.
  - amb_moor: a harbour at night (Ploumanac'h) with drips.
  - footsteps: four stone takes.
  - fire_loop.
  - letter and letter_dim: paper.
  - shuffle_0 and shuffle_2: real moans laid over the synthesized drag. shuffle_1 stays a bare drag.
- What stays synthesized: the stings, whisper, breath, death, heartbeat, lantern, oil, hook and UI clips.
- Loudness: each clip matches the RMS of the clip it replaced. The targets are fixed in `LOUD`, so a re-run doesn't creep louder. A soft knee at 0.8 keeps Vorbis transients under 0 dB. The bed is band-limited to 45 Hz-9 kHz because a mic thump clipped.
- Sources download once to `~/.cache/lethemoor_real_audio`. The footsteps come as a .7z, which needs `pip install py7zr`.
- Order matters: `gen_audio.py` first, then `real_audio.py`. gen_audio rewrites every clip.
- Reachable from the cloud sandbox: OpenGameArt and archive.org. Blocked here: freesound, pixabay, kenney.nl and zapsplat. The Wikimedia API rate-limits the shared proxy.


## Review fix 1: horrors you actually meet (Nov 25, Duff: "fix them all step by step")
- In Claude's play of build 160, night 2026 had no horror in the light for 54 turns. The cause: ward.gd measured how far a horror stands from the road as the crow flies (Manhattan). In a maze, two tiles off the road can be fifteen steps of walking, so you never met them.
- Now `_road_walk` gives the real walking distance from the road. Horrors keep the template's walk from the road, at least `ROAD_MIN` 3. Bodies lie in dead ends 1 to `ROAD_MAX`+3 walk off the road.
- Placement had been silently failing: 40% of nights fell back to the handmade walls, and that is why the old bot said 54%. It now falls back on 1 night in 200 (that night keeps the handmade walls and all six thralls).
- With every horror where you meet it, corridors leave no way round. Six thralls won 23%, so a ward deals `SPARE_THRALLS` 3 fewer: the ones farthest a walk off the template's road go (`_keep_nearest`, a rule, not row order).
- Bot result (now prints "horrors met per night" and how often none at all; counted by thrall index, since a Dictionary key hashes by content and a moving thrall would count twice):
  - 40% of nights won, 25 oil left at the bell;
  - nights with no horror in your light: 23% on main, now 7%;
  - 1.7 horrors met per night (main 1.3; the bot steers clear, a player meets more);
  - 3% dead by turn 20.
- Dealt nights on the handmade walls (`BOT_WALLS=0`) now win 100% for the bot. The game no longer plays them (only night 0), so they don't matter.
- `tools/eyes/pilot.gd` is the bot's policy one move at a time, so Eyes can play a whole night through the real view: `v.act(load('res://tools/eyes/pilot.gd').choose(v.game))`.

## Review fix 2: a crouch always ends in a lunge (Nov 25, Duff: "fix them all step by step")
- In Claude's play of build 160 (night 77) a thrall two tiles off crouched, Claude stepped back, the crouch was spent, Claude stepped in, it crouched again... a standoff while dread climbed and panic spilled oil, until it killed him.
- Now a crouch always ends in a move (`night.gd`, the lunge): still two off, it lands beside you; backed off a tile, it still lurches a tile after you and takes its `LUNGE_COOLDOWN` rest. No more stepping in and out to freeze it. Test: `test_a_crouch_always_ends_in_a_lunge`.
- That made the dealer's early thrall deadlier (bot dead by turn 20: 3% to 8%: with no hook yet, backing into the start's dead end was the only move). It now waits 12-17 steps in (`room.gd` `EARLY`, was 10-15): 5%.
- Bot, 200 nights: 39% won, 25.5 oil at the bell, 5% dead by turn 20, no horror met on 7% of nights. The IT LUNGED field note says backing off doesn't stop it.

## Review fix 3: no plank floating over the dark (Nov 25)
- In Claude's play of build 160 a stone beam hung in the sky at the end of a corridor. It was a lintel (`harbor.lintel`, on every seventh one-wide corridor tile) over a tile you had never seen: its material was black, but `metallic_specular` 0.25 still caught the teal sky, so it showed while the walls under it didn't.
- Lintels now hide while their tile is DARK, like the lamps, and any DARK material has no specular (unseen stone is black). Before/after: `docs/renders/fp_lintel_before.png`, `docs/renders/fp_lintel_after.png`.

## Review fix 4: landmarks (Nov 25)
- In Claude's play of build 160 every corner of a new-walls ward looked the same, so you steered only by the map.
- **Bell tower** (`Harbor.bell_tower()`, placed by `fp_view.gd` on the wall tile behind the bell, or over the bell if no wall touches it): a stone shaft rising from 2.1, inside even a ruined wall's top (the wall keeps its own stone and fog below) with an open belfry and a dim lamp, about 9.6 tall against walls of 2.4. It has no fog and no view-range cut, so it stands black against the clouds from anywhere, and you can walk toward it. It's a look only: the map already points to the bell from the first toll. Capture checks it (`TOWER PASS`).
- **Hall landmarks** (`_place_landmarks`, `Harbor.landmark(kind)`): every open 3x3 hall gets one, set against its wall. The kinds are an upturned rowing boat, a door that goes nowhere, and stacked lobster pots and crates. They never stand on a horror's tile. They're picked by position, so the same night always has the same ones, and they cycle so no two halls match. Like the lamps, they show only once seen (`harbor_fixtures`). Over 100 dealt nights: 3 landmarks in 72, 2 in 24, 1 or 0 in 4.
- Renders: `docs/renders/fp_landmark_{tower,boat,door,pots}.png`.

## Review fix 5: one keepsake a night (Nov 25)
- In Claude's play of build 160, night 555 was won with an S on the first bell, which unlocked Deeper Night and all three keepsakes at once. After that there was nothing left to chase.
- `record.gd` `add_night` now gives at most one keepsake a night: the first one in the list that the grade earns. Keepsake III ("THE LAST LANTERN") now needs an S on a Deeper Night (`KEEPSAKES` has a fifth field, Deeper only). So a perfect first night gives Deeper Night and keepsake I, and the shelf takes at least three good nights to fill.
- In the Field Guide, a locked keepsake shows `Record.lock_text`: the grade it needs, "on a Deeper Night" for the last one, and "One keepsake a night."

## Gentler first three nights (Nov 25, Duff picked "Gentler first 3 nights")
- Re-review as a genuine first-timer (`tools/eyes/first_timer.gd`, `docs/EYES.md`): a newcomer won 15% of nights on build 175. Two thirds of deaths were thralls grabbing with oil left, one third came after the oil ran out from wandering.
- Your first `Record.GENTLE_NIGHTS` (3) nights, counting any ending, deal `Night.GENTLE_SPARE` (1) thrall fewer: `Night.start_dealt(..., gentle)` runs `Ward.thin` on the ward, which removes the thrall farthest off the road and keeps the walls. A reported night number still has the same walls. The end card and the verdict say FIRST NIGHTS / first-nights. To replay one, use `LM_GENTLE=1` on desktop or `?gentle=1` on the web, next to `LM_NIGHT` / `?night=`. Never on a Deeper Night. Test: `test_first_nights_are_gentler`.
- First-timer bot, 200 nights: 22% won on a gentle night, 15% on a full one. The expert bot is unchanged on full nights (39%). Run with `BOT_GENTLE=1 godot --headless --path . --script tools/first_timer_bot.gd -- 200`.

## Hands that hold things (Nov 25, Duff: "They don't hold the lantern correctly, and they definitely don't hold the boat hook correctly")
- What was wrong: `fp_glove.glb` is a LEFT fist (thumb on model -X) that came with a stray wire loop as a second mesh part. The right hand used it unmirrored, posed sideways, the loop poking out, and the lantern hung beside the fist, not from it. The left hand floated near the hook's shaft.
- Now `scripts/hands.gd` builds both: `glove(mirror)` drops the loop (keeps the largest connected part) and mirrors in the mesh data for the right hand (a negative node scale turned the faces inside out on Compatibility). `grip()` puts the fist's grip channel (`GRIP`, along model X) on the grip point, along the handle, with the forearm toward a given elbow. Right: fist palm-down, an iron link (TorusMesh) through it, the lantern's own ring hooked on the link, all swinging from the fist. Left: fist round the hook's wrapped handle, hook standing up, a dark pole on down from the fist.
- Positions and directions are the consts at the top of `hands.gd` (camera space). Render: `fp_hands.png` (capture). The jab and the lantern swing in `_sway_viewmodel` are unchanged.

## Review fix A: the first grab tears free (Nov 26, Duff picked "Fixes 1-4, one PR each" after the build 183 reviews)
- Reviews of build 183 (newcomer bot 15% won; 2 in 3 deaths with oil to spare): the oil clock never felt like what killed you.
- `Night.torn_free` / `_tear_free()`: the first thrall to get its hands on you each night (beside you on its turn, or you walk into one in the dark) doesn't kill. You lose `GRAB_OIL` (10), dread +15, and it staggers back a tile, stunned `HOOK_STUN` turns, lunge on cooldown. Event `torn_free` (stops a walk, shakes the view, sting + oil slop sound, field note "IT HAD YOU"). The second grab kills as before. Deeper Nights too. The bride is unchanged: her touch still kills.
- Bots, same seeds: expert 41% -> 50% won, median death turn 35 -> 42. Newcomer 15% won either way, but deaths after the oil ran out went from 33% to 55% of deaths: the oil is the clock again. Tests set `torn_free = true` where they mean "this grab kills".
- Edges: two thralls beside you on one turn: the first tears free, the second kills. Walked into, its stun loses a turn at once (the thralls act at the end of your step). The shove can land it on burning oil, where it burns.

## Review fix B: the chart says which way (Nov 26)
- "The flame gutters. Something is near." used to say nothing about where. Now each unseen awake thrall or bride within `Fog.FLICKER_RANGE` (3, any wall) puts a red arc and arrowhead on the chart's rim pointing its way: `Fog.near_unseen()`, `Night.flicker_from()`, drawn in `_draw_map`. When dread makes the flame lie (`fake_flicker`), a mark appears from a direction picked by turn and seed: the chart lies too.
- No sound from that side: close-up thralls are silent by design (`Night.silent`, QUIET_NEAR), so the chart carries it. Capture: `FLICKER MAP PASS`, render `fp_flicker_map.png`. Test `test_flicker_says_which_way`.

## Review fix C: teach the hook (Nov 26)
- The first-timer review died with all 3 hook hits unused: nothing said "swing now". `Night.hook_target()` returns the thrall a swing would hit (first one within `HOOK_REACH` ahead, short of a wall); `hook()` uses it, so the glow and the swing always agree.
- The view lights HOOK (amber, `UI.lit`), relabels it HOOK IT!, pulses it, and the status line says it's in reach, but only when that thrall stands in LIT fog and isn't a lying corpse: a hidden one never lights the button, or the button would give it away. The field note says what the glow means.
- Capture: `HOOK GLOW PASS` (lit with a thrall 2 ahead, out once the hit knocks it to 3), render `fp_thrall.png`. Test `test_hook_target_matches_the_swing`.
- Gotcha: `tools/test.sh` doesn't load `fp_view.gd`, so a type-inference parse error there only shows in the capture (or `--check-only`). Run one of those after view edits.

## Review fix D: a fist you can read (Nov 26)
- From the eye line the right glove was a near-black blob: the lantern hangs below and in front of it, so its light never reaches the leather you see. `Hands._lift()` gives each glove (both hands) its own material copy: a faint emission from the leather's own texture tinted lantern-warm (`GLOVE_WARM`, `GLOVE_GLOW` 0.1) and a soft rim (`GLOVE_RIM` 0.3, `rim_tint` 0.85 so the rim takes the leather colour, not white).
- First try was GLOW 0.35 / RIM 0.6 / tint 0.6: the gloves went ghostly pale. Keep it subtle. Render `fp_hands.png`; before/after in project files `lethemoor-3d/review/glove_before_after.png`.

## The 8.5 pass: a first-timer who knows why (Nov 26)
Duff's new bar (Nov 26): build to an 8.5 from the blind first-time player's review, in one pass. Build 183's first-timer review was 5/10. What the newcomer bot (`tools/eyes/first_timer.gd`) showed, traced night by night: it got lost until the oil ran out, it got cornered by a thrall that came straight back after it tore free, and it swung the hook at thralls that were already down.
- **First nights (Record.gentle, nights 1-3)**: +`GENTLE_OIL` 15 oil, the bride hunts blind from `GENTLE_WAKES` 45 (not 30), `GENTLE_TEARS` 2 escapes, and chalk arrows (`Night.chalk`, `_chalk_road`): every fork (3+ ways) gets an arrow one step nearer the bell, drawn on the flagstones (`_chalk_arrow`, `chalk_nodes`). Field note "CHALK ON THE STONES".
- **Tearing free** (all nights): the thrall is down `GRAB_STUN` 4 turns (was HOOK_STUN 2) and loses you (`target = null`).
- **Shove past** (all nights): a thrall that's down (`Night.down(i)`: stunned, standing, a thrall) can be walked into: you swap places, event `shoved_past`, sound, status line, field note "IT'S DOWN". Before, walking into a hooked thrall killed you. `can_step` allows it even when lit.
- **HOOK IT!** only lights when the thrall in reach isn't already down; with a downed one ahead the status line says to shove past.
- **Death card** (`Lessons.death`): where it came from (ahead/behind/left/right, in your light or out of the dark, from `Night.killed_from`/`killed_seen`) and the one thing that would have saved you; `_mark_killer` at each horror death.
- **End card**: `Record.next_goal` (the next unlock) and the button reads ONE MORE NIGHT.
- **Subtitles for sound**: `Audio.heard(game, before)` names the nearest horror you heard move out of sight; the status line says "A wet shuffle, off to your left. A thrall." or the bride's silk.
- **Newcomer bot** now also follows chalk arrows (85%, then keeps going down the passage), turns toward the red rim mark (70%), treats a downed thrall as no threat and shoves past, and only hooks when HOOK IT! would be lit. All of that is on screen, so a real newcomer has it too.
- Bots (200 / 300 nights): newcomer on first nights 22% -> 41% won; newcomer on later nights 11%; expert (balance bot) 52%.
- Phone feel: swipes already fire as the finger crosses 50 px (not on lift), steps take 0.2 s. Nothing changed; FPS on a real phone still needs Duff.

## The gap pass: every fix from the 6.4 review (Nov 26)
The blind first-timer scored the 8.5 pass (build 196) 6.4. Duff: build all the gap fixes, cancel the reviews (no blind review this round). Found in that review and the newcomer bot: some nights nothing ever came (and still got an S), 36 of 200 first nights never found a hook, a cliff after night 3 (41% -> 11%), oil dropping with no reason given, a cone for a bell, downed thralls standing idle, one status line on repeat, and "Night 11" on a first night.
- **A scare every night** (`Night._beat`, after the first `_horrors` in `_end_turn`): no horror in your light by `BEAT_TURN` 20 -> the nearest standing thrall turns up `BEAT_FROM` 6-9 walking tiles off, on a tile out of your light, hunting you (event `scent`: status line, low turn + dread sound). 4-7 cost first nights 6 points of win rate; 6-9 costs none.
- **No S for an empty night**: `Night.met` (set on a first sighting); `grade()` caps at `UNMET_CAP` "B"; `capped()`; the end card says why.
- **Hook near the start on first nights** (`_hook_near_start`): the nearest hook moves 3-6 steps out, on the shortest road to the bell when it can.
- **Nights 4-6 half eased** (`Record.easing` 1, `Night.half`): +`HALF_OIL` 8, chalk, two escapes (`GENTLE_TEARS`), the normal bride.
- **View**: red "-N SPILLED" under the oil bar on torn_free/panic (`_show_spill`); downed thralls play rig state "down" (the fall clip) then "rise"; a lathe-turned bronze bell (`Harbor.bell_body`, `BELL_PROFILE`, child "Body" under the yoke) that swings for 1.7 s before the card (`_swing_bell`); `AMBIENT` status lines turn every 4 turns; a toll says which way (`_toll_line`); end card "FIRST NIGHT n OF 3" / "YOUR NIGHT n" (`_night_tag`, `night_no`).
- **Lessons**: the death tip only says HOOK IT! if you hold a hook; the OIL SLICK card waits for a standing thrall.
- Newcomer bot (200): first nights 40% won (was 41%), nights 4-6 29% (they were 11%), later nights 8%.


## Hook presentation polish (Nov 27)

- The existing first-person boathook now has a 0.36-second windup, sweeping contact pose, 35 ms visual hold and recovery. The grip stays closed; a pale spectral crescent and small contact-only camera kick are drawn without a new light or asset.
- Timing is visual only: the original one-turn action, reach, wear, stun, noise and seed logic remain unchanged. The old 0.2-second action glide is unchanged.
- Existing synthesized swing/hit clips were regenerated with an iron rattle, spectral breath and heavier low impact. The hit and break cues align with contact; status text retains the hook result over incidental audible events.
- Reproduce portrait screenshots with Godot Compatibility: `godot --path . res://scenes/fp_room.tscn -- --capture --hook-only`. This captures fixed poses and runs a real hit to check turn and wear.
- 85 headless tests pass; full desktop capture reached ART PASS before final visual alignment refinements, and the dedicated hook capture checks the final presentation. Physical-phone FPS and audible mix remain pending.


## Approved atmosphere pass (Nov 27)

- Integrated #76 (QA bot/HUD), #77 (scent retry), #78 (seeded wet floors/dawn text), #79 (return-visit crate) with green CI and independent exact-head fresh-eyes reviews. Merge SHAs are recorded in `BUILD_LOG.md`.
- `scripts/atmosphere.gd` schedules new rare cosmetic events without touching the simulation or global RNG. Reflection is at most one per eligible night, only lit wet floor with no essential prop/chalk or creature; disappears on action, lantern/fog/view change or modal. Use one lazy plane, not a reflection render target. The original undertone is at most once and spatialized, with caption while the tracked player is active. `Audio.atmosphere_conflicts` and cancellation protect the deliberate Bride silence, tolls, nearby horrors and essential sound cues.
- `Harbor.wall_for` keeps geometry and UVs, applies muted olive vertex colors to coping and upper masonry. Original procedural wood texture dresses existing crates; no new world prop. Seeded crate movement is restricted to at most one on a quarter of seeds, after a seen landmark and an unseen return. Existing Martha/Ada letters mention the mundane objects without altering read costs/grade. Existing verdict gets a short cool dawn wash and seeded text, controls unchanged.
- 92 tests pass; 500 nights reproduce the 88-test baseline: 81/200 gentle newcomer wins, 148/300 expert wins, 0 expert stalls, 0 deaths by turn 20. Full input `ART PASS`; staged high/low `ATMOSPHERE PASS` (hooding hides reflection, active audio and caption, toll cancels and blocks restart while ringing, crate moves unseen, dawn grade controls). Exact-head #79 independent render evidence is retained in `docs/renders/atmosphere_prototype_crate_*.png`.
- `docs/ATMOSPHERE_VERIFICATION.md` collects actual screenshots, commands and caveats. Compatibility full capture has no material errors; headless dummy renderer warning is present in original and new code. Active OGG loop teardown warning reproduced in isolated `tools/ogg_shutdown_probe.gd`; stopping, allowing 0.25 s for the mixer, and clearing the stream eliminates it in the probe. No unverified platform-wide lifecycle change. Device FPS, Safari and audible mix/human enjoyment are not measured by these automated tests.

- **Final integration:** #80 merged as `ab65ef570a709fd97ff80fa8b9d1304bd2ff6acf` after exact head `00cb67786ef024025a456f52b1b808b1d746d1bd` passed build #215 (`46038899848`), signed Android + web exports, gitleaks, rule-lock and independent fresh-eyes. The final stationary-hunter audio regression took the suite to 92 tests. Actual priority voices suppress a new undertone for their entire active tail; the full ringing bell cannot be masked. The final exact-head full local capture ended ART PASS, exit 0, with timing-dependent OGG teardown warnings after the capture (12 objects / 6 resources); no rendering or script errors. All 500 simulated-night metrics reproduced unchanged.

- Main build #216 published the fixed-key APK and versioned web build at `ab65ef5`; the public manifest and page asset suffix were independently checked.
- Live build 216 ran in Chromium WebGL 2.0 at 540×960 with mobile touch emulation: exact wasm/pack assets loaded, title/Begin/gesture worked, oil 75→73, zero page errors. Actual web PNGs retained; not Safari/device performance evidence.
