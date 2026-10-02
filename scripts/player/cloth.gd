class_name Cloth
extends MeshInstance3D

# A small Verlet cloth: a grid of particles whose top row is pinned to a bone.
# Distance links hold the weave together, a soft pull toward the tailored rest
# shape keeps the cut, and capsules on the body keep it outside. It runs in
# world space, so inertia, turning and wind all drag it behind her.
#
# panel splits the columns into independent strips (hair locks): links and
# faces never cross from one strip to the next.

const STEP := 1.0 / 60.0
const MAX_STEPS := 2

var stiffness := 0.0
# How hard folds resist, 0..1. Bend links reach two and three particles
# along each row and column, so a fold spreads over several segments and
# rolls instead of creasing at one joint.
var bend := 0.5
var damping := 0.03
var wind_response := 0.0
var iterations := 3
var panel := 0
var smooth_cols := true
var smooth_rows := true
# Hair cards: UVs run 0..1 across each strip and root to tip, and every strip
# is drawn card_layers times, each copy lifted off the last by layer_gap with its
# texture shifted, so one simulated lock reads as a thick fall of strands.
var card_uv := false
var card_layers := 1
var layer_gap := 0.008

var _skeleton: Skeleton3D
var _anchor := -1
var _cols := 2
var _rows := 2
var _local := PackedVector3Array()
var _rest := PackedVector3Array()
var _pos := PackedVector3Array()
var _prev := PackedVector3Array()
var _link_a := PackedInt32Array()
var _link_b := PackedInt32Array()
var _link_len := PackedFloat32Array()
var _link_k := PackedFloat32Array()
var _capsules: Array = []
var _world_caps: Array = []
var _trim: Callable
var _accum := 0.0
var _live := false
var _last_frame := Transform3D.IDENTITY
var _mesh := ArrayMesh.new()
var _render_cols := 0
var _render_rows := 0
var _indices := PackedInt32Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()


# rest: rows * cols points in skeleton rest space; row 0 is pinned to bone.
# closed_rows: how many top rows also link the last column back to the first.
# trim: func(u: float, v: float) -> Color with u, v in 0..1 over the grid.
func setup(skeleton: Skeleton3D, bone: String, rest: PackedVector3Array, cols: int, rows: int, closed_rows: int, trim: Callable) -> void:
	_skeleton = skeleton
	_anchor = skeleton.find_bone(bone)
	_cols = cols
	_rows = rows
	_rest = rest
	_trim = trim
	if panel > 0:
		smooth_cols = false
	var to_bone := skeleton.get_bone_global_rest(_anchor).affine_inverse()
	_local.resize(rest.size())
	for i in rest.size():
		_local[i] = to_bone * rest[i]
	for i in rows:
		for j in cols:
			if j + 1 < cols and not _panel_edge(j):
				_link(i, j, i, j + 1, 1.0)
			elif j + 1 == cols and i < closed_rows:
				_link(i, j, i, 0, 1.0)
			if i + 1 < rows:
				_link(i, j, i + 1, j, 1.0)
			if i + 2 < rows:
				_link(i, j, i + 2, j, bend)
			if i + 3 < rows:
				_link(i, j, i + 3, j, bend * 0.5)
			if _same_strip(j, j + 2):
				_link(i, j, i, j + 2, bend)
			elif j + 2 >= cols and i < closed_rows and panel == 0:
				_link(i, j, i, (j + 2) % cols, bend)
	_pos = rest.duplicate()
	_prev = rest.duplicate()
	_prepare_render()
	top_level = true
	mesh = _mesh
	extra_cull_margin = 2.0


func add_capsule(bone: String, a_rest: Vector3, b_rest: Vector3, radius: float) -> void:
	var index := _skeleton.find_bone(bone)
	var to_bone := _skeleton.get_bone_global_rest(index).affine_inverse()
	_capsules.append([index, to_bone * a_rest, to_bone * b_rest, radius])


func _panel_edge(j: int) -> bool:
	return panel > 0 and j % panel == panel - 1


func _same_strip(j0: int, j1: int) -> bool:
	if j1 >= _cols:
		return false
	return panel == 0 or floori(j0 / float(panel)) == floori(j1 / float(panel))


func _link(i0: int, j0: int, i1: int, j1: int, weight: float) -> void:
	if weight <= 0.0:
		return
	var a := i0 * _cols + j0
	var b := i1 * _cols + j1
	_link_a.append(a)
	_link_b.append(b)
	_link_len.append(_rest[a].distance_to(_rest[b]))
	_link_k.append(weight)


