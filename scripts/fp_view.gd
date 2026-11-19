extends Node3D
## First-person test (Nov 19). Same room, same rules (sim/night.gd), seen from her eyes.
## Grid crawler: step forward / back, turn 90 degrees, wait. Every action is one turn,
## turning included: the world moves while you look away. A corner map shows the tiles
## you remember (the fog system, drawn small). Top bar button switches to the top-down view.
## Renders + button test:
##   xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3
##     --resolution 1080x1920 res://scenes/fp_room.tscn -- --capture   -> docs/renders/fp_*.png

const Fog = preload("res://scripts/sim/fog.gd")
const Night = preload("res://scripts/sim/night.gd")
const Sound = preload("res://scripts/audio.gd")   # all sound; hooks do nothing without the autoload
const Lessons = preload("res://scripts/lessons.gd")
const Letters = preload("res://scripts/letters.gd")
const UI = preload("res://scripts/ui_style.gd")
const Perf = preload("res://scripts/perf.gd")

const UI_W := 540
const TOP_H := 72
const BOTTOM_H := 330              # status + lantern row + move pad
const WALL_H := 2.4                # tall: walls should loom over you
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
const LIGHT := {
	Fog.Lantern.HOODED: [0.8, 0.25],
	Fog.Lantern.NORMAL: [3.4, 1.7],
	Fog.Lantern.BRIGHT: [5.6, 2.4],
}
const STOP_EVENTS := ["heard", "hook_hit", "hook_broke", "hook_found", "burned", "ignite", "burned_self", "rang", "horror", "panic", "out_of_oil", "taken", "grabbed", "escaped", "letter", "oil", "letter_dim", "stalker_moved"]
const ROOM := "res://rooms/one_night.txt"   # the slice: reach the bell, ring it, get graded
const MAP_CELL := 7.0
const VIEW_RANGE := 10.0           # tiles further than this aren't drawn (fog hides them)

var game
var room
var fog
var busy := false
var t := 0.0
var flicker := false
var fake_flicker := false
var last_event := ""
var swipe_from = null              # where a finger went down on the world view (window px)
const SWIPE_MIN := 50.0            # UI px a finger must travel to count as a swipe

var cam: Camera3D
var light: OmniLight3D
var world_env: Environment
var perf: Perf                    # FPS readout + graphics quality (scripts/perf.gd)
var hand: Node3D
var flame: MeshInstance3D
var tile_mats := {}                # lamp posts + letters: their own material each (few)
var tile_nodes := {}               # floor/wall tile -> MeshInstance3D
var tile_tex := {}                 # floor/wall tile -> texture name
var shared_mats := {}              # "tex|shade" -> one material shared by every tile like it
var tile_base := {}
var thrall_nodes: Array = []
var flask_nodes := {}             # tile -> node, hidden once picked up
var hook_nodes := {}              # tile -> boathook lying on the floor
var slick_nodes := {}             # tile -> oil slick / fire on the floor (made as they appear)
var item_buttons := {}            # HOOK / POUR / SPARK, left edge above the bottom panel
var letter_mats := {}             # tile -> material, goes pale once read
var letters_label: Label
static var capture_phase := 0     # capture runs twice: win at the bell, then a death

var hud: Control
var hand_art: TextureRect
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
var minimap: Control
var end_screen: Control


func _ready() -> void:
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	game = Night.start(FileAccess.get_file_as_string(ROOM), _pick_night())
	room = game.room
	fog = game.fog
	_load_hints()
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
	var asked := OS.get_environment("LM_NIGHT")
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('night') || ''", true)
		if q is String and q != "":
			asked = q
	if asked.is_valid_int() and int(asked) > 0:
		return int(asked)
	return randi_range(1, 9999)


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


func _place_cam(pos: Vector3, yaw: float) -> void:
	cam.position = pos
	cam.rotation = Vector3(0, yaw, 0)


# ---------------------------------------------------------------- world

