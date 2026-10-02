class_name Fence
extends Node3D

const SEGMENTS: Array[String] = ["SM_Bld_Fence_01.fbx", "SM_Bld_Fence_02.fbx"]

var ground: Ground


func _ready() -> void:
	if ground:
		build()


func build() -> void:
	var corners: Array[Vector3] = [
		Vector3(Tune.FENCE_MIN_X, 0, Tune.FENCE_MAX_Z),
		Vector3(Tune.FENCE_MAX_X, 0, Tune.FENCE_MAX_Z),
		Vector3(Tune.FENCE_MAX_X, 0, Tune.FENCE_MIN_Z),
		Vector3(Tune.FENCE_MIN_X, 0, Tune.FENCE_MIN_Z),
	]
	var sample := PropFactory.spawn(SEGMENTS[0])
	var bounds := _bounds(sample)
	sample.free()
	var along_x := bounds.size.x >= bounds.size.z
	var span := bounds.size.x if along_x else bounds.size.z
	span = maxf(span, 0.5)
	for edge in corners.size():
		_run(corners[edge], corners[(edge + 1) % corners.size()], bounds, along_x, span)
		_end_post(corners[edge])


func _run(from: Vector3, to: Vector3, bounds: AABB, along_x: bool, span: float) -> void:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := flat.length()
	if length < 0.01:
		return
	var count := int(ceil(length / (span * 0.96)))
	var yaw := atan2(-flat.z, flat.x) if along_x else atan2(flat.x, flat.z)
	for i in count:
		var at := from.lerp(to, (float(i) + 0.5) / float(count))
		at.y = ground.height_at(at.x, at.z) if ground else 0.0
		var node := PropFactory.spawn(SEGMENTS[i % SEGMENTS.size()])
		node.rotation.y = yaw
		var center := bounds.get_center()
		node.position = at - node.transform.basis * Vector3(center.x, bounds.position.y, center.z)
		add_child(node)
	_wall(from, to)


func _end_post(at: Vector3) -> void:
	at.y = ground.height_at(at.x, at.z) if ground else 0.0
	var node := PropFactory.spawn("SM_Bld_Fence_End_01.fbx")
	var bounds := _bounds(node)
	var center := bounds.get_center()
	node.position = at - Vector3(center.x, bounds.position.y, center.z)
	add_child(node)


func _wall(from: Vector3, to: Vector3) -> void:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := flat.length()
	if length < 0.01:
		return
	var a := from
	var b := to
	a.y = ground.height_at(a.x, a.z) if ground else 0.0
	b.y = ground.height_at(b.x, b.z) if ground else 0.0
	var low := minf(a.y, b.y) - 0.4
	var high := maxf(a.y, b.y) + 2.4
	var body := StaticBody3D.new()
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	body.position = Vector3((a.x + b.x) * 0.5, (low + high) * 0.5, (a.z + b.z) * 0.5)
	body.rotation.y = atan2(flat.x, flat.z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, high - low, length)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _bounds(root: Node) -> AABB:
	var merged := AABB()
	var found := false
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh_instance as MeshInstance3D
		if not instance.visible or instance.mesh == null:
			continue
		var box := _to_root(root, instance) * instance.mesh.get_aabb()
		if not found:
			merged = box
			found = true
		else:
			merged = merged.merge(box)
	if not found:
		return AABB(Vector3.ZERO, Vector3(2, 1.5, 0.2))
	return merged


func _to_root(root: Node, node: Node3D) -> Transform3D:
	var xf := node.transform
	var current := node.get_parent()
	while current != null and current != root:
		if current is Node3D:
			xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf
