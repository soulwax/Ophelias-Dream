class_name Hud
extends CanvasLayer

var _intro: Control
var _objective_plate: PanelContainer
var _objective: Label
var _pips: Array[ColorRect] = []
var _warning_plate: PanelContainer
var _warning: Label
var _prompt: HBoxContainer
var _prompt_caption: Label
var _breath: Control
var _breath_fill: ColorRect
var _breath_label: Label
var _controls: Control
var _vignette: ColorRect
var _pause: Control
var _debug: Label
var _play_age := 0.0
var reader: NoteReader
var ending: EndCard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	Game.phase_changed.connect(_on_phase)
	_on_phase(Game.phase)


func _process(delta: float) -> void:
	_warning.text = _warning_line()
	_warning_plate.visible = _warning.text != "" and Game.phase == Game.Phase.PLAYING
	_refresh_prompt()
	_refresh_breath()
	_refresh_pips()
	if Game.phase == Game.Phase.INTRO:
		_intro.modulate.a = clampf(Game.intro_left / 0.65, 0.0, 1.0)
	elif Game.phase == Game.Phase.PLAYING:
		_play_age += delta
		_controls.modulate.a = clampf(1.0 - (_play_age - 8.0) / 4.0, 0.0, 1.0)
	if _vignette and _vignette.material is ShaderMaterial:
		(_vignette.material as ShaderMaterial).set_shader_parameter("strength", 0.18 + Game.threat() * 0.62)
		(_vignette.material as ShaderMaterial).set_shader_parameter("hurt", Vector3(0.02 + Game.threat() * 0.5, 0.0, 0.0))
	if _debug.visible and Game.player and Game.hunter and Game.trail:
		var gap := Game.trail.offset_of(Game.player.global_position) - Game.hunter.offset
		_debug.text = "gap %.1f m   breath %.1f" % [gap, Game.player.stamina]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Game.toggle_pause()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("restart"):
		if Game.phase == Game.Phase.CAUGHT or Game.phase == Game.Phase.ESCAPED or Game.phase == Game.Phase.PAUSED:
			Game.restart()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3 and OS.is_debug_build():
		_debug.visible = not _debug.visible


func _on_phase(next: Game.Phase) -> void:
	_intro.visible = next == Game.Phase.INTRO
	_pause.visible = next == Game.Phase.PAUSED
	var playing := next == Game.Phase.PLAYING
	_objective_plate.visible = playing
	_breath.visible = playing
	_controls.visible = playing
	if next == Game.Phase.INTRO:
		_controls.modulate.a = 1.0
	if next == Game.Phase.PLAYING and _play_age <= 0.0:
		_controls.modulate.a = 1.0
	_refresh_objective()


func _refresh_objective() -> void:
	if Game.notes_found < Tune.HUNT_NOTES:
		_objective.text = "Reach the lookout."
	else:
		_objective.text = "Keep moving."


func _refresh_pips() -> void:
	var found := Game.notes_found
	for index in _pips.size():
		var on := index < found
		_pips[index].color = Color(0.93, 0.86, 0.7) if on else Color(1, 1, 1, 0.22)


func _refresh_breath() -> void:
	if Game.player == null:
		return
	var ratio := clampf(Game.player.stamina / Tune.STAMINA_MAX, 0.0, 1.0)
	_breath_fill.anchor_right = ratio
	var spent := Game.player.exhaust_left > 0.0
	if Game.player.holding_breath:
		_breath_fill.color = Color(0.62, 0.78, 0.95)
		_breath_label.text = "Holding breath"
	elif spent:
		_breath_fill.color = Color(0.86, 0.32, 0.24)
		_breath_label.text = "Catching breath"
	elif ratio < 0.28:
		_breath_fill.color = Color(0.9, 0.62, 0.38)
		_breath_label.text = "Breath"
	else:
		_breath_fill.color = Color(0.86, 0.9, 0.94)
		_breath_label.text = "Breath"


func _warning_line() -> String:
	var near := Game.closeness
	if near > 0.82:
		return "It is close."
	if near > 0.55:
		return "Do not stop."
	if Game.anomaly_hint != "":
		return Game.anomaly_hint
	if near > 0.32:
		return "Something is on the trail."
	return ""


func _refresh_prompt() -> void:
	var show := false
	var caption := ""
	var key := "E"
	if Game.phase == Game.Phase.PLAYING and Game.player:
		if Game.player.nearby_note():
			show = true
			caption = "Read the note"
		elif _against_wire():
			show = true
			key = ""
			caption = "The fence does not give."
	_prompt.visible = show
	if not show:
		return
	_prompt.get_child(0).visible = key != ""
	_prompt_caption.text = caption


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
	_build_intro()
	_build_objective()
	_build_warning()
	_build_controls()
	_build_bottom()
	_build_pause()
	reader = NoteReader.new()
	add_child(reader)
	ending = EndCard.new()
	add_child(ending)
	_debug = UiChrome.label("", 14, UiChrome.MUTED)
	_debug.visible = false
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.offset_left = -280
	_debug.offset_top = 16
	_debug.offset_right = -16
	_debug.offset_bottom = 40
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_debug)


