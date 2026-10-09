class_name Settings
extends Node

# Everything the Esc menu can change, saved to user://settings.cfg and applied
# at once: look and keys, camera, display, sound and the HUD. Systems read the
# values here when they need them, so a change takes effect on the next frame.

signal changed

const PATH := "user://settings.cfg"
# Rebindable actions in menu order. Each holds up to SLOTS keys or buttons.
const ACTIONS := [
	["move_forward", "Move forward"],
	["move_back", "Move back"],
	["move_left", "Move left"],
	["move_right", "Move right"],
	["sprint", "Sprint"],
	["jump", "Jump"],
	["slide", "Slide (while sprinting)"],
	["walk_slow", "Walk slowly (hold)"],
	["glance_back", "Glance back (hold)"],
	["interact", "Read / open / use"],
	["draw_bow", "Draw / put away bow"],
	["aim_bow", "Aim the bow (hold)"],
	["shoot_arrow", "Shoot an arrow"],
	["journal", "Journal"],
	["restart", "Restart (paused or at the end)"],
]
const SLOTS := 2
const BUSES := ["Ambience", "Effects", "Dread"]
const FRAME_CAPS := [30, 60, 90, 120, 144, 165, 240, 0]
const DEFAULTS := {
	"mouse_sensitivity": 1.0,
	"stick_sensitivity": 1.0,
	"invert_y": false,
	"invert_x": false,
	"sprint_toggle": false,
	"rumble": true,
	"fov": 70.0,
	"camera_distance": 1.0,
	"camera_shake": 1.0,
	"speed_fov": true,
	"display_mode": 0,
	"vsync": true,
	"max_fps": 60,
	"render_scale": 1.0,
	"graphics": 0,
	"brightness": 1.0,
	"anti_aliasing": 0,
	"ui_scale": 1.0,
	"master_volume": 1.0,
	"ambience_volume": 1.0,
	"effects_volume": 1.0,
	"dread_volume": 1.0,
	"voice_volume": 1.0,
	"mute_unfocused": true,
	"show_prompts": true,
	"show_journal_toast": true,
	"breath_meter": 0,
	"show_reticle": true,
	"subtitles": true,
	"subtitle_size": 1,
	"screen_effects": 1.0,
}
# Subtitle font sizes for subtitle_size 0 small, 1 medium, 2 large.
const SUBTITLE_SIZES := [14, 16, 20]

# Look and keys.
var mouse_sensitivity: float = DEFAULTS.mouse_sensitivity
var stick_sensitivity: float = DEFAULTS.stick_sensitivity
var invert_y: bool = DEFAULTS.invert_y
var invert_x: bool = DEFAULTS.invert_x
var sprint_toggle: bool = DEFAULTS.sprint_toggle
var rumble: bool = DEFAULTS.rumble
# Camera: base field of view in degrees, boom length as a share of the
# default, how much footfalls, gusts and landings shake it, and whether it
# widens with her speed.
var fov: float = DEFAULTS.fov
var camera_distance: float = DEFAULTS.camera_distance
var camera_shake: float = DEFAULTS.camera_shake
var speed_fov: bool = DEFAULTS.speed_fov
# Display: 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen.
# max_fps 0 is unlimited. graphics 0 picks by GPU, 1 lean, 2 full; it is
# read when the snowfield is built, so it applies from the next run.
var display_mode: int = DEFAULTS.display_mode
var vsync: bool = DEFAULTS.vsync
var max_fps: int = DEFAULTS.max_fps
var render_scale: float = DEFAULTS.render_scale
var graphics: int = DEFAULTS.graphics
var brightness: float = DEFAULTS.brightness
# anti_aliasing 0 off, 1 FXAA, 2 SMAA, 3 TAA. ui_scale multiplies every 2D
# element (menus, HUD, subtitles), not the world.
var anti_aliasing: int = DEFAULTS.anti_aliasing
var ui_scale: float = DEFAULTS.ui_scale
# Sound, linear 0..1 per bus.
var master_volume: float = DEFAULTS.master_volume
var ambience_volume: float = DEFAULTS.ambience_volume
var effects_volume: float = DEFAULTS.effects_volume
var dread_volume: float = DEFAULTS.dread_volume
var voice_volume: float = DEFAULTS.voice_volume
var mute_unfocused: bool = DEFAULTS.mute_unfocused
# Interface. breath_meter 0 always, 1 only while she is short of breath.
var show_prompts: bool = DEFAULTS.show_prompts
var show_journal_toast: bool = DEFAULTS.show_journal_toast
var breath_meter: int = DEFAULTS.breath_meter
# The ring at the screen centre; her spoken lines as text and their size; how
# strongly the dread vignette darkens the screen's edges.
var show_reticle: bool = DEFAULTS.show_reticle
var subtitles: bool = DEFAULTS.subtitles
var subtitle_size: int = DEFAULTS.subtitle_size
var screen_effects: float = DEFAULTS.screen_effects

