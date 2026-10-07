extends Node
# Throwaway QA: shots of Ophelia's three house chores. Not committed.
# godot-mono --path . tools/_chores_view.tscn

const OUT := "res://build/chores/"

func _ready() -> void:
	_run.call_deferred()

func _shot(camera: Camera3D, from: Vector3, at: Vector3, name: String) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)

func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	for i in 20:
		await get_tree().process_frame
	Game.set_phase(Game.Phase.PLAYING)
	Game.player.visual.hide()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var house := Game.house
	var camera := Camera3D.new()
	camera.fov = 65.0
	get_tree().root.add_child(camera)
	camera.current = true

	var front := house.doors["front"] as HouseDoor
	await _shot(camera, house.to_global(Vector3(0.0, 1.5, 2.2)), house.to_global(Vector3(0.0, 1.2, 3.6)), "01_door_jammed")
	front.interact()
	front.interact()
	for i in 20:
		await get_tree().process_frame
	await _shot(camera, house.to_global(Vector3(0.0, 1.5, 2.2)), house.to_global(Vector3(0.0, 1.2, 3.6)), "02_door_open")

	await _shot(camera, house.to_global(Vector3(3.6, 1.3, -0.4)), house.to_global(Vector3(5.0, 0.7, -1.3)), "03_stove_cold")
	var stove := house.find_child("StoveChore", true, false) as Chore
	stove.interact()
	for i in 90:
		await get_tree().process_frame
	await _shot(camera, house.to_global(Vector3(3.6, 1.3, -0.4)), house.to_global(Vector3(5.0, 0.7, -1.3)), "04_stove_lit")

	await _shot(camera, house.to_global(Vector3(3.6, 1.35, -3.6)), house.to_global(Vector3(5.1, 0.78, -2.35)), "05_grate_note")
	await _shot(camera, house.to_global(Vector3(3.9, 1.7, -2.6)), house.to_global(Vector3(5.75, 1.5, -3.2)), "06_window")

	get_tree().quit()
