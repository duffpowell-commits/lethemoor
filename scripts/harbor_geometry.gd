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
	# the iron yoke stays on the wall; the bell hangs from it on its own node ("Body", pivot at the
	# yoke) so it can swing when you ring it (gap pass, Nov 26: the old one was a stack of cones)
	var iron := _surface()
	_box(iron, Vector3(0.60, 0.15, 0.16), Vector3(-0.23, 2.26, 0))
	var yoke := iron.commit()
	yoke.surface_set_material(0, _metal(Color("#353b40")))
	var frame := _fixture("HarborBell", yoke)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.position = Vector3(0, BELL_PIVOT, 0)
	body.mesh = bell_body()
	frame.add_child(body)
	return frame


const BELL_PIVOT := 2.2
## A bell's real section, turned on a lathe: crown, shoulder, waist, the thick sound-bow and the
## flared lip, outside then back up the inside. (radius, height above the floor)
const BELL_PROFILE := [
	Vector2(0.0, 1.84), Vector2(0.15, 1.84), Vector2(0.2, 1.80), Vector2(0.225, 1.72),
	Vector2(0.235, 1.6), Vector2(0.245, 1.46), Vector2(0.265, 1.32), Vector2(0.3, 1.2),
	Vector2(0.36, 1.1), Vector2(0.42, 1.035), Vector2(0.455, 1.0), Vector2(0.45, 0.975),
	Vector2(0.4, 0.98), Vector2(0.34, 1.04), Vector2(0.27, 1.17), Vector2(0.22, 1.36),
	Vector2(0.2, 1.56), Vector2(0.17, 1.72), Vector2(0.0, 1.76),
]
const BELL_SIDES := 28


## The bronze bell (lathe), with its iron hanger and clapper, origin at the pivot.
static func bell_body() -> ArrayMesh:
	var bronze := _surface()
	var lift := Vector3(0, -BELL_PIVOT, 0)
	for k in BELL_PROFILE.size() - 1:
		var a: Vector2 = BELL_PROFILE[k]
		var b: Vector2 = BELL_PROFILE[k + 1]
		for j in BELL_SIDES:
			var t0 := TAU * j / BELL_SIDES
			var t1 := TAU * (j + 1) / BELL_SIDES
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x) + lift
			var p01 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x) + lift
			var p10 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x) + lift
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x) + lift
			for v in [p00, p01, p11, p00, p11, p10]:
				bronze.add_vertex(v)
	bronze.generate_normals()
	var mesh := bronze.commit()
	var mat := _metal(Color("#9a6d3c"))
	mat.metallic = 0.55
	mat.roughness = 0.42
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # open mouth: you see in under the lip
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.6
	mesh.surface_set_material(0, mat)
	var iron := _surface()
	var hang := CylinderMesh.new()
	hang.top_radius = 0.04
	hang.bottom_radius = 0.05
	hang.height = BELL_PIVOT - 1.82
	hang.radial_segments = 10
	hang.rings = 0
	iron.append_from(hang, 0, Transform3D(Basis.IDENTITY, Vector3(0, (1.82 - BELL_PIVOT) * 0.5, 0)))
	var rod := CylinderMesh.new()
	rod.top_radius = 0.018
	rod.bottom_radius = 0.018
	rod.height = 0.62
	rod.radial_segments = 8
	rod.rings = 0
	iron.append_from(rod, 0, Transform3D(Basis.IDENTITY, Vector3(0, 1.42 - BELL_PIVOT, 0)))
	var ball := SphereMesh.new()
	ball.radius = 0.075
	ball.height = 0.15
	ball.radial_segments = 12
	ball.rings = 6
	iron.append_from(ball, 0, Transform3D(Basis.IDENTITY, Vector3(0, 1.09 - BELL_PIVOT, 0)))
	iron.commit(mesh)
	mesh.surface_set_material(1, _metal(Color("#353b40")))
	return mesh


