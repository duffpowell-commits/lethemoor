extends RefCounted
## Eyes pilot that plays like a genuine first-time player (Duff, Nov 25: "We set the bots to be
## more like genuine first-time players for their reviews"). Unlike pilot.gd (the balance bot, which
## knows the whole map), it only knows what you could know from the screen:
##   - walls and floor you've seen (fog not DARK), items and horrors only while they're in view
##   - where the bell is only as the chart shows it: a direction once it has tolled
##   - the field notes' advice (back off from a crouch, hook what's in front, face the bride)
## and it makes a newcomer's mistakes: it freezes now and then when something is close, it
## doesn't know about BRIGHT, hooding, oil slicks or letters, and it walks into dead ends.
##   {"gd": "var v = scene_tree.current_scene; v.act(load('res://tools/eyes/first_timer.gd').choose(v.game))"}
## tools/first_timer_bot.gd runs it headless over many nights.

const Fog = preload("res://scripts/sim/fog.gd")
const FREEZE := 0.2        # chance it just stands there when a horror is two tiles off
const GRAB := 5            # walks this far out of its way for a flask or hook it can see
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static var visits := {}    # tile -> times stood there (this night)
static var night_key := ""


static func choose(g) -> String:
	if g.over():
		return "wait"
	var key := "%d|%d" % [g.seed, g.get_instance_id()]
	if key != night_key:
		night_key = key
		visits = {}
	visits[g.hunter] = visits.get(g.hunter, 0) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = g.seed * 131 + g.turn * 7 + 3
	var near: Array = g.thralls.filter(func(th): return not th.get("gone", false) and not th.get("lying", false) \
			and g.fog.get_state(th.pos) == Fog.LIT)
	# the bride: the note says look at her and she can't come
	for th in near:
		if th.get("kind", "thrall") == "stalker" and _md(th.pos, g.hunter) <= 4:
			if not g.in_view(th.pos):
				return _face(g, th.pos)
			return "wait"
	var close: Array = near.filter(func(th): return th.get("kind", "thrall") == "thrall" and _md(th.pos, g.hunter) <= 2)
	if not close.is_empty():
		if rng.randf() < FREEZE:
			return "wait"           # a newcomer's freeze
		var ahead: Vector2i = g.hunter + g.facing
		if g.hook_wear > 0 and close.any(func(th): return th.pos == ahead or th.pos == ahead + g.facing):
			return "hook"
		for d: Vector2i in [-g.facing, g.facing]:   # back off, eyes on it (the field note)
			var n: Vector2i = g.hunter + d
			if _known_floor(g, n) and g.thrall_at(n) < 0 and close.all(func(th): return _md(th.pos, n) > _md(th.pos, g.hunter)):
				return _toward(g, d)
		return "wait"
	var avoid := {}
	for th in near:
		for d: Vector2i in [Vector2i.ZERO] + DIRS:
			avoid[th.pos + d] = true
	var reach := _known_reach(g, avoid)
	# the bell, if you've seen it
	var bell: Vector2i = g.room.bells[0]
	if g.fog.get_state(bell) != Fog.DARK and reach.has(bell):
		return _step_to(g, reach, bell)
	# a flask or hook in sight, not far out of the way
	var want := []
	for p: Vector2i in g.flasks_left + g.hooks_left:
		if g.fog.get_state(p) != Fog.DARK and reach.has(p) and reach[p][0] <= GRAB:
			want.append(p)
	if not want.is_empty():
		want.sort_custom(func(a, b): return reach[a][0] < reach[b][0])
		return _step_to(g, reach, want[0])
	# explore: the edge of what you've seen, toward the chart's arrow once the bell has tolled
	var best = null
	var best_score := INF
	for p: Vector2i in reach:
		var unknown := 0
		for d in DIRS:
			if g.fog.get_state(p + d) == Fog.DARK and not _bounds_wall(g, p + d):
				unknown += 1
		if unknown == 0 and p != g.hunter:
			continue
		var score: float = reach[p][0] + 2.0 * visits.get(p, 0)
		if g.bell_heard:
			score += 0.8 * _md(p, bell)       # the arrow says roughly where; it doesn't give a road
		if p == g.hunter:
			score += 3.0 if unknown > 0 else 99.0
		if score < best_score:
			best_score = score
			best = p
	if best == null or best == g.hunter:
		# nothing new in reach: look around (turning shows the dark you haven't looked at)
		return "right" if rng.randf() < 0.5 else "left"
	return _step_to(g, reach, best)


## Breadth-first over floor you've seen. tile -> [steps, first step direction].
static func _known_reach(g, avoid: Dictionary) -> Dictionary:
	var out := {g.hunter: [0, Vector2i.ZERO]}
	var q: Array[Vector2i] = [g.hunter]
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		for d in DIRS:
			var n: Vector2i = p + d
			if out.has(n) or not _known_floor(g, n) or avoid.has(n) or g.burning(n):
				continue
			out[n] = [out[p][0] + 1, d if p == g.hunter else out[p][1]]
			q.append(n)
	return out


static func _known_floor(g, p: Vector2i) -> bool:
	return g.fog.get_state(p) != Fog.DARK and not g.room.is_wall(p)


static func _bounds_wall(g, p: Vector2i) -> bool:
	return p.x <= 0 or p.y <= 0 or p.x >= g.room.size.x - 1 or p.y >= g.room.size.y - 1


static func _step_to(g, reach: Dictionary, target: Vector2i) -> String:
	if target == g.hunter:
		return "wait"
	return _toward(g, reach[target][1])


static func _face(g, p: Vector2i) -> String:
	var d: Vector2i = p - g.hunter
	var want := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
	if want == -g.facing:
		return "right"
	return "right" if want == Vector2i(-g.facing.y, g.facing.x) else "left"


static func _toward(g, d: Vector2i) -> String:
	if d == g.facing:
		return "forward"
	if d == -g.facing:
		return "back"
	return "right" if d == Vector2i(-g.facing.y, g.facing.x) else "left"


static func _md(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
