extends Node

## One rolling, platform-local run snapshot. The world is regenerated from its
## seed, then this state is laid over the rebuilt systems.
const PATH := "user://run_save.cfg"
const TEMP_PATH := "user://run_save.cfg.tmp"
const BACKUP_PATH := "user://run_save.cfg.bak"
const SNAPSHOT_VERSION := 3
const AUTOSAVE_SECONDS := 12.0

var _pending: Dictionary = {}
var _load_queued := false
var _autosave_left := AUTOSAVE_SECONDS
var _restoring := false
var last_status := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED] and Game.player:
		save_now()


func _process(delta: float) -> void:
	if _restoring or Game.player == null or Game.phase in [Game.Phase.BOOT, Game.Phase.CAUGHT, Game.Phase.ESCAPED]:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_SECONDS
		save_now()


func has_save() -> bool:
	return not _read_candidate(PATH).is_empty() or not _read_candidate(BACKUP_PATH).is_empty()


func load_snapshot() -> Dictionary:
	var primary := _read_candidate(PATH)
	if not primary.is_empty():
		last_status = "Run save loaded."
		return primary
	var backup := _read_candidate(BACKUP_PATH)
	if not backup.is_empty():
		last_status = "The main save was damaged; recovered the previous save."
		return backup
	last_status = "No valid run save was found."
	return {}


func save_now() -> bool:
	if Game.player == null or Game.trail == null or Game.phase == Game.Phase.BOOT:
		return false
	var active_phase := Game._paused_phase if Game.phase == Game.Phase.PAUSED else Game.phase
	var snapshot := {
		"version": SNAPSHOT_VERSION,
		"dream_mode": Game.dream_mode,
		"mathilda_pov": Game.mathilda_pov,
		"world_seed": Game.trail.seed_value,
		"phase": int(active_phase),
		"was_paused": Game.phase == Game.Phase.PAUSED,
		"game": _capture_game(),
		"player": _capture_player(),
		"house": Game.house.capture_run_state() if Game.house else {},
		"weather": _capture_properties(Game.weather, ["regime", "intensity", "gust", "whiteout", "flurry", "wind", "wind_scroll", "shelter", "snow_scale", "dream_quiet", "_heading", "_heading_target", "_gust_target", "_intensity_target", "_whiteout_target", "_flurry_target", "_regime_clock", "_pulse_clock", "_clock", "_pinned_regime"]),
		"atmosphere": _capture_properties(_atmosphere(), ["shelter", "snow_cover", "clock_hours", "clock_running"]),
		"chapter": _capture_properties(_chapter(), ["_mathilda_seen", "_pending", "_idle_left", "_place", "_chapter_finished", "_going_home", "_inspected", "_found_photo"]),
		"voice": _capture_properties(Game.voice, ["_pages", "_deciphered", "_places", "_revisits", "_bored", "_memories", "_spent", "_cold", "_falls", "_turned", "_endings", "_answers", "_moments", "_chores", "_encounters", "hushed", "_calls", "_misread", "_spoken", "_heard_pages", "_said_deciphered", "_seen", "_first_seen", "_revisited", "_bored_at", "_memory_at", "_cold_at", "_cold_next", "_outdoor_time", "_spent_at", "_fall_at", "_ending_ticket", "_answer_close", "_echo_stopped_early", "_call_at", "_call_left", "_echoed", "_echoes", "_pending_echo_stage", "_echo_ticket", "_misread_at", "_clock", "_place_dwell", "_last_place", "_returning", "_still", "_since"]),
		"dialogue": _capture_dialogue(),
		"journal_ui": _capture_ui("journal", "capture_run_state"),
		"reader_ui": _capture_ui("reader", "capture_run_state"),
		"dream": _capture_dream(),
		"dream_architecture": _capture_dream_architecture(),
		"dream_route": _capture_properties(_dream_route(), ["_fold_reveal"]),
		"dream_soundscape": _capture_dream_soundscape(),
		"errands": Game.errands.capture() if Game.errands else {},
	}
	if not _valid_snapshot(snapshot):
		last_status = "The current run could not be saved because its state failed validation."
		push_warning(last_status)
		return false
	var file := ConfigFile.new()
	var snapshot_text := var_to_str(snapshot)
	file.set_value("run", "schema", SNAPSHOT_VERSION)
	file.set_value("run", "checksum", _checksum_text(snapshot_text))
	file.set_value("run", "snapshot_text", snapshot_text)
	var result := file.save(TEMP_PATH)
	if result != OK:
		last_status = "Could not write the temporary save: %s" % error_string(result)
		push_warning(last_status)
		return false
	var staged := _read_candidate(TEMP_PATH)
	if staged.is_empty():
		_remove_path(TEMP_PATH)
		last_status = "The temporary save failed its read-back check."
		push_warning(last_status)
		return false
	var old_primary := _read_candidate(PATH)
	if not old_primary.is_empty():
		_remove_path(BACKUP_PATH)
		var move_old := _rename_path(PATH, BACKUP_PATH)
		if move_old != OK:
			_remove_path(TEMP_PATH)
			last_status = "Could not preserve the previous save: %s" % error_string(move_old)
			push_warning(last_status)
			return false
	else:
		# A damaged primary must not displace a valid recovery copy.
		_remove_path(PATH)
	var promote := _rename_path(TEMP_PATH, PATH)
	if promote != OK:
		if not old_primary.is_empty():
			_rename_path(BACKUP_PATH, PATH)
		last_status = "Could not install the new save: %s" % error_string(promote)
		push_warning(last_status)
		return false
	last_status = "Run saved."
	return true


