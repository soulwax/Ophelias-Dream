extends Node3D

## A short, freely playable dream walk. The figure is a CC0 Quaternius rig,
## kept deliberately unreadable by a translucent, unlit silhouette material.
const FIGURE_SCENE := preload("res://assets/characters/quaternius_modular_women/animated_woman_a.glb")
const FIGURE_OFFSETS := [9.0, 20.0, 34.0, 50.0, 67.0]
const SCENE_CAMERA_DISTANCE := [6.8, 6.2, 5.7, 5.2]
const SCENE_CAMERA_HEIGHT := [1.9, 1.8, 1.7, 1.6]
const STORY := preload("res://scripts/world/dream_story.gd")
const DREAM_ROUTE_SCRIPT := preload("res://scripts/world/dream_route.gd")

var _dream_route: Node3D
var _dream_soundscape: DreamSoundscape
var _warning_prop: Node3D
var _figure: Node3D
var _animation: AnimationPlayer
var _walk_animation := ""
var _idle_animation := ""
var _figure_offset := 0.0
var _figure_moving := false
var _silhouette: ShaderMaterial
var _boundary_shadow: MeshInstance3D
var _boundary_material: ShaderMaterial
var _boundary_strength := 0.0
var _post_material: ShaderMaterial
var _post_rect: ColorRect
var _dialogue_canvas: CanvasLayer
var _dialogue_plate: PanelContainer
var _dialogue_box_style: StyleBoxFlat
var _narration_box_style: StyleBoxEmpty
var _speaker_label: Label
var _caption: Label
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
var _dream_quiet := 0.0
var _dream_quiet_after_response := 0.0
var _choice_panel: PanelContainer
var _choice_buttons: Array[Button] = []
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
var _answer_open := false
var _conversation_intro_waiting := false
var _conversation_round := 0
var _conversation_waiting := false
var _ending_warning_shown := false
var _waking_card := false
var _dialogue_ui_hidden_for_pause := false
var _pause_dialogue_plate_visible := false
var _pause_choice_panel_visible := false
var _pause_lantern_prompt_visible := false
var _caption_tween: Tween
var _story_line_queue: Array[String] = []
var _story_line_active := false
var _story_line_hold := 0.0
var _story_gap_remaining := 0.0
var _story_finish_pending := false
var _stage := 0
var _finished := false
var _memory_chosen := false
var _caption_time := 0.0
var _effect_strength := 0.0
var _effect_target := 0.0
var _effect_hold := 0.0
var _effect_cue := "doubt"
var _story: Dictionary


func _ready() -> void:
	Game.phase_changed.connect(_on_game_phase_changed)
	_story = STORY.load_data()
	if _story.is_empty():
		return
	_build_dream_route()
	_build_caption()
	_build_figure()
	_build_warning_prop()
	_build_post_effect()
	_dream_soundscape = DreamSoundscape.new()
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
	_build_lantern()
	Game.audio_fade = 1.0
	Game.set_phase(Game.Phase.DREAM)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.settings.apply_audio()
	_set_caption(str(_story.get("opening", "")))
	_set_figure_moving(false)


func _build_dream_route() -> void:
	if Game.trail == null:
		return
	_dream_route = DREAM_ROUTE_SCRIPT.new() as Node3D
	_dream_route.name = "DreamRoute"
	add_child(_dream_route)
	_dream_route.call("build", Game.trail)


