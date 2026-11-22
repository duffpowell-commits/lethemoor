extends Node3D
## A player-scale alley slice built from standalone modular components.
## Deliberately art-only: no changes to gameplay, renderer, or main scene.

func _ready() -> void:
	_build_floor()
	_build_puddles()
	_build_walls()
	_build_dressing()
	_build_thrall()
	_build_lighting()
	_build_camera()

func _mat(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = pos
	parent.add_child(node)
	return node

func _block(parent: Node3D, name: String, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)
	parent.add_child(body)

func _build_floor() -> void:
	_box(self, "WetAlleyFloor", Vector3(5.2, 0.12, 9.0), Vector3(0,-0.06,0), Color(0.16,0.20,0.22))
	# Slab seams and edge puddle strips.
	for z in range(-4,5):
		_box(self, "StoneSeam_%d" % z, Vector3(5.0,0.008,0.018), Vector3(0,0.005,z), Color(0.10,0.13,0.15))
	for x in [-2.35,2.35]:
		_box(self, "Gutter_%s" % x, Vector3(0.16,0.025,8.8), Vector3(x,0.005,0), Color(0.08,0.12,0.14))

func _build_walls() -> void:
	var wallmat := Color(0.31,0.33,0.35)
	_box(self,"LeftWall",Vector3(0.25,2.6,9.0),Vector3(-2.65,1.3,0),wallmat)
	_box(self,"RightWall",Vector3(0.25,2.6,9.0),Vector3(2.65,1.3,0),Color(0.27,0.29,0.31))
	_box(self,"FarWall",Vector3(5.3,2.6,0.25),Vector3(0,1.3,-4.55),Color(0.36,0.34,0.32))
	_block(self,"LeftWallBlocker",Vector3(0.25,2.6,9.0),Vector3(-2.65,1.3,0))
	_block(self,"RightWallBlocker",Vector3(0.25,2.6,9.0),Vector3(2.65,1.3,0))
	_block(self,"FarWallBlocker",Vector3(5.3,2.6,0.25),Vector3(0,1.3,-4.55))
	for side in [-1,1]:
		for z in range(-4,5):
			_box(self,"MasonryBand_%d_%d" % [side,z],Vector3(0.04,0.42,0.84),Vector3(side*2.49,0.35,z),Color(0.39,0.40,0.41))
			_box(self,"MasonryBand2_%d_%d" % [side,z],Vector3(0.04,0.38,0.84),Vector3(side*2.49,1.12,z+0.42),Color(0.34,0.36,0.38))

func _build_dressing() -> void:
	var crate_scene := preload("res://scenes/prototypes/props/harbor_crate.tscn")
	var barrel_scene := preload("res://scenes/prototypes/props/harbor_barrel.tscn")
	var bollard_scene := preload("res://scenes/prototypes/props/mooring_bollard.tscn")
	var crate := crate_scene.instantiate()
	crate.position = Vector3(-1.75,0,1.3)
	crate.rotation.y = -0.18
	add_child(crate)
	var barrel := barrel_scene.instantiate()
	barrel.position = Vector3(1.75,0,-1.1)
	add_child(barrel)
	var bollard := bollard_scene.instantiate()
	bollard.position = Vector3(-1.9,0,-2.4)
	add_child(bollard)
	_box(self,"DoorDarkness",Vector3(1.15,2.15,0.06),Vector3(1.1,1.05,-4.38),Color(0.06,0.07,0.09))
	_box(self,"DoorFrameTop",Vector3(1.4,0.16,0.12),Vector3(1.1,2.2,-4.34),Color(0.42,0.39,0.36))
	_box(self,"DoorFrameSide",Vector3(0.16,2.3,0.12),Vector3(0.48,1.15,-4.34),Color(0.42,0.39,0.36))

func _build_lighting() -> void:
	var light := OmniLight3D.new()
	light.name = "AlleyLantern"
	light.position = Vector3(-1.9,2.25,-0.5)
	light.light_color = Color(1.0,0.72,0.43)
	light.light_energy = 2.4
	light.omni_range = 7.0
	light.shadow_enabled = true
	add_child(light)
	_box(self,"LanternHousing",Vector3(0.18,0.3,0.18),Vector3(-2.45,2.25,-0.5),Color(0.12,0.14,0.15))

func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(5.7,4.0,7.3)
	camera.look_at(Vector3(0,1.0,-0.3),Vector3.UP)
	camera.fov = 58.0
	add_child(camera)
	camera.current = true
	var envnode := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06,0.08,0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36,0.42,0.48)
	env.ambient_light_energy = 0.5
	envnode.environment = env
	add_child(envnode)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_energy = 0.65
	add_child(sun)

func _build_puddles() -> void:
	for i in range(6):
		var puddle := CylinderMesh.new()
		puddle.top_radius = 1.0
		puddle.bottom_radius = 1.0
		puddle.height = 0.012
		puddle.radial_segments = 20
		var node := MeshInstance3D.new()
		node.name = "Puddle_%d" % i
		node.mesh = puddle
		var wet := StandardMaterial3D.new()
		wet.albedo_color = Color(0.13,0.18,0.21,0.72)
		wet.roughness = 0.22
		wet.metallic = 0.28
		wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.material_override = wet
		node.position = Vector3(-1.5 + i*0.55,0.012,-2.6 + (i%3)*1.8)
		node.scale = Vector3(0.48 + (i%2)*0.22,1.0,0.22 + (i%3)*0.1)
		node.rotation.y = float(i)*0.35
		add_child(node)

func _build_thrall() -> void:
	var thrall_scene := preload("res://scenes/prototypes/faceless_thrall_study.tscn")
	var thrall := thrall_scene.instantiate() as Node3D
	thrall.name = "AlleyThrallScaleReference"
	thrall.position = Vector3(0.7,0.0,-2.9)
	thrall.rotation.y = 0.22
	thrall.scale = Vector3(0.78,0.78,0.78)
	add_child(thrall)
