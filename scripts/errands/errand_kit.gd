class_name ErrandKit
extends RefCounted

## Shared pieces for the errand verbs (MASTERPLAN W06): their sounds, from the
## CC0 set in assets/audio/errands/ (tools/make_errand_sounds.py), and their
## props, from the curated vendor set (VendorLoader) with a built fallback.

const SOUNDS := "res://assets/audio/errands/"
const LEARTES := "requested_errands/leartes/"

static var _clips: Dictionary = {}


## Every take of a sound: "<name>.wav", or "<name>_00.wav", "<name>_01.wav", ...
static func clips(sound: String) -> Array[AudioStream]:
	if _clips.has(sound):
		return _clips[sound]
	var found: Array[AudioStream] = []
	if ResourceLoader.exists(SOUNDS + sound + ".wav"):
		found.append(load(SOUNDS + sound + ".wav") as AudioStream)
	for index in 16:
		var path := SOUNDS + "%s_%02d.wav" % [sound, index]
		if not ResourceLoader.exists(path):
			break
		found.append(load(path) as AudioStream)
	_clips[sound] = found
	return found


## One take of a sound at the node, on the Effects bus at a typical SPL. The
## player frees itself when done. Returns null if the sound set is missing.
static func play(at: Node3D, sound: String, spl: float, far := false) -> AudioStreamPlayer3D:
	var takes := clips(sound)
	if takes.is_empty() or not at.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.name = "Sound_" + sound
	player.bus = "Effects"
	player.stream = takes[randi() % takes.size()]
	player.pitch_scale = randf_range(0.95, 1.05)
	at.add_child(player)
	Loudness.sound(player, spl, far)
	player.finished.connect(player.queue_free)
	player.play()
	return player


## A Leartes prop from the curated set, or a plain box of the given size when the
## vendor set is missing (an exported build without it). The box sits on y 0.
static func prop(parent: Node3D, leartes_name: String, fallback_size: Vector3, colour: Color) -> Node3D:
	var model := VendorLoader.load_model(LEARTES + leartes_name + ".gltf")
	if model == null:
		model = Node3D.new()
		HouseKit.box(model, "Fallback", Vector3(0.0, fallback_size.y * 0.5, 0.0), fallback_size, HouseKit.paint(colour, 0.85))
	model.name = leartes_name
	parent.add_child(model)
	return model


## The interacting player, when she is in a chapter that has errands.
static func player() -> Player:
	return Game.player if Game.player and not Game.dream_mode and not Game.mathilda_pov else null
