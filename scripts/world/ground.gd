class_name Ground
extends Node3D

# The snow field: one heightfield from the seed, built in layers. Warped hills,
# a gentle valley along the route with banks rising either side, cliff bands
# that wind across the hillsides and the field's edges, one ravine the route
# runs through, and a rim beyond the fence.
# Bump TERRAIN_REVISION whenever the land's shape changes, so an older
# editable-level snapshot does not lay its saved ground over the new one.
const TERRAIN_REVISION := 2
# Coarse grid (metres) for the route fields: distance to the path, the valley
# floor's height and the ravine's weight, read bilinearly between nodes.
const ROUTE_CELL := 6.0
# The valley floor is the hills along the route, sampled this often (metres).
const PROFILE_STEP := 2.0
# Steeper than this (cos 55°) is a cliff face.
const CLIFF_FACE := 0.574

var seed_value := 1701
# The route the land is shaped around (in this node's space), and the played
# stretch of it, from the start to the exit.
var route: Curve3D
var route_from := 0.0
var route_to := 0.0

var _heights := PackedFloat32Array()
var _normals := PackedVector3Array()
var _origin_x := 0.0
var _origin_z := 0.0
var _step_x := 1.0
var _step_z := 1.0
var _points_x := 2
var _points_z := 2

# Flat pads (the house sits on one): [Vector2 centre, inner radius, outer
# radius]. Inside the inner radius the snow is level at the height the land
# had at the centre; it blends back out by the outer radius.
var pads: Array = []
# Cuts: [Transform3D local-to-world, Rect2 local x/z]. Grid cells touching a
# cut are left out of the mesh and the collision (the stair well).
var cuts: Array = []
var _pad_heights: Array[float] = []
# The snow's material, so patches can match it exactly.
var snow_material: ShaderMaterial
# What was built, for probes.
var build_msec := 0
var cliff_cells := 0
var rock_count := 0

var _hills := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _cliff := FastNoiseLite.new()
var _cliff_zone := FastNoiseLite.new()
var _cliff_rise := FastNoiseLite.new()
var _dirt := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()

var _field_origin := Vector2.ZERO
var _field_size := Vector2i(1, 1)
var _route_distance := PackedFloat32Array()
var _valley_floor := PackedFloat32Array()
var _ravine := PackedFloat32Array()


func _ready() -> void:
	set_meta("terrain_revision", TERRAIN_REVISION)
	var started := Time.get_ticks_msec()
	_rng.seed = seed_value + 404
	_configure_noise()
	_build_route_fields()
	_build()
	build_msec = Time.get_ticks_msec() - started


func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var fx := clampf((x - _origin_x) / _step_x, 0.0, float(_points_x - 1))
	var fz := clampf((z - _origin_z) / _step_z, 0.0, float(_points_z - 1))
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, _points_x - 1)
	var z1 := mini(z0 + 1, _points_z - 1)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var h00 := _heights[z0 * _points_x + x0]
	var h10 := _heights[z0 * _points_x + x1]
	var h01 := _heights[z1 * _points_x + x0]
	var h11 := _heights[z1 * _points_x + x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


# The ground's up direction at the grid point nearest (x, z).
func normal_at(x: float, z: float) -> Vector3:
	if _normals.is_empty():
		return Vector3.UP
	var ix := clampi(int(round((x - _origin_x) / _step_x)), 0, _points_x - 1)
	var iz := clampi(int(round((z - _origin_z) / _step_z)), 0, _points_z - 1)
	return _normals[iz * _points_x + ix]


# How steep the ground is at (x, z), in degrees.
func slope_at(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(normal_at(x, z).y, -1.0, 1.0)))


# Metres from the route's centre line; very far when there is no route.
func route_distance(x: float, z: float) -> float:
	return _field(_route_distance, x, z, 1.0e6)


