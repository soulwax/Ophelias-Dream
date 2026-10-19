class_name DreamMemoryArchitecture
extends Node3D

signal cue_revealed(cue_id: String, at: Vector3)

## Memory landmarks share the forest's coordinates and weather. All forms
## are visual only; the trail's collision and dialogue remain authoritative.
const EDGE_SHADER := preload("res://shaders/dream_memory_edge.gdshader")
const BEAM_SHADER := preload("res://shaders/dream_lighthouse_beam.gdshader")
const PLASTER_TEXTURE := preload("res://assets/vendor/polyhaven/white_plaster_rough_01/white_plaster_rough_01_diff_1k.jpg")
const WOOD_TEXTURE := preload("res://assets/vendor/polyhaven/wooden_bookshelf_worn/textures/wooden_bookshelf_worn_diff_1k.jpg")
const STONE_TEXTURE := preload("res://assets/vendor/polyhaven/aerial_grass_rock/aerial_grass_rock_diff_1k.jpg")
const ROOF_TEXTURE := preload("res://assets/vendor/polyhaven/roof_slates_02/roof_slates_02_diff_1k.jpg")
const CUE_SPECS := {
	"sisters": {"offset": 15.0, "side": -7.2, "approach": 8.0, "reveal_delay": 0.9, "hold": 11.0, "afterglow": 0.15, "quiet_at": 27.0},
	# These reveal delays land on the end of the corresponding approach gesture.
	"thread": {"offset": 31.0, "side": -9.0, "approach": 9.0, "reveal_delay": 0.82, "hold": 13.0, "afterglow": 0.17, "quiet_at": 42.0},
	"window": {"offset": 46.0, "side": 7.2, "approach": 10.0, "reveal_delay": 0.7, "hold": 18.0, "afterglow": 0.28, "quiet_at": 58.0},
	"clearing": {"offset": 61.0, "side": -8.0, "approach": 6.0, "reveal_delay": 0.0, "hold": 30.0, "afterglow": 0.18, "quiet_at": 99.0},
}

var _trail: Trail
var _roots: Dictionary = {}
var _states: Dictionary = {}
var _values: Dictionary = {}
var _elapsed: Dictionary = {}
var _queued_reveals: Dictionary = {}
var _material_cache: Dictionary = {}
var _cue_materials: Dictionary = {}
var _suspended := false
var _closing := false
var _pressure := 0.0
var _pressure_target := 0.0
var _time := 0.0
var _bearing_follow := 0.0
var _lighthouse_beam: SpotLight3D
var _beam_pivot: Node3D
var _beam_material: ShaderMaterial
var _window_light: OmniLight3D
var _clearing_light: OmniLight3D
var _wrong_horizon_light: OmniLight3D


func build(source: Trail) -> void:
	_trail = source
	if _trail == null:
		return
	for cue_id in CUE_SPECS:
		_states[cue_id] = "dormant"
		_values[cue_id] = 0.0
		_elapsed[cue_id] = 0.0
		_cue_materials[cue_id] = []
	_build_sisters()
	_build_lighthouse()
	_build_window()
	_build_clearing()


func anticipate(cue_id: String, _at: Transform3D) -> void:
	if _states.get(cue_id, "") == "dormant":
		_states[cue_id] = "anticipating"


func queue_reveal(cue_id: String) -> void:
	if not CUE_SPECS.has(cue_id) or _queued_reveals.has(cue_id):
		return
	if _states.get(cue_id, "") in ["revealed", "afterimage", "quiet"]:
		return
	_states[cue_id] = "anticipating"
	_queued_reveals[cue_id] = float(CUE_SPECS[cue_id]["reveal_delay"])


func reveal_cue(cue_id: String) -> void:
	if not _states.has(cue_id):
		return
	if _states[cue_id] == "revealed":
		return
	for previous in ["sisters", "thread", "window"]:
		if previous != cue_id and _states.get(previous, "") == "revealed":
			_states[previous] = "afterimage"
	_states[cue_id] = "revealed"
	_elapsed[cue_id] = 0.0
	_queued_reveals.erase(cue_id)
	cue_revealed.emit(cue_id, cue_position(cue_id))


func enter_clearing() -> void:
	if _states.get("clearing", "") != "revealed":
		reveal_cue("clearing")
	if _states.get("window", "") == "revealed":
		_states["window"] = "afterimage"


