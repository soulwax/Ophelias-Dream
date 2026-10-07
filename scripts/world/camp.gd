class_name Camp
extends Node3D

## Mathilda's camp beyond the pines (docs/MATHILDA_POV.md): a canvas ridge tent,
## a stone-ringed fire with a log tepee, coals, shader flames, sparks and smoke,
## a woodpile with an axe, a stool, a crate table, and a lantern on a stump.
## The wooden props and the note come from the owner's asset bank
## (tools/curate_camp_assets.py, ignored); without them the camp builds
## stand-ins. The lantern is Poly Haven's CC0 Lantern_01. It replaces Trail's stylised tent and fire, which stay in the
## tree but hidden, so the editable level still lines up child for child.

const BANK := "res://assets/vendor/requested_camp/"
const OFFSET := 98.0
# Places in the route frame: x out from the route, y along it.
const FIRE := Vector2(4.4, 0.0)
const TENT := Vector2(7.5, 0.0)
const WOODPILE := Vector2(7.3, -1.75)
const STOOL := Vector2(4.6, -1.35)
const CRATE := Vector2(5.15, 1.45)
const STUMP := Vector2(6.05, 1.1)
const TENT_LENGTH := 2.3
const TENT_WIDTH := 1.9
const TENT_HEIGHT := 1.35
const LAYER_PROPS := 2
# The melted patch round the fire, in metres across: as the fire was lit,
# and once it has burned Tune.CAMP_MELT_SECONDS.
const MELT_START := 1.75
const MELT_END := 2.7

signal built

## Where Mathilda finds her things: "cups", "gloves", "note".
var spots := {}
var is_built := false
var fire_light: OmniLight3D

var _flat := Basis.IDENTITY
var _origin := Vector3.ZERO
var _lantern_light: OmniLight3D
var _noise := FastNoiseLite.new()
var _time := 0.0
var _materials := {}
var _sound: AudioStreamPlayer3D
var _melt_decal: Decal
var _melted := 0.0
# The windward tent corner, worked loose by the storm until someone mends it.
var _tent_sag_line: MeshInstance3D
var _tent_sag_peg: MeshInstance3D
var _tent_pole_top := Vector3.ZERO
var _tent_taut_peg := Vector3.ZERO
var tent_mended := true
# A brief, decaying brightening when the fire is fed (Mathilda's camp chore).
var _stoke_boost := 0.0


func _ready() -> void:
	name = "Camp"
	add_to_group("camp")
	_noise.seed = 1701
	_noise.frequency = 1.0
	ensure_built.call_deferred()


func ensure_built() -> void:
	if is_built or Game.trail == null:
		return
	var trail := Game.trail
	var frame := trail.frame_at(trail.player_start_offset + OFFSET)
	var x_dir := Vector3(frame.basis.x.x, 0.0, frame.basis.x.z).normalized()
	_flat = Basis(x_dir, Vector3.UP, x_dir.cross(Vector3.UP))
	_origin = frame.origin
	_hide_old(trail)
	_build_fire()
	_build_tent()
	_build_woodpile()
	_build_seating()
	_build_lantern()
	_build_sound()
	is_built = true
	built.emit()


func _process(delta: float) -> void:
	if not is_built:
		return
	_time += delta
	var flicker := _noise.get_noise_1d(_time * 7.0) * 0.5 + _noise.get_noise_1d(_time * 23.0 + 40.0) * 0.25
	_stoke_boost = maxf(_stoke_boost - delta / 2.4, 0.0)
	fire_light.light_energy = 2.3 * (1.0 + flicker * 0.35) * (1.0 + _stoke_boost * 0.55)
	fire_light.position = _at(FIRE, 0.55) + Vector3(_noise.get_noise_1d(_time * 3.0 + 9.0), 0.0, _noise.get_noise_1d(_time * 3.0 + 70.0)) * 0.05
	if _lantern_light:
		_lantern_light.light_energy = 0.7 * (1.0 + _noise.get_noise_1d(_time * 11.0 + 200.0) * 0.12)
	# The snow gives way slowly, fastest at first.
	if _melt_decal and Game.awake() and _melted < 1.0:
		_melted = minf(_melted + delta / Tune.CAMP_MELT_SECONDS, 1.0)
		var across := lerpf(MELT_START, MELT_END, 1.0 - pow(1.0 - _melted, 2.0))
		_melt_decal.size = Vector3(across, 1.4, across)


## A log on the fire: a brief, visible flare that eases back to normal over a
## couple of seconds. Called from her chapter when she feeds the fire.
func stoke() -> void:
	_stoke_boost = 1.0


