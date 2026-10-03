class_name HouseKit
extends RefCounted

## Building blocks for the house: scanned CC0 materials (Poly Haven, world-space
## triplanar at the scan's real size, as in merl), props, boxes, solids, walls
## with openings, slabs with holes and stairs. Everything solid lands on
## Tune.LAYER_WORLD so the player, the camera arm and door sweeps all see it.

const SCAN := "res://assets/vendor/polyhaven/%s/%s_%s_1k.jpg"
const MODEL := "res://assets/vendor/polyhaven/%s/%s_1k.gltf"
# Scan id -> real-world tile width in metres (assets/vendor/polyhaven/provenance.json).
const SCANS := {
	"long_white_tiles": 1.27,
	"floor_tiles_08": 1.5,
	"white_plaster_rough_01": 1.0,
	"weathered_plank_siding": 1.57,
	"roof_slates_02": 3.0,
}

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func scan(id: String, tint: Color = Color.WHITE, tile_scale: float = 1.0) -> ORMMaterial3D:
	var key := "%s|%s|%s" % [id, tint.to_html(), tile_scale]
	if _cache.has(key):
		return _cache[key]
	var material := ORMMaterial3D.new()
	material.albedo_texture = _texture(id, "diff")
	material.normal_enabled = true
	material.normal_texture = _texture(id, "nor_gl")
	material.orm_texture = _texture(id, "arm")
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = 4.0
	material.uv1_scale = Vector3.ONE / (float(SCANS.get(id, 1.0)) * tile_scale)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = material
	return material