func _process(delta: float) -> void:
	if _skeleton == null or _anchor < 0:
		return
	global_transform = Transform3D.IDENTITY
	var frame := _skeleton.global_transform * _skeleton.get_bone_global_pose(_anchor)
	if not _live or _pos[0].distance_to(frame * _local[0]) > 1.5:
		_reset(frame)
	_place_capsules()
	var wind := _wind()
	_accum = minf(_accum + delta, STEP * MAX_STEPS)
	var steps := int(_accum / STEP)
	for k in steps:
		_accum -= STEP
		# Sweep the pinned row from last frame's pose to this one, so a fast
		# turn drags the cloth instead of teleporting its top edge.
		_step(_last_frame.interpolate_with(frame, float(k + 1) / float(steps)), wind)
	_last_frame = frame
	_rebuild()


func _reset(frame: Transform3D) -> void:
	for i in _local.size():
		_pos[i] = frame * _local[i]
		_prev[i] = _pos[i]
	_last_frame = frame
	_live = true


func _wind() -> Vector3:
	if wind_response <= 0.0:
		return Vector3.ZERO
	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		return Vector3.ZERO
	var weather: Variant = game.get("weather")
	if weather == null:
		return Vector3.ZERO
	var t := Time.get_ticks_msec()
	var flutter := 0.75 + 0.5 * sin(t * 0.0037) * sin(t * 0.0011)
	return weather.wind * (1.0 + weather.gust) * wind_response * flutter


func _place_capsules() -> void:
	_world_caps.clear()
	var base := _skeleton.global_transform
	for capsule in _capsules:
		var pose: Transform3D = base * _skeleton.get_bone_global_pose(capsule[0])
		var a: Vector3 = pose * (capsule[1] as Vector3)
		var b: Vector3 = pose * (capsule[2] as Vector3)
		var ab := b - a
		_world_caps.append([a, ab, 1.0 / maxf(ab.length_squared(), 1e-8), capsule[3]])


func _step(frame: Transform3D, wind: Vector3) -> void:
	var pull := (Vector3(0.0, -9.8, 0.0) + wind) * STEP * STEP
	var keep := 1.0 - damping
	for j in _cols:
		var pinned := frame * _local[j]
		_pos[j] = pinned
		_prev[j] = pinned
	for idx in range(_cols, _pos.size()):
		var p := _pos[idx]
		var moved := p + (p - _prev[idx]) * keep + pull
		if stiffness > 0.0:
			moved += (frame * _local[idx] - moved) * stiffness
		_prev[idx] = p
		_pos[idx] = moved
	for _iteration in iterations:
		for k in _link_a.size():
			var a := _link_a[k]
			var b := _link_b[k]
			var pa := _pos[a]
			var pb := _pos[b]
			var d := pb - pa
			var dist := d.length()
			if dist < 1e-6:
				continue
			var fix := d * ((dist - _link_len[k]) / dist * _link_k[k])
			if a < _cols:
				_pos[b] = pb - fix
			elif b < _cols:
				_pos[a] = pa + fix
			else:
				_pos[a] = pa + fix * 0.5
				_pos[b] = pb - fix * 0.5
	_collide()


func _collide() -> void:
	for idx in range(_cols, _pos.size()):
		var p := _pos[idx]
		var hit := false
		for capsule in _world_caps:
			var a: Vector3 = capsule[0]
			var ab: Vector3 = capsule[1]
			var r: float = capsule[3]
			var t := clampf((p - a).dot(ab) * (capsule[2] as float), 0.0, 1.0)
			var d := p - (a + ab * t)
			var dist2 := d.length_squared()
			if dist2 < r * r and dist2 > 1e-10:
				p += d * (r / sqrt(dist2) - 1.0)
				hit = true
		if hit:
			_pos[idx] = p
			# Velvet and hair drag on whatever they slide over.
			_prev[idx] = _prev[idx].lerp(p, 0.25)


