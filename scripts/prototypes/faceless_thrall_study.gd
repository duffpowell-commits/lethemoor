extends Node3D
## Standalone faceless harbor-thrall silhouette study. Visual only; no gameplay hooks.
## Coordinate convention: forward is -Z, ground is Y=0.

func _ready() -> void:
	_build()

func _mat(c: Color, rough: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _mesh(parent: Node3D, name: String, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name
	n.mesh = mesh
	n.position = pos
	n.rotation = rot
	n.material_override = mat
	parent.add_child(n)
	return n

func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, name, m, pos, mat, rot)

func _capsule(parent: Node3D, name: String, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return _mesh(parent, name, m, pos, mat)

func _build() -> void:
	var coat := _mat(Color(0.055,0.065,0.075))
	var folds := _mat(Color(0.10,0.105,0.12))
	var skin := _mat(Color(0.20,0.19,0.18))
	var void_mat := _mat(Color(0.012,0.018,0.025))
	var tarnished := _mat(Color(0.22,0.17,0.12),0.7)

	# Root and shoulders: deliberately uneven, narrow at the waist.
	var rig := Node3D.new()
	rig.name = "ThrallRoot"
	add_child(rig)
	_capsule(rig,"Lower coat",0.29,0.95,Vector3(0,0.68,0),coat)
	_capsule(rig,"Chest",0.27,0.78,Vector3(0,1.34,0),folds)
	_box(rig,"Shoulder mantle",Vector3(0.78,0.20,0.40),Vector3(0,1.63,0.02),coat)
	_capsule(rig,"Neck",0.10,0.22,Vector3(0,1.78,-0.015),skin)

	# Hood mass and forward rim. The face is a dark inset void, not a glowing feature.
	_capsule(rig,"Hood dome",0.27,0.52,Vector3(0,2.03,0.025),coat)
	_box(rig,"Hood brow",Vector3(0.42,0.12,0.30),Vector3(0,1.97,-0.17),folds)
	_box(rig,"Face void",Vector3(0.26,0.30,0.045),Vector3(0,1.98,-0.215),void_mat)
	_box(rig,"Hood hanging edge",Vector3(0.34,0.22,0.20),Vector3(0,1.78,-0.13),coat)

	# Arms hang asymmetrically; sleeves and thin forearms give the silhouette some taper.
	for side in [-1,1]:
		var arm := Node3D.new()
		arm.name = "Left arm" if side < 0 else "Right arm"
		arm.position = Vector3(side*0.39,1.43,0.02)
		arm.rotation.z = side*0.08
		rig.add_child(arm)
		_capsule(arm,"Sleeve",0.13,0.70,Vector3(side*0.04,-0.24,0),coat)
		_capsule(arm,"Forearm",0.075,0.45,Vector3(side*0.10,-0.55,-0.04),folds)
		_capsule(arm,"Hand",0.06,0.22,Vector3(side*0.12,-0.77,-0.07),skin)

	# Ragged coat panels and low-key seams, with no bright trim.
	_box(rig,"Left coat flap",Vector3(0.18,0.72,0.06),Vector3(-0.14,0.44,-0.16),folds,Vector3(0,0,-0.06))
	_box(rig,"Right coat flap",Vector3(0.18,0.64,0.06),Vector3(0.14,0.40,-0.16),coat,Vector3(0,0,0.05))
	_box(rig,"Belt",Vector3(0.48,0.09,0.30),Vector3(0,0.83,0.01),tarnished)

	# Split, slightly splayed legs and boots, visible beneath the ragged hem.
	for side in [-1,1]:
		_capsule(rig,"Leg",0.12,0.62,Vector3(side*0.14,0.27,0.03),coat)
		_box(rig,"Boot",Vector3(0.18,0.14,0.32),Vector3(side*0.14,0.07,-0.10),folds)

	# Simple light and camera for a thumbnail-like studio preview.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38,-28,0)
	key.light_energy = 1.25
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2,1.7,2.5)
	fill.light_color = Color(0.30,0.38,0.52)
	fill.light_energy = 0.45
	fill.omni_range = 6
	add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035,0.045,0.065)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.15,0.18,0.23)
	e.ambient_light_energy = 0.65
	env.environment = e
	add_child(env)
	var camera := Camera3D.new()
	camera.position = Vector3(3.5,2.4,4.7)
	camera.look_at(Vector3(0,1.0,0),Vector3.UP)
	camera.current = true
	camera.fov = 42
	add_child(camera)
