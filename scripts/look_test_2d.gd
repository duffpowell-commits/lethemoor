extends Node2D
## Look test, flat 2D: 48 px tiles, 64 px character, 540x960, Godot 2D lights + wall shadows.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1080x1920 res://scenes/look_test_2d.tscn -- --capture

const C = preload("res://scripts/look_test_common.gd")
const TILE := 48
const ORIGIN := Vector2(6, 120)

var room: RefCounted


func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i(540, 960)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	RenderingServer.set_default_clear_color(Color(0.01, 0.01, 0.02))
	room = C.load_room()
	_build()
	if "--capture" in OS.get_cmdline_user_args():
		C.capture(self, C.tag_arg("2d"))


func _cell(p: Vector2i) -> Vector2:
	return ORIGIN + Vector2(p) * TILE


func _build() -> void:
	var dark := CanvasModulate.new()
	dark.color = Color(0.07, 0.07, 0.12)
	add_child(dark)

	for y in room.size.y:
		for x in room.size.x:
			var p := Vector2i(x, y)
			var s := Sprite2D.new()
			s.centered = false
			s.position = _cell(p)
			s.scale = Vector2(1.5, 1.5)  # 32 px placeholder tiles drawn at 48
			if room.is_wall(p):
				s.texture = C.tex("wall_top" if room.is_wall(p + Vector2i.DOWN) else "wall_face_%d" % (x % 2))
				var occ := LightOccluder2D.new()
				var poly := OccluderPolygon2D.new()
				poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2(TILE, 0), Vector2(TILE, TILE), Vector2(0, TILE)])
				occ.occluder = poly
				occ.position = _cell(p)
				add_child(occ)
			else:
				s.texture = C.tex("floor_%d" % C.floor_variant(p))
			add_child(s)

	for t in room.thralls:
		_actor(C.tex("thrall"), t, 1.5)
	for l in room.lamps:
		_actor(C.tex("lamp"), l, 1.5)

	# the survivor: 64 px frame, feet on the tile's lower edge
	var body := Sprite2D.new()
	var ct := CanvasTexture.new()
	ct.diffuse_texture = C.tex(C.SPRITE)
	ct.normal_texture = C.tex(C.SPRITE + "_n")
	body.texture = ct
	body.centered = false
	var feet := _cell(room.hunter) + Vector2(TILE / 2.0, TILE - 4)
	body.position = feet - Vector2(32, 62)
	add_child(body)
	var glow := Sprite2D.new()
	glow.texture = C.tex(C.SPRITE + "_glow")
	glow.centered = false
	glow.position = body.position
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = add
	add_child(glow)

	var light := PointLight2D.new()
	var g := GradientTexture2D.new()
	g.width = 512
	g.height = 512
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.45, Color(0.6, 0.6, 0.6, 1))
	g.gradient = grad
	light.texture = g
	light.texture_scale = 1.0
	light.color = C.AMBER
	light.energy = 1.6
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.position = body.position + C.flame_px(C.SPRITE)
	light.height = 24
	add_child(light)

	C.add_vignette(self)


func _actor(t: Texture2D, p: Vector2i, sc: float) -> void:
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.scale = Vector2(sc, sc)
	s.position = _cell(p)
	add_child(s)


# phone test build: tap anywhere to flip between the 2D and 3D versions
func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
		get_tree().change_scene_to_file("res://scenes/look_test_3d.tscn")
