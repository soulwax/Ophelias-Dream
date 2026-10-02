class_name StormAudio
extends Node

var _howl: AudioStreamPlayer
var _birds: AudioStreamPlayer


func _ready() -> void:
	_howl = _loop("wind.wav", -10.0)
	_birds = _loop(_first_birds(), -16.0)


func apply(intensity: float, gust: float) -> void:
	if _howl:
		_howl.volume_db = lerpf(-16.0, -4.0, intensity) + gust * 3.5
		_howl.pitch_scale = lerpf(0.72, 1.05, intensity) + gust * 0.08
	if _birds:
		var open := 1.0 - smoothstep(0.35, 0.72, intensity)
		_birds.volume_db = lerpf(-40.0, -14.0, open)


func _first_birds() -> String:
	for file_name in ["birds_0.wav", "birds_1.wav", "birds_2.wav"]:
		if FileAccess.file_exists("res://assets/audio/" + file_name):
			return file_name
	return "wind.wav"


func _loop(file_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	var path := "res://assets/audio/" + file_name
	if ResourceLoader.exists(path):
		var stream := load(path)
		if stream is AudioStreamWAV:
			var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			player.stream = wav
		else:
			player.stream = stream
	add_child(player)
	if player.stream:
		player.play()
	return player
