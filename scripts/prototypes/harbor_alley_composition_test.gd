extends Node3D
## Unified alley composition test. One root, one floor, one camera/environment.
## Geometry is intentionally simple and isolated from gameplay systems.

const WALL_H := 2.4
const WALL_T := 0.22
const ALLEY_W := 2.4
const ALLEY_L := 8.0

func _ready() -> void:
	_build_ground()
	_build_walls()
	_build_lantern()
	_build_far_silhouette()
	_build_camera_rig()

func _mat(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	add_child(instance)
	return instance

func _build_ground() -> void:
	_box("UnifiedGround", Vector3(4.0, 0.12, ALLEY_L), Vector3(0, -0.06, -ALLEY_L/2), _mat(Color(0.17, 0.19, 0.22)))

func _build_walls() -> void:
	var stone := _mat(Color(0.28, 0.30, 0.34))
	var dark := _mat(Color(0.20, 0.22, 0.25))
	var cap := _mat(Color(0.23, 0.24, 0.27))
	# Left wall broken by an opening near the far end.
	_box("LeftWallFront", Vector3(WALL_T, WALL_H, 4.7), Vector3(-ALLEY_W/2-WALL_T/2, WALL_H/2, -1.65), stone)
	_box("LeftWallRear", Vector3(WALL_T, WALL_H, 2.1), Vector3(-ALLEY_W/2-WALL_T/2, WALL_H/2, -6.95), stone)
	_box("LeftWallOpeningLintel", Vector3(WALL_T, 0.45, 1.0), Vector3(-ALLEY_W/2-WALL_T/2, WALL_H-0.225, -5.9), cap)
	_box("RightWall", Vector3(WALL_T, WALL_H, ALLEY_L), Vector3(ALLEY_W/2+WALL_T/2, WALL_H/2, -ALLEY_L/2), stone)
	# Simplified inset block relief; restrained density for silhouette readability.
	for side in [-1, 1]:
		var x := side * (ALLEY_W/2 + WALL_T/2)
		for row in range(5):
			for col in range(12):
				var z := -0.35 - col * 0.62
				if side == -1 and z > -5.35 and z < -6.45:
					continue
				var relief := Vector3(0.045, 0.34, 0.56)
				var shade := dark if (row + col) % 6 == 0 else stone
				_box("MasonryRelief", relief, Vector3(x + side*0.13, 0.25 + row*0.43, z), shade)

func _build_lantern() -> void:
	var metal := _mat(Color(0.12, 0.14, 0.16))
	var glow := _mat(Color(1.0, 0.68, 0.30), 0.3)
	var x := ALLEY_W/2 + 0.05
	var z := -5.2
	_box("LanternBracket", Vector3(0.12, 0.08, 0.65), Vector3(x-0.12, 1.9, z), metal)
	_box("LanternBody", Vector3(0.26, 0.34, 0.26), Vector3(x-0.32, 1.72, z), glow)
	var light := OmniLight3D.new()
	light.position = Vector3(x-0.32, 1.72, z)
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 1.8
	light.omni_range = 4.2
	light.omni_attenuation = 1.2
	add_child(light)

func _build_far_silhouette() -> void:
	var body := _mat(Color(0.09, 0.10, 0.12))
	_box("ThrallBodyStudy", Vector3(0.55, 1.45, 0.36), Vector3(0.1, 0.75, -7.15), body)
	_box("ThrallHeadStudy", Vector3(0.32, 0.34, 0.32), Vector3(0.1, 1.66, -7.15), body)

func _build_camera_rig() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_energy = 0.55
	env_node.environment = env
	add_child(env_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -24, 0)
	key.light_color = Color(0.62, 0.68, 0.78)
	key.light_energy = 0.65
	add_child(key)
	var camera := Camera3D.new()
	camera.name = "CompositionCamera"
	camera.position = Vector3(0, 1.65, 0.6)
	camera.rotation_degrees = Vector3(-3, 0, 0)
	camera.fov = 70
	camera.current = true
	add_child(camera)
