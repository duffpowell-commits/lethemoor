extends RefCounted
## One night in one room: the turn rules (M1b). Pure, no nodes; tests drive it headless.
## Every step is one turn: you move one tile (or wait), the lantern burns, dread moves,
## then every thrall acts. Two clocks pull against each other:
##   oil   burns while the lantern is lit (Light is life)
##   dread rises in the dark, falls in the light, spikes when a horror steps into view
## Thralls walk toward light. Hood the lantern and they lose you.

const Fog = preload("res://scripts/sim/fog.gd")
const Room = preload("res://scripts/sim/room.gd")

const START_OIL := 30
const DREAD_MAX := 100
const DREAD_DARK := 4          # per turn hooded or out of oil
const DREAD_LIT := -2          # per turn with the lantern lit
const DREAD_HORROR := 15       # a thrall steps into your light
const DREAD_HALLUCINATE := 50  # at or above: the view may lie (fake flickers)
const PANIC_OIL := 5           # at 100 dread you spill this much oil...
const PANIC_RESET := 60        # ...and dread drops back to here
## Thralls shamble: they step only on turns divisible by this. In first person every turn of
## your head costs a turn, so an equal-speed chaser catches you at the first corner.
const THRALL_EVERY := 2
## The Stalker: frozen while it stands in your light AND inside your view (you're looking at
## it). Otherwise it takes STALKER_STEPS steps a turn. Looking away (a turn) is how it gets you.
const STALKER_STEPS := 2
const VIEW_COS := 0.64          # ~50 degrees either side of where you face
const FLASK_OIL := 10          # an oil flask found on the floor
const LETTER_POINTS := 5       # grade: each letter read is worth this much oil
## Grade at the bell: oil left + LETTER_POINTS per letter read. [min points, grade]
const GRADES := [[20, "S"], [14, "A"], [8, "B"], [3, "C"], [0, "D"]]
## How far a thrall notices your lantern (tiles, needs line of sight).
const NOTICE := {Fog.Lantern.HOODED: 1, Fog.Lantern.NORMAL: 5, Fog.Lantern.BRIGHT: 8}

const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var room
var fog
var hunter := Vector2i.ZERO
var facing := Vector2i.UP       # first-person view looks this way (top-down ignores it)
var setting: int = Fog.Lantern.NORMAL
var oil := START_OIL
var dread := 0
var turn := 0
var dead := false
var escaped := false
var cause := ""                 # why you died, in the game's voice
var rang := false               # rang the bell (One Night's goal): escaped with a grade
var letters_read: Array = []    # letter tiles read (needs BRIGHT on the tile)
var flasks_left: Array = []     # oil flasks still on the floor
## Each thrall: {pos, target (last place it saw your light, or null), seen (in your light now),
## last_seen (where YOU last saw it, or null: the map's marker, and it can be stale)}
var thralls: Array = []


static func start(room_text: String) -> RefCounted:
	var n = load("res://scripts/sim/night.gd").new()
	n.room = Room.parse(room_text)
	n.fog = n.room.make_fog()
	n.hunter = n.room.hunter
	n.flasks_left = n.room.oil_flasks.duplicate()
	for p: Vector2i in n.room.thralls:
		n.thralls.append({pos = p, target = null, seen = false, last_seen = null, kind = "thrall"})
	for p: Vector2i in n.room.stalkers:
		n.thralls.append({pos = p, target = null, seen = false, last_seen = null, kind = "stalker"})
	n.fog.update([{pos = n.hunter, setting = n.setting}])
	for th in n.thralls:
		th.seen = n.fog.get_state(th.pos) == Fog.LIT
		if th.seen:
			th.last_seen = th.pos
	return n


## What the lantern really does this turn: no oil means hooded, whatever the button says.
func effective() -> int:
	return Fog.Lantern.HOODED if oil <= 0 else setting


func thrall_at(p: Vector2i) -> int:
	for i in thralls.size():
		if thralls[i].pos == p:
			return i
	return -1


func positions() -> Array:
	return thralls.map(func(th): return th.pos)


func over() -> bool:
	return dead or escaped


func flickers() -> bool:
	return fog.flickers(hunter, positions())


func hallucinating() -> bool:
	return dread >= DREAD_HALLUCINATE


## Can you take one step onto `p`? (4-way neighbour, floor, no thrall you can SEE there.)
## An unseen thrall doesn't block: you walk into it. That's the point of the dark.
func can_step(p: Vector2i) -> bool:
	if over() or room.is_wall(p) or (p - hunter).abs().x + (p - hunter).abs().y != 1:
		return false
	var i := thrall_at(p)
	return i < 0 or fog.get_state(p) != Fog.LIT


## Take one turn moving onto `p`. Returns the events that happened (strings), [] if illegal.
func step(p: Vector2i) -> Array:
	if not can_step(p):
		return []
	var events: Array = []
	if thrall_at(p) >= 0:
		_die("Something was standing in the dark. It was waiting.")
		events.append("grabbed")
		return events
	if p - hunter != -facing:
		facing = p - hunter   # walking turns you to face where you go; backing up doesn't
	hunter = p
	return _end_turn(events)


## Step one tile in a grid direction (first person: forward is `facing`, back is -facing).
## Facing doesn't change when you step back: you retreat with your eyes on the dark.
func step_dir(d: Vector2i) -> Array:
	return step(hunter + d)


