class_name CarryProbe
extends Node

var _failed := 0
var _player: Player
var _lamp: Carryable
var _palm := Vector3.ZERO


func _ready() -> void:
	OS.set_environment("RUN_PLAY", "1")
	RunSave.set_process(false)
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _ticks(8)
	_player = Game.player
	if _player == null:
		_check(false, "player exists")
		_finish()
		return
	Game.set_phase(Game.Phase.PLAYING)
	_player._autopilot = ""
	await _ticks(20)
	await _pick_and_drop()
	await _socket_accepts_kind()
	await _socket_capacity()
	await _socket_reflow()
	await _heavy_no_sprint()
	await _light_runs()
	await _bow_blocks_carry()
	await _read_keeps_item()
	await _indoors_drop_on_floor()
	await _hand_follows()
	await _drop_in_front_of_her()
	await _reparent_keeps_visual()
	await _hands_full()
	await _drop_ignored_in_dialogue()
	_lamp.global_position = _player.global_position + Vector3.UP * 0.7
	_check(_player.pick_up(_lamp) and not _player.pick_up(_lamp), "repeat pickup cannot duplicate ownership")
	_check(str(RunSave._capture_player().get("carrying_item_id", "")) == _lamp.item_id, "snapshot captures the stable item id")
	Game.mathilda_pov = true
	_check(not _player.drop_carried(), "Mathilda cannot use carry")
	Game.mathilda_pov = false
	Game.dream_mode = true
	_check(not _player.drop_carried(), "dream cannot use carry")
	Game.dream_mode = false
	_finish()


func _item(kind: String, heavy := false) -> Carryable:
	var item := Carryable.new()
	item.kind = kind
	item.heavy = heavy
	item.item_id = "probe_%s_%d" % [kind, get_child_count()]
	add_child(item)
	item.global_position = _player.global_position + Vector3.UP * 0.7 - _player.global_basis.z * 0.4
	return item


func _socket(kind: String) -> CarrySocket:
	var socket := CarrySocket.new()
	socket.accepts = PackedStringArray([kind])
	socket.socket_id = "probe_socket_%d" % get_child_count()
	add_child(socket)
	socket.global_position = _player.global_position + Vector3.UP * 0.7 - _player.global_basis.z * 0.45
	return socket


func _pick_and_drop() -> void:
	var cup := _item("cup")
	_check(_player.pick_up(cup), "_pick_and_drop: nearby cup picked")
	_check(not cup.is_in_group("interactables"), "held item leaves aim candidates")
	_check(cup.visual.get_parent() == _player.carry_hold.get_parent(), "visual follows rig without BoneAttachment")
	_check(_player.drop_carried(), "_pick_and_drop: put down")
	_check(_player.carrying == null and cup.is_in_group("interactables"), "drop releases ownership and offers pickup")
	cup.queue_free()
	await _ticks(2)


func _socket_accepts_kind() -> void:
	var cup := _item("cup")
	var box := _socket("firewood")
	_check(_player.pick_up(cup) and not _player.place(box), "_socket_accepts_kind: woodbox refuses cup")
	_check(not box.is_in_group("interactables"), "wrong-kind socket is not targetable")
	_player.drop_carried()
	cup.queue_free()
	box.queue_free()
	await _ticks(2)


func _socket_capacity() -> void:
	var socket := _socket("cup")
	var first := _item("cup")
	_check(_player.pick_up(first) and _player.place(socket), "_socket_capacity: accepts first item")
	var second := _item("cup")
	_check(_player.pick_up(second) and not _player.place(socket), "_socket_capacity: refuses a second")
	_player.drop_carried()
	socket.allow_take = false
	first.refresh_interaction()
	_check(not _player.pick_up(first), "socket can keep deposited item")
	socket.allow_take = true
	_check(_player.pick_up(first) and socket.held.is_empty(), "taking placed item releases socket capacity")
	_player.drop_carried()
	first.queue_free()
	second.queue_free()
	socket.queue_free()
	await _ticks(2)


func _outside() -> void:
	_player.global_position = Game.trail.on_ground(Game.trail.position_at(Game.trail.player_start_offset + 12.0)) + Vector3.UP * 0.08
	_player.velocity = Vector3.ZERO
	_player._glide = Vector3.ZERO
	_player._yaw = 0.0
	_player.reset_physics_interpolation()
	await _ticks(25)


