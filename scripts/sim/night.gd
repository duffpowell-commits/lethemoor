extends RefCounted
## One night in one room: the turn rules (M1b). Pure, no nodes; tests drive it headless.
## Every step is one turn: you move one tile (or wait), the lantern burns, dread moves,
## then every thrall acts. Two clocks pull against each other:
##   oil   burns while the lantern is lit (Light is life)
##   dread rises in the dark, falls in the light, spikes when a horror steps into view
## Thralls walk toward light. Hood the lantern and they lose you.

const Fog = preload("res://scripts/sim/fog.gd")
const Room = preload("res://scripts/sim/room.gd")
const Ward = preload("res://scripts/sim/ward.gd")

const START_OIL := 60        # One Night: the direct route is ~47 moves with turns; flasks are the margin
const DREAD_MAX := 100
const DREAD_DARK := 4          # per turn hooded or out of oil
const DREAD_LIT := -2          # per turn with the lantern lit
const DREAD_HORROR := 15       # a thrall steps into your light
const DREAD_HALLUCINATE := 50  # at or above: the view may lie (fake flickers)
const PANIC_OIL := 5           # at 100 dread you spill this much oil...
const PANIC_RESET := 60        # ...and dread drops back to here
## Thralls shamble: they step only on turns divisible by this. In first person every turn of
## your head costs a turn, so an equal-speed chaser catches you at the first corner.
const THRALL_EVERY := 2
## The Stalker: frozen while it stands in your light AND inside your view (you're looking at
## it). Otherwise it takes STALKER_STEPS steps a turn. Looking away (a turn) is how it gets you.
const STALKER_STEPS := 1
const STALKER_WAKES := 30       # from this turn the bride hunts you blind, not just your light (Nov 25)
const STALKER_HUNT_EVERY := 3   # hunting blind she takes a step every this many turns (seeing your light: STALKER_STEPS a turn)
const STALKER_SHADOW := 6       # blind, she closes to this many walking tiles and waits there for your light
const STALKER_RECOIL := 3       # held lit and looked at this many turns running, she can't bear it and is gone into the dark
const BELL_EVERY := 10          # the bell tolls by itself on turn 1 and every this many turns after: follow it
const VIEW_COS := 0.64          # ~50 degrees either side of where you face
const GENTLE_SPARE := 1         # thralls left out of a newcomer's first nights (Record.GENTLE_NIGHTS)
const GENTLE_OIL := 15          # a newcomer's first nights start with this much more oil (8.5 plan, Nov 26)
const GENTLE_WAKES := 45        # and the bride starts hunting you blind this much later
const GENTLE_TEARS := 2         # first nights and the half-eased nights 4-6: you tear free of this many grabs
const FLASK_OIL := 12          # an oil flask found on the floor
const GRAB_OIL := 10           # the first thrall to reach you: you tear free, the lantern spilling this much
                               # (review of build 183: two in three deaths came with oil to spare, so the
                               # oil clock never felt like what killed you; now the first grab costs oil)
const BEAT_TURN := 20          # no horror in your light by this turn: one catches your scent (gap pass)
const BEAT_FROM := Vector2i(6, 9)   # walking tiles from you, out of sight, where it turns up
const UNMET_CAP := "B"          # a night where nothing came into your light can't grade above this
const HOOK_NEAR := Vector2i(3, 6)  # first nights: a boathook this many walking steps from the start
const HALF_OIL := 8             # nights 4-6 (Record.easing 1): a little extra oil, still chalked
const GRAB_STUN := 4           # turns a thrall you tore free of is down, and it loses you: time to get away (8.5 plan)
## Deeper Night (unlocked by ringing the bell once, record.gd): the bride wakes sooner and the
## flasks are thinner and you set out with less oil. Same ward, same horrors.
const DEEP_WAKES := 18
const DEEP_FLASK := 8
const DEEP_OIL := 50            # you set out with less
const LETTER_POINTS := 5       # grade: each letter read is worth this much oil
## Grade at the bell: oil left + LETTER_POINTS per letter read. [min points, grade]
## The boathook (`K` on the map): swing it at the first thing 1-2 tiles straight ahead.
## A hit shoves it back a tile and stuns it for HOOK_STUN turns (it can't move or grab you).
## Every hit bends it: after HOOK_WEAR hits it's useless. A swing at nothing costs the turn only.
const HOOK_REACH := 2
const HOOK_WEAR := 3
const HOOK_STUN := 2
## Oil slick + spark. POUR spends SLICK_OIL and soaks the tile in front of you. SPARK spends
## SPARK_OIL and lights every soaked tile you can see in your light within SPARK_RANGE (fire
## runs along touching soaked tiles). Fire burns FIRE_TURNS turns, lights the tiles around it
## like a NORMAL lantern, and anything that stands in it burns. You can't walk into fire.
const SLICK_OIL := 3
const SPARK_OIL := 1
const SPARK_RANGE := 3
const FIRE_TURNS := 3
## Noise: loud actions draw horrors. A sound of level N is heard by every horror within N tiles
## of walking distance (it goes round corners, not through walls), which then heads for the
## sound, unless it sees your light (light always wins). Plain walking, turning and waiting
## are silent, so the old routes play exactly as before; only the tools make noise.
## Thralls (Nov 19, "make them more intimidating"):
const LUNGE_COOLDOWN := 3       # 2 tiles off and seeing your light: it crouches a turn, lunges a tile, then rests this long
const ROUSE_LOOK := 2           # held in BRIGHT light this many turns running: it moves every turn till it loses you
const QUIET_NEAR := 3           # within this many tiles a thrall makes no sound (silence is the warning)
const PRINT_TURNS := 10         # a thrall's wet footprints dry after this many turns
const CORPSE_WAKE := 2          # a corpse gets up when you're this close and it's not in your view cone
const RISE_TURNS := 1           # getting up costs it this many of its turns
const NOISE := {"hook_hit": 4, "hook_miss": 3, "pour": 2, "spark": 3, "fire": 3}
const RANKS := ["S", "A", "B", "C", "D"]
const GRADES := [[35, "S"], [29, "A"], [23, "B"], [18, "C"], [0, "D"]]   # +15 on Nov 19 when start oil went 45 -> 60
## How far a thrall notices your lantern (tiles, needs line of sight).
const NOTICE := {Fog.Lantern.HOODED: 1, Fog.Lantern.NORMAL: 5, Fog.Lantern.BRIGHT: 8}

