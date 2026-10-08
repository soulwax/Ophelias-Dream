extends Node

var failed := false

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	print("DOMESTIC ",description," = ",value)
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
	check(house.get_node_or_null("Domestic")!=null,"new fixtures survive old snapshot migration")
	for id in ["modern_ceiling_lamp_01","painted_wooden_bench","modern_wooden_cabinet"]:
		var replacement := house.find_child(id,true,false) as Node3D
		check(replacement!=null and replacement.scale.is_equal_approx(Vector3.ONE),"real normal-scale replacement "+id)
	for id in ["stove","cooker","bathroom","rug","cabinet","curtain","shelves","bed_rug","side_table","wood_lantern"]:
		var asset := house.find_child("Imported_"+id,true,false) as Node3D
		check(asset!=null and asset.get_child_count()>0,"curated visual "+id)
	check(house.room_at(house.to_global(Vector3(-5.25,.9,-2.4)))=="bathroom","bathroom room volume")
	var bath := house.find_child("Imported_bathroom",true,false) as Node3D
	if bath:
		var dimensions: Vector3 = bath.get_meta("dimensions_m")
		check(bath.position.x-dimensions.x*.5> -6.18 and bath.position.x+dimensions.x*.5< -4.16,"bathroom assembly fits between actual wall faces")
	player.global_position = house.to_global(Vector3(-5.25,.08,-.4))
	player.velocity = Vector3.ZERO
	var door := house.doors["bathroom"] as HouseDoor
	check(door.interact(),"bathroom door opens toward free room space")
	for frame in range(100): await get_tree().physics_frame
	var hit := KinematicCollision3D.new()
	var blocked := player.test_move(player.global_transform,house.global_basis*Vector3(0,0,-1.7),hit)
	if blocked: print("DOMESTIC blocked by ",hit.get_collider().get_path()," angle=",door._motion.angle)
	check(not blocked,"full player capsule fits new bathroom doorway")
	for point in [Vector3(-5.25,.08,-2.3),Vector3(2.5,.08,-1.4),Vector3(3.25,.08,-3.7),Vector3(4.1,.08,-3.55)]:
		var shape := player.get_child(0) as CollisionShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = Transform3D(house.global_basis,house.to_global(point)+shape.position)
		query.collision_mask = Tune.LAYER_WORLD
		query.exclude = [player.get_rid()]
		check(player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"fixture/circulation clearance "+str(point))
	if OS.get_cmdline_user_args().has("--capture"):
		# Use the existing player camera's sphere sweep, without modifying its rig.
		for point in [Vector3(-5.25,1.5,-2.3),Vector3(3.6,1.5,-3.6),Vector3(3,1.5,.2),Vector3(-2.8,1.5,2.8)]:
			for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
				var length := player._arm_free(house.to_global(point),house.global_basis*direction,1.75)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = player.spring_arm.shape
				query.transform = Transform3D(Basis(),house.to_global(point)+house.global_basis*direction*length)
				query.collision_mask = Tune.LAYER_WORLD
				query.exclude = [player.get_rid()]
				check(player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"camera sphere clear "+str(point)+" "+str(direction))
		await _capture(main,house,player)
	print("HOUSE DOMESTIC ","FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

func _capture(main: Node, house: House, player: Player) -> void:
	main.process_mode = Node.PROCESS_MODE_DISABLED
	player.visual.hide()
	for child in main.get_children():
		if child is CanvasLayer: child.hide()
	for hud in get_tree().get_nodes_in_group("hud"): hud.hide()
	var camera := player.camera
	for view in [
		["living",Vector3(2.1,1.6,3.0),Vector3(5.4,1,-1.2)],
		["sitting",Vector3(2.15,1.6,.35),Vector3(4.7,1.0,3.2)],
		["kitchen",Vector3(2.1,1.6,-.7),Vector3(4.6,1.1,-4.3)],
		["bathroom",Vector3(-5.25,1.55,-1.75),Vector3(-5.25,1.25,-4.0)],
		["bedroom",Vector3(-1.95,1.6,2.7),Vector3(-4.3,1.1,1.3)],
		["entry",Vector3(.65,1.6,2.1),Vector3(-.8,.9,4.05)]
	]:
		camera.global_position = house.to_global(view[1])
		camera.look_at(house.to_global(view[2]),Vector3.UP)
		camera.make_current()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://build/house-batch1-"+view[0]+".png")
		check(error==OK,"rendered "+view[0])
