extends RefCounted
## A handmade room, parsed from text. Rooms are handmade, not procedural (scope rule).
##   # wall   . floor   H hunter start   T thrall   L street lamp (unlit)   E exit

var rows: Array = []
var size := Vector2i.ZERO
var hunter := Vector2i(-1, -1)
var thralls: Array[Vector2i] = []
var lamps: Array[Vector2i] = []
var exits: Array[Vector2i] = []


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
				"L": r.lamps.append(p)
				"E": r.exits.append(p)
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
