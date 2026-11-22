extends Node3D
## Composition-only test for independently instanced harbor props.
const CRATE = preload("res://scenes/prototypes/props/harbor_crate.tscn")
const BARREL = preload("res://scenes/prototypes/props/harbor_barrel.tscn")
const BOLLARD = preload("res://scenes/prototypes/props/mooring_bollard.tscn")

func _ready() -> void:
	_make_floor()
	_place(CRATE, Vector3(-1.1, 0.0, -0.5), 0.2)
	_place(BARREL, Vector3(0.0, 0.0, -0.4), -0.15)
	_place(BOLLARD, Vector3(1.0, 0.0, 0.4), 0.0)
	_place(CRATE, Vector3(-0.6, 0.0, 1.0), -0.35)
	_make_rig()

func _place(scene: PackedScene, pos: Vector3, yaw: float) -> void:
	var instance := scene.instantiate() as Node3D
	instance.position = pos
	instance.rotation.y = yaw
	add_child(instance)
	_add_blocker(instance.name + "_Collision", pos, Vector3(0.82, 0.9, 0.82))

func _add_blocker(label: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _make_floor() -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(4.5, 0.12, 4.5)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position.y = -0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.19, 0.21)
	mat.roughness = 0.9
	floor.material_override = mat
	add_child(floor)

func _make_rig() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(3.8, 4.2, 5.4)
	camera.look_at(Vector3(0.0, 0.25, 0.0), Vector3.UP)
	camera.fov = 52.0
	add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	light.light_energy = 1.15
	add_child(light)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.42, 0.46)
	environment.ambient_light_energy = 0.65
	env.environment = environment
	add_child(env)
