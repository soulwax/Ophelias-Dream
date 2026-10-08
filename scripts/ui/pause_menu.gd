class_name PauseMenu
extends Control

signal title_closed

# The Esc menu, drawn as an old instrument console: page list on the left,
# the page's fields on the right, and a readout underneath that explains
# whatever the cursor is on. Values apply the moment they change and are saved
# when the menu closes.
#
# Mouse, keyboard and pad all drive it: arrows or the d-pad move the cursor,
# left and right adjust, Q/E or the bumpers turn the page, Backspace or pad Y
# puts the field under the cursor back to its default. A key is rebound by
# choosing a slot and pressing the new key or mouse button; Esc cancels and
# Backspace clears it. Restart and quit ask for a second press.

const PAGES := ["Controls", "Keys", "Camera", "Display", "Audio", "Interface"]
const SUBTITLES := {
	"Controls": "STEUERUNG",
	"Keys": "TASTENBELEGUNG",
	"Camera": "KAMERA",
	"Display": "ANZEIGE",
	"Audio": "TON",
	"Interface": "OBERFLÄCHE",
}
const NOTES := {
	"Controls": "How she answers the mouse, the stick and the keys.",
	"Keys": "Two slots per action. A key does one thing; taking it moves it here.",
	"Camera": "Where the camera sits and how much it moves with her.",
	"Display": "Window, frame pacing and image.",
	"Audio": "Levels for each part of the sound.",
	"Interface": "What the screen shows while you play, and how large.",
}
# What each page's reset puts back.
const PAGE_KEYS := {
	"Controls": ["mouse_sensitivity", "stick_sensitivity", "invert_y", "invert_x", "sprint_toggle", "rumble"],
	"Keys": [],
	"Camera": ["fov", "camera_distance", "camera_shake", "speed_fov"],
	"Display": ["display_mode", "vsync", "max_fps", "render_scale", "anti_aliasing", "brightness", "graphics"],
	"Audio": ["master_volume", "ambience_volume", "effects_volume", "voice_volume", "dread_volume", "mute_unfocused"],
	"Interface": ["show_prompts", "show_reticle", "show_journal_toast", "breath_meter", "subtitles", "subtitle_size", "ui_scale", "screen_effects"],
}
const LABEL_WIDTH := 280
const FRAME_MAX := Vector2(1220.0, 760.0)
const ARM_SECONDS := 3.0

var _page := "Controls"
var _tabs := {}
var _frame: Control
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _index: Label
var _heading: Label
var _subheading: Label
var _note: Label
var _info_title: Label
var _info_body: Label
var _info_default: Label
var _status: Label
var _hint: Label
var _clock: Label
var _cursor: Label
var _crt: ColorRect
var _scrim: ColorRect
var _content_stack: Control
var _mode_label: Label
var _subject_label: Label
var _session_heading: Label
var _resume_action: Button
var _lookout_action: Button
var _title_hidden: Array[Control] = []
var _open_tween: Tween
var _title_mode := false
var _title_dirty := false
# The binding being listened for, [action, slot], or empty.
var _capture: Array = []
# The open page's fields by id: {key, focus, panel, mark, caption, note, default}.
var _fields := {}
var _active := ""
# A sidebar action waiting for its second press.
var _armed: Button


func _ready() -> void:
	# Anchors and offsets together: in the tree already, anchors alone keep
	# the empty rect it starts with.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiChrome.term_theme()
	visible = false
	_build()
	resized.connect(_fit)
	Game.phase_changed.connect(_on_phase)
	Game.settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


func _on_phase(next: Game.Phase) -> void:
	if _title_mode:
		if next != Game.Phase.BOOT:
			_finish_title_close(false)
		return
	var open := next == Game.Phase.PAUSED
	if open and not visible:
		_capture = []
		_status.text = ""
		_disarm()
		_show_page(_page)
		_play_open()
		_focus_tab.call_deferred()
		_scrim.color = Color(0.02, 0.012, 0.015, 0.74)
		_content_stack.modulate.a = 1.0
		_session_heading.text = "SESSION"
		_resume_action.text = str(_resume_action.get_meta("text", "▸  RESUME"))
		_restore_session_controls()
	visible = open


# Deferred, so a page opened in the same frame (RUN_MENU) is the one focused.
func _focus_tab() -> void:
	(_tabs[_page] as Button).grab_focus()


func _process(_delta: float) -> void:
	if not visible:
		return
	_clock.text = Time.get_time_string_from_system()
	_cursor.visible = fmod(Time.get_ticks_msec() / 530.0, 2.0) < 1.0


func _on_settings_changed() -> void:
	if _crt and _crt.material is ShaderMaterial:
		(_crt.material as ShaderMaterial).set_shader_parameter("strength",
			minf(Game.settings.screen_effects, 0.22) if _title_mode else Game.settings.screen_effects)
	if _title_mode:
		_title_dirty = true


