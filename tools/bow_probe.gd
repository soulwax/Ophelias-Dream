extends Node

## Real player pickup/hoist/checkpoint probe. With a window, captures the gesture.
## godot-mono --headless --path . tools/bow_probe.tscn
var _failed := 0
var _events := 0
var _player: Player
var _pickup: Node3D
var _camera: Camera3D
var _sheet: Image
var _frame := 0
var _capture_tag := "hoist"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	_player = Game.player
	_pickup = get_tree().get_first_node_in_group("bow_pickup") as Node3D
	_check(_pickup != null and _player.bow_hoist != null, "world bow and C# modifier exist")
	if _pickup == null or _player.bow_hoist == null:
		_finish()
		return
	_check(not Game.has_bow and not _player.bow_hoist.HasBow, "she starts without a bow")
	_check(not _player.toggle_bow(), "she cannot draw a bow before finding it")
	_check(not bool(_pickup.call("interact")), "pickup is refused before play")
	Game.set_phase(Game.Phase.PLAYING)
	_check(not bool(_pickup.call("interact")), "distant pickup is refused")
	_player._autopilot = ""
	var spot := _pickup.global_position + Vector3(0.0, 0.0, 0.32)
	_player.global_position = Game.trail.on_ground(spot) + Vector3.UP * 0.05
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _ticks(20)
	_player.bow_hoist.connect("Hoisted", func() -> void: _events += 1)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/animation/bow"))
		_camera = Camera3D.new()
		_camera.fov = 38.0
		get_tree().root.add_child(_camera)
		_camera.current = true
		_sheet = Image.create(1600, 600, false, Image.FORMAT_RGB8)
		await _capture()
	_check(bool(_pickup.call("interact")), "nearby stationary player begins the reach")
	_check(_player.bow_hoist.Busy, "pickup starts the animation")
	_check(not bool(_pickup.call("interact")), "repeat interaction cannot duplicate the bow")
	var held_at := _player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _ticks(18)
	_check(_player.global_position.distance_to(held_at) > 0.05, "walking input moves her legs during the reach")
	_check(not _player._sprinting and _player._ground_speed() < Tune.WALK_SPEED, "sprint input remains a careful walk while hoisting")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var before: float = _player.bow_hoist.Progress
	Game.set_phase(Game.Phase.JOURNAL)
	await _ticks(12)
	_check(is_equal_approx(before, _player.bow_hoist.Progress), "journal freezes the gesture without finishing it")
	Game.set_phase(Game.Phase.PLAYING)
	var max_error := 0.0
	var max_speed := 0.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for sample in 6:
		await _ticks(22)
		max_speed = maxf(max_speed, _player._ground_speed())
		var progress: float = _player.bow_hoist.Progress
		if progress >= 0.12 and progress <= 0.8:
			max_error = maxf(max_error, _player.bow_hoist.HandError)
		print("  pose %.3f reach error %.3f" % [progress, _player.bow_hoist.HandError])
		await _capture()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check(max_speed < Tune.WALK_SPEED, "held sprint stays at walking pace throughout hoist (%.3f m/s)" % max_speed)
	await _ticks(30)
	await _capture()
	_check(not _player.bow_hoist.Busy and Game.has_bow, "hoist finishes and grants ownership")
	_check(_events == 1, "completion fires exactly once")
	var carried := _pickup.get("bow") as Node3D
	_check(carried.get_parent() is BoneAttachment3D, "bow is attached to her back bone")
	_check(max_error < 0.1, "gripped lift/seat targets stay in reach (%.3f m)" % max_error)
	Game.reach_checkpoint()
	_check(bool(Game.checkpoint.get("has_bow", false)), "lookout checkpoint remembers the found bow")
	Game._resume = true
	Game.has_bow = false
	Game.resume_checkpoint()
	_check(Game.has_bow and carried == _pickup.get("bow"), "checkpoint restore keeps one carried bow")
	Input.action_press("move_forward")
	await _ticks(25)
	Input.action_release("move_forward")
	_check(_player.global_position.distance_to(held_at) > 0.2, "movement resumes after the hoist")
	if _sheet:
		_sheet.save_png(ProjectSettings.globalize_path("res://build/animation/bow/hoist_sheet.png"))
	await _draw_and_stow(carried)
	await _combat_and_arrows()
	# A fresh rig is what a checkpoint reload really needs to restore.
	var model := (load("res://assets/characters/styloo_elf/elf.glb") as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	add_child(model)
	model.visible = false
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var restored := BowHoist.new()
	skeleton.add_child(restored)
	restored.Configure(Tune.BOW_HOIST_SECONDS, Tune.BOW_BACK_POSITION, Tune.BOW_BACK_ROLL)
	restored.ConfigureDrawing(Tune.BOW_DRAW_SECONDS, Tune.BOW_HAND_POSITION, Tune.BOW_HAND_ROLL)
	var bow := (load(Tune.BOW_MODEL) as PackedScene).instantiate() as Node3D
	model.add_child(bow)
	restored.Restore(bow)
	_check(restored.HasBow and not restored.Busy and bow.get_parent() is BoneAttachment3D, "fresh checkpoint rig restores the back attachment without replay")
	model.queue_free()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	Game.reset()
	_check(not Game.has_bow, "new run clears equipment ownership")
	_check(Game.arrow_count == 0 and Game.arrow_pickups.is_empty(), "new run clears arrows and picked bundles")
	_finish()


func _combat_and_arrows() -> void:
	var supplies := get_tree().get_nodes_in_group("arrow_supplies")
	_check(supplies.size() >= 3, "three finite arrow bundles are placed along the route")
	if supplies.is_empty():
		return
	var supply := supplies[0] as Node3D
	_player.global_position = Game.trail.on_ground(supply.global_position + Vector3(0.0, 0.0, 0.3)) + Vector3.UP * 0.04
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _ticks(4)
	_check(bool(supply.call("interact")), "nearby arrows begin the reaching gesture")
	_check(_player.bow_hoist.Busy, "arrow collection locks the arms into its transition")
	await _ticks(58)
	_check(Game.arrow_count == 4, "collection adds the bundle to the quiver")
	_check(_player.bow_hoist.HandError < 0.1, "reaching and stowing the arrow stays within arm reach")
	_check(not supply.visible, "an empty bundle disappears from the route")
	_check(_player.toggle_bow(), "she can draw the bow after collecting arrows")
	await _ticks(120)
	_check(_player.bow_hoist.IsDrawn, "combat stance is ready after the draw transition")
	_check(not _player._shoot_arrow(), "the bow will not loose an arrow before she aims")
	Input.action_press("aim_bow")
	await _ticks(12)
	_check(_player.bow_hoist.AimWeight > 0.5, "aim blends her support hand and nocks a finite arrow")
	_check(_player.bow_hoist.HandError < 0.1, "the supporting hand remains within reach while aiming")
	_capture_tag = "combat"
	_frame = 0
	if _sheet:
		_sheet.fill(Color.BLACK)
		await _capture()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _ticks(34)
	_check(_player._ground_speed() > Tune.WALK_SPEED + 0.2, "combat stance keeps a moving sprint available")
	_check(_player.bow_hoist.RunWeight > 0.5, "upper body lowers into the combat run carry")
	await _capture()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _ticks(12)
	await _capture()
	if _sheet:
		_sheet.save_png(ProjectSettings.globalize_path("res://build/animation/bow/combat_sheet.png"))
	_check(_player._shoot_arrow(), "aimed fire starts the string draw and release gesture")
	await _ticks(26)
	_check(Game.arrow_count == 3, "release consumes one arrow")
	_check(_player.bow_hoist.HandError < 0.1, "the string draw stays within arm reach")
	var fired := get_tree().get_nodes_in_group("fired_arrows")
	_check(not fired.is_empty(), "release spawns a recoverable arrow projectile")
	if not fired.is_empty():
		await _ticks(12)
		var arrow := fired[0] as Node3D
		arrow.set("stuck", true)
		_player.global_position = Game.trail.on_ground(arrow.global_position + Vector3(0.0, 0.0, 0.25)) + Vector3.UP * 0.04
		_player.velocity = Vector3.ZERO
		_player.reset_physics_interpolation()
		await _ticks(3)
		_check(bool(arrow.call("interact")), "a stuck arrow begins the same recovery animation")
		await _ticks(58)
		_check(Game.arrow_count == 4, "recovered arrows return to the finite quiver")
	Input.action_release("aim_bow")


func _draw_and_stow(carried: Node3D) -> void:
	await _ticks(20)
	var draws := [0]
	_player.bow_hoist.connect("Drawn", func() -> void: draws[0] += 1)
	var rig := _player.bow_hoist.get_parent() as Skeleton3D
	var left_palm := [Vector3.ZERO]
	_player.bow_hoist.modification_processed.connect(func() -> void:
		left_palm[0] = rig.get_bone_global_pose(rig.find_bone("DEF-hand.L")).origin)
	_capture_tag = "draw"
	_frame = 0
	if _sheet:
		_sheet.fill(Color.BLACK)
	await _capture()
	var event := InputEventAction.new()
	event.action = "draw_bow"
	event.pressed = true
	_player._unhandled_input(event)
	_check(_player.bow_hoist.Busy, "draw action reaches the player animation")
	_check(_player.bow_hoist.UsesLeftHand, "draw uses the left arm")
	_check(not _player.toggle_bow(), "repeated draw input does not restart the gesture")
	await _ticks(12)
	var before: float = _player.bow_hoist.Progress
	Game.set_phase(Game.Phase.JOURNAL)
	await _ticks(12)
	_check(is_equal_approx(before, _player.bow_hoist.Progress), "journal freezes the draw gesture")
	Game.set_phase(Game.Phase.PLAYING)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var max_speed := 0.0
	var max_error := 0.0
	for sample in 6:
		await _ticks(15)
		max_speed = maxf(max_speed, _player._ground_speed())
		max_error = maxf(max_error, _player.bow_hoist.HandError)
		await _capture()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _ticks(15)
	await _capture()
	_check(_player.bow_hoist.IsDrawn and not _player.bow_hoist.Busy, "draw finishes in a held bow pose")
	_check(draws[0] == 1 and Game.has_bow, "draw fires once and preserves ownership")
	_check(carried.get_parent() == _player.bow_hoist.get_parent(), "same bow follows the hand rather than the back attachment")
	_check(max_speed < Tune.WALK_SPEED, "legs walk but cannot sprint during draw")
	_check(max_error < 0.1, "draw targets stay in arm reach (%.3f m)" % max_error)
	await _ticks(20)
	_check(rig.to_local(carried.global_position).distance_to(Tune.BOW_HAND_POSITION) < 0.1, "held grip stays beside her body after recovery")
	_check(rig.to_local(carried.global_position).distance_to(left_palm[0]) < 0.11, "held bow remains at the evaluated left palm")
	if _sheet:
		_sheet.save_png(ProjectSettings.globalize_path("res://build/animation/bow/draw_sheet.png"))
	_capture_tag = "stow"
	_frame = 0
	if _sheet:
		_sheet.fill(Color.BLACK)
	await _capture()
	_check(_player.toggle_bow(), "same action begins putting the bow away")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for sample in 6:
		await _ticks(25)
		await _capture()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _ticks(25)
	await _capture()
	_check(not _player.bow_hoist.IsDrawn and not _player.bow_hoist.Busy, "put-away finishes and releases the left arm")
	_check(carried.get_parent() is BoneAttachment3D and _events == 2, "same bow returns to the back once")
	var mounted := rig.get_bone_global_rest(rig.find_bone("DEF-spine.003")) * carried.transform
	_check(mounted.origin.distance_to(Tune.BOW_BACK_POSITION) < 0.001, "rest-relative back mount keeps the tighter offset across poses")
	if _sheet:
		_sheet.save_png(ProjectSettings.globalize_path("res://build/animation/bow/stow_sheet.png"))


func _capture() -> void:
	if _camera == null:
		return
	var rig := _player.bow_hoist.get_parent() as Skeleton3D
	var side := -1.0 if _capture_tag == "hoist" else 1.0
	_camera.look_at_from_position(rig.to_global(Vector3(3.2 * side, 1.65, -3.4)), rig.to_global(Vector3(0.0, 1.15, 0.0)))
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://build/animation/bow/%s_%02d.png" % [_capture_tag, _frame]))
	shot.resize(400, 300)
	_sheet.blit_rect(shot, Rect2i(0, 0, 400, 300), Vector2i((_frame % 4) * 400, (_frame / 4) * 300))
	_frame += 1


func _ticks(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failed += 1


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print("Bow probe: %s" % ("PASS" if _failed == 0 else "FAIL (%d)" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)
