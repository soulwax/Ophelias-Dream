class_name Soundscape
extends Node

# Her own sounds and the dread. Every step is a recorded footfall placed at
# the foot that landed, chosen by what it landed on: snow, the cabin's
# planks or the cellar's stone, each at its physical level (Loudness) so the
# difference stays as small as it is in life. The heart, the drone and the
# sting are not in the world and play flat.

const STEPS := "res://assets/audio/steps/"
const SURFACES := {
	"snow": Loudness.SNOW_STEP,
	"wood": Loudness.WOOD_STEP,
	"stone": Loudness.STONE_STEP,
}
# Old boards answer a step with a creak now and then.
const CREAK_CHANCE := 0.12

var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _slide_hiss: AudioStreamPlayer
var _steps: Array[AudioStreamPlayer3D] = []
var _step_cursor := 0
var _sets := {}
var _last := {}
var _snap: AudioStreamPlayer3D
var _snap_clip: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drone = _loop("drone.wav", -22.0, "Dread")
	_heart = _flat("heart.wav", -8.0, "Dread")
	_slide_hiss = _loop("storm_hiss.wav", -20.0, "Effects")
	_slide_hiss.stop()
	_sting = _flat("sting.wav", -2.0, "Dread")
	for surface in ["snow", "wood", "stone", "creak"]:
		_sets[surface] = _load_set(surface)
	for _i in 8:
		var voice := Loudness.voice(Loudness.SNOW_STEP, "Effects")
		add_child(voice)
		_steps.append(voice)
	_snap = Loudness.voice(Loudness.BRANCH_SNAP, "Dread", true)
	add_child(_snap)
	if ResourceLoader.exists("res://assets/audio/snap.wav"):
		_snap_clip = load("res://assets/audio/snap.wav")
	Game.soundscape = self
	Game.closeness_changed.connect(_on_closeness)


## One footfall at a point. surface: "snow", "wood" or "stone". force 0..1:
## from a slow walk to a sprint stride or a landing.
func play_step(at: Vector3, surface: String, force: float) -> void:
	var level: float = SURFACES.get(surface, Loudness.SNOW_STEP)
	var clip := _pick(surface if _sets.has(surface) else "snow")
	if clip == null:
		return
	force = clampf(force, 0.0, 1.0)
	# A harder strike is louder and a touch lower.
	_voice(clip, at, level + Loudness.STRIDE_FORCE * force + randf_range(-1.5, 1.5), randf_range(0.95, 1.05) * lerpf(1.02, 0.93, force))
	if surface == "wood" and randf() < CREAK_CHANCE:
		var creak := _pick("creak")
		if creak:
			_voice(creak, at, Loudness.FLOOR_CREAK + randf_range(-3.0, 2.0), randf_range(0.85, 1.1))


## A branch breaking somewhere: where it is, and how loud at 1 m.
func play_snap(at: Vector3, spl: float = Loudness.BRANCH_SNAP) -> void:
	if _snap_clip == null:
		return
	_snap.stream = _snap_clip
	_snap.global_position = at
	_snap.volume_db = Loudness.volume(spl)
	_snap.pitch_scale = randf_range(0.9, 1.08)
	_snap.play()


# Snow hissing under her boots while she slides; amount 0 stops it.
func slide(amount: float) -> void:
	if _slide_hiss == null or _slide_hiss.stream == null:
		return
	if amount <= 0.0:
		_slide_hiss.stop()
		return
	_slide_hiss.volume_db = lerpf(-20.0, -5.0, amount)
	_slide_hiss.pitch_scale = lerpf(1.3, 1.8, amount)
	if not _slide_hiss.playing:
		_slide_hiss.play(randf() * 4.0)


func play_sting() -> void:
	if _sting.stream:
		_sting.play()


func _on_closeness(value: float) -> void:
	if _heart == null:
		return
	_heart.volume_db = lerpf(-28.0, -6.0, value)
	if value > 0.35 and not _heart.playing:
		_heart.play()
	elif value <= 0.2 and _heart.playing:
		_heart.stop()


func _process(_delta: float) -> void:
	# The heart answers whatever presses hardest: the hunter or an anomaly.
	_on_closeness(Game.threat())


func _voice(clip: AudioStream, at: Vector3, spl: float, pitch: float) -> void:
	var voice := _steps[_step_cursor]
	_step_cursor = (_step_cursor + 1) % _steps.size()
	voice.stream = clip
	voice.global_position = at
	voice.volume_db = Loudness.volume(spl)
	voice.pitch_scale = pitch
	voice.play()


# Never the same take twice in a row.
func _pick(surface: String) -> AudioStream:
	var clips: Array = _sets.get(surface, [])
	if clips.is_empty():
		return null
	var index := randi() % clips.size()
	if clips.size() > 1 and index == int(_last.get(surface, -1)):
		index = (index + 1 + randi() % (clips.size() - 1)) % clips.size()
	_last[surface] = index
	return clips[index]


# ResourceLoader, not the folder: in an export only the imported clips exist.
func _load_set(surface: String) -> Array:
	var clips := []
	for index in 32:
		var path := STEPS + "%s_%02d.wav" % [surface, index]
		if not ResourceLoader.exists(path):
			break
		clips.append(load(path))
	return clips


func _loop(file_name: String, volume_db: float, bus: String) -> AudioStreamPlayer:
	var player := _flat(file_name, volume_db, bus)
	if player.stream is AudioStreamWAV:
		var wav := (player.stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream = wav
	if player.stream:
		player.play()
	return player


func _flat(file_name: String, volume_db: float, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	player.bus = bus
	var path := "res://assets/audio/" + file_name
	if ResourceLoader.exists(path):
		player.stream = load(path)
	add_child(player)
	return player
