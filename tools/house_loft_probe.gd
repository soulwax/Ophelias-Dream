extends Node
var failed := false

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	print("LOFT ",description," = ",value)
	if not value:
		failed = true
		push_error(description)

func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	Game.set_phase(Game.Phase.PLAYING)
	var house: House = Game.house
	var player: Player = Game.player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	check(house.get_node_or_null("Domestic/Loft16Room")!=null,"full source room instanced")
	check(house.room_at(house.to_global(Vector3(8,1,2.5)))=="loft","registered upstairs room")
	check(house.contains(house.to_global(Vector3(8,1,2.5))),"weather shelter includes loft")
	check(house.get_node("Authoring/RoomTone").get_child_count()==2,"room reverb includes both floor plates")
	var hit := house.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(house.to_global(Vector3(8,2,2.5)),house.to_global(Vector3(8,-1,2.5)),Tune.LAYER_WORLD))
	check(not hit.is_empty(),"loft has physical floor")
	if not hit.is_empty(): print("LOFT floor_y=",house.to_local(hit.position).y," collider=",hit.collider.get_path())
	player.global_position = house.to_global(Vector3(5,.08,2.5))
	player.velocity = Vector3.ZERO
	var obstruction := KinematicCollision3D.new()
	if player.test_move(player.global_transform,house.global_basis*Vector3(3,0,0),obstruction):
		print("LOFT obstruction=",obstruction.get_collider().get_path()," at=",house.to_local(obstruction.get_position()))
	check(not player.test_move(player.global_transform,house.global_basis*Vector3(3,0,0)),"capsule clears host portal and imported room entrance")
	for frame in range(130):
		await get_tree().physics_frame
		var direction := house.global_basis*Vector3(1.5,0,0)
		player.velocity.x = direction.x
		player.velocity.z = direction.z
		player.velocity.y -= Tune.GRAVITY*get_physics_process_delta_time()
		player.move_and_slide()
	var position := house.to_local(player.global_position)
	print("LOFT walked_to=",position)
	check(position.x>7.7 and absf(position.y)<.15,"actual controller enters on aligned floor")
	if OS.get_cmdline_user_args().has("--capture"):
		main.process_mode = Node.PROCESS_MODE_DISABLED
		player.visual.hide()
		for child in main.get_children():
			if child is CanvasLayer: child.hide()
		for view in [
			["room",Vector3(7.4,1.65,2.4),Vector3(10.5,1.3,.3)],
			["junction",Vector3(3.0,1.65,2.5),Vector3(9.8,1.3,2.3)],
			["artwork",Vector3(8,1.65,1.2),Vector3(9.5,1.9,3.8)],
			["exterior",Vector3(16,6,10),Vector3(6,2,0)]
		]:
			player.camera.global_position = house.to_global(view[1])
			player.camera.look_at(house.to_global(view[2]),Vector3.UP)
			player.camera.make_current()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png("res://build/loft-"+view[0]+".png")==OK,"rendered "+view[0])
	main.queue_free()
	await get_tree().process_frame
	print("LOFT ","FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
