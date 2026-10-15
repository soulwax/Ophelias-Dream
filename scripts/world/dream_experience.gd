extends Node3D

## A short, freely playable dream walk. The figure is a CC0 Quaternius rig,
## kept deliberately unreadable by a translucent, unlit silhouette material.
const FIGURE_SCENE := preload("res://assets/characters/quaternius_modular_women/animated_woman_a.glb")
const FIGURE_OFFSETS := [9.0, 20.0, 34.0, 50.0, 67.0]
const WINDOW_INTERVAL_SECONDS := 6.0
const CLEARING_APPROACH_OFFSET := 61.0
const LANTERN_WIND_REACH := 13.0
const LANTERN_SHELTER_QUIET := 0.36
const LANTERN_RETURN_QUIET := 0.13
const SCENE_CAMERA_DISTANCE := [4.8, 4.5, 4.2, 3.9]
const SCENE_CAMERA_HEIGHT := [1.65, 1.58, 1.5, 1.42]
const CONVERSATION_CAMERA_REACH := 9.0
const APPARITION_DISSOLVE := 0.38
const APPARITION_FADE_SECONDS := 1.1
const APPARITION_MEMORY_SECONDS := 3.85
const MATHILDA_APPROACH_DISTANCE := 15.0
const STORY := preload("res://scripts/world/dream_story.gd")
const DREAM_ROUTE_SCRIPT := preload("res://scripts/world/dream_route.gd")
const DREAM_ARCHITECTURE_SCRIPT := preload("res://scripts/world/dream_memory_architecture.gd")
const DREAM_SOUNDSCAPE_SCRIPT := preload("res://scripts/audio/dream_soundscape.gd")
const CAPTION_VIEWPORT_WIDTH := 900
const CAPTION_SCREEN_SCALE := 0.75

var _dream_route: Node3D
var _memory_architecture: DreamMemoryArchitecture
var _dream_soundscape: Node3D
var _warning_prop: Node3D
var _figure: Node3D
var _animation: AnimationPlayer
var _walk_animation := ""
var _idle_animation := ""
var _figure_offset := 0.0
var _figure_moving := false
var _figure_motion_active := false
var _figure_motion_target_offset := 0.0
var _figure_motion_look_at_player := false
var _figure_motion_tween: Tween
var _figure_turn_active := false
var _figure_turn_target_yaw := 0.0
var _figure_turn_tween: Tween
var _figure_rambling := false
var _rambling_gaze_target := Vector3.ZERO
var _silhouette: ShaderMaterial
enum ApparitionState { PRESENT, LEAVING, ABSENT, RETURNING }
var _apparition_state := ApparitionState.PRESENT
var _apparition_timer := 0.0
var _apparition_dissolve := 0.0
var _apparition_tween: Tween
var _apparition_link_strength := 0.0
var _boundary_shadow: MeshInstance3D
var _boundary_material: ShaderMaterial
var _boundary_strength := 0.0
var _post_material: ShaderMaterial
var _post_rect: ColorRect
var _aura_material: ShaderMaterial
var _aura_rect: ColorRect
var _figure_aura_light: OmniLight3D
var _figure_aura_shell: MeshInstance3D
var _figure_aura_material: ShaderMaterial
var _aura_mote_material: StandardMaterial3D
var _figure_aura_color := Color("a87cff")
var _figure_aura_time := 0.0
var _figure_aura_pulse := 0.0
var _speech_view: SubViewport
var _dream_ui_layer: CanvasLayer
var _dream_ui_root: Control
var _speech_sprite: TextureRect
var _speech_panel: PanelContainer
var _speaker_label: Label
var _caption: Label
var _caption_action: HBoxContainer
var _speech_target: Node3D
var _lantern_prompt: Label
var _lantern: Node3D
var _lantern_light: OmniLight3D
var _lantern_flame: MeshInstance3D
var _lantern_time := 0.0
var _lantern_wait := 0.0
var _lantern_sheltered := false
var _lantern_seen := false
var _lantern_left_once := false
var _lantern_returned := false
var _lantern_wind_quiet := 0.0
var _dream_quiet := 0.0
var _dream_quiet_after_response := 0.0
var _dream_elapsed := 0.0
var _dream_voice_unlocked := false
var _opening_station_pending := false
var _choice_panel: Control
var _choice_title_back: Panel
var _choice_hint_back: Panel
var _choice_title: Label
var _choice_hint: Label
var _choice_buttons: Array[Label] = []
var _choice_rows: Array[Panel] = []
var _conversation_camera: Camera3D
var _return_camera: Camera3D
var _conversation_camera_active := false
var _conversation_camera_warmup := 0.0
var _conversation_camera_returning := false
var _conversation_camera_return_time := 0.0
var _camera_choreography_enabled := true
var _conversation_response := ""
var _conversation_response_pending := false
var _conversation_response_ready := false
var _conversation_response_timer := 0.0
var _choice_index := 0
var _choice_time := 0.0
var _choice_axis_latched := false
var _answer_open := false
var _conversation_intro_waiting := false
var _conversation_round := 0
var _station_dialogue_active := false
var _station_round_index := -1
var _station_after_line := -1
var _station_choice_effect := ""
var _completed_talk_rounds: Dictionary = {}
var _conversation_waiting := false
var _conversation_strain := 0
var _repair_menu_attempts := 0
var _repair_menu_active := false
var _conversation_choice_advances := true
var _dream_outcome := "complete"
var _ending_warning_shown := false
var _waking_card := false
var _dialogue_ui_hidden_for_pause := false
var _pause_speech_visible := false
var _pause_choice_panel_visible := false
var _pause_lantern_prompt_visible := false
var _journal_speech_visible := false
var _journal_choice_visible := false
var _journal_lantern_visible := false
var _caption_tween: Tween
var _story_line_queue: Array[Dictionary] = []
var _pending_station_rounds: Array[int] = []
var _story_line_active := false
var _story_line_hold := 0.0
var _story_gap_remaining := 0.0
var _story_finish_pending := false
var _late_step_stop_time := 0.0
var _late_step_dialogue_delay := -1.0
var _late_step_ready := false
var _window_interval_elapsed := -1.0
var _window_interval_complete := false
var _story_motion_tween: Tween
var _stage := 0
var _finished := false
var _memory_chosen := false
var _caption_time := 0.0
var _effect_strength := 0.0
var _effect_target := 0.0
var _effect_hold := 0.0
var _effect_cue := "doubt"
var _effect_focus: Node3D
var _story_event_cue_index := 0
var _seen_story_cues: Dictionary = {}
var _dream_understood := false
var _story: Dictionary
var _dream_journal_entries: Array[Dictionary] = []
var _dream_journal_seen: Dictionary = {}
var _dream_journal_layer: CanvasLayer
var _dream_journal_hint: Label
var _dream_journal_hint_panel: PanelContainer
var _dream_journal_hint_time := 0.0
var _dream_journal_scrim: ColorRect
var _dream_journal_panel: PanelContainer
var _dream_journal_scroll: ScrollContainer
var _dream_journal_rows: VBoxContainer
var _dream_journal_guidance_button: Button
var _dream_journal_available := false
var _dream_journal_open := false
var _journal_guidance_visible := false


func _ready() -> void:
	Game.phase_changed.connect(_on_game_phase_changed)
	_story = STORY.load_data()
	if _story.is_empty():
		return
	_build_dream_route()
	_build_dream_architecture()
	_build_caption()
	_build_dream_journal()
	_build_figure()
	_build_warning_prop()
	_build_post_effect()
	_dream_soundscape = DREAM_SOUNDSCAPE_SCRIPT.new()
	_dream_soundscape.name = "DreamSoundscape"
	add_child(_dream_soundscape)
	_start.call_deferred()


func _start() -> void:
	if Game.player == null or Game.trail == null:
		return
	# The dream begins inside the house, one step before its exit. Mathilda waits
	# beyond the door and remains silent until Ophelia comes within speaking range.
	var step_position: Vector3 = _dream_route.call("world_position", "step")
	Game.player.global_position = Game.house.front_door_approach() if Game.house else step_position + Vector3.UP * 0.15
	if Game.house:
		var facing := Game.house.front_door_facing()
		var heading := atan2(-facing.x, -facing.z)
		Game.player.set("_yaw", heading)
		Game.player.set("_facing", heading)
		Game.player.call("_apply_look")
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()
	_dream_elapsed = 0.0
	_dream_voice_unlocked = false
	_figure_offset = Game.trail.player_start_offset + FIGURE_OFFSETS[0]
	_place_figure(_figure_offset)
	_begin_figure_appearance(1.55)
	_build_lantern()
	Game.audio_fade = 1.0
	Game.set_phase(Game.Phase.DREAM)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.settings.apply_audio()
	_record_dream_entry(_story.get("journal_cue", {}))
	_set_figure_moving(false)


func restore_after_load(state: Dictionary) -> void:
	if not state.has("_window_interval_complete"):
		_window_interval_complete = _stage >= 4 or _finished or _memory_chosen
		if _completed_talk_rounds.has(2) and not _window_interval_complete:
			_begin_window_interval()
	if not state.has("_dream_voice_unlocked") and state.has("speech_visible"):
		_dream_voice_unlocked = bool(state.get("speech_visible", false)) or _stage > 0 or _story_event_cue_index > 0 or _finished
	if _caption and state.has("caption_text"):
		_caption.text = str(state.caption_text)
		_speaker_label.text = str(state.get("speaker_text", "MATHILDA"))
		_speaker_label.visible = not _speaker_label.text.is_empty()
		_set_caption_action(str(state.get("caption_action_text", "")) if bool(state.get("caption_action_visible", false)) else "")
		_resize_caption(_caption.text, _caption_action.visible)
		_speech_sprite.visible = bool(state.get("speech_visible", not _caption.text.is_empty()))
		_set_speaker(_speaker_label.text)
		_layout_caption()
	if _figure and state.has("figure_transform"):
		_figure.global_transform = state.figure_transform
	if _lantern and state.has("lantern_transform"):
		_lantern.global_transform = state.lantern_transform
		_lantern.visible = bool(state.get("lantern_visible", true))
	if _lantern_light:
		_lantern_light.light_energy = float(state.get("lantern_light_energy", _lantern_light.light_energy))
	if _lantern_flame and state.has("lantern_flame_scale"):
		_lantern_flame.scale = state.lantern_flame_scale
	if _warning_prop:
		_warning_prop.visible = bool(state.get("warning_prop_visible", _warning_prop.visible))
	if _figure:
		_figure.visible = int(_apparition_state) != ApparitionState.ABSENT
		_set_figure_moving(_figure_moving)
		_set_figure_dissolve(_apparition_dissolve)
		if _apparition_tween and _apparition_tween.is_running():
			_apparition_tween.kill()
		if _apparition_state == ApparitionState.LEAVING:
			var leave_time := APPARITION_FADE_SECONDS * (1.0 - _apparition_dissolve / APPARITION_DISSOLVE)
			_apparition_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_apparition_tween.tween_method(_set_figure_dissolve, _apparition_dissolve, APPARITION_DISSOLVE, maxf(leave_time, 0.01))
			_apparition_tween.tween_callback(_finish_figure_departure)
		elif _apparition_state == ApparitionState.RETURNING:
			var return_time := APPARITION_FADE_SECONDS * _apparition_dissolve / APPARITION_DISSOLVE
			_apparition_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_apparition_tween.tween_method(_set_figure_dissolve, _apparition_dissolve, 0.0, maxf(return_time, 0.01))
			_apparition_tween.tween_callback(_complete_figure_appearance)
	if _choice_panel:
		var labels: Array[String] = []
		for label: Variant in state.get("choice_labels", []):
			labels.append(str(label))
		if not labels.is_empty():
			_set_choice_rows(str(state.get("choice_title", "")), labels)
			_choice_hint.text = str(state.get("choice_hint", _choice_hint.text))
			_refresh_choices()
		_choice_panel.visible = bool(state.get("choice_visible", _choice_panel.visible))
	if _lantern_prompt:
		_lantern_prompt.visible = bool(state.get("lantern_prompt_visible", false))
	_refresh_dream_journal()
	if _dream_journal_open:
		_dream_journal_scrim.show()
		_dream_journal_panel.show()
	if _conversation_camera_returning:
		_complete_character_conversation()
	elif _conversation_camera_active:
		_conversation_camera_active = false
		_begin_character_conversation(_figure_rambling)
	if _figure_motion_active:
		var remaining := maxf(absf(_figure_motion_target_offset - _figure_offset) / 0.8, 0.18)
		_start_authored_figure_move(_figure_motion_target_offset, remaining, _figure_motion_look_at_player)
	if _figure_turn_active:
		var turn_distance := absf(wrapf(_figure_turn_target_yaw - _figure.rotation.y, -PI, PI))
		_turn_figure_to_yaw(_figure_turn_target_yaw, maxf(turn_distance / 1.4, 0.18))
	if _dream_journal_hint:
		_dream_journal_hint.text = _dream_return_context()
		_dream_journal_hint_time = 8.0
	if _dream_soundscape:
		_dream_soundscape.call("set_travel_quiet", _window_interval_active())
	if Game.weather:
		Game.weather.set_dream_quiet(maxf(_dream_quiet, _lantern_wind_quiet))
	if Game.player:
		Game.player.dialogue_locked = _dream_journal_open or _conversation_camera_active or _conversation_camera_returning or _conversation_waiting or _conversation_intro_waiting or _answer_open
		Game.player.set_dialogue_pose(_answer_open or _conversation_waiting or _conversation_intro_waiting or _station_dialogue_active,
			_conversation_response_pending and _conversation_waiting)


func _build_dream_route() -> void:
	if Game.trail == null:
		return
	_dream_route = DREAM_ROUTE_SCRIPT.new() as Node3D
	_dream_route.name = "DreamRoute"
	add_child(_dream_route)
	_dream_route.call("build", Game.trail)


func _build_dream_architecture() -> void:
	if Game.trail == null or _dream_route == null:
		return
	_memory_architecture = DREAM_ARCHITECTURE_SCRIPT.new() as DreamMemoryArchitecture
	_memory_architecture.name = "DreamMemoryArchitecture"
	add_child(_memory_architecture)
	_memory_architecture.build(Game.trail)
	_memory_architecture.cue_revealed.connect(_on_memory_cue_revealed)
	(_dream_route as DreamRoute).cue_requested.connect(_on_dream_cue_requested)


func _on_dream_cue_requested(cue_id: String, at: Transform3D) -> void:
	if _memory_architecture:
		_memory_architecture.anticipate(cue_id, at)


