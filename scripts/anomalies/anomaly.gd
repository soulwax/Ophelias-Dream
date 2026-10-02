class_name Anomaly
extends Node3D

# One anomalous thing on the snowfield, running alongside the hunter. Each
# follows a single strict rule. The rule is written down in its containment
# record, a page somewhere on the trail: reading it costs time while the
# world keeps moving, and turns the vague HUD warning into the actual rule.

var code := ""
var trail: Trail
# 0..1: how hard it presses on her this frame. The director feeds the
# strongest one into the vignette, the heartbeat and the warning line.
var dread := 0.0
# One HUD line while it matters; empty when it does not.
var hint := ""


# The page that describes the rule. Its record_of must be this code.
func record() -> NoteEntry:
	return null


# Where the record lies, in metres along the trail from the cabin.
func record_offset() -> float:
	return 14.0


# Dev hook: stand at a point, facing another.
func place_near(at: Vector3, facing: Vector3) -> void:
	if trail and trail.ground:
		at.y = trail.ground.height_at(at.x, at.z)
	global_position = at
	var to := facing - at
	rotation.y = atan2(to.x, to.z)


func understood() -> bool:
	return Game.knows(code)


# True while the world is running for it: playing, or frozen over a page.
func awake() -> bool:
	return Game.phase == Game.Phase.PLAYING or Game.phase == Game.Phase.READING


func catch(title: String, body: String) -> void:
	Game.mark("caught by %s" % code)
	Game.catch_player(title, body)


func make_record(title: String, body: String) -> NoteEntry:
	var entry := NoteEntry.new()
	entry.title = title
	entry.body = body
	entry.record_of = code
	return entry
