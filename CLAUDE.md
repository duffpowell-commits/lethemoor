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
  = the web build running in headless Chrome). CI builds a web zip + debug APK on every push,
  and every push to `main` refreshes the **`dev` release** (Releases → dev → tap the APK):
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
- **Art pipeline (Nov 7): Grok designs, Claude converts.** Duff drops green-screen designs in
  `grok_art/` (see its README). `tools/import_sprite.py` keys the green, shrinks, snaps to the
  palette, cleans speckle, outlines, writes sprite + normal map + flame glow. Hand fixes live in
  `tools/fixes/<name>.py`. First import: `bearer48` / `bearer64` from `grok_art/lantern_bearer.jpg`
  (WIP: not yet rendered in the art test scene; 64 reads far better than 48).
  See "Art session notes (Nov 7)" below before touching art.
- Next: **resize to 48 px tiles / 540×960**, then **M1 = new slice** (pivot doc #12): 2–3 rooms,
  locked door + key, one Stalker, one safe room, real sound. (Old tactics slice is void.)

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
- Base resolution 360×640 portrait, integer scaling, nearest filtering (crisp pixels).
  Room area is y 48–496; top bar 48 px; thumb controls in the bottom 144 px.
- Fog is gameplay truth (sim grid); 2D lights are the look. Never let the look decide rules.
- Game logic stays grid-only so a later isometric renderer is a renderer swap, not a rewrite.

## House rules
- **One Claude session per repo at a time.** `git fetch` before starting and before pushing.
- Duff is phone-only (Godot Android editor). No desktop-only tools. GDScript only.
- Push after every chunk of work; merge to `main` at the end of every milestone.
- Up to three milestones per session; update this handoff and merge after EACH one.
- Save renders to `docs/renders/`, don't paste lots of images into chat.
- Visual decisions need real engine renders shown to Duff, not sketches.
- Every feature must serve a pillar or it gets cut.
