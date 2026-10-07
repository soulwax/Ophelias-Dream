class_name DialogueBubble
extends Node3D

## A transparent UI texture on a real 3D plane. Topics use stable IDs;
## callbacks may open the next turn after the previous one has closed.
signal response_selected(id: String)
signal cancelled

var _viewport: SubViewport
var _surface: MeshInstance3D
var _panel: PanelContainer
var _speaker: Label
var _line: Label
var _topics: VBoxContainer
var _hint: Label
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
	_panel.add_theme_stylebox_override("panel", UiChrome.plate(24, 12))
	_viewport.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_speaker = UiChrome.label("", 15, UiChrome.MUTED)
	box.add_child(_speaker)
	_line = UiChrome.label("", 24, UiChrome.PAPER)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_line)
	_topics = VBoxContainer.new()
	_topics.add_theme_constant_override("separation", 4)
	box.add_child(_topics)
	_hint = UiChrome.label("", 14, UiChrome.MUTED)
	box.add_child(_hint)
	_surface = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.0)
	_surface.mesh = quad
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_texture = _viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_surface.material_override = material
	add_child(_surface)
	_surface.hide()
	Game.phase_changed.connect(_on_phase)


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
		button.text = str(_responses[i].text)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = _responses[i].get("disabled", false)
		button.add_theme_font_size_override("font_size", 21)
		button.add_theme_color_override("font_color", UiChrome.MUTED)
		button.add_theme_color_override("font_focus_color", UiChrome.PAPER)
		button.add_theme_stylebox_override("normal", UiChrome.button_style(Color(0, 0, 0, 0)))
		button.pressed.connect(choose.bind(i))
		button.mouse_entered.connect(_select.bind(i))
		_topics.add_child(button)
		_buttons.append(button)
	_selected = 0
	while _buttons[_selected].disabled:
		_selected += 1
	_hint.text = "↑ / ↓  Choose   ·   %s / Enter  Respond   ·   Esc  Leave" % Game.settings.key_label("interact")
	_topics.show()
	_hint.show()
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


func _select(index: int) -> void:
	if index < 0 or index >= _buttons.size() or _buttons[index].disabled:
		return
	_selected = index
	_buttons[index].grab_focus()


func _step(direction: int) -> void:
	for offset in range(1, _buttons.size() + 1):
		var index := posmod(_selected + offset * direction, _buttons.size())
		if not _buttons[index].disabled:
			_select(index)
			return


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
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
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.project_ray_origin(event.position)
	var direction := camera.project_ray_normal(event.position)
	var normal := _surface.global_basis.z
	var denominator := normal.dot(direction)
	if absf(denominator) < 0.0001:
		return
	var distance := normal.dot(_surface.global_position - origin) / denominator
	var point := _surface.to_local(origin + direction * distance)
	var uv := Vector2(point.x / 1.5 + 0.5, 0.5 - point.y)
	var inside := distance > 0 and Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv)
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
	var spoken := Game.murmur_left > 0 and Hud.murmur_shown(Game.phase)
	var shown := _active or (spoken and Game.phase == Game.Phase.PLAYING)
	if not _active:
		_topics.hide()
		_hint.hide()
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
		if camera.is_position_behind(_target.global_position):
			close()
		else:
			anchor = camera.unproject_position(_target.global_position + Vector3.UP * 1.7)
	anchor.x = clampf(anchor.x, screen.x * 0.28, screen.x * 0.72)
	anchor.y = clampf(anchor.y, screen.y * 0.30, screen.y * 0.70)
	# A shallow camera-facing plane preserves readability, stereo depth, and
	# a stable footprint even when the camera changes FOV or enters a room.
	_surface.global_transform = Transform3D(camera.global_basis, camera.project_position(anchor, 2.0))
	var width := camera.project_position(Vector2(screen.x * 0.72, screen.y * 0.5), 2.0).distance_to(camera.project_position(Vector2(screen.x * 0.28, screen.y * 0.5), 2.0))
	_surface.scale = Vector3.ONE * width / 1.5
