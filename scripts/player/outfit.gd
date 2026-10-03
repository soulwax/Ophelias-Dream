class_name Outfit
extends Node3D

# A long black velvet coat, a loose wine scarf, dark denim, leather boots and
# long brunette hair for the Quaternius body.
#
# The fitted parts are grown from her own skinned mesh: every vertex is pushed
# out along its normal by the thickness of what she wears there and keeps its
# bone weights, so the bodice, sleeves, jeans and boots bend exactly like she
# does. The coat skirt and the hair are Cloth, so they swing and trail.
# All sizes are measured from the mesh's rest pose, not hard-coded.

const VELVET := Color(0.013, 0.011, 0.015, 0.82)
const VELVET_BELT := Color(0.009, 0.008, 0.011, 0.7)
const CUFF := Color(0.018, 0.015, 0.02, 0.78)
const DENIM := Color(0.07, 0.075, 0.09, 0.85)
const LEATHER := Color(0.016, 0.006, 0.008, 0.3)
const HAIR_ROOT := Color(0.09, 0.045, 0.028, 0.48)
# The scalp under the locks wears the roots' own tone, so a gap reads as shadow in the hair.
const HAIR_CAP := Color(0.08, 0.042, 0.026, 0.7)
const HAIR_TIP := Color(0.3, 0.16, 0.08, 0.5)
const SILVER := Color(0.8, 0.8, 0.83)
const WINE := Color(0.05, 0.004, 0.009, 0.95)
# Corner of the painted face in the body texture (tools/paint_coat.py keeps
# this box as skin and dyes the rest).
const FACE_UV := Vector2(0.4, 0.36)

var skeleton: Skeleton3D
var body: MeshInstance3D
var mouth_rest := Vector3.ZERO

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _attachments: Dictionary = {}
var _weave: NoiseTexture2D
var _neck_y := 0.0
var _head := Vector3.ZERO
var _hips_y := 0.0
var _wrist_x := 0.0
var _belt_lo := 0.0
var _belt_hi := 0.0
var _skin := Color(0.55, 0.32, 0.2, 0.9)


static func dress(model: Node) -> Outfit:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var outfit := Outfit.new()
	outfit.name = "Outfit"
	outfit.skeleton = skeletons[0] as Skeleton3D
	var biggest := 0.0
	for child in outfit.skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var volume := mesh_instance.get_aabb().get_volume()
		if mesh_instance.skin and volume > biggest:
			biggest = volume
			outfit.body = mesh_instance
	if outfit.body == null:
		return null
	outfit.skeleton.add_child(outfit)
	outfit._build()
	return outfit


# Pins any node to a bone at a transform given in skeleton rest space.
func attach(bone: String, node: Node3D, rest_transform: Transform3D) -> void:
	var bone_rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	node.transform = bone_rest.affine_inverse() * rest_transform
	_attachment(bone).add_child(node)


func _build() -> void:
	var arrays := body.mesh.surface_get_arrays(0)
	_verts = arrays[Mesh.ARRAY_VERTEX]
	_normals = arrays[Mesh.ARRAY_NORMAL]
	_neck_y = _bone("Neck").y
	_head = _bone("Head")
	_hips_y = _bone("Hips").y
	_wrist_x = absf(_bone("LeftHand").x)
	_belt_lo = lerpf(_hips_y, _bone("Spine").y, 0.55)
	_belt_hi = _belt_lo + 0.055
	_weave = _make_weave()
	_skin = _sample_skin()
	_skin.a = 0.9
	_build_shell(arrays)
	_build_clasps()
	_build_skirt()
	_build_hair()
	_build_scarf()
	_build_boots()
	mouth_rest = _front_point(Vector2(_head.y + 0.025, _head.y + 0.045), 0.0, 0.02) + Vector3(0, 0, 0.012)


func _bone(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


func _attachment(bone: String) -> BoneAttachment3D:
	if _attachments.has(bone):
		return _attachments[bone]
	var attachment := BoneAttachment3D.new()
	attachment.name = "Wear_" + bone
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	_attachments[bone] = attachment
	return attachment


# --- Fitted layer grown from the body ------------------------------------

func _build_shell(arrays: Array) -> void:
	var count := _verts.size()
	var grown := PackedVector3Array()
	grown.resize(count)
	var colors := PackedColorArray()
	colors.resize(count)
	var keep := PackedByteArray()
	keep.resize(count)
	var bare := PackedByteArray()
	bare.resize(count)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in count:
		var zone := _zone(_verts[i], uvs[i] if i < uvs.size() else Vector2.ONE)
		grown[i] = _verts[i] + _normals[i] * (zone[1] as float)
		colors[i] = zone[0]
		keep[i] = 1 if zone[2] else 0
		bare[i] = 1 if zone.size() > 3 and zone[3] else 0
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var worn := PackedInt32Array()
	var skin := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		if keep[a] + keep[b] + keep[c] < 2:
			continue
		if bare[a] + bare[b] + bare[c] >= 2:
			skin.append_array([a, b, c])
		else:
			worn.append_array([a, b, c])
	var shell_arrays := []
	shell_arrays.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		shell_arrays[slot] = arrays[slot]
	shell_arrays[Mesh.ARRAY_VERTEX] = grown
	shell_arrays[Mesh.ARRAY_COLOR] = colors
	var flags := 0
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if weights.size() == count * 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var mesh := ArrayMesh.new()
	shell_arrays[Mesh.ARRAY_INDEX] = worn
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shell_arrays, [], {}, flags)
	mesh.surface_set_material(0, _fabric(Color.WHITE, 0.32, 0.12, 40.0, 0.22))
	if not skin.is_empty():
		shell_arrays[Mesh.ARRAY_INDEX] = skin
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shell_arrays, [], {}, flags)
		var flesh := StandardMaterial3D.new()
		flesh.vertex_color_use_as_albedo = true
		flesh.roughness = 0.9
		flesh.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mesh.surface_set_material(1, flesh)
	var shell := MeshInstance3D.new()
	shell.name = "Wear_Shell"
	shell.mesh = mesh
	shell.skin = body.skin
	skeleton.add_child(shell)
	shell.skeleton = shell.get_path_to(skeleton)


