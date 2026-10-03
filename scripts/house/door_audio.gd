class_name DoorAudio
extends RefCounted

## Handle, creak and latch cues for one hinged leaf (ported from merl).
## "front" and "steel" pick the heavier creak; steel also drops the pitch.
const HANDLE := "res://assets/derived/doors/audio/switch_01.ogg"
const CREAK_LIGHT := "res://assets/derived/doors/audio/door_01.ogg"
const CREAK_HEAVY := "res://assets/derived/doors/audio/door_02.ogg"
const LATCH := "res://assets/derived/doors/audio/door_close_01.ogg"


## Returns {"handle", "creak", "latch"} -> AudioStreamPlayer3D under `parent`.
static func add_cues(parent: Node3D, style: String, at: Vector3) -> Dictionary:
	var result := {}
	var paths := {
		"handle": HANDLE,
		"creak": CREAK_HEAVY if style == "front" or style == "steel" else CREAK_LIGHT,
		"latch": LATCH,
	}
	for cue in paths:
		var player := AudioStreamPlayer3D.new()
		player.name = "%sAudio" % str(cue).capitalize()
		if ResourceLoader.exists(paths[cue]):
			player.stream = load(paths[cue]) as AudioStream
		player.position = at
		player.volume_db = -9.0 if cue == "creak" else -6.0
		player.max_distance = 12.0
		player.pitch_scale = 0.85 if style == "steel" else 1.0
		parent.add_child(player)
		result[cue] = player
	return result
