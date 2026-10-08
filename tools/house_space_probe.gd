extends Node

# Check the current editable house, not just procedural constants.
var _failed := false


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	print("House space: ", message, " = ", ok)
	if not ok:
		_failed = true
		push_error(message)


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	var house := Game.house
	var player := Game.player
	Game.set_phase(Game.Phase.PLAYING)
	player.set_process(false)
	player.set_physics_process(false)
	_check(int(house.get_meta("layout_revision", 0)) == House.LAYOUT_REVISION, "current layout revision")
	var front := house.doors["front"] as HouseDoor
	_check(front.jam_shoves == 2, "the front door starts swollen shut")
	var shoves := 0
	while not front.is_open and shoves < 5:
		front.interact()
		shoves += 1
	_check(front.is_open and shoves == 2, "it takes exactly two shoves to free it (%d)" % shoves)
	front.interact()
	_check(not front.is_open and front.jam_shoves == 0, "once freed it opens and closes like any other door")
	var stove := house.find_child("StoveChore", true, false) as Chore
	var window := house.find_child("WindowChore", true, false) as Chore
	_check(stove != null and window != null and not stove.done and not window.done, "the stove and window chores start undone")
	var hearth := house.find_child("HearthLight", true, false) as OmniLight3D
	_check(hearth != null and hearth.light_energy == 0.0, "the hearth starts cold")
	stove.interact()
	_check(stove.done and not stove.is_in_group("interactables"), "lighting the stove uses it up")
	var grate := house.find_child("GratePage", true, false) as FieldNote
	_check(grate != null and grate.entry.title == "the grate" and not grate.entry.counts, "the grate's page is in the house")
	var camp := get_tree().get_first_node_in_group("camp") as Camp
	_check(camp != null and not camp.tent_mended, "the camp's windward guy-line starts loose too")
	_check(player.global_position.distance_to(house.spawn_point()) < 0.2, "default spawn follows expanded bedroom")
	_check(house.room_at(house.to_global(Vector3(-5.5, 0.9, 3.0))) == "bedroom", "expanded bedroom room volume")
	_check(house.room_at(house.to_global(Vector3(5.5, 0.9, -3.0))) == "living", "expanded living room volume")
	for id in ["ArmChair_01", "round_wooden_table_02", "throw_pillows_01"]:
		var prop := house.find_child(id, true, false) as Node3D
		_check(prop != null and prop.get_child_count() > 0 and prop.scale.is_equal_approx(Vector3.ONE), "imported human-scale " + id)
	var body_shape := player.get_child(0) as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body_shape.shape
	query.transform = Transform3D(Basis(), player.global_position + body_shape.position)
	query.collision_mask = Tune.LAYER_WORLD
	query.exclude = [player.get_rid()]
	_check(player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "spawn capsule clear of furniture and walls")
	var passages := {
		"bedroom": [Vector3(-2.8, 0.08, 2.8), Vector3(2.6, 0.0, 0.0)],
		"living": [Vector3(0.15, 0.08, 2.8), Vector3(2.7, 0.0, 0.0)],
		"backhall": [Vector3(0.0, 0.08, 1.95), Vector3(0.0, 0.0, -2.7)],
		"front": [Vector3(0.0, 0.08, 3.55), Vector3(0.0, 0.0, 2.0)],
		"janitor": [Vector3(-5.5, House.CELLAR_FLOOR + 0.08, House.JANITOR_DOOR_Z), Vector3(-1.6, 0.0, 0.0)],
	}
	for key in passages:
		var door := house.doors[key] as HouseDoor
		var path: Array = passages[key]
		player.global_position = house.to_global(path[0])
		player.velocity = Vector3.ZERO
		# The front door is swollen shut: a human shoves it more than once.
		for attempt in (door.jam_shoves + 1):
			_check(door.interact(), key + " door opens from approach")
			if door.is_open:
				break
		for frame in 100:
			await get_tree().physics_frame
		var hit := KinematicCollision3D.new()
		var blocked := player.test_move(player.global_transform, house.global_basis * (path[1] as Vector3), hit)
		if blocked:
			print("Blocked by ", hit.get_collider().get_path(), "; leaf angle ", door._motion.angle, "; hinge blocked ", door._motion.blocked)
		_check(not blocked, key + " full capsule fits open doorway")
	player.global_position = house.to_global(Vector3(1.0, 0.08, -1.4))
	_check(not player.test_move(player.global_transform, house.global_basis * Vector3(2.0, 0.0, 0.0)), "living to back hall open passage")
	# Traverse the real risers with the player's capsule, gravity and floor snap.
	player.global_position = house.to_global(Vector3(1.4, 0.08, House.STAIR_Z))
	player.velocity = Vector3.ZERO
	for frame in 300:
		await get_tree().physics_frame
		var along := house.global_basis * Vector3(-1.4, 0.0, 0.0)
		player.velocity.x = along.x
		player.velocity.z = along.z
		player.velocity.y -= Tune.GRAVITY * get_physics_process_delta_time()
		player.move_and_slide()
	var cellar_at := house.to_local(player.global_position)
	_check(cellar_at.x < House.STAIR_BOTTOM_X and absf(cellar_at.y - House.CELLAR_FLOOR) < 0.15, "stair traversal reaches cellar landing")
	print("HOUSE SPACE ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)
