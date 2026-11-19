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

const LANTERN := Color("#ff9a3c")
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
	Fog.Lantern.NORMAL: [3.4, 2.2],
	Fog.Lantern.BRIGHT: [5.6, 3.0],
}
const STOP_EVENTS := ["rang", "horror", "panic", "out_of_oil", "taken", "grabbed", "escaped", "letter", "oil", "letter_dim"]
const ROOM := "res://rooms/one_night.txt"   # the slice: reach the bell, ring it, get graded
const MAP_CELL := 7.0

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
var hand: Node3D
var flame: MeshInstance3D
var tile_mats := {}
var tile_base := {}
var thrall_nodes: Array = []
var flask_nodes := {}             # tile -> node, hidden once picked up
var letter_mats := {}             # tile -> material, goes pale once read
var letters_label: Label
static var capture_phase := 0     # capture runs twice: win at the bell, then a death

var hud: Control
var status_label: Label
var oil_pips: Array[ColorRect] = []
var oil_count: Label
var dread_fill: ColorRect
var dread_label: Label
var lantern_buttons := {}
var move_buttons := {}
var minimap: Control
var end_screen: Control


func _ready() -> void:
	game = Night.start(FileAccess.get_file_as_string(ROOM))
	room = game.room
	fog = game.fog
	_build_world()
	_build_hud()
	_place_cam(_cam_pos(game.hunter, game.facing), _yaw(game.facing))
	_refresh()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _tex(name: String) -> Texture2D:
	return load("res://assets/art/%s.png" % name)


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
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = MOON
	moon.light_energy = 0.12
	moon.rotation_degrees = Vector3(-60, -30, 0)
	add_child(moon)

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(1, 0.2, 1)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1, WALL_H, 1)
	for y in room.size.y:
		for x in room.size.x:
			var p := Vector2i(x, y)
			var mi := MeshInstance3D.new()
			var m := StandardMaterial3D.new()
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			m.metallic_specular = 0.25
			if room.is_wall(p):
				mi.mesh = wall_mesh
				mi.position = _w(p) + Vector3(0, WALL_H / 2.0, 0)
				m.albedo_texture = _tex("wall_face_%d" % ((x + y) % 2))
				m.uv1_scale = Vector3(3, 2.4 * 2, 1)   # BoxMesh UVs are a 3x2 atlas: tile it
				m.roughness = 0.9
				tile_base[p] = Color(0.85, 0.82, 0.92)
			else:
				mi.mesh = floor_mesh
				mi.position = _w(p) + Vector3(0, -0.1, 0)
				m.albedo_texture = _tex("exit" if p in room.exits else "floor_%d" % ((x * 7 + y * 13) % 4))
				m.roughness = 0.65
				tile_base[p] = Color(1, 1, 1)
			mi.material_override = m
			add_child(mi)
			tile_mats[p] = m

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

	# the bell: a dark frame with a brass bell hanging in it. Brass glows a little: it's the goal.
	for bp: Vector2i in room.bells:
		for side in [-0.4, 0.4]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.08, 2.2, 0.08)
			leg.mesh = lm
			leg.position = _w(bp) + Vector3(side, 1.1, 0)
			leg.material_override = iron.duplicate()
			add_child(leg)
		var bell := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.12
		bm.bottom_radius = 0.3
		bm.height = 0.42
		bell.mesh = bm
		bell.position = _w(bp) + Vector3(0, 1.6, 0)
		var brass := StandardMaterial3D.new()
		brass.albedo_color = Color("#8a6a2a")
		brass.metallic = 0.8
		brass.roughness = 0.35
		brass.emission_enabled = true
		brass.emission = Color("#3a2608")
		bell.material_override = brass
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
		page.position = _w(np) + Vector3(0, 1.1, 0)
		page.rotation.y = randf() * TAU
		add_child(page)
		tile_mats[Vector2i(-200 - np.x, -200 - np.y)] = pm2
		tile_base[Vector2i(-200 - np.x, -200 - np.y)] = pm2.albedo_color
		letter_mats[np] = pm2

	# oil flasks on the floor: small amber glass that catches the lantern
	for op: Vector2i in room.oil_flasks:
		var flask := MeshInstance3D.new()
		var fm2 := CylinderMesh.new()
		fm2.top_radius = 0.04
		fm2.bottom_radius = 0.08
		fm2.height = 0.22
		flask.mesh = fm2
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color("#a8641c")
		gm.metallic_specular = 0.9
		gm.roughness = 0.15
		flask.material_override = gm
		flask.position = _w(op) + Vector3(0.15, 0.11, 0.1)
		add_child(flask)
		flask_nodes[op] = flask

	for thrall in game.thralls:
		var holder := Node3D.new()
		holder.position = _w(thrall.pos)
		var th := Sprite3D.new()
		th.texture = _tex("thrall")
		th.pixel_size = PX * 3.2         # up close they're big: ~2 tiles tall
		th.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		th.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		th.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		th.shaded = true
		th.offset = Vector2(0, th.texture.get_height() / 2.0)
		th.modulate = Color(0.6, 0.62, 0.7)
		holder.add_child(th)
		add_child(holder)
		thrall_nodes.append(holder)

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.05
	# The HUD covers the top 72 px and bottom 330 px, so centre the view on the strip
	# between them: a frustum camera with its centre shifted up.
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.size = 2.0 * cam.near * tan(deg_to_rad(FOV / 2.0))
	var full_h := cam.size * 960.0 / UI_W
	var mid := (TOP_H + (960.0 - BOTTOM_H)) / 2.0
	cam.frustum_offset = Vector2(0, -full_h * (480.0 - mid) / 960.0)
	add_child(cam)

	# her hand and lantern, low right, riding with the camera
	hand = Node3D.new()
	hand.position = Vector3(HAND_X, HAND_Y, -0.55)
	cam.add_child(hand)
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
	for i in thrall_nodes.size():
		thrall_nodes[i].position = _w(game.thralls[i].pos)
	_refresh_hud()