# Her skin tone, read from the face in the body texture so the bare neck
# meets the jaw without a seam.
func _sample_skin() -> Color:
	var fallback := Color(0.55, 0.32, 0.2)
	var material := body.material_override as StandardMaterial3D
	if material == null or material.albedo_texture == null:
		return fallback
	var image := material.albedo_texture.get_image()
	if image == null:
		return fallback
	if image.is_compressed():
		image.decompress()
	var total := Color(0, 0, 0)
	var spots: Array[Vector2] = [Vector2(0.07, 0.27), Vector2(0.33, 0.27), Vector2(0.2, 0.33), Vector2(0.1, 0.12), Vector2(0.3, 0.12)]
	for spot in spots:
		var pixel := image.get_pixel(int(spot.x * image.get_width()), int(spot.y * image.get_height()))
		total += pixel
	var mean := total / float(spots.size())
	# Vertex colours feed the shader as linear values.
	return Color(mean.r, mean.g, mean.b).srgb_to_linear()


# [dye with roughness in alpha, thickness, covered, bare skin] for a rest-pose
# point and its texture coordinate.
func _zone(p: Vector3, uv: Vector2) -> Array:
	var side := absf(p.x)
	if p.y > _neck_y - 0.01 and side < 0.16:
		var back := p.z < _head.z + 0.03
		# The scalp layer stops well above the brow; the swept locks hide
		# its edge.
		if p.y > _head.y + 0.2 or (back and p.y > _neck_y + 0.075):
			return [HAIR_CAP, 0.01, true]
		# The face keeps its own painted skin. Everything else up here is
		# the dark base layer, so it gets a whisper-thin skin of her tone.
		if uv.x < FACE_UV.x and uv.y < FACE_UV.y:
			return [_skin, 0.0, false, true]
		return [_skin, 0.0015, true, true]
	if side > _wrist_x - 0.022 and p.y > 1.2:
		return [CUFF, 0.0, false]
	if side > 0.19 and p.y > 1.28:
		if side > _wrist_x - 0.13:
			return [CUFF, 0.026, true]
		return [VELVET, 0.015, true]
	if p.y > _hips_y - 0.13:
		if p.y > _belt_lo and p.y < _belt_hi:
			return [VELVET_BELT, 0.026, true]
		return [VELVET, 0.017, true]
	if p.y > 0.2:
		return [DENIM, 0.006, true]
	# Below the jeans she wears the lofted boots.
	return [LEATHER, 0.0, false]


# --- Measuring the body ----------------------------------------------------

# Ellipse of the torso between two heights: centre z, half width, front and
# back depth from that centre.
func _band(y0: float, y1: float) -> Dictionary:
	var max_x := 0.0
	var min_z := 1.0
	var max_z := -1.0
	for p in _verts:
		if p.y < y0 or p.y > y1 or absf(p.x) > 0.3:
			continue
		max_x = maxf(max_x, absf(p.x))
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	var cz := (min_z + max_z) * 0.5
	return {"cz": cz, "rx": max_x, "front": max_z - cz, "back": cz - min_z}


# Her outline at one height: for each direction theta (0 = front, around her
# left), how far the body reaches from (0, centre_z), smoothed so creases and
# the gap between the legs do not dent it.
func _outline(y: float, centre_z: float, thetas: Array[float]) -> Array[float]:
	var reach: Array[float] = []
	reach.resize(thetas.size())
	reach.fill(0.0)
	for p in _verts:
		if absf(p.y - y) > 0.018 or absf(p.x) > 0.32:
			continue
		var dx := p.x
		var dz := p.z - centre_z
		var angle := atan2(dx, dz)
		var r := Vector2(dx, dz).length()
		for j in thetas.size():
			if absf(angle_difference(angle, thetas[j])) < 0.26:
				reach[j] = maxf(reach[j], r)
	# Fill empty directions from their neighbours, then smooth twice.
	for j in reach.size():
		if reach[j] <= 0.0:
			reach[j] = maxf(reach[(j + 1) % reach.size()], reach[(j - 1 + reach.size()) % reach.size()])
	for _pass in 2:
		var smooth := reach.duplicate()
		for j in reach.size():
			var a := reach[maxi(j - 1, 0)]
			var b := reach[mini(j + 1, reach.size() - 1)]
			smooth[j] = maxf(reach[j], (a + reach[j] * 2.0 + b) * 0.25)
		reach = smooth
	return reach


# Widest distance from a bone segment, over the middle of that segment.
func _girth(a: Vector3, b: Vector3, side: float) -> float:
	var ab := b - a
	var inv := 1.0 / maxf(ab.length_squared(), 1e-8)
	var widest := 0.0
	for p in _verts:
		if side != 0.0 and signf(p.x) != side:
			continue
		var t := (p - a).dot(ab) * inv
		if t < 0.15 or t > 0.85:
			continue
		var reach := p.distance_to(a + ab * t)
		if reach < 0.2:
			widest = maxf(widest, reach)
	return widest


