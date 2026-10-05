extends SceneTree

# Bakes her feminine-style locomotion from the Bandai Namco Research Motion
# Dataset 1 (Bandai Namco Research Inc., CC BY-NC 4.0) onto the elf.
#   python tools/fetch_motion.py
#   godot --headless --path . -s tools/retarget_bvh.gd
#
# Godot has no BVH importer, so the takes are read here. Forward kinematics
# gives every joint's position, and the elf is posed from those positions
# alone: limbs by bone direction, the torso by its left-right and up axes. The
# dataset's zero pose is not a T-pose (joint orientations are folded into the
# rotations), so nothing is taken from its rest. Each take walks across the
# room from standing; one steady gait cycle is cut from it, turned to face +Z,
# made to loop in place, set on the ground, and baked under a role name.

const SOURCE := "res://build/bandai/%s.bvh"
const TARGET := "res://assets/characters/styloo_elf/elf.glb"
const OUTPUT := "res://assets/characters/styloo_elf/feminine/elf_feminine.res"
# [take, clip]
# The second walk take lifts a hand to shoulder height mid-stride, which reads
# as a wave; the left and right takes turn rather than sidestep.
const TAKES := [
	["dataset-1_walk_feminine_001", "Walk"],
	["dataset-1_run_feminine_001", "Jog"],
	["dataset-1_dash_feminine_001", "Run"],
	["dataset-1_walk-back_feminine_001", "Walk_Back"],
]
# The bones the Quaternius bake writes, so her idle and these clips blend
# bone for bone.
const TRACKED := ["DEF-spine", "DEF-spine.001", "DEF-spine.003", "DEF-spine.004", "DEF-spine.005", "DEF-spine.006",
	"DEF-shoulder.L", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L",
	"DEF-shoulder.R", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R",
	"DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-toe.L",
	"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R", "DEF-toe.R"]
# Torso bones posed by a frame: [elf bone, source up from, source up to,
# elf up from, elf up to, which left-right pair].
const TORSO := [
	["DEF-spine", "Hips", "Spine", "DEF-spine", "DEF-spine.001", "hips"],
	["DEF-spine.001", "Spine", "Chest", "DEF-spine.001", "DEF-spine.003", "waist"],
	["DEF-spine.003", "Chest", "Neck", "DEF-spine.003", "DEF-spine.005", "shoulders"],
]
# The dataset's head joint sits lower on the neck than the elf's, so a neck
# taken from it tips her face up. Neck and head keep the chest's carriage.
const CARRIED := ["DEF-spine.005", "DEF-spine.006"]
# Limbs posed by direction: [elf bone, elf child, source joint, source child].
const LIMBS := [
	["DEF-shoulder.L", "DEF-upper_arm.L", "Shoulder_L", "UpperArm_L"],
	["DEF-upper_arm.L", "DEF-forearm.L", "UpperArm_L", "LowerArm_L"],
	["DEF-forearm.L", "DEF-hand.L", "LowerArm_L", "Hand_L"],
	["DEF-shoulder.R", "DEF-upper_arm.R", "Shoulder_R", "UpperArm_R"],
	["DEF-upper_arm.R", "DEF-forearm.R", "UpperArm_R", "LowerArm_R"],
	["DEF-forearm.R", "DEF-hand.R", "LowerArm_R", "Hand_R"],
	["DEF-thigh.L", "DEF-shin.L", "UpperLeg_L", "LowerLeg_L"],
	["DEF-shin.L", "DEF-foot.L", "LowerLeg_L", "Foot_L"],
	["DEF-foot.L", "DEF-toe.L", "Foot_L", "Toes_L"],
	["DEF-thigh.R", "DEF-shin.R", "UpperLeg_R", "LowerLeg_R"],
	["DEF-shin.R", "DEF-foot.R", "LowerLeg_R", "Foot_R"],
	["DEF-foot.R", "DEF-toe.R", "Foot_R", "Toes_R"],
]
# Frames blended across the loop seam.
const SEAM := 5
# Share of each take that survives onto the elf. The feminine walk's hips
# travel like a runway, so the side-to-side is quieter, while the arms swing
# further than the take. The jog keeps its step and loses most of the pound
# (bob): the drop shrinks more than the rise, so it reads light.
const QUIET := {
	"Walk": {"hips": 0.72, "roll": 0.5, "arms": 1.35, "bob": 1.0},
	"Jog": {"hips": 0.9, "roll": 0.8, "arms": 1.3, "bob": 0.38},
	"Run": {"hips": 1.0, "roll": 1.0, "arms": 1.0, "bob": 1.0},
	"Walk_Back": {"hips": 0.78, "roll": 0.7, "arms": 1.2, "bob": 1.0},
}