func _refresh_fog() -> void:
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
		thrall_nodes[i].visible = fog.get_state(game.thralls[i].pos) == Fog.LIT
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


# ---------------------------------------------------------------- actions

## One action = one turn. The camera glides to the new pose while the thralls glide too.
func act(kind: String) -> void:
	if busy or game.over():
		return
	busy = true
	last_event = ""
	var from_pos := cam.position
	var from_yaw := cam.rotation.y
	var from_t: Array = game.positions()
	var events: Array = []
	match kind:
		"forward": events = game.step_dir(game.facing)
		"back": events = game.step_dir(-game.facing)
		"left": events = game.turn_by(-1)
		"right": events = game.turn_by(1)
		"wait": events = game.wait()
	if events.is_empty() and not game.over() and kind in ["forward", "back"]:
		busy = false          # bumped a wall (or a thrall you can see): no turn spent
		last_event = "blocked"
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


## A swipe in UI pixels. Mostly vertical: step; mostly sideways: turn the way the finger went.
func swipe(d: Vector2) -> void:
	if absf(d.y) >= absf(d.x):
		act("forward" if d.y < 0 else "back")
	else:
		act("right" if d.x > 0 else "left")


func _set_lantern(s: int) -> void:
	if game.over():
		return
	game.set_lantern(s)
	last_event = ""
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var press: bool = event is InputEventScreenTouch and event.pressed
	press = press or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if press and game.over() and end_screen and end_screen.visible:
		get_tree().reload_current_scene()
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
			KEY_1: _set_lantern(Fog.Lantern.HOODED)
			KEY_2: _set_lantern(Fog.Lantern.NORMAL)
			KEY_3: _set_lantern(Fog.Lantern.BRIGHT)


