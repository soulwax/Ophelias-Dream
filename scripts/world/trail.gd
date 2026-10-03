class_name Trail
extends Node3D

var curve: Curve3D
var ground: Ground
var house: House
var flora: Flora
var length: float = 1.0
var player_start_offset: float = 0.0
var exit_offset: float = 1.0
var exit_point: Vector3 = Vector3.ZERO

var _rng := RandomNumberGenerator.new()
var _reserved: Array[Vector3] = []
var seed_value := 1701


func _ready() -> void:
	_rng.seed = seed_value
	_build_curve()
	var house_frame := _house_frame()
	ground = Ground.new()
	ground.name = "Ground"
	ground.seed_value = seed_value
	# A level pad for the house and the cellar under the snow, and a cut
	# where the stair well goes down through it.
	# Level well past the cellar: the 3 m grid starts blending a whole cell
	# before the pad's edge.
	ground.pads = [[Vector2(house_frame.origin.x, house_frame.origin.z), 14.0, 22.0]]
	ground.cuts = [[house_frame, House.stair_cut()]]
	add_child(ground)
	house = House.new()
	house.name = "House"
	house_frame.origin.y = ground.height_at(house_frame.origin.x, house_frame.origin.z) + House.PLINTH
	house.transform = house_frame
	add_child(house)
	house.add_snow_patch(ground.snow_material)
	Game.house = house
	for x in range(-12, 13, 3):
		for z in range(-10, 11, 3):
			_reserve(house.to_global(Vector3(x, 0.0, z)))
	var fence := Fence.new()
	fence.name = "Fence"
	fence.ground = ground
	add_child(fence)
	_build_landmarks()
	var flora := Flora.new()
	flora.name = "Flora"
	add_child(flora)
	flora.grow(ground, curve, _reserved, seed_value)
	Game.trail = self


func offset_of(world_position: Vector3) -> float:
	return curve.get_closest_offset(to_local(world_position))


func position_at(offset: float) -> Vector3:
	return to_global(curve.sample_baked(clampf(offset, 0.0, length)))


func frame_at(offset: float) -> Transform3D:
	var local := curve.sample_baked_with_rotation(clampf(offset, 0.0, length), false)
	return global_transform * local


func on_ground(at: Vector3) -> Vector3:
	if ground:
		at.y = ground.height_at(at.x, at.z)
	return at


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
	exit_point = curve.sample_baked(exit_offset)


# Where the house stands: well off the trail start, front door facing it.
func _house_frame() -> Transform3D:
	var start := frame_at(player_start_offset)
	var at := start.origin + start.basis.x * -17.0
	at.y = 0.0
	var facing := start.origin - at
	facing.y = 0.0
	return Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), at)


func _build_landmarks() -> void:
	var start := frame_at(player_start_offset)
	_prop("SM_Prop_Bench_01.fbx", on_ground(start.origin + start.basis.x * -4.2 + (-start.basis.z) * 2.0), start, 1.0, false, Vector3.ZERO)
	_prop("SM_Prop_Wood_Pile_01.fbx", on_ground(start.origin + start.basis.x * 4.2), start, 1.0, false, Vector3.ZERO)
	_prop("SM_Prop_Lantern_01.fbx", on_ground(start.origin + start.basis.x * -2.6), start, 1.0, false, Vector3.ZERO)
	_light(on_ground(start.origin) + Vector3(0, 1.8, 0), Color(1.0, 0.62, 0.32), 1.1, 9.0)

	var notes := NoteCatalog.all()
	var marks: Array[float] = [22.0, 58.0, 98.0, 138.0, 176.0]
	for index in notes.size():
		var along := minf(player_start_offset + marks[index], exit_offset - 16.0)
		var frame := frame_at(along)
		var side := -1.0 if index % 2 == 0 else 1.0
		var at := on_ground(frame.origin + frame.basis.x * side * 3.6)
		at.y += 0.04
		_reserve(at)
		var page := FieldNote.new()
		page.name = "FieldNote_%d" % index
		page.entry = notes[index]
		page.position = at
		add_child(page)

	var camp := frame_at(player_start_offset + 98.0)
	var camp_at := on_ground(camp.origin + camp.basis.x * 7.5)
	_reserve(camp_at)
	_prop("SM_Prop_Tent_01.fbx", camp_at, camp, 1.1, true, Vector3(2.2, 1.6, 2.4))
	_prop("SM_Prop_Campfire_01.fbx", on_ground(camp.origin + camp.basis.x * 4.4), camp, 1.0, false, Vector3.ZERO)
	_light(on_ground(camp.origin) + Vector3(0, 0.7, 0), Color(1.0, 0.42, 0.12), 1.5, 8.0)

	var ending := frame_at(exit_offset)
	var lookout_at := on_ground(ending.origin + ending.basis.x * 6.0)
	_reserve(lookout_at)
	_prop("SM_Prop_Lookout_01.fbx", lookout_at, ending, 1.2, true, Vector3(3.0, 4.0, 3.0))
	_headlights(ending)


func _headlights(frame: Transform3D) -> void:
	for side_value in [-1.4, 1.4]:
		var side: float = side_value
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.85, 0.9, 1.0)
		spot.light_energy = 6.0
		spot.spot_range = 28.0
		spot.spot_angle = 20.0
		spot.light_volumetric_fog_energy = 1.2
		spot.shadow_enabled = false
		add_child(spot)
		var at: Vector3 = on_ground(frame.origin + frame.basis.x * side) + Vector3(0, 1.5, 0)
		spot.global_position = at
		var target: Vector3 = on_ground(frame.origin - frame.basis.z * 16.0) + Vector3(0, 1.2, 0)
		spot.look_at(target, Vector3.UP)


func _light(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.position = at
	light.light_volumetric_fog_energy = 0.6
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
	node.name = file_name.get_basename()
	node.scale = Vector3.ONE * Tune.PROP_SCALE * scale
	node.position = at
	var yaw := frame.basis.get_euler().y + _rng.randf_range(-0.4, 0.4)
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
