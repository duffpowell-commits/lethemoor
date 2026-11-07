extends Node2D
## M0 room: one hunter, a lantern, fog of war, real 2D light and wall shadows.
## Pure rules live in scripts/sim/; this file only draws them and takes taps.
##
## Renders for review (saved to docs/renders/):
##   xvfb-run -a godot --path . --rendering-driver opengl3 -- --capture

const Fog = preload("res://scripts/sim/fog.gd")
const Room = preload("res://scripts/sim/room.gd")

const T := 32                      # tile size in pixels
const ROOM_ORIGIN := Vector2(0, 48)  # room sits under the top bar
const MOVE_RANGE := 4              # tiles per move (placeholder until the AP rules land)
const START_OIL := 12
const LIGHT_ENERGY := 2.4

# Amber and ink (see tools/gen_placeholder_art.py and the design doc).
const DARKNESS := Color("#0d1420")   # what unlit ground looks like (CanvasModulate)
const LANTERN := Color("#ffb347")
const INK_BLACK := Color("#05070c")
const REMEMBERED := Color(0.02, 0.03, 0.06, 0.62)
const UI_TEXT := Color("#d9cdb4")
const UI_AMBER := Color("#f2c25a")
const UI_DIM := Color("#4d6078")

var room
var fog
var hunter := Vector2i.ZERO
var setting: int = Fog.Lantern.NORMAL
var oil := START_OIL
var night := 1

var light: PointLight2D
var hunter_sprite: Sprite2D
var thrall_sprites := {}
var fog_sprite: Sprite2D
var fog_image: Image
var reach_layer: Node2D
var hud: Control
var oil_label: Label
var status_label: Label
var buttons := {}
var reach: Dictionary = {}
var flicker := false
var t := 0.0


func _ready() -> void:
	room = Room.parse(FileAccess.get_file_as_string("res://rooms/quay_01.txt"))
	fog = room.make_fog()
	hunter = room.hunter
	_build_world()
	_build_hud()
	_refresh()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


# ---------------------------------------------------------------- world

func _tex(name: String) -> Texture2D:
	return load("res://assets/art/%s.png" % name)


func _cell_pos(p: Vector2i) -> Vector2:
	return ROOM_ORIGIN + Vector2(p * T) + Vector2(T, T) * 0.5


func _build_world() -> void:
	var dark := CanvasModulate.new()
	dark.color = DARKNESS
	add_child(dark)

	var tiles := Node2D.new()
	add_child(tiles)
	var floors := ["floor_0", "floor_1", "floor_2", "floor_3"]
	for y in room.size.y:
		for x in room.size.x:
			var p := Vector2i(x, y)
			var s := Sprite2D.new()
			s.position = _cell_pos(p)
			if room.is_wall(p):
				var below_open: bool = not room.is_wall(p + Vector2i.DOWN) and y + 1 < room.size.y
				s.texture = _tex("wall_face_%d" % ((x + y) % 2) if below_open else "wall_top")
				var occ := LightOccluder2D.new()
				var poly := OccluderPolygon2D.new()
				var h := T * 0.5
				poly.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
				occ.occluder = poly
				s.add_child(occ)
			elif p in room.exits:
				s.texture = _tex("exit")
			else:
				s.texture = _tex(floors[(x * 7 + y * 13) % 4])
			tiles.add_child(s)

	for lp in room.lamps:
		var l := Sprite2D.new()
		l.texture = _tex("lamp")
		l.position = _cell_pos(lp) + Vector2(0, -6)
		tiles.add_child(l)

	reach_layer = Node2D.new()
	reach_layer.draw.connect(_draw_reach)
	add_child(reach_layer)

	for tp in room.thralls:
		var s := Sprite2D.new()
		s.texture = _tex("thrall")
		s.position = _cell_pos(tp) + Vector2(0, -4)
		add_child(s)
		thrall_sprites[tp] = s

	hunter_sprite = Sprite2D.new()
	hunter_sprite.texture = _tex("hunter")
	hunter_sprite.position = _cell_pos(hunter) + Vector2(0, -4)
	add_child(hunter_sprite)

	light = PointLight2D.new()
	light.texture = _light_texture()
	light.color = LANTERN
	light.shadow_enabled = true
	light.shadow_color = Color(0, 0, 0, 1)
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.offset = Vector2(8, 4)  # the lantern is in his right hand
	hunter_sprite.add_child(light)

	# Fog sits above the lit world and ignores light: dark means you know nothing.
	# One pixel per tile, smoothed by linear filtering, so the edge of sight is soft, not blocky.
	fog_image = Image.create(room.size.x, room.size.y, false, Image.FORMAT_RGBA8)
	fog_sprite = Sprite2D.new()
	fog_sprite.centered = false
	fog_sprite.position = ROOM_ORIGIN
	fog_sprite.scale = Vector2(T, T)
	fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fog_sprite.material = mat
	add_child(fog_sprite)
	# You always see yourself, even hooded.
	var self_mat := CanvasItemMaterial.new()
	self_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	hunter_sprite.material = self_mat