## A corner line the storm worked loose: slack, with the peg half pulled.
func _sag_tent_line() -> void:
	if _tent_sag_line == null:
		return
	tent_mended = false
	var slack := _tent_pole_top.lerp(_tent_taut_peg, 0.55) + Vector3(0.0, -0.22, 0.12)
	_aim_line(_tent_sag_line, _tent_pole_top, slack)
	_tent_sag_peg.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(68.0)), _tent_taut_peg + Vector3(0.05, 0.015, 0.05))


## Re-pegs and re-tautens the sagging corner. Called from her chapter.
func mend_tent_line() -> void:
	if tent_mended or _tent_sag_line == null:
		return
	tent_mended = true
	var line := _tent_sag_line
	var pole := _tent_pole_top
	var peg := _tent_taut_peg
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _aim_line(line, pole, pole.lerp(peg, t)), 0.0, 1.0, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var peg_tween := create_tween().set_parallel(true)
	peg_tween.tween_property(_tent_sag_peg, "position", peg + Vector3(0.0, 0.03, 0.0), 0.32)
	peg_tween.tween_property(_tent_sag_peg, "rotation", Vector3(0.0, 0.0, 0.25), 0.32)


## Places one of Mathilda's things at its spot and returns it.
func place_story_prop(id: String) -> Node3D:
	ensure_built()
	var node := Node3D.new()
	node.name = "Story_" + id
	add_child(node)
	node.position = spots[id]
	node.basis = _flat
	match id:
		"cups":
			for i in 2:
				var cup := _bank_prop("leartes/SM_Cup.gltf", 0.11)
				if cup == null:
					cup = _fallback_cup()
				cup.position = Vector3(-0.07 + i * 0.15, 0.0, 0.03 * i)
				cup.rotation.y = i * 1.9
				node.add_child(cup)
		"gloves":
			node.add_child(_mitten(Vector3(-0.06, 0.0, 0.0), 0.3))
			node.add_child(_mitten(Vector3(0.08, 0.035, 0.03), -0.5))
		"note":
			var note := _bank_scan("note", 0.21, true)
			if note == null:
				note = _paper()
			note.rotation.y = 0.35
			node.add_child(note)
	return node


# ---------------------------------------------------------------- placement

## A world position for one of the route-frame offsets above (FIRE, WOODPILE,
## TENT, ...), for anything outside this file that needs to stand there —
## Mathilda's own chores, before she decides whether to go back.
func world_at(p: Vector2, lift := 0.0) -> Vector3:
	return _at(p, lift)


func _at(p: Vector2, lift := 0.0) -> Vector3:
	var world := _origin + _flat.x * p.x + _flat.z * p.y
	return Game.trail.on_ground(world) + Vector3.UP * lift


func _hide_old(trail: Trail) -> void:
	var tent := _at(TENT)
	var lamp := trail.on_ground(_origin) + Vector3(0, 0.7, 0)
	for child in trail.get_children():
		var n := str(child.name)
		if n.begins_with("SM_Prop_Tent_01") or n.begins_with("SM_Prop_Campfire_01"):
			(child as Node3D).visible = false
			child.set_meta("replaced_by", "Camp")
		elif child is OmniLight3D and (child as Node3D).global_position.distance_to(lamp) < 1.0:
			(child as OmniLight3D).visible = false
			child.set_meta("replaced_by", "Camp")
		elif child is StaticBody3D:
			var at := (child as Node3D).global_position
			if Vector2(at.x - tent.x, at.z - tent.z).length() < 0.6:
				(child as StaticBody3D).collision_layer = 0


