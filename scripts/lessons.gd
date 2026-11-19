## The first night teaches itself: one field note per system, shown the first time it matters.
## Pure: looks at a Night, never at nodes. The view decides how to show a card and remembers
## which ones the player has seen.
extends RefCounted

const Fog = preload("res://scripts/sim/fog.gd")

## Danger first: if a thrall and a letter turn up together, the thrall gets the card.
const ORDER := ["goal", "stalker", "rose", "lunge", "horror", "panic", "noise", "hook", "slick", "flicker", "letter", "flask", "hood", "oil", "dread", "map"]

const CARDS := {
	"goal": ["RING THE BELL",
		"The bell hangs somewhere in this ward. Reach it and ring it to end the night.\n\nSwipe up to step, down to back away, left or right to turn. WAIT waits a turn. (Rather have buttons? MENU, MOVE BUTTONS.) Every move, even a turn, is one turn. The dark moves when you do."],
	"oil": ["OIL IS YOUR CLOCK",
		"The amber bar is your oil. NORMAL burns 1 a turn, BRIGHT burns 2, HOODED burns none. Changing the lantern is free.\n\nThe oil you still have when the bell rings is your score."],
	"hood": ["HOODED",
		"Shuttered, you burn no oil and nothing sees you past arm's reach. But you see nothing either, and every turn in the dark feeds your dread."],
	"dread": ["DREAD",
		"The red bar. It climbs in the dark and when something finds you. Light brings it down.\n\nPast the halfway mark the flame starts lying to you. When it fills, your hands shake and you spill 5 oil."],
	"horror": ["THRALLS",
		"They come to light. BRIGHT is seen from 8 tiles, NORMAL from 5, HOODED only up close. One beside you on its turn is death.\n\nThey shamble, a step every other turn. But two tiles off they crouch, then lunge, and one held under BRIGHT light two turns stops shambling. Close up they make no sound at all. Wet prints on the stones mean one passed here."],
	"lunge": ["IT LUNGED",
		"Two tiles off and seeing your light, a thrall crouches for a turn, then closes the gap in one jerk. Then it must rest a few turns.\n\nMove now: back off, hook it, or step round a corner. Standing still is death."],
	"rose": ["THE DEAD GET UP",
		"Not every body is dead. Some lie still till you've walked past and look away, then rise behind you.\n\nGetting up costs it a turn. Keep bodies in front of you, or give them a wide berth."],
	"stalker": ["THE BRIDE",
		"She cannot move while she is lit and you are looking at her. Turn away or let the light fall, and she comes two steps at a time.\n\nBack away from her. Never turn your back."],
	"flicker": ["THE FLAME GUTTERS",
		"A flicker means something you can't see stands within 3 tiles. It won't tell you where."],
	"letter": ["LETTERS",
		"Pages nailed up in the dark. Stand on one with the lantern on BRIGHT to read it. Each letter read is worth 5 oil on your grade."],
	"flask": ["OIL FLASK",
		"Walk over it and the lantern drinks it: +10 oil."],
	"map": ["THE MAP",
		"Top right is what you remember. A red X marks where you last saw a thrall. It may not be there any more."],
	"noise": ["NOISE",
		"They hear as well as they see. Walking, turning and waiting are quiet. A hook blow carries 4 tiles, a swing at nothing 3, a spark 3, pouring 2, and fire crackles 3 tiles every turn it burns.\n\nWhat hears it comes to look, round corners too. Fire draws them in, and they walk into it."],
	"hook": ["THE BOATHOOK",
		"Tap HOOK to swing at the first thing up to 2 tiles ahead. It's knocked back a tile and can't move for 2 turns.\n\nEvery hit bends the hook. After 3 it's useless. A swing at nothing costs the turn."],
	"slick": ["OIL SLICK",
		"POUR soaks the tile in front of you (3 oil). Pour again to make it longer. Back off, keep looking at it, and tap SPARK (1 oil).\n\nThe fire burns 3 turns. Whatever stands in it burns, and you can't walk through it. Don't stand in your own oil."],
	"panic": ["PANIC",
		"Your dread filled. Your hands shook and oil spilled. Get back into the light to steady them."],
}

const GRADE_LINE := "Grade = oil left + 5 per letter read.\nS 35+  ·  A 29+  ·  B 23+  ·  C 18+  ·  D"


## The next card to show, or "" if none is due. `event` is the turn's headline event.
static func due(game, seen: Dictionary, event: String = "") -> String:
	for id: String in ORDER:
		if not seen.has(id) and _now(id, game, event):
			return id
	return ""


static func _now(id: String, game, event: String) -> bool:
	var fog = game.fog
	match id:
		"goal":
			return true
		"oil":
			return game.turn >= 3
		"hood":
			return game.setting == Fog.Lantern.HOODED
		"dread":
			return game.dread >= 25
		"horror":
			return game.thralls.any(func(th): return th.get("kind", "thrall") == "thrall" and not th.get("gone", false) and not th.get("lying", false) and fog.get_state(th.pos) == Fog.LIT)
		"lunge", "rose":
			return event == id
		"stalker":
			return game.thralls.any(func(th): return th.get("kind", "thrall") == "stalker" and not th.get("gone", false) and fog.get_state(th.pos) == Fog.LIT)
		"flicker":
			return game.flickers()
		"letter":
			return event == "letter_dim" or game.room.letters.any(func(p): return not game.letters_read.has(p) and fog.get_state(p) == Fog.LIT)
		"flask":
			return game.flasks_left.any(func(p): return fog.get_state(p) == Fog.LIT)
		"map":
			return game.thralls.any(func(th): return not th.get("gone", false) and th.last_seen != null and fog.get_state(th.pos) != Fog.LIT)
		"panic":
			return event == "panic"
		"noise":
			return event == "heard"
		"hook":
			return game.get("hook_wear") > 0
		"slick":
			return event == "poured" or game.thralls.any(func(th): return not th.get("gone", false) and fog.get_state(th.pos) == Fog.LIT)
	return false
