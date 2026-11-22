extends Node3D
## Modular wall-kit visual test. Reusable wall segments, corners and door openings.
## 1 world unit ~= 1 grid tile. Standalone art prototype; no gameplay dependencies.

const HEIGHT := 2.4
const THICKNESS := 0.22
const COURSE_HEIGHT := 0.38
const BLOCK_LENGTH := 0.48

var stone: StandardMaterial3D
var dark: StandardMaterial3D
var cap: StandardMaterial3D

func _ready() -> void:
	_make_materials()
	_build_demo()

func _mat(c: Color, r: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	return m

func _make_materials() -> void:
	stone = _mat(Color(0.27, 0.29, 0.33), 0.92)
	dark = _mat(Color(0.16, 0.18, 0.21), 0.95)
	cap = _mat(Color(0.22, 0.23, 0.25), 0.88)

func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

func make_straight_wall(parent: Node3D, origin: Vector3, length: float = 2.0) -> Node3D:
	var module := Node3D.new()
	module.name = "WallStraight_%0.1fm" % length
	module.position = origin
	parent.add_child(module)
	_box(module, "WallCore", Vector3(THICKNESS, HEIGHT, length), Vector3(0, HEIGHT / 2, 0), stone)
	_box(module, "Coping", Vector3(THICKNESS + 0.12, 0.14, length + 0.08), Vector3(0, HEIGHT + 0.07, 0), cap)
	# Surface relief is staggered; face pieces stay shallow to keep the silhouette modular.
	for face in [-1, 1]:
		for row in range(6):
			var y := 0.22 + row * COURSE_HEIGHT
			var blocks := int(ceil(length / BLOCK_LENGTH))
			for b in range(blocks):
				var z := -length / 2 + BLOCK_LENGTH / 2 + b * BLOCK_LENGTH
				if row % 2 == 1:
					z += BLOCK_LENGTH / 2
				if z > length / 2 - 0.08 or z < -length / 2 + 0.08:
					continue
				var block_mat: Material = dark if (row + b) % 5 == 0 else stone
				_box(module, "FaceBlock_%d_%d_%d" % [face, row, b],
					Vector3(0.035, COURSE_HEIGHT - 0.035, BLOCK_LENGTH - 0.035),
					Vector3(face * (THICKNESS / 2 + 0.02), y, z), block_mat)
	return module

func make_corner(parent: Node3D, origin: Vector3, inner: bool = true) -> Node3D:
	# Two wall runs meet at a corner without their cores occupying the same space.
	var node := Node3D.new()
	node.name = "CornerInner" if inner else "CornerOuter"
	node.position = origin
	parent.add_child(node)
	var half := THICKNESS / 2
	make_straight_wall(node, Vector3(0, 0, -0.5), 1.0)
	var perpendicular := make_straight_wall(node, Vector3(0.5 + half, 0, 0), 1.0)
	perpendicular.rotation.y = PI / 2
	return node

func make_doorway(parent: Node3D, origin: Vector3, opening_width: float = 1.0, total_width: float = 2.0) -> Node3D:
	var node := Node3D.new()
	node.name = "WallDoorway_%0.1m" % opening_width
	node.position = origin
	parent.add_child(node)
	var side_width := (total_width - opening_width) / 2.0
	if side_width <= 0.05:
		push_warning("Doorway requires enough width for two piers.")
		return node
	var pier_center := opening_width / 2.0 + side_width / 2.0
	_box(node, "LeftPier", Vector3(THICKNESS, HEIGHT, side_width),
		Vector3(0, HEIGHT / 2, -pier_center), stone)
	_box(node, "RightPier", Vector3(THICKNESS, HEIGHT, side_width),
		Vector3(0, HEIGHT / 2, pier_center), stone)
	_box(node, "Lintel", Vector3(THICKNESS, 0.42, total_width),
		Vector3(0, HEIGHT - 0.21, 0), cap)
	for side in [-1, 1]:
		_box(node, "PierCap_%d" % side, Vector3(THICKNESS + 0.10, 0.14, side_width + 0.05),
			Vector3(0, HEIGHT + 0.07, side * pier_center), cap)
	return node

func _build_demo() -> void:
	# A short wall, a doorway module, and an independent corner sample.
	make_straight_wall(self, Vector3(-1.65, 0, -2.0), 2.0)
	make_doorway(self, Vector3(0, 0, -2.0), 1.0, 2.0)
	make_straight_wall(self, Vector3(1.65, 0, -2.0), 2.0)
	make_corner(self, Vector3(-2.6, 0, 1.0), true)

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(7, 0.1, 6)
	var floor_node := MeshInstance3D.new()
	floor_node.name = "Floor"
	floor_node.mesh = floor_mesh
	floor_node.position = Vector3(0, -0.05, -1)
	floor_node.material_override = dark
	add_child(floor_node)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.3, 5.6)
	camera.rotation_degrees = Vector3(-17, 0, 0)
	camera.current = true
	add_child(camera)

	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.035, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.15, 0.17, 0.2)
	environment.ambient_light_energy = 0.5
	env_node.environment = environment
	add_child(env_node)