func _mesh_node(mesh: Mesh, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if material:
		node.material_override = material
	node.layers = LAYER_PROPS
	parent.add_child(node)
	return node


func _blocker(at: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_transform = Transform3D(_flat * basis, at + Vector3.UP * size.y * 0.5)


# ---------------------------------------------------------------- asset bank

## The LOD0 of a Leartes glTF with its ORM map wired in, scaled so its height
## (or longest side with `by_length`) is `size` metres. Null if the bank is absent.
func _bank_prop(path: String, size: float, by_length := false) -> Node3D:
	var full := BANK + path
	if not ResourceLoader.exists(full):
		return null
	var scene := load(full) as PackedScene
	if scene == null:
		return null
	var source := scene.instantiate()
	var lod: MeshInstance3D = null
	for node in source.find_children("*", "MeshInstance3D", true, false):
		if str(node.name).ends_with("LOD0"):
			lod = node
			break
	if lod == null:
		source.free()
		return null
	var mesh := lod.mesh
	var holder := Node3D.new()
	var mi := _mesh_node(mesh, null, holder)
	for s in mesh.get_surface_count():
		mi.set_surface_override_material(s, _orm_from(mesh.surface_get_material(s)))
	source.free()
	var box := mesh.get_aabb()
	var extent := maxf(box.size.x, maxf(box.size.y, box.size.z)) if by_length else box.size.y
	var k := size / maxf(extent, 0.001)
	mi.scale = Vector3.ONE * k
	mi.position = Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k)
	return holder


func _orm_from(source: Material) -> Material:
	var base := source as BaseMaterial3D
	if base == null or base.albedo_texture == null:
		return source
	var key := base.albedo_texture.resource_path
	if _materials.has(key):
		return _materials[key]
	var material := ORMMaterial3D.new()
	material.albedo_texture = base.albedo_texture
	material.normal_enabled = base.normal_texture != null
	material.normal_texture = base.normal_texture
	var orm_path := key.replace("_B.png", "_ORM.png")
	if ResourceLoader.exists(orm_path):
		material.orm_texture = load(orm_path)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = material
	return material


## A WW2 photoscan (lamp or note) from its FBX, with the packed ORM.
func _bank_scan(id: String, size: float, by_length := false) -> Node3D:
	var dir := BANK + id + "/"
	var fbx := dir + ("SM_WW2_Lamp_c1_LOD0.fbx" if id == "lamp" else "SM_WW2_NoteSheet01_c1_LOD0.fbx")
	if not ResourceLoader.exists(fbx):
		return null
	var scene := load(fbx) as PackedScene
	if scene == null:
		return null
	var source := scene.instantiate()
	var found := source.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		source.free()
		return null
	var src := found[0] as MeshInstance3D
	var mesh := src.mesh
	var to_root := Transform3D.IDENTITY
	var walk: Node = src
	while walk != source and walk is Node3D:
		to_root = (walk as Node3D).transform * to_root
		walk = walk.get_parent()
	source.free()
	var material := ORMMaterial3D.new()
	material.albedo_texture = load(dir + id + "_albedo.png")
	material.normal_enabled = true
	material.normal_texture = load(dir + id + "_normal.png")
	material.orm_texture = load(dir + id + "_orm.png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if id == "note":
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var holder := Node3D.new()
	var mi := _mesh_node(mesh, material, holder)
	var box := to_root * mesh.get_aabb()
	var extent := maxf(box.size.x, maxf(box.size.y, box.size.z)) if by_length else box.size.y
	var k := size / maxf(extent, 0.001)
	mi.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), Vector3.ZERO) * to_root
	var scaled := mi.transform * mesh.get_aabb()
	mi.position -= Vector3(scaled.get_center().x, scaled.position.y, scaled.get_center().z)
	return holder


func _wood() -> Material:
	if _materials.has("wood"):
		return _materials["wood"]
	var material := ORMMaterial3D.new()
	var albedo := BANK + "leartes/T_Wooden_B.png"
	if ResourceLoader.exists(albedo):
		material.albedo_texture = load(albedo)
		material.normal_enabled = true
		material.normal_texture = load(BANK + "leartes/T_Wooden_N.png")
		material.orm_texture = load(BANK + "leartes/T_Wooden_ORM.png")
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 1.6
	else:
		material.albedo_color = Color("5c4632")
		material.roughness = 0.9
	_materials["wood"] = material
	return material


# ---------------------------------------------------------------- the fire