func respond(effect: String, pressure: float = -1.0) -> void:
	if pressure >= 0.0:
		_pressure_target = clampf(pressure, 0.0, 1.0)
		return
	match effect:
		"push":
			_pressure_target = maxf(_pressure_target, 0.56)
		"escalate":
			_pressure_target = 1.0
		"repair":
			_pressure_target = 0.0


func settle(outcome: String) -> void:
	_closing = true
	enter_clearing()
	_states["sisters"] = "quiet"
	_states["thread"] = "afterimage"
	_states["window"] = "afterimage" if outcome in ["complete", "strained"] else "quiet"
	if outcome == "ruptured":
		_pressure_target = 1.0
	elif outcome == "complete":
		_pressure_target = 0.0


func set_suspended(value: bool) -> void:
	_suspended = value


func cue_position(cue_id: String) -> Vector3:
	var root := _roots.get(cue_id) as Node3D
	return root.global_position if root else Vector3.ZERO


func _process(delta: float) -> void:
	if _trail == null or not Game.dream_mode or _suspended:
		return
	_time += delta
	_pressure = move_toward(_pressure, _pressure_target, delta * 0.35)
	for cue_id in _queued_reveals.keys():
		_queued_reveals[cue_id] = float(_queued_reveals[cue_id]) - delta
		if float(_queued_reveals[cue_id]) <= 0.0:
			reveal_cue(str(cue_id))
	var progress := 0.0
	if Game.player:
		progress = _trail.offset_of(Game.player.global_position) - _trail.player_start_offset
	for cue_id in CUE_SPECS:
		var state := str(_states[cue_id])
		if state == "revealed" and cue_id != "clearing":
			_elapsed[cue_id] = float(_elapsed[cue_id]) + delta
			if float(_elapsed[cue_id]) >= float(CUE_SPECS[cue_id]["hold"]):
				_states[cue_id] = "afterimage"
				state = "afterimage"
		if not _closing and state == "afterimage" and progress >= float(CUE_SPECS[cue_id]["quiet_at"]):
			_states[cue_id] = "quiet"
			state = "quiet"
		var target := 0.0
		match state:
			"dormant":
				var spec: Dictionary = CUE_SPECS[cue_id]
				if not _closing and cue_id != "clearing" and progress >= float(spec["offset"]) - float(spec["approach"]):
					target = 0.12
			"anticipating":
				target = 0.24
			"revealed":
				target = 1.0
			"afterimage":
				target = float(CUE_SPECS[cue_id]["afterglow"])
		var amount := move_toward(float(_values[cue_id]), target, delta * (1.05 if target > float(_values[cue_id]) else 0.24))
		_values[cue_id] = amount
		var root := _roots.get(cue_id) as Node3D
		if root:
			root.visible = amount > 0.015
		for material in _cue_materials[cue_id]:
			(material as ShaderMaterial).set_shader_parameter("reveal", amount)
	_update_lights(progress, delta)


func _update_lights(progress: float, delta: float) -> void:
	var thread_amount := float(_values.get("thread", 0.0))
	if _lighthouse_beam:
		_lighthouse_beam.light_energy = thread_amount * (0.92 - _pressure * 0.25)
	if _beam_pivot:
		var sweep_angle := sin(_time * 0.19) * 0.42 - 0.18
		var home_angle := sweep_angle
		var follow_target := 0.0
		var camera := get_viewport().get_camera_3d()
		if thread_amount > 0.3 and progress >= 34.0 and progress <= 45.0 and camera and _trail:
			var home := _trail.frame_at(_trail.player_start_offset).origin
			var to_home := home - camera.global_position
			to_home.y = 0.0
			var view_forward := -camera.global_basis.z
			view_forward.y = 0.0
			if to_home.length_squared() > 0.01 and view_forward.length_squared() > 0.01 and to_home.normalized().dot(view_forward.normalized()) > 0.56:
				# From beyond the beacon, looking back makes its beam follow the
				# house's bearing in the player's view. The ground and tower stay fixed.
				var tower := _beam_pivot.get_parent() as Node3D
				var local_bearing := tower.global_basis.inverse() * to_home.normalized()
				home_angle = atan2(-local_bearing.x, -local_bearing.z)
				follow_target = 1.0
		_bearing_follow = move_toward(_bearing_follow, follow_target, delta * 0.9)
		var desired_angle := lerp_angle(sweep_angle, home_angle, _bearing_follow)
		_beam_pivot.rotation.y = lerp_angle(_beam_pivot.rotation.y, desired_angle, clampf(delta * 1.8, 0.0, 1.0))
	if _beam_material:
		_beam_material.set_shader_parameter("strength", thread_amount * (1.0 - _pressure * 0.35))
	var window_amount := float(_values.get("window", 0.0))
	if _window_light:
		_window_light.light_energy = window_amount * (1.75 - _pressure * 0.65)
	var clearing_amount := float(_values.get("clearing", 0.0))
	if _clearing_light:
		_clearing_light.light_energy = clearing_amount * (0.55 - _pressure * 0.18)
	if _wrong_horizon_light:
		var slow_breath := 0.88 + sin(_time * 0.34) * 0.06
		_wrong_horizon_light.light_energy = clearing_amount * slow_breath * (0.52 - _pressure * 0.12)


