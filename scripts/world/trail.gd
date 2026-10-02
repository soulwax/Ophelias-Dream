class_name Trail
extends Node3D

var curve: Curve3D
var length: float = 1.0
var player_start_offset: float = 0.0
var exit_offset: float = 1.0

var _rng := RandomNumberGenerator.new()
var _reserved: Array[Vector3] = []


func _ready() -> void:
	_rng.seed = 1701
	_build_curve()
	_build_ground()
	_build_landmarks()
	_scatter()
	Game.trail = self


func offset_of(world_position: Vector3) -> float:
	return curve.get_closest_offset(to_local(world_position))


func position_at(offset: float) -> Vector3:
	return to_global(curve.sample_baked(clampf(offset, 0.0, length)))


func frame_at(offset: float) -> Transform3D:
	var local := curve.sample_baked_with_rotation(clampf(offset, 0.0, length), false)
	return global_transform * local


func _build_curve() -> void:
	curve = Curve3D.new()
	curve.bake_interval = 0.4
	var points: Array[Vector3] = [
		Vector3(0, 0, 52),
		Vector3(0, 0, 10),
		Vector3(12, 0, -14),
		Vector3(-9, 0, -40),
		Vector3(15, 0, -68),
		Vector3(-13, 0, -100),
		Vector3(7, 0, -134),
		Vector3(-6, 0, -166),
		Vector3(10, 0, -200),
	]
	for point in points:
		curve.add_point(point)
	length = curve.get_baked_length()
	player_start_offset = curve.get_closest_offset(Vector3(0, 0, 10))
	exit_offset = length - Tune.EXIT_MARGIN


func _build_ground() -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Y
	plane.size = Vector2(180, 340)
	mesh_instance.mesh = plane
	mesh_instance.position = Vector3(0, 0, -70)
	var shader := load("res://shaders/snow_ground.gdshader") as Shader
	var material := ShaderMaterial.new()
	material.shader = shader
	if ResourceLoader.exists("res://assets/environment/Snow_01.png"):
		material.set_shader_parameter("snow_tex", load("res://assets/environment/Snow_01.png"))
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(180, 2, 340)
	shape.shape = box
	shape.position = Vector3(0, -1, -70)
	body.add_child(shape)
	add_child(body)


func _build_landmarks() -> void:
	var start := frame_at(player_start_offset)
	var cabin_at := start.origin + start.basis.x * -10.5
	_reserve(cabin_at)
	_prop("SM_Prop_Cabin_01.fbx", cabin_at, start, 1.15, true, Vector3(6.2, 6.8, 7.2))
	_prop("SM_Prop_Bench_01.fbx", start.origin + start.basis.x * -3.4 + (-start.basis.z) * 1.5, start, 1.0, false, Vector3.ZERO)
	_prop("SM_Prop_Wood_Pile_01.fbx", start.origin + start.basis.x * 3.6, start, 1.0, false, Vector3.ZERO)
	_prop("SM_Prop_Lantern_01.fbx", start.origin + start.basis.x * -2.2, start, 1.0, false, Vector3.ZERO)
	_light(start.origin + Vector3(0, 1.6, 0), Color(1.0, 0.62, 0.32), 1.3, 8.0)

	var notes := NoteCatalog.all()
	var marks: Array[float] = [18.0, 52.0, 90.0, 126.0, 158.0]
	for index in notes.size():
		var along := minf(player_start_offset + marks[index], exit_offset - 18.0)
		var frame := frame_at(along)
		var side := -1.0 if index % 2 == 0 else 1.0
		var at := frame.origin + frame.basis.x * side * 2.4
		at.y = 0.05
		_reserve(at)
		var page := FieldNote.new()
		page.entry = notes[index]
		page.position = at
		add_child(page)

	var camp := frame_at(player_start_offset + 90.0)
	_reserve(camp.origin)
	_prop("SM_Prop_Tent_01.fbx", camp.origin + camp.basis.x * 4.8, camp, 1.1, true, Vector3(2.2, 1.6, 2.4))
	_prop("SM_Prop_Campfire_01.fbx", camp.origin + camp.basis.x * 2.2, camp, 1.0, false, Vector3.ZERO)
	_light(camp.origin + Vector3(0, 0.6, 0), Color(1.0, 0.42, 0.12), 1.8, 7.0)

	var ending := frame_at(exit_offset)
	_prop("SM_Prop_Lookout_01.fbx", ending.origin + ending.basis.x * 5.5, ending, 1.2, true, Vector3(3.0, 4.0, 3.0))
	_headlights(ending)

	_mountains()


