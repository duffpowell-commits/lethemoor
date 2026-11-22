extends Node3D
## Procedural harbor prop kit study: timber braces, bollard, crate and lantern post.
## Standalone visual prototype; no gameplay dependencies.

func _ready() -> void:
	_build()

func _mat(color: Color, rough: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func _box(parent: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	n.position = pos
	n.rotation = rot
	n.material_override = mat
	parent.add_child(n)
	return n

func _cylinder(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	n.position = pos
	n.material_override = mat
	parent.add_child(n)
	return n

func _build() -> void:
	var wood := _mat(Color(0.19,0.12,0.075))
	var worn := _mat(Color(0.28,0.19,0.12))
	var iron := _mat(Color(0.12,0.14,0.16),0.7,0.65)
	var glass := _mat(Color(0.12,0.18,0.21),0.3)
	var ground := _mat(Color(0.12,0.14,0.17))

	# Timber wall brace assembly.
	var brace := Node3D.new()
	brace.name = "TimberBrace"
	brace.position = Vector3(-2.0,0,0)
	add_child(brace)
	_box(brace,"Main post",Vector3(0.18,2.4,0.18),Vector3(0,1.2,0),wood)
	_box(brace,"Cross beam",Vector3(2.0,0.18,0.18),Vector3(0,2.1,0),worn)
	_box(brace,"Diagonal brace",Vector3(0.14,1.7,0.14),Vector3(0.55,1.25,0),worn,Vector3(0,0,-0.68))
	_box(brace,"Foot block",Vector3(0.28,0.25,0.28),Vector3(0,0.13,0),iron)

	# Mooring bollard with weathered iron cap.
	var bollard := Node3D.new()
	bollard.name = "MooringBollard"
	bollard.position = Vector3(0,0,0)
	add_child(bollard)
	_cylinder(bollard,"Wooden bollard",0.16,0.85,Vector3(0,0.43,0),wood)
	_cylinder(bollard,"Iron top",0.20,0.12,Vector3(0,0.86,0),iron)
	_box(bollard,"Cross cleat",Vector3(0.55,0.12,0.12),Vector3(0,0.72,0),worn)

	# Compact wooden crate, visibly slatted.
	var crate := Node3D.new()
	crate.name = "Crate"
	crate.position = Vector3(1.5,0,0)
	add_child(crate)
	for row in range(4):
		_box(crate,"Front slat %d" % row,Vector3(0.75,0.13,0.06),Vector3(0,0.12+row*0.16,-0.36),worn)
		_box(crate,"Side slat %d" % row,Vector3(0.06,0.13,0.75),Vector3(0.36,0.12+row*0.16,0),wood)
	_box(crate,"Top plank A",Vector3(0.75,0.08,0.22),Vector3(0,0.70,-0.22),wood)
	_box(crate,"Top plank B",Vector3(0.75,0.08,0.22),Vector3(0,0.70,0),worn)
	_box(crate,"Top plank C",Vector3(0.75,0.08,0.22),Vector3(0,0.70,0.22),wood)

	# Lantern fixture: dark frame and non-emissive glass; gameplay lights remain separate.
	var lantern := Node3D.new()
	lantern.name = "LanternPost"
	lantern.position = Vector3(3.0,0,0)
	add_child(lantern)
	_cylinder(lantern,"Post",0.08,2.6,Vector3(0,1.3,0),wood)
	_box(lantern,"Bracket",Vector3(0.65,0.08,0.08),Vector3(0.28,2.35,0),iron)
	_box(lantern,"Lantern housing",Vector3(0.32,0.42,0.32),Vector3(0.58,2.12,0),iron)
	_box(lantern,"Glass front",Vector3(0.18,0.25,0.03),Vector3(0.58,2.12,-0.17),glass)
	_box(lantern,"Roof",Vector3(0.42,0.09,0.42),Vector3(0.58,2.38,0),worn)
	_box(lantern,"Base",Vector3(0.25,0.22,0.25),Vector3(0,0.11,0),iron)

	var floor := MeshInstance3D.new()
	floor.name = "DisplayFloor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(8,0.12,3.5)
	floor.mesh = floor_mesh
	floor.position = Vector3(0,-0.06,0)
	floor.material_override = ground
	add_child(floor)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42,-25,0)
	light.light_energy = 1.2
	add_child(light)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025,0.035,0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16,0.18,0.21)
	env.ambient_light_energy = 0.55
	env_node.environment = env
	add_child(env_node)
	var cam := Camera3D.new()
	cam.position = Vector3(5.5,3.8,7.0)
	cam.look_at(Vector3(0,1.1,0),Vector3.UP)
	cam.current = true
	cam.fov = 48
	add_child(cam)
