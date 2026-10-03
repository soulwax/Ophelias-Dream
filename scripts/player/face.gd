class_name Face
extends Node

## Her face comes alive: blinks, a strained squint, a frightened brow.
##
## The shapes were sculpted in Blender (tools/blender/sculpt_head.py) as
## per-vertex offsets keyed by rest position. Here they become blend shapes on
## a copy of her face and brow meshes, so the rig itself is never edited:
##   blink_L, blink_R  upper lids close onto the ball, lower lids rise a little
##   squint            lids narrow with exertion
##   brow_fear         inner brows lift and draw together

const SHAPES := "res://assets/characters/face_shapes.json"

# 0 calm .. 1 gasping, and 0 .. 1 how hard the world presses on her.
var strain: Callable
var fear: Callable

var _face: MeshInstance3D
var _brows: MeshInstance3D
var _blink_l := -1
var _blink_r := -1
var _squint := -1
var _brow := -1
var _next_blink := 1.5
var _blink_t := -1.0
var _double := false
var _squint_now := 0.0
var _fear_now := 0.0


## Adds blend shapes to the face and brow meshes of `model`. Returns null when
## the sculpted shapes are missing (the face then simply stays still).
static func fit(model: Node, face_mesh: MeshInstance3D) -> Face:
	if face_mesh == null or not FileAccess.file_exists(SHAPES):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHAPES))
	if not data is Dictionary:
		return null
	var shapes: Dictionary = data.get("shapes", {})
	var face := Face.new()
	face.name = "Face"
	face._face = face_mesh
	var names := face._shape(face_mesh, shapes, ["blink_L", "blink_R", "squint"])
	face._blink_l = names.find("blink_L")
	face._blink_r = names.find("blink_R")
	face._squint = names.find("squint")
	for child in model.find_children("*", "MeshInstance3D", true, false):
		if "brow" in child.name.to_lower():
			face._brows = child as MeshInstance3D
	if face._brows:
		face._brow = face._shape(face._brows, shapes, ["brow_fear"]).find("brow_fear")
	model.add_child(face)
	return face


func _process(delta: float) -> void:
	var effort: float = strain.call() if strain.is_valid() else 0.0
	var dread: float = fear.call() if fear.is_valid() else 0.0
	# Blinks: irregular, closer together when she is spent or afraid.
	_next_blink -= delta
	if _blink_t < 0.0 and _next_blink <= 0.0:
		_blink_t = 0.0
		_double = randf() < 0.18
		_next_blink = randf_range(2.2, 6.0) * lerpf(1.0, 0.45, maxf(effort, dread))
	var closed := 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		# Fast down, a beat closed, slower up.
		var t := _blink_t
		if t < 0.06:
			closed = t / 0.06
		elif t < 0.1:
			closed = 1.0
		elif t < 0.22:
			closed = 1.0 - (t - 0.1) / 0.12
		else:
			if _double:
				_double = false
				_blink_t = 0.0
			else:
				_blink_t = -1.0
	_squint_now = lerpf(_squint_now, clampf(effort * 0.85, 0.0, 0.85), 1.0 - exp(-delta * 3.0))
	_fear_now = lerpf(_fear_now, clampf(dread * 1.2, 0.0, 1.0), 1.0 - exp(-delta * 2.0))
	# Dev hook: RUN_FACE=blink|squint|fear holds that expression.
	match OS.get_environment("RUN_FACE"):
		"blink":
			closed = 1.0
		"squint":
			_squint_now = 1.0
		"fear":
			_fear_now = 1.0
	_weigh(_face, _blink_l, closed)
	_weigh(_face, _blink_r, closed)
	_weigh(_face, _squint, _squint_now * (1.0 - closed))
	_weigh(_brows, _brow, _fear_now)


func _weigh(mesh: MeshInstance3D, index: int, value: float) -> void:
	if mesh and index >= 0:
		mesh.set_blend_shape_value(index, value)


## Rebuilds `instance`'s mesh with the named shapes as blend shapes; returns
## the names in blend-shape order (only those that touched any vertex).
func _shape(instance: MeshInstance3D, shapes: Dictionary, names: Array) -> Array:
	var source := instance.mesh
	if source == null or source.get_surface_count() == 0:
		return []
	# Only the standard arrays: passing the custom slots back through as they
	# come out is rejected by add_surface_from_arrays.
	var original := source.surface_get_arrays(0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_INDEX]:
		arrays[slot] = original[slot]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Rest position -> vertex indices (seams split one point into several).
	var at: Dictionary = {}
	for i in verts.size():
		var key := _key(verts[i])
		if not at.has(key):
			at[key] = []
		(at[key] as Array).append(i)
	var used: Array = []
	var blends: Array = []
	for shape_name in names:
		var offsets: Array = shapes.get(shape_name, [])
		if offsets.is_empty():
			continue
		var moved := verts.duplicate()
		var hits := 0
		for row in offsets:
			var key := _key(Vector3(row[0], row[1], row[2]))
			for index in at.get(key, []):
				moved[index] = verts[index] + Vector3(row[3], row[4], row[5])
				hits += 1
		if hits == 0:
			continue
		# Relative blend shapes hold offsets from the base, not positions.
		var delta := PackedVector3Array()
		delta.resize(verts.size())
		for index in verts.size():
			delta[index] = moved[index] - verts[index]
		var flat := PackedVector3Array()
		flat.resize(verts.size())
		var blend := []
		blend.resize(Mesh.ARRAY_MAX)
		blend[Mesh.ARRAY_VERTEX] = delta
		blend[Mesh.ARRAY_NORMAL] = flat
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		if not tangents.is_empty():
			var flat_t := PackedFloat32Array()
			flat_t.resize(tangents.size())
			blend[Mesh.ARRAY_TANGENT] = flat_t
		blends.append(blend)
		used.append(shape_name)
	if used.is_empty():
		return []
	var mesh := ArrayMesh.new()
	for shape_name in used:
		mesh.add_blend_shape(shape_name)
	var flags := 0
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if weights.size() == verts.size() * 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends, {}, flags)
	mesh.surface_set_material(0, source.surface_get_material(0))
	instance.mesh = mesh
	return used


static func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 5000.0), roundi(p.y * 5000.0), roundi(p.z * 5000.0))
