extends Node

# Shots of Mathilda's camp, for judging it by eye: her arrival view, close on
# the fire, the tent door with the lantern, her things on the crate and stool,
# and the camp from the route. Runs her chapter (RUN_MATHILDA is set here).
# Needs a window. Set RUN_GRAPHICS=full|lean; RUN_VIEW_TAG names the set.
#   godot-mono --path . tools/camp_view.tscn
# Shots land in build/camp/<tag>_<view>.png.

const OUT := "res://build/camp/"


func _ready() -> void:
	OS.set_environment("RUN_MATHILDA", "1")
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	for i in 20:
		await get_tree().process_frame
	var camp := get_tree().get_first_node_in_group("camp") as Camp
	if camp == null or not camp.is_built:
		print("CAMP VIEW: no camp")
		get_tree().quit(1)
		return
	Game.player.visual.hide()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for id in ["cups", "gloves", "note"]:
		var thing := camp.get_node_or_null("Story_" + id) as Node3D
		var meshes := thing.find_children("*", "MeshInstance3D", true, false).size() if thing else 0
		print("%s: %s meshes at %s (spot %s)" % [id, meshes, thing.global_position if thing else "-", camp.spots.get(id)])
	var tag := OS.get_environment("RUN_VIEW_TAG")
	if tag == "":
		tag = "lean" if Game.lean_graphics else "full"
	var camera := Camera3D.new()
	camera.fov = 62.0
	get_tree().root.add_child(camera)
	camera.current = true
	var fire := camp.fire_light.global_position - Vector3.UP * 0.5
	var tent := camp.get_node("Tent") as Node3D
	var x := tent.global_basis.x
	var z := tent.global_basis.z
	var shots := [
		["arrival", fire - x * 2.6 + z * 0.4 + Vector3.UP * 1.6, (fire + tent.global_position) * 0.5 + Vector3.UP * 0.5],
		["fire", fire - x * 1.2 - z * 0.9 + Vector3.UP * 1.05, fire + Vector3.UP * 0.25],
		["door", fire + x * 0.4 - z * 1.6 + Vector3.UP * 1.3, tent.global_position - x * 1.1 + Vector3.UP * 0.5],
		["things", camp.spots["cups"] - x * 1.0 - z * 0.5 + Vector3.UP * 0.9, camp.spots["cups"]],
		["route", fire - x * 6.0 - z * 3.5 + Vector3.UP * 1.7, fire + x * 1.5 + Vector3.UP * 0.4],
	]
	for shot: Array in shots:
		camera.look_at_from_position(shot[1], shot[2])
		for i in 24:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [tag, shot[0]]))
		print("saved %s_%s" % [tag, shot[0]])
	get_tree().quit()
