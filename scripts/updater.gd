extends CanvasLayer
## In-app updates for the Android APK (autoload "Updater"). Android only; does nothing on web,
## desktop, headless tests and captures.
##
## How it works: CI stamps every APK with a build number (`version/code` = the workflow run
## number, also written to res://build_code.txt) and, on main, uploads the APK plus
## version.json ({"code": N, "sha": "abc1234"}) to the public "dev" release. On launch, when
## the app comes back to the front, and every RECHECK_S while it stays open, this reads version.json; if its code is higher than
## ours it offers UPDATE NOW. That downloads the APK into user:// and hands it to Android's
## installer via OS.shell_open (Godot's own FileProvider turns the path into a content:// URI).
## Android always asks the player to confirm; the first time it also asks to allow Lethemoor
## to install apps. The manifest needs REQUEST_INSTALL_PACKAGES (Android preset,
## custom_permissions) and every build must be signed with the same key (repo secret
## LM_KEYSTORE_PASS unlocks signing/lethemoor.keystore.enc), or Android refuses the update.
##
## Testing off-phone: LM_UPDATER_TEST=1 runs it anywhere; LM_UPDATER_URL points it at another
## version.json; LM_UPDATER_CODE pretends to be that build number; LM_UPDATER_SHOT=<png> saves
## a screenshot of the offer.

const UI = preload("res://scripts/ui_style.gd")

const RELEASE := "https://github.com/duffpowell-commits/lethemoor/releases/download/dev/"
const VERSION_URL := RELEASE + "version.json"
const APK_URL := RELEASE + "lethemoor.apk"
const APK_PATH := "user://update.apk"
const RECHECK_S := 120.0          # coming back to the app re-checks at most this often
## Why POLL_S < RECHECK_S (Nov 23 review): a 120 s timer against a 120 s gate skipped every other
## tick, so open-app checks really came every ~240 s. Tick often, let _check_if_due decide.
const POLL_S := 30.0

var my_code := 0
var new_code := 0
var busy := false                 # a check or download is running
var last_check := -1e9
var http: HTTPRequest
var sheet: Control
var line: Label
var go_btn: Button
var later_btn: Button
var installing := false           # the APK is downloaded; GO hands it to Android again
## Build the player said LATER to. Why (Nov 23 review): without it the open-app poll re-offered
## the same build every few minutes mid-night. Cleared when the app comes back to the front.
var dismissed := 0


func _ready() -> void:
	layer = 120                   # above every game sheet, the title and the kill shot
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _enabled():
		return
	my_code = _local_code()
	if my_code <= 0:
		return                    # editor / local export: no build number, nothing to compare
	if FileAccess.file_exists(APK_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(APK_PATH))   # last update's file
	await get_tree().create_timer(1.5).timeout     # let the title draw first
	check()
	var poll := Timer.new()
	poll.wait_time = POLL_S
	poll.timeout.connect(_check_if_due)
	add_child(poll)
	poll.start()


func _enabled() -> bool:
	if OS.get_environment("LM_UPDATER_TEST") == "1":
		return true
	return OS.get_name() == "Android"


func _local_code() -> int:
	if OS.get_environment("LM_UPDATER_CODE") != "":
		return OS.get_environment("LM_UPDATER_CODE").to_int()
	if FileAccess.file_exists("res://build_code.txt"):
		return FileAccess.get_file_as_string("res://build_code.txt").strip_edges().to_int()
	return 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		dismissed = 0
		_check_if_due()


## Offer only a newer build the player hasn't already put off.
static func should_offer(remote: int, local: int, put_off: int) -> bool:
	return local > 0 and remote > local and remote > put_off


func _check_if_due() -> void:
	if my_code > 0 and sheet == null and Time.get_ticks_msec() / 1000.0 - last_check >= RECHECK_S:
		check()


## Ask the dev release for its build number. Quietly gives up offline.
func check() -> void:
	if busy:
		return
	busy = true
	last_check = Time.get_ticks_msec() / 1000.0
	var url := OS.get_environment("LM_UPDATER_URL")
	if url == "":
		url = VERSION_URL
	url += ("&" if "?" in url else "?") + "t=%d" % Time.get_unix_time_from_system()   # dodge caches
	var req := _request()
	req.request_completed.connect(_on_version, CONNECT_ONE_SHOT)
	if req.request(url) != OK:
		busy = false


func _request() -> HTTPRequest:
	if http != null:
		http.queue_free()
	http = HTTPRequest.new()
	http.max_redirects = 8        # github.com -> the release file's storage host
	http.timeout = 20.0
	add_child(http)
	return http


func _on_version(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("code"):
		return
	new_code = int(data["code"])
	print("UPDATER mine %d, release %d" % [my_code, new_code])
	if should_offer(new_code, my_code, dismissed):
		_offer()


# ---------------------------------------------------------------- the sheet

func _offer() -> void:
	if sheet != null:
		return
	sheet = Control.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP     # the night waits underneath
	sheet.theme = UI.theme()
	add_child(sheet)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var head := Label.new()
	head.text = "A NEW BUILD IS HERE"
	head.add_theme_font_override("font", UI.head())
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", UI.AMBER)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	line = Label.new()
	line.text = "Build %d is out. You have build %d." % [new_code, my_code]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 20)
	col.add_child(line)
	go_btn = _button("UPDATE NOW", 72)
	UI.lit(go_btn)
	go_btn.pressed.connect(_go)
	col.add_child(go_btn)
	later_btn = _button("LATER", 60)
	later_btn.add_theme_color_override("font_color", UI.DIM)
	later_btn.pressed.connect(_close)
	col.add_child(later_btn)
	if OS.get_environment("LM_UPDATER_SHOT") != "":     # off-phone look check
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("LM_UPDATER_SHOT"))
		print("UPDATER SHOT")


func _button(text: String, h: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", 22)
	return b


func _close() -> void:
	if not installing:
		dismissed = new_code
	installing = false
	if http != null and busy:
		http.cancel_request()
		busy = false
	if sheet != null:
		sheet.queue_free()
		sheet = null


func _go() -> void:
	if installing:
		_install()
		return
	if busy:
		return
	busy = true
	go_btn.disabled = true
	line.text = "Downloading build %d..." % new_code
	var req := _request()
	req.timeout = 0.0             # big file on a phone connection: no overall timeout
	req.download_file = APK_PATH
	req.request_completed.connect(_on_apk, CONNECT_ONE_SHOT)
	if req.request(APK_URL + "?t=%d" % Time.get_unix_time_from_system()) != OK:
		_failed()


func _process(_dt: float) -> void:
	if busy and sheet != null and http != null and http.download_file != "":
		var total := http.get_body_size()
		if total > 0:
			line.text = "Downloading build %d... %d%%" % [new_code, int(100.0 * http.get_downloaded_bytes() / total)]


func _on_apk(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	busy = false
	if sheet == null:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_failed()
		return
	installing = true
	go_btn.disabled = false
	go_btn.text = "INSTALL"
	line.text = "Android will ask you to confirm. First time only: allow Lethemoor to install apps, then come back and tap INSTALL."
	_install()


func _install() -> void:
	var path := ProjectSettings.globalize_path(APK_PATH)
	if OS.shell_open(path) != OK:
		line.text = "Android wouldn't open the installer. Tap INSTALL to try again."


func _failed() -> void:
	busy = false
	go_btn.disabled = false
	line.text = "Download failed. Check your signal and tap UPDATE NOW again."
