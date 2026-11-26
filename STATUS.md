# STATUS

Public repo: follow the Public repo rules at the top of `CLAUDE.md`.

Read this first. Update it last. Long record: `docs/HANDOFF_LOG.md`. Design that wins: `docs/design/first_person_design.md` (Nov 19).

## The game

Lethemoor: The Last Lantern. Gothic turn-based survival horror, first-person grid crawler, for Android phones (portrait) and a web build for iPhone testers. Godot 4.5, GDScript only. Owner: Duff.

Pillars: light is life (oil is the clock), every slot matters, the dead don't stay gone.

The live slice is One Night: ring the bell before the oil runs out. Grade is oil left plus 5 per letter read (S 35 / A 29 / B 23 / C 18 / D). Start oil 60. Thralls move every other turn. The Stalker freezes only while lit and in view.

## Live

- Web (Safari): https://duffpowell-commits.github.io/lethemoor/
- APK: https://github.com/duffpowell-commits/lethemoor/releases/tag/dev (`lethemoor.apk`, `version.json`)
- Both are build 123, commit `de5bf2a`, with the 3D nightmare Thrall.

## Tools

Nov 24: Eyes (`docs/EYES.md`). A cloud session can play the night itself (tap, step, read the HUD, screenshot) before calling work done.

## In progress

Playtest round 1. Duff on the Android APK. iPhone testers on the web link. Collect fun 1-10, play again yes/no, FPS (MENU shows it), and sound notes.

The slice is built: bell and grade, Stalker, boathook, oil-slick trap, noise, letters, sound, shuffled nights, verdict card, corpses, painted art, in-app APK update.

