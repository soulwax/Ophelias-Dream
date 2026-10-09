class_name Stride
extends RefCounted

# Her locomotion: one blend space from standing to sprinting, driven by her
# real ground speed. Playback is scaled so a planted foot slides back at
# exactly that speed, so she never skates. A one-shot stumble rides on top.
#
# Natural speeds (metres per second at playback 1) live in Tune.

const IDLE := "Idle"
const WALK := "Walk"
const JOG := "Jog_Fwd"
const SPRINT := "Sprint"
const STUMBLE := "Hit_Chest"
const AIR := "Jump_Start"
const LAND := "Jump_Land"
const SLIDE := "Crouch_Idle"
# Stretch of Jump_Start that is airborne: sprung at
# 0.09 s, tucked highest near 0.35 s, legs reaching down by 1.2 s.
const AIR_FROM := 0.09
const AIR_TUCK := 0.36
const AIR_TO := 1.2
# Where each foot meets and leaves the ground in the running clips (seconds),
# measured by tools/leap_phase_probe.gd. A leap plays from the push-off
# foot's toe-off to the lead foot's contact, slowed to fill the flight.
const JOG_PHASES := {"length": 0.9333, "L_contact": 0.0039, "L_off": 0.1711, "R_contact": 0.4706, "R_off": 0.6378}
const SPRINT_PHASES := {"length": 0.6667, "L_contact": 0.6528, "L_off": 0.1306, "R_contact": 0.3278, "R_off": 0.4917}

var tree: AnimationTree
# [clip, blend position in m/s of ground speed, natural speed of the clip]
var _gaits: Array = []
# [blend point name, clip] for each running point, for landing cues.
var _points: Array = []


static func build(player: AnimationPlayer, model: Node) -> Stride:
	var stride := Stride.new()
	# Each running gait has a plateau (two points, same clip), so a steady
	# speed always plays one clip cleanly. Blends between clips with
	# different cycles muddle the legs, so they only happen in the short
	# bands she crosses while speeding up or slowing down.
	stride._gaits = [
		[IDLE, 0.0, 0.0],
		# A plateau over the walking pace, so the neutral walk plays cleanly
		# and its playback rate rises with her. The jog begins past that.
		[WALK, 1.05, Tune.STRIDE_WALK],
		[WALK, 1.95, Tune.STRIDE_WALK],
		[JOG, 2.2, Tune.STRIDE_JOG],
		[JOG, 3.2, Tune.STRIDE_JOG],
		[SPRINT, 4.6, Tune.STRIDE_SPRINT],
		[SPRINT, Tune.SPRINT_SPEED, Tune.STRIDE_SPRINT],
	]
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = Tune.SPRINT_SPEED + 1.0
	space.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_INDEPENDENT
	for index in stride._gaits.size():
		var gait: Array = stride._gaits[index]
		var clip := _resolve(player, gait[0])
		if clip == "":
			continue
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		# Each point can be cued on its own: a leap lands on a contact frame.
		var point := AnimationNodeBlendTree.new()
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		point.add_node("clip", node)
		point.add_node("seek", AnimationNodeTimeSeek.new())
		point.connect_node("seek", 0, "clip")
		point.connect_node("output", 0, "seek")
		var point_name := "%s_%d" % [gait[0], index]
		space.add_blend_point(point, gait[1], -1, point_name)
		stride._points.append([point_name, gait[0]])
	# locomotion -> pace -> air -> leap -> slide -> land -> stumble -> output
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
	# A running leap: her own jog and sprint from toe-off to the next contact,
	# slowed to fill the flight and blended by her speed at takeoff.
	root.add_node("leap_jog", _clip_node(player, JOG))
	root.add_node("leap_jog_seek", AnimationNodeTimeSeek.new())
	root.connect_node("leap_jog_seek", 0, "leap_jog")
	root.add_node("leap_sprint", _clip_node(player, SPRINT))
	root.add_node("leap_sprint_seek", AnimationNodeTimeSeek.new())
	root.connect_node("leap_sprint_seek", 0, "leap_sprint")
	root.add_node("leap_gait", AnimationNodeBlend2.new())
	root.connect_node("leap_gait", 0, "leap_jog_seek")
	root.connect_node("leap_gait", 1, "leap_sprint_seek")
	root.add_node("leap", AnimationNodeBlend2.new())
	root.connect_node("leap", 0, "air")
	root.connect_node("leap", 1, "leap_gait")
	# Sliding: crouched low.
	root.add_node("slide_pose", _clip_node(player, SLIDE))
	root.add_node("slide", AnimationNodeBlend2.new())
	root.connect_node("slide", 0, "leap")
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


# amount 0..1 of the leap pose; progress 0..1 through the flight; leap 0..1
# from a jog to a full sprint at takeoff, which picks the clip.
func leap_pose(amount: float, progress: float, lead_left: bool, leap: float) -> void:
	if tree == null:
		return
	tree.set("parameters/leap/blend_amount", amount)
	if amount <= 0.0:
		return
	tree.set("parameters/leap_gait/blend_amount", leap)
	tree.set("parameters/leap_jog_seek/seek_request", flight_time(JOG_PHASES, lead_left, progress))
	tree.set("parameters/leap_sprint_seek/seek_request", flight_time(SPRINT_PHASES, lead_left, progress))


# Down from a leap: every running clip picks up at the lead foot's contact,
# so her stride carries on from the step she landed on.
func leap_land(lead_left: bool) -> void:
	if tree == null:
		return
	var key := "L_contact" if lead_left else "R_contact"
	for point: Array in _points:
		var phases: Dictionary = JOG_PHASES if point[1] == JOG else SPRINT_PHASES if point[1] == SPRINT else {}
		if phases.is_empty():
			continue
		tree.set("parameters/locomotion/%s/seek/seek_request" % point[0], phases[key])


# Seconds into a running clip at this point of a leap's flight: from the
# push-off foot's toe-off to the lead foot's contact, across the loop if needed.
static func flight_time(phases: Dictionary, lead_left: bool, progress: float) -> float:
	var from: float = phases["R_off" if lead_left else "L_off"]
	var to: float = phases["L_contact" if lead_left else "R_contact"]
	var length: float = phases["length"]
	if to < from:
		to += length
	return fmod(lerpf(from, to, clampf(progress, 0.0, 1.0)), length)


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
