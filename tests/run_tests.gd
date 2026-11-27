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
	n.torn_free = true   # already torn free once tonight: this one keeps you
	n.set_lantern(Fog.Lantern.HOODED)
	var ev: Array = n.wait()
	check(not n.dead, "two tiles off and hooded: still alive (it noticed nothing)")
	n.set_lantern(Fog.Lantern.NORMAL)
	ev = n.wait()
	check(ev.has("crouch"), "lit, two off: it crouches")
	ev = n.wait()
	check(n.thralls[0].pos == Vector2i(2, 1), "then it closes in")
	ev = n.wait()
	check(n.dead and ev.has("taken"), "next to you on its turn: you die")
	check(n.step(Vector2i(1, 1)).is_empty(), "the dead don't walk")


func test_walking_into_unseen_thrall() -> void:
	var f = Night.start("#####\n#HT.#\n#####")
	f.set_lantern(Fog.Lantern.HOODED)
	var fe: Array = f.step(Vector2i(2, 1))
	check(not f.dead and "torn_free" in fe and f.hunter == Vector2i(1, 1) and f.thralls[0].pos == Vector2i(3, 1),
			"the first time tonight: its hands are on you, you wrench free and it staggers back")
	var n = Night.start("#####\n#HT.#\n#####")
	n.torn_free = true
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
	check(n.grade() == Night.UNMET_CAP and n.capped(), "nothing faced tonight: the grade stops at B")
	n.met = true
	check(n.grade() == "S" if n.oil >= 35 else true, "grade from points")


func test_every_night_gets_a_scare() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var n = Night.start_dealt(text, 21, false, true)
	n.set_lantern(Fog.Lantern.HOODED)
	var ev: Array = []
	for i in Night.BEAT_TURN:
		ev += n.wait()
	check(n.met or ("scent" in ev and n.beat_sent), "by BEAT_TURN, with nothing met, a thrall catches your scent")
	if "scent" in ev:
		var th = n.thralls.filter(func(t): return t.target == n.hunter and t.get("kind", "thrall") == "thrall")
		check(not th.is_empty(), "and it's coming for you")


func test_scent_retries_when_no_safe_spawn() -> void:
	var n = Night.start("###############\n#H..........T.#\n###############")
	n.turn = Night.BEAT_TURN
	var ev: Array = []
	# Temporarily block every candidate with a burning slick.
	for x in range(7, 11):
		n.slicks[Vector2i(x, 1)] = 3
	n._beat(ev)
	check(not n.beat_sent and not ev.has("scent"), "no safe spot does not spend scent beat")
	n.slicks.clear()
	n.turn += 1
	n._beat(ev)
	check(n.beat_sent and ev.has("scent"), "later safe spot triggers scent")
	var count := ev.count("scent")
	n._beat(ev)
	check(ev.count("scent") == count, "successful beat only fires once")


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
	n.turn_by(-1)   # look away (up the wall): with your back to her she closes a step a turn
	for i in 6:
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


func test_lessons_teach_in_order() -> void:
	var Lessons = load("res://scripts/lessons.gd")
	var g = Night.start(FileAccess.get_file_as_string("res://rooms/one_night.txt"))
	var seen := {}
	check(Lessons.due(g, seen) == "goal", "the first card is the goal")
	seen["goal"] = true
	check(Lessons.due(g, seen) == "", "nothing else on turn 0")
	g.set_lantern(Fog.Lantern.HOODED)
	check(Lessons.due(g, seen) == "hood", "hooding explains hooding")
	seen["hood"] = true
	check(Lessons.due(g, seen, "panic") == "panic", "panic event gets its card")
	var b = Night.start("########\n#..H...#\n########\n")
	b.facing = Vector2i.RIGHT
	b.thralls.append({"pos": Vector2i(1, 1), "kind": "thrall", "target": null, "last_seen": null})
	check(Lessons.due(b, {"goal": true}) == "behind", "a horror at your back gets the spin-round card")
	b.facing = Vector2i.LEFT
	check(Lessons.due(b, {"goal": true}) != "behind", "looking at it: no behind card")
	check(Lessons.CARDS.goal[1].length() < 260, "the first card stays short enough to read on a phone")
	for id in Lessons.ORDER:
		check(Lessons.CARDS.has(id), "every lesson has a card: " + id)


# ---------------------------------------------------------------- boathook + oil slick

const HOOK_HALL := "#########\n#HK...T.#\n#########"


func test_boathook_pickup_and_reach() -> void:
	var n = Night.start(HOOK_HALL)
	n.facing = Vector2i.RIGHT
	check(n.hook().is_empty(), "no hook in hand: can't swing, no turn spent")
	check(n.turn == 0, "a refused swing costs nothing")
	var ev: Array = n.step(Vector2i(2, 1))
	check("hook_found" in ev and n.hook_wear == Night.HOOK_WEAR, "walk over the boathook to take it")
	n.step(Vector2i(3, 1))
	var th: Dictionary = n.thralls[0]
	th.pos = Vector2i(5, 1)   # 2 tiles ahead: in reach
	ev = n.hook()
	check("hook_hit" in ev, "the hook reaches 2 tiles")
	check(th.pos == Vector2i(6, 1), "a hit shoves it back a tile")
	check(n.hook_wear == Night.HOOK_WEAR - 1, "a hit bends the hook")
	th.pos = Vector2i(6, 1)
	ev = n.hook()
	check("hook_miss" in ev and n.hook_wear == Night.HOOK_WEAR - 1, "3 tiles is out of reach: a miss doesn't bend it")


func test_hook_target_matches_the_swing() -> void:
	var n = Night.start(HOOK_HALL)
	n.facing = Vector2i.RIGHT
	n.step(Vector2i(2, 1))
	n.step(Vector2i(3, 1))
	var th: Dictionary = n.thralls[0]
	th.pos = Vector2i(5, 1)
	check(n.hook_target() == 0, "2 ahead: HOOK IT glows")
	th.pos = Vector2i(6, 1)
	check(n.hook_target() == -1, "3 ahead: out of reach, no glow")
	n.facing = Vector2i.LEFT
	th.pos = Vector2i(2, 1)
	check(n.hook_target() == 0, "the glow follows the way you face")
	n.facing = Vector2i.RIGHT
	check(n.hook_target() == -1, "behind you doesn't count")


func test_boathook_saves_you_when_adjacent() -> void:
	var n = Night.start("########\n#H.....#\n########")
	n.thralls.append({pos = Vector2i(2, 1), target = null, seen = true, last_seen = null, kind = "thrall", stun = 0, gone = false})
	n.hook_wear = Night.HOOK_WEAR
	n.facing = Vector2i.RIGHT
	n.hook()
	check(not n.dead, "hooked, knocked back and stunned: it can't grab you this turn")
	check(n.thralls[0].pos == Vector2i(3, 1), "knocked back to 2 tiles")
	n.wait()
	check(not n.dead, "still stunned on the next turn")


