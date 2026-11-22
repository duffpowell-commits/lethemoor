extends Node3D
## Modular harbor masonry builder. Geometry-only reusable modules.
## No camera, lights, environment or gameplay collision.

const HEIGHT := 2.4
const THICKNESS := 0.22
const COURSE := 0.38
const BLOCK := 0.48

func _ready() -> void:
	var stone=material(Color(0.27,0.29,0.33))
	var cap=material(Color(0.22,0.23,0.25))
	var dark=material(Color(0.16,0.18,0.21))
	build_wall(self,Vector3(-2.0,0,-3.0),3.0,stone,cap,dark)
	build_door(self,Vector3(0,0,-3.0),1.0,2.4,stone,cap)
	build_wall(self,Vector3(2.0,0,-3.0),3.0,stone,cap,dark)
	build_corner(self,Vector3(-2.0,0,-0.8),stone,cap,dark)
	# Shared test rig, intentionally only in this preview script.
	var floor=BoxMesh.new()
	floor.size=Vector3(6.5,0.1,5.5)
	var floor_node=MeshInstance3D.new()
	floor_node.mesh=floor
	floor_node.position=Vector3(0,-0.05,-2.0)
	floor_node.material_override=dark
	add_child(floor_node)
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-42,-25,0)
	add_child(light)
	var env_node=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.025,0.035,0.05)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.15,0.17,0.2)
	env.ambient_light_energy=0.5
	env_node.environment=env
	add_child(env_node)
	var camera=Camera3D.new()
	camera.position=Vector3(0,2.5,4.8)
	camera.rotation_degrees=Vector3(-20,0,0)
	camera.current=true
	add_child(camera)

func material(c:Color,r:float=0.9)->StandardMaterial3D:
	var m=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=r
	return m

func cube(parent:Node3D,label:String,size:Vector3,pos:Vector3,mat:Material)->MeshInstance3D:
	var mesh=BoxMesh.new()
	mesh.size=size
	var n=MeshInstance3D.new()
	n.name=label
	n.mesh=mesh
	n.position=pos
	n.material_override=mat
	parent.add_child(n)
	return n

func build_wall(parent:Node3D,origin:Vector3,length:float,stone:Material,cap:Material,dark:Material)->Node3D:
	var module=Node3D.new()
	module.name="WallStraight_%0.2f"%length
	module.position=origin
	parent.add_child(module)
	cube(module,"Wall core",Vector3(THICKNESS,HEIGHT,length),Vector3(0,HEIGHT/2,0),stone)
	cube(module,"Coping",Vector3(THICKNESS+0.12,0.14,length+0.08),Vector3(0,HEIGHT+0.07,0),cap)
	for face in [-1,1]:
		for row in range(6):
			var count=int(ceil(length/BLOCK))
			for b in range(count):
				var z=-length/2+BLOCK/2+b*BLOCK+(BLOCK/2 if row%2 else 0.0)
				if z< -length/2+0.08 or z>length/2-0.08: continue
				var mat:Material=dark if (row+b)%5==0 else stone
				cube(module,"Relief block",Vector3(0.035,COURSE-0.035,BLOCK-0.035),Vector3(face*(THICKNESS/2+0.02),0.22+row*COURSE,z),mat)
	return module

func build_corner(parent:Node3D,origin:Vector3,stone:Material,cap:Material,dark:Material)->Node3D:
	var node=Node3D.new()
	node.name="CornerModule"
	node.position=origin
	parent.add_child(node)
	build_wall(node,Vector3(0,0,-0.5),1.0,stone,cap,dark)
	var other=build_wall(node,Vector3(0.61,0,0),1.0,stone,cap,dark)
	other.rotation.y=PI/2
	return node

func build_door(parent:Node3D,origin:Vector3,opening:float,total:float,stone:Material,cap:Material)->Node3D:
	var node=Node3D.new()
	node.name="DoorwayModule_%0.2f"%opening
	node.position=origin
	parent.add_child(node)
	var side=(total-opening)/2
	if side<=0.05:
		push_warning("Doorway width must leave space for two piers.")
		return node
	var center=opening/2+side/2
	cube(node,"Left pier",Vector3(THICKNESS,HEIGHT,side),Vector3(0,HEIGHT/2,-center),stone)
	cube(node,"Right pier",Vector3(THICKNESS,HEIGHT,side),Vector3(0,HEIGHT/2,center),stone)
	cube(node,"Lintel",Vector3(THICKNESS,0.42,total),Vector3(0,HEIGHT-0.21,0),cap)
	for s in [-1,1]:
		cube(node,"Pier cap",Vector3(THICKNESS+0.1,0.14,side+0.05),Vector3(0,HEIGHT+0.07,s*center),cap)
	return node