The 3D harbor shipped in build 119 (PR #38). Since Nov 25 (PR #45) every horror is a rigged, animated 3D body and your hands and lantern are 3D. Needs a phone FPS check.

Parked until the kill test: safe room, satchel, revenant corpse, Choir. Kill test is Nov 28: median fun 6+/10 and testers choose to replay.

Open: PR #33 (art generation guide, docs). Draft PR #31 (Duff, Nov 20: the bell stays silent, so later sessions leave the bell without a hum).

## Blockers

- CI is running. This repo is public, and the build workflow kept succeeding after Nov 18, through the Nov 21 publish above. A newer web page or APK lands when a non-docs change merges to main. Markdown-only edits are ignored by the build workflow, so they do not start a build. A Nov 18 "Actions minutes ran out" note does not match these runs.
- `LM_KEYSTORE_PASS` is the repo Actions secret that unlocks `signing/lethemoor.keystore.enc`. Duff has the passphrase. Sessions cannot write Actions secrets. Never change this key and never use it for another game. If the secret is missing, CI signs with a throwaway key and that APK cannot update an installed one. The key must stay backed up outside the sandbox.
- Real-phone reads are still missing: FPS, lunge timing, corpse readability, kill shot, swipe-only controls, sound mix. Tuning waits on the playtest.
- P0 art still open: wall tops. List: `docs/art_needs.md`.

## Next

1. Play the Nov 21 web build and dev APK. Send verdicts, FPS, and sound notes.
2. Tune oil, thrall speed, and where the Stalker stands, from those notes.
3. Run a second playtest round.
4. Score the Nov 28 kill test. Full-game systems start only after it passes.
5. Wire wall-top art when Foxboard sends it. `git fetch` before every push.

## Key paths

- Rules (no nodes): `scripts/sim/night.gd`, `room.gd`, `fog.gd`. Tests: `tools/test.sh`.
- View: `scenes/fp_room.tscn`, `scripts/fp_view.gd`. Map: `rooms/one_night.txt`.
- Audio: `scripts/audio.gd`. Letters: `scripts/letters.gd`. Updater: `scripts/updater.gd`.
- New clips go in `assets/audio/SOURCES.md`. Art arrives via Foxboard into `grok_art/<date>-foxboard/`.
- Capture must end with `ART PASS`. Balance: `tools/balance_bot.gd`.

## Changelog

- Nov 26: with the boathook in hand, the HOOK button glows and reads HOOK IT! whenever a thrall you can see is within its 2-tile reach.
- Nov 26: when the flame gutters, a red mark on the chart's rim points to whatever unseen thing is near (it lies too when dread is high).

- Nov 26: the first thrall to grab you each night doesn't kill: you tear free, spilling 10 oil, and it staggers back. The second grab kills. Expert bot 41% -> 50% won; more deaths now come from running out of oil.

- Nov 25: hands hold things. The right fist holds the lantern by an iron link through its fingers (it was a left glove floating beside it); the left fist closes round the boathook's handle with the hook standing up. `scripts/hands.gd`, render `docs/renders/fp_hands.png`.

- Nov 25: your first three nights deal one thrall fewer (Duff's pick after the first-timer review: a newcomer won 15% of nights, 22% with one fewer).
- Nov 25: review fix 5 of 5. At most one keepsake a night, and the last one only for an S on a Deeper Night, so a perfect first night doesn't unlock everything at once.
- Nov 25: review fix 4 of 5. A bell tower stands over the walls so you can steer by it, and each open hall has a landmark: an upturned boat, a door to nowhere, or stacked lobster pots.
- Nov 25: review fix 3 of 5. A stone beam no longer floats in the sky over corridors you haven't seen yet.
- Nov 25: review fix 2 of 5. A thrall that crouches now always lunges: backing off a tile used to freeze it, a standoff while dread climbed. The early thrall waits a few steps further in so the first minute stays fair. Bot: 39% win, 5% dead by turn 20.
- Nov 25: review fix 1 of 5. In Claude's play-through, some new-walls nights had no horror at all. Horrors are now placed by how far you'd walk from the road, not by straight-line distance, so a night with no horror in your light went from 23% to 7%. A ward has 3 fewer thralls so the corridors stay survivable. Bot: 40% win, 25 oil at the bell.

- Nov 25: real recorded sound (Duff picked "Free library, I pick"). The bell is a real church peal, the ambience is a real harbour at night, and the footsteps, fire, paper and thrall moans are real recordings. All are CC0 or public domain, listed in `assets/audio/SOURCES.md`. Each is level-matched to the clip it replaced.

- Nov 25: new walls every night and unlocks (Duff: "Lets do 2 and 4 now"). Every dealt night carves its own ward from the handmade map, with the same things at the same pacing. Ringing the bell once unlocks Deeper Night (the bride wakes at turn 18, flasks +8, 50 oil to start). Grades B, A and S each find a keepsake letter in the Field Guide. The title shows bells rung and best grade. Bot on new walls: 54% win, 29 oil at the bell.

- Nov 25: all four fixes from Claude's play-through (Duff picked "All four"). The bell tolls so you can find it, and the map points to it. A thrall waits near the start. The bride hunts you; hold your light on her to drive her off. Flasks give +12. Bot: 50% win, 24 oil at the bell, the bride 19 of 151 deaths.

- Nov 25: more scary (Duff: "Lets get more scary"). Heads snap round to follow you, the kill is in 3D (the thing comes into your face and you go down under it), and at dread 50+ a grey figure stands in the dark ahead for a second. Fixed the bride standing side-on. Look only, no rule changes.

- 2026-11-25. Fully 3D horrors: rigged, animated, faceless thralls + bride (Meshy), 3D lantern arm and boathook, lantern gutters at low oil (PR #45).

- 2026-11-23. Added the skippable 3 Eyed Fox Studios splash and publisher credits in the Field Guide.

- 2026-11-21. Public-repo guardrails: rules in `CLAUDE.md`, gitleaks on PRs and main, secret and prompt ignores.
- 2026-11-21. Push guards, fresh-eyes review gate, lean CLAUDE.md (PR #32, commit 7191080).
- 2026-11-20. Breath keeps playing while a horror lingers. Short goal card, behind-you card, POUR hidden until it is needed.
- 2026-11-20. Footsteps land on the footfall. Breath at your neck. Two-finger swipe turns you about.
- 2026-11-20. Fluid moves: a swipe fires mid-drag, the next move queues, hold to keep walking, steps chain.
- 2026-11-19. Slice finished through painted art, nightmare thrall, verdict card, and in-app APK updates.

Updated 2026-11-25.
