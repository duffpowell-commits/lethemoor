extends RefCounted
## Your 3D hands (Nov 25, Duff: "They don't hold the lantern correctly, and they definitely don't
## hold the boat hook correctly"). The glove is a Meshy fist: sleeve up +Y, fingers curled toward
## -Z, thumb on -X, so as modelled it is a LEFT hand; the right hand is the same mesh mirrored.
## The fist's grip channel (where a handle passes through the curled fingers) runs along the
## model's X axis through GRIP. A hand is posed by naming where that channel sits, which way it
## runs and which way the forearm goes; the handle it holds is posed through the same point,
## so the fingers close on it rather than float near it. The look only: rules never read these.

const GLOVE := "res://assets/models/fp_glove.glb"
const GRIP := Vector3(0.0, -0.71, -0.04)          # centre of the fist's grip channel, model space
const LAMP_RING := Vector3(-0.035, 0.95, 0.0)      # the top of the lantern's ring (hooks on the link)
const HOOK_GRIP := Vector3(0.6, -0.78, 0.0)        # the boathook's wrapped handle
const HOOK_AXIS := Vector3(-0.68, 0.73, 0.0)       # handle -> head, along the shaft (model space)

# where things sit, camera space (the camera looks down -Z): the grip points, which way each
# handle runs and which way each forearm goes
const LAMP_AT := Vector3(0.095, -0.1, -0.36)      # right fist, the lantern's ring in it
const LAMP_ELBOW := Vector3(0.55, -0.5, 0.65)      # right forearm: back, down and off to the right
const ARM_SCALE := 0.16
const LAMP_SCALE := 0.085
const LINK_R := 0.013                              # the iron link between fist and lantern
const HOOK_AT := Vector3(-0.105, -0.15, -0.33)      # left fist round the boathook's handle
const HOOK_UP := Vector3(0.12, 0.97, -0.2)         # the hook stands up, head a little ahead
const HOOK_ELBOW := Vector3(-0.6, -0.15, 0.8)      # left forearm: level, back and to the left
const HOOK_FACE := Vector3(0.6, 0.0, 0.8)          # the side the hook's curl opens toward (model +Z)
const HOOK_SCALE := 0.12


## The right hand with the lantern hanging from its fist on an iron link. `root` sits at the grip
## point; returns [swing pivot (the link and lantern hang and swing from the fist), lantern, arm].
static func lantern_rig(root: Node3D) -> Array:
	var along := Vector3(LAMP_ELBOW.z, 0, -LAMP_ELBOW.x).normalized() * -1.0   # level, thumb inward
	var arm := glove(true)
	root.add_child(arm)
	grip(arm, along, LAMP_ELBOW, ARM_SCALE)
	var pivot := Node3D.new()
	root.add_child(pivot)
	# an iron link through the fist, the lantern's own ring hooked through the bottom of it
	var side := along.cross(Vector3.UP).normalized()
	var link := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = LINK_R - 0.0018
	tm.outer_radius = LINK_R + 0.0018
	tm.rings = 16
	tm.ring_segments = 6
	link.mesh = tm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#2a2622")
	lm.metallic = 0.6
	lm.roughness = 0.5
	link.material_override = lm
	link.basis = Basis(along, side, -Vector3.UP)   # stands upright, its top wire in the grip channel
	link.position = Vector3.DOWN * LINK_R
	pivot.add_child(link)
	var lamp: Node3D = (load("res://assets/models/fp_lantern.glb") as PackedScene).instantiate()
	# hangs upright, its ring square to the link like two links of a chain
	lamp.basis = Basis(side, Vector3.UP, side.cross(Vector3.UP)) * Basis.from_scale(Vector3.ONE * LAMP_SCALE)
	lamp.position = Vector3.DOWN * (2.0 * LINK_R - 0.002) - lamp.basis * LAMP_RING
	pivot.add_child(lamp)
	return [pivot, lamp, arm]


