extends Control

var _music: AudioStreamPlayer
var _eye: ShaderMaterial
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
	_build_snow()
	var title := UiChrome.label("Ophelia's Dream", 42, Color("e5dbd3"))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.offset_left = -500
	title.offset_right = 500
	title.offset_top = -365
	title.offset_bottom = -305
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var subtitle := UiChrome.label("LEAVE THE LANTERN BURNING", 14, Color("b55750"))
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
	row.offset_top = 258
	row.offset_bottom = 286
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	var rule := ColorRect.new()
	rule.color = Color("b5352e")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rule.anchor_left = 0.125
	rule.anchor_right = 0.875
	rule.offset_left = 0
	rule.offset_right = 0
	rule.offset_top = 248
	rule.offset_bottom = 250
	add_child(rule)
	for caption in ["DREAM", "OPHELIA", "MATHILDA", "CREDITS", "QUIT"]:
		var button := Button.new()
		button.text = caption
		for letter in range(caption.length() - 1, 0, -1):
			button.text = button.text.insert(letter, "  ")
		button.add_theme_font_size_override("font_size", 14)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("dddcd4") if state != "normal" else Color("b5352e")
			button.add_theme_stylebox_override(state, style)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", Color("1b1014"))
		button.add_theme_color_override("font_hover_color", Color("1b1014"))
		button.add_theme_color_override("font_focus_color", Color("1b1014"))
		row.add_child(button)
		_buttons.append(button)
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void:
			_target_mobility = 0.55 if caption == "QUIT" else 1.0
			_aim_at(button.get_global_rect().get_center())
		)
		button.pressed.connect(_choose.bind(caption))
	for i in _buttons.size():
		_buttons[i].focus_neighbor_left = _buttons[i].get_path_to(_buttons[posmod(i - 1, _buttons.size())])
		_buttons[i].focus_neighbor_right = _buttons[i].get_path_to(_buttons[(i + 1) % _buttons.size()])
	var credit := UiChrome.label("A GAME BY CHRISTIAN KLING", 13, Color("8f7775"))
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
	_body = UiChrome.label("", 21)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	var back := Button.new()
	back.text = "RETURN"
	back.pressed.connect(_close)
	box.add_child(back)
	_panel.hide()
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
		"CREDITS":
			_body.text = "Ophelia's Dream\n\nCreated by\nChristian Kling\n\nBuilt with Godot\n\nDanse Macabre — Kraak & Smaak\nBoogie Angst / Jalapeno Records\nPlayback loop and fade applied.\n\nAsset provenance and licenses accompany the game."
			_panel.show()
			(_panel.get_child(0).get_child(1) as Button).grab_focus()
		"QUIT":
			get_tree().quit()


func _close() -> void:
	_panel.hide()
	_buttons[0].grab_focus()


func _fade_music_in() -> void:
	if _music.playing:
		var fade := create_tween()
		fade.tween_property(_music, "volume_db", -12.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_music() -> void:
	if _music and _music.playing:
		_music.stop()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		if _panel.visible:
			_close()
		get_viewport().set_input_as_handled()
