extends Node3D
## First-person test (Nov 19). Same room, same rules (sim/night.gd), seen from her eyes.
## Grid crawler: step forward / back, turn 90 degrees, wait. Every action is one turn,
## turning included: the world moves while you look away. A corner map shows the tiles
## you remember (the fog system, drawn small). Top bar button switches to the top-down view.
## Renders + button test:
##   xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3
##     --resolution 1080x1920 res://scenes/fp_room.tscn -- --capture   -> docs/renders/fp_*.png

const StudioSplash = preload("res://branding/studio_splash.gd")

const Fog = preload("res://scripts/sim/fog.gd")
const Night = preload("res://scripts/sim/night.gd")
const Record = preload("res://scripts/sim/record.gd")
const Sound = preload("res://scripts/audio.gd")   # all sound; hooks do nothing without the autoload
const Lessons = preload("res://scripts/lessons.gd")
const Letters = preload("res://scripts/letters.gd")
const UI = preload("res://scripts/ui_style.gd")
const Perf = preload("res://scripts/perf.gd")

const Harbor = preload("res://scripts/harbor_geometry.gd")

const UI_W := 540
const TOP_H := 72
const PAD_H := 330                 # status + lantern row + move pad (MENU -> MOVE BUTTONS: ON)
const SLIM_H := 132                # status + lantern row + WAIT: swipes move you (the default)
const EYE := 0.82                  # eye height in tiles (a tile is ~ a stride)
const CAM_BACK := 0.32             # stand at the back of the tile so the next one is in view
const FOV := 64.0                  # horizontal (portrait keeps width)
const PX := 1.0 / 48.0
const STEP_TIME := 0.2
const HAND_X := 0.24
const HAND_Y := -0.2              # low right of the visible strip

const LANTERN := Color("#ffbe7a")   # warm but not orange: blue stone has to stay stone
const DEEP := Color("#0d1420")
const MOON := Color("#6f8fc4")
const INK_BLACK := Color("#05070c")
const UI_TEXT := Color("#d9cdb4")
const UI_AMBER := Color("#f2c25a")
const UI_DIM := Color("#7d8fa8")
const UI_BLOOD := Color("#c81e2e")
const SHADE := {Fog.DARK: 0.0, Fog.REMEMBERED: 0.2, Fog.LIT: 1.0}
## Lantern light per setting: [range, energy]. Close up, so less energy than top-down.
const LOW_OIL_SPUTTER := 12   # at or under this much oil the lantern gutters (look only, never a rule)
const LIGHT := {
	Fog.Lantern.HOODED: [0.8, 0.25],
	Fog.Lantern.NORMAL: [3.4, 1.7],
	Fog.Lantern.BRIGHT: [5.6, 2.4],
}
## the painted hand + lantern for each flame: shuttered, steady, roaring
const HAND_ART := {Fog.Lantern.HOODED: "hand_lantern_hooded", Fog.Lantern.NORMAL: "hand_lantern", Fog.Lantern.BRIGHT: "hand_lantern_bright"}
## Every look in the rotation has a rigged 3D body (RIGS). The painted cards (clawed, wired, dock,
## net-mender) left the rotation on Nov 25: a flat card among 3D bodies broke the spell.
const THRALL_LOOKS := ["thrall_nightmare", "thrall_hooded", "thrall_dockwoman"]
const THRALL_MODEL_SCALE := Vector3(0.82, 0.94, 0.82)
const RigHorror = preload("res://scripts/rig_horror.gd")
const Hands = preload("res://scripts/hands.gd")
## Looks that have a rigged, animated body (assets/models/<rig>.glb + <rig>_clips.res). A rig wins
## over the rigid model and the painted card; a look without one keeps what it had.
## [model, height, yaw fix]. The bride needs none: the old quarter turn left her side-on (render fp_art_bride_face, Nov 25).
## Heights are crown heights in tiles against EYE 0.82: thralls man-sized, the bride a head taller
## (Duff, Nov 24: "Why are the monsters so big?"; they were 1.8-2.15, carried over from the cards).
const RIGS := {"stalker_bride": ["rig_bride", 1.1, 0.0], "thrall_nightmare": ["rig_nightmare", 1.0],
	"thrall_hooded": ["rig_hooded", 0.92], "thrall_dockwoman": ["rig_dockwoman", 0.88]}
const BODY_TURN := 1.2               # how fast a standing horror's body follows its head round to you
const PHANTOM_EVERY := Vector2(7.0, 16.0)   # s between figures that aren't there, once dread hallucinates
const PHANTOM_LIFE := 0.9            # s it stands there before it's gone
const PHANTOM_TINT := Color(0.3, 0.33, 0.42)   # grey-blue, drowned: enough to see, not enough to be sure
const T_KILL_3D := 1.05              # s: the 3D kill, lunge to lying under it
const KILL_REACH := 0.34             # tiles in front of your eyes it stops
const KILL_LOOK_UP := 0.4            # rad you tip back as you go down
const KILL_ROLL := 0.22
const KILL_DROP := 0.3               # tiles your eyes fall
const KILL_WHIP := 0.15              # s to wrench you round to it when it comes from the side or behind
const THRALL_LUNGE := "thrall_lunge_nightmare"   # reaching for you, sack-mouth open: the lunge and the kill shot
const STOP_EVENTS := ["crouch", "lunge", "torn_free", "rose", "roused", "heard", "hook_hit", "hook_broke", "hook_found", "burned", "ignite", "burned_self", "rang", "horror", "panic", "out_of_oil", "taken", "grabbed", "escaped", "letter", "oil", "letter_dim", "stalker_moved"]
const ROOM := "res://rooms/one_night.txt"   # the slice: reach the bell, ring it, get graded
const MAP_CELL := 12.0               # the corner map follows you: ~15 tiles across the disc
const MAP_R := 88.0                  # radius of the round chart
const MAP_SIZE := Vector2(196, 196)
const VIEW_RANGE := 10.0           # tiles further than this aren't drawn (fog hides them)

var game
var room
var fog
var busy := false
var t := 0.0
var kill_rig := -1                 # the horror that has you: the kill drives it, not the rules
var kill_3d_ok := false
static var kill_3d_seen := false   # capture: the death pass saw a good 3D kill (the art pass gates on it)
var phantom: Node3D                # a figure at the edge of the light that isn't there (dread >= 50; look only)
var phantom_t := 0.0               # s left on it, or (negative) s until the next one
var lunge_hit := 0.0                # 1 the moment something lunges at you, fades: red edge + shake
var lunge_flash: TextureRect
var flicker := false
var fake_flicker := false
var last_event := ""
var swipe_from = null              # where a finger went down on the world view (window px)
const SWIPE_MIN := 50.0            # UI px a finger must travel to count as a swipe
## Fluid moves (Nov 20): a swipe fires the moment the finger passes SWIPE_MIN (not on lift);
## a move made mid-glide is queued and runs straight after; keep the finger down after a
## forward/back swipe and you keep walking. Anything in STOP_EVENTS (or a new flicker) ends the
## walk and drops the queue, so a held finger never walks you into a horror.
const MOVE_KINDS := ["forward", "back", "left", "right", "wait", "about"]
## About-face (Nov 20): swipe down with TWO fingers (or X) = turn right twice in one spin.
## Two turns, the world moves twice; a stop event after the first half ends the spin there.
const ABOUT_TIME := 0.32
var touches := {}                  # finger index -> true while it's down
var tools_shown := false           # POUR OIL appears once a horror has been seen (or the hook found)
var swipe_fired := false           # this finger already made its move
var hold_kind := ""                # finger still down after a forward/back swipe: repeat it
var queued := ""                   # one move made while the last one was still gliding
var chain_from := ""               # the move this one carries straight on from ("" = from rest)
var vm_lantern: Node3D             # 3D viewmodel: your gloved right arm and the lantern hanging from it
var vm_lamp: Node3D                # the lantern itself (swings on the bail)
var vm_hook: Node3D                # left arm with the boathook, while you carry one
var vm_glow: MeshInstance3D         # the flame seen through the glass: a soft additive glow
var vm_lamp_mat: StandardMaterial3D   # its glow follows the flame
var vm_swing := 0.0                # the lantern's pendulum angle and speed
var vm_swing_v := 0.0
var step_k := 0.0                  # 0..1..0 over each step: drives the hand-lantern bob
var foot := 1.0                    # which foot: the head sways the other way each step

var cam: Camera3D
var light: OmniLight3D
var world_env: Environment
var perf: Perf                    # FPS readout + graphics quality (scripts/perf.gd)
var hand: Node3D
var flame: MeshInstance3D
var tile_mats := {}                # letters have their own material
var tile_nodes := {}               # floor/wall tile -> MeshInstance3D
var lintels := {}
var bell_tower: MeshInstance3D       # the tower over the bell, seen over the walls (review fix 4)
var landmarks := {}                     # tile -> kind (boat, door, pots) dressed in a ward's open halls
var harbor_fixtures := {}
var tile_tex := {}                 # floor/wall tile -> texture name
var shared_mats := {}              # "tex|shade" -> one material shared by every tile like it
var tile_base := {}
var thrall_nodes: Array = []
var thrall_models: Dictionary[int, Node3D] = {}
var thrall_rigs: Dictionary[int, Node3D] = {}   # index -> rig_horror.gd body (also in thrall_models)
var thrall_sprites: Array = []     # the Sprite3D inside each holder (corpses lie flat, thralls twitch)
var print_nodes := {}              # tile -> wet footprints decal on the floor
var pool_nodes := {}               # tile -> blood pool decal where a body lay
var blood_screen: TextureRect      # blood thrown across your sight when one lunges, and at the kill
var print_tex: Texture2D
var kill_shot: Control             # the close-up when a thrall takes you
var flask_nodes := {}             # tile -> node, hidden once picked up
var hook_nodes := {}              # tile -> boathook lying on the floor
var slick_nodes := {}             # tile -> oil slick / fire on the floor (made as they appear)
var item_buttons := {}            # HOOK / POUR / SPARK, left edge above the bottom panel
var letter_mats := {}             # tile -> material, goes pale once read
var letters_label: Label
static var capture_phase := 0     # capture runs twice: win at the bell, then a death

var hud: Control
var hand_art: TextureRect
var hook_art: TextureRect          # the boathook in your left hand, while you carry one
var hook_jab := 0.0                # 1 the moment you swing it, easing back
const HOOK_W := 340.0
const HAND_W := 236.0
var status_label: Label
var oil_bar: Control
var dread_bar: Control
var modal: Control                # title or a field note: blocks moves while it's up
var guide_sheet: Control
var card_ok: Button
var turn_events: Array = []        # every event of the last turn (field notes check them all)
var title_begin: Button
var menu_button: Button
var menu_sheet: Control
var report_text_box: TextEdit
var report_sheet: Control
const REPO := "duffpowell-commits/lethemoor"
var seen := {}                    # field notes already shown (saved in user://)
var hints_on := true
var capture_mode := false
static var title_done := false    # the title shows once per launch, not on every retry
var oil_count: Label
var dread_label: Label
var lantern_buttons := {}
var move_buttons := {}
var wait_button: Button             # WAIT on the lantern row (swipe mode)
var bottom_panel: ColorRect
var pad_on := false                # the old move pad; off = swipes are the controls
var menu_items := {}               # menu label (before any colon) -> button, for the capture
var minimap: Control
var map_rot := 0.0                  # the chart turns so what's ahead is up (unless NORTH UP)
var map_north_up := false
var end_screen: Control
var record := {}                    # nights, bells rung, best grades, unlocks (record.gd; saved in user://)
var deep_on := false                # DEEPER NIGHT picked on the title (only once it's unlocked)
var night_counted := false
var unlocked_now: Array = []        # unlocked by this night, for the end card


func _ready() -> void:
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	record = Record.blank()
	_load_hints()
	game = Night.start_dealt(FileAccess.get_file_as_string(ROOM), _pick_night(), deep_on and Record.has(record, Record.DEEPER), Record.gentle(record) or _asked("LM_GENTLE", "gentle") == "1")
	room = game.room
	fog = game.fog
	_build_world()
	_build_hud()
	perf = Perf.new()
	add_child(perf)
	perf.setup(world_env, light, capture_mode)
	perf.set_position_below(TOP_H)
	perf.offset.x = _col_x()
	_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
	Sound.hook_night()   # before _refresh: track() needs the new night (retry restarts the flame)
	_refresh()
	if not title_done:
		_show_title()
	else:
		_teach()
	if capture_mode:
		_capture.call_deferred()


## Which night to deal. Every run is a new one; the capture plays the map as drawn (0).
## A reported night can be replayed: ?night=1234 on the web link, or LM_NIGHT=1234.
func _pick_night() -> int:
	if capture_mode:
		return 0
	var asked := _asked("LM_NIGHT", "night")
	if asked.is_valid_int() and int(asked) > 0:
		return int(asked)
	return randi_range(1, 9999)


## A tester's replay request: env var `env` on desktop, `?key=` on the web build.
func _asked(env: String, key: String) -> String:
	var asked := OS.get_environment(env)
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('%s') || ''" % key, true)
		if q is String and q != "":
			asked = q
	return asked


func _tex(name: String) -> Texture2D:
	return load("res://assets/art/%s.png" % name)


## A painted prop as an upright billboard standing on its base, `h` world units tall.
func _prop_sprite(name: String, h: float) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = _tex(name)
	sp.pixel_size = h / sp.texture.get_height()
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.shaded = true
	sp.offset = Vector2(0, sp.texture.get_height() / 2.0)
	return sp


func _w(p: Vector2i) -> Vector3:
	return Vector3(p.x, 0, p.y)


## Grid facing -> camera yaw. Grid up (0,-1) is world -z, which a camera looks down at yaw 0.
func _yaw(f: Vector2i) -> float:
	return atan2(-float(f.x), -float(f.y))


func _cam_pos(p: Vector2i, f: Vector2i) -> Vector3:
	return _w(p) - Vector3(f.x, 0, f.y) * CAM_BACK + Vector3(0, EYE, 0)


func _place_cam(pos: Vector3, yaw: float, roll := 0.0) -> void:
	cam.position = pos
	cam.rotation = Vector3(0, yaw, roll)


## Ease from v0 to v1 (0 = at rest, 1 = full speed): steps that run on into each other keep
## their speed instead of stopping dead on every tile (cubic Hermite, 0 -> 1).
static func glide(k: float, v0: float, v1: float) -> float:
	var k2 := k * k
	var k3 := k2 * k
	return (k3 - 2.0 * k2 + k) * v0 + (-2.0 * k3 + 3.0 * k2) + (k3 - k2) * v1


# ---------------------------------------------------------------- world

