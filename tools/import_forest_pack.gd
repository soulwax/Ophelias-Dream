extends SceneTree

# Splits the Sketchfab forest diorama (assets/vendor/sketchfab_forest) into the
# pieces the green biome plants: five tall spruces, two card trees, a card fir,
# a card bush and a grass card. Each is baked out of its place in the scene,
# stood on its base at the origin, and given materials of its own: alpha-cut,
# double-sided cards and opaque trunks.
# The raw FBX is kept out of git in build/vendor/sketchfab_forest/source/ (build/ is
# not imported by Godot). Copy it to SOURCE's folder, import, run, then delete it:
#   Copy-Item build/vendor/sketchfab_forest/source/forest_pack.fbx assets/vendor/sketchfab_forest/source/
#   godot-mono --headless --path . --import
#   godot-mono --headless --path . -s tools/import_forest_pack.gd
# .gitignore keeps the copy (and the extra forest_pack_9.png the import extracts) out of commits.

const SOURCE := "res://assets/vendor/sketchfab_forest/source/forest_pack.fbx"
const OUT := "res://assets/vendor/sketchfab_forest/meshes/"
# [piece, node-name prefix, which match (by order in the scene)]
const PIECES := [
	["spruce_a", "Cylinder_023", 0],
	["spruce_b", "Cylinder_012", 0],
	["spruce_c", "Cylinder_018", 0],
	["spruce_d", "Cylinder_013", 0],
	["spruce_e", "Cylinder_020", 0],
	["card_tree_a", "05ade0e713892be5", 0],
	["card_tree_b", "05ade0e713892be5", 2],
	["card_fir", "a37081a7611992c6f6d9dc1786dbc08d_cc24", 0],
	["card_bush", "a37081a7611992c6f6d9dc1786dbc08d_cc24", 7],
	["grass_card", "3f84aea6648aa6cc", 0],
]


func _initialize() -> void:
	var scene := (load(SOURCE) as PackedScene).instantiate()
	var meshes: Array = scene.find_children("*", "MeshInstance3D", true, false)
	var failed := 0
	for piece: Array in PIECES:
		var found: Array = []
		for node in meshes:
			if _clean(str(node.name)).begins_with(_clean(piece[1])):
				found.append(node)
		if found.size() <= int(piece[2]):
			print("FAIL %s: only %d nodes start with %s" % [piece[0], found.size(), piece[1]])
			failed += 1
			continue
		var instance := found[int(piece[2])] as MeshInstance3D
		var mesh := _bake(instance, _global(instance, scene))
		var path := OUT + str(piece[0]) + ".res"
		var result := ResourceSaver.save(mesh, path)
		var box := mesh.get_aabb()
		print("%-12s from %-40s %d surfaces, %.1f m tall -> %s (%s)" % [piece[0], str(instance.name).left(40), mesh.get_surface_count(), box.size.y, path, error_string(result)])
		if result != OK:
			failed += 1
	scene.free()
	quit(1 if failed > 0 else 0)


# Names in the FBX use characters the scene tree replaces; compare them loosely.
func _clean(name: String) -> String:
	return name.replace("|", "_").replace(" ", "_")


# The mesh in world space, moved so its base sits at the origin, with its own
# copies of the materials: cards alpha-cut and double-sided.
func _bake(instance: MeshInstance3D, to_world: Transform3D) -> ArrayMesh:
	var source := instance.mesh
	var bounds := AABB()
	var first := true
	for surface in source.get_surface_count():
		for vertex: Vector3 in source.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var at := to_world * vertex
			bounds = AABB(at, Vector3.ZERO) if first else bounds.expand(at)
			first = false
	var base := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			vertices[i] = to_world * vertices[i] - base
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in normals.size():
				normals[i] = (to_world.basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		# Tangents would need the same turn; the cards light fine without them.
		arrays[Mesh.ARRAY_TANGENT] = null
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		var material := instance.get_active_material(surface)
		mesh.surface_set_material(surface, _material(material))
	return mesh


func _material(original: Material) -> Material:
	if not original is BaseMaterial3D:
		return original
	var material := (original as BaseMaterial3D).duplicate() as StandardMaterial3D
	var texture := material.albedo_texture
	var image := texture.get_image() if texture else null
	if image and image.detect_alpha() != Image.ALPHA_NONE:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.4
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	material.metallic = 0.0
	return material


func _global(node: Node3D, root: Node) -> Transform3D:
	var t := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t