func _socket_reflow() -> void:
	var socket := _socket("cup")
	socket.capacity = 2
	var first := _item("cup")
	var second := _item("cup")
	_check(_player.pick_up(first) and _player.place(socket), "multi socket first placed")
	_check(_player.pick_up(second) and _player.place(socket), "multi socket second placed")
	_check(_player.pick_up(first), "non-last item removed")
	_check(second.global_position.distance_to(socket.item_transform(0).origin) < 0.01, "remaining item reflows to vacant slot")
	_check(_player.place(socket) and first.global_position.distance_to(second.global_position) > 0.15, "refill cannot overlap survivor")
	first.queue_free()
	await _ticks(2)
	_check(socket.held.size() == 1, "freed item releases socket capacity")
	second.queue_free()
	socket.queue_free()
	await _ticks(2)


func _heavy_no_sprint() -> void:
	await _outside()
	var wood := _item("firewood", true)
	_check(_player.pick_up(wood), "heavy armful picked")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var fastest := 0.0
	for i in 120:
		await _ticks(1)
		fastest = maxf(fastest, Vector2(_player.velocity.x, _player.velocity.z).length())
	_check(not _player._sprinting and fastest <= Tune.CARRY_HEAVY_SPEED + 0.05, "_heavy_no_sprint: speed capped %.3f" % fastest)
	await _capture("armful")
	_player._jump()
	_check(not _player.leaping and _player.velocity.y <= 0.0, "_heavy_no_leap: direct jump blocked")
	_player._start_slide()
	_check(not _player.sliding, "heavy armful blocks slide")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _ticks(25)
	_player.drop_carried()
	wood.queue_free()
	await _ticks(2)


func _light_runs() -> void:
	await _outside()
	_lamp = _item("lamp")
	_check(_player.pick_up(_lamp), "lamp picked")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _ticks(70)
	_check(_player._sprinting and _player._ground_speed() > Tune.CARRY_HEAVY_SPEED + 0.2, "_light_runs: lamp allows sprint")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _ticks(30)
	_player.drop_carried()


func _bow_blocks_carry() -> void:
	Game.has_bow = true
	_player.restore_bow()
	_lamp.global_position = _player.global_position + Vector3.UP * 0.7
	_check(_player.pick_up(_lamp), "lamp held before drawing bow")
	_check(_player.toggle_bow() and _player.carrying == null, "drawing bow first sets item down")
	await _ticks(120)
	_check(_player.bow_hoist.IsDrawn and not _player.pick_up(_lamp), "_bow_blocks_carry: drawn bow refuses pickup")
	_check(_player.toggle_bow(), "bow can be stowed")
	for i in 600:
		if not _player.bow_hoist.Busy:
			break
		await _ticks(1)
	_check(not _player.bow_hoist.Busy and not _player.bow_hoist.IsDrawn, "bow stowed and idle")


func _read_keeps_item() -> void:
	_lamp.global_position = _player.global_position + Vector3.UP * 0.7
	_check(_player.pick_up(_lamp), "lamp picked after stowing")
	Game.set_phase(Game.Phase.READING)
	await _ticks(3)
	var drop := InputEventAction.new()
	drop.action = "drop"
	drop.pressed = true
	_player._unhandled_input(drop)
	_check(_player.carrying == _lamp, "_read_keeps_item: reading and drop input keep item")
	Game.set_phase(Game.Phase.JOURNAL)
	_player._unhandled_input(drop)
	_check(_player.carrying == _lamp, "journal keeps held item")
	Game.set_phase(Game.Phase.PLAYING)


func _indoors_drop_on_floor() -> void:
	_player.global_position = Game.house.spawn_point()
	_player.velocity = Vector3.ZERO
	_player._glide = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _ticks(25)
	_check(_player.indoors(), "floor check is inside house")
	var floor_y := _player.global_position.y
	_check(_player.drop_carried() and absf(_lamp.global_position.y - floor_y) < 0.15, "_indoors_drop_on_floor: stays on current floor")


func _hand_follows() -> void:
	await _outside()
	_lamp.global_position = _player.global_position + Vector3.UP * 0.7
	_check(_player.pick_up(_lamp), "lamp picked for evaluated hand check")
	var rig := _player.carry_hold.get_parent() as Skeleton3D
	# The skin is drawn at the rig's interpolated transform times the evaluated bone
	# poses, so that is the rendered palm. This proves the visual lands on the palm
	# after every arm modifier in the frame it is drawn; it does not look at pixels.
	_player.carry_hold.modification_processed.connect(func() -> void:
		_palm = rig.get_global_transform_interpolated() * rig.get_bone_global_pose(rig.find_bone("DEF-hand.R")).origin)
	Input.action_press("move_forward")
	await _ticks(60)
	var error := _lamp.visual.global_position.distance_to(_palm)
	_check(error < 0.15, "_hand_follows: evaluated palm error %.3f" % error)
	await _capture("hand")
	Input.action_release("move_forward")
	await _ticks(25)


