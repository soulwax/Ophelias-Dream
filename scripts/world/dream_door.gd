class_name DreamDoor
extends Node3D

signal opened(door_id: String, flashback_id: String)

var door_id := ""
var flashback_id := ""
var label := "threshold"
var _tint := Color("b8a2d2")
var _open := false
var _pivot: Node3D
var _aperture: MeshInstance3D
var _glow: OmniLight3D
var _motion: Tween


func configure(identifier: String, title: String, cue: String, frame: Transform3D, tint: Color) -> void:
	door_id = identifier
	label = title
	flashback_id = cue
	_tint = tint
	global_transform = frame
	add_to_group("interactables")
	_build()


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.86, 0.0, -0.12), Vector3(1.72, 2.85, 0.24))]


func interact_label() -> String:
	return "Look through the " + label.to_lower() if _open else "Open the " + label.to_lower()


func interact() -> bool:
	if not _open:
		_open = true
		if _motion and _motion.is_running():
			_motion.kill()
		_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_motion.tween_property(_pivot, "rotation:y", -PI * 0.48, 1.1)
		_motion.parallel().tween_property(_glow, "light_energy", 1.9, 0.9)
		opened.emit(door_id, flashback_id)
	return true


func _build() -> void:
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = _tint.darkened(0.72)
	frame_material.roughness = 0.88
	frame_material.metallic = 0.12
	frame_material.emission_enabled = true
	frame_material.emission = _tint
	frame_material.emission_energy_multiplier = 0.12
	_add_box("LeftJamb", Vector3(-0.76, 1.34, 0.0), Vector3(0.16, 2.68, 0.22), frame_material)
	_add_box("RightJamb", Vector3(0.76, 1.34, 0.0), Vector3(0.16, 2.68, 0.22), frame_material)
	_add_box("Lintel", Vector3(0.0, 2.62, 0.0), Vector3(1.66, 0.16, 0.22), frame_material)
	_add_box("Threshold", Vector3(0.0, 0.035, 0.0), Vector3(1.56, 0.07, 0.34), frame_material)

	var aperture_material := ShaderMaterial.new()
	aperture_material.shader = preload("res://shaders/dream_threshold.gdshader")
	aperture_material.set_shader_parameter("tint", _tint)
	_aperture = _add_box("ImpossibleDarkness", Vector3(0.0, 1.28, -0.08), Vector3(1.34, 2.48, 0.035), aperture_material)

	_pivot = Node3D.new()
	_pivot.name = "Hinge"
	_pivot.position = Vector3(-0.69, 0.0, 0.08)
	add_child(_pivot)
	var door_material := StandardMaterial3D.new()
	door_material.albedo_color = Color("25232c")
	door_material.roughness = 0.86
	door_material.metallic = 0.08
	door_material.emission_enabled = true
	door_material.emission = _tint.darkened(0.45)
	door_material.emission_energy_multiplier = 0.16
	var leaf := MeshInstance3D.new()
	leaf.name = "Leaf"
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(1.35, 2.46, 0.10)
	leaf.mesh = leaf_mesh
	leaf.material_override = door_material
	leaf.position = Vector3(0.675, 1.28, 0.0)
	_pivot.add_child(leaf)
	var inlay_material := StandardMaterial3D.new()
	inlay_material.albedo_color = _tint.darkened(0.42)
	inlay_material.roughness = 0.74
	inlay_material.metallic = 0.12
	inlay_material.emission_enabled = true
	inlay_material.emission = _tint.darkened(0.52)
	inlay_material.emission_energy_multiplier = 0.1
	_add_leaf_inlay(_pivot, "LeftInlay", Vector3(0.16, 1.28, 0.056), Vector3(0.035, 2.12, 0.018), inlay_material)
	_add_leaf_inlay(_pivot, "RightInlay", Vector3(1.19, 1.28, 0.056), Vector3(0.035, 2.12, 0.018), inlay_material)
	_add_leaf_inlay(_pivot, "UpperInlay", Vector3(0.675, 2.31, 0.056), Vector3(1.00, 0.035, 0.018), inlay_material)
	_add_leaf_inlay(_pivot, "LowerInlay", Vector3(0.675, 0.25, 0.056), Vector3(1.00, 0.035, 0.018), inlay_material)
	_add_leaf_inlay(_pivot, "CenterGrain", Vector3(0.675, 1.28, 0.057), Vector3(0.035, 1.2, 0.018), inlay_material)
	_add_leaf_inlay(_pivot, "BackLeftInlay", Vector3(0.16, 1.28, -0.056), Vector3(0.035, 2.12, 0.018), inlay_material)
	_add_leaf_inlay(_pivot, "BackRightInlay", Vector3(1.19, 1.28, -0.056), Vector3(0.035, 2.12, 0.018), inlay_material)
	_add_leaf_inlay(_pivot, "BackUpperInlay", Vector3(0.675, 2.31, -0.056), Vector3(1.00, 0.035, 0.018), inlay_material)
	_add_leaf_inlay(_pivot, "BackLowerInlay", Vector3(0.675, 0.25, -0.056), Vector3(1.00, 0.035, 0.018), inlay_material)
	var body := StaticBody3D.new()
	body.name = "DoorLeafBody"
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = leaf_mesh.size
	shape.shape = box
	body.add_child(shape)
	leaf.add_child(body)

	_glow = OmniLight3D.new()
	_glow.name = "MemoryLight"
	_glow.position = Vector3(0.0, 1.3, -0.24)
	_glow.light_color = _tint
	_glow.light_energy = 0.28
	_glow.omni_range = 5.0
	_glow.shadow_enabled = false
	add_child(_glow)

	var title := Label3D.new()
	title.name = "ThresholdName"
	title.text = label.to_upper()
	title.font_size = 30
	title.modulate = Color("e2d8d0")
	title.outline_modulate = Color(0.035, 0.04, 0.07, 0.9)
	title.outline_size = 8
	title.position = Vector3(0.0, 2.96, 0.0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.no_depth_test = true
	title.pixel_size = 0.0017
	add_child(title)


func _add_box(node_name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance


func _add_leaf_inlay(parent: Node3D, node_name: String, at: Vector3, size: Vector3, material: Material) -> void:
	var inlay := MeshInstance3D.new()
	inlay.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	inlay.mesh = mesh
	inlay.material_override = material
	inlay.position = at
	inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inlay)
