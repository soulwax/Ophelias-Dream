extends Node

# Overview shots of the generated world, for judging the land by eye: near the
# route, high over the story, at eye level, a far aerial over the whole world
# and close on a thaw band. Prints the frame rate at the eye-level view after a
# warm-up. Needs a window. Set RUN_GRAPHICS=full|lean; RUN_VIEW_TAG names the set.
#   godot-mono --path . tools/terrain_view.tscn
# Shots land in build/terrain/<tag>_<view>.png.

const OUT := "res://build/terrain/"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	for i in 10:
		await get_tree().process_frame
	Game.set_phase(Game.Phase.PLAYING)
	var trail := Game.trail
	var ground := trail.ground
	var tag := OS.get_environment("RUN_VIEW_TAG")
	if tag == "":
		tag = "lean" if Game.lean_graphics else "full"
	var camera := Camera3D.new()
	camera.far = 2400.0
	get_tree().root.add_child(camera)
	camera.current = true
	var start := trail.player_start_offset
	var along := func(metres: float) -> Vector3: return trail.position_at(start + metres)
	var thaw := _thaw_spot(ground)
	var green := _spot(ground, 0.0, 0.08)
	var centre := ground.story_centre
	var shots := [
		["near", along.call(40.0) + Vector3(0, 6, 0), along.call(80.0)],
		["high", along.call(80.0) + Vector3(60, 90, 70), along.call(130.0)],
		["eye", along.call(100.0) + Vector3(0, 1.8, 0), along.call(140.0) + Vector3(0, 1.5, 0)],
		["far", centre + Vector3(0, 650, 520), centre + Vector3(0, 0, -60)],
		["thaw", thaw + Vector3(-25, 12, 30), thaw],
		["green", green + Vector3(0, 1.8, 0), green + Vector3(30, 1.0, -30)],
	]
	for shot: Array in shots:
		var target: Vector3 = shot[2]
		target.y = ground.height_at(target.x, target.z) + (target.y if shot[0] in ["eye", "green"] else 0.0)
		var from: Vector3 = shot[1]
		from.y += ground.height_at(from.x, from.z) if shot[0] != "far" else 0.0
		camera.look_at_from_position(from, target)
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if shot[0] == "eye":
			var frames := 0
			var began := Time.get_ticks_usec()
			while frames < 90:
				await get_tree().process_frame
				frames += 1
			var fps := float(frames) / (float(Time.get_ticks_usec() - began) / 1.0e6)
			print("%s eye-level: %.1f fps" % [tag, fps])
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [tag, shot[0]]))
		print("saved %s_%s" % [tag, shot[0]])
	get_tree().quit()


# A point on a snow-to-green edge, out from the story toward the north-east.
func _thaw_spot(ground: Ground) -> Vector3:
	return _spot(ground, 0.4, 0.6)


# A gentle point whose snow weight lies in [lo, hi], searched outward.
func _spot(ground: Ground, lo: float, hi: float) -> Vector3:
	for ring in range(250, 480, 10):
		for step in 36:
			var angle := -PI * 0.25 + TAU * float(step) / 36.0
			var x := ground.story_centre.x + cos(angle) * float(ring)
			var z := ground.story_centre.z + sin(angle) * float(ring)
			if x < Tune.WORLD_MIN_X + Tune.RING_WIDTH or x > Tune.WORLD_MAX_X - Tune.RING_WIDTH or z < Tune.WORLD_MIN_Z + Tune.RING_WIDTH or z > Tune.WORLD_MAX_Z - Tune.RING_WIDTH:
				continue
			var s := ground.snow_at(x, z)
			if s >= lo and s <= hi and ground.slope_at(x, z) < 20.0:
				return Vector3(x, 0.0, z)
	return ground.story_centre + Vector3(300, 0, -300)
