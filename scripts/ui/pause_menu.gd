class_name PauseMenu
extends Control

# The Esc menu: resume, restart or quit, and every setting, page by page.
# Values apply the moment they change and are saved when the menu closes.
# A key is rebound by clicking it and pressing the new key or mouse button;
# Esc cancels and Backspace clears the slot.

const PAGES := ["Controls", "Camera", "Display", "Audio", "Interface"]
const NOTES := {
	"Controls": "How she answers the mouse and the keys.",
	"Camera": "Where the camera sits and how much it moves with her.",
	"Display": "Window, frame pacing and image.",
	"Audio": "Levels for each part of the sound.",
	"Interface": "What the screen shows while you play.",
}
# What each page's reset button puts back.
const PAGE_KEYS := {
	"Controls": ["mouse_sensitivity", "stick_sensitivity", "invert_y", "sprint_toggle", "rumble"],
	"Camera": ["fov", "camera_distance", "camera_shake", "speed_fov"],
	"Display": ["display_mode", "vsync", "max_fps", "render_scale", "brightness", "graphics"],
	"Audio": ["master_volume", "ambience_volume", "effects_volume", "dread_volume", "mute_unfocused"],
	"Interface": ["show_prompts", "show_journal_toast", "breath_meter"],
}
const LABEL_WIDTH := 290

var _page := "Controls"
var _tabs := {}
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _heading: Label
var _note: Label
var _hint: Label
var _status: Label
# The binding being listened for, [action, slot], or empty.
var _capture: Array = []


func _ready() -> void:
	# Anchors and offsets together: in the tree already, anchors alone keep
	# the empty rect it starts with.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiChrome.menu_theme()
	visible = false
	_build()
	Game.phase_changed.connect(_on_phase)


func _on_phase(next: Game.Phase) -> void:
	var open := next == Game.Phase.PAUSED
	if open and not visible:
		_capture = []
		_status.text = ""
		_show_page(_page)
	visible = open


# Listening for a new binding comes before anything else sees the input,
# so the key pressed is never also acted on.
func _input(event: InputEvent) -> void:
	if not visible or _capture.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_ESCAPE:
			_end_capture("")
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


func _begin_capture(action: String, slot: int) -> void:
	_capture = [action, slot]
	_status.text = "Press a key or mouse button. Esc cancels, Backspace clears."
	_show_page(_page)


func _finish_capture(event: InputEvent) -> void:
	var taken: String = Game.settings.bind(_capture[0], _capture[1], event)
	_end_capture("Taken from %s." % taken if taken != "" else "")


func _end_capture(message: String) -> void:
	_capture = []
	_status.text = message
	_show_page(_page)


func _show_page(page: String) -> void:
	_page = page
	for name in _tabs:
		(_tabs[name] as Button).set_pressed_no_signal(name == page)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_heading.text = page
	_note.text = NOTES[page]
	match page:
		"Controls":
			_controls_page()
		"Camera":
			_camera_page()
		"Display":
			_display_page()
		"Audio":
			_audio_page()
		"Interface":
			_interface_page()
	_hint.text = "Esc resumes.   %s restarts." % Game.settings.key_label("restart")


func open_page(page: String) -> void:
	if PAGES.has(page):
		_show_page(page)


func _reset_page() -> void:
	_capture = []
	Game.settings.reset(PAGE_KEYS[_page])
	if _page == "Controls":
		Game.settings.reset_keys()
	_status.text = "%s set back to defaults." % _page
	_show_page(_page)


# --- Pages --------------------------------------------------------------