func queue_load() -> bool:
	_pending = load_snapshot()
	_load_queued = not _pending.is_empty()
	return _load_queued


func _read_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null:
		return {}
	var byte_count := source.get_length()
	source.close()
	if byte_count <= 0 or byte_count > 32 * 1024 * 1024:
		return {}
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return {}
	var schema: Variant = file.get_value("run", "schema", null)
	if schema == null:
		# Version 1 was the original unwrapped format; accept it for migration.
		if not file.has_section_key("run", "snapshot"):
			return {}
		var legacy: Variant = file.get_value("run", "snapshot", null)
		if not legacy is Dictionary or not _valid_snapshot(legacy):
			return {}
		if int(legacy.get("version", 0)) != 1:
			return {}
		legacy["version"] = SNAPSHOT_VERSION
		return legacy
	if not schema is int or int(schema) not in [2, SNAPSHOT_VERSION]:
		return {}
	var digest: Variant = file.get_value("run", "checksum", null)
	if not digest is String:
		return {}
	var value: Variant
	if int(schema) == SNAPSHOT_VERSION:
		var snapshot_text: Variant = file.get_value("run", "snapshot_text", null)
		if not snapshot_text is String or str(digest) != _checksum_text(snapshot_text):
			return {}
		value = str_to_var(snapshot_text)
	else:
		value = file.get_value("run", "snapshot", null)
		if not value is Dictionary or str(digest) != _checksum(value):
			return {}
	if not value is Dictionary or not _valid_snapshot(value):
		return {}
	return value


func _valid_snapshot(value: Dictionary) -> bool:
	if value.size() > 64 or not _valid_tree(value, 0):
		return false
	if int(value.get("version", 0)) not in [1, 2, SNAPSHOT_VERSION]:
		return false
	if not value.get("game", null) is Dictionary or not value.get("player", null) is Dictionary:
		return false
	for section: String in ["house", "weather", "atmosphere", "chapter", "voice", "dialogue", "journal_ui", "reader_ui", "dream", "dream_architecture", "dream_route", "dream_soundscape", "errands"]:
		if value.has(section) and not value[section] is Dictionary:
			return false
	if not value.get("world_seed", null) is int or not value.get("phase", null) is int:
		return false
	if int(value.world_seed) < -2147483648 or int(value.world_seed) > 2147483647:
		return false
	if int(value.phase) < 0 or int(value.phase) > int(Game.Phase.DIALOGUE):
		return false
	if not value.get("dream_mode", null) is bool or not value.get("mathilda_pov", null) is bool:
		return false
	var transform: Variant = value.player.get("global_transform", null)
	var velocity: Variant = value.player.get("velocity", null)
	if not transform is Transform3D or not velocity is Vector3:
		return false
	if value.game.has("journal_titles") and not _is_string_array(value.game.journal_titles):
		return false
	if value.game.has("active_note_title") and not value.game.active_note_title is String:
		return false
	if value.game.has("checkpoint") and not value.game.checkpoint is Dictionary:
		return false
	if value.game.has("checkpoint") and value.game.checkpoint.has("journal_titles") and not _is_string_array(value.game.checkpoint.journal_titles):
		return false
	if value.has("was_paused") and not value.was_paused is bool:
		return false
	return true


