extends SceneTree

# Prints the extent of the grown hair mesh below the shoulders.
#   godot --headless --path . -s tools/hair_extent.gd

func _initialize() -> void:
	var scene := (load("res://assets/characters/hair.glb") as PackedScene).instantiate()
	var mesh := (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var wide := 0.0
	var lowest := 9.0
	for p in points:
		if p.y < 1.45:
			wide = maxf(wide, absf(p.x))
		lowest = minf(lowest, p.y)
	print("HAIRGEO below-shoulder max |x| ", wide, " lowest y ", lowest)
	scene.free()
	quit()