var _skeleton: Skeleton3D
var _bone := {}
var _rest := {}
var _scale := 1.0
var _rest_ankle := 0.0
# Each torso frame's average over the cycle. Her rest spine curves unlike the
# performer's, so frames are taken relative to that average: her posture
# stays her own and only the sway and turn of each step carries over.
var _neutral := {}
# How much of this take's hip travel, hip roll, arm swing and bounce to keep.
var _quiet := {"hips": 1.0, "roll": 1.0, "arms": 1.0, "bob": 1.0}
var _hip_mean_y := 0.0


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var target := (load(TARGET) as PackedScene).instantiate()
	get_root().add_child(target)
	_skeleton = target.find_child("Skeleton3D", true, false) as Skeleton3D
	for name in TRACKED:
		var bone := _skeleton.find_bone(name)
		if bone < 0:
			push_error("Missing elf bone " + name)
			quit(1)
			return
		_bone[name] = bone
		_rest[name] = _skeleton.get_bone_global_rest(bone)
	var leg := _rest_at("DEF-shin.L").distance_to(_rest_at("DEF-thigh.L")) + _rest_at("DEF-foot.L").distance_to(_rest_at("DEF-shin.L"))
	_rest_ankle = minf(_rest_at("DEF-foot.L").y, _rest_at("DEF-foot.R").y)
	print("ELF left-right ", _rest_at("DEF-thigh.L") - _rest_at("DEF-thigh.R"), " foot forward ", _rest_at("DEF-toe.L") - _rest_at("DEF-foot.L"), " leg ", leg)
	if OS.get_cmdline_user_args().has("--profile"):
		for take in ["dataset-1_run_feminine_001", "dataset-1_dash_feminine_001", "dataset-1_walk-back_feminine_001", "dataset-1_walk-left_feminine_001", "dataset-1_walk-right_feminine_001"]:
			_profile(take)
		quit(0)
		return
	var library := AnimationLibrary.new()
	for take in TAKES:
		var bvh := _parse(SOURCE % take[0])
		if bvh.is_empty():
			push_error("Could not read " + take[0])
			quit(1)
			return
		var source_leg: float = (bvh["offsets"]["LowerLeg_L"] as Vector3).length() + (bvh["offsets"]["Foot_L"] as Vector3).length()
		_scale = leg / source_leg
		var clip := _clip(bvh, take[1])
		if clip == null:
			quit(1)
			return
		library.add_animation(take[1], clip)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var result := ResourceSaver.save(library, OUTPUT)
	print("Saved ", OUTPUT, " error ", result)
	quit(0 if result == OK else 1)


func _rest_at(name: String) -> Vector3:
	return (_rest[name] as Transform3D).origin