func _on_memory_cue_revealed(cue_id: String, at: Vector3) -> void:
	if cue_id != "clearing" and _dream_soundscape:
		_dream_soundscape.call("memory_cue", cue_id, at)


func _build_figure() -> void:
	_figure = FIGURE_SCENE.instantiate() as Node3D
	_figure.name = "UnrememberedFigure"
	_figure.scale = Vector3.ONE * 1.0
	_figure.visible = false
	add_child(_figure)
	_silhouette = ShaderMaterial.new()
	_silhouette.shader = preload("res://shaders/dream_shadow.gdshader")
	_silhouette.set_shader_parameter("shadow_tint", Color("080611"))
	_silhouette.set_shader_parameter("aura_tint", Color("32134f"))
	_silhouette.set_shader_parameter("opacity", 0.76)
	_silhouette.set_shader_parameter("dissolve", 0.0)
	for mesh_node in _figure.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		mesh.material_override = _silhouette
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_figure_aura_shell = MeshInstance3D.new()
	_figure_aura_shell.name = "MoodAuraShell"
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 1.0
	shell_mesh.height = 2.0
	shell_mesh.radial_segments = 48
	shell_mesh.rings = 24
	_figure_aura_shell.mesh = shell_mesh
	_figure_aura_shell.position = Vector3.UP * 1.03
	_figure_aura_shell.scale = Vector3(0.58, 1.05, 0.58)
	_figure_aura_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_figure_aura_material = ShaderMaterial.new()
	_figure_aura_material.shader = preload("res://shaders/mathilda_dream_aura.gdshader")
	_figure_aura_material.set_shader_parameter("mood_color", _figure_aura_color)
	_figure_aura_material.set_shader_parameter("intensity", 0.0)
	_figure_aura_shell.hide()
	_figure_aura_shell.material_override = _figure_aura_material
	_figure.add_child(_figure_aura_shell)
	_figure_aura_light = OmniLight3D.new()
	_figure_aura_light.name = "MathildaMoodAura"
	_figure_aura_light.position = Vector3(0.0, 1.05, 0.0)
	_figure_aura_light.light_color = _figure_aura_color
	_figure_aura_light.light_energy = 1.25
	_figure_aura_light.omni_range = 4.4
	_figure_aura_light.shadow_enabled = false
	_figure_aura_light.light_volumetric_fog_energy = 0.38
	_figure.add_child(_figure_aura_light)
	_animation = _figure.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation == null:
		for node in _figure.find_children("*", "AnimationPlayer", true, false):
			_animation = node as AnimationPlayer
			break
	if _animation:
		var chosen := ""
		for animation_name in _animation.get_animation_list():
			if String(animation_name).to_lower().contains("walk"):
				chosen = animation_name
				break
		if chosen == "" and not _animation.get_animation_list().is_empty():
			chosen = _animation.get_animation_list()[0]
		_walk_animation = chosen
		for animation_name in _animation.get_animation_list():
			var lowered := String(animation_name).to_lower()
			if _idle_animation == "" and (lowered.contains("idle") or lowered.contains("stand")):
				_idle_animation = String(animation_name)
	var particles := GPUParticles3D.new()
	particles.amount = 12 if Game.lean_graphics else 24
	particles.lifetime = 3.6
	particles.position = Vector3.UP * 0.85
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 35.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.32
	process.initial_velocity_min = 0.03
	process.initial_velocity_max = 0.12
	process.gravity = Vector3(0, 0.02, 0)
	process.scale_min = 0.12
	process.scale_max = 0.35
	var lifetime_gradient := Gradient.new()
	lifetime_gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	lifetime_gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var lifetime_texture := GradientTexture1D.new()
	lifetime_texture.gradient = lifetime_gradient
	process.color_ramp = lifetime_texture
	particles.process_material = process
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2(0.16, 0.16)
	_aura_mote_material = StandardMaterial3D.new()
	_aura_mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura_mote_material.albedo_color = Color(_figure_aura_color, 0.14)
	var mote_gradient := Gradient.new()
	mote_gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	mote_gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0)])
	var mote_texture := GradientTexture2D.new()
	mote_texture.gradient = mote_gradient
	mote_texture.width = 32
	mote_texture.height = 32
	mote_texture.fill = GradientTexture2D.FILL_RADIAL
	mote_texture.fill_from = Vector2(0.5, 0.5)
	mote_texture.fill_to = Vector2(1.0, 0.5)
	_aura_mote_material.albedo_texture = mote_texture
	_aura_mote_material.emission_enabled = true
	_aura_mote_material.emission = _figure_aura_color
	_aura_mote_material.emission_energy_multiplier = 0.4
	_aura_mote_material.vertex_color_use_as_albedo = true
	_aura_mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	particle_mesh.material = _aura_mote_material
	particles.draw_pass_1 = particle_mesh
	_figure.add_child(particles)
	if _walk_animation != "":
		_animation.play(_walk_animation, 0.35)
		_animation.pause()
	_build_boundary_shadow()


func _build_boundary_shadow() -> void:
	_boundary_shadow = MeshInstance3D.new()
	_boundary_shadow.name = "SharedSnowShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	_boundary_shadow.mesh = plane
	_boundary_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boundary_shadow.visible = false
	_boundary_material = ShaderMaterial.new()
	_boundary_material.shader = preload("res://shaders/dream_shadow_link.gdshader")
	_boundary_material.set_shader_parameter("strength", 0.0)
	_boundary_shadow.material_override = _boundary_material
	add_child(_boundary_shadow)


func _build_post_effect() -> void:
	var canvas := CanvasLayer.new()
	# Keep the screen-space post pass below every game UI canvas layer.
	canvas.layer = 19
	add_child(canvas)
	_aura_rect = ColorRect.new()
	_aura_rect.name = "DreamAura"
	_aura_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura_material = ShaderMaterial.new()
	_aura_material.shader = preload("res://shaders/dream_aura.gdshader")
	_aura_rect.material = _aura_material
	_aura_rect.visible = false
	canvas.add_child(_aura_rect)
	_post_rect = ColorRect.new()
	_post_rect.name = "DreamOptics"
	_post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_rect.visible = false
	_post_material = ShaderMaterial.new()
	_post_material.shader = preload("res://shaders/dream_warp.gdshader")
	_post_rect.material = _post_material
	canvas.add_child(_post_rect)


func _build_caption() -> void:
	_dream_ui_layer = CanvasLayer.new()
	_dream_ui_layer.name = "DreamInterface"
	_dream_ui_layer.layer = 21
	add_child(_dream_ui_layer)
	_dream_ui_root = Control.new()
	_dream_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dream_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dream_ui_layer.add_child(_dream_ui_root)
	_speech_view = SubViewport.new()
	_speech_view.name = "DreamSpeechViewport"
	_speech_view.size = Vector2i(CAPTION_VIEWPORT_WIDTH, 130)
	_speech_view.transparent_bg = true
	_speech_view.disable_3d = true
	_speech_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_speech_view)
	_speech_sprite = TextureRect.new()
	_speech_sprite.name = "DreamCaptionOverlay"
	_speech_sprite.texture = _speech_view.get_texture()
	_speech_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_speech_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_speech_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_sprite.visible = false
	_dream_ui_root.add_child(_speech_sprite)
	_speech_panel = PanelContainer.new()
	_speech_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var speech_style := UiChrome.term_box(Color(UiChrome.VOID, 0.94), Color(UiChrome.SIGNAL, 0.58), 1, 18)
	speech_style.border_width_left = 3
	_speech_panel.add_theme_stylebox_override("panel", speech_style)
	_speech_view.add_child(_speech_panel)
	var dialogue_column := VBoxContainer.new()
	dialogue_column.add_theme_constant_override("separation", 6)
	_speech_panel.add_child(dialogue_column)
	_speaker_label = UiChrome.term_label("", 14, UiChrome.SIGNAL)
	dialogue_column.add_child(_speaker_label)
	var subtitle_size: int = [24, 27, 32][clampi(Game.settings.subtitle_size, 0, 2)]
	_caption = UiChrome.term_label("", subtitle_size, UiChrome.BONE)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_column.add_child(_caption)
	_caption_action = UiChrome.key_row(Game.settings.key_label("interact"), "Continue")
	_caption_action.visible = false
	dialogue_column.add_child(_caption_action)
	_lantern_prompt = UiChrome.term_label("", 18, Color("e3c99c"))
	_lantern_prompt.name = "DreamLanternPrompt"
	_lantern_prompt.add_theme_color_override("font_outline_color", Color(0.012, 0.016, 0.024, 0.96))
	_lantern_prompt.add_theme_constant_override("outline_size", 3)
	_lantern_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lantern_prompt.custom_minimum_size = Vector2(0.0, 36.0)
	_lantern_prompt.size = Vector2(440.0, 36.0)
	_lantern_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lantern_prompt.visible = false
	_dream_ui_root.add_child(_lantern_prompt)
	_build_choice_panel()


