extends Node

# Hold to do: a tap still does instant things at once; something with
# interact_hold_seconds() fills while interact is held on it, pauses when let
# go, is forgotten after HOLD_FORGET, and never moves while she reads.
#   godot --headless --path . tools/hold_probe.tscn

const THING := preload("res://tools/hold_probe_thing.gd")

var _failures := 0
var _player: Player


func _ready() -> void:
	OS.set_environment("RUN_PLAY", "1")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _press(on: bool) -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = on
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# A fresh thing just in front of her, on the line through the reticle.
func _thing(seconds: float, instant_only := false) -> Node3D:
	var thing: Node3D
	if instant_only:
		var script := GDScript.new()
		script.source_code = "extends Node3D\nvar uses := 0\nfunc _ready() -> void:\n\tadd_to_group(\"interactables\")\nfunc interact_label() -> String:\n\treturn \"Tap\"\nfunc interact_point() -> Vector3:\n\treturn global_position\nfunc interact() -> bool:\n\tuses += 1\n\treturn true\nfunc aim_box() -> Array:\n\treturn [global_transform, AABB(Vector3(-0.2, -0.2, -0.2), Vector3(0.4, 0.4, 0.4))]\n"
		script.reload()
		thing = Node3D.new()
		thing.set_script(script)
	else:
		thing = THING.new()
		thing.hold_seconds = seconds
	add_child(thing)
	var camera := _player.camera
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var chest := _player.global_position + Vector3(0.0, 1.2, 0.0)
	var along := (chest - origin).dot(forward) + 0.6
	thing.global_position = origin + forward * along
	await _frames(3)
	return thing