const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var room
var fog
var hunter := Vector2i.ZERO
var facing := Vector2i.UP       # first-person view looks this way (top-down ignores it)
var setting: int = Fog.Lantern.NORMAL
var oil := START_OIL
var deep := false               # Deeper Night
var gentle := false             # one of your first nights: a thrall fewer (start_dealt)
var dread := 0
var turn := 0
var dead := false
var escaped := false
var cause := ""                 # why you died, in the game's voice
var torn_free := false         # you've used up tonight's tear-frees: the next grab keeps you
var tears := 0                  # grabs you've torn free of tonight
var half := false               # nights 4-6: chalk and HALF_OIL (Record.easing 1)
var met := false                # a horror has come into your light tonight
var beat_sent := false          # the BEAT_TURN scent has been sent
var chalk := {}                 # gentle nights: fork tile -> the way toward the bell, chalked on the stones
var killed_from := Vector2i.ZERO  # where what took you stood, from you (grid), for the death card
var killed_seen := false        # could you see it (lit and in front of you) when it took you
var killer := ""                # what took you: "thrall" or "stalker" ("" = not a horror)
var bell_heard := false        # it has tolled once: the map knows where it hangs
var rang := false               # rang the bell (One Night's goal): escaped with a grade
var letters_read: Array = []    # letter tiles read (needs BRIGHT on the tile)
var flasks_left: Array = []     # oil flasks still on the floor
var hooks_left: Array = []      # boathooks still on the floor
var hook_wear := 0              # hits left in the boathook in your hand (0 = no hook)
var slicks := {}                # tile -> fire turns left (0 = soaked, not lit yet)
## This turn's sounds, for the sound layer: [{pos, level, kind}] (kind is a NOISE key).
## Reset at the start of every action. Horrors that turned toward one are in `heard_by`.
var noises: Array = []
var heard_by: Array = []        # indexes into `thralls` drawn by a noise this turn
## Each thrall: {pos, target (last place it saw your light, or null), seen (in your light now),
## last_seen (where YOU last saw it, or null: the map's marker, and it can be stale),
## stun (turns left knocked down by the boathook), gone (burned: it stays in the list so the
## view's indexes hold, but it no longer counts for anything)}
var thralls: Array = []
## Wet footprints: tile -> turns until dry. Thralls leave them where they step (the view shows lit ones).
var prints := {}
var seed := 0                   # which night was dealt (0 = the map as drawn); testers quote it


