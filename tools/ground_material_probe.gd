extends Node

# Verify the actual terrain and house bindings, including a normal lean play.
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.get_node("EditableLevel").set_meta("seed", 1701)
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ground := Game.trail.ground
	var chunks := ground.get_node("Chunks")
	var terrain := (chunks.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	_check(terrain != null, "real terrain uses a ShaderMaterial")
	if terrain != null:
		_check(terrain.shader.resource_path == "res://shaders/snow_ground.gdshader", "terrain uses the snow ground shader")
		for uniform: String in ["green_tex", "grass_tex", "mud_tex", "green_normal", "grass_normal", "mud_normal"]:
			var texture := terrain.get_shader_parameter(uniform) as Texture2D
			_check(texture != null and texture.get_width() == 1024 and texture.get_height() == 1024, "%s binds a valid 1K texture" % uniform)
		_check(terrain.get_shader_parameter("ground_textures") == true, "fetched ground texture path enabled")
		_check(terrain.get_shader_parameter("use_vertex_snow") == true, "terrain uses vertex snow weights")
		_check(terrain.get_shader_parameter("lean_graphics") == Game.lean_graphics, "material follows actual graphics mode")
		_check(terrain.get_shader_parameter("snow_default") == 1.0, "explicit snow default is one")
	var patch := Game.house.get_node_or_null("SnowPatch")
	_check(patch != null, "house retains its snow patch")
	if patch != null:
		var meshes := patch.find_children("*", "MeshInstance3D", true, false)
		_check(not meshes.is_empty(), "house snow patch has meshes")
		for node: Node in meshes:
			var mesh := node as MeshInstance3D
			var material := mesh.material_override as ShaderMaterial
			_check(material == ground.snow_material, "house patch retains ground.snow_material")
			if material != null:
				_check(material.get_shader_parameter("use_vertex_snow") == false and material.get_shader_parameter("snow_default") == 1.0, "house mesh without colors explicitly defaults to snow")
	_check(ground.build_msec < 3500, "ground build %d ms < 3500 ms" % ground.build_msec)
	if not OS.get_environment("GROUND_MATERIAL_SHOT").is_empty():
		await _capture(main, ground)
	print("GROUND MATERIAL PROBE: %s (%d failures)" % ["PASS" if _failed == 0 else "FAIL", _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _check(ok: bool, message: String) -> void:
	print("  %s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failed += 1


# Optional GPU smoke frame; headless assertions inspect bindings only. Run
# without --headless and set GROUND_MATERIAL_SHOT to a PNG destination.
func _capture(main: Node, ground: Ground) -> void:
	var at := Vector3.ZERO
	var found := false
	for x in range(int(Tune.WORLD_MIN_X) + 100, int(Tune.WORLD_MAX_X) - 100, 12):
		for z in range(int(Tune.WORLD_MIN_Z) + 100, int(Tune.WORLD_MAX_Z) - 100, 12):
			var s := ground.snow_at(float(x), float(z))
			if s > 0.35 and s < 0.65 and ground.slope_at(float(x), float(z)) < 25.0:
				at = Vector3(float(x), ground.height_at(float(x), float(z)), float(z))
				found = true
				break
		if found:
			break
	_check(found, "GPU capture found a thaw surface")
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.global_position = at + Vector3(0.0, 9.0, 9.0)
	camera.look_at(at)
	camera.far = 160.0
	camera.make_current()
	# Inspection light only, to reveal grain at this edge under the night sky.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65.0, -30.0, 0.0)
	light.light_energy = 1.5
	main.add_child(light)
	for layer: Node in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(OS.get_environment("GROUND_MATERIAL_SHOT"))
	_check(result == OK, "GPU frame saved with actual %s shader branch" % ("lean" if Game.lean_graphics else "full"))
