class_name Grace
extends RefCounted

## GDScript-facing controller for the C# pose evaluator. Keep gameplay and
## editor probes on this stable API while the per-frame math stays native.

const BONES := ["DEF-spine", "DEF-spine.003", "DEF-spine.004", "DEF-spine.006",
	"DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
	"DEF-thigh.L", "DEF-thigh.R", "DEF-foot.L", "DEF-toe.L", "DEF-foot.R", "DEF-toe.R"]

var _motion: GraceMotion

var speed: float:
	get: return _motion.Speed if _motion else 0.0
	set(value):
		if _motion:
			_motion.Speed = value
var poise: float:
	get: return _motion.Poise if _motion else 1.0
	set(value):
		if _motion:
			_motion.Poise = value
var glance: float:
	get: return _motion.Glance if _motion else 0.0
	set(value):
		if _motion:
			_motion.Glance = value
var authored_walk: bool:
	get: return _motion.AuthoredWalk if _motion else false
	set(value):
		if _motion:
			_motion.AuthoredWalk = value
var dialogue_attention: float:
	get: return _motion.DialogueAttention if _motion else 0.0
	set(value):
		if _motion:
			_motion.DialogueAttention = value
var dialogue_speaking: float:
	get: return _motion.DialogueSpeaking if _motion else 0.0
	set(value):
		if _motion:
			_motion.DialogueSpeaking = value
var motion_drive: float:
	get: return _motion.MotionDrive if _motion else 0.0
	set(value):
		if _motion:
			_motion.MotionDrive = value
var motion_turn: float:
	get: return _motion.MotionTurn if _motion else 0.0
	set(value):
		if _motion:
			_motion.MotionTurn = value
var breath_strain: float:
	get: return _motion.BreathStrain if _motion else 0.0
	set(value):
		if _motion:
			_motion.BreathStrain = value
var active: bool:
	get: return bool(_motion.get("active")) if _motion else false
	set(value):
		if _motion:
			_motion.set("active", value)


func react(kind: int) -> void:
	if _motion:
		_motion.CueDialogueReaction(kind)


static func fit(skeleton: Skeleton3D) -> Grace:
	var grace := Grace.new()
	for name in BONES:
		if skeleton.find_bone(name) < 0:
			push_warning("Grace: missing bone " + name)
			return grace
	var motion := GraceMotion.new()
	motion.name = "Grace"
	motion.Configure(
		Tune.GRACE_WALK_ENTER, Tune.GRACE_WALK_EXIT,
		Tune.GLANCE_CHEST, Tune.GLANCE_HEAD,
		Tune.GRACE_COUNTER_TURN, Tune.GRACE_AUTHORED_COUNTER,
		Tune.GRACE_CHEST_LIFT, Tune.GRACE_ARM_SWING, Tune.GRACE_AUTHORED_ARM,
		Tune.TIPTOE_AFTER, Tune.TIPTOE_CYCLE, Tune.TIPTOE_LIFT, Tune.TIPTOE_PITCH)
	motion.ConfigureDialogue(Tune.DIALOGUE_ATTENTION_BLEND, Tune.DIALOGUE_SPEAKING_BLEND,
		Tune.DIALOGUE_REACTION_SECONDS, Tune.DIALOGUE_REACTION_STRENGTH)
	motion.ConfigureMotion(Tune.MOTION_FOLLOW_BLEND, Tune.MOTION_FOLLOW_STRENGTH)
	skeleton.add_child(motion)
	grace._motion = motion
	return grace
