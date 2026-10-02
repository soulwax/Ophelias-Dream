class_name Atmosphere
extends WorldEnvironment

func _ready() -> void:
	environment = _make_environment()
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.7, 0.86)
	moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-48, 32, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 48.0
	moon.shadow_bias = 0.08
	add_child(moon)


func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.045, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.38, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.9
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.58
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.026
	env.fog_light_color = Color(0.5, 0.56, 0.66)
	env.fog_aerial_perspective = 0.9
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.58, 0.64, 0.74)
	env.volumetric_fog_length = 72.0
	return env