func _build_figure() -> void:
	_figure = FIGURE_SCENE.instantiate() as Node3D
	_figure.name = "UnrememberedFigure"
	_figure.scale = Vector3.ONE * 1.0
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
	_dialogue_canvas = CanvasLayer.new()
	_dialogue_canvas.layer = 24
	add_child(_dialogue_canvas)
	_dialogue_plate = PanelContainer.new()
	_dialogue_plate.name = "DialogueHud"
	_dialogue_plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue_box_style = StyleBoxFlat.new()
	_dialogue_box_style.bg_color = Color(0.015, 0.02, 0.032, 0.88)
	_dialogue_box_style.border_color = Color(0.64, 0.51, 0.29, 0.62)
	_dialogue_box_style.set_border_width_all(1)
	_dialogue_box_style.set_corner_radius_all(3)
	_dialogue_box_style.set_content_margin_all(16)
	_narration_box_style = StyleBoxEmpty.new()
	_dialogue_plate.add_theme_stylebox_override("panel", _narration_box_style)
	_dialogue_canvas.add_child(_dialogue_plate)
	var dialogue_column := VBoxContainer.new()
	dialogue_column.add_theme_constant_override("separation", 4)
	_dialogue_plate.add_child(dialogue_column)
	_speaker_label = UiChrome.label("", 14, Color("d5b779"))
	_speaker_label.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.018, 0.9))
	_speaker_label.add_theme_constant_override("outline_size", 2)
	dialogue_column.add_child(_speaker_label)
	var subtitle_size: int = Settings.SUBTITLE_SIZES[clampi(Game.settings.subtitle_size, 0, Settings.SUBTITLE_SIZES.size() - 1)]
	_caption = UiChrome.label("", subtitle_size, Color("e4e0df"))
	_caption.add_theme_color_override("font_outline_color", Color(0.015, 0.022, 0.035, 0.96))
	_caption.add_theme_constant_override("outline_size", 3)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_column.add_child(_caption)
	_lantern_prompt = UiChrome.label("", 15, Color("e3c99c"))
	_lantern_prompt.add_theme_color_override("font_outline_color", Color(0.015, 0.022, 0.035, 0.96))
	_lantern_prompt.add_theme_constant_override("outline_size", 2)
	_lantern_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lantern_prompt.offset_top = -206
	_lantern_prompt.offset_bottom = -174
	_lantern_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lantern_prompt.modulate.a = 0.0
	_lantern_prompt.visible = false
	_dialogue_canvas.add_child(_lantern_prompt)
	get_viewport().size_changed.connect(_layout_caption)
	_layout_caption()


func _layout_caption() -> void:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var dialogue_width := minf(960.0, maxf(280.0, viewport_width - 32.0))
	if _dialogue_plate:
		_dialogue_plate.offset_left = -dialogue_width * 0.5
		_dialogue_plate.offset_right = dialogue_width * 0.5
		var dialogue_bottom := -36.0
		if _choice_panel and is_instance_valid(_choice_panel) and _choice_panel.visible:
			dialogue_bottom = _choice_panel.offset_top - 10.0
		_dialogue_plate.offset_bottom = dialogue_bottom
		_dialogue_plate.offset_top = dialogue_bottom - 204.0
	if _lantern_prompt:
		var prompt_width := minf(720.0, maxf(240.0, viewport_width - 32.0))
		_lantern_prompt.offset_left = -prompt_width * 0.5
		_lantern_prompt.offset_right = prompt_width * 0.5


func _process(delta: float) -> void:
	if Game.player == null:
		return
	_update_post_effect(delta)
	if Game.phase != Game.Phase.DREAM:
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
	_update_boundary_shadow(delta)
	if _finished:
		return
	if _answer_open:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	_update_story_lines(delta)
	if _story_line_active or _conversation_camera_returning:
		return
	_update_figure(delta)
	_update_lantern(delta)
	var route_progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	var beats: Array = _story.get("beats", [])
	if _stage < beats.size() and route_progress >= FIGURE_OFFSETS[_stage] - 2.5:
		_stage += 1
		var beat: Dictionary = beats[_stage - 1]
		_queue_story_line(str(beat.get("text", "")))
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


func _queue_story_line(line: String) -> void:
	if line.strip_edges().is_empty():
		return
	_story_line_queue.append(line)
	if not _story_line_active and _story_gap_remaining <= 0.0:
		_show_next_story_line()


func _show_next_story_line() -> void:
	if _story_line_queue.is_empty():
		return
	_begin_character_conversation()
	var line: String = _story_line_queue.pop_front()
	_caption.text = line
	_set_speaker("MATHILDA")
	_dialogue_plate.show()
	_caption.modulate.a = 0.0
	_caption_time = 0.0
	if _caption_tween and _caption_tween.is_running():
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_story_line_active = true
	var words := line.split(" ", false).size()
	_story_line_hold = clampf(float(words) / 2.6, 4.5, 8.0)


func _update_story_lines(delta: float) -> void:
	if _story_line_active:
		_caption_time += delta
		if _caption_time >= _story_line_hold:
			_caption.modulate.a = move_toward(_caption.modulate.a, 0.0, delta * 0.8)
			if _caption.modulate.a <= 0.01:
				_story_line_active = false
				_restore_character_conversation()
				_story_gap_remaining = 1.2 if not _story_line_queue.is_empty() else 0.0
	elif _story_gap_remaining > 0.0:
		_story_gap_remaining = maxf(_story_gap_remaining - delta, 0.0)
		if _story_gap_remaining <= 0.0:
			_show_next_story_line()
	if _story_finish_pending and not _story_line_active and _story_line_queue.is_empty() and _story_gap_remaining <= 0.0:
		_finish_dream()


