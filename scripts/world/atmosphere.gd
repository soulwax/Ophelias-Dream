class_name Atmosphere
extends WorldEnvironment

const VOLUMETRIC_SHADER := "res://shaders/volumetric_weather.gdshader"

var _sun: DirectionalLight3D
var _veil: ShaderMaterial
var _local_veil: ShaderMaterial
var _env: Environment
# 0 out in the snow .. 1 deep inside the house. Indoors the daylight ambience
# falls away and the rooms are only what their lamps make of them.
var shelter := 0.0
# 0..1: how much snow is in the air here, from the snow weight under the camera
# (set by Weather). Over green land the veil thins away; the fog stays.
var snow_cover := 1.0
# Hours on a 24 h clock. It only runs once a chapter starts it (Mathilda's, at
# early dusk); until then the sun stays where Ophelia's afternoon left it.
var clock_hours := 14.5
var clock_running := false
var _moon: DirectionalLight3D


func start_clock(hours: float) -> void:
	clock_hours = hours
	clock_running = true
	if _moon == null:
		_moon = DirectionalLight3D.new()
		_moon.name = "Moon"
		_moon.light_color = Color(0.56, 0.66, 0.92)
		_moon.light_energy = 0.0
		_moon.rotation_degrees = Vector3(-48, 150, 0)
		_moon.light_volumetric_fog_energy = 0.6
		add_child(_moon)


func _process(delta: float) -> void:
	if clock_running and Game.awake():
		clock_hours = fposmod(clock_hours + delta * 24.0 / (Tune.DAY_MINUTES * 60.0), 24.0)


## Sun height in degrees: up from 06:00 to 18:00, a low winter arc.
func sun_elevation() -> float:
	return sin((clock_hours - 6.0) / 12.0 * PI) * 32.0


## 1 in full daylight, 0 at night, through civil twilight in between.
func daylight() -> float:
	return smoothstep(-8.0, 6.0, sun_elevation()) if clock_running else 1.0


func rebind_authoring_resources() -> void:
	_env = environment
	if _env:
		_configure_environment_weather(_env)
	var volume := get_node_or_null("SnowFog") as FogVolume
	if Game.lean_graphics:
		if volume:
			volume.visible = false
		_veil = null
	elif volume:
		if not (volume.material is ShaderMaterial):
			volume.material = _make_volumetric_material(0.011, 0.026, 0.034, 0.14)
		_veil = volume.material as ShaderMaterial


func _ready() -> void:
	add_to_group("atmosphere")
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
	sun.light_volumetric_fog_energy = 1.95
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
	volume.size = Vector3(360, 44, 360)
	volume.position = Vector3(0, 15, -74)
	_veil = _make_volumetric_material(0.011, 0.026, 0.034, 0.14)
	volume.material = _veil
	add_child(volume)


func bind_local_volume(volume: FogVolume) -> void:
	if volume == null or Game.lean_graphics:
		return
	_local_veil = _make_volumetric_material(0.008, 0.038, 0.052, 0.18)
	volume.material = _local_veil