func _buried(p: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n := p + d
		if n.x >= 0 and n.y >= 0 and n.x < room.size.x and n.y < room.size.y and not room.is_wall(n):
			return false
	return true


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#020308")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = DEEP
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color("#0a0f18")
	env.fog_density = 0.09          # close fog: the corridor dissolves a few tiles out
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

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(1, 0.2, 1)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1, WALL_H, 1)
	for y in room.size.y:
		for x in room.size.x:
			var p := Vector2i(x, y)
			if room.is_wall(p) and _buried(p):
				continue           # a wall with no floor beside it can never be seen: no draw
			var mi := MeshInstance3D.new()
			mi.visibility_range_end = VIEW_RANGE   # past this the fog has it anyway
			if room.is_wall(p):
				mi.mesh = wall_mesh
				mi.position = _w(p) + Vector3(0, WALL_H / 2.0, 0)
				var stone: bool = (x * 3 + y) % 3 != 0
				tile_tex[p] = "wall_granite" if stone else "wall_damask"
				# Canva art is lit flat: let the lantern do the light. Paper is paler, so sink it more.
				tile_base[p] = Color(0.72, 0.72, 0.78) if stone else Color(0.5, 0.48, 0.46)
			else:
				mi.mesh = floor_mesh
				mi.position = _w(p) + Vector3(0, -0.1, 0)
				tile_tex[p] = "exit" if p in room.exits else "floor_stone"
				tile_base[p] = Color(0.58, 0.58, 0.62)   # the flagstone art is lit flat: sink it into the dark
			add_child(mi)
			tile_nodes[p] = mi

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#20242c")
	for lp: Vector2i in room.lamps:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.1, 2.6, 0.1)
		post.mesh = pm
		post.position = _w(lp) + Vector3(0, 1.3, 0)
		post.material_override = iron.duplicate()
		add_child(post)
		tile_mats[Vector2i(-100 - lp.x, -100 - lp.y)] = post.material_override
		tile_base[Vector2i(-100 - lp.x, -100 - lp.y)] = iron.albedo_color

	for bp: Vector2i in room.bells:
		# painted bell (Forge art, keyed) on a short iron rod from above, a touch bright: it's the goal.
		# No frame legs: from the side a leg sat right in front of the bell.
		var rod := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.05, 1.0, 0.05)
		rod.mesh = rm
		rod.position = _w(bp) + Vector3(0, 2.4, 0)
		rod.material_override = iron.duplicate()
		add_child(rod)
		var bell := _prop_sprite("prop_bell", 0.95)
		bell.position = _w(bp) + Vector3(0, 0.95, 0)
		bell.modulate = Color(1.2, 1.12, 1.0)
		add_child(bell)

	# letters: a pale page nailed at chest height, facing the open floor. Read under BRIGHT.
	for np: Vector2i in room.letters:
		var page := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.28, 0.36)
		page.mesh = q
		var pm2 := StandardMaterial3D.new()
		pm2.albedo_color = Color("#b9ab88")
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

	# oil flasks on the floor: small amber glass that catches the lantern
	for op: Vector2i in room.oil_flasks:
		var flask := _prop_sprite("prop_flask", 0.3)
		flask.position = _w(op) + Vector3(0.15, 0, 0.1)
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

	for thrall in game.thralls:
		var holder := Node3D.new()
		holder.position = _w(thrall.pos)
		var th := Sprite3D.new()
		var stalker: bool = thrall.get("kind", "thrall") == "stalker"
		th.texture = _tex("bride" if stalker else "thrall_dock")   # thrall = drowned dock worker
		th.pixel_size = 1.85 / th.texture.get_height()   # ~1.85 tiles tall
		th.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		th.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		th.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		th.shaded = true
		th.offset = Vector2(0, th.texture.get_height() / 2.0)
		th.modulate = Color(0.8, 0.8, 0.82)    # thralls: sodden, a touch darker than the lantern says
		if stalker:
			th.modulate = Color(1.25, 1.22, 1.3)   # the bride: pale, catches the light
			th.pixel_size = 2.15 / th.texture.get_height()
		holder.add_child(th)
		add_child(holder)
		thrall_nodes.append(holder)

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.05
	# The HUD covers the top 72 px and bottom 330 px, so centre the view on the strip
	# between them: a frustum camera with its centre shifted up.
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	_fit_camera()
	add_child(cam)

	# her hand and lantern, low right, riding with the camera
	hand = Node3D.new()
	hand.position = Vector3(HAND_X, HAND_Y, -0.55)
	cam.add_child(hand)
	hand.visible = false   # the painted hand overlay (HUD) replaces the placeholder box
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
	m.albedo_texture = _tex(tex)
	if tex.begins_with("wall"):
		m.uv1_scale = Vector3(3, 2.0 * 1.6, 1)   # BoxMesh UVs are a 3x2 atlas: tile it
		m.roughness = 0.9
	elif tex == "floor_stone":
		m.uv1_scale = Vector3(3, 2, 1)   # BoxMesh UVs are a 3x2 atlas: one full slab set per tile
		m.roughness = 0.45                # wet stone: the lantern glints off it
	else:
		m.roughness = 0.65
	m.albedo_color = Color(base.r * k, base.g * k, base.b * k)
	shared_mats[key] = m
	return m


