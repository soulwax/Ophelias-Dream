class_name Atmosphere
extends WorldEnvironment

var _sun: DirectionalLight3D
var _veil: FogMaterial
var _env: Environment
# 0 out in the snow .. 1 deep inside the house. Indoors the daylight ambience
# falls away and the rooms are only what their lamps make of them.
var shelter := 0.0


func rebind_authoring_resources() -> void:
	_env = environment
	var volume := get_node_or_null("SnowFog") as FogVolume
	_veil = volume.material as FogMaterial if volume else null
	if Game.lean_graphics and _env:
		_env.ssao_enabled = false
		_env.volumetric_fog_enabled = false
		_env.fog_density = 0.007
		if _sun:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			_sun.directional_shadow_max_distance = 70.0


func _ready() -> void:
	environment = _make_environment()
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(0.95, 0.94, 0.9)
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.04
	sun.light_volumetric_fog_energy = 1.8
	if Game.lean_graphics:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	_sun = sun
	if not Game.lean_graphics:
		_snow_volume()


func _snow_volume() -> void:
	var volume := FogVolume.new()
	volume.name = "SnowFog"
	volume.size = Vector3(360, 42, 360)
	volume.position = Vector3(0, 14, -74)
	var material := FogMaterial.new()
	material.density = 0.008
	material.albedo = Color(0.9, 0.93, 0.97)
	material.edge_fade = 0.18
	volume.material = material
	_veil = material
	add_child(volume)


func apply_storm(strength: float) -> void:
	if _env == null:
		return
	var t := clampf(strength, 0.0, 1.0) * 0.45
	if Game.lean_graphics:
		# Without volumetric fog the plain fog carries the whiteout alone.
		_env.fog_density = lerpf(0.007, 0.016, t)
	else:
		_env.fog_density = lerpf(0.004, 0.012, t)
	_env.fog_light_color = Color(0.78, 0.83, 0.88).lerp(Color(0.84, 0.87, 0.9), t)
	_env.volumetric_fog_density = lerpf(0.007, 0.02, t)
	_env.volumetric_fog_albedo = Color(0.9, 0.93, 0.96)
	_env.volumetric_fog_length = lerpf(90.0, 70.0, t)
	_env.background_color = Color(0.62, 0.7, 0.78).lerp(Color(0.7, 0.75, 0.8), t)
	# Outside the fill is the storm's blue. Inside it is a warm bounce, so the
	# lamps read as a room and the cold is what comes through the door.
	var indoors := clampf(shelter, 0.0, 1.0)
	_env.ambient_light_color = Color(0.68, 0.75, 0.84).lerp(Color(1.0, 0.82, 0.64), indoors)
	_env.ambient_light_energy = lerpf(0.9, 0.66, t) * lerpf(1.0, 0.27, indoors)
	_env.adjustment_brightness = lerpf(1.02, 0.92, t) * lerpf(1.0, 0.96, indoors) * (Game.settings.brightness if Game.settings else 1.0)
	_env.fog_density *= lerpf(1.0, 0.04, indoors)
	_env.adjustment_saturation = lerpf(lerpf(0.76, 0.52, t), 0.9, indoors)
	if _sun:
		_sun.light_color = Color(0.82, 0.88, 0.96).lerp(Color(1.0, 0.9, 0.78), indoors * 0.25)
		_sun.light_energy = lerpf(1.5, 0.95, t) * lerpf(1.0, 0.24, indoors)
		_sun.light_volumetric_fog_energy = lerpf(0.8, 1.3, t) * lerpf(1.0, 0.2, indoors)
	if _veil:
		_veil.density = lerpf(0.008, 0.02, t)
		_veil.albedo = Color(0.88, 0.91, 0.95)


func _make_environment() -> Environment:
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.64, 0.72, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.77, 0.84)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.05
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.04
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.78
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0045
	env.fog_light_color = Color(0.78, 0.83, 0.88)
	env.fog_aerial_perspective = 0.45
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.92, 0.94, 0.97)
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_ambient_inject = 0.7
	env.volumetric_fog_detail_spread = 1.1
	if Game.lean_graphics:
		env.ssao_enabled = false
		env.volumetric_fog_enabled = false
		env.fog_density = 0.007
	return env