# action -> the events it shipped with, for resetting the keys.
var _default_keys := {}
var _focused := true
var _save_timer: Timer


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.name = "SettingsSaveDebounce"
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.4
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	for bus in BUSES:
		_bus(bus, "Master")
	_build_mix()
	for pair in ACTIONS:
		_default_keys[pair[0]] = InputMap.action_get_events(pair[0]).duplicate()
	load_saved()
	apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		apply_audio()
		if not _focused:
			save()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


# Sets one value, applies it, and queues a machine-local save. Slider movement
# is debounced so dragging a control does not write the config on every tick.
func change(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	set(key, value)
	apply()
	_queue_save()


func reset(keys: Array) -> void:
	for key in keys:
		if DEFAULTS.has(key):
			set(key, DEFAULTS[key])
	apply()
	save()


func apply() -> void:
	_apply_display()
	apply_audio()
	changed.emit()


func load_saved() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for key in DEFAULTS:
		if file.has_section_key("settings", key):
			var value: Variant = file.get_value("settings", key)
			if typeof(value) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and value is int):
				set(key, value)
	for pair in ACTIONS:
		var action: String = pair[0]
		if not file.has_section_key("keys", action):
			continue
		var events: Array[InputEvent] = []
		for code in file.get_value("keys", action, []):
			var event := _decode(str(code))
			if event:
				events.append(event)
		_set_events(action, events)


func save() -> void:
	if _save_timer and not _save_timer.is_stopped():
		_save_timer.stop()
	var file := ConfigFile.new()
	for key in DEFAULTS:
		file.set_value("settings", key, get(key))
	for pair in ACTIONS:
		var codes: Array[String] = []
		for event in InputMap.action_get_events(pair[0]):
			var code := _encode(event)
			if code != "":
				codes.append(code)
		file.set_value("keys", pair[0], codes)
	var error := file.save(PATH)
	if error != OK:
		push_warning("Could not save machine-local settings (%s): %s" % [PATH, error_string(error)])


func _queue_save() -> void:
	if _save_timer:
		_save_timer.start()
	else:
		save()


# --- Keys ---------------------------------------------------------------

func events_of(action: String) -> Array[InputEvent]:
	var found: Array[InputEvent] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				found.append(event)
	return found


# Puts an event in one slot of an action. Whatever else held that key gives
# it up, so one key never does two things. Returns that other action's name.
func bind(action: String, slot: int, event: InputEvent) -> String:
	var taken := ""
	for pair in ACTIONS:
		var other: String = pair[0]
		if other == action:
			continue
		for held in events_of(other):
			if _same(held, event):
				InputMap.action_erase_event(other, held)
				taken = pair[1]
	var events := events_of(action)
	for held in events.duplicate():
		if _same(held, event):
			events.erase(held)
	if slot < events.size():
		events[slot] = event
	else:
		events.append(event)
	_set_events(action, events)
	save()
	changed.emit()
	return taken


func unbind(action: String, slot: int) -> void:
	var events := events_of(action)
	if slot < events.size():
		events.remove_at(slot)
	_set_events(action, events)
	save()
	changed.emit()


func reset_keys() -> void:
	for pair in ACTIONS:
		var events: Array[InputEvent] = []
		for event in _default_keys.get(pair[0], []):
			if event is InputEventKey or event is InputEventMouseButton:
				events.append(event)
		_set_events(pair[0], events)
	save()
	changed.emit()


# What to print on a keycap for this action: its first key or button.
func key_label(action: String) -> String:
	var events := events_of(action)
	return event_label(events[0]) if not events.is_empty() else "-"