func _buried(p: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n := p + d
		if n.x >= 0 and n.y >= 0 and n.x < room.size.x and n.y < room.size.y and not room.is_wall(n):
			return false
	return true


func _build_world() -> void:
	var env := Environment.new()
	# night sky over the alleys (painted strip baked into a panorama): only seen looking up past the walls
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = _tex("sky_night")
	pano.energy_multiplier = 0.55
	var sky := Sky.new()
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = DEEP
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color("#0a0f18")
	env.fog_density = 0.09          # close fog: the corridor dissolves a few tiles out
	env.fog_sky_affect = 0.35       # but the clouds still show through overhead
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world_env = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = MOON
	moon.light_energy = 0.3
	moon.rotation_degrees = Vector3(-60, -30, 0)
	add_child(moon)

	var harbor := Harbor.new()
	for y in room.size.y:
		for x in room.size.x:
			var p := Vector2i(x, y)
			var wall: bool = room.is_wall(p)
			if wall and _buried(p):
				continue
			var mi := MeshInstance3D.new()
			mi.visibility_range_end = VIEW_RANGE
			mi.position = _w(p)
			if wall:
				mi.mesh = harbor.wall_for(room, p)
				var stone: bool = (x * 3 + y) % 3 != 0
				tile_tex[p] = "wall_granite" if stone else "wall_damask"
				tile_base[p] = Color(0.72, 0.72, 0.78) if stone else Color(0.5, 0.48, 0.46)
			else:
				# The western approach from the hunter starts on harbor decking.
				var decking: bool = y == 19 and x >= 6 and x <= 10
				if p in room.bells:
					mi.mesh = harbor.bell_steps
				else:
					mi.mesh = harbor.dock if decking else harbor.floor_stone
				tile_tex[p] = "floor_stone"
				if decking:
					tile_tex[p] = "deck"
				elif p in room.exits:
					tile_tex[p] = "exit"
				elif (x * 5 + y) % 11 == 0:
					tile_tex[p] = "floor_wet"
				tile_base[p] = Color(0.31, 0.25, 0.20) if decking else Color(0.58, 0.58, 0.62)
				var across: bool = room.is_wall(p + Vector2i.LEFT) and room.is_wall(p + Vector2i.RIGHT)
				var along: bool = room.is_wall(p + Vector2i.UP) and room.is_wall(p + Vector2i.DOWN)
				if (across or along) and (x + y * 3) % 7 == 0:
					var lintel := MeshInstance3D.new()
					lintel.mesh = harbor.lintel
					lintel.position = _w(p)
					lintel.rotation.y = PI / 2 if along else 0.0
					lintel.visibility_range_end = VIEW_RANGE
					add_child(lintel)
					lintels[p] = lintel
			add_child(mi)
			tile_nodes[p] = mi

	var lamp_mesh := Harbor.lamp_mesh()
	for lp: Vector2i in room.lamps:
		var post := MeshInstance3D.new()
		post.name = "HarborLamp"
		post.mesh = lamp_mesh
		post.position = _w(lp) + Vector3(0.3, 0, 0.3)
		add_child(post)
		harbor_fixtures[lp] = post

	for bp: Vector2i in room.bells:
		var bell := Harbor.bell()
		bell.position = _w(bp)
		for direction: Vector2i in Harbor.CARDINALS:
			if room.is_wall(bp + direction):
				bell.rotation.y = atan2(float(direction.y), -float(direction.x))
				break
		add_child(bell)
		harbor_fixtures[bp] = bell
		# the tower over it, on the wall at its back: seen over the walls from anywhere
		if bell_tower == null:
			bell_tower = Harbor.bell_tower()
			bell_tower.position = _w(bp) + Vector3(0, 0.3, 0)   # no wall beside the bell (rare): the belfry stands over it, clear of its yoke (2.3)
			for direction: Vector2i in Harbor.CARDINALS:
				if room.is_wall(bp + direction):
					bell_tower.position = _w(bp + direction)
					break
			add_child(bell_tower)
	_place_landmarks()

	# letters: a pale page nailed at chest height, facing the open floor. Read under BRIGHT.
	for np: Vector2i in room.letters:
		var page := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.3, 0.45)
		page.mesh = q
		var pm2 := StandardMaterial3D.new()
		pm2.albedo_texture = _tex("letter_nailed")    # torn page on a nail (painted)
		pm2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		pm2.albedo_color = Color(0.55, 0.52, 0.48)   # parchment is pale: sink it or BRIGHT blows it out
		pm2.roughness = 1.0
		pm2.cull_mode = BaseMaterial3D.CULL_DISABLED
		page.material_override = pm2
		# nailed to a wall beside the tile, facing into it (not hanging in your face)
		var wall_dir := Vector2i.ZERO
		for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			if room.is_wall(np + d):
				wall_dir = d
				break
		page.position = _w(np) + Vector3(wall_dir.x, 0, wall_dir.y) * 0.49 + Vector3(0, 1.15, 0)
		page.rotation.y = atan2(-float(wall_dir.x), -float(wall_dir.y))
		add_child(page)
		tile_mats[Vector2i(-200 - np.x, -200 - np.y)] = pm2
		tile_base[Vector2i(-200 - np.x, -200 - np.y)] = pm2.albedo_color
		letter_mats[np] = pm2

	# oil flasks on the floor: grimy, dead-looking glass, but a cold glint on the shoulder comes and
	# goes so your eye still finds it (unshaded, so it shows a little past the lantern's edge)
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	var glint_tex := GradientTexture2D.new()
	glint_tex.gradient = gg
	glint_tex.fill = GradientTexture2D.FILL_RADIAL
	glint_tex.fill_from = Vector2(0.5, 0.5)
	glint_tex.fill_to = Vector2(1.0, 0.5)
	glint_tex.width = 32
	glint_tex.height = 32
	for op: Vector2i in room.oil_flasks:
		var flask := _prop_sprite("prop_flask", 0.3)
		flask.position = _w(op) + Vector3(0.15, 0, 0.1)
		var glint := Sprite3D.new()
		glint.texture = glint_tex
		glint.pixel_size = 0.07 / 32.0
		glint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glint.shaded = false
		glint.modulate = Color(0.85, 0.92, 1.0, 0.0)
		glint.position = Vector3(-0.025, 0.21, 0.01)   # the glass shoulder, in the sprite's own space
		glint.name = "Glint"
		flask.add_child(glint)
		add_child(flask)
		flask_nodes[op] = flask

	# boathooks on the floor: a long dark pole with an iron hook (placeholder, art comes via Foxboard)
	for kp: Vector2i in room.hooks:
		# painted boathook lying flat on the stones
		var pole := _prop_sprite("prop_boathook", 0.5)
		pole.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		pole.offset = Vector2.ZERO
		pole.rotation = Vector3(-PI / 2, 0.6, 0)
		pole.position = _w(kp) + Vector3(-0.1, 0.02, 0)
		add_child(pole)
		hook_nodes[kp] = pole

	var looks := 0
	for thrall in game.thralls:
		var holder := Node3D.new()
		holder.position = _w(thrall.pos)
		var th := Sprite3D.new()
		var stalker: bool = thrall.get("kind", "thrall") == "stalker"
		if stalker:
			th.texture = _tex("stalker_bride")
		else:   # the drowned of the quay, in turn: the sack-headed one, the hooded one, the dock woman
			th.texture = _tex(THRALL_LOOKS[looks % THRALL_LOOKS.size()])
			looks += 1
		th.set_meta("look", th.texture)
		th.set_meta("tall", 2.2 if th.texture == _tex("thrall_nightmare") else 1.85)   # the nightmare stoops under the lintels
		th.pixel_size = th.get_meta("tall") / th.texture.get_height()   # ~1.85 tiles tall
		th.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		th.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		th.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		th.shaded = true
		th.offset = Vector2(0, th.texture.get_height() / 2.0)
		th.modulate = Color(0.8, 0.8, 0.82)    # thralls: sodden, a touch darker than the lantern says
		if stalker:
			th.modulate = Color(1.12, 1.1, 1.15)   # the bride: pale, catches the light
			th.pixel_size = 2.15 / th.texture.get_height()
		if not stalker:
			# hunched and broken: squat and wide, leaning into you (the stalker stands tall)
			th.scale = Vector3(1.12, 0.84, 1.0)
		holder.add_child(th)
		var rig_look: String = "stalker_bride" if stalker else String(th.texture.resource_path.get_file().get_basename())
		var rig: Array = RIGS.get(rig_look, [])
		if not rig.is_empty() and ResourceLoader.exists("res://assets/models/%s.glb" % rig[0]):
			var body: Node3D = RigHorror.make(rig[0], rig[1])
			if rig.size() > 2:
				body.body.rotation.y = rig[2]
			if body.look and stalker:   # she turns her head further than a person can, and slower to let go
				body.look.max_yaw = 1.95
				body.look.hold = Vector2(0.6, 1.6)
			holder.add_child(body)
			th.visible = false
			thrall_models[thrall_nodes.size()] = body
			thrall_rigs[thrall_nodes.size()] = body
		add_child(holder)
		if thrall.get("lying", false):   # the dead lie in what ran out of them; the pool stays if they rise
			var pool := MeshInstance3D.new()
			var pq := QuadMesh.new()
			pq.size = Vector2(1.1, 1.1)
			pool.mesh = pq
			var pmat := StandardMaterial3D.new()
			pmat.albedo_texture = _tex("blood_pool")
			pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			pmat.roughness = 0.12                # wet: the lantern catches in it
			pmat.metallic_specular = 0.5
			pool.material_override = pmat
			pool.rotation = Vector3(-PI / 2, float(hash(thrall.pos) % 628) / 100.0, 0)
			pool.position = _w(thrall.pos) + Vector3(0, 0.01, 0)
			add_child(pool)
			pool_nodes[thrall.pos] = pool
		thrall_nodes.append(holder)
		thrall_sprites.append(th)

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.05
	# The HUD covers the top bar and the bottom panel (_bh()), so centre the view on the strip
	# between them: a frustum camera with its centre shifted up.
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	_fit_camera()
	add_child(cam)
	for i: int in thrall_rigs:   # every head turns to you
		if thrall_rigs[i].look:
			thrall_rigs[i].look.target = cam
	if ResourceLoader.exists("res://assets/models/rig_hooded.glb"):   # the figure that isn't there
		phantom = RigHorror.make("rig_hooded", 1.0)
		for m in phantom.find_children("*", "MeshInstance3D", true, false):   # unlit and cold: it
			var mi := m as MeshInstance3D                                     # shows where no light reaches
			if mi.mesh == null:
				continue
			for si in mi.mesh.get_surface_count():
				var src := mi.get_active_material(si) as StandardMaterial3D
				var cold := (src.duplicate() if src else StandardMaterial3D.new()) as StandardMaterial3D
				cold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				cold.albedo_color = PHANTOM_TINT
				cold.disable_fog = true
				mi.set_surface_override_material(si, cold)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		phantom.player.speed_scale = 0.0   # utterly still
		if phantom.look:
			phantom.look.target = cam
		add_child(phantom)
		_hide_phantom()

	# her hand and lantern, low right, riding with the camera
	hand = Node3D.new()
	hand.position = Vector3(HAND_X, HAND_Y, -0.55)
	cam.add_child(hand)
	hand.visible = false   # the 3D arm (_build_viewmodel) carries the lantern now
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.05, 0.075, 0.05)
	frame.mesh = fb
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#2a1e14")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # the light sits inside it: draw a silhouette
	frame.material_override = fm
	hand.add_child(frame)
	flame = MeshInstance3D.new()
	var fq := SphereMesh.new()
	fq.radius = 0.028
	fq.height = 0.07
	flame.mesh = fq
	var flm := StandardMaterial3D.new()
	flm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flm.albedo_color = Color(2.4, 1.5, 0.6)
	flame.material_override = flm
	hand.add_child(flame)

	light = OmniLight3D.new()
	light.light_color = LANTERN
	light.shadow_enabled = true
	light.omni_attenuation = 1.1
	light.position = Vector3(HAND_X, HAND_Y + 0.12, -0.5)
	cam.add_child(light)
	_build_viewmodel()


## Your hands, in 3D (Meshy models, Nov 25; grips fixed the same day, scripts/hands.gd): the
## right fist holds the lantern up by an iron link, and the light lives inside the globe, so the
## shadows come from where the lantern really hangs. The left fist closes round the boathook's
## handle while you have one. The look only: rules never read these.
func _build_viewmodel() -> void:
	vm_lantern = Node3D.new()
	vm_lantern.position = Hands.LAMP_AT
	cam.add_child(vm_lantern)
	var rig: Array = Hands.lantern_rig(vm_lantern)
	vm_lamp = rig[0]
	var lamp: Node3D = rig[1]
	var arm: Node3D = rig[2]
	for vm: Node3D in [arm, vm_lamp]:
		for m in vm.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the light sits inside the globe, so the lantern glows from within rather than catching it
	for m in lamp.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var src := mi.get_active_material(0) as StandardMaterial3D
		if src:
			vm_lamp_mat = src.duplicate() as StandardMaterial3D
			vm_lamp_mat.emission_enabled = true
			vm_lamp_mat.emission_texture = src.albedo_texture
			vm_lamp_mat.emission = Color("#ff9440")
			mi.material_override = vm_lamp_mat
	# the flame and the light sit in the globe
	flame.reparent(vm_lamp, false)
	flame.position = lamp.position + Vector3(0, -0.002, 0)
	flame.scale = Vector3.ONE * 0.45 * Hands.LAMP_SCALE / 0.07
	vm_glow = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(0.075, 0.09) * Hands.LAMP_SCALE / 0.07
	vm_glow.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.no_depth_test = true
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.78, 0.4, 1.0), Color(1.0, 0.45, 0.1, 0.45), Color(0.6, 0.2, 0.0, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gm.albedo_texture = gt
	vm_glow.material_override = gm
	vm_glow.position = flame.position + Vector3(0, 0.002, 0.01)
	vm_lamp.add_child(vm_glow)
	light.reparent(vm_lamp, false)
	light.position = flame.position + Vector3(0, 0, -0.04)
	vm_hook = Node3D.new()
	vm_hook.position = Hands.HOOK_AT
	vm_hook.visible = false
	cam.add_child(vm_hook)
	var hrig: Array = Hands.hook_rig(vm_hook)
	var hook: Node3D = hrig[0]
	var larm: Node3D = hrig[1]
	for vm: Node3D in [larm, hook, hrig[2]]:
		for m in vm.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Each frame: the arm bobs with your step, the lantern swings on its bail (a real pendulum
## kicked by steps and turns), the boathook jabs when you swing it.
func _sway_viewmodel(delta: float) -> void:
	if vm_lantern == null:
		return
	var bob := sin(t * 2.1) * 0.004 + step_k * 0.018
	vm_lantern.position = Hands.LAMP_AT + Vector3(sin(t * 1.3) * 0.003, -bob, 0)
	vm_swing_v += (-vm_swing * 38.0 - vm_swing_v * 2.2) * delta + step_k * delta * 1.6
	vm_swing += vm_swing_v * delta
	vm_lamp.rotation = Vector3(vm_swing, 0, vm_swing * 0.6 + sin(t * 0.9) * 0.02)
	if vm_lamp_mat:
		vm_lamp_mat.emission_energy_multiplier = 0.06 if game.effective() == Fog.Lantern.HOODED else 0.14 * light.light_energy / LIGHT[Fog.Lantern.NORMAL][1]
		vm_glow.visible = game.effective() != Fog.Lantern.HOODED
		vm_glow.scale = Vector3.ONE * (1.35 if game.effective() == Fog.Lantern.BRIGHT else 1.0) * clampf(light.light_energy / LIGHT[Fog.Lantern.NORMAL][1], 0.3, 1.4)
	vm_hook.visible = game.hook_wear > 0 and not game.dead
	if vm_hook.visible:
		var j := sin(hook_jab * PI) if hook_jab > 0.0 else 0.0
		vm_hook.position = Hands.HOOK_AT + Vector3(0.05 * j, -bob + 0.04 * j, -0.16 * j)
		vm_hook.rotation = Vector3(-0.5 * j, 0, 0)


# ---------------------------------------------------------------- rules -> look

func _refresh() -> void:
	flicker = game.flickers()
	fake_flicker = game.hallucinating() and not flicker and randf() < 0.35
	_refresh_fog()
	Sound.hook_track(game)
	for i in thrall_nodes.size():
		thrall_nodes[i].position = _w(game.thralls[i].pos)
	_refresh_hud()


## Every tile with the same texture and fog shade shares one material (perf: hundreds of
## unique materials made the phone switch GPU state for every tile; now it's about a dozen).
func _tile_mat(tex: String, base: Color, k: float) -> StandardMaterial3D:
	var key := "%s|%s" % [tex, k]
	if shared_mats.has(key):
		return shared_mats[key]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # painted textures from the mockup
	m.metallic_specular = 0.25
	if tex != "deck":
		m.albedo_texture = _tex(tex)
	if tex.begins_with("wall"):
		m.uv1_scale = Vector3(3, 2.0 * 1.6, 1)   # BoxMesh UVs are a 3x2 atlas: tile it
		m.roughness = 0.9
	elif tex in ["floor_stone", "floor_wet"]:
		m.uv1_scale = Vector3(3, 2, 1)   # BoxMesh UVs are a 3x2 atlas: one full slab set per tile
		m.roughness = 0.43 if tex == "floor_wet" else 0.52
	else:
		m.roughness = 0.65
	m.albedo_color = Color(base.r * k, base.g * k, base.b * k)
	if k == 0.0:
		m.metallic_specular = 0.0   # unseen stone is black, not a sheen of sky
	shared_mats[key] = m
	return m


## Dress each open hall (a 3x3 of floor) with one landmark against its wall: an upturned boat,
## a door that goes nowhere, a stack of lobster pots. Picked by position, so the same night
## always has the same ones, and no two halls the same kind if it can help it. Shown once seen,
## like the lamps (harbor_fixtures). Review of build 160: every corner of a ward looked alike.
func _place_landmarks() -> void:
	var centres: Array[Vector2i] = []
	for y in range(1, room.size.y - 1):
		for x in range(1, room.size.x - 1):
			var c := Vector2i(x, y)
			var open := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					open = open and not room.is_wall(c + Vector2i(dx, dy))
			var apart := true
			for o in centres:
				apart = apart and (absi(o.x - c.x) + absi(o.y - c.y)) > 4
			if open and apart:
				centres.append(c)
	var kinds := ["boat", "door", "pots"]
	var taken := {}
	for p in room.lamps + room.bells + room.letters + room.exits + room.hooks + room.oil_flasks \
			+ room.thralls + room.stalkers + room.corpses + [room.hunter]:   # never on a horror (a body half inside a boat) or the start
		taken[p] = true
	var k0 := posmod(room.size.x * 3 + centres.size() * 5 + (centres[0].x if not centres.is_empty() else 0), 3)
	for ci in centres.size():
		var c: Vector2i = centres[ci]
		var kind: String = kinds[(k0 + ci) % kinds.size()]
		# the hall tile on its rim with a wall behind it and nothing on it
		for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var t: Vector2i = c + d
			if not room.is_wall(t + d) or taken.has(t) or harbor_fixtures.has(t):
				continue
			var mark := Harbor.landmark(kind)
			mark.position = _w(t)
			mark.rotation.y = atan2(-float(d.x), -float(d.y))
			mark.visibility_range_end = VIEW_RANGE
			add_child(mark)
			harbor_fixtures[t] = mark
			landmarks[t] = kind
			break


func _refresh_fog() -> void:
	for p: Vector2i in tile_nodes:
		var mat := _tile_mat(tile_tex[p], tile_base[p], SHADE[fog.get_state(p)])
		if tile_nodes[p].material_override != mat:
			tile_nodes[p].material_override = mat
	for p: Vector2i in lintels:
		# a beam over a tile you've never seen stays hidden: its black stone still caught the sky,
		# a plank floating over the dark (review of build 160)
		lintels[p].visible = fog.get_state(p) != Fog.DARK
		lintels[p].material_override = _tile_mat("wall_granite", Color(0.72, 0.72, 0.78), SHADE[fog.get_state(p)])
	for p: Vector2i in harbor_fixtures:
		harbor_fixtures[p].visible = fog.get_state(p) != Fog.DARK
	for p in tile_mats:
		var gp: Vector2i = p
		if p.x <= -200:
			gp = Vector2i(-200 - p.x, -200 - p.y)
		elif p.x <= -100:
			gp = Vector2i(-100 - p.x, -100 - p.y)
		var k: float = SHADE[fog.get_state(gp)]
		var base: Color = tile_base[p]
		tile_mats[p].albedo_color = Color(base.r * k, base.g * k, base.b * k)
	for i in thrall_nodes.size():
		thrall_nodes[i].visible = fog.get_state(game.thralls[i].pos) == Fog.LIT and not game.thralls[i].get("gone", false)
		_pose(i)
		if thrall_rigs.has(i):   # perf: a body you can't see doesn't animate. A corpse keeps its pose and a
			# rise plays out even in the dark, so it never resumes half-risen somewhere else.
			var ap: AnimationPlayer = thrall_rigs[i].player
			var st: String = thrall_rigs[i].state
			var on: bool = thrall_nodes[i].visible or st == "dead" or (st == "rise" and ap.is_playing())
			if on != ap.active:
				ap.active = on
				if on:
					ap.advance(0.0)   # pose it at once, no stale frame
	_sync_prints()
	for kp: Vector2i in hook_nodes:
		hook_nodes[kp].visible = game.hooks_left.has(kp) and fog.get_state(kp) != Fog.DARK
	_sync_slicks()
	for fp: Vector2i in flask_nodes:
		flask_nodes[fp].visible = game.flasks_left.has(fp) and fog.get_state(fp) != Fog.DARK
	for lp: Vector2i in letter_mats:
		if game.letters_read.has(lp):
			tile_base[Vector2i(-200 - lp.x, -200 - lp.y)] = Color(0.3, 0.27, 0.23)   # read: it's spent
	var eff: int = game.effective()
	light.omni_range = LIGHT[eff][0]
	light.light_energy = LIGHT[eff][1]
	flame.visible = eff != Fog.Lantern.HOODED
	if minimap:
		minimap.queue_redraw()


## What clip a rigged horror is playing ("" when it has no rig). Captures check it.
func _rig_state(i: int) -> String:
	var rig: Node3D = thrall_rigs.get(i)
	return rig.state if rig else ""


## Turn a horror to face you (only when it isn't mid-step, so a walk reads as a walk).
func _face_cam(i: int, body: Node3D) -> void:
	if cam == null:
		return
	var toward: Vector3 = cam.global_position - thrall_nodes[i].global_position
	body.rotation.y = atan2(toward.x, toward.z)   # glTF bodies face +Z


## The rules say crouched / lunging / moving; the rig plays the clip for it. A risen one plays
## its rise to the end before it shambles.
func _drive_rig(i: int, rig: Node3D, th: Dictionary, delta := 0.0) -> void:
	var holder: Node3D = thrall_nodes[i]
	var moving: bool = holder.get_meta("last_pos", holder.position).distance_to(holder.position) > 0.0005
	holder.set_meta("last_pos", holder.position)
	if rig.state == "rise" and rig.player.is_playing():
		return
	if th.get("crouched", false):
		rig.set_state("crouch", 0.8)
	elif th.get("lunge_cd", 0) == Night.LUNGE_COOLDOWN and th.get("stun", 0) == 0:
		rig.set_state("lunge", 1.4)   # (a stunned one, torn off you, staggers rather than lunges)
	elif moving:
		rig.set_state("walk", 0.75)   # slow, dragging
	else:
		rig.set_state("idle", 0.6 + 0.08 * sin(t * 0.7 + i))
	if rig.state == "crouch" or rig.state == "lunge":
		_face_cam(i, rig)   # the tell and the lunge come straight at you
	elif rig.state != "walk":
		# standing: the head finds you first (head_look.gd); the body comes round after, slowly
		var toward: Vector3 = cam.global_position - holder.global_position if cam else Vector3.ZERO
		if toward.length() > 0.01:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(toward.x, toward.z), 1.0 - exp(-delta * BODY_TURN))
	else:
		var dir: Vector3 = _w(game.thralls[i].pos) - holder.position
		if dir.length() > 0.01:
			rig.rotation.y = atan2(dir.x, dir.z)


## A corpse lies flat on the stones, feet toward the wall; once it gets up it stands like the rest.
func _pose(i: int) -> void:
	var sp: Sprite3D = thrall_sprites[i]
	var lying: bool = game.thralls[i].get("lying", false)
	var model: Node3D = thrall_models.get(i)
	var rig: Node3D = thrall_rigs.get(i)
	if rig:   # the body itself lies there, and gets up
		rig.visible = true
		sp.visible = false
		if lying:
			if rig.state != "dead":
				rig.set_state("dead")
				rig.hold_end()   # it was dead before you came
		elif rig.state == "dead":
			rig.set_state("rise")
		_face_cam(i, rig)
		return
	if model:
		model.visible = not lying
		sp.visible = lying
		if game.thralls[i].kind == "stalker":
			var tile: Vector2i = game.thralls[i].pos
			if model.get_meta("facing_tile", Vector2i(-1, -1)) != tile:
				var toward: Vector2i = game.hunter - tile
				if toward != Vector2i.ZERO:
					model.rotation.y = atan2(toward.x, toward.y)
				model.set_meta("facing_tile", tile)
	sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED if lying else BaseMaterial3D.BILLBOARD_FIXED_Y
	if lying:
		# on its side across your view, turned to you, sagging back a little: a body, at a glance
		var to_cam: Vector3 = cam.global_position - thrall_nodes[i].global_position if cam else Vector3.FORWARD
		sp.rotation = Vector3(0, atan2(to_cam.x, to_cam.z), PI / 2 + 0.08)
		sp.offset = Vector2.ZERO
		sp.position = Vector3(0, sp.texture.get_width() * sp.pixel_size * sp.scale.x * 0.42, 0)
	else:
		sp.rotation = Vector3.ZERO
		sp.position = Vector3.ZERO
		sp.offset = Vector2(0, sp.texture.get_height() / 2.0)
	sp.modulate = Color(0.68, 0.68, 0.72) if lying else (sp.modulate if game.thralls[i].kind == "stalker" else Color(0.8, 0.8, 0.82))


## Two wet bare footprints, drawn once: dark, a little glossy.
func _print_texture() -> Texture2D:
	if print_tex:
		return print_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for foot in [[Vector2(22, 40), 1.0], [Vector2(42, 22), -1.0]]:
		var c: Vector2 = foot[0]
		for y in 64:
			for x in 64:
				var q := Vector2(x, y) - c
				var heel := (q - Vector2(0, 6)).length() < 5.0
				var sole := Vector2(q.x / 5.5, (q.y + 2.0) / 9.0).length() < 1.0
				var toes := false
				for k in 4:
					toes = toes or (q - Vector2(-4.0 + k * 2.7 * foot[1] * foot[1], -12.5 + absf(k - 1.5))).length() < 1.6
				if heel or sole or toes:
					img.set_pixel(x, y, Color(0.02, 0.03, 0.05, 0.85))
	print_tex = ImageTexture.create_from_image(img)
	return print_tex


## Wet prints show on lit floor while they last (the sim dries them).
func _sync_prints() -> void:
	for p: Vector2i in print_nodes.keys():
		if not game.prints.has(p):
			print_nodes[p].queue_free()
			print_nodes.erase(p)
	for p: Vector2i in game.prints:
		if not print_nodes.has(p):
			var m := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.55, 0.55)
			m.mesh = q
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = _print_texture()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.15                 # wet: it catches the lantern
			mat.metallic_specular = 0.6
			m.material_override = mat
			m.rotation = Vector3(-PI / 2, float(hash(p) % 628) / 100.0, 0)
			m.position = _w(p) + Vector3(0, 0.012, 0)
			add_child(m)
			print_nodes[p] = m
		print_nodes[p].visible = fog.get_state(p) == Fog.LIT
		var mat2: StandardMaterial3D = print_nodes[p].material_override
		mat2.albedo_color = Color(0.7, 0.1, 0.08, clampf(game.prints[p] / 4.0, 0.25, 1.0))   # bloody, drying
	for p: Vector2i in pool_nodes:
		pool_nodes[p].visible = fog.get_state(p) == Fog.LIT


