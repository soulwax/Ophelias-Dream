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


# Where it stands when the editable level has no marker for it yet.
func stand_transform(host: Trail) -> Transform3D:
	var along := host.player_start_offset + 40.0
	var frame := host.frame_at(along)
	var at := host.on_ground(frame.origin + frame.basis.x * 18.0)
	return Transform3D(Basis.looking_at(-frame.basis.z, Vector3.UP), at)


# Where its page lies, on the side of the trail opposite the field notes.
func record_position(host: Trail, index: int) -> Vector3:
	var along := host.player_start_offset + record_offset() + float(index) * 9.0
	var frame := host.frame_at(along)
	var at := host.on_ground(frame.origin + frame.basis.x * 3.4)
	at.y += 0.04
	return at


# Stand on the snow where the editor marker is, facing the way it faces.
func adopt_marker(marker: Node3D) -> void:
	global_position = marker.global_position
	rotation.y = marker.global_rotation.y
	if trail and trail.ground:
		var at := global_position
		at.y = trail.ground.height_at(at.x, at.z)
		global_position = at
	reset_physics_interpolation()


# Dev hook: stand at a point, facing another.
func place_near(at: Vector3, facing: Vector3) -> void:
	if trail and trail.ground:
		at.y = trail.ground.height_at(at.x, at.z)
	global_position = at
	var to := facing - at
	rotation.y = atan2(to.x, to.z)
	reset_physics_interpolation()


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