static func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		# The key at that position on her own layout: Z on a German Y.
		var local := code
		if key.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			local = DisplayServer.keyboard_get_keycode_from_physical(code)
		var text := OS.get_keycode_string(local)
		return text if text != "" else OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel down"
			MOUSE_BUTTON_XBUTTON1:
				return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2:
				return "Mouse 5"
		return "Mouse %d" % (event as InputEventMouseButton).button_index
	return "?"


# Keys and mouse buttons are rebindable; the pad's buttons and sticks stay.
func _set_events(action: String, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var pad: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			pad.append(event)
	InputMap.action_erase_events(action)
	for i in mini(events.size(), SLOTS):
		InputMap.action_add_event(action, events[i])
	for event in pad:
		InputMap.action_add_event(action, event)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return _encode(a) != "" and _encode(a) == _encode(b)


static func _encode(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		return "key:%d" % (key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


static func _decode(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	if parts[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = parts[1].to_int() as Key
		return key
	if parts[0] == "mouse":
		var button := InputEventMouseButton.new()
		button.button_index = parts[1].to_int() as MouseButton
		return button
	return null


# --- Display and sound --------------------------------------------------

func _bus(bus: String, send: String) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, send)
	return index


# The fixed parts of the mix. The rooms' reverbs feed the Effects level they
# come from; the storm's bus gets the low-pass the walls close down (Weather
# drives it); nothing that stacks up (a gust under a hard knock) may clip.
func _build_mix() -> void:
	_bus("Voice", "Effects")
	var room := AudioEffectReverb.new()
	room.predelay_msec = 8.0
	room.room_size = 0.28
	room.damping = 0.72
	room.spread = 0.8
	room.hipass = 0.08
	room.dry = 0.0
	room.wet = 0.55
	var cellar := AudioEffectReverb.new()
	cellar.predelay_msec = 18.0
	cellar.room_size = 0.58
	cellar.damping = 0.32
	cellar.spread = 0.9
	cellar.hipass = 0.12
	cellar.dry = 0.0
	cellar.wet = 0.65
	for pair in [["Room", room], ["Cellar", cellar]]:
		var index := _bus(pair[0], "Effects")
		if AudioServer.get_bus_effect_count(index) == 0:
			AudioServer.add_bus_effect(index, pair[1])
	# Everything heard from outside the walls (storm, trees, birds) rides on
	# Outside, under the Ambience level; the window whistle does not.
	var outside := _bus("Outside", "Ambience")
	if AudioServer.get_bus_effect_count(outside) == 0:
		var walls := AudioEffectLowPassFilter.new()
		walls.cutoff_hz = 650.0
		walls.resonance = 0.5
		AudioServer.add_bus_effect(outside, walls)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, limiter)


## The Outside bus's low-pass: 20 kHz in the open, a few hundred Hz behind walls.
func set_walls(cutoff_hz: float) -> void:
	var outside := AudioServer.get_bus_index("Outside")
	if outside < 0 or AudioServer.get_bus_effect_count(outside) == 0:
		return
	var walls := AudioServer.get_bus_effect(outside, 0) as AudioEffectLowPassFilter
	if walls:
		walls.cutoff_hz = cutoff_hz

func _apply_display() -> void:
	Engine.max_fps = max_fps
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if display_mode == 1:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	elif display_mode == 2:
		mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	var sync := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != sync:
		DisplayServer.window_set_vsync_mode(sync)
	var viewport := get_viewport()
	if viewport:
		viewport.scaling_3d_scale = render_scale
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
		viewport.use_taa = anti_aliasing == 3
		match anti_aliasing:
			1:
				viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			2:
				viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
			_:
				viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		var window := viewport as Window
		if window:
			window.content_scale_factor = ui_scale


func apply_audio() -> void:
	var fade := smoothstep(0.0, 1.0, Game.audio_fade) if Game and Game.phase not in [Game.Phase.PAUSED, Game.Phase.BOOT] else 1.0
	var levels := {"Master": master_volume * fade, "Ambience": ambience_volume, "Effects": effects_volume, "Dread": dread_volume, "Voice": voice_volume}
	for bus in levels:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var level: float = levels[bus]
		if Game.phase == Game.Phase.BOOT and bus != "Master":
			level = 0.0
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
		AudioServer.set_bus_mute(index, level <= 0.001 or (bus == "Master" and mute_unfocused and not _focused))