static func paint(color: Color, roughness: float = 0.6, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "paint|%s|%s|%s" % [color.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_cache[key] = material
	return material


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := "glow|%s|%s" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_cache[key] = material
	return material


static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.8, 0.86, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	material.metallic_specular = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["glass"] = material
	return material


## A fresh instance of a scanned prop, or an empty node if it is missing.
static func prop(parent: Node3D, id: String, at: Vector3, yaw_degrees: float = 0.0, scale: float = 1.0) -> Node3D:
	var path: String = MODEL % [id, id]
	var node: Node3D = null
	if ResourceLoader.exists(path):
		node = (load(path) as PackedScene).instantiate() as Node3D
	if node == null:
		push_warning("Missing house prop: %s" % id)
		node = Node3D.new()
	node.name = id
	node.position = at
	node.rotation.y = deg_to_rad(yaw_degrees)
	node.scale = Vector3.ONE * scale
	parent.add_child(node)
	return node


## Visual-only box.
static func box(parent: Node3D, name: String, center: Vector3, size: Vector3, material: Material, yaw: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	instance.rotation.y = yaw
	parent.add_child(instance)
	return instance


## A box you collide with.
static func solid(parent: Node3D, name: String, center: Vector3, size: Vector3, material: Material, yaw: float = 0.0) -> MeshInstance3D:
	var instance := box(parent, name, center, size, material, yaw)
	blocker(parent, name + "Body", center, size, yaw)
	return instance


## Collision only.
static func blocker(parent: Node3D, name: String, center: Vector3, size: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	body.position = center
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body


## A straight wall from a to b (x/z in parent space), solid, with openings.
## Each opening: {"at": distance from a to its centre, "width", "height",
## "sill": height of its bottom above the wall's bottom}.
## `inner`/`outer` finish the two faces (the outer face is the +normal side,
## normal = up x direction); pass null to use `core` for that face.
static func wall(parent: Node3D, name: String, a: Vector2, b: Vector2, bottom: float, top: float, thickness: float, core: Material, openings: Array = [], inner: Material = null, outer: Material = null) -> void:
	var run := b - a
	var length := run.length()
	if length < 0.01:
		return
	var axis := run / length
	var yaw := atan2(-axis.y, axis.x)
	var pieces: Array = []
	var cursor := 0.0
	var sorted := openings.duplicate()
	sorted.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["at"]) < float(q["at"]))
	for opening in sorted:
		var half := float(opening["width"]) * 0.5
		var from := float(opening["at"]) - half
		var to := float(opening["at"]) + half
		if from > cursor:
			pieces.append([cursor, from, bottom, top])
		var sill := bottom + float(opening.get("sill", 0.0))
		var head := sill + float(opening["height"])
		if sill > bottom + 0.005:
			pieces.append([from, to, bottom, sill])
		if head < top - 0.005:
			pieces.append([from, to, head, top])
		cursor = to
	if cursor < length:
		pieces.append([cursor, length, bottom, top])
	var normal := Vector2(-axis.y, axis.x)
	for index in pieces.size():
		var piece: Array = pieces[index]
		var mid := (float(piece[0]) + float(piece[1])) * 0.5
		var along := float(piece[1]) - float(piece[0])
		var height := float(piece[3]) - float(piece[2])
		var at2 := a + axis * mid
		var center := Vector3(at2.x, (float(piece[2]) + float(piece[3])) * 0.5, at2.y)
		solid(parent, "%s_%d" % [name, index], center, Vector3(along, height, thickness), core, yaw)
		for face in [[inner, -1.0], [outer, 1.0]]:
			if face[0] == null:
				continue
			var offset := normal * (thickness * 0.5 + 0.004) * float(face[1])
			box(parent, "%s_%d_face%d" % [name, index, int(face[1])], center + Vector3(offset.x, 0.0, offset.y), Vector3(along, height, 0.008), face[0], yaw)


## A horizontal slab over `rect` (x/z) between y0 and y1, with rectangular holes.
static func slab(parent: Node3D, name: String, rect: Rect2, y0: float, y1: float, material: Material, holes: Array = [], collide: bool = true) -> void:
	var pieces: Array = [rect]
	for hole in holes:
		var next: Array = []
		for piece in pieces:
			next.append_array(_subtract(piece, hole))
		pieces = next
	for index in pieces.size():
		var piece: Rect2 = pieces[index]
		var center := Vector3(piece.get_center().x, (y0 + y1) * 0.5, piece.get_center().y)
		var size := Vector3(piece.size.x, y1 - y0, piece.size.y)
		if collide:
			solid(parent, "%s_%d" % [name, index], center, size, material)
		else:
			box(parent, "%s_%d" % [name, index], center, size, material)


## A straight flight down along -X from `top` (top-step front edge, floor
## level) to `bottom`. Treads are visual; one smooth ramp carries the player.
static func stair(parent: Node3D, name: String, top: Vector3, bottom: Vector3, width: float, steps: int, tread: Material, riser: Material) -> void:
	var run := top.x - bottom.x
	var rise := top.y - bottom.y
	var going := run / float(steps)
	var step_rise := rise / float(steps)
	for index in steps:
		var y := top.y - step_rise * float(index + 1)
		var x := top.x - going * (float(index) + 0.5)
		box(parent, "%sTread_%02d" % [name, index], Vector3(x, y - 0.02, top.z), Vector3(going + 0.03, 0.04, width), tread)
		box(parent, "%sRiser_%02d" % [name, index], Vector3(x + going * 0.5, y + step_rise * 0.5, top.z), Vector3(0.02, step_rise, width), riser)
		box(parent, "%sFill_%02d" % [name, index], Vector3(x, y - step_rise * 0.5 - 0.04, top.z), Vector3(going, step_rise, width - 0.02), riser)
	# The ramp: a thin solid along the nosings.
	var slope := Vector3(-run, -rise, 0.0)
	var length := slope.length()
	var body := StaticBody3D.new()
	body.name = name + "Ramp"
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var middle := (top + bottom) * 0.5 + Vector3(0.0, -0.06, 0.0)
	body.transform = Transform3D(Basis(Vector3.BACK, atan2(rise, run)), middle)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(length, 0.1, width)
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)


static func light(parent: Node3D, name: String, at: Vector3, color: Color, energy: float, reach: float, shadows: bool = false) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = name
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = shadows
	parent.add_child(lamp)
	return lamp


static func _subtract(rect: Rect2, hole: Rect2) -> Array:
	if not rect.intersects(hole):
		return [rect]
	var cut := rect.intersection(hole)
	var out: Array = []
	if cut.position.x > rect.position.x:
		out.append(Rect2(rect.position.x, rect.position.y, cut.position.x - rect.position.x, rect.size.y))
	if cut.end.x < rect.end.x:
		out.append(Rect2(cut.end.x, rect.position.y, rect.end.x - cut.end.x, rect.size.y))
	if cut.position.y > rect.position.y:
		out.append(Rect2(cut.position.x, rect.position.y, cut.size.x, cut.position.y - rect.position.y))
	if cut.end.y < rect.end.y:
		out.append(Rect2(cut.position.x, cut.end.y, cut.size.x, rect.end.y - cut.end.y))
	return out


static func _texture(id: String, kind: String) -> Texture2D:
	var path: String = SCAN % [id, id, kind]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
