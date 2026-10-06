extends SceneTree
## Bake selected visual-only assets with consistent floor pivots; source stays untouched.

const SOURCES := {
	"stove": "res://assets/vendor/requested_house/stove/source/Dauntless FlexBurn Wood Stove.fbx",
	"cooker": "res://assets/vendor/requested_house/cooker/source/gas_stove_main.fbx",
	"rug": "res://assets/vendor/requested_house/rug/source/Wool Rug 160 x 230m.fbx",
	"cabinet": "res://assets/vendor/requested_house/cabinet/scene.gltf",
	"curtain": "res://assets/vendor/requested_house/curtain/scene.gltf",
	"shelves": "res://assets/vendor/requested_house/shelves/wooden_display_shelves_01_2k.gltf",
	"bathroom": "res://assets/vendor/requested_house/bathroom/source/SM_Bathroom_Props_01.fbx",
	"bed_rug": "res://assets/vendor/requested_house/bed_rug/source/Paloma Large Wool Rug.fbx",
	"wood_lantern": "res://assets/vendor/requested_house/wood_lantern/wooden_lantern_01_2k.gltf",
	"side_table": "res://assets/vendor/requested_house/side_table/side_table_01_2k.gltf"
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/derived/requested_house")
	for id in SOURCES:
		var scene: PackedScene = load(SOURCES[id])
		if scene == null: continue
		var source := scene.instantiate() as Node3D
		var result := Node3D.new()
		result.name = id.capitalize()
		_collect(source,Transform3D.IDENTITY,result,id)
		var bounds := AABB()
		var first := true
		for child in result.get_children():
			var box: AABB = child.transform*child.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var factor := 1.62/bounds.size.y if id == "curtain" else 1.0
		var offset := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		for child in result.get_children():
			child.position = (child.position-offset)*factor
			child.scale *= factor
			child.owner = result
		result.set_meta("dimensions_m",bounds.size*factor)
		result.set_meta("source",SOURCES[id])
		var packed := PackedScene.new()
		packed.pack(result)
		var error := ResourceSaver.save(packed,"res://assets/derived/requested_house/"+id+".scn")
		print("CURATED ",id," dimensions=",bounds.size*factor," save=",error)
		result.free()
		source.free()
	quit()

func _collect(node: Node3D, ancestor: Transform3D, destination: Node3D, id: String) -> void:
	var transform := ancestor*node.transform
	if node is MeshInstance3D:
		if (id in ["rug","bed_rug"] and node.name == "Plane001") or (id == "cabinet" and node.name == "Object_4"):
			return
		var copy := MeshInstance3D.new()
		copy.name = node.name
		copy.mesh = node.mesh
		if id == "bathroom":
			var fixtures := ArrayMesh.new()
			for surface in range(1,node.mesh.get_surface_count()):
				fixtures.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(surface))
				fixtures.surface_set_material(fixtures.get_surface_count()-1,node.mesh.surface_get_material(surface))
			copy.mesh = fixtures
		copy.transform = transform
		destination.add_child(copy)
		for surface in range(copy.mesh.get_surface_count()):
			var original: Material = copy.mesh.surface_get_material(surface)
			if original == null: continue
			var mat := original.duplicate() as BaseMaterial3D
			if mat == null: continue
			if id == "cooker":
				mat.albedo_texture = load("res://assets/vendor/requested_house/cooker/textures/gas_stove_BaseColor.png")
				mat.normal_enabled = true
				mat.normal_texture = load("res://assets/vendor/requested_house/cooker/textures/gas_stove_Normal.png")
				mat.roughness_texture = load("res://assets/vendor/requested_house/cooker/textures/gas_stove_Roughness.png")
				mat.metallic_texture = load("res://assets/vendor/requested_house/cooker/textures/gas_stove_Metallic.png")
				mat.metallic = 1
			if id == "rug":
				mat.albedo_texture = load("res://assets/vendor/requested_house/rug/textures/Henrik_Hand_Tufted_Wool_Rug_Mustard_and_Gr.jpg")
				mat.roughness = .98
			if id == "bed_rug":
				mat.albedo_texture = load("res://assets/vendor/requested_house/bed_rug/textures/Paloma_Large_Wool_Rug_diffuse.jpg")
				mat.roughness = .98
			if id == "bathroom":
				var prefix := "res://assets/vendor/requested_house/bathroom/textures/Material_"+str(surface+1)+"_"
				mat.albedo_texture = load(prefix+"Base_color.tga.png")
				mat.albedo_color = Color.WHITE
				mat.normal_enabled = true
				mat.normal_texture = load(prefix+"Normal_OpenGL.tga.png")
				mat.roughness_texture = load(prefix+"Roughness.tga.png")
				if surface == 1:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = .22
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if id == "cabinet":
				mat.albedo_color = Color("bfb194")
				mat.roughness = .85
			if id == "stove" and original.resource_name == "glass":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = Color(.65,.55,.4,.18)
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if id == "stove" and node.name == "PLANOFUEGO":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.emission_enabled = true
				mat.emission = Color("ff8e40")
				mat.emission_energy_multiplier = .8
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			copy.set_surface_override_material(surface,mat)
	for child in node.get_children():
		if child is Node3D: _collect(child,transform,destination,id)
