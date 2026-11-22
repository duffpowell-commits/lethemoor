extends Node3D
## Modular wall-kit visual test. Pieces are generated with reusable box meshes.
## Grid size: 1m. No gameplay dependencies.

const TILE := 1.0
const HEIGHT := 2.4
const THICKNESS := 0.22

func _ready() -> void:
	_make_materials()
	_build_demo()

var stone: StandardMaterial3D
var dark: StandardMaterial3D
var cap: StandardMaterial3D

func _make_materials() -> void:
	stone = _mat(Color(0.27,0.29,0.33),0.92)
	dark = _mat(Color(0.16,0.18,0.21),0.95)
	cap = _mat(Color(0.22,0.23,0.25),0.88)

func _mat(c: Color, r: float) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=r
	return m

func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh:=BoxMesh.new()
	mesh.size=size
	var node:=MeshInstance3D.new()
	node.name=name
	node.mesh=mesh
	node.position=pos
	node.material_override=mat
	parent.add_child(node)
	return node

func make_straight_wall(parent: Node3D, origin: Vector3, length: float=2.0) -> Node3D:
	var module:=Node3D.new()
	module.name="WallStraight_%0.1fm" % length
	module.position=origin
	parent.add_child(module)
	_box(module,"WallCore",Vector3(THICKNESS,HEIGHT,length),Vector3(0,HEIGHT/2,0),stone)
	_box(module,"Coping",Vector3(THICKNESS+0.12,0.14,length+0.08),Vector3(0,HEIGHT+0.07,0),cap)
	# Low-relief block courses on both faces, staggered and shared materials.
	for face in [-1,1]:
		for row in range(5):
			var y:=0.25+row*0.43
			var blocks:=int(length/0.5)+1
			for b in range(blocks):
				var z:float = -length/2+0.25+b*0.5+(0.25 if row%2==1 else 0.0)
				if z>length/2-0.12: continue
				_box(module,"FaceBlock",Vector3(0.035,0.36,0.46),Vector3(face*(THICKNESS/2+0.02),y,z),dark if (row+b)%5==0 else stone)
	return module

func make_corner(parent: Node3D, origin: Vector3, inner: bool=true) -> Node3D:
	var node:=Node3D.new()
	node.name="CornerInner" if inner else "CornerOuter"
	node.position=origin
	parent.add_child(node)
	make_straight_wall(node,Vector3(0,0,0),1.0)
	var rotated:=make_straight_wall(node,Vector3(0,0,0),1.0)
	rotated.rotation.y=PI/2
	return node

func make_doorway(parent: Node3D, origin: Vector3, width: float=1.0) -> Node3D:
	var node:=Node3D.new()
	node.name="WallDoorway"
	node.position=origin
	parent.add_child(node)
	var side:float=(2.0-width)/2
	_box(node,"LeftPier",Vector3(THICKNESS,HEIGHT,side),Vector3(0,HEIGHT/2,-(width+side)/2),stone)
	_box(node,"RightPier",Vector3(THICKNESS,HEIGHT,side),Vector3(0,HEIGHT/2,(width+side)/2),stone)
	_box(node,"Lintel",Vector3(THICKNESS,0.42,width+side*2),Vector3(0,HEIGHT-0.21,0),cap)
	return node

func _build_demo() -> void:
	make_straight_wall(self,Vector3(-1.5,0,-2),2.0)
	make_straight_wall(self,Vector3(1.5,0,-2),2.0)
	make_doorway(self,Vector3(0,0,-4),1.0)
	var floor_mesh:=BoxMesh.new()
	floor_mesh.size=Vector3(5,0.1,5)
	var floor_node:=MeshInstance3D.new()
	floor_node.name="Floor"
	floor_node.mesh=floor_mesh
	floor_node.position=Vector3(0,-0.05,-2)
	floor_node.material_override=dark
	add_child(floor_node)
	var camera:=Camera3D.new()
	camera.position=Vector3(0,1.6,1.5)
	camera.rotation_degrees=Vector3(-8,0,0)
	camera.current=true
	add_child(camera)
	var env:=WorldEnvironment.new()
	var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color(0.025,0.035,0.05)
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color(0.15,0.17,0.2)
	e.ambient_light_energy=0.5
	env.environment=e
	add_child(env)