func _root_at(cue_id: String, offset: float, side: float, name: String) -> Node3D:
	var frame := _trail.frame_at(_trail.player_start_offset + offset)
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	var place := _trail.on_ground(frame.origin + across * side)
	var toward_path := -across if side > 0.0 else across
	var root := Node3D.new()
	root.name = name
	add_child(root)
	root.global_transform = Transform3D(Basis.looking_at(toward_path, Vector3.UP), place)
	if not _roots.has(cue_id):
		_roots[cue_id] = root
	return root


func _material(cue_id: String, tint: Color, glow := Color.BLACK, chosen_surface: Texture2D = null) -> ShaderMaterial:
	var surface_key := chosen_surface.resource_path if chosen_surface else "auto"
	var key := "%s:%s:%s:%s" % [cue_id, tint.to_html(), glow.to_html(), surface_key]
	if _material_cache.has(key):
		return _material_cache[key] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = EDGE_SHADER
	material.set_shader_parameter("albedo_tint", tint)
	material.set_shader_parameter("glow_tint", glow)
	material.set_shader_parameter("reveal", 0.0)
	var surface: Texture2D = chosen_surface if chosen_surface else WOOD_TEXTURE
	if chosen_surface == null and cue_id == "thread":
		surface = STONE_TEXTURE
	elif chosen_surface == null and tint.get_luminance() > 0.4:
		surface = PLASTER_TEXTURE
	material.set_shader_parameter("surface_texture", surface)
	material.set_shader_parameter("texture_strength", 0.55 if cue_id == "thread" else 0.82)
	_material_cache[key] = material
	(_cue_materials[cue_id] as Array).append(material)
	return material


func _box(parent: Node3D, cue_id: String, name: String, at: Vector3, size: Vector3, tint: Color, glow := Color.BLACK, chosen_surface: Texture2D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(cue_id, tint, glow, chosen_surface)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	parent.add_child(node)
	return node


func _rod(parent: Node3D, cue_id: String, name: String, start: Vector3, finish: Vector3, radius: float, tint: Color) -> void:
	var length := start.distance_to(finish)
	if length < 0.01:
		return
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	node.mesh = mesh
	node.material_override = _material(cue_id, tint)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = (start + finish) * 0.5
	node.basis = Basis(Quaternion(Vector3.UP, (finish - start).normalized()))
	parent.add_child(node)


func _gable(parent: Node3D, cue_id: String, name: String, z: float, width: float, base_y: float, height: float, tint: Color) -> void:
	var vertices := PackedVector3Array([
		Vector3(-width * 0.5, base_y, z),
		Vector3(width * 0.5, base_y, z),
		Vector3(0.0, base_y + height, z),
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -1.0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.5, 0.0)])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var face := MeshInstance3D.new()
	face.name = name
	face.mesh = mesh
	face.material_override = _material(cue_id, tint)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(face)


func _build_sisters() -> void:
	# The starting house and tree gaps carry this first cue. A second freestanding
	# corridor beside the house looked like an unfinished construction shell.
	_root_at("sisters", 16.0, -7.2, "SistersBearing")