# Render grid: each sim span gets a Catmull-Rom midpoint, so a coarse sim
# draws as a smooth surface.
func _prepare_render() -> void:
	_render_cols = (_cols - 1) * 2 + 1 if smooth_cols else _cols
	_render_rows = (_rows - 1) * 2 + 1 if smooth_rows else _rows
	var count := _render_cols * _render_rows
	_uvs.resize(count * card_layers)
	_colors.resize(count * card_layers)
	var width := 0.0
	for j in _cols - 1:
		width += _rest[j].distance_to(_rest[j + 1])
	var height := 0.0
	for i in _rows - 1:
		height += _rest[i * _cols].distance_to(_rest[(i + 1) * _cols])
	for layer in card_layers:
		for i in _render_rows:
			for j in _render_cols:
				var u := float(j) / float(_render_cols - 1)
				var v := float(i) / float(_render_rows - 1)
				var uv := Vector2(u * width, v * height)
				if card_uv and panel > 1:
					uv = Vector2(float(j % panel) / float(panel - 1) + 0.37 * float(layer), v)
				var idx := layer * count + i * _render_cols + j
				_uvs[idx] = uv
				var tone: Color = _trim.call(u, v)
				# Inner card_layers sit in each other's shade.
				_colors[idx] = Color(tone.r, tone.g, tone.b, tone.a).darkened(0.18 * float(card_layers - 1 - layer))
	_indices.clear()
	for layer in card_layers:
		var base := layer * count
		for i in _render_rows - 1:
			for j in _render_cols - 1:
				if _panel_edge(j):
					continue
				var a := base + i * _render_cols + j
				var b := a + 1
				var c := a + _render_cols
				var d := c + 1
				_indices.append_array([a, b, d, a, d, c])


func _rebuild() -> void:
	var grid := _pos
	if smooth_cols:
		grid = _refine_cols(grid)
	if smooth_rows:
		grid = _refine_rows(grid)
	var count := grid.size()
	var normals := PackedVector3Array()
	normals.resize(count)
	var tangents := PackedFloat32Array()
	tangents.resize(count * 4)
	for i in _render_rows:
		var row := i * _render_cols
		var up_row := maxi(i - 1, 0) * _render_cols
		var down_row := mini(i + 1, _render_rows - 1) * _render_cols
		for j in _render_cols:
			var j0 := j - 1
			var j1 := j + 1
			# Strips only look at their own columns for the sideways tangent.
			if j0 < 0 or (panel > 0 and _panel_edge(j0)):
				j0 = j
			if j1 >= _render_cols or (panel > 0 and _panel_edge(j)):
				j1 = j
			var du := grid[row + j1] - grid[row + j0]
			var dv := grid[down_row + j] - grid[up_row + j]
			var n := dv.cross(du)
			var idx := row + j
			normals[idx] = n.normalized() if n.length_squared() > 1e-12 else Vector3.UP
			var t := du.normalized() if du.length_squared() > 1e-12 else Vector3.RIGHT
			tangents[idx * 4] = t.x
			tangents[idx * 4 + 1] = t.y
			tangents[idx * 4 + 2] = t.z
			tangents[idx * 4 + 3] = 1.0
	if card_layers > 1:
		var stacked := PackedVector3Array()
		stacked.resize(count * card_layers)
		var stacked_normals := PackedVector3Array()
		stacked_normals.resize(count * card_layers)
		var stacked_tangents := PackedFloat32Array()
		stacked_tangents.resize(count * card_layers * 4)
		for layer in card_layers:
			var lift := layer_gap * float(layer)
			for idx in count:
				stacked[layer * count + idx] = grid[idx] + normals[idx] * lift
				stacked_normals[layer * count + idx] = normals[idx]
				for c in 4:
					stacked_tangents[(layer * count + idx) * 4 + c] = tangents[idx * 4 + c]
		grid = stacked
		normals = stacked_normals
		tangents = stacked_tangents
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = grid
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


# Doubles the columns of every sim row.
func _refine_cols(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(_rows * _render_cols)
	for i in _rows:
		var row := i * _cols
		var dst := i * _render_cols
		for j in _cols:
			out[dst + j * 2] = points[row + j]
			if j + 1 < _cols:
				var p0 := points[row + maxi(j - 1, 0)]
				var p3 := points[row + mini(j + 2, _cols - 1)]
				out[dst + j * 2 + 1] = (points[row + j] + points[row + j + 1]) * 0.5625 - (p0 + p3) * 0.0625
	return out


# Doubles the rows of a grid that already has render columns.
func _refine_rows(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(_render_rows * _render_cols)
	for j in _render_cols:
		for i in _rows:
			out[i * 2 * _render_cols + j] = points[i * _render_cols + j]
			if i + 1 < _rows:
				var p0 := points[maxi(i - 1, 0) * _render_cols + j]
				var p3 := points[mini(i + 2, _rows - 1) * _render_cols + j]
				out[(i * 2 + 1) * _render_cols + j] = (points[i * _render_cols + j] + points[(i + 1) * _render_cols + j]) * 0.5625 - (p0 + p3) * 0.0625
	return out