func test_boathook_breaks_after_wear() -> void:
	var n = Night.start("#######\n#H....#\n#######")
	n.thralls.append({pos = Vector2i(2, 1), target = null, seen = true, last_seen = null, kind = "thrall", stun = 0, gone = false})
	n.hook_wear = Night.HOOK_WEAR
	n.facing = Vector2i.RIGHT
	var ev: Array = []
	for i in Night.HOOK_WEAR:
		n.thralls[0].pos = Vector2i(2, 1)
		ev = n.hook()
	check("hook_broke" in ev and n.hook_wear == 0, "it bends useless after HOOK_WEAR hits")
	check(n.hook().is_empty(), "a broken hook can't swing")


func test_boathook_stuns_the_stalker() -> void:
	var n = Night.start("#########\n#H......#\n#########")
	n.thralls.append({pos = Vector2i(3, 1), target = Vector2i(1, 1), seen = false, last_seen = null, kind = "stalker", stun = 0, gone = false})
	n.hook_wear = Night.HOOK_WEAR
	n.facing = Vector2i.RIGHT
	n.set_lantern(Fog.Lantern.HOODED)   # dark: she'd normally come 2 steps
	n.hook()
	check(n.thralls[0].pos == Vector2i(4, 1), "hooked in the dark: shoved back")
	n.turn_by(1)
	check(not n.dead and n.thralls[0].pos == Vector2i(4, 1), "stunned: she can't move even with your back turned")


func test_pour_costs_oil_and_soaks_ahead() -> void:
	var n = Night.start("#######\n#H....#\n#######")
	n.facing = Vector2i.RIGHT
	var before: int = n.oil
	var ev: Array = n.pour()
	check("poured" in ev, "pour works on open floor")
	check(n.slicks.get(Vector2i(2, 1), -1) == 0, "the tile ahead is soaked, not burning")
	check(n.oil == before - Night.SLICK_OIL - 1, "pour costs SLICK_OIL plus the turn's burn")
	check(n.pour().is_empty(), "can't pour twice on the same tile")
	n.facing = Vector2i.LEFT
	check(n.pour().is_empty(), "can't pour onto a wall")


func test_slick_trap_burns_a_thrall() -> void:
	var n = Night.start("##########\n#H.......#\n##########")
	n.facing = Vector2i.RIGHT
	n.pour()                      # soak (2,1)
	n.step(Vector2i(2, 1))        # walk over it (soaked oil doesn't hurt)
	n.pour()                      # soak (3,1): a two-tile slick
	n.step_dir(Vector2i.LEFT)     # back off, facing it
	check(n.facing == Vector2i.RIGHT and n.hunter == Vector2i(1, 1), "backed off with eyes on the oil")
	n.thralls.append({pos = Vector2i(3, 1), target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false})
	check(n.sparkable().size() >= 1, "lit and in view: the oil can be sparked")
	var before: int = n.oil
	var ev: Array = n.spark()
	check("ignite" in ev and "burned" in ev, "spark: whatever stands in it burns")
	check(n.thralls[0].gone, "the thrall is gone")
	check(n.burning(Vector2i(2, 1)) and n.burning(Vector2i(3, 1)), "fire runs along the soaked tiles")
	check(n.oil == before - Night.SPARK_OIL - 1, "spark costs SPARK_OIL plus the turn's burn")
	check(not n.can_step(Vector2i(2, 1)), "you can't walk into fire")
	check(n.thrall_at(Vector2i(3, 1)) == -1, "a burned thrall blocks nothing")
	for i in Night.FIRE_TURNS:
		n.wait()
	check(n.slicks.is_empty(), "the fire burns out after FIRE_TURNS")
	check(n.can_step(Vector2i(2, 1)), "and the way is open again")


func test_fire_kills_what_walks_into_it() -> void:
	var n = Night.start("##########\n#H.......#\n##########")
	n.facing = Vector2i.RIGHT
	n.pour()
	n.spark()
	check(n.burning(Vector2i(2, 1)), "fire on the tile ahead")
	n.thralls.append({pos = Vector2i(4, 1), target = Vector2i(1, 1), seen = false, last_seen = null, kind = "stalker", stun = 0, gone = false})
	n.set_lantern(Fog.Lantern.HOODED)
	check(n.watched(n.thralls[0]), "the fire lights her and you're looking: she's frozen")
	n.facing = Vector2i.LEFT     # look away: she comes, straight through the fire
	for i in 2:
		if not n.thralls[0].gone:
			n.wait()
	check(n.thralls[0].gone and not n.dead, "the bride walked through fire to reach you and burned")


func test_spark_needs_light_and_eyes() -> void:
	var n = Night.start("#######\n#H....#\n#######")
	n.facing = Vector2i.RIGHT
	n.pour()
	n.turn_by(1)
	check(n.spark().is_empty(), "can't spark oil you aren't looking at")
	n.turn_by(-1)
	n.set_lantern(Fog.Lantern.HOODED)
	check(n.spark().is_empty(), "hooded: no flame to throw")


func test_spark_under_your_own_feet_kills_you() -> void:
	var n = Night.start("#######\n#H....#\n#######")
	n.facing = Vector2i.RIGHT
	n.pour()                    # (2,1)
	n.step(Vector2i(2, 1))
	n.pour()                    # (3,1), touching the slick you stand in
	n.spark()
	check(n.dead, "fire runs back along the oil to your boots")


func test_one_night_has_a_boathook() -> void:
	var r = Room.parse(FileAccess.get_file_as_string("res://rooms/one_night.txt"))
	check(r.hooks.size() == 1 and r.reachable(r.hunter, 999).has(r.hooks[0]), "One Night has one reachable boathook")

# ---------------------------------------------------------------- sound (scripts/audio.gd)

const Audio = preload("res://scripts/audio.gd")