func _build_dream_journal() -> void:
	_dream_journal_layer = CanvasLayer.new()
	_dream_journal_layer.name = "DreamJournalLayer"
	_dream_journal_layer.layer = 28
	add_child(_dream_journal_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dream_journal_layer.add_child(root)
	_dream_journal_hint_panel = PanelContainer.new()
	_dream_journal_hint_panel.name = "DreamClueProgress"
	_dream_journal_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dream_journal_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_style := UiChrome.term_box(Color(UiChrome.VOID, 0.82), Color(UiChrome.SIGNAL, 0.52), 1, 5)
	hint_style.border_width_left = 3
	_dream_journal_hint_panel.add_theme_stylebox_override("panel", hint_style)
	_dream_journal_hint_panel.hide()
	root.add_child(_dream_journal_hint_panel)
	_dream_journal_hint = UiChrome.term_label("", 17, UiChrome.BONE)
	_dream_journal_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dream_journal_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dream_journal_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dream_journal_hint_panel.add_child(_dream_journal_hint)
	_dream_journal_scrim = ColorRect.new()
	_dream_journal_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dream_journal_scrim.color = Color(0.012, 0.009, 0.011, 0.8)
	_dream_journal_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dream_journal_scrim.hide()
	root.add_child(_dream_journal_scrim)
	_dream_journal_panel = PanelContainer.new()
	_dream_journal_panel.set_anchors_preset(Control.PRESET_CENTER)
	var panel_style := UiChrome.term_box(UiChrome.VOID, Color(UiChrome.SIGNAL, 0.65), 1, 28)
	panel_style.border_width_left = 3
	_dream_journal_panel.add_theme_stylebox_override("panel", panel_style)
	_dream_journal_panel.hide()
	root.add_child(_dream_journal_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_dream_journal_panel.add_child(column)
	var title := UiChrome.term_label("DREAM JOURNAL", 27, UiChrome.BONE, true)
	column.add_child(title)
	var subtitle := UiChrome.term_label("Words kept from the path. %s toggles notes; %s closes." % [Game.settings.key_label("interact"), Game.settings.key_label("journal")], 15, UiChrome.ASH)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(subtitle)
	var divider := HSeparator.new()
	column.add_child(divider)
	_dream_journal_guidance_button = UiChrome.text_button("SHOW APPROACH NOTES")
	_dream_journal_guidance_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dream_journal_guidance_button.pressed.connect(_toggle_journal_guidance)
	column.add_child(_dream_journal_guidance_button)
	_dream_journal_scroll = ScrollContainer.new()
	_dream_journal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_dream_journal_scroll)
	_dream_journal_rows = VBoxContainer.new()
	_dream_journal_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dream_journal_rows.add_theme_constant_override("separation", 14)
	_dream_journal_scroll.add_child(_dream_journal_rows)
	var foot := UiChrome.term_label("The field pages are gone here. Mathilda's words make the record.", 13, UiChrome.ASH)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(foot)
	get_viewport().size_changed.connect(_layout_dream_journal)
	_layout_dream_journal()


func _layout_dream_journal() -> void:
	if _dream_journal_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(860.0, maxf(1.0, viewport_size.x - 32.0))
	var panel_height := minf(620.0, maxf(1.0, viewport_size.y - 32.0))
	_dream_journal_panel.offset_left = -panel_width * 0.5
	_dream_journal_panel.offset_right = panel_width * 0.5
	_dream_journal_panel.offset_top = -panel_height * 0.5
	_dream_journal_panel.offset_bottom = panel_height * 0.5
	var compact := viewport_size.x < 720.0 or viewport_size.y < 560.0
	var margin := 14.0 if compact else 28.0
	var panel_style := _dream_journal_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style:
		panel_style.set_content_margin_all(margin)
	var column := _dream_journal_panel.get_child(0) as VBoxContainer
	if column:
		column.add_theme_constant_override("separation", 8 if compact else 12)
	if _dream_journal_rows:
		_dream_journal_rows.add_theme_constant_override("separation", 10 if compact else 14)
	if _dream_journal_scroll:
		_dream_journal_scroll.custom_minimum_size.y = maxf(56.0 if compact else 80.0, panel_height - (204.0 if compact else 220.0))
	var toast_width := minf(600.0, maxf(1.0, viewport_size.x - 32.0))
	_dream_journal_hint_panel.offset_left = 16.0
	_dream_journal_hint_panel.offset_right = 16.0 + toast_width
	_dream_journal_hint_panel.offset_top = -136.0
	_dream_journal_hint_panel.offset_bottom = -24.0


func _record_dream_entry(raw_entry: Variant) -> void:
	if typeof(raw_entry) != TYPE_DICTIONARY:
		return
	var entry := (raw_entry as Dictionary).duplicate(true)
	var identifier := str(entry.get("id", ""))
	if identifier.is_empty() or _dream_journal_seen.has(identifier):
		return
	if str(entry.get("title", "")).strip_edges().is_empty() or str(entry.get("text", "")).strip_edges().is_empty():
		return
	if str(entry.get("place", "")).strip_edges().is_empty():
		entry["place"] = _dream_journal_place()
	_dream_journal_seen[identifier] = true
	_dream_journal_entries.append(entry)
	_dream_journal_available = true
	_refresh_dream_journal_hint()
	_dream_journal_hint_time = 4.5
	_refresh_dream_journal()


func _dream_journal_place() -> String:
	if _waking_card:
		return "AFTER THE WARNING"
	if Game.trail and Game.player:
		var progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
		if progress >= 64.0:
			return "THE CLEARING"
		if progress >= 46.0:
			return "THE WARM WINDOW"
		if progress >= 31.0:
			return "THE RED THREAD"
		if progress >= 15.0:
			return "THE THREE SISTERS"
	return "THE THRESHOLD"


func _refresh_dream_journal_hint() -> void:
	var entry: Dictionary = _dream_journal_entries.back() if not _dream_journal_entries.is_empty() else {}
	var title := str(entry.get("title", "AN OBSERVATION")).to_upper()
	var place := str(entry.get("place", "THE WINTER PATH"))
	_dream_journal_hint.text = "%s  ·  JOURNAL UPDATED\n%s  /  %s" % [Game.settings.key_label("journal"), place, title]


func _dream_return_context() -> String:
	var last_kept := "nothing written yet"
	if not _dream_journal_entries.is_empty():
		last_kept = str(_dream_journal_entries.back().get("title", "an observation"))
	var situation := "near the cabin threshold"
	if _waking_card:
		situation = "at the waking card"
	elif _dream_journal_open:
		situation = "with the journal open"
	elif _conversation_waiting:
		if _conversation_response_pending:
			situation = "your answer is still being heard"
		elif _conversation_response_ready:
			situation = "Mathilda has answered; the next turn is yours"
		else:
			situation = "the conversation is paused between turns"
	elif _conversation_intro_waiting:
		situation = "the clearing conversation is waiting for you"
	elif _answer_open:
		situation = "choosing how to answer Mathilda"
	elif _window_interval_active():
		situation = "walking from the window toward the clearing"
	elif _seen_story_cues.has("window"):
		situation = "beside the warm window"
	elif _seen_story_cues.has("thread"):
		situation = "beneath the lighthouse beam"
	elif _seen_story_cues.has("sisters"):
		situation = "past the cut trees"
	return "RETURNED TO THE DREAM\nLAST KEPT: %s  ·  NOW: %s" % [last_kept, situation]


func _update_dream_journal_hint(delta: float) -> void:
	if _dream_journal_hint_panel == null:
		return
	var dialogue_visible := (_speech_sprite and _speech_sprite.visible) or (_choice_panel and _choice_panel.visible)
	var toast_enabled := Game.settings == null or Game.settings.show_journal_toast
	var can_show := toast_enabled and Game.phase == Game.Phase.DREAM and not _dream_journal_open and not dialogue_visible and not _window_interval_active()
	_dream_journal_hint_panel.visible = can_show and _dream_journal_hint_time > 0.0
	if can_show:
		_dream_journal_hint_time = maxf(_dream_journal_hint_time - delta, 0.0)


func _refresh_dream_journal() -> void:
	if _dream_journal_rows == null:
		return
	if _dream_journal_guidance_button:
		_dream_journal_guidance_button.text = "HIDE APPROACH NOTES" if _journal_guidance_visible else "SHOW APPROACH NOTES"
	for child in _dream_journal_rows.get_children():
		_dream_journal_rows.remove_child(child)
		child.queue_free()
	for entry in _dream_journal_entries:
		var place := str(entry.get("place", "THE WINTER PATH"))
		var source := UiChrome.term_label("KEPT AT  ·  " + place, 12, UiChrome.SIGNAL)
		_dream_journal_rows.add_child(source)
		var title := UiChrome.term_label(str(entry.get("title", "")), 19, UiChrome.BONE, true)
		_dream_journal_rows.add_child(title)
		var text := UiChrome.term_label(str(entry.get("text", "")), 16, UiChrome.BONE)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dream_journal_rows.add_child(text)
		var approach := str(entry.get("approach", "")).strip_edges()
		if _journal_guidance_visible and not approach.is_empty():
			var guidance := UiChrome.term_label("A WAY THROUGH  ·  " + approach, 14, UiChrome.ASH)
			guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			guidance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_dream_journal_rows.add_child(guidance)
		var divider := HSeparator.new()
		_dream_journal_rows.add_child(divider)


func _toggle_journal_guidance() -> void:
	_journal_guidance_visible = not _journal_guidance_visible
	_refresh_dream_journal()


func _open_dream_journal() -> void:
	if not _dream_journal_available or _dream_journal_open:
		return
	_dream_journal_open = true
	if _memory_architecture:
		_memory_architecture.set_suspended(true)
	if _dream_soundscape:
		_dream_soundscape.call("set_suspended", true)
	_journal_speech_visible = _speech_sprite.visible if _speech_sprite else false
	_journal_choice_visible = _choice_panel.visible if _choice_panel else false
	_journal_lantern_visible = _lantern_prompt.visible if _lantern_prompt else false
	if _speech_sprite:
		_speech_sprite.hide()
	if _choice_panel:
		_choice_panel.hide()
	if _lantern_prompt:
		_lantern_prompt.hide()
	_dream_journal_scroll.scroll_vertical = 0
	if Game.player:
		Game.player.dialogue_locked = true
	_dream_journal_scrim.show()
	_dream_journal_panel.show()


func _close_dream_journal() -> void:
	if not _dream_journal_open:
		return
	_dream_journal_open = false
	if _memory_architecture:
		_memory_architecture.set_suspended(Game.phase == Game.Phase.PAUSED)
	if _dream_soundscape:
		_dream_soundscape.call("set_suspended", Game.phase == Game.Phase.PAUSED)
	_dream_journal_scrim.hide()
	_dream_journal_panel.hide()
	if _speech_sprite and _journal_speech_visible:
		_speech_sprite.show()
	if _choice_panel and _journal_choice_visible:
		_choice_panel.show()
	if _lantern_prompt and _journal_lantern_visible:
		_lantern_prompt.show()
	if Game.player:
		Game.player.dialogue_locked = _conversation_camera_active or _conversation_camera_returning or _conversation_waiting or _conversation_intro_waiting or _answer_open


func _cue_story_event(event: Dictionary) -> void:
	var cue_id := str(event.get("id", ""))
	if cue_id.is_empty() or _seen_story_cues.has(cue_id):
		return
	_seen_story_cues[cue_id] = true
	if _dream_route and _dream_route.has_method("cue_event"):
		_dream_route.call("cue_event", cue_id, float(event.get("offset", -1.0)))
	var event_talk: Dictionary = _story.get("event_talk", {})
	var journal_entry: Dictionary = event.get("journal", {})
	_queue_story_line(str(event.get("line", "")), str(event.get("motion", "")), journal_entry, int(event_talk.get(cue_id, -1)), cue_id)


func _layout_caption() -> void:
	if _speech_sprite and _speech_target and is_instance_valid(_speech_target):
		var anchor := _speech_target.global_position + Vector3.UP * 2.25
		var camera := get_viewport().get_camera_3d()
		var viewport_size := get_viewport().get_visible_rect().size
		if camera and viewport_size.y > 1.0:
			var screen := camera.unproject_position(anchor)
			var ui_scale := minf(viewport_size.y / 900.0 * CAPTION_SCREEN_SCALE, (viewport_size.x - 48.0) / float(CAPTION_VIEWPORT_WIDTH))
			var caption_size := Vector2(_speech_view.size) * ui_scale
			_speech_sprite.size = caption_size
			var half_width := caption_size.x * 0.5
			var safe_x := half_width + 24.0
			var safe_y := caption_size.y * 0.5 + 28.0
			var offscreen := camera.is_position_behind(anchor) or screen.x < safe_x or screen.x > viewport_size.x - safe_x or screen.y < safe_y or screen.y > viewport_size.y * 0.7
			if offscreen:
				caption_size *= 0.86
				_speech_sprite.size = caption_size
				safe_x = caption_size.x * 0.5 + 24.0
				safe_y = caption_size.y * 0.5 + 28.0
				if camera.is_position_behind(anchor):
					var side := _dialogue_screen_side(camera, anchor, screen)
					screen.x = safe_x if side < 0.0 else viewport_size.x - safe_x
					screen.y = viewport_size.y * 0.2
				screen.x = clampf(screen.x, safe_x, viewport_size.x - safe_x)
				screen.y = clampf(screen.y, safe_y, viewport_size.y * 0.7)
			screen.y = clampf(screen.y - caption_size.y * 0.5 - 12.0, safe_y, viewport_size.y * 0.7)
			_speech_sprite.position = screen - caption_size * 0.5
	if _lantern_prompt and _lantern and is_instance_valid(_lantern):
		var camera := get_viewport().get_camera_3d()
		if camera:
			var viewport_size := get_viewport().get_visible_rect().size
			var prompt_at := _lantern.global_position + Vector3.UP * 1.25
			var screen := camera.unproject_position(prompt_at)
			_lantern_prompt.size.x = minf(440.0, viewport_size.x * 0.5)
			if camera.is_position_behind(prompt_at):
				var side := _dialogue_screen_side(camera, prompt_at, screen)
				screen.x = viewport_size.x * (0.16 if side < 0.0 else 0.84)
				screen.y = viewport_size.y * 0.6
			screen.x = clampf(screen.x, _lantern_prompt.size.x * 0.5 + 12.0, viewport_size.x - _lantern_prompt.size.x * 0.5 - 12.0)
			screen.y = clampf(screen.y, 24.0, viewport_size.y - 24.0)
			_lantern_prompt.position = screen - _lantern_prompt.size * 0.5


func _dialogue_screen_side(camera: Camera3D, world_position: Vector3, screen_position: Vector2) -> float:
	if not camera.is_position_behind(world_position):
		return -1.0 if screen_position.x < get_viewport().get_visible_rect().size.x * 0.5 else 1.0
	var to_speaker := world_position - camera.global_position
	to_speaker.y = 0.0
	var camera_right := camera.global_basis.x
	camera_right.y = 0.0
	if camera_right.length_squared() > 0.0001:
		camera_right = camera_right.normalized()
	return -1.0 if to_speaker.dot(camera_right) < 0.0 else 1.0


func _player_crossed_dream_threshold() -> bool:
	if Game.house == null:
		return true
	var facing := Game.house.front_door_facing()
	var doorway := Game.house.front_door_approach() + facing * 1.65
	return (Game.player.global_position - doorway).dot(facing) >= 0.0


func _process(delta: float) -> void:
	_update_dream_journal_hint(delta)
	if _aura_rect:
		var dream_active := Game.phase == Game.Phase.DREAM and not _dream_journal_open
		_aura_rect.visible = dream_active
		if _aura_material:
			var screen_effects := float(Game.settings.screen_effects) if Game.settings else 1.0
			_aura_material.set_shader_parameter("intensity", 0.18 * clampf(screen_effects, 0.0, 1.0))
	if Game.player == null:
		return
	_layout_caption()
	_update_choice_positions()
	if _choice_panel and _choice_panel.visible:
		_choice_time += delta
		if _choice_index >= 0 and _choice_index < _choice_buttons.size():
			var selected_row := _choice_rows[_choice_index]
			selected_row.modulate.a = 0.94 + sin(_choice_time * 2.0) * 0.035
	_update_post_effect(delta)
	if Game.phase != Game.Phase.DREAM:
		return
	_update_figure_aura(delta)
	if _dream_journal_open:
		if Game.player and not Game.player.dialogue_locked:
			Game.player.dialogue_locked = true
		return
	_update_dream_quiet(delta)
	if _conversation_camera_active:
		_update_conversation_camera(delta)
	elif _conversation_camera_returning:
		_update_conversation_camera_return(delta)
	if _conversation_response_pending:
		_conversation_response_timer -= delta
		if _conversation_response_timer <= 0.0:
			_reveal_conversation_response()
	if _figure and not _figure_rambling and (_answer_open or _conversation_waiting or _conversation_intro_waiting):
		Game.player.face_toward(_figure.global_position, delta)
	_update_figure_apparition(delta)
	_update_boundary_shadow(delta)
	if _finished:
		return
	if not _dream_voice_unlocked:
		if _apparition_state == ApparitionState.PRESENT and _player_crossed_dream_threshold() and Game.player.global_position.distance_to(_figure.global_position) <= MATHILDA_APPROACH_DISTANCE:
			_dream_voice_unlocked = true
			_opening_station_pending = true
			_set_caption(str(_story.get("opening", "")), "MATHILDA")
			_story_line_active = true
			_story_line_hold = 6.5
		else:
			_update_figure(delta)
			_update_lantern(delta)
			return
	if _answer_open:
		var choice_mouse_mode := Input.MOUSE_MODE_VISIBLE if _choice_panel.visible else Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode != choice_mouse_mode:
			Input.mouse_mode = choice_mouse_mode
		return
	_update_story_lines(delta)
	if _story_line_active or _conversation_camera_returning:
		return
	_update_window_interval(delta)
	_update_figure(delta)
	_update_lantern(delta)
	var route_progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	_update_late_step_scene(delta, route_progress)
	_queue_reached_story_marker(route_progress)
	var beats: Array = _story.get("beats", [])
	var events: Array = _story.get("events", [])
	if _stage >= beats.size() and _story_event_cue_index >= events.size() and route_progress >= FIGURE_OFFSETS[FIGURE_OFFSETS.size() - 1] - 2.0:
		_story_finish_pending = true
		if not _story_line_active and _story_line_queue.is_empty() and _pending_station_rounds.is_empty() and not _station_dialogue_active and _story_gap_remaining <= 0.0:
			_finish_dream()


func _queue_reached_story_marker(route_progress: float) -> void:
	if _window_interval_active() or _apparition_state != ApparitionState.PRESENT or _story_line_active or not _story_line_queue.is_empty() or not _pending_station_rounds.is_empty() or _station_dialogue_active:
		return
	var beats: Array = _story.get("beats", [])
	var events: Array = _story.get("events", [])
	var beat_offset := INF
	if _stage < beats.size() and _stage < FIGURE_OFFSETS.size() - 1:
		beat_offset = FIGURE_OFFSETS[_stage] - 2.5
		if str(beats[_stage].get("id", "")) == "empty_path":
			beat_offset = maxf(beat_offset, CLEARING_APPROACH_OFFSET)
	var event_offset := INF
	if _story_event_cue_index < events.size():
		var event: Dictionary = events[_story_event_cue_index]
		event_offset = float(event.get("offset", 0.0))
	if beat_offset <= event_offset and route_progress >= beat_offset:
		if str(beats[_stage].get("id", "")) == "footsteps" and not _late_step_ready:
			return
		var beat: Dictionary = beats[_stage]
		_stage += 1
		_queue_story_line(str(beat.get("text", "")), str(beat.get("motion", "")), beat.get("journal", {}))
		var cue := "footstep"
		match str(beat.get("id", "")):
			"lantern":
				cue = "lantern"
			"empty_path":
				cue = "merge"
		_pulse_effect(0.72, cue)
	elif route_progress >= event_offset:
		var event: Dictionary = events[_story_event_cue_index]
		_story_event_cue_index += 1
		_cue_story_event(event)


func _update_late_step_scene(delta: float, route_progress: float) -> void:
	var beats: Array = _story.get("beats", [])
	if _stage >= beats.size() or str(beats[_stage].get("id", "")) != "footsteps" or _late_step_ready:
		return
	var cue_offset: float = FIGURE_OFFSETS[_stage] - 2.5
	if route_progress < cue_offset:
		return
	var speed := Vector2(Game.player.velocity.x, Game.player.velocity.z).length()
	if _late_step_dialogue_delay >= 0.0:
		_late_step_dialogue_delay = maxf(_late_step_dialogue_delay - delta, 0.0)
		if _late_step_dialogue_delay <= 0.0:
			_late_step_ready = true
		return
	if route_progress >= cue_offset + 5.0:
		_late_step_ready = true
		return
	if speed <= 0.28:
		_late_step_stop_time += delta
		if _late_step_stop_time >= 0.55:
			var player_offset := Game.trail.offset_of(Game.player.global_position)
			var step_frame := Game.trail.frame_at(maxf(Game.trail.player_start_offset, player_offset - 2.2))
			var answer_frame := Game.trail.frame_at(maxf(Game.trail.player_start_offset, player_offset - 1.5))
			_dream_soundscape.call("delayed_step_cue", Game.trail.on_ground(step_frame.origin), Game.trail.on_ground(answer_frame.origin))
			_late_step_dialogue_delay = 0.82
	else:
		_late_step_stop_time = 0.0


func _queue_story_line(line: String, motion: String = "", journal_entry: Dictionary = {}, station_round: int = -1, visual_cue: String = "") -> void:
	if line.strip_edges().is_empty():
		return
	_story_line_queue.append({"text": line, "motion": motion, "journal": journal_entry, "station_round": station_round, "visual_cue": visual_cue})
	if not _story_line_active and _story_gap_remaining <= 0.0 and _apparition_state == ApparitionState.PRESENT:
		_show_next_story_line()


func _show_next_story_line() -> void:
	if _story_line_queue.is_empty() or _apparition_state != ApparitionState.PRESENT:
		return
	_begin_character_conversation(true)
	var beat: Dictionary = _story_line_queue.pop_front()
	_station_after_line = int(beat.get("station_round", -1))
	var line := str(beat.get("text", ""))
	_record_dream_entry(beat.get("journal", {}))
	_play_story_choreography(str(beat.get("motion", "")))
	_set_caption(line, "MATHILDA", true, "Continue")
	var visual_cue := str(beat.get("visual_cue", ""))
	if not visual_cue.is_empty() and _memory_architecture:
		_memory_architecture.queue_reveal(visual_cue)
	_caption_time = 0.0
	_story_line_active = true
	var words := line.split(" ", false).size()
	_story_line_hold = clampf(float(words) / 2.6, 4.5, 8.0)


func _play_story_choreography(cue: String) -> void:
	if cue.is_empty() or _figure == null or Game.trail == null:
		return
	if _story_motion_tween and _story_motion_tween.is_running():
		_story_motion_tween.kill()
	_story_motion_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var start := _figure_offset
	var first_stop := start
	var final_stop := start
	var first_duration := 0.0
	var second_duration := 0.0
	var pause := 0.0
	var gaze_side := 0.0
	match cue:
		"cut_tree":
			# She advances a few measured steps, then looks into the cut tree line.
			first_stop = start + 1.2
			first_duration = 1.35
			gaze_side = -1.0
		"delayed_steps":
			# Two short approaches with a held beat between them, echoing the
			# heavier steps that answer only after Ophelia has stopped.
			first_stop = start + 0.7
			final_stop = start + 1.45
			first_duration = 0.82
			second_duration = 0.9
			pause = 0.62
			gaze_side = 0.0
		"lantern_witness":
			# She draws level with the turned lantern and lets the light pull her
			# attention toward the trees.
			first_stop = start + 0.8
			first_duration = 0.95
			gaze_side = 1.0
		"tracks_stop":
			# A measured approach, a hesitation, then one last step that ends
			# before the clearing can become a way out.
			first_stop = start + 1.05
			final_stop = start + 1.65
			first_duration = 1.1
			second_duration = 0.72
			pause = 0.55
			gaze_side = 2.0
		"tower_gaze":
			# She takes one step to the stair, then watches its upper landing.
			first_stop = start + 0.55
			first_duration = 0.82
			gaze_side = -1.0
		"window_gaze":
			# She keeps her distance from the sill and looks through the glass.
			first_stop = start + 0.35
			first_duration = 0.7
			gaze_side = 1.0
		"threshold_pause":
			# A half-step toward the doorway, a held choice, then a small return
			# to motion just as the second frame becomes visible.
			first_stop = start + 0.48
			final_stop = start + 0.76
			first_duration = 0.58
			second_duration = 0.66
			pause = 0.9
			gaze_side = -1.0
		_:
			_story_motion_tween.kill()
			return
	if gaze_side != 0.0:
		_set_rambling_gaze_from_route(gaze_side)
	_set_figure_moving(true)
	_story_motion_tween.tween_method(_set_figure_route_offset, start, first_stop, first_duration)
	if pause > 0.0:
		_story_motion_tween.tween_callback(_set_figure_moving.bind(false))
		_story_motion_tween.tween_interval(pause)
		_story_motion_tween.tween_callback(_set_figure_moving.bind(true))
		_story_motion_tween.tween_method(_set_figure_route_offset, first_stop, final_stop, second_duration)
	_story_motion_tween.tween_callback(_set_figure_moving.bind(false))
	if gaze_side == 0.0:
		_story_motion_tween.tween_callback(_turn_figure_toward_player)
	else:
		_story_motion_tween.tween_callback(_turn_figure_toward_rambling_gaze)


func _set_figure_route_offset(along: float) -> void:
	_figure_offset = along
	_place_figure(along)


func _start_authored_figure_move(target_offset: float, duration: float, look_at_player := false) -> void:
	if _figure == null or Game.trail == null:
		return
	if _figure_motion_tween and _figure_motion_tween.is_running():
		_figure_motion_tween.kill()
	_figure_motion_target_offset = clampf(target_offset, Game.trail.player_start_offset, Game.trail.length)
	_figure_motion_look_at_player = look_at_player
	_figure_motion_active = absf(_figure_motion_target_offset - _figure_offset) > 0.015
	if not _figure_motion_active:
		_finish_authored_figure_move()
		return
	_set_figure_moving(true)
	_figure_motion_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_figure_motion_tween.tween_method(_set_figure_route_offset, _figure_offset, _figure_motion_target_offset, maxf(duration, 0.12))
	_figure_motion_tween.tween_callback(_finish_authored_figure_move)


func _finish_authored_figure_move() -> void:
	_figure_motion_active = false
	_set_figure_moving(false)
	if _figure_motion_look_at_player and Game.player:
		_turn_figure_toward_point(Game.player.global_position, 0.7)
	_figure_motion_look_at_player = false


func _set_rambling_gaze_from_route(side_sign: float) -> void:
	var frame := Game.trail.frame_at(_figure_offset)
	var gaze_direction := -frame.basis.z * 5.0 if absf(side_sign) > 1.0 else frame.basis.x * side_sign * 5.0
	_rambling_gaze_target = frame.origin + gaze_direction + Vector3.UP * 1.3


func _turn_figure_toward_player() -> void:
	if _figure == null or Game.player == null:
		return
	var direction := Game.player.global_position - _figure.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(_figure, "rotation:y", target_yaw, 0.55)


func _turn_figure_toward_rambling_gaze() -> void:
	if _figure == null:
		return
	var direction := _rambling_gaze_target - _figure.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(_figure, "rotation:y", target_yaw, 0.65)


func _update_story_lines(delta: float) -> void:
	if _window_interval_active() and not _story_line_active:
		return
	if not _story_line_active and _apparition_state != ApparitionState.PRESENT:
		return
	if _story_line_active:
		_caption_time += delta
		if _caption_time >= _story_line_hold:
			_speech_sprite.modulate.a = move_toward(_speech_sprite.modulate.a, 0.0, delta * 1.2)
			if _speech_sprite.modulate.a <= 0.01:
				_speech_sprite.hide()
				_story_line_active = false
				_restore_character_conversation()
				if _station_after_line >= 0:
					_pending_station_rounds.append(_station_after_line)
					_station_after_line = -1
				if _opening_station_pending:
					_pending_station_rounds.append(0)
					_opening_station_pending = false
				_story_gap_remaining = 1.2 if not _story_line_queue.is_empty() or not _pending_station_rounds.is_empty() else 0.0
	elif _story_gap_remaining > 0.0:
		_story_gap_remaining = maxf(_story_gap_remaining - delta, 0.0)
	if not _story_line_active and _story_gap_remaining <= 0.0 and not _station_dialogue_active and not _answer_open:
		if not _pending_station_rounds.is_empty():
			_start_station_dialogue(_pending_station_rounds.pop_front())
		elif not _story_line_queue.is_empty():
			_show_next_story_line()
	if _story_finish_pending and not _story_line_active and _story_line_queue.is_empty() and _pending_station_rounds.is_empty() and not _station_dialogue_active and _story_gap_remaining <= 0.0:
		_finish_dream()


func _unhandled_input(event: InputEvent) -> void:
	if Game.phase == Game.Phase.DREAM and Game.dream_mode and event.is_action_pressed("journal"):
		if _dream_journal_open:
			_close_dream_journal()
		else:
			_open_dream_journal()
		get_viewport().set_input_as_handled()
		return
	if _dream_journal_open:
		if event.is_action_pressed("pause"):
			_close_dream_journal()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_toggle_journal_guidance()
		elif event.is_action_pressed("ui_up"):
			_dream_journal_scroll.scroll_vertical = maxi(_dream_journal_scroll.scroll_vertical - 120, 0)
		elif event.is_action_pressed("ui_down"):
			_dream_journal_scroll.scroll_vertical += 120
		get_viewport().set_input_as_handled()
		return
	if _waking_card and Game.phase == Game.Phase.DIALOGUE:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_return_to_menu()
			return
		if event.is_action_pressed("pause"):
			Game.toggle_pause()
			get_viewport().set_input_as_handled()
			return
	if (_answer_open or _conversation_waiting or _conversation_intro_waiting) and Game.phase == Game.Phase.DREAM:
		if event.is_action_pressed("pause"):
			Game.toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if _conversation_intro_waiting:
			if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
				_conversation_intro_waiting = false
				_build_small_talk_choices()
			get_viewport().set_input_as_handled()
			return
		if _conversation_waiting:
			if _is_dialogue_confirm(event):
				if _conversation_response_pending:
					_reveal_conversation_response()
				elif _conversation_response_ready:
					_conversation_response_ready = false
					_conversation_waiting = false
					if _station_dialogue_active:
						_continue_station_dialogue()
					elif _memory_chosen:
						_continue_memory_dialogue()
					elif _conversation_choice_advances:
						_conversation_round += 1
						_conversation_choice_advances = true
						_build_small_talk_choices()
					else:
						_conversation_choice_advances = true
						_build_small_talk_choices()
			get_viewport().set_input_as_handled()
			return
		if not _answer_open:
			return
		var quick_choice := UiChrome.dialogue_choice_index(event, _choice_buttons.size())
		if quick_choice >= 0:
			_set_choice_index(quick_choice)
			_choose_focused_memory()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_Y:
			var stick_y := (event as InputEventJoypadMotion).axis_value
			if absf(stick_y) < 0.28:
				_choice_axis_latched = false
			elif absf(stick_y) >= 0.68 and not _choice_axis_latched:
				_choice_axis_latched = true
				_focus_choice(1 if stick_y > 0.0 else -1)
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
			_focus_choice(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
			_focus_choice(1)
			get_viewport().set_input_as_handled()
		elif _is_dialogue_confirm(event):
			_choose_focused_memory()
			get_viewport().set_input_as_handled()
		return
	if not _finished and Game.phase == Game.Phase.DREAM and not _lantern_sheltered \
		and event.is_action_pressed("interact") and _lantern and Game.player \
		and Game.player.global_position.distance_to(_lantern.global_position) <= 3.2:
		_shelter_lantern()
		get_viewport().set_input_as_handled()
		return
	if _story_line_active and Game.phase == Game.Phase.DREAM and _is_dialogue_confirm(event):
		if _caption_time >= 2.0:
			_caption_time = _story_line_hold
			_speech_sprite.modulate.a = 0.0
		get_viewport().set_input_as_handled()
		return
	if _finished and _memory_chosen and Game.phase == Game.Phase.DREAM and _is_dialogue_confirm(event):
		if Game.dream_mode:
			_show_standalone_waking()
		elif not _ending_warning_shown:
			_ending_warning_shown = true
			_show_warning_prop()
			_set_caption(str(_story.get("ending", _story.get("arrival", ""))), "MATHILDA", false, "Wake")
		else:
			_wake()
		get_viewport().set_input_as_handled()


func _is_dialogue_confirm(event: InputEvent) -> bool:
	return event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")


func _update_figure(delta: float) -> void:
	if _figure == null or Game.trail == null or Game.player == null or _apparition_state != ApparitionState.PRESENT:
		return
	var player_progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	var goal_index := mini(_stage, FIGURE_OFFSETS.size() - 1)
	var authored_goal: float = Game.trail.player_start_offset + FIGURE_OFFSETS[goal_index]
	if _window_interval_active():
		authored_goal = Game.trail.player_start_offset + CLEARING_APPROACH_OFFSET + 3.0
		_figure_rambling = true
		if _window_interval_elapsed >= 0.9 and _window_interval_elapsed < 2.4:
			_rambling_gaze_target = _memory_architecture.cue_position("window") if _memory_architecture else Game.trail.position_at(Game.trail.player_start_offset + 46.0)
			_set_figure_moving(false)
			_place_figure(_figure_offset, delta)
			return
		_rambling_gaze_target = Game.trail.position_at(minf(_figure_offset + 6.0, Game.trail.length))
	var soft_limit := Game.trail.player_start_offset + maxf(player_progress + 6.0, FIGURE_OFFSETS[0])
	var target_offset := maxf(_figure_offset, minf(authored_goal, soft_limit))
	var moving := target_offset - _figure_offset > 0.08
	_set_figure_moving(moving)
	if moving:
		_figure_offset = move_toward(_figure_offset, target_offset, delta * 1.05)
	_place_figure(_figure_offset, delta)


func _update_boundary_shadow(delta: float) -> void:
	if _boundary_shadow == null or _figure == null or Game.trail == null or Game.player == null:
		return
	var between := _figure.global_position - Game.player.global_position
	between.y = 0.0
	var distance := between.length()
	var beats: Array = _story.get("beats", [])
	var merging := _stage >= beats.size() and _effect_cue == "merge" and _effect_strength > 0.01
	var screen_effects := clampf(Game.settings.screen_effects, 0.0, 1.0) if Game.settings else 1.0
	var merge_strength := _effect_strength * (0.08 + screen_effects * 0.3) if merging and distance <= 14.0 else 0.0
	var target_strength := maxf(merge_strength, _apparition_link_strength)
	_boundary_strength = move_toward(_boundary_strength, target_strength, delta * (0.34 if target_strength > _boundary_strength else 0.16))
	_boundary_material.set_shader_parameter("strength", _boundary_strength)
	_boundary_shadow.visible = _boundary_strength > 0.003 and distance > 0.1
	if not _boundary_shadow.visible:
		return
	var direction := between.normalized()
	var midpoint := (Game.player.global_position + _figure.global_position) * 0.5
	var target_position := Game.trail.on_ground(midpoint) + Vector3.UP * 0.045
	var blend := 1.0 - exp(-delta * 14.0)
	_boundary_shadow.global_position = _boundary_shadow.global_position.lerp(target_position, blend)
	var target_yaw := atan2(-direction.x, -direction.z)
	_boundary_shadow.global_rotation.y = lerp_angle(_boundary_shadow.global_rotation.y, target_yaw, blend)
	var span := minf(distance + 0.9, 14.0)
	_boundary_shadow.scale = _boundary_shadow.scale.lerp(Vector3(2.15, 1.0, span), blend)
	_boundary_material.set_shader_parameter("aspect", span / 2.15)


func _set_figure_moving(moving: bool) -> void:
	_figure_moving = moving
	if _animation == null:
		return
	if moving:
		if _walk_animation != "" and (_animation.current_animation != _walk_animation or not _animation.is_playing()):
			_animation.play(_walk_animation, 0.35)
	elif _idle_animation != "":
		if _animation.current_animation != _idle_animation or not _animation.is_playing():
			_animation.play(_idle_animation, 0.35)
	elif _animation.is_playing():
		_animation.pause()


func _begin_figure_appearance(duration: float) -> void:
	if _figure == null or _silhouette == null:
		return
	if _apparition_tween and _apparition_tween.is_running():
		_apparition_tween.kill()
	_figure.show()
	_apparition_state = ApparitionState.RETURNING
	_set_figure_dissolve(APPARITION_DISSOLVE)
	_apparition_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_apparition_tween.tween_method(_set_figure_dissolve, APPARITION_DISSOLVE, 0.0, duration)
	_apparition_tween.tween_callback(_complete_figure_appearance)


func _begin_figure_departure() -> void:
	if _figure == null or _silhouette == null or _apparition_state != ApparitionState.PRESENT:
		return
	if _apparition_tween and _apparition_tween.is_running():
		_apparition_tween.kill()
	_set_figure_moving(false)
	_apparition_state = ApparitionState.LEAVING
	_apparition_timer = APPARITION_MEMORY_SECONDS
	_apparition_link_strength = 0.2
	if _dream_soundscape:
		_dream_soundscape.call("apparition_footstep", _figure.global_position, false)
	_apparition_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_apparition_tween.tween_method(_set_figure_dissolve, _apparition_dissolve, APPARITION_DISSOLVE, APPARITION_FADE_SECONDS)
	_apparition_tween.tween_callback(_finish_figure_departure)


func _finish_figure_departure() -> void:
	if _apparition_state != ApparitionState.LEAVING:
		return
	_figure.hide()
	_apparition_state = ApparitionState.ABSENT


func _update_figure_apparition(delta: float) -> void:
	# Her absence lasts as long as the memory landscape. The paired return cue
	# lands just after it has folded away, even if the player stopped to look.
	if _apparition_state == ApparitionState.LEAVING or _apparition_state == ApparitionState.ABSENT:
		_apparition_timer = maxf(_apparition_timer - delta, 0.0)
		if _apparition_state == ApparitionState.ABSENT and _apparition_timer <= 0.0:
			_return_figure_to_path()


func _return_figure_to_path() -> void:
	if _figure == null or Game.trail == null or Game.player == null:
		return
	var player_offset := Game.trail.offset_of(Game.player.global_position)
	_figure_offset = maxf(_figure_offset, player_offset + 4.2)
	_place_figure(_figure_offset)
	_figure.show()
	_apparition_state = ApparitionState.RETURNING
	_apparition_link_strength = 0.0
	if _dream_soundscape:
		_dream_soundscape.call("apparition_footstep", _figure.global_position, true)
	_begin_figure_appearance(1.25)


func _set_figure_dissolve(value: float) -> void:
	_apparition_dissolve = clampf(value, 0.0, APPARITION_DISSOLVE)
	if _silhouette:
		_silhouette.set_shader_parameter("dissolve", _apparition_dissolve)
	if _figure_aura_light:
		var reveal := 1.0 - _apparition_dissolve / APPARITION_DISSOLVE
		_figure_aura_light.light_energy = 1.25 * reveal
	if _figure_aura_material:
		_figure_aura_material.set_shader_parameter("reveal", 1.0 - _apparition_dissolve / APPARITION_DISSOLVE)


func _complete_figure_appearance() -> void:
	_apparition_state = ApparitionState.PRESENT
	_apparition_tween = null
	_apparition_link_strength = 0.0
	_set_figure_dissolve(0.0)


func _update_figure_aura(delta: float) -> void:
	if _figure == null or _figure_aura_material == null:
		return
	_figure_aura_time += delta
	_figure_aura_pulse = move_toward(_figure_aura_pulse, 0.0, delta * 0.78)
	var target_color := _figure_aura_mood_color()
	_figure_aura_color = _figure_aura_color.lerp(target_color, 1.0 - exp(-delta * 3.2))
	var cue_pulse := maxf(_effect_strength, _figure_aura_pulse)
	var breath := 0.91 + sin(_figure_aura_time * 2.1) * 0.07 + sin(_figure_aura_time * 3.7) * 0.02
	var reveal := 1.0 - _apparition_dissolve / APPARITION_DISSOLVE
	var screen_effects := clampf(Game.settings.screen_effects, 0.0, 1.0) if Game.settings else 1.0
	var aura_intensity := (0.025 + cue_pulse * 0.22) * breath * screen_effects
	_figure_aura_shell.visible = aura_intensity > 0.045 and reveal > 0.01
	_figure_aura_shell.scale = Vector3(0.58, 1.05, 0.58) * (1.0 + cue_pulse * 0.075 + sin(_figure_aura_time * 1.4) * 0.018)
	_figure_aura_shell.rotation.y += delta * (0.16 + cue_pulse * 0.48)
	_figure_aura_material.set_shader_parameter("mood_color", _figure_aura_color)
	_figure_aura_material.set_shader_parameter("time", _figure_aura_time)
	_figure_aura_material.set_shader_parameter("pulse", cue_pulse)
	_figure_aura_material.set_shader_parameter("intensity", aura_intensity)
	_figure_aura_material.set_shader_parameter("reveal", reveal)
	_silhouette.set_shader_parameter("aura_tint", _figure_aura_color)
	if _figure_aura_light:
		_figure_aura_light.light_color = _figure_aura_color
		_figure_aura_light.light_energy = (0.35 + cue_pulse * 0.6) * breath * reveal * screen_effects
		_figure_aura_light.omni_range = 2.4 + cue_pulse * 1.2
	if _aura_mote_material:
		_aura_mote_material.albedo_color = Color(_figure_aura_color, (0.14 + cue_pulse * 0.08) * reveal * screen_effects)
		_aura_mote_material.emission = _figure_aura_color
		_aura_mote_material.emission_energy_multiplier = 0.4 + cue_pulse * 0.6


func _figure_aura_mood_color() -> Color:
	if _memory_chosen:
		match Game.dream_memory:
			"name":
				return Color("ffe1a0")
			"waiting":
				return Color("a8dfff")
			"remember":
				return Color("f6a8c8")
			"silence":
				return Color("a5b8e8")
			"walk_beside":
				return Color("b5e5cb")
			"present_need":
				return Color("ffd79a")
	if _station_choice_effect == "escalate" or _conversation_strain >= 4:
		return Color("ff435f")
	if _station_choice_effect == "push" or _conversation_strain > 0:
		return Color("f078a9")
	if _station_choice_effect == "repair":
		return Color("8ef2d1")
	match _effect_cue:
		"insight":
			return Color("fff0b5")
		"lantern":
			return Color("ffc66e")
		"merge":
			return Color("f19ae8")
		"release":
			return Color("9ceaff")
		"footstep":
			return Color("9e92ff")
	return Color("b58bff")


func _place_figure(along: float, delta: float = 0.0) -> void:
	if _figure == null or Game.trail == null:
		return
	var frame := Game.trail.frame_at(along)
	var across := frame.basis.x * 0.9
	_figure.global_position = Game.trail.on_ground(frame.origin + across) + Vector3.UP * 0.02
	var toward := _rambling_gaze_target - _figure.global_position if _figure_rambling else (Game.player.global_position - _figure.global_position if Game.player else -frame.basis.z)
	if _figure_moving:
		var ahead := Game.trail.frame_at(minf(along + 1.0, Game.trail.length)).origin
		toward = ahead + frame.basis.x * 0.9 - _figure.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		var target_yaw := atan2(-toward.x, -toward.z)
		var turn_blend := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 10.0)
		_figure.rotation.y = lerp_angle(_figure.rotation.y, target_yaw, turn_blend)


func _build_lantern() -> void:
	if Game.trail == null:
		return
	_lantern = Node3D.new()
	_lantern.name = "DreamLantern"
	add_child(_lantern)
	_lantern.global_position = _dream_route.call("world_position", "lantern")
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("171b24")
	iron.metallic = 0.72
	iron.roughness = 0.34
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.18
	base_mesh.bottom_radius = 0.23
	base_mesh.height = 0.16
	base.mesh = base_mesh
	base.material_override = iron
	base.position.y = 0.08
	_lantern.add_child(base)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.17
	cap_mesh.bottom_radius = 0.13
	cap_mesh.height = 0.06
	cap.mesh = cap_mesh
	cap.material_override = iron
	cap.position.y = 0.56
	_lantern.add_child(cap)
	for side in range(4):
		var angle := TAU * float(side) / 4.0 + PI * 0.25
		var strut := MeshInstance3D.new()
		var strut_mesh := CylinderMesh.new()
		strut_mesh.top_radius = 0.012
		strut_mesh.bottom_radius = 0.012
		strut_mesh.height = 0.39
		strut.mesh = strut_mesh
		strut.material_override = iron
		strut.position = Vector3(cos(angle) * 0.12, 0.34, sin(angle) * 0.12)
		_lantern.add_child(strut)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.78, 0.48, 0.22, 0.32)
	glass_material.emission_enabled = true
	glass_material.emission = Color("ff9e4c")
	glass_material.emission_energy_multiplier = 0.7
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var glass := MeshInstance3D.new()
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = 0.115
	glass_mesh.bottom_radius = 0.14
	glass_mesh.height = 0.36
	glass.mesh = glass_mesh
	glass.material_override = glass_material
	glass.position.y = 0.34
	_lantern.add_child(glass)
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.albedo_color = Color("ffb85c")
	flame_material.emission_enabled = true
	flame_material.emission = Color("ff8a38")
	flame_material.emission_energy_multiplier = 1.8
	_lantern_flame = MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.075
	flame_mesh.height = 0.21
	_lantern_flame.mesh = flame_mesh
	_lantern_flame.material_override = flame_material
	_lantern_flame.position.y = 0.36
	_lantern.add_child(_lantern_flame)
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color("ffc17d")
	_lantern_light.light_energy = 0.9
	_lantern_light.omni_range = 8.0
	_lantern_light.shadow_enabled = false
	_lantern_light.position.y = 0.5
	_lantern.add_child(_lantern_light)


