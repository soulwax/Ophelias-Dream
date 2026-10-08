extends Node

# The new ends of Ophelia's chapter (docs/LAKE_MEETING.md):
# - the lake needs three journal pages; with fewer she will not go out,
# - a whole day without an attempt ends on "Mathilda is gone",
# - with every trail page read, the last deciphered and no turning around,
#   Mathilda waits on the ice; walking up opens the meeting, and its spine
#   ends "Together"; turning around before it makes her go,
# - the meeting's tree is sound, and her lines have clips.
#   godot --headless --path . tools/ending_probe.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _fresh() -> void:
	if _main:
		_main.queue_free()
		await get_tree().process_frame
	Game.checkpoint.clear()
	Game.reset()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	await _frames(6)
	Game.set_phase(Game.Phase.PLAYING)


func _stand(at: Vector3) -> void:
	Game.player.global_position = Game.trail.on_ground(at) + Vector3.UP * 0.3
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()


func _run() -> void:
	var tree := DialogueTree.load_from("res://assets/dialogue/lake.json")
	_check(tree.problems().is_empty(), "the meeting's tree is sound %s" % [tree.problems()])
	_check(tree.endings().has("together") and tree.endings().has("shore"), "it can end together or on the shore")
	var voiced := true
	for id in tree.lines:
		var line: Dictionary = tree.lines[id]
		if str(line.speaker) == "mathilda":
			voiced = voiced and ResourceLoader.exists(tree.clips + Voice.clip_key(str(line.text), str(line.mood)) + ".wav")
	_check(voiced, "every line of Mathilda's has a clip")

	# The lake with too few pages.
	await _fresh()
	_check(Game.day_running, "her day starts when she is in the world")
	for entry in NoteCatalog.all().slice(0, 2):
		Game.add_to_journal(entry)
	_stand(Game.trail.lake_hole)
	await _frames(4)
	_check(Game.phase == Game.Phase.PLAYING and Game._unready_said, "two pages: at the hole, not yet")
	Game.add_to_journal(NoteCatalog.all()[2])
	for i in 4:
		await get_tree().process_frame
		print("  frame %d: phase %d, at lake %s, pages %d, kind '%s'" % [i, Game.phase, Game._at_lake(), Game.journal.size(), Game.ending_kind])
	var hole := Game.trail.lake_hole
	var at := Game.player.global_position
	_check(Game.phase == Game.Phase.ESCAPED and Game.ending_kind == "road", "three pages: the lake ends the run (phase %d, %d pages, %.1f m from the hole, waiting %s)" % [
		Game.phase, Game.journal.size(), Vector2(at.x - hole.x, at.z - hole.z).length(), Game.meeting_waiting])

	# The day runs out.
	await _fresh()
	Game.day_seconds = Tune.DAY_MINUTES * 60.0 - 0.5
	await _frames(60)
	_check(Game.phase == Game.Phase.ESCAPED and Game.ending_title == "Mathilda is gone", "a whole day: Mathilda is gone")
	_check(Game._moments_said.has("dusk") and Game._moments_said.has("late"), "she noticed the hours on the way")

	# The meeting.
	await _fresh()
	for entry in NoteCatalog.all():
		Game.add_to_journal(entry)
	var last: NoteEntry = null
	for entry in NoteCatalog.all():
		if entry.title == NoteCatalog.LAST_TITLE:
			last = entry
	Game.deciphered[last.title] = {}
	for index in last.smudges.size():
		(Game.deciphered[last.title] as Dictionary)[index] = true
	_check(Game.meeting_ready(), "every trail page, the last deciphered, never turned: ready")
	var lake := get_tree().get_first_node_in_group("lake") as Lake
	var shore := Game.trail.position_at(Game.trail.lake_offset - Tune.LAKE_RADIUS - 10.0)
	_stand(shore)
	await _frames(4)
	_check(lake.mathilda != null and lake.mathilda.visible and Game.meeting_waiting, "Mathilda waits on the ice")
	_stand(Game.trail.lake_hole)
	await _frames(3)
	_check(Game.phase != Game.Phase.ESCAPED, "the hole is a meeting now, not an ending")
	_stand(lake.mathilda.global_position + (shore - lake.mathilda.global_position).normalized() * 2.0)
	await _frames(3)
	_check(Game.phase == Game.Phase.DIALOGUE and lake.meeting.active, "walking up to her opens the meeting")
	# Walk the spine: the onward topic each time, the last one 'together'.
	var spoken: Array[String] = []
	var steps := 0
	while lake.meeting.active and steps < 4000:
		steps += 1
		lake.meeting.skip()
		await get_tree().process_frame
		if lake.meeting._menu.choices_shown:
			var pick := 0
			for index in lake.meeting._topics.size():
				var topic: Dictionary = lake.meeting._topics[index]
				if topic.get("end", "") == "together" or (topic.has("goto") and not topic.has("end")):
					pick = index
					break
			spoken.append(str(lake.meeting._topics[pick].get("say", "")))
			lake.meeting.choose(pick)
	await _frames(3)
	print("  spine: ", ", ".join(spoken))
	_check(Game.phase == Game.Phase.ESCAPED and Game.ending_title == "Together", "asking properly ends together")

	# Turning around before the meeting makes her go.
	await _fresh()
	for entry in NoteCatalog.all():
		Game.add_to_journal(entry)
	Game.deciphered[last.title] = {}
	for index in last.smudges.size():
		(Game.deciphered[last.title] as Dictionary)[index] = true
	lake = get_tree().get_first_node_in_group("lake") as Lake
	_stand(shore)
	await _frames(4)
	Game.turned_around = true
	await _frames(3)
	_check(lake.mathilda != null and not lake.mathilda.visible and not Game.meeting_waiting, "turning around: she is not there any more")

	print("ENDINGS %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