func _process(delta: float) -> void:
	t += delta
	if busy:
		pass
	var eff: int = game.effective()
	if eff == Fog.Lantern.HOODED:
		return
	var base: float = LIGHT[eff][1]
	var wobble := sin(t * 7.0) * 0.05 + sin(t * 13.0) * 0.04
	if (flicker or fake_flicker) and fmod(t, 1.1) < 0.18:
		wobble -= 0.6 * absf(sin(t * 60.0))
	light.light_energy = base + wobble
	hand.position.y = HAND_Y + sin(t * 2.1) * 0.006   # the hand isn't quite steady


# ---------------------------------------------------------------- HUD

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, pos: Vector2, size: Vector2, cb: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 17)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)

	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.01, 0.015, 0.03, 0.9))
	g.add_point(0.5, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.0, 0.42)
	var vig := TextureRect.new()
	vig.texture = gt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vig)

	var top := ColorRect.new()
	top.color = INK_BLACK
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.size.y = TOP_H
	hud.add_child(top)
	var title := _label("ONE NIGHT  ·  THE BELL TOWER", 16, UI_TEXT)
	title.position = Vector2(14, 8)
	top.add_child(title)
	letters_label = _label("", 14, UI_DIM)
	letters_label.position = Vector2(290, 10)
	top.add_child(letters_label)
	var sw := _button("TOP-DOWN", Vector2(UI_W - 124, 6), Vector2(110, 26),
		func(): get_tree().change_scene_to_file("res://scenes/room3d.tscn"), top)
	sw.add_theme_font_size_override("font_size", 13)
	top.add_child(_label("OIL", 16, UI_AMBER))
	top.get_child(-1).position = Vector2(14, 36)
	for i in Night.START_OIL:
		var pip := ColorRect.new()
		pip.position = Vector2(58 + i * 8, 44)
		pip.size = Vector2(5, 14)
		top.add_child(pip)
		oil_pips.append(pip)
	oil_count = _label("", 16, UI_AMBER)
	oil_count.position = Vector2(58 + Night.START_OIL * 8 + 6, 36)
	top.add_child(oil_count)
	dread_label = _label("DREAD", 16, UI_DIM)
	dread_label.position = Vector2(352, 36)
	top.add_child(dread_label)
	var track := ColorRect.new()
	track.color = Color(0.12, 0.14, 0.2)
	track.position = Vector2(420, 45)
	track.size = Vector2(104, 12)
	top.add_child(track)
	dread_fill = ColorRect.new()
	dread_fill.color = UI_BLOOD
	dread_fill.position = Vector2(420, 45)
	dread_fill.size = Vector2(0, 12)
	top.add_child(dread_fill)

	# corner map: what you remember, drawn small. North is up; the arrow is you.
	minimap = Control.new()
	minimap.size = Vector2(room.size) * MAP_CELL
	minimap.position = Vector2(UI_W - 14 - minimap.size.x, TOP_H + 10)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_map)
	hud.add_child(minimap)

	var bottom := ColorRect.new()
	bottom.color = INK_BLACK
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM_H
	hud.add_child(bottom)
	status_label = _label("", 15, UI_DIM)
	status_label.position = Vector2(14, 8)
	status_label.size = Vector2(UI_W - 28, 44)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	bottom.add_child(status_label)
	var names := {Fog.Lantern.HOODED: "HOODED", Fog.Lantern.NORMAL: "NORMAL", Fog.Lantern.BRIGHT: "BRIGHT"}
	var x := 14
	for s in [Fog.Lantern.HOODED, Fog.Lantern.NORMAL, Fog.Lantern.BRIGHT]:
		lantern_buttons[s] = _button(names[s], Vector2(x, 58), Vector2(162, 52), _set_lantern.bind(s), bottom)
		x += 174
	# move pad: turn left / forward / turn right, then wait / back
	move_buttons["left"] = _button("TURN L", Vector2(14, 122), Vector2(162, 92), act.bind("left"), bottom)
	move_buttons["forward"] = _button("FORWARD", Vector2(188, 122), Vector2(162, 92), act.bind("forward"), bottom)
	move_buttons["right"] = _button("TURN R", Vector2(362, 122), Vector2(162, 92), act.bind("right"), bottom)
	move_buttons["wait"] = _button("WAIT", Vector2(14, 224), Vector2(162, 92), act.bind("wait"), bottom)
	move_buttons["back"] = _button("BACK", Vector2(188, 224), Vector2(162, 92), act.bind("back"), bottom)


