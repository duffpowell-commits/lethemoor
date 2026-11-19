extends Node3D
## The playable room in 3D (M1a, Nov 12). HD-2D: pixel sprites as upright billboards in a
## 3D world, one real 3D lantern light. Compatibility renderer (runs in iPhone Safari).
## Rules live in scripts/sim/ (night.gd runs the turns: oil, dread, thralls). This file only
## draws them and turns taps into steps. Fog is the truth; the light is the look.
## M1b (Nov 13): one tile per turn. Tap a tile and she walks there step by step, every step a
## turn; she stops early when something happens. Tap her own tile to wait a turn.
## 1 grid tile = 1 world unit. Grid (x, y) sits at world (x, 0, y): rows run toward the camera.
## Renders + tap test:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/room3d.tscn -- --capture
##   -> docs/renders/m1a_*.png

const Fog = preload("res://scripts/sim/fog.gd")
const Room = preload("res://scripts/sim/room.gd")
const Night = preload("res://scripts/sim/night.gd")

const UI_W := 540                  # UI base, portrait (pivot doc: 540x960)
const UI_H := 960
const TOP_H := 72
const BOTTOM_H := 216              # thumb zone: status line + three big lantern buttons
const WALL_H := 1.35
const PX := 1.0 / 48.0             # sprite pixel size: a 64 px bearer is 1.33 tiles tall
const STEP_TIME := 0.16            # seconds per tile while sliding
const SPRITE := "canva_bearer64"
const LANTERN_PX := Vector2(42, 44)  # flame pixel in the 64x64 frame (from the _glow image)

const LANTERN := Color("#ff9a3c")
const DEEP := Color("#0d1420")
const MOON := Color("#6f8fc4")
const INK_BLACK := Color("#05070c")
const UI_TEXT := Color("#d9cdb4")
const UI_AMBER := Color("#f2c25a")
const UI_DIM := Color("#7d8fa8")
const UI_BLOOD := Color("#c81e2e")
## How bright each fog state draws a surface. The light adds on top of LIT.
const SHADE := {Fog.DARK: 0.0, Fog.REMEMBERED: 0.2, Fog.LIT: 1.0}
## Lantern light per setting: [range in tiles, energy]. Range ~ fog radius + a soft edge.
const LIGHT := {
	Fog.Lantern.HOODED: [0.9, 0.3],
	Fog.Lantern.NORMAL: [3.2, 3.2],
	Fog.Lantern.BRIGHT: [5.4, 4.2],
}

var game                           # sim/night.gd: the truth
var room
var fog
var hunter := Vector2i.ZERO        # mirrors game.hunter (kept for the tap test)
var night := 1
var flicker := false
var fake_flicker := false          # high dread: the flame lies
var last_event := ""
var facing := 1                    # 1 = lantern on the right, -1 = flipped
var walking := false
var t := 0.0

var cam: Camera3D
var light: OmniLight3D
var bearer: Sprite3D
var flame: Sprite3D
var tile_mats := {}                # Vector2i -> StandardMaterial3D (floor and walls)
var tile_base := {}                # Vector2i -> base albedo Color
var reach_marks := {}              # Vector2i -> MeshInstance3D
var thrall_nodes: Array = []       # index matches game.thralls

var hud: Control
var status_label: Label
var oil_pips: Array[ColorRect] = []
var oil_count: Label
var dread_fill: ColorRect
var dread_label: Label
var buttons := {}
var end_screen: Control


func _ready() -> void:
	game = Night.start(FileAccess.get_file_as_string("res://rooms/quay_01.txt"))
	room = game.room
	fog = game.fog
	hunter = game.hunter
	_build_world()
	_build_hud()
	_refresh()
	_place_bearer(Vector3(hunter.x, 0, hunter.y))
	_place_camera(true)
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _tex(name: String) -> Texture2D:
	return load("res://assets/art/%s.png" % name)