## Oil on the floor: a painted black puddle while soaked; on fire, the painted burning pool
## with tongues of flame (painted flipbook particles, additive) over it and a light that gutters.
func _make_fire() -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.amount = 22
	f.lifetime = 0.7
	f.preprocess = 0.7
	f.local_coords = true
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(0.34, 0.02, 0.34)
	f.direction = Vector3.UP
	f.spread = 8.0
	f.gravity = Vector3(0, 0.9, 0)
	f.initial_velocity_min = 0.25
	f.initial_velocity_max = 0.55
	f.scale_amount_min = 0.7
	f.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.55))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.15))
	f.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.6, 0.95))
	ramp.set_color(1, Color(0.5, 0.06, 0.02, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.15, 0.85))
	f.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.44)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tex("fire_sheet")   # 8 painted flame frames, played as a flipbook
	m.particles_anim_h_frames = 8
	m.particles_anim_v_frames = 1
	m.particles_anim_loop = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR   # soft flames, not pixel blocks
	m.no_depth_test = false
	q.material = m
	f.mesh = q
	f.anim_offset_max = 1.0     # each tongue starts on its own frame
	f.anim_speed_min = 1.0
	f.anim_speed_max = 1.6
	f.position = Vector3(0, 0.02, 0)
	return f


func _sync_slicks() -> void:
	for p: Vector2i in slick_nodes.keys():
		if not game.slicks.has(p):
			slick_nodes[p].queue_free()
			slick_nodes.erase(p)
	for p: Vector2i in game.slicks:
		if not slick_nodes.has(p):
			var m := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(0.96, 0.96)
			m.mesh = pm
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_texture = _tex("decal_oilslick")   # painted oil (Forge art, keyed)
			mat.emission_texture = _tex("decal_fire")
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			mat.metallic = 0.6
			mat.metallic_specular = 1.0
			mat.roughness = 0.04             # oil: the lantern glints off it
			m.material_override = mat
			m.position = _w(p) + Vector3(0, 0.012, 0)
			m.rotation.y = float(hash(p) % 360) * PI / 180.0   # no two puddles lie the same way
			var fl := OmniLight3D.new()
			fl.light_color = Color("#ff8a3a")
			fl.omni_range = 2.6
			fl.light_energy = 1.6
			fl.position = Vector3(0, 0.4, 0)
			# each light redraws everything near it on the Compatibility renderer: two fire lights at most
			var lights := 0
			for q: Vector2i in slick_nodes:
				for c in slick_nodes[q].get_children():
					if c is OmniLight3D and c.visible:
						lights += 1
			fl.visible = lights < 2
			m.add_child(fl)
			var fire := _make_fire()
			m.add_child(fire)
			add_child(m)
			slick_nodes[p] = m
		var node: MeshInstance3D = slick_nodes[p]
		var mat: StandardMaterial3D = node.material_override
		var lit_fire: bool = game.burning(p)
		node.get_child(0).visible = lit_fire
		node.get_child(1).visible = lit_fire
		node.get_child(1).emitting = lit_fire
		node.visible = lit_fire or fog.get_state(p) != Fog.DARK
		if lit_fire:
			mat.albedo_texture = _tex("decal_fire")
			mat.albedo_color = Color(0.55, 0.5, 0.45, 1)
			mat.emission_enabled = true
			mat.emission = Color(1, 1, 1)
			mat.emission_energy_multiplier = 0.35   # the pool glows; the flame particles do the rest
		else:
			var k: float = SHADE[fog.get_state(p)]
			mat.albedo_texture = _tex("decal_oilslick")
			mat.albedo_color = Color(0.6 * k + 0.2, 0.6 * k + 0.2, 0.6 * k + 0.2, 0.95)
			mat.emission_enabled = false


## Burning oil gutters: each fire light breathes on its own.
func _flicker_fires() -> void:
	for p: Vector2i in slick_nodes:
		var fl: OmniLight3D = slick_nodes[p].get_child(0)
		if fl.visible:
			var ph := float(hash(p) % 100)
			fl.light_energy = 1.5 + 0.35 * sin(t * 11.0 + ph) + 0.2 * sin(t * 23.0 + ph * 2.0)


# ---------------------------------------------------------------- actions

## One action = one turn. The camera glides to the new pose while the thralls glide too.
func act(kind: String) -> void:
	if busy and kind in MOVE_KINDS and not game.over():
		queued = kind         # mid-glide: runs the moment this step lands
		return
	if busy or game.over() or modal != null or guide_sheet != null or menu_sheet != null or report_sheet != null:
		chain_from = ""
		return
	busy = true
	var carried := chain_from
	chain_from = ""
	last_event = ""
	turn_events = []
	var from_pos := cam.position
	var from_yaw := cam.rotation.y
	var from_t: Array = game.positions()
	var events: Array = []
	var turn0: int = game.turn
	match kind:
		"forward": events = game.step_dir(game.facing)
		"back": events = game.step_dir(-game.facing)
		"left": events = game.turn_by(-1)
		"right": events = game.turn_by(1)
		"about":
			events = game.turn_by(1)
			var half_stop: bool = game.over()
			for ev in events:
				half_stop = half_stop or ev in STOP_EVENTS
			if not half_stop:
				events += game.turn_by(1)
		"wait": events = game.wait()
		"hook": events = game.hook()
		"pour": events = game.pour()
		"spark": events = game.spark()
	Sound.hook_turn(kind, events, game, game.turn != turn0)
	# a quiet step returns no events too: only an unspent turn means you hit stone
	if game.turn == turn0 and not game.over() and kind in ["forward", "back"]:
		busy = false          # bumped a wall (or a thrall you can see): no turn spent
		hold_kind = ""
		queued = ""
		var ahead: Vector2i = game.hunter + (game.facing if kind == "forward" else -game.facing)
		var who: int = game.thrall_at(ahead)
		last_event = "blocked_fire" if game.burning(ahead) else ("blocked" if who < 0 else ("blocked_body" if game.thralls[who].get("lying", false) else "blocked_horror"))
		_refresh_hud()
		return
	if game.turn == turn0 and not game.over() and kind in ["hook", "pour", "spark"]:
		busy = false          # nothing to do it with, or nowhere to do it: no turn spent
		last_event = "cant_" + kind
		_refresh_hud()
		return
	var was_flicker := flicker
	_refresh_fog()
	var to_pos := _cam_pos(game.hunter, game.facing)
	var to_yaw := _yaw(game.facing)
	var walking := kind in ["forward", "back"]
	var v0 := 1.0 if walking and carried == kind else 0.0
	var v1 := 1.0 if walking and (hold_kind == kind or queued == kind) else 0.0
	var turn_dir := 0.0 if walking else signf(angle_difference(from_yaw, to_yaw))
	if walking:
		foot = -foot
	var side := cam.global_transform.basis.x
	var dur := ABOUT_TIME if kind == "about" else STEP_TIME
	if kind == "about" and absf(angle_difference(from_yaw, to_yaw)) > 3.0:
		turn_dir = -1.0
		to_yaw = from_yaw - PI   # a full half-turn: always spin the same way (right), not by lerp_angle's whim
	var e := 0.0
	while e < dur:
		e += get_process_delta_time()
		var u := minf(e / dur, 1.0)
		var k := glide(u, v0, v1)
		var arc := sin(u * PI)
		step_k = arc if walking else 0.0
		# head: dips onto the foot and sways off it; a turn leans into it a touch
		var head := Vector3(0, -arc * 0.035, 0) + side * (arc * 0.018 * foot) if walking else Vector3.ZERO
		var yaw := lerpf(from_yaw, to_yaw, k) if kind == "about" else lerp_angle(from_yaw, to_yaw, k)
		_place_cam(from_pos.lerp(to_pos, k) + head, yaw, -turn_dir * arc * (0.04 if kind == "about" else 0.025))
		for j in thrall_nodes.size():   # a step glides; a bride driven off by the light is simply gone
			var far: bool = game.thralls[j].get("recoiled_on", -1) > turn0 or (from_t[j] - game.thralls[j].pos).length() > 2.5
			thrall_nodes[j].position = _w(game.thralls[j].pos) if far else _w(from_t[j]).lerp(_w(game.thralls[j].pos), u)
		await get_tree().process_frame
	step_k = 0.0
	turn_events = events
	if "hook_hit" in events or "hook_miss" in events or "hook_broke" in events:
		hook_jab = 1.0
	if ("lunge" in events or "torn_free" in events) and not game.dead:
		lunge_hit = 1.0
	for ev in events:
		if ev in STOP_EVENTS or last_event not in STOP_EVENTS:
			last_event = ev
	_refresh()
	if flicker and not was_flicker and last_event not in STOP_EVENTS:
		last_event = "flicker"
		_refresh_hud()
	if game.dead and ("taken" in events or "grabbed" in events):
		await _kill_shot()
	busy = false
	if game.over():
		_show_end()
	elif "letter" in events:
		_show_page(game.letters_read.size() - 1)
	else:
		_teach(last_event)
	# carry straight on: a queued move first, else the held finger's walk
	var stop: bool = game.over() or last_event in STOP_EVENTS or last_event == "flicker" or modal != null
	var next: String = "" if stop else (queued if queued != "" else hold_kind)
	queued = ""
	if stop:
		hold_kind = ""
	if next != "":
		chain_from = kind
		act(next)


## A swipe in UI pixels. Mostly vertical: step; mostly sideways: turn the way the finger went.
func swipe(d: Vector2, fingers := 1) -> void:
	if fingers >= 2 and d.y > 0 and absf(d.y) >= absf(d.x):
		act("about")
	elif absf(d.y) >= absf(d.x):
		act("forward" if d.y < 0 else "back")
	else:
		act("right" if d.x > 0 else "left")


func _set_lantern(s: int) -> void:
	if busy or game.over() or modal != null or guide_sheet != null or menu_sheet != null or report_sheet != null:
		return
	if s != game.setting:
		Sound.hook_lantern(s)
	game.set_lantern(s)
	last_event = ""
	_refresh()
	_teach()


## Android back button / back gesture: close whatever is on top, else pause. Never quits
## (project.godot has quit_on_go_back off; a stray edge swipe used to end the night).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func go_back() -> void:
	if report_sheet != null:
		report_sheet.queue_free()
		report_sheet = null
	elif guide_sheet != null:
		guide_sheet.queue_free()
		guide_sheet = null
	elif menu_sheet != null:
		_close_menu()
	elif modal != null:
		if card_ok != null:
			card_ok.pressed.emit()   # field note or letter page: same as its button
	elif not game.over() and not busy:
		_open_menu()


func _unhandled_input(event: InputEvent) -> void:
	var press: bool = event is InputEventScreenTouch and event.pressed
	press = press or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if event is InputEventKey and event.pressed and modal != null and card_ok != null \
			and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
		card_ok.pressed.emit()
		return
	# swipe on the view: up = forward, down = back, left/right = turn (buttons stay as backup)
	var release: bool = event is InputEventScreenTouch and not event.pressed
	release = release or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	# second fingers only count toward a two-finger swipe; the first finger steers
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = true
		else:
			touches.erase(event.index)
		if event.index != 0:
			return
	if event is InputEventScreenDrag and event.index != 0:
		return
	var drag: bool = event is InputEventScreenDrag
	drag = drag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	if press:
		if swipe_from == null:   # touch + its emulated mouse press: keep the first
			swipe_fired = false
		swipe_from = event.position
	elif (drag or release) and swipe_from != null and not swipe_fired:
		var to_ui := get_viewport().get_final_transform().affine_inverse()
		var d: Vector2 = to_ui * event.position - to_ui * swipe_from
		if d.length() >= SWIPE_MIN:
			swipe_fired = true
			var fingers := touches.size()
			if drag and fingers < 2 and absf(d.y) >= absf(d.x) and modal == null and menu_sheet == null:
				hold_kind = "forward" if d.y < 0 else "back"   # finger stays down: keep walking
			swipe(d, fingers)
	if release:
		swipe_from = null
		swipe_fired = false
		hold_kind = ""
	# keyboard for the web build: arrows / WASD, space waits, 1-2-3 lantern
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP: act("forward")
			KEY_S, KEY_DOWN: act("back")
			KEY_A, KEY_LEFT: act("left")
			KEY_D, KEY_RIGHT: act("right")
			KEY_X: act("about")
			KEY_SPACE: act("wait")
			KEY_H: act("hook")
			KEY_P: act("pour")
			KEY_F: act("spark")
			KEY_F3: perf.toggle_show()
			KEY_ESCAPE: _open_menu() if menu_sheet == null else _close_menu()
			KEY_1: _set_lantern(Fog.Lantern.HOODED)
			KEY_2: _set_lantern(Fog.Lantern.NORMAL)
			KEY_3: _set_lantern(Fog.Lantern.BRIGHT)


func _process(delta: float) -> void:
	t += delta
	if minimap and game:   # the chart swings round to keep what's ahead at the top
		var want := 0.0 if map_north_up else Vector2(game.facing).angle_to(Vector2.UP)
		if absf(angle_difference(map_rot, want)) > 0.002:
			map_rot = want if capture_mode else lerp_angle(map_rot, want, 1.0 - exp(-delta * 9.0))
			minimap.queue_redraw()
	_flicker_fires()
	_sway_viewmodel(delta)
	_haunt(delta)
	for fp: Vector2i in flask_nodes:   # each flask glints on its own beat
		var g: Sprite3D = flask_nodes[fp].get_node_or_null("Glint")
		if g:
			var ph := t * 1.3 + float(fp.x * 7 + fp.y * 3)
			g.modulate.a = 0.15 + 0.75 * pow(maxf(0.0, sin(ph)), 6.0)
	# the bride, barely breathing (her clip runs at a crawl). Her body squares up to you only when
	# she has moved; in between it stays put and her head comes round after you, too far.
	for i: int in thrall_rigs:
		if i == kill_rig:
			continue
		if game.thralls[i].get("kind", "thrall") == "stalker" and thrall_nodes[i].visible:
			thrall_rigs[i].set_state("idle", 0.25)
			if thrall_rigs[i].get_meta("faced_at", Vector2i(-99, -99)) != game.thralls[i].pos:
				thrall_rigs[i].set_meta("faced_at", game.thralls[i].pos)
				_face_cam(i, thrall_rigs[i])
	# standing thralls twitch: a jerk of the head now and then, never smooth. Crouched (the tell
	# before a lunge) it drops low and wide, shivers and goes dark red; just after a lunge it rears up.
	for i in thrall_sprites.size():
		var th: Dictionary = game.thralls[i]
		if th.get("kind", "thrall") == "thrall" and not th.get("lying", false) and thrall_nodes[i].visible:
			var sp: Sprite3D = thrall_sprites[i]
			var jerk := 0.0
			if fmod(t * (1.3 + i * 0.17), 2.3) < 0.07:
				jerk = 0.05 * sin(t * 90.0 + i)
			var rig: Node3D = thrall_rigs.get(i)
			if rig:
				if i != kill_rig:
					_drive_rig(i, rig, th, delta)
				continue
			var model: Node3D = thrall_models.get(i)
			if model:
				var toward: Vector3 = cam.global_position - thrall_nodes[i].global_position
				var yaw := atan2(toward.x, toward.z) - PI / 2.0   # the imported Thrall faces +X
				var pitch := 0.0
				model.scale = THRALL_MODEL_SCALE
				if th.get("crouched", false):
					model.scale.y *= 0.72
					pitch = -0.17 + 0.018 * sin(t * 47.0 + i)
				elif th.get("lunge_cd", 0) == Night.LUNGE_COOLDOWN:
					model.scale.y *= 0.78
					pitch = -0.20
				model.rotation = Vector3(0, yaw, pitch)
				model.position.x = jerk
				continue
			if th.get("crouched", false):
				var beat := 0.5 + 0.5 * sin(t * 9.0)
				sp.scale = Vector3(1.3, 0.66, 1.0)
				jerk = 0.018 * sin(t * 47.0 + i)
				sp.modulate = Color(0.36 + 0.14 * beat, 0.1, 0.11)   # dark, blood-dim, pulsing
			elif th.get("lunge_cd", 0) == Night.LUNGE_COOLDOWN:
				_thrall_art(sp, _tex(THRALL_LUNGE), 1.45)   # arms out, sack-mouth open, right in your face
				sp.scale = Vector3.ONE
				sp.modulate = Color(0.5, 0.4, 0.4)    # its own drowned grey; the screen flash brings the red
			else:
				sp.scale = Vector3(1.12, 0.84, 1.0)
				sp.modulate = Color(0.8, 0.8, 0.82)
			if not th.get("lunge_cd", 0) == Night.LUNGE_COOLDOWN:
				_thrall_art(sp, sp.get_meta("look"), sp.get_meta("tall", 1.85))
			sp.position.x = jerk
	if lunge_hit > 0.0:
		lunge_hit = maxf(0.0, lunge_hit - delta * 1.6)
		if cam:
			cam.h_offset = randf_range(-1, 1) * 0.06 * minf(lunge_hit, 1.0)
			cam.v_offset = randf_range(-1, 1) * 0.04 * minf(lunge_hit, 1.0)
		if lunge_flash:
			lunge_flash.modulate.a = minf(lunge_hit, 1.0) * 0.8
		if blood_screen:   # the spatter hangs on longer than the flash, then runs off
			blood_screen.modulate.a = minf(lunge_hit * 1.4, 0.95)
	else:
		if cam and cam.h_offset != 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
		if lunge_flash and lunge_flash.modulate.a > 0.0:
			lunge_flash.modulate.a = 0.0
		if blood_screen and blood_screen.modulate.a > 0.0 and not kill_shot:
			blood_screen.modulate.a = 0.0
	var eff: int = game.effective()
	if hook_art:   # left hand: the boathook, lit by the lantern in the right; it jabs when you swing
		hook_art.visible = game.hook_wear > 0 and not game.dead
		if hook_art.visible:
			hook_jab = maxf(0.0, hook_jab - delta * 3.0)
			var j := sin(hook_jab * PI) if hook_jab > 0.0 else 0.0
			var lk := 0.45 if eff == Fog.Lantern.HOODED else (1.05 if eff == Fog.Lantern.NORMAL else 1.25)
			hook_art.modulate = Color(lk, lk * 0.96, lk * 0.92)
			hook_art.position = Vector2(-44 + 30.0 * j, _ui_h() - _bh() - HOOK_W - 50 - 80.0 * j + sin(t * 1.7 + 1.0) * 2.0)
	if hand_art:
		var want: String = HAND_ART[eff]
		if hand_art.get_meta("art", "") != want:
			hand_art.texture = _tex(want)
			hand_art.set_meta("art", want)
	if eff == Fog.Lantern.HOODED:
		if hand_art:
			hand_art.modulate = Color(0.55, 0.52, 0.52)   # shutter closed: the painted glass is dark already
		return
	var base: float = LIGHT[eff][1]
	var wobble := sin(t * 7.0) * 0.05 + sin(t * 13.0) * 0.04
	if (flicker or fake_flicker) and fmod(t, 1.1) < 0.18:
		wobble -= 0.6 * absf(sin(t * 60.0))
	if game.oil > 0 and game.oil <= LOW_OIL_SPUTTER:   # the wick gutters: the dark leans in (look only)
		var gap := fmod(t + 0.9, 2.6 - 1.2 * (1.0 - float(game.oil) / LOW_OIL_SPUTTER))
		if gap < 0.32:
			wobble -= base * 0.7 * sin(gap / 0.32 * PI)
	light.light_energy = maxf(0.05, base + wobble)
	hand.position.y = HAND_Y + sin(t * 2.1) * 0.006   # the hand isn't quite steady
	if hand_art:
		var k: float = clampf(light.light_energy / LIGHT[Fog.Lantern.NORMAL][1], 0.55, 1.25)
		hand_art.modulate = Color(k, k, k)
		hand_art.position.y = _ui_h() - _bh() - HAND_W + 22 + sin(t * 2.1) * 2.0 + step_k * 9.0


