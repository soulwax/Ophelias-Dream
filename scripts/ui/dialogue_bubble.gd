class_name DialogueBubble
extends Node3D

## A screen-space conversation panel anchored to a world character. Topics
## use stable IDs; callbacks may open the next turn after the previous closes.
signal response_selected(id: String)
signal cancelled

var _viewport: SubViewport
var _surface_layer: CanvasLayer
var _surface: TextureRect
var _panel: PanelContainer
var _speaker: Label
var _line: Label
var _turn: Label
var _topics: VBoxContainer
var _background: Label
var _buttons: Array[Button] = []
var _responses: Array[Dictionary] = []
var _target: Node3D
var _callback: Callable
var _active := false
var _selected := 0
var _last_line := ""
var _fade := 0.0
var _previous_mouse: Input.MouseMode
var _pointer_inside := false
var _choice_axis_latched := false


func _ready() -> void:
	Game.dialogue = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(720, 480)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.size = Vector2(696, 0)
	var panel_style := UiChrome.term_box(Color(UiChrome.DIALOGUE_INK, 0.96), Color(UiChrome.DIALOGUE_AMBER, 0.38), 1, 22)
	panel_style.border_width_left = 4
	_panel.add_theme_stylebox_override("panel", panel_style)
	_viewport.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_speaker = UiChrome.term_label("", 13, UiChrome.DIALOGUE_AMBER, true)
	box.add_child(_speaker)
	_line = UiChrome.term_label("", 24, UiChrome.DIALOGUE_FROST)
	_line.add_theme_font_override("font", UiChrome.literary_font())
	_line.add_theme_constant_override("line_spacing", 4)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_line)
	_turn = UiChrome.term_label("", 12, UiChrome.DIALOGUE_AMBER)
	_turn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_turn)
	_topics = VBoxContainer.new()
	_topics.add_theme_constant_override("separation", 4)
	box.add_child(_topics)
	_background = UiChrome.term_label("", 16, UiChrome.DIALOGUE_ASH)
	_background.add_theme_font_override("font", UiChrome.literary_font())
	_background.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_background.visible = false
	box.add_child(_background)
	_surface_layer = CanvasLayer.new()
	_surface_layer.name = "DialogueBubbleOverlay"
	_surface_layer.layer = 22
	add_child(_surface_layer)
	_surface = TextureRect.new()
	_surface.name = "DialogueBubbleSurface"
	_surface.texture = _viewport.get_texture()
	_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.hide()
	_surface_layer.add_child(_surface)
	Game.phase_changed.connect(_on_phase)
	Game.settings.changed.connect(_apply_subtitle_style)
	_apply_subtitle_style()


func _apply_subtitle_style() -> void:
	if _panel == null:
		return
	var high := Game.settings.subtitle_contrast
	var panel_style := UiChrome.term_box(Color(UiChrome.DIALOGUE_INK, 0.995 if high else 0.96), Color(UiChrome.DIALOGUE_AMBER, 0.68 if high else 0.38), 1, 22)
	panel_style.border_width_left = 4
	_panel.add_theme_stylebox_override("panel", panel_style)
	_line.add_theme_font_size_override("font_size", [18, 22, 27, 32][clampi(Game.settings.subtitle_size, 0, 3)])
	_turn.text = "// YOUR REPLY · W/S, ↑/↓ MOVE · 1–5 QUICK · %s / ENTER SELECT · ESC CLOSE" % Game.settings.key_label("interact")
	_panel.size.y = _panel.get_combined_minimum_size().y


