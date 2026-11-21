# Art generation guide for Claude

How the Grok Bot art agents get results Duff likes, mapped onto Foxboard Forge
(`duffpowell-commits/Foxboard`). Read this before you queue a Forge job for
**Hunter** or **Lethemoor**.

- **Quase · Art Team** makes painted graphic-novel sprites, portraits, scenes
  and UI (Chaos, and Hunter concept / UI art).
- **Glaze · Lethemoor Art** makes Lethemoor art: first the old 64 px pixel
  pipeline, now the painted 512×512 wall and floor textures (and other
  first-person slice art) after the Nov 19 first-person pivot.

This file does not invent techniques those agents do not use. Where Forge
cannot do what Grok does, it says so plainly. See `docs/DECISIONS.md`
(2026-11-21, America/Chicago) for why the style-reference path is a
workaround.

**Forge prompts and outputs are public.** Never put Duff's likeness, private
info, real names of living people, or anything that should stay off the
public internet in `forge/jobs/<id>.json`.

---

## Sources (so later sessions can check)

- Grok art skills: `game-art-delivery-pipeline`, `game-art-batch-pipeline`,
  `pixel-sprite-generate-and-clean`, `getting-started`.
- Files the Grok art agents wrote: Lethemoor `grok_art/glaze/HANDOFF.md`,
  `grok_art/glaze/showcase/README.md`, and
  `grok_art/glaze/env/round1/process_tiles.py`.
- Foxboard `README.md`, `CLAUDE.md`, `forge/render_one.py`,
  `tools/claude/art_loop.py`, and real job JSON under `forge/jobs/`
  (Hunter `dh-*`, Lethemoor `lm-*`).
- Hunter `docs/style-guide.md`, `docs/ART_LOG.md`, `tasks/lessons.md`,
  `standards/09-art-assets.md`.
- Lethemoor `docs/art_needs.md`, `CLAUDE.md`, `grok_art/README.md`.

If a game's own style guide or art-needs list disagrees with a generic
example here, the game's file wins.

---

## 1. The pipeline (do this in order)

This is the shared Grok pipeline, not a mood board.

1. **Read the repo first.** Art-needs list, style bible, palette, banned
   content, file names and sizes. Always `git fetch` and read the current
   docs before generating. Glaze almost started a 48 px pixel batch after
   Lethemoor had already switched to painted 512 px first-person art.
2. **Lock the style with 2–3 drafts** of one new asset type. Show Duff.
   Do not batch until he says the look is right. A new type (characters vs
   scenes, or a new realm) gets its own lock.
3. **Build a reference kit and keep it in the repo** before the batch:
   identity cards (verbatim trait strings, laterality, approved views),
   a style-only crop for scenes, a prop / setting guide.
4. **Generate one subject per job**, with an explicit prompt (style,
   setting, palette, pose or framing, and what to exclude). How to attach
   a picture on Forge is in §3 — it is not the same as Grok.
5. **Self-check with `art_loop.py score`, then `cut`**, and fix locally
   if a small area is wrong. Regenerate only when composition or identity
   is wrong.
6. **Preview with a contact sheet**, one honest weakest-spot line, and a
   clear approve / fix / hold ask.
7. **Handoff only the finals** (plus notes) into the **game** repo on a
   feature branch. Never push game-repo code to main, never force-push.
   Do not overwrite files that already exist on the default branch; put
   new art beside them. Do not touch code, scenes or rigs unless asked.

**Where to queue a Forge job: Foxboard `main`.**
`.github/workflows/forge.yml` runs only on a push to `main` under
`forge/jobs/**`, and only while the repo is public. A job committed on a
feature branch never renders. Code changes to Foxboard still go through
a pull request. `art_loop.py queue` publishes a job-only commit to
`origin/main` for you (see §2). The "no push to main" rule in step 7
applies to the game repos, not to those job files.

**Why this works:** Duff's "love it, now finish the rest in the same
style, and show me backgrounds again before you go on" is the quality
gate. Most of the art he has sent back failed a check the agent could
have run first.

---