func _configure_noise() -> void:
	_setup(_hills, seed_value, Tune.TERRAIN_HILL_FREQ, 5)
	_setup(_warp, seed_value + 1, Tune.TERRAIN_HILL_FREQ * 1.7, 2)
	_setup(_detail, seed_value + 2, 0.045, 2)
	_setup(_cliff, seed_value + 3, Tune.CLIFF_FREQ, 3)
	_setup(_cliff_zone, seed_value + 4, 0.006, 2)
	_setup(_cliff_rise, seed_value + 5, 0.02, 1)
	_setup(_dirt, seed_value + 6, 0.02, 3)


func _setup(noise: FastNoiseLite, noise_seed: int, frequency: float, octaves: int) -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves


# Rolling hills, warped so their ridges wander instead of repeating.
func _hills_at(x: float, z: float) -> float:
	var wx := x + _warp.get_noise_2d(x, z) * Tune.TERRAIN_WARP
	var wz := z + _warp.get_noise_2d(x + 517.0, z - 311.0) * Tune.TERRAIN_WARP
	return _hills.get_noise_2d(wx, wz) * Tune.TERRAIN_HILLS + _detail.get_noise_2d(x, z) * Tune.TERRAIN_DETAIL


# The walking floor along the route: the hills under it averaged over about
# 30 m, then no step steeper than VALLEY_GRADE.
func _valley_profile() -> PackedFloat32Array:
	var length := route.get_baked_length()
	var count := int(ceil(length / PROFILE_STEP)) + 1
	var raw := PackedFloat32Array()
	raw.resize(count)
	for k in count:
		var p := route.sample_baked(minf(float(k) * PROFILE_STEP, length))
		raw[k] = _hills_at(p.x, p.z)
	var half := int(15.0 / PROFILE_STEP)
	var smooth := PackedFloat32Array()
	smooth.resize(count)
	for k in count:
		var total := 0.0
		var samples := 0
		for m in range(maxi(k - half, 0), mini(k + half, count - 1) + 1):
			total += raw[m]
			samples += 1
		smooth[k] = total / float(samples)
	var rise := Tune.VALLEY_GRADE * PROFILE_STEP
	for k in range(1, count):
		smooth[k] = clampf(smooth[k], smooth[k - 1] - rise, smooth[k - 1] + rise)
	return smooth


func _build_route_fields() -> void:
	var min_x := Tune.FENCE_MIN_X - Tune.GROUND_PAD
	var max_x := Tune.FENCE_MAX_X + Tune.GROUND_PAD
	var min_z := Tune.FENCE_MIN_Z - Tune.GROUND_PAD
	var max_z := Tune.FENCE_MAX_Z + Tune.GROUND_PAD
	_field_origin = Vector2(min_x, min_z)
	_field_size = Vector2i(int(ceil((max_x - min_x) / ROUTE_CELL)) + 1, int(ceil((max_z - min_z) / ROUTE_CELL)) + 1)
	var count := _field_size.x * _field_size.y
	_route_distance.resize(count)
	_valley_floor.resize(count)
	_ravine.resize(count)
	if route == null or route.get_baked_length() <= 0.0:
		_route_distance.fill(1.0e6)
		_valley_floor.fill(0.0)
		_ravine.fill(0.0)
		return
	var profile := _valley_profile()
	var span := maxf(route_to - route_from, 1.0)
	for j in _field_size.y:
		for i in _field_size.x:
			var p := Vector3(_field_origin.x + float(i) * ROUTE_CELL, 0.0, _field_origin.y + float(j) * ROUTE_CELL)
			var offset := route.get_closest_offset(p)
			var on := route.sample_baked(offset)
			var index := j * _field_size.x + i
			_route_distance[index] = Vector2(p.x - on.x, p.z - on.z).length()
			var at := offset / PROFILE_STEP
			var k := clampi(int(floor(at)), 0, profile.size() - 1)
			_valley_floor[index] = lerpf(profile[k], profile[mini(k + 1, profile.size() - 1)], at - floor(at))
			var t := (offset - route_from) / span
			_ravine[index] = smoothstep(Tune.RAVINE_FROM, Tune.RAVINE_FROM + 0.05, t) * (1.0 - smoothstep(Tune.RAVINE_TO - 0.05, Tune.RAVINE_TO, t))