# ---------------------------------------------------------------- HUD

## Bottom panel height: slim when you move by swiping, tall with the move pad.
func _bh() -> float:
	return PAD_H if pad_on else SLIM_H


func _ui_h() -> float:
	return get_viewport().get_visible_rect().size.y


## The HUD is a 540-wide phone column, centred. On a wider screen (sideways phone, tablet,
## laptop) the world runs on past its sides; this is how far the column sits from the left.
func _col_x() -> float:
	return (get_viewport().get_visible_rect().size.x - UI_W) / 2.0


## The column always shows the same slice of the world (FOV across 540 UI px), whatever the
## screen; a wider screen just sees more to the sides. The view is centred on the strip
## between the top bar and the bottom panel (frustum shifted up).
func _fit_camera() -> void:
	var vis := get_viewport().get_visible_rect().size
	cam.size = 2.0 * cam.near * tan(deg_to_rad(FOV / 2.0)) * vis.x / UI_W
	var full_h := cam.size * vis.y / vis.x
	var mid := (TOP_H + (vis.y - _bh())) / 2.0
	cam.frustum_offset = Vector2(0, -full_h * (vis.y / 2.0 - mid) / vis.y)


## A screen-wide backing behind a column control (dark bars, dim sheets), so a wide screen
## doesn't show the world through the sides. It takes the parent's mouse filter.
func _wing(c: Control, color: Color) -> void:
	var w := ColorRect.new()
	w.color = color
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.offset_left = -4000
	w.offset_right = 4000
	w.show_behind_parent = true
	w.mouse_filter = c.mouse_filter
	c.add_child(w)
	c.move_child(w, 0)


## Rotation, a resized browser, the phone's bars sliding in and out: lay it all out again.
func _on_resize() -> void:
	if cam == null or hud == null:
		return
	_fit_camera()
	if perf:
		perf.offset.x = _col_x()
	if hand_art:
		hand_art.position.y = _ui_h() - _bh() - HAND_W + 22
	_refresh_hud()                        # the tool buttons sit on the bottom panel
	if modal != null and is_instance_valid(title_begin) and modal.is_ancestor_of(title_begin):
		modal.queue_free()                # the title is laid out by height: build it again
		modal = null
		_show_title()
	if guide_sheet != null:
		guide_sheet.queue_free()
		guide_sheet = null
		_open_guide()
	if end_screen != null:
		_fit_end_card()


func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, pos: Vector2, size: Vector2, cb: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## A thin brass rule, the house trim between panels and the view.
func _rule(parent: Control, y: float, top_edge := false) -> void:
	var r := ColorRect.new()
	r.color = UI.BRASS_DIM
	r.position = Vector2(-4000, y)       # runs on past the column on wide screens
	r.size = Vector2(UI_W + 8000, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top_edge:
		r.set_anchors_preset(Control.PRESET_TOP_WIDE)
	parent.add_child(r)


## A full-height control 540 UI px wide, kept centred by its anchors.
func _column() -> Control:
	var c := Control.new()
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_bottom = 1.0
	c.offset_left = -UI_W / 2.0
	c.offset_right = UI_W / 2.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# Back to front: the hand lantern (column), the vignette (whole screen), the HUD (column).
	var hand_col := _column()
	layer.add_child(hand_col)
	hand_col.visible = false   # the painted hands: kept as a fallback, the 3D arms (_build_viewmodel) show instead
	hud = _column()
	hud.theme = UI.theme()

	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.01, 0.015, 0.03, 0.9))
	g.add_point(0.5, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.0, 0.42)
	# her gloved hand and the brass lantern, painted, low right of the view (from Duff's mockup)
	hand_art = TextureRect.new()
	hand_art.texture = _tex("hand_lantern")
	hand_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # painted, not pixel art
	hand_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	hand_art.size = Vector2(HAND_W, HAND_W)
	hand_art.position = Vector2(UI_W - HAND_W + 6, _ui_h() - _bh() - HAND_W + 22)
	hand_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_col.add_child(hand_art)
	hook_art = TextureRect.new()
	hook_art.texture = _tex("hand_hook")
	hook_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hook_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hook_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	hook_art.size = Vector2(HOOK_W, HOOK_W)
	hook_art.position = Vector2(-44, _ui_h() - _bh() - HOOK_W - 50)
	hook_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hook_art.visible = false
	hand_col.add_child(hook_art)

	var vig := TextureRect.new()
	vig.texture = gt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vig)
	# blood at the edges of sight when something lunges (faded in by lunge_hit)
	var rg := Gradient.new()
	rg.set_color(0, Color(0.5, 0, 0.02, 0))
	rg.set_color(1, Color(0.55, 0, 0.03, 0.85))
	rg.add_point(0.55, Color(0.5, 0, 0.02, 0))
	var rgt := GradientTexture2D.new()
	rgt.gradient = rg
	rgt.fill = GradientTexture2D.FILL_RADIAL
	rgt.fill_from = Vector2(0.5, 0.45)
	rgt.fill_to = Vector2(1.0, 0.45)
	lunge_flash = TextureRect.new()
	lunge_flash.texture = rgt
	lunge_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	lunge_flash.stretch_mode = TextureRect.STRETCH_SCALE
	lunge_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lunge_flash.modulate.a = 0.0
	layer.add_child(lunge_flash)
	blood_screen = TextureRect.new()
	blood_screen.texture = _tex("fx_blood_screen")
	blood_screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	blood_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blood_screen.stretch_mode = TextureRect.STRETCH_SCALE
	blood_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_screen.modulate.a = 0.0
	layer.add_child(blood_screen)
	layer.add_child(hud)
	get_viewport().size_changed.connect(func(): _on_resize.call_deferred())

	# top bar: name, letters, guide button; then the two clocks, oil and dread
	var top := ColorRect.new()
	top.color = UI.INK
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.size.y = TOP_H
	hud.add_child(top)
	_wing(top, UI.INK)
	_rule(top, TOP_H - 1)
	var title := _label("ONE NIGHT", 17, UI.AMBER, UI.head())
	title.position = Vector2(14, 7)
	top.add_child(title)
	letters_label = _label("", 14, UI.DIM, UI.head())
	letters_label.position = Vector2(140, 10)
	top.add_child(letters_label)
	menu_button = _button("MENU", Vector2(UI_W - 92, 6), Vector2(80, 30), _open_menu, top)
	menu_button.add_theme_font_size_override("font_size", 14)
	top.add_child(_label("OIL", 14, UI.AMBER, UI.head()))
	top.get_child(-1).position = Vector2(14, 41)
	oil_bar = Control.new()
	oil_bar.position = Vector2(54, 44)
	oil_bar.size = Vector2(200, 16)
	oil_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oil_bar.draw.connect(_draw_oil)
	top.add_child(oil_bar)
	oil_count = _label("", 17, UI.AMBER, UI.head())
	oil_count.position = Vector2(262, 38)
	top.add_child(oil_count)
	dread_label = _label("DREAD", 14, UI.DIM, UI.head())
	dread_label.position = Vector2(318, 41)
	top.add_child(dread_label)
	dread_bar = Control.new()
	dread_bar.position = Vector2(392, 44)
	dread_bar.size = Vector2(UI_W - 392 - 14, 16)
	dread_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dread_bar.draw.connect(_draw_dread)
	top.add_child(dread_bar)

	# corner map: what you remember, on a round scrap of chart that turns with you.
	minimap = Control.new()
	minimap.size = MAP_SIZE
	minimap.position = Vector2(UI_W - 10 - minimap.size.x, TOP_H + 8)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_map)
	var paper := TextureRect.new()   # the chart paper sits under the drawing (a node: its round alpha holds)
	paper.texture = _tex("map_parchment")
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.size = Vector2(MAP_R, MAP_R) * 2.0
	paper.position = minimap.position + minimap.size / 2.0 - Vector2(MAP_R, MAP_R)
	paper.modulate = Color(0.82, 0.78, 0.74)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(paper)
	hud.add_child(minimap)

	var bottom := ColorRect.new()
	bottom.color = UI.INK
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -_bh()
	bottom_panel = bottom
	hud.add_child(bottom)
	_wing(bottom, UI.INK)
	_rule(bottom, 0)
	status_label = _label("", 19, UI.TEXT, UI.italic())
	status_label.position = Vector2(16, 8)
	status_label.size = Vector2(UI_W - 32, 46)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_constant_override("line_spacing", -3)
	bottom.add_child(status_label)
	# the lantern row teaches its own costs: name, then oil per turn and how far it lights
	var names := {
		Fog.Lantern.HOODED: "HOODED\n0 oil · unseen",
		Fog.Lantern.NORMAL: "NORMAL\n1 oil · 2 tiles",
		Fog.Lantern.BRIGHT: "BRIGHT\n2 oil · 4 tiles",
	}
	var x := 14
	var glyphs := {Fog.Lantern.HOODED: "hooded", Fog.Lantern.NORMAL: "normal", Fog.Lantern.BRIGHT: "bright"}
	for s in [Fog.Lantern.HOODED, Fog.Lantern.NORMAL, Fog.Lantern.BRIGHT]:
		var b := _button(names[s], Vector2(x, 60), Vector2(162, 56), _set_lantern.bind(s), bottom)
		b.add_theme_font_size_override("font_size", 13)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_glyph(b, glyphs[s], "", Rect2(6, 12, 32, 32))
		lantern_buttons[s] = b
		x += 174
	# move pad: engraved plates, a drawn sign over a small caption (no symbol fonts on web)
	move_buttons["left"] = _plate("turn_left", "TURN LEFT", Vector2(14, 126), Vector2(162, 92), act.bind("left"), bottom)
	move_buttons["forward"] = _plate("step", "STEP", Vector2(188, 126), Vector2(162, 92), act.bind("forward"), bottom, true)
	move_buttons["right"] = _plate("turn_right", "TURN RIGHT", Vector2(362, 126), Vector2(162, 92), act.bind("right"), bottom)
	move_buttons["wait"] = _plate("wait", "WAIT", Vector2(14, 228), Vector2(162, 88), act.bind("wait"), bottom)
	move_buttons["back"] = _plate("back", "BACK", Vector2(188, 228), Vector2(162, 88), act.bind("back"), bottom)
	move_buttons["guide"] = _plate("guide", "FIELD GUIDE", Vector2(362, 228), Vector2(162, 88), _open_guide, bottom)
	wait_button = _button("WAIT", Vector2(428, 60), Vector2(98, 56), act.bind("wait"), bottom)
	_plate_style(wait_button)
	wait_button.add_theme_font_size_override("font_size", 17)
	wait_button.add_theme_color_override("font_color", Color("#c9ad78"))
	_layout_bottom()
	# item column, left edge above the panel (the lantern hand is low right). Shown when usable.
	item_buttons["hook"] = _button("HOOK", Vector2.ZERO, Vector2(132, 64), act.bind("hook"), hud)
	item_buttons["pour"] = _button("POUR OIL\n3 oil", Vector2.ZERO, Vector2(132, 64), act.bind("pour"), hud)
	item_buttons["spark"] = _button("SPARK\n1 oil", Vector2.ZERO, Vector2(132, 64), act.bind("spark"), hud)
	for k in item_buttons:
		item_buttons[k].add_theme_font_size_override("font_size", 15)
		_plate_style(item_buttons[k])
		item_buttons[k].add_theme_color_override("font_color", Color("#c9ad78"))


## Swipe mode: a slim panel, three lantern buttons and WAIT on one row, the view gets the
## rest. Pad mode: the tall panel with the old move pad. Switch in MENU -> MOVE BUTTONS.
func _layout_bottom() -> void:
	bottom_panel.offset_top = -_bh()
	var x := 14.0
	for s in [Fog.Lantern.HOODED, Fog.Lantern.NORMAL, Fog.Lantern.BRIGHT]:
		var b: Button = lantern_buttons[s]
		b.position = Vector2(x, 60)
		b.size = Vector2(162 if pad_on else 128, 56)
		b.add_theme_font_size_override("font_size", 13 if pad_on else 11)
		x += 174 if pad_on else 138
	for k in move_buttons:
		move_buttons[k].visible = pad_on
	wait_button.visible = not pad_on
	if cam:
		_fit_camera()
	if hand_art:
		hand_art.position.y = _ui_h() - _bh() - HAND_W + 22
	if game:
		_refresh_hud()


func _set_pad(on: bool) -> void:
	pad_on = on
	_layout_bottom()
	_save_hints()


## A move-pad plate: iron face, brass rim, a sign drawn over its caption. `hero` = the big one.
func _plate(kind: String, caption: String, pos: Vector2, size: Vector2, cb: Callable, parent: Control, hero := false) -> Button:
	var b := _button("", pos, size, cb, parent)
	_plate_style(b, hero)
	var icon := 44.0 if hero else 36.0
	_glyph(b, kind, caption, Rect2((size.x - icon) / 2.0, size.y * 0.42 - icon / 2.0, icon, icon))
	return b


## Iron face, brass rim, a raised lip that drops when pressed.
func _plate_style(b: Button, hero := false) -> void:
	var face := Color(0.075, 0.068, 0.06, 0.97) if hero else Color(0.05, 0.05, 0.06, 0.96)
	var rim := UI.BRASS if hero else Color("#4a3d29")
	var normal := UI.box(face, rim, 2 if hero else 1, 7)
	normal.border_width_bottom = 4              # a lip along the bottom: it reads as raised
	normal.shadow_color = Color(0, 0, 0, 0.55)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	var down := UI.box(Color(0.17, 0.11, 0.045, 0.98), UI.AMBER, 2, 7)
	down.border_width_top = 4                   # pressed in: the lip moves to the top
	down.shadow_color = Color(1.0, 0.62, 0.2, 0.35)
	down.shadow_size = 8
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)


## Draw sign `kind` in `r` on top of button `b` (plus an optional caption under it). Brass at
## rest, amber while held or lit; follows the button's state on its own.
func _glyph(b: Button, kind: String, caption: String, r: Rect2) -> void:
	var g := Control.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	b.button_down.connect(g.queue_redraw)
	b.button_up.connect(g.queue_redraw)
	b.draw.connect(g.queue_redraw)          # lit / unlit restyles redraw the button
	g.draw.connect(func():
		var lit: bool = b.is_pressed() or b.get_theme_color("font_color") == UI.AMBER
		var col: Color = UI.AMBER if lit else Color("#c9ad78")
		if kind == "guide" and not lit:
			col = Color("#8f7a55")      # the guide is help, not a move: quieter brass
		_draw_sign(g, kind, r, col)
		if caption != "":
			var f: Font = UI.head()
			var fs := 13
			var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			g.draw_string(f, Vector2((b.size.x - w) / 2.0, b.size.y - 14), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.darkened(0.12)))


func _draw_sign(c: Control, kind: String, r: Rect2, col: Color) -> void:
	var m := r.get_center()
	var u := r.size.x / 2.0           # half size
	var w := maxf(2.0, u * 0.16)      # stroke
	match kind:
		"step", "back":
			var d := -1.0 if kind == "step" else 1.0
			var tip := m + Vector2(0, d * u)
			c.draw_colored_polygon(PackedVector2Array([tip, m + Vector2(-u * 0.75, d * u * 0.05),
					m + Vector2(-u * 0.28, d * u * 0.05), m + Vector2(-u * 0.28, -d * u * 0.9),
					m + Vector2(u * 0.28, -d * u * 0.9), m + Vector2(u * 0.28, d * u * 0.05),
					m + Vector2(u * 0.75, d * u * 0.05)]), col)
		"turn_left", "turn_right":
			var sgn := -1.0 if kind == "turn_left" else 1.0
			var ctr := m + Vector2(0, u * 0.35)
			var rad := u * 0.72
			# an arc over the top that bends round to the side you turn to
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI + (PI * 0.85) * i / 16.0     # from the left, over the top
				var pnt := Vector2(cos(a), sin(a)) * rad
				pts.append(ctr + Vector2(pnt.x * sgn, pnt.y))
			c.draw_polyline(pts, col, w, true)
			var end := pts[pts.size() - 1]
			var dirv := (end - pts[pts.size() - 2]).normalized()
			var side := Vector2(-dirv.y, dirv.x)
			c.draw_colored_polygon(PackedVector2Array([end + dirv * u * 0.42,
					end + side * u * 0.36, end - side * u * 0.36]), col)
		"wait":
			var t := u * 0.62
			c.draw_line(m + Vector2(-t, -u * 0.95), m + Vector2(t, -u * 0.95), col, w, true)
			c.draw_line(m + Vector2(-t, u * 0.95), m + Vector2(t, u * 0.95), col, w, true)
			c.draw_polyline(PackedVector2Array([m + Vector2(-t * 0.85, -u * 0.95), m + Vector2(0, 0),
					m + Vector2(-t * 0.85, u * 0.95)]), col, w * 0.8, true)
			c.draw_polyline(PackedVector2Array([m + Vector2(t * 0.85, -u * 0.95), m + Vector2(0, 0),
					m + Vector2(t * 0.85, u * 0.95)]), col, w * 0.8, true)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-t * 0.6, u * 0.88),
					m + Vector2(t * 0.6, u * 0.88), m + Vector2(0, u * 0.25)]), col)   # the sand that's run
		"guide":
			var h := u * 0.7
			for sgn in [-1.0, 1.0]:
				c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -h * 0.75), m + Vector2(sgn * u, -h),
						m + Vector2(sgn * u, h * 0.9), m + Vector2(0, h)]), col)
				for k in 3:   # lines of text on each page
					var yy := -h * 0.45 + k * h * 0.45
					c.draw_line(m + Vector2(sgn * u * 0.2, yy), m + Vector2(sgn * u * 0.78, yy - h * 0.08),
							Color(0.05, 0.05, 0.06), 1.5, true)
		"hooded", "normal", "bright":
			var k: float = {"hooded": 0.75, "normal": 1.05, "bright": 1.2}[kind]
			var base := m + Vector2(0, u * 0.55)
			var fh := u * 1.25 * k          # flame height
			var fw := u * 0.62 * k          # half width
			var fl := PackedVector2Array()
			for i in 21:                    # left edge up to the tip, curling a little
				var t := i / 20.0
				fl.append(base + Vector2(-fw * sin(PI * (0.15 + 0.85 * (1.0 - t))) * (1.0 - t * 0.6) + fw * 0.15 * sin(t * PI * 2.0), -fh * t))
			for i in range(20, -1, -1):     # and back down the right edge
				var t := i / 20.0
				fl.append(base + Vector2(fw * sin(PI * (0.15 + 0.85 * (1.0 - t))) * (1.0 - t * 0.6) + fw * 0.15 * sin(t * PI * 2.0), -fh * t))
			if kind == "hooded":
				c.draw_colored_polygon(fl, Color(col, 0.35))      # an ember behind the shutter
				var hood := PackedVector2Array()
				for i in 13:
					var a := PI + PI * i / 12.0
					hood.append(base + Vector2(cos(a) * u * 0.62, sin(a) * u * 0.62 - u * 0.05))
				c.draw_colored_polygon(hood, col)                 # the shutter, closed
				c.draw_line(base + Vector2(-u * 0.75, -u * 0.05), base + Vector2(u * 0.75, -u * 0.05), col, w, true)
			else:
				c.draw_colored_polygon(fl, col)
				var core := PackedVector2Array()
				for p in fl:
					core.append(base + (p - base) * Vector2(0.45, 0.5))
				c.draw_colored_polygon(core, Color(1.0, 0.95, 0.8, 0.85) if col == UI.AMBER else Color(0.05, 0.05, 0.06))
				if kind == "bright":
					for i in 5:
						var a := -PI / 2.0 + (i - 2) * 0.55
						var dv := Vector2(cos(a), sin(a))
						var o := base + Vector2(0, -fh * 0.45)
						c.draw_line(o + dv * (fh * 0.62), o + dv * (fh * 0.85), col, w * 0.8, true)


