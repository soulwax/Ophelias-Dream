class_name Grace
extends SkeletonModifier3D

# Her carriage on top of the baked clips, in the elf's skeleton space (+Z is
# forward, +X her left). Her walk already swings its arms, so a walk only
# gets a little looseness taken from the legs, elbows that soften as each hand
# comes forward, and shoulders that turn against the hips while the head
# stays level. At a sprint the athletic clip holds its elbows wide, so she
# draws them in. Standing a while, she rises onto her toes and lets herself
# back down. Setting off, she leans into the first step; stopping, she sits
# back onto the foot that landed. Standing, her weight shifts, she looks
# about, and one foot taps. Runs after FootLock, so steps are judged on the clip.
#
# Global poses read back inside a modification go stale once a parent is
# written, so every turn is written as a local rotation, conjugated through
# the parent's pose as the clip left it.

const BONES := ["DEF-spine", "DEF-spine.003", "DEF-spine.004", "DEF-spine.006",
	"DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
	"DEF-thigh.L", "DEF-shin.L", "DEF-thigh.R", "DEF-shin.R", "DEF-foot.L", "DEF-toe.L", "DEF-foot.R", "DEF-toe.R"]

# Her ground speed and how much she is upright on her feet (0 in the air,
# sliding or spent), set by the player each frame.
var speed := 0.0
var poise := 1.0
# 0 looking ahead .. 1 looking back over her right shoulder.
var glance := 0.0
var _bones := {}
var _idle := 0.0
var _tiptoe := 0.0
var _speed_was := 0.0
var _drive := 0.0
var _depart := 0.0
var _settle := 0.0
var _last_msec := 0
# This frame's clip pose: each bone's own and its parent's, in skeleton space.
var _pose := {}
var _parent := {}


static func fit(skeleton: Skeleton3D) -> Grace:
	var grace := Grace.new()
	grace.name = "Grace"
	for name in BONES:
		var bone := skeleton.find_bone(name)
		if bone < 0:
			push_warning("Grace: missing bone " + name)
			return grace
		grace._bones[name] = bone
	skeleton.add_child(grace)
	return grace


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _bones.size() < BONES.size():
		return
	var now := Time.get_ticks_msec()
	var delta := clampf(float(now - _last_msec) / 1000.0, 0.001, 0.1)
	_last_msec = now
	for name in BONES:
		var bone: int = _bones[name]
		_pose[name] = skeleton.get_bone_global_pose(bone)
		var up := skeleton.get_bone_parent(bone)
		_parent[name] = skeleton.get_bone_global_pose(up) if up >= 0 else Transform3D()
	var raw := (speed - _speed_was) / delta
	_speed_was = speed
	_drive = lerpf(_drive, clampf(raw, -16.0, 16.0), 1.0 - exp(-12.0 * delta))
	if _drive > 2.2 and speed < 1.8 and poise > 0.5:
		_depart = 1.0
	else:
		_depart = move_toward(_depart, 0.0, delta * 3.2)
	if _drive < -2.0 and speed < 2.4 and poise > 0.5:
		_settle = 1.0
	else:
		_settle = move_toward(_settle, 0.0, delta * (1.6 if speed < 0.15 else 3.0))
	var walk := smoothstep(0.15, 0.9, speed) * (1.0 - smoothstep(1.9, 2.5, speed)) * poise
	# Arms keep swinging through the jog and only tuck away into the sprint.
	var arms := smoothstep(0.25, 1.0, speed) * (1.0 - smoothstep(3.5, 5.0, speed)) * poise
	var light := smoothstep(2.0, 2.7, speed) * (1.0 - smoothstep(3.3, 4.4, speed)) * poise
	var sprint := smoothstep(3.6, 5.4, speed) * poise
	# +1 with her left leg reaching forward, -1 with the right.
	var reach_l: float = (_pose["DEF-thigh.L"] as Transform3D).basis.y.z
	var reach_r: float = (_pose["DEF-thigh.R"] as Transform3D).basis.y.z
	var legs := clampf((reach_l - reach_r) / 0.6, -1.0, 1.0)
	_tiptoe = move_toward(_tiptoe, _tiptoe_target(delta), delta * (1.2 if speed < 0.15 else 5.0))
	var rise := smoothstep(0.0, 1.0, _tiptoe)

	# Shoulders turn against the hips: her left shoulder draws back as the
	# left leg reaches. Above that the chest is a touch lifted and open,
	# more so up on her toes.
	# Looking back, her chest turns toward the right shoulder and her head
	# carries the rest of the way.
	var back := Quaternion(Vector3.UP, -Tune.GLANCE_CHEST * glance)
	var counter := Quaternion(Vector3.UP, Tune.GRACE_COUNTER_TURN * legs * walk) * back
	var lean := Quaternion(Vector3.RIGHT, (-Tune.DEPART_LEAN * _depart + Tune.SETTLE_LEAN * _settle) * poise)
	var lift := Quaternion(Vector3.RIGHT, -(Tune.GRACE_CHEST_LIFT + 0.03 * rise + Tune.JOG_LIFT * light) * poise)
	_turn(skeleton, "DEF-spine.003", counter * lean)
	_turn(skeleton, "DEF-spine.004", lift)
	for side in ["L", "R"]:
		var sign := 1.0 if side == "L" else -1.0
		# Each arm swings against the leg on its own side, back as it
		# reaches. The elbows stay out from the dress, a little more up on
		# her toes. The run keeps the tuck it already had.
		var swing := Tune.GRACE_ARM_SWING * legs * sign * arms
		var open := lerpf(Tune.GRACE_ELBOW_OUT, -3.0, sprint)
		var hang := sign * (deg_to_rad(open + 4.0 * rise) * poise - Tune.GRACE_SPRINT_TUCK * sprint)
		_turn(skeleton, "DEF-upper_arm." + side, Quaternion(Vector3.BACK, hang) * Quaternion(Vector3.RIGHT, swing))
		# The elbow stays soft and folds as the hand comes forward.
		var ahead := clampf(-legs * sign, 0.0, 1.0)
		_turn(skeleton, "DEF-forearm." + side, Quaternion(Vector3.RIGHT, -deg_to_rad(Tune.GRACE_ELBOW_FOLD * (0.3 + 0.7 * ahead)) * arms))
	if rise > 0.001:
		_rise_onto_toes(skeleton, rise)
	_shift_hips(skeleton, _stance(rise))
	# The head keeps its own carriage, so the turning chest never rocks it;
	# up on her toes the chin lifts a little. Standing, she looks about.
	var chin := Quaternion(Vector3.RIGHT, -0.04 * rise)
	var look := Quaternion(Vector3.UP, -(Tune.GLANCE_CHEST + Tune.GLANCE_HEAD) * glance)
	var gaze := _gaze()
	look = Quaternion(Vector3.UP, gaze.x) * Quaternion(Vector3.RIGHT, gaze.y) * look
	_turn(skeleton, "DEF-spine.006", (counter * lift * lean).inverse() * look * chin)
	_tap(skeleton, rise)