func _w(p: Vector2i) -> Vector3:
	return Vector3(p.x, 0, p.y)


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#03050a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = DEEP
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color("#0e1520")
	env.fog_density = 0.018
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = MOON
	moon.light_energy = 0.22
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
			m.metallic_specular = 0.2   # damp stone; a full highlight reads as a second light
			if room.is_wall(p):
				mi.mesh = wall_mesh
				mi.position = _w(p) + Vector3(0, WALL_H / 2.0, 0)
				m.albedo_texture = _tex("wall_face_%d" % ((x + y) % 2))
				m.roughness = 0.9
				tile_base[p] = Color(0.9, 0.85, 0.95)
			else:
				mi.mesh = floor_mesh
				mi.position = _w(p) + Vector3(0, -0.1, 0)
				var is_exit: bool = p in room.exits
				m.albedo_texture = _tex("exit" if is_exit else "floor_%d" % ((x * 7 + y * 13) % 4))
				m.roughness = 0.8
				tile_base[p] = Color(1, 1, 1)
				_add_reach_mark(p)
			mi.material_override = m
			add_child(mi)
			tile_mats[p] = m

	# dead street lamps: iron posts waiting to be relit
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#20242c")
	for lp: Vector2i in room.lamps:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.12, 2.2, 0.12)
		post.mesh = pm
		post.position = _w(lp) + Vector3(0, 1.1, 0)
		post.material_override = iron.duplicate()
		add_child(post)
		tile_mats[Vector2i(-100 - lp.x, -100 - lp.y)] = post.material_override  # fogged with its tile
		tile_base[Vector2i(-100 - lp.x, -100 - lp.y)] = iron.albedo_color

	for thrall in game.thralls:
		var tp: Vector2i = thrall.pos
		var holder := Node3D.new()
		holder.position = _w(tp)
		var th := _billboard("thrall")
		th.pixel_size = PX * 1.6
		th.modulate = Color(0.6, 0.62, 0.7)
		holder.add_child(th)
		# eyes catch the lantern: unshaded red pinpricks (only drawn when the thrall is LIT)
		for ex in [-0.07, 0.07]:
			var eye := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.05, 0.05)
			eye.mesh = q
			var em := StandardMaterial3D.new()
			em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			em.albedo_color = Color("#c81e2e") * 2.4
			em.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			eye.material_override = em
			eye.position = Vector3(ex, 1.05, 0.05)
			holder.add_child(eye)
		add_child(holder)
		thrall_nodes.append(holder)

	bearer = _billboard(SPRITE)
	add_child(bearer)
	flame = _billboard(SPRITE + "_glow")
	flame.shaded = false
	flame.modulate = Color(2.2, 1.7, 1.1)   # over the glow threshold: it blooms
	add_child(flame)

	light = OmniLight3D.new()
	light.light_color = LANTERN
	light.shadow_enabled = true
	light.omni_attenuation = 1.0
	add_child(light)

	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)


func _billboard(tex_name: String) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _tex(tex_name)
	s.pixel_size = PX
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.offset = Vector2(0, s.texture.get_height() / 2.0)   # feet on the ground
	return s


func _add_reach_mark(p: Vector2i) -> void:
	var mark := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.86, 0.86)
	mark.mesh = q
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(1.0, 0.75, 0.35, 0.10)
	mark.material_override = mm
	mark.position = _w(p) + Vector3(0, 0.01, 0)
	mark.visible = false
	add_child(mark)
	reach_marks[p] = mark


## Bearer, flame and light all hang off one ground point; facing flips the lantern side.
func _place_bearer(at: Vector3) -> void:
	bearer.position = at
	bearer.flip_h = facing < 0
	flame.position = at + Vector3(0, 0, 0.01)
	flame.flip_h = facing < 0
	var lx := (LANTERN_PX.x - 32.0) * PX * facing
	var ly := (64.0 - LANTERN_PX.y) * PX
	light.position = at + Vector3(lx, ly + 0.15, 0.3)


## High, tilted, long-ish lens; the hunter sits a little below the middle of the room area.
func _place_camera(snap: bool) -> void:
	var target := bearer.position + Vector3(0, 0.4, -1.6)
	var want := target + Vector3(0, 10.5, 8.0)
	if snap:
		cam.position = want
	else:
		cam.position = cam.position.lerp(want, 0.12)
	cam.look_at(cam.position + (target - want))


# ---------------------------------------------------------------- rules -> look

func _seen_thralls() -> Array:
	return game.positions().filter(func(p): return fog.get_state(p) == Fog.LIT)


