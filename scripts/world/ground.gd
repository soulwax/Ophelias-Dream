class_name Ground
extends Node3D

# The land: one height function from the seed, built in layers, and one snow
# weight shared by every system that cares where the snow lies.
#
# Height: warped hills; a gentle valley along the route with banks rising
# either side; cliff bands winding across hillsides; one ravine the route runs
# through; ridged mountains rising away from the story; a ring of peaks at the
# world's edge. The house sits on a flat pad.
#
# Snow (snow_at, 0 green .. 1 snow): snow wherever the story happens, mostly
# snow within SNOW_CORE_IN of it, and beyond that a biome noise, greener to the
# north-east and north-west, partly to the south-east (north is -Z), snowy
# again on high peaks. Every edge between them is a thaw band.
#
# The mesh is built in CHUNK_SIZE squares, finer near the story. Where a fine
# chunk meets a coarser one its edge is stitched onto the coarse edge, so the
# land and its collision are continuous across every seam.
#
# Bump TERRAIN_REVISION whenever the land's shape changes, so an older
# editable-level snapshot does not lay its saved ground over the new one.
const TERRAIN_REVISION := 3
# Coarse grid (metres) for the route fields: distance to the path and to the
# story, the valley floor's height and the ravine's weight.
const FIELD_CELL := 6.0
# The valley floor is the hills along the route, sampled this often (metres).
const PROFILE_STEP := 2.0
# Steeper than this (cos 55°) is a cliff face.
const CLIFF_FACE := 0.574

var seed_value := 1701
# The route the land is shaped around (in this node's space) and the played
# stretch of it, from the start to the exit. Set before the ground is ready.
var route: Curve3D
var route_from := 0.0
var route_to := 0.0
# Where the story happens besides the route itself: the house, the camp, the
# lookout, the pages. Set before the ground is ready.
var story_points := PackedVector3Array()
# The middle of the story, which bearings for the biome bias are taken from.
var story_centre := Vector3.ZERO

# Flat pads (the house sits on one): [Vector2 centre, inner radius, outer
# radius]. Inside the inner radius the land is level at the height it had at
# the centre; it blends back out by the outer radius.
var pads: Array = []
# Cuts: [Transform3D local-to-world, Rect2 local x/z]. Cells touching a cut are
# left out of the mesh and the collision (the stair well).
var cuts: Array = []
var _pad_heights: Array[float] = []
# The ground's material, so patches can match it exactly.
var snow_material: ShaderMaterial
var _terrain_material: ShaderMaterial
# What was built, for probes.
var build_msec := 0
var cliff_cells := 0
var rock_count := 0
var chunks_x := 1
var chunks_z := 1

var _chunk_cell := PackedFloat32Array()
var _chunk_points := PackedInt32Array()
var _chunk_heights: Array[PackedFloat32Array] = []
var _chunk_normals: Array[PackedVector3Array] = []

var _hills := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _cliff := FastNoiseLite.new()
var _cliff_zone := FastNoiseLite.new()
var _cliff_rise := FastNoiseLite.new()
var _mountain := FastNoiseLite.new()
var _biome := FastNoiseLite.new()
var _snow_wobble := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _dirt := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()

var _field_size := Vector2i(1, 1)
var _route_distance := PackedFloat32Array()
var _story_distance := PackedFloat32Array()
var _valley_floor := PackedFloat32Array()
var _ravine := PackedFloat32Array()
var _snow_distance := PackedFloat32Array()


func _ready() -> void:
	set_meta("terrain_revision", TERRAIN_REVISION)
	var started := Time.get_ticks_msec()
	_rng.seed = seed_value + 404
	_configure_noise()
	_build_fields()
	_build_chunks()
	_build_edge()
	build_msec = Time.get_ticks_msec() - started