func _light_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.8))
	g.add_point(0.7, Color(1, 1, 1, 0.22))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _paint_fog() -> void:
	for y in room.size.y:
		for x in room.size.x:
			var c := Color(0, 0, 0, 0)
			match fog.get_state(Vector2i(x, y)):
				Fog.DARK: c = INK_BLACK
				Fog.REMEMBERED: c = REMEMBERED
			fog_image.set_pixel(x, y, c)
	if fog_sprite.texture == null:
		fog_sprite.texture = ImageTexture.create_from_image(fog_image)
	else:
		fog_sprite.texture.update(fog_image)


func _draw_reach() -> void:
	for p: Vector2i in reach:
		if p == hunter:
			continue
		# Small corner ticks, not filled boxes: the light should be the loudest thing on screen.
		var o := ROOM_ORIGIN + Vector2(p * T)
		var c := Color(1.0, 0.85, 0.55, 0.45)
		for corner in [Vector2(3, 3), Vector2(T - 6, 3), Vector2(3, T - 6), Vector2(T - 6, T - 6)]:
			reach_layer.draw_rect(Rect2(o + corner, Vector2(3, 3)), c)


# ---------------------------------------------------------------- rules glue

func _refresh() -> void:
	fog.update([{pos = hunter, setting = setting}])
	var radius: int = Fog.RADIUS[setting]
	# Light reaches a bit past the last lit tile so the edge falls off softly.
	light.texture_scale = ((radius + 0.9) * T * 2.0) / 256.0
	light.energy = 0.0 if setting == Fog.Lantern.HOODED else LIGHT_ENERGY
	for tp in thrall_sprites:
		thrall_sprites[tp].visible = fog.get_state(tp) == Fog.LIT
	flicker = fog.flickers(hunter, room.thralls)
	reach = _reachable(hunter, MOVE_RANGE)
	hunter_sprite.position = _cell_pos(hunter) + Vector2(0, -4)
	_paint_fog()
	hunter_sprite.modulate = Color(0.55, 0.6, 0.75) if setting == Fog.Lantern.HOODED else Color(0.85, 0.75, 0.6)
	reach_layer.queue_redraw()
	_refresh_hud()


## Floor tiles within `steps` (4-way), not through walls or enemies you can see.
func _reachable(from: Vector2i, steps: int) -> Dictionary:
	var seen := {from: 0}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if seen[c] >= steps:
			continue
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if seen.has(n) or room.is_wall(n) or n in room.thralls:
				continue
			seen[n] = seen[c] + 1
			q.append(n)
	return seen


func _unhandled_input(event: InputEvent) -> void:
	var press: bool = event is InputEventScreenTouch and event.pressed
	press = press or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not press:
		return
	var cell := Vector2i(((event.position - ROOM_ORIGIN) / T).floor())
	if reach.has(cell) and cell != hunter:
		hunter = cell
		oil = Fog.burn(oil, setting)
		_refresh()


