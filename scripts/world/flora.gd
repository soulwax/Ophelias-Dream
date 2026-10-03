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
	var bushes := 0
	var tufts := 0
	var moss := 0
	var rocks := 0
	var mounds := 0
	var deadfall := 0
	var fallen: Array[String] = [
		"SM_Gen_Env_Log_01.fbx", "SM_Gen_Env_Log_02.fbx",
		"SM_Env_Pine_Stump_01.fbx",
	]
	var pines: Array[String] = [
		"SM_Env_Pine_04.fbx", "SM_Env_Pine_04.fbx",
		"SM_Env_Pine_03.fbx", "SM_Env_Pine_05.fbx", "SM_Env_Pine_02.fbx",
	]
	var shrubs: Array[String] = [
		"SM_Env_Bush_01_Alt.fbx", "SM_Env_Bush_01_Alt.fbx", "SM_Env_Bush_02.fbx",
	]
	var mosses: Array[String] = [
		"SM_Env_Moss_Lumps_01.fbx", "SM_Env_Moss_Lumps_02.fbx", "SM_Env_Moss_Lumps_03.fbx",
	]
	var step := 9.0
	var x := Tune.FENCE_MIN_X + 7.0
	while x < Tune.FENCE_MAX_X - 7.0:
		var z := Tune.FENCE_MIN_Z + 7.0
		while z < Tune.FENCE_MAX_Z - 7.0:
			var at := Vector3(x + _rng.randf_range(-3.2, 3.2), 0.0, z + _rng.randf_range(-3.2, 3.2))
			var noise := _density.get_noise_2d(at.x, at.z)
			var clearance := _off_path(curve, at)
			if trees < 64 and noise > 0.18 and clearance > 9.0 and not _blocked(at, 6.0, reserved):
				var pine := pines[_rng.randi() % pines.size()]
				if _rng.randf() < 0.1:
					pine = "SM_Env_Pine_NoLeaves_01.fbx"
				_prop(ground, pine, at, _rng.randf_range(0.95, 1.3), true)
				trees += 1
				if bushes < 48 and _rng.randf() < 0.55:
					var bush_at := at + Vector3(_rng.randf_range(-2.6, 2.6), 0.0, _rng.randf_range(-2.6, 2.6))
					if _off_path(curve, bush_at) > 6.5 and not _blocked(bush_at, 2.0, reserved):
						_prop(ground, shrubs[_rng.randi() % shrubs.size()], bush_at, _rng.randf_range(0.8, 1.15), false)
						bushes += 1
			if tufts < 120 and noise > -0.08 and clearance > 5.0 and _rng.randf() < 0.4 and not _blocked(at, 1.6, reserved):
				var grass_at := at + Vector3(_rng.randf_range(-1.8, 1.8), 0.0, _rng.randf_range(-1.8, 1.8))
				_prop(ground, "SM_Env_Grass_01.fbx", grass_at, _rng.randf_range(0.7, 1.15), false)
				tufts += 1
			if moss < 40 and noise > 0.05 and clearance > 6.0 and _rng.randf() < 0.14 and not _blocked(at, 2.0, reserved):
				_prop(ground, mosses[_rng.randi() % mosses.size()], at, _rng.randf_range(0.65, 1.05), false)
				moss += 1
			if rocks < 70 and clearance > 7.0 and not _blocked(at, 2.4, reserved) and _rng.randf() < 0.16:
				var rock_file := "SM_Env_Rock_0%d.fbx" % [1, 2, 5, 8][_rng.randi() % 4]
				_prop(ground, rock_file, at, _rng.randf_range(0.55, 1.45), false)
				rocks += 1
			if mounds < 90 and clearance > 5.0 and not _blocked(at, 2.0, reserved) and _rng.randf() < 0.28:
				_prop(ground, "SM_Env_Snow_Mound_0%d.fbx" % (_rng.randi() % 4 + 1), at, _rng.randf_range(0.7, 1.45), false)
				mounds += 1
			if deadfall < 28 and clearance > 8.0 and not _blocked(at, 3.0, reserved) and _rng.randf() < 0.08:
				_prop(ground, fallen[_rng.randi() % fallen.size()], at, _rng.randf_range(0.8, 1.15), false)
				deadfall += 1
			z += step
		x += step
	_horizon(ground)


func _prop(ground: Ground, file_name: String, at: Vector3, scale: float, trunk: bool) -> void:
	at.y = ground.height_at(at.x, at.z)
	var lower := file_name.to_lower()
	if "pine_03" in lower or "pine_05" in lower:
		scale *= 1.45
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
