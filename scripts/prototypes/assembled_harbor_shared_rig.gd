extends Node3D
## Shared-rig assembled harbor slice. Geometry only: no nested preview rigs.
## Art prototype, isolated from gameplay and renderer.

func _ready() -> void:
	build()

func mat(c: Color, r: float=0.9, metal: float=0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=r
	m.metallic=metal
	return m

func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	var n := MeshInstance3D.new()
	n.name=label
	n.mesh=mesh
	n.position=pos
	n.material_override=material
	parent.add_child(n)
	return n

func cylinder(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=8
	var n := MeshInstance3D.new()
	n.name=label
	n.mesh=mesh
	n.position=pos
	n.material_override=material
	parent.add_child(n)
	return n

func build() -> void:
	var stone=mat(Color(0.24,0.27,0.31))
	var darker=mat(Color(0.12,0.15,0.19))
	var timber=mat(Color(0.19,0.12,0.075))
	var worn=mat(Color(0.28,0.19,0.12))
	var iron=mat(Color(0.12,0.14,0.16),0.7,0.65)
	var wet=mat(Color(0.10,0.16,0.21),0.25)
	var amber=mat(Color(0.9,0.47,0.15),0.35)
	var cloth=mat(Color(0.07,0.08,0.11))

	# Unified floor: tileable stone shader is intentionally represented by wet material patches.
	box(self,"Ground slab",Vector3(5.0,0.12,8.0),Vector3(0,-0.06,-3.8),darker)
	for i in range(9):
		box(self,"Wet patch %02d"%i,Vector3(4.6,0.012,0.55),Vector3(0,0.012,-0.35-i*0.82),wet)

	# A short, connected masonry gateway section. Shared coordinate space.
	for side in [-1,1]:
		var x=float(side)*2.25
		box(self,"Harbor wall",Vector3(0.28,2.4,5.2),Vector3(x,1.2,-2.1),stone)
		box(self,"Wall coping",Vector3(0.4,0.18,5.35),Vector3(x,2.46,-2.1),worn)
		for row in range(5):
			for seg in range(6):
				var z=-0.1-seg*0.82+(0.22 if row%2==1 else 0.0)
				box(self,"Masonry block",Vector3(0.32,0.34,0.72),Vector3(x,0.32+row*0.43,z),darker if (row+seg)%4==0 else stone)
	# Back gate / doorway focal feature
	box(self,"Gate recess",Vector3(2.2,2.0,0.2),Vector3(0,1.0,-6.2),darker)
	box(self,"Gate door",Vector3(1.7,1.8,0.12),Vector3(0,0.9,-6.08),cloth)
	for side in [-1,1]:
		box(self,"Gate pier",Vector3(0.35,2.4,0.35),Vector3(side*1.05,1.2,-6.1),worn)
	box(self,"Gate lintel",Vector3(2.5,0.35,0.4),Vector3(0,2.2,-6.1),worn)

	# Timber brace and crate in the shared scene.
	box(self,"Brace upright",Vector3(0.18,2.2,0.18),Vector3(-1.75,1.1,-1.0),timber)
	box(self,"Brace beam",Vector3(1.5,0.18,0.18),Vector3(-1.75,2.0,-1.0),worn)
	var diagonal=box(self,"Brace diagonal",Vector3(0.14,1.35,0.14),Vector3(-1.3,1.2,-1.0),worn)
	diagonal.rotation.z=-0.68
	var crate=Node3D.new()
	crate.name="Slatted crate"
	crate.position=Vector3(1.35,0,-0.9)
	add_child(crate)
	for row in range(4):
		box(crate,"Crate slat",Vector3(0.75,0.13,0.07),Vector3(0,0.12+row*0.16,-0.36),worn)
		box(crate,"Side slat",Vector3(0.07,0.13,0.75),Vector3(0.36,0.12+row*0.16,0),timber)
	for i in range(3):
		box(crate,"Lid plank",Vector3(0.75,0.08,0.22),Vector3(0,0.7,-0.22+i*0.22),timber)

	# Bollard, lantern post, and a bell marker.
	cylinder(self,"Bollard",0.16,0.85,Vector3(1.9,0.43,-2.5),timber)
	cylinder(self,"Bollard cap",0.2,0.12,Vector3(1.9,0.86,-2.5),iron)
	box(self,"Bollard cleat",Vector3(0.55,0.12,0.12),Vector3(1.9,0.72,-2.5),worn)
	cylinder(self,"Lamp post",0.08,2.6,Vector3(-1.9,1.3,-3.4),timber)
	box(self,"Lamp bracket",Vector3(0.65,0.08,0.08),Vector3(-1.62,2.35,-3.4),iron)
	box(self,"Lantern",Vector3(0.32,0.42,0.32),Vector3(-1.32,2.12,-3.4),iron)
	box(self,"Lantern glass",Vector3(0.18,0.25,0.03),Vector3(-1.32,2.12,-3.57),amber)
	box(self,"Lantern roof",Vector3(0.42,0.09,0.42),Vector3(-1.32,2.38,-3.4),worn)
	box(self,"Bell",Vector3(0.32,0.42,0.32),Vector3(1.8,1.35,-5.0),iron)
	box(self,"Bell cap",Vector3(0.16,0.12,0.16),Vector3(1.8,1.6,-5.0),worn)

	# Faceless silhouette study at the gate. No face features.
	var thrall=Node3D.new()
	thrall.name="Faceless Thrall"
	thrall.position=Vector3(0,0,-4.8)
	add_child(thrall)
	box(thrall,"Body",Vector3(0.48,1.15,0.32),Vector3(0,0.95,0),cloth)
	box(thrall,"Hood",Vector3(0.42,0.48,0.4),Vector3(0,1.68,-0.02),cloth)
	box(thrall,"Void",Vector3(0.25,0.24,0.06),Vector3(0,1.64,-0.23),darker)
	for side in [-1,1]:
		box(thrall,"Leg",Vector3(0.16,0.65,0.18),Vector3(side*0.15,0.32,0),cloth)
		box(thrall,"Arm",Vector3(0.16,0.78,0.18),Vector3(side*0.35,0.95,0.03),cloth)

	# Single camera/environment/light for the whole composition.
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-42,-25,0)
	light.light_energy=1.2
	add_child(light)
	var fill=OmniLight3D.new()
	fill.position=Vector3(-1.32,2.1,-3.4)
	fill.light_color=Color(1.0,0.63,0.32)
	fill.light_energy=0.8
	fill.omni_range=4.0
	add_child(fill)
	var world=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.025,0.035,0.05)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.16,0.18,0.21)
	env.ambient_light_energy=0.55
	world.environment=env
	add_child(world)
	var cam=Camera3D.new()
	cam.position=Vector3(0,2.4,4.0)
	cam.rotation_degrees=Vector3(-12,0,0)
	cam.fov=72
	cam.current=true
	add_child(cam)