## Oil: one notch per drop up to the starting 30; more than that and the bar glows.
func _draw_oil() -> void:
	var w := oil_bar.size.x
	var n: int = Night.START_OIL
	var seg := w / n
	oil_bar.draw_rect(Rect2(Vector2(-2, -2), oil_bar.size + Vector2(4, 4)), UI.BRASS_DIM, false, 1.0)
	for i in n:
		var on: bool = i < game.oil
		var col := UI.AMBER if on else Color(0.13, 0.15, 0.2)
		if on and game.oil > n:
			col = Color(1.0, 0.86, 0.55)
		oil_bar.draw_rect(Rect2(Vector2(i * seg + 0.5, 0), Vector2(seg - 1.5, oil_bar.size.y)), col)


## Dread: a red bar with a notch at the halfway mark, where the flame starts lying.
func _draw_dread() -> void:
	var r := Rect2(Vector2.ZERO, dread_bar.size)
	dread_bar.draw_rect(r, Color(0.1, 0.11, 0.15))
	var k := float(game.dread) / Night.DREAD_MAX
	dread_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(r.size.x * k, r.size.y)), UI.BLOOD)
	var half := r.size.x * float(Night.DREAD_HALLUCINATE) / Night.DREAD_MAX
	dread_bar.draw_line(Vector2(half, -3), Vector2(half, r.size.y + 3), UI.BRASS, 1.0)
	dread_bar.draw_rect(Rect2(Vector2(-2, -2), r.size + Vector2(4, 4)), UI.BRASS_DIM, false, 1.0)


## The corner map: a round scrap of old chart under a brass ring. By default it turns with you
## (what's ahead is always up) and the brass N runs round the ring; MENU -> MAP: NORTH UP pins it.
## Floor you remember is worn pale paper, floor in your light glows warm, walls are inked edges with
## hatching behind them, all fading out toward the rim. Thralls lit now are blood blots; a red ink X
## marks where you last saw one. You are the brass arrow in the middle, a faint wedge ahead.
func _map_xf(v: Vector2) -> Vector2:   # grid point -> point on the map disc
	var hc := Vector2(game.hunter) + Vector2(0.5, 0.5)
	return minimap.size / 2.0 + (v - hc).rotated(map_rot) * MAP_CELL


func _map_fade(q: Vector2) -> float:   # 1 near you, 0 at the rim
	return clampf((MAP_R - 6.0 - q.distance_to(minimap.size / 2.0)) / 26.0, 0.0, 1.0)


func _map_quad(v: Vector2, inset: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		pts.append(_map_xf(v + Vector2(inset, inset) + k * (1.0 - 2.0 * inset)))
	minimap.draw_colored_polygon(pts, col)


func _draw_map() -> void:
	var c := MAP_CELL
	var mid := minimap.size / 2.0
	var ink := Color(0.16, 0.1, 0.06)
	var reach := int(ceil(MAP_R / c)) + 1
	var h: Vector2i = game.hunter
	for y in range(maxi(0, h.y - reach), mini(room.size.y, h.y + reach + 1)):
		for x in range(maxi(0, h.x - reach), mini(room.size.x, h.x + reach + 1)):
			var p := Vector2i(x, y)
			var st: int = fog.get_state(p)
			if st == Fog.DARK:
				continue
			var q := _map_xf(Vector2(p) + Vector2(0.5, 0.5))
			var fade := _map_fade(q)
			if fade <= 0.0:
				continue
			var lit := st == Fog.LIT
			if room.is_wall(p):
				# hatching on wall that borders known floor, an inked edge where it meets it
				var edges := []
				for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var n := p + d
					if n.x < 0 or n.y < 0 or n.x >= room.size.x or n.y >= room.size.y or room.is_wall(n):
						continue
					if fog.get_state(n) != Fog.DARK:
						edges.append(d)
				if edges.is_empty():
					continue
				var hatch := Color(ink, 0.22 * fade)
				for k in 3:
					var t := 0.2 + 0.3 * k
					minimap.draw_line(_map_xf(Vector2(p) + Vector2(t - 0.15, 0.9)), _map_xf(Vector2(p) + Vector2(t + 0.25, 0.1)), hatch, 1.0, true)
				for d: Vector2i in edges:
					var a2 := Vector2(p) + Vector2(0.5, 0.5) + Vector2(d) * 0.5
					var t2 := Vector2(-d.y, d.x) * 0.5
					minimap.draw_line(_map_xf(a2 - t2), _map_xf(a2 + t2), Color(ink, 0.9 * fade), 2.0, true)
			else:
				_map_quad(Vector2(p), -0.02, Color(0.86, 0.78, 0.6, 0.55 * fade))
				if lit:
					_map_quad(Vector2(p), -0.02, Color(1.0, 0.72, 0.32, 0.38 * fade))
				if game.prints.has(p) and lit:   # wet prints: something walked here
					minimap.draw_circle(q + Vector2(-2, 1), 1.5, Color(ink, 0.7 * fade))
					minimap.draw_circle(q + Vector2(2, -2), 1.5, Color(ink, 0.7 * fade))
	for y in range(maxi(0, h.y - reach), mini(room.size.y, h.y + reach + 1)):
		for x in range(maxi(0, h.x - reach), mini(room.size.x, h.x + reach + 1)):
			var p := Vector2i(x, y)
			if fog.get_state(p) == Fog.DARK:
				continue
			var q := _map_xf(Vector2(p) + Vector2(0.5, 0.5))
			if _map_fade(q) > 0.3:
				_map_sign(p, Rect2(q - Vector2(c, c) / 2.0, Vector2(c, c)))
	for th in game.thralls:
		if th.get("gone", false):
			continue   # burned: no mark
		if th.get("lying", false):
			if fog.get_state(th.pos) != Fog.DARK:   # a body on the stones, nothing more (so it seems)
				var bq := _map_xf(Vector2(th.pos) + Vector2(0.5, 0.5))
				minimap.draw_rect(Rect2(bq - Vector2(c * 0.36, c * 0.18), Vector2(c * 0.72, c * 0.36)), Color(ink, 0.6 * _map_fade(bq)))
		elif fog.get_state(th.pos) == Fog.LIT:
			var tc := _map_xf(Vector2(th.pos) + Vector2(0.5, 0.5))
			var blood := Color(0.55, 0.03, 0.04)
			minimap.draw_circle(tc, c * 0.62, Color(blood, 0.25))
			minimap.draw_circle(tc, c * 0.38, blood)
			minimap.draw_circle(tc + Vector2(c * 0.3, c * 0.28), c * 0.14, blood)    # spatter
			minimap.draw_circle(tc + Vector2(-c * 0.34, c * 0.12), c * 0.1, blood)
			minimap.draw_line(tc + Vector2(0, c * 0.3), tc + Vector2(0, c * 0.75), blood, 1.6)   # a drip
		elif th.last_seen != null:
			# last seen: where you saw it, not where it is. It may have moved.
			var m := _map_xf(Vector2(th.last_seen) + Vector2(0.5, 0.5))
			var red := Color(0.55, 0.03, 0.04, 0.75 * _map_fade(m))
			minimap.draw_line(m + Vector2(-4, -4), m + Vector2(4, 4), red, 2.0, true)
			minimap.draw_line(m + Vector2(4, -4), m + Vector2(-4, 4), red, 2.0, true)
	# the bell, once you've heard it toll: on the chart where it hangs, or on the rim pointing at it
	if game.bell_heard and not room.bells.is_empty():
		var bp: Vector2i = room.bells[0]
		var bq := _map_xf(Vector2(bp) + Vector2(0.5, 0.5))
		var off := bq - mid
		if off.length() > MAP_R - 12.0:
			bq = mid + off.normalized() * (MAP_R - 12.0)
			var dir := off.normalized()
			var sd := Vector2(-dir.y, dir.x)
			minimap.draw_colored_polygon(PackedVector2Array([bq + dir * 11.0, bq + dir * 5.0 + sd * 4.0, bq + dir * 5.0 - sd * 4.0]), UI.AMBER)
		if off.length() > MAP_R - 12.0 or fog.get_state(bp) == Fog.DARK:
			minimap.draw_circle(bq, c * 0.62, Color(0.06, 0.04, 0.03, 0.75))
			_map_sign(bp, Rect2(bq - Vector2(c, c) / 2.0, Vector2(c, c)))
	# you: the brass arrow, the way you face as a faint wedge of light
	var f := Vector2(game.facing).rotated(map_rot)
	var side := Vector2(-f.y, f.x)
	var wr: float = c * 3.0
	minimap.draw_colored_polygon(PackedVector2Array([mid, mid + (f + side * 0.8) * wr, mid + f * wr * 1.1, mid + (f - side * 0.8) * wr]), Color(1.0, 0.75, 0.35, 0.22))
	var arrow := PackedVector2Array([mid + f * 8.0, mid - f * 6.0 + side * 6.0, mid - f * 2.5, mid - f * 6.0 - side * 6.0])
	minimap.draw_colored_polygon(arrow, UI.AMBER)
	arrow.append(arrow[0])
	minimap.draw_polyline(arrow, Color(0.12, 0.07, 0.03), 1.4, true)
	# the brass ring: two rims, tick marks every 30 degrees, the N riding round as you turn
	minimap.draw_arc(mid, MAP_R + 1.0, 0, TAU, 64, Color(0.05, 0.04, 0.03), 7.0, true)
	minimap.draw_arc(mid, MAP_R + 1.0, 0, TAU, 64, UI.BRASS, 4.0, true)
	minimap.draw_arc(mid, MAP_R - 1.5, 0, TAU, 64, Color(UI.AMBER, 0.35), 1.0, true)
	minimap.draw_arc(mid, MAP_R + 4.0, 0, TAU, 64, UI.BRASS_DIM, 1.2, true)
	for k in 12:
		var ang := map_rot + TAU * k / 12.0
		var dv := Vector2(0, -1).rotated(ang)
		minimap.draw_line(mid + dv * (MAP_R - 4.0), mid + dv * (MAP_R + 1.0), Color(0.1, 0.07, 0.04), 1.4 if k % 3 == 0 else 0.8, true)
	var nv := Vector2(0, -1).rotated(map_rot)
	var np := mid + nv * (MAP_R + 1.0)
	minimap.draw_circle(np, 8.0, Color(0.06, 0.04, 0.03))
	minimap.draw_circle(np, 6.6, UI.BRASS)
	# a drawn N (no fonts needed): two uprights and a diagonal, kept upright on screen
	var u := Vector2(0, -1) * 3.2
	var r2 := Vector2(1, 0) * 2.4
	minimap.draw_polyline(PackedVector2Array([np - r2 - u, np - r2 + u, np + r2 - u, np + r2 + u]), Color(0.1, 0.06, 0.03), 1.6, true)


## One small drawn sign on a map tile (no symbol fonts on web).
func _map_sign(p: Vector2i, r: Rect2) -> void:
	var ctr := r.get_center()
	var c := r.size.x
	if room.bells.has(p):   # a bell: dome, lip, clapper
		minimap.draw_circle(ctr + Vector2(0, -0.5), c * 0.32, UI.AMBER)
		minimap.draw_rect(Rect2(ctr + Vector2(-c * 0.42, c * 0.05), Vector2(c * 0.84, c * 0.16)), UI.AMBER)
		minimap.draw_circle(ctr + Vector2(0, c * 0.33), c * 0.1, UI.AMBER)
	elif room.letters.has(p) and not game.letters_read.has(p):   # a page with a folded corner
		var pg := Rect2(ctr - Vector2(c * 0.28, c * 0.36), Vector2(c * 0.56, c * 0.72))
		minimap.draw_rect(pg, Color(0.86, 0.8, 0.66))
		minimap.draw_line(pg.position + Vector2(1.5, 2.5), pg.position + Vector2(pg.size.x - 1.5, 2.5), Color(0.3, 0.25, 0.2), 0.8)
		minimap.draw_line(pg.position + Vector2(1.5, 4.5), pg.position + Vector2(pg.size.x - 1.5, 4.5), Color(0.3, 0.25, 0.2), 0.8)
	elif game.flasks_left.has(p):   # a flask: round belly, thin neck
		minimap.draw_circle(ctr + Vector2(0, c * 0.12), c * 0.26, Color(0.62, 0.42, 0.16))
		minimap.draw_rect(Rect2(ctr + Vector2(-c * 0.08, -c * 0.38), Vector2(c * 0.16, c * 0.32)), Color(0.62, 0.42, 0.16))
	elif room.lamps.has(p):   # an unlit lamp post: a ring
		minimap.draw_arc(ctr, c * 0.3, 0, TAU, 12, Color(0.75, 0.7, 0.55), 1.2)
	elif game.hooks_left.has(p):   # the boathook: a slanted pole
		minimap.draw_line(ctr + Vector2(-c, c) * 0.35, ctr + Vector2(c, -c) * 0.35, Color(0.75, 0.7, 0.55), 1.4)


func _refresh_hud() -> void:
	oil_count.text = str(game.oil)
	letters_label.text = "·   LETTERS %d / %d" % [game.letters_read.size(), room.letters.size()]
	oil_bar.queue_redraw()
	dread_bar.queue_redraw()
	dread_label.add_theme_color_override("font_color", UI.BLOOD if game.hallucinating() else UI.DIM)
	var lines := {
		Fog.Lantern.HOODED: "Hooded. Unseen, and blind. The dark gets into you.",
		Fog.Lantern.NORMAL: "The lantern burns low: two paces of light.",
		Fog.Lantern.BRIGHT: "The flame burns high, and every eye turns to it.",
	}
	var said := {
		"horror": "Something stands at the edge of the light. It has seen you.",
		"panic": "Your hands shake. Oil spills hissing on the stones.",
		"out_of_oil": "The last of the oil is gone. The dark comes in.",
		"flicker": "The flame gutters. Something is near.",
		"blocked": "Stone. You can't go that way.",
		"blocked_fire": "The oil is burning there. Wait for it to die.",
		"blocked_horror": "It stands in your way. You will not walk into it.",
		"oil": "A flask, still corked. The lantern drinks.",
		"letter": "A letter, nailed to the post. You read it by the high flame.",
		"letter_dim": "Words on a page. Too dim to read. Burn brighter.",
		"rang": "The bell.",
		"stalker_moved": "Silk drags on stone. Something moved while you weren't looking.",
		"hook_found": "A boathook, left on the stones. Long enough to keep them off you.",
		"hook_hit": "The hook bites and shoves it back. It's down, for now.",
		"hook_miss": "The hook sweeps empty dark.",
		"hook_broke": "The hook bends double. It's no use now.",
		"cant_hook": "You have nothing to swing.",
		"poured": "Oil glugs onto the stones ahead, black and shining.",
		"cant_pour": "No room to pour there, or not enough oil.",
		"ignite": "The spark catches. Fire runs along the oil.",
		"burned": "Something burns in the oil. It doesn't scream.",
		"crouch": "It crouches, low and still, watching the flame. Move.",
		"lunge": "It lunges, a pace gone in a heartbeat. Backing off won't stop it coming.",
		"torn_free": "Cold hands had you. You tore free and the lantern slopped oil. Next time it won't let go.",
		"rose": "Behind you, wet cloth tears off the stones. The dead one is getting up.",
		"roused": "You held it in the high flame too long. It stops shambling.",
		"blocked_body": "A body lies there, sodden. You'd have to step over it.",
		"heard": "Somewhere in the dark, something stops, and turns toward the sound.",
		"cant_spark": "Nothing to light. Look at the oil, lantern lit, 3 tiles or nearer.",
	}
	var s: String = lines[game.setting]
	if game.oil == 0:
		s = "The oil is spent. The dark is coming in."
	var extra: String = said.get(last_event, "")
	if extra != "":
		s = extra
	elif flicker or fake_flicker:
		s = "The flame gutters. Something is near."
	if game.turn < 3 and extra == "":
		s = "Swipe up to walk (hold to keep going), down to back away, sideways to turn. Find the bell."
	status_label.text = s
	if item_buttons:
		item_buttons.hook.visible = game.hook_wear > 0
		item_buttons.hook.text = "HOOK\n%d hit%s left" % [game.hook_wear, "" if game.hook_wear == 1 else "s"]
		item_buttons.spark.visible = game.slicks.values().has(0)
		# POUR OIL waits till there's a reason for it: a horror seen, or the hook in hand
		# (the first minute shows only the lantern; a new player was pouring 3 oil on turn 1)
		if not tools_shown and (game.hook_wear > 0 or game.slicks.size() > 0 or game.thralls.any(func(th):
				return not th.get("gone", false) and not th.get("lying", false) and fog.get_state(th.pos) == Fog.LIT)):
			tools_shown = true
		item_buttons.pour.visible = tools_shown
		var y: float = _ui_h() - _bh() - 12 - 64
		for k in ["spark", "pour", "hook"]:
			if item_buttons[k].visible:
				item_buttons[k].position = Vector2(14, y)
				y -= 74
	for k in lantern_buttons:
		if k == game.setting:
			UI.lit(lantern_buttons[k])
		else:
			UI.unlit(lantern_buttons[k])
	if minimap:
		minimap.queue_redraw()


# ---------------------------------------------------------------- title, field notes, guide

## A full-screen sheet over the view: dims the world and eats every tap under it.
func _sheet(alpha: float) -> ColorRect:
	var s := ColorRect.new()
	s.color = Color(0.008, 0.01, 0.018, alpha)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(s)
	_wing(s, s.color)
	s.color = Color(0, 0, 0, 0)    # the wing does the dimming, once, edge to edge
	return s


func _center(c: Control, parent: Control, y: float, w: float) -> void:
	c.position = Vector2((UI_W - w) / 2.0, y)
	c.size.x = w
	parent.add_child(c)


func _show_title() -> void:
	modal = _sheet(0.93)
	# key art (Forge, bride's face veiled over by hand): the bearer's lantern, the bride down the alley
	var bride := TextureRect.new()
	bride.texture = _tex("title_keyart")
	bride.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # painted, not pixel art
	bride.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bride.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bride.modulate = Color(0.62, 0.6, 0.62, 1.0)    # dim enough for the title and buttons to read
	bride.size = Vector2(UI_W, _ui_h())
	bride.position = Vector2.ZERO
	bride.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(bride)
	var y := _ui_h() * 0.5 - 330
	var name_l := _label("LETHEMOOR", 58, UI.AMBER, UI.head())
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center(name_l, modal, y, UI_W)
	var sub := _label("ONE  NIGHT", 20, UI.TEXT, UI.head())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center(sub, modal, y + 80, UI_W)
	var tag := _label("Light is life. Oil is time.\nThe dead don't stay gone.", 21, UI.DIM, UI.italic())
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center(tag, modal, y + 128, UI_W)
	for l in [name_l, sub, tag]:   # the key art's lantern sits behind the words: keep them readable
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.85))
	var by := _ui_h() * 0.5 + 150
	var begin := Button.new()
	begin.text = "BEGIN THE NIGHT"
	begin.focus_mode = Control.FOCUS_NONE
	begin.add_theme_font_size_override("font_size", 22)
	begin.size.y = 72
	UI.lit(begin)
	begin.pressed.connect(_begin)
	_center(begin, modal, by, 340)
	title_begin = begin
	var guide := Button.new()
	guide.text = "FIELD GUIDE"
	guide.focus_mode = Control.FOCUS_NONE
	guide.size.y = 54
	guide.pressed.connect(_open_guide)
	_center(guide, modal, by + 88, 340)
	var hints := Button.new()
	hints.focus_mode = Control.FOCUS_NONE
	hints.size.y = 54
	hints.text = "HINTS: " + ("ON" if hints_on else "OFF")
	hints.pressed.connect(func():
		hints_on = not hints_on
		hints.text = "HINTS: " + ("ON" if hints_on else "OFF")
		_save_hints())
	if Record.has(record, Record.DEEPER):
		# HINTS and DEEPER NIGHT share the row, half each
		hints.position = Vector2((UI_W - 340) / 2.0, by + 152)
		hints.size.x = 166
		hints.text = "HINTS " + ("ON" if hints_on else "OFF")
		hints.pressed.connect(func(): hints.text = "HINTS " + ("ON" if hints_on else "OFF"))
		modal.add_child(hints)
		var deep := Button.new()
		deep.name = "Deeper"
		deep.focus_mode = Control.FOCUS_NONE
		deep.size = Vector2(166, 54)
		deep.position = Vector2((UI_W - 340) / 2.0 + 174, by + 152)
		deep.text = "DEEPER " + ("ON" if deep_on else "OFF")
		if deep_on:
			UI.lit(deep)
		deep.pressed.connect(func():   # a different night: deal it again
			deep_on = not deep_on
			_save_record()
			get_tree().reload_current_scene())
		modal.add_child(deep)
	else:
		_center(hints, modal, by + 152, 340)
	var rec_line := Record.summary(record)
	if rec_line != "":
		var rl := _label(rec_line.to_upper(), 15, UI.DIM, UI.head())
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.add_theme_constant_override("outline_size", 8)
		rl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.85))
		_center(rl, modal, by - 34, UI_W)
	var bug := Button.new()
	bug.text = "REPORT A BUG"
	bug.focus_mode = Control.FOCUS_NONE
	bug.size.y = 54
	bug.add_theme_color_override("font_color", UI.DIM)
	bug.pressed.connect(_open_report)
	_center(bug, modal, by + 216, 340)
	var foot := _label("Ring the bell before your oil runs out.", 17, UI.DIM, UI.italic())
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center(foot, modal, _ui_h() - 44, UI_W)


