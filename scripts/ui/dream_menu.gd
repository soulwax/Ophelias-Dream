extends Control

const MENU_ENTRIES := [
	{"id": "DREAM", "label": "ENTER DREAM", "japanese": "夢へ入る"},
	{"id": "OPHELIA", "label": "OPHELIA'S STORY", "japanese": "オフィーリアの物語"},
	{"id": "MATHILDA", "label": "MATHILDA'S STORY", "japanese": "マチルダの物語"},
	{"id": "SETTINGS", "label": "SETTINGS", "japanese": "設定"},
	{"id": "CREDITS", "label": "CREDITS", "japanese": "クレジット"},
	{"id": "QUIT", "label": "EXIT", "japanese": "終了"},
]

var _music: AudioStreamPlayer
var _eye: ShaderMaterial
var _glitch: ShaderMaterial
var _snow: GPUParticles2D
var _snow_motion: ParticleProcessMaterial
var _snow_size := Vector2.ZERO
var _buttons: Array[Button] = []
var _gaze := 0.5
var _target := 0.5
var _gaze_y := 0.65
var _target_y := 0.65
var _gaze_mobility := 1.0
var _target_mobility := 1.0
var _light_level := 0.45
var _pointer_light := 0.45
# Per-run phase for the idle micro-jitter, so each session's eye wanders its
# own way rather than every launch ticking in lockstep.
var _tremor_seed := 0.0
var _panel: PanelContainer
var _body: Label
var _settings_terminal: PauseMenu
var _settings_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiChrome.menu_theme()
	_tremor_seed = randf() * 1000.0
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/audio/music/danse_macabre.ogg")
	if _music.stream is AudioStreamOggVorbis:
		(_music.stream as AudioStreamOggVorbis).loop = true
	_music.volume_db = -60.0
	add_child(_music)
	if Game.phase == Game.Phase.BOOT and not Game.dream_mode and not Game.mathilda_pov and not Game.character_selected:
		Game.settings.apply_audio()
		_music.play()
		_fade_music_in()

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eye = ShaderMaterial.new()
	_eye.shader = preload("res://shaders/dream_menu.gdshader")
	_eye.set_shader_parameter("eye_center", Vector2(0.424, 0.454))
	_eye.set_shader_parameter("portrait", load("res://assets/ui/mathilda_eye.png"))
	background.material = _eye
	add_child(background)
	var glitch_glass := ColorRect.new()
	glitch_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glitch_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch = ShaderMaterial.new()
	_glitch.shader = preload("res://shaders/menu_crt.gdshader")
	glitch_glass.material = _glitch
	add_child(glitch_glass)
	_sync_glitch()
	Game.settings.changed.connect(_sync_glitch)
	_build_snow()
	var title := UiChrome.term_label("OPHELIA'S DREAM", 42, Color("e5dbd3"), true)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.offset_left = -500
	title.offset_right = 500
	title.offset_top = -365
	title.offset_bottom = -305
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var subtitle := UiChrome.term_label("// LEAVE THE LANTERN BURNING", 13, Color("b55750"))
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	subtitle.offset_left = -450
	subtitle.offset_right = 450
	subtitle.offset_top = -304
	subtitle.offset_bottom = -280
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.anchor_left = 0.125
	row.anchor_right = 0.875
	row.offset_left = 0
	row.offset_right = 0
	row.offset_top = 240
	row.offset_bottom = 322
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var rule := ColorRect.new()
	rule.color = Color("b5352e")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rule.anchor_left = 0.125
	rule.anchor_right = 0.875
	rule.offset_left = 0
	rule.offset_right = 0
	rule.offset_top = 264
	rule.offset_bottom = 266
	add_child(rule)
	var button_theme := UiChrome.term_theme()
	var japanese_font := SystemFont.new()
	japanese_font.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
	for index in MENU_ENTRIES.size():
		var entry: Dictionary = MENU_ENTRIES[index]
		var action: String = entry["id"]
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 5)
		row.add_child(cell)
		var translation := UiChrome.term_label(entry["japanese"], 14, UiChrome.BONE)
		translation.add_theme_font_override("font", japanese_font)
		translation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		translation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		translation.custom_minimum_size.y = 22
		cell.add_child(translation)
		var button := Button.new()
		button.theme = button_theme
		button.theme_type_variation = "TermAction"
		button.set_meta("plain_label", "%02d  /  %s" % [index + 1, entry["label"]])
		button.text = button.get_meta("plain_label")
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.y = 42
		button.add_theme_font_size_override("font_size", 11)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(button)
		_buttons.append(button)
		if action == "SETTINGS":
			_settings_button = button
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void:
			_set_menu_selection(button, true)
			_target_mobility = 0.55 if action == "QUIT" else 1.0
			_aim_at(button.get_global_rect().get_center())
		)
		button.focus_exited.connect(func() -> void: _set_menu_selection(button, button.is_hovered()))
		button.pressed.connect(_choose.bind(action))
	for i in _buttons.size():
		_buttons[i].focus_neighbor_left = _buttons[i].get_path_to(_buttons[posmod(i - 1, _buttons.size())])
		_buttons[i].focus_neighbor_right = _buttons[i].get_path_to(_buttons[(i + 1) % _buttons.size()])
	var credit := UiChrome.term_label("OD-7  //  A GAME BY CHRISTIAN KLING", 11, Color("8f7775"))
	credit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	credit.offset_left = -400
	credit.offset_right = 400
	credit.offset_top = -55
	credit.offset_bottom = -25
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(credit)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -420
	_panel.offset_right = 420
	_panel.offset_top = -220
	_panel.offset_bottom = 250
	_panel.add_theme_stylebox_override("panel", UiChrome.plate(32, 12))
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	_panel.add_child(box)
	_body = UiChrome.term_label("", 17, UiChrome.BONE)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	var back := Button.new()
	back.theme = button_theme
	back.theme_type_variation = "TermAction"
	back.text = "▸  RETURN TO TITLE"
	back.add_theme_font_size_override("font_size", 13)
	back.pressed.connect(_close)
	box.add_child(back)
	_panel.hide()
	_settings_terminal = PauseMenu.new()
	_settings_terminal.title_closed.connect(_settings_closed)
	add_child(_settings_terminal)
	Game.phase_changed.connect(func(next: Game.Phase) -> void:
		visible = next == Game.Phase.BOOT
		if _snow:
			_snow.emitting = visible
		if next != Game.Phase.BOOT:
			_stop_music()
	)
	visible = Game.phase == Game.Phase.BOOT
	_snow.emitting = visible
	_layout_snow()
	# The separate dream mode is the first threshold into the story.
	_buttons[0].grab_focus.call_deferred()