func _gone(thing: Node3D) -> void:
	thing.queue_free()
	await _frames(2)


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	Game.set_phase(Game.Phase.PLAYING)
	_player = Game.player
	if _player == null:
		_check(false, "the run builds a player")
		print("HOLD FAIL (%d)" % _failures)
		get_tree().quit(1)
		return
	_player._autopilot = ""
	var curve := Game.trail.curve
	var spot := curve.sample_baked(curve.get_baked_length() * 0.3)
	_player.global_position = Game.trail.on_ground(spot) + Vector3.UP * 0.05
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _frames(30)
	await _instant_unchanged()
	await _door_tap()
	await _hold_completes()
	await _release_pauses()
	await _reach_pauses()
	await _aim_away_pauses()
	await _forget()
	await _reading_blocks()
	print("HOLD %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _instant_unchanged() -> void:
	var thing := await _thing(0.0, true)
	_check(_player.aim.target == thing, "the tap thing is picked")
	_press(true)
	await _frames(1)
	_press(false)
	await _frames(5)
	_check(thing.get("uses") == 1, "a tap does an instant thing once (%d)" % thing.get("uses"))
	_check(_player.hold_target == null and _player.hold_progress == 0.0, "and starts no hold")
	await _gone(thing)


func _hold_completes() -> void:
	var thing := await _thing(1.0)
	_check(_player.aim.target == thing, "the held thing is picked")
	_press(true)
	await _seconds(0.5)
	_check(thing.uses == 0 and _player.hold_target == thing, "half held, not done yet")
	_check(absf(_player.hold_progress - 0.5) < 0.05, "half held is about half (%.2f)" % _player.hold_progress)
	_check(absf(thing.last_fraction - _player.hold_progress) < 0.001, "the thing hears the progress")
	await _seconds(0.6)
	_check(thing.uses == 1, "held 1.1 s it is done once (%d)" % thing.uses)
	await _frames(20)
	_press(false)
	await _frames(3)
	_check(thing.uses == 1 and _player.hold_progress == 0.0, "still once, and the ring is clear")
	await _gone(thing)


func _door_tap() -> void:
	var root := Node3D.new()
	add_child(root)
	var camera := _player.camera
	var forward := -camera.global_basis.z
	var chest := _player.global_position + Vector3(0.0, 1.2, 0.0)
	var along := (chest - camera.global_position).dot(forward) + 1.0
	var centre := camera.global_position + forward * along
	var door := HouseDoor.make(root, "HoldProbeDoor", centre - Vector3.UP * 1.05,
		_player.rotation.y, Vector3(0.9, 2.1, 0.045), "plank", StandardMaterial3D.new())
	await _frames(3)
	_check(_player.aim.target == door and not door.is_open, "a real closed door is picked")
	_press(true)
	await _frames(1)
	_press(false)
	await _frames(5)
	_check(door.is_open, "a tap opens a real door and does not close it again")
	_check(_player.hold_target == null and _player.hold_progress == 0.0, "a real door starts no hold")
	await _gone(root)


func _release_pauses() -> void:
	var thing := await _thing(1.0)
	_press(true)
	await _seconds(0.5)
	_press(false)
	await _frames(2)
	var kept := _player.hold_progress
	await _seconds(1.0)
	_check(thing.uses == 0 and absf(_player.hold_progress - kept) < 0.001 and kept > 0.4, "let go, it waits (%.2f)" % _player.hold_progress)
	_press(true)
	await _seconds(0.6)
	_check(thing.uses == 1, "picked up again, it finishes (%d)" % thing.uses)
	_press(false)
	await _gone(thing)


func _reach_pauses() -> void:
	var thing := await _thing(1.0)
	_press(true)
	await _seconds(0.85)
	var before := _player.hold_progress
	_check(before > 0.75 and thing.uses == 0, "reach check starts near completion")
	# Keep the rendered aim deliberately stale while physics continues. This
	# also covers several physics ticks between rendered frames on a slow GPU.
	_player.set_process(false)
	var standing := _player.global_transform
	_player.global_position += Vector3.RIGHT * (Tune.INTERACT_REACH + 4.0)
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _seconds(0.4)
	_check(_player.aim.target == thing, "reach check keeps the cached aim unchanged")
	_check(thing.uses == 0 and absf(_player.hold_progress - before) < 0.001,
		"out of reach cannot finish a nearly complete hold")
	_player.global_transform = standing
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _seconds(0.3)
	_check(thing.uses == 1, "returning within the grace period resumes the held action")
	_press(false)
	_player.set_process(true)
	await _gone(thing)


func _aim_away_pauses() -> void:
	var thing := await _thing(1.0)
	_press(true)
	await _seconds(0.5)
	var before := _player.hold_progress
	_player.set_process(false)
	var facing := _player.camera.global_transform
	_player.camera.rotate_y(PI)
	_player.aim.update(_player)
	_check(_player.aim.target != thing, "looking away removes the held target from aim")
	await _seconds(0.7)
	_check(thing.uses == 0 and absf(_player.hold_progress - before) < 0.001,
		"aiming away pauses while interact stays held")
	_player.camera.global_transform = facing
	_player.aim.update(_player)
	_check(_player.aim.target == thing, "looking back picks the unfinished target again")
	await _seconds(0.6)
	_check(thing.uses == 1, "looking back resumes without another press")
	_press(false)
	_player.set_process(true)
	await _gone(thing)


func _forget() -> void:
	var thing := await _thing(1.0)
	_press(true)
	await _seconds(0.5)
	_press(false)
	await _seconds(Tune.HOLD_FORGET + 0.5)
	_check(_player.hold_progress == 0.0 and _player.hold_target == null, "left alone, it is forgotten")
	_check(thing.last_fraction == 0.0, "forgetting also resets the target's visual progress")
	_press(true)
	await _seconds(0.6)
	_check(thing.uses == 0, "and starts again from nothing (%d)" % thing.uses)
	_press(false)
	await _gone(thing)


func _reading_blocks() -> void:
	var thing := await _thing(1.0)
	_press(true)
	await _seconds(0.3)
	var before := _player.hold_progress
	Game.set_phase(Game.Phase.READING)
	await _seconds(1.2)
	_check(thing.uses == 0 and absf(_player.hold_progress - before) < 0.001, "no progress while reading (%.2f -> %.2f)" % [before, _player.hold_progress])
	_press(false)
	Game.set_phase(Game.Phase.PLAYING)
	await _frames(3)
	await _gone(thing)