func _controls_page() -> void:
	_slider("Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.05, func(v: float) -> String: return "%.2fx" % v)
	_slider("Stick sensitivity", "stick_sensitivity", 0.3, 2.5, 0.05, func(v: float) -> String: return "%.2fx" % v, "Gamepad: the right stick looks. Held all the way, it turns faster after a moment.")
	_toggle("Invert vertical look", "invert_y")
	_choice("Sprint", "sprint_toggle", ["Hold the key", "Tap to toggle"], [false, true], "Toggle keeps her running until she stops, runs out of breath, or you tap again.")
	_toggle("Gamepad rumble", "rumble", "Landings, stumbling, and the door.")
	_section("Keys", "Click a key to change it. A key can only do one thing; taking it moves it here.")
	_fixed("Look around", "Mouse")
	for pair in Settings.ACTIONS:
		_binding(pair[0], pair[1])
	_fixed("This menu", "Esc")
	_section("Gamepad", "Left stick moves; pushed part-way she walks slowly. Right stick looks. LT sprint, RT hold breath, A jump, B slide, X read or open, LB walk slowly, R3 glance back, Start this menu.")


func _camera_page() -> void:
	_slider("Field of view", "fov", 55.0, 95.0, 1.0, func(v: float) -> String: return "%dÂ°" % int(v))
	_slider("Camera distance", "camera_distance", 0.7, 1.4, 0.05, _percent)
	_toggle("Widen the view at speed", "speed_fov", "Sprinting and sliding open the lens a few degrees.")
	_slider("Camera shake", "camera_shake", 0.0, 1.0, 0.05, _percent, "Footfalls, landings and gusts. Turn it down if motion bothers you.")


func _display_page() -> void:
	_choice("Window", "display_mode", ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"], [0, 1, 2])
	_toggle("V-Sync", "vsync", "Holds frames to the display's refresh, so the image never tears.")
	var caps: Array[String] = []
	for cap in Settings.FRAME_CAPS:
		caps.append("Unlimited" if cap == 0 else "%d fps" % cap)
	_choice("Frame rate limit", "max_fps", caps, Settings.FRAME_CAPS, "Movement is interpolated, so it stays smooth at any rate.")
	_slider("Render scale", "render_scale", 0.5, 1.0, 0.05, _percent, "Below 100% the world renders at fewer pixels and FSR scales it up.")
	_slider("Brightness", "brightness", 0.7, 1.4, 0.02, _percent)
	var now := "%s on %s" % ["lean" if Game.lean_graphics else "full", RenderingServer.get_video_adapter_name()]
	_choice("Graphics detail", "graphics", ["Automatic", "Lean", "Full"], [0, 1, 2], "Lean drops volumetric fog and half the snow for integrated GPUs. Applies when the run restarts. Running %s." % now)


func _audio_page() -> void:
	_slider("Master", "master_volume", 0.0, 1.0, 0.01, _percent)
	_slider("Storm and wind", "ambience_volume", 0.0, 1.0, 0.01, _percent)
	_slider("Steps, doors and the house", "effects_volume", 0.0, 1.0, 0.01, _percent)
	_slider("Heartbeat and dread", "dread_volume", 0.0, 1.0, 0.01, _percent)
	_toggle("Mute in the background", "mute_unfocused", "Silent while another window has focus.")


func _interface_page() -> void:
	_toggle("Interaction prompts", "show_prompts", "The key hint when a note, door or switch is in reach.")
	_toggle("Journal notice", "show_journal_toast", "A note when a page goes into the journal.")
	_choice("Breath meter", "breath_meter", ["Always", "Only when short of breath"], [0, 1])


# --- Rows ---------------------------------------------------------------

func _row(caption: String, control: Control, note := "", fill := true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var text := VBoxContainer.new()
	text.custom_minimum_size.x = LABEL_WIDTH
	text.add_theme_constant_override("separation", 2)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_child(UiChrome.label(caption, 16))
	if note != "":
		var small := UiChrome.label(note, 12, UiChrome.MUTED)
		small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		small.custom_minimum_size.x = LABEL_WIDTH
		text.add_child(small)
	row.add_child(text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if fill else Control.SIZE_SHRINK_BEGIN
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	_rows.add_child(row)


func _section(title: String, note: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	_rows.add_child(gap)
	_rows.add_child(UiChrome.label(title.to_upper(), 13, UiChrome.PAPER))
	var small := UiChrome.label(note, 12, UiChrome.MUTED)
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(small)


# A number setting; shown says how its value reads beside the slider.
func _slider(caption: String, key: String, low: float, high: float, step: float, shown: Callable, note := "") -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.scrollable = false
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(240, 22)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var readout := UiChrome.label("", 15, UiChrome.MUTED)
	readout.custom_minimum_size.x = 64
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var value := float(Game.settings.get(key))
	slider.set_value_no_signal(value)
	readout.text = shown.call(value)
	var whole: bool = Settings.DEFAULTS[key] is int
	slider.value_changed.connect(func(next: float) -> void:
		readout.text = shown.call(next)
		Game.settings.change(key, int(next) if whole else next)
	)
	box.add_child(slider)
	box.add_child(readout)
	_row(caption, box, note)


func _toggle(caption: String, key: String, note := "") -> void:
	var flip := Button.new()
	flip.toggle_mode = true
	flip.focus_mode = Control.FOCUS_NONE
	flip.custom_minimum_size = Vector2(120, 34)
	var on := bool(Game.settings.get(key))
	flip.set_pressed_no_signal(on)
	flip.text = "On" if on else "Off"
	flip.toggled.connect(func(now: bool) -> void:
		flip.text = "On" if now else "Off"
		Game.settings.change(key, now)
	)
	_row(caption, flip, note, false)


func _choice(caption: String, key: String, options: Array, values: Array, note := "") -> void:
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size.x = 280
	for option in options:
		pick.add_item(str(option))
	pick.select(maxi(values.find(Game.settings.get(key)), 0))
	pick.item_selected.connect(func(index: int) -> void: Game.settings.change(key, values[index]))
	_row(caption, pick, note, false)


func _binding(action: String, caption: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var events: Array[InputEvent] = Game.settings.events_of(action)
	for slot in Settings.SLOTS:
		var cap := Button.new()
		cap.focus_mode = Control.FOCUS_NONE
		cap.custom_minimum_size = Vector2(150, 34)
		cap.text = Settings.event_label(events[slot]) if slot < events.size() else "-"
		if not _capture.is_empty() and _capture[0] == action and _capture[1] == slot:
			cap.text = "Press a key..."
			cap.add_theme_color_override("font_color", UiChrome.PAPER)
		cap.pressed.connect(func() -> void: _begin_capture(action, slot))
		box.add_child(cap)
	_row(caption, box, "", false)


func _fixed(caption: String, keys: String) -> void:
	var cap := Button.new()
	cap.text = keys
	cap.disabled = true
	cap.focus_mode = Control.FOCUS_NONE
	cap.custom_minimum_size = Vector2(150, 34)
	cap.add_theme_color_override("font_disabled_color", UiChrome.MUTED)
	_row(caption, cap, "", false)


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


# --- Frame --------------------------------------------------------------

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.06, 0.62)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -560
	card.offset_right = 560
	card.offset_top = -340
	card.offset_bottom = 340
	var face := UiChrome.plate(0, 8)
	face.bg_color = Color(0.06, 0.07, 0.09, 0.96)
	card.add_theme_stylebox_override("panel", face)
	add_child(card)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 0)
	card.add_child(split)
	split.add_child(_build_sidebar())
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size.x = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(line)
	split.add_child(_build_body())


func _build_sidebar() -> Control:
	var margin := _margin(28)
	margin.custom_minimum_size.x = 250
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(UiChrome.label("Paused", 34))
	box.add_child(UiChrome.label("Nothing moves while you are here.", 13, UiChrome.MUTED))
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	box.add_child(gap)
	var group := ButtonGroup.new()
	for page in PAGES:
		var tab := _side_button(page)
		tab.toggle_mode = true
		tab.button_group = group
		tab.pressed.connect(func() -> void:
			_capture = []
			_status.text = ""
			_show_page(page)
		)
		box.add_child(tab)
		_tabs[page] = tab
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	var resume := _side_button("Resume")
	resume.pressed.connect(func() -> void: Game.toggle_pause())
	box.add_child(resume)
	var again := _side_button("Restart the run")
	again.pressed.connect(func() -> void: Game.restart())
	box.add_child(again)
	var leave := _side_button("Quit to desktop")
	leave.pressed.connect(func() -> void: Game.quit())
	box.add_child(leave)
	var credit := UiChrome.label("Her walk and jog: Bandai Namco Research Motion Dataset, Bandai Namco Research Inc., CC BY-NC 4.0, adapted.", 11, UiChrome.MUTED)
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.custom_minimum_size.x = 194
	box.add_child(credit)
	# The pack's author and page are still to be supplied (see its README).
	var forest := UiChrome.label("Green woods: \"Fir forest in the mountains\", Sketchfab, Standard licence, adapted.", 11, UiChrome.MUTED)
	forest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forest.custom_minimum_size.x = 194
	box.add_child(forest)
	return margin


func _build_body() -> Control:
	var margin := _margin(28)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_heading = UiChrome.label("", 26)
	box.add_child(_heading)
	_note = UiChrome.label("", 14, UiChrome.MUTED)
	box.add_child(_note)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_top", 8)
	inset.add_theme_constant_override("margin_right", 16)
	inset.add_theme_constant_override("margin_bottom", 8)
	_scroll.add_child(inset)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 14)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(_rows)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_status = UiChrome.label("", 13, UiChrome.PAPER)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	_hint = UiChrome.label("", 13, UiChrome.MUTED)
	footer.add_child(_hint)
	var reset := Button.new()
	reset.text = "Reset this page"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset_page)
	footer.add_child(reset)
	return margin


func _side_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 40
	return button


func _margin(size: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, size)
	return margin
