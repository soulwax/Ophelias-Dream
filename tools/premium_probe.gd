extends SceneTree


func _initialize() -> void:
	for file in DirAccess.get_files_at("res://assets/environment/premium"):
		if not file.ends_with(".fbx"):
			continue
		var scene := load("res://assets/environment/premium/" + file) as PackedScene
		var model := scene.instantiate() as Node3D
		print(file)
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			print("  ", mesh.name, " transform=", mesh.transform, " bounds=", mesh.get_aabb())
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface)
				print("    ", surface, " ", material.resource_name if material else "none")
		model.free()
	quit()