func _aim_at(point: Vector2) -> void:
	var relative := point / size.max(Vector2.ONE) - Vector2(0.424, 0.454)
	_target = clampf(0.5 + relative.x, 0.08, 0.92)
	_target_y = clampf(0.5 + relative.y, 0.12, 0.88)


func _set_menu_selection(button: Button, selected: bool) -> void:
	var label: String = button.get_meta("plain_label", "")
	button.text = "[ %s ]" % label if selected else label


func _build_snow() -> void:
	_snow = GPUParticles2D.new()
	_snow.name = "SlowEyeSnow"
	_snow.amount = 14
	_snow.lifetime = 20.0
	_snow.preprocess = 20.0
	_snow.randomness = 0.85
	_snow.explosiveness = 0.0
	_snow.local_coords = true
	_snow.texture = load("res://assets/weather/flake.png") as Texture2D
	_snow_motion = ParticleProcessMaterial.new()
	_snow_motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_snow_motion.direction = Vector3(-0.12, 1.0, 0.0)
	_snow_motion.spread = 8.0
	_snow_motion.initial_velocity_min = 2.2
	_snow_motion.initial_velocity_max = 5.8
	_snow_motion.gravity = Vector3(-0.035, 0.12, 0.0)
	_snow_motion.scale_min = 0.62
	_snow_motion.scale_max = 1.0
	_snow_motion.angle_min = -12.0
	_snow_motion.angle_max = 12.0
	_snow_motion.angular_velocity_min = -2.0
	_snow_motion.angular_velocity_max = 2.0
	_snow_motion.color = Color(0.88, 0.93, 1.0, 0.14)
	_snow_motion.turbulence_enabled = true
	_snow_motion.turbulence_noise_strength = 0.08
	_snow_motion.turbulence_noise_scale = 1.8
	_snow_motion.turbulence_noise_speed = Vector3(0.025, 0.045, 0.0)
	_snow_motion.turbulence_influence_min = 0.12
	_snow_motion.turbulence_influence_max = 0.3
	_snow.process_material = _snow_motion
	_snow.emitting = false
	_snow.z_index = 0
	add_child(_snow)


func _layout_snow() -> void:
	var viewport_size := get_viewport_rect().size.max(Vector2.ONE)
	if _snow_size.is_equal_approx(viewport_size):
		return
	_snow_size = viewport_size
	var focus := Vector2(viewport_size.x * 0.424, viewport_size.y * 0.454)
	var extent := Vector2(viewport_size.x * 0.3, viewport_size.y * 0.27)
	var margin := Vector2.ONE * 160.0
	_snow.position = focus
	_snow.visibility_rect = Rect2(-extent - margin, extent * 2.0 + margin * 2.0)
	_snow_motion.emission_box_extents = Vector3(extent.x, extent.y, 0.0)


