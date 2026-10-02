class_name Hud
extends CanvasLayer

var _intro: Control
var _intro_title: Label
var _objective: Label
var _prompt: Label
var _warning: Label
var _breath_fill: ColorRect
var _breath: Control
var _vignette: ColorRect
var _pause: Label
var _debug: Label
var reader: NoteReader
var ending: EndCard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	Game.phase_changed.connect(_on_phase)
	_on_phase(Game.phase)


func _process(_delta: float) -> void:
	_warning.text = _warning_line()
	_prompt.text = _prompt_line()
	if Game.player:
		var ratio := Game.player.stamina / Tune.STAMINA_MAX
		_breath_fill.offset_right = 220.0 * ratio
		_breath_fill.color = Color(0.85, 0.86, 0.9) if Game.player.exhaust_left <= 0.0 else Color(0.75, 0.3, 0.22)
	if _vignette and _vignette.material is ShaderMaterial:
		(_vignette.material as ShaderMaterial).set_shader_parameter("strength", 0.2 + Game.closeness * 0.7)
		(_vignette.material as ShaderMaterial).set_shader_parameter("hurt", Vector3(0.02 + Game.closeness * 0.55, 0.0, 0.0))
	if _debug.visible and Game.player and Game.hunter and Game.trail:
		var gap := Game.trail.offset_of(Game.player.global_position) - Game.hunter.offset
		_debug.text = "gap %.1f m   breath %.1f" % [gap, Game.player.stamina]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Game.toggle_pause()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("restart") or event.is_action_pressed("interact"):
		if Game.phase == Game.Phase.CAUGHT or Game.phase == Game.Phase.ESCAPED:
			Game.restart()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3 and OS.is_debug_build():
		_debug.visible = not _debug.visible


func _on_phase(next: Game.Phase) -> void:
	_intro.visible = next == Game.Phase.INTRO
	_pause.visible = next == Game.Phase.PAUSED
	_objective.visible = next == Game.Phase.PLAYING or next == Game.Phase.READING
	_refresh_objective()
	_breath.visible = next == Game.Phase.PLAYING or next == Game.Phase.READING


func _refresh_objective() -> void:
	if Game.notes_found < Tune.HUNT_NOTES:
		_objective.text = "The lookout is ahead.   %d / 5" % Game.notes_found
	else:
		_objective.text = "Do not stand still.   %d / 5" % Game.notes_found


func _warning_line() -> String:
	var near := Game.closeness
	if near > 0.82:
		return "it is close"
	if near > 0.55:
		return "do not stop"
	if near > 0.32:
		return "something is on the trail"
	return ""


func _prompt_line() -> String:
	if Game.phase != Game.Phase.PLAYING or Game.player == null:
		return ""
	if Game.player.nearby_note():
		return "E  —  read the note"
	if _against_wire():
		return "the wire does not give"
	return ""


func _against_wire() -> bool:
	var at := Game.player.global_position
	var dx := minf(at.x - Tune.FENCE_MIN_X, Tune.FENCE_MAX_X - at.x)
	var dz := minf(at.z - Tune.FENCE_MIN_Z, Tune.FENCE_MAX_Z - at.z)
	return minf(dx, dz) < 2.6


func _build() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := load("res://shaders/vignette.gdshader") as Shader
	var material := ShaderMaterial.new()
	material.shader = shader
	_vignette.material = material
	add_child(_vignette)

	_letterbox()

	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intro)
	_intro_title = _centered_label(_intro, "RUN AWAY", 64, Vector2(0, -40), Color(0.16, 0.18, 0.22))
	_centered_label(_intro, "Daylight on the snow. The wire is as far as the ground goes.", 22, Vector2(0, 30), Color(0.22, 0.24, 0.28))
	_centered_label(_intro, "It stays patient until you have read too much.", 18, Vector2(0, 64), Color(0.35, 0.28, 0.26))

	_objective = _anchored_label("The road is ahead.", 18, Control.PRESET_CENTER_TOP, Vector2(0, 28))
	_warning = _anchored_label("", 22, Control.PRESET_CENTER_TOP, Vector2(0, 58))
	_warning.add_theme_color_override("font_color", Color(0.45, 0.1, 0.08))
	_prompt = _anchored_label("", 20, Control.PRESET_CENTER_BOTTOM, Vector2(0, -78))

	_breath = Control.new()
	_breath.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_breath.offset_left = -110
	_breath.offset_right = 110
	_breath.offset_top = -48
	_breath.offset_bottom = -36
	add_child(_breath)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.45)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_breath.add_child(back)
	_breath_fill = ColorRect.new()
	_breath_fill.color = Color(0.85, 0.86, 0.9)
	_breath_fill.offset_right = 220
	_breath_fill.offset_bottom = 12
	_breath.add_child(_breath_fill)
	var breath_label := Label.new()
	breath_label.text = "breath"
	breath_label.position = Vector2(0, -18)
	breath_label.add_theme_font_size_override("font_size", 12)
	breath_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	_breath.add_child(breath_label)

	_pause = _centered_label(self, "Paused", 36, Vector2(0, 0), Color(0.9, 0.9, 0.92))
	_pause.visible = false

	reader = NoteReader.new()
	add_child(reader)
	ending = EndCard.new()
	add_child(ending)

	_debug = Label.new()
	_debug.visible = false
	_debug.position = Vector2(16, 16)
	_debug.add_theme_font_size_override("font_size", 14)
	add_child(_debug)


func _letterbox() -> void:
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.65)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if top:
			bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
			bar.offset_bottom = 18
		else:
			bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			bar.offset_top = -18
		add_child(bar)


func _centered_label(parent: Node, text: String, size: int, place: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -420
	label.offset_right = 420
	label.offset_top = place.y - 20
	label.offset_bottom = place.y + 24
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _anchored_label(text: String, size: int, preset: Control.LayoutPreset, place: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(preset)
	label.offset_left = -320 + place.x
	label.offset_right = 320 + place.x
	label.offset_top = place.y
	label.offset_bottom = place.y + 28
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.1, 0.12, 0.14))
	add_child(label)
	return label