# Front-most surface point near x within a height range.
func _front_point(heights: Vector2, x: float, half_width: float) -> Vector3:
	var best := Vector3(x, (heights.x + heights.y) * 0.5, -1.0)
	for p in _verts:
		if p.y < heights.x or p.y > heights.y or absf(p.x - x) > half_width:
			continue
		if p.z > best.z:
			best = p
	return best


# --- Tailored pieces --------------------------------------------------------

# A loose wine-red cashmere scarf: a soft loop resting on the shoulders that
# droops into a cowl at the front, and two tails falling down the coat.
func _build_scarf() -> void:
	var neck := _bone("Neck")
	var neck_r := _girth(neck, _head, 0.0)
	var chest := _band(1.22, 1.32)
	var shoulder := _shoulder_top()
	var base_y := _neck_y - 0.015
	var cols := 18
	var rows := 4
	var rest := PackedVector3Array()
	for i in rows:
		var t := float(i) / float(rows - 1)
		for j in cols:
			# Seam at the back, under the hair.
			var theta := PI + TAU * float(j) / float(cols)
			var front := maxf(cos(theta), 0.0)
			var r := neck_r + 0.028 + t * 0.03
			var y := base_y + 0.01 - t * 0.075 - front * front * 0.05
			rest.append(Vector3(sin(theta) * r * 1.12, y, neck.z + 0.008 + cos(theta) * r))
	var loop := Cloth.new()
	loop.name = "Wear_Scarf"
	loop.smooth_cols = true
	_soft_wool(loop)
	var trim := func(_u: float, v: float) -> Color:
		return WINE.darkened(0.15 * v)
	loop.setup(skeleton, "UpperChest", rest, cols, rows, rows, trim)
	# Ribbed knit: a deep, fine weave and only a little sheen.
	loop.material_override = _fabric(Color.WHITE, 0.18, 0.06, 46.0, 0.6, WINE.darkened(0.3))
	add_child(loop)
	_scarf_colliders(loop, neck, neck_r, chest, shoulder)

	# Two narrow tails off to her left, one longer than the other.
	var tails: Array = [[0.11, 0.5], [0.035, 0.4]]
	var strip := 3
	var tail_rows := 11
	var tail_rest := PackedVector3Array()
	tail_rest.resize(tail_rows * tails.size() * strip)
	for k in tails.size():
		var x: float = tails[k][0]
		var length: float = tails[k][1]
		for i in tail_rows:
			var y := base_y - 0.06 - length * float(i) / float(tail_rows - 1)
			var surface := _front_point(Vector2(y - 0.02, y + 0.02), x, 0.03)
			# Hangs a hand's breadth off the coat so it drapes, not paints.
			# The front tail hangs clear of the one behind it.
			var z := maxf(surface.z, chest.cz) + 0.05 + 0.018 * float(1 - k)
			var half := 0.027 * lerpf(1.0, 0.85, float(i) / float(tail_rows - 1))
			# Knit curls at the edges: the middle column sits a little proud.
			for c in strip:
				var across := (float(c) - 1.0) * half
				var curl := (1.0 - absf(float(c) - 1.0)) * 0.008
				tail_rest[(i * tails.size() + k) * strip + c] = Vector3(x + across, y, z + curl)
	var tail := Cloth.new()
	tail.name = "Wear_ScarfTails"
	tail.panel = strip
	_soft_wool(tail)
	var fringe := func(_u: float, v: float) -> Color:
		return WINE.lightened(0.06) if v > 0.95 else WINE
	tail.setup(skeleton, "UpperChest", tail_rest, tails.size() * strip, tail_rows, 0, fringe)
	tail.material_override = loop.material_override
	add_child(tail)
	_scarf_colliders(tail, neck, neck_r, chest, shoulder)
	var belly := _band(1.0, 1.1)
	var belly_r := maxf(belly.front, belly.back) + 0.04
	tail.add_capsule("Spine", Vector3(-0.05, 1.05, belly.cz), Vector3(0.05, 1.05, belly.cz), belly_r)
	var seat := _band(_hips_y - 0.06, _hips_y)
	var seat_r := maxf(seat.front, seat.back) + 0.07
	tail.add_capsule("Hips", Vector3(-0.06, _hips_y - 0.04, seat.cz), Vector3(0.06, _hips_y - 0.04, seat.cz), seat_r)


func _soft_wool(cloth: Cloth) -> void:
	cloth.stiffness = 0.025
	cloth.bend = 0.45
	cloth.damping = 0.085
	cloth.wind_response = 0.06
	cloth.iterations = 3


func _scarf_colliders(cloth: Cloth, neck: Vector3, neck_r: float, chest: Dictionary, shoulder: Vector3) -> void:
	cloth.add_capsule("Neck", neck + Vector3(0, -0.04, 0), _head, neck_r + 0.025)
	var r := 0.07
	cloth.add_capsule("UpperChest", Vector3(-shoulder.x, shoulder.y - r, shoulder.z), Vector3(shoulder.x, shoulder.y - r, shoulder.z), r + 0.02)
	var torso_r := maxf(chest.front, chest.back) + 0.035
	var torso_x := maxf((chest.rx as float) - torso_r, 0.01)
	cloth.add_capsule("Chest", Vector3(-torso_x, 1.27, chest.cz), Vector3(torso_x, 1.27, chest.cz), torso_r)


# Highest point of the shoulder line: (half width, height, depth centre).
func _shoulder_top() -> Vector3:
	var best := Vector3(0.15, 1.44, 0.0)
	for p in _verts:
		var side := absf(p.x)
		if side > 0.11 and side < 0.17 and p.y < _neck_y and p.y > best.y:
			best = Vector3(0.15, p.y, p.z)
	return best