func _unhandled_input(event: InputEvent) -> void:
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
				else:
					_conversation_round += 1
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
	if _figure == null or Game.trail == null or Game.player == null:
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
	var target_strength := _effect_strength * (0.08 + screen_effects * 0.3) if merging and distance <= 14.0 else 0.0
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


func _place_figure(along: float, delta: float = 0.0) -> void:
	if _figure == null or Game.trail == null:
		return
	var frame := Game.trail.frame_at(along)
	var across := frame.basis.x * 0.9
	_figure.global_position = Game.trail.on_ground(frame.origin + across) + Vector3.UP * 0.02
	var toward := Game.player.global_position - _figure.global_position if Game.player else -frame.basis.z
	if _figure_moving:
		var ahead := Game.trail.frame_at(minf(along + 1.0, Game.trail.length)).origin
		toward = ahead + frame.basis.x * 0.9 - _figure.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		var target_yaw := atan2(-toward.x, -toward.z)
		var turn_blend := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 10.0)
		_figure.rotation.y = lerp_angle(_figure.rotation.y, target_yaw, turn_blend)
	_figure.visible = true
	_figure.scale = Vector3.ONE


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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _begin_character_conversation() -> void:
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
	var target_position := midpoint + side * SCENE_CAMERA_DISTANCE[shot_index] + Vector3.UP * SCENE_CAMERA_HEIGHT[shot_index]
	var look_target := midpoint + Vector3.UP * 1.0
	var weight := 1.0 - exp(-delta * 2.8)
	_conversation_camera.global_position = _conversation_camera.global_position.lerp(target_position, weight)
	var target_basis := Basis.looking_at(look_target - _conversation_camera.global_position, Vector3.UP)
	_conversation_camera.global_basis = _conversation_camera.global_basis.slerp(target_basis, weight)


func _restore_character_conversation(immediate := false) -> void:
	_conversation_camera_active = false
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
	_dialogue_plate.hide()
	var box := _prepare_choice_panel(str(_story.get("question", "")))
	_add_choice_speaker(box, "YOU")
	var branches: Array = _story.get("branches", [])
	for index in range(branches.size()):
		var choice: Dictionary = branches[index]
		var button := _add_choice_button(box, str(choice.get("label", "")), index)
		button.pressed.connect(_choose_memory.bind(str(choice.get("id", ""))))
	_add_choice_hint(box, "↑ / ↓   ·   Click / %s   ·   Esc to pause" % Game.settings.key_label("interact"))
	_choice_panel.show()
	_choice_index = 0
	_refresh_choices()
	_layout_choices()
	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus.call_deferred()


func _build_small_talk_choices() -> void:
	var rounds: Array = _story.get("small_talk", [])
	if _conversation_round >= rounds.size():
		_conversation_waiting = false
		_set_caption("")
		_build_choices()
		return
	_dialogue_plate.hide()
	var round_data: Dictionary = rounds[_conversation_round]
	var box := _prepare_choice_panel(str(round_data.get("prompt", "")))
	_add_choice_speaker(box, "YOU")
	var choices: Array = round_data.get("choices", [])
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var button := _add_choice_button(box, str(choice.get("label", "")), index)
		button.pressed.connect(_choose_small_talk.bind(index))
	_add_choice_hint(box, "↑ / ↓   ·   Click / %s" % Game.settings.key_label("interact"))
	_choice_index = 0
	_refresh_conversation_choices(choices)
	_choice_panel.show()
	_layout_choices()
	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus.call_deferred()


