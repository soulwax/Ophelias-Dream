extends Node3D

## A short, freely playable dream walk. The figure is a CC0 Quaternius rig,
## kept deliberately unreadable by a translucent, unlit silhouette material.
const FIGURE_SCENE := preload("res://assets/characters/quaternius_modular_women/animated_woman_a.glb")
const FIGURE_OFFSETS := [9.0, 20.0, 34.0, 50.0, 67.0]
const SCENE_CAMERA_DISTANCE := [4.8, 4.5, 4.2, 3.9]
const SCENE_CAMERA_HEIGHT := [1.65, 1.58, 1.5, 1.42]
# Each memory takes her for one full reveal, then gives her back on the path.
const APPARITION_DISSOLVE := 0.38
const APPARITION_FADE_SECONDS := 1.1
const APPARITION_MEMORY_SECONDS := 3.85
const FLASHBACK_CUES := [
	{"offset": 13.0, "id": "sisters"},
	{"offset": 29.0, "id": "thread"},
	{"offset": 44.0, "id": "window"},
]
const STORY := preload("res://scripts/world/dream_story.gd")
const DREAM_ROUTE_SCRIPT := preload("res://scripts/world/dream_route.gd")
const DREAM_SOUNDSCAPE_SCRIPT := preload("res://scripts/audio/dream_soundscape.gd")

var _dream_route: Node3D
var _dream_soundscape: Node3D
var _warning_prop: Node3D
var _figure: Node3D
var _animation: AnimationPlayer
var _walk_animation := ""
var _idle_animation := ""
var _figure_offset := 0.0
var _figure_moving := false
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
var _speech_view: SubViewport
var _speech_sprite: Sprite3D
var _speech_panel: PanelContainer
var _speaker_label: Label
var _caption: Label
var _speech_target: Node3D
var _lantern_prompt: Label3D
var _lantern: Node3D
var _lantern_light: OmniLight3D
var _lantern_flame: MeshInstance3D
var _lantern_time := 0.0
var _lantern_wait := 0.0
var _lantern_sheltered := false
var _lantern_seen := false
var _lantern_left_once := false
var _lantern_returned := false
var _dream_quiet := 0.0
var _dream_quiet_after_response := 0.0
var _choice_panel: Node3D
var _choice_title: Label3D
var _choice_hint: Label3D
var _choice_buttons: Array[Label3D] = []
var _conversation_camera: Camera3D
var _return_camera: Camera3D
var _conversation_camera_active := false
var _conversation_camera_returning := false
var _conversation_camera_return_time := 0.0
var _camera_choreography_enabled := true
var _conversation_response := ""
var _conversation_response_pending := false
var _conversation_response_ready := false
var _conversation_response_timer := 0.0
var _choice_index := 0
var _choice_time := 0.0
var _answer_open := false
var _conversation_intro_waiting := false
var _conversation_round := 0
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
var _caption_tween: Tween
var _story_line_queue: Array[Dictionary] = []
var _story_line_active := false
var _story_line_hold := 0.0
var _story_gap_remaining := 0.0
var _story_finish_pending := false
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
var _flashback_cue_index := 0
var _flashback_cooldown := 0.0
var _flashback_seen: Dictionary = {}
var _opened_memory_doors: Dictionary = {}
var _dream_understood := false
var _story: Dictionary
var _dream_journal_entries: Array[Dictionary] = []
var _dream_journal_seen: Dictionary = {}
var _dream_journal_layer: CanvasLayer
var _dream_journal_hint: Label
var _dream_journal_hint_panel: PanelContainer
var _dream_journal_scrim: ColorRect
var _dream_journal_panel: PanelContainer
var _dream_journal_scroll: ScrollContainer
var _dream_journal_rows: VBoxContainer
var _dream_journal_available := false
var _dream_journal_open := false


func _ready() -> void:
	Game.phase_changed.connect(_on_game_phase_changed)
	_story = STORY.load_data()
	if _story.is_empty():
		return
	_build_dream_route()
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
	# Begin outside the cabin, where the player can look back at the lit house
	# before the figure draws them onto the path.
	var step_position: Vector3 = _dream_route.call("world_position", "step")
	Game.player.global_position = step_position + Vector3.UP * 0.15
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()
	_figure_offset = Game.trail.player_start_offset + FIGURE_OFFSETS[0]
	_place_figure(_figure_offset)
	_begin_figure_appearance(1.55)
	_build_lantern()
	Game.audio_fade = 1.0
	Game.set_phase(Game.Phase.DREAM)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.settings.apply_audio()
	_set_caption(str(_story.get("opening", "")), "MATHILDA")
	_record_dream_entry(_story.get("journal_cue", {}))
	_set_figure_moving(false)


