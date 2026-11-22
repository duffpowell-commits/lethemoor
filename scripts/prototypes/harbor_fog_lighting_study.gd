extends Node3D
## Isolated lighting/fog study. No gameplay systems or main-scene dependencies.

func _ready() -> void:
	_build_environment()
	_build_geometry()
	_build_lights()
	_build_camera()

func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(label: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	add_child(node)

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.21, 0.25)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.16, 0.21)
	env.fog_density = 0.035
	env.fog_sky_affect = 0.0
	env.fog_height = 0.0
	env.fog_height_density = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

func _build_geometry() -> void:
	var stone := _material(Color(0.28, 0.30, 0.34))
	var floor_mat := _material(Color(0.14, 0.17, 0.20))
	var dark := _material(Color(0.08, 0.10, 0.12))
	_box("Ground", Vector3(4, 0.12, 10), Vector3(0, -0.06, -5), floor_mat)
	for side in [-1, 1]:
		_box("Wall", Vector3(0.22, 2.4, 10), Vector3(side*1.32, 1.2, -5), stone)
	for z in [-2.0, -4.0, -6.0, -8.0]:
		_box("DepthMarker", Vector3(0.5, 1.2, 0.3), Vector3(0, 0.6, z), dark)

func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -20, 0)
	key.light_color = Color(0.58, 0.65, 0.78)
	key.light_energy = 0.45
	add_child(key)
	for z in [-2.5, -5.5, -8.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(1.05, 1.9, z)
		light.light_color = Color(1.0, 0.65, 0.34)
		light.light_energy = 1.1 if z == -2.5 else 0.55
		light.omni_range = 3.2 if z == -2.5 else 2.4
		add_child(light)

func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.65, 0.6)
	camera.rotation_degrees = Vector3(-3, 0, 0)
	camera.fov = 70
	camera.current = true
	add_child(camera)
