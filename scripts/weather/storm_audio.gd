class_name StormAudio
extends Node3D

# The storm around her ears, held in the world's frame: four storm beds and
# two breeze beds on a ring around her that keeps to the compass, not the
# camera, so turning her head turns the storm through the speakers. Gusts
# howl in from upwind. Levels are the storm's SPL at her ears (Loudness):
# the beds are not attenuated by distance, only placed. Inside, the walls
# take Loudness.WALLS and most of the highs, the cellar more, and the wind
# is heard where it gets in, whistling at the windows that face it.

const WEATHER := "res://assets/audio/weather/"
const RING := 8.0
const COMPASS := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]

var _storm: Array[AudioStreamPlayer3D] = []
var _breeze: Array[AudioStreamPlayer3D] = []
var _howl: AudioStreamPlayer3D
var _whistles: Array[AudioStreamPlayer3D] = []


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for i in 4:
		_storm.append(_bed("storm_%d.ogg" % i, (COMPASS[i] as Vector3) * RING + Vector3.UP))
	for i in 2:
		var corner := Vector3(1.0, 0.0, -1.0) if i == 0 else Vector3(-1.0, 0.0, 1.0)
		_breeze.append(_bed("breeze_%d.ogg" % i, corner.normalized() * RING))
	_howl = _bed("howl.ogg", Vector3(0.0, 1.5, -RING))
	for i in 2:
		var whistle := Loudness.voice(Loudness.WINDOW_WHISTLE, "Ambience")
		whistle.top_level = true
		whistle.volume_db = -80.0
		whistle.stream = _stream("window.ogg")
		add_child(whistle)
		if whistle.stream:
			whistle.play(randf() * whistle.stream.get_length())
		_whistles.append(whistle)


# Streamed loops still playing at quit are reported as leaks.
func _exit_tree() -> void:
	for player in find_children("*", "AudioStreamPlayer3D", false, false):
		(player as AudioStreamPlayer3D).stop()


## intensity and gust from Weather (0..1), the wind it blows, and how far
## she is inside (0 in the open .. 1 behind the walls).
func apply(intensity: float, gust: float, wind: Vector3, shelter: float, whiteout: float = 0.0) -> void:
	var listener := get_viewport().get_audio_listener_3d()
	var camera := get_viewport().get_camera_3d()
	var ears := listener.global_position if listener else (camera.global_position if camera else global_position)
	global_position = ears
	var cellar := 1.0 if Game.house and House.is_cellar(Game.house.room_at(ears)) else 0.0
	var through := Loudness.WALLS * shelter + Loudness.CELLAR * cellar
	var storm := smoothstep(0.22, 0.85, intensity + whiteout * 0.2)
	var bed := lerpf(Loudness.WIND_CALM - 2.0, Loudness.WIND_STORM + 2.5, clampf((intensity - 0.18) / 0.78, 0.0, 1.0)) + gust * 4.5 + whiteout * 2.0
	var upwind := Vector3(-wind.x, 0.0, -wind.z)
	upwind = upwind.normalized() if upwind.length() > 0.1 else Vector3.FORWARD
	# Four uncorrelated beds add up to the whole: 6 dB less each, biased slightly upwind.
	for i in _storm.size():
		var player := _storm[i]
		var dir_bias := maxf((COMPASS[i] as Vector3).dot(upwind), 0.0) * (1.8 + gust * 1.6)
		player.volume_db = Loudness.volume(bed - 6.0 + dir_bias - (1.0 - storm) * 11.0 - through)
		player.pitch_scale = lerpf(0.92, 1.06, clampf(intensity * 0.6 + gust * 0.4, 0.0, 1.0))
	for player in _breeze:
		player.volume_db = Loudness.volume(bed - 3.0 - storm * 12.0 - through)
		player.pitch_scale = lerpf(0.95, 1.04, gust)
	if _howl:
		_howl.position = upwind * RING + Vector3.UP * 1.5
		var howl_drive := smoothstep(0.12, 0.88, clampf(gust * 0.8 + whiteout * 0.35, 0.0, 1.0))
		_howl.volume_db = Loudness.volume(lerpf(Loudness.GUST - 26.0, Loudness.GUST + 1.5, howl_drive) - through)
		_howl.pitch_scale = lerpf(0.91, 1.08, clampf(gust * 0.75 + whiteout * 0.25, 0.0, 1.0))
	if Game.settings:
		Game.settings.set_walls(lerpf(20000.0, 650.0, shelter) * lerpf(1.0, 0.55, cellar))
	_place_whistles(ears, upwind, intensity, gust, shelter, whiteout)


# At the two windows nearest her among those that face into the wind.
func _place_whistles(ears: Vector3, upwind: Vector3, intensity: float, gust: float, shelter: float, whiteout: float) -> void:
	var windward := []
	if Game.house and shelter > 0.01:
		for window in Game.house.windows():
			if (window[1] as Vector3).dot(upwind) > 0.15:
				windward.append(window)
		windward.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).distance_to(ears) < (b[0] as Vector3).distance_to(ears))
	for i in _whistles.size():
		var whistle := _whistles[i]
		if i >= windward.size():
			whistle.volume_db = -80.0
			continue
		whistle.global_position = windward[i][0]
		var level := Loudness.WINDOW_WHISTLE + lerpf(-9.0, 1.5, intensity) + gust * 8.5 + whiteout * 2.0 - (1.0 - shelter) * 30.0
		whistle.volume_db = Loudness.volume(level)
		whistle.pitch_scale = lerpf(0.96, 1.07, clampf(gust * 0.8 + whiteout * 0.2, 0.0, 1.0))


func _bed(file_name: String, offset: Vector3) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = "Outside"
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.attenuation_filter_db = 0.0
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	player.max_db = 6.0
	player.volume_db = -80.0
	player.position = offset
	player.stream = _stream(file_name)
	add_child(player)
	if player.stream:
		player.play(randf() * player.stream.get_length())
	return player


func _stream(file_name: String) -> AudioStream:
	var path := WEATHER + file_name
	return load(path) if ResourceLoader.exists(path) else null