## `seed` deals the night (room.shuffle): 0 = the map exactly as drawn (tests, captures).
## A dealt night as the game plays it: night `seed` gets its own walls (ward.gd), then the dealer
## places the horrors on them. Seed 0 is the handmade night, walls as drawn.
## `gentle`: one of a newcomer's first nights (Record.gentle): one thrall fewer in the ward. Not
## on a Deeper Night, which you chose to make harder. (Duff, Nov 25, "Gentler first 3 nights":
## first-timer bot won 15% of nights, 24% with one thrall fewer.)
## `half`: nights 4-6 (Record.easing 1): the chalk stays and a little more oil, but every thrall
## is dealt and you get one escape (blind first-timer, Nov 26: 41% won on first nights, 11% after).
static func start_dealt(room_text: String, seed: int, deeper := false, gentle := false, half := false) -> RefCounted:
	var ward: String = Ward.carve(room_text, seed) if seed > 0 else room_text
	if gentle and not deeper and seed > 0:
		ward = Ward.thin(ward, GENTLE_SPARE)   # same walls, a thrall fewer
	var n = start(ward, seed)
	n.deep = deeper
	n.gentle = gentle and not deeper and seed > 0
	n.half = half and not n.gentle and not deeper and seed > 0
	if deeper:
		n.oil = DEEP_OIL
	elif n.gentle:
		n.oil += GENTLE_OIL
		n._chalk_road()
		n._hook_near_start()
	elif n.half:
		n.oil += HALF_OIL
		n._chalk_road()
	return n


## First nights: the boathook lies 3-6 steps from where you start (blind first-timer, Nov 26: 36 in
## 200 newcomer first nights never found one, and night 58 died to a thrall with no defence). The
## nearest hook moves there; the others stay where the dealer put them.
func _hook_near_start() -> void:
	var near: Dictionary = room.reachable(hunter, HOOK_NEAR.y)
	var spots: Array[Vector2i] = []
	for q: Vector2i in near:
		if near[q] >= HOOK_NEAR.x and thrall_at(q) < 0 and not room.bells.has(q) and not flasks_left.has(q) \
				and not room.letters.has(q) and not hooks_left.has(q):
			spots.append(q)
	if spots.is_empty():
		return
	spots.sort()
	# lay it on the road to the bell, so walking that way picks it up (a hook off in a side room was
	# still missed by 37 of 200 newcomer first nights)
	if not room.bells.is_empty():
		var road: Array[Vector2i] = room.path_in(room.reachable(hunter, 9999), hunter, room.bells[0])
		var on_road: Array[Vector2i] = []
		for q: Vector2i in spots:
			if road.has(q):
				on_road.append(q)
		if not on_road.is_empty():
			spots = on_road
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 17 + 5
	var to: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
	if room.hooks.is_empty():
		room.hooks.append(to)
		hooks_left.append(to)
		return
	var k := 0
	for i in room.hooks.size():
		if near.get(room.hooks[i], 999) < near.get(room.hooks[k], 999):
			k = i
	if near.get(room.hooks[k], 999) <= HOOK_NEAR.y:
		return   # already one this close
	hooks_left.erase(room.hooks[k])
	room.hooks[k] = to
	hooks_left.append(to)


## Someone came this way before you and chalked the forks: at every tile where three or more ways
## meet, an arrow toward the bell (the shortest way). Only on a newcomer's first nights, where
## getting lost was what ran the oil out (first-timer bot, Nov 26).
func _chalk_road() -> void:
	chalk = {}
	if room.bells.is_empty():
		return
	var bell: Vector2i = room.bells[0]
	var dist: Dictionary = room.reachable(bell, 9999)
	for p: Vector2i in dist:
		if p == bell:
			continue
		var ways: Array[Vector2i] = []
		for d: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if dist.has(p + d):
				ways.append(d)
		if ways.size() < 3:
			continue
		var best: Vector2i = ways[0]
		for d in ways:
			if dist[p + d] < dist[p + best]:
				best = d
		chalk[p] = best


## The turn the bride starts hunting you blind.
func wakes() -> int:
	return DEEP_WAKES if deep else (GENTLE_WAKES if gentle else STALKER_WAKES)


## Oil in a flask found on the floor.
func flask_oil() -> int:
	return DEEP_FLASK if deep else FLASK_OIL


static func start(room_text: String, seed: int = 0) -> RefCounted:
	var n = load("res://scripts/sim/night.gd").new()
	n.room = Room.parse(room_text)
	n.room.shuffle(seed)
	n.seed = seed
	n.fog = n.room.make_fog()
	n.hunter = n.room.hunter
	n.flasks_left = n.room.oil_flasks.duplicate()
	n.hooks_left = n.room.hooks.duplicate()
	n.facing = n.open_way(n.hunter)
	for p: Vector2i in n.room.thralls:
		n.thralls.append({pos = p, target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false})
	for p: Vector2i in n.room.stalkers:
		n.thralls.append({pos = p, target = null, seen = false, last_seen = null, kind = "stalker", stun = 0, gone = false})
	for p: Vector2i in n.room.corpses:   # thralls playing dead: last, so map indexes above stay put
		n.thralls.append({pos = p, target = null, seen = false, last_seen = null, kind = "thrall", stun = 0, gone = false, lying = true})
	for th in n.thralls:
		th.merge({lunge_cd = 0, lit_for = 0, roused = false, lying = false, crouched = false})
	n.fog.update(n.lights())
	for th in n.thralls:
		th.seen = n.fog.get_state(th.pos) == Fog.LIT
		if th.seen:
			th.last_seen = th.pos
	return n


