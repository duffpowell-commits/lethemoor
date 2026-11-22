extends Node3D
## Reusable, camera-free harbor prop geometry. Instantiate the functions' returned nodes
## under a parent transform; materials are intentionally local and easy to replace.

static func make_crate() -> Node3D:
	var root := Node3D.new()
	root.name = "HarborCrate"
	var wood := _mat(Color(0.30, 0.20, 0.12))
	var edge := _mat(Color(0.38, 0.25, 0.14))
	var base := _box("CrateCore", Vector3(0.78, 0.72, 0.78), wood, Vector3(0, 0.36, 0))
	root.add_child(base)
	_add_collision(root, Vector3(0.82, 0.78, 0.82), Vector3(0, 0.39, 0))
	for i in range(5):
		var x := -0.32 + i * 0.16
		root.add_child(_box("FrontSlat_%d" % i, Vector3(0.14, 0.66, 0.035), edge, Vector3(x, 0.36, -0.405)))
		root.add_child(_box("SideSlat_%d" % i, Vector3(0.035, 0.66, 0.14), edge, Vector3(0.405, 0.36, x)))
	for x in [-0.34, 0.34]:
		for z in [-0.34, 0.34]:
			root.add_child(_box("CornerBat_%s_%s" % [x,z], Vector3(0.09,0.76,0.09),wood,Vector3(x,0.38,z)))
	for i in range(4):
		root.add_child(_box("TopBoard_%d" % i,Vector3(0.18,0.045,0.76),edge,Vector3(-0.27+i*0.18,0.75,0)))
	return root

static func make_barrel() -> Node3D:
	var root := Node3D.new()
	root.name = "HarborBarrel"
	var wood := _mat(Color(0.28,0.18,0.12))
	var metal := _mat(Color(0.20,0.22,0.24))
	var body := CylinderMesh.new()
	body.top_radius = 0.32
	body.bottom_radius = 0.30
	body.height = 0.82
	body.radial_segments = 12
	var b := MeshInstance3D.new()
	b.mesh = body
	b.material_override = wood
	b.position.y = 0.41
	root.add_child(b)
	for y in [0.18,0.62]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.30
		hoop.outer_radius = 0.325
		var ring := MeshInstance3D.new()
		ring.mesh = hoop
		ring.material_override = metal
		ring.position.y = y
		root.add_child(ring)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.29
	lid.bottom_radius = 0.29
	lid.height = 0.035
	lid.radial_segments = 12
	var cap := MeshInstance3D.new()
	cap.mesh = lid
	cap.material_override = wood
	cap.position.y = 0.83
	root.add_child(cap)
	return root

static func make_bollard() -> Node3D:
	var root := Node3D.new()
	root.name = "MooringBollard"
	var dark := _mat(Color(0.12,0.14,0.15))
	var body := CylinderMesh.new()
	body.top_radius = 0.14
	body.bottom_radius = 0.21
	body.height = 0.65
	body.radial_segments = 10
	var post := MeshInstance3D.new()
	post.mesh = body
	post.material_override = dark
	post.position.y = 0.325
	root.add_child(post)
	var capmesh := SphereMesh.new()
	capmesh.radius = 0.16
	capmesh.height = 0.2
	var cap := MeshInstance3D.new()
	cap.mesh = capmesh
	cap.material_override = dark
	cap.position.y = 0.63
	root.add_child(cap)
	return root

static func _box(label: String, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	return node

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	return m