func _is_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for item: Variant in value:
		if not item is String:
			return false
	return true


func _valid_tree(value: Variant, depth: int) -> bool:
	if depth > 20:
		return false
	if value is Dictionary:
		if value.size() > 4096:
			return false
		for key: Variant in value:
			if not (key is String or key is int) or not _valid_tree(value[key], depth + 1):
				return false
		return true
	if value is Array:
		if value.size() > 16384:
			return false
		for item: Variant in value:
			if not _valid_tree(item, depth + 1):
				return false
		return true
	if value is float:
		return is_finite(value)
	if value is Vector2:
		return is_finite(value.x) and is_finite(value.y)
	if value is Vector3:
		return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
	if value is Vector4:
		return is_finite(value.x) and is_finite(value.y) and is_finite(value.z) and is_finite(value.w)
	if value is Color:
		return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	if value is Transform3D:
		return _valid_tree(value.basis, depth + 1) and _valid_tree(value.origin, depth + 1)
	if value is Transform2D:
		return _valid_tree(value.x, depth + 1) and _valid_tree(value.y, depth + 1) and _valid_tree(value.origin, depth + 1)
	if value is Basis:
		return _valid_tree(value.x, depth + 1) and _valid_tree(value.y, depth + 1) and _valid_tree(value.z, depth + 1)
	if value is Quaternion:
		return is_finite(value.x) and is_finite(value.y) and is_finite(value.z) and is_finite(value.w)
	if value is PackedFloat32Array or value is PackedFloat64Array:
		for item: float in value:
			if not is_finite(item):
				return false
	return _serializable(value)


func _checksum(value: Dictionary) -> String:
	return _checksum_text(_canonical(value))


func _checksum_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var entries_object: PackedStringArray = []
		for key: Variant in keys:
			entries_object.append(_canonical(key) + ":" + _canonical(value[key]))
		return "{" + ",".join(entries_object) + "}"
	if value is Array:
		var entries_array: PackedStringArray = []
		for item: Variant in value:
			entries_array.append(_canonical(item))
		return "[" + ",".join(entries_array) + "]"
	return var_to_str(value)


func _remove_path(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)


func _rename_path(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))


func has_pending_load() -> bool:
	return _load_queued and not _pending.is_empty()


func pending_snapshot() -> Dictionary:
	return _pending.duplicate(true) if has_pending_load() else {}


