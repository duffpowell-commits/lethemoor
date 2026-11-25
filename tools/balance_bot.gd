extends SceneTree
## Plays many dealt nights headless with a careful-player policy and prints how they end.
##   godot --headless --path . --script tools/balance_bot.gd -- [nights=200] [night_script]
## Policy: NORMAL lantern; walk the shortest road to the bell that keeps 2 tiles clear of
## every lit horror; one within 2 -> hook it if it's ahead, else step forward/back away from it
## (never turn with one that close); boxed in -> wait. Crude on purpose: it's a yardstick for
## comparing rule changes, not a model of a good player.

const Fog = preload("res://scripts/sim/fog.gd")
const EARLY := 20                       # ~the first minute on a phone
var first_seen := -1                    # turn the first horror came into the light this night


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 200
	var script_path: String = args[1] if args.size() > 1 else "res://scripts/sim/night.gd"
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var won := 0
	var died := 0
	var stuck := 0
	var oil_sum := 0
	var turns_sum := 0
	var causes := {}
	var early := 0                      # deaths in the first EARLY turns: the first-minute check
	var death_turns: Array = []
	var seen_turns: Array = []
	var first := int(OS.get_environment("BOT_FIRST")) if OS.get_environment("BOT_FIRST") != "" else 1
	for s in range(first, first + count):
		var g = load(script_path).start(text, s)
		first_seen = -1
		_play(g)
		seen_turns.append(first_seen if first_seen >= 0 else 999)
		if g.rang:
			won += 1
			oil_sum += g.oil
			turns_sum += g.turn
		elif g.dead:
			died += 1
			death_turns.append(g.turn)
			if g.turn <= EARLY:
				early += 1
			causes[g.cause.left(28)] = causes.get(g.cause.left(28), 0) + 1
		else:
			stuck += 1
	print("nights=%d won=%d (%.0f%%) died=%d (%.0f%%) stuck=%d  avg oil at bell=%.1f  avg turns=%.1f" % [
		count, won, 100.0 * won / count, died, 100.0 * died / count, stuck,
		float(oil_sum) / maxi(won, 1), float(turns_sum) / maxi(won, 1)])
	print("causes: ", causes)
	death_turns.sort()
	print("deaths by turn %d: %d (%.0f%% of nights)  median death turn: %s" % [EARLY, early,
		100.0 * early / count, str(death_turns[death_turns.size() / 2]) if death_turns.size() > 0 else "-"])
	seen_turns.sort()
	var quiet := seen_turns.filter(func(x): return x > EARLY).size()
	print("first horror seen: median turn %d, after turn %d in %.0f%% of nights" % [
		seen_turns[seen_turns.size() / 2], EARLY, 100.0 * quiet / count])
	quit()


func _awake_lit(g) -> Array:
	return g.thralls.filter(func(th): return not th.get("gone", false) and not th.get("lying", false) \
			and g.fog.get_state(th.pos) == Fog.LIT)


func _md(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _play(g) -> void:
	var trace := OS.get_environment("BOT_TRACE") != ""
	for guard in 400:
		if g.over():
			return
		var near: Array = _awake_lit(g)
		if first_seen < 0 and near.size() > 0:
			first_seen = g.turn
		if trace:
			print(g.turn, " me=", g.hunter, " f=", g.facing, " oil=", g.oil, " lit=", near.map(func(x): return x.pos), " all=", g.thralls.map(func(x): return x.pos))
		if _face_bride(g):   # the field note's rule: never turn your back on her
			continue
		if near.any(func(th): return th.get("kind", "thrall") == "thrall" and _md(th.pos, g.hunter) <= 2):
			_evade(g, near)
			continue
		var path := _safe_path(g, near, true)   # round where you last saw them, if there's a way
		if path.size() < 2:
			path = _safe_path(g, near, false)
		if path.size() < 2:
			g.wait()
			continue
		var d: Vector2i = path[1] - g.hunter
		if d == g.facing:
			g.step_dir(d)
		elif d == -g.facing:
			g.step_dir(d)        # back up toward it: keeps your eyes where they were
		else:
			g.turn_by(1 if d == Vector2i(-g.facing.y, g.facing.x) else -1)


## The bride lit and close: look at her (she freezes), then back away with your eyes on her,
## or hook her if she's in reach. False if she isn't a problem this turn.
func _face_bride(g) -> bool:
	for th in g.thralls:
		if th.get("kind", "thrall") != "stalker" or th.get("gone", false):
			continue
		var heard: bool = not g.in_view(th.pos) and g.room.reachable(th.pos, 2).has(g.hunter)   # her breath at your neck
		if not heard and (g.fog.get_state(th.pos) != Fog.LIT or _md(th.pos, g.hunter) > 4):
			continue
		if not g.in_view(th.pos):
			var d: Vector2i = th.pos - g.hunter
			var want := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
			g.turn_by(1 if want == Vector2i(-g.facing.y, g.facing.x) else -1)
			return true
		if g.watched(th):
			g.wait()   # hold the light on her till she can't bear it (STALKER_RECOIL)
			return true
		return false
	return false


func _evade(g, near: Array) -> void:
	var ahead: Vector2i = g.hunter + g.facing
	if g.hook_wear > 0 and near.any(func(th): return th.pos == ahead or th.pos == ahead + g.facing):
		g.hook()
		return
	var best = null
	var best_d := -1
	for d in [g.facing, -g.facing]:
		var n: Vector2i = g.hunter + d
		if g.room.is_wall(n) or g.thrall_at(n) >= 0 or g.burning(n):
			continue
		var m := 999
		for th in near:
			m = mini(m, _md(th.pos, n))
		if m > best_d:
			best_d = m
			best = d
	if best == null:
		g.wait()
	else:
		g.step_dir(best)


func _safe_path(g, near: Array, remembered: bool) -> Array:
	var bad := {}
	for th in g.thralls:   # a body you can see: you walk round it, you don't step on it
		if th.get("lying", false) and g.fog.get_state(th.pos) != Fog.DARK:
			bad[th.pos] = true
	if remembered:
		for th in g.thralls:
			if th.last_seen != null and not th.get("gone", false) and not th.get("lying", false):
				for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					bad[th.last_seen + d] = true
	for th in near:
		var r := 2 if th.get("kind", "thrall") == "thrall" else 1
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) + absi(dy) <= r:
					bad[th.pos + Vector2i(dx, dy)] = true
	var goal: Vector2i = g.room.bells[0]
	var prev := {g.hunter: g.hunter}
	var q: Array[Vector2i] = [g.hunter]
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		if p == goal:
			var out: Array = [p]
			while p != g.hunter:
				p = prev[p]
				out.push_front(p)
			return out
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n := p + d
			if not prev.has(n) and not g.room.is_wall(n) and (not bad.has(n) or n == goal):
				prev[n] = p
				q.append(n)
	return []