# A coarse route field, bilinear between its nodes.
func _field(values: PackedFloat32Array, x: float, z: float, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var fx := clampf((x - _field_origin.x) / ROUTE_CELL, 0.0, float(_field_size.x - 1))
	var fz := clampf((z - _field_origin.y) / ROUTE_CELL, 0.0, float(_field_size.y - 1))
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, _field_size.x - 1)
	var z1 := mini(z0 + 1, _field_size.y - 1)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var a := lerpf(values[z0 * _field_size.x + x0], values[z0 * _field_size.x + x1], tx)
	var b := lerpf(values[z1 * _field_size.x + x0], values[z1 * _field_size.x + x1], tx)
	return lerpf(a, b, tz)


# Metres inside the fence (negative outside it).
func _fence_distance(x: float, z: float) -> float:
	return minf(minf(x - Tune.FENCE_MIN_X, Tune.FENCE_MAX_X - x), minf(z - Tune.FENCE_MIN_Z, Tune.FENCE_MAX_Z - z))


func _sample(x: float, z: float) -> float:
	var distance := _field(_route_distance, x, z, 1.0e6)
	var h := _hills_at(x, z)
	# Banks rise away from the path; near it the land eases onto the floor.
	h += minf(maxf(distance - Tune.VALLEY_HALF, 0.0) * Tune.VALLEY_BANK, Tune.VALLEY_BANK_MAX)
	var on_floor := 1.0 - smoothstep(Tune.VALLEY_HALF * 0.6, Tune.VALLEY_HALF * 2.0, distance)
	h = lerpf(h, _field(_valley_floor, x, z, h), on_floor)
	h += _cliffs(x, z, distance)
	var walls := smoothstep(Tune.RAVINE_INNER, Tune.RAVINE_OUTER, distance) * (1.0 - smoothstep(40.0, 70.0, distance))
	h += _field(_ravine, x, z, 0.0) * walls * Tune.RAVINE_RISE
	h += smoothstep(0.0, Tune.GROUND_PAD, -_fence_distance(x, z)) * Tune.TERRAIN_RIM
	for index in _pad_heights.size():
		var pad: Array = pads[index]
		var centre: Vector2 = pad[0]
		var level := 1.0 - smoothstep(pad[1], pad[2], Vector2(x, z).distance_to(centre))
		h = lerpf(h, _pad_heights[index], level)
	return h


# Mesa edges: where the cliff noise crosses its threshold the ground steps up
# several metres within a couple, so cliff lines follow the noise's contours.
# Only near the field's edges and on chosen hillsides, never near the route,
# the fence or a pad; where that allowance fades, a cliff softens into a slope.
func _cliffs(x: float, z: float, distance: float) -> float:
	var inside := _fence_distance(x, z)
	var edge := 1.0 - smoothstep(30.0, 60.0, inside)
	var hillside := smoothstep(0.05, 0.25, _cliff_zone.get_noise_2d(x, z))
	var allowed := maxf(edge, hillside)
	allowed *= smoothstep(Tune.CLIFF_CLEAR, Tune.CLIFF_CLEAR + 15.0, distance)
	allowed *= smoothstep(Tune.CLIFF_FENCE, Tune.CLIFF_FENCE + 4.0, inside)
	for pad: Array in pads:
		allowed *= smoothstep(float(pad[2]), float(pad[2]) + 15.0, Vector2(x, z).distance_to(pad[0]))
	if allowed <= 0.0:
		return 0.0
	var step := smoothstep(Tune.CLIFF_THRESHOLD, Tune.CLIFF_THRESHOLD + Tune.CLIFF_SHARPNESS, _cliff.get_noise_2d(x, z))
	var rise := lerpf(Tune.CLIFF_RISE_MIN, Tune.CLIFF_RISE_MAX, _cliff_rise.get_noise_2d(x, z) * 0.5 + 0.5)
	return step * rise * allowed


