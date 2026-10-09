class_name DreamRoute
extends Node3D

## Ground-aligned anchors and the small ice clearing for the playable dream.
const CLEARING_OFFSET := 58.0
const CLEARING_WIDTH := 8.5
const CLEARING_LENGTH := 13.0
const GRID_ACROSS := 32
const GRID_ALONG := 48
const DARK_PATCHES := [
	{"offset": 14.0, "side": -1.5, "size": Vector2(6.8, 8.4)},
	{"offset": 27.0, "side": 1.6, "size": Vector2(5.8, 7.4)},
	{"offset": 42.0, "side": -1.7, "size": Vector2(7.2, 9.2)},
	{"offset": 58.0, "side": 1.2, "size": Vector2(6.2, 8.0)},
]

# The impossible path begins as ordinary ground, then rises and returns over
# its own horizontal footprint. Keep these together as art-direction controls.
const FOLD_SIDE_OFFSET := -12.5
const FOLD_WIDTH := 1.85
const FOLD_LENGTH := 26.0
const FOLD_RETURN := 12.5
const FOLD_HEIGHT := 6.5
const FOLD_SEGMENTS := 52
const FOLD_REVEAL_OFFSET := 18.0
const FOLD_FULL_OFFSET := 42.0
const ASSET_TOWER_02 := "res://assets/vendor/requested_dream/stylized_medieval_town/Art/Meshes/SM_Tower_02.gltf"
const ASSET_WINDOW := "res://assets/vendor/requested_dream/stylized_medieval_town/Art/Meshes/SM_Window_01.gltf"
const WEB_LIGHTHOUSE := "res://assets/dream/web/godot/lighthouse_rocky_coast.glb"
const WEB_CAMP := "res://assets/dream/web/godot/snowbound_forest_camp.glb"
const WEB_FROZEN_RETREAT := "res://assets/dream/web/godot/frozen_lake_retreat.glb"

var trail: Trail
var _anchors: Dictionary = {}
var _fold_material: ShaderMaterial
var _fold_reveal := 0.0
var _queued_flashbacks: Dictionary = {}


func build(source: Trail) -> void:
	trail = source
	if trail == null:
		return
	_anchors = {
		"step": _anchor(1.0, 0.0),
		"lantern": _anchor(33.0, 2.6),
		"clearing": _anchor(CLEARING_OFFSET, 0.0),
		"answer": _anchor(67.0, 0.0),
	}
	_build_clearing()
	_build_dark_patches()
	_build_flashback_landscapes()
	_build_folded_path()


func _process(delta: float) -> void:
	if _fold_material == null or trail == null or Game.player == null:
		return
	var progress := trail.offset_of(Game.player.global_position) - trail.player_start_offset
	var target := smoothstep(FOLD_REVEAL_OFFSET, FOLD_FULL_OFFSET, progress)
	_fold_reveal = move_toward(_fold_reveal, target, delta * 0.16)
	_fold_material.set_shader_parameter("reveal", _fold_reveal)


func anchor(key: String) -> Transform3D:
	var value: Transform3D = _anchors.get(key, Transform3D.IDENTITY)
	return value


func world_position(key: String) -> Vector3:
	return anchor(key).origin


func _anchor(route_offset: float, side_offset: float) -> Transform3D:
	var frame := trail.frame_at(trail.player_start_offset + route_offset)
	var side := frame.basis.x
	side.y = 0.0
	if side.length_squared() > 0.001:
		side = side.normalized()
	frame.origin = trail.on_ground(frame.origin + side * side_offset)
	return frame


