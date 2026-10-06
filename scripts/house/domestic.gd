class_name HouseDomestic
extends RefCounted
## Curated owner-supplied furniture; simple collision stays independent of visual detail.

const BATHROOM := Rect2(-6.3,-4.9,2.2,3.4)

static func visual(parent: Node3D, id: String, at: Vector3, yaw: float = 0) -> Node3D:
	var path := "res://assets/derived/requested_house/"+id+".scn"
	if not ResourceLoader.exists(path): return null
	var scene := load(path) as PackedScene
	if scene == null: return null
	var node := scene.instantiate() as Node3D
	node.name = "Imported_"+id
	node.position = at
	node.rotation.y = deg_to_rad(yaw)
	parent.add_child(node)
	return node

static func build(house: House) -> void:
	var root := Node3D.new()
	root.name = "Domestic"
	house.add_child(root)
	var birch := HouseKit.paint(Color("c4b48f"),.85)
	var cream := HouseKit.paint(Color("ded5bf"),.9)
	var dark := HouseKit.paint(Color("292d2e"),.65)
	HouseKit.wall(root,"BathroomEast",Vector2(-4.1,-4.9),Vector2(-4.1,-1.5),0,House.CEILING,House.PARTITION,house._plaster)
	HouseKit.wall(root,"BathroomSouth",Vector2(-6.24,-1.5),Vector2(-4.1,-1.5),0,House.CEILING,House.PARTITION,house._plaster,[{"at":.99,"width":House.DOOR_WIDTH,"height":House.DOOR_HEIGHT}])
	house.doors["bathroom"] = HouseDoor.make(root,"BathroomDoor",Vector3(-5.25,0,-1.5),0,Vector3(House.DOOR_WIDTH-.06,House.DOOR_HEIGHT-.02,.045),"plank",house._timber,-1,95,"Bathroom door")
	var tile := HouseKit.surface(HouseKit.scan("floor_tiles_08",Color("d1d0c2"),.7),"stone")
	HouseKit.solid(root,"BathroomTiles",Vector3(-5.20,.009,-3.2),Vector3(1.96,.018,3.2),tile)
	if visual(root,"bathroom",Vector3(-5.19,.025,-3.92)) == null:
		HouseKit.solid(root,"LaundryFallback",Vector3(-5.9,.48,-4.15),Vector3(.6,.96,.6),cream)
		HouseKit.solid(root,"VanityFallback",Vector3(-4.7,.45,-4.1),Vector3(.6,.9,.6),birch)
	HouseKit.blocker(root,"BathroomFixtureBody",Vector3(-5.19,.5,-3.92),Vector3(1.94,1,1.1))
	HouseKit.solid(root,"ToiletTank",Vector3(-6.0,.65,-3.05),Vector3(.32,.8,.48),cream)
	var bowl := MeshInstance3D.new()
	var bowl_shape := SphereMesh.new()
	bowl_shape.radius = .24
	bowl_shape.height = .4
	bowl.mesh = bowl_shape
	bowl.material_override = cream
	bowl.position = Vector3(-5.92,.3,-3.05)
	root.add_child(bowl)
	var seat := MeshInstance3D.new()
	var seat_shape := TorusMesh.new()
	seat_shape.inner_radius = .14
	seat_shape.outer_radius = .24
	seat.mesh = seat_shape
	seat.material_override = cream
	seat.position = Vector3(-5.92,.49,-3.05)
	seat.scale = Vector3(1,.22,1)
	root.add_child(seat)
	HouseKit.blocker(root,"ToiletBody",Vector3(-5.92,.3,-3.05),Vector3(.48,.6,.48))
	HouseKit.solid(root,"CompactVanity",Vector3(-4.52,.42,-3.05),Vector3(.42,.84,.4),birch)
	HouseKit.solid(root,"BasinRim",Vector3(-4.52,.87,-3.05),Vector3(.47,.08,.43),cream)
	HouseKit.box(root,"BasinInset",Vector3(-4.52,.914,-3.05),Vector3(.31,.008,.29),HouseKit.paint(Color("777c78"),.4))
	HouseKit.box(root,"BasinTap",Vector3(-4.32,1.02,-3.05),Vector3(.04,.25,.04),dark)
	HouseKit.box(root,"BathroomMirror",Vector3(-4.27,1.5,-3.05),Vector3(.016,.7,.45),HouseKit.paint(Color("8d9b9d"),.12,.65))
	house._keep_light("bathroom",HouseKit.light(root,"BathroomLight",Vector3(-5.25,2.8,-2.4),Color("ffe3bf"),.5,3.4))
	HouseKit.solid(root,"SinkCabinet",Vector3(4.1,.44,-4.47),Vector3(1.1,.88,.64),birch)
	HouseKit.solid(root,"DrawerCabinet",Vector3(5.8,.44,-4.47),Vector3(.7,.88,.64),birch)
	for spec in [[4.1,1.14],[5.8,.74]]:
		HouseKit.solid(root,"Countertop",Vector3(spec[0],.92,-4.47),Vector3(spec[1],.08,.7),cream)
	if visual(root,"cooker",Vector3(5.04,0,-4.47)) == null:
		HouseKit.solid(root,"CookerFallback",Vector3(5.04,.45,-4.47),Vector3(.49,.9,.56),dark)
	HouseKit.blocker(root,"CookerBody",Vector3(5.04,.45,-4.47),Vector3(.49,.9,.56))
	HouseKit.box(root,"Sink",Vector3(4.1,.966,-4.47),Vector3(.6,.012,.42),dark)
	HouseKit.box(root,"Tap",Vector3(4.1,1.13,-4.72),Vector3(.045,.35,.045),dark)
	HouseKit.box(root,"TapSpout",Vector3(4.1,1.28,-4.60),Vector3(.045,.045,.23),dark)
	for x in [3.85,4.37,5.8]:
		HouseKit.box(root,"CabinetPull",Vector3(x,.72,-4.135),Vector3(.18,.025,.025),dark)
	# Recessed panels and a toe-kick make the original cabinet modules read as joinery.
	for spec in [[4.1,1.1],[5.8,.7]]:
		HouseKit.box(root,"ToeKick",Vector3(spec[0],.075,-4.145),Vector3(spec[1]-.08,.15,.015),dark)
		for offset in [-.25,.25] if spec[1]>1 else [0.0]:
			HouseKit.box(root,"CabinetPanel",Vector3(spec[0]+offset,.47,-4.139),Vector3(.44,.63,.018),cream)
	HouseKit.box(root,"FridgeDoorSeam",Vector3(2.5,.67,-4.082),Vector3(.64,.015,.018),dark)
	HouseKit.solid(root,"Fridge",Vector3(2.5,1,-4.44),Vector3(.7,2,.7),cream)
	HouseKit.box(root,"FridgeHandle",Vector3(2.76,1.1,-4.06),Vector3(.035,.45,.04),dark)
	HouseKit.solid(root,"SlateHearth",Vector3(5.4,.035,-1.2),Vector3(1.4,.07,1.5),house._stone)
	var stove := visual(root,"stove",Vector3(5.4,.07,-1.2),-90)
	if stove == null:
		HouseKit.solid(root,"StoveFallback",Vector3(5.4,.53,-1.2),Vector3(.65,.9,.55),dark)
	HouseKit.blocker(root,"StoveBody",Vector3(5.4,.6,-1.2),Vector3(.70,1.2,.76))
	var flue_center := Vector3(5.4,2.2,-1.2)
	var flue_height := 2.1
	if stove:
		var source_flue := stove.get_node_or_null("TUBERIA") as MeshInstance3D
		if source_flue:
			var bounds: AABB = stove.transform*source_flue.transform*source_flue.get_aabb()
			flue_center = bounds.get_center()
			flue_height = House.CEILING+.1-bounds.end.y
			flue_center.y = bounds.end.y+flue_height*.5
	HouseKit.box(root,"FlueExtension",flue_center,Vector3(.14,flue_height,.14),dark)
	house._keep_light("living",HouseKit.light(root,"HearthLight",Vector3(4.95,.58,-1.2),Color("ffba78"),.45,3.6))
	if visual(root,"cabinet",Vector3(-3.3,0,1.1)) != null:
		HouseKit.blocker(root,"WardrobeBody",Vector3(-3.3,.9,1.1),Vector3(1.2,1.8,.8))
	if visual(root,"shelves",Vector3(5.9,0,.6)) != null:
		HouseKit.blocker(root,"DisplayShelfBody",Vector3(5.9,.78,.6),Vector3(.37,1.56,1.08))
	# The new cooking run replaces the decorative cupboard in its footprint.
	var old_cabinet := house.get_node_or_null("Furniture/GothicCabinet_01")
	if old_cabinet:
		old_cabinet.get_parent().remove_child(old_cabinet)
		old_cabinet.queue_free()
	if visual(root,"rug",Vector3(4.45,.028,2.6),90) != null:
		var comfort := house.get_node_or_null("Authoring/Comfort")
		if comfort:
			for name in ["LivingRug","LivingRugBorder"]:
				var old := comfort.get_node_or_null(name) as GeometryInstance3D
				if old: old.hide()
	if visual(root,"curtain",Vector3(4.3,.8,4.43)) != null:
		var comfort := house.get_node_or_null("Authoring/Comfort")
		if comfort:
			for child in comfort.get_children():
				if child is GeometryInstance3D and str(child.name).begins_with("LinenCurtain") and child.position.z>4 and child.position.x>2:
					child.hide()
	HouseKit.solid(root,"BootBench",Vector3(-1.05,.42,4.05),Vector3(.45,.14,1),birch)
	for z in [3.7,4.1,4.45]:
		HouseKit.box(root,"CoatPeg",Vector3(-1.34,1.65,z),Vector3(.13,.04,.04),dark)
	HouseIdentity.apply(house,root)
	HouseLoftRoom.build(house,root)