func _build_lighthouse() -> void:
	var stone := Color("777d82")
	var iron := Color("292f3b")
	var root := _root_at("thread", 31.0, -9.0, "LighthouseWithoutCoast")
	var foundation := MeshInstance3D.new()
	foundation.name = "TowerFoundation"
	var foundation_mesh := CylinderMesh.new()
	foundation_mesh.top_radius = 1.55
	foundation_mesh.bottom_radius = 1.7
	foundation_mesh.height = 0.7
	foundation_mesh.radial_segments = 24
	foundation.mesh = foundation_mesh
	foundation.material_override = _material("thread", stone)
	foundation.position = Vector3(0.0, 0.0, 2.7)
	root.add_child(foundation)
	var column := MeshInstance3D.new()
	column.name = "TowerBody"
	var stone_mesh := CylinderMesh.new()
	stone_mesh.top_radius = 1.02
	stone_mesh.bottom_radius = 1.52
	stone_mesh.height = 5.7
	stone_mesh.radial_segments = 24
	column.mesh = stone_mesh
	column.material_override = _material("thread", stone)
	column.position = Vector3(0.0, 2.75, 2.7)
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(column)
	_box(root, "thread", "ClosedDoor", Vector3(0.0, 0.97, 1.23), Vector3(0.8, 1.72, 0.08), iron)
	for index in 3:
		var height := 1.2 + float(index) * 1.55
		_box(root, "thread", "MasonryBand_%02d" % index, Vector3(0.0, height, 2.7), Vector3(2.5 - float(index) * 0.26, 0.11, 0.11), stone.darkened(0.22))
	for index in 2:
		_box(root, "thread", "ShutteredWindow_%02d" % index, Vector3(0.0, 2.45 + float(index) * 1.65, 1.47 + float(index) * 0.21), Vector3(0.38, 0.62, 0.08), iron)
	var gallery := MeshInstance3D.new()
	gallery.name = "GalleryThatReturns"
	var gallery_mesh := CylinderMesh.new()
	gallery_mesh.top_radius = 2.05
	gallery_mesh.bottom_radius = 2.05
	gallery_mesh.height = 0.18
	gallery_mesh.radial_segments = 24
	gallery.mesh = gallery_mesh
	gallery.material_override = _material("thread", stone)
	gallery.position = Vector3(0.0, 5.65, 2.7)
	root.add_child(gallery)
	var beacon := MeshInstance3D.new()
	beacon.name = "BeaconGlass"
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.56
	beacon_mesh.bottom_radius = 0.56
	beacon_mesh.height = 0.94
	beacon_mesh.radial_segments = 12
	beacon.mesh = beacon_mesh
	beacon.material_override = _material("thread", Color("83929a"), Color("425b68"))
	beacon.position = Vector3(0.0, 6.23, 2.7)
	root.add_child(beacon)
	var cap := MeshInstance3D.new()
	cap.name = "BeaconCap"
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.28
	cap_mesh.bottom_radius = 1.12
	cap_mesh.height = 0.58
	cap_mesh.radial_segments = 12
	cap.mesh = cap_mesh
	cap.material_override = _material("thread", iron)
	cap.position = Vector3(0.0, 7.02, 2.7)
	root.add_child(cap)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var edge := Vector3(cos(angle) * 1.86, 0.0, 2.7 + sin(angle) * 1.86)
		_rod(root, "thread", "GalleryPost_%02d" % index, edge + Vector3.UP * 5.73, edge + Vector3.UP * 6.53, 0.026, iron)
		if index > 0:
			var last_angle := TAU * float(index - 1) / 8.0
			var last := Vector3(cos(last_angle) * 1.86, 6.47, 2.7 + sin(last_angle) * 1.86)
			_rod(root, "thread", "GalleryRail_%02d" % index, last, edge + Vector3.UP * 6.47, 0.027, iron)
	_rod(root, "thread", "GalleryRailClosing", Vector3(cos(TAU * 7.0 / 8.0) * 1.86, 6.47, 2.7 + sin(TAU * 7.0 / 8.0) * 1.86), Vector3(1.86, 6.47, 2.7), 0.027, iron)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var edge := Vector3(cos(angle) * 0.55, 0.0, 2.7 + sin(angle) * 0.55)
		_rod(root, "thread", "LanternFrame_%02d" % index, edge + Vector3.UP * 5.79, edge + Vector3.UP * 6.76, 0.027, iron)
	_beam_pivot = Node3D.new()
	_beam_pivot.name = "SearchingBearing"
	_beam_pivot.position = Vector3(0.0, 6.46, 2.15)
	root.add_child(_beam_pivot)
	var beam_shape := MeshInstance3D.new()
	beam_shape.name = "BeamInTheSnow"
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.06
	beam_mesh.bottom_radius = 2.6
	beam_mesh.height = 17.0
	beam_mesh.radial_segments = 16
	beam_shape.mesh = beam_mesh
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = BEAM_SHADER
	_beam_material.set_shader_parameter("strength", 0.0)
	beam_shape.material_override = _beam_material
	beam_shape.position = Vector3(0.0, 0.0, -8.5)
	beam_shape.rotation.x = PI * 0.5
	beam_shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_pivot.add_child(beam_shape)
	_lighthouse_beam = SpotLight3D.new()
	_lighthouse_beam.name = "SearchingBeam"
	_lighthouse_beam.light_color = Color("c6d6db")
	_lighthouse_beam.light_energy = 0.0
	_lighthouse_beam.spot_range = 28.0
	_lighthouse_beam.spot_angle = 34.0
	_lighthouse_beam.shadow_enabled = false
	_lighthouse_beam.light_volumetric_fog_energy = 0.65
	_beam_pivot.add_child(_lighthouse_beam)


