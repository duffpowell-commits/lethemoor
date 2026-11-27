# Lethemoor sound: where every clip came from

**Two kinds.** Most clips are synthesized from scratch by `tools/gen_audio.py` (numpy noise,
sines, filters, a baked cave reverb; seed 1119), made for Lethemoor and owned by Duff. Since
Nov 25 (Duff: "Free library, I pick") the clips where a real recording matters most are real
recordings, built by `tools/real_audio.py` from **CC0 or public-domain** sources only, so nothing
needs a credit or a licence in the game. They are listed under "Real recordings" below with
their source. Rebuild everything with `python3 tools/gen_audio.py` then
`python3 tools/real_audio.py` (in that order: gen_audio would put the synthesized ones back).

Format: Ogg Vorbis, 44.1 kHz, mono except the stereo bed. Reverb is baked in because the web
build plays audio in Godot's "sample" mode, where bus effects don't run. Total ~1.3 MB.

| Clip | What it is | Plays when |
|---|---|---|
| amb_moor.ogg | 40 s stereo loop: wind in stone, a drowned drone, water lapping, drips | always; drops to near silence the turn before the Stalker can move ("silent bell") |
| heartbeat.ogg | one lub-dub, looped; pitch speeds it up | dread 25+, louder and faster toward 100 |
| flame_loop.ogg | 6 s loop: lantern hiss and crackle | lantern lit; louder on BRIGHT, gone when hooded or dry |
| step_0.ogg, step_1.ogg, step_2.ogg, step_3.ogg | boot on wet stone (heel, scuff, splash), 4 takes | every step forward or back |
| turn.ogg | cloth swish and a handle creak | turning left or right |
| bump.ogg | shoulder into a stone wall | a step that hits a wall (no turn spent) |
| lantern_hood.ogg | metal shutter clack, flame smothered | HOODED |
| lantern_normal.ogg | brass wheel ticks, flame settles | NORMAL |
| lantern_bright.ogg | rising whoosh of flame | BRIGHT |
| oil.ogg | glass clink, cork pop, glug | picking up an oil flask |
| out_of_oil.ogg | the flame sputters out | oil hits 0 |
| letter.ogg | old paper handled | reading a letter under BRIGHT |
| letter_dim.ogg | a softer paper touch | standing on a letter too dim to read |
| bell.ogg | the tower bell: bronze strike, inharmonic partials, long hum | ringing the bell (the win) |
| death.ogg | a hit in the chest, lantern glass breaking, a sagging dissonance | taken by a thrall or the Stalker |
| sting_horror.ogg | dissonant string stab with a sub thump | a thrall steps into your light |
| sting_dread.ogg | low string cluster | dread crosses 50 (the view starts lying) |
| panic.ogg | a gasp, oil spilling and hissing | dread hits 100 |
| whisper.ogg | breath shaped like words | the flame gutters (something near); random phantom whispers behind you at 50+ dread |
| shuffle_0.ogg, shuffle_1.ogg, shuffle_2.ogg | a foot dragging, a wet breath (one take without the groan) | a thrall within 7.5 tiles moves (in 3D, seen or not); hunting thralls drag a foot now and then |
| breath_behind.ogg | a slow wet exhale at your neck, nearly dry, a throat click | a horror gets within 2 walking tiles of you outside your view cone (once as it arrives, in 3D at its tile) |
| stalker_silk.ogg | lace dragging on stone with a breath in it | the Stalker moves (in 3D) |
| night_start.ogg | low swell and a far-off toll | each night starts (also dawn) |
| ui_click.ogg | soft wooden tick | any button |
| hook_swing.ogg | iron rattle and a falling spectral whoosh | swinging the boathook |
| hook_hit.ogg | heavy low thud and iron ring | the hook hits |
| hook_broke.ogg | shaft creaks, head snaps, clank | the hook wears out |
| hook_found.ogg | iron dragged off stone, taken up | picking up the boathook |
| pour.ogg | oil glugged onto stone | POUR (oil slick) |
| ignite.ogg | flint strike, the slick roars up | SPARK |
| burn_shriek.ogg | a cracked, falling shriek in fire | something burns in the slick |
| heard_turn.ogg | the drag stops, a pivot, a click in the throat | a horror turns toward a noise (hook, pour, spark, fire), in 3D at its tile |
| fire_loop.ogg | 5 s loop: oil burning on stone | on every burning tile, in 3D, while it burns |
| harbor_undertone.ogg | original synthesized bowed-metal and wind swell, baked reverb | rare seeded quiet moment, spatial and captioned |

## Real recordings (Nov 25, `tools/real_audio.py`)

These clips are cut, filtered, reverbed and level-matched from the sources below. Each one stays as loud as the synthesized clip it replaced.

| Clip | Source | Licence |
|---|---|---|
| bell.ogg | Radio Aporee: Rocamadour church bell, France, by kaoss012 (archive.org `aporee_61861_71175`) | Public Domain Mark |
| amb_moor.ogg | Radio Aporee: Ploumanac'h port at night (boats, wind in the rigging, masts), by yponomeutaneko (archive.org `aporee_34708_39904`). Mixed with OpenGameArt "Dripping water loop" | Public Domain Mark; CC0 |
| step_0.ogg, step_1.ogg, step_2.ogg, step_3.ogg | OpenGameArt: "Fantozzi's Footsteps (Grass/Sand & Stone)", the stone takes | CC0 |
| fire_loop.ogg | OpenGameArt: "Fire Crackling" | CC0 |
| shuffle_0.ogg | the synthesized drag (shuffle_1) under OpenGameArt "Undead moans" (undead-1) | CC0 |
| shuffle_2.ogg | the synthesized drag (shuffle_1) under OpenGameArt "Zombie moans" by darsycho | CC0 |
| letter.ogg, letter_dim.ogg | OpenGameArt: "Various paper sound effects" (paper_sound 1 and 3) | CC0 |