# Silver frog clasps down the bodice and a buckle on the belt.
func _build_clasps() -> void:
	var silver := _metal(SILVER)
	var braid := _metal(SILVER.darkened(0.35))
	for row in 4:
		var y := _belt_hi + 0.03 + float(row) * 0.068
		var bone := "Spine" if y < 1.12 else ("Chest" if y < 1.23 else "UpperChest")
		var cord := CylinderMesh.new()
		cord.top_radius = 0.0038
		cord.bottom_radius = 0.0038
		cord.height = 0.1
		cord.radial_segments = 8
		cord.rings = 1
		var middle := _front_point(Vector2(y - 0.012, y + 0.012), 0.0, 0.02)
		var span := Basis(Vector3.FORWARD, PI * 0.5)
		_piece(bone, cord, Transform3D(span, middle + Vector3(0, 0, 0.026)), braid)
		for side in [-1.0, 1.0]:
			var at := _front_point(Vector2(y - 0.012, y + 0.012), 0.05 * side, 0.012) + Vector3(0, 0, 0.024)
			var knot := SphereMesh.new()
			knot.radius = 0.012
			knot.height = 0.024
			knot.radial_segments = 12
			knot.rings = 6
			_piece(bone, knot, Transform3D(Basis().scaled(Vector3(1, 1, 0.6)), at), silver)
			var loop := TorusMesh.new()
			loop.inner_radius = 0.012
			loop.outer_radius = 0.019
			loop.rings = 16
			loop.ring_segments = 6
			_piece(bone, loop, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, -0.002)), braid)
	var buckle := TorusMesh.new()
	buckle.inner_radius = 0.016
	buckle.outer_radius = 0.022
	buckle.rings = 4
	buckle.ring_segments = 6
	var belt := _front_point(Vector2(_belt_lo, _belt_hi), 0.0, 0.02) + Vector3(0, 0, 0.03)
	_piece("Spine", buckle, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.25, 1.0, 0.9)), belt), silver)


func _build_skirt() -> void:
	# Find the widest point of the hips.
	var widest_y := _hips_y - 0.06
	var widest_rx := 0.0
	for k in 9:
		var probe := lerpf(_hips_y + 0.03, _hips_y - 0.16, float(k) / 8.0)
		var slice := _band(probe - 0.012, probe + 0.012)
		if (slice.rx as float) > widest_rx:
			widest_rx = slice.rx
			widest_y = probe
	var widest := _band(widest_y - 0.012, widest_y + 0.012)
	var hem_y := 0.24
	var cols := 30
	var rows := 15
	var gap := 0.14
	# Seven godets round the skirt: flat over the hips, deep folds at the hem.
	var folds := 7.0
	var thetas: Array[float] = []
	for j in cols:
		thetas.append(lerpf(gap * 0.5, TAU - gap * 0.5, float(j) / float(cols - 1)))
	# The coat's fitted layer covers waist and hips and follows every pose;
	# the skirt takes over from it just above the widest point of the hips,
	# wrapping her real outline there (not an ellipse), and falls from it.
	var top_y := widest_y + 0.07
	var centre_z: float = widest.cz
	var hip := _outline(widest_y, centre_z, thetas)
	var closed := 1
	var rest := PackedVector3Array()
	for i in rows:
		var t := float(i) / float(rows - 1)
		var y := lerpf(top_y, hem_y, pow(t, 1.15))
		var radii := hip
		if y > widest_y:
			radii = _outline(y, centre_z, thetas)
			closed = i + 1
		var open := clampf((widest_y - y) / (widest_y - hem_y), 0.0, 1.0)
		# Leaves the hips along their own curve, so the fall has no shelf.
		var flare := pow(open, 1.6)
		for j in cols:
			var theta := thetas[j]
			# Back and sides take more of the flare than the front.
			# A modest A-line: it falls close to her legs and opens as she strides.
			var reach := lerpf(0.11, 0.15, 0.5 - 0.5 * cos(theta))
			# The top row tucks just inside the fitted coat (which stands
			# 17 mm proud), so the seam is hidden; it eases out over two rows.
			var standoff := lerpf(0.004, 0.024, clampf(float(i) / 2.0, 0.0, 1.0))
			var r := radii[j] + standoff + reach * flare
			# The folds deepen fast below the hips, and the hollows dip deeper
			# than the crests stand out, as cloth falls.
			var wave := sin(theta * folds)
			r *= 1.0 + 0.11 * pow(open, 0.7) * (wave if wave > 0.0 else wave * 1.3)
			rest.append(Vector3(sin(theta) * r, y, centre_z + cos(theta) * r))
	var skirt := Cloth.new()
	skirt.name = "Wear_Skirt"
	# Heavy velvet: holds its A-line, swings slowly, barely flutters.
	skirt.stiffness = 0.036
	# The rows over the hips hold her shape; the swing starts below them.
	skirt.top_stiffness = 0.35
	skirt.top_rows = 4
	skirt.bend = 0.6
	skirt.damping = 0.075
	skirt.wind_response = 0.035
	skirt.iterations = 3
	var hem := func(_u: float, v: float) -> Color:
		return VELVET.darkened(0.25) if v > 0.97 else VELVET
	# Buttoned down to the hips, open below so she can stride.
	skirt.setup(skeleton, "Hips", rest, cols, rows, closed + 1, hem)
	skirt.material_override = _fabric(Color.WHITE, 0.3, 0.12, 9.0, 0.25)
	add_child(skirt)
	# The hips are held by the measured outline and the stiff top rows (a
	# crude pelvis capsule only shoved them into a shelf); capsules keep the
	# velvet off the striding legs.
	for side_name in ["Left", "Right"]:
		var side := 1.0 if side_name == "Left" else -1.0
		var thigh := _girth(_bone(side_name + "UpperLeg"), _bone(side_name + "LowerLeg"), side)
		var shin := _girth(_bone(side_name + "LowerLeg"), _bone(side_name + "Foot"), side)
		# From a third down the thigh: starting at the hip joint, the capsule's
		# round top shoved the skirt's hip rows out into a shelf.
		var thigh_top := _bone(side_name + "UpperLeg").lerp(_bone(side_name + "LowerLeg"), 0.35)
		skirt.add_capsule(side_name + "UpperLeg", thigh_top, _bone(side_name + "LowerLeg"), thigh + 0.018)
		skirt.add_capsule(side_name + "LowerLeg", _bone(side_name + "LowerLeg"), _bone(side_name + "Foot") + Vector3(0, 0.08, 0), shin + 0.03)


