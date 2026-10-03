class_name HairRig
extends MeshInstance3D

## Her hair obeys physics. It was grown and styled in Blender on her real
## scalp (tools/blender/grow_hair.py); 64 guide strands were kept for the
## simulation, and every one of the ~900 strand cards follows its nearest.
##
## Each guide is a chain of particles. The ones on the scalp are carried by
## the head; the rest fall under gravity with damping, keep their length,
## resist bending, are drawn gently back toward the styled shape (firmly near
## the roots, hardly at the tips), take the wind, and collide with capsules
## on her posed head, neck, shoulders, torso and upper arms.
##
## The CPU moves only the ~960 particles. Their positions go into a small
## float texture each frame and the shader (hair_strands.gdshader) rebuilds
## every vertex from its guide: the guide point at its distance along, plus
## its rest offset turned by the head and by the guide's bend there.

const MODEL := "res://assets/characters/hair.glb"
const GUIDES := "res://assets/characters/hair_guides.json"
const STEP := 1.0 / 60.0
const GRAVITY := Vector3(0.0, -9.8, 0.0)
const DAMPING := 0.07
const ITERATIONS := 3

var _skeleton: Skeleton3D
var _head := -1
var _head_unrest := Transform3D.IDENTITY
var _count := 0
var _points := 0
var _rest: Array[PackedVector3Array] = []
var _scalp: PackedInt32Array
var _pos: Array[PackedVector3Array] = []
var _prev: Array[PackedVector3Array] = []
var _length := 0.044
var _capsules: Array = []
var _world_caps: Array = []
var _image: Image
var _texture: ImageTexture
var _material: ShaderMaterial
var _live := false
var _accum := 0.0
var _last_usec := 0
var _last_head := Transform3D.IDENTITY
var _cost := 0
var _cost_frames := 0


static func available() -> bool:
	return ResourceLoader.exists(MODEL) and FileAccess.file_exists(GUIDES)


static func fit(outfit: Outfit, strands: Texture2D) -> HairRig:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GUIDES))
	if not data is Dictionary:
		return null
	var scene := (load(MODEL) as PackedScene).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		scene.free()
		return null
	var arrays := (found[0] as MeshInstance3D).mesh.surface_get_arrays(0)
	scene.free()
	var hair := HairRig.new()
	hair.name = "Wear_Hair"
	hair._skeleton = outfit.skeleton
	hair._head = outfit.skeleton.find_bone("Head")
	hair._head_unrest = outfit.skeleton.get_bone_global_rest(hair._head).affine_inverse()
	hair._load_guides(data)
	hair._build_mesh(arrays, strands)
	hair._build_capsules(outfit)
	# Vertices are placed in world space by the shader; the node stays at
	# the origin and is never culled for being "elsewhere".
	hair.top_level = true
	hair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	outfit.skeleton.add_child(hair)
	hair.global_transform = Transform3D.IDENTITY
	outfit.skeleton.skeleton_updated.connect(hair._on_skeleton_updated)
	return hair


func _load_guides(data: Dictionary) -> void:
	_length = float(data.get("segment", 0.044))
	var guides: Array = data["guides"]
	_count = guides.size()
	_points = (guides[0]["points"] as Array).size()
	_scalp.resize(_count)
	for g in _count:
		var rest := PackedVector3Array()
		for p in guides[g]["points"]:
			rest.append(Vector3(p[0], p[1], p[2]))
		_rest.append(rest)
		_scalp[g] = clampi(int(guides[g]["scalp"]), 1, _points - 2)
		_pos.append(rest.duplicate())
		_prev.append(rest.duplicate())


## The rest offset of every vertex from its guide goes in CUSTOM0, so the
## shader only has to add it back, turned.
func _build_mesh(arrays: Array, strands: Texture2D) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bind: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	# Each strand blends its three nearest guides (packed exactly in UV2.x as
	# g0 + n*g1 + n*n*g2), weighted by distance, each with its own offset:
	# small offsets, and their errors cancel instead of twisting the card.
	var custom: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	for channel in custom:
		channel.resize(verts.size() * 4)
	for i in verts.size():
		var packed := roundi(bind[i].x)
		var t := clampf(bind[i].y, 0.0, 1.0)
		var guides: Array[int] = [packed % _count, (packed / _count) % _count, packed / (_count * _count)]
		var offs: Array[Vector3] = []
		var weights: Array[float] = []
		var total := 0.0
		for g in guides:
			var off := verts[i] - _guide_point(_rest[clampi(g, 0, _count - 1)], t)
			offs.append(off)
			var w := 1.0 / pow(off.length() + 0.01, 2.0)
			weights.append(w)
			total += w
		for k in 3:
			custom[k][i * 4] = offs[k].x
			custom[k][i * 4 + 1] = offs[k].y
			custom[k][i * 4 + 2] = offs[k].z
			custom[k][i * 4 + 3] = weights[k] / total
	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_INDEX]:
		mesh_arrays[slot] = arrays[slot]
	mesh_arrays[Mesh.ARRAY_CUSTOM0] = custom[0]
	mesh_arrays[Mesh.ARRAY_CUSTOM1] = custom[1]
	mesh_arrays[Mesh.ARRAY_CUSTOM2] = custom[2]
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays, [], {}, flags)
	built.custom_aabb = AABB(Vector3(-600.0, -100.0, -600.0), Vector3(1200.0, 300.0, 1200.0))
	mesh = built
	var rest_image := Image.create(_points, _count, false, Image.FORMAT_RGBF)
	for g in _count:
		for i in _points:
			var p := _rest[g][i]
			rest_image.set_pixel(i, g, Color(p.x, p.y, p.z))
	_image = Image.create(_points, _count, false, Image.FORMAT_RGBF)
	_texture = ImageTexture.create_from_image(_image)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/hair_strands.gdshader")
	_material.set_shader_parameter("strands", strands)
	_material.set_shader_parameter("rest_points", ImageTexture.create_from_image(rest_image))
	_material.set_shader_parameter("current_points", _texture)
	_material.set_shader_parameter("points", _points)
	material_override = _material


