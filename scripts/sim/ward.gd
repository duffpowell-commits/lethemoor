extends RefCounted
## A fresh ward for a dealt night: new walls every night (Duff, Nov 25: "walls that shuffle").
## Pure: text in, text out. The handmade map is the template. The new ward is the same size, has
## the same things in it, and puts each one about as far along the road to the bell as the
## template does, so the pacing (first scare, flasks, bride) stays what the bot tuned.
## Seed 0 never comes here: the handmade night (tests, capture) keeps its walls.

const Room = preload("res://scripts/sim/room.gd")

const LOOPS := 0.12        # share of the leftover inner walls knocked through, so you can circle a thrall
const HALLS := 3           # small open rooms (3x3) per ward, so it isn't all one-wide corridor
const BELL_SLACK := 3      # the bell's walk from the start stays within this many tiles of the template's
const BELL_EXTRA := 6      # wards walk shorter than the handmade night (fewer detours): put the bell this much further
const HORROR_NEAR := 13    # no horror dealt nearer the start than this (the dealer's one early thrall still comes in closer, on purpose)
const TRIES := 40          # wards to try before giving up and keeping the template walls

const CARDINALS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## The ward for night `seed`, built from `template` (map text). Same seed, same ward.
static func carve(template: String, seed: int) -> String:
	var t = Room.parse(template)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 17
	var t_start: Dictionary = t.reachable(t.hunter, t.size.x * t.size.y)
	var t_bell: int = t_start.get(t.bells[0], 0) if not t.bells.is_empty() else 0
	for _i in TRIES:
		var out := _try(t, t_start, t_bell, rng)
		if out != "":
			return out
	return template


static func _try(t, t_start: Dictionary, t_bell: int, rng: RandomNumberGenerator) -> String:
	var w: int = t.size.x
	var h: int = t.size.y
	var g: Array = []           # rows of single-char strings
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill("#")
		g.append(row)
	_maze(g, w, h, rng)
	_loops(g, w, h, rng)
	for _i in HALLS:
		var cx := 1 + 2 * rng.randi_range(0, (w - 5) / 2)
		var cy := 1 + 2 * rng.randi_range(0, (h - 5) / 2)
		for y in range(cy, cy + 3):
			for x in range(cx, cx + 3):
				g[y][x] = "."
	var rows: Array = []
	for y in h:
		rows.append("".join(PackedStringArray(g[y])))
	var r = Room.parse("\n".join(PackedStringArray(rows)))
	# start: a floor tile on the bottom corridor, like the template
	var low: Array[Vector2i] = []
	for x in w:
		if not r.is_wall(Vector2i(x, h - 2)):
			low.append(Vector2i(x, h - 2))
	var start: Vector2i = low[rng.randi_range(0, low.size() - 1)]
	var from: Dictionary = r.reachable(start, w * h)
	# bell: as far a walk as the template's, at the end of a passage if one fits
	var bells: Array[Vector2i] = []
	for q: Vector2i in from:
		if absi(from[q] - t_bell - BELL_EXTRA) <= BELL_SLACK:
			bells.append(q)
	if bells.is_empty():
		return ""
	bells.sort()
	var ends := bells.filter(func(q): return r.dead_end(q))
	var pool: Array = ends if not ends.is_empty() else bells
	var bell: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
	var route: Array = r.path_in(from, start, bell)
	var road_len := float(maxi(1, from[bell]))
	var t_route: Array = t.path_in(t_start, t.hunter, t.bells[0]) if not t.bells.is_empty() else []
	var put := {start: "H", bell: "B"}
	var horrors := {}
	# everything else in the template, in this order: tools first, then the horrors (they keep
	# clear of each other), then letters and flasks
	var kinds := [["K", t.hooks], ["L", t.lamps], ["E", t.exits], ["S", t.stalkers], ["T", t.thralls],
		["C", t.corpses], ["N", t.letters], ["O", t.oil_flasks]]
	for kind in kinds:
		for p: Vector2i in kind[1]:
			var frac: float = float(t_start.get(p, 0)) / float(maxi(1, t_bell))
			var want := frac * road_len
			var t_road := _road(p, t_route)
			var best: Array[Vector2i] = []
			var best_err := 999.0
			for q: Vector2i in from:
				if put.has(q) or not _fits(kind[0], q, r, from, route, horrors, t_road):
					continue
				var err := absf(from[q] - want)
				if err < best_err - 0.5:
					best_err = err
					best = [q]
				elif err <= best_err + 1.5:
					best.append(q)
			if best.is_empty() or best_err > 6.0:
				return ""
			best.sort()
			var q: Vector2i = best[rng.randi_range(0, best.size() - 1)]
			put[q] = kind[0]
			if kind[0] in ["T", "S", "C"]:
				horrors[q] = true
	for q: Vector2i in put:
		g[q.y][q.x] = put[q]
	rows.clear()
	for y in h:
		rows.append("".join(PackedStringArray(g[y])))
	return "\n".join(PackedStringArray(rows))