# Long, side-parted, softly waved hair. Every lock is a path: rooted on the
# part or the crown, laid over the skull, then falling down the back, over the
# shoulders, or (the two framing locks) beside the face onto the coat.
func _build_hair() -> void:
	# Grown and draped in Blender on her real scalp (tools/blender/grow_hair.py):
	# one skinned mesh with a sway spring. What follows is only the fallback.
	if HairRig.available():
		HairRig.fit(self, _strand_texture())
		return
	var top_y := -1.0
	for p in _verts:
		top_y = maxf(top_y, p.y)
	var widest_y := _head.y + 0.1
	var skull := _band(widest_y - 0.012, widest_y + 0.012)
	var shoulders := _band(1.3, 1.38)
	var chest := _band(1.22, 1.32)
	var lift := 0.02
	var locks: Array = []
	# Back fall: crown to between the shoulder blades.
	for k in 17:
		var angle := deg_to_rad(lerpf(-104.0, 104.0, float(k) / 16.0))
		var reach := 0.56 + 0.05 * sin(float(k) * 2.3) - 0.08 * absf(sin(angle))
		var root := _scalp(skull, angle, top_y - 0.03, top_y, widest_y, lift)
		var path: Array[Vector3] = [root]
		path.append(_scalp(skull, angle, widest_y + 0.05, top_y, widest_y, lift))
		path.append(_scalp(skull, angle, widest_y - 0.02, top_y, widest_y, lift))
		var fall := Vector3(sin(angle) * (shoulders.rx * 0.62 + 0.03), top_y - reach, shoulders.cz - (shoulders.back + 0.045) * cos(angle) * 0.9)
		locks.append([path, fall, 0.08, false])
	# Side part on her left; most of the hair sweeps across to the right.
	var part_x := 0.032
	for k in 10:
		var t := float(k) / 9.0
		var z: float = lerpf(skull.cz + skull.front * 0.62, skull.cz - skull.back * 0.45, t)
		var side := -1.0 if k < 7 else 1.0
		var root := Vector3(part_x, _crest(top_y, widest_y, z, skull) + lift, z)
		var over := Vector3(side * (skull.rx * 0.72 + lift), widest_y + 0.06, z - 0.01 * t)
		var temple := Vector3(side * (skull.rx + lift + 0.006), widest_y - 0.025, z - 0.015)
		var framing := k == 0 or k == 7
		var fall := Vector3(side * (shoulders.rx * 0.72), 1.2, shoulders.cz - 0.02)
		if framing:
			fall = Vector3(side * 0.125, 1.18, chest.cz + chest.front + 0.035)
		var path: Array[Vector3] = [root, over, temple]
		locks.append([path, fall, 0.062 if framing else 0.075, framing])
	var rows := 11
	var rest := PackedVector3Array()
	rest.resize(rows * locks.size() * 2)
	var centre_head := Vector3(0.0, widest_y, skull.cz)
	for k in locks.size():
		var path: Array[Vector3] = locks[k][0]
		var fall: Vector3 = locks[k][1]
		var width: float = locks[k][2]
		var start: Vector3 = path[path.size() - 1]
		var points: Array[Vector3] = []
		for i in rows:
			if i < path.size():
				points.append(path[i])
				continue
			var t := float(i - path.size() + 1) / float(rows - path.size())
			# Ease out of the skull, then hang: the drop leans toward the fall
			# point while gravity does the rest in the sim.
			var p := start.lerp(fall, t)
			p.x = lerpf(start.x, fall.x, smoothstep(0.0, 0.7, t))
			p.z = lerpf(start.z, fall.z, smoothstep(0.0, 0.7, t))
			var outward := Vector3(p.x, 0.0, p.z - centre_head.z).normalized()
			p += outward * 0.013 * sin(t * 8.5 + float(k) * 1.9) * t
			points.append(p)
		var across := Vector3.RIGHT
		for i in rows:
			var before := points[maxi(i - 1, 0)]
			var after := points[mini(i + 1, rows - 1)]
			var normal := (points[i] - centre_head).normalized()
			var turned := (after - before).cross(normal)
			if turned.length_squared() > 1e-8:
				across = turned.normalized()
			var taper := lerpf(1.0, 0.5, float(i) / float(rows - 1))
			var index := (i * locks.size() + k) * 2
			rest[index] = points[i] - across * width * 0.5 * taper
			rest[index + 1] = points[i] + across * width * 0.5 * taper
	var hair := Cloth.new()
	hair.name = "Wear_Hair"
	hair.panel = 2
	hair.card_uv = true
	hair.card_layers = 3
	hair.layer_gap = 0.0055
	hair.stiffness = 0.022
	# The three rows laid over the skull are carried by the head: the hair
	# moves with the scalp, never on its own. Below them it eases from firm
	# into free swing.
	hair.pinned_rows = 3
	hair.top_stiffness = 0.3
	hair.top_rows = 3
	hair.bend = 0.55
	hair.damping = 0.06
	hair.wind_response = 0.1
	hair.iterations = 2
	var lock_count := locks.size()
	var shade := func(u: float, v: float) -> Color:
		var lock := floori(round(u * float(lock_count * 2 - 1)) / 2.0)
		var tone := 0.86 + 0.28 * fposmod(sin(float(lock) * 12.9898) * 43758.5453, 1.0)
		var color := HAIR_ROOT.lerp(HAIR_TIP, smoothstep(0.3, 1.0, v))
		return Color(color.r * tone, color.g * tone, color.b * tone, 1.0)
	hair.setup(skeleton, "Head", rest, lock_count * 2, rows, 0, shade)
	var hair_material := ShaderMaterial.new()
	hair_material.shader = preload("res://shaders/hair.gdshader")
	hair_material.set_shader_parameter("strands", _strand_texture())
	hair.material_override = hair_material
	_build_crown(skull, top_y, widest_y, part_x, hair_material)
	hair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(hair)
	var skull_r := maxf(skull.rx, maxf(skull.front, skull.back)) + 0.016
	hair.add_capsule("Head", Vector3(0, _head.y + 0.07, skull.cz), Vector3(0, _head.y + 0.11, skull.cz), skull_r)
	hair.add_capsule("Neck", _bone("Neck"), _head, _girth(_bone("Neck"), _head, 0.0) + 0.05)
	var shoulder_r := 0.075
	var shoulder_y := _bone("LeftUpperArm").y + 0.02
	hair.add_capsule("UpperChest", Vector3(-(shoulders.rx - shoulder_r), shoulder_y, shoulders.cz), Vector3(shoulders.rx - shoulder_r, shoulder_y, shoulders.cz), shoulder_r)
	var torso_r := maxf(chest.front, chest.back) + 0.03
	var torso_x := maxf(chest.rx - torso_r, 0.01)
	hair.add_capsule("Chest", Vector3(-torso_x, 1.27, chest.cz), Vector3(torso_x, 1.27, chest.cz), torso_r)
	hair.add_capsule("Spine", Vector3(0, 1.08, chest.cz), Vector3(0, 1.2, chest.cz), torso_r * 0.9)
	for side_name in ["Left", "Right"]:
		var arm := _girth(_bone(side_name + "UpperArm"), _bone(side_name + "LowerArm"), 0.0)
		hair.add_capsule(side_name + "UpperArm", _bone(side_name + "UpperArm"), _bone(side_name + "LowerArm"), arm + 0.035)


