class_name StormAudio
extends Node

var _body: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _gust: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _gust_armed := true


func _ready() -> void:
	_body = _loop("storm_body.wav", -9.0)
	_hiss = _loop("storm_hiss.wav", -14.0)
	_gust = _one_shot("storm_gust.wav", -6.0)
	_birds = _loop(_first_birds(), -18.0)


func apply(intensity: float, gust: float) -> void:
	if _body:
		_body.volume_db = lerpf(-14.0, -5.0, intensity)
		_body.pitch_scale = lerpf(0.92, 1.04, intensity)
	if _hiss:
		_hiss.volume_db = lerpf(-20.0, -8.0, intensity)
		_hiss.pitch_scale = lerpf(0.96, 1.08, gust)
	if _birds:
		var open := 1.0 - smoothstep(0.25, 0.6, intensity)
		_birds.volume_db = lerpf(-42.0, -16.0, open)
	if _gust == null or _gust.stream == null:
		return
	if gust < 0.35:
		_gust_armed = true
	elif _gust_armed and gust > 0.62 and not _gust.playing:
		_gust_armed = false
		_gust.pitch_scale = randf_range(0.86, 1.08)
		_gust.volume_db = randf_range(-8.0, -4.0)
		_gust.play()


func _first_birds() -> String:
	for file_name in ["birds_0.wav", "birds_1.wav", "birds_2.wav"]:
		if FileAccess.file_exists("res://assets/audio/" + file_name):
			return file_name
	return "storm_body.wav"


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
	player.bus = "Ambience"
	var path := "res://assets/audio/" + file_name
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		player.stream = load(path)
	add_child(player)
	return player