func _drop_in_front_of_her() -> void:
	# Walk toward the camera so her model faces about 180 degrees from the view,
	# then set the lamp down: it lands ahead of her, behind the camera's forward.
	_check(_player.drop_carried(), "lamp set down before facing check")
	await _outside()
	_lamp.global_position = _player.global_position + Vector3.UP * 0.7
	_check(_player.pick_up(_lamp), "lamp picked for facing check")
	Input.action_press("move_back")
	await _ticks(50)
	Input.action_release("move_back")
	await _ticks(40)
	var heading := Vector3(-sin(_player._facing), 0.0, -cos(_player._facing))
	var view := -_player.global_basis.z
	_check(heading.dot(view) < -0.8, "_drop_in_front_of_her: she faces the camera (%.2f)" % heading.dot(view))
	var from := _player.global_position
	_check(_player.drop_carried(), "_drop_in_front_of_her: put down")
	var offset := _lamp.global_position - from
	offset.y = 0.0
	_check(offset.dot(heading) > 0.3 and offset.dot(view) < 0.0, "_drop_in_front_of_her: lands in front of her model (%.2f ahead)" % offset.dot(heading))
	_check((-_lamp.global_basis.z).dot(heading) > 0.95, "_drop_in_front_of_her: turned the way she faces")
	await _ticks(2)
	_lamp.global_position = _player.global_position + Vector3.UP * 0.7
	_check(_player.pick_up(_lamp), "lamp picked again after facing check")
	_check(_lamp.world_position().distance_to(_lamp.visual.global_position) < 0.001 and _lamp.interact_point() == _lamp.world_position(), "carried world_position follows the visual")


func _reparent_keeps_visual() -> void:
	var shelf := Node3D.new()
	add_child(shelf)
	var shown := _lamp.visual
	_lamp.reparent(shelf)
	await _ticks(2)
	_check(is_instance_valid(shown) and shown.get_parent() == _lamp and _player.carrying == null, "_reparent_keeps_visual: reparenting a held item lets go and keeps its visual")
	_lamp.reparent(self)
	shelf.queue_free()
	await _ticks(2)
	_lamp.global_position = _player.global_position + Vector3.UP * 0.7
	_check(_player.pick_up(_lamp), "lamp picked after reparent")


func _hands_full() -> void:
	var other := _item("cup")
	_check(_player.carrying == _lamp and other.is_in_group("interactables"), "second item stays aimable while hands are full")
	_check(not other.interact() and other.blocked_label() == "Your hands are full.", "_hands_full: second pickup refused with a reason")
	other.queue_free()
	await _ticks(2)


func _drop_ignored_in_dialogue() -> void:
	var drop := InputEventAction.new()
	drop.action = "drop"
	drop.pressed = true
	Game.set_phase(Game.Phase.DIALOGUE)
	await _ticks(2)
	_player._unhandled_input(drop)
	_check(_player.carrying == _lamp, "_drop_ignored_in_dialogue: dialogue phase keeps item")
	Game.set_phase(Game.Phase.PLAYING)
	await _ticks(2)
	_player.dialogue_locked = true
	_player._unhandled_input(drop)
	_check(_player.carrying == _lamp, "_drop_ignored_in_dialogue: dialogue lock keeps item")
	_player.dialogue_locked = false
	_player._unhandled_input(drop)
	_check(_player.carrying == null, "drop action works again once free")


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _capture(tag: String) -> void:
	if OS.get_environment("RUN_CARRY_CAPTURE") != "1" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/errands"))
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 38.0
	var rig := _player.carry_hold.get_parent() as Skeleton3D
	camera.look_at_from_position(rig.to_global(Vector3(-2.4, 1.5, 3.2)), rig.to_global(Vector3(0.0, 1.1, 0.1)))
	camera.current = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/errands/carry_%s.png" % tag))
	_player.camera.current = true
	camera.queue_free()


func _check(ok: bool, message: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		_failed += 1


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print("CARRY PASS" if _failed == 0 else "CARRY FAIL (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
