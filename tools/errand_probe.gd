extends Node

# The errands core: learn, advance, finish and let go; requires; no digits in
# her prose; the journal's Undone list; nothing built in the dream or Mathilda's
# chapter; nothing added under House or Trail; the checkpoint and a capture
# keep every state, socket, loose item and what she carries.
#   godot --headless --path . tools/errand_probe.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	OS.set_environment("RUN_PLAY", "1")
	RunSave.set_process(false)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _build(errands_on := true) -> void:
	if errands_on:
		OS.unset_environment("RUN_ERRANDS")
	else:
		OS.set_environment("RUN_ERRANDS", "off")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	await _frames(8)


func _teardown() -> void:
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Game.reset()


# House and Trail as children and as whole subtrees.
func _counts() -> Array:
	var trail := Game.trail
	if trail == null or trail.house == null:
		return []
	return [trail.get_child_count(), _descendants(trail), trail.house.get_child_count(), _descendants(trail.house)]


func _descendants(node: Node) -> int:
	return node.find_children("*", "", true, false).size()


func _run() -> void:
	await _build()
	var errands := Game.errands
	_check(errands != null and errands.is_built, "Errands registers and builds in her chapter")
	if errands == null:
		_finish()
		return
	_check(errands.get_parent() == _main and errands.world_root().get_parent() == errands, "World is Errands' own child")
	var plain := _counts()
	_no_digits(errands)
	await _journal_lists_known_only(errands)
	_learn_advance_finish(errands)
	_requires(errands)
	_dev_hook(errands)
	await _save_round_trip(errands)
	_check(_counts() == plain, "Errands' pieces changed nothing under House or Trail")
	_let_go_when_day_runs_out(errands)
	await _checkpoint_keeps()
	await _let_go_on_turn()
	await _teardown()
	await _child_counts_unchanged(plain)
	await _dream_builds_nothing(plain)
	await _mathilda_builds_nothing()
	_finish()


