extends RefCounted
## Your record across nights and what it unlocks (Duff, Nov 25: "something to unlock for a good grade").
## Pure: a plain Dictionary in, the same Dictionary out (saved by the view in user://lethemoor.cfg).
##   Ring the bell once, any grade  -> DEEPER NIGHT (night.gd: the bride wakes sooner, thinner flasks, less oil)
##   Grade B or better               -> keepsake I     A or better -> II     S on a Deeper Night -> III
## At most one keepsake a night, so a great first night doesn't empty the shelf (review of build
## 160: one S unlocked everything at once). Keepsakes are kept in the Field Guide.

const RANK := {"S": 4, "A": 3, "B": 2, "C": 1, "D": 0}
const DEEPER := "deeper"
const GENTLE_NIGHTS := 3   # your first this-many nights deal a thrall fewer (Night.start_dealt gentle)

## [id, grade needed, title, words, Deeper Night only]
const KEEPSAKES := [
	["keep1", "B", "A RING OF BLACK WAX",
		"Pressed into the bell rope, still soft: a seal with no crest. Someone rang this bell before you, and wanted it known that they had. The wax smells of lamp oil and the sea.", false],
	["keep2", "A", "THE BRIDE'S GLOVE",
		"Lace, sodden, the fingers stitched shut with red thread. It was left on the bell's step, folded the way you fold a thing you mean to come back for. You don't touch it twice.", false],
	["keep3", "S", "THE LAST LANTERN",
		"Under the bell, a lantern older than the town, its glass gone milky. It still holds a thumb of oil. The note tied to it reads only: when the bell is quiet, light this, and go home.", true],
]


static func blank() -> Dictionary:
	return {nights = 0, rung = 0, best = "", best_deep = "", unlocked = []}


static func better(a: String, b: String) -> bool:
	return RANK.get(a, -1) > RANK.get(b, -1)


## Count a finished night. Returns the ids it unlocked just now (empty most nights).
static func add_night(rec: Dictionary, rang: bool, grade: String, deep: bool) -> Array:
	for k in blank():
		if not rec.has(k):
			rec[k] = blank()[k]
	rec.nights += 1
	var new: Array = []
	if not rang:
		return new
	rec.rung += 1
	var key := "best_deep" if deep else "best"
	if better(grade, rec[key]):
		rec[key] = grade
	if not DEEPER in rec.unlocked:
		new.append(DEEPER)
	for k in KEEPSAKES:   # the first one this night earns, and only that one
		if RANK.get(grade, -1) >= RANK[k[1]] and (deep or not k[4]) and not k[0] in rec.unlocked:
			new.append(k[0])
			break
	rec.unlocked.append_array(new)
	return new


## What the Field Guide says about a keepsake you haven't found yet.
static func lock_text(k: Array) -> String:
	return "LOCKED. Ring the bell with grade %s or better%s. One keepsake a night." % [k[1], " on a Deeper Night" if k[4] else ""]


## Still one of your first nights (any ending counts as a night)?
static func gentle(rec: Dictionary) -> bool:
	return int(rec.get("nights", 0)) < GENTLE_NIGHTS


static func has(rec: Dictionary, id: String) -> bool:
	return id in rec.get("unlocked", [])


## One short line for the end card naming what this night unlocked ("" if nothing): the card has
## no room for more (the verdict buttons sit under it).
static func news(ids: Array) -> String:
	var bits: Array[String] = []
	if DEEPER in ids:
		bits.append("DEEPER NIGHT (title)")
	var keeps := ids.filter(func(id): return id != DEEPER)
	if keeps.size() == 1:
		for k in KEEPSAKES:
			if k[0] == keeps[0]:
				bits.append("KEEPSAKE: %s (Field Guide)" % k[2])
	elif keeps.size() > 1:
		bits.append("%d KEEPSAKES (Field Guide)" % keeps.size())
	return "" if bits.is_empty() else "UNLOCKED: " + "  ·  ".join(bits)


## One line for the title: how you've done so far.
static func summary(rec: Dictionary) -> String:
	if rec.get("rung", 0) == 0:
		return ""
	var best: String = str(rec.get("best", ""))
	var s := "Bells rung %d · best %s" % [rec.rung, best if best != "" else "-"]
	if rec.get("best_deep", "") != "":
		s += " · deeper %s" % rec.best_deep
	return s


## The end card's pull to play again: the next thing to earn, in one line ("" once everything is
## found). Reads the record after this night was counted.
static func next_goal(rec: Dictionary) -> String:
	if not has(rec, DEEPER):
		return "NEXT: ring the bell once, any grade, to open DEEPER NIGHT."
	for k in KEEPSAKES:
		if not has(rec, k[0]):
			return "NEXT: grade %s or better%s for keepsake %s." % [k[1], " on a Deeper Night" if k[4] else "", "I".repeat(KEEPSAKES.find(k) + 1)]
	return ""