## The bell tower: a stone shaft rising from the wall behind the bell, rising far over the ward walls
## (2.4) with an open belfry and a dim lamp in it, so you can steer by it from anywhere.
## No fog on it: a black shape against the clouds, like a church over rooftops.
static func bell_tower() -> MeshInstance3D:
	var stone := _surface()
	_box(stone, Vector3(0.9, 3.53, 0.9), Vector3(0, 3.865, 0))        # the shaft, from 2.1 up (inside even a ruined wall's top):
	                                                                    # the wall below keeps its own stone and fog
	_box(stone, Vector3(1.12, 0.14, 1.12), Vector3(0, 5.67, 0))       # belfry floor ledge
	for x in [-0.48, 0.48]:
		for z in [-0.48, 0.48]:
			_box(stone, Vector3(0.16, 1.3, 0.16), Vector3(x, 6.39, z))  # four corner posts
	_box(stone, Vector3(1.2, 0.16, 1.2), Vector3(0, 7.12, 0))         # cornice
	for i in 5:                                                         # stepped spire
		var w := 0.95 - i * 0.18
		_box(stone, Vector3(w, 0.32, w), Vector3(0, 7.36 + i * 0.32, 0))
	_box(stone, Vector3(0.05, 0.7, 0.05), Vector3(0, 9.3, 0))         # iron finial
	var mesh := stone.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#11141a")
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.disable_fog = true
	mesh.surface_set_material(0, mat)
	var lamp := _surface()
	_box(lamp, Vector3(0.22, 0.3, 0.22), Vector3(0, 6.05, 0))
	lamp.commit(mesh)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.85, 0.55, 0.25)
	glow.disable_fog = true
	mesh.surface_set_material(1, glow)
	var tower := _fixture("BellTower", mesh)
	tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tower


## Landmarks for the open halls of a ward, so one maze corner doesn't look like the next.
## Each stands against a wall (local -z faces the wall), low enough not to hide a horror.
static func landmark(kind: String, shifted := false) -> MeshInstance3D:
	var wood := _surface()
	var mesh: ArrayMesh
	match kind:
		"boat":      # a rowing boat upturned along the wall, keel up, bow and stern drawn in
			for i in 4:
				var l := 1.5 - i * 0.22
				var w := 0.7 - i * 0.14
				_box(wood, Vector3(l, 0.1, w), Vector3(0, 0.05 + i * 0.1, -0.12))
				for side in [-1.0, 1.0]:   # the narrowing ends
					_box(wood, Vector3(0.16, 0.1, w * 0.55), Vector3(side * (l * 0.5 + 0.08), 0.05 + i * 0.1, -0.12))
			_box(wood, Vector3(1.9, 0.07, 0.06), Vector3(0, 0.43, -0.12))   # the keel
			_box(wood, Vector3(1.2, 0.04, 0.09), Vector3(0.1, 0.03, 0.36), Transform3D(Basis(Vector3.UP, 0.25), Vector3.ZERO))   # an oar
		"door":      # a door in the wall that goes nowhere, iron-banded, shut
			_box(wood, Vector3(0.8, 2.0, 0.06), Vector3(0, 1.0, -0.47))
			_box(wood, Vector3(0.12, 2.15, 0.1), Vector3(-0.46, 1.07, -0.46))
			_box(wood, Vector3(0.12, 2.15, 0.1), Vector3(0.46, 1.07, -0.46))
			_box(wood, Vector3(1.04, 0.14, 0.1), Vector3(0, 2.15, -0.46))
			for y in [0.45, 1.55]:
				_box(wood, Vector3(0.74, 0.05, 0.03), Vector3(0, y, -0.43))
			_box(wood, Vector3(0.06, 0.06, 0.06), Vector3(0.28, 1.0, -0.42))   # the ring
		_:           # lobster pots and a crate, stacked against the wall
			_box(wood, Vector3(0.5, 0.42, 0.5), Vector3(-0.22, 0.21, -0.2))
			_box(wood, Vector3(0.46, 0.4, 0.46), Vector3(0.3, 0.2, -0.22))
			_box(wood, Vector3(0.44, 0.38, 0.44), Vector3(-0.09 if shifted else 0.02, 0.61, -0.24), Transform3D(Basis(Vector3.UP, -0.28 if shifted else 0.3), Vector3.ZERO))
	mesh = wood.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#2e241b") if kind != "pots" else Color("#33291e")
	mat.roughness = 0.95
	mat.metallic_specular = 0.1
	mesh.surface_set_material(0, mat)
	return _fixture("Landmark_" + kind, mesh)


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