func height_at(x: float, z: float) -> float:
	if _chunk_heights.is_empty():
		return 0.0
	var cx := clampi(int(floor((x - Tune.WORLD_MIN_X) / Tune.CHUNK_SIZE)), 0, chunks_x - 1)
	var cz := clampi(int(floor((z - Tune.WORLD_MIN_Z) / Tune.CHUNK_SIZE)), 0, chunks_z - 1)
	var index := cz * chunks_x + cx
	var cell := _chunk_cell[index]
	var points := _chunk_points[index]
	var heights := _chunk_heights[index]
	var fx := clampf((x - Tune.WORLD_MIN_X - float(cx) * Tune.CHUNK_SIZE) / cell, 0.0, float(points - 1))
	var fz := clampf((z - Tune.WORLD_MIN_Z - float(cz) * Tune.CHUNK_SIZE) / cell, 0.0, float(points - 1))
	var x0 := mini(int(floor(fx)), points - 2)
	var z0 := mini(int(floor(fz)), points - 2)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var h00 := heights[z0 * points + x0]
	var h10 := heights[z0 * points + x0 + 1]
	var h01 := heights[(z0 + 1) * points + x0]
	var h11 := heights[(z0 + 1) * points + x0 + 1]
	# The mesh/collider diagonal is 00..11, not a bilinear patch.
	if tx >= tz:
		return h00 + tx * (h10 - h00) + tz * (h11 - h10)
	return h00 + tz * (h01 - h00) + tx * (h11 - h01)


# The walkable triangle's up direction at (x, z). Vertex normals remain
# smoothed for rendering, but must not spread a wall's slope onto its floor.
func normal_at(x: float, z: float) -> Vector3:
	if _chunk_heights.is_empty():
		return Vector3.UP
	var cx := clampi(int(floor((x - Tune.WORLD_MIN_X) / Tune.CHUNK_SIZE)), 0, chunks_x - 1)
	var cz := clampi(int(floor((z - Tune.WORLD_MIN_Z) / Tune.CHUNK_SIZE)), 0, chunks_z - 1)
	var index := cz * chunks_x + cx
	var cell := _chunk_cell[index]
	var points := _chunk_points[index]
	var fx := clampf((x - Tune.WORLD_MIN_X - float(cx) * Tune.CHUNK_SIZE) / cell, 0.0, float(points - 1))
	var fz := clampf((z - Tune.WORLD_MIN_Z - float(cz) * Tune.CHUNK_SIZE) / cell, 0.0, float(points - 1))
	var ix := mini(int(floor(fx)), points - 2)
	var iz := mini(int(floor(fz)), points - 2)
	var heights := _chunk_heights[index]
	var h00 := heights[iz * points + ix]
	var h10 := heights[iz * points + ix + 1]
	var h01 := heights[(iz + 1) * points + ix]
	var h11 := heights[(iz + 1) * points + ix + 1]
	var dx := h10 - h00 if fx - float(ix) >= fz - float(iz) else h11 - h01
	var dz := h11 - h10 if fx - float(ix) >= fz - float(iz) else h01 - h00
	return Vector3(-dx / cell, 1.0, -dz / cell).normalized()


# How steep the ground is at (x, z), in degrees.
func slope_at(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(normal_at(x, z).y, -1.0, 1.0)))


# Metres from the route's centre line; very far when there is no route.
func route_distance(x: float, z: float) -> float:
	return _field(_route_distance, x, z, 1.0e6)


# Metres from wherever the story happens: the route, the house, the camp, the
# lookout, the pages.
func story_distance(x: float, z: float) -> float:
	return _field(_story_distance, x, z, 1.0e6)


# 0 green .. 1 snow at (x, z).
func snow_at(x: float, z: float) -> float:
	return _snow(x, z, height_at(x, z))


func _configure_noise() -> void:
	_setup(_hills, seed_value, Tune.TERRAIN_HILL_FREQ, 5)
	_setup(_warp, seed_value + 1, Tune.TERRAIN_HILL_FREQ * 1.7, 2)
	_setup(_detail, seed_value + 2, 0.045, 2)
	_setup(_cliff, seed_value + 3, Tune.CLIFF_FREQ, 3)
	_setup(_cliff_zone, seed_value + 4, 0.006, 2)
	_setup(_cliff_rise, seed_value + 5, 0.02, 1)
	_setup(_mountain, seed_value + 6, Tune.MOUNTAIN_FREQ, 5)
	_mountain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_setup(_biome, seed_value + 7, Tune.BIOME_FREQ, 3)
	_setup(_snow_wobble, seed_value + 8, 0.012, 2)
	_setup(_patch, seed_value + 9, 0.03, 2)
	_setup(_dirt, seed_value + 10, 0.02, 3)


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