## The same rules the dealer keeps (room.gd shuffle), applied to a ward with no drawn places yet.
static func _fits(kind: String, q: Vector2i, r, from: Dictionary, route: Array, horrors: Dictionary, t_road: int) -> bool:
	var on_road := q in route
	match kind:
		"L":
			return on_road                      # a lamp you pass on the way
		"K":
			return not on_road and _road(q, route) <= 2 and _wall_beside(q, r)
		"N":
			return _wall_beside(q, r)
		"T", "S", "C":
			if from[q] < maxi(Room.SAFE_START, HORROR_NEAR):
				return false
			for d in [Vector2i.ZERO] + CARDINALS:
				if horrors.has(q + d):
					return false
			if kind == "S" and on_road:
				return false
			if kind == "C" and not r.dead_end(q):
				return false
			var rd := _road(q, route)
			return rd >= mini(t_road, 3) and rd <= t_road + 1   # as near the road as the template has it: you still have to pass it
	return true


static func _road(q: Vector2i, route: Array) -> int:
	var best := 999
	for p: Vector2i in route:
		best = mini(best, absi(q.x - p.x) + absi(q.y - p.y))
	return best


static func _wall_beside(q: Vector2i, r) -> bool:
	for d in CARDINALS:
		if r.is_wall(q + d):
			return true
	return false


## A perfect maze on the odd tiles (depth-first, the seed picks every turn).
static func _maze(g: Array, w: int, h: int, rng: RandomNumberGenerator) -> void:
	var cw := (w - 1) / 2
	var ch := (h - 1) / 2
	var seen := {}
	var c0 := Vector2i(rng.randi_range(0, cw - 1), rng.randi_range(0, ch - 1))
	var stack: Array[Vector2i] = [c0]
	seen[c0] = true
	g[c0.y * 2 + 1][c0.x * 2 + 1] = "."
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var next: Array[Vector2i] = []
		for d in CARDINALS:
			var n := c + d
			if n.x >= 0 and n.y >= 0 and n.x < cw and n.y < ch and not seen.has(n):
				next.append(n)
		if next.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = next[rng.randi_range(0, next.size() - 1)]
		seen[n] = true
		g[c.y + n.y + 1][c.x + n.x + 1] = "."     # the wall between them
		g[n.y * 2 + 1][n.x * 2 + 1] = "."
		stack.append(n)


## Knock through some inner walls that sit between two passages, so the ward has loops.
static func _loops(g: Array, w: int, h: int, rng: RandomNumberGenerator) -> void:
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if g[y][x] != "#" or (x % 2) == (y % 2):
				continue
			var across: bool = (x % 2 == 0 and g[y][x - 1] == "." and g[y][x + 1] == ".") \
					or (y % 2 == 0 and g[y - 1][x] == "." and g[y + 1][x] == ".")
			if across and rng.randf() < LOOPS:
				g[y][x] = "."