func _build_window() -> void:
	var plaster := Color("77716e")
	var timber := Color("37302f")
	var root := _root_at("window", 46.0, 7.2, "RoomInTheTrees")
	_box(root, "window", "StonePlinth", Vector3(0.0, -0.2, 1.6), Vector3(5.62, 0.7, 3.45), Color("555756"), Color.BLACK, STONE_TEXTURE)
	_box(root, "window", "WallLeft", Vector3(-2.1, 1.38, 0.0), Vector3(1.25, 2.75, 0.18), plaster)
	_box(root, "window", "WallRight", Vector3(2.1, 1.38, 0.0), Vector3(1.25, 2.75, 0.18), plaster)
	_box(root, "window", "WallBelowSill", Vector3(0.0, 0.43, 0.0), Vector3(3.0, 0.86, 0.18), plaster)
	_box(root, "window", "WallAboveWindow", Vector3(0.0, 2.53, 0.0), Vector3(3.0, 0.45, 0.18), plaster)
	for side in [-1.0, 1.0]:
		_box(root, "window", "WindowJamb_%s" % side, Vector3(side * 1.52, 1.59, -0.12), Vector3(0.11, 1.54, 0.13), timber)
	_box(root, "window", "WindowSill", Vector3(0.0, 0.88, -0.16), Vector3(3.25, 0.15, 0.4), timber)
	_box(root, "window", "WindowLintel", Vector3(0.0, 2.34, -0.13), Vector3(3.22, 0.13, 0.2), timber)
	_box(root, "window", "WindowMullion", Vector3(0.0, 1.6, -0.15), Vector3(0.09, 1.45, 0.12), timber)
	_box(root, "window", "BackWall", Vector3(0.0, 1.42, 3.2), Vector3(5.48, 2.84, 0.18), plaster)
	_box(root, "window", "WarmInterior", Vector3(0.0, 1.42, 3.08), Vector3(5.2, 2.66, 0.02), Color("805f4e"), Color("975c37"))
	for side in [-1.0, 1.0]:
		_box(root, "window", "Curtain_%s" % side, Vector3(side * 1.26, 1.55, 0.17), Vector3(0.37, 1.34, 0.08), Color("766259"), Color("3f261c"))
		_box(root, "window", "SideWall_%s" % side, Vector3(side * 2.74, 1.42, 1.6), Vector3(0.18, 2.84, 3.35), plaster)
		var roof := _box(root, "window", "PitchedRoof_%s" % side, Vector3(side * 1.38, 3.18, 1.6), Vector3(2.9, 0.15, 3.75), Color("626871"), Color.BLACK, ROOF_TEXTURE)
		roof.rotation.z = -side * 0.277
		_box(root, "window", "Eave_%s" % side, Vector3(side * 2.78, 2.85, 1.6), Vector3(0.16, 0.14, 3.75), timber)
	_box(root, "window", "RoofRidge", Vector3(0.0, 3.57, 1.6), Vector3(0.16, 0.18, 3.75), timber)
	_gable(root, "window", "FrontGable", -0.08, 5.48, 2.75, 0.8, plaster)
	_gable(root, "window", "BackGable", 3.3, 5.48, 2.75, 0.8, plaster)
	_box(root, "window", "InteriorFloor", Vector3(0.0, 0.14, 1.6), Vector3(5.3, 0.1, 3.2), timber)
	_box(root, "window", "SideDoor", Vector3(2.85, 1.09, 1.65), Vector3(0.08, 2.04, 0.91), timber)
	_box(root, "window", "SideDoorLintel", Vector3(2.91, 2.18, 1.65), Vector3(0.11, 0.12, 1.13), timber.lightened(0.15))
	_box(root, "window", "SideDoorHandle", Vector3(2.92, 1.04, 1.34), Vector3(0.05, 0.07, 0.07), Color("b0a07b"))
	_box(root, "window", "BackDoor", Vector3(0.0, 1.09, 3.32), Vector3(0.96, 2.04, 0.08), timber)
	for side in [-1.0, 1.0]:
		_box(root, "window", "BackDoorJamb_%s" % side, Vector3(side * 0.54, 1.1, 3.34), Vector3(0.1, 2.2, 0.12), timber.lightened(0.15))
	_box(root, "window", "BackDoorLintel", Vector3(0.0, 2.25, 3.34), Vector3(1.18, 0.1, 0.12), timber.lightened(0.15))
	_box(root, "window", "BackDoorHandle", Vector3(-0.32, 1.03, 3.38), Vector3(0.07, 0.07, 0.04), Color("b0a07b"))
	_window_light = OmniLight3D.new()
	_window_light.name = "TheWarmWindow"
	_window_light.light_color = Color("ffc48e")
	_window_light.light_energy = 0.0
	_window_light.omni_range = 10.5
	_window_light.shadow_enabled = false
	_window_light.position = Vector3(0.0, 1.7, 0.4)
	root.add_child(_window_light)


