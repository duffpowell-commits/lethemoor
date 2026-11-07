# Pivot: turn-based survival horror (Duff, Nov 7 2026)

This overrides the squad-tactics parts of the locked design doc
(https://claude.ai/artifact/6S3KvEG9LYLggwKtko4cs8). Setting, story, Poe voice, villains,
endings, palette and the lantern/fog rules are unchanged. The design doc itself is NOT yet
updated: fold this in when you next touch it.

## Genre
**Turn-based survival horror.** One survivor, step-based grid movement (tile by tile, "boxy",
like old Resident Evil tank movement); enemies act only when you act. Dread, not panic.
Real-time was rejected: phone thumbsticks feel bad, animation cost explodes, Nov 28 deadline.

## Locked decisions
1. **Revenant = you.** Death resets the night; your corpse rises as a revenant where you fell,
   carrying the gear you lost. Kill it to recover the gear. (Keeps "The dead don't stay gone".)
2. **No classes, no roster.** One fixed protagonist (a lone Watch survivor). Warden / Marksman /
   Lamplighter kits become found tools (big lantern, crossbow, flares).
   *Open:* skill tree or not (see Open questions).
3. **Saving is free, at lit safe rooms only.** Plus a suspend save on quit that is deleted when
   you resume (stops quit-to-save scumming; protects phone interruptions).
4. **No enemy intent previews.** Warnings come from the lantern flicker and sound only.
5. **Nights = expeditions.** Fixed town map. Leave the safehouse, push in, get back before the
   oil runs out. Unlocked doors and relit lamps persist; items and enemies reshuffle each night;
   the rot spreads (escalation clock).
6. **Dread = the survivor's sanity.** Rises in darkness and at horrors; high dread shows the
   designed hallucinations (fake enemy markers in remembered/dark tiles).
7. **Combat is a last resort.** Scarce ammo, weak melee. Real tools: hood the lantern and hide,
   run, burn, bait. Enemies already fit: Stalker (freezes when lit), Bellwether (bell pulls
   enemies), Leech (drinks oil), Thrall (walks to the brightest light).
8. **Keys, light puzzles, backtracking.** Needs a map screen and RE-style item combining.
   Keep it small in v1.
9. **Sound is half the game.** Budget real time for it in the slice (plan below).
10. **Animation:** left/right facing only (sprite flip), slide between tiles with a 2-frame bob.
    Revisit after seeing it run.
11. **Phone sessions:** safe-room saves + suspend save cover 10–20 minute bites.
12. **Vertical slice (still due Nov 28):** 2–3 connected rooms, one locked door + its key, one
    Stalker, one safe room, real sound. Isometric test dropped. Add more only if time allows.
13. **Positioning:** "turn-based survival horror" is nearly an empty genre; Duff wants originality.

## Size and screen
- Characters: **64 px frame**. Floor tiles: **48 px**. Base resolution: **540×960**
  (2× onto 1080p phones), ~11×20 tiles visible. Replaces 32 px tiles / 360×640.
- Work this means: redraw placeholder tiles at 48, update layout constants in `room_view.gd`
  (room area, HUD bar, thumb zone), fog/light radius in pixels, project.godot viewport, renders.

## Open questions (Claude's recommendations, Duff to confirm)
- **Skill tree?** Recommendation: no. Survival-horror power should come from things you find,
  not stats. Progression = satchel/inventory expansions (fits "Every slot matters"), the smith's
  safehouse upgrades, and the already-designed **earned scars** (traits with a cause, e.g. survive
  a Leech → "Oil-miser"). Scars are the skill tree, earned by what you survive.
- **Sound sourcing:** see plan below; Duff to OK spending a few dollars on hero sounds.

## Sound plan
Implementation is easy (Claude). Sourcing and taste are the hard part, and **Claude cannot hear**:
Duff judges every sound on his phone with headphones.
- **In-engine (free, Claude):** positional AudioStreamPlayer2D, a reverb bus, low-pass muffle when
  hooded / in the dark, randomised pitch and volume on footsteps, ambience layers that rise with
  dread, a procedural drone and heartbeat via AudioStreamGenerator.
- **CC0 foley (free):** Kenney, OpenGameArt, Freesound (CC0 filter), Sonniss GDC bundles.
  The sandbox can't reach most of these sites; Duff downloads on his phone and drops files in the
  repo (or Claude pulls packs that are hosted on GitHub).
- **Generated hero sounds (paid, small):** Creative Claw `generate_sound_effect` for 2–3
  signature sounds (Stalker scrape, the silent bell, the revenant). ~a few dollars of credits.
- **Slice sound list (~15):** stone footsteps ×4, lantern hood/unhood, oil glug, flicker ping,
  door creak, locked rattle, key pickup, Stalker scrape, thrall moan, heartbeat, harbour wind loop,
  distant bell, safe-room tone, hurt, death sting.
