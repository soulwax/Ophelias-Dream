class_name DreamRoute
extends Node3D

## Ground-aligned anchors and the small ice clearing for the playable dream.
const CLEARING_OFFSET := 58.0
const CLEARING_WIDTH := 8.5
const CLEARING_LENGTH := 13.0
const GRID_ACROSS := 32
const GRID_ALONG := 48

var trail: Trail
var _anchors: Dictionary = {}


func build(source: Trail) -> void:
	trail = source
	if trail == null:
		return
	_anchors = {
		"step": _anchor(1.0, 0.0),
		"lantern": _anchor(33.0, 2.6),
		"clearing": _anchor(CLEARING_OFFSET, 0.0),
		"answer": _anchor(67.0, 0.0),
	}
	_build_clearing()


func anchor(key: String) -> Transform3D:
	var value: Transform3D = _anchors.get(key, Transform3D.IDENTITY)
	return value


func world_position(key: String) -> Vector3:
	return anchor(key).origin


func _anchor(route_offset: float, side_offset: float) -> Transform3D:
	var frame := trail.frame_at(trail.player_start_offset + route_offset)
	var side := frame.basis.x
	side.y = 0.0
	if side.length_squared() > 0.001:
		side = side.normalized()
	frame.origin = trail.on_ground(frame.origin + side * side_offset)
	return frame


func _build_clearing() -> void:
	var frame := anchor("clearing")
	var ahead := anchor("answer").origin - frame.origin
	ahead.y = 0.0
	if ahead.length_squared() < 0.001:
		return
	ahead = ahead.normalized()
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_size := GRID_ACROSS + 1
	vertices.resize(row_size * (GRID_ALONG + 1))
	uvs.resize(vertices.size())
	for j in range(GRID_ALONG + 1):
		var along_ratio := float(j) / GRID_ALONG
		for i in range(GRID_ACROSS + 1):
			var across_ratio := float(i) / GRID_ACROSS
			var across_distance := (across_ratio - 0.5) * CLEARING_WIDTH
			var along_distance := (along_ratio - 0.5) * CLEARING_LENGTH
			var world := frame.origin + across * across_distance + ahead * along_distance
			world = trail.on_ground(world) + Vector3.UP * 0.055
			var index := j * row_size + i
			vertices[index] = to_local(world)
			uvs[index] = Vector2(across_ratio, along_ratio)
	for j in GRID_ALONG:
		for i in GRID_ACROSS:
			var lower_left := j * row_size + i
			var lower_right := lower_left + 1
			var upper_left := lower_left + row_size
			var upper_right := upper_left + 1
			indices.append(lower_left)
			indices.append(lower_right)
			indices.append(upper_left)
			indices.append(lower_right)
			indices.append(upper_right)
			indices.append(upper_left)
	var across_stride := CLEARING_WIDTH / GRID_ACROSS
	var along_stride := CLEARING_LENGTH / GRID_ALONG
	for j in range(GRID_ALONG + 1):
		for i in range(GRID_ACROSS + 1):
			var index := j * row_size + i
			var left := vertices[j * row_size + maxi(i - 1, 0)]
			var right := vertices[j * row_size + mini(i + 1, GRID_ACROSS)]
			var back := vertices[maxi(j - 1, 0) * row_size + i]
			var front := vertices[mini(j + 1, GRID_ALONG) * row_size + i]
			var tangent_across := (right - left) / (across_stride if i == 0 or i == GRID_ACROSS else across_stride * 2.0)
			var tangent_along := (front - back) / (along_stride if j == 0 or j == GRID_ALONG else along_stride * 2.0)
			normals.append(tangent_across.cross(tangent_along).normalized())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := MeshInstance3D.new()
	surface.name = "DreamIceClearing"
	surface.mesh = mesh
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dream_clearing.gdshader")
	surface.material_override = material
	add_child(surface)
