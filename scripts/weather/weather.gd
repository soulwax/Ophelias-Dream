class_name Weather
extends Node3D

const TEX := "res://assets/weather/"

var intensity := 0.62
var gust := 0.0
var wind := Vector3(8.0, 0.0, 3.0)

var _heading := 0.7
var _gust_target := 0.0
var _lull := 5.0
var _layers: Array[SnowLayer] = []
var _audio: StormAudio
var _atmosphere: Atmosphere


func _ready() -> void:
	Game.weather = self
	_audio = StormAudio.new()
	add_child(_audio)
	_build_layers()
	for child in get_parent().get_children():
		if child is Atmosphere:
			_atmosphere = child as Atmosphere
			break


func _process(delta: float) -> void:
	_advance(delta)
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position
	for layer in _layers:
		layer.apply(intensity, wind, gust)
	if _atmosphere:
		_atmosphere.apply_storm(intensity)
	if _audio:
		_audio.apply(intensity, gust)


func _advance(delta: float) -> void:
	_lull -= delta
	if _lull <= 0.0:
		_lull = randf_range(7.0, 16.0)
		_gust_target = randf_range(0.45, 1.0)
		_heading += randf_range(-0.55, 0.55)
	gust = move_toward(gust, _gust_target, delta * 0.28)
	_gust_target = move_toward(_gust_target, 0.08, delta * 0.07)
	_heading += delta * 0.03
	intensity = clampf(0.35 + gust * 0.4, 0.0, 1.0)
	var speed := lerpf(4.0, 9.0, intensity)
	wind = Vector3(cos(_heading), 0.0, sin(_heading)) * speed


func _build_layers() -> void:
	var flakes := SnowLayer.new()
	flakes.position = Vector3(0, 5.5, 0)
	flakes.fall = 2.4
	flakes.wind_scale = 0.55
	flakes.setup(TEX + "flake.png", 1600, 4.0, Vector3(16, 5, 16), 0.45, 1.0, Vector2(0.012, 0.012), Color(0.97, 0.98, 1.0, 0.9))
	_add_layer(flakes)

	var glitter := SnowLayer.new()
	glitter.position = Vector3(0, 3.0, 0)
	glitter.fall = 1.6
	glitter.wind_scale = 0.7
	glitter.setup(TEX + "flake.png", 420, 6.5, Vector3(22, 7, 22), 0.7, 1.3, Vector2(0.02, 0.02), Color(0.93, 0.95, 0.98, 0.35))
	_add_layer(glitter)

	var streaks := SnowLayer.new()
	streaks.position = Vector3(0, 1.2, 0)
	streaks.fall = 0.35
	streaks.wind_scale = 1.15
	streaks.spread_calm = 6.0
	streaks.spread_storm = 3.0
	streaks.gust_only = true
	streaks.setup(TEX + "streak.png", 220, 0.7, Vector3(14, 2.5, 14), 0.6, 1.0, Vector2(0.012, 0.22), Color(0.95, 0.97, 1.0, 0.55))
	streaks.align_to_velocity()
	_add_layer(streaks)

	var drift := SnowLayer.new()
	drift.position = Vector3(0, -1.15, 0)
	drift.fall = 0.15
	drift.wind_scale = 0.85
	drift.setup(TEX + "flake.png", 80, 1.8, Vector3(8, 0.2, 8), 0.4, 0.8, Vector2(0.05, 0.02), Color(0.94, 0.96, 0.99, 0.35))
	_add_layer(drift)


func _add_layer(layer: SnowLayer) -> void:
	add_child(layer)
	_layers.append(layer)

