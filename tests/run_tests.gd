extends SceneTree
## Headless rule tests. Run before every push:
##   godot --headless --path . --script tests/run_tests.gd
## Exits with code 1 if any test fails.

const Fog = preload("res://scripts/sim/fog.gd")
const Room = preload("res://scripts/sim/room.gd")
const Night = preload("res://scripts/sim/night.gd")

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


# ---------------------------------------------------------------- M1b: turns, dread, thralls

const CORRIDOR := "###########\n#H.......T#\n###########"


func test_one_step_per_turn() -> void:
	var n = Night.start("#####\n#H..#\n#####")
	check(not n.can_step(Vector2i(3, 1)), "can't jump two tiles")
	check(not n.can_step(Vector2i(1, 0)), "can't step into a wall")
	check(n.step(Vector2i(2, 1)).size() >= 0 and n.hunter == Vector2i(2, 1), "one tile moves you")
	check(n.turn == 1, "a step is a turn")
	check(n.oil == Night.START_OIL - 1, "normal burns 1 oil per step, got %d" % n.oil)


func test_bright_burns_two_hooded_none() -> void:
	var n = Night.start("######\n#H...#\n######")
	n.set_lantern(Fog.Lantern.BRIGHT)
	n.step(Vector2i(2, 1))
	check(n.oil == Night.START_OIL - 2, "bright burns 2")
	n.set_lantern(Fog.Lantern.HOODED)
	n.step(Vector2i(3, 1))
	check(n.oil == Night.START_OIL - 2, "hooded burns nothing")


func test_dread_rises_in_dark_falls_in_light() -> void:
	var n = Night.start("#####\n#H..#\n#####")
	n.set_lantern(Fog.Lantern.HOODED)
	n.wait()
	n.wait()
	check(n.dread == Night.DREAD_DARK * 2, "two dark turns add dread, got %d" % n.dread)
	n.set_lantern(Fog.Lantern.NORMAL)
	n.wait()
	check(n.dread == Night.DREAD_DARK * 2 + Night.DREAD_LIT, "a lit turn takes some back")


func test_no_oil_means_dark() -> void:
	var n = Night.start("#####\n#H..#\n#####")
	n.oil = 1
	var ev: Array = n.wait()
	check(n.oil == 0 and ev.has("out_of_oil"), "last drop burns, and you're told")
	check(n.effective() == Fog.Lantern.HOODED, "no oil = hooded, whatever the button says")
	n.wait()
	check(n.dread == Night.DREAD_DARK, "and the dark feeds dread (dread never goes below 0), got %d" % n.dread)


func test_panic_spills_oil() -> void:
	var n = Night.start("#####\n#H..#\n#####")
	n.set_lantern(Fog.Lantern.HOODED)
	n.dread = Night.DREAD_MAX - 1
	var ev: Array = n.wait()
	check(ev.has("panic"), "hitting max dread panics")
	check(n.oil == Night.START_OIL - Night.PANIC_OIL, "panic spills oil")
	check(n.dread == Night.PANIC_RESET, "and dread drops back")


func test_thrall_walks_to_the_light() -> void:
	var n = Night.start(CORRIDOR)   # thrall 8 tiles off, normal notices at 5
	n.wait()
	check(n.thralls[0].pos == Vector2i(9, 1), "normal light 8 tiles off: unnoticed")
	n.set_lantern(Fog.Lantern.BRIGHT)
	n.wait()
	check(n.thralls[0].pos == Vector2i(8, 1), "bright: it sees you and comes")


func test_hooding_loses_it() -> void:
	var n = Night.start(CORRIDOR)
	n.set_lantern(Fog.Lantern.BRIGHT)
	n.wait()                       # it saw you at (1,1): target set
	n.set_lantern(Fog.Lantern.HOODED)
	n.step(Vector2i(2, 1))
	n.step(Vector2i(1, 1))
	check(n.thralls[0].target == Vector2i(1, 1) or n.thralls[0].target == null, "it only knows where it last saw you")
	var n2 = Night.start("#########\n#H......#\n#.#####.#\n#.......#\n######T##\n#########")
	n2.set_lantern(Fog.Lantern.HOODED)
	for i in 3:
		n2.wait()
	check(n2.thralls[0].pos == Vector2i(6, 4), "hooded and far: it never notices")


