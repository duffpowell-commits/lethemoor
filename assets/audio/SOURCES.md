# Lethemoor sound: where every clip came from

**All of it is original.** Every file here is synthesized from scratch by
`tools/gen_audio.py` (numpy noise, sines, filters, a baked cave reverb; seed 1119), made for
Lethemoor and owned by Duff. No samples, no recordings, no third-party or CC0 packs, so there
is nothing to credit and nothing to license. Rebuild them all with
`python3 tools/gen_audio.py` (needs numpy + ffmpeg; one clip: `--only bell`).

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
| stalker_silk.ogg | lace dragging on stone with a breath in it | the Stalker moves (in 3D) |
| night_start.ogg | low swell and a far-off toll | each night starts (also dawn) |
| ui_click.ogg | soft wooden tick | any button |
| hook_swing.ogg | a heavy falling whoosh | swinging the boathook |
| hook_hit.ogg | iron into something wet: thud, ring | the hook hits |
| hook_broke.ogg | shaft creaks, head snaps, clank | the hook wears out |
| hook_found.ogg | iron dragged off stone, taken up | picking up the boathook |
| pour.ogg | oil glugged onto stone | POUR (oil slick) |
| ignite.ogg | flint strike, the slick roars up | SPARK |
| burn_shriek.ogg | a cracked, falling shriek in fire | something burns in the slick |
| heard_turn.ogg | the drag stops, a pivot, a click in the throat | a horror turns toward a noise (hook, pour, spark, fire), in 3D at its tile |
| fire_loop.ogg | 5 s loop: oil burning on stone | on every burning tile, in 3D, while it burns |