## The way with the longest run of open floor from `p` (ties: up, down, left, right).
## You start the night looking down a corridor, never with your nose on a wall.
func open_way(p: Vector2i) -> Vector2i:
	var best := Vector2i.UP
	var best_len := -1
	for d: Vector2i in DIRS:
		var n := 0
		while not room.is_wall(p + d * (n + 1)):
			n += 1
		if n > best_len:
			best = d
			best_len = n
	return best


## What the lantern really does this turn: no oil means hooded, whatever the button says.
func effective() -> int:
	return Fog.Lantern.HOODED if oil <= 0 else setting


## Every light this turn: your lantern, plus each burning slick (it lights like NORMAL).
func lights() -> Array:
	var out: Array = [{pos = hunter, setting = effective()}]
	for p: Vector2i in slicks:
		if slicks[p] > 0:
			out.append({pos = p, setting = Fog.Lantern.NORMAL})
	return out


func burning(p: Vector2i) -> bool:
	return slicks.get(p, 0) > 0


func thrall_at(p: Vector2i) -> int:
	for i in thralls.size():
		if thralls[i].pos == p and not thralls[i].get("gone", false):
			return i
	return -1


## Every entry's position, burned ones too (the view keeps one node per entry).
func positions() -> Array:
	return thralls.map(func(th): return th.pos)


## Positions of the horrors still walking (rules use these).
## Horrors that give themselves away (flicker, map): standing ones. A corpse lying still doesn't.
func awake_positions() -> Array:
	var out: Array = []
	for th in thralls:
		if not th.get("gone", false) and not th.get("lying", false):
			out.append(th.pos)
	return out


func live_positions(except: int = -1) -> Array:
	var out: Array = []
	for i in thralls.size():
		if i != except and not thralls[i].get("gone", false):
			out.append(thralls[i].pos)
	return out


func over() -> bool:
	return dead or escaped


func flickers() -> bool:
	return fog.flickers(hunter, awake_positions())


## Where the things making the flame gutter are (unseen, within Fog.FLICKER_RANGE).
func flicker_from() -> Array:
	return fog.near_unseen(hunter, awake_positions())


func hallucinating() -> bool:
	return dread >= DREAD_HALLUCINATE


## Can you take one step onto `p`? (4-way neighbour, floor, no thrall you can SEE there.)
## An unseen thrall doesn't block: you walk into it. That's the point of the dark.
func can_step(p: Vector2i) -> bool:
	if over() or room.is_wall(p) or burning(p) or (p - hunter).abs().x + (p - hunter).abs().y != 1:
		return false
	var i := thrall_at(p)
	return i < 0 or fog.get_state(p) != Fog.LIT or down(i)


## A thrall that's down this turn (hooked, or reeling after you tore free): you can shove past it.
func down(i: int) -> bool:
	var th: Dictionary = thralls[i]
	return th.get("stun", 0) > 0 and th.get("kind", "thrall") == "thrall" and not th.get("lying", false) and not th.get("gone", false)


## Take one turn moving onto `p`. Returns the events that happened (strings), [] if illegal.
func step(p: Vector2i) -> Array:
	if not can_step(p):
		return []
	_quiet()
	var events: Array = []
	var at := thrall_at(p)
	if at >= 0 and thralls[at].get("lying", false):
		_rise(at, events)   # you trip over a body in the dark, and it isn't dead
		return _end_turn(events)
	if at >= 0 and down(at):
		# it's down (hooked, or reeling from your tearing free): you shove past it, and it's behind you
		var th: Dictionary = thralls[at]
		th.pos = hunter
		if p - hunter != -facing:
			facing = p - hunter
		hunter = p
		events.append("shoved_past")
		return _end_turn(events)
	if at >= 0 and not torn_free and thralls[at].get("kind", "thrall") == "thrall":
		_tear_free(thralls[at], events)   # you walked into it: its hands are on you, and you wrench free
		return _end_turn(events)
	if at >= 0:
		killer = thralls[at].get("kind", "thrall")
		_mark_killer(thralls[at])
		_die("Something was standing in the dark. It was waiting.")
		events.append("grabbed")
		return events
	if p - hunter != -facing:
		facing = p - hunter   # walking turns you to face where you go; backing up doesn't
	hunter = p
	return _end_turn(events)


## Step one tile in a grid direction (first person: forward is `facing`, back is -facing).
## Facing doesn't change when you step back: you retreat with your eyes on the dark.
func step_dir(d: Vector2i) -> Array:
	return step(hunter + d)