## Her posed body as capsules (rest-space ends, carried by bones).
func _build_capsules(outfit: Outfit) -> void:
	var head := outfit._bone("Head")
	var neck := outfit._bone("Neck")
	var head_y := head.y
	var neck_y := neck.y
	var skull := outfit._band(head_y + 0.088, head_y + 0.112)
	var neck_band := outfit._band(neck_y - 0.03, neck_y + 0.03)
	var chest := outfit._band(1.25, 1.33)
	var neck_r := outfit._girth(neck, outfit._head, 0.0)
	var skull_r := maxf(float(skull.rx), maxf(float(skull.front), float(skull.back))) - 0.005
	var coat := 0.03
	_capsules = [
		["Head", Vector3(0.0, head_y + 0.06, skull.cz), Vector3(0.0, head_y + 0.11, skull.cz), skull_r],
		# Neck, with the scarf looped round it.
		["Neck", Vector3(0.0, neck_y - 0.12, neck_band.cz), Vector3(0.0, head_y, neck_band.cz), neck_r + 0.05],
		["UpperChest", Vector3(-0.04, neck_y - 0.075, chest.cz), Vector3(-0.165, neck_y - 0.15, chest.cz), 0.06 + coat],
		["UpperChest", Vector3(0.04, neck_y - 0.075, chest.cz), Vector3(0.165, neck_y - 0.15, chest.cz), 0.06 + coat],
		["Chest", Vector3(-0.055, 1.02, chest.cz), Vector3(-0.055, neck_y - 0.13, chest.cz), float(chest.back) + coat],
		["Chest", Vector3(0.055, 1.02, chest.cz), Vector3(0.055, neck_y - 0.13, chest.cz), float(chest.back) + coat],
	]
	for side in ["Left", "Right"]:
		var shoulder := outfit._bone(side + "UpperArm")
		var elbow := outfit._bone(side + "LowerArm")
		_capsules.append([side + "UpperArm", shoulder, elbow, outfit._girth(shoulder, elbow, 0.0) + 0.045])
	for capsule in _capsules:
		var bone := _skeleton.find_bone(capsule[0])
		var unrest := _skeleton.get_bone_global_rest(bone).affine_inverse()
		capsule[0] = bone
		capsule[1] = unrest * (capsule[1] as Vector3)
		capsule[2] = unrest * (capsule[2] as Vector3)


# --- Simulation ------------------------------------------------------------------

func _carried() -> Transform3D:
	# Rest space -> world, as if rigidly carried by the head.
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_head) * _head_unrest


func _on_skeleton_updated() -> void:
	var started := Time.get_ticks_usec()
	_simulate()
	# Dev hook: RUN_HAIR_COST=1 prints the simulation's cost now and then.
	if OS.get_environment("RUN_HAIR_COST") == "1":
		_cost += Time.get_ticks_usec() - started
		_cost_frames += 1
		if _cost_frames == 120:
			print("HAIR COST %.2f ms per frame" % (float(_cost) / 120.0 / 1000.0))
			_cost = 0
			_cost_frames = 0


func _simulate() -> void:
	var now := Time.get_ticks_usec()
	var delta := 0.0 if _last_usec == 0 else clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.1)
	_last_usec = now
	var carried := _carried()
	if not _live or _pos[0][0].distance_to(carried * _rest[0][0]) > 1.0:
		_settle(carried)
	_place_capsules()
	var wind := _wind()
	_accum = minf(_accum + delta, STEP * 3.0)
	var steps := int(_accum / STEP)
	for k in steps:
		_accum -= STEP
		# Sweep the scalp from last frame's pose to this one, so a fast turn
		# drags the hair instead of teleporting its roots.
		_step(_last_head.interpolate_with(carried, float(k + 1) / float(steps)), wind)
	if steps > 0:
		_last_head = carried
	_pin(carried)
	_upload(carried)


