extends Node

# godot --headless --path . tools/note_access_probe.tscn
# Exercise note access against the actual house walls and terrain colliders.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	var player := Game.player
	var house := Game.house
	var bedroom_page := main.find_child("NightstandPage", true, false) as FieldNote
	if player == null or house == null or bedroom_page == null:
		push_error("Note access probe could not find scene objects")
		get_tree().quit(1)
		return
	Game.set_phase(Game.Phase.PLAYING)
	player.velocity = Vector3.ZERO
	var page_at := house.to_local(bedroom_page.global_position)
	var outside := house.to_global(Vector3(page_at.x, 0.0, House.UPSTAIRS.end.y + 1.3))
	player.global_position = Vector3(outside.x, Game.trail.ground.height_at(outside.x, outside.z) + 0.5, outside.z)
	await get_tree().physics_frame
	var exterior_blocked := player.nearby_note() != bedroom_page
	print("Exterior wall blocks bedroom note: ", exterior_blocked)
	var inside := house.to_global(Vector3(page_at.x + 0.9, 0.0, page_at.z))
	player.global_position = inside + Vector3.UP * 0.5
	await get_tree().physics_frame
	var interior_access := player.nearby_note() == bedroom_page
	print("Bedroom side can read note: ", interior_access)
	var outdoor_access := true
	for index in 5:
		var trail_page := main.find_child("FieldNote_%d" % index, true, false) as FieldNote
		if trail_page == null:
			outdoor_access = false
			break
		var accessible := false
		for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var trail_at: Vector3 = trail_page.global_position + direction * 1.2
			player.global_position = Vector3(
				trail_at.x, Game.trail.ground.height_at(trail_at.x, trail_at.z) + 0.08, trail_at.z)
			player.velocity = Vector3.ZERO
			player._glide = Vector3.ZERO
			await get_tree().physics_frame
			if player.nearby_note() == trail_page:
				accessible = true
				break
		print("Ground note %d remains readable: %s" % [index, accessible])
		outdoor_access = outdoor_access and accessible
	get_tree().quit(0 if exterior_blocked and interior_access and outdoor_access else 1)