func open_title_settings() -> void:
	_title_mode = true
	_title_dirty = false
	_capture = []
	_status.text = ""
	_disarm()
	_show_page(_page)
	_mode_label.text = "// TITLE CONFIGURATION · STORY NOT STARTED"
	_subject_label.text = "MODE  UNSELECTED"
	_session_heading.text = "MENU"
	_resume_action.text = "▸  RETURN TO TITLE"
	for control in _title_hidden:
		control.visible = false
	_scrim.color = Color(0.02, 0.012, 0.015, 0.0)
	_content_stack.modulate.a = 0.0
	_frame.scale = Vector2(1.0, 0.015)
	_frame.modulate.a = 1.0
	visible = true
	_play_title_open()
	_focus_tab.call_deferred()


func is_title_settings_open() -> bool:
	return _title_mode and visible


func close_title_settings() -> void:
	if not _title_mode or not visible:
		return
	_capture = []
	_disarm()
	if _title_dirty:
		Game.settings.save()
	if _open_tween and _open_tween.is_running():
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(_content_stack, "modulate:a", 0.0, 0.11)
	_open_tween.tween_property(_frame, "scale:y", 0.015, 0.27).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_open_tween.tween_property(_scrim, "color", Color(0.02, 0.012, 0.015, 0.0), 0.24)
	if _crt.material is ShaderMaterial:
		_open_tween.tween_property(_crt.material, "shader_parameter/strength", 0.0, 0.12)
	_open_tween.chain().tween_callback(_finish_title_close)


func _finish_title_close(save_changes := false) -> void:
	if save_changes and _title_dirty:
		Game.settings.save()
	_title_mode = false
	_title_dirty = false
	visible = false
	_frame.scale = Vector2.ONE
	_content_stack.modulate.a = 1.0
	_scrim.color = Color(0.02, 0.012, 0.015, 0.74)
	_mode_label.text = "// PAUSIERT · NOTHING MOVES"
	_subject_label.text = "SUBJECT  %s" % ("MATHILDA" if Game.mathilda_pov else "OPHELIA")
	_session_heading.text = "SESSION"
	_resume_action.text = str(_resume_action.get_meta("text", "▸  RESUME"))
	_restore_session_controls()
	title_closed.emit()


func _restore_session_controls() -> void:
	for control in _title_hidden:
		control.visible = true
	if _lookout_action:
		_lookout_action.visible = not Game.checkpoint.is_empty()