func _build_warning_prop() -> void:
	if _dream_route == null or Game.trail == null:
		return
	var anchor: Transform3D = _dream_route.call("anchor", "answer")
	var across := anchor.basis.x
	across.y = 0.0
	across = across.normalized() if across.length_squared() > 0.001 else Vector3.RIGHT
	var ground := Game.trail.on_ground(anchor.origin + across * -1.8)
	_warning_prop = Node3D.new()
	_warning_prop.name = "TheCuttersAxe"
	_warning_prop.visible = false
	add_child(_warning_prop)
	_warning_prop.global_transform = Transform3D(anchor.basis, ground)

	var stump := PropFactory.spawn("SM_Env_Pine_Stump_01.fbx")
	if stump == null:
		return
	stump.name = "OldStump"
	stump.scale = Vector3(0.62, 0.48, 0.62)
	stump.position.y = 0.16
	_warning_prop.add_child(stump)
	var snow_material := StandardMaterial3D.new()
	snow_material.albedo_color = Color("b6c3cf")
	snow_material.roughness = 0.88
	var snow_cap_mesh := SphereMesh.new()
	snow_cap_mesh.radius = 0.5
	snow_cap_mesh.height = 0.5
	snow_cap_mesh.radial_segments = 20
	snow_cap_mesh.rings = 8
	var snow_cap := MeshInstance3D.new()
	snow_cap.name = "SnowOnStump"
	snow_cap.mesh = snow_cap_mesh
	snow_cap.material_override = snow_material
	snow_cap.scale = Vector3(0.3, 0.24, 0.3)
	snow_cap.position = Vector3(0.015, 0.69, -0.01)
	_warning_prop.add_child(snow_cap)

	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color("39281f")
	handle_material.roughness = 0.94
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.026
	handle_mesh.bottom_radius = 0.037
	handle_mesh.height = 0.94
	handle_mesh.radial_segments = 12
	var handle := MeshInstance3D.new()
	handle.name = "AxeHandle"
	handle.mesh = handle_mesh
	handle.material_override = handle_material
	handle.position = Vector3(0.24, 1.25, 0.0)
	handle.rotation = Vector3(0.38, 0.0, -0.34)
	_warning_prop.add_child(handle)

	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("92999e")
	head_material.metallic = 0.32
	head_material.roughness = 0.58
	var socket := MeshInstance3D.new()
	socket.name = "AxeHeadSocket"
	var socket_mesh := SphereMesh.new()
	socket_mesh.radius = 0.5
	socket_mesh.height = 1.0
	socket_mesh.radial_segments = 16
	socket_mesh.rings = 8
	socket.mesh = socket_mesh
	socket.material_override = head_material
	socket.scale = Vector3(0.115, 0.105, 0.075)
	socket.position = Vector3(0.18, 0.84, 0.0)
	_warning_prop.add_child(socket)
	var blade := MeshInstance3D.new()
	blade.name = "AxeBlade"
	blade.mesh = _build_axe_blade_mesh()
	var blade_material := head_material.duplicate() as StandardMaterial3D
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.material_override = blade_material
	blade.scale = Vector3(1.8, 1.42, 1.0)
	blade.position = Vector3(0.18, 0.84, 0.0)
	blade.rotation.y = PI * 0.5
	_warning_prop.add_child(blade)


func _build_axe_blade_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(0.075, -0.09), Vector2(0.075, 0.09), Vector2(0.015, 0.14),
		Vector2(-0.08, 0.15), Vector2(-0.22, 0.085), Vector2(-0.36, 0.015),
		Vector2(-0.33, -0.07), Vector2(-0.16, -0.15), Vector2(-0.045, -0.14),
	])
	var center := Vector2(-0.105, 0.0)
	var depth := 0.075
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(outline.size()):
		var point := outline[index]
		var next := outline[(index + 1) % outline.size()]
		surface.add_vertex(Vector3(center.x, center.y, depth * 0.5))
		surface.add_vertex(Vector3(point.x, point.y, depth * 0.5))
		surface.add_vertex(Vector3(next.x, next.y, depth * 0.5))
		surface.add_vertex(Vector3(center.x, center.y, -depth * 0.5))
		surface.add_vertex(Vector3(next.x, next.y, -depth * 0.5))
		surface.add_vertex(Vector3(point.x, point.y, -depth * 0.5))
		surface.add_vertex(Vector3(point.x, point.y, depth * 0.5))
		surface.add_vertex(Vector3(point.x, point.y, -depth * 0.5))
		surface.add_vertex(Vector3(next.x, next.y, -depth * 0.5))
		surface.add_vertex(Vector3(point.x, point.y, depth * 0.5))
		surface.add_vertex(Vector3(next.x, next.y, -depth * 0.5))
		surface.add_vertex(Vector3(next.x, next.y, depth * 0.5))
	surface.generate_normals()
	return surface.commit()