## Turn 90 degrees. Costs a whole turn: the world moves while you look away.
## `side` is +1 for right (clockwise on the grid), -1 for left.
func turn_by(side: int) -> Array:
	if over():
		return []
	_quiet()
	facing = Vector2i(-facing.y, facing.x) if side > 0 else Vector2i(facing.y, -facing.x)
	return _end_turn([])


## Stand still for a turn (hide hooded, let a thrall pass).
func wait() -> Array:
	if over():
		return []
	_quiet()
	return _end_turn([])


## The thrall a swing would hit now: the first one up to HOOK_REACH tiles ahead, short of a
## wall, or -1. Shared by hook() and the view's "it's in reach" glow, so the two always agree.
func hook_target() -> int:
	for r in range(1, HOOK_REACH + 1):
		var t: Vector2i = hunter + facing * r
		if room.is_wall(t):
			return -1
		var i := thrall_at(t)
		if i >= 0:
			return i
	return -1


## Swing the boathook down the way you face. Costs a turn. [] if you have no hook.
func hook() -> Array:
	if over() or hook_wear <= 0:
		return []
	_quiet()
	var events: Array = []
	var hit := hook_target()
	if hit < 0:
		events.append("hook_miss")
		make_noise(hunter, "hook_miss")
		return _end_turn(events)
	var th: Dictionary = thralls[hit]
	th.stun = HOOK_STUN
	th["crouched"] = false
	var back: Vector2i = th.pos + facing
	if not room.is_wall(back) and thrall_at(back) < 0:
		th.pos = back          # shoved back a tile (into fire, if that's what's behind it)
	hook_wear -= 1
	events.append("hook_hit")
	make_noise(hunter, "hook_hit")
	if hook_wear == 0:
		events.append("hook_broke")
	return _end_turn(events)


## Pour oil on the tile in front of you. Costs a turn and SLICK_OIL. [] if you can't.
func pour() -> Array:
	var t: Vector2i = hunter + facing
	if over() or oil < SLICK_OIL or room.is_wall(t) or slicks.has(t):
		return []
	_quiet()
	oil -= SLICK_OIL
	slicks[t] = 0
	make_noise(hunter, "pour")
	return _end_turn(["poured"])


## Soaked tiles a spark would catch now: lit, in view, within SPARK_RANGE, in line of sight.
func sparkable() -> Array:
	var out: Array = []
	if effective() == Fog.Lantern.HOODED:
		return out
	for p: Vector2i in slicks:
		if slicks[p] == 0 and fog.get_state(p) == Fog.LIT and in_view(p) \
				and Vector2(p - hunter).length() <= SPARK_RANGE + 0.5 and fog.has_los(hunter, p):
			out.append(p)
	return out


## Throw a spark from the lantern at the oil. Costs a turn and SPARK_OIL. [] if nothing catches.
func spark() -> Array:
	var seeds := sparkable()
	if over() or seeds.is_empty() or oil < SPARK_OIL:
		return []
	_quiet()
	oil -= SPARK_OIL
	make_noise(hunter, "spark")
	var q: Array = seeds.duplicate()
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		if slicks.get(p, -1) != 0:
			continue
		slicks[p] = FIRE_TURNS
		for d: Vector2i in DIRS:
			if slicks.get(p + d, -1) == 0:
				q.append(p + d)
	var events: Array = ["ignite"]
	if burning(hunter):
		_die("The oil under your own boots caught. You burned with it.")
		events.append("burned_self")
		return events
	_burn(events)
	return _end_turn(events)


func _quiet() -> void:
	noises = []
	heard_by = []


## Record a sound this turn. Horrors react to it in _end_turn, before they act.
func make_noise(at: Vector2i, kind: String) -> void:
	noises.append({pos = at, level = NOISE[kind], kind = kind})


## Every horror in earshot of this turn's sounds heads for the loudest one it heard.
func _hear(events: Array) -> void:
	for i in thralls.size():
		var th: Dictionary = thralls[i]
		if th.get("gone", false) or th.get("lying", false):
			continue
		var best = null
		var best_level := 0
		for nz in noises:
			if nz.level <= best_level:
				continue
			var reach: Dictionary = room.reachable(th.pos, nz.level)
			if reach.has(nz.pos):
				best = nz.pos
				best_level = nz.level
		if best != null and th.target != best:
			th.target = best
			heard_by.append(i)
	if not heard_by.is_empty():
		events.append("heard")


## Whatever stands in fire burns.
func _burn(events: Array) -> void:
	for th in thralls:
		if not th.get("gone", false) and burning(th.pos):
			th.gone = true
			th.seen = false
			if not events.has("burned"):
				events.append("burned")


