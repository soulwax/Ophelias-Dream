class_name DreamRoute
extends Node3D

## Route-local dream events and a few nonliteral terrain details.
## Visual scenes are deliberately supplied by listeners only when a cue asks for one.
signal cue_requested(cue_id: String, at: Transform3D)

const CLEARING_OFFSET := 58.0
const DARK_PATCHES := [
	{"offset": 14.0, "side": -1.5, "size": Vector2(6.8, 8.4)},
	{"offset": 27.0, "side": 1.6, "size": Vector2(5.8, 7.4)},
	{"offset": 42.0, "side": -1.7, "size": Vector2(7.2, 9.2)},
	{"offset": 58.0, "side": 1.2, "size": Vector2(6.2, 8.0)},
]

const FOLD_SIDE_OFFSET := -12.5
const FOLD_WIDTH := 1.85
const FOLD_LENGTH := 26.0
const FOLD_RETURN := 12.5
const FOLD_HEIGHT := 6.5
const FOLD_SEGMENTS := 52
const FOLD_REVEAL_OFFSET := 18.0
const FOLD_FULL_OFFSET := 42.0

var trail: Trail
var _anchors: Dictionary = {}
var _fold_material: ShaderMaterial
var _fold_reveal := 0.0


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
	_build_dark_patches()
	_build_folded_path()


func _process(delta: float) -> void:
	if trail == null or Game.player == null or _fold_material == null:
		return
	var progress := trail.offset_of(Game.player.global_position) - trail.player_start_offset
	var target := smoothstep(FOLD_REVEAL_OFFSET, FOLD_FULL_OFFSET, progress)
	_fold_reveal = move_toward(_fold_reveal, target, delta * 0.16)
	_fold_material.set_shader_parameter("reveal", _fold_reveal)


func anchor(key: String) -> Transform3D:
	return _anchors.get(key, Transform3D.IDENTITY)


func world_position(key: String) -> Vector3:
	return anchor(key).origin


func cue_event(cue_id: String, route_offset := -1.0) -> void:
	if trail == null:
		return
	var at: Transform3D
	if route_offset >= 0.0:
		at = trail.frame_at(trail.player_start_offset + route_offset)
	else:
		at = trail.frame_at(trail.offset_of(Game.player.global_position)) if Game.player else anchor("step")
	cue_requested.emit(cue_id, at)


func _anchor(route_offset: float, side_offset: float) -> Transform3D:
	var frame := trail.frame_at(trail.player_start_offset + route_offset)
	var side := frame.basis.x
	side.y = 0.0
	if side.length_squared() > 0.001:
		side = side.normalized()
	frame.origin = trail.on_ground(frame.origin + side * side_offset)
	return frame


func _build_dark_patches() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dream_dark_patch.gdshader")
	for index in range(DARK_PATCHES.size()):
		var patch_data: Dictionary = DARK_PATCHES[index]
		var frame := _anchor(float(patch_data["offset"]), float(patch_data["side"]))
		var patch := MeshInstance3D.new()
		patch.name = "SilenceShadow_%02d" % (index + 1)
		var plane := PlaneMesh.new()
		plane.size = patch_data["size"]
		patch.mesh = plane
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patch.material_override = material
		var ground := trail.on_ground(frame.origin) + Vector3.UP * 0.085
		patch.global_transform = Transform3D(frame.basis, ground)
		add_child(patch)


func _build_folded_path() -> void:
	var frame := anchor("clearing")
	var ahead := anchor("answer").origin - frame.origin
	ahead.y = 0.0
	if ahead.length_squared() < 0.001:
		return
	ahead = ahead.normalized()
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	var centers := PackedVector3Array()
	centers.resize(FOLD_SEGMENTS + 1)
	for index in range(FOLD_SEGMENTS + 1):
		var t := float(index) / FOLD_SEGMENTS
		var lift := smoothstep(0.28, 1.0, t)
		var return_curve := smoothstep(0.58, 1.0, t)
		var along_distance := -FOLD_LENGTH * 0.42 + FOLD_LENGTH * t - FOLD_RETURN * return_curve * return_curve
		var side_distance := FOLD_SIDE_OFFSET + sin(t * PI) * 1.15
		var horizontal := frame.origin + ahead * along_distance + across * side_distance
		centers[index] = trail.on_ground(horizontal) + Vector3.UP * (0.065 + FOLD_HEIGHT * lift * lift)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize((FOLD_SEGMENTS + 1) * 2)
	normals.resize(vertices.size())
	uvs.resize(vertices.size())
	for index in range(FOLD_SEGMENTS + 1):
		var t := float(index) / FOLD_SEGMENTS
		var tangent := (centers[mini(index + 1, FOLD_SEGMENTS)] - centers[maxi(index - 1, 0)]).normalized()
		var normal := across.cross(tangent).normalized()
		if normal.y < 0.0:
			normal = -normal
		var half_width := FOLD_WIDTH * lerpf(0.5, 0.34, smoothstep(0.62, 1.0, t))
		vertices[index * 2] = to_local(centers[index] - across * half_width)
		vertices[index * 2 + 1] = to_local(centers[index] + across * half_width)
		normals[index * 2] = normal
		normals[index * 2 + 1] = normal
		uvs[index * 2] = Vector2(0.0, t)
		uvs[index * 2 + 1] = Vector2(1.0, t)
	for index in FOLD_SEGMENTS:
		var lower_left := index * 2
		var lower_right := lower_left + 1
		var upper_left := lower_left + 2
		var upper_right := lower_left + 3
		indices.append_array([lower_left, lower_right, upper_left, lower_right, upper_right, upper_left])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := MeshInstance3D.new()
	surface.name = "FoldedSnowPath"
	surface.mesh = mesh
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fold_material = ShaderMaterial.new()
	_fold_material.shader = preload("res://shaders/dream_folded_path.gdshader")
	_fold_material.set_shader_parameter("reveal", 0.0)
	surface.material_override = _fold_material
	add_child(surface)
