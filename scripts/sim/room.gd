extends RefCounted
## A handmade room, parsed from text. Rooms are handmade, not procedural (scope rule).
##   # wall   . floor   H hunter start   T thrall   L street lamp (unlit)   E exit
##   B bell (ring it: the night is won)   N letter (readable under BRIGHT)   O oil flask (pickup)
##   K boathook (pickup: reach 2, bends with every hit)
##   S stalker (the veiled bride: frozen while you look at it in your light, 2 steps in the dark)

var rows: Array = []
var size := Vector2i.ZERO
var hunter := Vector2i(-1, -1)
var thralls: Array[Vector2i] = []
var stalkers: Array[Vector2i] = []
var lamps: Array[Vector2i] = []
var exits: Array[Vector2i] = []
var bells: Array[Vector2i] = []
var letters: Array[Vector2i] = []
var oil_flasks: Array[Vector2i] = []
var hooks: Array[Vector2i] = []


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
