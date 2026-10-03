class_name Posture
extends SkeletonModifier3D

## Life on top of the animation, before her feet are planted:
##   - her head and neck turn toward where the camera looks (forward again
##     when it looks behind her, never snapping across),
##   - her chest rises and falls with her breath, shoulders lifting, deeper
##     as she strains, held full while she holds it,
##   - standing still, her weight drifts slowly from foot to foot (the planted
##     feet stay put, so the hips sway over them).

const LOOK_YAW := deg_to_rad(70.0)
const LOOK_PITCH := deg_to_rad(28.0)
const NECK_SHARE := 0.4

var breath: Breath
# World-space direction she should look along; zero means straight ahead.
var look: Callable
# 0 calm .. 1 gasping (Player.strain).
var strain: Callable
# Her ground speed, for the weight shift and how freely she looks around.
var speed := 0.0

var _neck := -1
var _head := -1
var _chest := -1
var _shoulders: Array[int] = []
var _hips := -1
var _yaw := 0.0
var _pitch := 0.0
var _idle := 0.0
var _last_msec := 0


static func fit(skeleton: Skeleton3D, before: Node) -> Posture:
	var posture := Posture.new()
	posture.name = "Posture"
	posture._neck = skeleton.find_bone("Neck")
	posture._head = skeleton.find_bone("Head")
	posture._chest = skeleton.find_bone("UpperChest")
	posture._hips = skeleton.find_bone("Hips")
	for bone in ["LeftShoulder", "RightShoulder"]:
		posture._shoulders.append(skeleton.find_bone(bone))
	skeleton.add_child(posture)
	# Ahead of the foot lock and the leg IK, so they see the swayed hips.
	if before and before.get_parent() == skeleton:
		skeleton.move_child(posture, before.get_index())
	return posture


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _head < 0:
		return
	var now := Time.get_ticks_msec()
	var delta := clampf(float(now - _last_msec) / 1000.0, 0.001, 0.1)
	_last_msec = now
	_look(skeleton, delta)
	_breathe(skeleton)
	_shift_weight(skeleton, delta, now)


func _look(skeleton: Skeleton3D, delta: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	var wanted: Vector3 = look.call() if look.is_valid() else Vector3.ZERO
	if wanted.length_squared() > 0.001:
		# Into the skeleton's own space, where the rig faces +Z.
		var local := (skeleton.global_transform.basis.inverse() * wanted).normalized()
		yaw = atan2(local.x, local.z)
		pitch = -asin(clampf(local.y, -1.0, 1.0)) * 0.6
		# Behind her: she does not wrench round, she faces forward.
		if absf(yaw) > deg_to_rad(115.0):
			yaw = 0.0
	var freedom := lerpf(1.0, 0.45, clampf((speed - 3.0) / 3.5, 0.0, 1.0))
	yaw = clampf(yaw, -LOOK_YAW, LOOK_YAW) * freedom
	pitch = clampf(pitch, -LOOK_PITCH, LOOK_PITCH) * freedom
	var ease := 1.0 - exp(-delta * 4.0)
	_yaw = lerpf(_yaw, yaw, ease)
	_pitch = lerpf(_pitch, pitch, ease)
	_turn(skeleton, _neck, Basis(Vector3.UP, _yaw * NECK_SHARE) * Basis(Vector3.RIGHT, _pitch * NECK_SHARE))
	_turn(skeleton, _head, Basis(Vector3.UP, _yaw * (1.0 - NECK_SHARE)) * Basis(Vector3.RIGHT, _pitch * (1.0 - NECK_SHARE)))


func _breathe(skeleton: Skeleton3D) -> void:
	if breath == null:
		return
	var effort: float = strain.call() if strain.is_valid() else 0.0
	var fill := breath.fullness()
	var depth := lerpf(0.012, 0.055, clampf(effort, 0.0, 1.0)) * fill
	# The chest opens and lifts on the in-breath.
	_turn(skeleton, _chest, Basis(Vector3.RIGHT, -depth))
	for index in _shoulders.size():
		var side := 1.0 if index == 0 else -1.0
		_turn(skeleton, _shoulders[index], Basis(Vector3.BACK, side * depth * 0.9))


func _shift_weight(skeleton: Skeleton3D, delta: float, now: int) -> void:
	_idle = move_toward(_idle, 1.0 if speed < 0.25 else 0.0, delta * (0.6 if speed < 0.25 else 3.0))
	if _idle <= 0.001 or _hips < 0:
		return
	var t := float(now) / 1000.0
	var sway := (sin(t * 0.55) * 0.8 + sin(t * 1.3 + 1.7) * 0.2) * 0.022 * _idle
	var parent := skeleton.get_bone_parent(_hips)
	var to_parent := skeleton.get_bone_global_pose(parent).basis.inverse() if parent >= 0 else Basis()
	skeleton.set_bone_pose_position(_hips, skeleton.get_bone_pose_position(_hips) + to_parent * Vector3(sway, -absf(sway) * 0.25, 0.0))
	# The body rolls slightly against the hips, as people stand.
	_turn(skeleton, _hips, Basis(Vector3.BACK, -sway * 0.9))


## Rotates a bone about its own origin by `turn`, given in skeleton space.
func _turn(skeleton: Skeleton3D, bone: int, turn: Basis) -> void:
	if bone < 0:
		return
	var global := skeleton.get_bone_global_pose(bone)
	var turned := Transform3D(turn * global.basis, global.origin)
	var parent := skeleton.get_bone_parent(bone)
	var local := turned
	if parent >= 0:
		local = skeleton.get_bone_global_pose(parent).affine_inverse() * turned
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
