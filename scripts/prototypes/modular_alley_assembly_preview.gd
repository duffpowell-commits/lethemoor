extends Node3D
## Modular alley assembly proof. One rig, shared coordinate space.
## Preview only; isolated from gameplay scenes.

const WALL_H := 2.4
const WALL_T := 0.24
const MODULE_LEN := 2.0

func _ready() -> void:
	assemble()

func mat(color: Color, roughness := 0.88) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func wall_segment(parent: Node3D, x: float, z: float, length: float, stone: Material, trim: Material) -> void:
	box(parent, "Wall core", Vector3(WALL_T, WALL_H, length), Vector3(x, WALL_H * 0.5, z), stone)
	box(parent, "Coping", Vector3(WALL_T + 0.12, 0.16, length + 0.08), Vector3(x, WALL_H + 0.08, z), trim)
	# Simple face relief, staggered across two sides; use shared material.
	for side in [-1.0, 1.0]:
		for row in range(6):
			for index in range(int(length / 0.55)):
				var offset := -length * 0.5 + 0.28 + index * 0.55
				if row % 2 == 1:
					offset += 0.25
				if abs(offset) > length * 0.5 - 0.08:
					continue
				box(parent, "Stone relief", Vector3(0.035, 0.32, 0.48),
					Vector3(x + side * (WALL_T * 0.5 + 0.02), 0.28 + row * 0.38, z + offset), stone)

func assemble() -> void:
	var stone := mat(Color(0.29, 0.31, 0.34))
	var trim := mat(Color(0.20, 0.22, 0.25))
	var ground := mat(Color(0.11, 0.14, 0.17), 0.72)
	var wood := mat(Color(0.20, 0.14, 0.10))
	var iron := mat(Color(0.12, 0.14, 0.16), 0.7)
	var glow := mat(Color(0.95, 0.54, 0.24), 0.45)

	box(self, "Unified floor", Vector3(3.6, 0.12, 8.0), Vector3(0, -0.06, -3.5), ground)
	# Modular runs: leave a gap in the right wall for a side entrance.
	for i in range(4):
		var z := -1.0 - i * 2.0
		wall_segment(self, -1.95, z, MODULE_LEN, stone, trim)
		if i != 1:
			wall_segment(self, 1.95, z, MODULE_LEN, stone, trim)
	# Far arch-like portal assembled from independent pier/lintel pieces.
	box(self, "Far left pier", Vector3(0.32, WALL_H, 0.32), Vector3(-0.9, 1.2, -7.3), trim)
	box(self, "Far right pier", Vector3(0.32, WALL_H, 0.32), Vector3(0.9, 1.2, -7.3), trim)
	box(self, "Far lintel", Vector3(2.1, 0.35, 0.38), Vector3(0, 2.2, -7.3), trim)
	# Sparse story props, placed against edges to preserve the path.
	box(self, "Crate", Vector3(0.65, 0.65, 0.65), Vector3(1.3, 0.325, -1.0), wood)
	box(self, "Bollard", Vector3(0.25, 0.85, 0.25), Vector3(-1.25, 0.425, -4.4), iron)
	# Wall-mounted lantern and point light.
	box(self, "Lantern bracket", Vector3(0.45, 0.08, 0.08), Vector3(-1.65, 2.15, -3.0), iron)
	box(self, "Lantern body", Vector3(0.26, 0.38, 0.26), Vector3(-1.42, 2.0, -3.0), iron)
	box(self, "Lantern glass", Vector3(0.14, 0.24, 0.04), Vector3(-1.42, 2.0, -3.15), glow)
	var light := OmniLight3D.new()
	light.position = Vector3(-1.42, 2.0, -3.0)
	light.light_color = Color(1.0, 0.62, 0.34)
	light.light_energy = 1.2
	light.omni_range = 4.0
	add_child(light)
	# Silhouette only: simple faceless placeholder at the portal.
	var enemy := Node3D.new()
	enemy.name = "Thrall placeholder"
	enemy.position = Vector3(0, 0, -6.0)
	add_child(enemy)
	box(enemy, "Coat", Vector3(0.5, 1.2, 0.36), Vector3(0, 0.9, 0), trim)
	box(enemy, "Hood", Vector3(0.42, 0.44, 0.42), Vector3(0, 1.65, -0.02), trim)
	box(enemy, "Void face", Vector3(0.24, 0.22, 0.04), Vector3(0, 1.63, -0.24), ground)
	for side in [-1.0, 1.0]:
		box(enemy, "Leg", Vector3(0.16, 0.65, 0.18), Vector3(side * 0.15, 0.32, 0), trim)
		box(enemy, "Arm", Vector3(0.15, 0.78, 0.18), Vector3(side * 0.34, 0.9, 0.03), trim)
	# Shared preview rig.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -25, 0)
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.18, 0.21)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.13, 0.16, 0.19)
	env.fog_density = 0.035
	world.environment = env
	add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.65, 1.8)
	camera.rotation_degrees = Vector3(-5, 0, 0)
	camera.current = true
	add_child(camera)
