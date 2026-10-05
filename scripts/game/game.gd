extends Node

enum Phase { BOOT, INTRO, PLAYING, READING, PAUSED, CAUGHT, ESCAPED }

signal phase_changed(next: Phase)
signal closeness_changed(value: float)
signal interaction_feedback(message: String, succeeded: bool)

var phase: Phase = Phase.BOOT
# Threats report here: how near the one that hunts her is (closeness), the
# strongest other pressure (dread) and the HUD line that goes with it. The
# UI never shows distances. There are no threats in the field yet; see
# docs/THREATS.md.
var closeness: float = 0.0
var player: Player
var trail: Trail
var soundscape: Soundscape
var voice: Voice
var weather: Weather
var active_note: FieldNote
var intro_left: float = Tune.INTRO_TIME
var notes_found: int = 0
var lean_graphics := true
var blackbox: Blackbox
var settings: Settings
# The cabin she wakes in: rooms, cellar and morgue.
var house: House
var dread: float = 0.0
var threat_hint := ""
# Something waiting on the doorstep: the house knocks harder.
var something_at_door := false
# Whatever threat has just shown itself in the open; ravens scold beside it.
var shown_threat: Node3D
# A line from the house, spoken under the breath, gone in a few seconds.
var murmur := ""
var murmur_left := 0.0
# Records she has read (NoteEntry.record_of), by code.
var understood: Dictionary = {}
var ending_title := ""
var ending_body := ""
# She opened the page that asks her to finish. The road remembers. The catch does not speak in that voice.
var read_last_page := false
var hunt_started := false
var _hunt_seconds := 0.0
var audio_fade := 0.0
var _audio_hold := 4


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
	_bind("walk_slow", KEY_ALT)
	_bind("glance_back", KEY_Q)
	_bind_mouse("glance_back", MOUSE_BUTTON_MIDDLE)
	_bind_pad()
	# After the defaults, so it knows what to reset the keys to.
	settings = Settings.new()
	settings.name = "Settings"
	add_child(settings)
	lean_graphics = _wants_lean_graphics()
	print("graphics: ", "lean" if lean_graphics else "full", " on ", RenderingServer.get_video_adapter_name())


func _process(delta: float) -> void:
	if phase != Phase.BOOT and audio_fade < 1.0:
		if _audio_hold > 0:
			_audio_hold -= 1
		else:
			audio_fade = move_toward(audio_fade, 1.0, minf(delta, 0.05) / Tune.INTRO_TIME)
			if settings:
				settings.apply_audio()
	if phase == Phase.PLAYING and player and trail and _at_exit():
		escape()
	if phase == Phase.PLAYING or phase == Phase.READING:
		if not hunt_started and player and trail and not indoors(player.global_position + Vector3.UP * 0.9):
			if trail.offset_of(player.global_position) >= trail.player_start_offset + Tune.HUNT_ROUTE_DISTANCE:
				start_hunt()
		if hunt_started:
			_hunt_seconds += delta
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
	trail = null
	soundscape = null
	voice = null
	weather = null
	active_note = null
	notes_found = 0
	house = null
	dread = 0.0
	threat_hint = ""
	something_at_door = false
	shown_threat = null
	murmur = ""
	murmur_left = 0.0
	understood.clear()
	ending_title = ""
	ending_body = ""
	read_last_page = false
	hunt_started = false
	_hunt_seconds = 0.0
	audio_fade = 0.0
	_audio_hold = 4
	if settings:
		settings.apply_audio()


func begin_intro() -> void:
	intro_left = Tune.INTRO_TIME
	audio_fade = 0.0
	_audio_hold = 4
	if settings:
		settings.apply_audio()
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
		if entry and entry.title == NoteCatalog.LAST_TITLE:
			read_last_page = true
		if notes_found >= Tune.HUNT_NOTES:
			start_hunt()
	if voice and entry:
		voice.heard_page(entry)
	set_phase(Phase.READING)


func reading_last_page() -> bool:
	if phase != Phase.READING or active_note == null or active_note.entry == null:
		return false
	return active_note.entry.title == NoteCatalog.LAST_TITLE


func murmur_line(line: String) -> void:
	murmur = line
	murmur_left = clampf(2.6 + line.length() * 0.04, 3.2, 7.5)


func seconds_hunting() -> float:
	return _hunt_seconds


func start_hunt() -> void:
	if hunt_started:
		return
	hunt_started = true
	mark("hunt started at %d pages" % notes_found)


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


# title and body are the threat's own ending; empty gives the default card.
func catch_player(title := "", body := "") -> void:
	if phase == Phase.CAUGHT or phase == Phase.ESCAPED:
		return
	ending_title = title
	ending_body = body
	rumble(0.8, 1.0, 0.6)
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


# How hard the world is pressing on her, whichever threat it is.
func threat() -> float:
	return maxf(closeness, dread)


# The road: within EXIT_RADIUS of the exit, measured flat.
func _at_exit() -> bool:
	var at := player.global_position
	var end := trail.exit_point
	return Vector2(at.x - end.x, at.z - end.z).length() <= Tune.EXIT_RADIUS


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


# A gamepad alongside the keys. The sticks are read with their own radial dead
# zone (Player), so the actions themselves pass even the smallest push.
func _bind_pad() -> void:
	for axis in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
			["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0],
			["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0],
			["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0],
			["sprint", JOY_AXIS_TRIGGER_LEFT, 1.0], ["hold_breath", JOY_AXIS_TRIGGER_RIGHT, 1.0]]:
		_bind_axis(axis[0], axis[1], axis[2])
	for button in [["jump", JOY_BUTTON_A], ["slide", JOY_BUTTON_B], ["interact", JOY_BUTTON_X],
			["sprint", JOY_BUTTON_LEFT_STICK], ["glance_back", JOY_BUTTON_RIGHT_STICK],
			["walk_slow", JOY_BUTTON_LEFT_SHOULDER], ["hold_breath", JOY_BUTTON_RIGHT_SHOULDER],
			["pause", JOY_BUTTON_START], ["restart", JOY_BUTTON_BACK]]:
		if not InputMap.has_action(button[0]):
			InputMap.add_action(button[0])
		var event := InputEventJoypadButton.new()
		event.button_index = button[1]
		event.device = -1
		InputMap.action_add_event(button[0], event)


func _bind_axis(action: String, axis: JoyAxis, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_set_deadzone(action, 0.05)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	event.device = -1
	InputMap.action_add_event(action, event)


## A short shake on every connected pad, if she wants it.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if settings == null or not settings.rumble:
		return
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), seconds)
