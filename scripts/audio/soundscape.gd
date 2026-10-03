class_name Soundscape
extends Node

var _wind: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _steps: Array[AudioStreamPlayer] = []
var _step_clips: Array[AudioStream] = []
var _step_cursor := 0
var _last_step := -1
var _floor_clips: Array[AudioStream] = []
var _snap: AudioStreamPlayer
var _slide_hiss: AudioStreamPlayer
var _sting: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wind = _loop("wind.wav", -16.0, "Ambience")
	_drone = _loop("drone.wav", -22.0, "Ambience")
	_heart = _one_shot("heart.wav", -8.0, "Dread")
	_load_steps()
	_snap = _one_shot("snap.wav", -4.0, "Dread")
	_slide_hiss = _loop("storm_hiss.wav", -20.0, "Effects")
	_slide_hiss.stop()
	_sting = _one_shot("sting.wav", -2.0, "Dread")
	Game.soundscape = self
	Game.closeness_changed.connect(_on_closeness)
	if _wind:
		_wind.volume_db = -22.0


# One boot in snow. The clip is picked at random but never the same twice in
# a row, and each step gets its own pitch and level, so a long walk never
# turns into a loop. A sprint lands deeper and louder than a walk.
func play_step(heavy: bool = false, indoors: bool = false) -> void:
	var clips := _floor_clips if indoors and not _floor_clips.is_empty() else _step_clips
	if _steps.is_empty() or clips.is_empty():
		return
	var player := _steps[_step_cursor]
	_step_cursor = (_step_cursor + 1) % _steps.size()
	var pick := randi() % clips.size()
	if clips.size() > 1 and pick == _last_step:
		pick = (pick + 1 + randi() % (clips.size() - 1)) % clips.size()
	_last_step = pick
	player.stream = clips[pick]
	if heavy:
		player.pitch_scale = randf_range(0.86, 0.98)
		player.volume_db = randf_range(-5.0, -2.0)
	else:
		player.pitch_scale = randf_range(0.95, 1.08)
		player.volume_db = randf_range(-11.0, -7.5)
	player.play()


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


func play_snap(volume_db: float = -4.0) -> void:
	if _snap:
		_snap.volume_db = volume_db
	_play(_snap)


func _load_steps() -> void:
	# Recorded snow steps first; the generated taps and steps are fallbacks.
	# ResourceLoader, not FileAccess: imported sources are absent in exports.
	var sets: Array = [
		["snow_step_1.mp3", "snow_step_2.mp3", "snow_step_3.mp3"],
		["tap_0.wav", "tap_1.wav", "tap_2.wav", "tap_3.wav", "tap_4.wav", "tap_5.wav"],
		["step_0.wav", "step_1.wav", "step_2.wav", "step_3.wav", "step_4.wav", "step.wav"],
	]
	for names in sets:
		for file_name in names:
			var path := "res://assets/audio/" + (file_name as String)
			if ResourceLoader.exists(path):
				var clip := load(path) as AudioStream
				if clip:
					_step_clips.append(clip)
		if not _step_clips.is_empty():
			break
	# Indoors: the dry boot taps, on boards and tile.
	for file_name in ["tap_0.wav", "tap_1.wav", "tap_2.wav", "tap_3.wav", "tap_4.wav", "tap_5.wav"]:
		var path: String = "res://assets/audio/" + str(file_name)
		if ResourceLoader.exists(path):
			_floor_clips.append(load(path) as AudioStream)
	for _i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		_steps.append(player)


func play_sting() -> void:
	_play(_sting)


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


func _loop(file_name: String, volume_db: float, bus: String) -> AudioStreamPlayer:
	var player := _one_shot(file_name, volume_db, bus)
	if player.stream is AudioStreamWAV:
		var wav := (player.stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream = wav
	player.play()
	return player


func _one_shot(file_name: String, volume_db: float, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	player.bus = bus
	var path := "res://assets/audio/" + file_name
	if ResourceLoader.exists(path):
		player.stream = load(path)
	add_child(player)
	return player


func _play(player: AudioStreamPlayer) -> void:
	if player.stream == null:
		return
	player.play()