func test_audio_cues_follow_the_sim() -> void:
	check(Audio.cues("forward", [], true) == ["step"], "a quiet step is a footstep, not a bump")
	check(Audio.cues("forward", [], false) == ["bump"], "an unspent step is a wall bump")
	check(Audio.cues("left", [], true) == ["turn"], "turning rustles")
	check(Audio.cues("wait", [], true) == [], "waiting is silent")
	check(Audio.cues("forward", ["grabbed"], false) == ["death"], "walking into the dark kills, no bump")
	check(Audio.cues("forward", ["escaped", "rang"], true) == ["step", "bell"], "the bell, no dawn")
	check("sting" not in str(Audio.cues("forward", ["oil"], true)), "oil is not a stinger")
	check(Audio.cues("wait", ["horror", "taken"], true) == ["horror", "death"], "horror then death")
	check(Audio.cues("hook", ["hook_hit"], true) == ["hook_swing", "hook_hit"], "swing, then the hit")
	check(Audio.cues("hook", [], false) == [], "no hook in hand: no swing")
	check(Audio.cues("spark", ["burned"], true) == ["spark", "burned"], "the slick goes up, it burns")
	check(Audio.cues("spark", ["burned_self"], true) == ["spark", "death"], "you burn with it")
	check(Audio.cues("wait", ["toll"], true) == ["toll"], "the bell tolls by itself")
	check(Audio.cues("forward", ["escaped", "rang", "toll"], true) == ["step", "bell"], "ringing it drowns the toll")
	check(Audio.cues("wait", ["toll", "taken"], true) == ["death"], "no toll over your own death")


func test_audio_every_cue_has_a_clip() -> void:
	var names := ["amb_moor", "flame_loop", "heartbeat", "turn", "bump", "oil", "letter", "letter_dim",
		"sting_horror", "sting_dread", "panic", "out_of_oil", "bell", "death", "night_start", "ui_click",
		"lantern_hood", "lantern_normal", "lantern_bright", "stalker_silk", "whisper",
		"hook_swing", "hook_hit", "hook_broke", "hook_found", "pour", "ignite", "burn_shriek", "heard_turn", "fire_loop", "breath_behind", "harbor_undertone"]
	for i in 4:
		names.append("step_%d" % i)
	for i in 3:
		names.append("shuffle_%d" % i)
	for n in names:
		check(ResourceLoader.exists("res://assets/audio/%s.ogg" % n), "clip missing: " + n)
	var src := FileAccess.get_file_as_string("res://assets/audio/SOURCES.md")
	for n in names:
		check(src.contains(n + ".ogg"), "SOURCES.md doesn't list " + n)


func test_breath_behind_you() -> void:
	var g = Night.start("########\n#..H...#\n########\n")
	g.facing = Vector2i.RIGHT
	g.thralls.append({"pos": Vector2i(1, 1), "kind": "thrall", "target": null})
	check(Audio.behind(g) == [0], "two tiles behind, out of view: you hear it breathe")
	g.facing = Vector2i.LEFT
	check(Audio.behind(g) == [], "looking at it: no breath")
	g.facing = Vector2i.RIGHT
	g.thralls[0].pos = Vector2i(6, 1)
	check(Audio.behind(g) == [], "three tiles ahead: too far, and in view")
	g.facing = Vector2i.LEFT
	g.thralls[0].pos = Vector2i(5, 1)
	check(Audio.behind(g) == [0], "two tiles behind the other way")
	g.thralls[0].lying = true
	check(Audio.behind(g) == [], "playing dead: no breath")
	check(Audio.cues("about", [], true) == ["turn_about"], "spinning round rustles twice")


func test_silent_bell_before_the_stalker_moves() -> void:
	var g = Night.start("#######\n#H....#\n#.....#\n#....S#\n#######\n")
	g.facing = Vector2i.RIGHT
	g.set_lantern(Fog.Lantern.BRIGHT)
	var st: Dictionary = g.thralls[0]
	if g.watched(st):
		check(not Audio.stalker_free(g), "watched in the light: she can't move, no silence")
	g.facing = Vector2i.LEFT
	check(not g.watched(st), "turned away")
	check(Audio.stalker_free(g) == (st.target != null or g._sees_light(st)), "silence = she's free to come")
	g.thralls[0].target = g.hunter
	check(Audio.stalker_free(g), "hunting and unwatched: the bed goes quiet")
func test_every_letter_has_a_page_that_fits_a_phone() -> void:
	var Letters = load("res://scripts/letters.gd")
	var r = Room.parse(FileAccess.get_file_as_string("res://rooms/one_night.txt"))
	check(Letters.PAGES.size() >= r.letters.size(), "One Night has a written page for every letter on the map")
	for pg: Dictionary in Letters.PAGES:
		check(pg.head != "" and pg.body != "" and pg.sign != "", "page has a heading, body and signature")
		check(pg.body.split(" ", false).size() <= 80, "page body fits a phone (<= 80 words): " + pg.head)
		check(not ("AI" in pg.body.split(" ")), "no out-of-world text")
	check(Letters.page(99) == Letters.PAGES[-1], "reading past the last page repeats the last")
	check(Letters.page(0) == Letters.PAGES[0], "first letter read is always page one")

# ---------------------------------------------------------------- noise

func test_walking_is_silent() -> void:
	var n = Night.start("##########\n#H.......#\n##########")
	n.thralls.append({pos = Vector2i(5, 1), target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false})
	n.set_lantern(Fog.Lantern.HOODED)
	n.facing = Vector2i.UP
	n.step(Vector2i(2, 1))
	n.turn_by(1)
	n.wait()
	check(n.noises.is_empty() and n.heard_by.is_empty(), "steps, turns and waits make no sound")
	check(n.thralls[0].target == null, "so nothing comes")


func test_hook_swing_is_heard_round_corners() -> void:
	# the thrall is round a corner, 3 tiles of walking away
	var n = Night.start("#######\n#H..#.#\n###...#\n#######")
	n.thralls.append({pos = Vector2i(3, 2), target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false})
	n.hook_wear = Night.HOOK_WEAR
	n.set_lantern(Fog.Lantern.HOODED)
	n.facing = Vector2i.UP
	var ev: Array = n.hook()       # swing at the wall: a miss, level 3
	check("hook_miss" in ev and "heard" in ev, "the clatter is heard")
	check(n.heard_by == [0] and n.thralls[0].target == n.hunter, "it heads for where the sound was")


func test_quiet_pour_not_heard_far() -> void:
	var n = Night.start("##########\n#H.......#\n##########")
	n.thralls.append({pos = Vector2i(6, 1), target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false})
	n.set_lantern(Fog.Lantern.HOODED)
	n.facing = Vector2i.RIGHT
	var ev: Array = n.pour()
	check(n.noises.size() == 1 and n.noises[0].kind == "pour", "pouring makes a sound")
	check(not "heard" in ev and n.thralls[0].target == null, "but 5 tiles off it isn't heard (level 2)")


func test_fire_lures_them_in() -> void:
	var n = Night.start("##########\n#H.......#\n##########")
	n.facing = Vector2i.RIGHT
	n.pour()
	n.step(Vector2i(2, 1))
	n.pour()                      # (3,1)
	n.step_dir(Vector2i.LEFT)
	n.thralls.append({pos = Vector2i(4, 1), target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false})
	n.set_lantern(Fog.Lantern.NORMAL)
	n.spark()
	check(n.thralls[0].target != null, "the fire's crackle (3 tiles) draws it")
	n.set_lantern(Fog.Lantern.HOODED)   # hide: only the fire calls it
	for i in 3:
		if not n.dead:
			n.wait()
	check(n.thralls[0].gone and not n.dead, "it walked into the fire and burned")


