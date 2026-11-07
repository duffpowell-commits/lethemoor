extends Node2D
## Art test (M1 prep): the 48x48 lantern-bearer on the quay, lit by real Godot 2D lights.
## Not gameplay. It exists to judge the HD-2D look: pixel sprite + normal map + engine light.
## Renders:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/art_test.tscn -- --capture
##   -> docs/renders/m1_art_*.png

const T := 32
const DARKNESS := Color("#0d1420")
const LANTERN := Color("#ff9a3c")
const MOON := Color("#6f8fc4")
const CENTER := Vector2(180, 330)
const FLAME_OFFSET := Vector2(12.5, 11.5)  # lantern pixel in hunter48.png, from the sprite centre

var hunter: Sprite2D
var lantern: PointLight2D
var moon: PointLight2D
var lit_tex: CanvasTexture
var flat_tex: CanvasTexture


func _ready() -> void:
	_build()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _tex(name: String) -> Texture2D:
	return load("res://assets/art/%s.png" % name)


func _build() -> void:
	var dark := CanvasModulate.new()
	dark.color = DARKNESS
	add_child(dark)

	# wet quay: a wall along the top, cobbles everywhere else
	for y in 20:
		for x in 12:
			var s := Sprite2D.new()
			s.centered = false
			s.position = Vector2(x * T - 12, y * T)
			if y < 7:
				s.texture = _tex("wall_top")
			elif y == 7:
				s.texture = _tex("wall_face_%d" % (x % 2))
			else:
				s.texture = _tex("floor_%d" % ((x * 7 + y * 13) % 4))
			add_child(s)

	# something waiting at the edge of the light
	var thrall := Sprite2D.new()
	thrall.texture = _tex("thrall")
	thrall.position = CENTER + Vector2(-92, -58)
	add_child(thrall)
	# its eyes catch the lantern even where the body doesn't: unshaded red pinpricks
	var eye_mat := CanvasItemMaterial.new()
	eye_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for ex in [-3, 1]:
		var eye := ColorRect.new()
		eye.color = Color("#c81e2e")
		eye.size = Vector2(1, 1)
		eye.position = Vector2(ex, -6)
		eye.material = eye_mat
		thrall.add_child(eye)

	lit_tex = CanvasTexture.new()
	lit_tex.diffuse_texture = _tex("hunter48")
	lit_tex.normal_texture = _tex("hunter48_n")
	flat_tex = CanvasTexture.new()
	flat_tex.diffuse_texture = _tex("hunter48")

	hunter = Sprite2D.new()
	hunter.texture = lit_tex
	hunter.position = CENTER
	add_child(hunter)

	# the flame ignores light: it IS the light
	var glow := Sprite2D.new()
	glow.texture = _tex("hunter48_glow")
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = unshaded
	hunter.add_child(glow)

	lantern = PointLight2D.new()
	lantern.texture = _light_texture()
	lantern.texture_scale = 0.8
	lantern.color = LANTERN
	lantern.energy = 1.9
	lantern.height = 18.0          # low, at hand height: lights the coat from below and the side
	lantern.offset = FLAME_OFFSET
	lantern.shadow_enabled = true
	lantern.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	hunter.add_child(lantern)

	# cold moonlight from the upper left: only there to show off the normal map's rim
	moon = PointLight2D.new()
	moon.texture = _light_texture()
	moon.texture_scale = 1.3
	moon.color = MOON
	moon.energy = 0.0
	moon.height = 60.0
	moon.position = CENTER + Vector2(-70, -60)
	add_child(moon)

	add_child(_vignette())


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


## Screen-edge darkening, drawn unshaded on top: the "something is out there" frame.
func _vignette() -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.01, 0.015, 0.03, 0.92))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 360
	tex.height = 640
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = mat
	return s


# ---------------------------------------------------------------- capture

func _capture() -> void:
	var out := "res://docs/renders/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# [name, normal map on?, moonlight energy]
	var shots := [
		["m1_art_lantern", true, 0.0],
		["m1_art_moon", true, 0.55],
		["m1_art_flat", false, 0.55],
	]
	for s in shots:
		hunter.texture = lit_tex if s[1] else flat_tex
		moon.energy = s[2]
		for i in 6:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		# close-up of the hunter, 6x, so the pixels can be judged on a phone
		var crop := img.get_region(Rect2i(Vector2i(CENTER) - Vector2i(60, 70), Vector2i(120, 140)))
		crop.resize(crop.get_width() * 6, crop.get_height() * 6, Image.INTERPOLATE_NEAREST)
		crop.save_png(ProjectSettings.globalize_path(out + s[0] + "_zoom.png"))
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(ProjectSettings.globalize_path(out + s[0] + ".png"))
		print("saved ", s[0])
	get_tree().quit()
