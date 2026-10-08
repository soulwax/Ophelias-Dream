extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1000,800)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("303e49")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = .6
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_energy = 1.0
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	for id in ["bathroom","stove","rug","curtain"]:
		var scene: PackedScene = load("res://assets/derived/requested_house/"+id+".scn")
		var item := scene.instantiate() as Node3D
		world.add_child(item)
		var size: Vector3 = item.get_meta("dimensions_m")
		var span := maxf(size.x,maxf(size.y,size.z))
		camera.position = Vector3(span*1.05,span*.95,span*1.5)
		camera.look_at(Vector3(0,size.y*.45,0))
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/asset-"+id+".png")
		item.queue_free()
		await process_frame
	quit()
