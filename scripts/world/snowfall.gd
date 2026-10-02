class_name Snowfall
extends GPUParticles3D

func _ready() -> void:
	_configure(self, 1600, 7.0, Vector3(24, 8, 24), 0.35, 0.9, 0.45)
	var haze := GPUParticles3D.new()
	_configure(haze, 420, 9.0, Vector3(28, 10, 28), 0.9, 2.2, 0.22)
	haze.visibility_aabb = visibility_aabb
	add_child(haze)


func _configure(particles: GPUParticles3D, count: int, life: float, box: Vector3, scale_min: float, scale_max: float, alpha: float) -> void:
	particles.amount = count
	particles.lifetime = life
	particles.preprocess = 4.0
	particles.randomness = 0.65
	particles.visibility_aabb = AABB(Vector3(-32, -18, -32), Vector3(64, 36, 64))
	particles.local_coords = false
	particles.explosiveness = 0.0
	particles.process_material = _process_material(box, scale_min, scale_max)
	particles.draw_pass_1 = _flake(alpha)
	particles.emitting = true


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := camera.global_position
	global_position = Vector3(at.x, at.y + 8.0, at.z)


func _process_material(box: Vector3, scale_min: float, scale_max: float) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = box
	material.direction = Vector3(0.45, -1.0, 0.2)
	material.spread = 22.0
	material.initial_velocity_min = 0.4
	material.initial_velocity_max = 1.6
	material.gravity = Vector3(0.6, -0.8, 0.15)
	material.scale_min = scale_min
	material.scale_max = scale_max
	material.color = Color(0.95, 0.97, 1.0, 0.9)
	return material


func _flake(alpha: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/snowflake.gdshader")
	material.set_shader_parameter("alpha_scale", alpha)
	quad.material = material
	return quad
