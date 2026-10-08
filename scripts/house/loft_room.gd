class_name HouseLoftRoom
extends RefCounted
const RECT := Rect2(6.3,-2.1,6.0,6.0)
const VOLUME := AABB(Vector3(6.3,-.3,-2.1),Vector3(6,3.65,6))
const SCENE := "res://assets/derived/requested_house/loft_room.scn"

static func available() -> bool:
	return ResourceLoader.exists(SCENE)

static func build(house: House, parent: Node3D) -> void:
	if not available(): return
	var room := (load(SCENE) as PackedScene).instantiate() as Node3D
	room.name = "Loft16Room"
	room.position = Vector3(9.3,0,.9)
	room.rotation.y = PI
	parent.add_child(room)
	for child in room.get_children():
		if not child is MeshInstance3D: continue
		# Foliage cards and the painting are visual objects, not solid obstacles.
		if str(child.name).begins_with("Plane_") and child.name in ["Plane_009","Plane_010","Plane_011","Plane_012","Plane_013","Plane_014","Plane_015","Plane_016","Plane_017","Plane_018","Plane_019","Plane_020"]:
			continue
		var body := StaticBody3D.new()
		body.name = str(child.name)+"Body"
		body.transform = child.transform
		body.collision_layer = Tune.LAYER_WORLD
		body.collision_mask = 0
		body.set_meta("surface","wood")
		var shape := CollisionShape3D.new()
		var mesh_shape: ConcavePolygonShape3D = child.mesh.create_trimesh_shape()
		mesh_shape.backface_collision = true
		shape.shape = mesh_shape
		body.add_child(shape)
		room.add_child(body)
	HouseKit.solid(parent,"LoftThreshold",Vector3(6.3,-.06,2.5),Vector3(.55,.12,2.0),house._plank_floor)
	HouseKit.solid(parent,"LoftFoundation",Vector3(9.3,-.29,.9),Vector3(6,.35,6),house._stone)
	HouseKit.solid(parent,"LoftRoofCap",Vector3(9.3,3.43,.9),Vector3(6.3,.18,6.3),house._plank_out)
	house._keep_light("loft",HouseKit.light(parent,"LoftWarmLight",Vector3(9.8,2.7,1.2),Color("ffe2c5"),1.1,6.5))
	house._keep_light("loft",HouseKit.light(parent,"LoftWindowFill",Vector3(7.4,2.3,1),Color("c3d4de"),.25,4))
	# Clear the host room's approach: put its seating against the front wall.
	var sofa := house.get_node_or_null("Furniture/sofa_02") as Node3D
	if sofa:
		sofa.position = Vector3(4.35,0,4.25)
		sofa.rotation.y = PI
	var pillows := house.get_node_or_null("Furniture/throw_pillows_01") as Node3D
	if pillows:
		pillows.position = Vector3(4.35,.42,4.25)
		pillows.rotation.y = PI
	var furniture := house.get_node_or_null("Furniture")
	if furniture:
		for body in furniture.get_children():
			if body is StaticBody3D and body.position.distance_to(Vector3(5.5,.4,2.6))<.05:
				body.position = Vector3(4.35,.4,4.25)
				var box := body.get_child(0) as CollisionShape3D
				(box.shape as BoxShape3D).size = Vector3(1.85,.8,.85)
	# A second original painting gives the bedroom a connection to the modern studio.
	var path := "res://assets/derived/requested_house/loft_painting.scn"
	if ResourceLoader.exists(path):
		var art := (load(path) as PackedScene).instantiate() as Node3D
		art.name = "BedroomLoftPainting"
		art.position = Vector3(-4.9,2.65,.68)
		art.scale = Vector3.ONE*.5
		parent.add_child(art)