## Change the lantern. Free: costs no turn (the cost is in the next step's oil and dread).
func set_lantern(s: int) -> void:
	setting = s
	fog.update(lights())


func _end_turn(events: Array) -> Array:
	turn += 1
	var lit := effective() != Fog.Lantern.HOODED
	for p: Vector2i in prints.keys():
		prints[p] -= 1
		if prints[p] <= 0:
			prints.erase(p)
	oil = Fog.burn(oil, effective())
	if room.exits.has(hunter):
		escaped = true
		events.append("escaped")
		return events
	if room.bells.has(hunter):
		escaped = true
		rang = true
		events.append("rang")
		return events
	if hooks_left.has(hunter):
		hooks_left.erase(hunter)
		hook_wear = HOOK_WEAR
		events.append("hook_found")
	if flasks_left.has(hunter):
		flasks_left.erase(hunter)
		oil += flask_oil()
		events.append("oil")
	if room.letters.has(hunter) and not letters_read.has(hunter):
		if effective() == Fog.Lantern.BRIGHT:
			letters_read.append(hunter)
			events.append("letter")
		else:
			events.append("letter_dim")
	if turn % BELL_EVERY == 1 and not room.bells.is_empty():
		bell_heard = true
		events.append("toll")   # the bell rings itself: you hear which way it is
	fog.update(lights())
	dread += DREAD_LIT if lit else DREAD_DARK
	_horrors(events)
	_beat(events)
	for p: Vector2i in slicks:
		if slicks[p] > 0:
			make_noise(p, "fire")   # fire crackles: it draws them in, and they walk into it
	_hear(events)
	_thralls_act(events)
	if dead:
		return events
	_burn(events)
	for p: Vector2i in slicks.keys():
		if slicks[p] > 0:
			slicks[p] -= 1
			if slicks[p] == 0:
				slicks.erase(p)    # burnt out: the oil is gone
	fog.update(lights())
	_horrors(events)
	dread = clampi(dread, 0, DREAD_MAX)
	if dread >= DREAD_MAX:
		oil = maxi(0, oil - PANIC_OIL)
		dread = PANIC_RESET
		events.append("panic")
		fog.update(lights())
	if oil == 0 and lit:
		events.append("out_of_oil")
	return events


## A thrall stepping into your light is a horror, once per sighting.
func _horrors(events: Array) -> void:
	for th in thralls:
		if th.get("gone", false):
			continue
		var now: bool = fog.get_state(th.pos) == Fog.LIT
		if now and not th.seen and not th.get("lying", false):
			met = true
			dread += DREAD_HORROR
			if not events.has("horror"):
				events.append("horror")
		th.seen = now
		if now:
			th.last_seen = th.pos


## Every night gets its first scare (blind first-timer, Nov 26: a night with nothing in it
## felt empty and still earned an S). If no horror has come into your light by BEAT_TURN, the
## nearest standing thrall catches your scent: it turns up BEAT_FROM walking tiles away, on a
## tile you can't see, and comes for you. Fog is truth: it only ever appears in the dark.
func _beat(events: Array) -> void:
	if met or beat_sent or turn < BEAT_TURN:
		return
	beat_sent = true
	var near: Dictionary = room.reachable(hunter, BEAT_FROM.y)
	var spots: Array[Vector2i] = []
	for q: Vector2i in near:
		if near[q] >= BEAT_FROM.x and fog.get_state(q) != Fog.LIT and thrall_at(q) < 0 and not burning(q) \
				and not room.bells.has(q):
			spots.append(q)
	var k := -1
	var best := INF
	for i in thralls.size():
		var th: Dictionary = thralls[i]
		if th.get("kind", "thrall") != "thrall" or th.get("gone", false) or th.get("lying", false):
			continue
		var d := Vector2(th.pos - hunter).length()
		if d < best:
			best = d
			k = i
	if k < 0 or spots.is_empty():
		return
	spots.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + turn
	var th: Dictionary = thralls[k]
	th.pos = spots[rng.randi_range(0, spots.size() - 1)]
	th.target = hunter
	th.seen = false
	th.stun = 0
	events.append("scent")


func _sees_light(th: Dictionary) -> bool:
	var d := Vector2(hunter - th.pos).length()
	return d <= NOTICE[effective()] + 0.5 and fog.has_los(th.pos, hunter)


## Each thrall: next to you, it takes you. Sees your light, it comes. Lost you, it goes to
## the last place it saw you, then stands there.
## Is `p` in front of you, inside the view cone? (Your own tile counts as not.)
func in_view(p: Vector2i) -> bool:
	var d := Vector2(p - hunter)
	if d == Vector2.ZERO:
		return false
	return d.normalized().dot(Vector2(facing)) >= VIEW_COS