## The combed layer over the scalp: many short cards carried rigidly by the
## head, flowing down and away from the side part; at the front they sweep
## sideways to frame the face instead of falling over the forehead. Normals
## point out from the skull centre, so the layer shades as one soft mass.
func _build_crown(skull: Dictionary, top_y: float, widest_y: float, part_x: float, material: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var centre := Vector3(0.0, widest_y - 0.02, skull.cz)
	var front_line := _head.y + 0.165
	var side_line := _head.y + 0.105
	var back_line := _neck_y + 0.08
	# High and level across forehead and temples; it drops only behind the
	# temples, toward the ears and the nape.
	var hairline := func(angle: float) -> float:
		var c := cos(angle)
		var face := smoothstep(-0.25, -0.6, c)
		var nape := smoothstep(0.0, 0.9, c)
		return lerpf(lerpf(side_line, back_line, nape), front_line, face)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cards := 0
	var attempts := 0
	while cards < 150 and attempts < 3000:
		attempts += 1
		var a := rng.randf_range(-PI, PI)
		var line: float = hairline.call(a)
		if line > top_y - 0.03:
			continue
		var y := rng.randf_range(line + 0.008, top_y - 0.004)
		var frontness := clampf(-cos(a), 0.0, 1.0)
		# Away from the part: which side of it the root is on decides the comb.
		var side := 1.0 if sin(a) * skull.rx > part_x else -1.0
		var layer := rng.randi_range(0, 2)
		var lift := 0.011 + 0.006 * float(layer)
		var length := rng.randf_range(0.08, 0.13)
		var width := rng.randf_range(0.032, 0.046)
		var points: Array[Vector3] = []
		var segments := 5
		var angle := a
		var height := y
		for s in segments + 1:
			points.append(_scalp(skull, angle, height, top_y, widest_y, lift))
			var step := length / float(segments)
			# Front hair sweeps toward the temple, the rest falls back and down.
			height -= step * lerpf(0.95, 0.35, frontness)
			angle += side * step * lerpf(0.25, 0.8, frontness) / maxf(skull.rx, 0.05)
			height = maxf(height, float(hairline.call(angle)) - 0.012)
		_crown_card(tool, points, width, centre, rng.randf_range(0.86, 1.12))
		cards += 1
	tool.index()
	var piece := MeshInstance3D.new()
	piece.name = "Wear_Crown"
	piece.mesh = tool.commit()
	piece.material_override = material
	attach("Head", piece, Transform3D.IDENTITY)


func _crown_card(tool: SurfaceTool, points: Array[Vector3], width: float, centre: Vector3, tone: float) -> void:
	var count := points.size()
	var rows: Array = []
	for i in count:
		var along := points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]
		var normal := (points[i] - centre).normalized()
		var across := along.cross(normal).normalized()
		var taper := lerpf(1.0, 0.55, float(i) / float(count - 1))
		var v := float(i) / float(count - 1)
		var color := HAIR_ROOT.lerp(HAIR_TIP, v * 0.35)
		color = Color(color.r * tone, color.g * tone, color.b * tone, 1.0)
		rows.append([points[i] - across * width * 0.5 * taper, points[i] + across * width * 0.5 * taper, normal, v, color])
	for i in count - 1:
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		var quad := [[r0[0], 0.0, r0[3], r0[2], r0[4]], [r0[1], 1.0, r0[3], r0[2], r0[4]], [r1[1], 1.0, r1[3], r1[2], r1[4]], [r1[0], 0.0, r1[3], r1[2], r1[4]]]
		for k in [0, 1, 2, 0, 2, 3]:
			var corner: Array = quad[k]
			tool.set_normal(corner[3])
			tool.set_color(corner[4])
			tool.set_uv(Vector2(corner[1], 0.25 + corner[2] * 0.75))
			tool.add_vertex(corner[0])


