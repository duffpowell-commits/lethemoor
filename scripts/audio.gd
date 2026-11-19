extends Node
## Lethemoor's sound (autoload "Audio"). Everything audible lives here; the view only calls
## a few static hooks (via `const Sound = preload("res://scripts/audio.gd")`, so scripts still
## parse in --script/--check-only runs where autoload names don't exist, and do nothing then):
##   Sound.hook_night()                        a night starts (scene ready, retry)
##   Sound.hook_turn(kind, events, game, spent)   after every action, with the sim's events
##   Sound.hook_lantern(setting)               lantern changed
##   Sound.hook_track(game)                    after every refresh: heartbeat, flame, silence
## Buttons click by themselves (every Button that enters the tree gets a soft click).
##
## Sound is information in first person: thralls you can't see shuffle where they stand
## (3D, so a scrape behind your left shoulder is behind your left shoulder), the Stalker's
## silk drags when she moves, and the bed goes quiet the turn before she can move (the
## "silent bell" rule from docs/design/first_person_design.md).
##
## Web: browsers start audio suspended until the first tap. Godot's web build resumes the
## AudioContext on the first input event (the title's BEGIN tap does it); nothing here plays
## anything that matters before that. Web uses "sample" playback, where bus effects don't
## run, so every reverb is baked into the files (tools/gen_audio.py). iPhone: the ring/silent
## switch mutes web audio.
## Clips and where they came from: assets/audio/SOURCES.md.

const Fog = preload("res://scripts/sim/fog.gd")

const DIR := "res://assets/audio/"
const LOOPS := ["amb_moor", "flame_loop", "heartbeat"]
const BED_DB := -6.0
const QUIET_DB := -30.0           # the bed when the Stalker is about to move
const FLAME_DB := {Fog.Lantern.HOODED: -80.0, Fog.Lantern.NORMAL: -20.0, Fog.Lantern.BRIGHT: -12.0}
const HEAR := 7.5                 # tiles: thralls further off than this make no sound
const HEART_FROM := 25            # dread below this: no heartbeat
const POOL := 10
const CFG := "user://lethemoor.cfg"

var streams := {}
var bed: AudioStreamPlayer
var flame: AudioStreamPlayer
var heart: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var muted := false
var last_step := -1
var prev_pos: Array = []          # thrall positions after the last refresh
var quiet := false
var was_flicker := false
var was_haunted := false
var ended := false
var tweens := {}
var cue_frame := -1
var log_cues := OS.has_environment("LM_AUDIO_LOG")   # LM_AUDIO_LOG=1: print every sound played
static var _me: Node               # the autoload instance, once it's ready


static func hook_night() -> void:
	if _me:
		_me.night()


static func hook_turn(kind: String, events: Array, game, spent: bool) -> void:
	if _me:
		_me.on_turn(kind, events, game, spent)


static func hook_lantern(setting: int) -> void:
	if _me:
		_me.on_lantern(setting)


static func hook_track(game) -> void:
	if _me:
		_me.track(game)


func _ready() -> void:
	_me = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	# list_directory sees through export remaps (.import stubs), DirAccess would not
	for f in ResourceLoader.list_directory(DIR):
		if f.ends_with(".ogg"):
			var s = load(DIR + f)
			if s:
				streams[f.get_basename()] = s
	for n in LOOPS:
		if streams.has(n):
			streams[n].loop = true
	bed = _player("amb_moor", -80.0)
	flame = _player("flame_loop", -80.0)
	heart = _player("heartbeat", -80.0)
	for i in POOL:
		pool.append(_player("", 0.0))
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		muted = cfg.get_value("audio", "muted", false)
	AudioServer.set_bus_mute(0, muted)
	get_tree().node_added.connect(_on_node_added)


func _player(stream_name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if stream_name != "":
		p.stream = streams.get(stream_name)
		# belt and braces: if a platform ignores the loop flag, start it again
		p.finished.connect(func(): if p.volume_db > -79.0: p.play())
	p.volume_db = db
	add_child(p)
	return p


## Keyboard M mutes (web/desktop). On the phone the volume rocker does it.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		set_muted(not muted)


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, muted)
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("audio", "muted", muted)
	cfg.save(CFG)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.pressed.is_connected(_click):
		n.pressed.connect(_click)