func _build_fire() -> void:
	var c := _at(FIRE)
	var root := Node3D.new()
	root.name = "Fire"
	add_child(root)
	_scorch(c)
	var lean := Game.lean_graphics
	# Ring of fieldstones, sooted on the side that faces the fire.
	var stones: Array[Mesh] = [_rock_mesh(11), _rock_mesh(23), _rock_mesh(37)]
	var rock := HouseKit.scan("aerial_grass_rock", Color(0.78, 0.77, 0.75), 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var count := 13
	for i in count:
		var a := TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / count
		var r := 0.62 + rng.randf_range(-0.04, 0.05)
		var at := c + (_flat.x * cos(a) + _flat.z * sin(a)) * r
		var node := _mesh_node(stones[i % stones.size()], rock, root)
		node.scale = Vector3(rng.randf_range(0.13, 0.2), rng.randf_range(0.09, 0.13), rng.randf_range(0.11, 0.17))
		node.global_position = Game.trail.on_ground(at) + Vector3.UP * (node.scale.y * 0.35)
		node.rotation = Vector3(rng.randf_range(-0.25, 0.25), a + rng.randf_range(-0.6, 0.6), rng.randf_range(-0.25, 0.25))
	# Bed of coals.
	var embers := ShaderMaterial.new()
	embers.shader = load("res://shaders/camp_embers.gdshader")
	embers.set_shader_parameter("noise", _noise_texture(0.06, false))
	var bed := CylinderMesh.new()
	bed.top_radius = 0.28
	bed.bottom_radius = 0.4
	bed.height = 0.05
	_mesh_node(bed, embers, root).global_position = c + Vector3.UP * 0.02
	var coal := SphereMesh.new()
	coal.radius = 1.0
	coal.height = 2.0
	coal.radial_segments = 8
	coal.rings = 5
	for i in 14:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.34
		var node := _mesh_node(coal, embers, root)
		node.scale = Vector3(rng.randf_range(0.03, 0.07), rng.randf_range(0.02, 0.04), rng.randf_range(0.03, 0.06))
		node.global_position = c + (_flat.x * cos(a) + _flat.z * sin(a)) * r + Vector3.UP * 0.06
	# Log tepee, charred at the foot.
	var charred := _charred()
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var base := c + (_flat.x * cos(a) + _flat.z * sin(a)) * 0.36 + Vector3.UP * 0.05
		var top := c + Vector3.UP * 0.52 + (_flat.x * cos(a) + _flat.z * sin(a)) * 0.04
		_log(root, (base + top) * 0.5, (top - base).normalized(), base.distance_to(top) + 0.08, charred)
	# Two logs lying across the coals.
	for i in 2:
		var a := 0.9 + i * 1.7
		var dir := (_flat.x * cos(a) + _flat.z * sin(a))
		_log(root, c + Vector3.UP * 0.1 + dir.cross(Vector3.UP) * (0.1 - i * 0.2), dir, 0.7, charred)
	_blocker(c, Vector3(1.3, 0.35, 1.3))
	# Flames (shader layers), sparks and smoke.
	_flame_layers(root, c + Vector3.UP * 0.06)
	root.add_child(_sparks(c + Vector3.UP * 0.35, 12 if lean else 22))
	root.add_child(_smoke(c + Vector3.UP * 0.7, 10 if lean else 18))
	fire_light = OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.light_color = Color(1.0, 0.56, 0.26)
	fire_light.light_energy = 2.3
	fire_light.omni_range = 10.0
	fire_light.omni_attenuation = 1.3
	fire_light.shadow_enabled = true
	# Camp props and the player still cast fire shadows. A whole forest batch
	# must not be submitted to all six faces of this small light's shadow map.
	fire_light.shadow_caster_mask = 0xFFFFF & ~Tune.FOREST_RENDER_LAYER
	fire_light.shadow_bias = 0.05
	# A fire lights the snow softly; full specular turns its glints into sparks.
	fire_light.light_specular = 0.15
	fire_light.light_volumetric_fog_energy = 0.8
	fire_light.position = c + Vector3.UP * 0.55
	root.add_child(fire_light)


func _charred() -> Material:
	var source := _wood()
	var material := source.duplicate() as BaseMaterial3D
	material.albedo_color = Color(0.36, 0.33, 0.31)
	return material


## A fieldstone: a sphere pushed in and out by noise, so no two faces agree.
func _rock_mesh(seed_value: int) -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 18
	sphere.rings = 10
	var arrays := sphere.get_mesh_arrays()
	var shape := FastNoiseLite.new()
	shape.seed = seed_value
	shape.frequency = 1.1
	shape.fractal_octaves = 3
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for index in indices:
		var v := verts[index]
		var dir := v.normalized()
		var bump := 1.0 + shape.get_noise_3dv(dir * 1.7) * 0.35
		var flat := v * bump
		flat.y = maxf(flat.y, -0.55)
		st.set_uv(uvs[index])
		st.add_vertex(flat)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## A split log between two points: the bank's firewood, or a stand-in cylinder.
func _log(parent: Node3D, center: Vector3, along: Vector3, length: float, material: Material) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	var wood := _bank_prop("leartes/SM_Firewood.gltf", length, true)
	if wood:
		for mi in wood.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				(mi as MeshInstance3D).set_surface_override_material(s, material)
		holder.add_child(wood)
		wood.position = Vector3(0.0, -0.045 * length / 0.79, 0.0)
	else:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.055
		cyl.bottom_radius = 0.06
		cyl.height = length
		var node := _mesh_node(cyl, material, holder)
		node.rotation.x = PI * 0.5
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else _flat.x
	holder.global_transform = Transform3D(Basis.looking_at(along, up), center)


func _scorch(c: Vector3) -> void:
	var size := 192
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var orm := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var grain := FastNoiseLite.new()
	grain.seed = 77
	grain.frequency = 0.05
	for y in size:
		for x in size:
			var p := Vector2(x, y) / size * 2.0 - Vector2.ONE
			var n := grain.get_noise_2d(x, y)
			var r := p.length() + n * 0.16
			var ash := clampf(1.0 - r * 1.7, 0.0, 1.0)
			# Grey ash at the heart, wet dark earth, then a rim of slush and
			# meltwater where the snow is still giving way.
			var rim := smoothstep(0.55, 0.75, r) * (1.0 - smoothstep(0.78, 0.97, r))
			var col := Color(0.17, 0.14, 0.12).lerp(Color(0.3, 0.29, 0.28), ash * 0.8)
			col = col.lerp(Color(0.62, 0.66, 0.7), rim * 0.55)
			col.a = (1.0 - smoothstep(0.7, 0.98, r)) * 0.9
			image.set_pixel(x, y, col)
			var wet := smoothstep(0.25, 0.6, r) * (1.0 - smoothstep(0.85, 0.98, r))
			orm.set_pixel(x, y, Color(1.0, lerpf(0.9, 0.12, wet), 0.0, 1.0))
	image.generate_mipmaps()
	orm.generate_mipmaps()
	var decal := Decal.new()
	decal.name = "MeltedGround"
	decal.texture_albedo = ImageTexture.create_from_image(image)
	decal.texture_orm = ImageTexture.create_from_image(orm)
	decal.size = Vector3(MELT_START, 1.4, MELT_START)
	_melt_decal = decal
	decal.cull_mask = 1
	decal.upper_fade = 0.2
	decal.lower_fade = 0.2
	decal.position = c
	decal.basis = _flat
	add_child(decal)


## The flames are shader layers, each an upright quad turning to the camera
## with its own seed, offset a little so the fire has depth from any side.
func _flame_layers(root: Node3D, at: Vector3) -> void:
	var shader := load("res://shaders/camp_flame.gdshader") as Shader
	var noise := _noise_texture(0.03, true)
	var layers := [
		[Vector3(0.0, 0.0, 0.0), Vector2(0.62, 0.95), 0.0, 2.2],
		[Vector3(0.07, 0.0, 0.05), Vector2(0.5, 0.78), 0.37, 2.0],
		[Vector3(-0.08, 0.0, -0.04), Vector2(0.46, 0.7), 0.71, 2.0],
		[Vector3(0.0, 0.0, 0.0), Vector2(0.34, 0.5), 0.13, 2.8],
	]
	for i in layers.size():
		var spec: Array = layers[i]
		var quad := QuadMesh.new()
		quad.size = spec[1]
		quad.center_offset = Vector3(0, (spec[1] as Vector2).y * 0.5, 0)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("noise", noise)
		material.set_shader_parameter("seed", spec[2])
		material.set_shader_parameter("brightness", spec[3])
		material.render_priority = i
		var node := _mesh_node(quad, material, root)
		node.name = "Flame_%d" % i
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.global_position = at + _flat * (spec[0] as Vector3)
		node.custom_aabb = AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 1.2, 1.2))


