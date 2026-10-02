class_name Soundscape
extends Node

var _wind: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _steps: Array[AudioStreamPlayer] = []
var _step_clips: Array[AudioStream] = []
var _step_cursor := 0
var _snap: AudioStreamPlayer
var _sting: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wind = _loop("wind.wav", -16.0)
	_drone = _loop("drone.wav", -22.0)
	_heart = _one_shot("heart.wav", -8.0)
	_load_steps()
	_snap = _one_shot("snap.wav", -4.0)
	_sting = _one_shot("sting.wav", -2.0)
	Game.soundscape = self
	Game.closeness_changed.connect(_on_closeness)
	if _wind:
		_wind.volume_db = -22.0


func play_step(heavy: bool = false) -> void:
	if _steps.is_empty() or _step_clips.is_empty():
		return
	var player := _steps[_step_cursor]
	_step_cursor = (_step_cursor + 1) % _steps.size()
	player.stream = _step_clips[randi() % _step_clips.size()]
	player.pitch_scale = randf_range(0.94, 1.06) if heavy else randf_range(1.08, 1.28)
	player.volume_db = randf_range(-11.0, -7.5) if heavy else randf_range(-16.0, -12.0)
	player.play()


func play_snap(volume_db: float = -4.0) -> void:
	if _snap:
		_snap.volume_db = volume_db
	_play(_snap)


func _load_steps() -> void:
	var taps: Array[String] = ["tap_0.wav", "tap_1.wav", "tap_2.wav", "tap_3.wav", "tap_4.wav", "tap_5.wav"]
	var names: Array[String] = taps
	var found_tap := false
	for file_name in taps:
		if FileAccess.file_exists("res://assets/audio/" + file_name):
			found_tap = true
			break
	if not found_tap:
		names = ["step_0.wav", "step_1.wav", "step_2.wav", "step_3.wav", "step_4.wav"]
	for file_name in names:
		var path := "res://assets/audio/" + file_name
		if FileAccess.file_exists(path):
			var clip := load(path) as AudioStream
			if clip:
				_step_clips.append(clip)
	if _step_clips.is_empty() and ResourceLoader.exists("res://assets/audio/step.wav"):
		var fallback := load("res://assets/audio/step.wav") as AudioStream
		if fallback:
			_step_clips.append(fallback)
	for _i in 4:
		var player := AudioStreamPlayer.new()
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


func _loop(file_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := _one_shot(file_name, volume_db)
	if player.stream is AudioStreamWAV:
		var wav := (player.stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream = wav
	player.play()
	return player


func _one_shot(file_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	var path := "res://assets/audio/" + file_name
	if ResourceLoader.exists(path):
		player.stream = load(path)
	add_child(player)
	return player


func _play(player: AudioStreamPlayer) -> void:
	if player.stream == null:
		return
	player.play()