func test_light_beats_noise() -> void:
	var n = Night.start("##########\n#H.......#\n##########")
	n.thralls.append({pos = Vector2i(4, 1), target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false})
	n.hook_wear = Night.HOOK_WEAR
	n.facing = Vector2i.LEFT
	n.set_lantern(Fog.Lantern.NORMAL)
	n.make_noise(Vector2i(7, 1), "hook_hit")
	n._hear([])
	check(n.thralls[0].target == Vector2i(7, 1), "a sound alone sends it to the sound")
	n.wait()
	check(n.thralls[0].target == n.hunter, "but once it sees your lantern it comes for you")


# ---- every night is dealt fresh (Nov 19): same walls, things moved a little, from a seed ----

func _night_layout(g) -> Array:
	return [g.room.thralls.duplicate(), g.room.stalkers.duplicate(), g.room.corpses.duplicate(), g.room.oil_flasks.duplicate(), g.room.letters.duplicate()]


func test_seed_zero_is_the_handmade_night() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	check(_night_layout(Night.start(text, 0)) == _night_layout(Night.start(text)), "seed 0 keeps the map as drawn (tests and captures rely on it)")


func test_same_seed_same_night_and_seeds_differ() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	check(_night_layout(Night.start(text, 41)) == _night_layout(Night.start(text, 41)), "a seed always deals the same night")
	var seen := {}
	for s in range(1, 21):
		seen[str(_night_layout(Night.start(text, s)))] = true
	check(seen.size() >= 15, "20 seeds give at least 15 different nights (got %d)" % seen.size())


func test_dealt_nights_stay_fair() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var base = Night.start(text, 0)
	for s in range(1, 301):
		var g = Night.start(text, s)
		var r = g.room
		var from_start: Dictionary = r.reachable(r.hunter, r.size.x * r.size.y)
		var route: Array = r.path_in(from_start, r.hunter, r.bells[0])
		check(r.thralls.size() == base.room.thralls.size() and r.stalkers.size() == base.room.stalkers.size() and r.corpses.size() == base.room.corpses.size() \
				and r.oil_flasks.size() == base.room.oil_flasks.size() and r.letters.size() == base.room.letters.size(),
				"seed %d keeps every count" % s)
		var used := {r.hunter: true, r.bells[0]: true}
		for k in r.hooks:
			used[k] = true
		for p in r.thralls + r.stalkers + r.corpses + r.oil_flasks + r.letters:
			check(not r.is_wall(p), "seed %d: %s is on floor" % [s, p])
			check(not used.has(p), "seed %d: %s is shared or sits on the start, bell or hook" % [s, p])
			used[p] = true
		for p in r.corpses:
			check(r.dead_end(p), "seed %d: the body at %s lies in a dead end, not across a corridor" % [s, p])
		for p in r.thralls + r.stalkers + r.corpses:
			check(from_start.get(p, 0) >= Room.SAFE_START, "seed %d: horror at %s is too close to the start" % [s, p])
		for p in r.stalkers:
			check(not p in route, "seed %d: the Stalker at %s blocks the straight road to the bell" % [s, p])
		for p in r.letters:
			var beside := false
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				beside = beside or r.is_wall(p + d)
			check(beside, "seed %d: letter at %s has a wall to hang on" % [s, p])
		check(g.thralls.size() == r.thralls.size() + r.stalkers.size() + r.corpses.size() and g.flasks_left.size() == r.oil_flasks.size(),
				"seed %d: the night uses the dealt layout" % s)
		if failures > 0:
			return


# ---------------------------------------------------------------- "all four" (Nov 25: Duff's play-test fixes)

func test_bell_tolls_and_the_map_learns_it() -> void:
	var g = Night.start("#######\n#H...B#\n#######")
	g.facing = Vector2i.UP
	check(not g.bell_heard, "before the first turn nobody knows where it hangs")
	var ev: Array = g.wait()
	check("toll" in ev and g.bell_heard, "turn 1: the bell tolls by itself and the map knows it")
	var tolls := 0
	for i in Night.BELL_EVERY * 2:
		if "toll" in g.wait():
			tolls += 1
	check(tolls == 2, "then once every BELL_EVERY turns (%d)" % tolls)


func test_bride_hunts_blind_after_she_wakes() -> void:
	var g = Night.start("###################\n#H...............S#\n###################")
	g.facing = Vector2i.UP
	g.set_lantern(Fog.Lantern.HOODED)   # she can't see you: before she wakes she stays put
	var at: Vector2i = g.thralls[0].pos
	for i in 5:
		g.wait()
	check(g.thralls[0].pos == at, "asleep: she doesn't know where you are")
	g.turn = Night.STALKER_WAKES
	for i in Night.STALKER_HUNT_EVERY * 3:
		g.wait()
	check(g.thralls[0].pos.x < at.x, "awake: she comes for you in the dark")
	var close := false
	for i in 60:
		g.wait()
	close = g.room.reachable(g.thralls[0].pos, Night.STALKER_SHADOW).has(g.hunter)
	check(close and not g.dead, "blind she stops at the edge, STALKER_SHADOW tiles off, and waits for your light")
	check(Audio.stalker_free(g), "hunting and near: the bed goes quiet")


func test_held_light_drives_the_bride_off() -> void:
	var g = Night.start("###########\n#H..S.....#\n###########")
	g.facing = Vector2i.RIGHT
	g.set_lantern(Fog.Lantern.BRIGHT)
	var ev: Array = []
	for i in Night.STALKER_RECOIL:
		ev = g.wait()
	check("recoiled" in ev, "held in the light STALKER_RECOIL turns, she can't bear it")
	check(g.room.reachable(g.hunter, Night.STALKER_SHADOW).has(g.thralls[0].pos) == false and not g.dead,
			"she's gone into the dark, past STALKER_SHADOW")
	check(not g.thralls[0].pos in g.room.bells and g.thralls[0].get("recoiled_on", -1) == g.turn, "never onto the bell; the view knows she vanished this turn")


func test_dealt_nights_put_a_thrall_near_the_start() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var hits := 0
	for s in range(1, 101):
		var r = Night.start_dealt(text, s).room
		var from_start: Dictionary = r.reachable(r.hunter, r.size.x * r.size.y)
		var route: Array = r.path_in(from_start, r.hunter, r.bells[0])
		for p: Vector2i in r.thralls:
			var on_road := p in route
			var d: int = from_start.get(p, 999)
			if d >= Room.EARLY.x and d <= Room.EARLY.y and not on_road:
				hits += 1
				break
	check(hits >= 80, "most dealt nights have a thrall EARLY steps in, off the road (%d/100)" % hits)


