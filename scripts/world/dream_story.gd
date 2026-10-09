class_name DreamStory
extends RefCounted

const PATH := "res://assets/dialogue/dream.json"
const BEAT_COUNT := 4
const ID_PATTERN := "^[a-z][a-z0-9_-]{0,31}$"
const MOTION_CUES := ["cut_tree", "delayed_steps", "lantern_witness", "tracks_stop"]


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
	if typeof(beats) != TYPE_ARRAY or beats.size() != BEAT_COUNT or typeof(branches) != TYPE_ARRAY or not (2 <= branches.size() and branches.size() <= 8):
		push_error("Dream story needs four approach beats and at least two branches")
		return {}
	if typeof(small_talk) != TYPE_ARRAY or small_talk.size() > 3:
		push_error("Dream story small talk must contain at most three rounds")
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
		ids[beat["id"]] = true
	ids.clear()
	for branch in branches:
		if typeof(branch) != TYPE_DICTIONARY or id_regex.search(str(branch.get("id", ""))) == null or ids.has(branch["id"]):
			push_error("Dream story has an invalid or duplicate branch id")
			return {}
		for field in ["label", "response", "ophelia", "mathilda"]:
			if str(branch.get(field, "")).strip_edges().is_empty():
				push_error("Dream story branch %s is missing %s" % [branch["id"], field])
				return {}
		ids[branch["id"]] = true
	for round_data in small_talk:
		if typeof(round_data) != TYPE_DICTIONARY or str(round_data.get("prompt", "")).strip_edges().is_empty():
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
	return parsed


static func branch_for(story: Dictionary, branch_id: String) -> Dictionary:
	for branch in story.get("branches", []):
		if branch is Dictionary and str(branch.get("id", "")) == branch_id:
			return branch
	return {}


static func has_branch(branch_id: String) -> bool:
	return not branch_for(load_data(), branch_id).is_empty()
