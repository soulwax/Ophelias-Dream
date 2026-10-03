class_name Ground
extends Node3D

var seed_value := 1701

var _heights := PackedFloat32Array()
var _origin_x := 0.0
var _origin_z := 0.0
var _step_x := 1.0
var _step_z := 1.0
var _points_x := 2
var _points_z := 2

# Flat pads (the house sits on one): [Vector2 centre, inner radius, outer
# radius]. Inside the inner radius the snow is level at the height the noise
# had at the centre; it blends back out by the outer radius.
var pads: Array = []
# Cuts: [Transform3D local-to-world, Rect2 local x/z]. Grid cells touching a
# cut are left out of the mesh and the collision (the stair well).
var cuts: Array = []
var _pad_heights: Array[float] = []
# The snow's material, so patches can match it exactly.
var snow_material: ShaderMaterial

var _broad := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _dirt := FastNoiseLite.new()


func _ready() -> void:
	_configure_noise()
	_build()


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


func _configure_noise() -> void:
	_setup(_broad, seed_value, 0.0072, 5, FastNoiseLite.FRACTAL_FBM)
	_setup(_detail, seed_value + 1, 0.029, 2, FastNoiseLite.FRACTAL_FBM)
	_setup(_ridge, seed_value + 2, 0.011, 3, FastNoiseLite.FRACTAL_RIDGED)
	_setup(_dirt, seed_value + 3, 0.02, 3, FastNoiseLite.FRACTAL_FBM)


func _setup(noise: FastNoiseLite, seed_value: int, frequency: float, octaves: int, fractal: FastNoiseLite.FractalType) -> void:
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves


func _sample(x: float, z: float) -> float:
	var h := _broad.get_noise_2d(x, z) * 10.5
	h += _detail.get_noise_2d(x, z) * 2.15
	h += _ridge.get_noise_2d(x, z) * 3.6
	h = _flatten(h, x, z, 0.0, 10.0, 16.0)
	h = _flatten(h, x, z, 10.0, -200.0, 18.0)
	for index in _pad_heights.size():
		var pad: Array = pads[index]
		var centre: Vector2 = pad[0]
		var level := 1.0 - smoothstep(pad[1], pad[2], Vector2(x, z).distance_to(centre))
		h = lerpf(h, _pad_heights[index], level)
	return h


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


func _flatten(h: float, x: float, z: float, px: float, pz: float, radius: float) -> float:
	var distance := Vector2(x - px, z - pz).length()
	var weight := 1.0 - smoothstep(radius * 0.3, radius, distance)
	return lerpf(h, h * 0.2, weight)


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

	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.ZERO)
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
				# Reversed operands keep the normal pointing up for this winding.
				var face_normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
				normals[a] += face_normal
				normals[b] += face_normal
				normals[c] += face_normal
	for i in normals.size():
		if normals[i].length_squared() < 0.0001:
			normals[i] = Vector3.UP
		else:
			normals[i] = normals[i].normalized()
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
