extends Node

## Render focused dream compositions for visual review. Run with a window.
const MAIN := preload("res://scenes/main.tscn")
const OUT := "res://build/dream/"

var _camera: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.lean_graphics = false
	Game.dream_mode = true
	Game.character_selected = true
	var main := MAIN.instantiate()
	get_tree().root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for _frame in 2400:
		if Game.trail and Game.player and Game.phase == Game.Phase.DREAM:
			break
		await get_tree().process_frame
	if Game.trail == null or Game.player == null or Game.phase != Game.Phase.DREAM:
		push_error("Dream view could not enter the playable phase")
		get_tree().quit(1)
		return
	if OS.get_environment("RUN_DREAM_NO_SCREEN_EFFECTS") == "1":
		Game.settings.screen_effects = 0.0
	_camera = Camera3D.new()
	_camera.name = "DreamReviewCamera"
	_camera.fov = 52.0
	_camera.far = 320.0
	get_tree().root.add_child(_camera)
	_camera.current = true
	var route := main.find_child("DreamRoute", true, false) as Node3D
	var experience: Node = route.get_parent() if route else null
	if route == null or experience == null:
		push_error("Dream route helpers were not built")
		get_tree().quit(1)
		return
	if OS.get_environment("RUN_DREAM_NO_WARP") == "1":
		var post := experience.get("_post_rect") as ColorRect
		post.hide()
		experience.set("_post_rect", null)
	experience.set("_camera_choreography_enabled", false)
	var focus := OS.get_environment("RUN_DREAM_FOCUS")
	if focus == "conversation_handoff":
		await _capture_conversation_handoff(experience)
		get_tree().quit()
		return
	if focus == "quiet_travel":
		await _capture_quiet_travel(experience)
		get_tree().quit()
		return
	if focus == "opening":
		var started_inside := not bool(experience.call("_player_crossed_dream_threshold"))
		_place_player(1.0)
		var crossed := bool(experience.call("_player_crossed_dream_threshold"))
		print("Dream doorway: inside at start=%s, outside on route=%s" % [started_inside, crossed])
		var figure := experience.get("_figure") as Node3D
		_aim_player_at(figure.global_position + Vector3.UP * 1.2)
		await get_tree().create_timer(1.7).timeout
		await _save_frame("opening_player")
		get_tree().quit()
		return
	if focus == "threshold":
		await _capture_memory_architecture(experience)
		get_tree().quit()
		return
	if focus == "station_flow":
		await _capture_station_flow(experience)
		get_tree().quit()
		return
	if focus == "memory_architecture":
		await _capture_memory_architecture(experience)
		get_tree().quit()
		return
	if focus == "presentation_edges":
		await _capture_dream_journal(experience, "journal_final")
		experience.set("_answer_open", true)
		await _capture_warning(experience, "warning_final")
		get_tree().quit()
		return
	if focus == "cue_timing":
		await _capture_cue_timing(experience)
		get_tree().quit()
		return
	if focus == "folded_path":
		await _capture_fold_return(route, experience, "folded_path")
		print("Focused folded-path capture saved under build/dream/")
		get_tree().quit()
		return
	if focus == "clearing":
		await _capture_clearing(route, experience, "clearing")
		get_tree().quit()
		return
	if focus == "choice":
		await _capture_choice(route, experience, "answer")
		get_tree().quit()
		return
	await _capture_entry(route, "entry")
	await _capture_figure_apparition(experience)
	await _capture_lantern(route, experience, "lantern")
	await _capture_fold_reveal(route, experience, "fold_reveal")
	await _capture_fold_return(route, experience, "fold_return")
	await _capture_dream_journal(experience, "journal")
	await _capture_story_motion(experience, 9.0, "cut_tree", 0, "motion_cut_trees")
	await _capture_story_motion(experience, 20.0, "delayed_steps", 1, "motion_delayed_steps")
	await _capture_story_motion(experience, 34.0, "lantern_witness", 2, "motion_lantern_witness")
	await _capture_story_motion(experience, 50.0, "tracks_stop", 3, "motion_tracks_stop")
	await _capture_clearing(route, experience, "clearing")
	await _capture_choice(route, experience, "answer")
	experience.set("_conversation_round", 3)
	experience.call("_build_small_talk_choices")
	await _settle()
	await _save_frame("approach_clue")
	await _capture_warning(experience, "warning")
	print("Dream visual review captures saved under build/dream/")
	get_tree().quit()


