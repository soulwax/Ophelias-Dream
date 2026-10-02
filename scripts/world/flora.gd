class_name Flora
extends Node3D

var _rng := RandomNumberGenerator.new()
var _density := FastNoiseLite.new()


func grow(ground: Ground, curve: Curve3D, reserved: Array[Vector3]) -> void:
	_rng.seed = 90210
	_density.noise_type = FastNoiseLite.TYPE_PERLIN
	_density.seed = 88
	_density.frequency = 0.034
	_density.fractal_type = FastNoiseLite.FRACTAL_FBM
	_density.fractal_octaves = 3

	var trees := 0
	var shrubs := 0
	var rocks := 0
	var mounds := 0
	var ice := 0
	var clumps := 0
	var carpets := 0
	var deadfall := 0
	var grasses: Array[String] = [
		"SM_Gen_Env_Grass_01.fbx", "SM_Gen_Env_Grass_02.fbx", "SM_Gen_Env_Grass_03.fbx", "SM_Gen_Env_Grass_04.fbx", "SM_Gen_Env_Grass_05.fbx",
		"SM_Gen_Env_Grass_06.fbx", "SM_Gen_Env_Grass_07.fbx",
		"SM_Gen_Env_Grass_Tall_01.fbx", "SM_Gen_Env_Grass_Tall_02.fbx", "SM_Gen_Env_Grass_Tall_03.fbx", "SM_Gen_Env_Grass_Tall_04.fbx",
		"SM_Env_Grass_01.fbx",
		"SM_Gen_Env_Fern_01.fbx", "SM_Gen_Env_Fern_02.fbx", "SM_Gen_Env_Fern_03.fbx",
	]
	var flowers: Array[String] = [
		"SM_Env_Flowers_01.fbx", "SM_Env_Flowers_01_Alt.fbx", "SM_Env_Bush_Flower_01.fbx", "SM_Env_Bush_Flower_01_Alt.fbx",
		"SM_Gen_Env_Flowers_01.fbx", "SM_Gen_Env_Flowers_02.fbx", "SM_Gen_Env_Flowers_03.fbx", "SM_Gen_Env_Flowers_04.fbx",
		"SM_Gen_Env_Flowers_05.fbx", "SM_Gen_Env_Flowers_06.fbx", "SM_Gen_Env_Flowers_07.fbx", "SM_Gen_Env_Flowers_08.fbx",
	]
	var covers: Array[String] = [
		"SM_Env_GroundCover_01.fbx", "SM_Env_GroundCover_02.fbx", "SM_Env_GroundCover_03.fbx",
		"SM_Env_Moss_Lumps_01.fbx", "SM_Env_Moss_Lumps_02.fbx", "SM_Env_Moss_Lumps_03.fbx",
	]
	var mushrooms: Array[String] = [
		"SM_Gen_Env_Mushroom_01.fbx", "SM_Gen_Env_Mushroom_02.fbx", "SM_Gen_Env_Mushroom_03.fbx",
	]
	var bushes: Array[String] = [
		"SM_Env_Branch_01.fbx", "SM_Env_Branch_02.fbx", "SM_Env_Branch_03.fbx", "SM_Env_Branch_04.fbx",
		"SM_Env_Bush_01.fbx", "SM_Env_Bush_01_Alt.fbx", "SM_Env_Bush_02.fbx", "SM_Env_Bush_02_Alt.fbx",
		"SM_Gen_Env_Bush_01.fbx", "SM_Gen_Env_Bush_02.fbx", "SM_Gen_Env_Bush_03.fbx", "SM_Gen_Env_Bush_04.fbx",
		"SM_Gen_Env_Bush_Large_01.fbx", "SM_Gen_Env_Bush_Large_02.fbx", "SM_Gen_Env_Bush_Large_03.fbx", "SM_Gen_Env_Bush_Large_04.fbx",
		"SM_Gen_Env_Shrub_01.fbx", "SM_Gen_Env_Shrub_02.fbx", "SM_Gen_Env_Shrub_03.fbx",
	]
	var fallen: Array[String] = [
		"SM_Gen_Env_Log_01.fbx", "SM_Gen_Env_Log_02.fbx",
		"SM_Gen_Env_Stump_01.fbx", "SM_Gen_Env_Stump_02.fbx", "SM_Gen_Env_Stump_03.fbx",
		"SM_Env_Pine_Stump_01.fbx",
	]
	var pines: Array[String] = [
		"SM_Env_Pine_01.fbx", "SM_Env_Pine_02.fbx", "SM_Env_Pine_03.fbx", "SM_Env_Pine_04.fbx", "SM_Env_Pine_05.fbx",
		"SM_Gen_Env_Tree_Pine_01.fbx", "SM_Gen_Env_Tree_Pine_02.fbx", "SM_Gen_Env_Tree_Pine_03.fbx",
	]
	var broadleaf: Array[String] = [
		"SM_Gen_Env_Tree_01.fbx", "SM_Gen_Env_Tree_02.fbx", "SM_Gen_Env_Tree_03.fbx",
		"SM_Gen_Env_Tree_Dead_01.fbx", "SM_Gen_Env_Tree_Dead_02.fbx", "SM_Gen_Env_Tree_Dead_03.fbx",
	]
	var step := 9.0
	var x := Tune.FENCE_MIN_X + 7.0
	while x < Tune.FENCE_MAX_X - 7.0:
		var z := Tune.FENCE_MIN_Z + 7.0
		while z < Tune.FENCE_MAX_Z - 7.0:
			var at := Vector3(x + _rng.randf_range(-3.2, 3.2), 0.0, z + _rng.randf_range(-3.2, 3.2))
			var noise := _density.get_noise_2d(at.x, at.z)
			var clearance := _off_path(curve, at)
			if trees < 200 and noise > 0.12 and clearance > 8.2 and not _blocked(at, 5.2, reserved):
				_prop(ground, _tree(pines, broadleaf), at, _rng.randf_range(0.8, 1.4), true)
				trees += 1
				if trees < 200 and noise > 0.42:
					var extra := at + Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0))
					if _inside(extra) and _off_path(curve, extra) > 7.0 and not _blocked(extra, 4.0, reserved):
						_prop(ground, _tree(pines, broadleaf), extra, _rng.randf_range(0.7, 1.15), true)
						trees += 1
			if shrubs < 340 and noise > -0.12 and clearance > 4.4 and not _blocked(at, 2.4, reserved) and _rng.randf() < 0.78:
				var bush := at + Vector3(_rng.randf_range(-1.4, 1.4), 0.0, _rng.randf_range(-1.4, 1.4))
				_prop(ground, bushes[_rng.randi() % bushes.size()], bush, _rng.randf_range(0.7, 1.25), false)
				shrubs += 1
			if rocks < 100 and clearance > 6.5 and not _blocked(at, 2.2, reserved) and _rng.randf() < 0.22:
				var rock_file := "SM_Env_Rock_0%d.fbx" % [1, 2, 5, 8][_rng.randi() % 4]
				_prop(ground, rock_file, at, _rng.randf_range(0.55, 1.45), false)
				rocks += 1
			if mounds < 90 and clearance > 5.0 and not _blocked(at, 2.0, reserved) and _rng.randf() < 0.28:
				_prop(ground, "SM_Env_Snow_Mound_0%d.fbx" % (_rng.randi() % 4 + 1), at, _rng.randf_range(0.7, 1.45), false)
				mounds += 1
			var height := ground.height_at(at.x, at.z)
			if ice < 28 and height < -2.2 and clearance > 6.0 and _rng.randf() < 0.45:
				_prop(ground, "SM_Env_Ice_Sheet_01.fbx", at, _rng.randf_range(1.1, 2.0), false)
				ice += 1
			if clumps < 780 and noise > -0.08 and clearance > 3.0 and _rng.randf() < 0.88:
				var g := at + Vector3(_rng.randf_range(-3.5, 3.5), 0.0, _rng.randf_range(-3.5, 3.5))
				if _inside(g) and not _blocked(g, 1.5, reserved):
					_prop(ground, _roadside_plant(grasses, flowers, mushrooms, bushes, covers), g, _rng.randf_range(0.7, 1.3), false)
					clumps += 1
			if carpets < 260 and noise > -0.2 and clearance > 3.4 and _rng.randf() < 0.55:
				var patch := at + Vector3(_rng.randf_range(-2.8, 2.8), 0.0, _rng.randf_range(-2.8, 2.8))
				if _inside(patch) and not _blocked(patch, 1.8, reserved):
					_prop(ground, covers[_rng.randi() % covers.size()], patch, _rng.randf_range(0.85, 1.55), false)
					carpets += 1
			if deadfall < 90 and clearance > 5.4 and not _blocked(at, 2.6, reserved) and _rng.randf() < 0.16:
				_prop(ground, fallen[_rng.randi() % fallen.size()], at, _rng.randf_range(0.75, 1.35), false)
				deadfall += 1
			z += step
		x += step
	_along_the_road(ground, curve, reserved, grasses, flowers, mushrooms, bushes, covers)
	_horizon(ground)


