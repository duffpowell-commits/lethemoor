extends SceneTree
## Run via Godot --path . --script tools/foxboard_proof/compare.gd -- /tmp/foxboard-candidate.glb /tmp/foxboard-evidence
const STATES := ["idle", "walk", "crouch", "lunge", "dead", "down", "rise"]
var world: Node3D
var actors: Array[Node3D] = []
var lib: AnimationLibrary = preload("res://assets/models/rig_nightmare_clips.res")
var camera: Camera3D
var target_dir: String

func _initialize() -> void:
	call_deferred("run")

func make_actor(candidate: bool, path: String) -> Node3D:
	var model: Node3D
	if candidate:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			return null
		model = doc.generate_scene(state)
	else:
		model = (load("res://assets/models/rig_nightmare.glb") as PackedScene).instantiate()
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.get_bone_count() != 24:
		push_error("Expected 24 bones")
		model.free()
		return null
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		model.add_child(player)
	player.add_animation_library("rig", lib)
	print("Skeleton ", "Foxboard" if candidate else "Meshy", " bones=", sk.get_bone_count(), " path=", model.get_path_to(sk))
	return model

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [2, 3]:
		quit(2)
		return
	target_dir = args[1]
	DirAccess.make_dir_recursive_absolute(target_dir)
	root.size = Vector2i(540, 960)
	world = Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#131b22")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8393a7")
	env.environment.ambient_light_energy = 0.35
	world.add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(15, 15)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/art/floor_wet.png")
	mat.uv1_scale = Vector3(8, 8, 1)
	floor_mesh.material_override = mat
	world.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.15, 5.8)
	camera.fov = 48
	world.add_child(camera)
	camera.look_at(Vector3(0,0.95,0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.5, 3.3)
	light.light_color = Color("#ffc88a")
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.shadow_enabled = true
	world.add_child(light)
	for candidate in [false,true]:
		var a := make_actor(candidate,args[0])
		if a == null:
			quit(1)
			return
		world.add_child(a)
		a.position.x = 0.85 if candidate else -0.85
		actors.append(a)
	for state in STATES:
		var clip: String = "dead" if state == "down" else state
		var animation := lib.get_animation(clip)
		var root_span := Vector2.ZERO
		for t in animation.get_track_count():
			if animation.track_get_type(t) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(t)).ends_with(":Hips"):
				var first: Vector3 = animation.track_get_key_value(t, 0)
				for k in animation.track_get_key_count(t):
					var v: Vector3 = animation.track_get_key_value(t, k)
					root_span.x = maxf(root_span.x, absf(v.x-first.x))
					root_span.y = maxf(root_span.y, absf(v.z-first.z))
		print("CLIP ",state," duration=",animation.length," horizontal hip displacement=",root_span)
		for a in actors:
			var ap := a.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var sk := a.find_child("Skeleton3D",true,false) as Skeleton3D
			for t in animation.get_track_count():
				var path := animation.track_get_path(t)
				var bone := String(path.get_concatenated_subnames())
				if bone != "" and sk.find_bone(bone) == -1:
					push_error("unresolved bone " + bone)
					quit(1)
					return
			ap.play("rig/"+clip)
			ap.seek(animation.length if state in ["dead", "down"] else animation.length*0.5, true)
			ap.pause()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(target_dir+"/"+state+".png")
		for a in actors:
			var sk := a.find_child("Skeleton3D",true,false) as Skeleton3D
			print(state," hips=",sk.get_bone_global_pose(sk.find_bone("Hips")).origin," actor=",a.position)
			measure_stretch(a, sk)
		if args.size() == 3 and args[2] == "motion":
			for frame in 9:
				for a in actors:
					var ap := a.find_child("AnimationPlayer", true, false) as AnimationPlayer
					ap.seek(animation.length * float(frame) / 8.0, true)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(target_dir + "/%s_%02d.png" % [state, frame])
	for a in actors:
		a.queue_free()
	await process_frame
	for candidate in [false,true]:
		for count in [1,4,8]:
			actors.clear()
			for i in count:
				var a := make_actor(candidate,args[0])
				world.add_child(a)
				a.position = Vector3((i%4-1.5)*0.8,0,-float(i/4)*1.4)
				var ap := a.find_child("AnimationPlayer",true,false) as AnimationPlayer
				ap.play("rig/walk")
				actors.append(a)
			for i in 10:
				await process_frame
			var start := Time.get_ticks_usec()
			for i in 60:
				await process_frame
			print("BENCHMARK candidate=",candidate," actors=",count," elapsed_ms=",(Time.get_ticks_usec()-start)/1000.0," frames=60")
			for a in actors:
				a.queue_free()
			await process_frame
	quit()


## Edge-length stretch relative to the rest mesh at this sampled pose. Tiny edges
## are excluded; this is a deformation diagnostic, not visual acceptance.
func measure_stretch(a: Node3D, sk: Skeleton3D) -> void:
	var ratios: Array[float] = []
	for obj in a.find_children("*", "MeshInstance3D", true, false):
		var m := obj as MeshInstance3D
		if m.skin == null:
			continue
		var matrices: Array[Transform3D] = []
		var rest_matrices: Array[Transform3D] = []
		for i in m.skin.get_bind_count():
			var bone := m.skin.get_bind_bone(i)
			if bone < 0:
				bone = sk.find_bone(m.skin.get_bind_name(i))
			if bone < 0:
				push_error("unresolved skin bind")
				return
			matrices.append(sk.get_bone_global_pose(bone) * m.skin.get_bind_pose(i))
			rest_matrices.append(sk.get_bone_global_rest(bone) * m.skin.get_bind_pose(i))
		for surface in m.mesh.get_surface_count():
			var arrays := m.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var posed := PackedVector3Array()
			posed.resize(verts.size())
			var rest_verts := PackedVector3Array()
			rest_verts.resize(verts.size())
			var influences := ids.size() / verts.size()
			for v in verts.size():
				for j in influences:
					var idx := v * influences + j
					posed[v] += (matrices[ids[idx]] * verts[v]) * weights[idx]
					rest_verts[v] += (rest_matrices[ids[idx]] * verts[v]) * weights[idx]
			for i in range(0, indices.size(), 3):
				for edge in 3:
					var x := indices[i + edge]
					var y := indices[i + (edge + 1) % 3]
					var rest := rest_verts[x].distance_to(rest_verts[y])
					if verts[x].distance_to(verts[y]) > 0.01 and rest > 0.0001:
						ratios.append(posed[x].distance_to(posed[y]) / rest)
	if not ratios.is_empty():
		ratios.sort()
		print("STRETCH edges=",ratios.size()," p05=",ratios[int(ratios.size()*0.05)]," p95=",ratios[int(ratios.size()*0.95)]," max=",ratios.back())