func _refresh_fog() -> void:
	for p: Vector2i in tile_nodes:
		var mat := _tile_mat(tile_tex[p], tile_base[p], SHADE[fog.get_state(p)])
		if tile_nodes[p].material_override != mat:
			tile_nodes[p].material_override = mat
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
	for kp: Vector2i in hook_nodes:
		hook_nodes[kp].visible = game.hooks_left.has(kp) and fog.get_state(kp) != Fog.DARK
	_sync_slicks()
	for fp: Vector2i in flask_nodes:
		flask_nodes[fp].visible = game.flasks_left.has(fp) and fog.get_state(fp) != Fog.DARK
	for lp: Vector2i in letter_mats:
		if game.letters_read.has(lp):
			tile_base[Vector2i(-200 - lp.x, -200 - lp.y)] = Color("#5e5444")   # read: it's spent
	var eff: int = game.effective()
	light.omni_range = LIGHT[eff][0]
	light.light_energy = LIGHT[eff][1]
	flame.visible = eff != Fog.Lantern.HOODED
	if minimap:
		minimap.queue_redraw()


## Oil on the floor: a glossy black puddle with a ragged edge while soaked; on fire, tongues
## of flame (billboard particles, additive) over a glowing pool, with a light that gutters.
## Drawn in code until Foxboard art lands (docs/art_needs.md: slick decal + flame sheet).
var _puddle: Texture2D
var _flame: Texture2D


