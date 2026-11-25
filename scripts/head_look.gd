extends SkeletonModifier3D
## Turns a horror's head to look at you, on top of whatever clip is playing (look only, never a rule).
## It doesn't glide: it holds, then snaps to where you are now, like something that noticed.
## Works in skeleton space and only needs the body's forward, so it doesn't care how the rig's
## head bone is oriented.

var target: Node3D                 # the camera
var actor: Node3D                  # the body whose +Z is "forward"
var bone := "Head"
var max_yaw := 1.3                 # rad either way from the body's forward (the bride gets more)
var max_pitch := 0.5
var hold := Vector2(0.35, 1.1)     # s between snaps (random in this range)
var snap_rate := 22.0              # how fast a snap lands (higher = harder)
var locked := false                # the kill: no holding, eyes on you every frame

var _bone_i := -1
var _want := Quaternion.IDENTITY
var _cur := Quaternion.IDENTITY
var _wait := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or target == null or actor == null:
		return
	if _bone_i < 0:
		_bone_i = skel.find_bone(bone)
		if _bone_i < 0:
			return
	var inv := skel.global_basis.inverse()
	var pose := skel.get_bone_global_pose(_bone_i)
	_wait -= delta
	if _wait <= 0.0 or locked:
		_wait = randf_range(hold.x, hold.y)
		var fwd := (inv * actor.global_basis.z).normalized()
		var up := (inv * Vector3.UP).normalized()
		var to := skel.global_transform.affine_inverse() * target.global_position - pose.origin
		if to.length() < 0.001:
			return
		to = to.normalized()
		# split into yaw (around up) and pitch, clamp each, rebuild
		var flat := (to - up * to.dot(up))
		var yaw := 0.0
		if flat.length() > 0.001:
			yaw = fwd.signed_angle_to(flat.normalized(), up)
		yaw = clampf(yaw, -max_yaw, max_yaw)
		var pitch := clampf(asin(clampf(to.dot(up), -1.0, 1.0)), -max_pitch, max_pitch)
		var level := fwd.rotated(up, yaw)
		var aim := level.rotated(up.cross(level).normalized(), -pitch)   # about up x level, minus = upward
		_want = Quaternion(fwd, aim.normalized())
	_cur = _cur.slerp(_want, 1.0 - exp(-delta * (40.0 if locked else snap_rate)))
	pose.basis = Basis(_cur) * pose.basis
	skel.set_bone_global_pose(_bone_i, pose)
