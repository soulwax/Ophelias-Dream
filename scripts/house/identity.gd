class_name HouseIdentity
extends RefCounted
## Architectural details and restrained textiles organise the asset collection.

static func apply(house: House, root: Node3D) -> void:
	var moss := HouseKit.paint(Color("64766c"),.92)
	var timber := HouseKit.paint(Color("6d5741"),.9)
	var flax := HouseKit.paint(Color("c8bea3"),.97)
	var rust := HouseKit.paint(Color("825448"),.98)
	HouseKit.box(root,"FrontWainscot",Vector3(3.9,.30,4.767),Vector3(4.55,.60,.018),moss)
	HouseKit.box(root,"FrontPanelCap",Vector3(3.9,.615,4.75),Vector3(4.55,.018,.025),timber)
	for span in [Vector2(.45,1.45),Vector2(3.55,4.65)] if HouseLoftRoom.available() else [Vector2(.45,4.65)]:
		HouseKit.box(root,"EastWainscot",Vector3(6.165,.30,(span.x+span.y)*.5),Vector3(.018,.6,span.y-span.x),moss)
	var slate := HouseKit.scan("white_plaster_rough_01",Color("555b58"),.7)
	HouseKit.box(root,"StoveSurround",Vector3(6.165,1.15,-1.2),Vector3(.018,2.3,1.35),slate)
	for child in root.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("CabinetPanel"):
			child.material_override = moss
	var pillows := house.get_node_or_null("Furniture/throw_pillows_01")
	if pillows:
		var index := 0
		for mesh in pillows.find_children("*","MeshInstance3D",true,false):
			mesh.material_override = rust if index%2==0 else flax
			index += 1
	var curtains := root.get_node_or_null("Imported_curtain") as Node3D
	if curtains:
		curtains.position.y = .62
		curtains.scale.y = 1.08
		curtains.position.z = 4.55
		curtains.scale.z = .7
		var panels := curtains.get_children()
		for i in range(panels.size()):
			var panel := panels[i] as MeshInstance3D
			if panel:
				panel.scale.x *= .7
				var bounds: AABB = panel.transform*panel.get_aabb()
				panel.position.x += (-1.28 if i == 0 else 1.33)-bounds.get_center().x
	if HouseDomestic.visual(root,"bed_rug",Vector3(-4.2,.025,2.3),90):
		_hide(house,"Authoring/Comfort/BedRug")
		_hide(house,"Authoring/Comfort/BedRugBorder")
	if HouseDomestic.visual(root,"side_table",Vector3(5.6,0,4.1)):
		HouseKit.blocker(root,"LanternTableBody",Vector3(5.6,.275,4.1),Vector3(.55,.55,.45))
		if HouseDomestic.visual(root,"wood_lantern",Vector3(5.6,.551,4.1)):
			house._keep_light("living",HouseKit.light(root,"WindowLantern",Vector3(5.6,.72,4.1),Color("ffd4a0"),.35,2.5))
			HouseKit.box(root,"LanternFlame",Vector3(5.6,.74,4.1),Vector3(.018,.05,.018),HouseKit.glow(Color("ffbc70"),1.4))
	HouseKit.box(root,"RidgeFrame",Vector3(2.2,1.85,4.742),Vector3(.74,.94,.045),timber)
	HouseKit.box(root,"RidgePaper",Vector3(2.2,1.85,4.710),Vector3(.65,.85,.018),flax)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(1.92,1.59,4.694),Vector3(2.2,2.05,4.694),Vector3(2.46,1.59,4.694)]:
		surface.add_vertex(vertex)
	surface.generate_normals()
	var ridge := MeshInstance3D.new()
	ridge.name = "HandmadeRidge"
	ridge.mesh = surface.commit()
	var ink := HouseKit.paint(Color("496064"),.95).duplicate() as StandardMaterial3D
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	ridge.material_override = ink
	root.add_child(ridge)
	HouseKit.box(root,"ReliefSun",Vector3(2.0,2.1,4.69),Vector3(.1,.1,.018),rust)
	for i in range(5):
		HouseKit.box(root,"ShelfBook",Vector3(5.82,.523+(i%2)*.02,.28+i*.11),Vector3(.20,.27+(i%2)*.04,.065),rust if i%2==0 else flax)
	_pendant(house,root,flax,timber)
	_replacements(house,root)
	retune(house)

