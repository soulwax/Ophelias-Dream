extends Node

enum Phase { BOOT, INTRO, PLAYING, READING, PAUSED, CAUGHT, ESCAPED }

signal phase_changed(next: Phase)
signal closeness_changed(value: float)

var phase: Phase = Phase.BOOT
var closeness: float = 0.0
var player: Player
var hunter: Hunter
var trail: Trail
var soundscape: Soundscape
var weather: Weather
var active_note: FieldNote
var intro_left: float = Tune.INTRO_TIME
var notes_found: int = 0
var _hunt_start_msec: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind("move_forward", KEY_W)
	_bind("move_back", KEY_S)
	_bind("move_left", KEY_A)
	_bind("move_right", KEY_D)
	_bind("sprint", KEY_SHIFT)
	_bind("interact", KEY_E)
	_bind("pause", KEY_ESCAPE)
	_bind("restart", KEY_R)


func _process(delta: float) -> void:
	if phase != Phase.INTRO:
		return
	intro_left -= delta
	if intro_left <= 0.0:
		set_phase(Phase.PLAYING)


func reset() -> void:
	Engine.time_scale = 1.0
	if is_inside_tree():
		get_tree().paused = false
	phase = Phase.BOOT
	closeness = 0.0
	intro_left = Tune.INTRO_TIME
	player = null
	hunter = null
	trail = null
	soundscape = null
	weather = null
	active_note = null
	notes_found = 0
	_hunt_start_msec = -1


func begin_intro() -> void:
	intro_left = Tune.INTRO_TIME
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_phase(Phase.INTRO)


func set_phase(next: Phase) -> void:
	if phase == next:
		return
	phase = next
	phase_changed.emit(phase)


func set_closeness(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, closeness):
		return
	closeness = next
	closeness_changed.emit(closeness)


func begin_reading() -> void:
	if phase != Phase.PLAYING:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if active_note and active_note.collect():
		notes_found += 1
		if notes_found == Tune.HUNT_NOTES and _hunt_start_msec < 0:
			_hunt_start_msec = Time.get_ticks_msec()
	set_phase(Phase.READING)


func seconds_hunting() -> float:
	if _hunt_start_msec < 0:
		return 0.0
	return float(Time.get_ticks_msec() - _hunt_start_msec) / 1000.0


func close_reading() -> void:
	if phase != Phase.READING:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_phase(Phase.PLAYING)


func toggle_pause() -> void:
	if phase == Phase.PLAYING:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_phase(Phase.PAUSED)
	elif phase == Phase.PAUSED:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		set_phase(Phase.PLAYING)


func catch_player() -> void:
	if phase == Phase.CAUGHT or phase == Phase.ESCAPED:
		return
	Engine.time_scale = 0.4
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_phase(Phase.CAUGHT)
	if soundscape:
		soundscape.play_sting()


func escape() -> void:
	if phase == Phase.CAUGHT or phase == Phase.ESCAPED:
		return
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_phase(Phase.ESCAPED)


func restart() -> void:
	reset()
	get_tree().reload_current_scene()


func locks_movement() -> bool:
	return phase != Phase.PLAYING


func locks_look() -> bool:
	return phase != Phase.PLAYING and phase != Phase.INTRO


func _bind(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