# Hip offset for the first step, the plant, and the slow idle weight shift.
func _stance(rise: float) -> Vector3:
	var back := -0.022 * _depart * poise
	var drop := -0.014 * _settle * poise
	var side := 0.0
	if _settle > 0.05:
		var left_forward: float = (_pose["DEF-thigh.L"] as Transform3D).basis.y.z
		var right_forward: float = (_pose["DEF-thigh.R"] as Transform3D).basis.y.z
		side = (0.02 if left_forward >= right_forward else -0.02) * _settle * poise
	var idle_w := (1.0 - smoothstep(0.05, 0.28, speed)) * poise * (1.0 - rise)
	if idle_w > 0.02 and _settle < 0.25:
		var phase := sin(_idle * 0.55)
		side += phase * Tune.IDLE_SHIFT * idle_w
		drop += -0.005 * absf(phase) * idle_w
	return Vector3(side, drop, back)


func _shift_hips(skeleton: Skeleton3D, shift: Vector3) -> void:
	if shift.length_squared() < 0.0000001:
		return
	var hips: int = _bones["DEF-spine"]
	var moved := (_parent["DEF-spine"] as Transform3D).basis.inverse() * shift
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips) + moved)


# Where she is looking while she stands: held glances, then an ease to the next.
func _gaze() -> Vector2:
	var idle_w := (1.0 - smoothstep(0.05, 0.28, speed)) * poise * (1.0 - glance)
	if idle_w < 0.02:
		return Vector2.ZERO
	var holds: Array[Vector2] = [
		Vector2(0.0, 0.02),
		Vector2(0.22, 0.0),
		Vector2(0.14, 0.1),
		Vector2(0.0, 0.0),
		Vector2(-0.24, 0.03),
		Vector2(-0.08, 0.12),
		Vector2(0.0, 0.0),
	]
	var span := 2.1
	var i := int(_idle / span) % holds.size()
	var j := (i + 1) % holds.size()
	var u := smoothstep(0.62, 1.0, fmod(_idle, span) / span)
	return holds[i].lerp(holds[j], u) * idle_w * (1.0 - _tiptoe * 0.65)


