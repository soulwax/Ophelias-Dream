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
	experience.set("_camera_choreography_enabled", false)
	await _capture_entry(route, "entry")
	await _capture_figure_apparition(experience)
	await _capture_lantern(route, experience, "lantern")
	await _capture_fold_reveal(route, experience, "fold_reveal")
	await _capture_fold_return(route, experience, "fold_return")
	await _capture_landscape(route, "Flashback_Lighthouse", 20.0, 21.0, "lighthouse")
	await _capture_landscape(route, "Flashback_Cabin", 35.0, 5.2, "cabin")
	await _capture_landscape(route, "Flashback_DoorwayHorizon", 50.0, 4.5, "doorway_horizon")
	await _capture_flashback(route, "sisters", 13.0, "Flashback_Sisters", "sisters")
	await _capture_flashback(route, "thread", 29.0, "Flashback_AriadneThread", "thread")
	await _capture_flashback(route, "window", 44.0, "Flashback_WatchingWindow", "watching_window")
	await _capture_queued_flashback(route, experience, "sisters", 13.0, "insight_sisters")
	await _capture_queued_flashback(route, experience, "thread", 29.0, "insight_thread")
	await _capture_queued_flashback(route, experience, "window", 44.0, "insight_window")
	await _capture_dream_door(route, "sisters", 15.0, "door_sisters_open")
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


func _capture_landscape(route: Node3D, name: String, route_offset: float, focus_height: float, output_name: String) -> void:
	var landmark := route.get_node_or_null(name) as Node3D
	if landmark == null:
		push_error("Dream landmark was not built: %s" % name)
		return
	_place_player(route_offset)
	var original_fov := _camera.fov
	_camera.fov = 68.0
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + route_offset)
	_camera.global_position = Game.trail.on_ground(frame.origin) + Vector3.UP * 12.0
	_camera.look_at(landmark.global_position + Vector3.UP * focus_height, Vector3.UP)
	await _save_frame(output_name)
	_camera.fov = original_fov


func _capture_flashback(route: Node3D, cue_id: String, route_offset: float, landmark_name: String, output_name: String) -> void:
	var landmark := route.get_node_or_null(landmark_name) as Node3D
	if landmark == null:
		push_error("Dream flashback was not built: %s" % landmark_name)
		return
	_place_player(route_offset)
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + route_offset)
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	var focus_height := float(landmark.get_meta("insight_focus_height", 8.0))
	_camera.global_position = Game.player.global_position + across * 4.2 + Vector3.UP * 1.8
	_camera.look_at(landmark.global_position + Vector3.UP * focus_height, Vector3.UP)
	_camera.fov = 60.0
	route.call("play_flashback", cue_id)
	await _save_frame(output_name)


func _capture_queued_flashback(route: Node3D, experience: Node, cue_id: String, route_offset: float, output_name: String) -> void:
	_place_player(route_offset)
	var flashback := route.call("play_flashback", cue_id) as Node3D
	if flashback == null:
		push_error("Dream insight vignette was not built: %s" % cue_id)
		return
	var original_fov := _camera.fov
	_camera.fov = 68.0
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + route_offset)
	_camera.global_position = Game.trail.on_ground(frame.origin) + Vector3.UP * 12.0
	var focus_height := float(flashback.get_meta("insight_focus_height", 3.0))
	_camera.look_at(flashback.global_position + Vector3.UP * focus_height, Vector3.UP)
	experience.call("_pulse_effect", 0.96, "insight", flashback)
	await _save_frame(output_name)
	_camera.fov = original_fov


func _capture_dream_door(route: Node3D, door_id: String, route_offset: float, output_name: String) -> void:
	var doors: Array = route.call("dream_doors")
	var door: Node3D
	for candidate in doors:
		if str(candidate.get("door_id")) == door_id:
			door = candidate as Node3D
			break
	if door == null:
		push_error("Dream threshold was not built: %s" % door_id)
		return
	_place_player(route_offset - 3.0)
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + route_offset - 3.0)
	var ahead := Game.trail.frame_at(Game.trail.player_start_offset + route_offset - 2.0).origin - frame.origin
	ahead.y = 0.0
	ahead = ahead.normalized()
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	_camera.fov = 58.0
	_camera.global_position = Game.player.global_position + across * 2.4 - ahead * 1.2 + Vector3.UP * 1.7
	_camera.look_at(door.global_position + Vector3.UP * 1.4, Vector3.UP)
	_camera.make_current()
	door.call("interact")
	await get_tree().create_timer(1.2).timeout
	await _save_frame(output_name)


func _capture_dream_journal(experience: Node, output_name: String) -> void:
	var story: Dictionary = experience.get("_story")
	for beat in story.get("beats", []):
		experience.call("_record_dream_entry", beat.get("journal", {}))
	var doors: Array = story.get("doors", [])
	if not doors.is_empty():
		experience.call("_record_dream_entry", doors[0].get("journal", {}))
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
	_place_player(58.0)
	experience.set("_stage", 4)
	experience.call("_set_figure_moving", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 61.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 61.0)
	experience.call("_pulse_effect", 0.72, "merge")
	_aim(58.0, 0.48, -3.35, 1.62, 1.1)
	await _settle()
	await _save_frame(name)


func _capture_choice(route: Node3D, experience: Node, name: String) -> void:
	_place_player(65.0)
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


func _save_frame(name: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save dream review image %s: %s" % [path, error_string(error)])