## Is the bride hunting you now (awake, not burned)? She shadows you just past your light.
func stalker_hunting(th: Dictionary) -> bool:
	return th.get("kind", "thrall") == "stalker" and not th.get("gone", false) and turn >= wakes()


## A Stalker holds still only while it's lit and you're looking right at it.
func watched(th: Dictionary) -> bool:
	return fog.get_state(th.pos) == Fog.LIT and in_view(th.pos)


func _stalker_act(i: int, events: Array) -> void:
	var th: Dictionary = thralls[i]
	if th.get("stun", 0) > 0:
		th.stun -= 1
		return
	# she hunts: from STALKER_WAKES she always knows where you are and comes, slowly, blind;
	# when she sees your light she comes fast
	var blind_hunt: bool = turn >= wakes() and not _sees_light(th) and th.target == null \
			and not room.reachable(th.pos, STALKER_SHADOW).has(hunter)
	if blind_hunt and turn % STALKER_HUNT_EVERY != 0:
		return
	if watched(th):
		th.lit_for = th.get("lit_for", 0) + 1
		if th.lit_for >= STALKER_RECOIL:
			_recoil(i, events)
		return
	th.lit_for = 0
	for s in (1 if blind_hunt else STALKER_STEPS):
		if watched(th):
			return
		if (th.pos - hunter).abs().x + (th.pos - hunter).abs().y == 1:
			killer = "stalker"
			_mark_killer(th)
			_die("Lace, and a cold breath at your neck. You never saw her move.")
			events.append("taken")
			return
		if _sees_light(th):
			th.target = hunter
		var goal = hunter if blind_hunt else th.target
		if goal == null or th.pos == goal:
			th.target = null
			return
		var reach: Dictionary = room.reachable(th.pos, room.size.x * room.size.y, live_positions(i))
		var path: Array = room.path_in(reach, th.pos, goal)
		if path.size() < 2:
			th.target = null
			return
		th.pos = path[1]
		if burning(th.pos):
			th.gone = true
			if not events.has("burned"):
				events.append("burned")
			return
		if not events.has("stalker_moved"):
			events.append("stalker_moved")
		fog.update(lights())


## The light was on her too long: she's gone, back into the dark at least STALKER_SHADOW + 1
## walking tiles from you (the nearest such tile to where she stood). She'll be back.
func _recoil(i: int, events: Array) -> void:
	var th: Dictionary = thralls[i]
	var from_you: Dictionary = room.reachable(hunter, room.size.x * room.size.y)
	var from_her: Dictionary = room.reachable(th.pos, room.size.x * room.size.y)
	var best = null
	var best_d := 1 << 30
	var taken := live_positions(i)
	for q: Vector2i in from_her:
		if from_you.get(q, 0) <= STALKER_SHADOW or q in taken or fog.get_state(q) == Fog.LIT or q in room.bells or q in room.exits:
			continue
		var dq: int = from_her[q] * 1000 + q.x * 37 + q.y   # nearest to her; ties broken by place, not dictionary order
		if dq < best_d:
			best_d = dq
			best = q
	th.lit_for = 0
	th.target = null
	if best == null:
		return
	th.pos = best
	th.seen = false
	th.recoiled_on = turn   # the view makes her vanish, not glide
	if not events.has("recoiled"):
		events.append("recoiled")


