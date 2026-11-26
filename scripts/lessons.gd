## The first night teaches itself: one field note per system, shown the first time it matters.
## Pure: looks at a Night, never at nodes. The view decides how to show a card and remembers
## which ones the player has seen.
extends RefCounted

const Fog = preload("res://scripts/sim/fog.gd")

## Danger first: if a thrall and a letter turn up together, the thrall gets the card.
const ORDER := ["goal", "stalker", "rose", "torn", "down", "lunge", "behind", "horror", "panic", "noise", "hook", "slick", "flicker", "letter", "flask", "chalk", "hood", "oil", "dread", "map"]

const CARDS := {
	"goal": ["RING THE BELL",
		"A bell hangs somewhere in this ward. Ring it to end the night. It tolls by itself: follow the sound.\n\nSwipe up to walk, hold to keep going. Down backs away, sideways turns. Every move is a turn. The dark moves when you do."],
	"behind": ["BEHIND YOU",
		"A breath at your neck: something is that close and you are not looking at it.\n\nSwipe down with two fingers to spin round (two turns). Or keep walking.\n\n(Rather have buttons? MENU, MOVE BUTTONS.)"],
	"oil": ["OIL IS YOUR CLOCK",
		"The amber bar is your oil. NORMAL burns 1 a turn, BRIGHT burns 2, HOODED burns none. Changing the lantern is free.\n\nThe oil you still have when the bell rings is your score."],
	"hood": ["HOODED",
		"Shuttered, you burn no oil and nothing sees you past arm's reach. But you see nothing either, and every turn in the dark feeds your dread."],
	"dread": ["DREAD",
		"The red bar. It climbs in the dark and when something finds you. Light brings it down.\n\nPast the halfway mark the flame starts lying to you. When it fills, your hands shake and you spill 5 oil."],
	"horror": ["THRALLS",
		"They come to light. BRIGHT is seen from 8 tiles, NORMAL from 5, HOODED only up close. One beside you on its turn grabs you. The first time each night you tear free, spilling 10 oil (twice, your first nights). After that, it's death.\n\nThey shamble, a step every other turn. But two tiles off they crouch, then lunge, and one held under BRIGHT light two turns stops shambling. Close up they make no sound at all. Wet prints on the stones mean one passed here."],
	"lunge": ["IT LUNGED",
		"Two tiles off and seeing your light, a thrall crouches for a turn, then jerks a tile at you. Backing off doesn't stop it coming; it only buys room. Then it must rest a few turns.\n\nMove now: back off, hook it, or step round a corner. Standing still is death."],
	"torn": ["IT HAD YOU",
		"A thrall got its hands on you. You tore free, but the lantern slopped 10 oil. It is down for a few turns and has lost you: get away, or shove right past it.\n\nYour first nights give you two escapes like that. After that, one. The next one that reaches you keeps you."],
	"down": ["IT'S DOWN",
		"A hooked thrall, or one you tore free of, folds up on the stones for a few turns. Walk into it and you shove past: it's behind you then, so keep going."],
	"rose": ["THE DEAD GET UP",
		"Not every body is dead. Some lie still till you've walked past and look away, then rise behind you.\n\nGetting up costs it a turn. Keep bodies in front of you, or give them a wide berth."],
	"stalker": ["THE BRIDE",
		"She cannot move while she is lit and you are looking at her. Turn away or let the light fall, and she comes.\n\nHold your light on her and she can't bear it for long: she goes back into the dark. She always finds you again. When the night goes silent, she is close. Never turn your back."],
	"flicker": ["THE FLAME GUTTERS",
		"A flicker means something you can't see stands within 3 tiles. A red mark on the rim of the chart shows which way it is. Walls don't stop it: it may be in the next corridor."],
	"letter": ["LETTERS",
		"Pages nailed up in the dark. Stand on one with the lantern on BRIGHT to read it. Each letter read is worth 5 oil on your grade."],
	"chalk": ["CHALK ON THE STONES",
		"Someone came this way before you and chalked the forks. The arrows point toward the bell."],
	"flask": ["OIL FLASK",
		"Walk over it and the lantern drinks it: +12 oil (+8 on a Deeper Night)."],
	"map": ["THE MAP",
		"Top right is what you remember. A red X marks where you last saw a thrall. It may not be there any more. The amber bell shows where the bell hangs, once you have heard it toll."],
	"noise": ["NOISE",
		"They hear as well as they see. Walking, turning and waiting are quiet. A hook blow carries 4 tiles, a swing at nothing 3, a spark 3, pouring 2, and fire crackles 3 tiles every turn it burns.\n\nWhat hears it comes to look, round corners too. Fire draws them in, and they walk into it."],
	"hook": ["THE BOATHOOK",
		"Tap HOOK to swing at the first thing up to 2 tiles ahead. When it glows and reads HOOK IT!, something is in reach. It's knocked back a tile and is down for 2 turns: you can shove past it then.\n\nEvery hit bends the hook. After 3 it's useless. A swing at nothing costs the turn."],
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
		"torn":
			return event == "torn_free"
		"down":
			return event == "shoved_past" or game.thralls.any(func(th): return th.get("kind", "thrall") == "thrall" and th.get("stun", 0) > 0 \
					and not th.get("lying", false) and not th.get("gone", false) and fog.get_state(th.pos) == Fog.LIT)
		"chalk":
			return game.chalk.keys().any(func(p): return fog.get_state(p) == Fog.LIT)
		"behind":   # what the breath-at-your-neck sound means (audio.gd behind())
			return game.thralls.any(func(th): return not th.get("gone", false) and not th.get("lying", false) \
					and not game.in_view(th.pos) and game.room.reachable(th.pos, 2).has(game.hunter))
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


## The death card's "what happened": [where it came from, what would have saved you]. Pure: reads
## only the Night (8.5 plan, Nov 26: a first-timer should never die without knowing why).
static func death(game) -> Array:
	if game.killer == "":
		if game.cause.contains("oil under your own boots"):
			return ["YOUR OWN FIRE", "Back off a slick before you SPARK it, and never stand in lit oil."]
		return ["THE DARK", "Watch the amber bar. Flasks glint on the floor; walk over one for oil."]
	var f: Vector2i = game.facing
	var d: Vector2i = game.killed_from
	var side := "AHEAD"
	if d == -f:
		side = "BEHIND YOU"
	elif d == Vector2i(-f.y, f.x):
		side = "ON YOUR RIGHT"
	elif d == Vector2i(f.y, -f.x):
		side = "ON YOUR LEFT"
	var where := "%s, %s" % [side, "IN YOUR LIGHT" if game.killed_seen else "OUT OF THE DARK"]
	if game.killer == "stalker":
		return [where, "The bride can't move while she's in your light and you're looking at her. When the night goes quiet, turn round and find her."]
	if game.oil <= 0:
		return [where, "Your oil was gone, so it came with nothing to see it by. Pick up every flask you pass, and keep NORMAL unless you need BRIGHT."]
	var tip := ""
	if not game.killed_seen and side != "AHEAD":
		tip = "When the flame gutters, the red mark on the chart's rim shows which side it's on. Turn to face it: then HOOK IT! can light."
	elif not game.killed_seen:
		tip = "You walked into it in the dark. NORMAL light shows 2 tiles; BRIGHT shows 4 for 2 oil a turn."
	elif game.hook_wear > 0:
		tip = "When HOOK IT! glows, swing. It goes down, and you can shove past it."
	else:
		tip = "With no hook, back off while it rests after a lunge, or step round a corner. Standing still is death."
	if game.tears > 0:
		tip += " You'd torn free %s tonight." % ("once" if game.tears == 1 else "%d times" % game.tears)
	return [where, tip]