func _build_fields() -> void:
	_field_size = Vector2i(int(ceil((Tune.WORLD_MAX_X - Tune.WORLD_MIN_X) / FIELD_CELL)) + 1, int(ceil((Tune.WORLD_MAX_Z - Tune.WORLD_MIN_Z) / FIELD_CELL)) + 1)
	var count := _field_size.x * _field_size.y
	_route_distance.resize(count)
	_story_distance.resize(count)
	_valley_floor.resize(count)
	_ravine.resize(count)
	if route == null or route.get_baked_length() <= 0.0:
		_route_distance.fill(1.0e6)
		_story_distance.fill(1.0e6)
		_valley_floor.fill(0.0)
		_ravine.fill(0.0)
		return
	# The story's middle: the played route, evenly sampled, and its places.
	var sum := Vector3.ZERO
	var samples := 0
	var along := route_from
	while along <= route_to:
		sum += route.sample_baked(along)
		samples += 1
		along += 10.0
	for point in story_points:
		sum += point
		samples += 1
	story_centre = sum / float(maxi(samples, 1))
	story_centre.y = 0.0
	var profile := _valley_profile()
	var span := maxf(route_to - route_from, 1.0)
	for j in _field_size.y:
		for i in _field_size.x:
			var p := Vector3(Tune.WORLD_MIN_X + float(i) * FIELD_CELL, 0.0, Tune.WORLD_MIN_Z + float(j) * FIELD_CELL)
			var offset := route.get_closest_offset(p)
			var on := route.sample_baked(offset)
			var index := j * _field_size.x + i
			var distance := Vector2(p.x - on.x, p.z - on.z).length()
			_route_distance[index] = distance
			var story := distance
			for point in story_points:
				story = minf(story, Vector2(p.x - point.x, p.z - point.z).length())
			_story_distance[index] = story
			var at := offset / PROFILE_STEP
			var k := clampi(int(floor(at)), 0, profile.size() - 1)
			_valley_floor[index] = lerpf(profile[k], profile[mini(k + 1, profile.size() - 1)], at - floor(at))
			var t := (offset - route_from) / span
			_ravine[index] = smoothstep(Tune.RAVINE_FROM, Tune.RAVINE_FROM + 0.05, t) * (1.0 - smoothstep(Tune.RAVINE_TO - 0.05, Tune.RAVINE_TO, t))


# A coarse field, bilinear between its nodes.
func _field(values: PackedFloat32Array, x: float, z: float, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var fx := clampf((x - Tune.WORLD_MIN_X) / FIELD_CELL, 0.0, float(_field_size.x - 1))
	var fz := clampf((z - Tune.WORLD_MIN_Z) / FIELD_CELL, 0.0, float(_field_size.y - 1))
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, _field_size.x - 1)
	var z1 := mini(z0 + 1, _field_size.y - 1)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var a := lerpf(values[z0 * _field_size.x + x0], values[z0 * _field_size.x + x1], tx)
	var b := lerpf(values[z1 * _field_size.x + x0], values[z1 * _field_size.x + x1], tx)
	return lerpf(a, b, tz)


# Metres inside the world's edge (negative outside it).
func _edge_distance(x: float, z: float) -> float:
	return minf(minf(x - Tune.WORLD_MIN_X, Tune.WORLD_MAX_X - x), minf(z - Tune.WORLD_MIN_Z, Tune.WORLD_MAX_Z - z))


func _sample(x: float, z: float) -> float:
	var distance := _field(_route_distance, x, z, 1.0e6)
	var story := _field(_story_distance, x, z, 1.0e6)
	var h := _hills_at(x, z)
	# Banks rise away from the path; near it the land eases onto the floor.
	h += minf(maxf(distance - Tune.VALLEY_HALF, 0.0) * Tune.VALLEY_BANK, Tune.VALLEY_BANK_MAX)
	var on_floor := 1.0 - smoothstep(Tune.VALLEY_HALF * 0.6, Tune.VALLEY_HALF * 2.0, distance)
	h = lerpf(h, _field(_valley_floor, x, z, h), on_floor)
	h += _cliffs(x, z, distance)
	var walls := smoothstep(Tune.RAVINE_INNER, Tune.RAVINE_OUTER, distance) * (1.0 - smoothstep(40.0, 70.0, distance))
	h += _field(_ravine, x, z, 0.0) * walls * Tune.RAVINE_RISE
	# Mountains rise away from the story: ridged, highest along their crests.
	var ridge := _mountain.get_noise_2d(x, z) * 0.5 + 0.5
	h += ridge * ridge * Tune.MOUNTAIN_RELIEF * smoothstep(Tune.MOUNTAIN_FROM, Tune.MOUNTAIN_FULL, story)
	# A ring of peaks walls the world in.
	var edge := _edge_distance(x, z)
	h += (1.0 - smoothstep(0.0, Tune.RING_WIDTH, edge)) * Tune.RING_HEIGHT * (0.75 + 0.25 * ridge)
	for index in _pad_heights.size():
		var pad: Array = pads[index]
		var centre: Vector2 = pad[0]
		var level := 1.0 - smoothstep(pad[1], pad[2], Vector2(x, z).distance_to(centre))
		h = lerpf(h, _pad_heights[index], level)
	return h