func _build_dream_route() -> void:
	if Game.trail == null:
		return
	_dream_route = DREAM_ROUTE_SCRIPT.new() as Node3D
	_dream_route.name = "DreamRoute"
	add_child(_dream_route)
	_dream_route.call("build", Game.trail)
	var doors: Array = _dream_route.call("dream_doors")
	for door_variant in doors:
		var door := door_variant as Node
		if door:
			door.connect("opened", _on_dream_door_opened)


func _build_figure() -> void:
	_figure = FIGURE_SCENE.instantiate() as Node3D
	_figure.name = "UnrememberedFigure"
	_figure.scale = Vector3.ONE * 1.0
	_figure.visible = false
	add_child(_figure)
	_silhouette = ShaderMaterial.new()
	_silhouette.shader = preload("res://shaders/dream_shadow.gdshader")
	_silhouette.set_shader_parameter("shadow_tint", Color("080611"))
	_silhouette.set_shader_parameter("opacity", 0.76)
	_silhouette.set_shader_parameter("dissolve", 0.0)
	for mesh_node in _figure.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		mesh.material_override = _silhouette
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	particles.amount = 36
	particles.lifetime = 2.4
	particles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.35
	process.gravity = Vector3(0, 0.12, 0)
	process.scale_min = 0.035
	process.scale_max = 0.12
	particles.process_material = process
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2(0.16, 0.16)
	var mote := StandardMaterial3D.new()
	mote.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote.albedo_color = Color(0.6, 0.7, 0.85, 0.32)
	mote.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_mesh.material = mote
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
	canvas.layer = 19
	add_child(canvas)
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
	_speech_view = SubViewport.new()
	_speech_view.name = "DreamSpeechViewport"
	_speech_view.size = Vector2i(960, 200)
	_speech_view.transparent_bg = true
	_speech_view.disable_3d = true
	_speech_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_speech_view)
	_speech_sprite = Sprite3D.new()
	_speech_sprite.name = "InWorldSpeech"
	_speech_sprite.texture = _speech_view.get_texture()
	_speech_sprite.pixel_size = 0.0036
	_speech_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech_sprite.no_depth_test = true
	_speech_sprite.shaded = false
	_speech_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_speech_sprite.position = Vector3.UP * 2.4
	_speech_sprite.visible = false
	add_child(_speech_sprite)
	_speech_panel = PanelContainer.new()
	_speech_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var speech_style := StyleBoxFlat.new()
	speech_style.bg_color = Color(0.014, 0.018, 0.03, 0.91)
	speech_style.border_color = Color(0.68, 0.57, 0.37, 0.48)
	speech_style.set_border_width_all(1)
	speech_style.set_corner_radius_all(11)
	speech_style.set_content_margin_all(22)
	speech_style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	speech_style.shadow_size = 10
	_speech_panel.add_theme_stylebox_override("panel", speech_style)
	_speech_view.add_child(_speech_panel)
	var dialogue_column := VBoxContainer.new()
	dialogue_column.add_theme_constant_override("separation", 6)
	_speech_panel.add_child(dialogue_column)
	_speaker_label = UiChrome.label("", 24, Color("d5b779"))
	_speaker_label.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.018, 0.96))
	_speaker_label.add_theme_constant_override("outline_size", 3)
	dialogue_column.add_child(_speaker_label)
	var subtitle_size: int = maxi(24, Settings.SUBTITLE_SIZES[clampi(Game.settings.subtitle_size, 0, Settings.SUBTITLE_SIZES.size() - 1)])
	_caption = UiChrome.label("", subtitle_size, Color("e4e0df"))
	_caption.add_theme_color_override("font_outline_color", Color(0.015, 0.022, 0.035, 0.96))
	_caption.add_theme_constant_override("outline_size", 2)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_column.add_child(_caption)
	_lantern_prompt = Label3D.new()
	_lantern_prompt.name = "InWorldLanternPrompt"
	_lantern_prompt.font_size = 24
	_lantern_prompt.pixel_size = 0.0045
	_lantern_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lantern_prompt.no_depth_test = true
	_lantern_prompt.modulate = Color("e3c99c")
	_lantern_prompt.outline_size = 12
	_lantern_prompt.outline_modulate = Color(0.012, 0.016, 0.024, 0.96)
	_lantern_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lantern_prompt.position = Vector3.UP * 1.0
	_lantern_prompt.visible = false
	add_child(_lantern_prompt)
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
	_dream_journal_hint_panel.offset_left = 24.0
	_dream_journal_hint_panel.offset_top = -56.0
	_dream_journal_hint_panel.offset_right = 660.0
	_dream_journal_hint_panel.offset_bottom = -14.0
	_dream_journal_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.012, 0.018, 0.03, 0.78)
	hint_style.border_color = Color("9c8a70", 0.42)
	hint_style.set_border_width_all(1)
	hint_style.set_corner_radius_all(5)
	hint_style.content_margin_left = 10.0
	hint_style.content_margin_right = 10.0
	hint_style.content_margin_top = 4.0
	hint_style.content_margin_bottom = 4.0
	_dream_journal_hint_panel.add_theme_stylebox_override("panel", hint_style)
	_dream_journal_hint_panel.hide()
	root.add_child(_dream_journal_hint_panel)
	_dream_journal_hint = UiChrome.label("", 17, Color("e2d3b6"))
	_dream_journal_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dream_journal_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dream_journal_hint_panel.add_child(_dream_journal_hint)
	_dream_journal_scrim = ColorRect.new()
	_dream_journal_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dream_journal_scrim.color = Color(0.008, 0.012, 0.022, 0.78)
	_dream_journal_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dream_journal_scrim.hide()
	root.add_child(_dream_journal_scrim)
	_dream_journal_panel = PanelContainer.new()
	_dream_journal_panel.set_anchors_preset(Control.PRESET_CENTER)
	_dream_journal_panel.offset_left = -430.0
	_dream_journal_panel.offset_top = -310.0
	_dream_journal_panel.offset_right = 430.0
	_dream_journal_panel.offset_bottom = 310.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.03, 0.045, 0.97)
	panel_style.border_color = Color("9c8a70", 0.54)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(28)
	_dream_journal_panel.add_theme_stylebox_override("panel", panel_style)
	_dream_journal_panel.hide()
	root.add_child(_dream_journal_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_dream_journal_panel.add_child(column)
	var title := UiChrome.label("DREAM JOURNAL", 27, Color("d5b779"))
	column.add_child(title)
	var subtitle := UiChrome.label("Words kept from the path. Press J or Esc to close.", 15, Color("9e9aa0"))
	column.add_child(subtitle)
	var divider := HSeparator.new()
	column.add_child(divider)
	_dream_journal_scroll = ScrollContainer.new()
	_dream_journal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dream_journal_scroll.custom_minimum_size = Vector2(0.0, 440.0)
	column.add_child(_dream_journal_scroll)
	_dream_journal_rows = VBoxContainer.new()
	_dream_journal_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dream_journal_rows.add_theme_constant_override("separation", 14)
	_dream_journal_scroll.add_child(_dream_journal_rows)
	var foot := UiChrome.label("The field pages are gone here. Mathilda's words make the record.", 13, Color("7e8791"))
	column.add_child(foot)


func _record_dream_entry(raw_entry: Variant) -> void:
	if typeof(raw_entry) != TYPE_DICTIONARY:
		return
	var entry := (raw_entry as Dictionary).duplicate(true)
	var identifier := str(entry.get("id", ""))
	if identifier.is_empty() or _dream_journal_seen.has(identifier):
		return
	if str(entry.get("title", "")).strip_edges().is_empty() or str(entry.get("text", "")).strip_edges().is_empty():
		return
	_dream_journal_seen[identifier] = true
	_dream_journal_entries.append(entry)
	_dream_journal_available = true
	_refresh_dream_journal_hint()
	_dream_journal_hint_panel.show()
	_refresh_dream_journal()


func _refresh_dream_journal_hint() -> void:
	var door_count := _opened_memory_doors.size()
	var progress := "OPEN THE WARM WINDOW + ONE OTHER"
	if _opened_memory_doors.has("window") and door_count >= 2:
		progress = "WARNING REMEMBERED  ·  2/2"
	elif _opened_memory_doors.has("window"):
		progress = "WARM WINDOW FOUND  ·  %d/1 OTHER" % maxi(door_count - 1, 0)
	elif door_count > 0:
		progress = "WARM WINDOW STILL NEEDED  ·  %d/2" % door_count
	_dream_journal_hint.text = "%s  DREAM JOURNAL  ·  %d  |  %s" % [Game.settings.key_label("journal"), _dream_journal_entries.size(), progress]


func _refresh_dream_journal() -> void:
	if _dream_journal_rows == null:
		return
	for child in _dream_journal_rows.get_children():
		_dream_journal_rows.remove_child(child)
		child.queue_free()
	for entry in _dream_journal_entries:
		var title := UiChrome.label(str(entry.get("title", "")), 19, Color("c8ad79"))
		_dream_journal_rows.add_child(title)
		var text := UiChrome.label(str(entry.get("text", "")), 16, Color("dedbd7"))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dream_journal_rows.add_child(text)
		var approach := str(entry.get("approach", "")).strip_edges()
		if not approach.is_empty():
			var guidance := UiChrome.label("A WAY THROUGH  ·  " + approach, 14, Color("a9b0b8"))
			guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			guidance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_dream_journal_rows.add_child(guidance)
		var divider := HSeparator.new()
		_dream_journal_rows.add_child(divider)


func _open_dream_journal() -> void:
	if not _dream_journal_available or _dream_journal_open:
		return
	_dream_journal_open = true
	_dream_journal_scroll.scroll_vertical = 0
	if Game.player:
		Game.player.dialogue_locked = true
	_dream_journal_scrim.show()
	_dream_journal_panel.show()


func _close_dream_journal() -> void:
	if not _dream_journal_open:
		return
	_dream_journal_open = false
	_dream_journal_scrim.hide()
	_dream_journal_panel.hide()
	if Game.player:
		Game.player.dialogue_locked = _story_line_active or _conversation_camera_active or _conversation_camera_returning or _conversation_waiting or _conversation_intro_waiting or _answer_open


func _on_dream_door_opened(door_id: String, flashback_id: String) -> void:
	if _opened_memory_doors.has(door_id):
		return
	_opened_memory_doors[door_id] = true
	var threshold := STORY.door_for(_story, door_id)
	if threshold.is_empty():
		return
	var entry: Dictionary = threshold.get("journal", {})
	_record_dream_entry(entry)
	if not _flashback_seen.has(flashback_id):
		var flashback := _dream_route.call("play_flashback", flashback_id) as Node3D if _dream_route else null
		if flashback:
			_flashback_seen[flashback_id] = true
			_begin_figure_departure()
			_pulse_effect(0.96, "insight", flashback)
	_queue_story_line(str(threshold.get("line", "")))


func _layout_caption() -> void:
	if _speech_sprite and _speech_target and is_instance_valid(_speech_target):
		_speech_sprite.global_position = _speech_target.global_position + Vector3.UP * 2.25
	if _lantern_prompt and _lantern:
		_lantern_prompt.global_position = _lantern.global_position + Vector3.UP * 1.25
	if _choice_panel and _figure and is_instance_valid(_figure):
		_choice_panel.global_position = _figure.global_position + Vector3.UP * 0.4


func _process(delta: float) -> void:
	if Game.player == null:
		return
	_layout_caption()
	_update_choice_positions()
	if _choice_panel and _choice_panel.visible:
		_choice_time += delta
		if _choice_index >= 0 and _choice_index < _choice_buttons.size():
			var selected_label := _choice_buttons[_choice_index]
			var breath := 1.06 + sin(_choice_time * 2.4) * 0.025
			selected_label.scale = Vector3.ONE * breath
	_update_post_effect(delta)
	if Game.phase != Game.Phase.DREAM:
		return
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
	_update_figure_apparition(delta)
	_update_boundary_shadow(delta)
	if _finished:
		return
	if _answer_open:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_update_story_lines(delta)
	if _story_line_active or _conversation_camera_returning:
		return
	_update_figure(delta)
	_update_lantern(delta)
	var route_progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	_update_flashback_cues(delta, route_progress)
	var beats: Array = _story.get("beats", [])
	if _stage < beats.size() and _apparition_state == ApparitionState.PRESENT and route_progress >= FIGURE_OFFSETS[_stage] - 2.5:
		_stage += 1
		var beat: Dictionary = beats[_stage - 1]
		_queue_story_line(str(beat.get("text", "")), str(beat.get("motion", "")), beat.get("journal", {}))
		var cue := "footstep"
		match str(beat.get("id", "")):
			"lantern":
				cue = "lantern"
			"empty_path":
				cue = "merge"
		_pulse_effect(0.72, cue)
	elif _stage == beats.size() and route_progress >= FIGURE_OFFSETS[FIGURE_OFFSETS.size() - 1] - 2.0:
		_story_finish_pending = true
		if not _story_line_active and _story_line_queue.is_empty() and _story_gap_remaining <= 0.0:
			_finish_dream()


func _update_flashback_cues(delta: float, route_progress: float) -> void:
	_flashback_cooldown = maxf(_flashback_cooldown - delta, 0.0)
	if _apparition_state != ApparitionState.PRESENT or _flashback_cooldown > 0.0 or _flashback_cue_index >= FLASHBACK_CUES.size():
		return
	while _flashback_cue_index < FLASHBACK_CUES.size() and _flashback_seen.has(str(FLASHBACK_CUES[_flashback_cue_index]["id"])):
		_flashback_cue_index += 1
	if _flashback_cue_index >= FLASHBACK_CUES.size():
		return
	var cue: Dictionary = FLASHBACK_CUES[_flashback_cue_index]
	if route_progress < float(cue["offset"]):
		return
	_flashback_cue_index += 1
	var flashback := _dream_route.call("play_flashback", str(cue["id"])) as Node3D if _dream_route else null
	if flashback == null:
		return
	_flashback_seen[str(cue["id"])] = true
	_flashback_cooldown = 1.2
	_begin_figure_departure()
	_pulse_effect(0.96, "insight", flashback)


func _queue_story_line(line: String, motion: String = "", journal_entry: Dictionary = {}) -> void:
	if line.strip_edges().is_empty():
		return
	_story_line_queue.append({"text": line, "motion": motion, "journal": journal_entry})
	if not _story_line_active and _story_gap_remaining <= 0.0 and _apparition_state == ApparitionState.PRESENT:
		_show_next_story_line()


func _show_next_story_line() -> void:
	if _story_line_queue.is_empty() or _apparition_state != ApparitionState.PRESENT:
		return
	_begin_character_conversation(true)
	var beat: Dictionary = _story_line_queue.pop_front()
	var line := str(beat.get("text", ""))
	_record_dream_entry(beat.get("journal", {}))
	_play_story_choreography(str(beat.get("motion", "")))
	_set_caption(line, "MATHILDA")
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
				_story_gap_remaining = 1.2 if not _story_line_queue.is_empty() else 0.0
	elif _story_gap_remaining > 0.0:
		_story_gap_remaining = maxf(_story_gap_remaining - delta, 0.0)
		if _story_gap_remaining <= 0.0:
			_show_next_story_line()
	elif not _story_line_queue.is_empty():
		_show_next_story_line()
	if _story_finish_pending and not _story_line_active and _story_line_queue.is_empty() and _story_gap_remaining <= 0.0:
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
		elif event.is_action_pressed("ui_up"):
			_dream_journal_scroll.scroll_vertical = maxi(_dream_journal_scroll.scroll_vertical - 120, 0)
		elif event.is_action_pressed("ui_down"):
			_dream_journal_scroll.scroll_vertical += 120
		get_viewport().set_input_as_handled()
		return
	if _waking_card and Game.phase == Game.Phase.DIALOGUE:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_return_to_menu()
			get_viewport().set_input_as_handled()
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
			if event.is_action_pressed("interact"):
				if _conversation_response_pending:
					_reveal_conversation_response()
				elif _conversation_response_ready:
					_conversation_response_ready = false
					_conversation_waiting = false
					if _memory_chosen:
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
		if event.is_action_pressed("ui_up"):
			_focus_choice(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			_focus_choice(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_choose_focused_memory()
			get_viewport().set_input_as_handled()
		return
	if not _finished and Game.phase == Game.Phase.DREAM and not _lantern_sheltered \
		and event.is_action_pressed("interact") and _lantern and Game.player \
		and Game.player.global_position.distance_to(_lantern.global_position) <= 3.2:
		_shelter_lantern()
		get_viewport().set_input_as_handled()
		return
	if _finished and _memory_chosen and Game.phase == Game.Phase.DREAM and event.is_action_pressed("interact"):
		if Game.dream_mode:
			_show_standalone_waking()
		elif not _ending_warning_shown:
			_ending_warning_shown = true
			_show_warning_prop()
			_set_caption("%s\n%s TO WAKE" % [str(_story.get("ending", _story.get("arrival", ""))), Game.settings.key_label("interact")], "MATHILDA")
		else:
			_wake()
		get_viewport().set_input_as_handled()


func _update_figure(delta: float) -> void:
	if _figure == null or Game.trail == null or Game.player == null or _apparition_state != ApparitionState.PRESENT:
		return
	var player_progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	var goal_index := mini(_stage, FIGURE_OFFSETS.size() - 1)
	var authored_goal: float = Game.trail.player_start_offset + FIGURE_OFFSETS[goal_index]
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


func _complete_figure_appearance() -> void:
	_apparition_state = ApparitionState.PRESENT
	_apparition_tween = null
	_apparition_link_strength = 0.0
	_set_figure_dissolve(0.0)


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

	var stump_material := StandardMaterial3D.new()
	stump_material.albedo_color = Color("30241f")
	stump_material.roughness = 0.96
	var snow_material := StandardMaterial3D.new()
	snow_material.albedo_color = Color("b6c3cf")
	snow_material.roughness = 0.88
	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = 0.23
	stump_mesh.bottom_radius = 0.31
	stump_mesh.height = 0.64
	stump_mesh.radial_segments = 16
	var stump := MeshInstance3D.new()
	stump.name = "OldStump"
	stump.mesh = stump_mesh
	stump.material_override = stump_material
	stump.position.y = 0.32
	_warning_prop.add_child(stump)
	var snow_cap_mesh := SphereMesh.new()
	snow_cap_mesh.radius = 0.5
	snow_cap_mesh.height = 0.16
	snow_cap_mesh.radial_segments = 20
	snow_cap_mesh.rings = 8
	var snow_cap := MeshInstance3D.new()
	snow_cap.name = "SnowOnStump"
	snow_cap.mesh = snow_cap_mesh
	snow_cap.material_override = snow_material
	snow_cap.scale = Vector3(0.44, 0.16, 0.44)
	snow_cap.position = Vector3(0.015, 0.66, -0.01)
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
	handle.position = Vector3(0.18, 0.89, 0.0)
	handle.rotation.z = -0.2
	_warning_prop.add_child(handle)

	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("55565a")
	head_material.metallic = 0.54
	head_material.roughness = 0.78
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
	socket.position = Vector3(0.18, 1.31, 0.0)
	_warning_prop.add_child(socket)
	var blade := MeshInstance3D.new()
	blade.name = "AxeBlade"
	blade.mesh = _build_axe_blade_mesh()
	blade.material_override = head_material
	blade.position = Vector3(0.18, 1.31, 0.0)
	_warning_prop.add_child(blade)


func _build_axe_blade_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(0.07, -0.085), Vector2(0.075, 0.075), Vector2(0.015, 0.12),
		Vector2(-0.075, 0.105), Vector2(-0.17, 0.055), Vector2(-0.235, 0.0),
		Vector2(-0.195, -0.075), Vector2(-0.06, -0.12),
	])
	var center := Vector2(-0.055, -0.005)
	var depth := 0.045
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


func _shelter_lantern() -> void:
	_lantern_sheltered = true
	_lantern_wait = 0.0
	_pulse_effect(0.34, "lantern")
	if _silhouette:
		_silhouette.set_shader_parameter("lantern_warmth", 1.0)


func _update_dream_quiet(delta: float) -> void:
	if Game.weather == null or Game.trail == null or Game.player == null:
		return
	var target := 0.0
	if _stage >= _story.get("beats", []).size() and not _memory_chosen:
		target = 0.68
	if _memory_chosen:
		_dream_quiet_after_response = maxf(_dream_quiet_after_response - delta, 0.0)
		target = 0.84 if _conversation_response_pending or _dream_quiet_after_response > 0.0 else 0.12
	_dream_quiet = move_toward(_dream_quiet, target, delta * (0.24 if target > _dream_quiet else 0.18))
	Game.weather.set_dream_quiet(_dream_quiet)


func _finish_dream() -> void:
	if _answer_open or _finished:
		return
	_answer_open = true
	_conversation_intro_waiting = true
	_conversation_round = 0
	_conversation_waiting = false
	_set_figure_moving(false)
	_begin_character_conversation()
	_lantern_prompt.hide()
	_pulse_effect(0.72, "merge")
	_set_caption("%s\n\n%s TO CONTINUE" % [str(_story.get("arrival", "")), Game.settings.key_label("interact")], "MATHILDA")
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
	if not _camera_choreography_enabled or Game.player == null or _figure == null:
		return
	if _conversation_camera_returning:
		_complete_character_conversation()
	Game.player.dialogue_locked = true
	_set_figure_moving(false)
	_figure_offset = Game.trail.offset_of(Game.player.global_position) + 3.2 if Game.trail else _figure_offset
	_place_figure(_figure_offset)
	Game.player.face_toward(_figure.global_position)
	_lantern_prompt.hide()
	var toward_player := Game.player.global_position - _figure.global_position
	toward_player.y = 0.0
	if toward_player.length_squared() > 0.01:
		_figure.rotation.y = atan2(-toward_player.x, -toward_player.z)
	if _conversation_camera_active and _conversation_camera and is_instance_valid(_conversation_camera):
		return
	if Game.player.camera == null:
		return
	_return_camera = Game.player.camera
	_conversation_camera = Camera3D.new()
	_conversation_camera.name = "FixedConversationCamera"
	_conversation_camera.fov = _return_camera.fov
	_conversation_camera.near = _return_camera.near
	_conversation_camera.far = _return_camera.far
	add_child(_conversation_camera)
	_conversation_camera.global_transform = _return_camera.global_transform
	_conversation_camera.make_current()
	_conversation_camera_active = true


func _update_conversation_camera(delta: float) -> void:
	if _conversation_camera == null or not is_instance_valid(_conversation_camera) or Game.player == null or _figure == null:
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
	_conversation_camera.global_position = _conversation_camera.global_position.lerp(target_position, weight)
	var target_basis := Basis.looking_at(look_target - _conversation_camera.global_position, Vector3.UP)
	_conversation_camera.global_basis = _conversation_camera.global_basis.slerp(target_basis, weight)


func _restore_character_conversation(immediate := false) -> void:
	_conversation_camera_active = false
	_figure_rambling = false
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
	_conversation_camera.global_position = _conversation_camera.global_position.lerp(_return_camera.global_position, blend)
	_conversation_camera.global_basis = _conversation_camera.global_basis.slerp(_return_camera.global_basis, blend)
	_conversation_camera_return_time -= delta
	if _conversation_camera_return_time <= 0.0:
		_complete_character_conversation()


func _complete_character_conversation() -> void:
	_conversation_camera_returning = false
	if _return_camera and is_instance_valid(_return_camera):
		_return_camera.make_current()
	if _conversation_camera and is_instance_valid(_conversation_camera):
		_conversation_camera.queue_free()
	_conversation_camera = null
	_return_camera = null
	if Game.player:
		Game.player.dialogue_locked = false


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
	if _conversation_round >= rounds.size():
		_conversation_waiting = false
		_set_caption("")
		_build_choices()
		return
	_set_caption("")
	var round_data: Dictionary = rounds[_conversation_round]
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


func _build_choice_panel() -> void:
	_choice_panel = Node3D.new()
	_choice_panel.name = "InWorldConversationChoices"
	_choice_panel.visible = false
	add_child(_choice_panel)
	_choice_title = _new_choice_label(22)
	_choice_title.modulate = Color("d5b779")
	_choice_title.position = Vector3(0.0, 0.68, 0.0)
	_choice_panel.add_child(_choice_title)
	_choice_hint = _new_choice_label(18)
	_choice_hint.modulate = Color("b6b0a6")
	_choice_hint.position = Vector3(0.0, -0.68, 0.0)
	_choice_panel.add_child(_choice_hint)


func _new_choice_label(size: int) -> Label3D:
	var label := Label3D.new()
	label.font_size = size
	label.pixel_size = 0.0048
	label.fixed_size = false
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 12
	label.outline_modulate = Color(0.012, 0.016, 0.024, 0.97)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _set_choice_rows(title: String, labels: Array[String]) -> void:
	for child in _choice_panel.get_children():
		if child != _choice_title and child != _choice_hint:
			_choice_panel.remove_child(child)
			child.queue_free()
	_choice_buttons.clear()
	var row_spacing := 0.31 if labels.size() <= 4 else 0.26
	var row_half_height := float(maxi(labels.size() - 1, 0)) * row_spacing * 0.5
	_choice_title.position.y = row_half_height + 0.52
	_choice_hint.position.y = -row_half_height - 0.54
	_choice_title.text = title if _waking_card else "MATHILDA · %s" % title
	_choice_hint.text = (
		"PRESS %s TO RETURN" % Game.settings.key_label("interact")
		if _waking_card else "YOUR REPLY  ·  ↑ / ↓  ·  %s  ·  ESC TO PAUSE" % Game.settings.key_label("interact")
	)
	for index in range(labels.size()):
		var choice_label := _new_choice_label(24 if labels.size() <= 4 else 21)
		choice_label.position = Vector3(0.0, row_half_height - float(index) * row_spacing, 0.0)
		choice_label.text = labels[index]
		_choice_panel.add_child(choice_label)
		_choice_buttons.append(choice_label)
	_update_choice_positions()


func _update_choice_positions() -> void:
	if not is_instance_valid(_choice_panel) or not _choice_panel.visible or Game.player == null:
		return
	var speaker := _figure if _figure and is_instance_valid(_figure) else Game.player
	_choice_panel.global_position = speaker.global_position + Vector3.UP * 1.4
	var camera := get_viewport().get_camera_3d()
	if camera:
		_choice_panel.look_at(camera.global_position, Vector3.UP)


func _choose_small_talk(index: int) -> void:
	var round_data: Dictionary
	if _repair_menu_active:
		round_data = _story.get("repair", {})
	else:
		var rounds: Array = _story.get("small_talk", [])
		if _conversation_round >= rounds.size():
			return
		round_data = rounds[_conversation_round]
	var choices: Array = round_data.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	var effect := str(choice.get("effect", ""))
	if effect == "push" or effect == "escalate":
		_conversation_strain += 2
	elif effect == "repair":
		_conversation_strain = 0
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
	_conversation_response_timer = 1.2
	_conversation_response = mathilda_line
	_set_caption(player_line, "YOU")


func _reveal_conversation_response() -> void:
	if not _conversation_response_pending:
		return
	_conversation_response_pending = false
	_conversation_response_ready = true
	if _memory_chosen:
		_dream_quiet_after_response = 4.5
	_set_caption("%s\n\n%s TO CONTINUE" % [_conversation_response, Game.settings.key_label("interact")], "MATHILDA")


func _continue_memory_dialogue() -> void:
	if Game.dream_mode:
		_show_standalone_waking()
	elif not _ending_warning_shown:
		_ending_warning_shown = true
		_show_warning_prop()
		_set_caption("%s\n\n%s TO WAKE" % [_ending_text(), Game.settings.key_label("interact")], "MATHILDA")
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
	_choice_index = index
	_refresh_choices()


func _style_choice(index: int, text: String) -> void:
	if index < 0 or index >= _choice_buttons.size():
		return
	var label := _choice_buttons[index]
	var selected := index == _choice_index
	label.text = ("◆  " if selected else "◇  ") + text
	label.modulate = Color("f0dfbd") if selected else Color("c5c3c3")
	label.scale = Vector3.ONE * (1.08 if selected else 1.0)


func _refresh_choices() -> void:
	if _repair_menu_active:
		var repair: Dictionary = _story.get("repair", {})
		_refresh_conversation_choices(repair.get("choices", []))
		return
	var rounds: Array = _story.get("small_talk", [])
	if _answer_open and not _conversation_waiting and _conversation_round < rounds.size():
		var round_data: Dictionary = rounds[_conversation_round]
		_refresh_conversation_choices(round_data.get("choices", []))
		return
	var branches: Array = _story.get("branches", [])
	for index in range(mini(_choice_buttons.size(), branches.size())):
		_style_choice(index, str(branches[index].get("label", "")))


func _choose_focused_memory() -> void:
	var rounds: Array = _story.get("small_talk", [])
	if _answer_open and _conversation_round < rounds.size():
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
	_pulse_effect(0.42, "release")
	_layout_caption()
	_react_to_answer(memory)
	var response := str(branch.get("response", "")).replace("\nPress E to wake.", "")
	_begin_dialogue_exchange(str(branch.get("label", "")), response)
	_lantern_prompt.hide()
	_layout_caption()


func _react_to_answer(memory: String) -> void:
	if _figure == null:
		return
	var reaction := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	match memory:
		"name":
			reaction.tween_property(_figure, "rotation:y", _figure.rotation.y + deg_to_rad(9.0), 0.65)
		"waiting":
			var toward_player := (Game.player.global_position - _figure.global_position).normalized()
			reaction.tween_property(_figure, "global_position", _figure.global_position + toward_player * 0.38, 0.8)
		"remember":
			reaction.tween_property(_figure, "scale:y", 0.92, 0.45)
			reaction.tween_property(_figure, "scale:y", 1.0, 0.6)
		"silence":
			var house_point := Game.house.spawn_point() if Game.house else _figure.global_position + Vector3.BACK
			var away := house_point - _figure.global_position
			away.y = 0.0
			if away.length_squared() > 0.01:
				var yaw := atan2(-away.x, -away.z)
				reaction.tween_property(_figure, "rotation:y", yaw, 0.8)


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
	_set_choice_rows("THE LIGHT REMAINS\n\nRETURN TO THE THRESHOLD  ·  %s" % Game.settings.key_label("interact"), [])
	Game.set_phase(Game.Phase.DIALOGUE)
	_choice_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ending_text() -> String:
	if _conversation_strain >= 4:
		_dream_understood = false
		_dream_outcome = "ruptured"
		var ruptured: Dictionary = _story.get("ruptured", {})
		_record_dream_entry(ruptured.get("journal", {}))
		return str(ruptured.get("response", _story.get("arrival", "")))
	_dream_understood = _opened_memory_doors.has("window") and _opened_memory_doors.size() >= 2
	if _dream_understood:
		_dream_outcome = "complete"
		return str(_story.get("ending", _story.get("arrival", "")))
	var unresolved: Dictionary = _story.get("unresolved", {})
	_dream_outcome = "unresolved"
	_record_dream_entry(unresolved.get("journal", {}))
	return str(unresolved.get("response", _story.get("arrival", "")))


func _return_to_menu() -> void:
	_restore_character_conversation(true)
	Game.dream_mode = false
	Game.mathilda_pov = false
	Game.character_selected = false
	Game.set_phase(Game.Phase.BOOT)
	get_tree().reload_current_scene()


func _set_caption(line: String, speaker := "") -> void:
	_story_line_active = false
	_story_line_queue.clear()
	_story_gap_remaining = 0.0
	_set_speaker(speaker)
	_caption.text = line
	_speech_sprite.visible = not line.is_empty()
	_speech_sprite.modulate.a = 0.0
	_caption_time = 0.0
	if _caption_tween and _caption_tween.is_running():
		_caption_tween.kill()
	if not line.is_empty():
		_caption_tween = create_tween()
		_caption_tween.tween_property(_speech_sprite, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_layout_caption()


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
	if next == Game.Phase.DREAM or next == Game.Phase.DIALOGUE:
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


func _update_post_effect(delta: float) -> void:
	_effect_hold = maxf(_effect_hold - delta, 0.0)
	if _effect_hold <= 0.0:
		_effect_target = 0.0
	var effect_rate := 6.0 if _effect_cue == "insight" and _effect_target > _effect_strength else 2.7 if _effect_cue == "insight" else 1.15 if _effect_target > _effect_strength else 0.24
	_effect_strength = move_toward(_effect_strength, _effect_target, delta * effect_rate)
	var screen_effects := clampf(Game.settings.screen_effects, 0.0, 1.0) if Game.settings else 1.0
	var visible_strength := _effect_strength * screen_effects
	if _post_rect:
		_post_rect.visible = false
	if _post_material:
		_post_material.set_shader_parameter("intensity", visible_strength)
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
				_post_rect.visible = visible_strength > 0.015
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
