class_name Ground
extends Node3D

var _heights := PackedFloat32Array()
var _origin_x := 0.0
var _origin_z := 0.0
var _step_x := 1.0
var _step_z := 1.0
var _points_x := 2
var _points_z := 2

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
	_setup(_broad, 1701, 0.0072, 5, FastNoiseLite.FRACTAL_FBM)
	_setup(_detail, 1702, 0.029, 2, FastNoiseLite.FRACTAL_FBM)
	_setup(_ridge, 1703, 0.011, 3, FastNoiseLite.FRACTAL_RIDGED)
	_setup(_dirt, 1704, 0.02, 3, FastNoiseLite.FRACTAL_FBM)


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
	return h


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
	indices.resize(cells_x * cells_z * 6)
	faces.resize(cells_x * cells_z * 6)
	var cursor := 0
	for z in cells_z:
		for x in cells_x:
			var i00 := z * _points_x + x
			var i10 := i00 + 1
			var i01 := i00 + _points_x
			var i11 := i01 + 1
			for tri in [[i00, i01, i11], [i00, i11, i10]]:
				var a: int = tri[0]
				var b: int = tri[1]
				var c: int = tri[2]
				indices[cursor] = a
				faces[cursor] = vertices[a]
				cursor += 1
				indices[cursor] = b
				faces[cursor] = vertices[b]
				cursor += 1
				indices[cursor] = c
				faces[cursor] = vertices[c]
				cursor += 1
				var face_normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
				normals[a] += face_normal
				normals[b] += face_normal
				normals[c] += face_normal
	for i in normals.size():
		if normals[i].length_squared() < 0.0001:
			normals[i] = Vector3.UP
		else:
			normals[i] = normals[i].normalized()

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.data = faces
	concave.backface_collision = true
	shape.shape = concave
	body.add_child(shape)
	add_child(body)


func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/snow_ground.gdshader")
	if ResourceLoader.exists("res://assets/environment/Snow_01.png"):
		material.set_shader_parameter("snow_tex", load("res://assets/environment/Snow_01.png"))
	material.set_shader_parameter("dirt_tex", _dirt_texture())
	return material


func _dirt_texture() -> ImageTexture:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var n := _dirt.get_noise_2d(float(x) * 2.0, float(y) * 2.0) * 0.5 + 0.5
			image.set_pixel(x, y, Color(n, n, n))
	return ImageTexture.create_from_image(image)