func test_adjacent_thrall_takes_you() -> void:
	var n = Night.start("######\n#H.T.#\n######")
	n.set_lantern(Fog.Lantern.HOODED)
	var ev: Array = n.wait()
	check(not n.dead, "two tiles off and hooded: still alive (it noticed nothing)")
	n.set_lantern(Fog.Lantern.NORMAL)
	ev = n.wait()
	check(n.thralls[0].pos == Vector2i(2, 1), "lit: it closes in")
	ev = n.wait()
	check(n.dead and ev.has("taken"), "next to you on its turn: you die")
	check(n.step(Vector2i(1, 1)).is_empty(), "the dead don't walk")


func test_walking_into_unseen_thrall() -> void:
	var n = Night.start("#####\n#HT.#\n#####")
	n.set_lantern(Fog.Lantern.HOODED)
	check(n.can_step(Vector2i(2, 1)), "you can't see it, so you can step there")
	var ev: Array = n.step(Vector2i(2, 1))
	check(n.dead and ev.has("grabbed"), "and it has you")
	var m = Night.start("#####\n#HT.#\n#####")
	check(not m.can_step(Vector2i(2, 1)), "lit, you see it and can't walk into it")


func test_horror_spikes_dread_once() -> void:
	var n = Night.start("##########\n#H.......#\n##########")
	n.thralls.append({pos = Vector2i(5, 1), target = null, seen = false, last_seen = null})
	n.set_lantern(Fog.Lantern.BRIGHT)
	var ev: Array = n.wait()
	check(ev.has("horror"), "a thrall stepping into your light is a horror")
	var d: int = n.dread
	n.set_lantern(Fog.Lantern.NORMAL)
	n.step(Vector2i(2, 1))
	check(n.dread <= d + Night.DREAD_HORROR, "dread doesn't spike every turn for the same sighting")


func test_reaching_exit_escapes() -> void:
	var n = Night.start("#####\n#H.E#\n#####")
	n.step(Vector2i(2, 1))
	var ev: Array = n.step(Vector2i(3, 1))
	check(n.escaped and ev.has("escaped"), "the exit ends the night")


# ---------------------------------------------------------------- first-person test: facing


func test_turning_costs_a_turn() -> void:
	var n = Night.start("#####\n#...#\n#.H.#\n#...#\n#####")
	check(n.facing == Vector2i.UP, "you start facing up the map")
	n.turn_by(1)
	check(n.facing == Vector2i.RIGHT, "turn right: up -> right")
	check(n.turn == 1 and n.oil == Night.START_OIL - 1, "a turn is a turn: the lantern burns")
	n.turn_by(-1)
	n.turn_by(-1)
	check(n.facing == Vector2i.LEFT, "two lefts from right -> left")
	for i in 4:
		n.turn_by(1)
	check(n.facing == Vector2i.LEFT, "four rights: back where you were")


func test_back_step_keeps_facing() -> void:
	var n = Night.start("#####\n#...#\n#.H.#\n#...#\n#####")
	n.step_dir(-n.facing)
	check(n.hunter == Vector2i(2, 3) and n.facing == Vector2i.UP, "backing up keeps your eyes forward")
	n.step_dir(Vector2i.RIGHT)
	check(n.facing == Vector2i.RIGHT, "walking sideways turns you that way")


func test_last_seen_marker_goes_stale() -> void:
	var n = Night.start(CORRIDOR)
	check(n.thralls[0].last_seen == null, "never seen: no marker")
	n.set_lantern(Fog.Lantern.BRIGHT)
	for i in 10:   # it notices and shambles closer until it's in the light
		n.wait()
		if n.thralls[0].last_seen != null:
			break
	check(n.thralls[0].last_seen == n.thralls[0].pos, "in your light: the marker is where it is")
	var seen_at: Vector2i = n.thralls[0].last_seen
	n.set_lantern(Fog.Lantern.HOODED)
	n.step(Vector2i(2, 1))
	check(n.thralls[0].last_seen == seen_at, "out of the light: the marker stays where you saw it")