# Hips speed and which foot is planted, every few frames, to find where a take
# stands, gets going, walks steadily and stops.
func _profile(take: String) -> void:
	var bvh := _parse(SOURCE % take)
	var dt: float = bvh["dt"]
	var raw: Array[Dictionary] = []
	for f in int(bvh["frames"]):
		raw.append(_positions(bvh, f))
	var line := ""
	for f in range(1, raw.size() - 1, 3):
		var hips := _flat(raw[f + 1]["Hips"] - raw[f - 1]["Hips"]).length() / (2.0 * dt)
		var left := _flat(raw[f + 1]["Foot_L"] - raw[f - 1]["Foot_L"]).length() / (2.0 * dt)
		var right := _flat(raw[f + 1]["Foot_R"] - raw[f - 1]["Foot_R"]).length() / (2.0 * dt)
		line += "%d:%d%s%s " % [f, int(hips), "L" if left < 20.0 else "", "R" if right < 20.0 else ""]
	print(take, " frames ", raw.size(), "\n", line)


# --- BVH --------------------------------------------------------------------

# joints: [{name, parent, offset, channels, first}], plus every frame's values.
func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var tokens := text.replace("\t", " ").replace("\r", " ").replace("\n", " ").split(" ", false)
	var joints: Array[Dictionary] = []
	var stack: Array[int] = []
	var last := -1
	var width := 0
	var i := 0
	while i < tokens.size():
		var token := tokens[i]
		if token == "ROOT" or token == "JOINT":
			var parent := stack[stack.size() - 1] if not stack.is_empty() else -1
			joints.append({"name": tokens[i + 1], "parent": parent, "offset": Vector3.ZERO, "channels": PackedStringArray(), "first": 0})
			last = joints.size() - 1
			i += 2
		elif token == "End":
			last = -2
			i += 2
		elif token == "{":
			stack.append(last)
			i += 1
		elif token == "}":
			stack.pop_back()
			i += 1
		elif token == "OFFSET":
			if last >= 0:
				joints[last]["offset"] = Vector3(tokens[i + 1].to_float(), tokens[i + 2].to_float(), tokens[i + 3].to_float())
			i += 4
		elif token == "CHANNELS":
			var count := tokens[i + 1].to_int()
			var channels := PackedStringArray()
			for k in count:
				channels.append(tokens[i + 2 + k])
			if last >= 0:
				joints[last]["channels"] = channels
				joints[last]["first"] = width
				width += count
			i += 2 + count
		elif token == "MOTION":
			i += 1
			break
		else:
			i += 1
	var frames := tokens[i + 1].to_int()
	var dt := tokens[i + 4].to_float()
	i += 5
	var values := PackedFloat32Array()
	values.resize(frames * width)
	for k in frames * width:
		values[k] = tokens[i + k].to_float()
	var offsets := {}
	for joint in joints:
		offsets[joint["name"]] = joint["offset"]
	return {"joints": joints, "frames": frames, "dt": dt, "width": width, "values": values, "offsets": offsets}


# Every joint's position in centimetres, by name, for one frame.
func _positions(bvh: Dictionary, frame: int) -> Dictionary:
	var joints: Array[Dictionary] = bvh["joints"]
	var values: PackedFloat32Array = bvh["values"]
	var width: int = bvh["width"]
	var globals: Array[Transform3D] = []
	var found := {}
	for joint in joints:
		var place: Vector3 = joint["offset"]
		var turn := Basis()
		var channels: PackedStringArray = joint["channels"]
		var base: int = frame * width + int(joint["first"])
		for c in channels.size():
			var value := values[base + c]
			match channels[c]:
				"Xposition":
					place.x = value
				"Yposition":
					place.y = value
				"Zposition":
					place.z = value
				"Xrotation":
					turn = turn * Basis(Vector3.RIGHT, deg_to_rad(value))
				"Yrotation":
					turn = turn * Basis(Vector3.UP, deg_to_rad(value))
				"Zrotation":
					turn = turn * Basis(Vector3.BACK, deg_to_rad(value))
		var local := Transform3D(turn, place)
		var parent: int = joint["parent"]
		var world := globals[parent] * local if parent >= 0 else local
		globals.append(world)
		found[joint["name"]] = world.origin
	return found