func _along_the_road(ground: Ground, curve: Curve3D, reserved: Array[Vector3], grasses: Array[String], flowers: Array[String], mushrooms: Array[String], bushes: Array[String], covers: Array[String]) -> void:
	var cursor := 5.0
	var length := curve.get_baked_length()
	var placed := 0
	while cursor < length - 6.0 and placed < 640:
		var frame := curve.sample_baked_with_rotation(cursor, false)
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			if _rng.randf() < 0.18:
				continue
			var at: Vector3 = frame.origin + frame.basis.x * _rng.randf_range(3.3, 8.8) * side
			at += -frame.basis.z * _rng.randf_range(-1.4, 1.4)
			if _blocked(at, 1.6, reserved):
				continue
			var file_name := _roadside_plant(grasses, flowers, mushrooms, bushes, covers)
			_prop(ground, file_name, at, _rng.randf_range(0.65, 1.2), false)
			placed += 1
		cursor += _rng.randf_range(2.2, 3.8)


func _tree(pines: Array[String], broadleaf: Array[String]) -> String:
	var roll := _rng.randf()
	if roll < 0.14:
		return "SM_Env_Pine_NoLeaves_01.fbx"
	if roll < 0.34:
		return broadleaf[_rng.randi() % broadleaf.size()]
	return pines[_rng.randi() % pines.size()]