func _scatter() -> void:
	var pines: Array[String] = [
		"SM_Env_Pine_01.fbx", "SM_Env_Pine_02.fbx", "SM_Env_Pine_03.fbx", "SM_Env_Pine_05.fbx",
	]
	var cursor := 6.0
	while cursor < length - 4.0:
		var frame := frame_at(cursor)
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			if _rng.randf() < 0.22:
				continue
			var lateral: float = _rng.randf_range(5.0, 13.5) * side
			var at: Vector3 = frame.origin + frame.basis.x * lateral
			at.y = 0.0
			if _blocked(at, 3.4):
				continue
			var file_name: String = pines[_rng.randi() % pines.size()]
			if _rng.randf() < 0.18:
				file_name = "SM_Env_Pine_NoLeaves_01.fbx"
			var scale := _rng.randf_range(0.85, 1.35)
			var height := 4.2 * scale * Tune.PROP_SCALE
			_prop(file_name, at, frame, scale, false, Vector3(0.45, height, 0.45), true)
		if _rng.randf() < 0.55:
			var mound_side := -1.0 if _rng.randf() < 0.5 else 1.0
			var mound_at := frame.origin + frame.basis.x * _rng.randf_range(3.2, 6.4) * mound_side
			if not _blocked(mound_at, 1.6):
				var which := _rng.randi() % 4 + 1
				_prop("SM_Env_Snow_Mound_0%d.fbx" % which, mound_at, frame, _rng.randf_range(0.8, 1.3), false, Vector3.ZERO)
		if _rng.randf() < 0.28:
			var rock_side := -1.0 if _rng.randf() < 0.5 else 1.0
			var rock_at := frame.origin + frame.basis.x * _rng.randf_range(4.0, 9.0) * rock_side
			if not _blocked(rock_at, 1.8):
				var rock_file := "SM_Env_Rock_0%d.fbx" % [1, 2, 5, 8][_rng.randi() % 4]
				_prop(rock_file, rock_at, frame, _rng.randf_range(0.7, 1.4), true, Vector3(1.1, 0.8, 1.1))
		cursor += _rng.randf_range(4.2, 7.0)

	for index in 8:
		var along := 12.0 + float(index) * (length / 9.0)
		var frame := frame_at(along)
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			var at: Vector3 = frame.origin + frame.basis.x * (30.0 + _rng.randf_range(0.0, 10.0)) * side
			_prop("SM_Env_Background_Trees_02.fbx", at, frame, _rng.randf_range(0.85, 1.15), false, Vector3.ZERO)


func _mountains() -> void:
	for index in 4:
		var along := 20.0 + float(index) * 45.0
		var frame := frame_at(minf(along, length - 1.0))
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			var at: Vector3 = frame.origin + frame.basis.x * 42.0 * side
			at.y = -1.5
			var file_name := "SM_Env_MountainRange_01.fbx" if index % 2 == 0 else "SM_Env_Rock_Cliff_02.fbx"
			_prop(file_name, at, frame, 1.0 if index % 2 == 0 else 0.85, false, Vector3.ZERO)


func _headlights(frame: Transform3D) -> void:
	for side_value in [-1.4, 1.4]:
		var side: float = side_value
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.85, 0.9, 1.0)
		spot.light_energy = 8.0
		spot.spot_range = 36.0
		spot.spot_angle = 22.0
		spot.light_volumetric_fog_energy = 2.4
		spot.shadow_enabled = false
		add_child(spot)
		var at: Vector3 = frame.origin + frame.basis.x * side + Vector3(0, 1.4, 0)
		spot.global_position = at
		var target := frame.origin - frame.basis.z * 16.0 + Vector3(0, 1.0, 0)
		spot.look_at(target, Vector3.UP)


func _light(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.position = at
	light.light_volumetric_fog_energy = 1.1
	add_child(light)


func _prop(
	file_name: String,
	at: Vector3,
	frame: Transform3D,
	scale: float,
	block: bool,
	block_size: Vector3,
	trunk: bool = false
) -> void:
	var node := PropFactory.spawn(file_name)
	node.scale = Vector3.ONE * Tune.PROP_SCALE * scale
	node.position = at
	var yaw := frame.basis.get_euler().y + _rng.randf_range(-0.6, 0.6)
	node.rotation.y = yaw
	add_child(node)
	if trunk:
		_cylinder_at(at, block_size.x, block_size.y)
	elif block and block_size != Vector3.ZERO:
		_box_at(at, block_size * Tune.PROP_SCALE * scale)


func _cylinder_at(at: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Tune.LAYER_WORLD
	body.position = at
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3(0, height * 0.5, 0)
	body.add_child(shape)
	add_child(body)


func _box_at(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Tune.LAYER_WORLD
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	add_child(body)


func _reserve(at: Vector3) -> void:
	_reserved.append(at)


func _blocked(at: Vector3, radius: float) -> bool:
	for reserved in _reserved:
		if Vector2(at.x - reserved.x, at.z - reserved.z).length() < radius:
			return true
	return false