func _build_clearing() -> void:
	var root := _root_at("clearing", 61.0, -8.0, "ClearingBearing")
	_build_ice_horizon(root)
	_build_wrong_horizon_window(root)
	_clearing_light = OmniLight3D.new()
	_clearing_light.name = "ClearingAfterimage"
	_clearing_light.light_color = Color("c7d8e5")
	_clearing_light.light_energy = 0.0
	_clearing_light.omni_range = 9.0
	_clearing_light.shadow_enabled = false
	_clearing_light.position = Vector3(0.0, 2.6, 1.0)
	root.add_child(_clearing_light)


func _build_wrong_horizon_window(root: Node3D) -> void:
	# A small piece of the cabin's wall has surfaced through the far ice. The
	# buried base makes the window feel attached to the landscape, not suspended.
	var center := Vector3(1.0, 1.55, 2.84)
	var pane := _material("clearing", Color("e3a875"), Color("ffc58d"), PLASTER_TEXTURE)
	pane.set_shader_parameter("texture_strength", 0.0)
	var backing := _box(root, "clearing", "BuriedWindowWall", Vector3(1.0, 1.0, 2.84), Vector3(1.72, 2.45, 0.38), Color("586575"), Color("17202e"), STONE_TEXTURE)
	backing.rotation.z = -0.045
	var snow_cap := _box(root, "clearing", "WindowWallIceCap", Vector3(0.98, 2.16, 2.84), Vector3(1.92, 0.12, 0.52), Color("9caeb8"), Color.BLACK, STONE_TEXTURE)
	snow_cap.rotation.z = -0.045
	var glass := MeshInstance3D.new()
	glass.name = "WrongHorizonWarmPanes"
	var glass_mesh := QuadMesh.new()
	glass_mesh.size = Vector2(0.58, 0.74)
	glass.mesh = glass_mesh
	glass.material_override = pane
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = center + Vector3(0.0, 0.0, -0.205)
	root.add_child(glass)
	_box(root, "clearing", "WrongHorizonJambLeft", center + Vector3(-0.34, 0.0, -0.23), Vector3(0.06, 0.9, 0.08), Color("596573"), Color.BLACK, STONE_TEXTURE)
	_box(root, "clearing", "WrongHorizonJambRight", center + Vector3(0.34, 0.0, -0.23), Vector3(0.06, 0.9, 0.08), Color("596573"), Color.BLACK, STONE_TEXTURE)
	_box(root, "clearing", "WrongHorizonLintel", center + Vector3(0.0, 0.45, -0.23), Vector3(0.74, 0.06, 0.08), Color("596573"), Color.BLACK, STONE_TEXTURE)
	_box(root, "clearing", "WrongHorizonSill", center + Vector3(0.0, -0.45, -0.23), Vector3(0.74, 0.06, 0.08), Color("596573"), Color.BLACK, STONE_TEXTURE)
	_box(root, "clearing", "WrongHorizonMullion", center + Vector3(0.0, 0.0, -0.23), Vector3(0.04, 0.76, 0.09), Color("596573"), Color.BLACK, STONE_TEXTURE)
	_wrong_horizon_light = OmniLight3D.new()
	_wrong_horizon_light.name = "WarmLightBeyondTheIce"
	_wrong_horizon_light.light_color = Color("ffc48e")
	_wrong_horizon_light.light_energy = 0.0
	_wrong_horizon_light.omni_range = 4.2
	_wrong_horizon_light.shadow_enabled = false
	_wrong_horizon_light.position = center + Vector3(0.0, 0.0, -0.08)
	root.add_child(_wrong_horizon_light)


