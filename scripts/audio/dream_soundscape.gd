class_name DreamSoundscape
extends Node3D

## A sparse pair of remembered snow steps, kept behind the player's own pace.
const STEP_PATH := "res://assets/audio/steps/"
const STEP_COUNT := 24
const STEP_LEVEL := 48.0
var _voices: Array[AudioStreamPlayer3D] = []
var _last_clip := -1
var _next_pair := 5.5
var _second_step_in := -1.0
var _apparition_quiet_time := 0.0


func _ready() -> void:
	for index in 2:
		var voice := Loudness.voice(STEP_LEVEL, "Effects", true)
		voice.name = "RememberedFootstep%d" % index
		voice.max_distance = 22.0
		voice.volume_db = -80.0
		add_child(voice)
		_voices.append(voice)


func _exit_tree() -> void:
	for voice in _voices:
		voice.stop()


func _process(delta: float) -> void:
	if Game.phase != Game.Phase.DREAM or Game.player == null or Game.trail == null:
		return
	_apparition_quiet_time = maxf(_apparition_quiet_time - delta, 0.0)
	if _apparition_quiet_time > 0.0:
		return
	var speed := Vector2(Game.player.velocity.x, Game.player.velocity.z).length()
	if speed < 0.9:
		return
	if _second_step_in >= 0.0:
		_second_step_in -= delta
		if _second_step_in <= 0.0:
			_play_step(1, 4.3)
			_second_step_in = -1.0
		return
	_next_pair -= delta
	if _next_pair <= 0.0:
		_play_step(0, 3.2)
		_second_step_in = 0.46
		_next_pair = randf_range(8.0, 12.0)


func _play_step(voice_index: int, behind: float) -> void:
	var player_offset := Game.trail.offset_of(Game.player.global_position)
	var step_offset := maxf(player_offset - behind, Game.trail.player_start_offset)
	var at := Game.trail.on_ground(Game.trail.frame_at(step_offset).origin) + Vector3.UP * 0.08
	var voice := _voices[voice_index]
	voice.stream = _pick_step()
	if voice.stream == null:
		return
	voice.global_position = at
	voice.pitch_scale = randf_range(0.96, 1.04)
	Loudness.sound(voice, STEP_LEVEL, true)
	voice.play()


func apparition_footstep(at: Vector3, returning: bool) -> void:
	if _voices.is_empty():
		return
	var voice := _voices[1 if returning else 0]
	if voice.playing:
		voice.stop()
	voice.stream = _pick_step()
	if voice.stream == null:
		return
	voice.global_position = at + Vector3.UP * 0.08
	voice.pitch_scale = 0.94 if returning else 0.84
	Loudness.sound(voice, STEP_LEVEL - 8.0, true)
	voice.play()
	_apparition_quiet_time = 2.0


func _pick_step() -> AudioStream:
	var index := randi_range(0, STEP_COUNT - 1)
	if STEP_COUNT > 1 and index == _last_clip:
		index = (index + randi_range(1, STEP_COUNT - 1)) % STEP_COUNT
	_last_clip = index
	var path := STEP_PATH + "snow_%02d.wav" % index
	return load(path) if ResourceLoader.exists(path) else null
