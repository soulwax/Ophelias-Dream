class_name Leap
extends SkeletonModifier3D

# Her running leap's carriage, layered after Grace: the split, pointed toes,
# opening arms and a lifted chest in the air, and a catlike dip on the lead
# leg when she lands. The math is static so it can be checked headlessly
# (tools/leap_math_probe.gd).

const BONES := ["DEF-spine", "DEF-spine.004", "DEF-spine.006",
	"DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
	"DEF-thigh.L", "DEF-shin.L", "DEF-foot.L",
	"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R"]

# Set by the player each tick: how much of the line shows (0 on the ground),
# how far through the flight she is, and which leg leads.
var amount := 0.0
var progress := 0.0
var lead_left := true
var _dip := 0.0
var _dip_speed := 0.0
var _dip_left := true
var _bones := {}
var _last_msec := 0
# This frame's pose before Leap: each bone's own and its parent's, in
# skeleton space. Global poses go stale once a parent is written (see Grace).
var _pose := {}
var _parent := {}


static func fit(skeleton: Skeleton3D) -> Leap:
	var leap := Leap.new()
	leap.name = "Leap"
	for name in BONES:
		var bone := skeleton.find_bone(name)
		if bone < 0:
			push_warning("Leap: missing bone " + name)
			return leap
		leap._bones[name] = bone
	skeleton.add_child(leap)
	return leap


# She has landed: the spring sinks her on the lead leg, deeper for a harder
# drop (power 0..1), then lets her rise.
func dip(power: float, left: bool) -> void:
	_dip_left = left
	_dip_speed = dip_kick(lerpf(Tune.LEAP_DIP_DEPTH, Tune.LEAP_DIP_DROP, power))


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _bones.size() < BONES.size():
		return
	var now := Time.get_ticks_msec()
	var delta := clampf(float(now - _last_msec) / 1000.0, 0.001, 0.1)
	_last_msec = now
	var next := spring(_dip, _dip_speed, delta)
	_dip = next.x
	_dip_speed = next.y
	var crouch := maxf(_dip, 0.0)
	if amount <= 0.001 and crouch <= 0.0005:
		return
	for name in BONES:
		var bone: int = _bones[name]
		_pose[name] = skeleton.get_bone_global_pose(bone)
		var up := skeleton.get_bone_parent(bone)
		_parent[name] = skeleton.get_bone_global_pose(up) if up >= 0 else Transform3D()
	if amount > 0.001:
		_hold_line(skeleton)
	if crouch > 0.0005:
		_crouch(skeleton, crouch)


# In skeleton space +Z is forward and +X her left; turning a hanging limb by
# +X swings it back, and turning a foot by +X tips its toes down.
func _hold_line(skeleton: Skeleton3D) -> void:
	var shape := line(progress, amount)
	var lead := "L" if lead_left else "R"
	var trail := "R" if lead_left else "L"
	# The lead thigh reaches, the trailing one extends behind, and the
	# trailing knee all but straightens.
	_turn(skeleton, "DEF-thigh." + lead, Quaternion(Vector3.RIGHT, -shape.split))
	_turn(skeleton, "DEF-thigh." + trail, Quaternion(Vector3.RIGHT, shape.split))
	var thigh := (_pose["DEF-thigh." + trail] as Transform3D).basis.y.normalized()
	var shin := (_pose["DEF-shin." + trail] as Transform3D).basis.y.normalized()
	if thigh.dot(shin) < 0.9999:
		_turn(skeleton, "DEF-shin." + trail, Quaternion.IDENTITY.slerp(Quaternion(shin, thigh), shape.straighten))
	_turn(skeleton, "DEF-foot." + trail, Quaternion(Vector3.RIGHT, shape.point_trail))
	_turn(skeleton, "DEF-foot." + lead, Quaternion(Vector3.RIGHT, shape.point_lead))
	# The arm opposite the lead leg comes forward and a little open; the
	# other sweeps back and out. Elbows stay soft.
	for side in ["L", "R"]:
		var outward := 1.0 if side == "L" else -1.0
		var forward: bool = side == trail
		var swing: float = -shape.arms if forward else shape.arms * 0.8
		var open: float = outward * shape.arms * (0.25 if forward else 0.45)
		_turn(skeleton, "DEF-upper_arm." + side, Quaternion(Vector3.BACK, open) * Quaternion(Vector3.RIGHT, swing))
		_turn(skeleton, "DEF-forearm." + side, Quaternion(Vector3.RIGHT, -deg_to_rad(18.0 if forward else 6.0) * amount))
	# Chest lifted; the head keeps level.
	var lift := Quaternion(Vector3.RIGHT, -shape.chest)
	_turn(skeleton, "DEF-spine.004", lift)
	_turn(skeleton, "DEF-spine.006", lift.inverse())