# Mesa edges: where the cliff noise crosses its threshold the ground steps up
# several metres within a couple, so cliff lines follow the noise's contours.
# On chosen hillsides, never near the route, the world's edge or a pad; where
# that allowance fades, a cliff softens into a slope.
func _cliffs(x: float, z: float, distance: float) -> float:
	var allowed := smoothstep(0.05, 0.25, _cliff_zone.get_noise_2d(x, z))
	allowed *= smoothstep(Tune.CLIFF_CLEAR, Tune.CLIFF_CLEAR + 15.0, distance)
	allowed *= smoothstep(Tune.CLIFF_FENCE + Tune.RING_WIDTH, Tune.CLIFF_FENCE + Tune.RING_WIDTH + 4.0, _edge_distance(x, z))
	for pad: Array in pads:
		allowed *= smoothstep(float(pad[2]), float(pad[2]) + 15.0, Vector2(x, z).distance_to(pad[0]))
	if allowed <= 0.0:
		return 0.0
	var step := smoothstep(Tune.CLIFF_THRESHOLD, Tune.CLIFF_THRESHOLD + Tune.CLIFF_SHARPNESS, _cliff.get_noise_2d(x, z))
	var rise := lerpf(Tune.CLIFF_RISE_MIN, Tune.CLIFF_RISE_MAX, _cliff_rise.get_noise_2d(x, z) * 0.5 + 0.5)
	return step * rise * allowed


# Snow, given the height there.
func _snow(x: float, z: float, h: float) -> float:
	if not _snow_distance.is_empty():
		if story_distance(x, z) < Tune.SNOW_FORCE:
			return 1.0
		# smoothstep(-a,+a) has its 0.2..0.8 span at 0.4257185*a*2.
		var half_band := Tune.BIOME_THAW / 0.851437
		return smoothstep(-half_band, half_band, _field(_snow_distance, x, z, half_band))
	return _raw_snow(x, z, h)


func _raw_snow(x: float, z: float, h: float) -> float:
	var story := _field(_story_distance, x, z, 1.0e6)
	if story < Tune.SNOW_FORCE:
		return 1.0
	# The core: snow, fading out round SNOW_CORE_IN..SNOW_CORE_OUT, its edge
	# wandering a little; past SNOW_PATCH_CLEAR a few green patches break it.
	var wobble := _snow_wobble.get_noise_2d(x, z) * 20.0
	var core := 1.0 - smoothstep(Tune.SNOW_CORE_IN - 20.0 + wobble, Tune.SNOW_CORE_OUT + 30.0 + wobble, story)
	if story > Tune.SNOW_PATCH_CLEAR:
		var patch := smoothstep(0.45, 0.6, _patch.get_noise_2d(x, z))
		core *= 1.0 - 0.8 * patch * smoothstep(Tune.SNOW_PATCH_CLEAR, Tune.SNOW_PATCH_CLEAR + 30.0, story)
	# Beyond it, the biome: noise, pushed greener by bearing, snowy on peaks.
	var b := _biome.get_noise_2d(x, z) + _bias(x, z) - smoothstep(Tune.BIOME_SNOWLINE, Tune.BIOME_SNOWLINE + 30.0, h)
	var biome := 1.0 - smoothstep(-0.3, 0.3, b)
	return clampf(maxf(core, biome), 0.0, 1.0)


