# The studio mascot in every game (Duff's rule, Nov 26, 2026)

For any coding AI (Claude, Grok, Codex, ChatGPT...) or person working on a 3 Eyed Fox Studios game.

## The rule
- The studio mascot, the **three-eyed fox**, appears in **every** game.
- It is a **cameo, not a pal**: no companion, no sidekick, no follower, no helper the player keeps.
- It shows up as a **small event that matters but never ruins a run**: it costs or nudges something
  the player notices (a turn, a moment, a bit of noise, a dropped item), never a death, a lost save,
  a failed level or anything the player can't recover from.
- Rare: at most once a run or once a night/level, so it stays a surprise.
- **Duff approves the fox art on a tappable card before anything is built.** Use the studio look
  (distressed gold, tattoo-inspired, three eyes, the ear jewelry; godot-game-starter docs/MARKETING.md "Brand"), make
  it in Foxboard Forge first, then show him. No fox art ships without his yes.
- The example Duff gave (Rush): on a quiet service a fox gets loose in the kitchen and costs a turn.

## Exceptions (Duff's calls)
- **The Devil You Owe (Hunter):** the fox is **Cain's pet**, not a cameo (Duff, Nov 26).
- **DuffQuest:** besides its cameo, the fox also joins the overworld animals, with the raccoons.

## How to build one
1. Write the game's cameo idea (one line) in this file's "This game" section and the handoff log.
2. Get the fox art approved by Duff on a card (see above).
3. Build it with a TUNE slider for its odds/cost and an autoplay PASS line, like any feature.
4. Log it in the handoff (CLAUDE.md "Where things stand" + the handoff log).

## This game: Lethemoor
- Idea (not approved yet, nothing built): at most once a night, three small gold lights blink in the fog ahead. The player may take it for a horror; it's the fox. It yelps and bolts, making one noise pulse (thralls hear it) and +5 dread. Never grabs, never kills, never spends oil.
- Rules go in `scripts/sim/` like every rule (pure, tested); the view only draws it.
- Before building: Duff OKs the fox art on a card. It must still read as the faceless-horror world's odd one out, not a horror.