func _set_lantern(s: int) -> void:
	setting = s
	_refresh()


func _process(delta: float) -> void:
	t += delta
	if setting == Fog.Lantern.HOODED:
		return
	# A living flame breathes a little; something unseen nearby makes it stutter.
	var base := LIGHT_ENERGY
	var wobble := sin(t * 7.0) * 0.04 + sin(t * 13.0) * 0.03
	if flicker and fmod(t, 1.1) < 0.18:
		wobble -= 0.55 * absf(sin(t * 60.0))
	light.energy = base + wobble


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

	var top := ColorRect.new()
	top.color = INK_BLACK
	top.position = Vector2.ZERO
	top.size = Vector2(360, 48)
	hud.add_child(top)
	var title := _label("NIGHT %d  ·  THE DROWNED QUAY" % night, 11, UI_TEXT)
	title.position = Vector2(10, 6)
	hud.add_child(title)
	oil_label = _label("", 11, UI_AMBER)
	oil_label.position = Vector2(10, 24)
	hud.add_child(oil_label)

	var bottom := ColorRect.new()
	bottom.color = INK_BLACK
	bottom.position = Vector2(0, 496)
	bottom.size = Vector2(360, 144)
	hud.add_child(bottom)
	status_label = _label("", 10, UI_DIM)
	status_label.position = Vector2(10, 502)
	status_label.size = Vector2(340, 30)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud.add_child(status_label)

	var names := {Fog.Lantern.HOODED: "HOODED", Fog.Lantern.NORMAL: "NORMAL", Fog.Lantern.BRIGHT: "BRIGHT"}
	var x := 10
	for s in [Fog.Lantern.HOODED, Fog.Lantern.NORMAL, Fog.Lantern.BRIGHT]:
		var b := Button.new()
		b.text = names[s]
		b.position = Vector2(x, 548)
		b.size = Vector2(108, 72)  # thumb-sized: bottom third, big targets
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_set_lantern.bind(s))
		hud.add_child(b)
		buttons[s] = b
		x += 116


func _refresh_hud() -> void:
	var pips := ""
	for i in START_OIL:
		pips += "■" if i < oil else "□"
	oil_label.text = "OIL  %s  %d" % [pips, oil]
	var cost: int = Fog.OIL_COST[setting]
	var lines := {
		Fog.Lantern.HOODED: "Hooded. Unseen, and blind. Burns nothing.",
		Fog.Lantern.NORMAL: "The lantern burns low: two paces of light. 1 oil a move.",
		Fog.Lantern.BRIGHT: "The flame burns high: four paces, and every eye turns to it. %d oil a move." % cost,
	}
	var s: String = lines[setting]
	if flicker:
		s += "  The flame gutters. Something is near."
	if oil == 0:
		s = "The oil is spent. The dark is coming in."
	status_label.text = s
	for k in buttons:
		var on: bool = k == setting
		buttons[k].modulate = Color(1, 0.85, 0.5) if on else Color(0.55, 0.6, 0.7)


# ---------------------------------------------------------------- capture

## Saves review renders: each lantern setting, then a walk so remembered tiles show.
func _capture() -> void:
	var out := "res://docs/renders/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var shots := [
		["m0_normal", Fog.Lantern.NORMAL, room.hunter],
		["m0_bright", Fog.Lantern.BRIGHT, room.hunter],
		["m0_hooded", Fog.Lantern.HOODED, room.hunter],
		["m0_walked_bright", Fog.Lantern.BRIGHT, Vector2i(7, 8)],
		["m0_walked_far", Fog.Lantern.NORMAL, Vector2i(4, 3)],
	]
	for s in shots:
		setting = s[1]
		hunter = s[2]
		_refresh()
		t = 0.3  # a steady flame for the still
		for i in 6:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(ProjectSettings.globalize_path(out + s[0] + ".png"))
		print("saved ", s[0])
	get_tree().quit()