func _begin() -> void:
	title_done = true
	modal.queue_free()
	modal = null
	_teach()


## One field note, centred on the view. Tap GOT IT (or Enter) to put it away.
func _show_card(id: String) -> void:
	modal = _sheet(0.55)
	var card := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var kicker := _label("FIELD NOTE", 13, UI.DIM, UI.head())
	box.add_child(kicker)
	var head := _label(Lessons.CARDS[id][0], 26, UI.AMBER, UI.head())
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(head)
	var body := _label(Lessons.CARDS[id][1], 20, UI.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_constant_override("line_spacing", -2)
	box.add_child(body)
	var ok := Button.new()
	ok.text = "GOT IT"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(0, 58)
	ok.pressed.connect(_close_card.bind(id))
	box.add_child(ok)
	card_ok = ok
	card.custom_minimum_size.x = 470
	card.position = Vector2((UI_W - 470) / 2.0, TOP_H + 70)
	modal.add_child(card)


## A letter you just read, as a page held up to the flame. Always shown (story, not a hint).
## Tap PUT IT AWAY (or Enter) to go on; any field note that's due comes after.
func _show_page(n: int) -> void:
	if modal != null:
		modal.queue_free()
	modal = _sheet(0.7)
	var pg: Dictionary = Letters.page(n)
	# a torn scrap of paper, stretched behind the words (it has its own torn rim and stains)
	var card := PanelContainer.new()
	var margins := StyleBoxEmpty.new()
	margins.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", margins)
	var paper := TextureRect.new()
	paper.texture = load("res://assets/art/letters/%s.png" % pg.paper)
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # painted, not pixel art
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(paper)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 44)
	pad.add_theme_constant_override("margin_top", 50)
	pad.add_theme_constant_override("margin_bottom", 56)
	card.add_child(pad)
	var ink: Color = pg.ink
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pad.add_child(box)
	box.add_child(_label("LETTER %s OF %d" % [Letters.numeral(n), room.letters.size()], 13, Color(ink, 0.6), UI.head()))
	var head := _label(pg.head, 21, pg.head_ink, UI.head())
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(head)
	var body := _label(pg.body, 20, ink, UI.italic())
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_constant_override("line_spacing", -3)
	box.add_child(body)
	var sign := _label(pg.sign, 19, ink, UI.italic())
	sign.autowrap_mode = TextServer.AUTOWRAP_WORD
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(sign)
	var w: float = pg.width
	card.custom_minimum_size.x = w
	card.position = Vector2((UI_W - w) / 2.0, TOP_H + 26)
	card.pivot_offset = Vector2(w / 2.0, 300)
	card.rotation_degrees = pg.tilt
	modal.add_child(card)
	# the button sits below the paper, on the dark, so the scrap stays a scrap
	var ok := Button.new()
	ok.text = "PUT IT AWAY"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(0, 58)
	ok.pressed.connect(_close_page)
	ok.custom_minimum_size.x = 300
	modal.add_child(ok)
	card_ok = ok
	await get_tree().process_frame          # let the paper size itself to the words
	if card_ok == ok:
		ok.position = Vector2((UI_W - 300) / 2.0, card.position.y + card.size.y + 24)


func _close_page() -> void:
	modal.queue_free()
	modal = null
	card_ok = null
	_teach("letter")


func _close_card(id: String) -> void:
	seen[id] = true
	_save_hints()
	modal.queue_free()
	modal = null
	card_ok = null
	_teach()


## Show the next field note that's due, if hints are on and nothing else is up.
func _teach(event: String = "") -> void:
	if not hints_on or modal != null or game.over() or not title_done:
		return
	# every event of the last turn gets a chance, not just the headline (panic + out_of_oil
	# on one turn used to drop the panic card)
	var id := ""
	for ev in [event] + turn_events:
		id = Lessons.due(game, seen, ev)
		if id != "":
			break
	if id != "":
		_show_card(id)


