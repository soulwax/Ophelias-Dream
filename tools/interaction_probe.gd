extends Node

# MASTERPLAN W03: the cases hold_probe and carry_probe leave out, driven by the
# real input actions. A press picks up and the drop key sets down; a hold
# stands still while paused and lets go cleanly when its thing is freed; the
# lantern and a carried thing never share her right hand; a drop on an outdoor
# slope rests on the snow, not under it. Quits 1 on any failure.
#   godot --headless --path . tools/interaction_probe.tscn

const THING := preload("res://tools/hold_probe_thing.gd")

var _failures := 0
var _player: Player


func _ready() -> void:
	OS.set_environment("RUN_PLAY", "1")
	RunSave.set_process(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _action(action: String, on: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = on
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(action: String) -> void:
	_action(action, true)
	await _frames(2)
	_action(action, false)
	await _frames(2)


# Just in front of her chest, on the line through the reticle.
func _in_front(thing: Node3D) -> void:
	var camera := _player.camera
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var chest := _player.global_position + Vector3(0.0, 1.2, 0.0)
	thing.global_position = origin + forward * ((chest - origin).dot(forward) + 0.6)


func _cup() -> Carryable:
	var item := Carryable.new()
	item.kind = "cup"
	item.item_id = "interaction_cup_%d" % get_child_count()
	add_child(item)
	_in_front(item)
	await _frames(4)
	return item


func _settle_here(at: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	_player._glide = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _frames(20)


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	_player = Game.player
	if _player == null:
		_check(false, "player exists")
		_finish()
		return
	Game.set_phase(Game.Phase.PLAYING)
	_player._autopilot = ""
	await _frames(20)
	await _input_pick_and_drop()
	await _hold_survives_pause()
	await _hold_target_freed()
	await _lantern_and_carry()
	await _drop_on_slope()
	_finish()


func _input_pick_and_drop() -> void:
	var cup := await _cup()
	_check(_player.aim.target == cup, "the cup in front of her is picked by the aim")
	await _tap("interact")
	_check(_player.carrying == cup, "an interact press picks it up")
	await _tap("drop")
	_check(_player.carrying == null and cup.carrier == null, "the drop key sets it down")
	# Carried to a socket that takes cups, a press places it there.
	_in_front(cup)
	await _frames(4)
	_check(_player.pick_up(cup), "she carries the cup again")
	var socket := CarrySocket.new()
	socket.accepts = PackedStringArray(["cup"])
	socket.socket_id = "interaction_socket"
	add_child(socket)
	_in_front(socket)
	await _frames(4)
	_check(_player.aim.target == socket, "the socket in front of her is picked")
	await _tap("interact")
	_check(_player.carrying == null and cup.socket == socket and socket.held.has(cup), "an interact press places it in the socket")
	socket.queue_free()
	cup.queue_free()
	await _frames(2)


func _hold_survives_pause() -> void:
	var thing := THING.new()
	thing.hold_seconds = 1.0
	add_child(thing)
	_in_front(thing)
	await _frames(3)
	_action("interact", true)
	await _frames(roundi(0.5 * Engine.physics_ticks_per_second))
	var before := _player.hold_progress
	_check(before > 0.3 and before < 0.7, "half a hold fills about half (%.2f)" % before)
	Game.toggle_pause()
	await _frames(roundi(1.0 * Engine.physics_ticks_per_second))
	_check(is_equal_approx(_player.hold_progress, before), "paused, the hold does not move (%.2f)" % _player.hold_progress)
	_action("interact", false)
	await _frames(2)
	Game.toggle_pause()
	await _frames(4)
	_check(not _player._holding, "released during the pause, nothing is still held after it")
	_check(thing.uses == 0, "a paused hold never completes on its own")
	thing.queue_free()
	await _frames(4)


func _hold_target_freed() -> void:
	var thing := THING.new()
	thing.hold_seconds = 1.0
	add_child(thing)
	_in_front(thing)
	await _frames(3)
	_action("interact", true)
	await _frames(roundi(0.4 * Engine.physics_ticks_per_second))
	_check(_player.hold_target == thing, "the hold is on the thing")
	thing.queue_free()
	await _frames(4)
	_check(_player.hold_target == null and is_zero_approx(_player.hold_progress), "freed mid-hold, the hold clears")
	_check(not _player._holds.has(thing), "and nothing remembers it")
	_action("interact", false)
	await _frames(2)


func _lantern_and_carry() -> void:
	_player.restore_lantern(false)
	await _frames(4)
	_check(_player.lantern_hold.HasLantern and not _player.lantern_hold.IsEquipped, "she has the lantern, stowed")
	# Carrying first, then the lantern key.
	var cup := await _cup()
	_check(_player.pick_up(cup), "she carries a cup")
	await _tap("toggle_lantern")
	await _frames(roundi((Tune.LANTERN_TOGGLE_SECONDS + 0.3) * Engine.physics_ticks_per_second))
	var both: bool = is_instance_valid(_player.carrying) and _player.lantern_hold.IsEquipped
	_check(not both, "the lantern key never puts the lantern in a hand that is carrying")
	_check(_player.lantern_hold.IsEquipped and cup.carrier == null, "the cup is set down and the lantern comes out")
	# Lantern first, then a pickup.
	if is_instance_valid(_player.carrying):
		_player.drop_carried()
		await _frames(2)
	if not _player.lantern_hold.IsEquipped:
		_player.toggle_lantern()
		await _frames(roundi((Tune.LANTERN_TOGGLE_SECONDS + 0.3) * Engine.physics_ticks_per_second))
	_check(_player.lantern_hold.IsEquipped, "the lantern is in her hand")
	_in_front(cup)
	await _frames(4)
	_player.pick_up(cup)
	await _frames(roundi((Tune.LANTERN_TOGGLE_SECONDS + 0.3) * Engine.physics_ticks_per_second))
	both = is_instance_valid(_player.carrying) and _player.lantern_hold.IsEquipped
	_check(not both, "a pickup never puts a carried thing in the lantern's hand")
	_check(cup.blocked_label().contains("lantern"), "and the refusal says why")
	if is_instance_valid(_player.carrying):
		_player.drop_carried()
	cup.queue_free()
	# Put the lantern away, so the next case starts with her hands free.
	if _player.lantern_hold.IsEquipped:
		_player.toggle_lantern()
		await _frames(roundi((Tune.LANTERN_TOGGLE_SECONDS + 0.3) * Engine.physics_ticks_per_second))
	_check(not _player.lantern_hold.IsEquipped, "the lantern goes away again")
	await _frames(4)


func _drop_on_slope() -> void:
	var ground := Game.trail.ground
	# The steepest walkable spot a few metres off the route, past the house pad.
	var best := Vector3.INF
	var steepest := 0.0
	for step in 40:
		var offset := Game.trail.player_start_offset + 30.0 + float(step) * 3.0
		var frame := Game.trail.frame_at(offset)
		for side in [-6.0, 6.0]:
			var at: Vector3 = frame.origin + frame.basis.x * side
			var slope: float = ground.slope_at(at.x, at.z)
			if slope > steepest and slope < Tune.FOREST_SLOPE:
				steepest = slope
				best = Vector3(at.x, ground.height_at(at.x, at.z), at.z)
	_check(best != Vector3.INF, "an outdoor slope near the route (%.2f)" % steepest)
	if best == Vector3.INF:
		return
	await _settle_here(best + Vector3.UP * 0.3)
	var cup := await _cup()
	_check(_player.pick_up(cup), "she carries a cup on the slope")
	_check(_player.drop_carried(), "and sets it down there")
	await _frames(30)
	var under := ground.height_at(cup.global_position.x, cup.global_position.z)
	_check(cup.global_position.y >= under - 0.05 and cup.global_position.y <= under + 0.3,
		"the cup rests on the snow (%.2f m over the ground)" % (cup.global_position.y - under))
	cup.queue_free()


func _finish() -> void:
	print("Interaction probe: %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
