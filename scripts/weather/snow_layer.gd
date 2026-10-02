class_name SnowLayer
extends GPUParticles3D

var motion: ParticleProcessMaterial
var fall := 1.4
var wind_scale := 1.0
var spread_calm := 18.0
var spread_storm := 7.0
var gust_only := false


func setup(texture_path: String, count: int, life: float, box: Vector3, scale_min: float, scale_max: float, quad_size: Vector2, tint: Color) -> void:
	amount = count if not Game.lean_graphics else maxi(int(count * 0.5), 1)
	lifetime = life
	preprocess = 2.5
	randomness = 0.8
	explosiveness = 0.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-36, -20, -36), Vector3(72, 40, 72))
	draw_pass_1 = _card(texture_path, quad_size)
	motion = ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = box
	motion.angle_min = 0.0
	motion.angle_max = 360.0
	motion.angular_velocity_min = -35.0
	motion.angular_velocity_max = 35.0
	motion.scale_min = scale_min
	motion.scale_max = scale_max
	motion.color = tint
	motion.turbulence_enabled = not Game.lean_graphics
	motion.turbulence_noise_strength = 0.65
	motion.turbulence_noise_scale = 1.6
	motion.turbulence_noise_speed = Vector3(0.15, 0.05, 0.12)
	motion.turbulence_influence_min = 0.05
	motion.turbulence_influence_max = 0.22
	process_material = motion
	emitting = true


func align_to_velocity() -> void:
	if motion:
		motion.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)


func apply(intensity: float, wind: Vector3, gust: float) -> void:
	if motion == null:
		return
	var blow := Vector3(wind.x, 0.0, wind.z) * wind_scale
	var fall_speed := fall * lerpf(1.15, 0.55, intensity)
	var travel := Vector3(blow.x, -fall_speed, blow.z)
	var speed := maxf(travel.length(), 0.2)
	motion.direction = travel / speed
	motion.initial_velocity_min = speed * 0.62
	motion.initial_velocity_max = speed * (1.05 + gust * 0.45)
	motion.gravity = Vector3(blow.x * 0.15, -0.25 * fall, blow.z * 0.15)
	motion.spread = lerpf(spread_calm, spread_storm, intensity)
	if gust_only:
		amount_ratio = clampf(gust * intensity, 0.0, 0.75)
	else:
		amount_ratio = clampf(lerpf(0.55, 1.0, intensity), 0.2, 1.0)


func _card(texture_path: String, quad_size: Vector2) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = quad_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	if ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path)
	quad.material = material
	return quad
