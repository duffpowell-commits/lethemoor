# Lethemoor: The Last Lantern

Gothic **turn-based survival horror** for Android phones (portrait), Godot 4.5, GDScript only.
Owner: Duff. Read this first; it is the handoff between sessions.

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
- **DECIDED (Duff, Nov 20): the bell stays silent.** No hum, toll or sound cue from the bell to steer by (it would
  break the letters' "keep the bell silent" story). If finding it is a problem in playtests, solve it without sound.
- **Art needs: `docs/art_needs.md`** (prioritized P0/P1/P2 for the slice, then the full game, with
  sizes and why). Shared copy for Duff's art team: Claude Doc https://claude.ai/artifact/1UXeTCHVCWkMg9qgRMq6bj.
  P0 = app icon (APK + home screen still show the Godot robot), sky over the alleys, wall tops.
  Tick items off in the md as art lands.
- **Slice status (Nov 19):** all slice features built. Left before expanding: one playtest round
  (Duff Android, Brittany + Madison iPhone) collecting verdicts, FPS and sound notes; tune oil,
  thrall speed, Stalker spot from it; second round. Kill test by Nov 28: median fun 6+, testers
  replay. Don't start the full-game systems (safe room, satchel, corpse, Choir) before it passes.
- Older plan: **M1 = new slice** (pivot doc #12): 2–3 rooms, locked door + key, one Stalker, one safe
  room, real sound. Also: real tile art for 3D, and one-step-per-tap vs the 4-tile placeholder
  move (pivot says step-based; decide with Duff on the phone build).

## Art session notes (Nov 7, end of session; Duff is about to change the game "a bit")
Duff's change happened: see the pivot doc. Size is now decided (64 px characters, 48 px tiles).
- **Target look:** Final Fantasy Resonance (Square Enix, HD-2D, out Oct 22 2026). HD-2D =
  simple pixel sprites + modern engine light (glow, depth, fog, vignette). So: keep sprites
  clean, put the mood in Godot lights. Duff wants it "overall more creepy".
- **Roles (Duff's call):** Grok designs characters, Claude is "the head": converts, cleans,
  lights, integrates, and pushes back on quality. Grok's design >> code-drawn `hunter48`
  (Duff and Claude agree). Prompt template lives in `grok_art/README.md`.
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
- Test channels: **web build** for iPhone testers (Brittany is on iPhone; she opens a link in
  Safari, no install). **APK** for Duff's Android. iOS native is later (needs a Mac build
  machine + $99/yr Apple account); avoid Android-only plugins so a port stays a build job.
- Hosting: code here (private GitHub). Builds = CI artifacts. Web playtests on an **itch.io
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

## Layout
- `scripts/sim/` pure rules, no nodes: `fog.gd`, `room.gd`. Tests drive these headless.
- `scripts/room_view.gd` the playable room (draws rules, takes taps, HUD built in code).
- `rooms/*.txt` handmade rooms: `#` wall, `.` floor, `H` hunter, `T` thrall, `L` lamp, `E` exit.
  Exported via the presets' include filter (`rooms/*.txt`); new data folders need adding there.
- `grok_art/` design sources from Duff (never ships). `tools/fixes/` per-sprite hand fixes.
- `assets/art/` 32×32 tiles. `tools/` scripts that never ship. `docs/` never ships.

## Commands
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

## Tech rules
- Renderer is **Compatibility** everywhere: the only one that runs in iPhone Safari.
- UI base 540×960 portrait, canvas_items stretch (3D at full phone res), nearest filtering on
  sprites/tiles. 3D room: top bar 72 px, thumb zone (status + lantern buttons) bottom 216 px.
- Fog is gameplay truth (sim grid); lights are the look. Never let the look decide rules.
- Game logic stays grid-only so a later isometric renderer is a renderer swap, not a rewrite.

## House rules
- **One Claude session per repo at a time.** `git fetch` before starting and before pushing.
- Duff is phone-only (Godot Android editor). No desktop-only tools. GDScript only.
- Push after every chunk of work; merge to `main` at the end of every milestone.
- Up to three milestones per session; update this handoff and merge after EACH one.
- Save renders to `docs/renders/`, don't paste lots of images into chat.
- Visual decisions need real engine renders shown to Duff, not sketches.
- Every feature must serve a pillar or it gets cut.