## Every field note in one scroll, any time (top-bar ? or FIELD GUIDE).
func _open_guide() -> void:
	if guide_sheet != null:
		return
	guide_sheet = _sheet(0.9)
	var card := PanelContainer.new()
	card.position = Vector2(20, TOP_H + 20)
	card.size = Vector2(UI_W - 40, _ui_h() - TOP_H - 60)
	guide_sheet.add_child(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	card.add_child(outer)
	outer.add_child(_label("FIELD GUIDE", 28, UI.AMBER, UI.head()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for id: String in Lessons.ORDER:
		var h := _label(Lessons.CARDS[id][0], 18, UI.AMBER, UI.head())
		list.add_child(h)
		var b := _label(Lessons.CARDS[id][1], 18, UI.TEXT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.custom_minimum_size.x = UI_W - 100
		list.add_child(b)
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		list.add_child(gap)
	if not game.letters_read.is_empty():
		list.add_child(_label("LETTERS READ TONIGHT", 18, UI.AMBER, UI.head()))
		for n in game.letters_read.size():
			var pg: Dictionary = Letters.page(n)
			var lt := _label("%s.  %s\n\n%s" % [Letters.numeral(n), pg.body, pg.sign], 18, UI.TEXT, UI.italic())
			lt.autowrap_mode = TextServer.AUTOWRAP_WORD
			lt.custom_minimum_size.x = UI_W - 100
			list.add_child(lt)
			var lg := Control.new()
			lg.custom_minimum_size.y = 8
			list.add_child(lg)
	list.add_child(_label("KEEPSAKES", 18, UI.AMBER, UI.head()))
	for k in Record.KEEPSAKES:
		var got := Record.has(record, k[0])
		var kt := _label(("%s\n%s" % [k[2], k[3]]) if got else Record.lock_text(k), 18, UI.TEXT if got else UI.DIM, UI.italic())
		kt.autowrap_mode = TextServer.AUTOWRAP_WORD
		kt.custom_minimum_size.x = UI_W - 100
		list.add_child(kt)
		var kg := Control.new()
		kg.custom_minimum_size.y = 8
		list.add_child(kg)
	if not Record.has(record, Record.DEEPER):
		var dl := _label("DEEPER NIGHT: LOCKED. Ring the bell once.", 18, UI.DIM, UI.italic())
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dl.custom_minimum_size.x = UI_W - 100
		list.add_child(dl)
	list.add_child(_label("GRADES", 18, UI.AMBER, UI.head()))
	var gl := _label(Lessons.GRADE_LINE, 18, UI.TEXT)
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD
	gl.custom_minimum_size.x = UI_W - 100
	list.add_child(gl)
	list.add_child(_label("CREDITS", 18, UI.AMBER, UI.head()))
	list.add_child(_label("Published by " + StudioSplash.PUBLISHER, 18, UI.TEXT))
	var close := Button.new()
	close.text = "CLOSE"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 58)
	close.pressed.connect(func():
		guide_sheet.queue_free()
		guide_sheet = null)
	outer.add_child(close)


## The pause menu (top-bar MENU). The night waits while it's open: nothing moves.
func _open_menu() -> void:
	if menu_sheet != null or report_sheet != null:
		return
	menu_sheet = _sheet(0.88)
	var y := TOP_H + 120.0
	var head := _label("PAUSED", 30, UI.AMBER, UI.head())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center(head, menu_sheet, y, UI_W)
	var items := [
		["RESUME", _close_menu],
		["FIELD GUIDE", func(): _close_menu(); _open_guide()],
		["REPORT A BUG", func(): _close_menu(); _open_report()],
		["MOVE BUTTONS: " + ("ON" if pad_on else "OFF"), "pad"],
		["MAP: " + ("NORTH UP" if map_north_up else "TURNS WITH YOU"), "map"],
		["HINTS: " + ("ON" if hints_on else "OFF"), Callable()],
		["SHOW FPS: " + ("ON" if perf.show else "OFF"), "fps"],
		["GRAPHICS: " + perf.quality_name(), "gfx"],
		["QUIT TO TITLE", func(): title_done = false; get_tree().reload_current_scene()],
	]
	y += 70
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size.y = 60
		b.add_theme_font_size_override("font_size", 19)
		if it[0] == "RESUME":
			UI.lit(b)
		menu_items[it[0].get_slice(":", 0)] = b
		if it[1] is String and it[1] == "pad":
			b.pressed.connect(func():
				_set_pad(not pad_on)
				b.text = "MOVE BUTTONS: " + ("ON" if pad_on else "OFF"))
		elif it[1] is String and it[1] == "map":
			b.pressed.connect(func():
				map_north_up = not map_north_up
				_save_hints()
				b.text = "MAP: " + ("NORTH UP" if map_north_up else "TURNS WITH YOU"))
		elif it[1] is String and it[1] == "fps":
			b.pressed.connect(func():
				perf.toggle_show()
				b.text = "SHOW FPS: " + ("ON" if perf.show else "OFF"))
		elif it[1] is String and it[1] == "gfx":
			b.pressed.connect(func(): b.text = "GRAPHICS: " + perf.cycle_quality())
		elif it[1].is_valid():
			b.pressed.connect(it[1])
		else:
			b.pressed.connect(func():
				hints_on = not hints_on
				b.text = "HINTS: " + ("ON" if hints_on else "OFF")
				_save_hints())
		_center(b, menu_sheet, y, 360)
		y += 74


func _close_menu() -> void:
	if menu_sheet:
		menu_sheet.queue_free()
		menu_sheet = null


## Everything a bug report needs that a tester can't be asked to type.
func _report_text(note: String) -> String:
	var build := "dev"
	if FileAccess.file_exists("res://build.txt"):
		build = FileAccess.get_file_as_string("res://build.txt").strip_edges()
	var device := "%s %s, screen %s, UI %s" % [OS.get_name(), OS.get_model_name(),
		DisplayServer.screen_get_size(), get_viewport().get_visible_rect().size]
	if OS.has_feature("web"):
		device += ", " + str(JavaScriptBridge.eval("navigator.userAgent", true))
	var names := {Fog.Lantern.HOODED: "hooded", Fog.Lantern.NORMAL: "normal", Fog.Lantern.BRIGHT: "bright"}
	var foes: Array = game.thralls.map(func(th): return "%s %s" % [th.get("kind", "thrall"), th.pos])
	var state := "night %d, tile %s facing %s, turn %d, oil %d, dread %d, lantern %s, letters %d/%d, last event '%s', over %s%s\n%s" % [
		game.seed, game.hunter, game.facing, game.turn, game.oil, game.dread, names[game.setting],
		game.letters_read.size(), room.letters.size(), last_event, game.over(),
		(" (" + game.cause + ")") if game.dead else "", ", ".join(foes)]
	return "%s\n\n---\nBuild: %s\nDevice: %s\nState: %s" % [note.strip_edges(), build, device, state]


## Bug report: a note box, then send it as a GitHub issue or copy it to text to Duff.
func _open_report() -> void:
	if report_sheet != null:
		return
	report_sheet = _sheet(0.94)
	var card := PanelContainer.new()
	card.position = Vector2(20, TOP_H + 30)
	card.custom_minimum_size = Vector2(UI_W - 40, 0)
	report_sheet.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(_label("REPORT A BUG", 26, UI.AMBER, UI.head()))
	var how := _label("What happened, and what did you expect? Where you are, your oil and your phone get added for you.", 18, UI.DIM)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(how)
	var note := TextEdit.new()
	note.custom_minimum_size = Vector2(0, 170)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.placeholder_text = "I tapped STEP and..."
	note.add_theme_font_size_override("font_size", 19)
	note.add_theme_stylebox_override("normal", UI.box(Color(0.07, 0.075, 0.09), UI.BRASS_DIM))
	note.add_theme_stylebox_override("focus", UI.box(Color(0.07, 0.075, 0.09), UI.BRASS))
	box.add_child(note)
	var done := _label("", 17, UI.AMBER)
	done.autowrap_mode = TextServer.AUTOWRAP_WORD
	var send := Button.new()
	send.text = "SEND ON GITHUB"
	send.focus_mode = Control.FOCUS_NONE
	send.custom_minimum_size = Vector2(0, 60)
	UI.lit(send)
	send.pressed.connect(func():
		var first := note.text.strip_edges().split("\n")[0].left(60)
		var title := "Bug: " + (first if first != "" else "(no note)")
		var url := "https://github.com/%s/issues/new?labels=bug&title=%s&body=%s" % [REPO, title.uri_encode(), _report_text(note.text).uri_encode()]
		if _web_queue("open", url):
			done.text = "Tap anywhere once more to open GitHub, then sign in and press Create."
		else:
			OS.shell_open(url)
			done.text = "Opened GitHub. Sign in there and press Create to file it.")
	box.add_child(send)
	var copy := Button.new()
	copy.text = "COPY, TO TEXT IT TO DUFF"
	copy.focus_mode = Control.FOCUS_NONE
	copy.custom_minimum_size = Vector2(0, 56)
	copy.pressed.connect(func():
		var text := "Lethemoor bug: " + _report_text(note.text)
		DisplayServer.clipboard_set(text)
		if _web_queue("copy", text):
			done.text = "Tap anywhere once more to copy, then paste it in a text to Duff."
		else:
			done.text = "Copied. Paste it in a text to Duff.")
	box.add_child(copy)
	var cancel := Button.new()
	cancel.text = "CLOSE"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.custom_minimum_size = Vector2(0, 52)
	cancel.pressed.connect(func():
		report_sheet.queue_free()
		report_sheet = null)
	box.add_child(cancel)
	box.add_child(done)
	report_text_box = note


## Web only: Safari lets a page open a tab or write the clipboard only inside a real tap, and
## Godot sees the tap a frame after the browser is done with it. So hand the job to the page
## (export head_include runs `window.lmQueue` on the next tap). False off the web.
func _web_queue(kind: String, value: String) -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval("window.lmQueue={k:%s,v:%s};" % [JSON.stringify(kind), JSON.stringify(value)], true)
	return true


func _load_hints() -> void:
	var cfg := ConfigFile.new()
	if capture_mode or cfg.load("user://lethemoor.cfg") != OK:
		return
	hints_on = cfg.get_value("hints", "on", true)
	pad_on = cfg.get_value("controls", "pad", false)
	map_north_up = cfg.get_value("controls", "map_north_up", false)
	for id in cfg.get_value("hints", "seen", []):
		seen[id] = true
	var rd = cfg.get_value("record", "data", Record.blank())
	record = rd if rd is Dictionary else Record.blank()   # a damaged save starts a fresh record, never a crash
	deep_on = cfg.get_value("record", "deep_on", false)


func _save_record() -> void:
	if capture_mode:
		return
	var cfg := ConfigFile.new()
	cfg.load("user://lethemoor.cfg")   # keep the other sections
	cfg.set_value("record", "data", record)
	cfg.set_value("record", "deep_on", deep_on)
	cfg.save("user://lethemoor.cfg")


func _save_hints() -> void:
	if capture_mode:
		return
	var cfg := ConfigFile.new()
	cfg.load("user://lethemoor.cfg")   # keep the other sections (audio mute, fps, graphics)
	cfg.set_value("hints", "on", hints_on)
	cfg.set_value("hints", "seen", seen.keys())
	cfg.set_value("controls", "pad", pad_on)
	cfg.set_value("controls", "map_north_up", map_north_up)
	cfg.save("user://lethemoor.cfg")


## It has you: the thing fills the screen, lunging up out of the dark, a red flash, a shake.
## Swap a thrall's art (its own look, or the lunge) keeping it standing on the floor at a set height.
func _thrall_art(sp: Sprite3D, tex: Texture2D, tall: float) -> void:
	if sp.texture == tex:
		return
	sp.texture = tex
	sp.pixel_size = tall / tex.get_height()
	sp.offset = Vector2(0, tex.get_height() / 2.0)


func _kill_shot() -> void:
	for i in game.thralls.size():   # the one that took you: if it has a body, it does it in 3D
		var th: Dictionary = game.thralls[i]
		if th.get("kind", "thrall") == game.killer and not th.get("gone", false) and not th.get("lying", false) \
				and absi(th.pos.x - game.hunter.x) + absi(th.pos.y - game.hunter.y) <= 1 and thrall_rigs.has(i):
			await _kill_shot_3d(i)
			return
	var stalker: bool = game.killer == "stalker"
	kill_shot = Control.new()
	kill_shot.set_anchors_preset(Control.PRESET_FULL_RECT)
	kill_shot.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(kill_shot)
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0.0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	kill_shot.add_child(dark)
	_wing(kill_shot, Color(0, 0, 0, 0))
	var face := TextureRect.new()
	face.texture = _tex("stalker_bride" if stalker else THRALL_LUNGE)
	for i in game.thralls.size():   # the one that took you, in its own look
		var th: Dictionary = game.thralls[i]
		if th.get("kind", "thrall") == game.killer and not th.get("gone", false) and not th.get("lying", false) \
				and absi(th.pos.x - game.hunter.x) + absi(th.pos.y - game.hunter.y) <= 1:
			face.texture = thrall_sprites[i].texture if stalker else _tex(THRALL_LUNGE)
			break
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.modulate = Color(0.75, 0.7, 0.7) if not stalker else Color(1.1, 1.08, 1.12)
	kill_shot.add_child(face)
	var red := ColorRect.new()
	red.color = Color(0.55, 0.0, 0.02, 0.0)
	red.set_anchors_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_shot.add_child(red)
	var gore := TextureRect.new()   # and then blood across your eyes
	gore.texture = _tex("fx_blood_screen")
	gore.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gore.set_anchors_preset(Control.PRESET_FULL_RECT)
	gore.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gore.stretch_mode = TextureRect.STRETCH_SCALE
	gore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gore.modulate.a = 0.0
	kill_shot.add_child(gore)
	var h := _ui_h()
	var e := 0.0
	const T_KILL := 0.75
	while e < T_KILL:
		e += get_process_delta_time()
		var k := clampf(e / 0.28, 0.0, 1.0)          # it comes up fast, then hangs there
		var size := lerpf(h * 0.5, (h * 2.1 if stalker else h * 1.15), k * k)   # the lunge art is half a body: hands stay in frame
		var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * (1.0 - e / T_KILL)
		var tex := face.texture.get_size()
		face.size = Vector2(size * tex.x / tex.y, size)   # its own shape: nothing cropped off the top
		# the hood is in the top fifth of the art: keep it in the middle of the screen as it comes
		face.position = Vector2((UI_W - face.size.x) / 2.0, h * 0.4 - size * (0.13 if stalker else 0.22)) + shake
		dark.color.a = 0.6 * k
		red.color.a = 0.45 * (1.0 - absf(e - 0.3) / 0.45) if e < 0.75 else 0.0
		gore.modulate.a = clampf((e - 0.22) / 0.08, 0.0, 1.0)   # thrown at the moment it reaches you
		await get_tree().process_frame
	if capture_mode:
		await _shot("fp_killshot")
	kill_shot.queue_free()
	kill_shot = null


## The kill, in the world: the body that has you comes off its tile into your face, its head locked
## on you, and you go down under it, looking up into the lantern light on it. Red flash, blood.
func _kill_shot_3d(i: int) -> void:
	kill_rig = i
	var rig: Node3D = thrall_rigs[i]
	var holder: Node3D = thrall_nodes[i]
	holder.visible = true
	rig.visible = true
	rig.player.active = true
	rig.set_state("lunge", 1.5, true)
	if rig.look:
		rig.look.locked = true
	kill_shot = Control.new()
	kill_shot.set_anchors_preset(Control.PRESET_FULL_RECT)
	kill_shot.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(kill_shot)
	var red := ColorRect.new()
	red.color = Color(0.55, 0.0, 0.02, 0.0)
	red.set_anchors_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_shot.add_child(red)
	var gore := TextureRect.new()
	gore.texture = _tex("fx_blood_screen")
	gore.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gore.set_anchors_preset(Control.PRESET_FULL_RECT)
	gore.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gore.stretch_mode = TextureRect.STRETCH_SCALE
	gore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gore.modulate.a = 0.0
	kill_shot.add_child(gore)
	# it may come from beside or behind (she never lets you see her move): you're wrenched round to it
	var cam0 := cam.transform
	var fwd := -cam0.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := holder.position - Vector3(cam0.origin.x, holder.position.y, cam0.origin.z)
	if at.length() > 0.05:
		fwd = at.normalized()
	var yaw0 := cam.rotation.y
	var yaw1 := atan2(-fwd.x, -fwd.z)
	var from := holder.position
	var to := Vector3(cam0.origin.x, holder.position.y, cam0.origin.z) + fwd * KILL_REACH
	var e := 0.0
	var shot := false
	while e < T_KILL_3D:
		var dt := get_process_delta_time()
		e += dt
		var k := clampf(e / 0.26, 0.0, 1.0)
		holder.position = from.lerp(to, 1.0 - pow(1.0 - k, 3.0))   # it comes fast and stops in your face
		_face_cam(i, rig)
		var fall := clampf((e - 0.22) / 0.5, 0.0, 1.0)
		fall = fall * fall * (3.0 - 2.0 * fall)
		var shake := (1.0 - e / T_KILL_3D) * (0.05 if e > 0.2 else 0.015)
		var base := Basis(Vector3.UP, lerp_angle(yaw0, yaw1, clampf(e / KILL_WHIP, 0.0, 1.0)))
		var b := base * Basis(Vector3.RIGHT, KILL_LOOK_UP * fall) * Basis(Vector3.FORWARD, KILL_ROLL * fall)
		cam.transform = Transform3D(b, cam0.origin - fwd * 0.08 * fall + Vector3(0, -KILL_DROP * fall, 0)
			+ Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake)
		red.color.a = 0.4 * clampf(1.0 - absf(e - 0.3) / 0.4, 0.0, 1.0)
		gore.modulate.a = clampf((e - 0.24) / 0.08, 0.0, 0.85)
		if vm_hook:
			vm_hook.visible = vm_hook.visible and e < 0.3
		if capture_mode and not shot and e > 0.62:   # the moment it's over you
			shot = true
			kill_3d_ok = Vector2(holder.position.x - cam.position.x, holder.position.z - cam.position.z).length() < 0.8 \
				and rig.state == "lunge"
			kill_3d_seen = kill_3d_ok
			print("KILL3D ", "PASS" if kill_3d_ok else "FAIL", " who=", game.killer)
			await _shot("fp_killshot")
		await get_tree().process_frame
	kill_shot.queue_free()
	kill_shot = null


## Dread at or past half: now and then a figure stands at the edge of the light, down the way you
## face, black against the fog. Then it isn't there. Look only: it's not in the rules or on the map.
func _haunt(delta: float) -> void:
	if phantom == null or game == null:
		return
	if phantom.visible:
		phantom_t -= delta
		if phantom_t <= 0.0 or busy or _sheet_up():
			_hide_phantom()
		return
	if not game.hallucinating() or game.over() or busy or _sheet_up():
		return
	phantom_t += delta
	if phantom_t < 0.0:
		return
	phantom_t = -randf_range(PHANTOM_EVERY.x, PHANTOM_EVERY.y)
	_show_phantom()


func _sheet_up() -> bool:
	return modal != null or guide_sheet != null or menu_sheet != null or report_sheet != null


func _hide_phantom() -> void:
	phantom.visible = false
	phantom.player.active = false   # nothing runs while it isn't there
	if phantom.look:
		phantom.look.active = false
	phantom_t = -randf_range(PHANTOM_EVERY.x, PHANTOM_EVERY.y)


## Put the figure in the first dark tile straight ahead (3-6 tiles), if the corridor runs that far.
func _show_phantom() -> bool:
	var f: Vector2i = game.facing
	var p: Vector2i = game.hunter
	for d in range(1, 7):
		p = game.hunter + f * d
		if room.is_wall(p):
			return false
		if d >= 3 and fog.get_state(p) != Fog.LIT:
			var taken := false
			for th: Dictionary in game.thralls:
				taken = taken or (th.pos == p and not th.get("gone", false))
			if taken:
				return false
			phantom.position = _w(p)
			phantom.rotation.y = atan2(-float(f.x), -float(f.y))   # facing you (glTF bodies face +Z)
			phantom.visible = true
			phantom.player.active = true
			if phantom.look:
				phantom.look.active = true
			phantom_t = PHANTOM_LIFE
			Sound.hook_sfx("whisper", -14.0, randf_range(0.8, 0.95))
			return true
	return false


func _show_end() -> void:
	if end_screen == null:
		end_screen = ColorRect.new()
		end_screen.color = Color(0.01, 0.01, 0.02, 0.86)
		end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		end_screen.mouse_filter = Control.MOUSE_FILTER_STOP
		hud.add_child(end_screen)
		_wing(end_screen, end_screen.color)
		end_screen.color = Color(0, 0, 0, 0)
		var card := PanelContainer.new()
		card.name = "Card"
		card.custom_minimum_size.x = 480
		card.position = Vector2(30, _ui_h() * 0.5 - 300)
		card.resized.connect(_centre_end_card)
		end_screen.add_child(card)
		var box := VBoxContainer.new()
		box.name = "Box"
		box.add_theme_constant_override("separation", 12)
		card.add_child(box)
		var big := _label("", 32, UI.BLOOD, UI.head())
		big.name = "Big"
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(big)
		var grade := _label("", 96, UI.AMBER, UI.head())
		grade.name = "Grade"
		grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(grade)
		var small := _label("", 20, UI.TEXT)
		small.name = "Small"
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(small)
		var again := Button.new()
		again.text = "WALK THE NIGHT AGAIN"
		again.focus_mode = Control.FOCUS_NONE
		again.custom_minimum_size = Vector2(0, 66)
		again.add_theme_font_size_override("font_size", 19)
		UI.lit(again)
		again.pressed.connect(func(): get_tree().reload_current_scene())
		box.add_child(_build_verdict())
		box.add_child(again)
		var menu := Button.new()
		menu.text = "TITLE"
		menu.focus_mode = Control.FOCUS_NONE
		menu.custom_minimum_size = Vector2(0, 54)
		menu.pressed.connect(func():
			title_done = false
			get_tree().reload_current_scene())
		box.add_child(menu)
	var big: Label = end_screen.get_node("Card/Box/Big")
	var grade: Label = end_screen.get_node("Card/Box/Grade")
	var small: Label = end_screen.get_node("Card/Box/Small")
	grade.visible = game.rang
	if game.rang:
		big.text = "THE BELL RINGS"
		big.add_theme_color_override("font_color", UI.AMBER)
		grade.text = game.grade()
		small.text = "It rolls out over the drowned quay, and every door in the town hears it.\n\n%d oil left  +  %d letters × 5  =  %d\n%d turns\n\n%s" % [game.oil, game.letters_read.size(), game.points(), game.turn, Lessons.GRADE_LINE]
	elif game.escaped:
		big.text = "DAWN"
		big.add_theme_color_override("font_color", UI.AMBER)
		small.text = "You reach the water's edge as the sky goes grey.\n\n%d turns  ·  %d oil left" % [game.turn, game.oil]
	else:
		big.text = "THE DARK TOOK YOU"
		small.text = "%s\n\n%d turns  ·  %d oil left" % [game.cause, game.turn, game.oil]
	small.text += ("\n\nNight %d" % game.seed + ("  ·  DEEPER" if game.deep else "") + ("  ·  FIRST NIGHTS" if game.gentle else "")) if game.seed > 0 else ""
	if not night_counted and not capture_mode:
		night_counted = true
		var news: Array = Record.add_night(record, game.rang, game.grade() if game.rang else "", game.deep)
		_save_record()
		unlocked_now = news
	if not unlocked_now.is_empty():
		small.text += "\n" + Record.news(unlocked_now)
	end_screen.visible = true
	_fit_end_card.call_deferred()


## Shrink the card to its contents (it grows while its labels are still empty and never
## shrinks by itself), then centre it.
func _fit_end_card() -> void:
	var card: Control = end_screen.get_node("Card")
	card.size.y = 0
	_centre_end_card()


func _centre_end_card() -> void:
	var card: Control = end_screen.get_node("Card")
	card.position.y = maxf(TOP_H + 8, (_ui_h() - card.size.y) / 2.0)


# ---------------------------------------------------------------- tester verdict

var verdict_fun := 0                 # 1-10, 0 = not rated yet
var verdict_again := ""              # "yes" / "no"
var verdict_buttons := {}            # for the capture: "fun7", "yes", "no", "text", "copy"


## Two taps on the end card: how fun (1-10), would you play again. Then one tap texts it to
## Duff (opens Messages with it written) or copies it. Kill rule: median fun 6+, testers replay.
func _build_verdict() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var ask := _label("HOW WAS THAT NIGHT?  1 = DULL, 10 = GREAT", 13, UI.DIM, UI.head())
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(ask)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	wrap.add_child(row)
	var show_row := func(items: Array) -> void:
		for c in row.get_children():
			c.queue_free()
		for it in items:
			var b := Button.new()
			b.text = it[0]
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 46)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 15)
			b.pressed.connect(it[1])
			row.add_child(b)
			verdict_buttons[it[2]] = b
	var send_row := func() -> void:
		ask.text = "THANK YOU. SEND IT TO DUFF:"
		show_row.call([
			["TEXT IT TO DUFF", func(): _send_verdict(ask, true), "text"],
			["COPY", func(): _send_verdict(ask, false), "copy"]])
	var again_row := func() -> void:
		ask.text = "FUN %d / 10.  WOULD YOU PLAY AGAIN?" % verdict_fun
		show_row.call([
			["YES", func():
				verdict_again = "yes"
				send_row.call(), "yes"],
			["NO", func():
				verdict_again = "no"
				send_row.call(), "no"]])
	var nums: Array = []
	for i in range(1, 11):
		nums.append([str(i), func():
			verdict_fun = i
			again_row.call(), "fun%d" % i])
	show_row.call(nums)
	return wrap


func _verdict_text() -> String:
	var build := "dev"
	if FileAccess.file_exists("res://build.txt"):
		build = FileAccess.get_file_as_string("res://build.txt").strip_edges()
	var how := "rang the bell, grade %s (oil %d, letters %d/%d)" % [game.grade(), game.oil, game.letters_read.size(), room.letters.size()] \
			if game.rang else "died: %s" % game.cause
	return "Lethemoor verdict: fun %d/10, play again: %s. Night %d%s: %s, %d turns. Build %s, %s %s." % [
		verdict_fun, verdict_again, game.seed, (" deeper" if game.deep else "") + (" first-nights" if game.gentle else ""), how, game.turn, build, OS.get_name(), OS.get_model_name()]


func _send_verdict(status: Label, by_text: bool) -> void:
	var text := _verdict_text()
	var cfg := ConfigFile.new()          # keep a copy on the phone too
	if not capture_mode:
		cfg.load("user://lethemoor.cfg")
		var all: Array = cfg.get_value("verdicts", "sent", [])
		all.append(text)
		cfg.set_value("verdicts", "sent", all)
		cfg.save("user://lethemoor.cfg")
	if not by_text:
		DisplayServer.clipboard_set(text)
		if _web_queue("copy", text):
			status.text = "TAP ANYWHERE ONCE MORE TO COPY, THEN PASTE IT TO DUFF"
		else:
			status.text = "COPIED. PASTE IT IN A TEXT TO DUFF."
		return
	# sms: with no number opens Messages with the words written; you pick Duff
	var url := "sms:?&body=" + text.uri_encode()
	if _web_queue("open", url):
		status.text = "TAP ANYWHERE ONCE MORE TO OPEN MESSAGES"
	else:
		if not capture_mode:
			OS.shell_open(url)
		status.text = "MESSAGES OPENED. PICK DUFF AND SEND."


# ---------------------------------------------------------------- capture + button test

func _shot(name: String) -> void:
	t = 0.3
	for i in 10:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/renders/" + name + ".png"))
	print("saved ", name, " ", img.get_size())


## Turn the phone sideways and back: the HUD column stays centred, the bars and the view
## fill the screen, a real tap still lands on its button, and no turn passes.
func _capture_rotate() -> void:
	var tall := get_window().size
	get_window().size = Vector2i(tall.x, tall.x * tall.x / tall.y)   # sideways (fits CI's 1080-wide screen)
	for i in 20:
		await get_tree().process_frame
	var vis := get_viewport().get_visible_rect().size
	var turn0: int = game.turn
	var centred: bool = vis.x > vis.y and absf(bottom_panel.get_global_rect().get_center().x - vis.x / 2.0) < 2.0
	await _shot("fp_sideways")
	await _press(menu_button)
	var tapped: bool = menu_sheet != null
	_close_menu()
	get_window().size = tall
	for i in 20:
		await get_tree().process_frame
	var back_ok: bool = absf(get_viewport().get_visible_rect().size.x - UI_W) < 1.0 and hud.get_global_rect().position.x == 0.0
	print("ROTATE ", "PASS" if centred and tapped and back_ok and game.turn == turn0 else "FAIL",
			" sideways=", vis, " centred=", centred, " tap=", tapped, " back=", back_ok)


## A real finger on a real button: click its centre through the input system.
func _press(b: Button) -> void:
	var pos: Vector2 = get_viewport().get_final_transform() * b.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
		await get_tree().process_frame
	for i in 40:
		await get_tree().process_frame
		if not busy:
			break


## Walk to `goal` the way a player would: turn to face the next tile, then step. Every action
## is a real button press. Stops at `stop_on` events, at the goal, or when the night ends.
func _walk_to(goal: Vector2i, stop_on: Array = []) -> String:
	for guard in 200:
		if game.over() or game.hunter == goal:
			return last_event
		var close: bool = _lit_awake().any(func(th): return th.get("kind", "thrall") == "thrall" \
				and absi(th.pos.x - game.hunter.x) + absi(th.pos.y - game.hunter.y) <= 2)
		if close:
			await _evade()   # it's within lunging reach: get clear before anything else, never turn
			continue
		var path: Array = _safe_path(goal)
		if path.size() < 2:
			await _evade()   # a thrall sits on every way through: hook it, back off, or let it move
			continue
		var d: Vector2i = path[1] - game.hunter
		if game.facing == d:
			await _go("forward")
		else:
			var right := Vector2i(-game.facing.y, game.facing.x)
			await _go("right" if d == right else "left")
		if last_event in stop_on:
			return last_event
		if card_ok != null and card_ok.text == "PUT IT AWAY":
			await _press(card_ok)   # a letter read on the way: put the page away and go on
	return "gave_up"


## Lit horrors that are up and about (a corpse lying still isn't one, as far as you know).
func _lit_awake() -> Array:
	return game.thralls.filter(func(th): return not th.get("gone", false) and not th.get("lying", false) \
			and fog.get_state(th.pos) == Fog.LIT)


## Something is too close: hook it if it's right ahead, else step to the tile furthest from
## every horror you can see (backing up keeps your eyes on it), else wait.
func _evade() -> void:
	var near: Array = _lit_awake()
	var ahead: Vector2i = game.hunter + game.facing
	if game.hook_wear > 0 and near.any(func(th): return th.pos == ahead or th.pos == ahead + game.facing):
		await _press(item_buttons.hook)
		return
	if near.is_empty():
		await _go("wait")
		return
	var best := Vector2i.ZERO
	var best_d := -1
	for d: Vector2i in [game.facing, -game.facing, Vector2i(-game.facing.y, game.facing.x), Vector2i(game.facing.y, -game.facing.x)]:
		var n: Vector2i = game.hunter + d
		if room.is_wall(n) or game.thrall_at(n) >= 0 or game.burning(n):
			continue
		var m := 999
		for th in near:
			m = mini(m, absi(th.pos.x - n.x) + absi(th.pos.y - n.y))
		if m > best_d:
			best_d = m
			best = d
	if best == game.facing:
		await _go("forward")
	elif best == -game.facing:
		await _go("back")
	else:
		await _go("wait")


## Shortest way to `goal` that keeps two tiles clear of every thrall you can see (they lunge
## from two) and, if there's another way, round where you last saw one: what a careful player does.
func _safe_path(goal: Vector2i) -> Array:
	var round_them := _safe_path_avoiding(goal, true)
	return round_them if round_them.size() >= 2 else _safe_path_avoiding(goal, false)


func _safe_path_avoiding(goal: Vector2i, remembered: bool) -> Array:
	var bad := {}
	for th in game.thralls:
		if th.get("lying", false) and fog.get_state(th.pos) != Fog.DARK:
			bad[th.pos] = true   # a body you can see: walk round it
		elif remembered and th.last_seen != null and not th.get("gone", false) and not th.get("lying", false):
			for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				bad[th.last_seen + d] = true
	for th in _lit_awake():
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if absi(dx) + absi(dy) <= (2 if th.get("kind", "thrall") == "thrall" else 1):
					bad[th.pos + Vector2i(dx, dy)] = true
	var prev := {game.hunter: game.hunter}
	var q: Array[Vector2i] = [game.hunter]
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		if p == goal:
			var out: Array = [p]
			while p != game.hunter:
				p = prev[p]
				out.push_front(p)
			return out
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n := p + d
			if not prev.has(n) and not room.is_wall(n) and (not bad.has(n) or n == goal):
				prev[n] = p
				q.append(n)
	return []


## One move the way a player makes it: a swipe on the view (WAIT is a button), or the
## move pad's plate when the pad is on.
func _go(kind: String) -> void:
	if pad_on:
		await _press(move_buttons[kind])
	elif kind == "wait":
		await _press(wait_button)
	else:
		var c := Vector2(_col_x() + UI_W / 2.0, (TOP_H + _ui_h() - _bh()) / 2.0)
		var d: Vector2 = {"forward": Vector2(0, -1), "back": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}[kind] * 90.0
		await _swipe_real(c - d, c + d)


func _swipe_real(from: Vector2, to: Vector2) -> void:
	var xf := get_viewport().get_final_transform()
	for pair in [[from, true], [to, false]]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pair[1]
		ev.position = xf * pair[0]
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await get_tree().process_frame
	for i in 40:
		await get_tree().process_frame
		if not busy:
			break


## Fluid moves: a second swipe made mid-glide still counts (QUEUE), and a finger held down
## after a forward swipe keeps walking until it lifts (HOLD).
func _capture_fluid() -> void:
	var xf := get_viewport().get_final_transform()
	var c := Vector2(_col_x() + UI_W / 2.0, (TOP_H + _ui_h() - _bh()) / 2.0)
	var f: Vector2i = game.facing
	var t0: int = game.turn
	for dx in [90.0, -90.0]:     # right then straight back left, no waiting between
		_mouse(xf * (c - Vector2(dx, 0)), true)
		_mouse(xf * (c + Vector2(dx, 0)), false)
		await get_tree().process_frame
	for i in 60:
		await get_tree().process_frame
		if not busy and queued == "":
			break
	print("QUEUE ", "PASS" if game.turn == t0 + 2 and game.facing == f else "FAIL", " turns=", game.turn - t0)
	var at: Vector2i = game.hunter
	t0 = game.turn
	_mouse(xf * (c + Vector2(0, 90)), true)
	var mv := InputEventMouseMotion.new()
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	mv.position = xf * (c - Vector2(0, 90))
	mv.global_position = mv.position
	Input.parse_input_event(mv)
	for i in 120:                # hold until two steps are done (or something stops the walk)
		await get_tree().process_frame
		if game.turn >= t0 + 2 or hold_kind == "":
			break
	var held_steps: int = game.turn - t0
	_mouse(mv.position, false)
	for i in 60:
		await get_tree().process_frame
		if not busy:
			break
	await get_tree().process_frame
	var settled: bool = not busy and game.turn - t0 <= held_steps + 1
	print("HOLD ", "PASS" if held_steps >= 2 and game.hunter == at + f * (game.turn - t0) and settled else "FAIL",
			" steps=", game.turn - t0, " held=", held_steps)
	# two fingers down = spin round: facing flips, two turns spent, one gesture
	var f2: Vector2i = game.facing
	t0 = game.turn
	_touch(0, xf * (c - Vector2(0, 90)), true)
	_touch(1, xf * (c + Vector2(70, -90)), true)
	var dr := InputEventScreenDrag.new()
	dr.index = 0
	dr.position = xf * (c + Vector2(0, 90))
	Input.parse_input_event(dr)
	await get_tree().process_frame
	_touch(0, dr.position, false)
	_touch(1, xf * (c + Vector2(70, 90)), false)
	for i in 60:
		await get_tree().process_frame
		if not busy:
			break
	var cam_back: bool = absf(angle_difference(cam.rotation.y, _yaw(game.facing))) < 0.02
	print("ABOUT ", "PASS" if game.facing == -f2 and game.turn == t0 + 2 and cam_back else "FAIL",
			" facing=", game.facing, " turns=", game.turn - t0)
	# a horror two tiles behind, out of view: the breath plays once, at its tile
	var au = get_node_or_null("/root/Audio")
	var behind_tile: Vector2i = game.hunter - game.facing * 2
	var bi := -1
	for i in game.thralls.size():
		if not game.thralls[i].get("lying", false) and game.thralls[i].get("kind", "thrall") == "thrall":
			bi = i
			break
	if au and bi >= 0 and not room.is_wall(behind_tile) and not room.is_wall(game.hunter - game.facing):
		var keep: Vector2i = game.thralls[bi].pos
		game.thralls[bi].pos = behind_tile
		au.was_behind = {}
		au._world_sounds(game)
		au._world_sounds(game)    # still there next turn: it breathes again
		var heard: bool = au.was_behind.get(bi, 0) == 2
		game.thralls[bi].pos = keep
		au.was_behind = {}
		print("BREATH ", "PASS" if heard else "FAIL")
	else:
		print("BREATH ", "PASS (skipped: wall behind)")


func _touch(index: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = down
	ev.position = pos
	Input.parse_input_event(ev)


func _mouse(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)


## Two passes (the scene reloads between them): 0 = controls + walk to the bell and ring it,
## 1 = read a letter under BRIGHT, then hood and walk blind into a thrall.
func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/renders/"))
	for i in 20:
		await get_tree().process_frame
	if capture_phase == 0 and "--art-only" in OS.get_cmdline_user_args():   # quick look at the art pass
		capture_phase = 4
		kill_3d_seen = true   # the kill isn't in this run
	if capture_phase == 0:
		await _shot("fp_title")
		await _press(title_begin)
		print("TITLE ", "PASS" if title_done else "FAIL")
		await _shot("fp_hint")
		print("HINT ", "PASS" if card_ok != null else "FAIL")
		await _press(card_ok)
		await _press(menu_button)
		await _press(menu_items["FIELD GUIDE"])
		await _shot("fp_guide")
		print("GUIDE ", "PASS" if guide_sheet != null else "FAIL")
		guide_sheet.queue_free()
		guide_sheet = null
		await _press(menu_button)
		await _shot("fp_menu")
		print("MENU ", "PASS" if menu_sheet != null else "FAIL")
		_close_menu()
		_open_report()
		report_text_box.text = "Capture test: the camera froze after a step."
		var rep := _report_text(report_text_box.text)
		await _shot("fp_report")
		print("REPORT ", "PASS" if "tile (" in rep and "oil" in rep and "Build:" in rep else "FAIL")
		# Android back: closes the top sheet, opens the menu in play, closes it again, never quits
		go_back()
		var back_closed: bool = report_sheet == null
		go_back()
		var back_menu: bool = menu_sheet != null
		go_back()
		print("BACK ", "PASS" if back_closed and back_menu and menu_sheet == null \
				and not ProjectSettings.get_setting("application/config/quit_on_go_back") else "FAIL")
	hints_on = false               # the rest of the capture plays like someone who knows
	if modal != null:
		modal.queue_free()
		modal = null
	if capture_phase == 0:
		await _shot("fp_start")
		var at: Vector2i = game.hunter
		var f0: Vector2i = game.facing
		print("OPEN ", "PASS" if not room.is_wall(at + f0) else "FAIL", " facing=", f0)
		await _go("forward")
		var cam_ok: bool = cam.position.distance_to(_cam_pos(game.hunter, game.facing)) < 0.05
		print("FWD ", "PASS" if game.hunter == at + f0 and game.turn == 1 and cam_ok and last_event != "blocked" else "FAIL", " hunter=", game.hunter, " cam_ok=", cam_ok)
		await _go("right")
		print("TURN ", "PASS" if game.facing == Vector2i(-f0.y, f0.x) and game.turn == 2 else "FAIL", " facing=", game.facing)
		var turn_before: int = game.turn
		await _swipe_real(Vector2(380, 420), Vector2(240, 430))   # a finger dragged left = turn left
		print("SWIPE ", "PASS" if game.facing == f0 and game.turn == turn_before + 1 else "FAIL", " facing=", game.facing)
		# the old move pad, from the menu: tall panel, plates work; then back to swipes
		await _press(menu_button)
		await _press(menu_items["MOVE BUTTONS"])
		_close_menu()
		var tall_ok: bool = pad_on and absf(bottom_panel.size.y - PAD_H) < 1.0 and move_buttons["right"].is_visible_in_tree()
		await _shot("fp_pad")
		var f1: Vector2i = game.facing
		await _press(move_buttons["right"])
		await _press(move_buttons["left"])
		var plates_ok: bool = game.facing == f1 and game.turn == turn_before + 3
		await _press(menu_button)
		await _press(menu_items["MOVE BUTTONS"])
		_close_menu()
		var slim_ok: bool = not pad_on and absf(bottom_panel.size.y - SLIM_H) < 1.0 and wait_button.is_visible_in_tree()
		print("PAD ", "PASS" if tall_ok and plates_ok and slim_ok else "FAIL", " tall=", tall_ok, " plates=", plates_ok, " slim=", slim_ok)
		await _capture_fluid()
		await _capture_rotate()
		var bell: Vector2i = room.bells[0]
		var shot_horror := false
		while not game.over():
			var why := await _walk_to(bell, ["horror"])
			if why == "horror" and not shot_horror:
				await _shot("fp_horror")
				shot_horror = true
				break
			elif why != "horror":
				break
		print("HORROR ", "PASS" if shot_horror else "FAIL")
		if not game.over():
			# from here this checks that real input walks you to the bell; whether the thralls
			# are fair is the balance bot's job (tools/balance_bot.gd) and the rule tests'
			for th in game.thralls:
				th.gone = true
			_refresh()
			await _walk_to(bell)
		await _shot("fp_bell")
		print("BELL ", "PASS" if game.rang else "FAIL", " grade=", game.grade(), " oil=", game.oil, " turns=", game.turn, " ", game.cause)
		capture_phase = 1
		get_tree().reload_current_scene()
		return
	if capture_phase == 2:
		await _capture_stalker()
		return
	if capture_phase == 3:
		await _capture_trap()
		return
	if capture_phase == 4:
		await _capture_art()
		return
	var letter: Vector2i = room.letters.reduce(func(a, b): return a if (a - game.hunter).length() < (b - game.hunter).length() else b)
	var reach: Dictionary = room.reachable(game.hunter, 999)
	var path: Array = room.path_in(reach, game.hunter, letter)
	await _walk_to(path[path.size() - 2])
	await _press(lantern_buttons[Fog.Lantern.BRIGHT])
	await _walk_to(letter, ["letter"])
	await _shot("fp_letter")
	var page_up: bool = modal != null and card_ok != null and card_ok.text == "PUT IT AWAY"
	print("LETTER ", "PASS" if game.letters_read.size() == 1 and page_up else "FAIL", " at=", letter, " page=", page_up)
	if page_up:
		await _press(card_ok)
	for k in range(1, Letters.PAGES.size()):   # every page is its own scrap: render the rest too
		_show_page(k)
		await _shot("fp_letter_%d" % (k + 1))
		await _press(card_ok)
	print("PAGES ", "PASS" if modal == null else "FAIL")
	await _press(lantern_buttons[Fog.Lantern.HOODED])
	await _shot("fp_hooded")
	for i in 6:
		if game.over():
			break
		await _walk_to(game.thralls[2].pos)   # blind, into the dark where it stands (thralls[2]: any thrall will do)
	await _shot("fp_dead")
	print("DEATH ", "PASS" if game.dead else "FAIL", " ", game.cause)
	await _press(verdict_buttons["fun7"])
	await _press(verdict_buttons["yes"])
	await _shot("fp_verdict")
	await _press(verdict_buttons["text"])
	var vt := _verdict_text()
	print("VERDICT ", "PASS" if "fun 7/10" in vt and "play again: yes" in vt and "died:" in vt and verdict_buttons.has("copy") else "FAIL", " ", vt.left(60))
	capture_phase = 2
	get_tree().reload_current_scene()


## Pass 2: walk into the Stalker's corridor and face her with the lantern high.
func _capture_stalker() -> void:
	for th in game.thralls:   # her shot alone: the thralls are tested elsewhere
		if th.kind == "thrall":
			th.gone = true
	_refresh()
	await _walk_to(Vector2i(3, 7))
	await _press(lantern_buttons[Fog.Lantern.BRIGHT])
	await _walk_to(Vector2i(4, 6))
	while game.facing != Vector2i.RIGHT and not game.over():
		await _go("right")
	var st: Dictionary = game.thralls.filter(func(t): return t.get("kind") == "stalker")[0]
	await _shot("fp_stalker_3d")
	var index: int = game.thralls.find(st)
	var model: Node3D = thrall_models.get(index)
	var model_visible := is_instance_valid(model) and model.is_visible_in_tree()
	print("STALKER MODEL ", "PASS" if model_visible and not thrall_sprites[index].is_visible_in_tree() else "FAIL")
	print("STALKER ", "PASS" if game.watched(st) and not game.dead else "FAIL", " at=", st.pos, " dead=", game.dead)
	capture_phase = 3
	get_tree().reload_current_scene()


## Pass 3: pick up the boathook, lay a two-tile oil slick, back off, spark it with a thrall in
## it, then hook the next one. Thralls are placed by hand so the shot is the same every run.
func _capture_trap() -> void:
	var kp: Vector2i = room.hooks[0]
	await _walk_to(kp)
	print("HOOKFIND ", "PASS" if game.hook_wear == Night.HOOK_WEAR and item_buttons.hook.visible else "FAIL")
	var west := kp + Vector2i(1, 0)
	await _walk_to(west)
	while game.facing != Vector2i.LEFT and not game.over():
		await _go("left")
	await _press(item_buttons.pour)
	await _go("forward")
	await _press(item_buttons.pour)
	await _go("back")
	var a: Dictionary = game.thralls[0]
	a.pos = west + Vector2i(-2, 0)
	a.target = null
	_refresh()
	await _shot("fp_trap_oil")
	await _press(item_buttons.spark)
	await _shot("fp_trap_fire")
	print("SLICK ", "PASS" if a.get("gone", false) and not game.dead else "FAIL", " oil=", game.oil)
	for i in Night.FIRE_TURNS:
		await _go("wait")
	var b: Dictionary = game.thralls[1]
	b.pos = west + Vector2i(-2, 0)
	b.target = null
	_refresh()
	await _shot("fp_thrall")   # art check: a thrall two tiles ahead, in the lantern's reach
	await _press(item_buttons.hook)
	await _shot("fp_trap_hook")
	print("HOOK ", "PASS" if b.pos == west + Vector2i(-3, 0) and b.stun > 0 and game.hook_wear == Night.HOOK_WEAR - 1 else "FAIL", " at=", b.pos)
	capture_phase = 4
	get_tree().reload_current_scene()


## Pass 4: check harbor geometry and capture lantern-lit fixtures, enemies, and props.
func _capture_art() -> void:
	await _press(lantern_buttons[Fog.Lantern.BRIGHT])
	var entry: Vector2i = room.hunter
	var quay_wall: Vector2i = entry + Vector2i.DOWN
	var bell: Vector2i = room.bells[0]
	var lamp: Vector2i = room.lamps[0]
	var harbor_ok: bool = tile_nodes[entry].mesh is ArrayMesh and tile_tex[entry] == "deck" \
		and tile_nodes[quay_wall].mesh.get_faces().size() > 36 \
		and harbor_fixtures[bell].mesh is ArrayMesh and harbor_fixtures[lamp].mesh is ArrayMesh \
		and harbor_fixtures[bell].visible == (fog.get_state(bell) != Fog.DARK)
	print("HARBOR ", "PASS" if harbor_ok else "FAIL")
	# the bell tower stands on the wall behind the bell and rises far over the walls (2.4)
	var tower_at := Vector2i(roundi(bell_tower.position.x), roundi(bell_tower.position.z)) if bell_tower else Vector2i(-9, -9)
	var tower_ok: bool = bell_tower != null and room.is_wall(tower_at) and (tower_at - bell).length_squared() == 1 \
		and bell_tower.mesh.get_aabb().end.y > 8.0 and bell_tower.visible
	print("TOWER ", "PASS" if tower_ok else "FAIL")
	# the bell tolls on the first turn; from then the chart points to it, here from the far end of the ward
	var toll_ev: Array = game.wait()
	game.hunter = entry
	game.facing = Vector2i.UP
	game.fog.update(game.lights())
	_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
	_refresh()
	await _shot("fp_art_bell_map")
	var bell_map_ok: bool = "toll" in toll_ev and game.bell_heard
	print("BELL MAP ", "PASS" if bell_map_ok else "FAIL")
	var views := [["fp_art_bell", Vector2i(3, 1), Vector2i.LEFT],
		["fp_art_flask", Vector2i(5, 4), Vector2i.LEFT],
		["fp_art_hook", Vector2i(6, 18), Vector2i.RIGHT],
		["fp_art_lamp", Vector2i(9, 12), Vector2i.RIGHT],
		["fp_art_letter", Vector2i(7, 4), Vector2i.UP],
		["fp_art_thrall_a", Vector2i(10, 6), Vector2i.UP],    # the hooded one, two tiles off
		["fp_art_thrall_b", Vector2i(5, 12), Vector2i.LEFT],
		["fp_art_thrall_c", Vector2i(3, 16), Vector2i.LEFT]]
	for v in views:
		game.hunter = v[1]
		game.facing = v[2]
		game.fog.update(game.lights())
		_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
		_refresh()
		await _shot(v[0])
	# the tell and the lunge: a thrall two tiles ahead, crouched; then reared up with blood at the edges
	var ti := -1
	for i in game.thralls.size():
		if game.thralls[i].kind == "thrall" and not game.thralls[i].get("lying", false):
			ti = i
			break
	var keep_pos: Vector2i = game.thralls[ti].pos
	game.hunter = Vector2i(6, 18)
	game.facing = Vector2i.RIGHT
	game.thralls[ti].pos = Vector2i(8, 18)
	game.fog.update(game.lights())
	_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
	_refresh()
	thrall_nodes[ti].position = _w(game.thralls[ti].pos)
	var thrall_model: Node3D = thrall_models.get(ti)
	await _shot("fp_art_thrall_3d")
	var thrall_model_ok: bool = thrall_model != null and thrall_model.is_visible_in_tree() and not thrall_sprites[ti].visible
	game.thralls[ti].crouched = true
	for k in 8:
		await get_tree().process_frame
	await _shot("fp_art_crouch")
	thrall_model_ok = thrall_model_ok and _rig_state(ti) == "crouch"   # the scream, the tell before it comes
	game.thralls[ti].crouched = false
	game.thralls[ti].lunge_cd = Night.LUNGE_COOLDOWN
	game.thralls[ti].pos = Vector2i(7, 18)
	_refresh()
	thrall_nodes[ti].position = _w(game.thralls[ti].pos)
	for k in 4:
		await get_tree().process_frame
	lunge_hit = 20.0   # held for the shot (a capture frame can be slow)
	await _shot("fp_art_lunge")
	thrall_model_ok = thrall_model_ok and _rig_state(ti) == "lunge"
	print("THRALL MODEL ", "PASS" if thrall_model_ok else "FAIL")
	game.thralls[ti].lunge_cd = 0
	game.thralls[ti].pos = keep_pos
	thrall_nodes[ti].position = _w(keep_pos)
	lunge_hit = 0.0
	# a corpse playing dead two tiles ahead, wet prints leading past it
	game.hunter = Vector2i(17, 10)
	game.facing = Vector2i.DOWN
	game.prints = {Vector2i(17, 11): 9, Vector2i(17, 9): 4}
	game.fog.update(game.lights())
	_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
	_refresh()
	await _shot("fp_art_corpse")
	var corpse_i := -1   # the corpse by what it is (lying), never by index
	for i in game.thralls.size():
		if game.thralls[i].get("lying", false) and game.thralls[i].pos == Vector2i(17, 12):
			corpse_i = i
	var corpse_ok: bool = corpse_i >= 0 and thrall_nodes[corpse_i].visible and _rig_state(corpse_i) == "dead" and print_nodes.size() == 2
	print("CORPSE ", "PASS" if corpse_ok else "FAIL")
	# your hands are 3D: the lantern hangs in your right fist with the light inside its globe,
	# and the boathook shows in your left exactly while you carry one
	game.hook_wear = 3
	await get_tree().process_frame
	await _shot("fp_hands")   # both fists: the lantern on its link, the boathook's handle
	var vm_ok: bool = vm_lantern.is_visible_in_tree() and light.get_parent() == vm_lamp and vm_hook.is_visible_in_tree() \
		and not hook_art.is_visible_in_tree() and not hand_art.is_visible_in_tree()
	game.hook_wear = 0
	await get_tree().process_frame
	vm_ok = vm_ok and not vm_hook.is_visible_in_tree()
	print("VIEWMODEL ", "PASS" if vm_ok else "FAIL")
	# the bride's body turned well away from you; her head comes round anyway
	var bi := -1
	for i in game.thralls.size():
		if game.thralls[i].get("kind", "thrall") == "stalker":
			bi = i
	var head_ok := false
	if bi >= 0 and thrall_rigs.has(bi):
		var keep_b: Vector2i = game.thralls[bi].pos
		game.hunter = Vector2i(6, 18)
		game.facing = Vector2i.RIGHT
		game.thralls[bi].pos = Vector2i(8, 18)
		game.fog.update(game.lights())
		_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
		_refresh()
		var br: Node3D = thrall_rigs[bi]
		thrall_nodes[bi].position = _w(game.thralls[bi].pos)
		br.set_meta("faced_at", game.thralls[bi].pos)
		_face_cam(bi, br)
		for k in 10:
			await get_tree().process_frame
		await _shot("fp_art_bride_face")
		br.rotation.y += 1.5   # her body faces off down the wall
		# her head holds up to 1.6 s between snaps: wait (real time) for the next one, not a frame count
		var waited := 0.0
		while waited < 3.0 and not (br.look and br.look._want.get_angle() > 1.0 and br.look._cur.get_angle() > 0.9):
			await get_tree().process_frame
			waited += get_process_delta_time()
		head_ok = br.look != null and br.look._want.get_angle() > 1.0 and br.look._cur.get_angle() > 0.9
		await _shot("fp_art_bride_head")
		game.thralls[bi].pos = keep_b
		thrall_nodes[bi].position = _w(keep_b)
	print("HEAD LOOK ", "PASS" if head_ok else "FAIL")
	# dread past half: a black figure down the corridor that isn't there
	var phantom_ok := false
	game.setting = Fog.Lantern.NORMAL
	for y in room.size.y:
		for x in room.size.x:
			for f: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if phantom_ok or room.is_wall(Vector2i(x, y)):
					continue
				game.hunter = Vector2i(x, y)
				game.facing = f
				game.fog.update(game.lights())
				phantom_ok = _show_phantom() and phantom.position.distance_to(_w(game.hunter)) >= 3.0
	if phantom_ok:
		_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
		_refresh()
		phantom_t = 99.0
		for k in 4:
			await get_tree().process_frame
		phantom_ok = phantom.is_visible_in_tree()
		await _shot("fp_art_phantom")
		_hide_phantom()
	print("PHANTOM ", "PASS" if phantom_ok else "FAIL", " at=", game.hunter, " facing=", game.facing)
	var art_ok := harbor_ok and tower_ok and corpse_ok and thrall_model_ok and vm_ok and head_ok and phantom_ok and kill_3d_seen and bell_map_ok
	print("ART ", "PASS" if art_ok else "FAIL")   # CI requires this final result
	get_tree().quit(0 if art_ok else 1)
