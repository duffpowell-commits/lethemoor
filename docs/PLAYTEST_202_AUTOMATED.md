# Build 202 — automated QA, Nov 27

Main tested: `1ba34584ffaf55adfdb70b440c2cbf5905ebb9d0`, Godot 4.7.2 stable. Owner personal playtest waived; automated QA can proceed without his availability. Volunteer human enjoyment evidence remains separate; no blind review run.

## Reproduced checks
- `godot --headless --path . --import`: exit 0.
- `sh tools/test.sh`: **85 passed, 0 failed**, TESTS PASS.
- `godot --headless --path . --check-only --script scripts/fp_view.gd`: exit 0.
- `BOT_GENTLE=1 godot --headless --path . --script tools/first_timer_bot.gd -- 200`: 81 wins (40.5%), 106 deaths (53%), 13 out of time (6.5%); no deaths by turn 20; median death turn 66; mean winning oil 34.8. 90 deaths classified cold hands, 7 standing figure, 9 lace; 49 of 106 deaths had no oil remaining.
- `godot --headless --path . --script tools/balance_bot.gd -- 300`: 144 wins (48%), 154 deaths (51.3%), 2 stuck (0.7%); no early deaths by turn 20; median death turn 44; mean winning oil 20.8. First horror seen median turn 19, after 20 in 44%; no encounter in 7% of nights. Cold hands account for 123 deaths.
- `XDG_DATA_HOME=<fresh temp directory> godot --headless --path . --quit-after 180 res://scenes/fp_room.tscn`: exit 0, but HUD anchor override warning at fp_view.gd:1733, dummy renderer null material error, 16 ObjectDB instances and 8 resources retained on exit. Investigate with real renderer and ordinary shutdown before attribution. Not a clean runtime pass.
- Rendered capture blocked: xvfb-run absent; Xorg dummy display failed to establish listening sockets. ART PASS, screenshots, touchscreen, audible mix and device FPS not independently verified.

## Recommendation
Investigate two stuck runs using reproducible seed traces; inspect why horrors are first seen after turn 20 despite the scare beat (spawn vs visibility), and distinguish expired oil from enemy-caused deaths. Validate the HUD sizing warning in a real renderer. Do not tune balance from bots alone; preserve rules in the approved atmosphere pass. No code/art changes, no build or merge. User is not required to personally playtest; human fun/replay data remains unavailable and the full-game viability decision is unverified.
