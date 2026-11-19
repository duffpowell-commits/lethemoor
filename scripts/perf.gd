extends CanvasLayer
## Frame rate readout + graphics quality for phones.
##
## Readout (MENU -> SHOW FPS, or F3): "58 fps  17 ms  worst 33  |  142 draws  |  HIGH".
##   fps   = frames in the last second; ms = average frame time; worst = slowest frame.
##   draws = draw calls in the last frame (how much the GPU is asked to do).
## Quality (MENU -> GRAPHICS): AUTO (default), HIGH, MEDIUM, LOW.
##   HIGH   = the full look: 3D at the phone's full resolution, glow, lantern shadows.
##   MEDIUM = no glow (the soft halo round fire and brass). Measured Nov 19: glow was ~40% of
##            the frame in a software-GPU run, more than anything else; the look barely changes.
##   LOW    = no glow, no lantern shadows, 3D drawn at 70% resolution and stretched.
##            (Walls still block light in the rules: fog is the truth, shadows are only the look.)
##   AUTO starts at HIGH and steps down one level whenever the game averages under 45 fps for
##   4 seconds; it never steps back up during a run. The look never decides rules.
## LM_PERF_LOG=1 prints the readout line once a second (for headless/CI runs).

const CFG := "user://lethemoor.cfg"
const NAMES := ["AUTO", "HIGH", "MEDIUM", "LOW"]
enum { AUTO, HIGH, MEDIUM, LOW }
const SCALE := {HIGH: 1.0, MEDIUM: 1.0, LOW: 0.7}
const AUTO_FPS := 45.0
const AUTO_WINDOW := 4.0
const WARMUP := 3.0              # loading hitches in the first seconds don't count

var env: Environment
var light: OmniLight3D
var choice := AUTO               # what the player picked
var level := HIGH                # what is applied now
var show := false
var label: Label
var back: ColorRect

var _frames := 0
var _sum := 0.0
var _worst := 0.0
var _tick := 0.0
var _age := 0.0
var _slow := 0.0                 # seconds in a row averaging under AUTO_FPS
var _log := OS.get_environment("LM_PERF_LOG") == "1"
var _no_save := false


func setup(environment: Environment, lantern: OmniLight3D, no_save := false) -> void:
	env = environment
	light = lantern
	_no_save = no_save
	layer = 90
	back = ColorRect.new()
	back.color = Color(0, 0, 0, 0.62)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#9fe3a0"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var cfg := ConfigFile.new()
	if not no_save and cfg.load(CFG) == OK:
		show = cfg.get_value("perf", "show_fps", false)
		choice = clampi(cfg.get_value("perf", "quality", AUTO), AUTO, LOW)
	if no_save:
		choice = HIGH            # captures render the full look; AUTO would drop it on a slow CI box
		var forced := NAMES.find(OS.get_environment("LM_PERF_QUALITY"))
		if forced >= 0:
			choice = forced
	level = HIGH if choice == AUTO else choice
	apply()
	_update_visible()


func set_position_below(y: float) -> void:
	label.position = Vector2(14, y + 4)
	back.position = Vector2(8, y)


func toggle_show() -> void:
	show = not show
	_update_visible()
	_save()


## Cycle AUTO -> HIGH -> MEDIUM -> LOW -> AUTO. Returns the new name for the menu button.
func cycle_quality() -> String:
	choice = (choice + 1) % NAMES.size()
	level = HIGH if choice == AUTO else choice
	_slow = 0.0
	apply()
	_save()
	return quality_name()


func quality_name() -> String:
	if choice == AUTO:
		return "AUTO (%s)" % NAMES[level]
	return NAMES[choice]


func apply() -> void:
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = SCALE[level]
	if env:
		env.glow_enabled = level == HIGH
	if light:
		light.shadow_enabled = level != LOW


func _update_visible() -> void:
	label.visible = show
	back.visible = show


func _save() -> void:
	if _no_save:
		return
	var cfg := ConfigFile.new()
	cfg.load(CFG)               # keep the other sections (hints, audio)
	cfg.set_value("perf", "show_fps", show)
	cfg.set_value("perf", "quality", choice)
	cfg.save(CFG)


func _process(delta: float) -> void:
	_age += delta
	_frames += 1
	_sum += delta
	_worst = maxf(_worst, delta)
	_tick += delta
	if _tick < 1.0:
		return
	var fps := _frames / _tick
	var line := "%d fps  %d ms  worst %d  |  %d draws  |  %s" % [
		roundi(fps), roundi(1000.0 * _sum / _frames), roundi(1000.0 * _worst),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), quality_name()]
	label.text = line
	back.size = Vector2(label.get_minimum_size().x + 12, 26)
	if _log:
		print("PERF ", line)
	if choice == AUTO and _age > WARMUP and level < LOW:
		_slow = _slow + _tick if fps < AUTO_FPS else 0.0
		if _slow >= AUTO_WINDOW:
			level += 1
			_slow = 0.0
			apply()
			if _log:
				print("PERF auto quality -> ", NAMES[level])
	_frames = 0
	_sum = 0.0
	_worst = 0.0
	_tick = 0.0