func _place_player(offset: float) -> void:
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + offset)
	Game.player.global_position = Game.trail.on_ground(frame.origin) + Vector3.UP * 0.15
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()


func _aim_player_at(target: Vector3) -> void:
	var toward := target - (Game.player.global_position + Vector3.UP * 1.5)
	var flat := Vector2(toward.x, toward.z).length()
	Game.player.set("_yaw", atan2(-toward.x, -toward.z))
	# Terrain heights at adjacent route samples vary sharply. Keep the ordinary
	# shoulder camera while pointing toward a memory on the hillside.
	Game.player.set("_pitch", clampf(atan2(toward.y, maxf(flat, 0.01)), -0.15, 0.15))
	Game.player.call("_apply_look")
	Game.player.camera.make_current()


func _capture_quiet_travel(experience: Node) -> void:
	await get_tree().create_timer(1.6).timeout
	_place_player(53.0)
	experience.set("_dream_voice_unlocked", true)
	experience.set("_opening_station_pending", false)
	experience.set("_stage", 3)
	experience.set("_story_event_cue_index", 3)
	experience.set("_story_line_active", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 56.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 56.0)
	experience.set("_apparition_state", 0)
	var figure := experience.get("_figure") as Node3D
	figure.show()
	experience.get("_memory_architecture").reveal_cue("window")
	experience.call("_begin_window_interval")
	_aim_player_at(figure.global_position + Vector3.UP * 1.2)
	experience.set("_window_interval_elapsed", 1.0)
	await _save_frame("quiet_travel_lookback")
	experience.set("_window_interval_elapsed", 2.6)
	await _save_frame("quiet_travel_forward")
	assert(not experience.get("_speech_sprite").visible and not experience.get("_dream_journal_hint_panel").visible, "quiet travel must remain free of dialogue and journal notices")


func _capture_conversation_handoff(experience: Node) -> void:
	await get_tree().create_timer(1.6).timeout
	experience.set("_camera_choreography_enabled", true)
	experience.set("_dream_voice_unlocked", true)
	experience.set("_opening_station_pending", false)
	experience.set("_stage", 3)
	experience.set("_story_event_cue_index", 3)
	experience.set("_story_line_active", false)
	_place_player(46.0)
	experience.set("_figure_offset", Game.trail.player_start_offset + 50.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 50.0)
	var figure := experience.get("_figure") as Node3D
	_aim_player_at(figure.global_position + Vector3.UP * 1.2)
	var before := figure.global_position
	var heading: float = Game.player.get("_yaw")
	experience.call("_start_station_dialogue", 2)
	assert(figure.global_position.is_equal_approx(before), "opening dialogue must preserve the speaker position")
	await _save_frame("conversation_hold_start")
	await get_tree().create_timer(0.8).timeout
	await _save_frame("conversation_hold_settled")
	var snapshot: Dictionary = RunSave._capture_dream()
	experience.call("_complete_character_conversation")
	RunSave._apply_properties(experience, snapshot)
	experience.call("restore_after_load", snapshot)
	assert(figure.global_position.is_equal_approx(before), "restoring dialogue must preserve the speaker position")
	await _save_frame("conversation_hold_restored")
	experience.set("_station_dialogue_active", false)
	experience.set("_answer_open", false)
	experience.set("_conversation_waiting", false)
	experience.get("_choice_panel").hide()
	experience.call("_set_caption", "")
	experience.call("_restore_character_conversation")
	await get_tree().create_timer(0.7).timeout
	await _save_frame("conversation_walk_return")
	assert(Game.player.camera.is_current() and not Game.player.dialogue_locked and is_equal_approx(float(Game.player.get("_yaw")), heading), "return must preserve the player's view and restore movement")
	_place_player(84.0)
	_aim_player_at(figure.global_position + Vector3.UP * 1.2)
	before = figure.global_position
	experience.call("_start_station_dialogue", 2)
	assert(not experience.get("_conversation_camera_active") and figure.global_position.is_equal_approx(before), "distant dialogue must retain the view and actor position")
	await _save_frame("conversation_far_reply")
	var before_offset: float = experience.get("_figure_offset")
	experience.call("_react_to_answer", "walk_beside")
	assert(absf(float(experience.get("_figure_motion_target_offset")) - before_offset) <= 1.601, "a company gesture must remain a measured step even at a distance")
	await get_tree().create_timer(2.1).timeout
	await _save_frame("conversation_far_company_step")
	print("Conversation handoff checked: actor positions preserved, reply restored, player heading retained, movement returned, distant camera fallback, bounded company gesture")


