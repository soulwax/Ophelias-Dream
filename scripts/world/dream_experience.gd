extends Node3D

## A short, freely playable dream walk. The figure is a CC0 Quaternius rig,
## kept deliberately unreadable by a translucent, unlit silhouette material.
const FIGURE_SCENE := preload("res://assets/characters/quaternius_modular_women/animated_woman_a.glb")
const FIGURE_OFFSETS := [9.0, 20.0, 34.0, 50.0, 67.0]
const STORY := preload("res://scripts/world/dream_story.gd")

var _figure: Node3D
var _animation: AnimationPlayer
var _silhouette: ShaderMaterial
var _whisper: AudioStreamPlayer3D
var _post_material: ShaderMaterial
var _post_rect: ColorRect
var _caption: Label
var _choice_panel: PanelContainer
var _stage := 0
var _finished := false
var _memory_chosen := false
var _caption_time := 0.0
var _effect_strength := 0.0
var _effect_target := 0.0
var _effect_hold := 0.0
var _story: Dictionary


func _ready() -> void:
	_story = STORY.load_data()
	if _story.is_empty():
		return
	_build_caption()
	_build_figure()
	_build_post_effect()
	_start.call_deferred()


func _start() -> void:
	if Game.player == null or Game.trail == null:
		return
	# Begin outside the cabin, where the player can look back at the lit house
	# before the figure draws them onto the path.
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + 1.0)
	Game.player.global_position = Game.trail.on_ground(frame.origin) + Vector3.UP * 0.15
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()
	_place_figure()
	Game.audio_fade = 1.0
	Game.set_phase(Game.Phase.DREAM)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.settings.apply_audio()
	_set_caption(str(_story.get("opening", "")))


func _build_figure() -> void:
	_figure = FIGURE_SCENE.instantiate() as Node3D
	_figure.name = "UnrememberedFigure"
	_figure.scale = Vector3.ONE * 1.0
	add_child(_figure)
	_silhouette = ShaderMaterial.new()
	_silhouette.shader = preload("res://shaders/dream_shadow.gdshader")
	_silhouette.set_shader_parameter("shadow_tint", Color("080611"))
	_silhouette.set_shader_parameter("opacity", 0.76)
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
		if chosen != "":
			_animation.play(chosen, 0.35)
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
	_whisper = AudioStreamPlayer3D.new()
	_whisper.name = "SnowWhistle"
	_whisper.stream = load("res://assets/audio/weather/howl.ogg")
	_whisper.bus = "Ambience"
	_whisper.volume_db = -22.0
	_whisper.unit_size = 8.0
	_whisper.max_distance = 52.0
	_whisper.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_figure.add_child(_whisper)


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
	_caption = UiChrome.label("", 18, Color("e4e0df"))
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_left = -540
	_caption.offset_right = 540
	_caption.offset_top = -118
	_caption.offset_bottom = -54
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(_caption)


func _process(delta: float) -> void:
	if Game.player == null:
		return
	_update_post_effect(delta)
	if _finished or Game.phase != Game.Phase.DREAM:
		return
	_caption_time += delta
	var distance := Game.player.global_position.distance_to(_figure.global_position)
	var beats: Array = _story.get("beats", [])
	if _stage < beats.size() and distance < 4.6:
		_stage += 1
		_place_figure()
		_set_caption(str(beats[_stage - 1].get("text", "")))
		_pulse_effect(0.72)
	elif _stage == beats.size() and distance < 4.6:
		_finish_dream()
	if _caption_time > 7.0 and _caption.modulate.a > 0.0:
		_caption.modulate.a = move_toward(_caption.modulate.a, 0.0, delta * 0.18)


func _unhandled_input(event: InputEvent) -> void:
	if _finished and _memory_chosen and Game.phase == Game.Phase.DREAM and event.is_action_pressed("interact"):
		_wake()
		get_viewport().set_input_as_handled()


func _place_figure() -> void:
	if _figure == null or Game.trail == null:
		return
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + FIGURE_OFFSETS[_stage])
	var across := frame.basis.x * (1.0 if _stage % 2 == 0 else -1.0) * 0.9
	_figure.global_position = Game.trail.on_ground(frame.origin + across) + Vector3.UP * 0.02
	var toward := Game.player.global_position - _figure.global_position if Game.player else -frame.basis.z
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		_figure.rotation.y = atan2(-toward.x, -toward.z)
	_figure.visible = true
	_figure.scale = Vector3.ONE * 1.0
	if _animation and _animation.is_playing():
		_animation.seek(randf() * 0.2, true)
	if _stage > 0 and _whisper:
		_whisper.stop()
		_whisper.play(randf_range(0.0, 0.24))