## Remembered floor dim, lit floor amber, walls you've seen grey; thralls only if lit now.
func _draw_map() -> void:
	var c := MAP_CELL
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color(0, 0, 0, 0.55))
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
				minimap.draw_circle((Vector2(p) + Vector2(0.5, 0.5)) * c, c * 0.4, UI_AMBER)
			elif room.letters.has(p) and not game.letters_read.has(p):
				minimap.draw_rect(Rect2(Vector2(p) * c + Vector2(2, 1.5), Vector2(c - 4, c - 3)), UI_TEXT)
			elif game.flasks_left.has(p):
				minimap.draw_rect(Rect2(Vector2(p) * c + Vector2(2.5, 2.5), Vector2(c - 5, c - 5)), LANTERN)
	for th in game.thralls:
		if fog.get_state(th.pos) == Fog.LIT:
			minimap.draw_rect(Rect2(Vector2(th.pos) * c + Vector2(2, 2), Vector2(c - 4, c - 4)), UI_BLOOD)
		elif th.last_seen != null:
			# last-seen marker: where you saw it, not where it is. It may have moved.
			var m: Vector2 = Vector2(th.last_seen) * c
			var dim := Color(UI_BLOOD, 0.55)
			minimap.draw_line(m + Vector2(2, 2), m + Vector2(c - 2, c - 2), dim, 1.5)
			minimap.draw_line(m + Vector2(c - 2, 2), m + Vector2(2, c - 2), dim, 1.5)
	var ctr := (Vector2(game.hunter) + Vector2(0.5, 0.5)) * c
	var f := Vector2(game.facing)
	var side := Vector2(-f.y, f.x)
	minimap.draw_colored_polygon(PackedVector2Array([ctr + f * 4.5, ctr - f * 3 + side * 3.5, ctr - f * 3 - side * 3.5]), UI_TEXT)


func _refresh_hud() -> void:
	oil_count.text = str(game.oil)
	letters_label.text = "LETTERS %d/%d" % [game.letters_read.size(), room.letters.size()]
	for i in oil_pips.size():
		oil_pips[i].color = UI_AMBER if i < game.oil else Color(0.2, 0.25, 0.32)
	dread_fill.size.x = 104.0 * game.dread / Night.DREAD_MAX
	dread_label.add_theme_color_override("font_color", UI_BLOOD if game.hallucinating() else UI_DIM)
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
		"oil": "A flask, still corked. The lantern drinks.",
		"letter": "A letter, nailed to the post. You read it by the high flame.",
		"letter_dim": "Words on a page. Too dim to read. Burn brighter.",
		"rang": "The bell.",
	}
	var s: String = lines[game.setting]
	if game.oil == 0:
		s = "The oil is spent. The dark is coming in."
	var extra: String = said.get(last_event, "")
	if extra != "":
		s = extra
	elif flicker or fake_flicker:
		s = "The flame gutters. Something is near."
	if game.turn == 0 and extra == "":
		s += "  Turning costs a turn too."
	status_label.text = s
	for k in lantern_buttons:
		lantern_buttons[k].modulate = Color(1, 0.85, 0.5) if k == game.setting else Color(0.55, 0.6, 0.7)
	if minimap:
		minimap.queue_redraw()