func _show_warning_prop() -> void:
	if is_instance_valid(_warning_prop):
		_warning_prop.show()


func _update_lantern(delta: float) -> void:
	if _lantern == null or Game.player == null:
		return
	_lantern_time += delta
	var distance := Game.player.global_position.distance_to(_lantern.global_position)
	var near := distance <= 3.2
	if distance <= 4.4:
		if _lantern_left_once and not _lantern_returned:
			_lantern_returned = true
			_pulse_effect(0.22, "lantern")
			if _silhouette:
				_silhouette.set_shader_parameter("lantern_warmth", 0.56)
			_lantern_wait = 0.0
		_lantern_seen = true
	elif _lantern_seen and distance >= 5.2:
		_lantern_left_once = true
	var horizontal_speed := Vector2(Game.player.velocity.x, Game.player.velocity.z).length()
	if near and not _lantern_sheltered and horizontal_speed < 0.28:
		_lantern_wait += delta
		if _lantern_wait >= 1.6:
			_shelter_lantern()
	else:
		_lantern_wait = 0.0
	if _lantern_prompt:
		var prompt_target := clampf(inverse_lerp(4.4, 2.8, distance), 0.0, 1.0) if Game.settings.show_prompts else 0.0
		_lantern_prompt.modulate.a = move_toward(_lantern_prompt.modulate.a, prompt_target, delta * 2.2)
		_lantern_prompt.visible = _lantern_prompt.modulate.a > 0.01
		var key := Game.settings.key_label("interact")
		if _lantern_sheltered:
			_lantern_prompt.text = "THE LIGHT HOLDS"
		elif _lantern_returned:
			_lantern_prompt.text = "YOU FOUND THE LIGHT AGAIN  ·  %s" % key
		else:
			_lantern_prompt.text = "SHELTER THE FLAME  ·  %s" % key
	if _lantern_light:
		var flicker := 0.992 + sin(_lantern_time * 4.1) * 0.018 + sin(_lantern_time * 6.3) * 0.008
		var steady_energy := 1.05 if _lantern_sheltered else (0.9 if _lantern_returned else 0.76)
		_lantern_light.light_energy = lerpf(_lantern_light.light_energy, steady_energy * flicker, delta * 2.0)
	if _lantern_flame:
		var breath := 1.0 if _lantern_sheltered else (0.98 + sin(_lantern_time * 3.8) * 0.02 if _lantern_returned else 0.96 + sin(_lantern_time * 3.8) * 0.04)
		_lantern_flame.scale = Vector3(1.0, breath, 1.0)
		var wind := Game.weather.wind if Game.weather else Vector3.ZERO
		var local_wind := _lantern.global_basis.inverse() * wind.normalized() if wind.length_squared() > 0.001 else Vector3.ZERO
		var exposure := 0.18 if _lantern_sheltered else (0.66 if _lantern_returned else 1.0)
		var lean := clampf(wind.length() / 16.0, 0.0, 1.0) * exposure * 0.14
		var target_rotation := Vector3(-local_wind.z * lean, 0.0, local_wind.x * lean)
		var turn := 1.0 - exp(-delta * 4.0)
		_lantern_flame.rotation.x = lerp_angle(_lantern_flame.rotation.x, target_rotation.x, turn)
		_lantern_flame.rotation.z = lerp_angle(_lantern_flame.rotation.z, target_rotation.z, turn)


func _shelter_lantern() -> void:
	_lantern_sheltered = true
	_lantern_wait = 0.0
	_pulse_effect(0.34, "lantern")
	if _silhouette:
		_silhouette.set_shader_parameter("lantern_warmth", 1.0)


func _update_dream_quiet(delta: float) -> void:
	if Game.weather == null or Game.trail == null or Game.player == null:
		return
	var lantern_quiet_target := 0.0
	if _lantern_seen and _lantern:
		var lantern_distance := Game.player.global_position.distance_to(_lantern.global_position)
		var proximity := 1.0 - smoothstep(2.5, LANTERN_WIND_REACH, lantern_distance)
		var care := LANTERN_SHELTER_QUIET if _lantern_sheltered else (LANTERN_RETURN_QUIET if _lantern_returned else 0.0)
		lantern_quiet_target = care * proximity
	_lantern_wind_quiet = move_toward(_lantern_wind_quiet, lantern_quiet_target, delta * 0.62)
	var target := 0.0
	if _window_interval_active():
		target = 0.48
	if _stage >= _story.get("beats", []).size() and not _memory_chosen:
		target = 0.68
	if _memory_chosen:
		_dream_quiet_after_response = maxf(_dream_quiet_after_response - delta, 0.0)
		target = 0.84 if _conversation_response_pending or _dream_quiet_after_response > 0.0 else 0.12
	_dream_quiet = move_toward(_dream_quiet, target, delta * (0.24 if target > _dream_quiet else 0.18))
	Game.weather.set_dream_quiet(maxf(_dream_quiet, _lantern_wind_quiet))


func _finish_dream() -> void:
	if _answer_open or _finished:
		return
	_answer_open = true
	if _memory_architecture:
		_memory_architecture.enter_clearing()
	_conversation_intro_waiting = true
	_conversation_round = 0
	_advance_unseen_talk_round()
	_conversation_waiting = false
	_set_figure_moving(false)
	_begin_character_conversation()
	_lantern_prompt.hide()
	_pulse_effect(0.72, "merge")
	_set_caption(str(_story.get("arrival", "")), "MATHILDA", false, "Continue")
	_layout_caption()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _begin_character_conversation(rambling := false) -> void:
	_figure_rambling = rambling
	if rambling:
		_set_figure_moving(false)
		if Game.player and Game.trail and _figure:
			var player_offset := Game.trail.offset_of(Game.player.global_position)
			var glance_offset := clampf(player_offset + 9.0 + float(posmod(_stage, 3)) * 3.5, 0.0, Game.trail.length)
			var glance_frame := Game.trail.frame_at(glance_offset)
			var away_side := -1.0 if posmod(_stage, 2) == 0 else 1.0
			var lifted := 4.0 if posmod(_stage, 2) == 0 else 1.2
			_rambling_gaze_target = glance_frame.origin + glance_frame.basis.x * away_side * 8.0 + Vector3.UP * lifted
		return
	if Game.player == null or _figure == null:
		return
	if _conversation_camera_returning:
		_complete_character_conversation()
	Game.player.dialogue_locked = true
	Game.player.set_dialogue_pose(true)
	_set_figure_moving(false)
	_lantern_prompt.hide()
	if _conversation_camera_active and _conversation_camera and is_instance_valid(_conversation_camera):
		return
	_turn_figure_toward_point(Game.player.global_position, 0.65)
	if not _camera_choreography_enabled or Game.player.camera == null:
		return
	if Game.player.global_position.distance_to(_figure.global_position) > CONVERSATION_CAMERA_REACH:
		return
	_return_camera = Game.player.camera
	_conversation_camera = Camera3D.new()
	_conversation_camera.name = "FixedConversationCamera"
	_conversation_camera.fov = _return_camera.fov
	_conversation_camera.near = _return_camera.near
	_conversation_camera.far = _return_camera.far
	add_child(_conversation_camera)
	_conversation_camera.global_transform = _return_camera.global_transform
	# Let the player's spring arm settle after spawning/loading before copying
	# its view into a camera that no longer follows the player rig.
	_conversation_camera_warmup = 0.18
	_conversation_camera_active = true


func _update_conversation_camera(delta: float) -> void:
	if _conversation_camera == null or not is_instance_valid(_conversation_camera) or Game.player == null or _figure == null:
		return
	if _conversation_camera_warmup > 0.0:
		_conversation_camera.global_transform = _return_camera.global_transform
		_conversation_camera_warmup = maxf(0.0, _conversation_camera_warmup - delta)
		if _conversation_camera_warmup <= 0.0:
			_conversation_camera.make_current()
		return
	var midpoint := (Game.player.global_position + _figure.global_position) * 0.5
	var frame := Game.trail.frame_at(Game.trail.offset_of(Game.player.global_position)) if Game.trail else Transform3D.IDENTITY
	var side := frame.basis.x
	side.y = 0.0
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	if (_figure.global_position - Game.player.global_position).dot(side) >= 0.0:
		side = -side
	var shot_index := clampi(_stage - 1, 0, SCENE_CAMERA_DISTANCE.size() - 1)
	var target_position: Vector3 = midpoint + side * SCENE_CAMERA_DISTANCE[shot_index] + Vector3.UP * SCENE_CAMERA_HEIGHT[shot_index]
	var look_target := midpoint + Vector3.UP * 1.0
	var weight := 1.0 - exp(-delta * 2.8)
	var safe_target := _clip_conversation_camera(look_target, target_position)
	if safe_target.distance_to(look_target) < 1.4:
		safe_target = _conversation_camera.global_position
	var next_position := _conversation_camera.global_position.lerp(safe_target, weight)
	_conversation_camera.global_position = _clip_conversation_camera(_conversation_camera.global_position, next_position)
	var target_basis := Basis.looking_at(look_target - _conversation_camera.global_position, Vector3.UP)
	_conversation_camera.global_basis = _conversation_camera.global_basis.slerp(target_basis, weight)


