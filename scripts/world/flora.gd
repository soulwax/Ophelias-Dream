class_name Flora
extends Node3D

# The woods, grown by biome over the whole world from the level seed.
#
# A forest mask makes woods and clearings. Where the snow lies (Ground.snow_at
# above one half) they are the premium pines, a share of them great pines, plus
# a few lone giants beside the route; where it is green they are the forest
# pack's spruces and card trees, denser, with firs and bushes underneath and
# grass in the clearings. Nothing grows in the route's corridor, on landmarks
# or on steep ground. Steep cliffs near the route are dressed with rock faces.
#
# Everything is drawn as MultiMeshes, one per mesh part per FOREST_BATCH_SIZE square,
# each with a draw distance. Trunks collide through PhysicsServer3D, one static
# body per chunk, so thousands of trees are not thousands of nodes.
#
# Every random draw for a candidate is made before deciding, so lean graphics
# keeps a stable half of exactly the trees full graphics plants.

const PACK := "res://assets/vendor/sketchfab_forest/meshes/"
const SNOW_PINES: Array[String] = ["SM_Env_Pine_02.fbx", "SM_Env_Pine_03.fbx"]
const BARE_PINE := "SM_Env_Pine_NoLeaves_01.fbx"
const SPRUCES: Array[String] = ["spruce_a", "spruce_b", "spruce_c", "spruce_d", "spruce_e"]
const CARD_TREES: Array[String] = ["card_tree_a", "card_tree_b"]
const MOUNDS: Array[String] = ["SM_Env_Snow_Mound_01.fbx", "SM_Env_Snow_Mound_02.fbx", "SM_Env_Snow_Mound_03.fbx", "SM_Env_Snow_Mound_04.fbx"]
const LOGS: Array[String] = ["SM_Gen_Env_Log_01.fbx", "SM_Gen_Env_Log_02.fbx", "SM_Env_Pine_Stump_01.fbx"]
const BOULDERS: Array[String] = ["SM_Env_Rock_01.fbx", "SM_Env_Rock_02.fbx", "SM_Env_Rock_05.fbx", "SM_Env_Rock_08.fbx"]
const CLIFF_ROCK := "SM_Env_Rock_Cliff_02.fbx"
# Spatial hash cell for spacing and nearest-tree queries (metres).
const HASH := 8.0
const BATCH_REVISION := 1
const CACHE_REVISION := 1
const CACHE_DIR := "user://flora"

# Every tree: trunk base in world space, and its kind ("snow", "snow_bare",
# "snow_great", "snow_giant", "green", "green_card").
var trees := PackedVector3Array()
var tree_kinds: Array[String] = []
var giant_count := 0
var great_count := 0
# Ordinary trees (not great, not giants) the full world plants, and how many
# this graphics mode kept; likewise the undergrowth.
var ordinary_planned := 0
var ordinary_kept := 0
var undergrowth_planned := 0
var undergrowth_count := 0
var rock_count := 0
var build_msec := 0
var cache_hit := false

var _rng := RandomNumberGenerator.new()
var _woods := FastNoiseLite.new()
var _ground: Ground
var _curve: Curve3D
var _reserved: Array[Vector3] = []
# Spacing hash: cell key -> PackedVector4Array of (x, z, gap, 0).
var _taken: Dictionary = {}
# Tree hash: cell key -> PackedInt32Array of tree indices.
var _tree_cells: Dictionary = {}
# Batches: "model|chunk" -> Array[Transform3D]; and which are undergrowth.
var _batches: Dictionary = {}
var _batch_under: Dictionary = {}
# Mesh parts per model: Array of [Mesh, Transform3D, bool cast shadow].
var _parts: Dictionary = {}
# Trunks per chunk: chunk index -> Array of [Vector3 base, radius, height].
var _trunks: Dictionary = {}
var _bodies: Array[RID] = []
var _shapes: Dictionary = {}


