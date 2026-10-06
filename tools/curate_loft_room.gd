extends SceneTree
## Flatten the owner-supplied room into house-local units without modifying its source.
const SOURCE := "res://assets/vendor/requested_house/loft_room/source/скетч.fbx"
const SCALE := .4
const FLOOR_Y := .210932

func _initialize() -> void:
	var scene := load(SOURCE) as PackedScene
	var source := scene.instantiate() as Node3D
	var room := Node3D.new()
	room.name = "Loft16"
	_collect(source,Transform3D.IDENTITY,room)
	room.set_meta("source",SOURCE)
	room.set_meta("unit_correction",SCALE)
	room.set_meta("floorplate_m",Vector2(5.973,5.973))
	var packed := PackedScene.new()
	packed.pack(room)
	ResourceSaver.save(packed,"res://assets/derived/requested_house/loft_room.scn")
	# A separate, reusable painting keeps its source texture and aspect ratio.
	var painting := room.get_node_or_null("Plane_020") as MeshInstance3D
	if painting:
		var art := Node3D.new()
		art.name = "LoftPainting"
		var copy := painting.duplicate() as MeshInstance3D
		var bounds: AABB = copy.transform*copy.get_aabb()
		copy.position -= bounds.get_center()
		art.add_child(copy)
		copy.owner = art
		var resource := PackedScene.new()
		resource.pack(art)
		ResourceSaver.save(resource,"res://assets/derived/requested_house/loft_painting.scn")
		art.free()
	room.free()
	source.free()
	print("LOFT_CURATED: 5.973 m floorplate, uniform 0.4 correction, original artwork/materials retained")
	quit()

func _collect(node: Node3D, ancestor: Transform3D, room: Node3D) -> void:
	var transform := ancestor*node.transform
	if node is MeshInstance3D:
		var copy := MeshInstance3D.new()
		copy.name = node.name
		copy.mesh = node.mesh
		if str(node.name)=="Plane":
			copy.mesh = _open_threshold(node.mesh,transform)
		copy.transform = transform
		copy.position = (copy.position-Vector3(0,FLOOR_Y,0))*SCALE
		copy.scale *= SCALE
		room.add_child(copy)
		copy.owner = room
		for surface in range(copy.mesh.get_surface_count()):
			var original := copy.mesh.surface_get_material(surface) as BaseMaterial3D
			if original:
				var material := original.duplicate() as BaseMaterial3D
				if original.resource_name=="Material.010":
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					material.alpha_scissor_threshold = .4
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				copy.set_surface_override_material(surface,material)
	for child in node.get_children():
		if child is Node3D: _collect(child,transform,room)

func _open_threshold(mesh: Mesh, transform: Transform3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(vertices.size()): indices.append(i)
		var kept := PackedInt32Array()
		for i in range(0,indices.size(),3):
			var centre := Vector3.ZERO
			var highest := -INF
			for j in range(3):
				var point := transform*vertices[indices[i+j]]
				centre += point/3.0
				highest = maxf(highest,point.y)
			if centre.x>6.5 and highest>FLOOR_Y+.01: continue
			for j in range(3): kept.append(indices[i+j])
		arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface,mesh.surface_get_material(surface))
	return result
