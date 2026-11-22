extends Node3D
## A reusable harbor prop cluster study. Shared coordinate space and materials.
## All forms are blockout meshes; art direction is for replacement assets.

func _ready() -> void:
	build()

func material(c:Color,r:float=0.86)->StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=r
	return m

func box(parent:Node3D,label:String,size:Vector3,pos:Vector3,mat:Material)->MeshInstance3D:
	var mesh:=BoxMesh.new()
	mesh.size=size
	var n:=MeshInstance3D.new()
	n.name=label
	n.mesh=mesh
	n.position=pos
	n.material_override=mat
	parent.add_child(n)
	return n

func cylinder(parent:Node3D,label:String,radius:float,height:float,pos:Vector3,mat:Material,segments:=10)->MeshInstance3D:
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=segments
	var n:=MeshInstance3D.new()
	n.name=label
	n.mesh=mesh
	n.position=pos
	n.material_override=mat
	parent.add_child(n)
	return n

func build()->void:
	var wood:=material(Color(0.22,0.14,0.09))
	var wood_light:=material(Color(0.34,0.23,0.14))
	var iron:=material(Color(0.12,0.14,0.17),0.68)
	var stone:=material(Color(0.27,0.3,0.33))
	var rope:=material(Color(0.42,0.32,0.22))
	var wet:=material(Color(0.08,0.12,0.16),0.28)
	var floor:=box(self,"Ground",Vector3(5.5,0.1,5.5),Vector3(0,-0.05,0),stone)
	# Crate: corner posts, slats, top boards.
	var crate:=Node3D.new()
	crate.name="Crate"
	crate.position=Vector3(-1.4,0,-0.7)
	add_child(crate)
	for side in [-1.0,1.0]:
		for row in range(4):
			box(crate,"Side slat",Vector3(0.7,0.14,0.08),Vector3(0,0.1+row*0.16,side*0.34),wood_light)
			box(crate,"Side slat",Vector3(0.08,0.14,0.7),Vector3(side*0.34,0.1+row*0.16,0),wood)
	for corner_x in [-0.32,0.32]:
		for corner_z in [-0.32,0.32]:
			box(crate,"Corner batten",Vector3(0.09,0.72,0.09),Vector3(corner_x,0.36,corner_z),wood)
	for i in range(3):
		box(crate,"Top board",Vector3(0.72,0.08,0.22),Vector3(0,0.72,-0.22+i*0.22),wood)
	# Barrel: segmented low-poly cylinder with two iron hoops.
	var barrel:=Node3D.new()
	barrel.name="Barrel"
	barrel.position=Vector3(0.6,0,-0.8)
	add_child(barrel)
	cylinder(barrel,"Barrel body",0.38,0.82,Vector3(0,0.41,0),wood,12)
	for y in [0.18,0.62]:
		cylinder(barrel,"Iron hoop",0.405,0.07,Vector3(0,y,0),iron,12)
	cylinder(barrel,"Barrel lid",0.36,0.08,Vector3(0,0.86,0),wood_light,12)
	# Bollard and rope coil.
	var bollard:=Node3D.new()
	bollard.name="Mooring Bollard"
	bollard.position=Vector3(1.5,0,0.9)
	add_child(bollard)
	cylinder(bollard,"Bollard base",0.24,0.18,Vector3(0,0.09,0),stone,8)
	cylinder(bollard,"Bollard shaft",0.14,0.75,Vector3(0,0.48,0),wood,8)
	cylinder(bollard,"Bollard head",0.24,0.14,Vector3(0,0.9,0),wood_light,8)
	for ring in range(3):
		cylinder(bollard,"Rope coil",0.22,0.055,Vector3(0,0.68+ring*0.06,0),rope,12)
	# Drain grate: frame and bars.
	var drain:=Node3D.new()
	drain.name="Drain Grate"
	drain.position=Vector3(0.1,0.015,1.65)
	add_child(drain)
	box(drain,"Drain frame",Vector3(0.8,0.04,0.45),Vector3(0,0,0),iron)
	for i in range(6):
		box(drain,"Drain bar",Vector3(0.06,0.045,0.36),Vector3(-0.3+i*0.12,0.025,0),stone)
	# Small wet patch with rough, fragmented highlight strips.
	var patch:=Node3D.new()
	patch.name="Wet highlight patch"
	patch.position=Vector3(-0.6,0.025,1.5)
	add_child(patch)
	for i in range(7):
		var length:=0.25+float(i%3)*0.18
		var strip:=box(patch,"Broken reflection",Vector3(length,0.015,0.025),Vector3(-0.4+i*0.12,0,0.08*(i%2)),wet)
		strip.rotation.y=float(i%2)*0.16
	# Single neutral lighting and preview camera.
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-50,-20,0)
	add_child(light)
	var envnode:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.025,0.035,0.05)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.17,0.19,0.22)
	env.ambient_light_energy=0.55
	envnode.environment=env
	add_child(envnode)
	var camera:=Camera3D.new()
	camera.position=Vector3(0,3.2,4.4)
	camera.rotation_degrees=Vector3(-32,0,0)
	camera.current=true
	add_child(camera)