static func _replacements(house: House, root: Node3D) -> void:
	var lamp_path := "res://assets/vendor/polyhaven/modern_ceiling_lamp_01/modern_ceiling_lamp_01_1k.gltf"
	if ResourceLoader.exists(lamp_path):
		var lamp := HouseKit.prop(root,"modern_ceiling_lamp_01",Vector3(4.45,1.907,-2.7))
		for name in ["DiningShade","PendantCord","PendantGlow"]:
			var old := root.get_node_or_null(name) as GeometryInstance3D
			if old: old.hide()
		for mesh in lamp.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var original: Material = mesh.mesh.surface_get_material(surface)
				if original and original.resource_name == "modern_ceiling_globe":
					var mat := original.duplicate() as BaseMaterial3D
					mat.emission_enabled = true
					mat.emission = Color("ffddb0")
					mat.emission_energy_multiplier = .35
					mesh.set_surface_override_material(surface,mat)
	var bench_path := "res://assets/vendor/polyhaven/painted_wooden_bench/painted_wooden_bench_1k.gltf"
	if ResourceLoader.exists(bench_path):
		HouseKit.prop(root,"painted_wooden_bench",Vector3(-1.16,.0005,4.02),90)
		var old := root.get_node_or_null("BootBench") as GeometryInstance3D
		if old: old.hide()
		var body := root.get_node_or_null("BootBenchBody") as StaticBody3D
		if body: body.collision_layer = 0
		HouseKit.blocker(root,"ImportedBootBenchBody",Vector3(-1.16,.445,4.02),Vector3(.497,.89,1.165))
	var cabinet_path := "res://assets/vendor/polyhaven/modern_wooden_cabinet/modern_wooden_cabinet_1k.gltf"
	if ResourceLoader.exists(cabinet_path):
		# Reconfigure the row rather than shrinking the 2.44 m cabinet.
		for name in ["Imported_cooker","CookerBody","CookerFallback"]:
			var cooker := root.get_node_or_null(name) as Node3D
			if cooker: cooker.position.x = 3.39
		for child in root.get_children():
			if not child is Node3D: continue
			if child.position.x>=3.5 and child.position.x<=6.2 and child.position.z< -4.1 and child.position.y<1.4:
				if str(child.name) in ["Sink","Tap","TapSpout"]: continue
				if child is GeometryInstance3D: child.hide()
				elif child is StaticBody3D: child.collision_layer = 0
		HouseKit.prop(root,"modern_wooden_cabinet",Vector3(4.9,.20,-4.47))
		HouseKit.solid(root,"KitchenPlinth",Vector3(4.9,.10,-4.47),Vector3(2.44,.20,.50),HouseKit.paint(Color("354039"),.9))
		HouseKit.solid(root,"KitchenWorktop",Vector3(4.9,.92,-4.47),Vector3(2.47,.08,.64),HouseKit.paint(Color("ded5bf"),.9))
		HouseKit.blocker(root,"RealCabinetBody",Vector3(4.9,.54,-4.47),Vector3(2.44,.68,.52))

static func _hide(house: House, path: String) -> void:
	var node := house.get_node_or_null(path) as GeometryInstance3D
	if node: node.hide()

static func _pendant(house: House, root: Node3D, shade_material: Material, cord_material: Material) -> void:
	_hide(house,"Lights/KitchenBulb")
	_hide(house,"Lights/KitchenFlex")
	var shade := MeshInstance3D.new()
	shade.name = "DiningShade"
	var mesh := CylinderMesh.new()
	mesh.top_radius = .18
	mesh.bottom_radius = .32
	mesh.height = .25
	shade.mesh = mesh
	shade.material_override = shade_material
	shade.position = Vector3(4.45,2.5,-2.7)
	root.add_child(shade)
	HouseKit.box(root,"PendantCord",Vector3(4.45,2.82,-2.7),Vector3(.014,.62,.014),cord_material)
	HouseKit.box(root,"PendantGlow",Vector3(4.45,2.38,-2.7),Vector3(.16,.025,.16),HouseKit.glow(Color("ffddb0"),.6))

static func retune(house: House) -> void:
	var lights := house.get_node_or_null("Lights")
	if lights:
		house._retune(lights,"KitchenLight",Color("ffe1bf"),.72,4.8,1.05)
		house._retune(lights,"LanternLight",Color("ffcb95"),1.0,4.5,.9)
		var kitchen := lights.get_node_or_null("KitchenLight") as OmniLight3D
		if kitchen: kitchen.position.y = 2.32
	var comfort := house.get_node_or_null("Authoring/Comfort")
	if comfort:
		house._retune(comfort,"BedroomFill",Color("e8dcc9"),.18,4.5,1.0)
		house._retune(comfort,"LivingLamp",Color("ffdbb2"),.65,4.5,1.0)
