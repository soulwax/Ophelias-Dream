class_name DialogueTree
extends RefCounted

## A branching conversation from JSON (docs/DIALOGUE.md). A node says its
## lines, then offers topics. A topic is one of her lines: it may get replies,
## and then goes to another node, ends the conversation, or comes back to the
## same topics. Lines live in a separate table so the voice bake reads one list.

var lines: Dictionary = {}
var nodes: Dictionary = {}
var names: Dictionary = {}
var start := ""
var npc := ""
var clips := ""
# Said when she comes back to a conversation she left.
var resume: Array = []
# The topic that is always last: say a line, hear the replies, walk away.
var leave: Dictionary = {}


static func load_from(path: String) -> DialogueTree:
	var tree := DialogueTree.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("DialogueTree: cannot read " + path)
		return tree
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(data.get("lines", ""))))
	if typeof(table) == TYPE_ARRAY:
		for line: Dictionary in table:
			tree.lines[str(line.id)] = line
	tree.nodes = data.get("nodes", {})
	tree.names = data.get("names", {})
	tree.start = str(data.get("start", ""))
	tree.npc = str(data.get("npc", ""))
	tree.clips = str(data.get("clips", ""))
	tree.resume = data.get("resume", [])
	tree.leave = data.get("leave", {})
	return tree


func line(id: String) -> Dictionary:
	return lines.get(id, {})


func node(id: String) -> Dictionary:
	return nodes.get(id, {})


func name_of(speaker: String) -> String:
	return str(names.get(speaker, speaker.capitalize()))


## The topics offered at a node: those whose flags are all set, less the
## once-only topics already taken. Each is a copy with its text, its key
## ("node/index") and whether it was taken before (shown dimmed).
func topics(node_id: String, flags: Dictionary, taken: Dictionary) -> Array[Dictionary]:
	var offered: Array[Dictionary] = []
	var choices: Array = node(node_id).get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var key := "%s/%d" % [node_id, i]
		if choice.get("once", false) and taken.has(key):
			continue
		var allowed := true
		for flag in choice.get("requires", []):
			allowed = allowed and flags.has(str(flag))
		if not allowed:
			continue
		var topic := choice.duplicate()
		topic["key"] = key
		topic["text"] = str(choice.get("prompt", line(str(choice.get("say", ""))).get("text", "")))
		topic["dim"] = taken.has(key)
		offered.append(topic)
	return offered


## Every ending a topic can reach.
func endings() -> Array[String]:
	var found: Array[String] = []
	for id in nodes:
		for choice: Dictionary in node(id).get("choices", []):
			if choice.has("end") and not found.has(str(choice.end)):
				found.append(str(choice.end))
	return found


## What is wrong with the tree: unknown lines or nodes, dead ends, nodes no
## topic reaches. Empty when it is sound.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if not nodes.has(start):
		found.append("start node '%s' is missing" % start)
	var ids: Array = resume.duplicate()
	if not leave.is_empty():
		ids.append(leave.get("say", ""))
		ids.append_array(leave.get("reply", []))
	var reached := {start: true}
	for id in nodes:
		var here := node(id)
		ids.append_array(here.get("say", []))
		var choices: Array = here.get("choices", [])
		if choices.is_empty():
			found.append("node '%s' offers nothing" % id)
		var onward := false
		for choice: Dictionary in choices:
			ids.append(choice.get("say", ""))
			ids.append_array(choice.get("reply", []))
			if choice.has("goto"):
				reached[str(choice.goto)] = true
				if not nodes.has(str(choice.goto)):
					found.append("node '%s' goes to missing '%s'" % [id, choice.goto])
			onward = onward or choice.has("goto") or choice.has("end")
		if not choices.is_empty() and not onward:
			found.append("node '%s' never leads on" % id)
	for id in nodes:
		if not reached.has(id):
			found.append("node '%s' is never reached" % id)
	for id in ids:
		if not lines.has(str(id)):
			found.append("line '%s' is missing" % id)
	return found