## 2. Prompt structure and how to queue

### Two working queue paths

1. **`art_loop.py queue`** (the usual Claude path; this is what the
   `lm-*` jobs originally used, now with the missing flags):

   ```
   python3 tools/claude/art_loop.py queue \
     --id lm-walltop-b-20261121 --prompt-file p.txt \
     --n 2 --w 512 --h 512 --seed 2125475105 --tile \
     --ref grok_art/style_crop.png --ref-strength 0.55
   ```

   Optional: `--mode new|sketch|edit --init a.png --mask m.png`
   `--strength 0.7 --key '#00FF00'`. `--no-publish` writes the files
   without pushing (tests / a dry run). The command writes the job
   JSON and any `.init.b64` / `.mask.b64` / `.ref.b64` in one commit
   and publishes that job-only commit to Foxboard `main`.

2. **`F.forgeFiles({mode, prompt, initCanvas|id, refCanvas|refSrc,
   strength, tile, seed, w, h, n, ...})`** through
   `node tools/claude/fb.js`, then `saveForge`, then a job-only push
   to `main`. Same fields.

A hand-written `forge/jobs/<id>.json` plus the matching b64 files also
works if they land on `main` in the same commit.

### Job fields

| Field | What to put |
|---|---|
| `prompt` | One complete instruction, max 1500 characters. See the template below. |
| `n` | 2 or 3 for a style-lock or a pick sheet (`n` ≤ 4). |
| `w`, `h` | **256–1024 and a multiple of 64.** `render_one.py` clamps and floors anything else; `art_loop.py queue` rejects it with a clear error. Game asset sizes that are not valid Forge sizes (Lethemoor ~190×500, ~660×665, 184×512, ~400×900) should be rendered at a valid size (for example 576×1024 or 512×512) and then cut or resized with `art_loop.py cut --height`. |
| `seed` | Always set one integer. Take `k` is rendered at `seed+k`. |
| `key` | `"#00FF00"` (or the game's key) for cut-out sprites; omit for full-frame textures and skies. |
| `tile` | `true` for Lethemoor 512×512 floor/wall textures (adds sd.cpp `--circular`). Only affects the FLUX path (`new` / `sketch` / flux edit), not klein edits. For Hunter's different tile rule, see **§9**. |
| `mode` | `new` (text-to-image, or a new subject with `ref`), `sketch` (img2img from `init`), `edit` (Magic edit), `expand`, `upscale`. |
| `strength` | Img2img follow, **0.3–0.95**. The renderer defaults to **0.7** if it is missing on a sketch job. The Foxboard Follow slider defaults to 0.87; a flat sketch needs ≥ 0.75 or FLUX schnell can leave it flat. Subtle vary is 0.35, strong vary is 0.6. |
| `init` | `forge/jobs/<id>.init.b64` (`png:` + base64). Means "start from this picture" (same subject, or a rough layout). **`mode` must be `sketch`** (or edit/expand/upscale). If you set `init` on `mode: "new"`, the queue and the renderer **switch the job to sketch and warn**. They will not silently ignore it. Forge takes exactly one `init`. |
| `mask` | Required with `init` for `edit` (and expand). White = change, black = keep. |
| `ref` | `forge/jobs/<id>.ref.b64`. Style-board workaround for a **new** subject. See §3. Cannot be combined with `init`. |
| `ref_strength` | 0.15–0.85, default 0.55. How hard to follow `ref`. Higher stays closer to the style board. |

### `edit` (Magic edit)

Needs **both** `init` and `mask`. The mask is white = change, black =
keep. The edit runs on FLUX.2 klein at `side` (default 512), so `w` /
`h` and `tile` do not apply to it. Do not go back to schnell inpaint.

### Prompt template (paste, then fill the brackets)

Write the prompt as short labeled blocks, not a loose paragraph.

```
STYLE / GAME: [one locked sentence for this game, unchanged from the
style guide.]

SUBJECT: [literal description. Name which hand holds what, what
replaces a missing hand, hair/hat/bald, face covered or not, laterality
of every tattoo, sleeve, satchel or armband. Paste the identity-card
trait string verbatim; do not rewrite it from memory.]

VIEW: [camera and pose in screen terms, e.g. "full body, feet at the
bottom edge, face pointing at the BOTTOM of the frame" or "overhead
wall cap, seen straight from above".]

CANVAS: [how much of the frame the subject fills; "whole figure in
frame with margin all round"; "fills the frame edge to edge" for a
texture.]

PALETTE: [the locked swatches, and which accent is allowed. Say what
color is banned or limited, e.g. "blood red only on the stole".]

LIGHT: [Hunter concept: key from upper left, hard toon bands, orange
rim on the hero. Lethemoor world art: lit flat, no baked lantern
highlights or glows — the in-game lantern does the lighting.]

BACKGROUND: [sprites: "plain flat solid #00FF00, no scenery, no floor
shadow, no text, no border". Textures: "edge to edge, no frame, no
border stones, no caption".]

AVOID: [banned props, readable text, logos, named IP, the wrong style
("no comic ink" on a Lethemoor texture; "no painterly photorealism" on
a Hunter ink sprite), and any trait the last take invented.]
```

**Why this works:** Vague pose words made Grok repeat one pose or swap
sides. Naming feet, pointing at a screen edge, and saying what replaces
the hand fixed those. A pasted trait string does not drift the way a
rewritten one does.

On Forge, the style sentence and the trait string are doing more of the
work than they did on Grok, because Forge cannot truly "see" an attached
style reference. See §3.

### Game style sentences (locked; do not mix them)

**Hunter** (`docs/style-guide.md`, locked Nov 20): ink and blood on
real-time 3D. Concept art, voice-dialogue portraits and UI are 2D comic
ink, not in-game sprites. Thick confident black outlines, 2–3 hard
light bands, flat colour, large solid-black shadow shapes, no PBR
shine, no fine noise. Palette: ink black `#0D0C0C`, charcoal `#2B2A2E`,
bone white `#EEEAE0`, blood red `#B01818`, hero accent demon orange
`#FF6A1A`. One accent per realm as in the style guide. Silhouette
first. No named IP. Rook keeps the iron mask; Vesper has no horns and
a candle halo.

**Lethemoor, current game** (`docs/art_needs.md`, Nov 19): painted, not
pixel art. Moody, wet, gothic, 1890s harbour. Faceless enemies (veils,
sacks, hoods, shadow — no face). Light the art flat. Palette is amber
and ink: warm gold light, blue-black dark, desaturated bone, moss,
rust; blood red only for vampires and danger. Match existing walls,
floor and the dock thrall (`docs/renders/fp_start.png`). The older
64 px / `#00FF00` / 16-colour pixel rules in `grok_art/glaze/HANDOFF.md`
still describe work already in `glaze/final/`. Do not start new pixel
characters unless Duff reopens that pipeline.

---

## 3. Pictures you attach: `init` vs `ref`

This is the main place the first version of this guide was wrong.
Grok's `GenerateImage` can take an attached image as a style or
character reference. **FLUX.1-schnell, as Forge runs it, cannot.**
sd.cpp's IP-Adapter supports only SD 1.5 and SDXL. There is no FLUX
Redux hook on this stack. See `docs/DECISIONS.md`.

### `init` + `mode: "sketch"` — "start from this picture"

The model img2imgs from the whole `init`, resized to `w`×`h`. At
strength below about 0.95 it keeps that picture's layout and
silhouette. Use it for:

- a rough layout or a flat sketch (strength ≥ 0.75)
- variations of an approved take (0.35 subtle, 0.6 strong, seed kept)

Do **not** use a character sprite as `init` when you want a *new*
creature in the same style. That is the opposite of "copy only the
technique and palette." The wording "Copy ONLY the technique and
colour palette of the attached image; do NOT copy its character or
props" **has no effect on Forge.** That wording is for Grok or Canva.

Forge takes exactly one `init`. There is no multi-reference.

### `ref` + `mode: "new"` — style-board workaround

`ref` is the closest Forge can get to a style reference for a **new**
subject. `forge/style_ref.py` shuffles overlapping crops of the
reference into a board (so a character does not sit in the same place)
and schnell img2imgs from that board at a high strength (0.72–0.92,
mapped from `ref_strength`). Palette and brushwork can bleed through.
This is **not** IP-Adapter and will not hold a character identity.

- Prefer a **style-only crop** (brushwork and outlines, no face, no
  unique silhouette, no text).
- Default `ref_strength` is 0.55. Higher follows the board more;
  too high can still leak shapes from a character photo.
- You cannot set `ref` and `init` on the same job.

### What actually keeps a character consistent on Forge

The locked style sentence, a verbatim trait string, seed reuse, and
`init` + sketch when you are editing an approved take. Same-seed
rerolls that name the one failed detail (`tasks/lessons.md`) are still
the right fix when the rest of the take is already good (Rook's iron
mask, "no horns" on Vesper).

**Why this works (and why the first guide failed):** a paragraph of
style words plus an attached file looked like Grok's method, but Forge
never fed that file to a style encoder. The jobs that "attached a
reference" and used `mode: "new"` were plain text-to-image.

---

## 4. Palette and outline rules

- Stay inside the game's locked swatches. One strong accent, not a
  rainbow. Faction or realm colors stay on their own side.
- Pin the accents that must survive a shrink or a 16-colour cut.
- Outlines: Hunter ink uses a thick, even dark outline around the
  whole figure. Lethemoor painted textures are the opposite: "no
  outlines, no comic ink".
- No readable text, fake lettering, logos or brand badges unless Duff
  asked for that exact wording. Leave signs, posters and banners blank;
  set real type afterward in Foxboard or with a script.
- The image provider may block gore words. Generate a milder take, then
  Magic-edit (`init` + `mask`) or finish the last details by hand.
  Phrase changes as edits to an existing image ("dark red stains", not
  "blood").

**Why this works:** palette and outline are how a batch still looks
like one game. Text in a generated image is almost never spelled right.

---

## 5. Seeds and consistency

Grok's recorded workflow did not use a seed. Consistency came from the
approved reference and a verbatim trait string. Forge does expose a
seed — keep using it, on top of the trait string, not instead of a
picture when `init` or `ref` actually applies.

- Always set `seed`. Take `k` uses `seed+k`. Log the take-0 seed.
- To retry one missed detail, queue a same-seed job whose prompt names
  that one failed detail.
- Foxboard's Reuse action resubmits prompt + seed.

**Why this works:** a seed repeat plus one named fix stays on-model. A
rewritten prompt with a new seed often fixes the mask and breaks the
pose.

---

## 6. One asset type at a time, then batch

- If the style or the setting is new, draft 2–3 pieces and stop.
- Put them on a contact sheet at a size Duff can read on a phone.
- Ask him to pick, or to change one thing, before you make the rest.
- Once he says "finish the rest in this style", batch that type only.
- A later type (backgrounds after characters, env tiles after figures)
  gets a fresh 2–3 draft lock.
- Write any flavor text from the image you actually got, not from the
  brief.

**Why this works:** batching a guessed style multiplies one wrong
assumption across a week of work.

---

## 7. Self-checks before you show Duff

Run Foxboard's checker first, then look at the sheet yourself.

```
python3 tools/claude/art_loop.py score <id> --game lethemoor --kind sprite|texture|scene|hud [--aspect 0.37]
```

`score` flags key holes, floor shadow, stray marks / watermarks,
cropped head or sides, floating feet, off-palette colour, baked glow,
and texture seams, and writes `forge/out/<id>_sheet.png`. It is a
pre-filter: it cannot see faces, and Lethemoor's faceless rule still
needs your eye.

Then, for every take you plan to keep:

- Exact *game* size after `cut`, not only the Forge canvas.
- Flat key color, no scenery, no caption, no border (sprites).
- Nothing important touching a cell edge; feet on one baseline.
- Correct facing (named by screen edge). Laterality matches the
  identity card. Do not ship a mirrored copy of an asymmetric design.
- On-model: the verbatim traits are all visible. No extra horns, hats,
  lanterns, faces, or dropped masks.
- Lethemoor figures: faceless, lit flat, reads at ~390 px wide in the
  dark.
- Lethemoor textures: inspect the 3×3 preview `score` implies by the
  seam flag, or build one yourself. Early cobbles failed this way.

**If a check fails**

- Small area: Magic edit (`mode: "edit"` + `init` + `mask`) or a
  logged scripted retouch. Re-score after the fix.
- Wrong composition or identity: regenerate, with the failed detail
  named, preferably same seed.
- Save each revision under a **new filename**.

**Why this works:** Duff has been acting as the QA department. The
list is almost entirely things he or the agents already had to send
back.

---

## 8. Background removal and cleanup

Use Foxboard's cutter first, not a hand-rolled chroma key and not
Lethemoor's old `--shadow` script (that script is not in this repo):

```
python3 tools/claude/art_loop.py cut <id>/<take> out.png --height 640
```

`--key` is optional when the job JSON already has one. `cut` turns the
key to transparent (soft edge), crops to the subject, resizes, and
despills only a 3 px edge band so real key-ish colours inside the
subject (moss on a green key) survive.

- For cut-out sprites, set `"key": "#00FF00"` on the job. Forge
  `keyfix.py` then forces an exact-key background before you cut.
- Subtle idles and 1 px bobs should be done in code, not by asking
  the model for "the same image, 1 px lower".
- Left/right facings for a symmetric character: flip in code or PIL
  after cleanup. Do not regenerate the other facing, and do not flip
  a design with one-sided tattoos.

**Why this works:** cleanup is part of the art. Local edits keep
identity stable; a full redraw often adds a new mistake.

---

## 9. Sizes and Godot import

Use the size the game already documents. Render at a **valid Forge
size**, then cut or resize to the game size.

**Lethemoor** (`docs/art_needs.md`)

| Kind | Game size | Example Forge canvas, then cut |
|---|---|---|
| Standing figure (enemy, NPC) | ~190×500, feet at the bottom, facing you (dock thrall is 184×512) | 576×1024, then `cut --height 500` |
| Floor / wall texture | 512×512, seamless on all four sides | 512×512, `tile: true` |
| Floor / standing prop | 100–400 px tall, upright, facing you | 512×1024, then `cut` |
| HUD hand art | ~660×665, lower right, transparent | 640×640 or 768×768, then `cut` |
| Letter paper | ~600×800, torn edges, transparent | 576×768 or 640×832, then `cut` |
| App icon | 1024×1024, no transparency, must read at 48 px | 1024×1024 |
| Boss (full game, later) | ~400×900 | 512×1024, then `cut --height 900` |

Light it flat. Painted HUD and world art use **linear** filtering.
Enemies stay faceless. Delivery is PNG.

**Hunter** (`docs/style-guide.md`, `standards/09-art-assets.md`)

- Concept / lineup art from Forge is reference for 3D models,
  portraits and colour, not a sprite sheet to drop in as a character.
- In-game: low-poly humanoids, toon shading, thick screen-space
  outlines (~3 px at 720×1280), hero about 1/9 of screen height.

**Seamless tiles — the two games disagree, so follow the one you are
in.**

- Lethemoor wants 512×512 seamless textures. Ask for an edge-to-edge
  texture, set `"tile": true` on the Forge job (the old `lm-walltop`
  and `lm-sky` jobs asked for "seamless" in the prompt but did not set
  this flag), then inspect a 3×3 repeat or the `score` seam flag.
- Hunter's standard 09 says: never ask an image generator for a
  seamless tile; use one big painted surface and make the seams or
  repeats in code.

**Import settings**

- Commit the `.import` sidecars with a consistent preset. Do not
  leave Godot on "detect".
- Colour maps: sRGB, normal map **off**. Only `*_n` / `*_normal`
  files are normal maps.
- Fail the build if an import breaks, when the repo has that check.

**Why this works:** a beautiful painting that is the wrong aspect,
baked-lit, or imported as a normal map still fails in the game.
Phone-size readability is the real acceptance test.

---

## 10. Logging (`ART_LOG` and the handoff note)

Every kept take gets a row, including the ones Duff rejects.

| Date (America/Chicago) | Job id (`dh-*` / `lm-*`) | Seed (take 0) | `init` / `ref` | Verdict | Where it lives | Wired into the game? |
|---|---|---|---|---|---|---|

Also write down the prompt (the job JSON is the source of truth), known
issues and the fix you already tried, and flavor text only after it
matches the final picture. For a batch PR: a contact sheet, commit
SHAs, CI status, one honest weakest-spot line, and a status per asset
(wired, needs a rig, or unused).

Hunter already has `docs/ART_LOG.md`. Lethemoor logs live in
`docs/art_needs.md` (tick when wired), `docs/HANDOFF_LOG.md`, and
`grok_art/glaze/HANDOFF.md`. Add a row; do not start a third
conflicting log.

**Why this works:** the next session cannot see your chat.

---

## 11. Differences from what Claude does today

1. **Do not pretend Forge can use an attached image the way Grok can.**
   Many Lethemoor jobs (`lm-walltop`, `lm-sky`, `lm-thrall-dockwoman`)
   and Hunter's early `dh-*` jobs have no `init` and no `ref`; the
   prompt just says "realistic oil-painted…". That is still a text-only
   schnell job. For a new subject, add `ref` (style-only crop) and
   understand it is a style-board workaround. For an approved take you
   want to vary, use `init` + `sketch`. The "copy only the technique"
   sentence does nothing on Forge.

2. **Lock one asset type with 2–3 picks on a contact sheet, then
   batch.** Do not explore several styles or a full set before Duff
   has chosen. Write flavor from the picture you got.

3. **Run `art_loop.py score` (and `cut`) before Duff sees the take.**
   Catch dropped masks, invented horns, leftover key fringing, baked
   lantern light, and laterality. If the composition is already right,
   Magic-edit or script-edit the broken area instead of rolling a new
   picture.

4. **Use Forge's actual switches, not only a longer prompt.** Always
   set and reuse `seed`. Set `"tile": true` on Lethemoor floor and wall
   textures (`lm-walltop` and `lm-sky` asked for seamless in prose and
   left `tile` unset). Attach `init` only with `mode: "sketch"` (or
   let the queue switch and warn). For Hunter, do not ask the
   generator for a seamless tile (`standards/09-art-assets.md`).

5. **Be painfully literal, light Lethemoor art flat, queue on
   Foxboard main, and log the take.** Name facings by screen edge,
   which hand holds the prop, "bald, no hat", "carries nothing",
   "face completely covered". Leave signs blank. Do not bake lantern
   highlights into a floor or wall. After a pick, log the job, the
   seed, the verdict, and whether the art is wired.

---

## Quick checklist (every Forge job)

- [ ] I fetched and read this game's current style guide and art-needs
      list. I am not using a retired pipeline.
- [ ] The prompt is public-safe (no Duff likeness, no private info, no
      named IP).
- [ ] Style is already locked for this asset type, or this job is one
      of 2–3 lock drafts, not a silent batch.
- [ ] If I am varying an approved picture, I set `init` and
      `mode: "sketch"` (or I am ready for the queue to switch and
      warn). If I want a new subject with a style hint, I set `ref`
      and a style-only crop, and I know that is a workaround.
- [ ] Trait string, laterality, palette, light, background/key, size,
      and avoids are explicit.
- [ ] `seed` is set. Lethemoor tiles have `"tile": true`. Cut-out
      sprites have `"key": "#00FF00"`. `w`/`h` are 256–1024 and a
      multiple of 64.
- [ ] I queued onto **Foxboard `main`** (via `art_loop.py queue` or a
      job-only commit), then ran `score` and `cut` before showing Duff.
- [ ] Contact sheet + one honest weak spot + a pick request.
- [ ] Log row written. Finals only, on a **game-repo** feature branch.
      No push of game code to main, no force-push.