func apply_pending() -> bool:
	if not has_pending_load() or Game.player == null:
		return false
	_restoring = true
	var data := _pending
	_apply_game(data.get("game", {}))
	_apply_properties(Game.weather, data.get("weather", {}))
	_apply_properties(_atmosphere(), data.get("atmosphere", {}))
	_apply_properties(_chapter(), data.get("chapter", {}))
	_apply_properties(Game.voice, data.get("voice", {}))
	_apply_properties(_dream(), data.get("dream", {}))
	_apply_properties(_dream_architecture(), data.get("dream_architecture", {}))
	_apply_properties(_dream_route(), data.get("dream_route", {}))
	_apply_player(data.get("player", {}))
	if Game.house and data.get("house", {}) is Dictionary:
		Game.house.restore_run_state(data.get("house", {}))
	# After the player, whose carrying_item_id says what is back in her arms.
	if Game.errands and data.get("errands", {}) is Dictionary:
		Game.errands.restore(data.get("errands", {}))
	_refresh_field_pages()
	var desired_phase: Game.Phase = int(data.get("phase", Game.Phase.PLAYING))
	if desired_phase not in [Game.Phase.INTRO, Game.Phase.DREAM, Game.Phase.PLAYING, Game.Phase.READING, Game.Phase.JOURNAL, Game.Phase.PAUSED, Game.Phase.CAUGHT, Game.Phase.ESCAPED, Game.Phase.DIALOGUE]:
		desired_phase = Game.Phase.DREAM if Game.dream_mode else Game.Phase.PLAYING
	if desired_phase == Game.Phase.PAUSED:
		desired_phase = Game.Phase.DREAM if Game.dream_mode else Game.Phase.PLAYING
	Game.set_phase(desired_phase)
	Engine.time_scale = 0.4 if desired_phase == Game.Phase.CAUGHT else 1.0
	if _dream() and _dream().has_method("restore_after_load"):
		_dream().call("restore_after_load", data.get("dream", {}))
	_restore_dream_soundscape(data.get("dream_soundscape", {}))
	_restore_ui("journal", "restore_run_state", data.get("journal_ui", {}))
	_restore_ui("reader", "restore_run_state", data.get("reader_ui", {}))
	if _chapter() and _chapter().has_method("restore_after_load"):
		_chapter().call("restore_after_load")
	_restore_dialogue(data.get("dialogue", {}))
	if bool(data.get("was_paused", false)):
		Game.toggle_pause()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if desired_phase in [Game.Phase.READING, Game.Phase.JOURNAL, Game.Phase.DIALOGUE, Game.Phase.CAUGHT, Game.Phase.ESCAPED] else Input.MOUSE_MODE_CAPTURED
	_load_queued = false
	_pending.clear()
	_restoring = false
	_autosave_left = AUTOSAVE_SECONDS
	return true


func return_to_title() -> void:
	save_now()
	Game.character_selected = false
	Game.dream_mode = false
	Game.mathilda_pov = false
	Game._resume = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _capture_game() -> Dictionary:
	var result := _capture_properties(Game, [
		"closeness", "intro_left", "notes_found", "has_lantern", "lantern_equipped", "has_bow", "arrow_count", "arrow_pickups",
		"dread", "threat_hint", "something_at_door", "murmur", "murmur_left", "murmur_speaker",
		"passings", "understood", "read_last_page", "journal_focus", "read_pages", "visited",
		"heard_events", "deciphered", "turned_around", "_turn_hold", "at_checkpoint",
		"day_seconds", "day_running", "_moments_said", "ending_kind", "meeting_waiting", "_unready_said",
		"hunt_started", "_hunt_seconds", "audio_fade", "_audio_hold", "dream_memory", "dream_completed",
		"ending_title", "ending_body"
	])
	result["journal_titles"] = Game.journal.map(func(entry: NoteEntry) -> String: return entry.title)
	result["active_note_title"] = Game.active_note.entry.title if Game.active_note and Game.active_note.entry else ""
	result["checkpoint"] = _capture_checkpoint()
	return result


func _apply_game(data: Dictionary) -> void:
	_apply_properties(Game, data)
	Game.journal.clear()
	for title: String in data.get("journal_titles", []):
		var entry := NoteCatalog.find(title)
		if entry:
			Game.journal.append(entry)
	Game.active_note = _find_note(str(data.get("active_note_title", "")))
	Game.checkpoint = data.get("checkpoint", {}).duplicate(true)
	if not Game.checkpoint.is_empty():
		Game.checkpoint["journal"] = []
		for title: String in Game.checkpoint.get("journal_titles", []):
			var checkpoint_entry := NoteCatalog.find(title)
			if checkpoint_entry:
				Game.checkpoint["journal"].append(checkpoint_entry)
		Game.checkpoint.erase("journal_titles")
	if Game.player:
		Game.player.dialogue_locked = false
	Game.journal_changed.emit()