# ---------------------------------------------------------------- thralls, made worse (Nov 19)

const LONG := "###########\n#H........#\n###########"


func _thrall_at(n, p: Vector2i, extra := {}) -> Dictionary:
	var th := {pos = p, target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false}
	th.merge(extra, true)
	n.thralls.append(th)
	return th


func test_thrall_lunges_from_two_tiles() -> void:
	var n = Night.start(LONG)
	n.facing = Vector2i.RIGHT
	var th := _thrall_at(n, Vector2i(3, 1))
	var ev: Array = n.wait()
	check("crouch" in ev and th.pos == Vector2i(3, 1), "two tiles off, it sees the light: first it crouches (the tell)")
	n.turn = 2          # its next turn would be an off (shambling) turn: the lunge ignores that
	ev = n.wait()
	check("lunge" in ev and th.pos == Vector2i(2, 1), "still there: it lunges a tile")
	check(not n.dead, "a lunge closes the gap; the grab comes on its next turn")
	n.step_dir(Vector2i.LEFT)   # back into the wall: no turn spent
	var before: int = n.oil
	ev = n.wait()
	check(not n.dead and "torn_free" in ev, "stand there after a lunge and it grabs: the first time tonight, you tear free")
	check(before - n.oil >= Night.GRAB_OIL and th.stun > 0 and th.pos == Vector2i(3, 1), \
			"it costs GRAB_OIL, and the thing staggers back a tile and is down")
	for i in 12:
		n.wait()
		if n.dead:
			break
	check(n.dead, "stand there and it comes again: the second grab keeps you")


func test_first_grab_tears_free_once() -> void:
	var n = Night.start("#######\n#H....#\n#######")
	n.facing = Vector2i.RIGHT
	var th := _thrall_at(n, Vector2i(2, 1), {target = Vector2i(1, 1)})
	var oil0: int = n.oil
	var ev: Array = n.wait()
	check(not n.dead and "torn_free" in ev and n.torn_free, "next to you on its turn, the first time: you tear free")
	check(oil0 - n.oil >= Night.GRAB_OIL, "the lantern slops GRAB_OIL")
	check(th.pos == Vector2i(3, 1) and th.stun == Night.GRAB_STUN and th.target == null, "it staggers back a tile, is down and has lost you")
	th.stun = 0
	th.lunge_cd = 0
	th.pos = Vector2i(2, 1)
	ev = n.wait()
	check(n.dead and "taken" in ev, "the second time it has you")


func test_first_nights_tear_free_twice() -> void:
	var n = Night.start("#######\n#H....#\n#######")
	n.gentle = true
	n.facing = Vector2i.RIGHT
	var th := _thrall_at(n, Vector2i(2, 1), {target = Vector2i(1, 1)})
	n.wait()
	check(not n.dead and n.tears == 1 and not n.torn_free, "first night: the first grab leaves one escape")
	th.stun = 0
	th.lunge_cd = 0
	th.pos = Vector2i(2, 1)
	th.target = Vector2i(1, 1)
	n.wait()
	check(not n.dead and n.tears == 2 and n.torn_free, "the second grab: torn free again, none left")
	th.stun = 0
	th.lunge_cd = 0
	th.pos = Vector2i(2, 1)
	n.wait()
	check(n.dead, "the third keeps you")


func test_nights_four_to_six_are_half_eased() -> void:
	check(Record.easing({nights = 0}) == 2 and Record.easing({nights = 2}) == 2, "nights 1-3: first nights")
	check(Record.easing({nights = 3}) == 1 and Record.easing({nights = 5}) == 1, "nights 4-6: half eased")
	check(Record.easing({nights = 6}) == 0, "night 7 on: the full night")
	var n = Night.start("#######\n#H....#\n#######")
	n.half = true
	n.facing = Vector2i.RIGHT
	var th := _thrall_at(n, Vector2i(2, 1), {target = Vector2i(1, 1)})
	n.wait()
	check(not n.dead and n.tears == 1 and not n.torn_free, "half-eased night: the first grab leaves one escape too")


func test_shove_past_a_downed_thrall() -> void:
	var n = Night.start("#######\n#H....#\n#######")
	n.facing = Vector2i.RIGHT
	n.torn_free = true
	var th := _thrall_at(n, Vector2i(2, 1))
	th.stun = 2
	var ev: Array = n.step_dir(Vector2i.RIGHT)
	check("shoved_past" in ev and n.hunter == Vector2i(2, 1) and th.pos == Vector2i(1, 1) and not n.dead, "a downed thrall: you shove past and it's behind you")
	var m = Night.start("#######\n#H....#\n#######")
	m.facing = Vector2i.RIGHT
	var up := _thrall_at(m, Vector2i(2, 1))
	m.fog.update(m.lights())
	check(not m.can_step(Vector2i(2, 1)) and up.stun == 0, "one that's standing, in your light: you can't walk into it")


func test_first_nights_chalk_the_way_and_give_oil() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var g = Night.start_dealt(text, 11, false, true)
	var h = Night.start_dealt(text, 11, false, false)
	check(g.oil == h.oil + Night.GENTLE_OIL and g.wakes() == Night.GENTLE_WAKES, "first nights: more oil, the bride wakes later")
	check(not g.chalk.is_empty() and h.chalk.is_empty(), "first nights are chalked, later ones aren't")
	var bell: Vector2i = g.room.bells[0]
	var dist: Dictionary = g.room.reachable(bell, 9999)
	var ok := true
	for p: Vector2i in g.chalk:
		ok = ok and dist.has(p + g.chalk[p]) and dist[p + g.chalk[p]] == dist[p] - 1
	check(ok, "every chalk arrow points one step nearer the bell")
	var d = Night.start_dealt(text, 11, true, true)
	check(d.chalk.is_empty() and not d.gentle, "a Deeper Night is never gentle")


func test_death_card_says_why() -> void:
	var n = Night.start("#######\n#.H...#\n#######")
	n.facing = Vector2i.RIGHT
	n.torn_free = true
	var th := _thrall_at(n, Vector2i(1, 1), {target = Vector2i(2, 1)})
	n.set_lantern(Fog.Lantern.NORMAL)
	n.wait()
	check(n.dead and n.killed_from == Vector2i.LEFT, "it took you from behind")
	var why: Array = Lessons.death(n)
	check(why[0] == "BEHIND YOU, OUT OF THE DARK" and why[1].contains("red mark"), "the card names the side and points at the red mark")
	var rec := Record.blank()
	check(Record.next_goal(rec).contains("DEEPER NIGHT"), "first goal: ring the bell once")
	Record.add_night(rec, true, "C", false)
	check(Record.next_goal(rec).contains("grade B"), "then a keepsake")


