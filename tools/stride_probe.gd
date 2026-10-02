extends SceneTree

# Measures how fast each in-place locomotion clip "travels": while a foot is
# planted it slides backward at the speed the body would move. Prints metres
# per second at playback speed 1, plus cycle length, for Tune.
#   godot --headless --path . -s tools/stride_probe.gd

const RIG := "res://addons/quaternius_ik_rigged/Models_with_rigging/Female_Rigged.tscn"
const CLIPS := ["Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Crouch_Fwd"]
const SLOW := 0.25

var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _clip_index := -1
var _length := 1.0
var _elapsed := 0.0
var _samples: Array = []


func _initialize() -> void:
	var model := (load(RIG) as PackedScene).instantiate()
	root.add_child(model)
	_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# The rig's IK pins the feet after the animation; read the clip itself.
	for modifier in _skeleton.find_children("*", "SkeletonModifier3D", true, false):
		(modifier as SkeletonModifier3D).active = false
	_next()


func _process(delta: float) -> bool:
	if _clip_index >= CLIPS.size():
		return true
	_elapsed += delta * SLOW
	var left := _skeleton.get_bone_global_pose(_skeleton.find_bone("LeftFoot")).origin
	var right := _skeleton.get_bone_global_pose(_skeleton.find_bone("RightFoot")).origin
	_samples.append([_elapsed, left, right])
	# One full cycle after a short settle.
	if _elapsed > _length + 0.1:
		_report()
		_next()
	return _clip_index >= CLIPS.size()


func _next() -> void:
	_clip_index += 1
	_samples.clear()
	_elapsed = 0.0
	if _clip_index >= CLIPS.size():
		return
	for name in _animation.get_animation_list():
		if name.ends_with("/" + CLIPS[_clip_index]):
			var animation := _animation.get_animation(name)
			animation.loop_mode = Animation.LOOP_LINEAR
			_length = animation.length
			_animation.play(name)
			_animation.speed_scale = SLOW
			return


func _report() -> void:
	var speeds: Array[float] = []
	for foot in [1, 2]:
		var low := 10.0
		for sample in _samples:
			low = minf(low, (sample[foot] as Vector3).y)
		for i in _samples.size() - 1:
			var a: Vector3 = _samples[i][foot]
			var b: Vector3 = _samples[i + 1][foot]
			var dt: float = _samples[i + 1][0] - _samples[i][0]
			# Planted: within 2 cm of its lowest point on both samples.
			if dt > 0.0 and a.y < low + 0.02 and b.y < low + 0.02:
				speeds.append(absf(b.z - a.z) / dt)
	speeds.sort()
	var median := speeds[speeds.size() / 2] if not speeds.is_empty() else 0.0
	# Cross-check: a foot sweeps its whole fore-aft range once per cycle on
	# the ground, so two ranges per cycle approximates travel speed.
	var reach := 0.0
	for foot in [1, 2]:
		var lo := 10.0
		var hi := -10.0
		for sample in _samples:
			lo = minf(lo, (sample[foot] as Vector3).z)
			hi = maxf(hi, (sample[foot] as Vector3).z)
		reach = maxf(reach, hi - lo)
	print("STRIDE %s cycle %.2f s  planted %.2f m/s (%d samples)  reach %.2f m -> %.2f m/s" % [CLIPS[_clip_index], _length, median, speeds.size(), reach, reach * 2.0 / _length])
