extends RefCounted
## Shared bits for the 2D vs 3D look test (scenes/look_test_2d.tscn, look_test_3d.tscn).
## Same room, same sprite, same palette; only the way it is drawn changes.

const ROOM_PATH := "res://rooms/quay_01.txt"
const SPRITE := "canva_bearer64"
const AMBER := Color(1.0, 0.62, 0.26)

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.75;
void fragment() {
	vec2 d = UV - vec2(0.5);
	d.x *= 0.6;
	float v = smoothstep(0.18, 0.62, length(d));
	COLOR = vec4(0.0, 0.0, 0.02, v * strength);
}
"""


static func load_room() -> RefCounted:
	var Room = load("res://scripts/sim/room.gd")
	return Room.parse(FileAccess.get_file_as_string(ROOM_PATH))


static func tex(name: String) -> Texture2D:
	return load("res://assets/art/%s.png" % name)


## Centre of the flame pixels in the _glow image, in sprite pixels from the top-left.
static func flame_px(name: String) -> Vector2:
	var img: Image = tex(name + "_glow").get_image()
	var sum := Vector2.ZERO
	var n := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a
			if a > 0.1:
				sum += Vector2(x + 0.5, y + 0.5) * a
				n += a
	return sum / n if n > 0.0 else Vector2(img.get_width() * 0.75, img.get_height() * 0.7)


static func floor_variant(p: Vector2i) -> int:
	return absi(p.x * 7 + p.y * 13 + p.x * p.y) % 4


static func add_vignette(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)
	parent.add_child(layer)


## Waits for shaders to settle, saves docs/renders/look_<tag>.png at 1080x1920, quits.
static func capture(node: Node, tag: String) -> void:
	for i in 40:
		await node.get_tree().process_frame
	var img := node.get_viewport().get_texture().get_image()
	if img.get_width() < 1080:
		img.resize(1080, 1920, Image.INTERPOLATE_NEAREST)
	var out := ProjectSettings.globalize_path("res://docs/renders/look_%s.png" % tag)
	img.save_png(out)
	print("saved ", out)
	node.get_tree().quit()


static func tag_arg(default: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--tag")
	return args[i + 1] if i >= 0 and i + 1 < args.size() else default
