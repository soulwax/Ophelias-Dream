extends Node

## W09: placement, five real holds, a mid-walk save/load, glove recovery,
## non-counting keepsake, and the optional camp placement.
var _main: Node
var _failures := 0


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


func _start() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	for frame in 900:
		await get_tree().process_frame
		if Game.player and Game.phase == Game.Phase.PLAYING and Game.errands and Game.errands.is_built and not RunSave.has_pending_load():
			break
	await _frames(8)
	if Game.player:
		Game.player._autopilot = ""


func _walk() -> RedThread:
	return Game.errands.builders.get(RedThread.ID) as RedThread if Game.errands else null


func _reload() -> void:
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(RunSave.queue_load(), "saved walk loads")
	await _start()


func _run() -> void:
	await _start()
	var walk := _walk()
	if walk == null:
		_check(false, "red-thread builder exists")
		_finish()
		return
	_check(walk.snags.size() == 5 and walk.anchors.size() == 7, "five snags lead to the birch")
	var links_ok := true
	var visible_ok := true
	for i in 6:
		var length := walk.anchors[i].distance_to(walk.anchors[i + 1])
		links_ok = links_ok and length > 1.0 and length < 23.0
		visible_ok = visible_ok and walk._ground_clearance(walk.anchors[i], walk.anchors[i + 1]) > 0.35
	_check(links_ok, "each neighbouring length is within walking visibility")
	_check(visible_ok, "the snow does not hide a next snag at player height")
	var tree_anchors := 0
	for i in range(1, 7):
		for tree: Vector3 in Game.trail.flora.tree_positions(walk.anchors[i], 0.35):
			tree_anchors += 1
			break
	_check(tree_anchors >= 1, "the walk reaches an actual tree anchor (%d of 6)" % tree_anchors)
	if OS.get_environment("PROBE_VIEWS") == "1":
		await _views(walk)
		_finish()
		return
	if OS.get_environment("PROBE_PLACEMENT_ONLY") == "1":
		for i in range(1, 7):
			var near := Game.trail.flora.nearest_indices(walk.anchors[i], 1, 40.0)
			var gap := walk.anchors[i].distance_to(Game.trail.flora.trees[near[0]]) if not near.is_empty() else -1.0
			var from := walk.anchors[i - 1] + Vector3.UP * 1.6
			var to := walk.anchors[i] + Vector3.UP * 0.95
			var clearance := 99.0
			for sample in range(1, 20):
				var at := from.lerp(to, float(sample) / 20.0)
				clearance = minf(clearance, at.y - Game.trail.ground.height_at(at.x, at.z))
			print("ANCHOR %d at %s, nearest tree %.1f m at %s, link %.1f m, clearance %.2f" % [i, walk.anchors[i], gap, Game.trail.flora.trees[near[0]] if not near.is_empty() else Vector3.ZERO, walk.anchors[i - 1].distance_to(walk.anchors[i]), clearance])
		_finish()
		return
	_check(not walk.glove.visible and not walk.snags[0].is_in_group("interactables"), "the glove waits for the thread")
	_check(walk.window.interact(), "she latches the window")
	await _frames(3)
	_check(walk.snags[0].is_in_group("interactables"), "the first snag appears")
	for i in 3:
		if i == 1:
			_check(walk.snow_branch.knock(), "snow drops from the second snag")
		_check(walk.snags[i].interact(), "she winds snag %d" % (i + 1))
	_check(walk.wound == 3 and Game.errands.is_known(RedThread.ID), "partial walk enters the journal")
	_check(RunSave.save_now(), "partial thread walk saves")
	await _reload()
	walk = _walk()
	_check(walk != null and walk.wound == 3 and walk.snags[3].is_in_group("interactables"), "three snags stay wound after loading")
	for i in range(3, 5):
		_check(walk.snags[i].interact(), "she winds snag %d" % (i + 1))
	_check(walk.initials.interact(), "she brushes snow from their initials")
	await _frames(2)
	_check(walk.glove.visible and walk.glove.is_in_group("interactables"), "the glove is uncovered")
	Game.player.global_position = walk.glove.global_position + Vector3(0.6, 0, 0)
	await _frames(4)
	_check(Game.player.pick_up(walk.glove), "she takes Mathilda's glove")
	_check(Game.errands.is_done(RedThread.ID) and Game.journal.any(func(entry: NoteEntry) -> bool: return entry.title == "The thread"), "the errand adds its keepsake once")
	_check(not NoteCatalog.thread().lake_counts and not NoteCatalog.thread().counts, "keepsake does not count as a lake or trail page")
	_check(RunSave.save_now(), "completed thread walk saves")
	await _reload()
	walk = _walk()
	_check(Game.errands.is_done(RedThread.ID) and walk.wound == 5, "completed walk survives loading")
	_check(Game.player.carrying != null and Game.player.carrying.item_id == RedThread.GLOVE, "the glove returns to her hands")
	_check(Game.journal.filter(func(entry: NoteEntry) -> bool: return entry.title == "The thread").size() == 1, "the keepsake is not duplicated")
	_check(Game.player.drop_carried(), "she can set the glove down in the snow")
	var drop_at := walk.glove.global_position
	_check(RunSave.save_now(), "the dropped glove saves")
	await _reload()
	walk = _walk()
	_check(Game.player.carrying == null and walk.glove.global_position.distance_to(drop_at) < 0.2, "the same glove remains where she dropped it")
	Game.player.global_position = walk.glove.global_position + Vector3(0.6, 0, 0)
	await _frames(4)
	_check(Game.player.pick_up(walk.glove), "she recovers the dropped glove")
	if walk.camp_spot:
		Game.player.global_position = walk.camp_spot.global_position + Vector3(0.65, 0.0, 0.0)
		await _frames(5)
		_check(Game.player.place(walk.camp_spot), "she leaves the glove at Mathilda's camp")
		_check(walk.camp_spot.held.size() == 1 and walk.camp_spot.held[0].item_id == RedThread.GLOVE, "the glove is visible on the camp crate")
		_check(RunSave.save_now(), "camp glove placement saves")
		await _reload()
		walk = _walk()
		_check(walk.camp_spot.held.size() == 1 and Game.player.carrying == null, "camp placement survives loading")
	_finish()


func _views(walk: RedThread) -> void:
	var folder := ProjectSettings.globalize_path("res://build/mvp/thread")
	DirAccess.make_dir_recursive_absolute(folder)
	var camera := Camera3D.new()
	camera.fov = 72.0
	get_tree().root.add_child(camera)
	walk.window.interact()
	for child in _main.get_children():
		if child is CanvasLayer:
			child.visible = false
	await _frames(4)
	for i in 6:
		var toward := (walk.anchors[i + 1] - walk.anchors[i]).normalized()
		var near := walk.anchors[i] + toward * 2.8
		near = Game.trail.on_ground(near)
		camera.global_position = near + toward.cross(Vector3.UP).normalized() * (1.6 if i == 0 else 2.5) + Vector3.UP * 1.6
		camera.look_at(walk.anchors[i + 1] + Vector3.UP * 1.0)
		camera.current = true
		await _frames(4)
		await RenderingServer.frame_post_draw
		var path := folder.path_join("link_%d.png" % i)
		var image := get_viewport().get_texture().get_image()
		_check(image.save_png(path) == OK, "player-height view of link %d saved" % i)
		if i < 5:
			if i == 1:
				walk.snow_branch.knock()
			walk.snags[i].interact()
	camera.queue_free()


func _finish() -> void:
	print("THREAD %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
