class_name Hud
extends CanvasLayer

var _intro: Control
var _toast: PanelContainer
var _toast_keys: HBoxContainer
var _toast_left := 0.0
var journal: Journal

var _warning_plate: PanelContainer
var _warning: Label
var _murmur_plate: PanelContainer
var _murmur: Label
var _prompt_plate: PanelContainer
var _prompt: HBoxContainer
var _prompt_caption: Label
var _prompt_target: Node3D
var _prompt_tween: Tween
var _reticle: Panel
var _feedback_text := ""
var _feedback_left := 0.0
var _breath: Control
var _breath_fill: ColorRect
var _breath_label: Label
var _vignette: ColorRect
var _debug: Label
var menu: PauseMenu
var reader: NoteReader
var ending: EndCard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	Game.phase_changed.connect(_on_phase)
	Game.interaction_feedback.connect(_on_interaction_feedback)
	Game.page_added.connect(_on_page_added)
	_on_phase(Game.phase)


func _process(delta: float) -> void:
	_feedback_left = maxf(0.0, _feedback_left - delta)
	var playing := Game.phase == Game.Phase.PLAYING
	_warning.text = _warning_line()
	_warning_plate.visible = _warning.text != "" and playing
	if Game.phase != Game.Phase.PAUSED:
		Game.murmur_left = maxf(0.0, Game.murmur_left - delta)
	var reading := Game.phase == Game.Phase.READING or Game.phase == Game.Phase.JOURNAL
	var spoken := Game.murmur_left > 0.0 and (playing or reading)
	_murmur.text = Game.murmur if spoken else ""
	_murmur_plate.visible = spoken
	if spoken:
		_murmur_plate.offset_top = -84 if reading else -192
		_murmur_plate.offset_bottom = -24 if reading else -132
	_toast_left = maxf(0.0, _toast_left - delta)
	_toast.visible = _toast_left > 0.0 and (playing or Game.phase == Game.Phase.READING)
	_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
	_refresh_prompt()
	_refresh_breath()
	if Game.phase == Game.Phase.INTRO:
		_intro.modulate.a = clampf(Game.intro_left / 0.65, 0.0, 1.0)
	if _vignette and _vignette.material is ShaderMaterial:
		var whiteout_press := (Game.weather.whiteout * 0.14) if Game.weather and Game.player and not Game.player.indoors() else 0.0
		(_vignette.material as ShaderMaterial).set_shader_parameter("strength", 0.18 + Game.threat() * 0.62 + whiteout_press)
		(_vignette.material as ShaderMaterial).set_shader_parameter("hurt", Vector3(0.02 + Game.threat() * 0.5, 0.0, 0.0))
	if _debug.visible and Game.player:
		var wx := Game.weather.regime_name() if Game.weather else "None"
		_debug.text = "%s   threat %.2f   breath %.1f" % [wx, Game.threat(), Game.player.stamina]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if Game.phase == Game.Phase.JOURNAL:
			Game.close_journal()
			get_viewport().set_input_as_handled()
		elif Game.phase == Game.Phase.PLAYING or Game.phase == Game.Phase.READING:
			Game.open_journal()
			get_viewport().set_input_as_handled()
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




func _refresh_breath() -> void:
	if Game.player == null:
		_breath.visible = false
		return
	var ratio := clampf(Game.player.stamina / Tune.STAMINA_MAX, 0.0, 1.0)
	_breath_fill.anchor_right = ratio
	var spent := Game.player.exhaust_left > 0.0
	var short := ratio < 0.995 or spent or Game.player.holding_breath
	_breath.visible = Game.phase == Game.Phase.PLAYING and (Game.settings.breath_meter == 0 or short)
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
	# Whichever pressure is actually stronger speaks.
	if Game.threat_hint != "" and Game.dread > near:
		return Game.threat_hint
	if near > 0.32:
		return "Something is on the trail."
	if Game.threat_hint != "":
		return Game.threat_hint
	return ""


func _refresh_prompt() -> void:
	var show := false
	var caption := ""
	var key := Game.settings.key_label("interact")
	var target: Node3D
	var dim := false
	var aim: Aim = Game.player.aim if Game.player else null
	if Game.phase == Game.Phase.PLAYING and aim and Game.settings.show_prompts:
		var focused: Node3D = aim.target
		if focused is FieldNote:
			show = true
			var page := focused as FieldNote
			caption = "Read the page" if page.entry and not page.entry.counts else "Read the note"
			target = focused
		elif focused:
			show = true
			caption = str(focused.call("interact_label"))
			target = focused
		elif aim.far:
			show = true
			dim = true
			key = ""
			caption = "Too far to reach"
		elif _against_wire():
			show = true
			key = ""
			caption = "The fence does not give."
		if _feedback_left > 0.0 and _feedback_text != "":
			show = true
			key = ""
			caption = _feedback_text
	_prompt_plate.visible = show
	if target != _prompt_target:
		_prompt_target = target
		if target:
			_pulse_prompt(false)
	_refresh_reticle(aim)
	if not show:
		return
	if not (_prompt_tween and _prompt_tween.is_running()):
		_prompt_plate.modulate.a = 0.6 if dim else 1.0
	_prompt.get_child(0).visible = key != ""
	UiChrome.set_key(_prompt, key)
	_prompt_caption.text = caption


