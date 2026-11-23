extends RefCounted
## Player-scale modules adapted from the masonry and prop studies in PR #36.
## Modules share meshes. All relief stays inside solid cells, clear of the grid lanes.

const CARDINALS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BOX := preload("res://assets/geometry/harbor_unit_box.tres")

var walls := {}
var floor_stone: ArrayMesh
var bell_steps: ArrayMesh
var dock: ArrayMesh
var lintel: ArrayMesh


func _init() -> void:
	var slabs := _surface()
	_box(slabs, Vector3(1, 0.12, 1), Vector3(0, -0.082, 0))
	for x in [-0.25, 0.25]:
		_box(slabs, Vector3(0.494, 0.06, 0.99), Vector3(x, -0.03, 0))
	floor_stone = slabs.commit()

	var steps := _surface()
	_box(steps, Vector3(1, 0.12, 1), Vector3(0, -0.06, 0))
	_box(steps, Vector3(0.84, 0.06, 0.84), Vector3(0, 0.03, 0))
	_box(steps, Vector3(0.68, 0.06, 0.68), Vector3(0, 0.09, 0))
	bell_steps = steps.commit()

	var boards := _surface()
	_box(boards, Vector3(1, 0.12, 1), Vector3(0, -0.086, 0))
	for i in 5:
		_box(boards, Vector3(0.187, 0.06, 1), Vector3(-0.4 + i * 0.2, -0.03, 0))
	# Two recessed nail heads at the ends of each board, clear of the walking surface.
	for i in 5:
		for z in [-0.43, 0.43]:
			_box(boards, Vector3(0.019, 0.005, 0.019), Vector3(-0.4 + i * 0.2, 0, z))
	dock = boards.commit()

	var arch := _surface()
	_box(arch, Vector3(1, 0.19, 0.22), Vector3(0, 2.31, 0))
	for side in [-1.0, 1.0]:
		_box(arch, Vector3(0.13, 0.15, 0.2), Vector3(side * 0.435, 2.15, 0))
	lintel = arch.commit()


func wall_for(room, cell: Vector2i) -> ArrayMesh:
	var sides := 0
	for i in CARDINALS.size():
		if not room.is_wall(cell + CARDINALS[i]):
			sides |= 1 << i
	var ruined := posmod(cell.x * 7 + cell.y * 11, 13) == 0
	var key := sides + (16 if ruined else 0)
	if walls.has(key):
		return walls[key]

	var surface := _surface()
	var height := 2.16 if ruined else 2.4
	var west := -0.46 if sides & 8 else -0.5
	var east := 0.46 if sides & 2 else 0.5
	var north := -0.46 if sides & 1 else -0.5
	var south := 0.46 if sides & 4 else 0.5
	_box(surface, Vector3(east - west, height - 0.11, south - north),
		Vector3((east + west) * 0.5, (height - 0.11) * 0.5, (north + south) * 0.5))
	for i in CARDINALS.size():
		if not sides & (1 << i):
			continue
		var turn := Transform3D(Basis(Vector3.UP, -i * PI / 2.0), Vector3.ZERO)
		_box(surface, Vector3(0.96, 0.18, 0.06), Vector3(0, 0.09, -0.468), turn)
		for row in (5 if ruined else 6):
			var y := 0.33 + row * 0.35
			var split := -0.16 if row % 2 == 0 else 0.14
			var offset := 0.004 * (row % 3)
			_box(surface, Vector3(0.482 + split, 0.316, 0.05), Vector3((split - 0.49) * 0.5, y, -0.467 - offset), turn)
			_box(surface, Vector3(0.482 - split, 0.324, 0.05), Vector3((split + 0.49) * 0.5, y + 0.004, -0.463), turn)
	# The cap is textured on all faces. Broken walls retain an uneven row of coping stones.
	for i in 3:
		var rise := (0.1 if i == 0 else 0.0) if ruined else 0.0
		_box(surface, Vector3(0.326, 0.13 + rise, 0.992), Vector3((i - 1) * 0.331, height - 0.055 + rise * 0.5, 0))

	if ruined:
		_box(surface, Vector3(0.2, 0.075, 0.23), Vector3(0.27, height + 0.047, 0.28))
		_box(surface, Vector3(0.13, 0.05, 0.18), Vector3(0.01, height + 0.035, -0.29))
	var mesh := surface.commit()
	walls[key] = mesh
	return mesh


static func lamp_mesh() -> ArrayMesh:
	var iron := _surface()
	_cylinder(iron, 0.1, 0.15, 0.12, 0.06)
	_cylinder(iron, 0.036, 0.057, 1.92, 1.02)
	_cylinder(iron, 0.15, 0.046, 0.12, 2.02)
	_cylinder(iron, 0.025, 0.18, 0.17, 2.39)
	for x in [-0.104, 0.104]:
		for z in [-0.104, 0.104]:
			_box(iron, Vector3(0.025, 0.28, 0.025), Vector3(x, 2.2, z))
	var mesh := iron.commit()
	mesh.surface_set_material(0, _metal(Color("#3b4143")))
	var panes := _surface()
	_box(panes, Vector3(0.187, 0.25, 0.187), Vector3(0, 2.2, 0))
	panes.commit(mesh)
	mesh.surface_set_material(1, _metal(Color("#57533d")))
	return mesh


static func bell() -> MeshInstance3D:
	var bronze := _surface()
	_cylinder(bronze, 0.17, 0.32, 0.48, 1.44)
	_cylinder(bronze, 0.32, 0.42, 0.12, 1.14)
	_cylinder(bronze, 0.42, 0.43, 0.054, 1.054)
	_cylinder(bronze, 0.115, 0.17, 0.12, 1.73)
	var mesh := bronze.commit()
	mesh.surface_set_material(0, _metal(Color("#8d643b")))
	var iron := _surface()
	_box(iron, Vector3(0.60, 0.15, 0.16), Vector3(-0.23, 2.26, 0))
	_cylinder(iron, 0.037, 0.05, 0.5, 1.99)
	_cylinder(iron, 0.025, 0.085, 0.14, 0.99)
	iron.commit(mesh)
	mesh.surface_set_material(1, _metal(Color("#353b40")))
	return _fixture("HarborBell", mesh)


static func _fixture(label: String, mesh: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	return instance


static func _metal(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.63
	mat.metallic = 0.22
	return mat


static func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


static func _box(surface: SurfaceTool, size: Vector3, pos: Vector3, rotation := Transform3D.IDENTITY) -> void:
	surface.append_from(BOX, 0, rotation * Transform3D(Basis.from_scale(size), pos))


static func _cylinder(surface: SurfaceTool, top: float, bottom: float, height: float, y: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 0
	surface.append_from(mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