func _capture_memory_architecture(experience: Node) -> void:
	var architecture := experience.get("_memory_architecture") as DreamMemoryArchitecture
	if architecture == null:
		push_error("Dream memory architecture was not built")
		return
	experience.call("_set_caption", "")
	var views := [
		{"cue": "sisters", "offset": 12.0, "name": "memory_threshold"},
		{"cue": "sisters", "offset": 22.0, "name": "memory_corridor_lookback"},
		{"cue": "thread", "offset": 28.0, "name": "memory_lighthouse"},
		{"cue": "thread", "offset": 37.0, "name": "memory_lighthouse_lookback"},
		{"cue": "window", "offset": 43.0, "name": "memory_window"},
		{"cue": "clearing", "offset": 61.0, "name": "memory_clearing"},
	]
	for view in views:
		var cue := str(view["cue"])
		architecture.reveal_cue(cue)
		if cue == "clearing":
			architecture.enter_clearing()
		_place_player(float(view["offset"]))
		var focus_at := architecture.cue_position(cue) + Vector3.UP * (3.1 if cue == "thread" else 1.45)
		_aim_player_at(focus_at)
		await get_tree().create_timer(1.6).timeout
		experience.call("_set_caption", "")
		architecture.reveal_cue(cue)
		await get_tree().create_timer(1.0).timeout
		print("Memory preview %s: %s %.2f" % [cue, str(architecture._states[cue]), float(architecture._values[cue])])
		_aim_player_at(focus_at)
		await _save_frame(str(view["name"]) + "_player")
		_camera.make_current()
		var frame := Game.trail.frame_at(Game.trail.player_start_offset + float(view["offset"]))
		var across := frame.basis.x.normalized()
		if cue == "window":
			var room := architecture._roots[cue] as Node3D
			_camera.global_position = room.to_global(Vector3(0.0, 2.0, -8.0))
			_camera.look_at(room.to_global(Vector3(0.0, 1.5, 0.0)), Vector3.UP)
		else:
			_camera.global_position = Game.player.global_position + across * 2.0 - frame.basis.z * 1.4 + Vector3.UP * 2.2
			_camera.look_at(architecture.cue_position(cue) + Vector3.UP * (3.0 if cue == "thread" else 1.35), Vector3.UP)
		await _save_frame(str(view["name"]) + "_wide")
		if OS.get_environment("RUN_DREAM_FOCUS") == "threshold":
			break
	print("Dream memory architecture captures saved under build/dream/")


