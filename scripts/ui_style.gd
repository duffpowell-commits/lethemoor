## Lethemoor's UI look: ink-black panels, thin brass trim, Cinzel for headings and buttons,
## IM Fell English for anything you read. Built in code so the web build ships no .tres.
extends RefCounted

const INK := Color("#05070c")
const PANEL := Color(0.035, 0.04, 0.055, 0.94)
const BRASS := Color("#7a6238")
const BRASS_DIM := Color("#3f3424")
const AMBER := Color("#f2c25a")
const TEXT := Color("#e2d6bd")
const DIM := Color("#8a97ab")
const BLOOD := Color("#c81e2e")

static var _head: Font
static var _body: Font
static var _italic: Font


static func head() -> Font:
	if _head == null:
		var v := FontVariation.new()
		v.base_font = load("res://assets/fonts/Cinzel.ttf")
		v.variation_opentype = {"wght": 600}
		_head = v
	return _head


static func body() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/IMFellEnglish.ttf")
	return _body


static func italic() -> Font:
	if _italic == null:
		_italic = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	return _italic


static func box(bg: Color, border: Color, width := 1, radius := 5, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


## The whole HUD hangs off one Theme: labels read in Fell, buttons speak in Cinzel.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", head())
	t.set_font_size("font_size", "Button", 17)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_hover_pressed_color", "Button", AMBER)
	t.set_stylebox("normal", "Button", box(PANEL, BRASS_DIM))
	t.set_stylebox("hover", "Button", box(Color(0.06, 0.065, 0.085, 0.96), BRASS))
	t.set_stylebox("pressed", "Button", box(Color(0.16, 0.11, 0.05, 0.96), AMBER, 2))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.16, 0.11, 0.05, 0.96), AMBER, 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "Panel", box(PANEL, BRASS_DIM))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.03, 0.035, 0.05, 0.97), BRASS, 1, 6, 22))
	return t


## A lit button: the lantern setting you're on, or a call to action.
static func lit(b: Button) -> void:
	var s := box(Color(0.2, 0.13, 0.05, 0.96), AMBER, 2)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_color_override("font_color", AMBER)
	b.add_theme_color_override("font_hover_color", AMBER)


static func unlit(b: Button) -> void:
	for k in ["normal", "hover"]:
		b.remove_theme_stylebox_override(k)
	for k in ["font_color", "font_hover_color"]:
		b.remove_theme_color_override(k)