# --- Cutting a cycle ----------------------------------------------------------

func _clip(bvh: Dictionary, clip_name: String) -> Animation:
	var frames: int = bvh["frames"]
	var dt: float = bvh["dt"]
	var raw: Array[Dictionary] = []
	for f in frames:
		raw.append(_positions(bvh, f))
	var cycle := _cycle(raw, dt)
	if cycle.y <= 0:
		push_error("No steady cycle in " + clip_name)
		return null
	_quiet = QUIET.get(clip_name, {"hips": 1.0, "roll": 1.0, "arms": 1.0, "bob": 1.0})
	var start := cycle.x
	var length := cycle.y
	# Turn the take so she faces +Z over the cycle.
	var facing := Vector3.ZERO
	for f in range(start, start + length):
		facing += _forward(raw[f])
	var yaw := atan2(facing.x, facing.z)
	var turn := Basis(Vector3.UP, -yaw)
	var turned: Array[Dictionary] = []
	for f in frames:
		var moved := {}
		for name in raw[f]:
			moved[name] = turn * (raw[f][name] as Vector3)
		turned.append(moved)
	# In place: take out the straight line the hips travel along, then centre
	# what is left (the sway and surge of each step) on zero.
	var from: Vector3 = turned[start]["Hips"]
	var to: Vector3 = turned[start + length]["Hips"]
	var travel := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var centre := Vector3.ZERO
	for t in length:
		var hips: Vector3 = turned[start + t]["Hips"]
		centre += Vector3(hips.x - from.x, 0.0, hips.z - from.z) - travel * float(t) / float(length)
	centre /= float(length)
	var in_place := func(f: int) -> Dictionary:
		var shift := from + travel * float(f - start) / float(length) + centre
		shift.y = 0.0
		var placed := {}
		for name in turned[f]:
			placed[name] = (turned[f][name] as Vector3) - shift
		return placed
	var sway := Vector2(INF, -INF)
	var bob := Vector2(INF, -INF)
	var poses: Array[Dictionary] = []
	var seam := mini(SEAM, start)
	for t in length:
		var pose: Dictionary = in_place.call(start + t)
		if t > length - seam - 1 and seam > 0:
			var earlier: Dictionary = in_place.call(start + t - length)
			var w := smoothstep(0.0, 1.0, float(t - (length - seam - 1)) / float(seam))
			for name in pose:
				pose[name] = (pose[name] as Vector3).lerp(earlier[name], w)
		var hips: Vector3 = pose["Hips"]
		sway = Vector2(minf(sway.x, hips.x), maxf(sway.y, hips.x))
		bob = Vector2(minf(bob.x, hips.y), maxf(bob.y, hips.y))
		poses.append(pose)
	_neutral.clear()
	for entry in TORSO:
		var sum := Quaternion(0.0, 0.0, 0.0, 0.0)
		for pose in poses:
			var q := _frame(_lateral(pose, entry[5]), pose[entry[2]] - pose[entry[1]]).get_rotation_quaternion()
			if sum.dot(q) < 0.0:
				q = -q
			sum += q
		_neutral[entry[0]] = Basis(sum.normalized())
	var sum_y := 0.0
	for pose in poses:
		sum_y += (pose["Hips"] as Vector3).y
	_hip_mean_y = sum_y / float(poses.size())
	var duration := float(length) * dt
	var speed := travel.length() / duration * _scale * Tune.PLAYER_MODEL_SCALE
	print("%s: frames %d..%d (%.2f s), natural %.3f m/s, %.2f steps/s, hip sway %.1f cm, bob %.1f cm, travel %s" % [
		clip_name, start, start + length, duration, speed, 2.0 / duration, sway.y - sway.x, bob.y - bob.x, travel.normalized()])
	return _animation(poses, dt)