# Only there when something can be picked: bright on what is under it, faint
# when a nearby thing was chosen around it, rust when it is out of reach.
func _refresh_reticle(aim: Aim) -> void:
	var playing := Game.phase == Game.Phase.PLAYING and aim != null and Game.settings.show_prompts
	var shown := playing and (aim.target != null or aim.far != null)
	var back := _reticle.get_parent() as Control
	back.visible = shown
	if not shown:
		return
	var ring := _reticle.get_theme_stylebox("panel") as StyleBoxFlat
	if aim.far:
		ring.border_color = Color(UiChrome.RUST, 0.85)
	elif aim.direct:
		ring.border_color = Color(UiChrome.PAPER, 1.0)
	else:
		ring.border_color = Color(UiChrome.PAPER, 0.55)
	back.modulate.a = 1.0 if aim.direct or aim.far else 0.7


func _on_interaction_feedback(message: String, succeeded: bool) -> void:
	_feedback_text = message
	_feedback_left = 0.65 if message != "" else 0.0
	_pulse_prompt(succeeded)


func _pulse_prompt(succeeded: bool) -> void:
	if _prompt_tween and _prompt_tween.is_running():
		_prompt_tween.kill()
	_prompt_plate.pivot_offset = _prompt_plate.size * 0.5
	_prompt_plate.scale = Vector2.ONE * (1.06 if succeeded else 0.94)
	_prompt_plate.modulate = Color(1.0, 0.9, 0.68) if succeeded else Color(1.0, 1.0, 1.0, 0.65)
	_prompt_tween = create_tween().set_parallel(true)
	_prompt_tween.tween_property(_prompt_plate, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_prompt_tween.tween_property(_prompt_plate, "modulate", Color.WHITE, 0.24)


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
	_build_toast()
	_build_warning()
	_build_bottom()
	_build_reticle()
	reader = NoteReader.new()
	add_child(reader)
	journal = Journal.new()
	add_child(journal)
	_build_murmur()
	ending = EndCard.new()
	add_child(ending)
	menu = PauseMenu.new()
	add_child(menu)
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
	card.offset_top = -118
	card.offset_bottom = 118
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
	var line := UiChrome.label("Mathilda went out into the storm.", 18, UiChrome.MUTED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var told := UiChrome.label("You told her to.", 15, Color(UiChrome.MUTED, 0.75))
	told.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(told)
	# The controls live in the Esc menu, not on screen.
	var menu_line := UiChrome.label("Esc: controls and settings", 13, UiChrome.MUTED)
	menu_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(menu_line)



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


func _build_murmur() -> void:
	_murmur_plate = PanelContainer.new()
	_murmur_plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_murmur_plate.offset_left = -310
	_murmur_plate.offset_right = 310
	_murmur_plate.offset_top = -192
	_murmur_plate.offset_bottom = -132
	_murmur_plate.add_theme_stylebox_override("panel", UiChrome.plate(12, 6))
	_murmur_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_murmur_plate.visible = false
	add_child(_murmur_plate)
	_murmur = UiChrome.label("", 16, UiChrome.PAPER)
	_murmur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_murmur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_murmur.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_murmur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_murmur_plate.add_child(_murmur)


# A light ring on a dark one, so it reads on snow and on the cabin walls.
func _build_reticle() -> void:
	var back := Panel.new()
	back.set_anchors_preset(Control.PRESET_CENTER)
	back.offset_left = -10
	back.offset_right = 10
	back.offset_top = -10
	back.offset_bottom = 10
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", _ring(Color(0.05, 0.05, 0.06, 0.45), 4, 10))
	back.visible = false
	add_child(back)
	_reticle = Panel.new()
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.offset_left = 1
	_reticle.offset_right = -1
	_reticle.offset_top = 1
	_reticle.offset_bottom = -1
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.add_theme_stylebox_override("panel", _ring(Color(UiChrome.PAPER, 0.95), 2, 9))
	back.add_child(_reticle)


func _ring(color: Color, width: int, radius: int) -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(width)
	ring.set_corner_radius_all(radius)
	ring.anti_aliasing = true
	ring.border_color = color
	return ring


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
	# On a plate, so the key reads against bright snow.
	_prompt_plate = PanelContainer.new()
	_prompt_plate.add_theme_stylebox_override("panel", UiChrome.plate(10, 6))
	_prompt_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_plate.visible = false
	dock.add_child(_prompt_plate)
	_prompt = UiChrome.key_row("E", "Read the note")
	_prompt_caption = _prompt.get_child(1) as Label
	_prompt_plate.add_child(_prompt)
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


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast.offset_left = 28
	_toast.offset_top = -86
	_toast.offset_right = 340
	_toast.offset_bottom = -28
	_toast.add_theme_stylebox_override("panel", UiChrome.plate(14, 6))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	_toast_keys = UiChrome.key_row("J", "Added to the journal")
	_toast.add_child(_toast_keys)


func _on_page_added(_entry: NoteEntry) -> void:
	if not Game.settings.show_journal_toast:
		return
	UiChrome.set_key(_toast_keys, Game.settings.key_label("journal"))
	_toast_left = Tune.JOURNAL_TOAST