## A puddle shape: a soft blob with a noisy, ragged rim (alpha only; colour comes from the material).
func _puddle_tex() -> Texture2D:
	if _puddle == null:
		var n := FastNoiseLite.new()
		n.seed = 7
		n.frequency = 0.045
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2(x - 64, y - 64).length() / 64.0
				var edge := 0.78 + 0.22 * n.get_noise_2d(x, y)
				var a := clampf((edge - d) * 9.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_puddle = ImageTexture.create_from_image(img)
	return _puddle


## One flame tongue: hot white-yellow core fading out at the edges and the top.
func _flame_tex() -> Texture2D:
	if _flame == null:
		var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 32:
				var u := (x - 15.5) / 16.0
				var v := y / 63.0                       # 0 top, 1 bottom
				var width := 0.25 + 0.75 * pow(v, 0.6)  # narrow tip, wide base
				var a := clampf(1.0 - absf(u) / width, 0.0, 1.0) * clampf(v * 1.6, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_flame = ImageTexture.create_from_image(img)
	return _flame


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
	m.albedo_texture = _flame_tex()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR   # soft flames, not pixel blocks
	m.no_depth_test = false
	q.material = m
	f.mesh = q
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
			mat.albedo_texture = _puddle_tex()
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
			mat.albedo_color = Color(0.35, 0.1, 0.02, 0.95)
			mat.emission_enabled = true
			mat.emission = Color("#ff5a12")
			mat.emission_energy_multiplier = 1.4
		else:
			var k: float = SHADE[fog.get_state(p)]
			mat.albedo_color = Color(0.04 * k + 0.015, 0.035 * k + 0.012, 0.025 * k + 0.01, 0.92)
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
	if busy or game.over() or modal != null or guide_sheet != null or menu_sheet != null or report_sheet != null:
		return
	busy = true
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
		"wait": events = game.wait()
		"hook": events = game.hook()
		"pour": events = game.pour()
		"spark": events = game.spark()
	Sound.hook_turn(kind, events, game, game.turn != turn0)
	# a quiet step returns no events too: only an unspent turn means you hit stone
	if game.turn == turn0 and not game.over() and kind in ["forward", "back"]:
		busy = false          # bumped a wall (or a thrall you can see): no turn spent
		var ahead: Vector2i = game.hunter + (game.facing if kind == "forward" else -game.facing)
		last_event = "blocked_fire" if game.burning(ahead) else ("blocked_horror" if game.thrall_at(ahead) >= 0 else "blocked")
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
	var e := 0.0
	while e < STEP_TIME:
		e += get_process_delta_time()
		var k := smoothstep(0.0, 1.0, minf(e / STEP_TIME, 1.0))
		var bob := sin(k * PI) * 0.03 if kind in ["forward", "back"] else 0.0
		_place_cam(from_pos.lerp(to_pos, k) + Vector3(0, bob, 0), lerp_angle(from_yaw, to_yaw, k))
		for j in thrall_nodes.size():
			thrall_nodes[j].position = _w(from_t[j]).lerp(_w(game.thralls[j].pos), k)
		await get_tree().process_frame
	turn_events = events
	for ev in events:
		if ev in STOP_EVENTS or last_event not in STOP_EVENTS:
			last_event = ev
	_refresh()
	if flicker and not was_flicker and last_event not in STOP_EVENTS:
		last_event = "flicker"
		_refresh_hud()
	busy = false
	if game.over():
		_show_end()
	elif "letter" in events:
		_show_page(game.letters_read.size() - 1)
	else:
		_teach(last_event)


## A swipe in UI pixels. Mostly vertical: step; mostly sideways: turn the way the finger went.
func swipe(d: Vector2) -> void:
	if absf(d.y) >= absf(d.x):
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
	if press:
		swipe_from = event.position
	elif release and swipe_from != null:
		var to_ui := get_viewport().get_final_transform().affine_inverse()
		var d: Vector2 = to_ui * event.position - to_ui * swipe_from
		swipe_from = null
		if d.length() >= SWIPE_MIN:
			swipe(d)
	# keyboard for the web build: arrows / WASD, space waits, 1-2-3 lantern
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP: act("forward")
			KEY_S, KEY_DOWN: act("back")
			KEY_A, KEY_LEFT: act("left")
			KEY_D, KEY_RIGHT: act("right")
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
	_flicker_fires()
	if busy:
		pass
	var eff: int = game.effective()
	if eff == Fog.Lantern.HOODED:
		if hand_art:
			hand_art.modulate = Color(0.22, 0.2, 0.2)   # shutter closed: barely a shape
		return
	var base: float = LIGHT[eff][1]
	var wobble := sin(t * 7.0) * 0.05 + sin(t * 13.0) * 0.04
	if (flicker or fake_flicker) and fmod(t, 1.1) < 0.18:
		wobble -= 0.6 * absf(sin(t * 60.0))
	light.light_energy = base + wobble
	hand.position.y = HAND_Y + sin(t * 2.1) * 0.006   # the hand isn't quite steady
	if hand_art:
		var k: float = clampf(light.light_energy / LIGHT[Fog.Lantern.NORMAL][1], 0.55, 1.25)
		hand_art.modulate = Color(k, k, k)
		hand_art.position.y = _ui_h() - BOTTOM_H - HAND_W + 22 + sin(t * 2.1) * 2.0


# ---------------------------------------------------------------- HUD

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
	var mid := (TOP_H + (vis.y - BOTTOM_H)) / 2.0
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
		hand_art.position.y = _ui_h() - BOTTOM_H - HAND_W + 22
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
	hand_art.position = Vector2(UI_W - HAND_W + 6, _ui_h() - BOTTOM_H - HAND_W + 22)
	hand_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_col.add_child(hand_art)

	var vig := TextureRect.new()
	vig.texture = gt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vig)
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

	# corner map: what you remember, drawn small. North is up; the arrow is you.
	minimap = Control.new()
	minimap.size = Vector2(room.size) * MAP_CELL
	minimap.position = Vector2(UI_W - 14 - minimap.size.x, TOP_H + 10)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_map)
	hud.add_child(minimap)

	var bottom := ColorRect.new()
	bottom.color = UI.INK
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM_H
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
		Fog.Lantern.HOODED: "HOODED\nno oil · unseen",
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
	# item column, left edge above the panel (the lantern hand is low right). Shown when usable.
	item_buttons["hook"] = _button("HOOK", Vector2.ZERO, Vector2(132, 64), act.bind("hook"), hud)
	item_buttons["pour"] = _button("POUR OIL\n3 oil", Vector2.ZERO, Vector2(132, 64), act.bind("pour"), hud)
	item_buttons["spark"] = _button("SPARK\n1 oil", Vector2.ZERO, Vector2(132, 64), act.bind("spark"), hud)
	for k in item_buttons:
		item_buttons[k].add_theme_font_size_override("font_size", 15)
		_plate_style(item_buttons[k])
		item_buttons[k].add_theme_color_override("font_color", Color("#c9ad78"))


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


