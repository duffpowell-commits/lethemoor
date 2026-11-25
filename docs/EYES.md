# Eyes: Claude sees and drives the running game

Added Nov 24, 2026 (Duff: "Yes" to giving Claude eyes in the running game).

The `--capture` run (CLAUDE.md Commands) plays a fixed script. Eyes is for the times a session needs to look around on
its own: open the game, tap through screens, read what's on screen, screenshot it, and poke the
live scene tree, then judge the result itself before calling anything done. It runs in a cloud
session under `xvfb-run`; Duff's phone only sees the results.

Engine: [godot-mcp-runtime](https://github.com/Erodenn/godot-mcp-runtime) 4.0.1 (MIT), pinned in
`tools/eyes/package-lock.json`. Vetted Nov 24: one dependency (the official MCP SDK), localhost-only
bridge, no telemetry, nothing committed into the game. It adds a temporary autoload while the game
runs and removes it on exit; its scratch files live in `.mcp/` (git-ignored).

## Setup (once per cloud session)
1. Godot on PATH (CLAUDE.md Commands), then `godot --headless --path . --import`.
2. `tools/eyes/setup.sh` -> `EYES SETUP PASS`.

## Use
```sh
xvfb-run -a -s "-screen 0 1080x1920x24" node tools/eyes/eyes.mjs tools/eyes/smoke.json
xvfb-run -a -s "-screen 0 1080x1920x24" node tools/eyes/eyes.mjs '[{"click":"NEW GAME"},{"shot":"x"}]'
```
Steps, run in order: `{"ui":true}` lists visible text; `{"click":"PLAY"}` taps a visible button
by its text or node name (retries 3 s; add `"optional":true` to skip if it never shows);
`{"key":"Escape"}`; `{"action":"ui_accept"}`; `{"wait":800}` (ms); `{"shot":"name"}` saves
`docs/renders/eyes/name.png` (git-ignored; copy the ones Duff should see into `docs/renders/`);
`{"gd":"return scene_tree.current_scene.name"}` runs GDScript against the live tree.
Ends with `EYES PASS`, or `EYES FAIL <reason>` and exit 1. Errors the game prints fail the run,
including bare stderr lines (`printerr`, crash text) and the game exiting on its own; warnings are
listed but don't (sandbox audio and vsync noise filtered out); add `{"allowErrors":true}` anywhere in
the list (as its own step or on any other step, which still runs) to only list them; it covers the whole run.

Each run starts a fresh game process but keeps `user://` saves between runs, so a second run may
show CONTINUE on the title screen.

Self-test: `tools/test_eyes.sh` -> `EYES TEST PASS` (smoke must pass; a missing button, broken
GDScript and a game runtime error must fail). Run it after touching `tools/eyes/`.

## In Lethemoor
`tools/eyes/smoke.json` begins the night, dismisses up to three Field Notes (they only show on a
fresh save), taps WAIT and steps forward (`{"key":"Up"}`); oil should drop 60 -> 59 -> 58.
Swipes aren't a step type; use the arrow keys.

## In a game repo
Write a `tools/eyes/smoke.json` that reaches your core screen. After a gameplay change, play a few
turns the way a new player would (follow the on-screen hints only), look at every shot, and write
what confused you into `STATUS.md` or `docs/HANDOFF_LOG.md`. First real run (Rush, Nov 24) caught the template intro
text left in and a dead-end hint after FIRE.

## Optional: as a live MCP tool
`.mcp.json` registers the same server for Claude Code sessions that load project MCP servers (it
may ask for approval once). If it doesn't load, use the script above: same engine, same results.
