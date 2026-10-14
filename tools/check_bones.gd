extends SceneTree

func _initialize() -> void:
	var scn := load("res://assets/characters/styloo_elf/elf.glb") as PackedScene
	var model := scn.instantiate()
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	for b in [
		"DEF-spine", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-spine.004", "DEF-spine.005", "DEF-spine.006"
	]:
		var idx := skel.find_bone(b)
		if idx >= 0:
			var pose := skel.get_bone_global_rest(idx)
			print(b, ": pos = ", pose.origin, " fwd (Z) = ", pose.basis.z, " up (Y) = ", pose.basis.y)
	quit(0)