func _build_clearing() -> void:
	var frame := anchor("clearing")
	var ahead := anchor("answer").origin - frame.origin
	ahead.y = 0.0
	if ahead.length_squared() < 0.001:
		return
	ahead = ahead.normalized()
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_size := GRID_ACROSS + 1
	vertices.resize(row_size * (GRID_ALONG + 1))
	uvs.resize(vertices.size())
	for j in range(GRID_ALONG + 1):
		var along_ratio := float(j) / GRID_ALONG
		for i in range(GRID_ACROSS + 1):
			var across_ratio := float(i) / GRID_ACROSS
			var across_distance := (across_ratio - 0.5) * CLEARING_WIDTH
			var along_distance := (along_ratio - 0.5) * CLEARING_LENGTH
			var world := frame.origin + across * across_distance + ahead * along_distance
			world = trail.on_ground(world) + Vector3.UP * 0.055
			var index := j * row_size + i
			vertices[index] = to_local(world)
			uvs[index] = Vector2(across_ratio, along_ratio)
	for j in GRID_ALONG:
		for i in GRID_ACROSS:
			var lower_left := j * row_size + i
			var lower_right := lower_left + 1
			var upper_left := lower_left + row_size
			var upper_right := upper_left + 1
			indices.append(lower_left)
			indices.append(lower_right)
			indices.append(upper_left)
			indices.append(lower_right)
			indices.append(upper_right)
			indices.append(upper_left)
	var across_stride := CLEARING_WIDTH / GRID_ACROSS
	var along_stride := CLEARING_LENGTH / GRID_ALONG
	for j in range(GRID_ALONG + 1):
		for i in range(GRID_ACROSS + 1):
			var index := j * row_size + i
			var left := vertices[j * row_size + maxi(i - 1, 0)]
			var right := vertices[j * row_size + mini(i + 1, GRID_ACROSS)]
			var back := vertices[maxi(j - 1, 0) * row_size + i]
			var front := vertices[mini(j + 1, GRID_ALONG) * row_size + i]
			var tangent_across := (right - left) / (across_stride if i == 0 or i == GRID_ACROSS else across_stride * 2.0)
			var tangent_along := (front - back) / (along_stride if j == 0 or j == GRID_ALONG else along_stride * 2.0)
			var normal := tangent_across.cross(tangent_along).normalized()
			if normal.y < 0.0:
				normal = -normal
			normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := MeshInstance3D.new()
	surface.name = "DreamIceClearing"
	surface.mesh = mesh
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dream_clearing.gdshader")
	surface.material_override = material
	add_child(surface)


func _build_dark_patches() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dream_dark_patch.gdshader")
	for index in range(DARK_PATCHES.size()):
		var patch_data: Dictionary = DARK_PATCHES[index]
		var patch_offset: float = patch_data["offset"]
		var patch_side: float = patch_data["side"]
		var patch_size: Vector2 = patch_data["size"]
		var frame := _anchor(patch_offset, patch_side)
		var patch := MeshInstance3D.new()
		patch.name = "SilenceShadow_%02d" % (index + 1)
		var plane := PlaneMesh.new()
		plane.size = patch_size
		patch.mesh = plane
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patch.material_override = material
		var ground := trail.on_ground(frame.origin) + Vector3.UP * 0.085
		# PlaneMesh is already horizontal in Godot (its normal is local +Y).
		# Rotating it here stood the dark pools upright and filled the view with
		# translucent panels when the camera passed near them.
		patch.global_transform = Transform3D(frame.basis, ground)
		add_child(patch)


func _build_flashback_landscapes() -> void:
	_build_lighthouse_memory()
	_build_cabin_memory()
	_build_doorway_horizon_memory()
	_build_queued_flashbacks()


func _build_queued_flashbacks() -> void:
	_queued_flashbacks["sisters"] = _build_sister_spires()
	_queued_flashbacks["thread"] = _build_thread_memory()
	_queued_flashbacks["window"] = _build_watching_window()
	for flashback in _queued_flashbacks.values():
		if flashback is Node3D:
			(flashback as Node3D).hide()


func play_flashback(cue_id: String) -> Node3D:
	var flashback := _queued_flashbacks.get(cue_id) as Node3D
	if flashback == null or not is_instance_valid(flashback):
		return null
	flashback.show()
	var fade_timer := get_tree().create_timer(3.6)
	fade_timer.timeout.connect(func() -> void:
		if is_instance_valid(flashback):
			flashback.hide()
	)
	return flashback


func _build_sister_spires() -> Node3D:
	var root := _landscape_root("Flashback_Sisters", 22.0, -33.0)
	root.set_meta("insight_focus_height", 4.4)
	var retreat := _add_web_scene(root, "TwoSistersByTheFrozenPond", WEB_FROZEN_RETREAT, Vector3.ZERO, Vector3.ONE * 1.05, Vector3(0.0, -0.42, 0.0))
	if retreat == null:
		_add_memory_ground(root, Vector2(18.0, 14.0), Color("141b29"))
		for index in 3:
			_build_fallback_spire(root, index, Vector3(-6.0 + float(index) * 6.0, 0.0, 0.0), 0.42 + float(index % 2) * 0.05)
	else:
		var sister_positions: Array[Vector3] = [Vector3(-11.0, 0.4, -8.0), Vector3(0.0, 0.4, 9.0), Vector3(11.0, 0.4, -8.0)]
		for index in sister_positions.size():
			var tower := _add_bank_scene(root, "SisterTower_%02d" % index, ASSET_TOWER_02, sister_positions[index], Vector3.ONE * (0.75 + float(index % 2) * 0.12), Vector3(0.0, float(index) * 0.8, 0.0))
			_tint_asset_for_dream(tower, Color(0.5, 0.57, 0.72), Color("334d75"), 0.08)
	return root


func _build_thread_memory() -> Node3D:
	var root := _landscape_root("Flashback_AriadneThread", 36.0, 34.0)
	root.set_meta("insight_focus_height", 13.0)
	var lighthouse := _add_web_scene(root, "TheLightThatFindsTheWayBack", WEB_LIGHTHOUSE, Vector3.ZERO, Vector3.ONE * 0.48, Vector3(0.0, 0.62, 0.0))
	if lighthouse == null:
		_add_memory_ground(root, Vector2(20.0, 16.0), Color("181523"))
		_build_fallback_door(root, 5, Vector3(0.0, 0.0, 0.0), 1.5, Vector3.ZERO)
		for index in 3:
			_build_fallback_thread_loop(root, index, Vector3(-5.0 + float(index) * 5.0, 7.0 + float(index % 2) * 2.0, 0.0), 1.6 + float(index) * 0.2)
	else:
		for index in 3:
			var loop_position := Vector3(-8.0 + float(index) * 8.0, 7.0 + sin(float(index) * 1.7) * 2.0, 2.5)
			_build_fallback_thread_loop(root, index, loop_position, 1.6 + float(index) * 0.2)
	return root


func _build_watching_window() -> Node3D:
	var root := _landscape_root("Flashback_WatchingWindow", 51.0, -33.0)
	root.set_meta("insight_focus_height", 4.0)
	var camp := _add_web_scene(root, "WarmthBeyondTheTrees", WEB_CAMP, Vector3.ZERO, Vector3.ONE * 1.25, Vector3(0.0, -0.3, 0.0))
	if camp == null:
		_add_memory_ground(root, Vector2(20.0, 16.0), Color("151923"))
		_build_fallback_cabin(root)
		_build_fallback_window(root, 0, Vector3(0.0, 5.0, -4.0))
	else:
		for index in 3:
			var window_position := Vector3(-6.5 + float(index) * 6.5, 6.4 + float(index % 2) * 1.0, -6.0)
			var window := _add_bank_scene(root, "ImpossibleWindow_%02d" % index, ASSET_WINDOW, window_position, Vector3.ONE * 1.15, Vector3(0.0, float(index) * 0.35 - 0.35, -0.1))
			_tint_asset_for_dream(window, Color(0.62, 0.58, 0.64), Color("b17e62"), 0.16)
	var glow := OmniLight3D.new()
	glow.name = "SomeoneStillAwake"
	glow.position = Vector3(0.0, 3.5, 0.0)
	glow.light_color = Color("eabf88")
	glow.light_energy = 1.8
	glow.omni_range = 20.0
	glow.shadow_enabled = false
	root.add_child(glow)
	return root


func _build_fallback_spire(parent: Node3D, index: int, position: Vector3, size: float) -> void:
	var stone := _memory_material(Color("364052"), Color("283954"), 0.12)
	var dark := _memory_material(Color("151c29"))
	var spire := Node3D.new()
	spire.name = "FallbackSister_%02d" % index
	spire.position = position
	spire.scale = Vector3.ONE * size
	parent.add_child(spire)
	_add_memory_cylinder(spire, "PaleTower", 1.7, 2.3, 20.0, stone, Vector3(0.0, 10.0, 0.0))
	_add_memory_cylinder(spire, "BrokenCrown", 2.0, 2.0, 1.2, dark, Vector3(0.0, 20.0, 0.0))
	_add_memory_cylinder(spire, "NeedleRoof", 0.0, 2.0, 6.0, stone, Vector3(0.0, 23.0, 0.0))


func _build_fallback_thread_loop(parent: Node3D, index: int, position: Vector3, radius: float) -> void:
	var strand := MeshInstance3D.new()
	strand.name = "FallbackThreadLoop_%02d" % index
	var loop := TorusMesh.new()
	loop.inner_radius = radius * 0.88
	loop.outer_radius = radius
	loop.rings = 40
	loop.ring_segments = 8
	strand.mesh = loop
	strand.position = position
	strand.rotation = Vector3(PI * 0.5, float(index) * 0.62, 0.0)
	strand.material_override = _memory_material(Color("806a92"), Color("6e4e83"), 0.35)
	strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(strand)


func _build_fallback_window(parent: Node3D, index: int, position: Vector3) -> void:
	var frame_material := _memory_material(Color("303341"), Color("624b50"), 0.12)
	var glass := _memory_material(Color("c39a73"), Color("edb77f"), 0.8)
	var window := Node3D.new()
	window.name = "FallbackWindow_%02d" % index
	window.position = position
	window.rotation.y = float(index) * 0.32 - 0.3
	_add_memory_box(window, "WarmGlass", Vector3.ZERO, Vector3(2.0, 2.6, 0.12), glass)
	_add_memory_box(window, "LeftFrame", Vector3(-1.12, 0.0, -0.1), Vector3(0.16, 2.9, 0.18), frame_material)
	_add_memory_box(window, "RightFrame", Vector3(1.12, 0.0, -0.1), Vector3(0.16, 2.9, 0.18), frame_material)
	_add_memory_box(window, "TopFrame", Vector3(0.0, 1.45, -0.1), Vector3(2.4, 0.16, 0.18), frame_material)
	_add_memory_box(window, "Sill", Vector3(0.0, -1.45, -0.1), Vector3(2.4, 0.16, 0.18), frame_material)
	parent.add_child(window)


func _landscape_root(name: String, route_offset: float, side_offset: float) -> Node3D:
	var frame := _anchor(route_offset, side_offset)
	var root := Node3D.new()
	root.name = name
	add_child(root)
	root.global_transform = frame
	return root


func _build_lighthouse_memory() -> void:
	# A fully textured station becomes a beacon island, visible across the storm
	# but well outside the route's walkable corridor.
	var root := _landscape_root("Flashback_Lighthouse", 20.0, -42.0)
	var web_station := _add_web_scene(root, "LightStationAndRockyPoint", WEB_LIGHTHOUSE, Vector3.ZERO, Vector3.ONE * 0.78, Vector3(0.0, 0.28, 0.0))
	var beacon_position := Vector3(10.88, 18.0, 4.1)
	if web_station == null:
		_add_memory_ground(root, Vector2(22.0, 18.0), Color("101824"))
		_build_fallback_lighthouse(root)
		beacon_position = Vector3(0.0, 35.0, 0.0)
	# The authored tower is centred at (12, 0, 9) in its source layout.
	# Match its scene rotation and scale so the dream light sits in its lantern.
	var beacon := OmniLight3D.new()
	beacon.name = "BeaconGlow"
	beacon.position = beacon_position
	beacon.light_color = Color("ffd19a")
	beacon.light_energy = 1.4
	beacon.omni_range = 22.0
	beacon.shadow_enabled = false
	root.add_child(beacon)
	var beam := SpotLight3D.new()
	beam.name = "LostBeaconBeam"
	beam.light_color = Color("e9d7b4")
	beam.light_energy = 0.55
	beam.spot_range = 34.0
	beam.spot_angle = 9.0
	beam.shadow_enabled = false
	beam.position = beacon_position
	beam.rotation.x = -0.12
	beam.rotation.y = -PI * 0.5 + 0.28
	root.add_child(beam)
	var beacon_core := MeshInstance3D.new()
	beacon_core.name = "DistantBeaconCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.1
	core_mesh.height = 2.2
	beacon_core.mesh = core_mesh
	beacon_core.position = beacon_position
	beacon_core.material_override = _emissive_material(Color("ffad55"), 0.85)
	beacon_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beacon_core)


func _build_cabin_memory() -> void:
	# Mathilda's house hangs beyond the field, turned slightly away as if the
	# memory refuses to be entered.
	var root := _landscape_root("Flashback_Cabin", 35.0, 50.0)
	if _add_web_scene(root, "SnowboundForestCamp", WEB_CAMP, Vector3.ZERO, Vector3.ONE * 1.55, Vector3(0.0, 0.7, 0.0)) == null:
		_add_memory_ground(root, Vector2(14.0, 12.0), Color("171822"))
		_build_fallback_cabin(root)
	var window_glow := OmniLight3D.new()
	window_glow.name = "OneLightInTheCabin"
	window_glow.position = Vector3(0.0, 5.5, 0.0)
	window_glow.light_color = Color("f6b976")
	window_glow.light_energy = 2.4
	window_glow.omni_range = 24.0
	window_glow.shadow_enabled = false
	root.add_child(window_glow)


func _build_doorway_horizon_memory() -> void:
	# A complete frozen retreat hangs beyond the path, a home-sized place
	# distorted into a far-off threshold.
	var root := _landscape_root("Flashback_DoorwayHorizon", 50.0, 48.0)
	if _add_web_scene(root, "FrozenLakeRetreat", WEB_FROZEN_RETREAT, Vector3.ZERO, Vector3.ONE * 1.25, Vector3(0.0, 1.15, 0.0)) == null:
		root.global_position += Vector3.UP * 2.2
		_add_memory_ground(root, Vector2(20.0, 18.0), Color("101824"))
		for index in 4:
			var placement := Vector3(-6.0 + float(index) * 4.0, 0.4 + float(index % 2) * 0.6, -9.0 + float(index) * 6.0)
			_build_fallback_door(root, index, placement, 0.85 + float(index % 2) * 0.16, Vector3(0.0, float(index) * 0.38 - 0.55, float(index % 2) * 0.08))


func _build_fallback_lighthouse(parent: Node3D) -> void:
	# Simple native geometry keeps owner-only imports optional in a clean clone.
	var stone := _memory_material(Color("48515e"))
	var dark := _memory_material(Color("171e29"))
	var warm := _memory_material(Color("c7a16f"), Color("ffbc70"), 0.7)
	_add_memory_cylinder(parent, "FallbackTower", 2.3, 3.4, 32.0, stone, Vector3(0.0, 17.0, 0.0))
	_add_memory_cylinder(parent, "FallbackGallery", 3.0, 3.2, 0.5, dark, Vector3(0.0, 33.2, 0.0))
	_add_memory_cylinder(parent, "FallbackLanternRoom", 2.6, 2.6, 3.2, dark, Vector3(0.0, 35.0, 0.0))
	_add_memory_cylinder(parent, "FallbackRoof", 0.1, 3.2, 3.4, stone, Vector3(0.0, 38.2, 0.0))
	_add_memory_box(parent, "FallbackBeaconWindow", Vector3(0.0, 35.0, -2.58), Vector3(0.62, 1.0, 0.05), warm)


