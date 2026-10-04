extends Node

# Steer the real player along the saved trail with normal movement and threats.
# godot --headless --path . tools/traversal_probe.tscn
const MAX_SECONDS := 210.0
const LOOK_AHEAD := 5.0

var _main: Node3D
var _player: Player
var _trail: Trail
var _elapsed := 0.0
var _last_report := -1
var _max_offset := 0.0
var _hunt_at := -1.0
var _hunt_report := 0
var _outcome := ""
var _with_notes := OS.get_environment("RUN_TRAVERSAL_NOTES") == "1"
var _notes: Array[FieldNote] = []
var _note_index := 0
var _reading_since := -1.0


func _ready() -> void:
	process_priority = -100
	process_physics_priority = -100
	_start.call_deferred()


func _start() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	await get_tree().physics_frame
	_player = Game.player
	_trail = Game.trail
	if _player == null or _trail == null:
		_finish("scene did not build the player and trail")
		return
	var start := _trail.position_at(_trail.player_start_offset)
	_player.global_position = _trail.on_ground(start) + Vector3.UP * 0.5
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	if _with_notes:
		for index in 3:
			var note := _main.find_child("FieldNote_%d" % index, true, false) as FieldNote
			if note == null:
				_finish("missing authored note %d" % index)
				return
			_notes.append(note)
			print("Authored note %d at %.1f m" % [index,
				_trail.offset_of(note.global_position) - _trail.player_start_offset])
	Game.set_phase(Game.Phase.PLAYING)
	Input.action_press("move_forward")
	print("Traversal start: %.1f m saved route, %s" % [
		_trail.exit_offset - _trail.player_start_offset,
		"three notes" if _with_notes else "no notes"])
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _player == null or _trail == null or _outcome != "":
		return
	_elapsed += delta
	var offset := _trail.offset_of(_player.global_position)
	_max_offset = maxf(_max_offset, offset)
	if Game.hunt_started and _hunt_at < 0.0:
		_hunt_at = _elapsed
		print("Hunt began at %.1f s, %.1f m along route, hunter gap %.1f m" % [
			_elapsed, offset - _trail.player_start_offset,
			_player.global_position.distance_to(Game.hunter.global_position)])
	if _hunt_at >= 0.0 and _elapsed - _hunt_at >= _hunt_report * 10.0:
		print("Hunt +%d s: gap %.1f m, stamina %.1f" % [
			_hunt_report * 10, _player.global_position.distance_to(Game.hunter.global_position),
			_player.stamina])
		_hunt_report += 1
	if Game.phase == Game.Phase.READING:
		Input.action_release("move_forward")
		Input.action_release("sprint")
		if _reading_since < 0.0:
			_reading_since = _elapsed
		if _elapsed - _reading_since >= 2.0:
			_interact()
			_note_index += 1
			_reading_since = -1.0
		return
	Input.action_press("move_forward")
	var ahead := _trail.position_at(minf(offset + LOOK_AHEAD, _trail.exit_offset))
	if _with_notes and _note_index < _notes.size():
		var note := _notes[_note_index]
		var note_offset := _trail.offset_of(note.global_position)
		if offset >= note_offset - 6.0:
			ahead = note.global_position
			var distance := _player.global_position.distance_to(ahead)
			if distance < 1.8:
				Input.action_release("move_forward")
				Input.action_release("sprint")
				if _player.nearby_note() == note:
					_interact()
					if Game.phase != Game.Phase.READING:
						_finish("could not open note %d" % _note_index)
					else:
						print("Read note %d at %.1f m, t=%.1f, hunt=%s" % [
							_note_index, offset - _trail.player_start_offset,
							_elapsed, Game.hunt_started])
					return
				elif distance < 0.8:
					_finish("note %d is physically unreachable" % _note_index)
					return
			else:
				Input.action_press("move_forward")
	var direction := ahead - _player.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.04:
		_player._yaw = atan2(-direction.x, -direction.z)
	# Sprint in short bursts during pursuit, as a player with stamina would.
	if Game.hunt_started and _player.stamina > 2.4 and _player.exhaust_left <= 0.0:
		Input.action_press("sprint")
	elif _player.stamina < 0.8 or _player.exhaust_left > 0.0:
		Input.action_release("sprint")
	var report := int(_elapsed / 10.0)
	if report != _last_report:
		_last_report = report
		print("t=%.0f progress=%.1f/%.1f stamina=%.1f phase=%d hunter=%.1f" % [
			_elapsed, offset - _trail.player_start_offset,
			_trail.exit_offset - _trail.player_start_offset,
			_player.stamina, Game.phase,
			_player.global_position.distance_to(Game.hunter.global_position)])
	if Game.phase == Game.Phase.ESCAPED:
		_finish("escaped")
	elif Game.phase == Game.Phase.CAUGHT:
		_finish("caught: %s" % Game.ending_title)
	elif _elapsed >= MAX_SECONDS:
		_finish("timed out")


func _finish(result: String) -> void:
	if _outcome != "":
		return
	_outcome = result
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print("Traversal result: %s at %.1f s, furthest %.1f m, hunt at %.1f s, notes %d, gap %.1f m, stamina %.1f" % [
		result, _elapsed, _max_offset - _trail.player_start_offset if _trail else 0.0,
		_hunt_at, Game.notes_found,
		_player.global_position.distance_to(Game.hunter.global_position) if _player and Game.hunter else -1.0,
		_player.stamina if _player else -1.0])
	var expected_notes := 3 if _with_notes else 0
	get_tree().quit(0 if result == "escaped" and Game.notes_found == expected_notes and _hunt_at >= 0.0 else 1)


func _interact() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	_player._unhandled_input(key)