# Two quick taps of one foot, alternating sides, once she has been still a moment.
func _tap(skeleton: Skeleton3D, rise: float) -> void:
	if rise > 0.2 or _settle > 0.35 or speed > 0.2 or poise < 0.95:
		return
	var slot := int(_idle / Tune.IDLE_TAP_EVERY)
	var local := fmod(_idle, Tune.IDLE_TAP_EVERY)
	if local < Tune.IDLE_TAP_AT or local > Tune.IDLE_TAP_AT + Tune.IDLE_TAP_LEN:
		return
	var u := (local - Tune.IDLE_TAP_AT) / Tune.IDLE_TAP_LEN
	var tap := maxf(sin(u * TAU * 2.0), 0.0)
	var side := "L" if slot % 2 == 0 else "R"
	_turn(skeleton, "DEF-thigh." + side, Quaternion(Vector3.RIGHT, -0.14 * tap))
	_turn(skeleton, "DEF-shin." + side, Quaternion(Vector3.RIGHT, 0.22 * tap))
	_turn(skeleton, "DEF-foot." + side, Quaternion(Vector3.RIGHT, -0.5 * tap))


# 0..1: how far up on her toes she should be. After standing still for
# Tune.TIPTOE_AFTER she rises, holds, settles back down and rests, again.
func _tiptoe_target(delta: float) -> float:
	if speed > 0.15 or poise < 0.99:
		_idle = 0.0
		return 0.0
	_idle += delta
	var into := _idle - Tune.TIPTOE_AFTER
	if into < 0.0:
		return 0.0
	var t := fmod(into, Tune.TIPTOE_CYCLE)
	if t < 1.2:
		return t / 1.2
	if t < 3.8:
		return 1.0
	if t < 5.0:
		return 1.0 - (t - 3.8) / 1.2
	return 0.0


# Lifts her by however far the feet allow, then pitches each foot so the ball
# stays where it stood and the toes stay flat on the ground. A steeper foot
# is shorter from above, so she also comes forward over her toes.
func _rise_onto_toes(skeleton: Skeleton3D, rise: float) -> void:
	var height := Tune.TIPTOE_LIFT
	for side in ["L", "R"]:
		var reach := (_pose["DEF-toe." + side] as Transform3D).origin - (_pose["DEF-foot." + side] as Transform3D).origin
		height = minf(height, maxf(reach.length() * sin(Tune.TIPTOE_PITCH) + reach.y, 0.0))
	height *= rise
	var shift := Vector3(0.0, height, 0.0)
	for side in ["L", "R"]:
		var reach := (_pose["DEF-toe." + side] as Transform3D).origin - (_pose["DEF-foot." + side] as Transform3D).origin
		var across := Vector3(reach.x, 0.0, reach.z)
		var drop := minf(-reach.y + height, reach.length())
		var forward := across.length() - sqrt(reach.length_squared() - drop * drop)
		shift += across.normalized() * forward * 0.5
	var hips: int = _bones["DEF-spine"]
	var moved := (_parent["DEF-spine"] as Transform3D).basis.inverse() * shift
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips) + moved)
	for side in ["L", "R"]:
		var ankle := (_pose["DEF-foot." + side] as Transform3D).origin
		var ball := (_pose["DEF-toe." + side] as Transform3D).origin
		var from := (ball - ankle).normalized()
		var to := (ball - ankle - shift).normalized()
		if from.dot(to) > 0.99999:
			continue
		var pitch := Quaternion(from, to)
		_turn(skeleton, "DEF-foot." + side, pitch)
		_turn(skeleton, "DEF-toe." + side, pitch.inverse())


# Rotates a bone by a skeleton-space rotation about its head, written into its
# local pose through the parent's clip pose.
func _turn(skeleton: Skeleton3D, name: String, rotation: Quaternion) -> void:
	if rotation.is_equal_approx(Quaternion.IDENTITY):
		return
	var bone: int = _bones[name]
	var frame := (_parent[name] as Transform3D).basis.orthonormalized().get_rotation_quaternion()
	var local := frame.inverse() * rotation * frame
	skeleton.set_bone_pose_rotation(bone, (local * skeleton.get_bone_pose_rotation(bone)).normalized())
