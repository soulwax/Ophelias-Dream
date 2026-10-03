extends Node

enum Phase { BOOT, INTRO, PLAYING, READING, PAUSED, CAUGHT, ESCAPED }

signal phase_changed(next: Phase)
signal closeness_changed(value: float)
signal interaction_feedback(message: String, succeeded: bool)

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
var lean_graphics := true
var blackbox: Blackbox
var settings: Settings
# Anomalies: the strongest pressure any of them puts on her this frame, the
# HUD line that goes with it, and which ones she has read the record of.
var director: AnomalyDirector
# The cabin she wakes in: rooms, cellar and morgue.
var house: House
var dread: float = 0.0
var anomaly_hint := ""
# A line from the house, spoken under the breath, gone in a few seconds.
var murmur := ""
var murmur_left := 0.0
var understood: Dictionary = {}
var ending_title := ""
var ending_body := ""
var _hunt_start_msec: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var blackbox_path := OS.get_environment("RUN_BLACKBOX")
	if blackbox_path != "":
		blackbox = Blackbox.open(blackbox_path)
		if blackbox:
			add_child(blackbox)
	_bind("move_forward", KEY_W)
	_bind("move_back", KEY_S)
	_bind("move_left", KEY_A)
	_bind("move_right", KEY_D)
	_bind("sprint", KEY_SHIFT)
	_bind("interact", KEY_E)
	_bind("pause", KEY_ESCAPE)
	_bind("restart", KEY_R)
	_bind("jump", KEY_SPACE)
	_bind("slide", KEY_CTRL)
	_bind("slide", KEY_C)
	_bind_mouse("hold_breath", MOUSE_BUTTON_RIGHT)
	_bind("hold_breath", KEY_F)
	# After the defaults, so it knows what to reset the keys to.
	settings = Settings.new()
	settings.name = "Settings"
	add_child(settings)
	lean_graphics = _wants_lean_graphics()
	print("graphics: ", "lean" if lean_graphics else "full", " on ", RenderingServer.get_video_adapter_name())


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
	director = null
	house = null
	dread = 0.0
	anomaly_hint = ""
	murmur = ""
	murmur_left = 0.0
	understood.clear()
	ending_title = ""
	ending_body = ""
	_hunt_start_msec = -1


func begin_intro() -> void:
	intro_left = Tune.INTRO_TIME
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_phase(Phase.INTRO)


func mark(line: String) -> void:
	if blackbox:
		blackbox.write(line)


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
	var entry := active_note.entry if active_note else null
	if entry and entry.record_of != "":
		active_note.collect()
		understood[entry.record_of] = true
	elif entry and not entry.counts:
		active_note.collect()
	elif active_note and active_note.collect():
		notes_found += 1
		if notes_found == Tune.HUNT_NOTES and _hunt_start_msec < 0:
			_hunt_start_msec = Time.get_ticks_msec()
	set_phase(Phase.READING)


func murmur_line(line: String) -> void:
	murmur = line
	murmur_left = 4.5


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
		if settings:
			settings.save()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		set_phase(Phase.PLAYING)


# title and body replace the hunter's ending when something else took her.
func catch_player(title := "", body := "") -> void:
	if phase == Phase.CAUGHT or phase == Phase.ESCAPED:
		return
	ending_title = title
	ending_body = body
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
	if settings:
		settings.save()
	reset()
	# The graphics detail setting is read while the snowfield is built.
	lean_graphics = _wants_lean_graphics()
	get_tree().reload_current_scene()


func quit() -> void:
	if settings:
		settings.save()
	get_tree().quit()


# How hard the world is pressing on her: the hunter or any anomaly.
func threat() -> float:
	return maxf(closeness, dread)


func knows(code: String) -> bool:
	return understood.has(code)


func indoors(world_point: Vector3) -> bool:
	return house != null and house.contains(world_point)


func locks_movement() -> bool:
	return phase != Phase.PLAYING


func locks_look() -> bool:
	return phase != Phase.PLAYING and phase != Phase.INTRO


# Integrated GPUs hard-froze on volumetric fog and the full shadow load.
# RUN_GRAPHICS=full or RUN_GRAPHICS=lean overrides the guess, then the
# graphics detail setting.
func _wants_lean_graphics() -> bool:
	var forced := OS.get_environment("RUN_GRAPHICS")
	if forced == "full":
		return false
	if forced == "lean":
		return true
	if settings and settings.graphics != 0:
		return settings.graphics == 1
	return RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _bind(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