func _build_ice_horizon(root: Node3D) -> void:
	# One low, folded ridge reads as the edge of the frozen basin. Its changing
	# depth makes the line plausible up close and subtly impossible at a distance.
	var stations := [
		{"x": -7.2, "z": 5.1, "height": 0.68},
		{"x": -5.4, "z": 4.25, "height": 1.08},
		{"x": -3.5, "z": 3.58, "height": 0.82},
		{"x": -1.7, "z": 3.03, "height": 1.14},
		{"x": 0.0, "z": 2.82, "height": 0.76},
		{"x": 2.0, "z": 2.96, "height": 1.08},
		{"x": 3.9, "z": 3.48, "height": 0.82},
		{"x": 5.7, "z": 4.22, "height": 1.02},
		{"x": 7.2, "z": 5.12, "height": 0.64},
	]
	var ice := _material("clearing", Color("4f6075"), Color("4b5c72"), STONE_TEXTURE)
	ice.set_shader_parameter("texture_strength", 0.38)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(stations.size() - 1):
		var left: Dictionary = stations[index]
		var right: Dictionary = stations[index + 1]
		var left_x := float(left["x"])
		var right_x := float(right["x"])
		var left_front := Vector3(left_x, 0.0, float(left["z"]) - 1.25)
		var left_back := Vector3(left_x, 0.0, float(left["z"]) + 1.25)
		var right_front := Vector3(right_x, 0.0, float(right["z"]) - 1.25)
		var right_back := Vector3(right_x, 0.0, float(right["z"]) + 1.25)
		var left_top_front := Vector3(left_x, float(left["height"]), float(left["z"]) - 0.22)
		var left_top_back := Vector3(left_x, float(left["height"]), float(left["z"]) + 0.22)
		var right_top_front := Vector3(right_x, float(right["height"]), float(right["z"]) - 0.22)
		var right_top_back := Vector3(right_x, float(right["height"]), float(right["z"]) + 0.22)
		_add_double_sided_quad(surface, left_front, right_front, right_top_front, left_top_front)
		_add_double_sided_quad(surface, right_back, left_back, left_top_back, right_top_back)
		_add_double_sided_quad(surface, left_top_front, right_top_front, right_top_back, left_top_back)
	_add_double_sided_quad(surface, Vector3(-7.2, 0.0, 5.1 - 1.25), Vector3(-7.2, 0.0, 5.1 + 1.25), Vector3(-7.2, 0.68, 5.1 + 0.22), Vector3(-7.2, 0.68, 5.1 - 0.22))
	_add_double_sided_quad(surface, Vector3(7.2, 0.0, 5.12 - 1.25), Vector3(7.2, 0.0, 5.12 + 1.25), Vector3(7.2, 0.64, 5.12 + 0.22), Vector3(7.2, 0.64, 5.12 - 0.22))
	surface.generate_normals()
	var ridge := MeshInstance3D.new()
	ridge.name = "FoldedIceHorizon"
	ridge.mesh = surface.commit()
	ridge.material_override = ice
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ridge)


func _add_double_sided_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for triangle in [[a, b, c], [a, c, d], [c, b, a], [d, c, a]]:
		for vertex in triangle:
			surface.add_vertex(vertex)
