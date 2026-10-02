class_name Soundscape
extends Node

var _wind: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _step: AudioStreamPlayer
var _snap: AudioStreamPlayer
var _sting: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wind = _loop("wind.wav", -16.0)
	_drone = _loop("drone.wav", -22.0)
	_heart = _one_shot("heart.wav", -8.0)
	_step = _one_shot("step.wav", -6.0)
	_snap = _one_shot("snap.wav", -4.0)
	_sting = _one_shot("sting.wav", -2.0)
	Game.soundscape = self
	Game.closeness_changed.connect(_on_closeness)


func play_step() -> void:
	_play(_step)


func play_snap() -> void:
	_play(_snap)


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
	if Game.closeness > 0.35 and _heart and not _heart.playing:
		_heart.play()


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
