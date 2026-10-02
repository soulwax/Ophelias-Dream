class_name Fence
extends Node3D

const SCALE := 100.0
const MESH := "res://assets/environment/SM_WireFence.fbx"
const ALBEDO := "res://assets/environment/T_WireFence_B.png"
const NORMAL := "res://assets/environment/T_WireFence_N.png"

var ground: Ground
var _packed: PackedScene
var _material: StandardMaterial3D


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
	_packed = load(MESH) as PackedScene
	_material = _wire_material()
	var sample := _segment()
	var bounds := _bounds(sample)
	sample.free()
	var span := maxf(bounds.size.x * SCALE, 0.5)
	for edge in corners.size():
		_run(corners[edge], corners[(edge + 1) % corners.size()], bounds, span)


func _run(from: Vector3, to: Vector3, bounds: AABB, span: float) -> void:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := flat.length()
	if length < 0.01:
		return
	var count := int(ceil(length / (span * 0.98)))
	var yaw := atan2(-flat.z, flat.x)
	for i in count:
		var at := from.lerp(to, (float(i) + 0.5) / float(count))
		at.y = ground.height_at(at.x, at.z) if ground else 0.0
		var node := _segment()
		add_child(node)
		_seat(node, at, yaw, bounds)
	_wall(from, to)


func _seat(node: Node3D, at: Vector3, yaw: float, bounds: AABB) -> void:
	var stand := Basis(Vector3.RIGHT, -PI * 0.5)
	var turn := Basis(Vector3.UP, yaw)
	node.transform.basis = (turn * stand).scaled(Vector3(SCALE, SCALE, SCALE))
	var acc := Vector3.ZERO
	var min_y := INF
	var corners := _corners(bounds)
	for corner in corners:
		var placed: Vector3 = node.transform.basis * corner
		acc += placed
		min_y = minf(min_y, placed.y)
	acc /= float(corners.size())
	node.position = at - Vector3(acc.x, min_y, acc.z)


func _corners(bounds: AABB) -> Array[Vector3]:
	var p := bounds.position
	var s := bounds.size
	return [
		p,
		p + Vector3(s.x, 0, 0),
		p + Vector3(0, s.y, 0),
		p + Vector3(0, 0, s.z),
		p + Vector3(s.x, s.y, 0),
		p + Vector3(s.x, 0, s.z),
		p + Vector3(0, s.y, s.z),
		p + s,
	]


func _segment() -> Node3D:
	var node := _packed.instantiate() as Node3D
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh_instance as MeshInstance3D
		var mesh_name := instance.name.to_lower()
		if "lod1" in mesh_name or "lod2" in mesh_name or mesh_name.begins_with("ucx"):
			instance.visible = false
			continue
		instance.material_override = _material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _wire_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ALBEDO)
	material.normal_enabled = true
	material.normal_texture = load(NORMAL)
	material.metallic = 0.72
	material.roughness = 0.48
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


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
