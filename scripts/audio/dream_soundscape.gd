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
var _cued_step_in := -1.0
var _cued_step_position := Vector3.ZERO
var _apparition_quiet_time := 0.0
var _memory_bed: AudioStreamPlayer3D
var _wood_creak: AudioStreamPlayer3D
var _memory_target_db := -80.0
var _memory_hold := 0.0
var _suspended := false
var _travel_quiet := false
var _travel_quiet_weight := 0.0


func _ready() -> void:
	for index in 2:
		var voice := Loudness.voice(STEP_LEVEL, "Effects", true)
		voice.name = "RememberedFootstep%d" % index
		voice.max_distance = 22.0
		voice.volume_db = -80.0
		add_child(voice)
		_voices.append(voice)
	_memory_bed = Loudness.voice(40.0, "Effects", true)
	_memory_bed.name = "RoomToneInSnow"
	_memory_bed.max_distance = 28.0
	_memory_bed.volume_db = -80.0
	_memory_bed.stream = load("res://assets/audio/drone.wav")
	_memory_bed.finished.connect(_repeat_memory_bed)
	add_child(_memory_bed)
	_wood_creak = Loudness.voice(43.0, "Effects", true)
	_wood_creak.name = "RememberedFloorboard"
	_wood_creak.max_distance = 20.0
	_wood_creak.volume_db = -80.0
	_wood_creak.stream = load("res://assets/audio/house_creak_board.wav")
	add_child(_wood_creak)


func _exit_tree() -> void:
	for voice in _voices:
		voice.stop()
	if _memory_bed:
		_memory_bed.stop()
	if _wood_creak:
		_wood_creak.stop()


func _process(delta: float) -> void:
	if _suspended:
		return
	_update_memory_bed(delta)
	if Game.phase != Game.Phase.DREAM or Game.player == null or Game.trail == null:
		return
	if _travel_quiet:
		_second_step_in = -1.0
		_next_pair = maxf(_next_pair, 2.5)
		return
	if _cued_step_in >= 0.0:
		_cued_step_in -= delta
		if _cued_step_in <= 0.0:
			_play_step_at(1, _cued_step_position, 0.86)
			_cued_step_in = -1.0
	_apparition_quiet_time = maxf(_apparition_quiet_time - delta, 0.0)
	if _apparition_quiet_time > 0.0:
		return
	var speed := Vector2(Game.player.velocity.x, Game.player.velocity.z).length()
	if speed < 0.9:
		return
	var progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	if _dark_patch_weight(progress) > 0.65:
		_second_step_in = -1.0
		_next_pair = maxf(_next_pair, 2.5)
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


func memory_cue(cue_id: String, at: Vector3) -> void:
	if _memory_bed == null:
		return
	_memory_bed.global_position = at + Vector3.UP * 1.3
	_memory_bed.pitch_scale = 0.72 if cue_id == "thread" else 0.88 if cue_id == "window" else 0.94
	_memory_target_db = -43.0 if cue_id == "window" else -47.0
	_memory_hold = 19.0 if cue_id == "window" else 13.0
	if not _memory_bed.playing:
		_memory_bed.play()
	if cue_id != "thread" and _wood_creak and _wood_creak.stream:
		_wood_creak.global_position = at + Vector3.UP * 0.3
		_wood_creak.pitch_scale = 0.82 if cue_id == "window" else 0.96
		Loudness.sound(_wood_creak, 43.0, true)
		_wood_creak.play()


func set_suspended(value: bool) -> void:
	_suspended = value


func set_travel_quiet(value: bool) -> void:
	_travel_quiet = value


func _repeat_memory_bed() -> void:
	if _memory_bed and Game.dream_mode and _memory_target_db > -70.0:
		_memory_bed.play()


func _update_memory_bed(delta: float) -> void:
	if _memory_bed == null or Game.phase == Game.Phase.PAUSED:
		return
	_travel_quiet_weight = move_toward(_travel_quiet_weight, 1.0 if _travel_quiet else 0.0, delta * 0.45)
	_memory_hold = maxf(_memory_hold - delta, 0.0)
	if _memory_hold <= 0.0 or not Game.dream_mode:
		_memory_target_db = -80.0
	var quiet := 0.0
	if Game.player and Game.trail:
		var progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
		quiet = _dark_patch_weight(progress)
	var target := _memory_target_db - maxf(quiet, _travel_quiet_weight) * 30.0
	_memory_bed.volume_db = move_toward(_memory_bed.volume_db, target, delta * 7.0)
	if _memory_bed.volume_db <= -76.0 and _memory_target_db <= -76.0 and _memory_bed.playing:
		_memory_bed.stop()


func _dark_patch_weight(progress: float) -> float:
	var weight := 0.0
	for patch_offset in [14.0, 27.0, 42.0, 58.0]:
		weight = maxf(weight, 1.0 - absf(progress - patch_offset) / 3.6)
	return clampf(weight, 0.0, 1.0)


func _play_step(voice_index: int, behind: float) -> void:
	var player_offset := Game.trail.offset_of(Game.player.global_position)
	var step_offset := maxf(player_offset - behind, Game.trail.player_start_offset)
	var at := Game.trail.on_ground(Game.trail.frame_at(step_offset).origin) + Vector3.UP * 0.08
	_play_step_at(voice_index, at, randf_range(0.96, 1.04))


func _play_step_at(voice_index: int, at: Vector3, pitch: float) -> void:
	if voice_index < 0 or voice_index >= _voices.size():
		return
	var voice := _voices[voice_index]
	if voice.playing:
		voice.stop()
	voice.stream = _pick_step()
	if voice.stream == null:
		return
	voice.global_position = at
	voice.pitch_scale = pitch
	Loudness.sound(voice, STEP_LEVEL, true)
	voice.play()


func delayed_step_cue(first_at: Vector3, second_at: Vector3) -> void:
	if _voices.size() < 2:
		return
	_cued_step_position = second_at + Vector3.UP * 0.08
	_play_step_at(0, first_at + Vector3.UP * 0.08, 0.92)
	_cued_step_in = 0.62
	_apparition_quiet_time = 1.25


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