func _click() -> void:
	_click_now.call_deferred()


## Move and lantern buttons make their own sound (a step, a shutter): no click on top of it.
func _click_now() -> void:
	if cue_frame != Engine.get_process_frames():
		sfx("ui_click", -10.0, randf_range(0.95, 1.05))


# ---------------------------------------------------------------- playing

## A one-shot, not positioned (it's in your head or in your hands).
func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	if not streams.has(name):
		push_warning("no clip " + name)
		return
	if log_cues:
		print("SOUND ", name)
	if name != "ui_click":
		cue_frame = Engine.get_process_frames()
	var p: AudioStreamPlayer = pool[0]
	for q in pool:
		if not q.playing:
			p = q
			break
	pool.erase(p)
	pool.append(p)      # the oldest busy voice is the one stolen next
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## A one-shot out in the world at grid tile `tile` (the camera is the ears).
func at(name: String, tile: Vector2i, db := 0.0, pitch := 1.0) -> void:
	var scene := get_tree().current_scene
	if not streams.has(name) or not (scene is Node3D):
		return
	if log_cues:
		print("SOUND3D ", name, " at ", tile)
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 2.5
	p.max_distance = HEAR + 3.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.panning_strength = 1.4
	p.position = Vector3(tile.x, 1.1, tile.y)
	p.finished.connect(p.queue_free)
	scene.add_child(p)
	p.play()


func _fade(p: AudioStreamPlayer, db: float, time: float) -> void:
	if tweens.has(p) and tweens[p].is_valid():
		tweens[p].kill()
	if db > -79.0 and not p.playing and p.stream:
		p.volume_db = -60.0
		p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, time)
	if db <= -79.0:
		tw.tween_callback(p.stop)
	tweens[p] = tw


# ---------------------------------------------------------------- hooks from the view

## A night begins (first load, or a retry reloads the scene).
func night() -> void:
	ended = false
	quiet = false
	was_flicker = false
	was_haunted = false
	prev_pos = []
	_fade(bed, BED_DB, 3.0)
	_fade(heart, -80.0, 0.5)
	sfx("night_start", -6.0)


## The sim's verdict on one action -> what you hear. `spent` = the action cost a turn.
func on_turn(kind: String, events: Array, game, spent: bool) -> void:
	for c in cues(kind, events, spent):
		match c:
			"step":
				var i := randi() % 4
				if i == last_step:
					i = (i + 1) % 4
				last_step = i
				sfx("step_%d" % i, -3.0, randf_range(0.92, 1.07))
			"turn": sfx("turn", -6.0, randf_range(0.95, 1.05))
			"bump": sfx("bump", -2.0, randf_range(0.95, 1.05))
			"oil": sfx("oil", -2.0)
			"letter": sfx("letter", 0.0)
			"letter_dim": sfx("letter_dim", -4.0)
			"horror": sfx("sting_horror", -3.0)
			"panic": sfx("panic", 0.0)
			"out_of_oil": sfx("out_of_oil", 0.0)
			"bell":
				sfx("bell", 0.0)
				_end(-22.0)
			"dawn":
				sfx("night_start", 0.0, 1.2)
				_end(-22.0)
			"death":
				sfx("death", 0.0)
				_end(-80.0)
			"hook_swing": sfx("hook_swing", -4.0, randf_range(0.93, 1.07))
			"hook_hit": sfx("hook_hit", -1.0, randf_range(0.95, 1.05))
			"hook_broke": sfx("hook_broke", 0.0)
			"hook_found": sfx("hook_found", -2.0)
			"pour": sfx("pour", -3.0)
			"spark": sfx("ignite", -1.0)
			"burned": sfx("burn_shriek", -2.0)
	if not spent or game.over():
		return
	_world_sounds(game)


