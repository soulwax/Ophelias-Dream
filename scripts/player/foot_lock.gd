class_name FootLock
extends SkeletonModifier3D

# Detects planted feet after animation; optional leg IK holds them in place:
# when the animation sets a foot down, that spot on the terrain is locked and
# IK can hold the foot there while the body travels over it. When
# the animation lifts the foot (or the leg would overstretch) the IK fades
# out and the foot swings free to its next step. Each touchdown is reported,
# so steps, prints and powder come from real contacts.

signal planted(left: bool, at: Vector3)

const DOWN := 0.03
const UP := 0.07
const STILL := 0.6
# The lowest a foot has been lately creeps up this fast (m/s), so contact is
# judged against each foot's own recent floor, not a fixed rest height.
const FLOOR_CREEP := 0.08
# How far a foot must rise between landings to count as a new step.
const SWING := 0.05
const OVERREACH := 0.42
const BLEND_IN := 0.06
const BLEND_OUT := 0.14

var ground: Ground
# Height of whatever she stands on under a point: the snow outside, the
# boards and tile indoors. Falls back to the terrain when unset.
var floor_at: Callable
# Her ground speed, set by the player each frame: a planted foot may drift a
# little more in the world at speed, where gaits are blended.
var body_speed := 0.0
# In the air or sliding, nothing is planted: feet go where the pose puts them.
var suspended := false
var _model: Node3D
var _feet: Array = []
var _last_msec := 0


# model: the rig root, which may also hold foot targets and leg IK nodes.
static func fit(model: Node3D, skeleton: Skeleton3D, left_bone := "LeftFoot", right_bone := "RightFoot") -> FootLock:
	var lock := FootLock.new()
	lock.name = "FootLock"
	lock._model = model
	for side in ["L", "R"]:
		var bone_name := left_bone if side == "L" else right_bone
		var ik := skeleton.get_node_or_null(side + "_LegIK3D") as SkeletonModifier3D
		var target := model.get_node_or_null(side + "_foot_target") as Node3D
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		lock._feet.append({
			"left": side == "L",
			"bone": bone,
			"ik": ik,
			"target": target,
			"ankle": skeleton.get_bone_global_rest(bone).origin.y,
			"locked": false,
			"at": Vector3.ZERO,
			"last": Vector3.ZERO,
			"weight": 0.0,
			"floor": 0.0,
		})
	skeleton.add_child(lock)
	# Modifiers run in child order; this one must see the pose before the IK.
	var first := skeleton.get_child_count()
	for foot in lock._feet:
		if foot["ik"] != null:
			first = mini(first, (foot["ik"] as Node).get_index())
	skeleton.move_child(lock, first)
	return lock


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _feet.is_empty():
		return
	var now := Time.get_ticks_msec()
	var delta := clampf(float(now - _last_msec) / 1000.0, 0.001, 0.1)
	_last_msec = now
	var to_world := skeleton.global_transform
	var floor_y := _model.global_position.y
	var scale_y := _model.global_transform.basis.get_scale().y
	for foot in _feet:
		var animated: Vector3 = to_world * skeleton.get_bone_global_pose(foot["bone"]).origin
		var last: Vector3 = foot["last"]
		var drift := Vector2(animated.x - last.x, animated.z - last.z).length() / delta
		foot["last"] = animated
		# Height of the ankle above where it rests when standing, judged
		# against the lowest this foot has been lately.
		var lift := animated.y - floor_y - float(foot["ankle"]) * scale_y
		var low := minf(float(foot["floor"]) + FLOOR_CREEP * delta, lift)
		foot["floor"] = low
		var still := STILL + 0.35 * body_speed
		# A sprint's contact can be shorter than a frame: also count the
		# bottom of the swing, where the foot stops falling and starts rising.
		var falling := lift < float(foot.get("lift", lift))
		var bottomed := bool(foot.get("falling", false)) and not falling and lift < low + DOWN * 2.0
		foot["falling"] = falling
		foot["lift"] = lift
		# A foot only lands again after it has really swung: blended gaits
		# wobble near the ground, and a wobble is not a step.
		foot["peak"] = maxf(float(foot.get("peak", 1.0)), lift - low)
		var swung := float(foot["peak"]) > SWING
		var locked: bool = foot["locked"]
		if suspended:
			locked = false
			foot["peak"] = 1.0
		elif not locked and swung and ((lift < low + DOWN and drift < still) or bottomed):
			locked = true
			foot["peak"] = 0.0
			foot["at"] = _on_ground(animated, floor_y)
			planted.emit(foot["left"], foot["at"])
		elif locked:
			var reach := Vector2(animated.x - (foot["at"] as Vector3).x, animated.z - (foot["at"] as Vector3).z).length()
			if lift > low + UP or reach > OVERREACH:
				locked = false
		foot["locked"] = locked
		var rate := delta / (BLEND_IN if locked else BLEND_OUT)
		foot["weight"] = move_toward(foot["weight"], 1.0 if locked else 0.0, rate)
		if foot["ik"] != null and foot["target"] != null:
			var target := foot["at"] as Vector3 if locked else _on_ground(animated, floor_y)
			(foot["target"] as Node3D).global_position = target
			(foot["ik"] as SkeletonModifier3D).influence = foot["weight"]


# The animated ankle, moved by however much the terrain under the foot
# differs from the terrain under her: the uphill foot lands higher.
func _on_ground(animated: Vector3, floor_y: float) -> Vector3:
	var under := floor_y
	if floor_at.is_valid():
		under = floor_at.call(animated)
	elif ground:
		under = ground.height_at(animated.x, animated.z)
	return Vector3(animated.x, animated.y + (under - floor_y), animated.z)