func _capture_player() -> Dictionary:
	var fields := [
		"stamina", "_yaw", "_pitch", "exhaust_left", "_sprinting", "_sprint_latch", "_left_foot", "_glide",
		"_since_plant", "_step_time", "_coyote", "_jump_buffer", "_airborne", "_jumped", "_air_time",
		"_fall_speed", "_air_weight", "leaping", "leap", "leap_lead_left", "_leap_airtime", "sliding",
		"_slide_time", "_slide_speed", "_slide_dir", "_slide_weight", "_spray_in", "_autopilot_clock",
		"_travel", "_stride_phase", "_jolt", "_roll_kick", "_boom", "_shoulder", "_glow", "_trail_offset",
		"_camera_lead", "_rise_lag", "strain", "_facing", "_lean", "_sway", "_last_glide", "glance", "_look_ramp"
	]
	var result := _capture_properties(Game.player, fields)
	result["global_transform"] = Game.player.global_transform
	result["velocity"] = Game.player.velocity
	result["lantern_present"] = Game.has_lantern
	result["lantern_equipped"] = Game.lantern_equipped
	result["bow_present"] = Game.has_bow
	result["carrying_item_id"] = Game.player.carrying.item_id if is_instance_valid(Game.player.carrying) else Game.player.carrying_item_id
	return result


func _apply_player(data: Dictionary) -> void:
	if data.has("global_transform"):
		Game.player.global_transform = data["global_transform"]
	Game.player.velocity = data.get("velocity", Vector3.ZERO)
	_apply_properties(Game.player, data)
	# Errands resolves this stable id once its saved items/sockets are restored.
	Game.player.carrying_item_id = str(data.get("carrying_item_id", "")) if not Game.dream_mode and not Game.mathilda_pov else ""
	Game.player.dialogue_locked = false
	Game.player.reset_physics_interpolation()
	Game.player.call("_apply_look")
	if Game.has_lantern:
		Game.player.restore_lantern(Game.lantern_equipped)
		for pickup in get_tree().get_nodes_in_group("lantern_pickup"):
			pickup.call("remove_found_lantern")
	if Game.has_bow:
		Game.player.restore_bow()
		for pickup in get_tree().get_nodes_in_group("bow_pickup"):
			pickup.call("remove_found_bow")