func _refresh() -> void:
	hunter = game.hunter
	flicker = game.flickers()
	fake_flicker = game.hallucinating() and not flicker and randf() < 0.35
	for p in tile_mats:
		var gp: Vector2i = p if p.x > -100 else Vector2i(-100 - p.x, -100 - p.y)
		var k: float = SHADE[fog.get_state(gp)]
		var base: Color = tile_base[p]
		tile_mats[p].albedo_color = Color(base.r * k, base.g * k, base.b * k)
	for p in reach_marks:
		reach_marks[p].visible = not walking and game.can_step(p) and fog.get_state(p) != Fog.DARK
	for i in thrall_nodes.size():
		var tp: Vector2i = game.thralls[i].pos
		thrall_nodes[i].visible = fog.get_state(tp) == Fog.LIT
		if not walking:
			thrall_nodes[i].position = _w(tp)
	var eff: int = game.effective()
	var lv: Array = LIGHT[eff]
	light.omni_range = lv[0]
	light.light_energy = lv[1]
	flame.visible = eff != Fog.Lantern.HOODED
	bearer.modulate = Color(0.6, 0.65, 0.8) if eff == Fog.Lantern.HOODED else Color(1, 1, 1)
	_refresh_hud()


# ---------------------------------------------------------------- input

## Grid tile under a screen point: ray from the camera onto the floor plane (y = 0).
func cell_at(screen: Vector2) -> Vector2i:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector2i(-1, -1)
	var hit := o + d * (-o.y / d.y)
	return Vector2i(roundi(hit.x), roundi(hit.z))


## Screen point over a grid tile's centre (used by the tap test).
func screen_of(p: Vector2i) -> Vector2:
	return cam.unproject_position(_w(p))


func _unhandled_input(event: InputEvent) -> void:
	var press: bool = event is InputEventScreenTouch and event.pressed
	press = press or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not press:
		return
	if game.over():
		if end_screen and end_screen.visible:
			get_tree().reload_current_scene()
		return
	if walking:
		return
	try_move(cell_at(event.position))


## Tap your own tile: wait a turn. Tap any known floor tile: walk there, one turn per tile.
func try_move(cell: Vector2i) -> bool:
	if walking or game.over():
		return false
	if cell == hunter:
		_walk_path([hunter, hunter])
		return true
	if room.is_wall(cell) or fog.get_state(cell) == Fog.DARK:
		return false
	var reach: Dictionary = room.reachable(hunter, room.size.x * room.size.y, _seen_thralls())
	var path: Array = room.path_in(reach, hunter, cell)
	if path.size() < 2:
		return false
	_walk_path(path)
	return true


## Events that stop a walk: something changed, the player should get to choose again.
const STOP_EVENTS := ["horror", "panic", "out_of_oil", "taken", "grabbed", "escaped"]


## Each tile is one turn of the sim. The hunter slides, thralls slide with her; the walk stops
## the moment anything happens (a horror, a panic, a new flicker, death).
func _walk_path(path: Array) -> void:
	walking = true
	last_event = ""
	for m in reach_marks.values():
		m.visible = false
	for i in range(1, path.size()):
		var was_flicker: bool = game.flickers()
		var from_t: Array = game.positions()
		var a := _w(path[i - 1])
		var b := _w(path[i])
		var events: Array = game.wait() if path[i] == path[i - 1] else game.step(path[i])
		if path[i] != path[i - 1] and events.is_empty() and not game.dead:
			break   # step refused (it became illegal): stop here
		if path[i].x != path[i - 1].x:
			facing = signi(path[i].x - path[i - 1].x)
		if game.hunter != path[i]:
			b = a   # grabbed before she got there
		_refresh_fog_only()
		var e := 0.0
		while e < STEP_TIME:
			e += get_process_delta_time()
			var k := minf(e / STEP_TIME, 1.0)
			var bob := 0.04 if k < 0.5 and a != b else 0.0
			_place_bearer(a.lerp(b, k) + Vector3(0, bob, 0))
			for j in thrall_nodes.size():
				thrall_nodes[j].position = _w(from_t[j]).lerp(_w(game.thralls[j].pos), k)
			await get_tree().process_frame
		for ev in events:   # the line under the screen names the thing that matters most
			if ev in STOP_EVENTS or last_event not in STOP_EVENTS:
				last_event = ev
		if game.over() or events.any(func(ev): return ev in STOP_EVENTS):
			break
		if game.flickers() and not was_flicker:
			last_event = "flicker"
			break
	walking = false
	_refresh()
	if game.over():
		_show_end()


