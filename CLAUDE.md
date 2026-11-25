# Lethemoor: The Last Lantern

## Public repo rules

This repo is public. Never commit secrets, passwords, keys, tokens, keystore passes, or `.env` files (secrets only in GitHub Actions secrets added by Duff). Never commit AI prompts, bot instructions, persona text, or private chat handoffs. Never commit personal or family info. Never copy code, data, signals, or results from swinglifeaway or other private trading repos.

Gothic turn-based survival horror, **first person** grid crawler, Android phones (portrait) + web for
iPhone testers. Godot 4.7.2, GDScript only. Owner: Duff. This is the handoff; keep it short.
**Everything built so far, with the details and gotchas of each system: `docs/HANDOFF_LOG.md`.**
Search it for a system before you change it.
**Read `STATUS.md` first and update it last.**

- Publisher branding uses the approved 3 Eyed Fox Studios artwork at startup and credits in the Field Guide.

## Where things stand (Nov 21)
- Design that wins over every older doc: `docs/design/first_person_design.md` (Nov 19, first person,
  Duff: "Switch fully now"). Pillars: light is life, every slot matters, the dead don't stay gone.
- The One Night slice is built: bell + grade, Stalker, boathook + oil-slick trap, noise, letters,
  sound, shuffled nights, verdict card, scarier thralls, corpses, painted art, in-app updates.
- **Now:** one playtest round (Duff on Android, iPhone testers on the web build): verdicts, FPS, sound notes.
  Tune oil, thrall speed, Stalker spot from it; then a second round.
- **Kill test by Nov 28:** median fun 6+/10 and testers choose to replay. Don't start full-game
  systems (safe room, satchel, corpse, Choir) before it passes.
- One Night has the 3D harbor environment (PR #38).
- Nov 25: every horror is a rigged, animated, faceless 3D body (Meshy, `scripts/rig_horror.gd`): nightmare,
  hooded and dock-woman thralls + the bride. Clips: idle, stagger walk, zombie-scream tell, attack lunge,
  fall dead, arise. Your hands are 3D too (gloved arm + lantern with the light in its globe, boathook).
  Painted cards are out of the thrall rotation. Re-bake/re-shrink steps: `docs/HANDOFF_LOG.md` "Fully 3D horrors".
- Builds: `dev` release APK (https://github.com/duffpowell-commits/lethemoor/releases/tag/dev) and
  web https://duffpowell-commits.github.io/lethemoor/ (gh-pages, pushed by CI on main).
- Art still needed: `docs/art_needs.md` (P0 first). Shared copy: https://claude.ai/artifact/1UXeTCHVCWkMg9qgRMq6bj
- How to generate that art in Foxboard: `docs/ART_GENERATION_GUIDE.md` (Quase and Glaze's method, mapped onto Forge job fields). Prompts in Foxboard are public: no private info (Duff's likeness is OK, his call Nov 24).

## Rules (the ones sessions trip on)
- Duff is phone-only (Godot Android editor). No desktop steps. GDScript only.
- Rules live in `scripts/sim/` (pure, no nodes, tested). The view only draws them. Fog is gameplay
  truth; lights are the look. Never let the look decide a rule.
- Renderer is **Compatibility** everywhere (the only one that runs in iPhone Safari).
- Every feature serves a pillar or gets cut. Visual decisions need real engine renders.
- Web has no system fonts: draw symbols in code or ship a font. Web plays audio in sample mode
  (no bus effects), so reverb is baked into the clips.
- Every new clip is listed in `assets/audio/SOURCES.md` (a test checks).
- Enemies are faceless (darken painted faces to a void). Painted HUD/world art uses linear filtering.
- Art comes from Duff's Foxboard (Send to game -> `grok_art/<date>-foxboard/`, decoded by CI as
  github-actions[bot] commits on main): `git fetch` before every push.
- Thrall indexes shift when the map changes: pick horrors by kind or position, never by index.
- **Signing:** Lethemoor keeps its OWN key (`signing/lethemoor.keystore.enc`, secret
  `LM_KEYSTORE_PASS`). Never change it, never use it for another game. A new key breaks updates.
- `git fetch` before starting and before pushing. Save renders to `docs/renders/`, not chat.
- UI base 540×960 portrait, canvas_items stretch; top bar 72 px, thumb zone bottom 216 px.
- The signing key must be backed up outside the sandbox; Duff has the passphrase (sessions can't write secrets).
  Not Netlify (credits spent).
- One Claude session per repo at a time. Push after every chunk; merge to main after every
  milestone (up to three per session), updating this file + `docs/HANDOFF_LOG.md`, then `STATUS.md`, each time.

## Guards (enforced)
- `.claude/hooks/guard.py` blocks force push, direct push to main, pushing code the tests didn't pass
  on, writing/generating signing keys and committing secret files (.env, keystores, secrets.*; names only, not contents). Run `tools/test.sh` before a push.
- PRs: the `fresh-eyes` status stays pending until a fresh-context review posts
  `FRESH-EYES REVIEW: PASS` on the head commit (`docs/FRESH_EYES.md`). Pending is not green: sessions check the combined status and don't merge
  (GitHub itself doesn't block it).

## Layout
- `scripts/sim/` rules: `night.gd` (turns, thralls, Stalker, oil, dread, noise), `room.gd` (map,
  paths, shuffle), `fog.gd`. `rooms/*.txt` maps (`one_night.txt` is the slice; legend:
  `#` wall `.` floor `H` hunter `T` thrall `L` lamp `E` exit, more in the log). New data folders go in the
  export presets' include filter (`rooms/*.txt` is there).
- Main scene `scenes/fp_room.tscn` (`scripts/fp_view.gd`). `audio.gd` (autoload `Audio`),
  `letters.gd`, `lessons.gd` (field notes), `perf.gd`, `ui_style.gd`, `updater.gd`.
- Old views kept for reference only: `room.tscn` (2D), `room3d.tscn` (top-down 3D).
- `tools/` never ships (`balance_bot.gd`, `gen_audio.py`, art generators). `grok_art/`, `docs/` never ship.

## Commands
- Godot in the cloud sandbox: 4.7.2-stable Linux zip from GitHub releases -> `/usr/local/bin/godot`.
  Fresh clone: `godot --headless --path . --import`.
- Tests: `tools/test.sh` (runs `tests/run_tests.gd`, must end `N passed, 0 failed`).
- Parse check one script: `godot --headless --path . --check-only --script <file>` (a parse error hangs a scene).
- Capture (real input, prints PASS lines; CI needs the last line `ART PASS`):
  `xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --resolution 1080x1920 res://scenes/fp_room.tscn -- --capture`
- Balance: `godot --headless --path . --script tools/balance_bot.gd -- 300` (`BOT_FIRST=0` = handmade night).
- CI: `gh api repos/duffpowell-commits/lethemoor/actions/runs?per_page=3` (gh GraphQL is blocked).
  Run `gh run list -L 3` before calling a milestone done. Exports run in CI only.
