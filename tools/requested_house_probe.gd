extends SceneTree

func _initialize() -> void:
	for role in ["loft_room"]:
		var paths := _models("res://assets/vendor/requested_house/"+role)
		for path in paths:
			var scene: PackedScene = load(path)
			if scene == null: continue
			var root := scene.instantiate() as Node3D
			print("MODEL ",role," ",path)
			_inspect(root,Transform3D.IDENTITY)
			root.free()
	quit()

func _models(folder: String) -> Array[String]:
	var result: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.get_extension().to_lower() in ["fbx","gltf","glb"]:
			result.append(folder+"/"+file)
	for directory in DirAccess.get_directories_at(folder):
		result.append_array(_models(folder+"/"+directory))
	return result

func _inspect(node: Node3D, parent_transform: Transform3D) -> void:
	var transform := parent_transform*node.transform
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var box: AABB = transform*mesh.get_aabb()
		var names: Array[String] = []
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(surface)
			names.append(material.resource_name if material != null else "none")
		print(" MESH ",node.name," bounds=",box," materials=",names)
		if "bathroom" in str(mesh.mesh.resource_path) or node.name == "Plane_001":
			for surface in range(mesh.mesh.get_surface_count()):
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var bounds := AABB(vertices[0],Vector3.ZERO)
				for vertex in vertices: bounds = bounds.expand(vertex)
				print(" BATH_SURFACE ",surface," ",names[surface]," ",transform*bounds)
	for child in node.get_children():
		if child is Node3D: _inspect(child,transform)
