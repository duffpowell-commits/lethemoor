extends Node3D
## Look test, HD-2D: the same room built as a 3D scene, pixel sprites as upright billboards,
## real 3D lantern light + shadows, fog, glow, depth of field. 1 tile = 1 metre.
##   Android (Mobile renderer):
##     xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --resolution 1080x1920 res://scenes/look_test_3d.tscn -- --capture --tag 3d_android
##   iPhone web (Compatibility renderer):
##     xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1080x1920 res://scenes/look_test_3d.tscn -- --capture --tag 3d_web

const C = preload("res://scripts/look_test_common.gd")
const PX := 1.0 / 48.0  # one sprite pixel in metres: a 64 px character stands 1.33 tiles tall
const WALL_H := 1.2

var room: RefCounted


func _ready() -> void:
	# sprites keep their pixels (nearest filter); light, fog and blur render at full phone res
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	room = C.load_room()
	_build()
	if "--capture" in OS.get_cmdline_user_args():
		C.capture(self, C.tag_arg("3d"))


func _w(p: Vector2i) -> Vector3:
	return Vector3(p.x + 0.5, 0, p.y + 0.5)


func _mat(name: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = C.tex(name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.roughness = 0.95
	return m


func _build() -> void:
	var floors := []
	for i in 4:
		floors.append(_mat("floor_%d" % i))
	var wall := _mat("wall_face_0")
	var wall_top := _mat("wall_top")

	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var box := BoxMesh.new()
	box.size = Vector3(1, WALL_H, 1)
	var low_box := BoxMesh.new()
	low_box.size = Vector3(1, 0.2, 1)
	for y in room.size.y:
		for x in room.size.x:
			var p := Vector2i(x, y)
			var mi := MeshInstance3D.new()
			if room.is_wall(p):
				# cutaway: walls on the camera side are cut down so they never hide the survivor
				var h := 0.2 if y == room.size.y - 1 else WALL_H
				mi.mesh = box if h == WALL_H else low_box
				mi.material_override = wall
				mi.position = _w(p) + Vector3(0, h / 2.0, 0)
				var cap := MeshInstance3D.new()
				cap.mesh = plane
				cap.material_override = wall_top
				cap.position = _w(p) + Vector3(0, h + 0.001, 0)
				add_child(cap)
			else:
				mi.mesh = plane
				mi.material_override = floors[C.floor_variant(p)]
				mi.position = _w(p)
			add_child(mi)

	for t in room.thralls:
		_billboard(C.tex("thrall"), _w(t), 1.0 / 32.0)
	for l in room.lamps:
		_billboard(C.tex("lamp"), _w(l), 1.0 / 32.0)

	var body := _billboard(C.tex(C.SPRITE), _w(room.hunter), PX)
	# the flame: unshaded and over-bright so the glow pass blooms it
	var flame := Sprite3D.new()
	flame.texture = C.tex(C.SPRITE + "_glow")
	flame.pixel_size = PX
	flame.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	flame.shaded = false
	flame.modulate = Color(4, 2.6, 1.2)
	flame.position = body.position + Vector3(0, 0, 0.01)
	add_child(flame)

	var f := C.flame_px(C.SPRITE)
	var lantern := OmniLight3D.new()
	lantern.light_color = C.AMBER
	lantern.light_energy = 3.0
	lantern.omni_range = 5.0
	lantern.omni_attenuation = 1.4
	lantern.shadow_enabled = true
	lantern.position = body.position + Vector3((f.x - 32) * PX, (32 - f.y) * PX, 0.6)
	add_child(lantern)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.55, 0.85)
	moon.light_energy = 0.12
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 30, 0)
	add_child(moon)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.09, 0.16)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.035, 0.06)
	env.fog_density = 0.06
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 34.0
	var target := _w(room.hunter) + Vector3(0, 0.6, -3.5)
	cam.position = target + Vector3(0, 12.0, 15.0)
	add_child(cam)
	cam.look_at(target)
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 21.0
	attrs.dof_blur_far_transition = 5.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 14.0
	attrs.dof_blur_near_transition = 2.0
	attrs.dof_blur_amount = 0.12
	cam.attributes = attrs
	cam.current = true

	# Compatibility lights in sRGB, Mobile/Forward+ in linear: same numbers read far hotter
	# on Mobile, so tone those renderers down to match the look.
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		lantern.light_energy *= 0.35
		moon.light_energy *= 0.5
		env.ambient_light_energy *= 0.5
		flame.modulate = Color(2.2, 1.5, 0.8)

	C.add_vignette(self)


func _billboard(t: Texture2D, at: Vector3, px: float) -> Node3D:
	# a textured quad with a billboard material: renders the same on every renderer
	# (Sprite3D drew flat silhouettes on the Mobile renderer in the test rig)
	var size := Vector2(t.get_width(), t.get_height()) * px
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = at + Vector3(0, size.y / 2.0, 0)
	add_child(mi)
	return mi