func _build_fallback_cabin(parent: Node3D) -> void:
	var timber := _memory_material(Color("323744"))
	var roof := _memory_material(Color("202633"))
	var warm := _memory_material(Color("b17d53"), Color("f6b976"), 0.36)
	_add_memory_box(parent, "FallbackCabinBody", Vector3(0.0, 2.2, 0.0), Vector3(8.0, 4.4, 6.0), timber)
	_add_memory_box(parent, "FallbackRoofLeft", Vector3(-2.05, 4.9, 0.0), Vector3(4.8, 0.38, 7.0), roof, Vector3(0.0, 0.0, -0.58))
	_add_memory_box(parent, "FallbackRoofRight", Vector3(2.05, 4.9, 0.0), Vector3(4.8, 0.38, 7.0), roof, Vector3(0.0, 0.0, 0.58))
	_add_memory_box(parent, "FallbackWindow", Vector3(-1.9, 2.8, -3.04), Vector3(1.2, 1.1, 0.08), warm)
	_add_memory_box(parent, "FallbackDoor", Vector3(1.2, 1.55, -3.06), Vector3(1.2, 3.1, 0.12), roof)


func _build_fallback_door(parent: Node3D, index: int, position: Vector3, size: float, rotation: Vector3) -> void:
	var frame := Node3D.new()
	frame.name = "FallbackDoor_%02d" % index
	frame.position = position
	frame.scale = Vector3.ONE * size
	frame.rotation = rotation
	parent.add_child(frame)
	var stone := _memory_material(Color("414b60"), Color("627899"), 0.16)
	var dark := _memory_material(Color("151b26"))
	_add_memory_box(frame, "JambLeft", Vector3(-0.56, 1.0, 0.0), Vector3(0.16, 2.2, 0.18), stone)
	_add_memory_box(frame, "JambRight", Vector3(0.56, 1.0, 0.0), Vector3(0.16, 2.2, 0.18), stone)
	_add_memory_box(frame, "Lintel", Vector3(0.0, 2.08, 0.0), Vector3(1.3, 0.16, 0.2), stone)
	_add_memory_box(frame, "UnlitThreshold", Vector3(0.0, 0.04, 0.0), Vector3(1.38, 0.08, 0.36), dark)
	_add_memory_box(frame, "DarkOpening", Vector3(0.0, 1.04, -0.01), Vector3(0.94, 1.88, 0.035), dark)


