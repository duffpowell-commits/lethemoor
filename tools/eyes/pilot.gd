extends RefCounted
## Eyes pilot: the balance bot's careful-player policy (tools/balance_bot.gd), one move at a time,
## as the name of the button a player would press. For Claude playing the running game.
##   {"gd": "var v = scene_tree.current_scene; v.act(load('res://tools/eyes/pilot.gd').choose(v.game))"}

const Fog = preload("res://scripts/sim/fog.gd")


static func choose(g) -> String:
	if g.over():
		return "wait"
	var near: Array = g.thralls.filter(func(th): return not th.get("gone", false) and not th.get("lying", false) \
			and g.fog.get_state(th.pos) == Fog.LIT)
	var b := _bride(g)
	if b != "":
		return b
	if near.any(func(th): return th.get("kind", "thrall") == "thrall" and _md(th.pos, g.hunter) <= 2):
		return _evade(g, near)
	var path := _safe_path(g, near, true)
	if path.size() < 2:
		path = _safe_path(g, near, false)
	if path.size() < 2:
		return "wait"
	return _toward(g, path[1] - g.hunter)


static func _toward(g, d: Vector2i) -> String:
	if d == g.facing:
		return "forward"
	if d == -g.facing:
		return "back"
	return "right" if d == Vector2i(-g.facing.y, g.facing.x) else "left"


static func _md(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _bride(g) -> String:
	for th in g.thralls:
		if th.get("kind", "thrall") != "stalker" or th.get("gone", false):
			continue
		var heard: bool = not g.in_view(th.pos) and g.room.reachable(th.pos, 2).has(g.hunter)
		if not heard and (g.fog.get_state(th.pos) != Fog.LIT or _md(th.pos, g.hunter) > 4):
			continue
		if not g.in_view(th.pos):
			var d: Vector2i = th.pos - g.hunter
			var want := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
			return "right" if want == Vector2i(-g.facing.y, g.facing.x) else "left"
		if g.watched(th):
			return "wait"
	return ""


static func _evade(g, near: Array) -> String:
	var ahead: Vector2i = g.hunter + g.facing
	if g.hook_wear > 0 and near.any(func(th): return th.pos == ahead or th.pos == ahead + g.facing):
		return "hook"
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
		return "wait"
	return "forward" if best == g.facing else "back"


static func _safe_path(g, near: Array, remembered: bool) -> Array:
	var bad := {}
	for th in g.thralls:
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
