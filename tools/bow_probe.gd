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
		_camera.fov = 32.0
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
	# A fresh rig is what a checkpoint reload really needs to restore.
	var model := (load("res://assets/characters/styloo_elf/elf.glb") as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	add_child(model)
	model.visible = false
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var restored := BowHoist.new()
	skeleton.add_child(restored)
	restored.Configure(Tune.BOW_HOIST_SECONDS, Tune.BOW_BACK_POSITION, Tune.BOW_BACK_ROLL)
	var bow := (load(Tune.BOW_MODEL) as PackedScene).instantiate() as Node3D
	model.add_child(bow)
	restored.Restore(bow)
	_check(restored.HasBow and not restored.Busy and bow.get_parent() is BoneAttachment3D, "fresh checkpoint rig restores the back attachment without replay")
	model.queue_free()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	Game.reset()
	_check(not Game.has_bow, "new run clears equipment ownership")
	if _sheet:
		_sheet.save_png(ProjectSettings.globalize_path("res://build/animation/bow/hoist_sheet.png"))
	_finish()


func _capture() -> void:
	if _camera == null:
		return
	var rig := _player.bow_hoist.get_parent() as Skeleton3D
	_camera.look_at_from_position(rig.to_global(Vector3(-3.2, 1.65, -3.4)), rig.to_global(Vector3(0.0, 1.15, 0.0)))
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://build/animation/bow/hoist_%02d.png" % _frame))
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