func _sparks(at: Vector3, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Sparks"
	p.amount = amount
	p.lifetime = 1.8
	p.randomness = 0.6
	p.local_coords = false
	p.layers = LAYER_PROPS
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3.UP
	pm.spread = 22.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.9
	pm.gravity = Vector3(0, 0.25, 0)
	pm.damping_min = 0.3
	pm.damping_max = 0.8
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 1.4
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	pm.color_ramp = ramp_texture
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.022, 0.022)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(3.0, 2.0, 1.2)
	quad.material = mat
	p.draw_pass_1 = quad
	p.position = at
	return p


func _smoke(at: Vector3, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = amount
	p.lifetime = 7.5
	p.randomness = 0.35
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.local_coords = false
	p.layers = LAYER_PROPS
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 9, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.65
	# Rises, slows, and drifts off with the air.
	pm.gravity = Vector3(0.16, 0.06, 0.07)
	pm.damping_min = 0.04
	pm.damping_max = 0.1
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.55
	pm.turbulence_noise_scale = 2.6
	pm.turbulence_noise_speed_random = 0.4
	pm.scale_min = 0.45
	pm.scale_max = 0.75
	pm.scale_curve = _curve([Vector2(0, 0.3), Vector2(0.4, 1.4), Vector2(1, 2.9)])
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	# Young smoke is thick and blue-grey; it pales and thins as it climbs.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(0.62, 0.64, 0.7, 0.9), Color(0.82, 0.83, 0.86, 0.75), Color(1.0, 1.0, 1.0, 0.45)])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	pm.color_ramp = ramp_texture
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/camp_smoke.gdshader")
	mat.set_shader_parameter("noise", _noise_texture(0.02, true))
	quad.material = mat
	p.draw_pass_1 = quad
	p.position = at
	return p


func _curve(points: Array) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = 3.0
	for point in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _noise_texture(frequency: float, seamless: bool, normal := false) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 2026
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = seamless or normal
	texture.noise = noise
	if normal:
		texture.as_normal_map = true
		texture.bump_strength = 6.0
	return texture


# ---------------------------------------------------------------- the tent

func _build_tent() -> void:
	var tent := Node3D.new()
	tent.name = "Tent"
	add_child(tent)
	var base := _at(TENT)
	# The door faces the fire, along -x of the route frame.
	tent.global_transform = Transform3D(_flat, base)
	var canvas := ShaderMaterial.new()
	canvas.shader = load("res://shaders/camp_canvas.gdshader")
	var weave := FastNoiseLite.new()
	weave.noise_type = FastNoiseLite.TYPE_CELLULAR
	weave.frequency = 0.35
	var weave_texture := NoiseTexture2D.new()
	weave_texture.width = 256
	weave_texture.height = 256
	weave_texture.seamless = true
	weave_texture.as_normal_map = true
	weave_texture.bump_strength = 3.0
	weave_texture.noise = weave
	canvas.set_shader_parameter("weave", weave_texture)
	canvas.set_shader_parameter("grime", _noise_texture(0.012, true))
	canvas.set_shader_parameter("height", TENT_HEIGHT)
	var l := TENT_LENGTH * 0.5
	var w := TENT_WIDTH * 0.5
	var h := TENT_HEIGHT
	# Roof panels, sagging a little between the poles.
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cols := 14
		var rows := 8
		var slant := Vector2(w, h).length()
		for i in rows:
			for j in cols:
				var quad := [Vector2(j, i), Vector2(j + 1, i), Vector2(j + 1, i + 1), Vector2(j, i), Vector2(j + 1, i + 1), Vector2(j, i + 1)]
				if side > 0.0:
					quad = [quad[0], quad[2], quad[1], quad[3], quad[5], quad[4]]
				for q in quad:
					var u: float = q.x / cols
					var v: float = q.y / rows
					var sag := sin(PI * u) * sin(PI * v) * 0.06 + sin(PI * u * 3.0) * sin(PI * v) * 0.012
					var point := Vector3(lerpf(-l - 0.12, l + 0.12, u), lerpf(h, 0.04, v), side * lerpf(0.0, w, v))
					point -= Vector3(0.0, sag * 0.7, side * sag * 0.5)
					st.set_uv(Vector2(u * (TENT_LENGTH + 0.24), v * slant))
					st.add_vertex(point)
		st.generate_normals()
		st.generate_tangents()
		_mesh_node(st.commit(), canvas, tent)
	# Back wall and the front: one flap closed, one tied back.
	_triangle(tent, canvas, [Vector3(l, h, 0), Vector3(l, 0.03, -w), Vector3(l, 0.03, w)], 1.0)
	_triangle(tent, canvas, [Vector3(-l, h, 0), Vector3(-l, 0.03, 0.0), Vector3(-l, 0.03, -w)], -1.0)
	var flap := Node3D.new()
	tent.add_child(flap)
	flap.position = Vector3(-l, 0.0, w)
	flap.rotation.y = deg_to_rad(-62.0)
	_triangle(flap, canvas, [Vector3(0, h, -w), Vector3(0, 0.03, 0.0), Vector3(0, 0.03, -w * 0.45)], -1.0)
	# Inside: a groundsheet, a sleeping bag and a pillow in the warm dark.
	_mesh_node(_box(Vector3(TENT_LENGTH - 0.1, 0.01, TENT_WIDTH - 0.15)), HouseKit.paint(Color("1c2420"), 0.8), tent).position = Vector3(0, 0.01, 0)
	var bag := CapsuleMesh.new()
	bag.radius = 0.24
	bag.height = 1.85
	var bag_node := _mesh_node(bag, HouseKit.paint(Color("5a2a24"), 0.55), tent)
	bag_node.rotation = Vector3(0, 0, PI * 0.5)
	bag_node.scale = Vector3(1.0, 1.0, 0.55)
	bag_node.position = Vector3(0.05, 0.13, 0.32)
	_mesh_node(_box(Vector3(0.38, 0.12, 0.3)), HouseKit.paint(Color("b9b2a2"), 0.9), tent).position = Vector3(0.82, 0.08, -0.35)
	var inner := OmniLight3D.new()
	inner.light_color = Color(1.0, 0.62, 0.32)
	inner.light_energy = 0.35
	inner.omni_range = 1.9
	inner.position = Vector3(0.2, 0.7, 0)
	tent.add_child(inner)
	# Poles, guy lines and pegs.
	var pole := CylinderMesh.new()
	pole.top_radius = 0.018
	pole.bottom_radius = 0.02
	pole.height = h + 0.12
	for x in [-l, l]:
		_mesh_node(pole, _wood(), tent).position = Vector3(x, (h + 0.12) * 0.5, 0)
	var rope := HouseKit.paint(Color("c9bb98"), 0.9)
	for x in [-l, l]:
		var top := Vector3(x, h + 0.08, 0)
		var peg := Vector3(x + signf(x) * 1.0, 0.0, 0)
		if x < 0.0:
			# The windward corner: the storm has worked this one loose. A visit
			# can mend it, which is where she starts, not where she's going.
			_tent_pole_top = top
			_tent_taut_peg = peg
			_tent_sag_peg = _peg(tent, peg)
			_tent_sag_line = _line(tent, rope, top, peg)
			_sag_tent_line()
			continue
		_line(tent, rope, top, peg)
		_peg(tent, peg)
	for x in [-l * 0.9, 0.0, l * 0.9]:
		for side in [-1.0, 1.0]:
			var eave := Vector3(x, 0.08, side * w)
			var peg := Vector3(x, 0.0, side * (w + 0.45))
			_line(tent, rope, eave, peg)
			_peg(tent, peg)
	_blocker(base, Vector3(TENT_LENGTH, h * 0.8, TENT_WIDTH))


func _triangle(parent: Node3D, material: Material, points: Array, facing: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var order := [0, 1, 2] if facing > 0.0 else [0, 2, 1]
	for k in order:
		var p: Vector3 = points[k]
		st.set_uv(Vector2(p.z, -p.y) + Vector2(1.0, 1.4))
		st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()
	_mesh_node(st.commit(), material, parent)


func _line(parent: Node3D, material: Material, a: Vector3, b: Vector3) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0035
	cyl.bottom_radius = 0.0035
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 5
	var node := _mesh_node(cyl, material, parent)
	_aim_line(node, a, b)
	return node


## Re-aims an existing line mesh between two LOCAL points (same space it was
## built in), resizing its cylinder to match. Used to mend the sagging guy-line.
func _aim_line(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var dir := (b - a).normalized()
	if dir == Vector3.ZERO:
		return
	var side := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.RIGHT).normalized()
	node.transform = Transform3D(Basis(side, dir, side.cross(dir)), (a + b) * 0.5)
	(node.mesh as CylinderMesh).height = a.distance_to(b)


func _peg(parent: Node3D, at: Vector3) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.006
	cyl.height = 0.16
	var node := _mesh_node(cyl, _wood(), parent)
	node.position = at + Vector3(0, 0.03, 0)
	node.rotation.z = 0.25
	return node


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


# ---------------------------------------------------------------- the rest

func _build_woodpile() -> void:
	var c := _at(WOODPILE)
	var pile := Node3D.new()
	pile.name = "Woodpile"
	add_child(pile)
	var wood := _wood()
	var rows := [[-0.21, -0.07, 0.07, 0.21], [-0.14, 0.0, 0.14], [-0.07, 0.07]]
	for r in rows.size():
		for x in rows[r]:
			var at := c + _flat.x * float(x) + Vector3.UP * (0.06 + r * 0.115)
			_log(pile, at, _flat.z, 0.78, wood)
	var axe := _bank_prop("leartes/SM_Axe.gltf", 0.72)
	if axe:
		pile.add_child(axe)
		axe.global_transform = Transform3D(_flat * Basis(Vector3.RIGHT, -0.3) * Basis(Vector3.UP, 1.2), c - _flat.x * 0.42 - _flat.z * 0.25)
	_blocker(c, Vector3(0.6, 0.4, 0.85))


func _build_seating() -> void:
	var stool_at := _at(STOOL)
	var stool := _bank_prop("leartes/SM_Stool.gltf", 0.45)
	var seat_y := 0.45
	if stool == null:
		stool = Node3D.new()
		var top := _mesh_node(_box(Vector3(0.42, 0.06, 0.32)), _wood(), stool)
		top.position.y = 0.42
		for x in [-0.16, 0.16]:
			for z in [-0.11, 0.11]:
				_mesh_node(_box(Vector3(0.04, 0.42, 0.04)), _wood(), stool).position = Vector3(x, 0.21, z)
	add_child(stool)
	stool.global_transform = Transform3D(_flat * Basis(Vector3.UP, 0.4), stool_at)
	spots["gloves"] = stool_at + Vector3.UP * seat_y
	_blocker(stool_at, Vector3(0.45, 0.45, 0.4))

	# The crate stands upside down, its boarded bottom for a table.
	var crate_at := _at(CRATE)
	var crate := _bank_prop("leartes/SM_Crate.gltf", 0.36)
	if crate == null:
		crate = Node3D.new()
		_mesh_node(_box(Vector3(0.56, 0.36, 0.86)), _wood(), crate).position.y = 0.18
	else:
		var flipped := Node3D.new()
		flipped.add_child(crate)
		crate.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3.UP * 0.36)
		crate = flipped
	add_child(crate)
	crate.global_transform = Transform3D(_flat * Basis(Vector3.UP, -0.25), crate_at)
	spots["cups"] = crate_at + Vector3.UP * 0.36
	_blocker(crate_at, Vector3(0.6, 0.36, 0.9), Basis(Vector3.UP, -0.25))


func _build_lantern() -> void:
	var at := _at(STUMP)
	var stump := CylinderMesh.new()
	stump.top_radius = 0.19
	stump.bottom_radius = 0.23
	stump.height = 0.4
	_mesh_node(stump, _wood(), self).global_position = at + Vector3.UP * 0.18
	var top := at + Vector3.UP * 0.38
	# Poly Haven's CC0 hurricane lantern (already in the repository for the house).
	var lantern := HouseKit.prop(self, "Lantern_01", Vector3.ZERO)
	lantern.global_transform = Transform3D(_flat * Basis(Vector3.UP, 2.3), top - _flat.z * 0.06)
	var glass_height := 0.11
	var bounds := AABB()
	for mi in lantern.find_children("*", "MeshInstance3D", true, false):
		var piece := mi as MeshInstance3D
		var box := lantern.global_transform.affine_inverse() * piece.global_transform * piece.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	if bounds.size.y > 0.0:
		glass_height = bounds.position.y + bounds.size.y * 0.42
	var flame := SphereMesh.new()
	flame.radius = 0.012
	flame.height = 0.035
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.7, 0.35)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.6, 0.25)
	glow.emission_energy_multiplier = 6.0
	_mesh_node(flame, glow, self).global_position = top - _flat.z * 0.06 + Vector3.UP * glass_height
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.66, 0.36)
	_lantern_light.light_energy = 0.7
	_lantern_light.omni_range = 3.5
	_lantern_light.light_specular = 0.2
	_lantern_light.position = top - _flat.z * 0.06 + Vector3.UP * (glass_height + 0.03)
	add_child(_lantern_light)
	spots["note"] = top + _flat.z * 0.09
	_blocker(at, Vector3(0.45, 0.4, 0.45))


