extends RefCounted
## A handmade room, parsed from text. Rooms are handmade, not procedural (scope rule).
##   # wall   . floor   H hunter start   T thrall   L street lamp (unlit)   E exit
##   B bell (ring it: the night is won)   N letter (readable under BRIGHT)   O oil flask (pickup)
##   K boathook (pickup: reach 2, bends with every hit)
##   S stalker (the veiled bride: frozen while you look at it in your light, 2 steps in the dark)
##   C corpse (a thrall playing dead: it gets up once you're close and not looking at it)

var rows: Array = []
var size := Vector2i.ZERO
var hunter := Vector2i(-1, -1)
var thralls: Array[Vector2i] = []
var stalkers: Array[Vector2i] = []
var corpses: Array[Vector2i] = []
var lamps: Array[Vector2i] = []
var exits: Array[Vector2i] = []
var bells: Array[Vector2i] = []
var letters: Array[Vector2i] = []
var oil_flasks: Array[Vector2i] = []
var hooks: Array[Vector2i] = []


## Dealing a night (shuffle): how far a thing may wander from where the map draws it, and how
## close to the start a horror may stand (walking tiles). The walls never move.
const SHUFFLE_REACH := 3
const SAFE_START := 7


static func parse(text: String) -> RefCounted:
	var r = load("res://scripts/sim/room.gd").new()
	for line in text.strip_edges().split("\n"):
		r.rows.append(line.strip_edges())
	r.size = Vector2i(r.rows[0].length(), r.rows.size())
	for y in r.size.y:
		assert(r.rows[y].length() == r.size.x, "room rows must be the same width")
		for x in r.size.x:
			var c: String = r.rows[y][x]
			var p := Vector2i(x, y)
			match c:
				"H": r.hunter = p
				"T": r.thralls.append(p)
				"S": r.stalkers.append(p)
				"C": r.corpses.append(p)
				"L": r.lamps.append(p)
				"E": r.exits.append(p)
				"B": r.bells.append(p)
				"N": r.letters.append(p)
				"O": r.oil_flasks.append(p)
				"K": r.hooks.append(p)
	return r


func is_wall(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
		return true
	return rows[p.y][p.x] == "#"


## Fresh fog grid with this room's walls.
func make_fog() -> RefCounted:
	var Fog = load("res://scripts/sim/fog.gd")
	var f = Fog.create(size.x, size.y)
	for y in size.y:
		for x in size.x:
			f.walls[y * size.x + x] = 1 if is_wall(Vector2i(x, y)) else 0
	return f


## Floor tiles within `steps` (4-way), not through walls or `blockers` (e.g. seen enemies).
## Returns {tile: distance}. The start tile is included at distance 0.
func reachable(from: Vector2i, steps: int, blockers: Array = []) -> Dictionary:
	var seen := {from: 0}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if seen[c] >= steps:
			continue
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if seen.has(n) or is_wall(n) or n in blockers:
				continue
			seen[n] = seen[c] + 1
			q.append(n)
	return seen


## Step-by-step path from `from` to `to` (both included) inside a reachable() result.
## Empty if `to` isn't in it. Walks back down the distance numbers, so it's a shortest path.
func path_in(reach: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not reach.has(to):
		return out
	var c := to
	out.append(c)
	while c != from:
		var stepped := false
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if reach.has(n) and reach[n] == reach[c] - 1:
				c = n
				stepped = true
				break
		if not stepped:  # reach wasn't built from `from`: no path rather than a hang
			out.clear()
			return out
		out.push_front(c)
	return out


## Deal a fresh night from `seed`: horrors, oil flasks and letters each move to a floor tile
## within SHUFFLE_REACH steps of where the map draws them. Seed 0 keeps the map as drawn.
## Fair by rule: no horror within SAFE_START steps of the start or next to another horror, no
## horror nearer the straight road to the bell or to the start than the map draws it (so the night is as
## dangerous as the handmade one, just in new places), the Stalker never on that road, letters always beside a wall to hang on,
## nothing on the start, bell, hook, lamp or exit, nothing sharing a tile.
func shuffle(seed: int) -> void:
	if seed == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var from_start := reachable(hunter, size.x * size.y)
	var route: Array = path_in(from_start, hunter, bells[0]) if not bells.is_empty() else []
	var used := {hunter: true}
	for p in bells + hooks + lamps + exits:
		used[p] = true
	var horrors := {}
	var road := func(q: Vector2i) -> int:     # tiles from the straight road to the bell
		var best := 999
		for t: Vector2i in route:
			best = mini(best, absi(q.x - t.x) + absi(q.y - t.y))
		return best
	var far := func(q: Vector2i) -> bool:
		if from_start.get(q, 0) < SAFE_START:
			return false
		for d in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if horrors.has(q + d):
				return false
		return true
	# a horror may wander, but never nearer the road than the map puts it: same danger, new places
	# and never nearer the start: you meet each one no sooner than on the handmade night
	var fair := func(q: Vector2i, p: Vector2i) -> bool:
		return far.call(q) and road.call(q) >= road.call(p) and from_start.get(q, 0) >= from_start.get(p, 0)
	stalkers = _deal(stalkers, rng, used, func(q, p): return fair.call(q, p) and not q in route, horrors)
	thralls = _deal(thralls, rng, used, fair, horrors)
	# bodies lie in dead ends you pass or walk into, never across a corridor you must use
	corpses = _deal(corpses, rng, used, func(q, p): return fair.call(q, p) and dead_end(q), horrors)
	letters = _deal(letters, rng, used, func(q, _p): return _against_wall(q))
	oil_flasks = _deal(oil_flasks, rng, used, func(_q, _p): return true)


func _deal(from: Array[Vector2i], rng: RandomNumberGenerator, used: Dictionary, ok: Callable, mark = null) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in from:
		var spots: Array[Vector2i] = []
		for q: Vector2i in reachable(p, SHUFFLE_REACH):
			if not used.has(q) and ok.call(q, p):
				spots.append(q)
		spots.sort()                       # dictionary order isn't a promise; the seed must be
		var pick := p if spots.is_empty() else spots[rng.randi_range(0, spots.size() - 1)]
		used[pick] = true
		if mark != null:
			mark[pick] = true
		out.append(pick)
	return out


## A floor tile with one way out: an alcove or the end of a passage.
func dead_end(p: Vector2i) -> bool:
	var ways := 0
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not is_wall(p + d):
			ways += 1
	return not is_wall(p) and ways == 1


func _against_wall(p: Vector2i) -> bool:
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if is_wall(p + d):
			return true
	return false
