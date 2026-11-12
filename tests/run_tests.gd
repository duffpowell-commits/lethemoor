extends SceneTree
## Headless rule tests. Run before every push:
##   godot --headless --path . --script tests/run_tests.gd
## Exits with code 1 if any test fails.

const Fog = preload("res://scripts/sim/fog.gd")
const Room = preload("res://scripts/sim/room.gd")

var failures := 0
var passed := 0


func _init() -> void:
	for m in get_method_list():
		if m.name.begins_with("test_"):
			var before := failures
			call(m.name)
			if failures == before:
				passed += 1
			else:
				print("FAIL ", m.name)
	print("%d passed, %d failed" % [passed, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  assertion failed: ", msg)


func open_room(w := 9, h := 9) -> RefCounted:
	return Fog.create(w, h)


func test_everything_starts_dark() -> void:
	var f = open_room()
	check(f.get_state(Vector2i(4, 4)) == Fog.DARK, "fresh grid is dark")


func test_radius_per_setting() -> void:
	var f = open_room()
	var c := Vector2i(4, 4)
	check(f.lit_by(c, Fog.Lantern.HOODED).size() == 1, "hooded lights only your own tile")
	check(Vector2i(6, 4) in f.lit_by(c, Fog.Lantern.NORMAL), "normal reaches 2 tiles")
	check(not (Vector2i(7, 4) in f.lit_by(c, Fog.Lantern.NORMAL)), "normal stops at 2")
	check(Vector2i(8, 4) in f.lit_by(c, Fog.Lantern.BRIGHT), "bright reaches 4")
	check(Vector2i(5, 6) in f.lit_by(c, Fog.Lantern.NORMAL), "radius is round, not a diamond")
	check(not (Vector2i(6, 6) in f.lit_by(c, Fog.Lantern.NORMAL)), "and not a square")


func test_walls_block_light() -> void:
	var f = open_room()
	f.walls[f.idx(Vector2i(5, 4))] = 1
	var lit = f.lit_by(Vector2i(4, 4), Fog.Lantern.BRIGHT)
	check(Vector2i(5, 4) in lit, "you see the wall itself")
	check(not (Vector2i(6, 4) in lit), "but not behind it")
	check(not (Vector2i(8, 4) in lit), "or far behind it")


func test_lit_fades_to_remembered() -> void:
	var f = open_room()
	f.update([{pos = Vector2i(1, 1), setting = Fog.Lantern.NORMAL}])
	check(f.get_state(Vector2i(2, 1)) == Fog.LIT, "lit while the lantern is there")
	f.update([{pos = Vector2i(7, 7), setting = Fog.Lantern.NORMAL}])
	check(f.get_state(Vector2i(2, 1)) == Fog.REMEMBERED, "remembered after you leave")
	check(f.get_state(Vector2i(7, 6)) == Fog.LIT, "new spot lit")
	check(f.get_state(Vector2i(4, 1)) == Fog.DARK, "never-seen stays dark")


func test_oil_burn() -> void:
	check(Fog.burn(5, Fog.Lantern.BRIGHT) == 3, "bright burns 2")
	check(Fog.burn(5, Fog.Lantern.NORMAL) == 4, "normal burns 1")
	check(Fog.burn(5, Fog.Lantern.HOODED) == 5, "hooded burns nothing")
	check(Fog.burn(1, Fog.Lantern.BRIGHT) == 0, "oil never goes negative")


func test_flicker_only_for_unlit_nearby() -> void:
	var f = open_room()
	var me := Vector2i(4, 4)
	f.update([{pos = me, setting = Fog.Lantern.NORMAL}])
	check(not f.flickers(me, [Vector2i(5, 4)]), "a lit enemy doesn't flicker (you can see it)")
	check(f.flickers(me, [Vector2i(7, 4)]), "unlit enemy 3 tiles away flickers")
	check(not f.flickers(me, [Vector2i(8, 8)]), "far enemy doesn't")


func test_room_parses() -> void:
	var r = Room.parse(FileAccess.get_file_as_string("res://rooms/quay_01.txt"))
	check(r.size == Vector2i(11, 14), "quay_01 is 11x14, got %s" % r.size)
	check(r.hunter != Vector2i(-1, -1), "has a hunter start")
	check(r.thralls.size() == 3, "has 3 thralls")
	check(r.exits.size() == 1, "has an exit")
	var f = r.make_fog()
	check(f.is_wall(Vector2i(0, 0)), "corner is wall")
	check(not f.is_wall(r.hunter), "hunter stands on floor")


func test_reach_and_path() -> void:
	var r = Room.parse("#####\n#H..#\n#.#.#\n#..T#\n#####")
	var reach: Dictionary = r.reachable(r.hunter, 4, r.thralls)
	check(reach.has(Vector2i(3, 2)), "can reach round the pillar")
	check(not reach.has(Vector2i(2, 2)), "can't stand in a wall")
	check(not reach.has(r.thralls[0]), "can't walk into a seen thrall")
	check(not r.reachable(r.hunter, 1).has(Vector2i(2, 1) + Vector2i(1, 0)), "2 steps away is out of a 1-step reach")
	var p: Array = r.path_in(reach, r.hunter, Vector2i(3, 2))
	check(p.size() == 4, "path to (3,2) is 4 tiles incl. both ends, got %d" % p.size())
	check(p[0] == r.hunter and p[-1] == Vector2i(3, 2), "path starts at the hunter and ends at the target")
	for i in range(1, p.size()):
		check((p[i] - p[i - 1]).abs().x + (p[i] - p[i - 1]).abs().y == 1, "every step is one tile, 4-way")
	check(r.path_in(reach, r.hunter, Vector2i(2, 2)).is_empty(), "no path into a wall")