## Pure mapping from an action and its events to cue names (tested headless).
static func cues(kind: String, events: Array, spent: bool) -> Array:
	var out: Array = []
	if not spent and kind in ["forward", "back"] and not ("taken" in events or "grabbed" in events):
		return ["bump"]
	if spent and kind in ["forward", "back"]:
		out.append("step")
	elif spent and kind in ["left", "right"]:
		out.append("turn")
	elif spent and kind == "hook":
		out.append("hook_swing")
	elif spent and kind in ["pour", "spark"]:
		out.append(kind)
	for e in events:
		match e:
			"oil", "letter", "letter_dim", "horror", "panic", "out_of_oil", \
					"hook_hit", "hook_broke", "hook_found", "burned":
				out.append(e)
			"rang":
				out.append("bell")
			"escaped":
				if not "rang" in events:
					out.append("dawn")
			"taken", "grabbed", "burned_self":
				if not "death" in out:
					out.append("death")
	return out


## Thralls you can hear: the ones that moved this turn shuffle where they now stand, the
## ones hunting you but lurching in place drag a foot now and then. Seen or not: in first
## person, the ear is how you know what's behind you.
func _world_sounds(game) -> void:
	for i in game.thralls.size():
		var th: Dictionary = game.thralls[i]
		if th.get("gone", false):
			continue   # burned: it makes no more sound
		var d: float = Vector2(th.pos - game.hunter).length()
		if d > HEAR:
			continue
		var moved: bool = i < prev_pos.size() and prev_pos[i] != th.pos
		var near_db := -4.0 - d * 1.2
		if th.get("kind", "thrall") == "stalker":
			if moved:
				at("stalker_silk", th.pos, near_db + 2.0, randf_range(0.95, 1.05))
		elif moved:
			at("shuffle_%d" % (randi() % 3), th.pos, near_db, randf_range(0.9, 1.1))
		elif th.target != null and randf() < 0.35:
			at("shuffle_%d" % (randi() % 3), th.pos, near_db - 6.0, randf_range(0.85, 1.0))


## After every refresh: the heartbeat follows dread, the flame follows the lantern, the bed
## falls silent when the Stalker is free to move, the flame's gutter whispers.
func track(game) -> void:
	prev_pos = game.positions()
	if ended or game.over():
		return
	# heartbeat: silent when calm, loud and fast at panic
	var k: float = clampf(float(game.dread - HEART_FROM) / float(100 - HEART_FROM), 0.0, 1.0)
	if game.dread < HEART_FROM:
		_fade(heart, -80.0, 1.0)
	else:
		_fade(heart, lerpf(-26.0, -3.0, k), 0.6)
	heart.pitch_scale = lerpf(0.9, 1.65, k)
	_fade(flame, FLAME_DB[game.effective()], 0.4)
	# the silent bell: one turn of quiet before she can move
	var q := stalker_free(game)
	if q != quiet:
		quiet = q
		_fade(bed, QUIET_DB if q else BED_DB, 0.25 if q else 1.5)
	var fl: bool = game.flickers()
	if fl and not was_flicker:
		sfx("whisper", -8.0)
	was_flicker = fl
	# at 50+ dread the view lies, and so do your ears: a whisper from nowhere, now and then
	var haunted: bool = game.hallucinating()
	if haunted and not was_haunted:
		sfx("sting_dread", -6.0)
	elif haunted and randf() < 0.12:
		at("whisper", game.hunter - game.facing * 2 + Vector2i(randi_range(-1, 1), 0), -10.0, randf_range(0.8, 1.0))
	was_haunted = haunted


## Will a Stalker move on the next turn if nothing changes? (Not watched, and she's hunting
## or can see your light.)
static func stalker_free(game) -> bool:
	for th in game.thralls:
		if th.get("kind", "thrall") != "stalker" or th.get("gone", false):
			continue
		if game.watched(th):
			continue
		if th.target != null or game._sees_light(th):
			return true
	return false


func on_lantern(setting: int) -> void:
	match setting:
		Fog.Lantern.HOODED: sfx("lantern_hood", -3.0)
		Fog.Lantern.NORMAL: sfx("lantern_normal", -4.0)
		Fog.Lantern.BRIGHT: sfx("lantern_bright", -3.0)


func _end(bed_db: float) -> void:
	ended = true
	quiet = false
	_fade(bed, bed_db, 2.0)
	_fade(heart, -80.0, 1.0)
	_fade(flame, -80.0, 1.0)
