class_name SnowLayer
extends GPUParticles3D

const SPINDRIFT_SHADER := "res://shaders/spindrift.gdshader"

var motion: ParticleProcessMaterial
var fall := 1.4
var wind_scale := 1.0
var spread_calm := 18.0
var spread_storm := 7.0
var gust_only := false
var spindrift_mode := false
var veil_mode := false
var glitter_mode := false
var _base_turbulence := 0.65


func setup(
	texture_path: String,
	count: int,
	life: float,
	box: Vector3,
	scale_min: float,
	scale_max: float,
	quad_size: Vector2,
	tint: Color
) -> void:
	amount = count if not Game.lean_graphics else maxi(int(count * 0.6), 1)
	lifetime = life
	preprocess = 2.5
	randomness = 0.82
	explosiveness = 0.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-48, -24, -48), Vector3(96, 48, 96))
	draw_pass_1 = _card(texture_path, quad_size)
	_build_motion(box, scale_min, scale_max, tint, 35.0)


func setup_spindrift(
	texture_path: String,
	count: int,
	life: float,
	box: Vector3,
	scale_min: float,
	scale_max: float,
	quad_size: Vector2,
	tint: Color,
	softness: float = 1.15,
	density_boost: float = 1.2
) -> void:
	amount = count if not Game.lean_graphics else maxi(int(count * 0.55), 1)
	lifetime = life
	preprocess = 2.0
	randomness = 0.88
	explosiveness = 0.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-48, -24, -48), Vector3(96, 48, 96))
	draw_pass_1 = _wisp_card(texture_path, quad_size, softness, density_boost)
	_build_motion(box, scale_min, scale_max, tint, 14.0)


func _build_motion(box: Vector3, scale_min: float, scale_max: float, tint: Color, spin: float) -> void:
	motion = ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = box
	motion.angle_min = -spin
	motion.angle_max = spin
	motion.angular_velocity_min = -spin
	motion.angular_velocity_max = spin
	motion.scale_min = scale_min
	motion.scale_max = scale_max
	motion.color = tint
	motion.turbulence_enabled = not Game.lean_graphics
	motion.turbulence_noise_strength = _base_turbulence
	motion.turbulence_noise_scale = 1.65
	motion.turbulence_noise_speed = Vector3(0.22, 0.07, 0.18)
	motion.turbulence_influence_min = 0.06
	motion.turbulence_influence_max = 0.24
	process_material = motion
	emitting = true


func align_to_velocity() -> void:
	if motion:
		motion.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)


func apply(intensity: float, wind: Vector3, gust: float, whiteout: float = 0.0, flurry: float = 0.5) -> void:
	if motion == null:
		return
	var blow := Vector3(wind.x, 0.0, wind.z) * wind_scale
	var fall_speed := fall * lerpf(1.18, 0.48, clampf(intensity * 0.75 + gust * 0.25, 0.0, 1.0))
	if spindrift_mode:
		fall_speed = lerpf(0.12, -0.18, gust)
	elif veil_mode:
		fall_speed = fall * lerpf(0.75, 0.35, gust)
	var travel := Vector3(blow.x, -fall_speed, blow.z)
	var speed := maxf(travel.length(), 0.2)
	motion.direction = travel / speed
	motion.initial_velocity_min = speed * (0.58 if not spindrift_mode else 0.72)
	motion.initial_velocity_max = speed * (1.08 + gust * 0.52 + whiteout * 0.22)
	motion.gravity = Vector3(blow.x * 0.18, -0.22 * fall if not spindrift_mode else 0.05 * gust, blow.z * 0.18)
	motion.spread = lerpf(spread_calm, spread_storm, clampf(intensity * 0.7 + gust * 0.3, 0.0, 1.0))
	if motion.turbulence_enabled:
		motion.turbulence_noise_strength = _base_turbulence * (0.75 + gust * 0.85 + flurry * 0.35)
		motion.turbulence_noise_speed = Vector3(wind.x * 0.04, 0.08 + gust * 0.12, wind.z * 0.04)

	if gust_only:
		amount_ratio = clampf((gust * 0.75 + whiteout * 0.45) * (0.45 + 0.55 * intensity), 0.0, 1.0)
	elif spindrift_mode:
		amount_ratio = clampf(0.18 + gust * 0.62 + intensity * 0.35 + whiteout * 0.25, 0.12, 1.0)
	elif veil_mode:
		amount_ratio = clampf((intensity - 0.18) * 1.15 + gust * 0.38 + whiteout * 0.45, 0.0, 1.0)
	elif glitter_mode:
		amount_ratio = clampf(lerpf(0.95, 0.22, whiteout) * lerpf(0.45, 1.0, flurry), 0.15, 1.0)
	else:
		amount_ratio = clampf(lerpf(0.28, 1.0, clampf(intensity * 0.7 + flurry * 0.3 + whiteout * 0.25, 0.0, 1.0)), 0.18, 1.0)


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


func _wisp_card(texture_path: String, quad_size: Vector2, softness: float, density_boost: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = quad_size
	if ResourceLoader.exists(SPINDRIFT_SHADER):
		var mat := ShaderMaterial.new()
		mat.shader = load(SPINDRIFT_SHADER) as Shader
		mat.set_shader_parameter("softness", softness)
		mat.set_shader_parameter("density_boost", density_boost)
		quad.material = mat
		return quad
	return _card(texture_path, quad_size)