func _capture_properties(target: Object, keys: Array) -> Dictionary:
	var result := {}
	if target == null or not is_instance_valid(target):
		return result
	for key: String in keys:
		if not _has_property(target, key):
			continue
		var value: Variant = target.get(key)
		if _serializable(value):
			result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func _apply_properties(target: Object, values: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	for key: Variant in values:
		if not key is String or not _has_property(target, key):
			continue
		var current: Variant = target.get(key)
		var incoming: Variant = values[key]
		if typeof(current) != typeof(incoming):
			continue
		if incoming is float and not is_finite(incoming):
			continue
		target.set(key, incoming)


func _has_property(target: Object, key: String) -> bool:
	for info: Dictionary in target.get_property_list():
		if str(info.get("name", "")) == key:
			return true
	return false


func _serializable(value: Variant) -> bool:
	return value == null or value is bool or value is int or value is float or value is String \
		or value is Vector2 or value is Vector3 or value is Vector4 or value is Color \
		or value is Transform2D or value is Transform3D or value is Quaternion or value is Basis \
		or value is Array or value is Dictionary or value is PackedByteArray or value is PackedInt32Array \
		or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array \
		or value is PackedStringArray or value is PackedVector2Array or value is PackedVector3Array \
		or value is PackedColorArray


func capture_properties(target: Object, keys: Array) -> Dictionary:
	return _capture_properties(target, keys)


func apply_properties(target: Object, values: Dictionary) -> void:
	_apply_properties(target, values)


func _atmosphere() -> Object:
	return get_tree().get_first_node_in_group("atmosphere")


func _chapter() -> Object:
	for child in get_tree().current_scene.get_children():
		if child.get_script() == load("res://scripts/player/mathilda_pov.gd"):
			return child
	return null


func _dream() -> Object:
	for child in get_tree().current_scene.get_children():
		if child.get_script() == load("res://scripts/world/dream_experience.gd"):
			return child
	return null


func _dream_state_keys() -> Array:
	return [
		"_figure_offset", "_figure_moving", "_figure_rambling", "_figure_motion_active", "_figure_motion_target_offset",
		"_figure_motion_look_at_player", "_figure_turn_active", "_figure_turn_target_yaw",
		"_rambling_gaze_target", "_apparition_state",
		"_apparition_timer", "_apparition_dissolve", "_apparition_link_strength", "_boundary_strength",
		"_lantern_time", "_lantern_wait", "_lantern_sheltered", "_lantern_seen", "_lantern_left_once", "_lantern_returned", "_lantern_wind_quiet",
		"_dream_quiet", "_dream_quiet_after_response", "_dream_elapsed", "_dream_voice_unlocked", "_opening_station_pending",
		"_conversation_camera_active", "_conversation_camera_returning",
		"_conversation_camera_return_time", "_camera_choreography_enabled", "_conversation_response",
		"_conversation_response_pending", "_conversation_response_ready", "_conversation_response_timer", "_choice_index",
		"_choice_time", "_answer_open", "_conversation_intro_waiting", "_conversation_round", "_station_dialogue_active",
		"_station_round_index", "_station_after_line", "_station_choice_effect", "_completed_talk_rounds",
		"_conversation_waiting", "_conversation_strain", "_repair_menu_attempts", "_repair_menu_active",
		"_conversation_choice_advances", "_dream_outcome", "_ending_warning_shown", "_waking_card",
		"_dialogue_ui_hidden_for_pause", "_pause_speech_visible", "_pause_choice_panel_visible", "_pause_lantern_prompt_visible",
		"_journal_speech_visible", "_journal_choice_visible", "_journal_lantern_visible", "_story_line_queue",
		"_pending_station_rounds", "_story_line_active", "_story_line_hold", "_story_gap_remaining", "_story_finish_pending",
		"_late_step_stop_time", "_late_step_dialogue_delay", "_late_step_ready",
		"_window_interval_elapsed", "_window_interval_complete",
		"_stage", "_finished", "_memory_chosen", "_caption_time", "_effect_strength", "_effect_target", "_effect_hold",
		"_effect_cue", "_story_event_cue_index", "_seen_story_cues", "_dream_understood", "_dream_journal_entries",
		"_dream_journal_seen", "_dream_journal_available", "_dream_journal_open", "_journal_guidance_visible",
		"_dream_journal_hint_time"
	]


func _capture_dream() -> Dictionary:
	var target := _dream()
	var values := _capture_properties(target, _dream_state_keys())
	if target and target.get("_caption"):
		values["caption_text"] = target.get("_caption").text
		values["speech_visible"] = target.get("_speech_sprite").visible
		values["speaker_text"] = target.get("_speaker_label").text
		var caption_action := target.get("_caption_action") as HBoxContainer
		values["caption_action_visible"] = caption_action.visible
		values["caption_action_text"] = (caption_action.get_child(1) as Label).text
	if target and target.get("_figure"):
		values["figure_transform"] = target.get("_figure").global_transform
	if target and target.get("_lantern"):
		values["lantern_transform"] = target.get("_lantern").global_transform
		values["lantern_visible"] = target.get("_lantern").visible
	if target and target.get("_lantern_light"):
		values["lantern_light_energy"] = target.get("_lantern_light").light_energy
	if target and target.get("_lantern_flame"):
		values["lantern_flame_scale"] = target.get("_lantern_flame").scale
	if target and target.get("_warning_prop"):
		values["warning_prop_visible"] = target.get("_warning_prop").visible
	if target and target.get("_choice_panel"):
		values["choice_visible"] = target.get("_choice_panel").visible
		values["choice_title"] = str(target.get("_choice_title").text).trim_prefix("MATHILDA · ")
		values["choice_hint"] = target.get("_choice_hint").text
		values["choice_labels"] = target.get("_choice_buttons").map(func(label: Label) -> String: return label.text.trim_prefix("◆  ").trim_prefix("◇  "))
	if target and target.get("_lantern_prompt"):
		values["lantern_prompt_visible"] = target.get("_lantern_prompt").visible
	return values


func _dream_soundscape() -> Object:
	var dream := _dream()
	return dream.get("_dream_soundscape") if dream else null


func _dream_architecture() -> Object:
	var dream := _dream()
	return dream.get("_memory_architecture") if dream else null


func _dream_route() -> Object:
	var dream := _dream()
	return dream.get("_dream_route") if dream else null


func _capture_dream_architecture() -> Dictionary:
	return _capture_properties(_dream_architecture(), ["_states", "_values", "_elapsed", "_queued_reveals", "_suspended", "_closing", "_pressure", "_pressure_target", "_time", "_bearing_follow"])


func _capture_dream_soundscape() -> Dictionary:
	var target := _dream_soundscape()
	var values := _capture_properties(target, ["_last_clip", "_next_pair", "_second_step_in", "_cued_step_in", "_cued_step_position", "_apparition_quiet_time", "_memory_target_db", "_memory_hold", "_suspended", "_travel_quiet", "_travel_quiet_weight"])
	if target and target.get("_memory_bed"):
		var bed: AudioStreamPlayer3D = target.get("_memory_bed")
		values["bed_playing"] = bed.playing
		values["bed_position"] = bed.get_playback_position()
		values["bed_transform"] = bed.global_transform
		values["bed_volume"] = bed.volume_db
		values["bed_pitch"] = bed.pitch_scale
	if target and target.get("_wood_creak"):
		var creak: AudioStreamPlayer3D = target.get("_wood_creak")
		values["creak_playing"] = creak.playing
		values["creak_position"] = creak.get_playback_position()
		values["creak_transform"] = creak.global_transform
		values["creak_volume"] = creak.volume_db
		values["creak_pitch"] = creak.pitch_scale
	return values


func _restore_dream_soundscape(state: Dictionary) -> void:
	var target := _dream_soundscape()
	if target == null:
		return
	_apply_properties(target, state)
	var bed: AudioStreamPlayer3D = target.get("_memory_bed")
	if bed:
		if state.has("bed_transform"):
			bed.global_transform = state.bed_transform
		bed.volume_db = float(state.get("bed_volume", bed.volume_db))
		bed.pitch_scale = float(state.get("bed_pitch", bed.pitch_scale))
		if bool(state.get("bed_playing", false)):
			bed.play(float(state.get("bed_position", 0.0)))
		else:
			bed.stop()
	var creak: AudioStreamPlayer3D = target.get("_wood_creak")
	if creak:
		if state.has("creak_transform"):
			creak.global_transform = state.creak_transform
		creak.volume_db = float(state.get("creak_volume", creak.volume_db))
		creak.pitch_scale = float(state.get("creak_pitch", creak.pitch_scale))
		if bool(state.get("creak_playing", false)):
			creak.play(float(state.get("creak_position", 0.0)))
		else:
			creak.stop()


func _capture_dialogue() -> Dictionary:
	if Game.dialogue == null or not Game.dialogue.has_method("capture_run_state"):
		return {}
	return Game.dialogue.call("capture_run_state")


func _restore_dialogue(data: Dictionary) -> void:
	if data.is_empty() or Game.dialogue == null or not Game.dialogue.has_method("restore_run_state"):
		return
	Game.dialogue.call("restore_run_state", data)


func _capture_ui(member: String, method: String) -> Dictionary:
	var hud := _hud()
	if hud == null:
		return {}
	var target: Object = hud.get(member)
	if target == null or not target.has_method(method):
		return {}
	return target.call(method)


func _restore_ui(member: String, method: String, state: Dictionary) -> void:
	var hud := _hud()
	if hud == null or state.is_empty():
		return
	var target: Object = hud.get(member)
	if target and target.has_method(method):
		target.call(method, state)


func _hud() -> Object:
	for child in get_tree().current_scene.get_children():
		if child is Hud:
			return child
	return null


func _capture_checkpoint() -> Dictionary:
	if Game.checkpoint.is_empty():
		return {}
	var result := Game.checkpoint.duplicate(true)
	var titles: Array[String] = []
	for entry: NoteEntry in Game.checkpoint.get("journal", []):
		titles.append(entry.title)
	result["journal_titles"] = titles
	result.erase("journal")
	return result


func _find_note(title: String) -> FieldNote:
	if title.is_empty() or Game.trail == null:
		return null
	for note in Game.trail.find_children("*", "FieldNote", true, false):
		if note is FieldNote and note.entry and note.entry.title == title:
			return note
	return null


func _refresh_field_pages() -> void:
	if Game.trail == null:
		return
	for note in Game.trail.find_children("*", "FieldNote", true, false):
		if note is FieldNote and note.entry and Game.read_pages.has(note.entry.title):
			note.visible = false
			note.remove_from_group("field_notes")
	for supply in get_tree().get_nodes_in_group("arrow_supplies"):
		supply.call("refresh")
