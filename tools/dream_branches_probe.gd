extends Node

## MASTERPLAN W05: every authored memory answer is reachable and saved (including
## the private "I can't say it yet."), and a repair reply eases the strain while
## an escalation ruptures the talk. Isolate user data as for dream_flow_probe
## (docs/mvp/BASELINE.md). Quits 1 on any failure.
const MAIN := preload("res://scenes/main.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if detail.is_empty() else "  (" + detail + ")"))
	if not ok:
		_failures += 1


func _saved_memory() -> String:
	var file := ConfigFile.new()
	if file.load("user://dream.cfg") != OK:
		return ""
	return str(file.get_value("dream", "memory", ""))


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ProjectSettings.globalize_path("user://").contains("DreamFlowPlayabilityAudit"):
		_check(false, "user data is isolated", "see docs/mvp/BASELINE.md")
		get_tree().quit(1)
		return
	Game.dream_mode = true
	Game.character_selected = true
	var main := MAIN.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for _frame in 2400:
		if Game.trail and Game.player and Game.phase == Game.Phase.DREAM:
			break
		await get_tree().process_frame
	var route := main.find_child("DreamRoute", true, false)
	var experience: Node = route.get_parent() if route else null
	if experience == null:
		_check(false, "the dream reaches its playable phase")
		get_tree().quit(1)
		return
	var story: Dictionary = experience.get("_story")

	# Each answer to the final question, as the open question offers it.
	for branch: Dictionary in story.get("branches", []):
		var id := str(branch.get("id", ""))
		Game.dream_memory = ""
		Game.dream_completed = false
		experience.set("_answer_open", true)
		experience.call("_choose_memory", id)
		await get_tree().process_frame
		_check(Game.dream_memory == id and _saved_memory() == id, "the answer '%s' is kept" % branch.get("label", id))
		_check(not Game.dream_completed, "choosing '%s' does not complete the dream before waking" % id)
		_check(not bool(experience.get("_answer_open")), "the question closes after '%s'" % id)
	# A closed question takes no second answer.
	experience.call("_choose_memory", "name")
	_check(_saved_memory() == str((story.get("branches", []) as Array).back().get("id", "")), "a closed question ignores a late answer")

	# Repair: a strained talk eases with a repair reply and ruptures with an escalation.
	var repair: Dictionary = story.get("repair", {})
	var choices: Array = repair.get("choices", [])
	var repair_index := -1
	var escalate_index := -1
	for index in choices.size():
		match str((choices[index] as Dictionary).get("effect", "")):
			"repair":
				if repair_index < 0:
					repair_index = index
			"escalate", "push":
				if escalate_index < 0:
					escalate_index = index
	_check(repair_index >= 0 and escalate_index >= 0, "the repair round offers both a repair and an escalation")
	experience.set("_repair_menu_active", true)
	experience.set("_conversation_strain", 3)
	experience.call("_choose_small_talk", repair_index)
	await get_tree().process_frame
	_check(int(experience.get("_conversation_strain")) == 2, "a repair reply reduces but does not erase strain", str(experience.get("_conversation_strain")))
	experience.set("_repair_menu_active", true)
	experience.set("_conversation_strain", 3)
	experience.call("_choose_small_talk", escalate_index)
	await get_tree().process_frame
	_check(int(experience.get("_conversation_strain")) >= 4, "an escalation past the strain limit ruptures", str(experience.get("_conversation_strain")))
	experience.call("_ending_text")
	_check(str(experience.get("_dream_outcome")) == "ruptured", "and the dream wakes ruptured")

	print("Dream branches probe: %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
