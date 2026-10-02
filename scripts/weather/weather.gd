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
var _sheets: Array[Node3D] = []
var _audio: StormAudio
var _atmosphere: Atmosphere


func _ready() -> void:
	Game.weather = self
	_audio = StormAudio.new()
	add_child(_audio)
	_build_layers()
	_build_sheets()
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
	_drift_sheets(delta)
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
	intensity = clampf(0.5 + gust * 0.48, 0.0, 1.0)
	var speed := lerpf(6.5, 17.5, intensity)
	wind = Vector3(cos(_heading), 0.0, sin(_heading)) * speed


func _build_layers() -> void:
	var flakes := SnowLayer.new()
	flakes.position = Vector3(0, 5.5, 0)
	flakes.fall = 2.4
	flakes.wind_scale = 0.55
	flakes.setup(TEX + "PolygonParticles_Soft_Spot_01.png", 1500, 5.5, Vector3(22, 6, 22), 0.08, 0.28, Vector2(0.09, 0.09), Color(0.96, 0.97, 1.0, 0.82))
	_add_layer(flakes)

	var glitter := SnowLayer.new()
	glitter.position = Vector3(0, 3.0, 0)
	glitter.fall = 1.6
	glitter.wind_scale = 0.7
	glitter.setup(TEX + "PolygonParticles_Sparkle_01.png", 220, 4.5, Vector3(16, 5, 16), 0.04, 0.12, Vector2(0.07, 0.07), Color(1.0, 1.0, 1.0, 0.7))
	_add_layer(glitter)

	var streaks := SnowLayer.new()
	streaks.position = Vector3(0, 1.2, 0)
	streaks.fall = 0.35
	streaks.wind_scale = 1.15
	streaks.spread_calm = 6.0
	streaks.spread_storm = 3.0
	streaks.setup(TEX + "Generic_Wind_Streaks_01.png", 640, 1.6, Vector3(20, 4, 20), 0.55, 1.35, Vector2(0.05, 1.15), Color(0.94, 0.96, 1.0, 0.42))
	streaks.align_to_velocity()
	_add_layer(streaks)

	var drift := SnowLayer.new()
	drift.position = Vector3(0, -1.15, 0)
	drift.fall = 0.15
	drift.wind_scale = 0.85
	drift.setup(TEX + "PolygonParticles_Fumes_01.png", 320, 3.2, Vector3(14, 0.45, 14), 1.1, 2.4, Vector2(1.6, 0.7), Color(0.9, 0.93, 0.97, 0.28))
	_add_layer(drift)


func _add_layer(layer: SnowLayer) -> void:
	add_child(layer)
	_layers.append(layer)


func _build_sheets() -> void:
	var path := "res://assets/weather/SM_Env_Fog_Ring_01.fbx"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.9, 0.93, 0.97, 0.22)
	if ResourceLoader.exists(TEX + "Gradient_Fog.png"):
		material.albedo_texture = load(TEX + "Gradient_Fog.png")
	for i in 4:
		var ring := packed.instantiate() as Node3D
		ring.scale = Vector3(10.0 + float(i) * 3.5, 4.0, 10.0 + float(i) * 3.5)
		ring.position = Vector3(randf_range(-6.0, 6.0), randf_range(-0.4, 1.6), randf_range(-6.0, 6.0))
		for mesh_instance in ring.find_children("*", "MeshInstance3D", true, false):
			(mesh_instance as MeshInstance3D).material_override = material
			(mesh_instance as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_sheets.append(ring)


func _drift_sheets(delta: float) -> void:
	var slide := Vector3(wind.x, 0.0, wind.z)
	if slide.length() > 0.01:
		slide = slide.normalized()
	for sheet in _sheets:
		sheet.position += slide * delta * (1.4 + gust)
		sheet.position.y = clampf(sheet.position.y + sin(Time.get_ticks_msec() * 0.0004 + sheet.position.x) * delta * 0.15, -0.6, 2.2)
		sheet.rotation.y += delta * 0.04
		if Vector2(sheet.position.x, sheet.position.z).length() > 22.0:
			sheet.position = Vector3(randf_range(-7.0, 7.0), randf_range(-0.2, 1.4), randf_range(-7.0, 7.0))