func _finish_dream() -> void:
	_finished = true
	_pulse_effect(0.92)
	var fade := create_tween()
	fade.tween_property(_figure, "scale", Vector3(1.0, 0.02, 1.0), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.parallel().tween_property(_silhouette, "shader_parameter/opacity", 0.0, 1.8)
	if _whisper and _whisper.playing:
		fade.parallel().tween_property(_whisper, "volume_db", -48.0, 1.8)
		fade.tween_callback(_whisper.stop)
	fade.tween_callback(func() -> void: _figure.visible = false)
	_set_caption(str(_story.get("arrival", "")))
	_build_choices()
	_choice_panel.show()
	Game.set_phase(Game.Phase.DIALOGUE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_choice_panel.get_child(0).get_child(1) as Button).grab_focus.call_deferred()


func _build_choices() -> void:
	_choice_panel = PanelContainer.new()
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.offset_left = -300
	_choice_panel.offset_right = 300
	_choice_panel.offset_top = -125
	_choice_panel.offset_bottom = 180
	_choice_panel.add_theme_stylebox_override("panel", UiChrome.plate(26, 12))
	_choice_panel.hide()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_choice_panel.add_child(box)
	var question := UiChrome.label(str(_story.get("question", "")), 19, Color("e4e0df"))
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(question)
	var branches: Array = _story.get("branches", [])
	for choice in branches:
		var button := Button.new()
		button.text = str(choice.get("label", ""))
		button.pressed.connect(_choose_memory.bind(str(choice.get("id", ""))))
		box.add_child(button)
	_caption.get_parent().add_child(_choice_panel)


func _choose_memory(memory: String) -> void:
	Game.save_dream_memory(memory)
	_memory_chosen = true
	_choice_panel.hide()
	var branch := STORY.branch_for(_story, memory)
	_set_caption(str(branch.get("response", "")))
	Game.set_phase(Game.Phase.DREAM)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	var branch := STORY.branch_for(_story, Game.dream_memory)
	_caption.hide()
	_choice_panel.offset_top = -205
	_choice_panel.offset_bottom = 235
	var box := _choice_panel.get_child(0) as VBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var heading := UiChrome.label("WHAT WAKES", 24, Color("e4e0df"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	for speaker in ["OPHELIA", "MATHILDA"]:
		var echo_text := str(branch.get(speaker.to_lower(), ""))
		var echo := UiChrome.label("%s\n%s" % [speaker, echo_text], 17, Color("c9c0c0"))
		echo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		echo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(echo)
	var return_button := UiChrome.text_button("Return to the threshold")
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.pressed.connect(_return_to_menu)
	box.add_child(return_button)
	_choice_panel.show()
	Game.set_phase(Game.Phase.DIALOGUE)
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
	_caption.modulate.a = 1.0
	_caption_time = 0.0


func _pulse_effect(strength: float) -> void:
	_effect_target = strength
	_effect_hold = 1.4


func _update_post_effect(delta: float) -> void:
	_effect_hold = maxf(_effect_hold - delta, 0.0)
	if _effect_hold <= 0.0:
		_effect_target = 0.0
	_effect_strength = move_toward(_effect_strength, _effect_target, delta * (1.15 if _effect_target > _effect_strength else 0.24))
	if _post_rect:
		_post_rect.visible = _effect_strength > 0.015
	if _post_material:
		_post_material.set_shader_parameter("intensity", _effect_strength)
		var viewport_size := get_viewport().get_visible_rect().size.max(Vector2.ONE)
		_post_material.set_shader_parameter("aspect", viewport_size.x / viewport_size.y)
		var camera := get_viewport().get_camera_3d()
		if camera and _figure and _figure.visible:
			var point := camera.unproject_position(_figure.global_position + Vector3.UP * 1.1)
			_post_material.set_shader_parameter("focus_point", (point / viewport_size).clamp(Vector2.ZERO, Vector2.ONE))