func test_heard_names_what_moved() -> void:
	var n = Night.start("#############\n#......H....#\n#############")
	n.facing = Vector2i.RIGHT
	var th := _thrall_at(n, Vector2i(1, 1))
	var before: Array = n.positions()
	th.pos = Vector2i(2, 1)   # 5 tiles behind: past QUIET_NEAR, within earshot
	check(Audio.heard(n, before) == ["thrall", Vector2i(2, 1)], "a thrall shuffled behind you, out of sight: the subtitle says so")
	before = n.positions()
	check(Audio.heard(n, before).is_empty(), "nothing moved: nothing to say")


func test_lunge_rests_and_backing_off_works() -> void:
	var n = Night.start("###########\n#.....H...#\n###########")
	n.facing = Vector2i.RIGHT
	var th := _thrall_at(n, Vector2i(8, 1))
	n.wait()
	n.wait()
	check(th.pos == Vector2i(7, 1) and th.lunge_cd == Night.LUNGE_COOLDOWN, "it crouched, lunged, and must rest")
	for i in 3:
		n.step_dir(Vector2i.LEFT)   # back away, facing it
	check(not n.dead, "backing off while it rests gets you clear")


func test_long_look_rouses_a_thrall() -> void:
	var n = Night.start("##############\n#H...........#\n##############")
	n.facing = Vector2i.RIGHT
	n.set_lantern(Fog.Lantern.BRIGHT)
	var th := _thrall_at(n, Vector2i(5, 1))
	var roused := false
	for i in 2:
		roused = roused or "roused" in n.wait()
	check(roused and th.roused, "held in the light two turns running, it stirs")
	n.set_lantern(Fog.Lantern.HOODED)
	var a: Vector2i = th.pos
	n.wait()
	check(th.pos != a or n.dead, "roused: it moves on what would be a shambling turn")


func test_corpse_plays_dead_until_you_pass() -> void:
	var n = Night.start("##########\n#H.......#\n##########")
	n.facing = Vector2i.RIGHT
	var th := _thrall_at(n, Vector2i(4, 1), {lying = true})
	n.step_dir(Vector2i.RIGHT)          # (2,1): it's ahead, in view: it stays down
	check(th.lying, "looked at, it plays dead")
	check(n.awake_positions().is_empty(), "a lying corpse doesn't make the flame gutter")
	n.turn_by(1)                         # look away, 2 tiles from it
	check(not th.lying and th.target != null, "look away while close and it gets up")
	n.turn_by(-1)
	check(not n.dead, "getting up costs it a turn")


func test_tripping_on_a_corpse_in_the_dark() -> void:
	var n = Night.start("#######\n#H....#\n#######")
	n.facing = Vector2i.RIGHT
	n.set_lantern(Fog.Lantern.HOODED)
	var th := _thrall_at(n, Vector2i(2, 1), {lying = true})
	var ev: Array = n.step_dir(Vector2i.RIGHT)
	check("rose" in ev and n.hunter == Vector2i(1, 1) and not n.dead, "you trip on it: you don't move, it wakes, you live")
	check(not th.lying, "it's up")


func test_thralls_leave_wet_prints_that_dry() -> void:
	var n = Night.start(LONG)
	n.facing = Vector2i.RIGHT
	n.set_lantern(Fog.Lantern.BRIGHT)
	var th := _thrall_at(n, Vector2i(8, 1))
	var from: Vector2i = th.pos
	for i in 2:
		n.wait()
	check(n.prints.has(from), "where it stepped from is wet")
	n.prints[from] = 1
	n.set_lantern(Fog.Lantern.HOODED)
	n.wait()
	check(not n.prints.has(from), "prints dry out")


func test_close_thralls_go_silent() -> void:
	var n = Night.start(LONG)
	var near := _thrall_at(n, Vector2i(3, 1))
	var far := _thrall_at(n, Vector2i(8, 1))
	check(n.silent(near) and not n.silent(far), "within 3 tiles a thrall makes no sound")


func test_a_crouch_always_ends_in_a_lunge() -> void:
	var n = Night.start(LONG)
	n.facing = Vector2i.LEFT     # backing away = stepping right, eyes on it
	n.hunter = Vector2i(3, 1)
	var th := _thrall_at(n, Vector2i(1, 1))
	check("crouch" in n.wait(), "it crouches")
	var ev: Array = n.step_dir(Vector2i.RIGHT)
	check("lunge" in ev and th.pos == Vector2i(2, 1) and th.lunge_cd == Night.LUNGE_COOLDOWN and not n.dead,
		"you backed off a tile: it still lurches after you, then must rest (no standoff)")
	# the review standoff: step in, it crouches; step out, step in... it must not just crouch forever
	var m = Night.start("##############\n#............#\n##############")
	m.hunter = Vector2i(6, 1)
	m.facing = Vector2i.LEFT
	var t2 := _thrall_at(m, Vector2i(4, 1))
	var lunged := false
	for i in 4:
		var e: Array = m.step_dir(Vector2i.RIGHT) if i % 2 == 0 else m.step_dir(Vector2i.LEFT)
		lunged = lunged or "lunge" in e
	check(lunged, "stepping in and out of reach: within 2 turns of the crouch it lunges")
	# a crouch that ends some other way (it lost you) doesn't hide a lunge for later
	var q = Night.start(LONG)
	q.facing = Vector2i.RIGHT
	var t3 := _thrall_at(q, Vector2i(3, 1))
	check("crouch" in q.wait(), "it crouches")
	q.set_lantern(Fog.Lantern.HOODED)    # it can't see you now
	t3.target = null                     # and it has lost you
	var e2: Array = q.wait()
	check(not "lunge" in e2 and not t3.crouched and t3.pos == Vector2i(3, 1), "it lost you: the crouch is gone, no lunge")
	q.set_lantern(Fog.Lantern.NORMAL)
	e2 = q.wait()
	check("crouch" in e2 and not "lunge" in e2, "seen again: a fresh tell first, never a lunge out of nowhere")


func test_corpse_never_rises_through_a_wall() -> void:
	var n = Night.start("#######\n#H#...#\n#.#...#\n#######")
	n.facing = Vector2i.DOWN
	var th := _thrall_at(n, Vector2i(3, 1), {lying = true})   # 2 tiles away, a wall between
	n.wait()
	check(th.lying, "a wall between you: it stays down")


func test_hook_breaks_a_crouch() -> void:
	var n = Night.start(LONG)
	n.facing = Vector2i.RIGHT
	n.hook_wear = 3
	var th := _thrall_at(n, Vector2i(3, 1))
	n.wait()
	check(th.crouched, "it crouches")
	n.hook()
	check(not th.crouched, "the hook knocks it out of the crouch")


