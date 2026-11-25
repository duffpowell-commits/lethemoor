extends SceneTree
## Bakes Meshy clip GLBs into one AnimationLibrary per horror, so the game ships one rigged mesh
## plus small clip data instead of a full mesh copy per clip.
## Clip GLBs go in tools/clips_src/<who>_<clip>.glb (not in git; copies live in the project files
## folder lethemoor-3d/meshy_source/). Clip names the game uses: idle, walk, crouch, lunge, dead, rise
## (scripts/rig_horror.gd). Run:
##   godot --headless --path . --import && godot --headless --path . --script tools/bake_clips.gd -- <who> [...]
## tools/clips_src has a .gdignore, so the importer skips it; this script loads the GLBs itself.

const LOOPS := ["idle", "walk", "walking", "crouch"]
const SRC := "res://tools/clips_src/"


func _initialize() -> void:
	for who in OS.get_cmdline_user_args():
		var lib := AnimationLibrary.new()
		for file in DirAccess.get_files_at(SRC):
			if not file.begins_with(who + "_") or not file.ends_with(".glb"):
				continue
			var clip := file.get_basename().trim_prefix(who + "_")
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(ProjectSettings.globalize_path(SRC + file), state) != OK:
				push_error("can't read " + file)
				continue
			var scene: Node = doc.generate_scene(state)
			var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if player == null or player.get_animation_list().is_empty():
				push_error("no clip in " + file)
				scene.free()
				continue
			var anim := player.get_animation(player.get_animation_list()[0]).duplicate(true) as Animation
			anim.loop_mode = Animation.LOOP_LINEAR if clip in LOOPS else Animation.LOOP_NONE
			if clip not in ["dead", "rise"]:   # a fall travels; let it
				_pin_hips(anim)
			lib.add_animation(clip, anim)
			print("%s %s %.2fs tracks=%d" % [who, clip, anim.length, anim.get_track_count()])
			scene.free()
		var out := "res://assets/models/%s_clips.res" % who
		ResourceSaver.save(lib, out)
		print("saved ", out)
	quit()


## Keep clips in place: the grid moves the body. Hips may bob but not travel.
func _pin_hips(anim: Animation) -> void:
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not str(anim.track_get_path(t)).ends_with(":Hips"):
			continue
		var first: Vector3 = anim.track_get_key_value(t, 0)
		for k in anim.track_get_key_count(t):
			var v: Vector3 = anim.track_get_key_value(t, k)
			anim.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))
