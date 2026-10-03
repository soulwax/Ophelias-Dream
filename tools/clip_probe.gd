extends SceneTree

# Charts hips and foot heights through a clip, to find its phases (crouch,
# airborne, landing). Lets frames tick so the animation really applies.
#   godot --headless --path . -s tools/clip_probe.gd -- Jump Jump_Start

const RIG := "res://addons/quaternius_ik_rigged/Models_with_rigging/Female_Rigged.tscn"
const SLOW := 0.25
const ROWS := 16

var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _clips: PackedStringArray
var _index := -1
var _length := 1.0
var _elapsed := 0.0
var _next_row := 0.0


func _initialize() -> void:
	_clips = OS.get_cmdline_user_args()
	var model := (load(RIG) as PackedScene).instantiate()
	root.add_child(model)
	_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for modifier in _skeleton.find_children("*", "SkeletonModifier3D", true, false):
		(modifier as SkeletonModifier3D).active = false
	_next()


func _process(delta: float) -> bool:
	if _index >= _clips.size():
		return true
	_elapsed += delta * SLOW
	if _elapsed >= _next_row and _elapsed <= _length:
		var hips := _skeleton.get_bone_global_pose(_skeleton.find_bone("Hips")).origin
		var left := _skeleton.get_bone_global_pose(_skeleton.find_bone("LeftFoot")).origin
		var right := _skeleton.get_bone_global_pose(_skeleton.find_bone("RightFoot")).origin
		print("  %-11s t=%.2f (%.0f%%)  hips y %.3f  feet y %.3f %.3f" % [_clips[_index], _elapsed, _elapsed / _length * 100.0, hips.y, left.y, right.y])
		_next_row += _length / float(ROWS)
	if _elapsed > _length + 0.05:
		_next()
	return _index >= _clips.size()


func _next() -> void:
	_index += 1
	_elapsed = 0.0
	_next_row = 0.0
	if _index >= _clips.size():
		return
	for name in _animation.get_animation_list():
		if name.ends_with("/" + _clips[_index]):
			_length = _animation.get_animation(name).length
			_animation.get_animation(name).loop_mode = Animation.LOOP_NONE
			_animation.play(name)
			_animation.speed_scale = SLOW
			print("CLIP %s length %.2f s" % [_clips[_index], _length])
			return
