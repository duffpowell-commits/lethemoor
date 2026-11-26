# BUILD LOG: pick up the build here

Plain handoff for any coding AI (Claude, Grok, Codex...) or person. Duff, Nov 26: "Continue but keep
logs for another ai to build where you stop." Updated as the work goes, not only at the end.
The newest entry is at the top. Rules and commands: `CLAUDE.md` (it applies to every agent).
Details of each system: `docs/HANDOFF_LOG.md`. Short state: `STATUS.md`.

## Right now (2026-11-26, 13:10 UTC)
- **Live:** build 196 (main `cda4877`): the 8.5 pass (PR #66). APK:
  https://github.com/duffpowell-commits/lethemoor/releases/download/dev/lethemoor.apk ;
  web: https://duffpowell-commits.github.io/lethemoor/ . Check `releases/download/dev/version.json`.
- **Working branch:** `claude/project-thread-qrikmp` (the only branch sessions push to). No PR open
  for the gap pass yet.
- **Goal:** Duff's bar is an **8.5/10 from a blind first-time player's review** before more rounds.
  Build to a plan, OK'd once, in one pass; then review; then merge.
- **Scores so far (blind first-timer):** build 183: 5/10. Build 196 (8.5 pass): 6.4/10.
  Duff chose: merge 6.4, then build the gap below in one pass, gated on 8.5 again.

## The gap pass (in progress): what a first-timer still hit at 6.4
Tick each line when it's built, tested and in the branch.
- [ ] **A scare every night.** Rule in `scripts/sim/night.gd`: `_beat()`; if no horror has come into
      your light by `BEAT_TURN` (20), the nearest standing thrall turns up 4-7 walking tiles away on a
      dark tile and comes for you (event `scent`). Built, test `test_every_night_gets_a_scare`. Still
      to do: a status line and sound for `scent`, and bot numbers (first sighting by turn 25).
- [ ] **No S for an empty night.** `Night.met`, `grade()` caps at `UNMET_CAP` ("B") if nothing came
      into your light; `capped()`. Built and tested. Still to do: the end card should say why.
- [ ] **A hook early on first nights.** 36 of 200 newcomer first nights never got the boathook. Plan:
      in `start_dealt`, when gentle, move the nearest hook to a tile 3-6 steps from the start.
- [ ] **Death tip only suggests the hook if you hold one** (`scripts/lessons.gd` `death()`).
- [ ] **THRALLS card before OIL SLICK** (`lessons.gd`: make "slick" trigger on kind "thrall" only).
- [ ] **No cliff after night 3.** Newcomer bot: 41% won on first nights, 11% after. Plan:
      `Record.easing(rec)` 2 for nights 1-3, 1 for nights 4-6 (`HALF_OIL` 8 more oil, chalk kept,
      one escape, normal bride), 0 after.
- [ ] **Show oil spills** (tear-free -10, panic -5): a red "-10" by the oil bar when it happens.
- [ ] **A real bell** to ring at the end: build a bronze bell from primitives in Godot (no paid
      art), swing it on the win, play the bell clip.
- [ ] **Downed thralls slump** (`fp_view.gd` `_drive_rig`): while `stun > 0` it still plays idle.
- [ ] **Status line stops repeating** "The lantern burns low: two paces of light" (it shows even at
      75 oil). Rotate ambient lines; say which way the bell tolled.
- [ ] **End card on first nights** says "FIRST NIGHT 1 OF 3", not "Night 11".
- [ ] Docs: `CLAUDE.md` Where things stand, `docs/HANDOFF_LOG.md`, `STATUS.md`, this file.
- [ ] Gate: tests, capture ART PASS, CI green, fresh-eyes review PASS on the head, then a **blind
      first-timer review** (below). Merge only at 8.5, or bring Duff the gap.

## How to build, test and review (cloud sandbox)
1. Godot 4.7.2-stable Linux at `/usr/local/bin/godot`; fresh clone: `godot --headless --path . --import`.
2. `git config core.hooksPath .githooks` once per clone. `git fetch` before starting and pushing.
3. Tests: `tools/test.sh` (must print `TESTS PASS`; it records the tree the push guard checks).
   Commit, then push in a separate command.
4. Capture (~10 min): `xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3
   --resolution 1080x1920 res://scenes/fp_room.tscn -- --capture`, last line `ART PASS`. It rewrites
   `docs/renders/*.png`; keep only the renders your change is about.
5. Bots: newcomer `BOT_GENTLE=1 godot --headless --path . --script tools/first_timer_bot.gd -- 200`
   (first nights; drop BOT_GENTLE for later nights); expert `tools/balance_bot.gd -- 300`.
6. Blind first-timer review: a fresh reviewer that hasn't seen the code plays 2-3 nights through Eyes
   (`docs/EYES.md`, pilot `tools/eyes/first_timer.gd`) and reads only the screenshots.
   **Reset the save first, including `hints/seen`**, or no field notes appear and teaching isn't tested.
7. PR: draft, fresh-eyes review comment `FRESH-EYES REVIEW: PASS <full sha>` on the head
   (`docs/FRESH_EYES.md`), combined status success, then squash-merge. Live when
   `version.json` shows the merge sha.

## Gotchas
- `tools/test.sh` doesn't load `scripts/fp_view.gd`: a type error there only shows in the capture or
  `godot --headless --path . --check-only --script scripts/fp_view.gd`.
- `UI.unlit()` strips a button's plate style: restore `_plate_style()` instead on item buttons.
- Rules live in `scripts/sim/` and are tested; the view only draws. The newcomer bot may only use what a
  player sees on screen.
- Rule files (CLAUDE.md rules/guards sections, `.claude/`, `.githooks/`...) are locked: a PR touching
  them needs Duff's `duff-ok` label. Agents never add it. The "Where things stand" section is free.
- Lethemoor keeps its own signing key. Never make or change a key.

## Log (newest first)
- 2026-11-26 13:10 UTC: gap pass started. Built the scare-every-night rule and the grade cap (tests
  pass, 83). Next: early hook on first nights, then easing over nights 4-6.
- 2026-11-26 12:57 UTC: PR #66 (8.5 pass) merged, build 196 live. First-timer review 6.4.
- 2026-11-26 06:00-07:00 UTC: review fixes A-D merged (#62 tear free, #63 red rim mark, #64 HOOK IT!,
  #65 lighter gloves).