func _input(event: InputEvent) -> void:
	if not visible or _panel.visible or not event is InputEventMouseMotion:
		return
	var pointer := (event as InputEventMouseMotion).position / size.max(Vector2.ONE)
	_aim_at((event as InputEventMouseMotion).position)
	# Treat the cursor as a nearby soft light; moving it toward the eye
	# produces a pronounced pupil reflex as well as a change in illumination.
	var proximity := 1.0 - clampf((pointer - Vector2(0.424, 0.454)).length() / 0.65, 0.0, 1.0)
	_pointer_light = lerpf(0.08, 0.95, proximity * proximity)
	_target_mobility = 0.55 if _buttons[-1].get_global_rect().has_point((event as InputEventMouseMotion).position) else 1.0


func _process(delta: float) -> void:
	if visible:
		_layout_snow()
	if visible:
		# A living eye never quite settles: a small, smooth tremor on top of
		# the deliberate pursuit, each frequency irrational against the rest
		# so the motion never visibly repeats.
		var t := Time.get_ticks_msec() * 0.001 + _tremor_seed
		var tremor_x := sin(t * 1.7) * 0.0055 + sin(t * 4.3 + 1.1) * 0.0028
		var tremor_y := sin(t * 2.1 + 0.6) * 0.0048 + sin(t * 5.1 + 2.4) * 0.0024
		# Quicker to pick up a new point of interest than to drift there.
		_gaze = lerpf(_gaze, _target + tremor_x, 1.0 - exp(-delta * 13.0))
		_gaze_y = lerpf(_gaze_y, _target_y + tremor_y, 1.0 - exp(-delta * 11.0))
		_gaze_mobility = lerpf(_gaze_mobility, _target_mobility, 1.0 - exp(-delta * 8.0))
		# The same soft light drives illumination and the pupil reflex: it
		# constricts quickly toward a nearer light and eases open slowly once
		# it has passed, the way a real pupillary reflex is asymmetric.
		var light_target := clampf(_pointer_light + 0.08 * sin(Time.get_ticks_msec() * 0.0007), 0.0, 1.0)
		var light_rate := 7.0 if light_target > _light_level else 2.4
		_light_level = lerpf(_light_level, light_target, 1.0 - exp(-delta * light_rate))
		_eye.set_shader_parameter("light_level", _light_level)
		_eye.set_shader_parameter("mobility", _gaze_mobility)
		_eye.set_shader_parameter("gaze", _gaze)
		_eye.set_shader_parameter("gaze_y", _gaze_y)
		_eye.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


func _sync_glitch() -> void:
	if _glitch:
		_glitch.set_shader_parameter("strength", minf(Game.settings.screen_effects * 0.16, 0.16))


func _choose(caption: String) -> void:
	match caption:
		"DREAM":
			_stop_music()
			Game.character_selected = true
			Game.dream_mode = true
			Game.mathilda_pov = false
			get_tree().reload_current_scene()
		"MATHILDA":
			_stop_music()
			Game.character_selected = true
			Game.dream_mode = false
			Game.mathilda_pov = true
			get_tree().reload_current_scene()
		"OPHELIA":
			Game.character_selected = true
			Game.dream_mode = false
			Game.mathilda_pov = false
			_stop_music()
			get_tree().reload_current_scene()
		"SETTINGS":
			_panel.hide()
			_settings_terminal.open_title_settings()
		"CREDITS":
			_body.text = "Ophelia's Dream\n\nCreated by\nChristian Kling\n\nBuilt with Godot\n\nDanse Macabre — Kraak & Smaak\nBoogie Angst / Jalapeno Records\nPlayback loop and fade applied.\n\nAsset provenance and licenses accompany the game."
			_panel.show()
			(_panel.get_child(0).get_child(1) as Button).grab_focus()
		"QUIT":
			get_tree().quit()


func _close() -> void:
	_panel.hide()
	_buttons[0].grab_focus()


func _settings_closed() -> void:
	if is_instance_valid(_settings_button) and visible:
		_settings_button.grab_focus.call_deferred()


func _fade_music_in() -> void:
	if _music.playing:
		var fade := create_tween()
		fade.tween_property(_music, "volume_db", -12.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_music() -> void:
	if _music and _music.playing:
		_music.stop()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		if _settings_terminal and _settings_terminal.is_title_settings_open():
			_settings_terminal.close_title_settings()
		elif _panel.visible:
			_close()
		get_viewport().set_input_as_handled()