## The left hand closed round the boathook's handle, the hook standing up out of the fist and
## the pole running on down out of sight. Returns [hook, arm, pole].
static func hook_rig(root: Node3D) -> Array:
	var arm := glove(false)
	root.add_child(arm)
	grip(arm, -HOOK_UP, HOOK_ELBOW, ARM_SCALE)   # thumb up, toward the head
	var hook: Node3D = (load("res://assets/models/fp_boathook.glb") as PackedScene).instantiate()
	hook.basis = align(HOOK_AXIS, Vector3.BACK, HOOK_UP, HOOK_FACE) * Basis.from_scale(Vector3.ONE * HOOK_SCALE)
	hook.position = -(hook.basis * HOOK_GRIP)
	root.add_child(hook)
	var pole := MeshInstance3D.new()   # the model's shaft is short: the pole runs on down from the fist
	var pc := CylinderMesh.new()
	pc.top_radius = 0.0085
	pc.bottom_radius = 0.0095
	pc.height = 0.8
	pc.radial_segments = 8
	pole.mesh = pc
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("#3b322b")   # dark, wet wood under the iron
	pmat.roughness = 0.9
	pole.material_override = pmat
	pole.basis = align(Vector3.UP, Vector3.BACK, HOOK_UP, HOOK_FACE)
	pole.position = -HOOK_UP.normalized() * 0.38
	root.add_child(pole)
	return [hook, arm, pole]


## A gloved fist. The mesh carries a stray wire loop (a second, separate part) that would hang
## out of the fingers: it is dropped so the fist only holds what it is given.
static func glove(mirror: bool) -> Node3D:
	var g: Node3D = (load(GLOVE) as PackedScene).instantiate()
	for m in g.find_children("*", "MeshInstance3D", true, false):
		_keep_largest_part(m as MeshInstance3D, mirror)
	return g


## Pose `g` (a child of the grip point's node) so its grip channel runs along `along`, through
## the origin, with the forearm heading toward `elbow`. The thumb lies toward +`along` on the
## right hand and toward -`along` on the left.
static func grip(g: Node3D, along: Vector3, elbow: Vector3, scale: float) -> void:
	var x := along.normalized()
	var y := (elbow - x * elbow.dot(x)).normalized()
	var b := Basis(x, y, x.cross(y))
	g.basis = b * Basis.from_scale(Vector3.ONE * scale)
	g.position = -(g.basis * GRIP)


## Basis that turns model axis `a` onto world `to`, keeping model +Z as close to `up_hint` as it can.
static func align(a: Vector3, z: Vector3, to: Vector3, up_hint: Vector3) -> Basis:
	var m := Basis(a.normalized(), z.cross(a).normalized(), z.normalized())
	var w1 := to.normalized()
	var w3 := (up_hint - w1 * up_hint.dot(w1)).normalized()
	var w := Basis(w1, w3.cross(w1), w3)
	return w * m.inverse()


## Keeps the mesh's biggest connected part; `mirror` flips it across X in the mesh data itself
## (a negative node scale turns the faces inside out on the Compatibility renderer).
static func _keep_largest_part(mi: MeshInstance3D, mirror: bool) -> void:
	var mesh := mi.mesh
	if mesh == null or mesh.get_surface_count() != 1:
		push_warning("hands: %s is not one surface, left as it is" % mi.name)
		return
	var arr: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		return
	var p := PackedInt32Array()
	p.resize(v.size())
	var seen := {}
	for i in v.size():   # weld split vertices (UV seams) by position
		var k := Vector3i((v[i] * 10000.0).round())
		p[i] = seen.get(k, i)
		seen[k] = p[i]
	for t in range(0, idx.size(), 3):
		var a := _root(p, idx[t])
		p[_root(p, idx[t + 1])] = a
		p[_root(p, idx[t + 2])] = a
	var count := {}
	for i in v.size():
		var r := _root(p, i)
		count[r] = count.get(r, 0) + 1
	var big: int = count.keys()[0]
	for r: int in count:
		if count[r] > count[big]:
			big = r
	var keep := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if _root(p, idx[t]) == big:
			keep.append(idx[t])
			keep.append(idx[t + 1])
			keep.append(idx[t + 2])
	if mirror:
		for i in v.size():
			v[i].x = -v[i].x
		arr[Mesh.ARRAY_VERTEX] = v
		if arr[Mesh.ARRAY_NORMAL] != null:
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in nn.size():
				nn[i].x = -nn[i].x
			arr[Mesh.ARRAY_NORMAL] = nn
		if arr[Mesh.ARRAY_TANGENT] != null:
			var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
			for i in range(0, tg.size(), 4):
				tg[i] = -tg[i]
				tg[i + 3] = -tg[i + 3]
			arr[Mesh.ARRAY_TANGENT] = tg
		for t in range(0, keep.size(), 3):   # flipped, so wind the other way round
			var k1 := keep[t + 1]
			keep[t + 1] = keep[t + 2]
			keep[t + 2] = k1
	arr[Mesh.ARRAY_INDEX] = keep
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	out.surface_set_material(0, mesh.surface_get_material(0))
	mi.mesh = out


static func _root(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i