func test_killer_is_recorded() -> void:
	var n = Night.start("#####\n#HT.#\n#####")
	n.torn_free = true
	n.set_lantern(Fog.Lantern.HOODED)
	n.step(Vector2i(2, 1))
	check(n.dead and n.killer == "thrall", "walked into a thrall in the dark: the thrall took you")


# Why (Nov 23 review): the open-app update poll re-offered the same build after LATER.
func test_updater_later_holds() -> void:
	var U = load("res://scripts/updater.gd")
	check(U.should_offer(5, 4, 0), "newer build offered")
	check(not U.should_offer(5, 4, 5), "LATER holds for that build")
	check(U.should_offer(6, 4, 5), "a build newer than the one put off is offered")
	check(not U.should_offer(9, 0, 0), "editor build (0) never offered")


# ---------------------------------------------------------------- new walls every night (Nov 25)

const Ward = preload("res://scripts/sim/ward.gd")
const Record = preload("res://scripts/sim/record.gd")
const Lessons = preload("res://scripts/lessons.gd")


func test_every_dealt_night_has_its_own_walls() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var t = Room.parse(text)
	var t_from: Dictionary = t.reachable(t.hunter, 999)
	var a: String = Ward.carve(text, 5)
	check(a == Ward.carve(text, 5), "same night number, same ward (reported nights replay)")
	check(a != Ward.carve(text, 6), "another night, other walls")
	check(Night.start_dealt(text, 0).room.rows == t.rows, "night 0 keeps the handmade walls (capture, tests)")
	for s in range(1, 41):
		var r = Room.parse(Ward.carve(text, s))
		check(r.size == t.size, "same size")
		check(r.thralls.size() == t.thralls.size() - Ward.SPARE_THRALLS and r.stalkers.size() == t.stalkers.size() \
				and r.corpses.size() == t.corpses.size() and r.letters.size() == t.letters.size() \
				and r.oil_flasks.size() == t.oil_flasks.size() and r.hooks.size() == t.hooks.size() \
				and r.bells.size() == 1, "night %d: everything the handmade night has" % s)
		var from: Dictionary = r.reachable(r.hunter, 999)
		var all: Array = r.thralls + r.stalkers + r.corpses + r.letters + r.oil_flasks + r.hooks + r.bells
		check(all.all(func(p): return from.has(p)), "night %d: every thing can be walked to" % s)
		var walk: int = from.get(r.bells[0], -1)
		check(absi(walk - t_from[t.bells[0]] - Ward.BELL_EXTRA) <= Ward.BELL_SLACK, "night %d: the bell is as far a walk as tuned (%d)" % [s, walk])
		for p: Vector2i in r.thralls + r.stalkers + r.corpses:
			check(from[p] >= Ward.HORROR_NEAR, "night %d: no horror drawn near the start" % s)
		# you meet them: some horrors stand a short WALK off the road, not just near it as the crow flies
		var road: Dictionary = Ward._road_walk(r, r.path_in(from, r.hunter, r.bells[0]))
		var close: int = (r.thralls + r.stalkers).filter(func(p): return road.get(p, 99) <= 6).size()
		check(close >= 2, "night %d: at least two horrors a short walk off the road (%d)" % [s, close])


func test_deeper_night_is_harder() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var easy = Night.start_dealt(text, 3)
	var deep = Night.start_dealt(text, 3, true)
	check(easy.room.rows == deep.room.rows, "same ward")
	check(deep.oil == Night.DEEP_OIL and easy.oil == Night.START_OIL, "you set out with less oil")
	check(deep.flask_oil() < easy.flask_oil(), "thinner flasks")
	check(deep.wakes() < easy.wakes(), "the bride wakes sooner")


func test_first_nights_are_gentler() -> void:
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var t = Room.parse(text)
	for s in [3, 41, 2026]:
		var n = Night.start_dealt(text, s)
		var g = Night.start_dealt(text, s, false, true)
		check(g.gentle and not n.gentle, "night %d: the gentle one says so" % s)
		var same := true
		for y in n.room.size.y:
			for x in n.room.size.x:
				same = same and n.room.is_wall(Vector2i(x, y)) == g.room.is_wall(Vector2i(x, y))
		check(same, "night %d: the same walls, so a reported night replays" % s)
		check(g.room.thralls.size() == t.thralls.size() - Ward.SPARE_THRALLS - Night.GENTLE_SPARE, "night %d: a thrall fewer on a first night" % s)
		var d = Night.start_dealt(text, s, true, true)
		check(not d.gentle and d.room.thralls.size() == n.room.thralls.size(), "night %d: never gentler on a Deeper Night" % s)
	var rec := Record.blank()
	for i in Record.GENTLE_NIGHTS:
		check(Record.gentle(rec), "night %d is still a first night" % (i + 1))
		Record.add_night(rec, false, "", false)
	check(not Record.gentle(rec), "after %d nights, the full ward" % Record.GENTLE_NIGHTS)


func test_the_record_unlocks_things() -> void:
	var rec := Record.blank()
	check(Record.add_night(rec, false, "", false).is_empty(), "dying unlocks nothing")
	check(rec.nights == 1 and rec.rung == 0, "but the night counts")
	var got := Record.add_night(rec, true, "C", false)
	check(got == [Record.DEEPER], "the first bell unlocks Deeper Night, a C nothing more: %s" % str(got))
	got = Record.add_night(rec, true, "A", true)
	check(got == ["keep1"], "an A earns I and II, but one keepsake a night: %s" % str(got))
	check(rec.best == "C" and rec.best_deep == "A", "best grade kept per mode")
	check(Record.add_night(rec, true, "S", false) == ["keep2"], "the next good night finds the next")
	check(Record.add_night(rec, true, "S", false).is_empty(), "the last only on a Deeper Night")
	check(Record.add_night(rec, true, "S", true) == ["keep3"], "an S on a Deeper Night finds the last")
	check(Record.add_night(rec, true, "S", true).is_empty(), "nothing twice")
	check(rec.best == "S" and rec.best_deep == "S" and rec.rung == 6, "record counts")
	var fresh := Record.blank()
	check(Record.add_night(fresh, true, "S", true) == [Record.DEEPER, "keep1"], "a perfect first night: Deeper Night and one keepsake, not all")
	check(Record.lock_text(Record.KEEPSAKES[2]).contains("Deeper"), "the guide says where the last one is")
	check(Record.news([]) == "", "nothing new, nothing said")
	check(Record.news(["deeper", "keep1"]).contains("DEEPER") and Record.news(["deeper", "keep1"]).contains("BLACK WAX"), "one line names them")
	check(Record.news(["deeper", "keep1", "keep2", "keep3"]).contains("3 KEEPSAKES"), "many keepsakes, counted")


