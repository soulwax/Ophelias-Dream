extends Node

## Walks the live dream from opening to waking at real movement speed. Set
## RUN_DREAM_PACE=walk or sprint; configure its user data directory to isolate
## the saved memory and completion record.
const MAIN := preload("res://scenes/main.tscn")
const EXPECTED_MARKERS := ["tree_line", "sisters", "footsteps", "thread", "lantern", "window", "empty_path"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.dream_mode = true
	Game.character_selected = true
	var main := MAIN.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for _frame in 2400:
		if Game.trail and Game.player and Game.phase == Game.Phase.DREAM:
			break
		await get_tree().process_frame
	if not _require(Game.phase == Game.Phase.DREAM, "dream must enter the playable phase"):
		get_tree().quit(1)
		return
	var route := main.find_child("DreamRoute", true, false)
	var experience: Node = route.get_parent() if route else null
	if not _require(experience != null, "live dream experience must exist"):
		get_tree().quit(1)
		return
	var front_door: HouseDoor = Game.house.doors.get("front") as HouseDoor if Game.house else null
	if not _require(front_door != null, "the dream threshold must have its house door"):
		get_tree().quit(1)
		return
	for _shove in front_door.jam_shoves:
		front_door.interact()
	if not front_door.is_open:
		front_door.interact()
	if not _require(front_door.is_open, "the dream walk must pass through the opened house door"):
		get_tree().quit(1)
		return
	experience.set("_camera_choreography_enabled", false)
	var pace := OS.get_environment("RUN_DREAM_PACE")
	if pace.is_empty():
		pace = "walk"
	if not _require(pace in ["walk", "sprint"], "RUN_DREAM_PACE must be walk or sprint"):
		get_tree().quit(1)
		return
	Game.player.set("_autopilot", pace)
	var starting_offset := Game.trail.offset_of(Game.player.global_position)
	var furthest_offset := starting_offset
	var story: Dictionary = experience.get("_story")
	var beats: Array = story.get("beats", [])
	var events: Array = story.get("events", [])
	var seen_markers: Array[String] = []
	var seen_stations: Array[int] = []
	var last_stage := 0
	var last_event := 0
	var journal_and_pause_checked := false
	for frame_index in 12000:
		await get_tree().process_frame
		_steer_along_dream_route()
		furthest_offset = maxf(furthest_offset, Game.trail.offset_of(Game.player.global_position))
		var stage: int = experience.get("_stage")
		var event_index: int = experience.get("_story_event_cue_index")
		if stage > last_stage:
			seen_markers.append(str(beats[stage - 1].get("id", "")))
			last_stage = stage
		if event_index > last_event:
			seen_markers.append(str(events[event_index - 1].get("id", "")))
			last_event = event_index
		if experience.get("_story_line_active"):
			if not journal_and_pause_checked:
				experience.call("_open_dream_journal")
				if not _require(experience.get("_dream_journal_open") and Game.player.dialogue_locked, "journal must hold the dream and player"):
					get_tree().quit(1)
					return
				experience.call("_close_dream_journal")
				if not _require(not Game.player.dialogue_locked, "closing the journal must restore free walking"):
					get_tree().quit(1)
					return
				Game.toggle_pause()
				if not _require(Game.phase == Game.Phase.PAUSED, "pause must interrupt the dream"):
					get_tree().quit(1)
					return
				Game.toggle_pause()
				if not _require(Game.phase == Game.Phase.DREAM, "resume must restore the dream"):
					get_tree().quit(1)
					return
				journal_and_pause_checked = true
			experience.set("_caption_time", 100.0)
			var speech := experience.get("_speech_sprite") as TextureRect
			speech.modulate.a = 0.0
		if experience.get("_story_gap_remaining") > 0.0:
			experience.set("_story_gap_remaining", 0.0)
		if experience.get("_station_dialogue_active"):
			var round_index: int = experience.get("_station_round_index")
			if not seen_stations.has(round_index):
				seen_stations.append(round_index)
				if not _require(experience.get("_choice_buttons").size() == story["small_talk"][round_index]["choices"].size(), "station choices must match their own round"):
					get_tree().quit(1)
					return
				experience.call("_choose_small_talk", 0)
				if not _require(experience.get("_conversation_response") == story["small_talk"][round_index]["choices"][0]["response"], "station must use the displayed response"):
					get_tree().quit(1)
					return
			if experience.get("_conversation_response_pending"):
				experience.call("_reveal_conversation_response")
		if experience.get("_station_dialogue_active") and experience.get("_conversation_response_ready"):
			experience.call("_continue_station_dialogue")
		if not experience.get("_station_dialogue_active") and experience.get("_conversation_waiting"):
			if experience.get("_conversation_response_pending"):
				experience.call("_reveal_conversation_response")
			elif experience.get("_conversation_response_ready"):
				experience.set("_conversation_response_ready", false)
				experience.set("_conversation_waiting", false)
				if experience.get("_answer_open"):
					experience.set("_conversation_round", int(experience.get("_conversation_round")) + 1)
					experience.call("_build_small_talk_choices")
		if experience.get("_conversation_intro_waiting"):
			experience.set("_conversation_intro_waiting", false)
			experience.call("_build_small_talk_choices")
		if experience.get("_answer_open") and not experience.get("_station_dialogue_active") and experience.get("_conversation_round") < story["small_talk"].size() and not experience.get("_conversation_waiting"):
			experience.call("_choose_small_talk", 0)
		if experience.get("_answer_open") and not experience.get("_station_dialogue_active") and experience.get("_conversation_response_pending"):
			experience.call("_reveal_conversation_response")
		if experience.get("_answer_open") and not experience.get("_station_dialogue_active") and experience.get("_conversation_response_ready"):
			experience.set("_conversation_response_ready", false)
			experience.set("_conversation_waiting", false)
			experience.set("_conversation_round", int(experience.get("_conversation_round")) + 1)
			experience.call("_build_small_talk_choices")
		if experience.get("_answer_open") and experience.get("_choice_buttons").size() == story["branches"].size() and experience.get("_conversation_round") >= story["small_talk"].size():
			break
	if not _require(furthest_offset - starting_offset >= 60.0, "player must physically walk to the clearing: %.2f m" % (furthest_offset - starting_offset)):
		get_tree().quit(1)
		return
	if not _require(seen_markers == EXPECTED_MARKERS, "%s pace cue order: %s" % [pace, seen_markers]):
		get_tree().quit(1)
		return
	if not _require(seen_stations == [0, 1], "station replies must follow their cues: %s" % [seen_stations]):
		get_tree().quit(1)
		return
	if not _require(experience.get("_story_line_queue").is_empty(), "no story line may be discarded"):
		get_tree().quit(1)
		return
	if not _require(experience.get("_answer_open"), "the final choice must become available"):
		get_tree().quit(1)
		return
	if not _require(journal_and_pause_checked, "journal and pause must be exercised on a line"):
		get_tree().quit(1)
		return
	if not _exercise_endings(experience):
		get_tree().quit(1)
		return
	if not await _exercise_standalone_exit(experience):
		get_tree().quit(1)
		return
	print("Dream flow checked at %s pace: %.1f m traversed, ordered cues, two station replies, journal/pause, chosen memory saved, wake completed, title returned" % [pace, furthest_offset - starting_offset])
	get_tree().quit()


func _exercise_endings(experience: Node) -> bool:
	var previous_cues: Dictionary = experience.get("_seen_story_cues").duplicate(true)
	var previous_strain: int = experience.get("_conversation_strain")
	var previous_outcome := str(experience.get("_dream_outcome"))
	var previous_understood: bool = experience.get("_dream_understood")
	experience.set("_conversation_strain", 0)
	experience.set("_seen_story_cues", {"window": true, "sisters": true})
	experience.call("_ending_text")
	if not _require(experience.get("_dream_outcome") == "complete", "window and another cue must reach the complete ending"):
		return false
	experience.set("_seen_story_cues", {})
	experience.call("_ending_text")
	if not _require(experience.get("_dream_outcome") == "unresolved", "missing clues must reach the unresolved ending"):
		return false
	experience.set("_conversation_strain", 4)
	experience.call("_ending_text")
	if not _require(experience.get("_dream_outcome") == "ruptured", "high conversation strain must reach the ruptured ending"):
		return false
	experience.set("_conversation_strain", previous_strain)
	experience.set("_seen_story_cues", previous_cues)
	experience.set("_dream_outcome", previous_outcome)
	experience.set("_dream_understood", previous_understood)
	return true


func _exercise_standalone_exit(experience: Node) -> bool:
	var sandbox_path: String = ProjectSettings.globalize_path("user://")
	if not _require(sandbox_path.contains("DreamFlowPlayabilityAudit"), "launch with application/config/custom_user_dir_name=DreamFlowPlayabilityAudit to isolate the save"):
		return false
	Game.dream_memory = ""
	Game.dream_completed = false
	experience.call("_choose_memory", "name")
	if not _require(Game.dream_memory == "name" and not Game.dream_completed, "the choice must save before waking"):
		return false
	var save := ConfigFile.new()
	if not _require(save.load("user://dream.cfg") == OK, "the selected memory must persist"):
		return false
	if not _require(save.get_value("dream", "memory", "") == "name", "saved memory must match the answer"):
		return false
	experience.call("_reveal_conversation_response")
	experience.call("_continue_memory_dialogue")
	if not _require(experience.get("_waking_card") and Game.phase == Game.Phase.DIALOGUE, "closing response must lead to the waking card"):
		return false
	if not _require(not Game.dream_completed, "completion waits until the waking card is dismissed"):
		return false
	var return_event := InputEventAction.new()
	return_event.action = &"interact"
	return_event.pressed = true
	return_event.strength = 1.0
	experience.call("_unhandled_input", return_event)
	if not _require(Game.dream_completed, "waking card dismissal must mark the dream complete"):
		return false
	if not _require(Game.phase == Game.Phase.BOOT and not Game.dream_mode, "waking must return to the title phase"):
		return false
	if not _require(save.load("user://dream.cfg") == OK and bool(save.get_value("dream", "completed", false)), "completion must persist beside the chosen memory"):
		return false
	for _frame in 1200:
		var scene := get_tree().current_scene
		if scene and scene.find_child("TitleMenu", true, false):
			break
		await get_tree().process_frame
	var title := get_tree().current_scene
	if not _require(title and title.find_child("TitleMenu", true, false), "waking card must return to the title menu"):
		return false
	return true


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false


func _steer_along_dream_route() -> void:
	var trail: Trail = Game.trail
	var player: Player = Game.player
	var offset := trail.offset_of(player.global_position)
	var nearest := trail.position_at(offset)
	var cross_track := Vector2(player.global_position.x - nearest.x, player.global_position.z - nearest.z).length()
	if offset < trail.player_start_offset - 1.0:
		return
	var heading_vector := nearest - player.global_position if cross_track > 4.0 else trail.position_at(minf(offset + 2.0, trail.length)) - nearest
	heading_vector.y = 0.0
	if heading_vector.length_squared() < 0.01:
		return
	var heading := atan2(-heading_vector.x, -heading_vector.z)
	player.set("_yaw", heading)
	player.set("_facing", heading)
	player.call("_apply_look")
