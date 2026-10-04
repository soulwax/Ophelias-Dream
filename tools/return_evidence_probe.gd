extends Node

# Render the saved level's doorway clue from a plausible standing viewpoint.
# RUN_GRAPHICS=lean godot --path . tools/return_evidence_probe.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	Game.set_phase(Game.Phase.PLAYING)
	var player: Player = Game.player
	var house: House = Game.house
	var mark := house.doorstep() + house.global_basis.x.normalized() * 0.46
	mark.y = Game.trail.ground.height_at(mark.x, mark.z)
	player.footprints.stamp(mark, house.global_rotation.y + 0.5, false, false, Footprints.Mark.SOLE, true)
	player.visual.visible = false
	var camera := player.camera
	camera.global_position = mark + house.global_basis.z.normalized() * 2.0 + Vector3.UP * 1.6
	camera.look_at(mark + Vector3.UP * 0.08, Vector3.UP)
	camera.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://build/validation/door_mark.png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("Door mark close view: ", path, " (", error_string(error), ")")
	player.global_position = house.doorstep() + house.global_basis.z.normalized() * 1.15
	player.global_position.y = Game.trail.ground.height_at(player.global_position.x, player.global_position.z)
	player.visual.visible = true
	camera.global_position = house.doorstep() + house.global_basis.z.normalized() * 3.2 + Vector3.UP * 1.8
	camera.look_at(mark + Vector3.UP * 0.15, Vector3.UP)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var player_path := ProjectSettings.globalize_path("res://build/validation/door_mark_player.png")
	var player_error := get_viewport().get_texture().get_image().save_png(player_path)
	print("Door mark player view: ", player_path, " (", error_string(player_error), ")")
	get_tree().quit(0 if error == OK and player_error == OK else 1)
