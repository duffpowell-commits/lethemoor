extends Node
## HD-2D 3D test (Nov 11): how far Godot's Compatibility renderer gets in 3D.
## Not gameplay. Pixel sprites as billboards in a real 3D street, lit by a real 3D lantern,
## with fog, glow and a tilted perspective camera. Reuses the existing 32 px tiles and bearer64.
## Compatibility only (repo rule: it's what runs in iPhone Safari), so no volumetric fog,
## SSAO or depth of field. Whatever this shows is the real ceiling for Lethemoor.
## Renders:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/hd2d_test.tscn -- --capture
##   -> docs/renders/hd2d_*.png

const W := 1080            # 2x the 540x960 base, so pixels are judged at phone size
const H := 1920
const PX := 1.0 / 48.0     # one sprite pixel = one 48th of a tile (64 px bearer = 1.33 tiles)
const LANTERN := Color("#ff9a3c")
const DEEP := Color("#0d1420")
const MOON := Color("#6f8fc4")
const BLOOD := Color("#c81e2e")
const STREET_LEN := 14      # tiles, running away from the camera (-z)
const STREET_W := 3         # tiles between the house fronts: an alley (fits portrait)

## lantern settings from the design: [name, light range in tiles, energy]
const SETTINGS := {
	"bright": [5.0, 3.0],
	"normal": [3.2, 2.2],
	"hooded": [0.9, 0.35],
}

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var lantern: OmniLight3D
var flame: Sprite3D
var bearer: Sprite3D


func _ready() -> void:
	_build()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _tex(name: String) -> Texture2D:
	return load("res://assets/art/%s.png" % name)


func _mat(tex_name: String, uv: Vector3, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = uv
	m.roughness = rough
	m.metallic_specular = 0.2   # damp, not mirror-wet: a full highlight reads as a second light
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	world.add_child(mi)
	return mi


func _billboard(tex_name: String, pos: Vector3, shaded: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _tex(tex_name)
	s.pixel_size = PX
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y   # stays upright, turns to face the camera
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = shaded
	s.offset = Vector2(0, s.texture.get_height() / 2.0)   # feet on the ground
	s.position = pos
	world.add_child(s)
	return s


func _build() -> void:
	var holder := SubViewportContainer.new()
	holder.stretch = false   # keep the 3D at full 1080x1920; the capture reads it directly
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)

	# --- sky, fog, glow: the mood lives here, not in the sprites
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#05080d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = DEEP
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("#141c2a")
	env.fog_density = 0.045
	env.fog_sky_affect = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	# faint cold moon from above-left, so the dark has shape instead of being pure black
	var moon := DirectionalLight3D.new()
	moon.light_color = MOON
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-55, -35, 0)
	world.add_child(moon)

	# --- the street: wet cobbles (low roughness = the lantern smears across the stones)
	var half := STREET_W / 2.0
	_box(Vector3(STREET_W + 2, 0.2, STREET_LEN + 4), Vector3(0, -0.1, -STREET_LEN / 2.0),
		_mat("floor_1", Vector3((STREET_W + 2) * 1.5, (STREET_LEN + 4) * 1.5, 1), 0.8))
	# house fronts, uneven heights, both sides
	var wall_mat := _mat("wall_face_0", Vector3(1, 1, 1), 0.9)
	var roof_mat := _mat("wall_top", Vector3(1, 1, 1), 0.95)
	var heights := [3.0, 4.0, 3.5, 4.5, 3.0, 5.0, 3.5]
	for i in heights.size():
		var h: float = heights[i]
		var z := -i * 2.0 - 1.0
		for side in [-1, 1]:
			var hh: float = h if side < 0 else heights[(i + 3) % heights.size()]
			var wm := wall_mat.duplicate() as StandardMaterial3D
			wm.uv1_scale = Vector3(2, hh, 1)
			_box(Vector3(1.0, hh, 2.0), Vector3(side * (half + 0.5), hh / 2.0, z), wm)
			_box(Vector3(1.3, 0.25, 2.1), Vector3(side * (half + 0.55), hh + 0.12, z), roof_mat)

	# a dead street lamp near the hunter (a district to relight) and a live one far off
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#1b1f26")
	iron.roughness = 0.6
	_box(Vector3(0.12, 2.6, 0.12), Vector3(-half + 0.25, 1.3, -2.5), iron)
	_box(Vector3(0.12, 2.6, 0.12), Vector3(half - 0.4, 1.3, -10.5), iron)
	var far_lamp := OmniLight3D.new()
	far_lamp.light_color = Color("#ffb45a")
	far_lamp.light_energy = 2.4
	far_lamp.omni_range = 4.0
	far_lamp.position = Vector3(half - 0.4, 2.7, -10.5)
	world.add_child(far_lamp)
	var far_flame := _billboard("bearer64_glow", Vector3(half - 0.4, 2.35, -10.5), false)
	far_flame.modulate = Color(1.6, 1.3, 0.9)

	# --- the lantern bearer, lit by her own lantern
	bearer = _billboard("bearer64", Vector3(0, 0, -4.0), true)
	bearer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame = _billboard("bearer64_glow", Vector3(0, 0, -3.99), false)
	flame.modulate = Color(2.2, 1.7, 1.1)   # >1 pushes it over the glow threshold: it blooms
	lantern = OmniLight3D.new()
	lantern.light_color = LANTERN
	lantern.shadow_enabled = true
	lantern.omni_attenuation = 1.0
	lantern.position = Vector3(0.4, 0.55, -3.7)   # at her right hand, a little in front
	world.add_child(lantern)

	# --- something at the edge of the light: dark body, eyes that catch it anyway
	for t in [[Vector3(-0.9, 0, -7.0), 1.0], [Vector3(0.9, 0, -9.5), 0.8]]:
		var th := _billboard("thrall", t[0], true)
		th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		th.pixel_size = PX * 1.6 * t[1]
		th.modulate = Color(0.55, 0.6, 0.7)
		for ex in [-0.07, 0.07]:
			var eye := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.045, 0.045) * t[1]
			eye.mesh = q
			var em := StandardMaterial3D.new()
			em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			em.albedo_color = BLOOD * 2.4
			em.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			eye.material_override = em
			eye.position = t[0] + Vector3(ex * t[1], 1.05 * t[1], 0.05)
			world.add_child(eye)

	# --- HD-2D camera: high, tilted, long lens (flattens perspective like a diorama)
	cam = Camera3D.new()
	cam.fov = 44.0
	cam.position = Vector3(0, 6.2, 2.2)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.4, -5.4))

	_set_lantern("normal")
	# vignette lives inside the 3D viewport so the capture includes it at full size
	var layer := CanvasLayer.new()
	vp.add_child(layer)
	layer.add_child(_vignette())


func _set_lantern(mode: String) -> void:
	var s: Array = SETTINGS[mode]
	lantern.omni_range = s[0]
	lantern.light_energy = s[1]
	flame.visible = mode != "hooded"


## Screen-edge darkening on top of the 3D view: the "something is out there" frame.
func _vignette() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.01, 0.015, 0.03, 0.9))
	g.add_point(0.5, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 270
	tex.height = 480
	var r := TextureRect.new()
	r.texture = tex
	r.size = Vector2(W, H)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---------------------------------------------------------------- capture

func _capture() -> void:
	var out := "res://docs/renders/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for mode in ["normal", "bright", "hooded"]:
		_set_lantern(mode)
		for i in 8:
			await get_tree().process_frame
		# the 3D viewport itself is 1080x1920; grab it directly, no rescale
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(out + "hd2d_" + mode + ".png"))
		print("saved hd2d_", mode)
	get_tree().quit()