## Mid-walk: fog and thrall visibility follow every step, the HUD waits for the stop.
func _refresh_fog_only() -> void:
	for p in tile_mats:
		var gp: Vector2i = p if p.x > -100 else Vector2i(-100 - p.x, -100 - p.y)
		var k: float = SHADE[fog.get_state(gp)]
		var base: Color = tile_base[p]
		tile_mats[p].albedo_color = Color(base.r * k, base.g * k, base.b * k)
	for i in thrall_nodes.size():
		thrall_nodes[i].visible = fog.get_state(game.thralls[i].pos) == Fog.LIT
	var eff: int = game.effective()
	light.omni_range = LIGHT[eff][0]
	flame.visible = eff != Fog.Lantern.HOODED
	_refresh_hud()


func _set_lantern(s: int) -> void:
	if game.over():
		return
	game.set_lantern(s)
	last_event = ""
	_refresh()


func _process(delta: float) -> void:
	t += delta
	_place_camera(false)
	if game.effective() == Fog.Lantern.HOODED:
		return
	# a living flame breathes; something unseen nearby makes it stutter
	var base: float = LIGHT[game.effective()][1]
	var wobble := sin(t * 7.0) * 0.05 + sin(t * 13.0) * 0.04
	if (flicker or fake_flicker) and fmod(t, 1.1) < 0.18:
		wobble -= 0.6 * absf(sin(t * 60.0))
	light.light_energy = base + wobble


# ---------------------------------------------------------------- HUD

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)

	# vignette between the world and the bars: the "something is out there" frame
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.01, 0.015, 0.03, 0.85))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
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
	var title := _label("NIGHT %d  ·  THE DROWNED QUAY" % night, 16, UI_TEXT)
	title.position = Vector2(14, 8)
	top.add_child(title)
	var fp := Button.new()   # back to the main view (first person, Nov 19)
	fp.text = "FIRST PERSON"
	fp.position = Vector2(540 - 134, 6)
	fp.size = Vector2(120, 26)
	fp.add_theme_font_size_override("font_size", 13)
	fp.focus_mode = Control.FOCUS_NONE
	fp.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/fp_room.tscn"))
	top.add_child(fp)
	var oil_label := _label("OIL", 16, UI_AMBER)
	oil_label.position = Vector2(14, 36)
	top.add_child(oil_label)
	# pips are drawn, not typed: the web build has no system fonts for symbols
	for i in Night.START_OIL:
		var pip := ColorRect.new()
		pip.position = Vector2(58 + i * 8, 44)
		pip.size = Vector2(5, 14)
		top.add_child(pip)
		oil_pips.append(pip)
	oil_count = _label("", 16, UI_AMBER)
	oil_count.position = Vector2(58 + Night.START_OIL * 8 + 6, 36)
	top.add_child(oil_count)
	# dread: the second clock. Fills in the dark, drains in the light.
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

	var bottom := ColorRect.new()
	bottom.color = INK_BLACK
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM_H
	hud.add_child(bottom)
	status_label = _label("", 15, UI_DIM)
	status_label.position = Vector2(14, 10)
	status_label.size = Vector2(UI_W - 28, 60)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	bottom.add_child(status_label)
	var names := {Fog.Lantern.HOODED: "HOODED", Fog.Lantern.NORMAL: "NORMAL", Fog.Lantern.BRIGHT: "BRIGHT"}
	var x := 14
	for s in [Fog.Lantern.HOODED, Fog.Lantern.NORMAL, Fog.Lantern.BRIGHT]:
		var b := Button.new()
		b.text = names[s]
		b.position = Vector2(x, 84)
		b.size = Vector2(162, 108)   # thumb-sized, bottom third
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_set_lantern.bind(s))
		bottom.add_child(b)
		buttons[s] = b
		x += 174