# Why (review of build 183): "Something is near" scared you but never said from where. The chart's
# rim now marks the way of each unseen thing making the flame gutter.
func test_flicker_says_which_way() -> void:
	var n = Night.start("#########\n#H......#\n#.#######\n#.#######\n#########")
	n.set_lantern(Fog.Lantern.HOODED)
	var th := _thrall_at(n, Vector2i(3, 1))
	n.fog.update(n.lights())
	check(n.flickers() and n.flicker_from() == [Vector2i(3, 1)], "unseen and near: the flame gutters, and we know which one")
	th.pos = Vector2i(7, 1)
	check(not n.flickers() and n.flicker_from().is_empty(), "too far: no flicker, no mark")


func test_hook_presentation_keyframes() -> void:
	var View = preload("res://scripts/fp_view.gd")
	var rest: Array = View.hook_pose(0.0)
	var windup: Array = View.hook_pose(0.045)
	var contact: Array = View.hook_pose(0.10)
	check(rest == View.hook_pose(View.HOOK_ANIM_TIME), "hook settles exactly to rest")
	check(windup[1].z > 0.0 and contact[1].z < 0.0, "clearly opposed windup and sweep poses")
	check(contact[0].is_equal_approx(View.hook_pose(0.135)[0]) and contact[1].is_equal_approx(View.hook_pose(0.135)[1]), "brief presentation-only contact hold")
	check(contact[0].z < windup[0].z, "hook moves across the foreground")


func test_seeded_atmosphere_is_cosmetic_and_repeatable() -> void:
	var View = preload("res://scripts/fp_view.gd")
	var tile := Vector2i(2, 1)
	check(View.wet_floor_for(tile, 0), "seed zero preserves original wet tile layout")
	check(not View.wet_floor_for(tile, 1), "seed changes cosmetic texture selection")
	check(View.wet_floor_for(tile, 11), "repeatable wet tile selection")
	check(View.dawn_detail(1) == View.dawn_detail(1), "same seed, same dawn")
	check(View.dawn_detail(1) != View.dawn_detail(2), "different dawn detail")


func test_landmark_memory_gates() -> void:
	var View = preload("res://scripts/fp_view.gd")
	var tile := Vector2i(1, 1)
	check(View.can_shift_landmark(3, tile, 5, 13, 7, false), "eligible unseen return visit")
	check(not View.can_shift_landmark(0, tile, 5, 13, 7, false), "capture baseline unchanged")
	check(not View.can_shift_landmark(6, tile, 5, 13, 7, false), "not every seed permits a shift")
	check(not View.can_shift_landmark(3, tile, -1, 13, 7, false), "must see landmark first")
	check(not View.can_shift_landmark(3, tile, 5, 12, 7, false), "no immediate change")
	check(not View.can_shift_landmark(3, tile, 5, 13, 6, false), "player must be away")
	check(not View.can_shift_landmark(3, tile, 5, 13, 7, true), "never changes within view")


func test_rare_atmosphere_schedule() -> void:
	var path := "res://scripts/atmosphere.gd"
	check(FileAccess.file_exists(path), "cosmetic scheduler exists")
	if not FileAccess.file_exists(path):
		return
	var Atmos = load(path)
	var reflections := 0
	var sounds := 0
	for seed in range(1, 501):
		var reflection: int = Atmos.event_turn(seed, "reflection")
		var sound: int = Atmos.event_turn(seed, "sound")
		check(reflection == Atmos.event_turn(seed, "reflection"), "repeatable schedule")
		check(reflection == -1 or reflection >= 18 and reflection <= 50, "reflection late, bounded window")
		check(sound == -1 or sound >= 25 and sound <= 70, "sound late, bounded window")
		reflections += int(reflection >= 0)
		sounds += int(sound >= 0)
	check(reflections > 0 and reflections <= 100, "reflection scheduled in at most 20% of nights")
	check(sounds > 0 and sounds <= 125, "sound scheduled in at most 25% of nights")
	check(Atmos.event_turn(0, "reflection") == -1 and Atmos.event_turn(0, "sound") == -1, "capture baseline is quiet")
	check(not Atmos.eligible(20, 20, true, true), "one shot only")
	check(not Atmos.eligible(20, 20, false, false), "no cue over essential feedback")
	check(Atmos.eligible(22, 20, false, true), "quiet opportunity after scheduled turn")
	check(not Atmos.eligible(29, 20, false, true), "missed window stays missed")


func test_wall_coping_is_weathered_without_geometry_change() -> void:
	var Harbor = preload("res://scripts/harbor_geometry.gd")
	var room = Room.parse("#####\n#H..#\n#####")
	var mesh: ArrayMesh = Harbor.new().wall_for(room, Vector2i(1, 0))
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	check(colors.size() == vertices.size(), "wall vertices carry weathering")
	if colors.size() != vertices.size():
		return
	var moss := false
	var stone := false
	for i in colors.size():
		if vertices[i].y > 2.0 and colors[i].g > colors[i].r:
			moss = true
		if vertices[i].y < 1.0 and colors[i] == Color.WHITE:
			stone = true
	check(moss and stone, "moss concentrated at coping with lower stone preserved")


func test_atmosphere_yields_to_gameplay_and_silent_bell() -> void:
	var sound = load("res://scripts/audio.gd")
	check(sound.has_method("atmosphere_conflicts"), "ambient cue has a gameplay priority gate")
	if not sound.has_method("atmosphere_conflicts"):
		return
	var calm = Night.start("###########\n#H........#\n###########")
	check(not sound.atmosphere_conflicts(calm, [], calm.positions()), "quiet turn permits atmosphere")
	check(sound.atmosphere_conflicts(calm, ["toll"], calm.positions()), "bell cue takes priority")
	calm.dread = 50
	check(sound.atmosphere_conflicts(calm, [], calm.positions()), "high dread takes priority")
	var bride = Night.start("#######\n#H....#\n#.....#\n#....S#\n#######")
	bride.facing = Vector2i.LEFT
	bride.thralls[0].target = bride.hunter
	check(sound.stalker_free(bride), "Bride is free to move")
	check(sound.atmosphere_conflicts(bride, [], bride.positions()), "intentional silence takes priority")


func test_atmosphere_yields_to_stationary_hunting_thrall() -> void:
	var g = Night.start("############\n#H.....T...#\n############")
	g.facing = Vector2i.LEFT
	g.thralls[0].target = g.hunter
	check(Audio.behind(g).is_empty() and Audio.heard(g, g.positions()).is_empty(), "stationary thrall is not a moved or behind cue")
	check(Audio.atmosphere_conflicts(g, [], g.positions()), "within-earshot pursuing thrall has a shuffle priority even when stationary")