func _finish() -> void:
	OS.unset_environment("RUN_ERRANDS")
	OS.unset_environment("RUN_ERRAND")
	print("ERRAND %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _no_digits(errands: Errands) -> void:
	var digit := RegEx.create_from_string("[0-9]")
	var catalog := Errands.load_catalog()
	_check(catalog.size() == 4, "four errands in the data")
	var ids := catalog.map(func(errand: Errand) -> String: return errand.id)
	_check(ids == ["warm_house", "two_cups", "red_thread", "light_for_dark"], "the four errands from the spec, in order")
	var clean := true
	for errand in catalog:
		for text in errand.prose():
			if text.strip_edges() == "" or digit.search(text):
				clean = false
				print("  bad prose in %s: '%s'" % [errand.id, text])
	_check(clean, "every prose string in the data is written and has no digits")
	# Every undone_text() a state can show.
	var probe := Errand.from_data({})
	clean = true
	for errand in catalog:
		probe = errand
		var seen: Array[String] = []
		probe.state = Errand.State.KNOWN
		for index in probe.steps.size():
			probe.step = index
			seen.append(probe.undone_text())
		probe.state = Errand.State.DONE
		seen.append(probe.undone_text())
		probe.state = Errand.State.LET_GO
		seen.append(probe.undone_text())
		probe.state = Errand.State.UNKNOWN
		_check(probe.undone_text() == "", "%s says nothing while unknown" % errand.id)
		for text in seen:
			if text == "" or digit.search(text):
				clean = false
	_check(clean, "every undone_text() has words and no digits")
	_check(errands.get_errand("two_cups").requires == PackedStringArray(["warm_house"]), "two_cups requires warm_house")


func _journal() -> Journal:
	var found := _main.find_children("*", "Journal", true, false)
	return found[0] as Journal if not found.is_empty() else null


func _journal_lists_known_only(errands: Errands) -> void:
	var journal := _journal()
	_check(journal != null, "the HUD has a journal")
	if journal == null:
		return
	Game.add_to_journal(NoteCatalog.all()[0])
	Game.open_journal()
	await _frames(2)
	_check(Game.phase == Game.Phase.JOURNAL and journal.visible, "the journal opens")
	_check(not journal._undone_head.visible and journal._undone.get_child_count() == 0, "nothing known: no Undone section")
	errands.learn("red_thread")
	await _frames(1)
	var lines := journal._undone.get_children()
	_check(journal._undone_head.visible and lines.size() == 1, "one known errand: one line under Undone")
	if lines.size() == 1:
		var line := lines[0] as RichTextLabel
		_check(line.text == errands.get_errand("red_thread").undone_text() and not line.text.contains("[s]"), "the line is its undone prose, not struck")
		_check(line.focus_mode == Control.FOCUS_NONE, "Undone lines never take focus (pad navigation unchanged)")
	errands.advance("red_thread", "follow")
	await _frames(1)
	lines = journal._undone.get_children()
	_check(lines.size() == 1 and (lines[0] as RichTextLabel).text == "Red wool, the birches, the stump. It goes on.", "advancing changes the prose")
	errands.finish("red_thread")
	await _frames(1)
	lines = journal._undone.get_children()
	_check(lines.size() == 1 and (lines[0] as RichTextLabel).text == "[s]%s[/s]" % errands.get_errand("red_thread").done, "done: struck, with its done prose")
	var page_button := journal._buttons.get(NoteCatalog.all()[0].title) as Button
	_check(page_button != null and page_button.focus_mode == Control.FOCUS_ALL, "the page list still takes focus")
	Game.close_journal()
	await _frames(1)


func _learn_advance_finish(errands: Errands) -> void:
	var id := "light_for_dark"
	_check(errands.state_of(id) == Errand.State.UNKNOWN, "unknown at the start")
	var heard: Array[String] = []
	var listen := func(changed: String) -> void: heard.append(changed)
	Game.errand_changed.connect(listen)
	_check(errands.learn(id) and errands.state_of(id) == Errand.State.KNOWN and errands.get_errand(id).step == 0, "learn makes it known at the first step")
	_check(not errands.learn(id), "learning twice does nothing")
	_check(errands.advance(id, "carry") and errands.get_errand(id).step == 2, "advance moves on by step id")
	_check(not errands.advance(id, "oil") and errands.get_errand(id).step == 2, "advance never goes back")
	_check(not errands.advance(id, "nowhere"), "an unknown step is refused")
	errands.set_flag(id, "lit", true)
	_check(errands.flag(id, "lit", false) == true, "flags keep per-errand notes")
	_check(errands.finish(id) and errands.is_done(id), "finish marks it done")
	_check(not errands.let_go(id) and errands.is_done(id), "a done errand is never let go")
	Game.errand_changed.disconnect(listen)
	_check(heard.size() == 4 and heard.all(func(changed: String) -> bool: return changed == id), "every change emits Game.errand_changed(id)")
	# Advancing an unknown errand learns it on the way.
	_check(errands.advance("warm_house", "carry") and errands.state_of("warm_house") == Errand.State.KNOWN, "advancing an unknown errand learns it")


func _requires(errands: Errands) -> void:
	errands.learn("two_cups")
	_check(not errands.is_done("warm_house"), "warm_house not done yet")
	_check(not errands.finish("two_cups") and errands.state_of("two_cups") == Errand.State.KNOWN, "two_cups cannot finish before warm_house")
	_check(errands.finish("warm_house"), "warm_house finishes")
	_check(errands.finish("two_cups") and errands.is_done("two_cups"), "then two_cups can")


func _dev_hook(errands: Errands) -> void:
	# Fresh errands to exercise RUN_ERRAND's parsing without touching the others.
	var spare := Errand.from_data({"id": "probe_spare", "steps": [{"id": "a", "undone": "A."}, {"id": "b", "undone": "B."}], "done": "Done.", "let_go": "Gone."})
	errands.errands["probe_spare"] = spare
	OS.set_environment("RUN_ERRAND", "probe_spare:b")
	errands._dev_hook()
	OS.unset_environment("RUN_ERRAND")
	_check(spare.state == Errand.State.KNOWN and spare.step == 1, "RUN_ERRAND=<id>:<step> learns and advances")
	errands.errands.erase("probe_spare")


func _save_round_trip(errands: Errands) -> void:
	var root := errands.world_root()
	var player := Game.player
	var box := CarrySocket.new()
	box.socket_id = "probe_box"
	box.accepts = PackedStringArray(["log"])
	box.capacity = 3
	root.add_child(box)
	box.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
	errands.register_socket(box)
	var logs: Array[Carryable] = []
	for index in 3:
		var piece := Carryable.new()
		piece.kind = "log"
		piece.heavy = true
		piece.item_id = "probe_log_%d" % index
		root.add_child(piece)
		piece.global_position = player.global_position + Vector3(-2.0, 0.0, index * 0.6)
		errands.register_item(piece)
		logs.append(piece)
	var made: Array[String] = []
	errands.register_maker("probe_fresh_", func(item_id: String) -> void:
		var fresh := Carryable.new()
		fresh.kind = "log"
		fresh.item_id = item_id
		root.add_child(fresh)
		errands.register_item(fresh)
		made.append(item_id))
	var fresh_one := Carryable.new()
	fresh_one.kind = "log"
	fresh_one.item_id = "probe_fresh_0"
	root.add_child(fresh_one)
	errands.register_item(fresh_one)
	var tin := Carryable.new()
	tin.item_id = "probe_tin"
	root.add_child(tin)
	errands.register_item(tin)
	var brushed := {"value": true}
	errands.register_state("probe_sign", func() -> Variant: return brushed.value, func(value: Variant) -> void: brushed.value = value)
	box.add_item(logs[0])
	box.add_item(fresh_one)
	var loose_at := logs[1].global_transform.translated(Vector3(0.0, 0.0, 0.3))
	logs[1].global_transform = loose_at
	player.restore_carried(logs[2])
	await _frames(1)
	errands.consume(tin)
	await _frames(1)
	_check(player.carrying == logs[2], "she carries the third log")
	var saved := errands.capture()
	_check(saved.get("carrying") == "probe_log_2", "capture records what she carries")
	_check(saved.sockets.get("probe_box") == ["probe_log_0", "probe_fresh_0"], "capture records socket contents in order")
	_check((saved.loose as Dictionary).has("probe_log_1"), "capture records loose items")
	_check((saved.gone as Array).has("probe_tin"), "capture records used-up items")
	_check(saved.pieces.get("probe_sign") == true, "capture records registered piece state")
	_check(var_to_str(saved).length() > 0 and str_to_var(var_to_str(saved)) is Dictionary, "the capture serializes")
	var states_before := {}
	for errand in errands.ordered():
		states_before[errand.id] = [errand.state, errand.step, errand.flags.duplicate(true)]

	# A new Errands restores the same states and steps.
	var copy := Errands.new()
	_main.add_child(copy)
	await _frames(1)
	copy.restore(saved)
	var same := true
	for errand in copy.ordered():
		var before: Array = states_before[errand.id]
		if errand.state != before[0] or errand.step != before[1] or errand.flags != before[2]:
			same = false
	_check(same, "a new Errands restores the same states, steps and flags")
	copy.queue_free()
	await get_tree().process_frame
	Game.errands = errands
	# The same pieces, scattered, come back where they were.
	player.call("_clear_carried")
	logs[2].return_visual()
	box.remove_item(logs[0])
	box.remove_item(fresh_one)
	fresh_one.queue_free()
	logs[1].global_position += Vector3(5.0, 0.0, 0.0)
	brushed.value = false
	await _frames(1)
	player.carrying_item_id = ""
	errands.restore(saved)
	await _frames(1)
	_check(made == ["probe_fresh_0"], "a maker remakes an item that appeared in play")
	var remade := errands.item("probe_fresh_0")
	_check(box.held.size() == 2 and box.held[0] == logs[0] and box.held[1] == remade, "socket contents come back in order")
	_check(logs[1].global_transform.origin.distance_to(loose_at.origin) < 0.001 and logs[1].socket == null, "a loose item comes back where it lay")
	_check(player.carrying == logs[2], "what she carried is back in her arms")
	_check(brushed.value == true, "a registered piece state comes back")
	_check(errands.item("probe_tin") == null, "a used-up item stays gone")
	# Leave her hands empty for the rest of the probe.
	player.call("_clear_carried")
	logs[2].return_visual()


func _let_go_when_day_runs_out(errands: Errands) -> void:
	# Everything is done by now; open one again to have something to let go.
	errands.get_errand("red_thread").state = Errand.State.KNOWN
	var known := errands.ordered().filter(func(errand: Errand) -> bool: return errand.state == Errand.State.KNOWN)
	var done := errands.ordered().filter(func(errand: Errand) -> bool: return errand.state == Errand.State.DONE)
	_check(known.size() == 1, "one errand is open as the day ends")
	Game.mathilda_gone()
	_check(Game.phase == Game.Phase.ESCAPED and Game.ending_kind == "gone", "the day runs out")
	_check(known.all(func(errand: Errand) -> bool: return errand.state == Errand.State.LET_GO), "the day running out lets go every known errand")
	_check(done.all(func(errand: Errand) -> bool: return errand.state == Errand.State.DONE), "done errands stay done")


func _checkpoint_keeps() -> void:
	# A fresh run: one errand mid-way, one done, at the lookout.
	await _teardown()
	await _build()
	var errands := Game.errands
	errands.advance("warm_house", "light")
	errands.learn("red_thread")
	errands.finish("red_thread")
	errands.set_flag("red_thread", "snags", ["a", "b"])
	Game.add_to_journal(NoteCatalog.all()[0])
	Game.reach_checkpoint()
	_check(Game.checkpoint.get("errands", {}).has("errands"), "the checkpoint keeps the errands")
	await _teardown()
	Game._resume = true
	Game.reset()
	await _build()
	errands = Game.errands
	_check(errands != null and Game.at_checkpoint, "the run resumes at the lookout with errands")
	if errands == null:
		return
	_check(errands.state_of("warm_house") == Errand.State.KNOWN and errands.get_errand("warm_house").step_id() == "light", "a known errand keeps its step")
	_check(errands.is_done("red_thread") and errands.flag("red_thread", "snags") == ["a", "b"], "a done errand stays done, with its flags")
	_check(errands.state_of("two_cups") == Errand.State.UNKNOWN, "an unknown errand stays unknown")


func _let_go_on_turn() -> void:
	var errands := Game.errands
	if errands == null:
		return
	Game.read_last_page = true
	Game.player.global_position = Game.trail.on_ground(Game.trail.exit_point) + Vector3.UP * 0.3
	Game.player.reset_physics_interpolation()
	await _frames(2)
	Game.turn_around()
	_check(Game.turned_around, "she turned around")
	_check(errands.state_of("warm_house") == Errand.State.LET_GO, "turning around lets go a known errand")
	_check(errands.is_done("red_thread"), "but not a done one")
	_check(errands.state_of("two_cups") == Errand.State.UNKNOWN, "nor an unknown one")
	_check(errands.get_errand("warm_house").undone_text() == errands.get_errand("warm_house").let_go, "let go shows its let-go prose")
	_check(not errands.learn("two_cups"), "nothing new is learned once she has turned around")
	Game.checkpoint.clear()
	Game._resume = false


func _child_counts_unchanged(plain: Array) -> void:
	await _build(false)
	_check(Game.errands == null and _main.get_node_or_null("Errands") == null, "RUN_ERRANDS=off leaves Errands out")
	_check(not plain.is_empty() and _counts() == plain, "House and Trail child counts equal a run without Errands %s" % [plain])
	await _teardown()


func _dream_builds_nothing(plain: Array) -> void:
	Game.dream_mode = true
	await _build()
	_check(Game.errands == null and _main.get_node_or_null("Errands") == null, "the dream builds no Errands")
	var dream := _counts()
	await _teardown()
	await _build(false)
	_check(_counts() == dream, "House and Trail counts in the dream equal a dream without Errands %s" % [dream])
	print("  dream counts %s, plain %s" % [dream, plain])
	await _teardown()
	Game.dream_mode = false


func _mathilda_builds_nothing() -> void:
	Game.mathilda_pov = true
	await _build()
	_check(Game.errands == null and _main.get_node_or_null("Errands") == null, "Mathilda's chapter builds no Errands")
	await _teardown()
	Game.mathilda_pov = false
