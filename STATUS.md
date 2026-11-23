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
- Both are build code 110, commit `7191080`, published 2026-11-21 02:34 UTC. That is the build testers have.

## In progress

Playtest round 1. Duff on the Android APK. iPhone testers on the web link. Collect fun 1-10, play again yes/no, FPS (MENU shows it), and sound notes.

The slice is built: bell and grade, Stalker, boathook, oil-slick trap, noise, letters, sound, shuffled nights, verdict card, corpses, painted art, in-app APK update.

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

- 2026-11-23. Added the skippable 3 Eyed Fox Studios splash and publisher credits in the Field Guide.

- 2026-11-21. Public-repo guardrails: rules in `CLAUDE.md`, gitleaks on PRs and main, secret and prompt ignores.
- 2026-11-21. Push guards, fresh-eyes review gate, lean CLAUDE.md (PR #32, commit 7191080).
- 2026-11-20. Breath keeps playing while a horror lingers. Short goal card, behind-you card, POUR hidden until it is needed.
- 2026-11-20. Footsteps land on the footfall. Breath at your neck. Two-finger swipe turns you about.
- 2026-11-20. Fluid moves: a swipe fires mid-drag, the next move queues, hold to keep walking, steps chain.
- 2026-11-19. Slice finished through painted art, nightmare thrall, verdict card, and in-app APK updates.

Updated 2026-11-23.
