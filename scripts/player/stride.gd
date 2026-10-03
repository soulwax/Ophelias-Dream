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
const AIR := "Jump_Start"
const LAND := "Jump_Land"
const SLIDE := "Crouch_Idle"
# Stretch of Jump_Start that is airborne (tools/clip_probe.gd): sprung at
# 0.09 s, tucked highest near 0.35 s, legs reaching down by 1.2 s.
const AIR_FROM := 0.09
const AIR_TUCK := 0.36
const AIR_TO := 1.2

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
		# A plateau over the walking pace, so it stays Walk_Formal and the
		# playback rate rises with her. The jog only begins past that.
		["Walk_Formal", 1.05, Tune.STRIDE_WALK],
		["Walk_Formal", 1.95, Tune.STRIDE_WALK],
		["Jog_Fwd", 2.2, Tune.STRIDE_JOG],
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
	# locomotion -> pace -> air -> slide -> land -> stumble -> output
	var root := AnimationNodeBlendTree.new()
	root.add_node("locomotion", space)
	root.add_node("pace", AnimationNodeTimeScale.new())
	root.connect_node("pace", 0, "locomotion")
	# In the air: Jump_Start held at a time picked from her vertical motion
	# (tuck rising, legs reaching for the ground falling).
	root.add_node("air_pose", _clip_node(player, AIR))
	root.add_node("air_seek", AnimationNodeTimeSeek.new())
	root.connect_node("air_seek", 0, "air_pose")
	root.add_node("air", AnimationNodeBlend2.new())
	root.connect_node("air", 0, "pace")
	root.connect_node("air", 1, "air_seek")
	# Sliding: crouched low.
	root.add_node("slide_pose", _clip_node(player, SLIDE))
	root.add_node("slide", AnimationNodeBlend2.new())
	root.connect_node("slide", 0, "air")
	root.connect_node("slide", 1, "slide_pose")
	# Landing: Jump_Land absorbs the drop, faster for a soft one.
	var land := AnimationNodeOneShot.new()
	land.fadein_time = 0.04
	land.fadeout_time = 0.25
	root.add_node("land", land)
	root.add_node("land_pose", _clip_node(player, LAND))
	root.add_node("land_pace", AnimationNodeTimeScale.new())
	root.connect_node("land_pace", 0, "land_pose")
	root.connect_node("land", 0, "slide")
	root.connect_node("land", 1, "land_pace")
	var stumble := AnimationNodeOneShot.new()
	stumble.fadein_time = 0.06
	stumble.fadeout_time = 0.3
	root.add_node("stumble", stumble)
	root.add_node("hit", _clip_node(player, STUMBLE))
	root.connect_node("stumble", 0, "land")
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


# air: 0..1 how much of the air pose shows. rise: her vertical speed as a
# fraction of takeoff speed, +1 leaving the ground .. -1 coming down hard.
func posture(air: float, rise: float, slide: float) -> void:
	if tree == null:
		return
	tree.set("parameters/air/blend_amount", air)
	tree.set("parameters/slide/blend_amount", slide)
	if air > 0.0:
		var at := lerpf(AIR_FROM, AIR_TUCK, clampf(1.0 - rise, 0.0, 1.0))
		if rise < 0.0:
			at = lerpf(AIR_TUCK, AIR_TO, clampf(-rise, 0.0, 1.0))
		tree.set("parameters/air_seek/seek_request", at)


# power 0..1: how hard she came down. A soft landing plays the absorb fast.
func land(power: float) -> void:
	if tree == null:
		return
	tree.set("parameters/land_pace/scale", lerpf(2.2, 1.0, power))
	tree.set("parameters/land/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


static func _clip_node(player: AnimationPlayer, clip: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = _resolve(player, clip)
	return node


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