## Remembered floor dim, lit floor amber, walls you've seen grey; thralls only if lit now.
func _draw_map() -> void:
	var c := MAP_CELL
	minimap.draw_rect(Rect2(Vector2(-3, -3), minimap.size + Vector2(6, 6)), Color(0, 0, 0, 0.6))
	minimap.draw_rect(Rect2(Vector2(-3, -3), minimap.size + Vector2(6, 6)), UI.BRASS_DIM, false, 1.0)
	for y in room.size.y:
		for x in room.size.x:
			var p := Vector2i(x, y)
			var st: int = fog.get_state(p)
			if st == Fog.DARK:
				continue
			var col: Color
			if room.is_wall(p):
				col = Color(0.3, 0.34, 0.42) if st == Fog.LIT else Color(0.18, 0.2, 0.26)
			else:
				col = Color(0.75, 0.5, 0.2) if st == Fog.LIT else Color(0.28, 0.3, 0.36)
			minimap.draw_rect(Rect2(Vector2(x, y) * c + Vector2(0.5, 0.5), Vector2(c - 1, c - 1)), col)
			if room.bells.has(p):
				minimap.draw_circle((Vector2(p) + Vector2(0.5, 0.5)) * c, c * 0.4, UI.AMBER)
			elif room.letters.has(p) and not game.letters_read.has(p):
				minimap.draw_rect(Rect2(Vector2(p) * c + Vector2(2, 1.5), Vector2(c - 4, c - 3)), UI.TEXT)
			elif game.flasks_left.has(p):
				minimap.draw_rect(Rect2(Vector2(p) * c + Vector2(2.5, 2.5), Vector2(c - 5, c - 5)), LANTERN)
	for th in game.thralls:
		if th.get("gone", false):
			continue   # burned: no square, no last-seen mark
		if fog.get_state(th.pos) == Fog.LIT:
			minimap.draw_rect(Rect2(Vector2(th.pos) * c + Vector2(2, 2), Vector2(c - 4, c - 4)), UI.BLOOD)
		elif th.last_seen != null:
			# last-seen marker: where you saw it, not where it is. It may have moved.
			var m: Vector2 = Vector2(th.last_seen) * c
			var dim := Color(UI.BLOOD, 0.55)
			minimap.draw_line(m + Vector2(2, 2), m + Vector2(c - 2, c - 2), dim, 1.5)
			minimap.draw_line(m + Vector2(c - 2, 2), m + Vector2(2, c - 2), dim, 1.5)
	var ctr := (Vector2(game.hunter) + Vector2(0.5, 0.5)) * c
	var f := Vector2(game.facing)
	var side := Vector2(-f.y, f.x)
	minimap.draw_colored_polygon(PackedVector2Array([ctr + f * 4.5, ctr - f * 3 + side * 3.5, ctr - f * 3 - side * 3.5]), UI.TEXT)


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
		s = "Swipe up to walk, down to back away, sideways to turn. Find the bell."
	status_label.text = s
	if item_buttons:
		item_buttons.hook.visible = game.hook_wear > 0
		item_buttons.hook.text = "HOOK\n%d hit%s left" % [game.hook_wear, "" if game.hook_wear == 1 else "s"]
		item_buttons.spark.visible = game.slicks.values().has(0)
		var y: float = _ui_h() - BOTTOM_H - 12 - 64
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
	var bride := TextureRect.new()
	bride.texture = _tex("bride")
	bride.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # painted, not pixel art
	bride.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bride.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bride.modulate = Color(0.5, 0.48, 0.52, 0.55)
	bride.size = Vector2(UI_W, 560)
	bride.position = Vector2(0, _ui_h() * 0.5 - 330)
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
	_center(hints, modal, by + 152, 340)
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
	list.add_child(_label("GRADES", 18, UI.AMBER, UI.head()))
	var gl := _label(Lessons.GRADE_LINE, 18, UI.TEXT)
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD
	gl.custom_minimum_size.x = UI_W - 100
	list.add_child(gl)
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
		if it[1] is String and it[1] == "fps":
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
	for id in cfg.get_value("hints", "seen", []):
		seen[id] = true