# Redistance the combined field, including core/patch unions and altitude.
# Seed exact interpolated S=.5 crossings, then propagate nearest edge points.
# Unlike a noise-space width, this remains in world metres on steep snowlines.
func _build_snow_field() -> void:
	var count := _field_size.x * _field_size.y
	var raw := PackedFloat32Array()
	raw.resize(count)
	var nearest := PackedVector2Array()
	nearest.resize(count)
	nearest.fill(Vector2(1.0e6, 1.0e6))
	for j in _field_size.y:
		for i in _field_size.x:
			var x := Tune.WORLD_MIN_X + float(i) * FIELD_CELL
			var z := Tune.WORLD_MIN_Z + float(j) * FIELD_CELL
			raw[j * _field_size.x + i] = _raw_snow(x, z, _sample(x, z))
	# Sub-band islands cannot contain both threshold endpoints. Smooth their
	# competing edges before redistancing rather than spreading narrow holes
	# across the snowy core. A separable 54 m box filters terrain/noise detail.
	var horizontal := PackedFloat32Array()
	horizontal.resize(count)
	for j in _field_size.y:
		for i in _field_size.x:
			var total := 0.0
			for k in range(-4, 5):
				total += raw[j * _field_size.x + clampi(i + k, 0, _field_size.x - 1)]
			horizontal[j * _field_size.x + i] = total / 9.0
	for j in _field_size.y:
		for i in _field_size.x:
			var total := 0.0
			for k in range(-4, 5):
				total += horizontal[clampi(j + k, 0, _field_size.y - 1) * _field_size.x + i]
			raw[j * _field_size.x + i] = total / 9.0
	for j in _field_size.y:
		for i in _field_size.x:
			var index := j * _field_size.x + i
			var at := Vector2(i, j) * FIELD_CELL
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var next := Vector2i(i, j) + offset
				if next.x >= _field_size.x or next.y >= _field_size.y:
					continue
				var other := next.y * _field_size.x + next.x
				if (raw[index] - 0.5) * (raw[other] - 0.5) > 0.0 or is_equal_approx(raw[index], raw[other]):
					continue
				var edge := at + Vector2(offset) * FIELD_CELL * ((0.5 - raw[index]) / (raw[other] - raw[index]))
				if at.distance_squared_to(edge) < at.distance_squared_to(nearest[index]):
					nearest[index] = edge
				var other_at := Vector2(next) * FIELD_CELL
				if other_at.distance_squared_to(edge) < other_at.distance_squared_to(nearest[other]):
					nearest[other] = edge
	for sweep in 2:
		var direction := 1 if sweep == 0 else -1
		var offsets: Array[Vector2i] = [Vector2i(-direction, 0), Vector2i(0, -direction), Vector2i(-direction, -direction), Vector2i(direction, -direction)]
		for row in _field_size.y:
			var j := row if sweep == 0 else _field_size.y - 1 - row
			for column in _field_size.x:
				var i := column if sweep == 0 else _field_size.x - 1 - column
				var index := j * _field_size.x + i
				var at := Vector2(i, j) * FIELD_CELL
				for offset in offsets:
					var next := Vector2i(i, j) + offset
					if next.x < 0 or next.y < 0 or next.x >= _field_size.x or next.y >= _field_size.y:
						continue
					var edge := nearest[next.y * _field_size.x + next.x]
					if at.distance_squared_to(edge) < at.distance_squared_to(nearest[index]):
						nearest[index] = edge
	_snow_distance.resize(count)
	for j in _field_size.y:
		for i in _field_size.x:
			var index := j * _field_size.x + i
			_snow_distance[index] = (Vector2(i, j) * FIELD_CELL).distance_to(nearest[index]) * (1.0 if raw[index] >= 0.5 else -1.0)


# How much greener the land is by its bearing from the story. North is -Z.
func _bias(x: float, z: float) -> float:
	var away := Vector2(x - story_centre.x, z - story_centre.z)
	if away.length() < 1.0:
		return 0.0
	away = away.normalized()
	var bias := 0.0
	bias += Tune.BIOME_NE * pow(maxf(away.dot(Vector2(1.0, -1.0).normalized()), 0.0), 2.0)
	bias += Tune.BIOME_NW * pow(maxf(away.dot(Vector2(-1.0, -1.0).normalized()), 0.0), 2.0)
	bias += Tune.BIOME_SE * pow(maxf(away.dot(Vector2(1.0, 1.0).normalized()), 0.0), 2.0)
	bias += Tune.BIOME_SW * pow(maxf(away.dot(Vector2(-1.0, 1.0).normalized()), 0.0), 2.0)
	return bias