## Turn 90 degrees. Costs a whole turn: the world moves while you look away.
## `side` is +1 for right (clockwise on the grid), -1 for left.
func turn_by(side: int) -> Array:
	if over():
		return []
	facing = Vector2i(-facing.y, facing.x) if side > 0 else Vector2i(facing.y, -facing.x)
	return _end_turn([])


## Stand still for a turn (hide hooded, let a thrall pass).
func wait() -> Array:
	if over():
		return []
	return _end_turn([])


## Change the lantern. Free: costs no turn (the cost is in the next step's oil and dread).
func set_lantern(s: int) -> void:
	setting = s
	fog.update([{pos = hunter, setting = effective()}])


func _end_turn(events: Array) -> Array:
	turn += 1
	var lit := effective() != Fog.Lantern.HOODED
	oil = Fog.burn(oil, effective())
	if room.exits.has(hunter):
		escaped = true
		events.append("escaped")
		return events
	if room.bells.has(hunter):
		escaped = true
		rang = true
		events.append("rang")
		return events
	if flasks_left.has(hunter):
		flasks_left.erase(hunter)
		oil += FLASK_OIL
		events.append("oil")
	if room.letters.has(hunter) and not letters_read.has(hunter):
		if effective() == Fog.Lantern.BRIGHT:
			letters_read.append(hunter)
			events.append("letter")
		else:
			events.append("letter_dim")
	fog.update([{pos = hunter, setting = effective()}])
	dread += DREAD_LIT if lit else DREAD_DARK
	_horrors(events)
	_thralls_act(events)
	if dead:
		return events
	fog.update([{pos = hunter, setting = effective()}])
	_horrors(events)
	dread = clampi(dread, 0, DREAD_MAX)
	if dread >= DREAD_MAX:
		oil = maxi(0, oil - PANIC_OIL)
		dread = PANIC_RESET
		events.append("panic")
		fog.update([{pos = hunter, setting = effective()}])
	if oil == 0 and lit:
		events.append("out_of_oil")
	return events


## A thrall stepping into your light is a horror, once per sighting.
func _horrors(events: Array) -> void:
	for th in thralls:
		var now: bool = fog.get_state(th.pos) == Fog.LIT
		if now and not th.seen:
			dread += DREAD_HORROR
			if not events.has("horror"):
				events.append("horror")
		th.seen = now
		if now:
			th.last_seen = th.pos


func _sees_light(th: Dictionary) -> bool:
	var d := Vector2(hunter - th.pos).length()
	return d <= NOTICE[effective()] + 0.5 and fog.has_los(th.pos, hunter)


## Each thrall: next to you, it takes you. Sees your light, it comes. Lost you, it goes to
## the last place it saw you, then stands there.
## Is `p` in front of you, inside the view cone? (Your own tile counts as not.)
func in_view(p: Vector2i) -> bool:
	var d := Vector2(p - hunter)
	if d == Vector2.ZERO:
		return false
	return d.normalized().dot(Vector2(facing)) >= VIEW_COS


## A Stalker holds still only while it's lit and you're looking right at it.
func watched(th: Dictionary) -> bool:
	return fog.get_state(th.pos) == Fog.LIT and in_view(th.pos)


func _stalker_act(i: int, events: Array) -> void:
	var th: Dictionary = thralls[i]
	for s in STALKER_STEPS:
		if watched(th):
			return
		if (th.pos - hunter).abs().x + (th.pos - hunter).abs().y == 1:
			_die("Lace, and a cold breath at your neck. You never saw her move.")
			events.append("taken")
			return
		if _sees_light(th):
			th.target = hunter
		if th.target == null or th.pos == th.target:
			th.target = null
			return
		var others: Array = positions()
		others.remove_at(i)
		var reach: Dictionary = room.reachable(th.pos, room.size.x * room.size.y, others)
		var path: Array = room.path_in(reach, th.pos, th.target)
		if path.size() < 2:
			th.target = null
			return
		th.pos = path[1]
		if not events.has("stalker_moved"):
			events.append("stalker_moved")
		fog.update([{pos = hunter, setting = effective()}])


func _thralls_act(events: Array) -> void:
	for i in thralls.size():
		var th: Dictionary = thralls[i]
		if th.get("kind", "thrall") == "stalker":
			_stalker_act(i, events)
			if dead:
				return
			continue
		if (th.pos - hunter).abs().x + (th.pos - hunter).abs().y == 1:
			_die("Cold hands, out of the dark. The lantern rolls away.")
			events.append("taken")
			return
		if _sees_light(th):
			th.target = hunter
		if th.target == null:
			continue
		if th.pos == th.target:
			th.target = null
			continue
		if turn % THRALL_EVERY != 0:
			continue   # shambling: this turn it only lurches in place
		var others: Array = positions()
		others.remove_at(i)
		var reach: Dictionary = room.reachable(th.pos, room.size.x * room.size.y, others)
		var path: Array = room.path_in(reach, th.pos, th.target)
		if path.size() < 2:
			th.target = null   # no way through: it gives up
			continue
		th.pos = path[1]
		if not events.has("thrall_moved"):
			events.append("thrall_moved")


## One Night score: oil left plus letters read. Only meaningful once the bell has rung.
func points() -> int:
	return oil + LETTER_POINTS * letters_read.size()


func grade() -> String:
	for g in GRADES:
		if points() >= g[0]:
			return g[1]
	return "D"


func _die(why: String) -> void:
	dead = true
	cause = why