func grow(ground: Ground, curve: Curve3D, reserved: Array[Vector3], seed_value: int = 1701) -> void:
	var started := Time.get_ticks_msec()
	set_meta("batch_revision", BATCH_REVISION)
	_ground = ground
	_curve = curve
	_reserved = reserved
	_rng.seed = seed_value + 88509
	_woods.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_woods.seed = seed_value - 1613
	_woods.frequency = Tune.FOREST_FREQ
	_woods.fractal_type = FastNoiseLite.FRACTAL_FBM
	_woods.fractal_octaves = 3
	var fingerprint := _cache_fingerprint(seed_value)
	var use_cache := OS.get_environment("RUN_TERRAIN_CACHE") != "off"
	cache_hit = use_cache and _load_placements(fingerprint)
	if not cache_hit:
		_plant_giants()
		_plant_woods()
		_plant_clearings()
		_dress_cliffs()
		if use_cache:
			_save_placements(fingerprint)
	_draw_batches()
	_build_trunks()
	build_msec = Time.get_ticks_msec() - started


func _cache_fingerprint(seed_value: int) -> String:
	var inputs: Array = [CACHE_REVISION, BATCH_REVISION, _ground._cache_fingerprint(),
		seed_value, _curve.get_baked_points(), _reserved, Game.lean_graphics]
	if FileAccess.file_exists("res://scripts/world/flora.gd"):
		inputs.append(FileAccess.get_file_as_bytes("res://scripts/world/flora.gd"))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(inputs))
	return hash.finish().hex_encode()


func _load_placements(fingerprint: String) -> bool:
	var path := "%s/forest_%s.res" % [CACHE_DIR, fingerprint]
	if not FileAccess.file_exists(path):
		return false
	var cache := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as FloraCache
	if cache == null or cache.fingerprint != fingerprint or cache.data.size() != 16:
		return false
	var d := cache.data
	trees = d["trees"]
	tree_kinds.assign(d["kinds"])
	_tree_cells = d["tree_cells"]
	_batches = d["batches"]
	_batch_under = d["batch_under"]
	_trunks = d["trunks"]
	giant_count = d["giants"]
	great_count = d["great"]
	ordinary_planned = d["ordinary_planned"]
	ordinary_kept = d["ordinary_kept"]
	undergrowth_planned = d["under_planned"]
	undergrowth_count = d["under_kept"]
	rock_count = d["rocks"]
	_rng.state = d["rng_state"]
	return true


func _save_placements(fingerprint: String) -> void:
	var cache := FloraCache.new()
	cache.fingerprint = fingerprint
	cache.data = {
		"trees": trees, "kinds": tree_kinds, "tree_cells": _tree_cells,
		"batches": _batches, "batch_under": _batch_under, "trunks": _trunks,
		"giants": giant_count, "great": great_count, "ordinary_planned": ordinary_planned,
		"ordinary_kept": ordinary_kept, "under_planned": undergrowth_planned,
		"under_kept": undergrowth_count, "rocks": rock_count, "rng_state": _rng.state,
		"batch_revision": BATCH_REVISION, "cache_revision": CACHE_REVISION,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var path := "%s/forest_%s.res" % [CACHE_DIR, fingerprint]
	var temporary := "%s/forest_%s_%d.tmp.res" % [CACHE_DIR, fingerprint, OS.get_process_id()]
	if ResourceSaver.save(cache, temporary, ResourceSaver.FLAG_COMPRESS) != OK:
		return
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return
	var old: Array[Dictionary] = []
	for file in DirAccess.get_files_at(CACHE_DIR):
		var hash := file.trim_prefix("forest_").trim_suffix(".res")
		if not file.begins_with("forest_") or not file.ends_with(".res") or hash.length() != 64 or not hash.is_valid_hex_number():
			continue
		var cached_path := CACHE_DIR.path_join(file)
		if cached_path != path:
			old.append({"path": cached_path, "time": FileAccess.get_modified_time(cached_path)})
	old.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] > b["time"])
	for i in range(7, old.size()):
		DirAccess.remove_absolute(old[i]["path"])


