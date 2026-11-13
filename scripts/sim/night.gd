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
## How far a thrall notices your lantern (tiles, needs line of sight).
const NOTICE := {Fog.Lantern.HOODED: 1, Fog.Lantern.NORMAL: 5, Fog.Lantern.BRIGHT: 8}

const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var room
var fog
var hunter := Vector2i.ZERO
var setting: int = Fog.Lantern.NORMAL
var oil := START_OIL
var dread := 0
var turn := 0
var dead := false
var escaped := false
var cause := ""                 # why you died, in the game's voice
## Each thrall: {pos: Vector2i, target: Vector2i or null (last place it saw your light), seen: bool}
var thralls: Array = []


static func start(room_text: String) -> RefCounted:
	var n = load("res://scripts/sim/night.gd").new()
	n.room = Room.parse(room_text)
	n.fog = n.room.make_fog()
	n.hunter = n.room.hunter
	for p: Vector2i in n.room.thralls:
		n.thralls.append({pos = p, target = null, seen = false})
	n.fog.update([{pos = n.hunter, setting = n.setting}])
	for th in n.thralls:
		th.seen = n.fog.get_state(th.pos) == Fog.LIT
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
	hunter = p
	return _end_turn(events)


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


func _sees_light(th: Dictionary) -> bool:
	var d := Vector2(hunter - th.pos).length()
	return d <= NOTICE[effective()] + 0.5 and fog.has_los(th.pos, hunter)


## Each thrall: next to you, it takes you. Sees your light, it comes. Lost you, it goes to
## the last place it saw you, then stands there.
func _thralls_act(events: Array) -> void:
	for i in thralls.size():
		var th: Dictionary = thralls[i]
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


func _die(why: String) -> void:
	dead = true
	cause = why