func _capture_cue_timing(experience: Node) -> void:
	var architecture := experience.get("_memory_architecture") as DreamMemoryArchitecture
	var events: Array = experience.get("_story").get("events", [])
	if architecture == null or events.is_empty():
		push_error("Dream cue timing needs the architecture and story events")
		return
	experience.set("_story_event_cue_index", 1)
	experience.set("_stage", 1)
	experience.set("_apparition_state", 0)
	var figure := experience.get("_figure") as Node3D
	if figure:
		figure.show()
	_place_player(14.5)
	_aim_player_at(architecture.cue_position("sisters") + Vector3.UP * 1.4)
	experience.call("_set_caption", "")
	var event: Dictionary = events[0]
	experience.call("_queue_story_line", str(event["line"]), "threshold_pause", event.get("journal", {}), -1, "sisters")
	assert(architecture._states["sisters"] == "anticipating", "the subtitle should prepare the threshold before its reveal")
	var cue_started := Time.get_ticks_msec()
	await get_tree().create_timer(0.25).timeout
	await _save_frame("cue_threshold_before")
	print("Threshold at %.2f s: %s %.2f" % [float(Time.get_ticks_msec() - cue_started) / 1000.0, architecture._states["sisters"], architecture._values["sisters"]])
	await get_tree().create_timer(0.9).timeout
	await _save_frame("cue_threshold_rising")
	print("Threshold at %.2f s: %s %.2f" % [float(Time.get_ticks_msec() - cue_started) / 1000.0, architecture._states["sisters"], architecture._values["sisters"]])
	await get_tree().create_timer(1.8).timeout
	await _save_frame("cue_threshold_held")
	print("Threshold at %.2f s: %s %.2f" % [float(Time.get_ticks_msec() - cue_started) / 1000.0, architecture._states["sisters"], architecture._values["sisters"]])
	experience.call("_open_dream_journal")
	var held_amount: float = architecture._values["sisters"]
	await get_tree().create_timer(0.5).timeout
	assert(is_equal_approx(float(architecture._values["sisters"]), held_amount), "reading the journal must hold the memory reveal")
	experience.call("_close_dream_journal")
	print("Threshold reveal and journal hold checked")


func _aim(offset: float, from_across: float, from_ahead: float, height: float, look_height: float = 0.8) -> void:
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + offset)
	var ahead := Game.trail.frame_at(Game.trail.player_start_offset + offset + 1.0).origin - frame.origin
	ahead.y = 0.0
	ahead = ahead.normalized()
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	var target := Game.trail.on_ground(frame.origin) + Vector3.UP * look_height
	_camera.global_position = target + across * from_across + ahead * from_ahead + Vector3.UP * height
	_camera.look_at(target, Vector3.UP)


func _aim_between(camera_offset: float, target_offset: float, target_across: float, target_height: float) -> void:
	var camera_frame := Game.trail.frame_at(Game.trail.player_start_offset + camera_offset)
	var camera_ahead := Game.trail.frame_at(Game.trail.player_start_offset + camera_offset + 1.0).origin - camera_frame.origin
	camera_ahead.y = 0.0
	camera_ahead = camera_ahead.normalized()
	var camera_across := camera_frame.basis.x
	camera_across.y = 0.0
	camera_across = camera_across.normalized()
	var target_frame := Game.trail.frame_at(Game.trail.player_start_offset + target_offset)
	var target_side := target_frame.basis.x
	target_side.y = 0.0
	target_side = target_side.normalized()
	var camera_ground := Game.trail.on_ground(camera_frame.origin)
	var target := Game.trail.on_ground(target_frame.origin + target_side * target_across) + Vector3.UP * target_height
	_camera.global_position = camera_ground + camera_across * 3.4 - camera_ahead * 4.8 + Vector3.UP * 2.15
	_camera.look_at(target, Vector3.UP)


func _set_fold_reveal(route: Node3D, amount: float) -> void:
	route.set("_fold_reveal", amount)
	var folded_path := route.get_node_or_null("FoldedSnowPath") as MeshInstance3D
	if folded_path and folded_path.material_override is ShaderMaterial:
		(folded_path.material_override as ShaderMaterial).set_shader_parameter("reveal", amount)


func _capture_entry(route: Node3D, name: String) -> void:
	_place_player(1.0)
	_aim(1.0, 0.48, -3.35, 1.62, 1.25)
	await _save_frame(name)


