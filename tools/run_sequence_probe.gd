extends Node

# Integration checks against the actual saved level, without regenerating it.
# godot --headless --path . tools/run_sequence_probe.tscn
var _failures := 0


func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		push_error("Sequence probe timed out")
		get_tree().quit(1)
	)
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ", message)
	if not condition:
		_failures += 1


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	Game.set_process(false)
	Game.set_phase(Game.Phase.PLAYING)
	var player: Player = Game.player
	var trail: Trail = Game.trail
	var hunter: Hunter = Game.hunter
	var listener := Game.director.anomalies[0] as Listener
	var route_metres := trail.exit_offset - trail.player_start_offset
	print("Saved route: %.1f m from start to exit; hunt at %.1f m" % [route_metres, Tune.HUNT_ROUTE_DISTANCE])
	_check(route_metres > Tune.HUNT_ROUTE_DISTANCE + Tune.EXIT_RADIUS, "saved route has a pursuit leg before the exit")
	var haunting: Haunting
	for child in trail.house.get_children():
		if child is Haunting:
			haunting = child
	_check(haunting != null, "saved house binds its haunting system")
	player.global_position = trail.on_ground(trail.position_at(trail.player_start_offset + 30.0))
	Game._process(1.0)
	_check(not Game.hunt_started, "early route leaves room for the Listener and a return")
	listener._wake_in = 0.0
	listener.place_near(player.global_position + Vector3.RIGHT * 5.0, player.global_position)
	player.breath.plume = 1.0
	listener._physics_process(0.1)
	_check(listener._mood == Listener.Mood.HUNT, "exertion wakes the early Listener")
	player.global_position = trail.on_ground(trail.position_at(trail.player_start_offset + Tune.HUNT_ROUTE_DISTANCE + 1.0))
	Game._process(1.0)
	_check(Game.hunt_started and Game.notes_found == 0, "route starts pursuit with no pages")
	listener._physics_process(0.1)
	_check(listener._mood == Listener.Mood.DRIFT, "Listener yields to the figure")
	player.global_position = trail.exit_point
	hunter._physics_process(0.01)
	_check(Game.phase == Game.Phase.ESCAPED and Game.notes_found == 0, "no-page route reaches the real exit trigger")
	Game.set_phase(Game.Phase.PLAYING)
	player.global_position = trail.on_ground(trail.position_at(trail.player_start_offset + 90.0))
	var elapsed: float = Game.seconds_hunting()
	Game.set_phase(Game.Phase.PAUSED)
	Game._process(90.0)
	_check(is_equal_approx(elapsed, Game.seconds_hunting()), "pause freezes escalation")
	Game.set_phase(Game.Phase.READING)
	Game._process(2.0)
	_check(is_equal_approx(elapsed + 2.0, Game.seconds_hunting()), "reading still advances pursuit")
	Game.set_phase(Game.Phase.PLAYING)
	var prints := player.footprints
	var old_trail_camera := player.camera.global_transform
	player.global_position = trail.on_ground(trail.position_at(trail.player_start_offset + Tune.WRONG_TRACK_ROUTE_DISTANCE))
	player.camera.global_position = player.global_position + Vector3.UP * 1.6
	player.camera.look_at(trail.position_at(trail.player_start_offset + Tune.WRONG_TRACK_ROUTE_DISTANCE + 5.0) + Vector3.UP, Vector3.UP)
	for i in 10:
		var along := trail.player_start_offset + Tune.RETURN_CLUE_ROUTE_DISTANCE * 0.5 + float(i)
		prints.stamp(trail.on_ground(trail.position_at(along)), 0.0, false, i % 2 == 0)
	prints._process(0.01)
	_check(prints._lied, "wrong track appears on the early path after it is left behind")
	player.camera.global_transform = old_trail_camera
	prints.stamp(player.global_position, 0.0, false, false, Footprints.Mark.SOLE, true)
	var evidence_slot := (prints._cursor + Footprints.POOL - 1) % Footprints.POOL
	var evidence_at := prints._quads[evidence_slot].position
	for i in Footprints.POOL * 2:
		prints.stamp(player.global_position + Vector3.RIGHT * float(i), 0.0, false, false)
	_check(prints._quads[evidence_slot].position == evidence_at, "ordinary tracks cannot overwrite evidence")
	prints._process(60.0)
	_check(prints._quads[evidence_slot].visible, "evidence survives an exploration return")
	var age := prints._ages[evidence_slot]
	Game.set_phase(Game.Phase.PAUSED)
	prints._process(60.0)
	_check(is_equal_approx(age, prints._ages[evidence_slot]), "pause freezes snow ageing")
	Game.set_phase(Game.Phase.PLAYING)
	if haunting:
		haunting._enter("", "bedroom")
		haunting._enter("bedroom", "")
		_check(not haunting._mat_turned, "stepping outside and back does not turn the mat")
		haunting._enter("", "bedroom")
		player.global_position = trail.on_ground(trail.position_at(trail.player_start_offset + Tune.RETURN_CLUE_ROUTE_DISTANCE + 1.0))
		haunting._notice_excursion()
		haunting._enter("bedroom", "")
		var camera := player.camera
		var old_camera := camera.global_transform
		_check(haunting._mat_pending and trail.house.lantern_light.visible, "early-trail return queues mat clue and relights lantern")
		var mat := trail.house.get_node("Authoring/Traces/Mat") as Node3D
		camera.look_at_from_position(mat.global_position + trail.house.global_basis.z.normalized() * 2.0 + Vector3.UP * 1.5, mat.global_position)
		haunting._maybe_turn_mat()
		_check(not haunting._mat_turned, "mat waits while the doorway is visible")
		camera.rotate_y(PI)
		haunting._maybe_turn_mat()
		_check(haunting._mat_turned, "mat turns after the player looks away")
		haunting._enter("corridor", "morgue")
		haunting.room = "corridor"
		var body_at := trail.house.morgue.body.global_position + Vector3.UP * 1.1
		camera.look_at_from_position(body_at + Vector3(0.0, 0.8, 2.0), body_at)
		haunting._lay_body()
		_check(not trail.house.morgue.body.visible, "mortuary body waits while the table is visible")
		camera.rotate_y(PI)
		haunting._lay_body()
		haunting._enter("morgue", "corridor")
		_check(trail.house.morgue.body.visible, "second mortuary visit finds body placed while unseen")
		camera.look_at_from_position(trail.house.doorstep() + Vector3(0.0, 2.0, 3.0), trail.house.doorstep())
		haunting._lay_door_mark()
		_check(haunting._door_mark_pending, "door mark waits while its ground is visible")
		camera.rotate_y(PI)
		haunting._lay_door_mark()
		_check(not haunting._door_mark_pending, "door mark appears after looking away")
		camera.global_transform = old_camera
	Game.escape()
	var card := _find_card(main)
	_check(card != null and card._body.text == "Headlights. You do not look back.", "unread last page leaves the road ending plain")
	Game.set_phase(Game.Phase.PLAYING)
	var last := FieldNote.new()
	last.entry = NoteCatalog.all().back()
	main.add_child(last)
	Game.active_note = last
	Game.begin_reading()
	_check(Game.read_last_page and Game.reading_last_page(), "last-page collection records the open page")
	Game.close_reading()
	Game.escape()
	_check(card._body.text.ends_with("The line was not finished."), "last page changes the escape text")
	Game.set_phase(Game.Phase.READING)
	player.global_position = trail.on_ground(trail.position_at(trail.player_start_offset + 130.0))
	hunter.global_position = player.global_position + Vector3.RIGHT
	hunter._hunting = true
	Game._hunt_seconds = 75.0
	hunter._physics_process(0.01)
	_check(Game.phase == Game.Phase.CAUGHT and Game.ending_body.ends_with("The count closed."), "catch on the last page belongs to the snow")
	Game.set_phase(Game.Phase.PLAYING)
	Game.hunt_started = false
	listener.global_position = player.global_position
	player.breath.plume = 1.0
	listener._physics_process(0.01)
	_check(Game.phase == Game.Phase.CAUGHT and Game.ending_title == "It heard you breathe", "Listener retains its breath ending")
	Game.set_phase(Game.Phase.PLAYING)
	Game.hunt_started = true
	Game.active_note = null
	hunter.global_position = player.global_position + Vector3.RIGHT
	hunter._physics_process(0.01)
	_check(Game.phase == Game.Phase.CAUGHT and not Game.ending_body.contains("count closed"), "ordinary catch keeps its original ending")
	Game.set_phase(Game.Phase.PLAYING)
	Game.dread = 1.0
	Game.closeness = 0.0
	player.holding_breath = true
	hunter.global_position = player.global_position + Vector3.RIGHT
	hunter._physics_process(0.01)
	_check(Game.phase == Game.Phase.CAUGHT, "hunter can catch after Listener handoff while breath is held")
	player.holding_breath = false
	Game.dread = 0.0
	Game.hunt_started = false
	Game._hunt_seconds = 0.0
	Game.notes_found = 0
	Game.set_phase(Game.Phase.PLAYING)
	for index in Tune.HUNT_NOTES:
		var note := FieldNote.new()
		note.entry = NoteCatalog.all()[index]
		main.add_child(note)
		Game.active_note = note
		Game.begin_reading()
		Game.close_reading()
	_check(Game.hunt_started and Game.notes_found == Tune.HUNT_NOTES, "three optional pages can start pursuit early")
	Game.reset()
	_check(not Game.hunt_started and Game.seconds_hunting() == 0.0 and not Game.read_last_page, "restart clears sequence and ending history")
	main.queue_free()
	await get_tree().process_frame
	print("Sequence probe: ", _failures, " failures")
	get_tree().quit(0 if _failures == 0 else 1)


func _find_card(node: Node) -> EndCard:
	if node is EndCard:
		return node as EndCard
	for child in node.get_children():
		var found := _find_card(child)
		if found:
			return found
	return null
