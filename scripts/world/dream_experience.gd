extends Node3D

## A short, freely playable dream walk. The figure is a CC0 Quaternius rig,
## kept deliberately unreadable by a translucent, unlit silhouette material.
const FIGURE_SCENE := preload("res://assets/characters/quaternius_modular_women/animated_woman_a.glb")
const FIGURE_OFFSETS := [9.0, 20.0, 34.0, 50.0, 67.0]
const STORY := preload("res://scripts/world/dream_story.gd")
const DREAM_ROUTE_SCRIPT := preload("res://scripts/world/dream_route.gd")

var _dream_route: DreamRoute
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
var _caption: Label
var _lantern_prompt: Label
var _lantern: Node3D
var _lantern_light: OmniLight3D
var _lantern_flame: MeshInstance3D
var _lantern_time := 0.0
var _lantern_wait := 0.0
var _lantern_sheltered := false
var _choice_panel: PanelContainer
var _choice_buttons: Array[Button] = []
var _choice_index := 0
var _answer_open := false
var _waking_card := false
var _caption_tween: Tween
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
	_story = STORY.load_data()
	if _story.is_empty():
		return
	_build_dream_route()
	_build_caption()
	_build_figure()
	_build_post_effect()
	_start.call_deferred()


func _start() -> void:
	if Game.player == null or Game.trail == null:
		return
	# Begin outside the cabin, where the player can look back at the lit house
	# before the figure draws them onto the path.
	Game.player.global_position = _dream_route.world_position("step") + Vector3.UP * 0.15
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
	_dream_route = DREAM_ROUTE_SCRIPT.new() as DreamRoute
	_dream_route.name = "DreamRoute"
	add_child(_dream_route)
	_dream_route.build(Game.trail)


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
	var canvas := CanvasLayer.new()
	canvas.layer = 24
	add_child(canvas)
	var subtitle_size := Settings.SUBTITLE_SIZES[clampi(Game.settings.subtitle_size, 0, Settings.SUBTITLE_SIZES.size() - 1)]
	_caption = UiChrome.label("", subtitle_size, Color("e4e0df"))
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_top = -118
	_caption.offset_bottom = -54
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(_caption)
	_lantern_prompt = UiChrome.label("", 15, Color("e3c99c"))
	_lantern_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lantern_prompt.offset_top = -206
	_lantern_prompt.offset_bottom = -174
	_lantern_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lantern_prompt.modulate.a = 0.0
	_lantern_prompt.visible = false
	canvas.add_child(_lantern_prompt)
	get_viewport().size_changed.connect(_layout_caption)
	_layout_caption()


func _layout_caption() -> void:
	var viewport_width := get_viewport_rect().size.x
	var caption_width := minf(1080.0, maxf(240.0, viewport_width - 32.0))
	if _caption:
		_caption.offset_left = -caption_width * 0.5
		_caption.offset_right = caption_width * 0.5
		if _answer_open and _choice_panel and is_instance_valid(_choice_panel):
			_caption.offset_bottom = _choice_panel.offset_top - 12.0
			_caption.offset_top = _caption.offset_bottom - 96.0
		else:
			_caption.offset_top = -160.0
			_caption.offset_bottom = -52.0
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
	_update_boundary_shadow(delta)
	if _finished:
		return
	if _answer_open:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	_caption_time += delta
	_update_figure(delta)
	_update_lantern(delta)
	var route_progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	var beats: Array = _story.get("beats", [])
	if _stage < beats.size() and route_progress >= FIGURE_OFFSETS[_stage] - 2.5:
		_stage += 1
		var beat: Dictionary = beats[_stage - 1]
		_set_caption(str(beat.get("text", "")))
		var cue := "footstep"
		match str(beat.get("id", "")):
			"lantern":
				cue = "lantern"
			"empty_path":
				cue = "merge"
		_pulse_effect(0.72, cue)
	elif _stage == beats.size() and route_progress >= FIGURE_OFFSETS[FIGURE_OFFSETS.size() - 1] - 2.0:
		_finish_dream()
	if _caption_time > 7.0 and _caption.modulate.a > 0.0:
		_caption.modulate.a = move_toward(_caption.modulate.a, 0.0, delta * 0.18)


func _unhandled_input(event: InputEvent) -> void:
	if _answer_open and Game.phase == Game.Phase.DREAM:
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
		_wake()
		get_viewport().set_input_as_handled()


func _update_figure(delta: float) -> void:
	if _figure == null or Game.trail == null or Game.player == null:
		return
	var player_progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
	var goal_index := mini(_stage, FIGURE_OFFSETS.size() - 1)
	var authored_goal := Game.trail.player_start_offset + FIGURE_OFFSETS[goal_index]
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
	_lantern.global_position = _dream_route.world_position("lantern")
	add_child(_lantern)
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