func _capture_station_flow(experience: Node) -> void:
	_place_player(28.0)
	experience.call("_set_figure_moving", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 31.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 31.0)
	var figure := experience.get("_figure") as Node3D
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + 28.0)
	var across := frame.basis.x.normalized()
	_camera.global_position = Game.player.global_position + across * 2.8 + Vector3.UP * 1.7
	_camera.look_at(figure.global_position + Vector3.UP * 1.15, Vector3.UP)
	_camera.make_current()
	experience.call("_start_station_dialogue", 0)
	await _settle()
	await _save_frame("station_threshold_choices")
	_exercise_station_choice(experience, 0)
	experience.call("_start_station_dialogue", 1)
	await _settle()
	await _save_frame("station_thread_choices")
	_exercise_station_choice(experience, 0)
	experience.call("_start_station_dialogue", 2)
	await _settle()
	await _save_frame("station_window_choices")
	_exercise_station_choice(experience, 0)
	var completed: Dictionary = experience.get("_completed_talk_rounds")
	assert(completed.has(0) and completed.has(1) and completed.has(2), "threshold and trail exchanges should be recorded once each")
	experience.call("_finish_dream")
	experience.set("_conversation_intro_waiting", false)
	experience.call("_build_small_talk_choices")
	assert(experience.get("_conversation_round") == 3, "closing dialogue should continue at the first unplayed round")
	await _settle()
	await _save_frame("station_flow_continues")
	print("Station dialogue capture: threshold, thread, and window exchanges recorded; closing dialogue resumes at round 4")


func _exercise_station_choice(experience: Node, index: int) -> void:
	experience.call("_choose_small_talk", index)
	experience.call("_reveal_conversation_response")
	experience.call("_continue_station_dialogue")


func _capture_figure_apparition(experience: Node) -> void:
	await get_tree().create_timer(1.7).timeout
	var figure := experience.get("_figure") as Node3D
	if figure == null:
		push_error("Dream apparition figure was not built")
		return
	experience.call("_set_caption", "")
	var toward := (figure.global_position - Game.player.global_position).normalized()
	var side := Vector3.UP.cross(toward).normalized()
	_camera.global_position = figure.global_position + side * 3.3 + Vector3.UP * 1.55
	_camera.look_at(figure.global_position + Vector3.UP * 1.05, Vector3.UP)
	_camera.make_current()
	experience.call("_begin_figure_departure")
	await get_tree().create_timer(0.25).timeout
	await _save_frame("mathilda_leaving")
	await get_tree().create_timer(3.6).timeout
	await _save_frame("mathilda_returning")
	await get_tree().create_timer(0.48).timeout
	await _save_frame("mathilda_reforming")
	await get_tree().create_timer(0.8).timeout
	await _save_frame("mathilda_returned")


func _capture_lantern(route: Node3D, experience: Node, name: String) -> void:
	_place_player(33.0)
	experience.set("_stage", 2)
	experience.call("_set_figure_moving", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 34.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 34.0)
	_aim(33.0, 0.48, -3.35, 1.62, 1.0)
	await _save_frame(name)


func _capture_fold_reveal(route: Node3D, experience: Node, name: String) -> void:
	_place_player(42.0)
	experience.set("_stage", 3)
	experience.call("_set_figure_moving", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 50.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 50.0)
	experience.call("_set_caption", "")
	_set_fold_reveal(route, 0.48)
	_aim_between(42.0, 52.0, -8.5, 2.5)
	await _save_frame(name)


func _capture_fold_return(route: Node3D, experience: Node, name: String) -> void:
	_place_player(53.0)
	experience.set("_stage", 4)
	experience.call("_set_figure_moving", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 61.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 61.0)
	experience.call("_set_caption", "")
	_set_fold_reveal(route, 1.0)
	_aim_between(51.0, 58.0, -9.0, 4.2)
	await _save_frame(name)


func _capture_dream_journal(experience: Node, output_name: String) -> void:
	var story: Dictionary = experience.get("_story")
	for beat in story.get("beats", []):
		experience.call("_record_dream_entry", beat.get("journal", {}))
	var events: Array = story.get("events", [])
	if not events.is_empty():
		experience.call("_record_dream_entry", events[0].get("journal", {}))
	var talk_rounds: Array = story.get("small_talk", [])
	if not talk_rounds.is_empty():
		var first_choices: Array = talk_rounds[0].get("choices", [])
		if not first_choices.is_empty():
			experience.call("_record_dream_entry", first_choices[0].get("journal", {}))
	experience.call("_open_dream_journal")
	await _save_frame(output_name)
	experience.call("_close_dream_journal")