# One gait cycle from left-foot stance to left-foot stance, chosen where the
# hips move at the take's steady speed. x is its first frame, y its length.
func _cycle(raw: Array[Dictionary], dt: float) -> Vector2i:
	var frames := raw.size()
	var hips_speed := PackedFloat32Array()
	var foot_speed := PackedFloat32Array()
	hips_speed.resize(frames)
	foot_speed.resize(frames)
	for f in range(1, frames - 1):
		hips_speed[f] = _flat(raw[f + 1]["Hips"] - raw[f - 1]["Hips"]).length() / (2.0 * dt)
		foot_speed[f] = _flat(raw[f + 1]["Foot_L"] - raw[f - 1]["Foot_L"]).length() / (2.0 * dt)
	var sorted := hips_speed.duplicate()
	sorted.sort()
	var steady := sorted[int(frames * 0.8)]
	var stance := PackedByteArray()
	stance.resize(frames)
	for f in range(1, frames - 1):
		var smooth := (foot_speed[maxi(f - 1, 1)] + foot_speed[f] + foot_speed[mini(f + 1, frames - 2)]) / 3.0
		stance[f] = 1 if smooth < 0.35 * maxf(hips_speed[f], 0.3 * steady) else 0
	var onsets: Array[int] = []
	var swing := 0
	for f in range(2, frames - 1):
		if stance[f] == 0:
			swing += 1
		elif stance[f - 1] == 0:
			if swing >= 3 and hips_speed[f] > 0.6 * steady:
				onsets.append(f)
			swing = 0
	var durations: Array[int] = []
	for k in range(1, onsets.size()):
		durations.append(onsets[k] - onsets[k - 1])
	if durations.is_empty():
		return Vector2i(0, 0)
	var typical := durations.duplicate()
	typical.sort()
	var usual: int = typical[typical.size() / 2]
	var best := Vector2i(0, 0)
	var best_score := INF
	for k in range(1, onsets.size()):
		var a: int = onsets[k - 1]
		var b: int = onsets[k]
		var length := b - a
		if a < SEAM or b >= frames - 1 or float(length) * dt < 0.35 or float(length) * dt > 2.0:
			continue
		var mean := 0.0
		for f in range(a, b):
			mean += hips_speed[f]
		mean /= float(length)
		var score := absf(mean - steady) / steady + absf(float(length - usual)) / float(usual)
		if score < best_score:
			best_score = score
			best = Vector2i(a, length)
	return best


func _forward(pose: Dictionary) -> Vector3:
	var left: Vector3 = pose["UpperLeg_L"] - pose["UpperLeg_R"]
	var up: Vector3 = pose["Spine"] - pose["Hips"]
	return _flat(left.cross(up)).normalized()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Posing the elf -----------------------------------------------------------

# Left-right as x, up as y, forward as z.
func _frame(left: Vector3, up: Vector3) -> Basis:
	var x := left.normalized()
	var y := (up - x * up.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


func _lateral(pose: Dictionary, kind: String) -> Vector3:
	var hips: Vector3 = (pose["UpperLeg_L"] - pose["UpperLeg_R"]).normalized()
	var shoulders: Vector3 = (pose["UpperArm_L"] - pose["UpperArm_R"]).normalized()
	match kind:
		"hips":
			return hips
		"waist":
			return (hips + shoulders).normalized()
	return shoulders


func _animation(poses: Array[Dictionary], dt: float) -> Animation:
	var animation := Animation.new()
	animation.length = float(poses.size()) * dt
	animation.loop_mode = Animation.LOOP_LINEAR
	var tracks := {}
	for name in TRACKED:
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("Skeleton3D:%s" % name))
		tracks[name] = track
	var hips_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(hips_track, NodePath("Skeleton3D:DEF-spine"))
	var hips_keys: Array[Vector3] = []
	var lowest := INF
	for t in poses.size():
		_pose(poses[t])
		for name in TRACKED:
			animation.rotation_track_insert_key(tracks[name], float(t) * dt, _skeleton.get_bone_pose_rotation(_bone[name]))
		hips_keys.append(_skeleton.get_bone_pose_position(_bone["DEF-spine"]))
		lowest = minf(lowest, minf(_skeleton.get_bone_global_pose(_bone["DEF-foot.L"]).origin.y, _skeleton.get_bone_global_pose(_bone["DEF-foot.R"]).origin.y))
	# On the ground: her lowest ankle over the cycle is where it stands at rest.
	var lift := _rest_ankle - lowest
	for t in hips_keys.size():
		animation.position_track_insert_key(hips_track, float(t) * dt, hips_keys[t] + Vector3(0.0, lift, 0.0))
	return animation


