class_name Snowfall
extends GPUParticles3D

func _ready() -> void:
	amount = 700
	lifetime = 6.0
	randomness = 0.6
	visibility_aabb = AABB(Vector3(-18, -8, -18), Vector3(36, 16, 36))
	local_coords = false
	process_material = _process_material()
	draw_pass_1 = _flake()
	emitting = true


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := camera.global_position
	global_position = Vector3(at.x, at.y + 7.0, at.z)


func _process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(14, 0.4, 14)
	material.direction = Vector3(0.35, -1.0, 0.15)
	material.spread = 18.0
	material.initial_velocity_min = 0.6
	material.initial_velocity_max = 1.8
	material.gravity = Vector3(0.8, -1.4, 0.2)
	material.scale_min = 0.15
	material.scale_max = 0.45
	material.color = Color(0.9, 0.94, 1.0, 0.85)
	return material


func _flake() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.95, 1.0, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = material
	return quad