func _memory_material(color: Color, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _add_memory_box(parent: Node3D, name: String, position: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	mesh_instance.rotation = rotation
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_memory_cylinder(parent: Node3D, name: String, top_radius: float, bottom_radius: float, height: float, material: Material, position: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_web_scene(parent: Node3D, name: String, path: String, position: Vector3, scale: Vector3, rotation: Vector3) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("Dream web scene is not installed: %s" % path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Dream web scene could not be loaded: %s" % path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("Dream web scene root is not Node3D: %s" % path)
		return null
	instance.name = name
	instance.position = position
	instance.scale = scale
	instance.rotation = rotation
	parent.add_child(instance)
	return instance


func _add_bank_scene(parent: Node3D, name: String, path: String, position: Vector3, scale: Vector3, rotation: Vector3) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("Dream memory asset is not installed: %s" % path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Dream memory asset could not be loaded: %s" % path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("Dream memory asset root is not Node3D: %s" % path)
		return null
	instance.name = name
	instance.position = position
	instance.scale = scale
	instance.rotation = rotation
	parent.add_child(instance)
	for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
		(mesh_node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _tint_asset_for_dream(instance: Node3D, tint: Color, glow: Color, energy: float) -> void:
	if instance == null:
		return
	for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface_index in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface_index) as StandardMaterial3D
			if source == null:
				continue
			var dream_material := source.duplicate() as StandardMaterial3D
			dream_material.albedo_color *= tint
			dream_material.emission_enabled = true
			dream_material.emission = glow
			dream_material.emission_energy_multiplier = energy
			mesh.set_surface_override_material(surface_index, dream_material)


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_memory_ground(parent: Node3D, size: Vector2, color: Color) -> void:
	var ground := MeshInstance3D.new()
	ground.name = "MemoryPool"
	var plane := PlaneMesh.new()
	plane.size = size
	ground.mesh = plane
	ground.position.y = 0.09
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dream_dark_patch.gdshader")
	material.set_shader_parameter("shadow_color", Color(color.lerp(Color("596577"), 0.48), 0.28))
	material.set_shader_parameter("edge_softness", 0.62)
	ground.material_override = material
	parent.add_child(ground)


func _build_folded_path() -> void:
	var frame := anchor("clearing")
	var ahead := anchor("answer").origin - frame.origin
	ahead.y = 0.0
	if ahead.length_squared() < 0.001:
		return
	ahead = ahead.normalized()
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	var centers := PackedVector3Array()
	centers.resize(FOLD_SEGMENTS + 1)
	for index in range(FOLD_SEGMENTS + 1):
		var t := float(index) / FOLD_SEGMENTS
		var lift := smoothstep(0.28, 1.0, t)
		var return_curve := smoothstep(0.58, 1.0, t)
		var along_distance := -FOLD_LENGTH * 0.42 + FOLD_LENGTH * t - FOLD_RETURN * return_curve * return_curve
		var side_distance := FOLD_SIDE_OFFSET + sin(t * PI) * 1.15
		var horizontal := frame.origin + ahead * along_distance + across * side_distance
		centers[index] = trail.on_ground(horizontal) + Vector3.UP * (0.065 + FOLD_HEIGHT * lift * lift)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize((FOLD_SEGMENTS + 1) * 2)
	normals.resize(vertices.size())
	uvs.resize(vertices.size())
	for index in range(FOLD_SEGMENTS + 1):
		var t := float(index) / FOLD_SEGMENTS
		var previous := centers[maxi(index - 1, 0)]
		var following := centers[mini(index + 1, FOLD_SEGMENTS)]
		var tangent := (following - previous).normalized()
		# The fold bends in the route's forward/up plane. A stable across axis
		# avoids the ribbon twisting when its forward direction reverses.
		var width_axis := across
		var normal := width_axis.cross(tangent).normalized()
		if normal.y < 0.0:
			normal = -normal
		var half_width := FOLD_WIDTH * lerpf(0.5, 0.34, smoothstep(0.62, 1.0, t))
		vertices[index * 2] = to_local(centers[index] - width_axis * half_width)
		vertices[index * 2 + 1] = to_local(centers[index] + width_axis * half_width)
		normals[index * 2] = normal
		normals[index * 2 + 1] = normal
		uvs[index * 2] = Vector2(0.0, t)
		uvs[index * 2 + 1] = Vector2(1.0, t)
	if FOLD_SEGMENTS > 0:
		for index in FOLD_SEGMENTS:
			var lower_left := index * 2
			var lower_right := lower_left + 1
			var upper_left := lower_left + 2
			var upper_right := lower_left + 3
			indices.append(lower_left)
			indices.append(lower_right)
			indices.append(upper_left)
			indices.append(lower_right)
			indices.append(upper_right)
			indices.append(upper_left)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := MeshInstance3D.new()
	surface.name = "FoldedSnowPath"
	surface.mesh = mesh
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fold_material = ShaderMaterial.new()
	_fold_material.shader = preload("res://shaders/dream_folded_path.gdshader")
	_fold_material.set_shader_parameter("reveal", 0.0)
	surface.material_override = _fold_material
	add_child(surface)