func _pose(pose: Dictionary) -> void:
	_skeleton.reset_bone_poses()
	var turns := {}
	for entry in TORSO:
		var name: String = entry[0]
		var kind: String = entry[5]
		var source := _frame(_lateral(pose, kind), pose[entry[2]] - pose[entry[1]])
		var turn := source * (_neutral[name] as Basis).inverse()
		# Less of the performer's hip and chest swagger; the step stays.
		var roll := float(_quiet["roll"])
		if name != "DEF-spine":
			roll = lerpf(roll, 1.0, 0.4)
		if roll < 0.999:
			turn = Basis(Quaternion.IDENTITY.slerp(turn.get_rotation_quaternion(), roll))
		turns[name] = turn
		var bone: int = _bone[name]
		var origin := _skeleton.get_bone_global_pose(bone).origin
		if name == "DEF-spine":
			var hips := (pose["Hips"] as Vector3) * _scale
			hips.x *= float(_quiet["hips"])
			var bob := float(_quiet["bob"])
			if bob < 0.999:
				var mean_y := _hip_mean_y * _scale
				var dev := hips.y - mean_y
				# The landing shrinks more than the rise, so a jog floats
				# instead of pounding.
				hips.y = mean_y + dev * (bob if dev < 0.0 else lerpf(bob, 1.0, 0.35))
			origin = hips
		_skeleton.set_bone_global_pose(bone, Transform3D(turn * (_rest[name] as Transform3D).basis.orthonormalized(), origin))
	var chest: Basis = turns["DEF-spine.003"]
	for name: String in CARRIED:
		var bone: int = _bone[name]
		_skeleton.set_bone_global_pose(bone, Transform3D(chest * (_rest[name] as Transform3D).basis.orthonormalized(), _skeleton.get_bone_global_pose(bone).origin))
	for entry in LIMBS:
		var name: String = entry[0]
		var bone: int = _bone[name]
		var parent := _skeleton.get_bone_parent(bone)
		# The parent's turn from rest is carried down, so twist follows the
		# chain; only the swing onto the source direction is new.
		var carried := _skeleton.get_bone_global_pose(parent).basis.orthonormalized() * _skeleton.get_bone_global_rest(parent).basis.orthonormalized().inverse()
		var rest_dir := carried * (_rest_at(entry[1]) - _rest_at(name))
		var want: Vector3 = pose[entry[3]] - pose[entry[2]]
		var swing_q := Quaternion(rest_dir.normalized(), want.normalized())
		var arms := float(_quiet["arms"])
		# Only the swing from the shoulder grows. The elbow keeps the take's
		# own bend, so a bigger swing does not hyperextend it.
		if not is_equal_approx(arms, 1.0) and (name.begins_with("DEF-upper_arm") or name.begins_with("DEF-shoulder")):
			swing_q = Quaternion.IDENTITY.slerp(swing_q, arms)
		var swing := Basis(swing_q)
		var basis := swing * carried * (_rest[name] as Transform3D).basis.orthonormalized()
		_skeleton.set_bone_global_pose(bone, Transform3D(basis, _skeleton.get_bone_global_pose(bone).origin))