func _refresh_hud() -> void:
	oil_count.text = str(game.oil)
	for i in oil_pips.size():
		oil_pips[i].color = UI_AMBER if i < game.oil else Color(0.2, 0.25, 0.32)
	dread_fill.size.x = 104.0 * game.dread / Night.DREAD_MAX
	dread_label.add_theme_color_override("font_color", UI_BLOOD if game.hallucinating() else UI_DIM)
	var lines := {
		Fog.Lantern.HOODED: "Hooded. Unseen, and blind. The dark gets into you.",
		Fog.Lantern.NORMAL: "The lantern burns low: two paces of light. 1 oil a step.",
		Fog.Lantern.BRIGHT: "The flame burns high: four paces, and every eye turns to it. 2 oil a step.",
	}
	var said := {
		"horror": "Something stands at the edge of the light. It has seen you.",
		"panic": "Your hands shake. Oil spills hissing on the stones.",
		"out_of_oil": "The last of the oil is gone. The dark comes in.",
		"thrall_moved": "",
		"flicker": "The flame gutters. Something is near.",
	}
	var s: String = lines[game.setting]
	if game.oil == 0:
		s = "The oil is spent. The dark is coming in."
	var extra: String = said.get(last_event, "")
	if extra != "":
		s = extra
	elif flicker or fake_flicker:
		s += "  The flame gutters. Something is near."
	if game.hallucinating() and extra == "":
		s += "  You are not sure what you see."
	if not game.over() and extra == "" and game.turn == 0:
		s += "  Tap a tile to walk. Tap yourself to wait."
	status_label.text = s
	for k in buttons:
		buttons[k].modulate = Color(1, 0.85, 0.5) if k == game.setting else Color(0.55, 0.6, 0.7)


## Death or dawn. One tap and the night starts over.
func _show_end() -> void:
	if end_screen == null:
		end_screen = ColorRect.new()
		end_screen.color = Color(0.01, 0.01, 0.02, 0.82)
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
	if game.escaped:
		big.text = "DAWN"
		big.add_theme_color_override("font_color", UI_AMBER)
		small.text = "You reach the water's edge as the sky goes grey.\n\n%d steps  ·  %d oil left\n\nTap to walk the night again." % [game.turn, game.oil]
	else:
		big.text = "THE DARK TOOK YOU"
		small.text = "%s\n\n%d steps  ·  %d oil left\n\nTap to try again." % [game.cause, game.turn, game.oil]
	end_screen.visible = true


# ---------------------------------------------------------------- capture + tap test

func _shot(name: String) -> void:
	t = 0.3   # steady flame for the still
	for i in 10:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/renders/" + name + ".png"))
	print("saved ", name, " ", img.get_size())


## Real taps through the input system (screen -> ray -> tile -> path -> walk), then renders.
## Prints TAP PASS/FAIL so a broken tap mapping can't hide behind a nice picture.
func _tap(cell: Vector2i, should_move := true) -> void:
	var before := hunter
	for i in 30:   # let the camera settle on the hunter first
		await get_tree().process_frame
	# a finger lands in window pixels; the viewport maps those back to the 540x960 UI space
	var pos: Vector2 = get_viewport().get_final_transform() * screen_of(cell)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	for i in 120:
		await get_tree().process_frame
		if not walking and hunter == cell:
			break
	var ok: bool = (hunter == cell) if should_move else (hunter == before)
	print("TAP ", "PASS" if ok else "FAIL", " target=", cell, " move expected=", should_move,
		" screen=", pos, " hunter=", hunter)


## Let the sim run a few turns through the same code path a tap uses, and wait for it.
func _act(cell: Vector2i) -> void:
	try_move(cell)
	while walking:
		await get_tree().process_frame


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/renders/"))
	await _shot("m1b_start")
	var oil_before: int = game.oil
	await _tap(hunter + Vector2i(0, -1))   # one tile up: one turn
	print("STEP ", "PASS" if game.turn == 1 and game.oil == oil_before - 1 else "FAIL",
		" turn=", game.turn, " oil=", game.oil)
	await _tap(Vector2i(4, 9), false)        # a wall: she must NOT move
	_set_lantern(Fog.Lantern.BRIGHT)
	for i in 8:                              # bright: something out there sees it
		await _act(hunter)
		if last_event == "horror" or game.over():
			break
	await _shot("m1b_horror")
	print("HORROR ", "PASS" if last_event == "horror" else "FAIL", " dread=", game.dread)
	_set_lantern(Fog.Lantern.HOODED)
	await _act(hunter)
	await _act(hunter)
	await _shot("m1b_hooded")
	for i in 12:                             # hooding hides the light, not where you stood
		if game.over():
			break
		await _act(hunter)
	await _shot("m1b_dead")
	print("DEATH ", "PASS" if game.dead else "FAIL", " cause=", game.cause)
	get_tree().quit()