# Hips down by depth metres. The planted leg folds half at the hip and half
# at the ankle around its knee, so the foot stays where it landed; the chest
# tips forward a touch and the head stays level.
func _crouch(skeleton: Skeleton3D, depth: float) -> void:
	var drop := depth / Tune.PLAYER_MODEL_SCALE
	var hips: int = _bones["DEF-spine"]
	var moved := (_parent["DEF-spine"] as Transform3D).basis.inverse() * Vector3(0.0, -drop, 0.0)
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips) + moved)
	var side := "L" if _dip_left else "R"
	var hip := (_pose["DEF-thigh." + side] as Transform3D).origin
	var knee := (_pose["DEF-shin." + side] as Transform3D).origin
	var ankle := (_pose["DEF-foot." + side] as Transform3D).origin
	var fold := knee_fold(hip.distance_to(knee), knee.distance_to(ankle), hip.distance_to(ankle), drop)
	_turn(skeleton, "DEF-thigh." + side, Quaternion(Vector3.RIGHT, -fold * 0.5))
	_turn(skeleton, "DEF-shin." + side, Quaternion(Vector3.RIGHT, fold))
	_turn(skeleton, "DEF-foot." + side, Quaternion(Vector3.RIGHT, -fold * 0.5))
	var tip := Quaternion(Vector3.RIGHT, Tune.LEAP_DIP_LEAN * depth)
	_turn(skeleton, "DEF-spine.004", tip)
	_turn(skeleton, "DEF-spine.006", tip.inverse())


# Rotates a bone by a skeleton-space rotation about its head, written into its
# local pose through the parent's pose as Leap found it (Grace's method).
func _turn(skeleton: Skeleton3D, name: String, rotation: Quaternion) -> void:
	if rotation.is_equal_approx(Quaternion.IDENTITY):
		return
	var bone: int = _bones[name]
	var frame := (_parent[name] as Transform3D).basis.orthonormalized().get_rotation_quaternion()
	var local := frame.inverse() * rotation * frame
	skeleton.set_bone_pose_rotation(bone, (local * skeleton.get_bone_pose_rotation(bone)).normalized())


# Seconds from takeoff to landing on flat ground for a jump leaving at rise
# m/s with jump held: Player's gravity, its apex hang within APEX_SPEED and
# its heavier fall.
static func airtime(rise: float) -> float:
	var g := Tune.GRAVITY
	var band := minf(Tune.APEX_SPEED, rise)
	var up := (rise - band) / g
	var hang := band / (g * Tune.APEX_HANG)
	# Down through the hang band again, then the rest at fall gravity.
	var left := (rise * rise - band * band) / (2.0 * g)
	var fall_g := g * Tune.FALL_GRAVITY
	var down := (-band + sqrt(band * band + 2.0 * fall_g * left)) / fall_g
	return up + hang * 2.0 + down


# 0..1 through the flight. Time leads until LEAP_REACH_HOLD; from there only
# the ground coming up (drop, metres below her feet) finishes the reach, so
# off a ledge she holds it.
static func flight_progress(air_time: float, flight: float, drop: float) -> float:
	var by_time := maxf(air_time / maxf(flight, 0.1), 0.0)
	if by_time < Tune.LEAP_REACH_HOLD:
		return by_time
	var near := 1.0 - clampf(drop / Tune.LEAP_REACH_HEIGHT, 0.0, 1.0)
	return lerpf(Tune.LEAP_REACH_HOLD, 1.0, near)


# One step of her landing spring: crouch x (metres, positive is lower) and its
# speed v, slightly under-damped so she sinks, springs back and settles.
static func spring(x: float, v: float, dt: float) -> Vector2:
	var w := Tune.LEAP_DIP_FREQ
	var z := Tune.LEAP_DIP_ZETA
	var steps := maxi(1, ceili(dt * 240.0))
	var h := dt / float(steps)
	for i in steps:
		v += (-w * w * x - 2.0 * z * w * v) * h
		x += v * h
	return Vector2(x, v)


# The speed a landing gives the spring so its deepest point is about depth
# (at damping 0.6 the peak is half of kick / frequency).
static func dip_kick(depth: float) -> float:
	return 2.0 * depth * Tune.LEAP_DIP_FREQ


# How much further the knee must fold (radians) for a leg of thigh a and
# shin b, hip-to-ankle span now, to come drop shorter.
static func knee_fold(a: float, b: float, span: float, drop: float) -> float:
	var lo := absf(a - b) + 0.001
	var hi := a + b - 0.001
	var now := acos(clampf((a * a + b * b - pow(clampf(span, lo, hi), 2.0)) / (2.0 * a * b), -1.0, 1.0))
	var then := acos(clampf((a * a + b * b - pow(clampf(span - drop, lo, hi), 2.0)) / (2.0 * a * b), -1.0, 1.0))
	return now - then


# Her line at this point of the flight. The split swells to its widest at 40%
# and is gone by the reach; the lead foot unpoints for a ball-first landing.
static func line(through: float, strength: float) -> Dictionary:
	var p := clampf(through, 0.0, 1.0)
	var swell := strength * sin(PI * clampf(p / 0.8, 0.0, 1.0))
	return {
		"split": Tune.LEAP_SPLIT * swell,
		"straighten": 0.7 * swell,
		"point_trail": Tune.LEAP_POINT * strength,
		"point_lead": Tune.LEAP_POINT * strength * lerpf(1.0, 0.25, smoothstep(0.75, 1.0, p)),
		"arms": Tune.LEAP_ARMS * swell,
		"chest": Tune.LEAP_CHEST * strength * (1.0 - smoothstep(0.8, 1.0, p)),
	}