func _roadside_plant(grasses: Array[String], flowers: Array[String], mushrooms: Array[String], bushes: Array[String], covers: Array[String]) -> String:
	var roll := _rng.randf()
	if roll < 0.32:
		return grasses[_rng.randi() % grasses.size()]
	if roll < 0.5:
		return flowers[_rng.randi() % flowers.size()]
	if roll < 0.62:
		return covers[_rng.randi() % covers.size()]
	if roll < 0.74:
		return mushrooms[_rng.randi() % mushrooms.size()]
	return bushes[_rng.randi() % bushes.size()]


func _prop(ground: Ground, file_name: String, at: Vector3, scale: float, trunk: bool) -> void:
	at.y = ground.height_at(at.x, at.z)
	var lower := file_name.to_lower()
	if "large" in lower:
		scale *= 0.62
	if lower.ends_with("grass_06.fbx") or lower.ends_with("grass_07.fbx"):
		scale *= 0.38
	if lower.begins_with("sm_gen_env_tree"):
		scale *= 1.4
	var node := PropFactory.spawn(file_name)
	node.scale = Vector3.ONE * Tune.PROP_SCALE * scale
	node.position = at
	node.rotation.y = _rng.randf() * TAU
	add_child(node)
	if trunk:
		_trunk(at, 0.4, 3.6 * scale)


func _trunk(at: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3(0, height * 0.5, 0)
	body.add_child(shape)
	add_child(body)


func _horizon(ground: Ground) -> void:
	var along := Tune.FENCE_MIN_Z + 20.0
	while along < Tune.FENCE_MAX_Z - 10.0:
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			var at := Vector3(Tune.FENCE_MAX_X * side + 14.0 * side, 0.0, along + _rng.randf_range(-6.0, 6.0))
			at.y = ground.height_at(at.x, at.z) - 1.2
			var horizon_file := "SM_Env_Background_Trees_02.fbx" if _rng.randf() < 0.55 else "SM_Env_Background_Trees_01.fbx"
			var node := PropFactory.spawn(horizon_file)
			node.scale = Vector3.ONE * _rng.randf_range(0.9, 1.35)
			node.position = at
			node.rotation.y = _rng.randf() * TAU
			add_child(node)
		along += _rng.randf_range(18.0, 28.0)
	for index in 5:
		var z := Tune.FENCE_MIN_Z + 30.0 + float(index) * 58.0
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			var at := Vector3((Tune.FENCE_MAX_X + 22.0) * side, 0.0, z)
			at.y = ground.height_at(at.x, at.z) - 4.0
			var file_name := "SM_Env_MountainRange_01.fbx" if index % 2 == 0 else "SM_Env_Rock_Cliff_02.fbx"
			var node := PropFactory.spawn(file_name)
			node.scale = Vector3.ONE * (1.15 if index % 2 == 0 else 0.95)
			node.position = at
			node.rotation.y = _rng.randf() * TAU
			add_child(node)


func _off_path(curve: Curve3D, at: Vector3) -> float:
	var on := curve.sample_baked(curve.get_closest_offset(at))
	return Vector2(at.x - on.x, at.z - on.z).length()


func _inside(at: Vector3) -> bool:
	return at.x > Tune.FENCE_MIN_X + 4.0 and at.x < Tune.FENCE_MAX_X - 4.0 and at.z > Tune.FENCE_MIN_Z + 4.0 and at.z < Tune.FENCE_MAX_Z - 4.0


func _blocked(at: Vector3, radius: float, reserved: Array[Vector3]) -> bool:
	for point in reserved:
		if Vector2(at.x - point.x, at.z - point.z).length() < radius:
			return true
	return false
