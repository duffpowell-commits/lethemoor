# BUILD LOG: pick up the build here

Plain handoff for any coding AI (Claude, Grok, Codex...) or person. Duff, Nov 26: "Continue but keep
logs for another ai to build where you stop." Updated as the work goes, not only at the end.
The newest entry is at the top. Rules and commands: `CLAUDE.md` (it applies to every agent).
Details of each system: `docs/HANDOFF_LOG.md`. Short state: `STATUS.md`.

## Studio mascot (Duff, Nov 26)
- **The three-eyed fox is in every game as a rare cameo, not a pal**: a small event
  that matters but never ruins a run. Duff OKs the fox art on a card before it's built. Rule + this game's idea: `docs/MASCOT.md`.

## Right now (2026-11-26, 19:50 UTC; checked against main `48a526d`)
- **Live:** build 199 (main `e17a537`): the gap pass (PR #68). APK:
  https://github.com/duffpowell-commits/lethemoor/releases/download/dev/lethemoor.apk ;
  web: https://duffpowell-commits.github.io/lethemoor/ . Check `releases/download/dev/version.json`.
- **Since build 199:** only docs merged (#69 this log, #70 mascot rule), so the live build is still 199.
- **Working branch:** each session pushes to the branch its harness names (`claude/...`). No current-work PR open.
- **Old open PRs, not current work:** #31 (Nov 20 "the bell stays silent": out of date, the bell now
  tolls every 10 turns; don't merge) and #36 (Nov 22 isolated 3D harbor prototypes, superseded by the
  3D harbor in #38). Leave both for Duff to close.
- **Paused** (Duff, Nov 26: "Pause all of them we'll continue on rush"). Then "We'll build all of the
  fixes, cancel the reviews": the gap pass below is built and merged, with no blind review.
  Next: nothing until Duff picks Lethemoor up again (his phone playtest of build 199 comes first).
- **Scores so far (blind first-timer):** build 183: 5/10. Build 196 (8.5 pass): 6.4/10.
  Build 199 (gap pass): not reviewed (Duff cancelled it).

## The gap pass (done, PR #68, build 199): what a first-timer still hit at 6.4
Tick each line when it's built, tested and in the branch.
- [x] **A scare every night.** Rule in `scripts/sim/night.gd`: `_beat()`; if no horror has come into
      your light by `BEAT_TURN` (20), the nearest standing thrall turns up 6-9 walking tiles away on a
      dark tile and comes for you (event `scent`). Built, test `test_every_night_gets_a_scare`. Status line
      and sound for `scent` done. Bot cost: newcomer first nights 41% -> 34% won; being tuned.
- [x] **No S for an empty night.** `Night.met`, `grade()` caps at `UNMET_CAP` ("B") if nothing came
      into your light; `capped()`. Built and tested. End card says why ("Nothing came into your light tonight...").
- [x] **A hook early on first nights.** 36 of 200 newcomer first nights never got the boathook.
      `Night._hook_near_start()`: when gentle, the nearest hook moves 3-6 steps from the start, on
      the shortest road to the bell when it can (a side room was still missed).
- [x] **Death tip only suggests the hook if you hold one** (`scripts/lessons.gd` `death()`).
- [x] **THRALLS card before OIL SLICK** (`lessons.gd`: make "slick" trigger on kind "thrall" only).
- [x] **No cliff after night 3.** `Record.easing(rec)` 2 for nights 1-3, 1 for nights 4-6
      (`Night.half`: `HALF_OIL` 8 more oil, chalk, two escapes, normal bride), 0 after.
      Newcomer bot nights 4-6: 11% -> 29% won.
- [x] **Show oil spills**: red "-10 SPILLED" under the oil bar on torn_free / panic (`_show_spill`).
- [x] **A real bell**: `Harbor.bell()` is now the iron yoke plus a child "Body" (lathe-turned
      bronze, `BELL_PROFILE`, hanger + clapper). `fp_view._swing_bell()` swings it 1.7 s before the card.
- [x] **Downed thralls slump** (`fp_view.gd` `_drive_rig`): while `stun > 0` it still plays idle.
- [x] **Status line stops repeating**: `AMBIENT` lines turn over every 4 turns at normal flame;
      on a toll, `_toll_line()` says which way (ahead / behind / left / right of where you face).
- [x] **End card on first nights** says "FIRST NIGHT 1 OF 3" (`_night_tag()`, `night_no`).
- [x] Docs: `CLAUDE.md` Where things stand, `docs/HANDOFF_LOG.md`, `STATUS.md`, this file.
- [x] Gate: tests, capture ART PASS, CI green, fresh-eyes review PASS on the head, merge (#68).
      (Blind first-timer review cancelled by Duff for this round.)

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
- 2026-11-27: pacing follow-up `fix/scent-retry-pacing`: `_beat` now records delivery only after a valid safe spawn exists and retries later if none exists. Regression test blocks every candidate then clears them. 86/86 tests; 200 newcomer and 300 expert outcomes identical to QA branch (81 and 148 wins, zero early deaths, zero expert stuck). The alternative occupied-path restriction reduced wins to 79/140 and left no-encounter rate at 7%, so discarded. Retry fix is correctness, not proven pacing improvement. Verbose headless exit identified three playing OGG streams (amb_moor, flame_loop, night_start); investigate ordinary rendered shutdown before changing audio. Real capture still pending.
- 2026-11-27: QA reliability branch `fix/qa-stuck-hud`: expert bot seeds 235/255 oscillated after running out of oil; both now finish (102/121 turns) by resuming routing instead of trying to freeze the Bride without light. Illegal non-turn actions also fall back to waiting; incomplete runs log seed and state. HUD top bar uses anchor offset instead of size setter; startup anchor warning gone. Tests 85/85, newcomer 81/200 wins (unchanged), expert 148/300 wins, 152 deaths, zero stuck (was 144/154/2). Simulation rules unchanged. Dummy renderer material/cleanup warnings remain; real capture blocked by unavailable display. Horror pacing unchanged; next inspect scent events vs actual sightings, then approved atmosphere pass. No human playtest required from owner.
- 2026-11-26 19:50 UTC: handoff refresh (no code). Main is `48a526d`, live build 199. Noted the two old open PRs; STATUS engine line fixed to 4.7.2.
- 2026-11-26 13:50 UTC: PR #68 (gap pass) merged as e17a537. Every gap item ticked; no blind review
  (Duff cancelled it). Next for any AI: wait for Duff (game paused, Rush has the focus).
- 2026-11-26 13:40 UTC: Duff paused, then "build all of the fixes, cancel the reviews". Built: hook on
  the bell road, slump, spill label, lathe bell + swing, rotating status, toll direction, scent line +
  sound, first-night label, grade-cap note. Tests 83 pass. Next: tune the first-night win rate back
  (beat dropped it 41% -> 34%), easing nights 4-6 (22%), then capture, PR, merge.
- 2026-11-26 13:10 UTC: gap pass started. Built the scare-every-night rule and the grade cap (tests
  pass, 83). Next: early hook on first nights, then easing over nights 4-6.
- 2026-11-26 12:57 UTC: PR #66 (8.5 pass) merged, build 196 live. First-timer review 6.4.
- 2026-11-26 06:00-07:00 UTC: review fixes A-D merged (#62 tear free, #63 red rim mark, #64 HOOK IT!,
  #65 lighter gloves).