func test_ringing_the_bell_wins_with_grade() -> void:
	var n = Night.start("####\n#HB#\n####")
	n.step(Vector2i(2, 1))
	check(n.escaped and n.rang, "stepping on the bell rings it and ends the night")
	check(n.points() == n.oil, "no letters: points = oil left")
	check(n.grade() == "S" if n.oil >= 25 else true, "grade from points")


func test_letter_needs_bright() -> void:
	var n = Night.start("#####\n#HNN#\n#...#\n#####")
	var ev: Array = n.step(Vector2i(2, 1))
	check("letter_dim" in ev and n.letters_read.is_empty(), "normal light can't read a letter")
	n.set_lantern(Fog.Lantern.BRIGHT)
	ev = n.step(Vector2i(3, 1))
	check("letter" in ev and n.letters_read.size() == 1, "bright light reads it")
	check(n.points() == n.oil + Night.LETTER_POINTS, "a letter adds to the score")


func test_oil_flask_pickup_once() -> void:
	var n = Night.start("#####\n#HO.#\n#####")
	var before: int = n.oil
	var ev: Array = n.step(Vector2i(2, 1))
	check("oil" in ev and n.oil == before - 1 + Night.FLASK_OIL, "flask adds oil (after the step's burn)")
	n.step(Vector2i(3, 1))
	n.step(Vector2i(2, 1))
	check(n.flasks_left.is_empty(), "a flask is picked up only once")


func test_one_night_map_is_winnable() -> void:
	var r = Room.parse(FileAccess.get_file_as_string("res://rooms/one_night.txt"))
	var reach: Dictionary = r.reachable(r.hunter, 999)
	check(r.bells.size() == 1 and reach.has(r.bells[0]), "the bell can be reached")
	for p in r.letters + r.oil_flasks:
		check(reach.has(p), "every letter and flask can be reached")
	for t in r.thralls:
		check((t - r.hunter).length() > 5.5, "no thrall notices you on turn 0")


const HALL := "#########\n#H.....S#\n#########"


func test_stalker_frozen_while_watched() -> void:
	var n = Night.start(HALL)
	n.facing = Vector2i.UP      # start looking at the wall: turn right to face her
	n.set_lantern(Fog.Lantern.BRIGHT)
	var at: Vector2i = n.thralls[0].pos
	check(n.thralls[0].kind == "stalker", "S parses as a stalker")
	n.turn_by(1)   # she is 6 away, outside BRIGHT radius 4: unlit, so she comes
	check(n.facing == Vector2i.RIGHT, "now facing down the hall")
	check(n.thralls[0].pos.x <= at.x - 1, "unlit: she moves")
	for i in 4:
		n.wait()
	check(not n.dead, "lit and looked at: she can't reach you")
	check(n.watched(n.thralls[0]), "she stands frozen in the light, in view")


func test_stalker_gets_you_when_you_look_away() -> void:
	var n = Night.start(HALL)
	n.facing = Vector2i.UP
	n.set_lantern(Fog.Lantern.BRIGHT)
	n.turn_by(1)
	for i in 4:
		n.wait()
	n.turn_by(-1)   # look away (up the wall): one turn with your back to her
	for i in 2:
		if not n.dead:
			n.wait()
	check(n.dead, "looking away lets her close the gap")


func test_in_view_cone() -> void:
	var n = Night.start(HALL)
	n.facing = Vector2i.RIGHT
	check(n.in_view(n.hunter + Vector2i(3, 0)), "straight ahead is in view")
	check(n.in_view(n.hunter + Vector2i(3, 1)), "a little off to the side is in view")
	check(not n.in_view(n.hunter + Vector2i(0, 1)), "beside you is not")
	check(not n.in_view(n.hunter + Vector2i(-2, 0)), "behind you is not")


func test_start_facing_open_corridor() -> void:
	var g = Night.start(FileAccess.get_file_as_string("res://rooms/one_night.txt"))
	var ahead: Vector2i = g.hunter + g.facing
	check(not g.room.is_wall(ahead), "start facing a wall")
	check(g.facing == Vector2i.RIGHT, "one_night starts looking down the long corridor east")