## Up to five topics fit without obscuring the scene. Disabled topics remain
## visible but cannot be selected. An optional target anchors the bubble.
func open(speaker: String, text: String, responses: Array, target: Node3D = null, callback: Callable = Callable()) -> bool:
	if Game.phase not in [Game.Phase.PLAYING, Game.Phase.DIALOGUE]:
		return false
	if responses.is_empty() or responses.size() > 5:
		return false
	var available := false
	for response: Dictionary in responses:
		if str(response.get("id", "")) == "" or str(response.get("text", "")) == "":
			return false
		var background: Variant = response.get("background", "")
		if background != null and (typeof(background) != TYPE_STRING or str(background).length() > 180 or str(background).contains("\n") or str(background).contains("\r")):
			return false
		available = available or not response.get("disabled", false)
	if not available:
		return false
	if not _active:
		_previous_mouse = Input.mouse_mode
	_active = true
	_target = target
	_callback = callback
	_responses.assign(responses)
	_speaker.text = speaker.to_upper()
	_line.text = text
	_line.visible_characters = -1
	_last_line = ""
	for button in _buttons:
		_topics.remove_child(button)
		button.queue_free()
	_buttons.clear()
	for i in _responses.size():
		var button := Button.new()
		button.text = "  %d  %s" % [i + 1, str(_responses[i].text)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = _responses[i].get("disabled", false)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_override("font", UiChrome.literary_font())
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", UiChrome.DIALOGUE_ASH)
		button.add_theme_color_override("font_hover_color", UiChrome.DIALOGUE_FROST)
		button.add_theme_color_override("font_focus_color", UiChrome.DIALOGUE_FROST)
		button.add_theme_color_override("font_pressed_color", UiChrome.DIALOGUE_FROST)
		button.add_theme_stylebox_override("normal", _response_style(false))
		button.add_theme_stylebox_override("hover", _response_style(true))
		button.add_theme_stylebox_override("focus", _response_style(true))
		button.add_theme_stylebox_override("pressed", _response_style(true))
		button.pressed.connect(choose.bind(i))
		button.mouse_entered.connect(_select.bind(i))
		_topics.add_child(button)
		_buttons.append(button)
	_selected = 0
	while _buttons[_selected].disabled:
		_selected += 1
	_topics.show()
	_turn.show()
	_panel.size.y = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.set_phase(Game.Phase.DIALOGUE)
	_select(_selected)
	return true


func choose(index: int) -> void:
	if not _active or index < 0 or index >= _responses.size() or _buttons[index].disabled:
		return
	var id := str(_responses[index].id)
	var callback := _callback
	close()
	response_selected.emit(id)
	if callback.is_valid():
		callback.call(id)


func close() -> void:
	if not _active:
		return
	_active = false
	_target = null
	_callback = Callable()
	if Game.phase == Game.Phase.DIALOGUE:
		Input.mouse_mode = _previous_mouse
		Game.set_phase(Game.Phase.PLAYING)


func capture_run_state() -> Dictionary:
	if not _active:
		return {}
	var callback_path := ""
	var callback_object := _callback.get_object()
	if callback_object is Node and is_instance_valid(callback_object):
		callback_path = get_tree().current_scene.get_path_to(callback_object)
	var target_path := ""
	if _target and is_instance_valid(_target):
		target_path = get_tree().current_scene.get_path_to(_target)
	return {
		"speaker": _speaker.text,
		"line": _line.text,
		"responses": _responses.duplicate(true),
		"selected": _selected,
		"target_path": target_path,
		"callback_path": callback_path,
		"callback_method": str(_callback.get_method()) if _callback.is_valid() else "",
	}


func restore_run_state(state: Dictionary) -> void:
	var responses: Variant = state.get("responses", [])
	if not responses is Array or responses.is_empty():
		return
	var target: Node3D
	var target_path := str(state.get("target_path", ""))
	if not target_path.is_empty():
		target = get_tree().current_scene.get_node_or_null(target_path) as Node3D
	var callback := Callable()
	var callback_path := str(state.get("callback_path", ""))
	var method := str(state.get("callback_method", ""))
	if not callback_path.is_empty() and not method.is_empty():
		var owner := get_tree().current_scene.get_node_or_null(callback_path)
		if owner:
			callback = Callable(owner, method)
	open(str(state.get("speaker", "")), str(state.get("line", "")), responses, target, callback)
	var selected := clampi(int(state.get("selected", 0)), 0, _buttons.size() - 1)
	_select(selected)


func _select(index: int) -> void:
	if index < 0 or index >= _buttons.size() or _buttons[index].disabled:
		return
	_selected = index
	for i in _buttons.size():
		_buttons[i].text = ("› " if i == index else "  ") + "%02d   %s" % [i + 1, str(_responses[i].text)]
	var background: Variant = _responses[index].get("background", "")
	var thought := str(background).strip_edges() if background != null else ""
	_background.text = "UNDER THE WORDS · " + thought if not thought.is_empty() else ""
	_background.visible = not thought.is_empty()
	_buttons[index].grab_focus()


func _response_style(selected: bool) -> StyleBoxFlat:
	var style := UiChrome.term_box(Color("17212a", 0.92) if selected else Color(0, 0, 0, 0),
		Color(UiChrome.DIALOGUE_AMBER, 0.84) if selected else Color(UiChrome.DIALOGUE_EDGE, 0.28), 1, 8)
	style.border_width_left = 3 if selected else 1
	return style


func _step(direction: int) -> void:
	for offset in range(1, _buttons.size() + 1):
		var index := posmod(_selected + offset * direction, _buttons.size())
		if not _buttons[index].disabled:
			_select(index)
			return


func _input(event: InputEvent) -> void:
	if not _active:
		return
	var quick_choice := UiChrome.dialogue_choice_index(event, _responses.size())
	if quick_choice >= 0:
		choose(quick_choice)
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		var stick_y: float = (event as InputEventJoypadMotion).axis_value
		if absf(stick_y) < 0.28:
			_choice_axis_latched = false
		elif absf(stick_y) >= 0.68 and not _choice_axis_latched:
			_choice_axis_latched = true
			_step(1 if stick_y > 0.0 else -1)
		else:
			return
		cancelled.emit()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_step(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_step(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		choose(_selected)
	elif event is InputEventMouse:
		_forward_pointer(event as InputEventMouse)
	get_viewport().set_input_as_handled()


func _forward_pointer(event: InputEventMouse) -> void:
	if not _surface.visible or _surface.size.x <= 0.0 or _surface.size.y <= 0.0:
		return
	var uv := (_surface.get_global_transform_with_canvas().affine_inverse() * event.position) / _surface.size
	var inside := Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv)
	if inside and not _pointer_inside:
		_viewport.notify_mouse_entered()
	elif not inside and _pointer_inside:
		_viewport.notify_mouse_exited()
	_pointer_inside = inside
	if inside:
		var forwarded := event.duplicate() as InputEventMouse
		forwarded.position = uv * Vector2(_viewport.size)
		forwarded.global_position = forwarded.position
		_viewport.push_input(forwarded, true)


func _on_phase(phase: Game.Phase) -> void:
	if _active and phase != Game.Phase.DIALOGUE:
		close()


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_surface.hide()
		return
	var spoken := Game.murmur_left > 0 and Hud.murmur_shown(Game.phase) and Game.settings.subtitles
	var shown := _active or (spoken and Game.phase == Game.Phase.PLAYING)
	if not _active:
		_topics.hide()
		_turn.hide()
		_background.hide()
		_speaker.text = Game.murmur_speaker.to_upper() if Game.murmur_speaker != "" else ("MATHILDA" if Game.mathilda_pov else "OPHELIA")
		if _last_line != Game.murmur:
			_last_line = Game.murmur
			_line.text = _last_line
			_panel.size.y = 0
	_panel.size.y = _panel.get_combined_minimum_size().y
	_fade = move_toward(_fade, 1.0 if shown else 0.0, delta * 6.0)
	_panel.modulate.a = _fade
	_surface.visible = _fade > 0.01
	var screen := get_viewport().get_visible_rect().size
	var anchor := screen * Vector2(0.62, 0.63)
	if is_instance_valid(_target):
		var target_position := _target.global_position + Vector3.UP * 1.7
		if camera.is_position_behind(target_position):
			var to_target := target_position - camera.global_position
			to_target.y = 0.0
			var camera_right := camera.global_basis.x
			camera_right.y = 0.0
			var target_is_left := to_target.dot(camera_right.normalized()) < 0.0
			anchor = Vector2(screen.x * (0.28 if target_is_left else 0.72), screen.y * 0.63)
		else:
			anchor = camera.unproject_position(target_position)
	anchor.x = clampf(anchor.x, screen.x * 0.28, screen.x * 0.72)
	anchor.y = clampf(anchor.y, screen.y * 0.30, screen.y * 0.70)
	# Keep the panel's footprint fixed in screen space, independent of target depth.
	_surface.size = Vector2(screen.x * 0.44, screen.x * 0.44 / 1.5)
	_surface.position = anchor - _surface.size * 0.5
