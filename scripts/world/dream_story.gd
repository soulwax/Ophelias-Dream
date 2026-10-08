class_name DreamStory
extends RefCounted

const PATH := "res://assets/dialogue/dream.json"
const BEAT_COUNT := 4
const ID_PATTERN := "^[a-z][a-z0-9_-]{0,31}$"


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
	if typeof(beats) != TYPE_ARRAY or beats.size() != BEAT_COUNT or typeof(branches) != TYPE_ARRAY or not (2 <= branches.size() and branches.size() <= 8):
		push_error("Dream story needs four approach beats and at least two branches")
		return {}
	var id_regex := RegEx.new()
	id_regex.compile(ID_PATTERN)
	var ids: Dictionary = {}
	for beat in beats:
		if typeof(beat) != TYPE_DICTIONARY or id_regex.search(str(beat.get("id", ""))) == null or ids.has(beat["id"]) or str(beat.get("text", "")).strip_edges().is_empty():
			push_error("Dream story has an invalid or duplicate beat id")
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
	return parsed


static func branch_for(story: Dictionary, branch_id: String) -> Dictionary:
	for branch in story.get("branches", []):
		if branch is Dictionary and str(branch.get("id", "")) == branch_id:
			return branch
	return {}


static func has_branch(branch_id: String) -> bool:
	return not branch_for(load_data(), branch_id).is_empty()
