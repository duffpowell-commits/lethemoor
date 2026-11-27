# STATUS

Public repo: follow the Public repo rules at the top of `CLAUDE.md`.

Read this first. Update it last. Long record: `docs/HANDOFF_LOG.md`. **Any AI picking up the build: `docs/BUILD_LOG.md`.** Design that wins: `docs/design/first_person_design.md` (Nov 19).

## The game

Lethemoor: The Last Lantern. Gothic turn-based survival horror, first-person grid crawler, for Android phones (portrait) and a web build for iPhone testers. Godot 4.7.2 (4.7.x only), GDScript only, Compatibility renderer. Owner: Duff.

Pillars: light is life (oil is the clock), every slot matters, the dead don't stay gone.

The live slice is One Night: ring the bell before the oil runs out. Grade is oil left plus 5 per letter read (S 35 / A 29 / B 23 / C 18 / D). Start oil 60. Thralls move every other turn. The Stalker freezes only while lit and in view.

## Live

- Web (Safari): https://duffpowell-commits.github.io/lethemoor/
- APK: https://github.com/duffpowell-commits/lethemoor/releases/tag/dev (`lethemoor.apk`, `version.json`)
- Public manifest last verified build 213, commit `e31f818` (#79). Atmosphere #80 merged as `ab65ef5`; main build #216 publication pending. Check `version.json` rather than assuming latest main is already live.

## Tools

Nov 24: Eyes (`docs/EYES.md`). A cloud session can play the night itself (tap, step, read the HUD, screenshot) before calling work done.

## Current state

- **Integrated:** PRs #76, #77, #78, #79 merged after CI and independent fresh-eyes passes. Exact merge commits in `docs/BUILD_LOG.md`.
- **Atmosphere complete:** PR #80 merged as `ab65ef570a709fd97ff80fa8b9d1304bd2ff6acf` after final exact head `00cb6778` passed all gates; completes approved #74: seeded rare puddle silhouettes, unseen crate shift, original quiet spatial cue (stops for essential feedback), coping patina, prop-linked letters, wrong dawn. No simulation, signing key or approved 3D asset changes. 92 tests pass, 500-night benchmark unchanged, actual Compatibility `ART PASS` and staged HIGH/LOW atmosphere checks. See [verification and real screenshots](docs/ATMOSPHERE_VERIFICATION.md). Build #215, fixed-key Android/web export, gitleaks/rule-lock and independent exact-head fresh-eyes passed before merge.
- One Night remains the slice. The 7% expert no-encounter rate is unchanged. Parked until the separate viability decision: safe room, satchel, revenant corpse and Choir.
- Old PRs #31 and #36 remain untouched. #74 is the approved design reference.

## Remaining evidence / constraints

- Android and web exports must pass CI with fixed signing key as before; do not alter `signing/lethemoor.keystore.enc`.
- Actual physical-phone FPS, Safari runtime, audible mix and genuine volunteer enjoyment remain unmeasured. Owner personal playtest is waived; automated quality evidence does not measure enjoyment.
- Existing active-OGG teardown issue and dummy-material warning are isolated/documented, not treated as fixed on all platforms. See verification doc for reproduction.

## Next

1. Verify main build #216 publication and public APK/web manifest.
2. If volunteers give genuine feedback, record the Nov 28 viability decision (median fun 6+/10 and voluntary replay). Do not equate bot/engine correctness or synthetic verdict taps with that result; no personal playtest required from Duff.
3. Do not expand the slice or start parked full-game systems without the viability decision.

## Key paths

- Rules (no nodes): `scripts/sim/night.gd`, `room.gd`, `fog.gd`. Tests: `tools/test.sh`.
- View: `scenes/fp_room.tscn`, `scripts/fp_view.gd`. Map: `rooms/one_night.txt`.
- Audio: `scripts/audio.gd`. Letters: `scripts/letters.gd`. Updater: `scripts/updater.gd`.
- New clips go in `assets/audio/SOURCES.md`. Art arrives via Foxboard into `grok_art/<date>-foxboard/`.
- Capture must end with `ART PASS`. Balance: `tools/balance_bot.gd`.

## Changelog

- Nov 26 (gap pass, no review this round per Duff): something always comes for you by turn 20, and a night where nothing came can't earn better than B. First nights put a boathook on your road. Nights 4-6 are half eased (more oil, chalk, two escapes). Spilled oil shows as a red number. The bell is a real bronze bell that swings when you ring it. Knocked-down thralls slump. Status lines vary and the toll says which way. The end card says FIRST NIGHT 1 OF 3. Newcomer bot: first nights 40%, nights 4-6 29% (was 11%).
- Nov 26 (8.5 pass): your first three nights are chalked toward the bell, with more oil, two escapes and a later bride. A thrall that's down can be shoved past. The death card says what got you, from where, and what would have saved you; the end card names the next unlock (ONE MORE NIGHT). Sounds get subtitles. Newcomer bot on first nights: 22% -> 41% won.
- Nov 26: your gloves catch a little of the lantern's warmth and have a soft rim, so the right fist reads as a fist from the eye line instead of a dark blob.
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

Updated 2026-11-27.