func _settle(carried: Transform3D) -> void:
	# Packed arrays come out of an Array as copies: edit, then put back.
	for g in _count:
		var pos := _pos[g]
		for i in _points:
			pos[i] = carried * _rest[g][i]
		_pos[g] = pos
		_prev[g] = pos.duplicate()
	_last_head = carried
	_live = true


func _pin(carried: Transform3D) -> void:
	for g in _count:
		var pos := _pos[g]
		var prev := _prev[g]
		for i in _scalp[g]:
			pos[i] = carried * _rest[g][i]
			prev[i] = pos[i]
		_pos[g] = pos
		_prev[g] = prev


func _step(carried: Transform3D, wind: Vector3) -> void:
	var pull := (GRAVITY + wind) * STEP * STEP
	var keep := 1.0 - DAMPING
	for g in _count:
		var pos := _pos[g]
		var prev := _prev[g]
		var rest := _rest[g]
		var scalp := _scalp[g]
		for i in scalp:
			pos[i] = carried * rest[i]
			prev[i] = pos[i]
		for i in range(scalp, _points):
			var p := pos[i]
			var t := float(i - scalp) / float(_points - scalp)
			# Wind and gravity catch the tips. The roots stay with the head.
			var moved := p + (p - prev[i]) * keep + pull * lerpf(0.15, 1.0, t)
			# Roots keep the style. Tips barely remember it, so they trail.
			moved += (carried * rest[i] - moved) * lerpf(0.14, 0.0012, sqrt(t))
			prev[i] = p
			pos[i] = moved
		for _iteration in ITERATIONS:
			for i in range(scalp, _points):
				# Length to the previous particle (which may be pinned).
				var a := pos[i - 1]
				var d := pos[i] - a
				var dist := d.length()
				if dist > 1e-6:
					var fix := d * ((dist - _length) / dist)
					if i - 1 < scalp:
						pos[i] -= fix
					else:
						pos[i - 1] += fix * 0.5
						pos[i] -= fix * 0.5
				# A little resistance to folding: keep two apart near their rest.
				if i >= 2:
					var b := pos[i - 2]
					var e := pos[i] - b
					var reach := e.length()
					var want := rest[i].distance_to(rest[i - 2])
					if reach > 1e-6 and reach < want * 0.94:
						pos[i] += e * ((want * 0.94 - reach) / reach) * 0.3
			_collide(pos, scalp)
		# A light smoothing pass: hair has no kinks of its own, only jitter.
		for i in range(scalp, _points - 1):
			pos[i] = pos[i].lerp((pos[i - 1] + pos[i + 1]) * 0.5, 0.05)
		_pos[g] = pos
		_prev[g] = prev


func _place_capsules() -> void:
	_world_caps.clear()
	var base := _skeleton.global_transform
	for capsule in _capsules:
		var pose: Transform3D = base * _skeleton.get_bone_global_pose(capsule[0])
		var a: Vector3 = pose * (capsule[1] as Vector3)
		var b: Vector3 = pose * (capsule[2] as Vector3)
		var ab := b - a
		_world_caps.append([a, ab, 1.0 / maxf(ab.length_squared(), 1e-8), capsule[3]])


func _collide(pos: PackedVector3Array, scalp: int) -> void:
	for i in range(scalp, _points):
		var p := pos[i]
		for capsule in _world_caps:
			var a: Vector3 = capsule[0]
			var ab: Vector3 = capsule[1]
			var r: float = capsule[3]
			var t := clampf((p - a).dot(ab) * (capsule[2] as float), 0.0, 1.0)
			var d := p - (a + ab * t)
			var dist2 := d.length_squared()
			if dist2 < r * r and dist2 > 1e-10:
				p += d * (r / sqrt(dist2) - 1.0)
		pos[i] = p


func _upload(carried: Transform3D) -> void:
	for g in _count:
		var pos := _pos[g]
		for i in _points:
			var p := pos[i]
			_image.set_pixel(i, g, Color(p.x, p.y, p.z))
	_texture.update(_image)
	_material.set_shader_parameter("head", carried)


func _wind() -> Vector3:
	var game := get_tree().root.get_node_or_null("Game")
	if game == null or game.get("weather") == null:
		return Vector3.ZERO
	if game.call("indoors", _pos[0][0]):
		return Vector3.ZERO
	var weather: Variant = game.get("weather")
	var t := Time.get_ticks_msec()
	var flutter := 0.7 + 0.6 * sin(t * 0.0041) * sin(t * 0.0017)
	var wind: Vector3 = weather.wind
	return Vector3(wind.x, 0.0, wind.z) * (1.0 + float(weather.gust)) * 0.45 * flutter


static func _guide_point(points: PackedVector3Array, t: float) -> Vector3:
	var s := t * float(points.size() - 1)
	var i0 := mini(floori(s), points.size() - 2)
	return points[i0].lerp(points[i0 + 1], s - float(i0))