func _save_hints() -> void:
	if capture_mode:
		return
	var cfg := ConfigFile.new()
	cfg.load("user://lethemoor.cfg")   # keep the other sections (audio mute, fps, graphics)
	cfg.set_value("hints", "on", hints_on)
	cfg.set_value("hints", "seen", seen.keys())
	cfg.save("user://lethemoor.cfg")


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
	small.text += "\n\nNight %d" % game.seed if game.seed > 0 else ""
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
	return "Lethemoor verdict: fun %d/10, play again: %s. Night %d: %s, %d turns. Build %s, %s %s." % [
		verdict_fun, verdict_again, game.seed, how, game.turn, build, OS.get_name(), OS.get_model_name()]


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
	var centred: bool = vis.x > vis.y and absf(move_buttons["forward"].get_global_rect().get_center().x - vis.x / 2.0) < 2.0
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
		var path: Array = _safe_path(goal)
		if path.size() < 2:
			await _press(move_buttons["wait"])   # a thrall sits on every way through: let it move
			continue
		var d: Vector2i = path[1] - game.hunter
		if game.facing == d:
			await _press(move_buttons["forward"])
		else:
			var right := Vector2i(-game.facing.y, game.facing.x)
			await _press(move_buttons["right" if d == right else "left"])
		if last_event in stop_on:
			return last_event
		if card_ok != null and card_ok.text == "PUT IT AWAY":
			await _press(card_ok)   # a letter read on the way: put the page away and go on
	return "gave_up"