func _cut(x0: float, z0: float, size_x: float, size_z: float) -> bool:
	for cut in cuts:
		var to_local: Transform3D = (cut[0] as Transform3D).affine_inverse()
		var rect: Rect2 = cut[1]
		# The cell, seen in the cut's frame, against the cut rectangle.
		var bounds := Rect2()
		var first := true
		for corner in [Vector3(x0, 0, z0), Vector3(x0 + size_x, 0, z0), Vector3(x0, 0, z0 + size_z), Vector3(x0 + size_x, 0, z0 + size_z)]:
			var local: Vector3 = to_local * corner
			if first:
				bounds = Rect2(local.x, local.z, 0, 0)
				first = false
			else:
				bounds = bounds.expand(Vector2(local.x, local.z))
		if bounds.intersects(rect):
			return true
	return false


func _build() -> void:
	var min_x := Tune.FENCE_MIN_X - Tune.GROUND_PAD
	var max_x := Tune.FENCE_MAX_X + Tune.GROUND_PAD
	var min_z := Tune.FENCE_MIN_Z - Tune.GROUND_PAD
	var max_z := Tune.FENCE_MAX_Z + Tune.GROUND_PAD
	var cells_x := int(ceil((max_x - min_x) / Tune.GROUND_CELL))
	var cells_z := int(ceil((max_z - min_z) / Tune.GROUND_CELL))
	_points_x = cells_x + 1
	_points_z = cells_z + 1
	_origin_x = min_x
	_origin_z = min_z
	_step_x = (max_x - min_x) / float(cells_x)
	_step_z = (max_z - min_z) / float(cells_z)

	_pad_heights.clear()
	var raw: Array[float] = []
	for pad in pads:
		raw.append(_sample((pad[0] as Vector2).x, (pad[0] as Vector2).y))
	_pad_heights = raw

	var vertices := PackedVector3Array()
	vertices.resize(_points_x * _points_z)
	_heights.resize(_points_x * _points_z)
	for z in _points_z:
		for x in _points_x:
			var wx := _origin_x + float(x) * _step_x
			var wz := _origin_z + float(z) * _step_z
			var h := _sample(wx, wz)
			var index := z * _points_x + x
			_heights[index] = h
			vertices[index] = Vector3(wx, h, wz)

	# Normals from the heights themselves (central differences), so shading
	# runs smoothly across cells instead of showing the grid.
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	cliff_cells = 0
	for z in _points_z:
		var up := maxi(z - 1, 0)
		var down := mini(z + 1, _points_z - 1)
		for x in _points_x:
			var left := maxi(x - 1, 0)
			var right := mini(x + 1, _points_x - 1)
			var dx := (_heights[z * _points_x + right] - _heights[z * _points_x + left]) / (_step_x * float(right - left))
			var dz := (_heights[down * _points_x + x] - _heights[up * _points_x + x]) / (_step_z * float(down - up))
			var n := Vector3(-dx, 1.0, -dz).normalized()
			normals[z * _points_x + x] = n
			if n.y < CLIFF_FACE:
				cliff_cells += 1
	_normals = normals.duplicate()

	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	var kept := PackedByteArray()
	kept.resize(cells_x * cells_z)
	for z in cells_z:
		for x in cells_x:
			if not cuts.is_empty() and _cut(_origin_x + float(x) * _step_x, _origin_z + float(z) * _step_z, _step_x, _step_z):
				continue
			kept[z * cells_x + x] = 1
			var i00 := z * _points_x + x
			var i10 := i00 + 1
			var i01 := i00 + _points_x
			var i11 := i01 + 1
			# Clockwise seen from above: Godot's front face. (Counter-clockwise
			# was culled from above, so for a long time the "snow" on screen
			# was only the sky colour behind an invisible terrain.)
			for tri in [[i00, i11, i01], [i00, i10, i11]]:
				var a: int = tri[0]
				var b: int = tri[1]
				var c: int = tri[2]
				indices.append(a)
				indices.append(b)
				indices.append(c)
				faces.append(vertices[a])
				faces.append(vertices[b])
				faces.append(vertices[c])
	# The walkable surface is the top. The pack continues SNOW_DEPTH straight
	# down, with a wall wherever a cell was cut out, so the depth is real.
	var grid := vertices.size()
	var bottom := PackedVector3Array()
	bottom.resize(grid)
	var bottom_normals := PackedVector3Array()
	bottom_normals.resize(grid)
	for i in grid:
		var top := vertices[i]
		bottom[i] = Vector3(top.x, top.y - Tune.SNOW_DEPTH, top.z)
		bottom_normals[i] = -normals[i]
	vertices.append_array(bottom)
	normals.append_array(bottom_normals)
	var top_indices := indices.duplicate()
	for i in range(0, top_indices.size(), 3):
		indices.append(top_indices[i] + grid)
		indices.append(top_indices[i + 2] + grid)
		indices.append(top_indices[i + 1] + grid)
	var lips: Array[Vector3] = []
	for z in cells_z:
		for x in cells_x:
			if kept[z * cells_x + x] == 0:
				continue
			var i00 := z * _points_x + x
			var i10 := i00 + 1
			var i01 := i00 + _points_x
			var i11 := i01 + 1
			if not _cell(kept, cells_x, cells_z, x - 1, z):
				lips.append(vertices[i01])
				lips.append(vertices[i00])
			if not _cell(kept, cells_x, cells_z, x + 1, z):
				lips.append(vertices[i10])
				lips.append(vertices[i11])
			if not _cell(kept, cells_x, cells_z, x, z - 1):
				lips.append(vertices[i00])
				lips.append(vertices[i10])
			if not _cell(kept, cells_x, cells_z, x, z + 1):
				lips.append(vertices[i11])
				lips.append(vertices[i01])
	var lip := 0
	while lip < lips.size():
		var top_a := lips[lip]
		var top_b := lips[lip + 1]
		lip += 2
		var outward := Vector3.UP.cross(top_b - top_a)
		if outward.length_squared() < 0.0001:
			continue
		outward = outward.normalized()
		var base := vertices.size()
		vertices.append(top_a)
		vertices.append(top_b)
		vertices.append(Vector3(top_b.x, top_b.y - Tune.SNOW_DEPTH, top_b.z))
		vertices.append(Vector3(top_a.x, top_a.y - Tune.SNOW_DEPTH, top_a.z))
		normals.append(outward)
		normals.append(outward)
		normals.append(outward)
		normals.append(outward)
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SnowSurface"
	mesh_instance.mesh = mesh
	snow_material = _material()
	mesh_instance.material_override = snow_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "SnowShape"
	var concave := ConcavePolygonShape3D.new()
	concave.data = faces
	concave.backface_collision = true
	shape.shape = concave
	body.add_child(shape)
	add_child(body)


func _cell(kept: PackedByteArray, cells_x: int, cells_z: int, x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= cells_x or z >= cells_z:
		return false
	return kept[z * cells_x + x] != 0


func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/snow_ground.gdshader")
	if ResourceLoader.exists("res://assets/environment/Snow_01.png"):
		material.set_shader_parameter("snow_tex", load("res://assets/environment/Snow_01.png"))
	material.set_shader_parameter("dirt_tex", _dirt_texture())
	material.set_shader_parameter("snow_depth", Tune.SNOW_DEPTH)
	return material


func _dirt_texture() -> ImageTexture:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var n := _dirt.get_noise_2d(float(x) * 2.0, float(y) * 2.0) * 0.5 + 0.5
			image.set_pixel(x, y, Color(n, n, n))
	return ImageTexture.create_from_image(image)