func _thralls_act(events: Array) -> void:
	for i in thralls.size():
		var th: Dictionary = thralls[i]
		if th.get("gone", false):
			continue
		if th.get("kind", "thrall") == "stalker":
			_stalker_act(i, events)
			if dead:
				return
			continue
		th.merge({lunge_cd = 0, lit_for = 0, roused = false, lying = false, crouched = false})   # hand-made entries (tests)
		var coiled: bool = th.crouched   # crouched last turn: this turn it lunges, if it gets that far
		th.crouched = false              # every way out of this turn but a new crouch leaves it standing
		if th.lying:
			# playing dead: it waits till you're close and looking elsewhere (you walked past it)
			if room.reachable(th.pos, CORPSE_WAKE).has(hunter) and not in_view(th.pos):   # walking tiles: never through a wall
				_rise(i, events)
			continue
		if th.lunge_cd > 0:
			th.lunge_cd -= 1
		if th.get("stun", 0) > 0:
			th.stun -= 1       # knocked down by the hook (or still getting up): no move, no grab
			                   # (and out of its crouch: the next lunge needs a new tell)
			continue
		if _dist(th.pos) == 1 and not torn_free:
			_tear_free(th, events)
			continue
		if _dist(th.pos) == 1:
			killer = "thrall"
			_mark_killer(th)
			_die("Cold hands, out of the dark. The lantern rolls away.")
			events.append("taken")
			return
		var sees := _sees_light(th)
		if sees:
			th.target = hunter
		# a long look stirs it: held in your light ROUSE_LOOK turns running, it stops shambling
		var stared: bool = effective() == Fog.Lantern.BRIGHT and fog.get_state(th.pos) == Fog.LIT
		th.lit_for = th.lit_for + 1 if stared else 0   # only the high flame stirs them
		if th.lit_for >= ROUSE_LOOK and not th.roused and th.target != null:
			th.roused = true
			if not events.has("roused"):
				events.append("roused")
		if th.target == null:
			th.roused = false
			continue
		if th.pos == th.target:
			th.target = null   # it lost you: it stands where it last saw the light, and calms
			th.roused = false
			continue
		var reach: Dictionary = room.reachable(th.pos, room.size.x * room.size.y, live_positions(i))
		var path: Array = room.path_in(reach, th.pos, th.target)
		if path.size() < 2:
			th.target = null   # no way through: it gives up
			th.roused = false
			continue
		# the lunge: two tiles off and it sees you, it crouches a turn (the tell), then it comes a
		# tile, slow or not: still two off and it lands beside you (the grab is its next turn);
		# backed off and it still lurches after you and must rest. A crouch always ends in a move
		# (review of build 160: stepping in and out of reach kept it crouching forever, a
		# standoff while dread climbed and panic spilled oil).
		var in_reach: bool = sees and th.lunge_cd == 0 and path.size() == 3
		var lunge: bool = coiled
		th.crouched = in_reach and not lunge
		if th.crouched:
			if not events.has("crouch"):
				events.append("crouch")
			continue   # coiled: it doesn't move this turn
		if not lunge and not th.roused and turn % THRALL_EVERY != 0:
			continue   # shambling: this turn it only lurches in place
		prints[th.pos] = PRINT_TURNS   # drowned things leave wet prints
		th.pos = path[1]
		if lunge:
			th.lunge_cd = LUNGE_COOLDOWN
			if not events.has("lunge"):
				events.append("lunge")
		if not events.has("thrall_moved"):
			events.append("thrall_moved")


## The first grab of the night: you wrench free. Oil slops out of the lantern (GRAB_OIL), dread
## jumps, and the thing staggers back a tile and is down for HOOK_STUN turns. Only once a night.
func _tear_free(th: Dictionary, events: Array) -> void:
	tears += 1
	torn_free = tears >= (GENTLE_TEARS if gentle or half else 1)
	oil = maxi(0, oil - GRAB_OIL)
	dread = mini(DREAD_MAX, dread + DREAD_HORROR)
	th.stun = GRAB_STUN
	th.target = null      # it reels off and loses you for now
	th.crouched = false
	th.lunge_cd = LUNGE_COOLDOWN
	var back: Vector2i = th.pos + (th.pos - hunter)
	if not room.is_wall(back) and thrall_at(back) < 0 and back != hunter:
		th.pos = back
	events.append("torn_free")


## A corpse gets up: it's hunting you now, but rising costs it its next turn.
func _rise(i: int, events: Array) -> void:
	var th: Dictionary = thralls[i]
	th.lying = false
	th.seen = false       # up in your light: that's a horror, with its sting and dread
	th.target = hunter
	th.stun = RISE_TURNS
	th.lunge_cd = LUNGE_COOLDOWN
	if not events.has("rose"):
		events.append("rose")


## Walking distance on the grid ignoring walls (Manhattan) from you to `p`.
func _dist(p: Vector2i) -> int:
	return absi(p.x - hunter.x) + absi(p.y - hunter.y)


## Too close to hear: a thrall within QUIET_NEAR tiles makes no sound at all.
func silent(th: Dictionary) -> bool:
	return th.get("kind", "thrall") == "thrall" and room.reachable(th.pos, QUIET_NEAR).has(hunter)


## One Night score: oil left plus letters read. Only meaningful once the bell has rung.
func points() -> int:
	return oil + LETTER_POINTS * letters_read.size()


func grade() -> String:
	for g in GRADES:
		if points() >= g[0]:
			if not met and RANKS.find(g[1]) < RANKS.find(UNMET_CAP):
				return UNMET_CAP   # nothing faced tonight: a quiet walk isn't a top grade
			return g[1]
	return "D"


## Did the grade get held down because nothing came into your light? (The end card says so.)
func capped() -> bool:
	return not met and RANKS.find(grade()) == RANKS.find(UNMET_CAP) and points() >= GRADES[RANKS.find(UNMET_CAP) - 1][0]


## Remember where the thing that took you stood and whether you could see it (the death card says).
func _mark_killer(th: Dictionary) -> void:
	killed_from = th.pos - hunter
	killed_seen = fog.get_state(th.pos) == Fog.LIT and in_view(th.pos)


func _die(why: String) -> void:
	dead = true
	cause = why
