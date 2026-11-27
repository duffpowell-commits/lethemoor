# Lethemoor art needs (Nov 19, 2026)

The list the art team works from, in order. Future sessions: work top down. Tick an item off
here when its art is wired into the game and visible in a capture render.
Why the order: the vertical slice (One Night) has to pass its kill test by **Nov 28**
(testers choose to replay, median fun 6/10+). Art that testers see in the first minute, or
that tells them what is going on, comes first. Everything for the full game waits until the
slice passes.

## House rules for every piece
- **Painted, not pixel art.** Moody, wet, gothic, lit by one warm lantern. Match the
  current walls, floor and the dock thrall (see `docs/renders/fp_start.png`, `fp_thrall.png`).
- **Faceless rule:** no enemy ever shows a face. Veils, sacks, hoods, shadow.
- **Original only:** no copyrighted characters, logos or lookalikes.
- **Delivery:** PNG, transparent background for anything that stands in the world or the HUD.
  Send it through Foxboard (Shared library → Send to game). It lands in `grok_art/` and a
  session wires it in.
- **Light it flat.** The game's lantern does the lighting. Baked highlights and glows fight it.
- **Phone first:** it has to read at ~390 px wide on a phone, in the dark.

## Sizes (what the game uses now)
| Kind | Size | Example |
|---|---|---|
| Standing figure (enemy, NPC) | ~190 × 500 px, feet at the bottom edge, facing you | `thrall_dock.png` 184×512 |
| Floor / wall texture | 512 × 512, seamless on all four sides | `wall_granite.png` |
| Floor prop | 100–400 px tall, standing upright, facing you | `prop_bell.png` 244×384 |
| HUD hand art | ~660 × 665, lower right corner, transparent | `hand_lantern.png` |
| Letter paper | ~600 × 800, torn edges, transparent | `assets/art/letters/` |
| App icon | 1024 × 1024 square, no transparency, must read at 48 px | `app_icon.png` (+ Android 192 / adaptive 432) |

---

## Now: for the slice (before and during the Nov 20–28 playtests)

### P0. Testers see these on day one
1. ~~**App icon (1024×1024).**~~ DONE Nov 19 (`app_icon.png`, Android launcher + adaptive icons, web favicon). The APK and the iPhone home screen still show the default
   Godot robot. It's the first thing a tester sees, and it says "unfinished". Idea: the
   brass lantern, lit, on black, with a thin veil drawn over the glass.
2. ~~**Sky / ceiling over the alleys**~~ DONE Nov 19 (`sky_night.png`, strip baked into a panorama sky). **Sky / ceiling over the alleys (512×512 seamless, or a 2048×512 strip).** Above the walls
   the view is a flat dark-blue void. It's on screen every second of every run.
   Low fog, a moonless overcast sky, or a dripping stone vault: anything that isn't empty.
3. **Wall tops (512×512 seamless).** Nov 27: existing coping now has procedural olive patina and weathered masonry in the atmosphere pass; a dedicated painted texture is optional future art, not a current blocker. Earlier note: the tops of walls are flat colour. Mossy coping stones or
   broken brick edges. Seen on every screen when walls are low.

### P1. Makes the slice's systems readable
4. ~~**The Stalker: a dedicated veiled bride (standing figure).**~~ DONE Nov 19 (`stalker_bride.png`, Forge). She currently reuses the
   mockup bride cut out by hand, tinted pale. She is the slice's signature horror and the one
   rule players must learn (she freezes while you look at her), so she must look different
   from every thrall at a glance: tall, pale lace, long veil, dress dragging.
5. **Two more thrall variants (standing figures).** Every night is now dealt fresh, so four
   identical dock workers reads as copy-paste. A drowned fisherman with net and rope, and a
   dock woman with a shawl over her head. Same faceless rule.
6. ~~**Oil slick decal (256×256, transparent).**~~ DONE Nov 19 (`decal_oilslick.png`; burning pool `decal_fire.png`, particles kept). The poured-oil puddle is drawn in code as a
   dark blob. A wet black oil pool with a faint rainbow sheen and a ragged edge.
