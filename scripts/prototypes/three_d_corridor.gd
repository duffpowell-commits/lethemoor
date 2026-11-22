extends Node3D
## Standalone, visual-only corridor proof of concept. Does not touch game simulation.
## Run: godot --path . res://scenes/prototypes/three_d_corridor.tscn

const TILE := 1.0
const WALL_H := 2.4
const LENGTH := 8.0
const WIDTH := 3.0

func _ready() -> void:
	_build()

func _mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(parent: Node3D, label: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = label
	inst.mesh = mesh
	inst.position = pos
	inst.material_override = material
	parent.add_child(inst)
	return inst

func _build() -> void:
	var stone := _mat(Color(0.24, 0.27, 0.31))
	var dark_stone := _mat(Color(0.12, 0.15, 0.19))
	var wet := _mat(Color(0.10, 0.16, 0.21), 0.25)
	var mortar := _mat(Color(0.19, 0.21, 0.24))
	var brass := _mat(Color(0.45, 0.29, 0.12), 0.55)
	var cloth := _mat(Color(0.08, 0.09, 0.12))
	var amber := _mat(Color(1.0, 0.56, 0.18), 0.35)

	# Floor and subtle alternating wet patches.
	_box(self, "Floor", Vector3(WIDTH, 0.12, LENGTH), Vector3(0, -0.06, -LENGTH/2), dark_stone)
	for i in range(8):
		_box(self, "Wet stone %02d" % i, Vector3(2.8, 0.015, 0.85), Vector3(0, 0.012, -0.5-i), wet)

	# Wall modules with modest irregularity via different block sizes, not high-frequency geometry.
	for side in [-1, 1]:
		var x := side * WIDTH/2
		_box(self, "Wall %s" % side, Vector3(0.24, WALL_H, LENGTH), Vector3(x, WALL_H/2, -LENGTH/2), stone)
		_box(self, "Coping %s" % side, Vector3(0.34, 0.18, LENGTH), Vector3(x, WALL_H+0.06, -LENGTH/2), mortar)
		for row in range(4):
			for seg in range(8):
				var z := -0.5 - seg
				var offset := 0.0 if row % 2 == 0 else 0.22
				_box(self, "Block", Vector3(0.27, 0.38, 0.96), Vector3(x, 0.28+row*0.43, z+offset), dark_stone if (row+seg)%3==0 else stone)

	_box(self, "End wall", Vector3(WIDTH, WALL_H, 0.25), Vector3(0, WALL_H/2, -LENGTH), stone)
	_box(self, "End coping", Vector3(WIDTH+0.15, 0.18, 0.34), Vector3(0, WALL_H+0.06, -LENGTH), mortar)

	# Door opening on right wall: framed inset recess with a simple door slab.
	_box(self, "Door recess", Vector3(0.08, 1.9, 1.15), Vector3(WIDTH/2-0.16, 1.0, -4.2), dark_stone)
	_box(self, "Door slab", Vector3(0.08, 1.65, 0.9), Vector3(WIDTH/2-0.10, 0.85, -4.2), cloth)
	_box(self, "Door lintel", Vector3(0.42, 0.22, 1.3), Vector3(WIDTH/2, 2.08, -4.2), mortar)

	# Wall lamp: stylized cage, amber emissive wick (the actual lighting remains a separate Light3D).
	_box(self, "Lamp bracket", Vector3(0.45, 0.08, 0.08), Vector3(-WIDTH/2+0.25, 1.9, -2.0), brass)
	_box(self, "Lamp cage", Vector3(0.24, 0.42, 0.24), Vector3(-WIDTH/2+0.35, 1.62, -2.0), brass)
	var wick := _box(self, "Lamp wick", Vector3(0.10, 0.22, 0.10), Vector3(-WIDTH/2+0.35, 1.62, -2.0), amber)
	var light := OmniLight3D.new()
	light.name = "Prototype lamp light"
	light.position = Vector3(-WIDTH/2+0.35, 1.62, -2.0)
	light.light_color = Color(1.0, 0.63, 0.32)
	light.light_energy = 1.2
	light.omni_range = 4.0
	add_child(light)

	# Simplified faceless thrall silhouette at the corridor end, as a placeholder mesh study.
	var enemy := Node3D.new()
	enemy.name = "Faceless Thrall Study"
	enemy.position = Vector3(0, 0, -6.4)
	add_child(enemy)
	_box(enemy, "Body", Vector3(0.48, 1.15, 0.32), Vector3(0, 0.95, 0), cloth)
	_box(enemy, "Hood", Vector3(0.42, 0.48, 0.40), Vector3(0, 1.68, -0.02), cloth)
	_box(enemy, "Shadow face", Vector3(0.25, 0.24, 0.06), Vector3(0, 1.64, -0.23), dark_stone)
	for side in [-1, 1]:
		_box(enemy, "Leg", Vector3(0.16, 0.65, 0.18), Vector3(side*0.15, 0.32, 0), cloth)
		_box(enemy, "Arm", Vector3(0.16, 0.78, 0.18), Vector3(side*0.35, 0.95, 0.03), cloth)

	# Bell prop on left, abstract simple shapes.
	var bell := Node3D.new()
	bell.name = "Bell prop"
	bell.position = Vector3(-WIDTH/2+0.35, 0, -7.0)
	add_child(bell)
	_box(bell, "Bell body", Vector3(0.32, 0.42, 0.32), Vector3(0, 1.35, 0), brass)
	_box(bell, "Bell cap", Vector3(0.16, 0.12, 0.16), Vector3(0, 1.60, 0), brass)
	_box(bell, "Bell clapper", Vector3(0.08, 0.14, 0.08), Vector3(0, 1.10, 0), dark_stone)

	# First-person viewing camera, deliberately separate from the game's active scene.
	var camera := Camera3D.new()
	camera.name = "Prototype camera"
	camera.position = Vector3(0, 1.55, 0.15)
	camera.rotation_degrees = Vector3(-3, 0, 0)
	camera.fov = 72
	camera.current = true
	add_child(camera)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.12, 0.16, 0.22)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
