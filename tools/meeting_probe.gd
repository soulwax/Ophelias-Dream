extends Node

## The doorway meeting on the real chapter (docs/DIALOGUE.md). Runs the spine
## to "home" on its own Conversation, then the chapter's meeting with every
## side topic, a walk-away and a resume, to "step" and its end card. Prints
## both transcripts.

var transcript: PackedStringArray = []


func _ready() -> void:
	OS.set_environment("RUN_MEETING", "1")
	Game.mathilda_pov = true
	add_child(load("res://scenes/main.tscn").instantiate())
	for i in 12:
		await get_tree().process_frame
	var chapter: Node = Game.voice
	assert(chapter._returning and is_instance_valid(chapter._ophelia), "Ophelia waits at the door")
	assert(chapter._near_ophelia(), "she starts within reach")
	var meeting: Conversation = chapter._meeting
	var tree := meeting.tree
	assert(tree.problems().is_empty(), "tree: " + ", ".join(tree.problems()))
	var sources := {"final": 0, "draft": 0, "subtitle": 0}
	for id in tree.lines:
		var line: Dictionary = tree.lines[id]
		var key := Voice.clip_key(str(line.text), str(line.mood))
		if ResourceLoader.exists(tree.clips + key + ".wav"):
			sources.final += 1
		elif ResourceLoader.exists(tree.clips + "draft/" + key + ".wav"):
			sources.draft += 1
		else:
			assert(Conversation.spoken_for(str(line.text)) > 0.0)
			sources.subtitle += 1
	print("voices: %d final, %d draft, %d subtitle only" % [sources.final, sources.draft, sources.subtitle])
	Engine.time_scale = 4.0

	# 1. The spine alone, always the first topic, must play 01..24 in order.
	var spine := Conversation.make(chapter.MEETING, chapter._ophelia)
	add_child(spine)
	var heard: PackedStringArray = []
	spine.line_started.connect(func(line: Dictionary) -> void: heard.append(str(line.id)))
	var ending := [""]
	spine.ended.connect(func(id: String) -> void: ending[0] = id)
	assert(spine.begin())
	while ending[0] == "":
		await _offered(spine)
		if ending[0] == "":
			spine.choose(0)
	var expected: PackedStringArray = []
	for i in range(1, 25):
		expected.append("%02d" % i)
	assert(heard == expected, "spine order: " + ",".join(heard))
	assert(ending[0] == "home")
	_settle(spine)
	spine.queue_free()
	await get_tree().process_frame

	# 2. The chapter's meeting, opened as she would: every side topic, a walk-away, a resume.
	meeting.line_started.connect(func(line: Dictionary) -> void:
		transcript.append("  %4s %-8s %s" % [line.id, line.speaker, line.text]))
	_press(chapter, "interact")
	assert(meeting.active and Game.phase == Game.Phase.DIALOGUE and Game.locks_movement() and Game.locks_look())
	var left := false
	var sides := 0
	while meeting.finished == "":
		await _offered(meeting)
		if meeting.finished != "":
			break
		var topics := meeting._topics
		var pick := 0
		for i in topics.size():
			if topics[i].get("once", false):
				pick = i
		if meeting.node_id == "milk" and not left:
			pick = topics.size() - 1
			assert(topics[pick].get("leave", false), "leaving is always the last topic")
			left = true
			meeting.choose(pick)
			while meeting.active:
				meeting.skip()
				await get_tree().process_frame
			assert(Game.phase == Game.Phase.PLAYING, "walking away gives control back")
			var ambience := AudioServer.get_bus_index("Ambience")
			assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(ambience)), Game.settings.ambience_volume) \
				or Game.settings.ambience_volume <= 0.001, "the duck lifts")
			transcript.append("  ---- she walks away; then comes back")
			_press(chapter, "interact")
			assert(meeting.active and meeting.node_id == "milk", "it resumes where it stopped")
			continue
		if topics[pick].get("once", false):
			var key := str(topics[pick].key)
			sides += 1
			meeting.choose(pick)
			await _offered(meeting)
			for topic in meeting._topics:
				assert(str(topic.get("key", "")) != key, "a once topic is not offered again")
			continue
		if meeting.node_id == "take":
			for i in topics.size():
				if str(topics[i].get("end", "")) == "step":
					pick = i
		meeting.choose(pick)
	assert(left and sides == 5, "took %d side topics" % sides)
	assert(transcript[transcript.find("  ---- she walks away; then comes back") + 1].contains("a15"), "the greeting opens the resume")
	assert(meeting.finished == "step")
	var forward := -Game.player.camera.global_basis.z
	var toward: Vector3 = (chapter._ophelia.head() - Game.player.camera.global_position).normalized()
	assert(rad_to_deg(forward.angle_to(toward)) < 20.0, "the view turned to her")
	var waited := 0.0
	while Game.phase != Game.Phase.ESCAPED and waited < 20.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	assert(Game.phase == Game.Phase.ESCAPED and Game.ending_title == "On the step", "the end card: " + Game.ending_title)
	print("\n--- chapter meeting -> step\n" + "\n".join(transcript))
	print("\nMEETING PASS: spine in order to home; side topics once; leave and resume; camera, duck, end card")
	Engine.time_scale = 1.0
	get_tree().quit()


# Skips lines until the topics show (or the conversation ends).
func _offered(conversation: Conversation) -> void:
	while conversation.active and not conversation._menu.choices_shown:
		conversation.skip()
		await get_tree().process_frame


func _settle(conversation: Conversation) -> void:
	if Game.phase == Game.Phase.DIALOGUE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Game.set_phase(Game.Phase.PLAYING)
	conversation._restore_audio()


func _press(chapter: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	chapter._unhandled_input(event)