7. ~~**Fire sprite sheet**~~ DONE Nov 19 (`fire_sheet.png`, particle flipbook). **Fire sprite sheet (8 frames of 128×256 in a row, transparent).** Burning oil is a
   code-drawn particle stand-in. The trap is the slice's big "aha" moment, so it should look
   great.
8. ~~**Lantern hand, hooded and bright**~~ DONE Nov 19 (`hand_lantern_hooded/_bright.png`, swap by lantern). **Lantern hand, hooded and bright (2 more HUD images, same size as `hand_lantern.png`).**
   Today the hand art just dims for HOODED. The shutter should visibly close. BRIGHT
   should show the wick turned up with a bigger flame. Players learn the lantern states by looking at
   the hand.
9. ~~**Street lamp post (standing prop, ~150 × 600).**~~ DONE Nov 19 (`prop_lamppost.png`). The map has a lamp post that is a grey
   box today. A rusted iron gas lamp, unlit.
10. ~~**Letter nailed to a wall**~~ DONE Nov 19 (`letter_nailed.png`). **Letter nailed to a wall (prop, ~200 × 260, paper with a nail).** Letters on walls show the
    in-hand page art. A small folded note pinned with a nail reads better from a distance.

### P2. Polish for the slice, if the art team has time
11. **Bell tower landmark** (a tall silhouette prop seen over the walls). It gives the night
    a goal you can see.
12. **End screen art:** a "bell rings" illustration and a "the dark took you" illustration
    (each ~540 × 300, top of the end card).
13. **Floor variety:** a wet-puddle floor tile and a drain grate tile (512×512).
14. **Title card logo:** "LETHEMOOR" lettering as art (~900 × 250, transparent).

---

## Later: the full game (after the slice passes; don't start before Nov 28)
Ordered by when the design needs them (`docs/design/first_person_design.md`).

### L1. The loop between nights
- **Dawn safe room** (a background scene, lamp-lit). This is where every night ends and the
  next begins.
- **The lamp keeper** (standing figure; looks less human each dawn: 4–5 stages).
- **The ferryman** (standing figure; trades oil for teeth or eyes; never attacks).
- **Satchel: 3×3 grid view** (open leather bag, top-down) and **item icons** (~128×128 each):
  matches (dry / wet), bread (fresh / moldy), rope, hook, salt, oil flask, knife, flare gun,
  iron bell, teeth, eyes, keys.
- **Night journal pages** (a few page backgrounds; text is set by the game).

### L2. Your corpse and new horrors
- **Your revenant corpse** (standing figure, carrying YOUR lit lantern; the same coat as the
  hand art).
- **The Choir** (three figures that move only while your back is turned; they need to read
  as a group).
- **Hollow** (a breathing door; wall texture + animated overlay).
- **Notes from past selves** (paper scraps with worse handwriting each time; 4–5 variants).

### L3. Weapons and traps in hand and world
- **Free-hand weapon art** (HUD, lower left, mirroring the lantern hand): boathook,
  silvered knife, flare gun, iron bell.
- **Trap props:** bait lantern hanging, gaff-and-rope tripwire across a doorway, collapsing
  shelf (before / after), salt line on the floor (decal).

### L4. Districts
- **Carrion Row tile set** (walls, floor, wall tops, 2–3 props) and **Cathedral tile set**
  (finale). Same seamless 512×512 spec.
- **Wallpaper that forms words** from one spot (a damask variant with hidden lettering).

### L5. Bosses (each dies to a trap or a quest, never a slugfest)
- The Drowned Bride (+ silver comb prop, chapel light trap), Quay Master (+ crane and cargo),
  Rat King (+ wormwood, smoke), Lamp Keeper (final form), the Choir's Conductor (+ organ
  pipes). Large standing figures, ~400 × 900.

### L6. Store
- Google Play: feature graphic 1024×500, 4–8 phone screenshots (taken in-engine), icon
  (the P0 icon). Web cut "One Night" for CrazyGames/Poki: cover 512×384 and a thumbnail.
