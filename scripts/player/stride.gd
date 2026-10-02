class_name Stride
extends RefCounted

# Her locomotion: one blend space from standing to sprinting, driven by her
# real ground speed. Playback is scaled so a planted foot slides back at
# exactly that speed, so she never skates. A one-shot stumble rides on top.
#
# Natural speeds (metres per second at playback 1) were measured from the
# clips with tools/stride_probe.gd.

const IDLE := "Idle"
const STUMBLE := "Hit_Chest"

var tree: AnimationTree
# [clip, blend position in m/s of ground speed, natural speed of the clip]
var _gaits: Array = []


static func build(player: AnimationPlayer, model: Node) -> Stride:
	var stride := Stride.new()
	# Each running gait has a plateau (two points, same clip), so a steady
	# speed always plays one clip cleanly. Blends between clips with
	# different cycles muddle the legs, so they only happen in the short
	# bands she crosses while speeding up or slowing down.
	stride._gaits = [
		[IDLE, 0.0, 0.0],
		["Walk_Formal", 1.2, Tune.STRIDE_WALK],
		["Jog_Fwd", 2.0, Tune.STRIDE_JOG],
		["Jog_Fwd", 3.2, Tune.STRIDE_JOG],
		["Sprint", 4.6, Tune.STRIDE_SPRINT],
		["Sprint", Tune.SPRINT_SPEED, Tune.STRIDE_SPRINT],
	]
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = Tune.SPRINT_SPEED + 1.0
	space.sync = true
	for index in stride._gaits.size():
		var gait: Array = stride._gaits[index]
		var clip := _resolve(player, gait[0])
		if clip == "":
			continue
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		space.add_blend_point(node, gait[1], -1, "%s_%d" % [gait[0], index])
	var root := AnimationNodeBlendTree.new()
	root.add_node("locomotion", space)
	var pace := AnimationNodeTimeScale.new()
	root.add_node("pace", pace)
	var stumble := AnimationNodeOneShot.new()
	stumble.fadein_time = 0.06
	stumble.fadeout_time = 0.3
	root.add_node("stumble", stumble)
	var hit := AnimationNodeAnimation.new()
	hit.animation = _resolve(player, STUMBLE)
	root.add_node("hit", hit)
	root.connect_node("pace", 0, "locomotion")
	root.connect_node("stumble", 0, "pace")
	root.connect_node("stumble", 1, "hit")
	root.connect_node("output", 0, "stumble")
	stride.tree = AnimationTree.new()
	stride.tree.name = "Stride"
	stride.tree.tree_root = root
	model.add_child(stride.tree)
	stride.tree.anim_player = stride.tree.get_path_to(player)
	stride.tree.active = true
	return stride


func update(ground_speed: float) -> void:
	if tree == null:
		return
	tree.set("parameters/locomotion/blend_position", ground_speed)
	tree.set("parameters/pace/scale", _pace(ground_speed))


func stumble() -> void:
	if tree:
		tree.set("parameters/stumble/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


# Playback rate that matches the feet to the ground at this speed: at each
# blend point a clip plays at (its point / its natural speed); in between,
# the rate eases from one to the next.
func _pace(speed: float) -> float:
	var rates: Array[float] = []
	for gait in _gaits:
		rates.append(1.0 if gait[2] <= 0.0 else float(gait[1]) / float(gait[2]))
	if speed >= float(_gaits[_gaits.size() - 1][1]):
		return speed / float(_gaits[_gaits.size() - 1][2])
	for i in _gaits.size() - 1:
		var lo: float = _gaits[i][1]
		var hi: float = _gaits[i + 1][1]
		if speed <= hi:
			return lerpf(rates[i], rates[i + 1], clampf((speed - lo) / (hi - lo), 0.0, 1.0))
	return 1.0


static func _resolve(player: AnimationPlayer, clip: String) -> String:
	if player.has_animation(clip):
		return clip
	for name in player.get_animation_list():
		if name.ends_with("/" + clip):
			return name
	return ""