func _cut(x0: float, z0: float, size_x: float, size_z: float) -> bool:
	for cut in cuts:
		var into: Transform3D = (cut[0] as Transform3D).affine_inverse()
		var rect: Rect2 = cut[1]
		# The cell, seen in the cut's frame, against the cut rectangle.
		var bounds := Rect2()
		var first := true
		for corner in [Vector3(x0, 0, z0), Vector3(x0 + size_x, 0, z0), Vector3(x0, 0, z0 + size_z), Vector3(x0 + size_x, 0, z0 + size_z)]:
			var local: Vector3 = into * corner
			if first:
				bounds = Rect2(local.x, local.z, 0, 0)
				first = false
			else:
				bounds = bounds.expand(Vector2(local.x, local.z))
		if bounds.intersects(rect):
			return true
	return false


# The cuts' extent on the ground, so only chunks under one test every cell.
func _cut_bounds() -> Rect2:
	var bounds := Rect2()
	var first := true
	for cut in cuts:
		var to_world: Transform3D = cut[0]
		var rect: Rect2 = cut[1]
		for corner in [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.position + Vector2(0.0, rect.size.y), rect.end]:
			var at: Vector3 = to_world * Vector3(corner.x, 0.0, corner.y)
			bounds = Rect2(at.x, at.z, 0, 0) if first else bounds.expand(Vector2(at.x, at.z))
			first = false
	return bounds.grow(2.0) if not first else Rect2()


func _chunk_cell_for(cx: int, cz: int) -> float:
	if cx < 0 or cz < 0 or cx >= chunks_x or cz >= chunks_z:
		return 0.0
	return _chunk_cell[cz * chunks_x + cx]


func _build_chunks() -> void:
	chunks_x = int(round((Tune.WORLD_MAX_X - Tune.WORLD_MIN_X) / Tune.CHUNK_SIZE))
	chunks_z = int(round((Tune.WORLD_MAX_Z - Tune.WORLD_MIN_Z) / Tune.CHUNK_SIZE))
	var count := chunks_x * chunks_z
	_chunk_cell.resize(count)
	_chunk_points.resize(count)
	_chunk_heights.resize(count)
	_chunk_normals.resize(count)
	# Cell size from how near the chunk comes to the story.
	for cz in chunks_z:
		for cx in chunks_x:
			var nearest := 1.0e6
			for sz in 5:
				for sx in 5:
					var x := Tune.WORLD_MIN_X + (float(cx) + float(sx) / 4.0) * Tune.CHUNK_SIZE
					var z := Tune.WORLD_MIN_Z + (float(cz) + float(sz) / 4.0) * Tune.CHUNK_SIZE
					nearest = minf(nearest, story_distance(x, z))
			var cell := Tune.CHUNK_CELL_FAR
			if nearest < Tune.CHUNK_NEAR:
				cell = Tune.CHUNK_CELL_NEAR
			elif nearest < Tune.CHUNK_MID:
				cell = Tune.CHUNK_CELL_MID
			_chunk_cell[cz * chunks_x + cx] = cell
	_pad_heights.clear()
	var raw: Array[float] = []
	for pad in pads:
		var centre := pad[0] as Vector2
		# The house apron meets the walking valley; using the unflattened hill
		# here creates a steep lip where the apron overlaps the route.
		raw.append(_field(_valley_floor, centre.x, centre.y, _sample(centre.x, centre.y)))
	_pad_heights = raw
	_build_snow_field()
	snow_material = _material()
	_terrain_material = snow_material.duplicate() as ShaderMaterial
	_terrain_material.set_shader_parameter("use_vertex_snow", true)
	var cut_area := _cut_bounds()
	cliff_cells = 0
	var root := Node3D.new()
	root.name = "Chunks"
	add_child(root)
	for cz in chunks_z:
		for cx in chunks_x:
			_build_chunk(root, cx, cz, cut_area)