# A point on the skull, angle 0 at the back, lifted off the scalp.
func _scalp(skull: Dictionary, angle: float, y: float, top_y: float, widest_y: float, lift: float) -> Vector3:
	var shrink := 1.0
	if y > widest_y:
		var up := (y - widest_y) / maxf(top_y - widest_y, 0.01)
		shrink = maxf(sqrt(maxf(0.0, 1.0 - up * up)), 0.18)
	var depth: float = skull.back if cos(angle) > 0.0 else skull.front
	var p := Vector3(sin(angle) * (skull.rx as float) * shrink, y, (skull.cz as float) - cos(angle) * depth * shrink)
	var centre := Vector3(0.0, widest_y - 0.02, skull.cz)
	return p + (p - centre).normalized() * lift


# Height of the top of the skull at a given z.
func _crest(top_y: float, widest_y: float, z: float, skull: Dictionary) -> float:
	var depth: float = skull.front if z > (skull.cz as float) else skull.back
	var along := (z - (skull.cz as float)) / maxf(depth, 0.01)
	return widest_y + (top_y - widest_y) * sqrt(maxf(0.0, 1.0 - along * along))


# Ankle boots lofted around her measured foot: an ellipse per slice from heel
# to toe, a rounded toe cap and a flat sole, plus a shaft around the ankle.
# They are skinned like her body, so the toe flexes with her toes and the
# shaft with her shin; nothing pokes through in any pose.
func _build_boots() -> void:
	var leather := _fabric(LEATHER, 0.12, 0.04, 30.0, 0.04, LEATHER, 0.6)
	for side in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var weigh := func(p: Vector3) -> void:
			_boot_weights(tool, p, prefix)
		_loft_boot(side, weigh, tool)
		_boot_shaft(side, weigh, tool)
		tool.index()
		tool.generate_normals()
		var boot := MeshInstance3D.new()
		boot.name = "Wear_Boot_" + prefix
		boot.mesh = tool.commit()
		boot.material_override = leather
		boot.skin = body.skin
		skeleton.add_child(boot)
		boot.skeleton = boot.get_path_to(skeleton)


# Bind index of a bone in the body's skin.
func _bind(bone_name: String) -> int:
	var skin := body.skin
	var bone := skeleton.find_bone(bone_name)
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == bone or skin.get_bind_name(i) == bone_name:
			return i
	return 0


func _boot_weights(tool: SurfaceTool, p: Vector3, prefix: String) -> void:
	var foot := _bind(prefix + "Foot")
	var other := foot
	var blend := 0.0
	if p.y > 0.1:
		other = _bind(prefix + "LowerLeg")
		blend = smoothstep(0.1, 0.19, p.y)
	else:
		other = _bind(prefix + "Toes")
		var toe_z := _bone(prefix + "Toes").z
		blend = smoothstep(toe_z - 0.02, toe_z + 0.025, p.z)
	tool.set_bones(PackedInt32Array([foot, other, 0, 0]))
	tool.set_weights(PackedFloat32Array([1.0 - blend, blend, 0.0, 0.0]))


func _boot_shaft(side: float, weigh: Callable, tool: SurfaceTool) -> void:
	var ankle := _bone(("Left" if side > 0.0 else "Right") + "Foot")
	var ring := 18
	var levels := 7
	var rings: Array[PackedVector3Array] = []
	for s in levels:
		# Starts inside the foot part of the boot and ends over the jeans hem.
		var y := lerpf(0.1, 0.235, float(s) / float(levels - 1))
		var lo := Vector2(1.0, 1.0)
		var hi := Vector2(-1.0, -1.0)
		for p in _verts:
			if p.x * side > 0.02 and absf(p.y - y) < 0.014 and absf(p.z - ankle.z) < 0.11:
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		if hi.x < lo.x:
			lo = Vector2(ankle.x - 0.04, ankle.z - 0.04)
			hi = Vector2(ankle.x + 0.04, ankle.z + 0.04)
		var centre := (lo + hi) * 0.5
		var radius := (hi - lo) * 0.5 + Vector2(0.013, 0.013)
		var points := PackedVector3Array()
		for k in ring:
			var phi := TAU * float(k) / float(ring)
			points.append(Vector3(centre.x + radius.x * cos(phi), y, centre.y + radius.y * sin(phi)))
		rings.append(points)
	for s in levels - 1:
		for k in ring:
			var a: Vector3 = rings[s][k]
			var b: Vector3 = rings[s][(k + 1) % ring]
			var c: Vector3 = rings[s + 1][k]
			var d: Vector3 = rings[s + 1][(k + 1) % ring]
			for v in [a, b, d, a, d, c]:
				weigh.call(v)
				tool.add_vertex(v)


