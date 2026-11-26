extends RefCounted
## Pure fog-of-war and lantern rules. No scenes, no nodes: tests run headless.
## Pillar 1, "Light is life": your lantern radius is your vision, oil is your clock.
##
## Tile states (design doc, Stage 2):
##   LIT        - in a lantern's light right now: full info, enemy intent shown.
##   REMEMBERED - seen before: layout known, last-known enemy spot (can be wrong).
##   DARK       - never seen: nothing.

const DARK := 0
const REMEMBERED := 1
const LIT := 2

enum Lantern { HOODED, NORMAL, BRIGHT }

## Light radius in tiles. Hooded lights only the hunter's own tile.
const RADIUS := {Lantern.HOODED: 0, Lantern.NORMAL: 2, Lantern.BRIGHT: 4}
## Oil burned per round.
const OIL_COST := {Lantern.HOODED: 0, Lantern.NORMAL: 1, Lantern.BRIGHT: 2}
## The lantern flickers when something unlit is this close (no what, no where).
const FLICKER_RANGE := 3

var width := 0
var height := 0
var walls := PackedByteArray()  # 1 = wall, blocks movement and light
var state := PackedByteArray()  # DARK / REMEMBERED / LIT per tile


static func create(w: int, h: int) -> RefCounted:
	var f = load("res://scripts/sim/fog.gd").new()
	f.width = w
	f.height = h
	f.walls.resize(w * h)
	f.state.resize(w * h)
	return f


func idx(p: Vector2i) -> int:
	return p.y * width + p.x


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func is_wall(p: Vector2i) -> bool:
	return not in_bounds(p) or walls[idx(p)] == 1


func get_state(p: Vector2i) -> int:
	return state[idx(p)] if in_bounds(p) else DARK


## True if nothing solid sits strictly between a and b (Bresenham line).
## The end tile itself may be a wall: you can see the wall you're looking at.
func has_los(a: Vector2i, b: Vector2i) -> bool:
	var d := (b - a).abs()
	var s := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var err := d.x - d.y
	var p := a
	while p != b:
		if p != a and is_wall(p):
			return false
		var e2 := err * 2
		if e2 > -d.y:
			err -= d.y
			p.x += s.x
		if e2 < d.x:
			err += d.x
			p.y += s.y
	return true


## Tiles a lantern at `pos` lights with the given setting.
func lit_by(pos: Vector2i, setting: int) -> Array[Vector2i]:
	var r: int = RADIUS[setting]
	var out: Array[Vector2i] = []
	for y in range(pos.y - r, pos.y + r + 1):
		for x in range(pos.x - r, pos.x + r + 1):
			var p := Vector2i(x, y)
			if not in_bounds(p):
				continue
			# +0.5 rounds the circle out so radius 2 isn't a diamond.
			if Vector2(p - pos).length() > r + 0.5:
				continue
			if has_los(pos, p):
				out.append(p)
	return out


## Recompute fog for a set of lights: [{pos: Vector2i, setting: Lantern}, ...].
## Whatever was LIT and isn't any more fades to REMEMBERED.
func update(lights: Array) -> void:
	for i in state.size():
		if state[i] == LIT:
			state[i] = REMEMBERED
	for l in lights:
		for p in lit_by(l.pos, l.setting):
			state[idx(p)] = LIT


## Oil left after one round at this setting. Never below zero.
static func burn(oil: int, setting: int) -> int:
	return maxi(0, oil - OIL_COST[setting])


## Does the lantern at `pos` flicker? Only unlit enemies count.
func flickers(pos: Vector2i, enemies: Array) -> bool:
	return not near_unseen(pos, enemies).is_empty()


## The unlit enemies that make the lantern at `pos` flicker (within FLICKER_RANGE, any wall).
## The chart's rim marks which way they are (review of build 183: "Something is near" scared
## you but never said from where).
func near_unseen(pos: Vector2i, enemies: Array) -> Array:
	var out: Array = []
	for e: Vector2i in enemies:
		if get_state(e) != LIT and maxi(absi(e.x - pos.x), absi(e.y - pos.y)) <= FLICKER_RANGE:
			out.append(e)
	return out