func _show_end() -> void:
	if end_screen == null:
		end_screen = ColorRect.new()
		end_screen.color = Color(0.01, 0.01, 0.02, 0.84)
		end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		end_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(end_screen)
		var big := _label("", 34, UI_BLOOD)
		big.name = "Big"
		big.position = Vector2(30, 330)
		big.size = Vector2(UI_W - 60, 50)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		end_screen.add_child(big)
		var small := _label("", 17, UI_TEXT)
		small.name = "Small"
		small.position = Vector2(40, 400)
		small.size = Vector2(UI_W - 80, 200)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.autowrap_mode = TextServer.AUTOWRAP_WORD
		end_screen.add_child(small)
	var big: Label = end_screen.get_node("Big")
	var small: Label = end_screen.get_node("Small")
	if game.rang:
		big.text = "THE BELL RINGS  ·  %s" % game.grade()
		big.add_theme_color_override("font_color", UI_AMBER)
		small.text = "It rolls out over the drowned quay, and every door in the town hears it.\n\n%d oil left  ·  %d of %d letters read  ·  %d turns\nScore %d\n\nTap to walk the night again." % [game.oil, game.letters_read.size(), room.letters.size(), game.turn, game.points()]
	elif game.escaped:
		big.text = "DAWN"
		big.add_theme_color_override("font_color", UI_AMBER)
		small.text = "You reach the water's edge as the sky goes grey.\n\n%d turns  ·  %d oil left\n\nTap to walk the night again." % [game.turn, game.oil]
	else:
		big.text = "THE DARK TOOK YOU"
		small.text = "%s\n\n%d turns  ·  %d oil left\n\nTap to try again." % [game.cause, game.turn, game.oil]
	end_screen.visible = true


# ---------------------------------------------------------------- capture + button test

func _shot(name: String) -> void:
	t = 0.3
	for i in 10:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/renders/" + name + ".png"))
	print("saved ", name, " ", img.get_size())


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
		var reach: Dictionary = room.reachable(game.hunter, 999)
		var path: Array = room.path_in(reach, game.hunter, goal)
		if path.size() < 2:
			return "no_path"
		var d: Vector2i = path[1] - game.hunter
		if game.facing == d:
			await _press(move_buttons["forward"])
		else:
			var right := Vector2i(-game.facing.y, game.facing.x)
			await _press(move_buttons["right" if d == right else "left"])
		if last_event in stop_on:
			return last_event
	return "gave_up"


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
		await _shot("fp_start")
		var at: Vector2i = game.hunter
		await _press(move_buttons["forward"])
		print("FWD ", "PASS" if game.hunter == at + Vector2i.UP and game.turn == 1 else "FAIL", " hunter=", game.hunter)
		await _press(move_buttons["right"])
		print("TURN ", "PASS" if game.facing == Vector2i.RIGHT and game.turn == 2 else "FAIL", " facing=", game.facing)
		var turn_before: int = game.turn
		await _swipe_real(Vector2(380, 420), Vector2(240, 430))   # a finger dragged left = turn left
		print("SWIPE ", "PASS" if game.facing == Vector2i.UP and game.turn == turn_before + 1 else "FAIL", " facing=", game.facing)
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
	var letter: Vector2i = room.letters.reduce(func(a, b): return a if (a - game.hunter).length() < (b - game.hunter).length() else b)
	var reach: Dictionary = room.reachable(game.hunter, 999)
	var path: Array = room.path_in(reach, game.hunter, letter)
	await _walk_to(path[path.size() - 2])
	await _press(lantern_buttons[Fog.Lantern.BRIGHT])
	await _walk_to(letter, ["letter"])
	await _shot("fp_letter")
	print("LETTER ", "PASS" if game.letters_read.size() == 1 else "FAIL", " at=", letter)
	await _press(lantern_buttons[Fog.Lantern.HOODED])
	await _shot("fp_hooded")
	for i in 6:
		if game.over():
			break
		await _walk_to(game.thralls[2].pos)   # blind, into the dark where it stands
	await _shot("fp_dead")
	print("DEATH ", "PASS" if game.dead else "FAIL", " ", game.cause)
	get_tree().quit()