## Where the trees stand (trunk base, world space): what the wind thrashes,
## what sheds snow and where the birds sit. With a radius, only the trees
## within it of centre, nearest first.
func tree_positions(centre := Vector3.INF, radius := -1.0) -> PackedVector3Array:
	if radius < 0.0:
		return trees.duplicate()
	var found := PackedVector3Array()
	for index in nearest_indices(centre, 1 << 30, radius):
		found.append(trees[index])
	return found


## Indices into trees of up to count trees within reach of from, nearest first.
func nearest_indices(from: Vector3, count: int, reach: float) -> Array:
	var ranked := []
	var lo := _cell_of(from.x - reach, from.z - reach)
	var hi := _cell_of(from.x + reach, from.z + reach)
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cz)
			if not _tree_cells.has(key):
				continue
			for index: int in _tree_cells[key]:
				var at := trees[index]
				var distance := Vector2(at.x - from.x, at.z - from.z).length()
				if distance <= reach:
					ranked.append([distance, index])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var picked := []
	for entry in ranked.slice(0, count):
		picked.append(entry[1])
	return picked


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_WORLD:
			var space := get_world_3d().space
			for body in _bodies:
				PhysicsServer3D.body_set_space(body, space)
		NOTIFICATION_EXIT_WORLD:
			for body in _bodies:
				PhysicsServer3D.body_set_space(body, RID())
		NOTIFICATION_PREDELETE:
			for body in _bodies:
				PhysicsServer3D.free_rid(body)
			for shape: RID in _shapes.values():
				PhysicsServer3D.free_rid(shape)
			_bodies.clear()
			_shapes.clear()


# --- Placement ---------------------------------------------------------------

func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / HASH)), int(floor(z / HASH)))


# Room for something needing gap metres to every neighbour (each with its own).
func _room(x: float, z: float, gap: float) -> bool:
	var reach := maxf(gap, Tune.FOREST_GREAT_GAP)
	var lo := _cell_of(x - reach, z - reach)
	var hi := _cell_of(x + reach, z + reach)
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cz)
			if not _taken.has(key):
				continue
			for other: Vector4 in _taken[key]:
				if Vector2(x - other.x, z - other.y).length() < maxf(gap, other.z):
					return false
	return true


func _occupy(x: float, z: float, gap: float) -> void:
	var key := _cell_of(x, z)
	if not _taken.has(key):
		_taken[key] = PackedVector4Array()
	var list: PackedVector4Array = _taken[key]
	list.append(Vector4(x, z, gap, 0.0))
	_taken[key] = list


func _near_reserved(x: float, z: float, radius: float) -> bool:
	for point in _reserved:
		if Vector2(x - point.x, z - point.z).length() < radius:
			return true
	return false


# Inside the world, short of the outer wall's steepest rock.
func _inside(x: float, z: float, margin: float) -> bool:
	return x > Tune.WORLD_MIN_X + margin and x < Tune.WORLD_MAX_X - margin and z > Tune.WORLD_MIN_Z + margin and z < Tune.WORLD_MAX_Z - margin


func _chunk_of(x: float, z: float) -> int:
	var columns := int(round((Tune.WORLD_MAX_X - Tune.WORLD_MIN_X) / Tune.CHUNK_SIZE))
	var cx := clampi(int(floor((x - Tune.WORLD_MIN_X) / Tune.CHUNK_SIZE)), 0, columns - 1)
	var rows := int(round((Tune.WORLD_MAX_Z - Tune.WORLD_MIN_Z) / Tune.CHUNK_SIZE))
	var cz := clampi(int(floor((z - Tune.WORLD_MIN_Z) / Tune.CHUNK_SIZE)), 0, rows - 1)
	return cz * columns + cx


func _add(model: String, at: Vector3, yaw: float, scale: float, under: bool) -> void:
	var cell := Vector2i(int(floor(at.x / Tune.FOREST_BATCH_SIZE)), int(floor(at.z / Tune.FOREST_BATCH_SIZE)))
	var key := "%s|%d,%d" % [model, cell.x, cell.y]
	if not _batches.has(key):
		_batches[key] = []
		_batch_under[key] = under
	(_batches[key] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), at))