func _update_lantern(delta: float) -> void:
	if _lantern == null or Game.player == null:
		return
	_lantern_time += delta
	var distance := Game.player.global_position.distance_to(_lantern.global_position)
	var near := distance <= 3.2
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
		_lantern_prompt.text = "THE LIGHT HOLDS" if _lantern_sheltered else "SHELTER THE FLAME  ·  %s" % key
	if _lantern_light:
		var flicker := 0.992 + sin(_lantern_time * 4.1) * 0.018 + sin(_lantern_time * 6.3) * 0.008
		_lantern_light.light_energy = (1.05 if _lantern_sheltered else 0.76) * flicker
	if _lantern_flame:
		var breath := 1.0 if _lantern_sheltered else 0.96 + sin(_lantern_time * 3.8) * 0.04
		_lantern_flame.scale = Vector3(1.0, breath, 1.0)


func _shelter_lantern() -> void:
	_lantern_sheltered = true
	_lantern_wait = 0.0
	_pulse_effect(0.34, "lantern")
	if _silhouette:
		_silhouette.set_shader_parameter("lantern_warmth", 1.0)


func _finish_dream() -> void:
	if _answer_open or _finished:
		return
	_answer_open = true
	_set_figure_moving(false)
	_lantern_prompt.hide()
	_pulse_effect(0.72, "merge")
	_set_caption(str(_story.get("arrival", "")))
	_build_choices()
	_choice_panel.show()
	_choice_panel.modulate.a = 0.0
	create_tween().tween_property(_choice_panel, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_layout_caption()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus.call_deferred()


func _build_choices() -> void:
	_choice_buttons.clear()
	_choice_panel = PanelContainer.new()
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_choice_panel.offset_left = -390
	_choice_panel.offset_right = 390
	_choice_panel.offset_top = -378
	_choice_panel.offset_bottom = -132
	get_viewport().size_changed.connect(_layout_choices)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.025, 0.03, 0.045, 0.72)
	plate.set_corner_radius_all(10)
	plate.set_content_margin_all(16)
	plate.border_color = Color(0.76, 0.68, 0.58, 0.12)
	plate.set_border_width_all(1)
	plate.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	plate.shadow_size = 14
	_choice_panel.add_theme_stylebox_override("panel", plate)
	_choice_panel.hide()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_choice_panel.add_child(box)
	var question := UiChrome.label(str(_story.get("question", "")), 18, Color("e4e0df"))
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(question)
	var branches: Array = _story.get("branches", [])
	for index in range(branches.size()):
		var choice: Dictionary = branches[index]
		var button := Button.new()
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 40.0
		button.focus_mode = Control.FOCUS_ALL
		button.text = str(choice.get("label", ""))
		button.add_theme_font_size_override("font_size", 16)
		button.mouse_entered.connect(_set_choice_index.bind(index))
		button.focus_entered.connect(_set_choice_index.bind(index))
		button.pressed.connect(_choose_memory.bind(str(choice.get("id", ""))))
		box.add_child(button)
		_choice_buttons.append(button)
	var hint := UiChrome.label("↑ / ↓   ·   Click / %s   ·   Esc to pause" % Game.settings.key_label("interact"), 13, Color("9c9ba1"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_caption.get_parent().add_child(_choice_panel)
	_choice_index = 0
	_refresh_choices()
	_layout_choices()


func _layout_choices() -> void:
	if _choice_panel == null or not is_instance_valid(_choice_panel):
		return
	var viewport_size := get_viewport_rect().size
	var viewport_width := viewport_size.x
	var panel_width := minf(780.0, maxf(320.0, viewport_width - 32.0))
	_choice_panel.offset_left = -panel_width * 0.5
	_choice_panel.offset_right = panel_width * 0.5
	var bottom_margin: float
	var panel_height: float
	if _waking_card:
		bottom_margin = minf(90.0, viewport_size.y * 0.18)
		panel_height = minf(182.0, maxf(150.0, viewport_size.y - bottom_margin - 24.0))
	else:
		bottom_margin = minf(132.0, maxf(24.0, viewport_size.y * 0.18))
		panel_height = minf(274.0, maxf(220.0, viewport_size.y - bottom_margin - 24.0))
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
	var branches: Array = _story.get("branches", [])
	for index in range(mini(_choice_buttons.size(), branches.size())):
		var button := _choice_buttons[index]
		var selected := index == _choice_index
		button.text = ("›  " if selected else "   ") + str(branches[index].get("label", ""))
		button.add_theme_color_override("font_color", Color("f0dfbd") if selected else Color("b4b2b4"))
		button.add_theme_color_override("font_hover_color", Color("f0dfbd"))


func _choose_focused_memory() -> void:
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
	_set_caption("%s\n%s TO WAKE" % [response, Game.settings.key_label("interact")])
	_lantern_prompt.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	_caption.hide()
	_lantern_prompt.hide()
	var box := _choice_panel.get_child(0) as VBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	_choice_buttons.clear()
	var heading := UiChrome.label("THE LIGHT REMAINS", 22, Color("e4e0df"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var closing := UiChrome.label(str(_story.get("arrival", "")), 16, Color("c9c0c0"))
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
	Game.dream_mode = false
	Game.mathilda_pov = false
	Game.character_selected = false
	Game.set_phase(Game.Phase.BOOT)
	get_tree().reload_current_scene()


func _set_caption(line: String) -> void:
	_caption.text = line
	_caption.modulate.a = 0.0
	_caption_time = 0.0
	if _caption_tween and _caption_tween.is_running():
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