func _make_volumetric_material(base_d: float, squall_d: float, spindrift_d: float, emit_e: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists(VOLUMETRIC_SHADER):
		mat.shader = load(VOLUMETRIC_SHADER) as Shader
	mat.set_shader_parameter("base_density", base_d)
	mat.set_shader_parameter("squall_density", squall_d)
	mat.set_shader_parameter("spindrift_density", spindrift_d)
	mat.set_shader_parameter("emission_energy", emit_e)
	return mat


func apply_storm(strength: float) -> void:
	apply_weather(
		strength,
		clampf((strength - 0.25) * 1.2, 0.0, 1.0),
		clampf((strength - 0.65) * 2.5, 0.0, 1.0),
		strength,
		Vector3(6.0, 0.0, 2.5),
		Vector3.ZERO,
		0.0
	)


func apply_weather(
	intensity: float,
	gust: float,
	whiteout: float,
	flurry: float,
	wind: Vector3,
	wind_scroll: Vector3,
	focus_y: float
) -> void:
	if _env == null:
		return
	var s := clampf(intensity, 0.0, 1.0)
	var g := clampf(gust, 0.0, 1.0)
	var w := clampf(whiteout, 0.0, 1.0)
	var f := clampf(flurry, 0.0, 1.0)
	var indoors := clampf(shelter, 0.0, 1.0)
	var outdoor_mask := lerpf(1.0, 0.04, indoors)

	# Exponential depth fog + ground-hugging spindrift height fog.
	var base_fog := lerpf(0.0045, 0.024, pow(s, 1.25)) + w * 0.014 + g * 0.004
	if not Game.lean_graphics:
		base_fog *= 0.62
	_env.fog_density = base_fog * outdoor_mask
	_env.fog_height = focus_y + lerpf(2.2, 8.5, clampf(s * 0.65 + g * 0.35 + w * 0.4, 0.0, 1.0))
	_env.fog_height_density = lerpf(0.032, 0.22, clampf(s * 0.55 + g * 0.45 + w * 0.35, 0.0, 1.0)) * outdoor_mask
	_env.fog_aerial_perspective = lerpf(0.38, 0.78, clampf(s * 0.7 + w * 0.3, 0.0, 1.0))

	var clear_fog := Color(0.75, 0.82, 0.90)
	var squall_fog := Color(0.82, 0.86, 0.91)
	var whiteout_fog := Color(0.90, 0.93, 0.96)
	_env.fog_light_color = clear_fog.lerp(squall_fog, s).lerp(whiteout_fog, w)
	_env.fog_light_energy = lerpf(0.95, 1.22, w * 0.7 + g * 0.3)
	_env.fog_sun_scatter = lerpf(0.28, 0.06, clampf(s * 0.6 + w * 0.6, 0.0, 1.0))

	# Volumetric fog scattering: forward-scattered sun shafts during lulls,
	# dense isotropic whiteout wall during blizzards.
	_env.volumetric_fog_density = lerpf(0.0045, 0.024, pow(s, 1.3)) + w * 0.012
	_env.volumetric_fog_albedo = Color(0.88, 0.92, 0.97).lerp(Color(0.96, 0.98, 1.0), w * 0.7 + f * 0.3)
	_env.volumetric_fog_anisotropy = lerpf(0.62, 0.26, clampf(s * 0.55 + w * 0.65, 0.0, 1.0))
	_env.volumetric_fog_length = lerpf(108.0, 58.0, clampf(s * 0.6 + w * 0.5, 0.0, 1.0))
	_env.volumetric_fog_detail_spread = lerpf(1.25, 0.82, s)
	_env.volumetric_fog_ambient_inject = lerpf(0.58, 1.05, clampf(s * 0.6 + w * 0.5, 0.0, 1.0))

	var sky_clear := Color(0.60, 0.70, 0.81)
	var sky_squall := Color(0.72, 0.77, 0.83)
	var sky_whiteout := Color(0.85, 0.88, 0.92)
	_env.background_color = sky_clear.lerp(sky_squall, s).lerp(sky_whiteout, w)

	# Outside the fill is the storm's blue. Inside it is a warm bounce, so the
	# lamps read as a room and the cold is what comes through the door.
	var outdoor_ambient := Color(0.67, 0.75, 0.85).lerp(Color(0.78, 0.83, 0.89), w)
	_env.ambient_light_color = outdoor_ambient.lerp(Color(1.0, 0.82, 0.64), indoors)
	_env.ambient_light_energy = lerpf(0.92, 0.68, s * 0.7 + w * 0.3) * lerpf(1.0, 0.27, indoors)
	_env.adjustment_brightness = lerpf(1.04, 0.93, s * 0.65 + w * 0.35) * lerpf(1.0, 0.96, indoors) * (Game.settings.brightness if Game.settings else 1.0)
	_env.adjustment_contrast = lerpf(1.06, 0.98, w * 0.65)
	_env.adjustment_saturation = lerpf(lerpf(0.80, 0.46, clampf(s * 0.65 + w * 0.55, 0.0, 1.0)), 0.9, indoors)

	if _sun:
		var sun_tint := Color(0.88, 0.92, 0.98).lerp(Color(0.80, 0.86, 0.94), s)
		_sun.light_color = sun_tint.lerp(Color(1.0, 0.9, 0.78), indoors * 0.25)
		_sun.light_energy = lerpf(1.62, 0.82, clampf(s * 0.65 + w * 0.45, 0.0, 1.0)) * lerpf(1.0, 0.24, indoors)
		_sun.light_volumetric_fog_energy = lerpf(1.15, 2.35, clampf(s * 0.6 + g * 0.4 + w * 0.4, 0.0, 1.0)) * lerpf(1.0, 0.18, indoors)

	if clock_running:
		_apply_clock(indoors)

	var flat_wind := Vector2(wind.x, wind.z)
	var wind_dir := flat_wind.normalized() if flat_wind.length() > 0.05 else Vector2(0.92, 0.38)
	var house_inv := Game.house.global_transform.affine_inverse() if Game.house else Transform3D.IDENTITY
	_update_veil(_veil, s, g, w, wind_dir, wind_scroll, focus_y, house_inv, 0.011, 0.028, 0.036)
	_update_veil(_local_veil, s, g, w, wind_dir, wind_scroll, focus_y, house_inv, 0.008, 0.042, 0.056)


## Lays the hour over the weather's daylight: the sun sinks and warms toward
## the horizon, the sky and fog go through amber to blue dusk to night, and a
## faint moon takes over the shadows.
func _apply_clock(indoors: float) -> void:
	var elevation := sun_elevation()
	var day := daylight()
	# Low sun: 1 near the horizon, 0 once it is well up.
	var low := 1.0 - smoothstep(1.0, 18.0, elevation)
	var dusk := low * smoothstep(-7.0, 2.0, elevation)
	var t := (clock_hours - 6.0) / 12.0
	if _sun:
		_sun.rotation_degrees = Vector3(-maxf(elevation, 1.5), lerpf(-125.0, 125.0, clampf(t, 0.0, 1.0)), 0.0)
		_sun.light_color = _sun.light_color.lerp(Color(1.0, 0.56, 0.32), dusk * 0.85)
		_sun.light_energy *= smoothstep(-1.5, 7.0, elevation) * lerpf(1.0, 0.7, low)
		_sun.light_volumetric_fog_energy *= smoothstep(-3.0, 4.0, elevation)
	if _moon:
		_moon.light_energy = 0.11 * (1.0 - day) * lerpf(1.0, 0.24, indoors)
		_moon.visible = _moon.light_energy > 0.002
	var night_sky := Color(0.025, 0.035, 0.075)
	var dusk_sky := Color(0.82, 0.52, 0.42)
	var blue_hour := Color(0.18, 0.24, 0.42)
	var sky := _env.background_color.lerp(dusk_sky, dusk * 0.55)
	sky = blue_hour.lerp(sky, smoothstep(-6.0, 3.0, elevation))
	_env.background_color = night_sky.lerp(sky, day)
	var fog := _env.fog_light_color.lerp(Color(0.86, 0.6, 0.5), dusk * 0.5)
	_env.fog_light_color = Color(0.05, 0.065, 0.12).lerp(fog, day)
	_env.fog_light_energy *= lerpf(0.25, 1.0, day)
	_env.fog_sun_scatter *= lerpf(1.0, 2.2, dusk)
	var ambient := _env.ambient_light_color.lerp(Color(0.86, 0.66, 0.6), dusk * 0.35)
	_env.ambient_light_color = Color(0.32, 0.4, 0.62).lerp(ambient, day)
	_env.ambient_light_energy *= lerpf(0.13, 1.0, day)
	_env.volumetric_fog_ambient_inject *= lerpf(0.2, 1.0, day)
	_env.adjustment_saturation = lerpf(_env.adjustment_saturation, 0.95, dusk * 0.5)


func _update_veil(
	mat: ShaderMaterial,
	intensity: float,
	gust: float,
	whiteout: float,
	wind_dir: Vector2,
	wind_scroll: Vector3,
	ground_y: float,
	house_inv: Transform3D,
	base_d: float,
	squall_d: float,
	spindrift_d: float
) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("base_density", base_d * snow_cover)
	mat.set_shader_parameter("squall_density", squall_d * snow_cover)
	mat.set_shader_parameter("spindrift_density", spindrift_d * snow_cover)
	mat.set_shader_parameter("ground_level", ground_y)
	mat.set_shader_parameter("weather_intensity", intensity)
	mat.set_shader_parameter("gust_strength", gust)
	mat.set_shader_parameter("whiteout", whiteout)
	mat.set_shader_parameter("wind_dir", wind_dir)
	mat.set_shader_parameter("wind_scroll", wind_scroll)
	mat.set_shader_parameter("house_inv_transform", Projection(house_inv))


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
	_configure_environment_weather(env)
	return env


func _configure_environment_weather(env: Environment) -> void:
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0055
	env.fog_light_color = Color(0.78, 0.83, 0.88)
	env.fog_aerial_perspective = 0.48
	env.fog_sun_scatter = 0.18
	env.fog_height = 3.5
	env.fog_height_density = 0.075
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0075
	env.volumetric_fog_albedo = Color(0.92, 0.95, 0.98)
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 88.0
	env.volumetric_fog_ambient_inject = 0.75
	env.volumetric_fog_detail_spread = 1.08
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.88
	if Game.lean_graphics:
		env.ssao_enabled = false
		env.volumetric_fog_enabled = false
		env.fog_density = 0.009