func _build_intro() -> void:
	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intro)
	var scrim := ColorRect.new()
	scrim.color = Color(0.04, 0.05, 0.07, 0.28)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(scrim)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -340
	card.offset_right = 340
	card.offset_top = -168
	card.offset_bottom = 168
	card.add_theme_stylebox_override("panel", UiChrome.plate(28, 8))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var title := UiChrome.label("RUN AWAY", 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := UiChrome.label("The fence is as far as the snow goes.", 18, UiChrome.MUTED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	box.add_child(HSeparator.new())
	for pair in [["Mouse", "Look"], ["WASD", "Move"], ["Shift", "Sprint"], ["Space", "Hold breath"], ["E", "Read"], ["Esc", "Pause"]]:
		var row := UiChrome.key_row(pair[0], pair[1])
		box.add_child(row)


func _build_objective() -> void:
	_objective_plate = PanelContainer.new()
	_objective_plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_objective_plate.offset_left = 28
	_objective_plate.offset_top = 28
	_objective_plate.offset_right = 360
	_objective_plate.offset_bottom = 118
	_objective_plate.add_theme_stylebox_override("panel", UiChrome.plate(16, 6))
	_objective_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_plate.add_child(box)
	_objective = UiChrome.label("Reach the lookout.", 20)
	box.add_child(_objective)
	var notes := HBoxContainer.new()
	notes.add_theme_constant_override("separation", 8)
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes.add_child(UiChrome.label("Notes", 13, UiChrome.MUTED))
	var total := NoteCatalog.all().size()
	for _index in total:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 8)
		pip.color = Color(1, 1, 1, 0.22)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notes.add_child(pip)
		_pips.append(pip)
	box.add_child(notes)


func _build_warning() -> void:
	_warning_plate = PanelContainer.new()
	_warning_plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning_plate.offset_left = -180
	_warning_plate.offset_right = 180
	_warning_plate.offset_top = 28
	_warning_plate.offset_bottom = 76
	_warning_plate.add_theme_stylebox_override("panel", UiChrome.plate(12, 6))
	_warning_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_plate.visible = false
	add_child(_warning_plate)
	_warning = UiChrome.label("", 18, UiChrome.RUST)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warning_plate.add_child(_warning)


func _build_controls() -> void:
	_controls = VBoxContainer.new()
	_controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_controls.offset_left = 28
	_controls.offset_top = -210
	_controls.offset_right = 240
	_controls.offset_bottom = -28
	_controls.add_theme_constant_override("separation", 4)
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_controls)
	for pair in [["WASD", "Move"], ["Shift", "Sprint"], ["Space", "Hold breath"], ["E", "Read"], ["Esc", "Pause"]]:
		_controls.add_child(UiChrome.key_row(pair[0], pair[1]))


func _build_bottom() -> void:
	var dock := VBoxContainer.new()
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock.offset_left = -160
	dock.offset_right = 160
	dock.offset_top = -128
	dock.offset_bottom = -28
	dock.add_theme_constant_override("separation", 10)
	dock.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dock)
	_prompt = UiChrome.key_row("E", "Read the note")
	_prompt.visible = false
	_prompt_caption = _prompt.get_child(1) as Label
	dock.add_child(_prompt)
	_breath = PanelContainer.new()
	_breath.add_theme_stylebox_override("panel", UiChrome.plate(12, 6))
	_breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(_breath)
	var breath_box := VBoxContainer.new()
	breath_box.add_theme_constant_override("separation", 6)
	breath_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath.add_child(breath_box)
	_breath_label = UiChrome.label("Breath", 12, UiChrome.MUTED)
	breath_box.add_child(_breath_label)
	var track := Control.new()
	track.custom_minimum_size = Vector2(240, 8)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breath_box.add_child(track)
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.12)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(back)
	_breath_fill = ColorRect.new()
	_breath_fill.color = Color(0.86, 0.9, 0.94)
	_breath_fill.anchor_right = 1.0
	_breath_fill.anchor_bottom = 1.0
	_breath_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_breath_fill)


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.06, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(scrim)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -260
	card.offset_right = 260
	card.offset_top = -180
	card.offset_bottom = 180
	card.add_theme_stylebox_override("panel", UiChrome.plate(28, 8))
	_pause.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var title := UiChrome.label("Paused", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for pair in [["Mouse", "Look"], ["WASD", "Move"], ["Shift", "Sprint"], ["Space", "Hold breath"], ["E", "Read"]]:
		box.add_child(UiChrome.key_row(pair[0], pair[1]))
	var resume := UiChrome.text_button("Resume")
	resume.pressed.connect(func() -> void: Game.toggle_pause())
	box.add_child(resume)
	var again := UiChrome.text_button("Restart")
	again.pressed.connect(func() -> void: Game.restart())
	box.add_child(again)
	var hint := UiChrome.label("Esc resumes.  R restarts.", 13, UiChrome.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _letterbox() -> void:
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.72)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if top:
			bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
			bar.offset_bottom = 10
		else:
			bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			bar.offset_top = -10
		add_child(bar)