func _build_sound() -> void:
	var path := "res://assets/audio/nature/campfire_loop.wav"
	if not ResourceLoader.exists(path):
		return
	_sound = Loudness.voice(Loudness.CAMPFIRE, "Outside")
	_sound.name = "Crackle"
	var stream := load(path) as AudioStreamWAV
	if stream:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_sound.stream = stream
	add_child(_sound)
	_sound.global_position = _at(FIRE, 0.3)
	Loudness.sound(_sound, Loudness.CAMPFIRE)
	_sound.play()


# ---------------------------------------------------------------- stand-ins

func _mitten(offset: Vector3, yaw: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = offset
	holder.rotation.y = yaw
	var wool := StandardMaterial3D.new()
	wool.albedo_color = Color("4f2a25")
	wool.roughness = 1.0
	wool.rim_enabled = true
	wool.rim = 0.35
	wool.rim_tint = 0.6
	wool.normal_enabled = true
	wool.normal_texture = _noise_texture(0.4, true, true)
	wool.uv1_scale = Vector3(3, 3, 3)
	var hand := CapsuleMesh.new()
	hand.radius = 0.048
	hand.height = 0.21
	var body := _mesh_node(hand, wool, holder)
	body.rotation.x = PI * 0.5
	body.scale = Vector3(1.0, 1.0, 0.45)
	body.position.y = 0.022
	var thumb := CapsuleMesh.new()
	thumb.radius = 0.018
	thumb.height = 0.08
	var t := _mesh_node(thumb, wool, holder)
	t.rotation = Vector3(PI * 0.5, 0.0, 0.6)
	t.position = Vector3(0.05, 0.02, -0.03)
	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.05
	cuff.bottom_radius = 0.05
	cuff.height = 0.05
	var c := _mesh_node(cuff, wool, holder)
	c.rotation.x = PI * 0.5
	c.scale = Vector3(1.0, 1.0, 0.5)
	c.position = Vector3(0, 0.022, 0.12)
	return holder


func _fallback_cup() -> Node3D:
	var holder := Node3D.new()
	var cup := CylinderMesh.new()
	cup.top_radius = 0.045
	cup.bottom_radius = 0.04
	cup.height = 0.1
	_mesh_node(cup, HouseKit.paint(Color("8fa3a6"), 0.35, 0.6), holder).position.y = 0.05
	return holder


func _paper() -> Node3D:
	var holder := Node3D.new()
	_mesh_node(_box(Vector3(0.15, 0.002, 0.21)), HouseKit.paint(Color("d6ccb4"), 0.95), holder).position.y = 0.001
	return holder