func _prepare_choice_panel(title: String) -> VBoxContainer:
	if _choice_panel == null or not is_instance_valid(_choice_panel):
		_choice_panel = PanelContainer.new()
		_choice_panel.name = "CharacterDialogueChoices"
		_choice_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_choice_panel.offset_left = -390
		_choice_panel.offset_right = 390
		_choice_panel.offset_top = -378
		_choice_panel.offset_bottom = -132
		get_viewport().size_changed.connect(_layout_choices)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.015, 0.02, 0.032, 0.9)
		plate.set_corner_radius_all(3)
		plate.set_content_margin_all(18)
		plate.border_color = Color(0.64, 0.51, 0.29, 0.62)
		plate.set_border_width_all(1)
		plate.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
		plate.shadow_size = 14
		_choice_panel.add_theme_stylebox_override("panel", plate)
		var new_box := VBoxContainer.new()
		new_box.name = "ConversationChoices"
		new_box.add_theme_constant_override("separation", 7)
		_choice_panel.add_child(new_box)
		_dialogue_canvas.add_child(_choice_panel)
	var box := _choice_panel.get_child(0) as VBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	_choice_buttons.clear()
	var speaker := UiChrome.label("MATHILDA", 13, Color("d5b779"))
	speaker.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.018, 0.9))
	speaker.add_theme_constant_override("outline_size", 2)
	box.add_child(speaker)
	var heading := UiChrome.label(title, 18, Color("e4e0df"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	var divider := HSeparator.new()
	var divider_style := StyleBoxLine.new()
	divider_style.color = Color(0.64, 0.51, 0.29, 0.4)
	divider_style.thickness = 1
	divider.add_theme_stylebox_override("separator", divider_style)
	box.add_child(divider)
	return box


func _add_choice_button(box: VBoxContainer, label: String, index: int) -> Button:
	var button := Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 40.0
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.text = label
	button.add_theme_font_size_override("font_size", 16)
	button.mouse_entered.connect(_set_choice_index.bind(index))
	button.focus_entered.connect(_set_choice_index.bind(index))
	box.add_child(button)
	_choice_buttons.append(button)
	return button


func _add_choice_speaker(box: VBoxContainer, speaker: String) -> void:
	var label := UiChrome.label(speaker, 11, Color("a99b7d"))
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.018, 0.9))
	label.add_theme_constant_override("outline_size", 1)
	box.add_child(label)