## Shortest way to `goal` that never steps next to a thrall you can see (what a player does).
func _safe_path(goal: Vector2i) -> Array:
	var bad := {}
	for th in game.thralls:
		if fog.get_state(th.pos) == Fog.LIT:
			for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				bad[th.pos + d] = true
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


## Two passes (the scene reloads between them): 0 = controls + walk to the bell and ring it,
## 1 = read a letter under BRIGHT, then hood and walk blind into a thrall.
func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/renders/"))
	for i in 20:
		await get_tree().process_frame
	if capture_phase == 0:
		await _shot("fp_title")
		await _press(title_begin)
		print("TITLE ", "PASS" if title_done else "FAIL")
		await _shot("fp_hint")
		print("HINT ", "PASS" if card_ok != null else "FAIL")
		await _press(card_ok)
		await _press(move_buttons["guide"])
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
		await _press(move_buttons["forward"])
		var cam_ok: bool = cam.position.distance_to(_cam_pos(game.hunter, game.facing)) < 0.05
		print("FWD ", "PASS" if game.hunter == at + f0 and game.turn == 1 and cam_ok and last_event != "blocked" else "FAIL", " hunter=", game.hunter, " cam_ok=", cam_ok)
		await _press(move_buttons["right"])
		print("TURN ", "PASS" if game.facing == Vector2i(-f0.y, f0.x) and game.turn == 2 else "FAIL", " facing=", game.facing)
		var turn_before: int = game.turn
		await _swipe_real(Vector2(380, 420), Vector2(240, 430))   # a finger dragged left = turn left
		print("SWIPE ", "PASS" if game.facing == f0 and game.turn == turn_before + 1 else "FAIL", " facing=", game.facing)
		await _capture_rotate()
		var bell: Vector2i = room.bells[0]
		var shot_horror := false
		while not game.over():
			var why := await _walk_to(bell, ["horror"])
			if why == "horror" and not shot_horror:
				await _shot("fp_horror")
				shot_horror = true
			elif why != "horror":
				break
		print("HORROR ", "PASS" if shot_horror else "FAIL")
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
		await _walk_to(game.thralls[2].pos)   # blind, into the dark where it stands
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
	await _walk_to(Vector2i(3, 7))
	await _press(lantern_buttons[Fog.Lantern.BRIGHT])
	await _walk_to(Vector2i(4, 6))
	while game.facing != Vector2i.RIGHT and not game.over():
		await _press(move_buttons["right"])
	var st: Dictionary = game.thralls.filter(func(t): return t.get("kind") == "stalker")[0]
	await _shot("fp_stalker")
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
		await _press(move_buttons["left"])
	await _press(item_buttons.pour)
	await _press(move_buttons["forward"])
	await _press(item_buttons.pour)
	await _press(move_buttons["back"])
	var a: Dictionary = game.thralls[0]
	a.pos = west + Vector2i(-2, 0)
	a.target = null
	_refresh()
	await _shot("fp_trap_oil")
	await _press(item_buttons.spark)
	await _shot("fp_trap_fire")
	print("SLICK ", "PASS" if a.get("gone", false) and not game.dead else "FAIL", " oil=", game.oil)
	for i in Night.FIRE_TURNS:
		await _press(move_buttons["wait"])
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


## Pass 4 (art only, no checks): stand in fixed spots with the lantern high and look at the props.
func _capture_art() -> void:
	await _press(lantern_buttons[Fog.Lantern.BRIGHT])
	var views := [["fp_art_bell", Vector2i(3, 1), Vector2i.LEFT],
		["fp_art_flask", Vector2i(5, 4), Vector2i.LEFT],
		["fp_art_hook", Vector2i(6, 18), Vector2i.RIGHT]]
	for v in views:
		game.hunter = v[1]
		game.facing = v[2]
		game.fog.update(game.lights())
		_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
		_refresh()
		await _shot(v[0])
	print("ART PASS")
	get_tree().quit()
