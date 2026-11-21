# Art generation guide for Claude

How the Grok Bot art agents get results Duff likes, mapped onto Foxboard Forge
(`duffpowell-commits/Foxboard`). Read this before you queue a Forge job for
**Hunter** or **Lethemoor**.

- **Quase · Art Team** makes painted graphic-novel sprites, portraits, scenes
  and UI (Chaos, and Hunter concept / UI art).
- **Glaze · Lethemoor Art** makes Lethemoor art: first the old 64 px pixel
  pipeline, now the painted 512×512 wall and floor textures (and other
  first-person slice art) after the Nov 19 first-person pivot.

This file does not invent techniques those agents do not use. Forge-only
controls (seeds, `tile: true`, `keyfix.py`, Magic edit) are called out as
Forge features that stand in for a Grok habit, not as something Grok itself
exposed.

**Forge prompts and outputs are public.** Never put Duff's likeness, private
info, real names of living people, or anything that should stay off the
public internet in `forge/jobs/<id>.json`.

---

## Sources (so later sessions can check)

- Grok art skills: `game-art-delivery-pipeline`, `game-art-batch-pipeline`,
  `pixel-sprite-generate-and-clean`, `getting-started`.
- Transcripts of Quase (`81b2f3dd-ab12-4901-b8dd-b37f5f5a32be`) and Glaze
  (`b17145c5-8d33-409a-a57c-611724f21f4f`), Nov 2026. The transcript tool
  returned the chat, not the hidden `GenerateImage` tool calls, so exact
  prompt wording is taken from files the agents wrote: Lethemoor
  `grok_art/glaze/HANDOFF.md`, `grok_art/glaze/showcase/README.md`, and
  `grok_art/glaze/env/round1/process_tiles.py`.
- Foxboard `README.md`, `CLAUDE.md`, and real job JSON under `forge/jobs/`
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
   content, file names and sizes. Glaze almost started a 48 px pixel batch
   after Lethemoor had already switched to painted 512 px first-person art
   (`docs/art_needs.md`, Nov 19). Always `git fetch` and read the current
   docs before generating.
2. **Lock the style with 2–3 drafts** of one new asset type. Show Duff.
   Do not batch until he says the look is right. After that, you may batch
   that type without asking about style again. A new type (characters vs
   scenes, or a new realm) gets its own lock. Quase was told: finish the
   characters in the locked sprite style, then stop and get background
   drafts approved separately.
3. **Build a reference kit and keep it in the repo** before the batch:
   identity cards, a style-only crop for scenes, a prop / setting guide.
4. **Generate one subject per job**, with the references attached and an
   explicit prompt (style, setting, palette, pose or framing, and what to
   exclude).
5. **Self-check, then fix locally** if a small area is wrong. Regenerate
   the whole image only when composition or identity is wrong.
6. **Preview with a contact sheet**, one honest weakest-spot line, and a
   clear approve / fix / hold ask. Do not dump a pile of unreviewed takes
   on Duff.
7. **Handoff only the finals** (plus notes). Log the job, seed, verdict
   and known issues. Commit on a feature branch, never main, never a
   force-push. Do not overwrite files that already exist on the default
   branch; put new art beside them. Do not touch code, scenes or rigs
   unless asked.

**Why this works:** Duff's "love it, now finish the rest in the same
style, and show me backgrounds again before you go on" is the quality
gate. Most of the art he has sent back failed a check the agent could
have run first (stray text, off-palette color, leftover backgrounds,
wrong laterality, a description that did not match the picture).

**On Foxboard:** queue `forge/jobs/<id>.json` as in Foxboard `CLAUDE.md`.
Wait with `python3 tools/claude/forge_wait.py <id>...`. Copy approved
takes into the game repo's art drop (Hunter `docs/art/`, Lethemoor
`grok_art/`) on a feature branch, or use Send to game for the Lethemoor
inbox. Do not commit 55 MB of rejected raws; keep those off the PR
(Glaze left rejects on the machine and said so).

---

## 2. Prompt structure (Forge job fields)

A Forge job is a JSON file at `forge/jobs/<id>.json`. The fields that
matter for this guide:

| Field | What to put |
|---|---|
| `prompt` | One complete instruction. See the template below. |
| `n` | 2 or 3 for a style-lock or a pick sheet (`n` ≤ 4). |
| `w`, `h` | Multiples of 64, up to 1024. Use the game's size table, not a default 512×768 unless that is the spec. |
| `seed` | Always set one integer. Take `k` is rendered at `seed+k`. |
| `key` | `"#00FF00"` (or the game's key) for cut-out sprites; omit for full-frame textures and skies. |
| `tile` | `true` for Lethemoor 512×512 floor/wall textures (adds sd.cpp `--circular`). See §6 for Hunter's different rule. |
| `mode` | `new` for a first take. `sketch` (img2img from `init`, `strength` 0.3–0.95, lower = closer) when you have an approved reference or a sketch. `edit` + `mask` to fix a small area (FLUX.2 klein). |
| `init` / `mask` | Paths to `forge/jobs/<id>.init.b64` and `.mask.b64`. This is how you attach a style anchor or the previous approved take. |

### Prompt template (paste, then fill the brackets)

Write the prompt as short labeled blocks, not a loose paragraph. Glaze's
working pixel template (from `HANDOFF.md` §3) and Quase's locked sprite
briefs both do this: style first, then the subject, then view, canvas,
palette, light, background, and avoids.

```
STYLE / GAME: [one locked sentence for this game, unchanged from the
style guide. For a new character in an existing style, start with:
"Copy ONLY the technique and colour palette of the attached image;
do NOT copy its character or props."]

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

**Why this works:** Vague pose words ("contact / passing", "facing
left", "the lamp fuses into his body") made Grok repeat one pose, swap
sides, or ignore the change. Naming feet frame by frame, pointing at a
screen edge, and saying what replaces the hand fixed those. A pasted
trait string does not drift the way a rewritten one does.

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
§1–6 still describe work already in `glaze/final/`. Do not start new
pixel characters unless Duff reopens that pipeline.

---

## 3. Style anchors and reference images

This is the main consistency trick. A paragraph of style words is not a
substitute for the approved picture.

**Identity card (one per character), kept in the repo:**

- Paths to the approved front, back and portrait.
- 3–5 must-keep traits as **one verbatim prompt string** (example from
  Quase's Chaos work: Teodor's skin tone, grey beard, and rag). Paste
  that string unchanged into every later prompt.
- A laterality list (which side each tattoo, armband, satchel or prop
  is on). When a back view disagrees with the front, the approved art
  wins, and you do not mirror an asymmetric sprite to make the other
  facing.
- Things to avoid (hats Grok likes to invent, horns nobody asked for,
  a lantern copied off the style anchor).
- Attach the hero images to the job as `init`, and use `sketch` at a
  strength that follows the identity without flattening it. If Forge
  cannot take several refs, attach the best approved view and keep the
  other paths listed in the identity card so you can check against them.

**New creature or prop in the same style:** attach the approved style
anchor, but do **not** say "match this exact character". Use the line
that stopped Glaze's first enemies from all coming back as the
skull-faced lantern-bearer:

> Copy ONLY the pixel technique and colour palette of the attached
> image; do NOT copy its character or props.

For Lethemoor painted work, say "painted technique and colour palette"
instead of "pixel". Spell out "carries NOTHING" and "no skull, no
lantern, no hat" when those belong only to the anchor. If the anchor
still bleeds through, drop it and attach the character's own earlier
passing take instead (that is how the Faceless Docker's backward knees
finally read).

**Scenes and backdrops:** do not attach a full character sprite as the
style reference. Use a close-up crop of approved brushwork and outlines
with no identity and no text. Open the prompt with a preamble that
copies only technique and palette. Treat photo references as layout
only. Attach the prop / setting guide (approved props and banned props
for the era) so the model does not invent armored vans, regime
barriers, or off-era furniture.

**Why this works:** image models copy props and faces from a full
character reference unless you forbid it. Quase's scene drafts went
too realistic, or picked up character details, until the style-only
crop was used. Glaze's Stalker only passed once the prompt said the
face was completely covered and the creature carried nothing; without
that, the "one warm lantern accent" in the base template rebuilt the
hero.

---

## 4. Palette and outline rules

- Stay inside the game's locked swatches. One strong accent, not a
  rainbow. Faction or realm colors stay on their own side.
- Pin the accents that must survive a shrink or a 16-colour cut (bone
  white, blood red, near-black, lamp glow, Hunter's demon orange).
  Plain median-cut quantization ate the Red Death's white mask and
  blood red until Glaze locked those colors and k-means'd the rest.
- Outlines: Hunter ink uses a thick, even dark outline around the
  whole figure (Duff asked for a slightly thicker outline on a Chaos
  sprite and noticed when it only thickened a little). Lethemoor
  painted textures are the opposite: "no outlines, no comic ink".
- No readable text, fake lettering, logos, brand badges or
  license-plate glyphs in the image unless Duff asked for that exact
  wording. Leave signs, posters, banners and stamps blank; set real
  type afterward with a script or in Foxboard. Quase kept seeing
  gibberish captions until this became a hard rule.
- Content: follow the game's rules (Lethemoor faceless enemies; no
  named IP). The image provider may also block gore words (`blood`,
  `nailed`, `jammed`, `caved in`, `fatal wound`). Glaze's workaround
  was to generate a milder take, then edit the existing image ("dark
  red stains", "ribs bent outward like a burst cage") or finish the
  last details by hand at final size. Do not keep retrying blocked
  wording.

**Why this works:** palette and outline are how a batch still looks
like one game. Small accents vanish in cleanup unless you protect
them. Text in a generated image is almost never spelled right.

---

## 5. Seeds and consistency

Grok's `GenerateImage` path, as recorded in the agents' handoff notes,
did **not** use a seed. Consistency came from the approved reference,
the verbatim trait string, and "same character, same style, change
only X" edit prompts.

Forge does expose a seed, and Claude already uses it well. Keep doing
that, on top of the reference kit, not instead of it:

- Always set `seed`. Take `k` uses `seed+k`. Log the take-0 seed in
  `ART_LOG`.
- To retry one missed detail (Rook's iron mask, "no horns" on Vesper),
  queue a same-seed job whose prompt names that one failed detail
  (`tasks/lessons.md`). This is a Forge lesson, and it is the right
  tool when the rest of the take is already good.
- Foxboard's Reuse action resubmits prompt + seed. Subtle / strong
  variations keep the seed and change `strength` (0.35 same layout,
  0.6 reworked details).
- Do not rely on a new random seed to "maybe get the mask this time"
  while rewriting the whole prompt from memory.

**Why this works:** a seed repeat plus one named fix stays on-model.
A rewritten prompt with a new seed often fixes the mask and breaks
the pose, or the other way around.

---

## 6. One asset type at a time, then batch

- If the style or the setting is new, draft 2–3 pieces and stop.
- Put them on a contact sheet at a size Duff can read on a phone.
- Ask him to pick, or to change one thing, before you make the rest.
- Once he says "finish the rest in this style", batch that type only.
- A later type (backgrounds after characters, env tiles after
  figures, a new district) gets a fresh 2–3 draft lock.
- Write any flavor text from the image you actually got, not from the
  brief. Duff rejected Revenant flavor that described a wound the
  picture did not show.

**Why this works:** batching a guessed style multiplies one wrong
assumption across a week of work. Quase's first "regime" backdrops
were technically on-style and still wrong for the modern-city setting;
two modern drafts would have caught that before a full scene set.

---

## 7. Self-checks before you show Duff

Do these on every take you plan to keep. If a game repo has an
automated art check, run it. Then look at the image, including a
zoomed crop of the risky area and a downscale to phone size.

**Every sprite or standing figure**

- Exact canvas size the game asked for.
- Flat key color, no scenery, no caption, no border.
- Nothing important touching a cell edge; the whole figure is in
  frame; feet sit on one baseline.
- Correct facing (named by screen edge). Laterality matches the
  identity card. Do not ship a mirrored copy of an asymmetric design.
- Attack or action frames are real strike poses, not a tinted idle.
- On-model: the verbatim traits are all visible. No extra horns, hats,
  lanterns, faces, or dropped masks.
- No readable junk text.

**Lethemoor painted figures and HUD**

- Faceless. Lit flat (no baked lantern bloom). Feet at the bottom
  edge, facing the camera, about 190×500 for standing enemies (see
  the size table). Reads at ~390 px wide in the dark.

**Textures**

- Exact 512×512 (or the stated strip size). Edge to edge, no picture
  frame. Lit flat.
- Preview a **3×3 repeat** (Glaze writes these under `tiles_3x3/`)
  and a zoomed crop. If a grid, bevel or border shows, it is not
  seamless. Early cobbles failed this way.
- Match the existing granite / stone palette, not a new one.

**If a check fails**

- Small area: inpaint or Magic edit (`mode: "edit"` + mask), or a
  logged scripted retouch (Glaze stamped leaves out of the wet floor,
  pushed Revenant ribs at 64 px, wrapped tile edges in
  `process_tiles.py`). Re-check after the fix.
- Wrong composition or identity: regenerate, with the failed detail
  named, preferably same seed.
- Save each revision under a **new filename**. Chat and some previews
  cache same-name images.

**Why this works:** Duff has been acting as the QA department. The
list above is almost entirely things he or the agents already had to
send back (Teodor's skin, chalk pastels off-palette, red-and-white
barriers, leftover grey backgrounds, leftover blue dress after a full
redraw, a face on Rook, horns on Vesper, flavor that did not match).

---

## 8. Background removal and cleanup

- For cut-out sprites, set `"key": "#00FF00"` on the job. Forge
  `keyfix.py` then forces an exact-key background (border flood plus
  enclosed key-tinted patches such as the shadow between legs) and
  leaves muted subject colors alone.
- If you still have to key a generated image yourself, **chroma-key
  by hue with a tolerance**, not by the exact hex. Grok's green came
  back JPEG-noisy, around `(4, 235, 12)`. A working test from
  `HANDOFF.md`: `g > 140 and g - max(r, b) > 70`. Use a shadow pass
  (Glaze's `--shadow`) to drop dark-green ground shadows and puddles.
- Crop to the subject, then resize with the right filter:
  nearest-neighbour for true pixel art, Lanczos for painted 512.
- De-spill green from the edges. Drop orphan pixels.
- Prefer a transparent PNG for anything that stands in the world or
  the HUD. Keep a green-key copy if the importer wants one.
- For pixel work that still needs a 16-colour cap, pin accents first,
  then quantize, then do hand fixes at final size in a small logged
  script.
- Subtle idles and 1 px bobs should be done in code, not by asking
  the model for "the same image, 1 px lower". That request comes back
  as a full repaint and the texture boils (movement test T4, plan B).
- Left/right facings for a symmetric (or accepted-as-symmetric)
  character: flip in code or PIL after cleanup. Do not regenerate the
  other facing, and do not flip a design with one-sided tattoos.

**Why this works:** the generator will not give you a perfect key or a
perfect palette. Cleanup is part of the art, not an afterthought.
Local edits keep identity stable; a full redraw often adds a new
mistake.

---

## 9. Sizes and Godot import

Use the size the game already documents. Do not invent a "close
enough" canvas.

**Lethemoor** (`docs/art_needs.md`)

| Kind | Size |
|---|---|
| Standing figure (enemy, NPC) | ~190×500, feet at the bottom, facing you (dock thrall is 184×512) |
| Floor / wall texture | 512×512, seamless on all four sides |
| Floor / standing prop | 100–400 px tall, upright, facing you |
| HUD hand art | ~660×665, lower right, transparent |
| Letter paper | ~600×800, torn edges, transparent |
| App icon | 1024×1024, no transparency, must read at 48 px |
| Boss (full game, later) | ~400×900 |

Light it flat. Painted HUD and world art use **linear** filtering.
Enemies stay faceless. Delivery is PNG.

**Hunter** (`docs/style-guide.md`, `standards/09-art-assets.md`)

- Concept / lineup art from Forge is reference for 3D models,
  portraits and colour, not a sprite sheet to drop in as a character.
- In-game: low-poly humanoids, toon shading, thick screen-space
  outlines (~3 px at 720×1280), hero about 1/9 of screen height
  (`docs/art/ink-3d/`).
- Source art still arrives through Foxboard into `grok_art/` and does
  not ship.

**Seamless tiles — the two games disagree, so follow the one you are
in.**

- Lethemoor wants 512×512 seamless textures. Ask for an edge-to-edge
  texture, set `"tile": true` on the Forge job (Claude's `lm-walltop`
  and `lm-sky` jobs asked for "seamless" in the prompt but did not set
  this flag), then inspect a 3×3 repeat. If a faint seam remains,
  heal only a thin opposite-edge band; Glaze's first plus-shaped blur
  left a dark cross on every join (`process_tiles.py`).
- Hunter's standard 09 says: never ask an image generator for a
  seamless tile; use one big painted surface and make the seams or
  repeats in code.

**Import settings** (both games; also Quase's Chaos upgrade)

- Commit the `.import` sidecars with a consistent preset. Do not
  leave Godot on "detect".
- Colour maps: sRGB, normal map **off**. Only `*_n` / `*_normal`
  files are normal maps (Import dock → Normal Map).
- Fail the build if an import breaks, when the repo has that check.
- Small images go into atlases once the game is wiring them
  (Hunter `standards/05-performance.md`).

**Why this works:** a beautiful 1024 px painting that is the wrong
aspect, baked-lit, or imported as a normal map still fails in the
game. Phone-size readability is the real acceptance test.

---

## 10. Logging (`ART_LOG` and the handoff note)

Every kept take gets a row, including the ones Duff rejects.

| Date (America/Chicago) | Job id (`dh-*` / `lm-*`) | Seed (take 0) | Refs attached | Verdict | Where it lives | Wired into the game? |
|---|---|---|---|---|---|---|

Also write down:

- The prompt (the job JSON is the source of truth; do not retype it
  from memory).
- Which identity card or style crop was attached.
- Known issues and the fix you already tried (same-seed reroll, local
  edit, dropped anchor).
- Flavor text only after it matches the final picture.
- For a batch PR: a contact sheet, commit SHAs, CI status, one honest
  weakest-spot line, and a status per asset (wired, needs a rig, or
  unused).

Hunter already has `docs/ART_LOG.md`. Lethemoor logs live in
`docs/art_needs.md` (tick when wired), `docs/HANDOFF_LOG.md`, and
`grok_art/glaze/HANDOFF.md` §10. Add a row; do not start a third
conflicting log.

**Why this works:** the next session cannot see your chat. A seed,
a job id and a verdict are how Claude (or Quase, or Glaze) picks up
without repeating a failed take.

---

## 11. Differences from what Claude does today

These are the gaps that show up when you compare Forge jobs and
Hunter's art log with the Grok agents' actual working method. They
are the five things to change first.

1. **Attach an approved style anchor (or a style-only crop) and a
   verbatim trait string. Do not describe the style from memory and
   call that a reference.** Many Lethemoor jobs (`lm-walltop`,
   `lm-sky`, `lm-thrall-dockwoman`) have no `init` image; the prompt
   just says "realistic oil-painted game art…". Hunter's early
   `dh-hero` / `dh-rook` / style-test jobs are the same: words only,
   no locked identity card. That is why FLUX schnell added horns
   nobody asked for on Vesper and dropped Rook's iron mask
   (`tasks/lessons.md`). Glaze only stopped cloning the lantern-bearer
   after "Copy ONLY the technique and palette… do NOT copy its
   character or props."

2. **Lock one asset type with 2–3 picks on a contact sheet, then
   batch. Do not explore three whole styles, or a full set, before
   Duff has chosen.** Hunter's Nov 20 log still had pixel, ink and
   puppet tests sitting in "awaiting Duff" in parallel, and the log
   itself went stale after the style was locked. Quase showed style
   options, then one sprite, then waited; backgrounds needed a second
   lock. Glaze showed two wall tops, two wet floors, two grates, two
   bell towers, and filed only the pick.

3. **Run the self-check and fix in place before Duff sees the take.**
   Claude's log often records the miss after the fact, then suggests a
   same-seed reroll. Keep the reroll, but first catch dropped masks,
   invented horns, leftover key-colour fringing, baked lantern light,
   readable junk text, and laterality. If the composition is already
   right, Magic-edit or script-edit the broken area (Glaze's rib push,
   leaf stamp, and seam wrap) instead of rolling a new picture that
   can introduce a new error.

4. **Use Forge's actual consistency switches, not only a longer
   prompt.** Always set `seed` and reuse it (this part Claude already
   does). Also attach `init.b64` for approved art, and for Lethemoor
   floor and wall textures set `"tile": true`. The `lm-walltop` and
   `lm-sky` jobs asked for a "seamless tileable texture" in prose and
   left `tile` unset, so seam fixing had to happen in post, the same
   way Glaze's first cobbles arrived with a border and would not tile.
   For Hunter, do not ask the generator for a seamless tile at all
   (`standards/09-art-assets.md`).

5. **Be painfully literal, light Lethemoor art flat, and write notes
   from the picture you got.** Name facings by screen edge, which hand
   holds the prop, what replaces a hand, "bald, no hat", "carries
   nothing", "face completely covered". Leave signs blank. Do not bake
   lantern highlights into a floor or wall (the old 256 px
   `floor_wet.png` was unused for that reason; Duff picked Glaze's
   flat-lit flooded floor). After a pick, log the job, the seed, the
   verdict, and whether the art is wired. Flavor text describes the
   final image, not the brief.

---

## Quick checklist (every Forge job)

- [ ] I fetched and read this game's current style guide and art-needs
      list (Hunter: ink on 3D; Lethemoor: painted 512, faceless, lit
      flat). I am not using a retired pipeline.
- [ ] The prompt is public-safe (no Duff likeness, no private info, no
      named IP).
- [ ] Style is already locked for this asset type, or this job is one
      of 2–3 lock drafts, not a silent batch.
- [ ] Approved `init` reference is attached, with the correct "copy
      only technique and palette" or identity-card wording.
- [ ] Trait string, laterality, palette, light, background/key, size,
      and avoids are explicit.
- [ ] `seed` is set. Lethemoor tiles have `"tile": true`. Cut-out
      sprites have `"key": "#00FF00"`.
- [ ] I keyed, cleaned, and self-checked (including a 3×3 tile preview
      or a phone-size downscale) before showing Duff.
- [ ] Contact sheet + one honest weak spot + a pick request.
- [ ] Log row written. Finals only on the PR. No push to main, no
      force-push.