func _add_choice_hint(box: VBoxContainer, text: String) -> void:
	var hint := UiChrome.label(text, 13, Color("9c9ba1"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _choose_small_talk(index: int) -> void:
	var rounds: Array = _story.get("small_talk", [])
	if _conversation_round >= rounds.size():
		return
	var round_data: Dictionary = rounds[_conversation_round]
	var choices: Array = round_data.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	_choice_panel.hide()
	_begin_dialogue_exchange(str(choice.get("label", "")), str(choice.get("response", "")))
	_lantern_prompt.hide()
	_layout_caption()


func _begin_dialogue_exchange(player_line: String, mathilda_line: String) -> void:
	_conversation_waiting = true
	_conversation_response_pending = true
	_conversation_response_ready = false
	_conversation_response_timer = 0.8
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
		_set_caption("%s\n\n%s TO WAKE" % [str(_story.get("ending", _story.get("arrival", ""))), Game.settings.key_label("interact")], "MATHILDA")
	else:
		_wake()


func _refresh_conversation_choices(choices: Array) -> void:
	for index in range(mini(_choice_buttons.size(), choices.size())):
		var button := _choice_buttons[index]
		var selected := index == _choice_index
		button.text = ("›  " if selected else "   ") + str(choices[index].get("label", ""))
		button.add_theme_color_override("font_color", Color("f0dfbd") if selected else Color("b4b2b4"))
		button.add_theme_color_override("font_hover_color", Color("f0dfbd"))


func _layout_choices() -> void:
	if _choice_panel == null or not is_instance_valid(_choice_panel):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var viewport_width: float = viewport_size.x
	var panel_width := minf(880.0, maxf(280.0, viewport_width - 32.0))
	_choice_panel.offset_left = -panel_width * 0.5
	_choice_panel.offset_right = panel_width * 0.5
	var bottom_margin: float
	var panel_height: float
	if _waking_card:
		bottom_margin = minf(90.0, viewport_size.y * 0.18)
		panel_height = minf(182.0, maxf(150.0, viewport_size.y - bottom_margin - 24.0))
	else:
		bottom_margin = minf(96.0, maxf(20.0, viewport_size.y * 0.12))
		panel_height = minf(360.0, maxf(240.0, viewport_size.y - bottom_margin - 24.0))
	_choice_panel.offset_bottom = -bottom_margin
	_choice_panel.offset_top = -bottom_margin - panel_height
	_layout_caption()
	var text_scale := clampf(panel_width / 780.0, 0.76, 1.0)
	for button in _choice_buttons:
		button.add_theme_font_size_override("font_size", roundi(16.0 * text_scale))


func _focus_choice(direction: int) -> void:
	if _choice_buttons.is_empty():
		return
	_choice_index = posmod(_choice_index + direction, _choice_buttons.size())
	_choice_buttons[_choice_index].grab_focus()
	_refresh_choices()


func _set_choice_index(index: int) -> void:
	_choice_index = index
	_refresh_choices()


func _refresh_choices() -> void:
	var rounds: Array = _story.get("small_talk", [])
	if _answer_open and not _conversation_waiting and _conversation_round < rounds.size():
		var round_data: Dictionary = rounds[_conversation_round]
		_refresh_conversation_choices(round_data.get("choices", []))
		return
	var branches: Array = _story.get("branches", [])
	for index in range(mini(_choice_buttons.size(), branches.size())):
		var button := _choice_buttons[index]
		var selected := index == _choice_index
		button.text = ("›  " if selected else "   ") + str(branches[index].get("label", ""))
		button.add_theme_color_override("font_color", Color("f0dfbd") if selected else Color("b4b2b4"))
		button.add_theme_color_override("font_hover_color", Color("f0dfbd"))


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
	_caption.hide()
	_dialogue_plate.hide()
	_lantern_prompt.hide()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.025, 0.03, 0.045, 0.9)
	card_style.border_color = Color(0.72, 0.7, 0.66, 0.16)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(20)
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	card_style.shadow_size = 16
	_choice_panel.add_theme_stylebox_override("panel", card_style)
	var box := _choice_panel.get_child(0) as VBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	_choice_buttons.clear()
	var heading := UiChrome.label("THE LIGHT REMAINS", 22, Color("e4e0df"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var speaker := UiChrome.label("MATHILDA", 12, Color("d5b779"))
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(speaker)
	var closing := UiChrome.label(str(_story.get("ending", _story.get("arrival", ""))), 16, Color("c9c0c0"))
	closing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	closing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(closing)
	var return_button := UiChrome.text_button("Return to the threshold")
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.pressed.connect(_return_to_menu)
	box.add_child(return_button)
	Game.set_phase(Game.Phase.DIALOGUE)
	_layout_choices()
	_choice_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return_button.grab_focus.call_deferred()


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
	_dialogue_plate.visible = not line.is_empty()
	_caption.modulate.a = 0.0
	_caption_time = 0.0
	if _caption_tween and _caption_tween.is_running():
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_layout_caption()


func _set_speaker(speaker: String) -> void:
	_speaker_label.text = speaker.to_upper()
	_speaker_label.visible = not speaker.is_empty()
	if speaker.is_empty():
		_dialogue_plate.add_theme_stylebox_override("panel", _narration_box_style)
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_dialogue_plate.add_theme_stylebox_override("panel", _dialogue_box_style)
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _on_game_phase_changed(next: Game.Phase) -> void:
	if next == Game.Phase.PAUSED:
		if _dialogue_ui_hidden_for_pause:
			return
		_pause_dialogue_plate_visible = is_instance_valid(_dialogue_plate) and _dialogue_plate.visible
		_pause_choice_panel_visible = is_instance_valid(_choice_panel) and _choice_panel.visible
		_pause_lantern_prompt_visible = is_instance_valid(_lantern_prompt) and _lantern_prompt.visible
		if is_instance_valid(_dialogue_plate):
			_dialogue_plate.hide()
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
		if is_instance_valid(_dialogue_plate):
			_dialogue_plate.visible = _pause_dialogue_plate_visible
		if is_instance_valid(_choice_panel):
			_choice_panel.visible = _pause_choice_panel_visible
		if is_instance_valid(_lantern_prompt):
			_lantern_prompt.visible = _pause_lantern_prompt_visible


func _pulse_effect(strength: float, cue := "doubt") -> void:
	_effect_target = strength
	_effect_hold = 1.4
	_effect_cue = cue


func _update_post_effect(delta: float) -> void:
	_effect_hold = maxf(_effect_hold - delta, 0.0)
	if _effect_hold <= 0.0:
		_effect_target = 0.0
	_effect_strength = move_toward(_effect_strength, _effect_target, delta * (1.15 if _effect_target > _effect_strength else 0.24))
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
		if camera and _figure and _figure.visible:
			var focus := _figure.global_position + Vector3.UP * 1.1
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
	return 0