func _resume_action_pressed() -> void:
	if _title_mode:
		close_title_settings()
	else:
		Game.toggle_pause()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Listening for a new binding comes before anything else sees the input,
	# so the key pressed is never also acted on.
	if not _capture.is_empty():
		_listen(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode:
			KEY_Q:
				_turn_page(-1)
			KEY_E:
				_turn_page(1)
			KEY_BACKSPACE, KEY_DELETE:
				_reset_active()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_turn_page(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_turn_page(1)
			JOY_BUTTON_Y:
				_reset_active()
			JOY_BUTTON_B:
				if event.is_action("pause"):
					return
				Game.toggle_pause()
			_:
				return
		get_viewport().set_input_as_handled()


func _listen(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_ESCAPE:
			_end_capture("Cancelled.")
		elif code == KEY_BACKSPACE or code == KEY_DELETE:
			Game.settings.unbind(_capture[0], _capture[1])
			_end_capture("Cleared.")
		else:
			var bound := InputEventKey.new()
			bound.physical_keycode = code
			_finish_capture(bound)
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		var bound := InputEventMouseButton.new()
		bound.button_index = (event as InputEventMouseButton).button_index
		_finish_capture(bound)
	elif event is InputEventJoypadButton and event.pressed:
		# The pad's buttons are fixed; any of them backs out.
		get_viewport().set_input_as_handled()
		_end_capture("Cancelled. Pad buttons are fixed.")


func _begin_capture(action: String, slot: int) -> void:
	_capture = [action, slot]
	_status.text = "Awaiting input. Esc cancels, Backspace clears."
	_show_page(_page, "bind:%s:%d" % [action, slot])


func _finish_capture(event: InputEvent) -> void:
	var at := "bind:%s:%d" % _capture
	var taken: String = Game.settings.bind(_capture[0], _capture[1], event)
	_capture = []
	_status.text = "Taken from %s." % taken if taken != "" else "Bound."
	_show_page(_page, at)


func _end_capture(message: String) -> void:
	var at := "bind:%s:%d" % _capture
	_capture = []
	_status.text = message
	_show_page(_page, at)


# --- Pages --------------------------------------------------------------

func open_page(page: String) -> void:
	for each in PAGES:
		if (each as String).to_lower() == page.to_lower():
			_show_page(each)


func _turn_page(step: int) -> void:
	_capture = []
	var next: String = PAGES[wrapi(PAGES.find(_page) + step, 0, PAGES.size())]
	_status.text = ""
	_show_page(next)
	(_tabs[next] as Button).grab_focus()


# keep_focus: the id of a field to put the cursor back on after the rebuild.
func _show_page(page: String, keep_focus := "") -> void:
	var turned := page != _page
	_page = page
	for each in _tabs:
		(_tabs[each] as Button).set_pressed_no_signal(each == page)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_fields.clear()
	_active = ""
	_index.text = "%02d" % (PAGES.find(page) + 1)
	_heading.text = page.to_upper()
	_subheading.text = "// %s" % SUBTITLES[page]
	_note.text = NOTES[page]
	match page:
		"Controls":
			_controls_page()
		"Keys":
			_keys_page()
		"Camera":
			_camera_page()
		"Display":
			_display_page()
		"Audio":
			_audio_page()
		"Interface":
			_interface_page()
	_refresh_marks()
	_hint.text = "[↑↓] SELECT   [←→] ADJUST   [Q/E] PAGE   [BKSP] DEFAULT   [%s] RESTART   [ESC] RESUME" % Game.settings.key_label("restart").to_upper()
	_show_info("", "", "")
	if keep_focus != "":
		_refocus.call_deferred(keep_focus)
	if turned:
		_scroll.scroll_vertical = 0
		_heading.visible_ratio = 0.0
		create_tween().tween_property(_heading, "visible_ratio", 1.0, 0.22)


func _refocus(id: String) -> void:
	for child in _rows.find_children("*", "Control", true, false):
		if child.has_meta("id") and child.get_meta("id") == id:
			(child as Control).grab_focus()
			return


func _reset_page() -> void:
	_capture = []
	Game.settings.reset(PAGE_KEYS[_page])
	if _page == "Keys":
		Game.settings.reset_keys()
	_status.text = "%s restored to defaults." % _page
	_show_page(_page)


# Backspace on a field: that one setting back to its default, or on a key
# slot, that slot cleared.
func _reset_active() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused and focused.has_meta("bind"):
		var slot: Array = focused.get_meta("bind")
		Game.settings.unbind(slot[0], slot[1])
		_status.text = "Cleared."
		_show_page(_page, focused.get_meta("id"))
		return
	if not _fields.has(_active):
		return
	var field: Dictionary = _fields[_active]
	if field.key == "":
		return
	Game.settings.change(field.key, Settings.DEFAULTS[field.key])
	_status.text = "%s restored." % (field.caption as String).capitalize()
	_show_page(_page, _active)


func _controls_page() -> void:
	_section("Look")
	_slider("Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.05, _times, "How far the camera turns per inch of mouse travel. The window size never changes it.")
	_slider("Stick sensitivity", "stick_sensitivity", 0.3, 2.5, 0.05, _times, "Gamepad: the right stick looks. Held all the way, it turns faster after a moment.")
	_flag("Invert vertical look", "invert_y", "Pushing the mouse or stick forward looks down instead of up.")
	_flag("Invert horizontal look", "invert_x", "Mouse and stick turn the camera the other way round.")
	_section("Movement")
	_choice("Sprint", "sprint_toggle", ["Hold the key", "Tap to toggle"], [false, true], "Toggle keeps her running until she stops, runs out of breath, or you tap again.")
	_flag("Gamepad rumble", "rumble", "Landings, stumbling, and the door.")


func _keys_page() -> void:
	_section("Keyboard and mouse")
	_fixed("Look around", "Mouse")
	for pair in Settings.ACTIONS:
		_binding(pair[0], pair[1])
	_fixed("This menu", "Esc")
	_section("Gamepad (fixed)")
	_fixed("Move / look", "L stick / R stick")
	_fixed("Sprint / jump / slide", "LT / A / B")
	_fixed("Read or open", "X")
	_fixed("Walk slowly / glance back", "LB / R3")
	_fixed("Journal / this menu", "Y / Start")


func _camera_page() -> void:
	_section("Lens")
	_slider("Field of view", "fov", 55.0, 95.0, 1.0, func(v: float) -> String: return "%d°" % int(v), "The horizontal angle the camera sees, before any widening at speed.")
	_flag("Widen the view at speed", "speed_fov", "Sprinting, sliding and leaping open the lens a few degrees.")
	_section("Rig")
	_slider("Camera distance", "camera_distance", 0.7, 1.4, 0.05, _percent, "How far behind her the camera sits outdoors. Indoors it always comes in over her shoulder.")
	_slider("Camera shake", "camera_shake", 0.0, 1.0, 0.05, _percent, "Footfalls, landings and gusts. Turn it down if motion bothers you.")


func _display_page() -> void:
	_section("Window")
	_choice("Window mode", "display_mode", ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"], [0, 1, 2], "Exclusive fullscreen can lower latency; borderless switches windows faster.")
	_flag("V-Sync", "vsync", "Holds frames to the display's refresh, so the image never tears.")
	var caps: Array[String] = []
	for cap in Settings.FRAME_CAPS:
		caps.append("Unlimited" if cap == 0 else "%d fps" % cap)
	_choice("Frame rate limit", "max_fps", caps, Settings.FRAME_CAPS, "Movement is interpolated, so it stays smooth at any rate.")
	_section("Image")
	_slider("Render scale", "render_scale", 0.5, 1.0, 0.05, _percent, "Below 100% the world renders at fewer pixels and FSR scales it up. The interface stays sharp.")
	_choice("Anti-aliasing", "anti_aliasing", ["Off", "FXAA", "SMAA", "TAA"], [0, 1, 2, 3], "Smooths jagged edges. FXAA is cheapest; SMAA is sharper; TAA is smoothest but softens and can ghost in falling snow.")
	_slider("Brightness", "brightness", 0.7, 1.4, 0.02, _percent, "Raise it until the cellar's darkest corners just show.")
	var now := "%s on %s" % ["lean" if Game.lean_graphics else "full", RenderingServer.get_video_adapter_name()]
	_choice("Graphics detail", "graphics", ["Automatic", "Lean", "Full"], [0, 1, 2], "Lean drops volumetric fog and half the snow for integrated GPUs. Applies when the run restarts. Now running %s." % now)


func _audio_page() -> void:
	_section("Levels")
	_slider("Master", "master_volume", 0.0, 1.0, 0.01, _percent, "Everything, after the levels below.")
	_slider("Storm and wind", "ambience_volume", 0.0, 1.0, 0.01, _percent, "The storm, the trees and the birds.")
	_slider("Steps, doors and the house", "effects_volume", 0.0, 1.0, 0.01, _percent, "Everything she touches. Voices ride under this level too.")
	_slider("Voices", "voice_volume", 0.0, 1.0, 0.01, _percent, "Her lines and anyone she meets.")
	_slider("Heartbeat and dread", "dread_volume", 0.0, 1.0, 0.01, _percent, "Her heart, the low drone and the stings when something is wrong.")
	_section("Behaviour")
	_flag("Mute in the background", "mute_unfocused", "Silent while another window has focus.")


func _interface_page() -> void:
	_section("In play")
	_flag("Interaction prompts", "show_prompts", "The key hint when a note, door or switch is in reach.")
	_flag("Reticle", "show_reticle", "The ring at the centre when something can be read or opened.")
	_flag("Journal notice", "show_journal_toast", "A note when a page goes into the journal.")
	_choice("Breath meter", "breath_meter", ["Always", "Only when short of breath"], [0, 1], "The bar under the prompt that empties as she runs.")
	_section("Text")
	_flag("Subtitles", "subtitles", "Spoken lines as text. Conversations always show theirs.")
	_choice("Subtitle size", "subtitle_size", ["Small", "Medium", "Large"], [0, 1, 2], "The size of her spoken lines at the bottom of the screen.")
	_choice("Interface scale", "ui_scale", ["80%", "90%", "100%", "110%", "120%", "130%"], [0.8, 0.9, 1.0, 1.1, 1.2, 1.3], "Every menu, page and hint, not the world.")
	_section("Comfort")
	_slider("Screen effects", "screen_effects", 0.0, 1.0, 0.05, _percent, "The dread vignette at the edges of the screen, and this console's scanlines and grain.")


# --- Fields -------------------------------------------------------------

# One line of a page: the caption (with a mark while it differs from its
# default) and its control. focus is what the cursor lands on.
func _row(id: String, caption: String, control: Control, focus: Control, note := "", key := "", default_text := "") -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style(false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var head := HBoxContainer.new()
	head.custom_minimum_size.x = LABEL_WIDTH
	head.add_theme_constant_override("separation", 8)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UiChrome.term_label(caption.to_upper(), 14))
	var mark := UiChrome.term_label("◆", 10, UiChrome.SIGNAL)
	mark.visible = false
	mark.tooltip_text = "Changed from the default"
	head.add_child(mark)
	row.add_child(head)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	_rows.add_child(panel)
	if not focus.has_meta("id"):
		focus.set_meta("id", id)
	_fields[id] = {"key": key, "focus": focus, "panel": panel, "mark": mark, "caption": caption, "note": note, "default": default_text}
	_follow(focus, id)
	panel.mouse_entered.connect(func() -> void:
		if focus.focus_mode != Control.FOCUS_NONE and _capture.is_empty():
			focus.grab_focus()
		else:
			_activate(id)
	)


# The cursor follows the mouse, so there is only ever one lit field.
func _follow(focus: Control, id: String) -> void:
	focus.focus_entered.connect(func() -> void: _activate(id))
	focus.mouse_entered.connect(func() -> void:
		if focus.focus_mode != Control.FOCUS_NONE and _capture.is_empty():
			focus.grab_focus()
	)


func _activate(id: String) -> void:
	if _fields.has(_active):
		(_fields[_active].panel as PanelContainer).add_theme_stylebox_override("panel", _row_style(false))
	_active = id
	if not _fields.has(id):
		return
	var field: Dictionary = _fields[id]
	(field.panel as PanelContainer).add_theme_stylebox_override("panel", _row_style(true))
	_show_info(field.caption, field.note, field.default)


func _show_info(caption: String, note: String, default_text: String) -> void:
	_info_title.text = "▶ %s" % caption.to_upper() if caption != "" else "▶ %s" % _page.to_upper()
	_info_body.text = note if note != "" else (NOTES[_page] if caption == "" else "Left and right change it.")
	_info_default.text = "DEFAULT  %s" % default_text.to_upper() if default_text != "" else ""


func _refresh_marks() -> void:
	for id in _fields:
		var field: Dictionary = _fields[id]
		if field.key == "":
			continue
		var now: Variant = Game.settings.get(field.key)
		var base: Variant = Settings.DEFAULTS[field.key]
		var same: bool = is_equal_approx(float(now), float(base)) if base is float else now == base
		(field.mark as Label).visible = not same


func _row_style(lit: bool) -> StyleBoxFlat:
	var style := UiChrome.term_box(Color(UiChrome.SIGNAL, 0.08) if lit else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 5)
	style.border_color = UiChrome.SIGNAL if lit else Color(UiChrome.BONE, 0.06)
	style.border_width_left = 3 if lit else 1
	return style


func _section(title: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _rows.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(gap)
	box.add_child(UiChrome.term_label("■", 10, UiChrome.SIGNAL))
	box.add_child(UiChrome.term_label(title.to_upper(), 12, UiChrome.ASH, true))
	var rule := ColorRect.new()
	rule.color = Color(UiChrome.BONE, 0.1)
	rule.custom_minimum_size.y = 1
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	_rows.add_child(box)


# A number setting; shown says how its value reads beside the slider.
func _slider(caption: String, key: String, low: float, high: float, step: float, shown: Callable, note := "") -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	# Arrows move a twentieth of the range, however fine the drag is.
	var coarse := maxf(snappedf((high - low) / 20.0, step), step)
	slider.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left", true):
			slider.value -= coarse
			slider.accept_event()
		elif event.is_action_pressed("ui_right", true):
			slider.value += coarse
			slider.accept_event()
	)
	slider.scrollable = false
	slider.focus_mode = Control.FOCUS_ALL
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var readout := UiChrome.term_label("", 14, UiChrome.BONE)
	readout.custom_minimum_size.x = 72
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var value := float(Game.settings.get(key))
	slider.set_value_no_signal(value)
	readout.text = shown.call(value)
	var whole: bool = Settings.DEFAULTS[key] is int
	slider.value_changed.connect(func(next: float) -> void:
		readout.text = shown.call(next)
		Game.settings.change(key, int(next) if whole else next)
		_refresh_marks()
	)
	box.add_child(slider)
	box.add_child(readout)
	_row(key, caption, box, slider, note, key, shown.call(float(Settings.DEFAULTS[key])))


func _flag(caption: String, key: String, note := "") -> void:
	_choice(caption, key, ["Off", "On"], [false, true], note)


# A value stepped through in place: click either end, press left or right,
# or Enter for the next one.
func _choice(caption: String, key: String, options: Array, values: Array, note := "") -> void:
	var field := Button.new()
	field.theme_type_variation = "TermField"
	field.focus_mode = Control.FOCUS_ALL
	field.custom_minimum_size = Vector2(300, 32)
	field.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	field.set_meta("at", maxi(values.find(Game.settings.get(key)), 0))
	field.text = _cycle_text(options[field.get_meta("at")])
	var step := func(by: int) -> void:
		var at := wrapi(int(field.get_meta("at")) + by, 0, values.size())
		field.set_meta("at", at)
		field.text = _cycle_text(options[at])
		Game.settings.change(key, values[at])
		_refresh_marks()
	field.pressed.connect(func() -> void: step.call(1))
	field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			step.call(-1 if field.get_local_mouse_position().x < field.size.x * 0.3 else 1)
			field.accept_event()
		elif event.is_action_pressed("ui_left", true):
			step.call(-1)
			field.accept_event()
		elif event.is_action_pressed("ui_right", true):
			step.call(1)
			field.accept_event()
	)
	var holder := HBoxContainer.new()
	holder.add_child(field)
	_row(key, caption, holder, field, note, key, str(options[maxi(values.find(Settings.DEFAULTS[key]), 0)]))


func _cycle_text(option: Variant) -> String:
	return "◂   %s   ▸" % str(option).to_upper()


func _binding(action: String, caption: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var events: Array[InputEvent] = Game.settings.events_of(action)
	var first: Button = null
	for slot in Settings.SLOTS:
		var cap := Button.new()
		cap.theme_type_variation = "TermField"
		cap.focus_mode = Control.FOCUS_ALL
		cap.custom_minimum_size = Vector2(150, 32)
		cap.text = Settings.event_label(events[slot]).to_upper() if slot < events.size() else "—"
		cap.set_meta("id", "bind:%s:%d" % [action, slot])
		cap.set_meta("bind", [action, slot])
		if not _capture.is_empty() and _capture[0] == action and _capture[1] == slot:
			cap.text = "[ PRESS A KEY ]"
			cap.add_theme_color_override("font_color", UiChrome.SIGNAL)
			cap.add_theme_color_override("font_focus_color", UiChrome.SIGNAL)
		cap.pressed.connect(func() -> void: _begin_capture(action, slot))
		box.add_child(cap)
		if first == null:
			first = cap
		else:
			_follow(cap, action)
	_row(action, caption, box, first, "Enter or click a slot, then press the new key or mouse button. Backspace clears a slot.")


func _fixed(caption: String, keys: String) -> void:
	var cap := Button.new()
	cap.theme_type_variation = "TermField"
	cap.text = keys.to_upper()
	cap.disabled = true
	cap.focus_mode = Control.FOCUS_NONE
	cap.custom_minimum_size = Vector2(150, 32)
	var holder := HBoxContainer.new()
	holder.add_child(cap)
	_row("fixed:%s" % caption, caption, holder, cap, "Fixed: this one cannot be rebound.")


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _times(value: float) -> String:
	return "%.2fx" % value


# --- Frame --------------------------------------------------------------

func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(0.02, 0.012, 0.015, 0.74)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var face := Panel.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.add_theme_stylebox_override("panel", UiChrome.term_box(UiChrome.VOID, Color(UiChrome.SIGNAL, 0.45), 1, 0))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(face)
	var brackets := Control.new()
	brackets.set_anchors_preset(Control.PRESET_FULL_RECT)
	brackets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brackets.draw.connect(func() -> void: _draw_brackets(brackets))
	brackets.resized.connect(brackets.queue_redraw)
	_frame.add_child(brackets)
	var stack := VBoxContainer.new()
	_content_stack = stack
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	_frame.add_child(stack)
	stack.add_child(_build_header())
	stack.add_child(_hairline(false))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 0)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(split)
	split.add_child(_build_sidebar())
	split.add_child(_hairline(true))
	split.add_child(_build_body())
	stack.add_child(_hairline(false))
	stack.add_child(_build_readout())
	stack.add_child(_build_footer())
	# The glass goes over everything, the frame and the world behind it.
	_crt = ColorRect.new()
	_crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/menu_crt.gdshader") as Shader
	_crt.material = glass
	add_child(_crt)
	_fit()


func _fit() -> void:
	if _frame == null:
		return
	_frame.size = Vector2(minf(FRAME_MAX.x, size.x - 48.0), minf(FRAME_MAX.y, size.y - 40.0)).floor()
	_frame.position = ((size - _frame.size) * 0.5).floor()
	_frame.pivot_offset = _frame.size * 0.5


func _play_open() -> void:
	if _open_tween and _open_tween.is_running():
		_open_tween.kill()
	_frame.scale = Vector2(1.0, 0.94)
	_frame.modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.tween_property(_frame, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_open_tween.parallel().tween_property(_frame, "modulate:a", 1.0, 0.05)
	# The tube catches: a dip, then steady.
	_open_tween.tween_property(_frame, "modulate:a", 0.45, 0.03)
	_open_tween.tween_property(_frame, "modulate:a", 1.0, 0.07)


func _play_title_open() -> void:
	if _open_tween and _open_tween.is_running():
		_open_tween.kill()
	_frame.scale = Vector2(1.0, 0.015)
	_frame.modulate.a = 1.0
	_content_stack.modulate.a = 0.0
	var glass := _crt.material as ShaderMaterial
	glass.set_shader_parameter("strength", 0.0)
	_open_tween = create_tween()
	_open_tween.tween_property(_scrim, "color", Color(0.02, 0.012, 0.015, 0.34), 0.12)
	_open_tween.tween_property(_frame, "scale:y", 1.02, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_open_tween.parallel().tween_property(_crt.material, "shader_parameter/strength", 0.22, 0.25)
	_open_tween.tween_interval(0.055)
	_open_tween.tween_property(_content_stack, "modulate:a", 1.0, 0.14)
	_open_tween.parallel().tween_property(_frame, "scale:y", 1.0, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.parallel().tween_property(_crt.material, "shader_parameter/strength", 0.10, 0.12)


func _build_header() -> Control:
	var margin := _margin(10, 18)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	margin.add_child(bar)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiChrome.term_box(UiChrome.SIGNAL, Color(0, 0, 0, 0), 0, 3))
	badge.add_child(UiChrome.term_label("OD-7", 14, UiChrome.SOOT, true))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(badge)
	var title := UiChrome.term_label("SYSTEM CONFIGURATION", 20, UiChrome.BONE, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(title)
	_mode_label = UiChrome.term_label("// PAUSIERT · NOTHING MOVES", 12, UiChrome.ASH)
	_mode_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_mode_label)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(fill)
	_subject_label = UiChrome.term_label("SUBJECT  %s" % ("MATHILDA" if Game.mathilda_pov else "OPHELIA"), 12, UiChrome.ASH)
	_subject_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_subject_label)
	_clock = UiChrome.term_label("00:00:00", 14, UiChrome.BONE)
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_clock)
	_cursor = UiChrome.term_label("█", 14, UiChrome.SIGNAL)
	_cursor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_cursor)
	return margin


func _build_sidebar() -> Control:
	var margin := _margin(18, 16)
	margin.custom_minimum_size.x = 260
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	box.add_child(UiChrome.term_label("INDEX", 11, UiChrome.ASH, true))
	box.add_child(_gap(4))
	var group := ButtonGroup.new()
	for i in PAGES.size():
		var page: String = PAGES[i]
		var tab := Button.new()
		tab.theme_type_variation = "TermTab"
		tab.text = "%02d   %s" % [i + 1, page.to_upper()]
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size.y = 34
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_ALL
		tab.pressed.connect(func() -> void:
			_capture = []
			_status.text = ""
			_show_page(page)
		)
		# Moving the cursor down the index turns the pages with it.
		tab.focus_entered.connect(func() -> void:
			if page != _page:
				_capture = []
				_status.text = ""
				_show_page(page)
		)
		box.add_child(tab)
		_tabs[page] = tab
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	_session_heading = UiChrome.term_label("SESSION", 11, UiChrome.ASH, true)
	box.add_child(_session_heading)
	box.add_child(_gap(4))
	_resume_action = _action("Resume", _resume_action_pressed)
	box.add_child(_resume_action)
	# Once she has reached the lookout she can go back there with what she had.
	_lookout_action = _action("Back to the lookout", func() -> void: Game.restart(true), true)
	_lookout_action.visible = not Game.checkpoint.is_empty()
	Game.checkpoint_reached.connect(func() -> void: _lookout_action.visible = true)
	_title_hidden.append(_lookout_action)
	box.add_child(_lookout_action)
	var restart := _action("Restart the run", func() -> void: Game.restart(), true)
	_title_hidden.append(restart)
	box.add_child(restart)
	var quit := _action("Quit to desktop", func() -> void: Game.quit(), true)
	_title_hidden.append(quit)
	box.add_child(quit)
	var session_gap := _gap(10)
	_title_hidden.append(session_gap)
	box.add_child(session_gap)
	# The forest pack's author and page are still to be supplied (see its README).
	var credit := UiChrome.term_label("Her walk and jog: Bandai Namco Research Motion Dataset, Bandai Namco Research Inc., CC BY-NC 4.0, adapted. Green woods: \"Fir forest in the mountains\", Sketchfab, Standard licence, adapted.", 10, Color(UiChrome.ASH, 0.8))
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.custom_minimum_size.x = 220
	_title_hidden.append(credit)
	box.add_child(credit)
	return margin


# A sidebar action. With confirm, the first press arms it and only a second
# press within ARM_SECONDS goes through.
func _action(text: String, run: Callable, confirm := false) -> Button:
	var button := Button.new()
	button.theme_type_variation = "TermAction"
	button.text = "▸  %s" % text.to_upper()
	button.set_meta("text", button.text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 32
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func() -> void:
		if not confirm or _armed == button:
			_disarm()
			run.call()
			return
		_disarm()
		_armed = button
		button.text = "▸  CONFIRM: %s" % text.to_upper()
		button.add_theme_color_override("font_color", UiChrome.SIGNAL)
		button.add_theme_color_override("font_focus_color", UiChrome.SIGNAL)
		button.add_theme_color_override("font_hover_color", UiChrome.SIGNAL)
		_status.text = "Press again to %s." % text.to_lower()
		get_tree().create_timer(ARM_SECONDS, true).timeout.connect(func() -> void:
			if _armed == button:
				_disarm()
				_status.text = ""
		)
	)
	return button


func _disarm() -> void:
	if _armed == null:
		return
	_armed.text = _armed.get_meta("text")
	for color in ["font_color", "font_focus_color", "font_hover_color"]:
		_armed.remove_theme_color_override(color)
	_armed = null


func _build_body() -> Control:
	var margin := _margin(16, 26)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 14)
	box.add_child(title)
	_index = UiChrome.term_label("01", 40, UiChrome.SIGNAL, true)
	title.add_child(_index)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(names)
	_heading = UiChrome.term_label("", 26, UiChrome.BONE, true)
	names.add_child(_heading)
	_subheading = UiChrome.term_label("", 11, UiChrome.ASH)
	names.add_child(_subheading)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(fill)
	var reset := Button.new()
	reset.text = "RESTORE PAGE DEFAULTS"
	reset.focus_mode = Control.FOCUS_ALL
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.add_theme_font_size_override("font_size", 12)
	reset.pressed.connect(_reset_page)
	title.add_child(reset)
	_note = UiChrome.term_label("", 13, UiChrome.ASH)
	box.add_child(_note)
	var ruler := Control.new()
	ruler.custom_minimum_size.y = 10
	ruler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ruler.draw.connect(func() -> void: _draw_ruler(ruler))
	ruler.resized.connect(ruler.queue_redraw)
	box.add_child(ruler)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	box.add_child(_scroll)
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_top", 4)
	inset.add_theme_constant_override("margin_right", 14)
	inset.add_theme_constant_override("margin_bottom", 8)
	_scroll.add_child(inset)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(_rows)
	return margin


# What the cursor is on, what it does, and what it was by default.
func _build_readout() -> Control:
	var margin := _margin(10, 18)
	margin.custom_minimum_size.y = 74
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_info_title = UiChrome.term_label("", 13, UiChrome.SIGNAL, true)
	text.add_child(_info_title)
	_info_body = UiChrome.term_label("", 13, UiChrome.BONE)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_info_body)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	side.custom_minimum_size.x = 300
	row.add_child(side)
	_info_default = UiChrome.term_label("", 12, UiChrome.ASH)
	_info_default.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.add_child(_info_default)
	_status = UiChrome.term_label("", 12, UiChrome.SIGNAL)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_status)
	return margin


