class_name DreamStory
extends RefCounted

const PATH := "res://assets/dialogue/dream.json"
const BEAT_COUNT := 4
const SMALL_TALK_MAX_ROUNDS := 4
const ID_PATTERN := "^[a-z][a-z0-9_-]{0,31}$"
const MOTION_CUES := ["cut_tree", "delayed_steps", "lantern_witness", "tracks_stop", "tower_gaze", "window_gaze"]


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		push_error("Dream story file is missing: %s" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != 1:
		push_error("Dream story must be a version 1 object")
		return {}
	var beats: Variant = parsed.get("beats", [])
	var branches: Variant = parsed.get("branches", [])
	var small_talk: Variant = parsed.get("small_talk", [])
	var events: Variant = parsed.get("events", [])
	var repair: Variant = parsed.get("repair", {})
	var ruptured: Variant = parsed.get("ruptured", {})
	if typeof(beats) != TYPE_ARRAY or beats.size() != BEAT_COUNT or typeof(branches) != TYPE_ARRAY or not (2 <= branches.size() and branches.size() <= 8):
		push_error("Dream story needs four approach beats and at least two branches")
		return {}
	var unresolved: Variant = parsed.get("unresolved", {})
	if not _valid_journal_entry(parsed.get("journal_cue", {})) or str(parsed.get("question_guidance", "")).strip_edges().is_empty() or typeof(events) != TYPE_ARRAY or events.size() != 3:
		push_error("Dream story needs an opening journal cue and three trail events")
		return {}
	if typeof(unresolved) != TYPE_DICTIONARY or str(unresolved.get("response", "")).strip_edges().is_empty() or str(unresolved.get("ophelia", "")).strip_edges().is_empty() or str(unresolved.get("mathilda", "")).strip_edges().is_empty() or not _valid_journal_entry(unresolved.get("journal", {})):
		push_error("Dream story needs an unresolved wakeup and reflection for each character")
		return {}
	if typeof(ruptured) != TYPE_DICTIONARY or str(ruptured.get("response", "")).strip_edges().is_empty() or str(ruptured.get("ophelia", "")).strip_edges().is_empty() or str(ruptured.get("mathilda", "")).strip_edges().is_empty() or not _valid_journal_entry(ruptured.get("journal", {})):
		push_error("Dream story needs a closed-conversation outcome for each character")
		return {}
	if typeof(repair) != TYPE_DICTIONARY or str(repair.get("prompt", "")).strip_edges().is_empty() or str(repair.get("guidance", "")).strip_edges().is_empty():
		push_error("Dream story needs a repair conversation")
		return {}
	var repair_options: Variant = repair.get("choices", [])
	if typeof(repair_options) != TYPE_ARRAY or repair_options.size() < 2:
		push_error("Dream story repair conversation needs at least two choices")
		return {}
	for option in repair_options:
		if typeof(option) != TYPE_DICTIONARY or str(option.get("label", "")).strip_edges().is_empty() or str(option.get("response", "")).strip_edges().is_empty() or not ["repair", "escalate"].has(str(option.get("effect", ""))) or not _valid_journal_entry(option.get("journal", {})):
			push_error("Dream story contains an invalid repair choice")
			return {}
	if typeof(small_talk) != TYPE_ARRAY or small_talk.size() > SMALL_TALK_MAX_ROUNDS:
		push_error("Dream story small talk has too many rounds")
		return {}
	var id_regex := RegEx.new()
	id_regex.compile(ID_PATTERN)
	var ids: Dictionary = {}
	for beat in beats:
		if typeof(beat) != TYPE_DICTIONARY or id_regex.search(str(beat.get("id", ""))) == null or ids.has(beat["id"]) or str(beat.get("text", "")).strip_edges().is_empty():
			push_error("Dream story has an invalid or duplicate beat id")
			return {}
		if not MOTION_CUES.has(str(beat.get("motion", ""))):
			push_error("Dream beat %s has no recognized movement cue" % beat["id"])
			return {}
		if not _valid_journal_entry(beat.get("journal", {})):
			push_error("Dream beat %s needs its own journal cue" % beat["id"])
			return {}
		ids[beat["id"]] = true
	ids.clear()
	var previous_event_offset := -1.0
	for event in events:
		if typeof(event) != TYPE_DICTIONARY or id_regex.search(str(event.get("id", ""))) == null or ids.has(event["id"]) or str(event.get("line", "")).strip_edges().is_empty() or not _valid_journal_entry(event.get("journal", {})):
			push_error("Dream story has an invalid or duplicate trail event cue")
			return {}
		var offset := float(event.get("offset", -1.0))
		if offset < 0.0 or offset < previous_event_offset or offset > 1000.0:
			push_error("Dream event %s has an invalid or unordered route offset" % event["id"])
			return {}
		previous_event_offset = offset
		if event.has("motion") and not MOTION_CUES.has(str(event.get("motion", ""))):
			push_error("Dream event %s has an unknown movement cue" % event["id"])
			return {}
		ids[event["id"]] = true
	var event_talk: Variant = parsed.get("event_talk", {})
	if typeof(event_talk) != TYPE_DICTIONARY:
		push_error("Dream event talk must map trail events to small-talk rounds")
		return {}
	for event_id in event_talk:
		var round_number := float(event_talk[event_id])
		if not ids.has(str(event_id)) or not is_equal_approx(round_number, round(round_number)) or round_number < 0.0 or round_number >= small_talk.size():
			push_error("Dream event talk references an unknown event or round")
			return {}
	ids.clear()
	for branch in branches:
		if typeof(branch) != TYPE_DICTIONARY or id_regex.search(str(branch.get("id", ""))) == null or ids.has(branch["id"]):
			push_error("Dream story has an invalid or duplicate branch id")
			return {}
		for field in ["label", "response", "ophelia", "mathilda"]:
			if str(branch.get(field, "")).strip_edges().is_empty():
				push_error("Dream story branch %s is missing %s" % [branch["id"], field])
				return {}
		if not branch.has("journal") or not _valid_journal_entry(branch["journal"]):
			push_error("Dream story branch %s has an invalid journal note" % branch["id"])
			return {}
		ids[branch["id"]] = true
	for round_data in small_talk:
		if typeof(round_data) != TYPE_DICTIONARY or str(round_data.get("prompt", "")).strip_edges().is_empty() or str(round_data.get("guidance", "")).strip_edges().is_empty():
			push_error("Dream story contains an invalid small-talk round")
			return {}
		var options: Variant = round_data.get("choices", [])
		if typeof(options) != TYPE_ARRAY or not (2 <= options.size() and options.size() <= 4):
			push_error("Dream story small talk needs between two and four choices per round")
			return {}
		for option in options:
			if typeof(option) != TYPE_DICTIONARY or str(option.get("label", "")).strip_edges().is_empty() or str(option.get("response", "")).strip_edges().is_empty():
				push_error("Dream story contains an incomplete small-talk choice")
				return {}
			if not str(option.get("effect", "")).is_empty() and not ["push"].has(str(option.get("effect", ""))):
				push_error("Dream story contains an unknown small-talk effect")
				return {}
			if not option.has("journal") or not _valid_journal_entry(option["journal"]):
				push_error("Dream story small-talk choice has an invalid journal note")
				return {}
	return parsed


static func branch_for(story: Dictionary, branch_id: String) -> Dictionary:
	for branch in story.get("branches", []):
		if branch is Dictionary and str(branch.get("id", "")) == branch_id:
			return branch
	return {}


static func event_for(story: Dictionary, event_id: String) -> Dictionary:
	for event in story.get("events", []):
		if event is Dictionary and str(event.get("id", "")) == event_id:
			return event
	return {}


static func _valid_journal_entry(entry: Variant) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var identifier := str(entry.get("id", ""))
	var id_regex := RegEx.new()
	id_regex.compile(ID_PATTERN)
	if id_regex.search(identifier) == null or str(entry.get("title", "")).strip_edges().is_empty() or str(entry.get("text", "")).strip_edges().is_empty():
		return false
	return str(entry.get("approach", "")).strip_edges() != ""


static func has_branch(branch_id: String) -> bool:
	return not branch_for(load_data(), branch_id).is_empty()