func _clip_conversation_camera(from: Vector3, to: Vector3) -> Vector3:
	var travel := to - from
	if travel.length_squared() < 0.0001:
		return to
	var available := travel.length()
	var right := _conversation_camera.global_basis.x * 0.16 if _conversation_camera else Vector3.RIGHT * 0.16
	for margin in [Vector3.ZERO, right, -right]:
		var query := PhysicsRayQueryParameters3D.create(from + margin, to + margin, Tune.LAYER_WORLD)
		if Game.player:
			query.exclude = [Game.player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			available = minf(available, maxf(0.0, (Vector3(hit.position) - from - margin).length() - 0.25))
	return from + travel.normalized() * available


func _restore_character_conversation(immediate := false) -> void:
	_conversation_camera_active = false
	_figure_rambling = false
	if _conversation_camera_warmup > 0.0:
		_complete_character_conversation()
		return
	if not immediate and _conversation_camera and is_instance_valid(_conversation_camera) and _return_camera and is_instance_valid(_return_camera):
		_conversation_camera_returning = true
		_conversation_camera_return_time = 0.42
		return
	_complete_character_conversation()


func _update_conversation_camera_return(delta: float) -> void:
	if _conversation_camera == null or not is_instance_valid(_conversation_camera) or _return_camera == null or not is_instance_valid(_return_camera):
		_complete_character_conversation()
		return
	var blend := 1.0 - exp(-delta * 9.0)
	var next_position := _conversation_camera.global_position.lerp(_return_camera.global_position, blend)
	_conversation_camera.global_position = _clip_conversation_camera(_conversation_camera.global_position, next_position)
	_conversation_camera.global_basis = _conversation_camera.global_basis.slerp(_return_camera.global_basis, blend)
	_conversation_camera_return_time -= delta
	if _conversation_camera_return_time <= 0.0:
		_complete_character_conversation()


func _complete_character_conversation() -> void:
	_conversation_camera_active = false
	_conversation_camera_returning = false
	_conversation_camera_warmup = 0.0
	if _return_camera and is_instance_valid(_return_camera):
		_return_camera.make_current()
	if _conversation_camera and is_instance_valid(_conversation_camera):
		_conversation_camera.queue_free()
	_conversation_camera = null
	_return_camera = null
	if Game.player:
		Game.player.dialogue_locked = false
		Game.player.set_dialogue_pose(false)


func _build_choices() -> void:
	_set_caption("")
	var branches: Array = _story.get("branches", [])
	var labels: Array[String] = []
	for branch in branches:
		labels.append(str(branch.get("label", "")))
	_set_choice_rows(str(_story.get("question", "")), labels)
	var guidance := str(_story.get("question_guidance", ""))
	if not guidance.is_empty():
		_choice_hint.text = "%s\n%s" % [guidance, _choice_hint.text]
	_choice_panel.show()
	_choice_index = 0
	_refresh_choices()


func _build_small_talk_choices() -> void:
	var rounds: Array = _story.get("small_talk", [])
	if _conversation_strain >= 2 and _repair_menu_attempts < 2:
		var repair: Dictionary = _story.get("repair", {})
		var repair_choices: Array = repair.get("choices", [])
		var repair_labels: Array[String] = []
		for choice in repair_choices:
			repair_labels.append(str(choice.get("label", "")))
		_repair_menu_attempts += 1
		_repair_menu_active = true
		_set_caption("")
		_set_choice_rows(str(repair.get("prompt", "")), repair_labels)
		_choice_hint.text = "%s\n%s" % [str(repair.get("guidance", "")), _choice_hint.text]
		_choice_index = 0
		_refresh_conversation_choices(repair_choices)
		_choice_panel.show()
		return
	_repair_menu_active = false
	var round_index := _station_round_index if _station_dialogue_active else _conversation_round
	if not _station_dialogue_active:
		_advance_unseen_talk_round()
		round_index = _conversation_round
	if round_index >= rounds.size():
		if _station_dialogue_active:
			_station_dialogue_active = false
			_station_round_index = -1
			_answer_open = false
			_choice_panel.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_restore_character_conversation()
			return
		_conversation_waiting = false
		_set_caption("")
		_build_choices()
		return
	_set_caption("")
	var round_data: Dictionary = rounds[round_index]
	var choices: Array = round_data.get("choices", [])
	var labels: Array[String] = []
	for choice in choices:
		labels.append(str(choice.get("label", "")))
	_set_choice_rows(str(round_data.get("prompt", "")), labels)
	var guidance := str(round_data.get("guidance", ""))
	if not guidance.is_empty():
		_choice_hint.text = "%s\n%s" % [guidance, _choice_hint.text]
	_choice_index = 0
	_refresh_conversation_choices(choices)
	_choice_panel.show()


func _start_station_dialogue(round_index: int) -> void:
	var rounds: Array = _story.get("small_talk", [])
	if round_index < 0 or round_index >= rounds.size() or _completed_talk_rounds.has(round_index):
		return
	_station_dialogue_active = true
	_station_round_index = round_index
	_station_choice_effect = ""
	_answer_open = true
	_conversation_waiting = false
	_conversation_intro_waiting = false
	_begin_character_conversation()
	_build_small_talk_choices()
	if Game.player:
		Game.player.dialogue_locked = true


func _continue_station_dialogue() -> void:
	if _station_choice_effect == "push" or _station_choice_effect == "escalate" or _station_choice_effect == "repair":
		_build_small_talk_choices()
		return
	var completed_round := _station_round_index
	_completed_talk_rounds[completed_round] = true
	_station_dialogue_active = false
	_station_round_index = -1
	_station_choice_effect = ""
	_answer_open = false
	_choice_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_restore_character_conversation()
	_story_gap_remaining = 0.7
	if completed_round == 2:
		_begin_window_interval()


func _window_interval_active() -> bool:
	return _window_interval_elapsed >= 0.0 and not _window_interval_complete


func _begin_window_interval() -> void:
	if _window_interval_active() or _window_interval_complete:
		return
	_window_interval_elapsed = 0.0
	_conversation_waiting = false
	_conversation_response_ready = false
	_set_caption("")
	if _dream_journal_hint_panel:
		_dream_journal_hint_panel.hide()
	if _dream_soundscape:
		_dream_soundscape.call("set_travel_quiet", true)


func _update_window_interval(delta: float) -> void:
	if not _window_interval_active():
		return
	_window_interval_elapsed += delta
	var progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	if _window_interval_elapsed < WINDOW_INTERVAL_SECONDS or progress < CLEARING_APPROACH_OFFSET:
		return
	_window_interval_complete = true
	_figure_rambling = false
	if _dream_soundscape:
		_dream_soundscape.call("set_travel_quiet", false)


func _advance_unseen_talk_round() -> void:
	var rounds: Array = _story.get("small_talk", [])
	while _conversation_round < rounds.size() and _completed_talk_rounds.has(_conversation_round):
		_conversation_round += 1


func _build_choice_panel() -> void:
	_choice_panel = Control.new()
	_choice_panel.name = "DreamConversationChoices"
	_choice_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_panel.visible = false
	_dream_ui_root.add_child(_choice_panel)
	_choice_title_back = Panel.new()
	_choice_title_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_style := UiChrome.term_box(Color(UiChrome.VOID, 0.9), Color(UiChrome.SIGNAL, 0.65), 1, 0)
	title_style.border_width_left = 3
	_choice_title_back.add_theme_stylebox_override("panel", title_style)
	_choice_panel.add_child(_choice_title_back)
	_choice_hint_back = Panel.new()
	_choice_hint_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_hint_back.add_theme_stylebox_override("panel", UiChrome.term_box(Color(UiChrome.VOID, 0.85), Color(UiChrome.BONE, 0.22), 1, 0))
	_choice_panel.add_child(_choice_hint_back)
	_choice_title = _new_choice_label(19)
	_choice_title.modulate = UiChrome.BONE
	_choice_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_choice_panel.add_child(_choice_title)
	_choice_hint = _new_choice_label(16)
	_choice_hint.modulate = Color(UiChrome.BONE, 0.82)
	_choice_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_choice_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_choice_panel.add_child(_choice_hint)


func _new_choice_label(font_size: int) -> Label:
	var label := UiChrome.term_label("", font_size, UiChrome.BONE)
	label.custom_minimum_size = Vector2(0.0, 28.0)
	label.add_theme_color_override("font_outline_color", Color(0.012, 0.016, 0.024, 0.97))
	label.add_theme_constant_override("outline_size", 3)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _set_choice_rows(title: String, labels: Array[String]) -> void:
	for child in _choice_panel.get_children():
		if child != _choice_title and child != _choice_hint and child != _choice_title_back and child != _choice_hint_back:
			_choice_panel.remove_child(child)
			child.queue_free()
	_choice_buttons.clear()
	_choice_rows.clear()
	_choice_title.text = title if _waking_card else "MATHILDA · %s" % title
	_choice_hint.text = "RETURN" if _waking_card else "YOU // REPLY"
	_set_caption_action("Return" if _waking_card else "")
	for index in range(labels.size()):
		# A plain Panel, not a PanelContainer: a container never shrinks below its
		# autowrapped label's minimum height, which stretched the rows over each
		# other; _update_choice_positions sizes the row and the label fills it.
		var row := Panel.new()
		row.name = "DreamChoiceRow%d" % (index + 1)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(_set_choice_index.bind(index))
		row.gui_input.connect(_on_dream_choice_gui_input.bind(index))
		_choice_panel.add_child(row)
		var choice_label := _new_choice_label(20 if labels.size() <= 4 else 18)
		choice_label.text = labels[index]
		choice_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		choice_label.offset_left = 14.0
		choice_label.offset_right = -12.0
		choice_label.offset_top = 5.0
		choice_label.offset_bottom = -5.0
		row.add_child(choice_label)
		_choice_rows.append(row)
		_choice_buttons.append(choice_label)
	if not labels.is_empty() and not _waking_card:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_choice_positions()


func _update_choice_positions() -> void:
	if not is_instance_valid(_choice_panel) or Game.player == null:
		return
	var speaker := _figure if _figure and is_instance_valid(_figure) else Game.player
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var speaker_at := speaker.global_position + Vector3.UP * 1.55
	var speaker_screen := camera.unproject_position(speaker_at)
	var label_width := minf(540.0, viewport_size.x * 0.36)
	var left_x := viewport_size.x * 0.23
	var right_x := viewport_size.x * 0.77
	var player_screen := camera.unproject_position(Game.player.global_position + Vector3.UP * 1.55)
	var left_score := absf(speaker_screen.x - left_x) + absf(player_screen.x - left_x) * 0.55
	var right_score := absf(speaker_screen.x - right_x) + absf(player_screen.x - right_x) * 0.55
	if speaker != Game.player and not camera.is_position_behind(speaker_at):
		# The speaker stays visible even when the player's side is the better
		# home for a reply panel during the camera's approach or return.
		var speaker_clearance := label_width * 0.5 + 64.0
		left_score -= maxf(0.0, speaker_clearance - absf(speaker_screen.x - left_x)) * 4.0
		right_score -= maxf(0.0, speaker_clearance - absf(speaker_screen.x - right_x)) * 4.0
	if is_instance_valid(_lantern) and _lantern.visible:
		var lantern_screen := camera.unproject_position(_lantern.global_position + Vector3.UP * 0.9)
		if not camera.is_position_behind(_lantern.global_position + Vector3.UP * 0.9):
			left_score -= maxf(0.0, label_width * 0.8 - absf(lantern_screen.x - left_x))
			right_score -= maxf(0.0, label_width * 0.8 - absf(lantern_screen.x - right_x))
	var side := -1.0 if left_score >= right_score else 1.0
	var center_x := left_x if side < 0.0 else right_x
	var row_height := 46.0
	var characters_per_line := maxi(int((label_width - 38.0) / 12.5), 16)
	for button in _choice_buttons:
		var line_count := maxi(1, ceili(float(button.text.length()) / float(characters_per_line)))
		row_height = maxf(row_height, float(line_count) * 26.0 + 16.0)
	var row_spacing := row_height + 8.0
	var row_half_height := float(_choice_buttons.size()) * row_spacing * 0.5
	label_width = minf(label_width, viewport_size.x * 0.42)
	var title_characters_per_line := maxi(int((label_width - 40.0) / 11.5), 12)
	var title_lines := maxi(1, ceili(float(_choice_title.text.length()) / float(title_characters_per_line)))
	var title_height := maxf(30.0, float(title_lines) * 25.0)
	# Measured from the wrapped label itself; a characters-per-line guess left the
	# guidance spilling out of its box at the real font.
	_choice_hint.size.x = label_width - 24.0
	var hint_line := float(_choice_hint.get_line_height() + _choice_hint.get_theme_constant("line_spacing"))
	var hint_height := maxf(24.0, float(_choice_hint.get_line_count()) * hint_line + 4.0)
	var center_margin := maxf(row_half_height + title_height + 20.0, row_half_height + hint_height + 36.0)
	center_margin = minf(center_margin, viewport_size.y * 0.47)
	var center_y := clampf(viewport_size.y * 0.55, center_margin, viewport_size.y - center_margin)
	_choice_title_back.size = Vector2(label_width, title_height)
	_choice_title_back.position = Vector2(center_x - label_width * 0.5, center_y - row_half_height - title_height - 12.0)
	_choice_title.size = Vector2(label_width - 24.0, title_height - 8.0)
	_choice_title.position = _choice_title_back.position + Vector2(12.0, 4.0)
	_choice_hint_back.size = Vector2(label_width, hint_height + 12.0)
	_choice_hint_back.position = Vector2(center_x - label_width * 0.5, center_y + row_half_height + 16.0)
	_choice_hint.size = Vector2(label_width - 24.0, hint_height)
	_choice_hint.position = _choice_hint_back.position + Vector2(12.0, 6.0)
	for index in _choice_buttons.size():
		var button := _choice_buttons[index]
		var row := _choice_rows[index]
		row.size = Vector2(label_width, row_height)
		row.position = Vector2(center_x - label_width * 0.5, center_y - row_half_height + float(index) * row_spacing)


func _choose_small_talk(index: int) -> void:
	var round_data: Dictionary
	if _repair_menu_active:
		round_data = _story.get("repair", {})
	else:
		var rounds: Array = _story.get("small_talk", [])
		var round_index := _station_round_index if _station_dialogue_active else _conversation_round
		if round_index < 0 or round_index >= rounds.size():
			return
		round_data = rounds[round_index]
	var choices: Array = round_data.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	var effect := str(choice.get("effect", ""))
	_station_choice_effect = effect
	if _memory_architecture:
		_memory_architecture.respond(effect)
	if effect == "push" or effect == "escalate":
		_conversation_strain += 2
		_pulse_effect(0.88, "doubt", _figure)
		if Game.player:
			Game.player.react_to_dialogue("recoil")
	elif effect == "repair":
		_conversation_strain = 0
		_pulse_effect(0.72, "release", _figure)
		if Game.player:
			Game.player.react_to_dialogue("release")
	else:
		_pulse_effect(0.34, "footstep", _figure)
		if Game.player:
			Game.player.react_to_dialogue("uncertain")
	_repair_menu_active = false
	_conversation_choice_advances = bool(choice.get("advance", true))
	_choice_panel.hide()
	_record_dream_entry(choice.get("journal", {}))
	_set_caption("")
	_begin_dialogue_exchange(str(choice.get("label", "")), str(choice.get("response", "")))
	_lantern_prompt.hide()
	_layout_caption()


func _begin_dialogue_exchange(player_line: String, mathilda_line: String) -> void:
	_conversation_waiting = true
	_conversation_response_pending = true
	_conversation_response_ready = false
	# Give the chosen words their own readable turn before Mathilda answers.
	# Confirmation can still move the exchange forward at the player's pace.
	_conversation_response_timer = clampf(1.1 + player_line.length() * 0.065, 2.6, 7.0)
	_conversation_response = mathilda_line
	_set_caption(player_line, "YOU", false, "Listen")


func _reveal_conversation_response() -> void:
	if not _conversation_response_pending:
		return
	_conversation_response_pending = false
	_conversation_response_ready = true
	if _memory_chosen:
		_dream_quiet_after_response = 4.5
	_set_caption(_conversation_response, "MATHILDA", false, "Continue")


func _continue_memory_dialogue() -> void:
	if Game.dream_mode:
		_show_standalone_waking()
	elif not _ending_warning_shown:
		_ending_warning_shown = true
		_show_warning_prop()
		_set_caption(_ending_text(), "MATHILDA", false, "Wake")
	else:
		_wake()


func _refresh_conversation_choices(choices: Array) -> void:
	for index in range(mini(_choice_buttons.size(), choices.size())):
		_style_choice(index, str(choices[index].get("label", "")))


func _focus_choice(direction: int) -> void:
	if _choice_buttons.is_empty():
		return
	_choice_index = posmod(_choice_index + direction, _choice_buttons.size())
	_refresh_choices()


func _set_choice_index(index: int) -> void:
	if index < 0 or index >= _choice_buttons.size():
		return
	_choice_index = index
	_refresh_choices()


func _on_dream_choice_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_choice_index(index)
		_choose_focused_memory()
		get_viewport().set_input_as_handled()


func _style_choice(index: int, text: String) -> void:
	if index < 0 or index >= _choice_buttons.size() or index >= _choice_rows.size():
		return
	var label := _choice_buttons[index]
	var row := _choice_rows[index]
	var selected := index == _choice_index
	label.text = ("▸ " if selected else "  ") + "%d  %s" % [index + 1, text]
	label.modulate = UiChrome.BONE if selected else Color(UiChrome.BONE, 0.72)
	var border_color := UiChrome.SIGNAL if selected else UiChrome.BONE
	border_color.a = 0.76 if selected else 0.34
	var style := UiChrome.term_box(
		Color(UiChrome.VOID, 0.94 if selected else 0.78),
		border_color,
		2 if selected else 1,
		8
	)
	style.border_width_left = 4 if selected else 1
	row.add_theme_stylebox_override("panel", style)
	row.modulate.a = 1.0


func _refresh_choices() -> void:
	if _repair_menu_active:
		var repair: Dictionary = _story.get("repair", {})
		_refresh_conversation_choices(repair.get("choices", []))
		return
	var rounds: Array = _story.get("small_talk", [])
	var round_index := _station_round_index if _station_dialogue_active else _conversation_round
	if _answer_open and not _conversation_waiting and round_index < rounds.size():
		var round_data: Dictionary = rounds[round_index]
		_refresh_conversation_choices(round_data.get("choices", []))
		return
	var branches: Array = _story.get("branches", [])
	for index in range(mini(_choice_buttons.size(), branches.size())):
		_style_choice(index, str(branches[index].get("label", "")))


func _choose_focused_memory() -> void:
	var rounds: Array = _story.get("small_talk", [])
	var round_index := _station_round_index if _station_dialogue_active else _conversation_round
	if _answer_open and round_index < rounds.size():
		_choose_small_talk(_choice_index)
		return
	var branches: Array = _story.get("branches", [])
	if _choice_index >= 0 and _choice_index < branches.size():
		_choose_memory(str(branches[_choice_index].get("id", "")))


func _choose_memory(memory: String) -> void:
	if not _answer_open:
		return
	var branch := STORY.branch_for(_story, memory)
	if branch.is_empty():
		return
	Game.save_dream_memory(memory)
	_record_dream_entry(branch.get("journal", {}))
	_memory_chosen = true
	_finished = true
	_answer_open = false
	_choice_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pulse_effect(0.42, "release")
	_layout_caption()
	_react_to_answer(memory)
	var response := str(branch.get("response", "")).replace("\nPress E to wake.", "")
	_begin_dialogue_exchange(str(branch.get("label", "")), response)
	_lantern_prompt.hide()
	_layout_caption()


func _react_to_answer(memory: String) -> void:
	if _figure == null or Game.player == null:
		return
	if _story_motion_tween and _story_motion_tween.is_running():
		_story_motion_tween.kill()
	_set_figure_moving(false)
	match memory:
		"name":
			_turn_figure_toward_point(Game.player.global_position, 0.7)
		"waiting":
			# Stillness is accepted without drawing Mathilda closer.
			_figure_aura_pulse = 0.12
			_turn_figure_toward_point(Game.player.global_position, 0.8)
		"remember":
			var ahead := Game.trail.frame_at(minf(_figure_offset + 7.0, Game.trail.length)).origin if Game.trail else _figure.global_position + Vector3.FORWARD
			_turn_figure_toward_point(ahead, 0.8)
		"silence":
			var house_point := Game.house.spawn_point() if Game.house else _figure.global_position + Vector3.BACK
			_turn_figure_toward_point(house_point, 0.8)
		"walk_beside":
			var player_offset := Game.trail.offset_of(Game.player.global_position) if Game.trail else _figure_offset
			var beside_offset := minf(player_offset + 2.45, Game.trail.length) if Game.trail else _figure_offset
			# Company does not require closing a distant gap in a single gesture.
			beside_offset = clampf(beside_offset, _figure_offset - 1.6, _figure_offset + 1.6)
			var duration := maxf(0.9, absf(beside_offset - _figure_offset) / 0.8)
			_start_authored_figure_move(beside_offset, duration, true)
		"present_need":
			var light_at := _lantern.global_position if is_instance_valid(_lantern) else _figure.global_position + Vector3.FORWARD
			if not is_instance_valid(_lantern) and _memory_architecture:
				light_at = _memory_architecture.cue_position("clearing")
			_turn_figure_toward_point(light_at, 0.8)


func _turn_figure_toward_point(point: Vector3, duration: float) -> void:
	if _figure == null:
		return
	var direction := point - _figure.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	_turn_figure_to_yaw(target_yaw, duration)


func _turn_figure_to_yaw(target_yaw: float, duration: float) -> void:
	if _figure == null:
		return
	if _figure_turn_tween and _figure_turn_tween.is_running():
		_figure_turn_tween.kill()
	_figure_turn_target_yaw = _figure.rotation.y + wrapf(target_yaw - _figure.rotation.y, -PI, PI)
	_figure_turn_active = absf(_figure_turn_target_yaw - _figure.rotation.y) > 0.01
	if not _figure_turn_active:
		return
	_figure_turn_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_figure_turn_tween.tween_property(_figure, "rotation:y", _figure_turn_target_yaw, maxf(duration, 0.12))
	_figure_turn_tween.tween_callback(_finish_figure_turn)


func _finish_figure_turn() -> void:
	_figure_turn_active = false


func _wake() -> void:
	Game.complete_dream()
	if Game.dream_mode:
		_show_standalone_waking()
		return
	_restore_character_conversation(true)
	Game.dream_mode = false
	Game.player.global_position = Game.house.spawn_point() if Game.house else Game.player.global_position
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()
	var reflection := preload("res://scripts/ui/dream_reflection.gd").new()
	reflection.set("memory", Game.dream_memory)
	reflection.set("mathilda", Game.mathilda_pov)
	reflection.set("outcome", _dream_outcome)
	get_tree().current_scene.add_child(reflection)
	if Game.mathilda_pov:
		get_tree().current_scene.add_child(preload("res://scripts/player/mathilda_pov.gd").new())
	else:
		# The waking phase brings Ophelia's ordinary story systems into this world.
		get_tree().current_scene.add_child(Voice.new())
		get_tree().current_scene.add_child(Encounters.new())
		get_tree().current_scene.add_child(DialogueBubble.new())
		Game.begin_intro()
	queue_free()


func _show_standalone_waking() -> void:
	_waking_card = true
	_show_warning_prop()
	_set_caption(_ending_text(), "MATHILDA")
	_lantern_prompt.hide()
	_set_choice_rows("THE LIGHT REMAINS", [])
	Game.set_phase(Game.Phase.DIALOGUE)
	_choice_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ending_text() -> String:
	var result := ""
	if _conversation_strain >= 4:
		_dream_understood = false
		_dream_outcome = "ruptured"
		var ruptured: Dictionary = _story.get("ruptured", {})
		_record_dream_entry(ruptured.get("journal", {}))
		result = str(ruptured.get("response", _story.get("arrival", "")))
	else:
		_dream_understood = _seen_story_cues.has("window") and _seen_story_cues.size() >= 2
		if _dream_understood:
			_dream_outcome = "complete"
			result = str(_story.get("ending", _story.get("arrival", "")))
		else:
			var unresolved: Dictionary = _story.get("unresolved", {})
			_dream_outcome = "unresolved"
			_record_dream_entry(unresolved.get("journal", {}))
			result = str(unresolved.get("response", _story.get("arrival", "")))
	if _memory_architecture:
		_memory_architecture.settle(_dream_outcome)
	_compose_waking_scene()
	return result


func _compose_waking_scene() -> void:
	if _figure == null or Game.player == null:
		return
	if _story_motion_tween and _story_motion_tween.is_running():
		_story_motion_tween.kill()
	_set_figure_moving(false)
	match _dream_outcome:
		"complete":
			_turn_figure_toward_point(Game.player.global_position, 0.9)
		"unresolved":
			var window_at := _memory_architecture.cue_position("window") if _memory_architecture else _figure.global_position + Vector3.FORWARD
			_turn_figure_toward_point(window_at, 0.9)
		"ruptured":
			# She turns out of the exchange and takes one measured step. The
			# warning remains readable while she chooses to leave the conversation.
			var exit_offset := minf(_figure_offset + 0.75, Game.trail.length) if Game.trail else _figure_offset
			_start_authored_figure_move(exit_offset, 0.95)
			_figure_aura_pulse = 0.28


func _return_to_menu() -> void:
	# The standalone dream exits from its waking card rather than through
	# _wake(), so commit completion at this final handoff as well.
	Game.complete_dream()
	_restore_character_conversation(true)
	Game.dream_mode = false
	Game.mathilda_pov = false
	Game.character_selected = false
	Game.set_phase(Game.Phase.BOOT)
	get_tree().reload_current_scene()


func _set_caption(line: String, speaker := "", preserve_story_queue := false, action := "") -> void:
	_story_line_active = false
	if not preserve_story_queue and not _station_dialogue_active:
		_story_line_queue.clear()
	_story_gap_remaining = 0.0
	_set_speaker(speaker)
	if Game.player and Game.player.dialogue_locked and not line.is_empty():
		Game.player.set_dialogue_pose(true, speaker.to_upper() == "YOU")
	_caption.text = line
	_set_caption_action(action)
	_resize_caption(line, not action.is_empty())
	_speech_sprite.visible = not line.is_empty()
	_speech_sprite.modulate.a = 0.0
	_caption_time = 0.0
	if _caption_tween and _caption_tween.is_running():
		_caption_tween.kill()
	if not line.is_empty():
		_caption_tween = create_tween()
		_caption_tween.tween_property(_speech_sprite, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_layout_caption()


func _resize_caption(line: String, include_action: bool) -> void:
	var font_size := _caption.get_theme_font_size("font_size")
	var estimated_lines := maxi(1, ceili(float(line.length()) / (58.0 * 27.0 / float(font_size))))
	var content_height := 54 + estimated_lines * ceili(38.0 * float(font_size) / 27.0) + (32 if include_action else 0)
	_speech_view.size = Vector2i(CAPTION_VIEWPORT_WIDTH, clampi(content_height, 92, 320))


func _set_caption_action(caption: String) -> void:
	if not is_instance_valid(_caption_action):
		return
	_caption_action.visible = not caption.is_empty()
	if caption.is_empty():
		return
	UiChrome.set_key(_caption_action, Game.settings.key_label("interact"))
	(_caption_action.get_child(1) as Label).text = caption


func _set_speaker(speaker: String) -> void:
	_speaker_label.text = speaker.to_upper()
	_speaker_label.visible = not speaker.is_empty()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if speaker == "YOU":
		_speech_target = Game.player
	else:
		_speech_target = _figure if _figure and is_instance_valid(_figure) else Game.player
	_layout_caption()


func _on_game_phase_changed(next: Game.Phase) -> void:
	if next == Game.Phase.PAUSED:
		if _memory_architecture:
			_memory_architecture.set_suspended(true)
		if _dream_soundscape:
			_dream_soundscape.call("set_suspended", true)
		if _dialogue_ui_hidden_for_pause:
			return
		_pause_speech_visible = is_instance_valid(_speech_sprite) and _speech_sprite.visible
		_pause_choice_panel_visible = is_instance_valid(_choice_panel) and _choice_panel.visible
		_pause_lantern_prompt_visible = is_instance_valid(_lantern_prompt) and _lantern_prompt.visible
		if is_instance_valid(_speech_sprite):
			_speech_sprite.hide()
		if is_instance_valid(_choice_panel):
			_choice_panel.hide()
		if is_instance_valid(_lantern_prompt):
			_lantern_prompt.hide()
		_dialogue_ui_hidden_for_pause = true
		return
	if not _dialogue_ui_hidden_for_pause:
		return
	_dialogue_ui_hidden_for_pause = false
	if _dream_soundscape:
		_dream_soundscape.call("set_suspended", _dream_journal_open)
	if next == Game.Phase.DREAM or next == Game.Phase.DIALOGUE:
		if _memory_architecture:
			_memory_architecture.set_suspended(_dream_journal_open)
		if is_instance_valid(_speech_sprite):
			_speech_sprite.visible = _pause_speech_visible
		if is_instance_valid(_choice_panel):
			_choice_panel.visible = _pause_choice_panel_visible
		if is_instance_valid(_lantern_prompt):
			_lantern_prompt.visible = _pause_lantern_prompt_visible


func _pulse_effect(strength: float, cue := "doubt", focus: Node3D = null) -> void:
	_effect_target = strength
	_effect_hold = 0.2 if cue == "insight" else 1.4
	_effect_cue = cue
	_effect_focus = focus
	_figure_aura_pulse = maxf(_figure_aura_pulse, strength)


func _update_post_effect(delta: float) -> void:
	_effect_hold = maxf(_effect_hold - delta, 0.0)
	if _effect_hold <= 0.0:
		_effect_target = 0.0
	var effect_rate := 6.0 if _effect_cue == "insight" and _effect_target > _effect_strength else 2.7 if _effect_cue == "insight" else 1.15 if _effect_target > _effect_strength else 0.24
	_effect_strength = move_toward(_effect_strength, _effect_target, delta * effect_rate)
	var screen_effects := clampf(Game.settings.screen_effects, 0.0, 1.0) if Game.settings else 1.0
	var visible_strength := _effect_strength * screen_effects
	var dream_active := Game.phase == Game.Phase.DREAM and not _dream_journal_open
	if dream_active:
		_dream_elapsed += delta
	var dream_weight := 0.52 * screen_effects if dream_active else 0.0
	if _post_rect:
		_post_rect.visible = dream_weight > 0.001 or visible_strength > 0.015
	if _post_material:
		_post_material.set_shader_parameter("intensity", visible_strength)
		_post_material.set_shader_parameter("dream_weight", dream_weight)
		_post_material.set_shader_parameter("dream_clock", _dream_elapsed)
		_post_material.set_shader_parameter("cue", _cue_value(_effect_cue))
		var viewport_size := get_viewport().get_visible_rect().size.max(Vector2.ONE)
		_post_material.set_shader_parameter("aspect", viewport_size.x / viewport_size.y)
		var camera := get_viewport().get_camera_3d()
		var focus_node := _effect_focus if is_instance_valid(_effect_focus) and _effect_focus.visible else _figure
		if camera and focus_node and focus_node.visible:
			var focus_height := 1.1 if focus_node == _figure else float(focus_node.get_meta("insight_focus_height", 3.0))
			var focus := focus_node.global_position + Vector3.UP * focus_height
			var point := camera.unproject_position(focus)
			var on_screen := not camera.is_position_behind(focus) and Rect2(Vector2.ZERO, viewport_size).has_point(point)
			if on_screen:
				_post_material.set_shader_parameter("focus_point", point / viewport_size)
	if _silhouette:
		var dissolve := visible_strength * 0.06 if _effect_cue == "merge" else 0.0
		_silhouette.set_shader_parameter("dissolve", dissolve)


func _cue_value(cue: String) -> int:
	match cue:
		"footstep":
			return 1
		"lantern":
			return 2
		"merge":
			return 3
		"release":
			return 4
		"insight":
			return 5
	return 0