func _add_tree(model: String, kind: String, at: Vector3, yaw: float, scale: float, trunk_radius: float, trunk_height: float) -> void:
	_add(model, at, yaw, scale, false)
	var index := trees.size()
	trees.append(at)
	tree_kinds.append(kind)
	var key := _cell_of(at.x, at.z)
	if not _tree_cells.has(key):
		_tree_cells[key] = PackedInt32Array()
	var list: PackedInt32Array = _tree_cells[key]
	list.append(index)
	_tree_cells[key] = list
	var chunk := _chunk_of(at.x, at.z)
	if not _trunks.has(chunk):
		_trunks[chunk] = []
	(_trunks[chunk] as Array).append([at, trunk_radius, trunk_height])


# 0..1: how wooded the land is here.
func _wood_mask(x: float, z: float) -> float:
	return smoothstep(-0.15, 0.35, _woods.get_noise_2d(x, z))


# Lone giants in clearings beside the route, where she will see them.
func _plant_giants() -> void:
	var spots: Array[Vector3] = []
	var length := _curve.get_baked_length()
	var along := 0.0
	while along < length:
		var frame := _curve.sample_baked_with_rotation(along, false)
		var side := frame.basis.x
		side.y = 0.0
		side = side.normalized()
		for sign_value in [-1.0, 1.0]:
			for out in [Tune.FOREST_GIANT_NEAR + 6.0, (Tune.FOREST_GIANT_NEAR + Tune.FOREST_GIANT_FAR) * 0.5, Tune.FOREST_GIANT_FAR - 6.0]:
				var at: Vector3 = frame.origin + side * float(sign_value) * float(out)
				spots.append(at)
		along += 12.0
	# Shuffle with the seeded generator so the choice is the seed's.
	for i in range(spots.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var chosen: Array[Vector3] = []
	for at in spots:
		if chosen.size() >= Tune.FOREST_GIANTS:
			break
		var distance := _ground.route_distance(at.x, at.z)
		if distance < Tune.FOREST_GIANT_NEAR or distance > Tune.FOREST_GIANT_FAR:
			continue
		if not _inside(at.x, at.z, Tune.RING_WIDTH) or _ground.slope_at(at.x, at.z) > 20.0 or _ground.snow_at(at.x, at.z) < 0.6:
			continue
		if _near_reserved(at.x, at.z, Tune.FOREST_RESERVED) or not _room(at.x, at.z, 30.0):
			continue
		var scale := _rng.randf_range(Tune.FOREST_GIANT_MIN, Tune.FOREST_GIANT_MAX)
		var ground_at := Vector3(at.x, _ground.height_at(at.x, at.z) - 0.2, at.z)
		_add_tree(SNOW_PINES[chosen.size() % SNOW_PINES.size()], "snow_giant", ground_at, _rng.randf() * TAU, scale, 0.35 * scale, 3.6 * scale)
		_occupy(at.x, at.z, 30.0)
		chosen.append(at)
	giant_count = chosen.size()


func _plant_woods() -> void:
	var lean := Game.lean_graphics
	var spacing := minf(Tune.FOREST_SPACING, Tune.GREEN_SPACING)
	var margin := Tune.RING_WIDTH * 0.35
	var x := Tune.WORLD_MIN_X + margin
	while x < Tune.WORLD_MAX_X - margin:
		var z := Tune.WORLD_MIN_Z + margin
		while z < Tune.WORLD_MAX_Z - margin:
			# Every draw first, whatever is decided, so lean is a subset of full.
			var jx := _rng.randf_range(-0.45, 0.45) * spacing
			var jz := _rng.randf_range(-0.45, 0.45) * spacing
			var accept := _rng.randf()
			var thin := _rng.randf()
			var pick := _rng.randf()
			var great_roll := _rng.randf()
			var size_roll := _rng.randf()
			var yaw := _rng.randf() * TAU
			var under_rolls := [_rng.randf(), _rng.randf(), _rng.randf(), _rng.randf(), _rng.randf(), _rng.randf()]
			_try_tree(x + jx, z + jz, accept, thin, pick, great_roll, size_roll, yaw, under_rolls, lean)
			z += spacing
		x += spacing


func _try_tree(x: float, z: float, accept: float, thin: float, pick: float, great_roll: float, size_roll: float, yaw: float, under_rolls: Array, lean: bool) -> void:
	if _ground.route_distance(x, z) < Tune.FOREST_CLEAR:
		return
	var mask := _wood_mask(x, z)
	if mask <= 0.0:
		return
	var snow := _ground.snow_at(x, z)
	var green := snow < 0.5
	# Green land is lusher: woods spread wider and grow thicker.
	var density := Tune.GREEN_DENSITY * smoothstep(-0.05, 0.6, mask + 0.25) if green else Tune.FOREST_DENSITY * mask
	# Snow woods grow on the wider grid: skip about a fifth of the candidates.
	if not green and accept > density * Tune.GREEN_SPACING * Tune.GREEN_SPACING / (Tune.FOREST_SPACING * Tune.FOREST_SPACING):
		return
	if green and accept > density:
		return
	if _ground.slope_at(x, z) > Tune.FOREST_SLOPE or _near_reserved(x, z, Tune.FOREST_RESERVED):
		return
	var great := not green and great_roll < Tune.FOREST_GREAT_SHARE
	var gap := Tune.FOREST_GREAT_GAP if great else Tune.FOREST_MIN_GAP
	if not _room(x, z, gap):
		return
	_occupy(x, z, gap)
	var at := Vector3(x, _ground.height_at(x, z) - 0.15, z)
	if great:
		var scale := lerpf(Tune.FOREST_GREAT_MIN, Tune.FOREST_GREAT_MAX, size_roll)
		_add_tree(SNOW_PINES[int(pick * SNOW_PINES.size()) % SNOW_PINES.size()], "snow_great", at, yaw, scale, 0.35 * scale, 3.6 * scale)
		great_count += 1
		return
	ordinary_planned += 1
	if lean and thin >= Tune.FOREST_LEAN_SHARE:
		return
	ordinary_kept += 1
	if green:
		var card := pick < Tune.GREEN_CARD_SHARE
		var model := PACK + (CARD_TREES[int(size_roll * CARD_TREES.size()) % CARD_TREES.size()] if card else SPRUCES[int(pick * 97.0) % SPRUCES.size()])
		var scale := lerpf(Tune.GREEN_TREE_MIN, Tune.GREEN_TREE_MAX, size_roll)
		_add_tree(model, "green_card" if card else "green", at, yaw, scale, 0.18 * scale, 3.0 * scale)
		_understory(at, under_rolls, lean)
	else:
		var bare := pick > 0.9
		var scale := lerpf(Tune.FOREST_TREE_MIN, Tune.FOREST_TREE_MAX, size_roll)
		var model := BARE_PINE if bare else SNOW_PINES[int(pick * 31.0) % SNOW_PINES.size()]
		_add_tree(model, "snow_bare" if bare else "snow", at, yaw, scale, 0.35 * scale, 3.6 * scale)


# Firs and bushes under a green tree.
func _understory(at: Vector3, rolls: Array, lean: bool) -> void:
	for k in 2:
		var angle: float = rolls[k * 3] * TAU
		var out: float = lerpf(1.6, 3.6, rolls[k * 3 + 1])
		var x := at.x + cos(angle) * out
		var z := at.z + sin(angle) * out
		if _ground.route_distance(x, z) < Tune.FOREST_CLEAR * 0.5 or _ground.slope_at(x, z) > 40.0:
			continue
		undergrowth_planned += 1
		if lean and rolls[k * 3 + 2] >= Tune.FOREST_LEAN_SHARE:
			continue
		undergrowth_count += 1
		var model := PACK + ("card_fir" if rolls[k * 3 + 2] < 0.6 else "card_bush")
		_add(model, Vector3(x, _ground.height_at(x, z) - 0.05, z), angle * 3.7, lerpf(0.8, 1.6, rolls[k * 3 + 1]), true)


# The open land between the woods: grass in green clearings; in the snow,
# mounds, the odd boulder, and logs where the woods begin.
func _plant_clearings() -> void:
	var lean := Game.lean_graphics
	var step := 6.0
	var margin := Tune.RING_WIDTH * 0.5
	var x := Tune.WORLD_MIN_X + margin
	while x < Tune.WORLD_MAX_X - margin:
		var z := Tune.WORLD_MIN_Z + margin
		while z < Tune.WORLD_MAX_Z - margin:
			var px := x + _rng.randf_range(-2.5, 2.5)
			var pz := z + _rng.randf_range(-2.5, 2.5)
			var roll := _rng.randf()
			var thin := _rng.randf()
			var size_roll := _rng.randf()
			var yaw := _rng.randf() * TAU
			z += step
			if _ground.route_distance(px, pz) < 3.0 or _near_reserved(px, pz, 4.0) or _ground.slope_at(px, pz) > 40.0:
				continue
			var mask := _wood_mask(px, pz)
			var snow := _ground.snow_at(px, pz)
			var model := ""
			var scale := 1.0
			if snow < 0.5:
				if mask > 0.55 or roll > 0.75:
					continue
				model = PACK + "grass_card"
				scale = lerpf(0.6, 1.2, size_roll)
			else:
				if mask > 0.2 and mask < 0.5 and roll < 0.12:
					model = LOGS[int(size_roll * LOGS.size()) % LOGS.size()]
				elif mask < 0.3 and roll < 0.18:
					model = MOUNDS[int(size_roll * MOUNDS.size()) % MOUNDS.size()]
					scale = lerpf(0.7, 1.45, size_roll)
				elif roll > 0.97 and _ground.route_distance(px, pz) > 6.0:
					model = BOULDERS[int(size_roll * BOULDERS.size()) % BOULDERS.size()]
					scale = lerpf(0.55, 1.45, size_roll)
				else:
					continue
			undergrowth_planned += 1
			if lean and thin >= Tune.FOREST_LEAN_SHARE:
				continue
			undergrowth_count += 1
			_add(model, Vector3(px, _ground.height_at(px, pz) - 0.05, pz), yaw, scale, true)
		x += step


# Rock faces on the steep cliffs within sight of the route.
func _dress_cliffs() -> void:
	var steep: Array[Vector3] = []
	var x := Tune.WORLD_MIN_X + Tune.RING_WIDTH
	while x < Tune.WORLD_MAX_X - Tune.RING_WIDTH:
		var z := Tune.WORLD_MIN_Z + Tune.RING_WIDTH
		while z < Tune.WORLD_MAX_Z - Tune.RING_WIDTH:
			var distance := _ground.route_distance(x, z)
			if distance >= Tune.RAVINE_INNER + 2.0 and distance < 160.0 and _ground.normal_at(x, z).y < Ground.CLIFF_FACE:
				steep.append(Vector3(x, 0.0, z))
			z += 3.0
		x += 3.0
	for i in range(steep.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := steep[i]
		steep[i] = steep[j]
		steep[j] = swap
	var placed: Array[Vector3] = []
	for at in steep:
		if placed.size() >= Tune.CLIFF_ROCKS_MAX:
			break
		var clear := true
		for other in placed:
			if Vector2(at.x - other.x, at.z - other.z).length() < Tune.CLIFF_ROCK_GAP:
				clear = false
				break
		if not clear or _near_reserved(at.x, at.z, 10.0):
			continue
		var normal := _ground.normal_at(at.x, at.z)
		var outward := Vector3(normal.x, 0.0, normal.z).normalized()
		var scale := _rng.randf_range(0.6, 1.2)
		var base := Vector3(at.x, _ground.height_at(at.x, at.z), at.z) - outward * 2.5 * scale - Vector3.UP * 3.0 * scale
		_add(CLIFF_ROCK, base, atan2(outward.x, outward.z), scale, false)
		placed.append(at)
	rock_count = placed.size()


# --- Drawing and collision ---------------------------------------------------

func _draw_batches() -> void:
	var lean := Game.lean_graphics
	var root := Node3D.new()
	root.name = "Batches"
	add_child(root)
	for key: String in _batches:
		var model := key.get_slice("|", 0)
		var under: bool = _batch_under[key]
		var transforms: Array = _batches[key]
		for part: Array in _model_parts(model):
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part[0]
			multimesh.instance_count = transforms.size()
			for i in transforms.size():
				multimesh.set_instance_transform(i, (transforms[i] as Transform3D) * (part[1] as Transform3D))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.layers = Tune.FOREST_RENDER_LAYER
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part[2] and not under else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if under:
				instance.visibility_range_end = Tune.UNDER_DRAW_LEAN if lean else Tune.UNDER_DRAW
			else:
				instance.visibility_range_end = Tune.FOREST_DRAW_LEAN if lean else Tune.FOREST_DRAW
			instance.visibility_range_end_margin = 10.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			root.add_child(instance)
	_batches.clear()


# The visible mesh parts of a model, with their materials baked into the
# surfaces and their offset from the model's root.
func _model_parts(model: String) -> Array:
	if _parts.has(model):
		return _parts[model]
	var parts: Array = []
	if model.begins_with(PACK):
		var mesh := load(model + ".res") as Mesh
		if mesh:
			parts.append([mesh, Transform3D(), true])
	else:
		var node := PropFactory.spawn(model)
		if node:
			for found in node.find_children("*", "MeshInstance3D", true, false):
				var instance := found as MeshInstance3D
				if instance.mesh == null or not _shown(instance, node):
					continue
				var mesh := instance.mesh.duplicate() as Mesh
				if mesh is ArrayMesh:
					for surface in mesh.get_surface_count():
						var material := instance.get_active_material(surface)
						if material:
							(mesh as ArrayMesh).surface_set_material(surface, material)
				parts.append([mesh, _relative(instance, node), true])
			node.free()
	if parts.is_empty():
		push_warning("Flora: no mesh for " + model)
	_parts[model] = parts
	return parts


func _shown(node: Node, root: Node) -> bool:
	var at := node
	while at != null and at != root:
		if at is Node3D and not (at as Node3D).visible:
			return false
		at = at.get_parent()
	return true


func _relative(node: Node3D, root: Node) -> Transform3D:
	var xform := node.transform
	var at := node.get_parent()
	while at != null and at != root:
		if at is Node3D:
			xform = (at as Node3D).transform * xform
		at = at.get_parent()
	return xform


func _build_trunks() -> void:
	var space := get_world_3d().space if is_inside_tree() else RID()
	for chunk: int in _trunks:
		var body := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(body, Tune.LAYER_WORLD)
		PhysicsServer3D.body_set_collision_mask(body, 0)
		for trunk: Array in _trunks[chunk]:
			var radius := snappedf(float(trunk[1]), 0.05)
			var height := snappedf(float(trunk[2]), 0.5)
			var base: Vector3 = trunk[0]
			PhysicsServer3D.body_add_shape(body, _trunk_shape(radius, height), Transform3D(Basis(), base + Vector3.UP * height * 0.5))
		if space.is_valid():
			PhysicsServer3D.body_set_space(body, space)
		_bodies.append(body)
	_trunks.clear()


func _trunk_shape(radius: float, height: float) -> RID:
	var key := Vector2(radius, height)
	if not _shapes.has(key):
		var shape := PhysicsServer3D.cylinder_shape_create()
		PhysicsServer3D.shape_set_data(shape, {"radius": radius, "height": height})
		_shapes[key] = shape
	return _shapes[key]
