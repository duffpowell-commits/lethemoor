extends Node3D
## A horror on a real humanoid skeleton (Meshy rig, glTF), driven by real clips.
## Model: assets/models/<who>.glb (rigged mesh). Clips: assets/models/<who>_clips.res
## (an AnimationLibrary baked by tools/bake_clips.gd from Meshy's clip GLBs).
## The view only tells it what state the rules are in; it never decides a rule.
## States: idle, walk, crouch (the tell before a lunge), lunge, dead (lying), rise.
## A state whose clip is missing falls back to the nearest one we have.

const BLEND := 0.18
const FALLBACK := {
	"walk": ["walk", "walking", "idle"],
	"idle": ["idle"],
	"crouch": ["crouch", "idle"],
	"lunge": ["lunge", "idle"],
	"dead": ["dead", "idle"],
	"rise": ["rise", "idle"],
}
const LOOPS := ["idle", "walk", "walking", "crouch"]

var body: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var state := ""
var clip := ""


## Build one from res://assets/models/<who>.glb, scaled to `height` world units (crown).
static func make(who: String, height: float) -> Node3D:
	var actor: Node3D = (load("res://scripts/rig_horror.gd") as GDScript).new()
	actor.name = who.capitalize()
	actor.body = (load("res://assets/models/%s.glb" % who) as PackedScene).instantiate()
	actor.add_child(actor.body)
	actor.skeleton = actor.body.find_child("Skeleton3D", true, false)
	actor.player = actor.body.find_child("AnimationPlayer", true, false)
	if actor.player == null:
		actor.player = AnimationPlayer.new()
		actor.body.add_child(actor.player)
	var lib_path := "res://assets/models/%s_clips.res" % who
	if ResourceLoader.exists(lib_path):
		actor.player.add_animation_library("rig", load(lib_path))
	actor.player.playback_default_blend_time = BLEND
	# scale by the mesh's real height (the rest pose), feet on the floor
	var aabb := AABB()
	var first := true
	for m in actor.body.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var box: AABB = mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	if aabb.size.y > 0.001:
		actor.body.scale = Vector3.ONE * (height / aabb.size.y)
		actor.body.position.y = -aabb.position.y * actor.body.scale.y
	actor.set_state("idle")
	return actor


func has(c: String) -> bool:
	return player.has_animation("rig/" + c)


## Switch to a state; a one-shot (lunge, dead, rise) restarts only when the state changes.
func set_state(s: String, speed := 1.0) -> void:
	if s == state:
		player.speed_scale = speed
		return
	state = s
	var want := ""
	for c in FALLBACK.get(s, ["idle"]):
		if has(c):
			want = c
			break
	if want == "":
		return
	clip = want
	player.speed_scale = speed
	var blend := 0.0 if s == "dead" else (0.06 if s == "lunge" else BLEND)   # the dead were lying already
	player.play("rig/" + want, blend)


## Jump to the last frame of the current clip (a body that was already lying there).
func hold_end() -> void:
	if clip != "":
		player.seek(player.get_animation("rig/" + clip).length, true)