func _build_chunk(root: Node3D, cx: int, cz: int, cut_area: Rect2) -> void:
	var index := cz * chunks_x + cx
	var cell := _chunk_cell[index]
	var cells := int(round(Tune.CHUNK_SIZE / cell))
	var points := cells + 1
	var x0 := Tune.WORLD_MIN_X + float(cx) * Tune.CHUNK_SIZE
	var z0 := Tune.WORLD_MIN_Z + float(cz) * Tune.CHUNK_SIZE
	# Heights with a one-cell border, so normals at the edges see past them.
	var wide := points + 2
	var padded := PackedFloat32Array()
	padded.resize(wide * wide)
	for j in wide:
		for i in wide:
			padded[j * wide + i] = _sample(x0 + float(i - 1) * cell, z0 + float(j - 1) * cell)
	var heights := PackedFloat32Array()
	heights.resize(points * points)
	var normals := PackedVector3Array()
	normals.resize(points * points)
	for j in points:
		for i in points:
			var c := (j + 1) * wide + (i + 1)
			heights[j * points + i] = padded[c]
			var dx := (padded[c + 1] - padded[c - 1]) / (2.0 * cell)
			var dz := (padded[c + wide] - padded[c - wide]) / (2.0 * cell)
			var n := Vector3(-dx, 1.0, -dz).normalized()
			normals[j * points + i] = n
			if n.y < CLIFF_FACE and cell <= Tune.CHUNK_CELL_NEAR:
				cliff_cells += 1
	# Stitch: along an edge shared with a coarser chunk, lie on its straight
	# edge between its vertices, so the two meet exactly.
	var sides := [[cx - 1, cz, true, 0], [cx + 1, cz, true, points - 1], [cx, cz - 1, false, 0], [cx, cz + 1, false, points - 1]]
	for side: Array in sides:
		var other := _chunk_cell_for(int(side[0]), int(side[1]))
		if other <= cell:
			continue
		var ratio := int(round(other / cell))
		for k in points:
			var r := k % ratio
			if r == 0:
				continue
			var a := k - r
			var b := mini(a + ratio, points - 1)
			var t := float(r) / float(ratio)
			if side[2]:
				var col: int = side[3]
				heights[k * points + col] = lerpf(heights[a * points + col], heights[b * points + col], t)
			else:
				var row: int = side[3]
				heights[row * points + k] = lerpf(heights[row * points + a], heights[row * points + b], t)
	# Refresh derivatives after stitching changes heights. Retain the raw
	# one-cell halo only outside this chunk, use final vertices inside it.
	for j in points:
		for i in points:
			padded[(j + 1) * wide + i + 1] = heights[j * points + i]
	for j in points:
		for i in points:
			var c := (j + 1) * wide + i + 1
			var dx := (padded[c + 1] - padded[c - 1]) / (2.0 * cell)
			var dz := (padded[c + wide] - padded[c - wide]) / (2.0 * cell)
			normals[j * points + i] = Vector3(-dx, 1.0, -dz).normalized()
	_chunk_cell[index] = cell
	_chunk_points[index] = points
	_chunk_heights[index] = heights
	_chunk_normals[index] = normals

	var vertices := PackedVector3Array()
	vertices.resize(points * points)
	var colors := PackedColorArray()
	colors.resize(points * points)
	for j in points:
		for i in points:
			var x := x0 + float(i) * cell
			var z := z0 + float(j) * cell
			var h := heights[j * points + i]
			vertices[j * points + i] = Vector3(x, h, z)
			colors[j * points + i] = Color(_snow(x, z, h), 0.0, 0.0, 1.0)
	var chunk_rect := Rect2(x0, z0, Tune.CHUNK_SIZE, Tune.CHUNK_SIZE)
	var cut_here := not cuts.is_empty() and cut_area.size != Vector2.ZERO and chunk_rect.intersects(cut_area)
	var kept := PackedByteArray()
	kept.resize(cells * cells)
	kept.fill(1)
	if cut_here:
		for j in cells:
			for i in cells:
				if _cut(x0 + float(i) * cell, z0 + float(j) * cell, cell, cell):
					kept[j * cells + i] = 0
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for j in cells:
		for i in cells:
			if kept[j * cells + i] == 0:
				continue
			var i00 := j * points + i
			var i10 := i00 + 1
			var i01 := i00 + points
			var i11 := i01 + 1
			# Clockwise seen from above: Godot's front face. (Counter-clockwise
			# was culled from above, so for a long time the "snow" on screen
			# was only the sky colour behind an invisible terrain.)
			for tri in [[i00, i11, i01], [i00, i10, i11]]:
				for corner: int in tri:
					indices.append(corner)
					faces.append(vertices[corner])
	if cut_here:
		_add_depth(vertices, normals, colors, indices, kept, cells, points)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var chunk := MeshInstance3D.new()
	chunk.name = "Chunk_%d_%d" % [cx, cz]
	chunk.mesh = mesh
	chunk.material_override = _terrain_material
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(chunk)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.data = faces
	concave.backface_collision = true
	shape.shape = concave
	body.add_child(shape)
	chunk.add_child(body)