func _build_footer() -> Control:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiChrome.term_box(Color(UiChrome.SIGNAL, 0.12), Color(0, 0, 0, 0), 0, 5))
	var row := HBoxContainer.new()
	strip.add_child(row)
	_hint = UiChrome.term_label("", 11, UiChrome.BONE)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	row.add_child(_hint)
	row.add_child(UiChrome.term_label("v%s" % ProjectSettings.get_setting("application/config/version", "?"), 11, UiChrome.ASH))
	return strip


# Corner brackets just outside the frame and short ticks along its top edge.
func _draw_brackets(on: Control) -> void:
	var s := on.size
	var arm := 22.0
	var c := UiChrome.SIGNAL
	for corner: Vector2 in [Vector2(0, 0), Vector2(s.x, 0), Vector2(0, s.y), s]:
		var out := Vector2(-1.0 if corner.x == 0.0 else 1.0, -1.0 if corner.y == 0.0 else 1.0)
		var at := corner + out * 4.0
		on.draw_line(at, at - Vector2(out.x * arm, 0.0), c, 2.0)
		on.draw_line(at, at - Vector2(0.0, out.y * arm), c, 2.0)
	var x := s.x - 40.0
	while x > s.x - 200.0:
		on.draw_line(Vector2(x, -4.0), Vector2(x, -9.0), Color(c, 0.6), 1.0)
		x -= 8.0


# A measuring rule under the page title: a hairline with ticks.
func _draw_ruler(on: Control) -> void:
	var y := on.size.y - 1.0
	on.draw_line(Vector2(0, y), Vector2(on.size.x, y), Color(UiChrome.BONE, 0.18), 1.0)
	var x := 0.0
	var i := 0
	while x < on.size.x:
		var tall := 8.0 if i % 10 == 0 else 3.0
		on.draw_line(Vector2(x, y), Vector2(x, y - tall), Color(UiChrome.SIGNAL if i % 10 == 0 else UiChrome.BONE, 0.5 if i % 10 == 0 else 0.2), 1.0)
		x += 8.0
		i += 1


func _hairline(vertical: bool) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(UiChrome.SIGNAL, 0.35)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		line.custom_minimum_size.x = 1
	else:
		line.custom_minimum_size.y = 1
	return line


func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _margin(vertical: int, horizontal: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	return margin