func _loft_boot(side: float, weigh: Callable, tool: SurfaceTool) -> void:
	var foot: Array[Vector3] = []
	var min_z := 1.0
	var max_z := -1.0
	for p in _verts:
		if p.x * side > 0.02 and p.y < 0.13:
			foot.append(p)
			min_z = minf(min_z, p.z)
			max_z = maxf(max_z, p.z)
	var count := 14
	var step := (max_z - min_z) / float(count - 1)
	var lows: Array[float] = []
	var highs: Array[float] = []
	var tops: Array[float] = []
	for s in count:
		lows.append(1.0)
		highs.append(-1.0)
		tops.append(0.0)
	for p in foot:
		var s := clampi(roundi((p.z - min_z) / step), 0, count - 1)
		lows[s] = minf(lows[s], p.x)
		highs[s] = maxf(highs[s], p.x)
		tops[s] = maxf(tops[s], p.y)
	for s in count:
		if highs[s] < lows[s]:
			var near := s - 1 if s > 0 else s + 1
			lows[s] = lows[near]
			highs[s] = highs[near]
			tops[s] = tops[near]
	# From the ball forward the last only narrows: one clean taper over the
	# toes instead of five bumps.
	var width := 0.0
	var top := 0.0
	var half_widths: Array[float] = []
	var heights: Array[float] = []
	half_widths.resize(count)
	heights.resize(count)
	for s in range(count - 1, -1, -1):
		width = maxf(width, (highs[s] - lows[s]) * 0.5)
		top = maxf(top, tops[s])
		half_widths[s] = width + 0.009
		heights[s] = top + 0.012
	var ring := 18
	var sole := 0.004
	var rings: Array[PackedVector3Array] = []
	var tip := 3
	for s in count + tip:
		var z: float
		var w: float
		var h: float
		var cx: float
		if s < count:
			z = min_z + step * float(s)
			w = half_widths[s]
			h = heights[s]
			cx = (lows[s] + highs[s]) * 0.5
		else:
			var k := float(s - count + 1) / float(tip + 1)
			var round_off := sqrt(maxf(0.0, 1.0 - k * k))
			z = max_z + 0.03 * k
			w = half_widths[count - 1] * round_off
			h = sole + (heights[count - 1] - sole) * round_off
			cx = (lows[count - 1] + highs[count - 1]) * 0.5
		var points := PackedVector3Array()
		for k in ring:
			var phi := TAU * float(k) / float(ring)
			var cy := (h + sole) * 0.5
			var y := maxf(cy + (h - sole) * 0.5 * sin(phi), sole)
			points.append(Vector3(cx + w * cos(phi), y, z))
		rings.append(points)
	var heel := Vector3((lows[0] + highs[0]) * 0.5, heights[0] * 0.5, min_z - 0.012)
	var toe := Vector3((lows[count - 1] + highs[count - 1]) * 0.5, sole + 0.012, max_z + 0.034)
	for s in rings.size() - 1:
		for k in ring:
			var a: Vector3 = rings[s][k]
			var b: Vector3 = rings[s][(k + 1) % ring]
			var c: Vector3 = rings[s + 1][k]
			var d: Vector3 = rings[s + 1][(k + 1) % ring]
			for v in [a, c, d, a, d, b]:
				weigh.call(v)
				tool.add_vertex(v)
	for k in ring:
		var first: Vector3 = rings[0][k]
		var second: Vector3 = rings[0][(k + 1) % ring]
		for v in [heel, first, second]:
			weigh.call(v)
			tool.add_vertex(v)
		var last := rings[rings.size() - 1]
		for v in [toe, last[(k + 1) % ring], last[k]]:
			weigh.call(v)
			tool.add_vertex(v)


func _strand_texture() -> ImageTexture:
	var width := 128
	var height := 256
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var strand := 2
	for x0 in range(0, width, strand):
		var tone := rng.randf_range(0.72, 1.28)
		var ends := rng.randf_range(0.7, 1.0)
		var present := rng.randf() > 0.14
		var edge := minf(float(x0), float(width - x0)) / float(width)
		if edge < 0.08 and rng.randf() < 0.6:
			present = false
		for y in height:
			var v := float(y) / float(height - 1)
			var alpha := 0.0
			if present:
				alpha = 1.0 - smoothstep(ends - 0.12, ends, v)
			var glint := tone * (0.92 + 0.08 * sin(v * 40.0 + float(x0)))
			for dx in strand:
				var soft := 1.0 if dx == 0 else 0.75
				image.set_pixel(x0 + dx, y, Color(glint, glint, glint, alpha * soft))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# --- Materials and helpers -------------------------------------------------

func _piece(bone: String, mesh: Mesh, rest_transform: Transform3D, material: Material) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	attach(bone, piece, rest_transform)


func _fabric(tint: Color, sheen: float, rim: float, weave_scale: float, weave_depth: float, lining := Color(0.05, 0.04, 0.05), specular := 0.3) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/wear.gdshader")
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("lining", lining)
	material.set_shader_parameter("sheen", sheen)
	material.set_shader_parameter("rim_light", rim)
	material.set_shader_parameter("weave", _weave)
	material.set_shader_parameter("weave_scale", weave_scale)
	material.set_shader_parameter("weave_depth", weave_depth)
	material.set_shader_parameter("specular_level", specular)
	if tint != Color.WHITE:
		# Primitive meshes have no vertex colors; tint carries the dye, and
		# the roughness rides in tint's alpha.
		material.set_shader_parameter("roughness_scale", tint.a)
	return material


func _metal(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 1.0
	material.roughness = 0.32
	return material


func _make_weave() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.09
	noise.fractal_octaves = 2
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = 4.0
	texture.noise = noise
	return texture