# Where cells are cut out (the stair well), the snow shows its depth: the pack
# continues SNOW_DEPTH straight down, with a wall along every cut edge.
func _add_depth(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, kept: PackedByteArray, cells: int, points: int) -> void:
	var lips: Array[Vector3] = []
	for j in cells:
		for i in cells:
			if kept[j * cells + i] == 0:
				continue
			var i00 := j * points + i
			var i10 := i00 + 1
			var i01 := i00 + points
			var i11 := i01 + 1
			if i > 0 and kept[j * cells + i - 1] == 0:
				lips.append(vertices[i01])
				lips.append(vertices[i00])
			if i < cells - 1 and kept[j * cells + i + 1] == 0:
				lips.append(vertices[i10])
				lips.append(vertices[i11])
			if j > 0 and kept[(j - 1) * cells + i] == 0:
				lips.append(vertices[i00])
				lips.append(vertices[i10])
			if j < cells - 1 and kept[(j + 1) * cells + i] == 0:
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
		for k in 4:
			normals.append(outward)
			colors.append(Color(1.0, 0.0, 0.0, 1.0))
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)


# An invisible wall just inside the world's edge, behind the ring of peaks.
func _build_edge() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldEdge"
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var inset := 12.0
	var width := Tune.WORLD_MAX_X - Tune.WORLD_MIN_X
	var depth := Tune.WORLD_MAX_Z - Tune.WORLD_MIN_Z
	var centre := Vector3((Tune.WORLD_MIN_X + Tune.WORLD_MAX_X) * 0.5, 0.0, (Tune.WORLD_MIN_Z + Tune.WORLD_MAX_Z) * 0.5)
	var walls := [
		[Vector3(Tune.WORLD_MIN_X + inset - 2.0, 0.0, centre.z), Vector3(4.0, 800.0, depth)],
		[Vector3(Tune.WORLD_MAX_X - inset + 2.0, 0.0, centre.z), Vector3(4.0, 800.0, depth)],
		[Vector3(centre.x, 0.0, Tune.WORLD_MIN_Z + inset - 2.0), Vector3(width, 800.0, 4.0)],
		[Vector3(centre.x, 0.0, Tune.WORLD_MAX_Z - inset + 2.0), Vector3(width, 800.0, 4.0)],
	]
	for wall: Array in walls:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		shape.shape = box
		shape.position = wall[0]
		body.add_child(shape)
	add_child(body)


func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/snow_ground.gdshader")
	if ResourceLoader.exists("res://assets/environment/Snow_01.png"):
		material.set_shader_parameter("snow_tex", load("res://assets/environment/Snow_01.png"))
	material.set_shader_parameter("dirt_tex", _dirt_texture())
	material.set_shader_parameter("snow_depth", Tune.SNOW_DEPTH)
	material.set_shader_parameter("lean_graphics", Game.lean_graphics)
	material.set_shader_parameter("use_vertex_snow", false)
	material.set_shader_parameter("snow_default", 1.0)
	var maps := {
		"green_tex": "forrest_ground_01/forrest_ground_01_diff_1k.jpg",
		"grass_tex": "aerial_grass_rock/aerial_grass_rock_diff_1k.jpg",
		"mud_tex": "brown_mud_leaves_01/brown_mud_leaves_01_diff_1k.jpg",
		"green_normal": "forrest_ground_01/forrest_ground_01_nor_gl_1k.jpg",
		"grass_normal": "aerial_grass_rock/aerial_grass_rock_nor_gl_1k.jpg",
		"mud_normal": "brown_mud_leaves_01/brown_mud_leaves_01_nor_gl_1k.jpg",
	}
	var complete := true
	for uniform: String in maps:
		var path: String = "res://assets/vendor/polyhaven/" + maps[uniform]
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture != null:
				material.set_shader_parameter(uniform, texture)
			else:
				complete = false
		else:
			complete = false
	if not complete:
		push_warning("Ground biome textures missing; using procedural earth. Run py tools/fetch_ground_textures.py and reimport.")
	material.set_shader_parameter("ground_textures", complete)
	return material


func _dirt_texture() -> ImageTexture:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var n := _dirt.get_noise_2d(float(x) * 2.0, float(y) * 2.0) * 0.5 + 0.5
			image.set_pixel(x, y, Color(n, n, n))
	return ImageTexture.create_from_image(image)