func _capture_story_motion(experience: Node, route_offset: float, cue: String, beat_index: int, output_name: String) -> void:
	_place_player(maxf(route_offset - 2.5, 0.0))
	experience.set("_stage", beat_index)
	experience.set("_figure_offset", Game.trail.player_start_offset + route_offset)
	experience.call("_set_figure_moving", false)
	experience.call("_place_figure", Game.trail.player_start_offset + route_offset)
	experience.call("_begin_character_conversation", true)
	var beats: Array = experience.get("_story").get("beats", [])
	if beat_index < beats.size():
		experience.call("_set_caption", str(beats[beat_index].get("text", "")), "MATHILDA")
	_camera.make_current()
	var figure := experience.get("_figure") as Node3D
	var frame := Game.trail.frame_at(experience.get("_figure_offset"))
	_camera.global_position = figure.global_position + frame.basis.x * 0.4 + frame.basis.z * 3.6 + Vector3.UP * 1.8
	_camera.look_at(figure.global_position + Vector3.UP * 1.05, Vector3.UP)
	experience.call("_play_story_choreography", cue)
	await get_tree().create_timer(0.65).timeout
	await _save_frame(output_name + "_moving")
	await get_tree().create_timer(2.3).timeout
	await _save_frame(output_name + "_settled")


func _capture_clearing(route: Node3D, experience: Node, name: String) -> void:
	var architecture := experience.get("_memory_architecture") as DreamMemoryArchitecture
	if architecture:
		architecture.enter_clearing()
	_place_player(58.0)
	experience.set("_stage", 4)
	experience.call("_set_figure_moving", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 61.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 61.0)
	experience.call("_begin_figure_appearance", 0.4)
	experience.call("_pulse_effect", 0.72, "merge")
	_aim_between(58.0, 61.0, 0.9, 1.25)
	await _settle()
	experience.set_process(false)
	experience.set("_apparition_state", 0)
	experience.call("_set_figure_dissolve", 0.0)
	var figure := experience.get("_figure") as Node3D
	if figure:
		figure.show()
	var speech := experience.get("_speech_sprite") as CanvasItem
	if speech:
		speech.hide()
	var lantern_prompt := experience.get("_lantern_prompt") as CanvasItem
	if lantern_prompt:
		lantern_prompt.hide()
	var journal_hint := experience.get("_dream_journal_hint_panel") as CanvasItem
	if journal_hint:
		journal_hint.hide()
	await _save_frame(name, false)


func _capture_choice(route: Node3D, experience: Node, name: String) -> void:
	_place_player(65.0)
	experience.set("_dream_voice_unlocked", true)
	experience.set("_stage", 4)
	experience.set("_figure_offset", Game.trail.player_start_offset + 67.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 67.0)
	experience.set("_camera_choreography_enabled", true)
	experience.call("_finish_dream")
	experience.set("_conversation_intro_waiting", false)
	experience.call("_build_small_talk_choices")
	await _settle()
	await _save_frame(name)


func _capture_warning(experience: Node, name: String) -> void:
	experience.call("_complete_character_conversation")
	experience.set("_camera_choreography_enabled", false)
	_camera.make_current()
	_place_player(70.0)
	experience.get("_choice_panel").hide()
	experience.call("_show_warning_prop")
	experience.call("_set_caption", "The axe waits beside the old stump.", "MATHILDA")
	_aim_between(71.0, 67.0, -1.8, 1.25)
	await _save_frame(name)


func _settle() -> void:
	for _frame in 18:
		await get_tree().process_frame


func _save_frame(name: String, settle_first := true) -> void:
	if settle_first:
		await _settle()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var prefix := "no_effects_" if OS.get_environment("RUN_DREAM_NO_SCREEN_EFFECTS") == "1" else "no_warp_" if OS.get_environment("RUN_DREAM_NO_WARP") == "1" else ""
	var path := ProjectSettings.globalize_path(OUT + prefix + name + ".png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save dream review image %s: %s" % [path, error_string(error)])
