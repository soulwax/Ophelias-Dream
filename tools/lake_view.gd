extends Node

# Shots of the end of Ophelia's walk: the lookout's lanterns seen from the
# field (they should read as headlights), the lookout close, the posts leading
# on, the frozen lake from its shore, and the old hole with the prints.
# Needs a window. RUN_GRAPHICS=full|lean; RUN_VIEW_TAG names the set.
#   godot-mono --path . tools/lake_view.tscn
# Shots land in build/lake/<tag>_<view>.png.

const OUT := "res://build/lake/"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	for i in 20:
		await get_tree().process_frame
	var lake := get_tree().get_first_node_in_group("lake") as Lake
	var trail := Game.trail
	if lake == null or not lake.is_built or trail == null:
		print("LAKE VIEW: nothing built")
		get_tree().quit(1)
		return
	Game.set_phase(Game.Phase.PLAYING)
	Game.player.visual.hide()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var tag := OS.get_environment("RUN_VIEW_TAG")
	if tag == "":
		tag = "lean" if Game.lean_graphics else "full"
	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.far = 1500.0
	get_tree().root.add_child(camera)
	camera.current = true
	var eye := Vector3.UP * 1.6
	var at := func(offset: float) -> Vector3: return trail.on_ground(trail.position_at(offset))
	var lookout := trail.on_ground(trail.exit_point)
	var shore: Vector3 = at.call(trail.lake_offset - Tune.LAKE_RADIUS - 6.0)
	var shots := [
		["lights_far", at.call(trail.exit_offset - 45.0) + eye, lookout + Vector3.UP * 2.5],
		["lookout", at.call(trail.exit_offset - 10.0) + eye, lookout + Vector3.UP * 2.0],
		["posts", at.call(trail.exit_offset + 4.0) + eye, at.call(trail.exit_offset + 45.0) + Vector3.UP * 0.8],
		["shore", shore + eye, trail.on_ground(trail.lake_point)],
		["hole", trail.on_ground(trail.lake_hole) + (shore - trail.lake_hole).normalized() * 7.0 + Vector3.UP * 2.2, trail.on_ground(trail.lake_hole)],
	]
	for shot: Array in shots:
		camera.look_at_from_position(shot[1], shot[2])
		# Keep her out of the frame: she shows herself when no camera is in her.
		Game.player.global_position = trail.on_ground(trail.position_at(trail.player_start_offset)) + Vector3.UP * 0.2
		for i in 24:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [tag, shot[0]]))
		print("saved %s_%s" % [tag, shot[0]])
	get_tree().quit()
