class_name Atmosphere
extends WorldEnvironment

const VOLUMETRIC_SHADER := "res://shaders/volumetric_weather.gdshader"
const DREAM_UNIVERSE_SKY_SHADER := "res://shaders/dream_universe_sky.gdshader"
const WINTER_SKY_SHADER := "res://shaders/winter_sky.gdshader"

var _sun: DirectionalLight3D
var _veil: ShaderMaterial
var _local_veil: ShaderMaterial
var _env: Environment
var _dream_sky: Sky
var _weather_sky: Sky
var _weather_sky_material: ShaderMaterial
var _cloud_coverage := 0.2
var _cloud_opacity := 0.68
var _cloud_offset := Vector2.ZERO
var _sun_clear_energy := 0.0
var _sun_clear_fog_energy := 0.0
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
	# Keep the sun disc and the cloud field aligned with the moving camera.
	_update_weather_sun_projection()


## Sun height in degrees: up from 06:00 to 18:00, a low winter arc.
func sun_elevation() -> float:
	return sin((clock_hours - 6.0) / 12.0 * PI) * 32.0


## 1 in full daylight, 0 at night, through civil twilight in between.
func daylight() -> float:
	return smoothstep(-8.0, 6.0, sun_elevation()) if clock_running else 1.0


func rebind_authoring_resources() -> void:
	_env = environment
	# Old snapshots store four cascades; keep authored direction and colour,
	# but apply the current shadow budget after their properties are copied.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if _env:
		_configure_environment_weather(_env)
	var volume := get_node_or_null("SnowFog") as FogVolume
	if Game.lean_graphics:
		if volume:
			volume.visible = false
		_veil = null
	elif volume:
		if not (volume.material is ShaderMaterial):
			volume.material = _make_volumetric_material(0.001, 0.026, 0.034)
		_veil = volume.material as ShaderMaterial


func _ready() -> void:
	add_to_group("atmosphere")
	environment = _make_environment()
	_ensure_weather_sky()
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(0.95, 0.94, 0.9)
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.04
	sun.light_angular_distance = 0.42
	sun.shadow_blur = 1.1
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
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
	_veil = _make_volumetric_material(0.001, 0.026, 0.034)
	volume.material = _veil
	add_child(volume)


func bind_local_volume(volume: FogVolume) -> void:
	if volume == null or Game.lean_graphics:
		return
	_local_veil = _make_volumetric_material(0.0008, 0.038, 0.052)
	volume.material = _local_veil


func _make_volumetric_material(base_d: float, squall_d: float, spindrift_d: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists(VOLUMETRIC_SHADER):
		mat.shader = load(VOLUMETRIC_SHADER) as Shader
	mat.set_shader_parameter("base_density", base_d)
	mat.set_shader_parameter("squall_density", squall_d)
	mat.set_shader_parameter("spindrift_density", spindrift_d)
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

	var in_dream := Game.dream_mode or Game.phase == Game.Phase.DREAM
	# Exponential depth fog + ground-hugging spindrift height fog.
	var base_fog := lerpf(0.0045, 0.024, pow(s, 1.25)) + w * 0.014 + g * 0.004
	if not Game.lean_graphics:
		base_fog *= 0.62
	_env.fog_density = base_fog * outdoor_mask
	_env.fog_height = focus_y + lerpf(2.2, 8.5, clampf(s * 0.65 + g * 0.35 + w * 0.4, 0.0, 1.0))
	_env.fog_height_density = lerpf(0.032, 0.22, clampf(s * 0.55 + g * 0.45 + w * 0.35, 0.0, 1.0)) * outdoor_mask
	if in_dream:
		# Memory fragments and the panoramic cosmos need clear depth through the winter night.
		_env.fog_density *= 0.36
		_env.fog_height_density *= 0.32
	_env.fog_aerial_perspective = 0.08 if in_dream else lerpf(0.38, 0.78, clampf(s * 0.7 + w * 0.3, 0.0, 1.0))
	# Keep distant fog on the landscape, but let the actual sky retain its
	# blue-to-cream gradient and cloud contrast instead of whitening overhead.
	_env.fog_sky_affect = 0.06 if in_dream else 0.18

	var clear_fog := Color(0.75, 0.82, 0.90)
	var squall_fog := Color(0.82, 0.86, 0.91)
	var whiteout_fog := Color(0.90, 0.93, 0.96)
	_env.fog_light_color = clear_fog.lerp(squall_fog, s).lerp(whiteout_fog, w)
	if in_dream:
		_env.fog_light_color = _env.fog_light_color.lerp(Color(0.18, 0.20, 0.38), 0.72)
	_env.fog_light_energy = lerpf(0.95, 1.22, w * 0.7 + g * 0.3)
	if in_dream:
		_env.fog_light_energy *= 0.52
	_env.fog_sun_scatter = lerpf(0.28, 0.06, clampf(s * 0.6 + w * 0.6, 0.0, 1.0))

	# Volumetric fog scattering: forward-scattered sun shafts during lulls,
	# dense isotropic whiteout wall during blizzards.
	_env.volumetric_fog_density = lerpf(0.0012, 0.024, pow(s, 1.3)) + w * 0.012
	if in_dream:
		_env.volumetric_fog_density *= 0.42
	_env.volumetric_fog_sky_affect = 0.06 if in_dream else 0.22
	_env.volumetric_fog_albedo = Color(0.88, 0.92, 0.97).lerp(Color(0.96, 0.98, 1.0), w * 0.7 + f * 0.3)
	_env.volumetric_fog_anisotropy = lerpf(0.62, 0.26, clampf(s * 0.55 + w * 0.65, 0.0, 1.0))
	_env.volumetric_fog_length = lerpf(108.0, 58.0, clampf(s * 0.6 + w * 0.5, 0.0, 1.0))
	_env.volumetric_fog_detail_spread = lerpf(1.25, 0.82, s)
	_env.volumetric_fog_ambient_inject = lerpf(0.35, 0.85, clampf(s * 0.6 + w * 0.5, 0.0, 1.0))

	var sky_clear := Color(0.60, 0.70, 0.81)
	var sky_squall := Color(0.72, 0.77, 0.83)
	var sky_whiteout := Color(0.85, 0.88, 0.92)
	_env.background_color = sky_clear.lerp(sky_squall, s).lerp(sky_whiteout, w)
	if in_dream:
		_ensure_dream_sky()
		_env.background_mode = Environment.BG_SKY
		_env.sky = _dream_sky
	else:
		_ensure_weather_sky()
		_env.background_mode = Environment.BG_SKY
		_env.sky = _weather_sky

	# Keep a faint, neutral sky bounce indoors. Warmth comes from the fixtures,
	# while their shadows and the surface normals can still describe the room.
	var outdoor_ambient := Color(0.67, 0.75, 0.85).lerp(Color(0.78, 0.83, 0.89), w)
	_env.ambient_light_color = outdoor_ambient.lerp(Color(0.68, 0.73, 0.76), indoors)
	if in_dream:
		_env.ambient_light_color = _env.ambient_light_color.lerp(Color(0.46, 0.44, 0.74), 0.38)
	_env.ambient_light_energy = lerpf(0.92, 0.68, s * 0.7 + w * 0.3) * lerpf(1.0, 0.18, indoors)
	_env.adjustment_brightness = lerpf(1.04, 0.93, s * 0.65 + w * 0.35) * lerpf(1.0, 0.96, indoors) * (Game.settings.brightness if Game.settings else 1.0)
	if in_dream:
		_env.ambient_light_energy *= 0.76
		_env.adjustment_brightness *= 0.96
	_env.adjustment_contrast = 1.08 if in_dream else lerpf(1.06, 0.98, w * 0.65)
	_env.adjustment_saturation = 1.06 if in_dream else lerpf(lerpf(0.80, 0.46, clampf(s * 0.65 + w * 0.55, 0.0, 1.0)), 0.9, indoors)
	_env.glow_intensity = 0.28 if in_dream else 0.18
	_env.glow_bloom = 0.10 if in_dream else 0.06

	if _sun:
		var sun_tint := Color(1.0, 0.96, 0.86).lerp(Color(0.83, 0.88, 0.96), s)
		_sun.light_color = sun_tint.lerp(Color(0.74, 0.80, 1.0), 0.35) if in_dream else sun_tint
		_sun.light_energy = lerpf(1.62, 0.82, clampf(s * 0.65 + w * 0.45, 0.0, 1.0))
		_sun.light_volumetric_fog_energy = lerpf(0.4, 1.35, clampf(s * 0.6 + g * 0.4 + w * 0.4, 0.0, 1.0))
		if in_dream:
			_sun.light_energy *= 0.62
			_sun.light_volumetric_fog_energy *= 0.32

	if clock_running:
		_apply_clock()
	if _sun:
		_sun_clear_energy = _sun.light_energy
		_sun_clear_fog_energy = _sun.light_volumetric_fog_energy
	_cloud_offset = Vector2(wind_scroll.x, wind_scroll.z) * 0.003
	_update_weather_sky(s, g, w)
	_update_cloud_light()

	var flat_wind := Vector2(wind.x, wind.z)
	var wind_dir := flat_wind.normalized() if flat_wind.length() > 0.05 else Vector2(0.92, 0.38)
	var house_inv := Game.house.global_transform.affine_inverse() if Game.house else Transform3D.IDENTITY
	_update_veil(_veil, s, g, w, wind_dir, wind_scroll, focus_y, house_inv, 0.001, 0.028, 0.036)
	_update_veil(_local_veil, s, g, w, wind_dir, wind_scroll, focus_y, house_inv, 0.0008, 0.042, 0.056)


## Lays the hour over the weather's daylight: the sun sinks and warms toward
## the horizon, the sky and fog go through amber to blue dusk to night, and a
## faint moon takes over the shadows.
func _apply_clock() -> void:
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
		_moon.light_energy = 0.11 * (1.0 - day)
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
	# Keep the dream's snow moving, but leave enough air between the flakes to
	# read Mathilda, the path and the landmarks through the storm.
	var veil_scale := 0.2 if Game.dream_mode else 1.0
	mat.set_shader_parameter("base_density", base_d * snow_cover * veil_scale)
	mat.set_shader_parameter("squall_density", squall_d * snow_cover * veil_scale)
	mat.set_shader_parameter("spindrift_density", spindrift_d * snow_cover * veil_scale)
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


func _ensure_dream_sky() -> void:
	if _dream_sky != null:
		return
	var sky_mat := ShaderMaterial.new()
	if ResourceLoader.exists(DREAM_UNIVERSE_SKY_SHADER):
		sky_mat.shader = load(DREAM_UNIVERSE_SKY_SHADER) as Shader
	_dream_sky = Sky.new()
	_dream_sky.sky_material = sky_mat
	_dream_sky.process_mode = Sky.PROCESS_MODE_REALTIME


func _ensure_weather_sky() -> void:
	if _weather_sky != null:
		return
	_weather_sky_material = ShaderMaterial.new()
	if ResourceLoader.exists(WINTER_SKY_SHADER):
		_weather_sky_material.shader = load(WINTER_SKY_SHADER) as Shader
	_weather_sky = Sky.new()
	_weather_sky.sky_material = _weather_sky_material
	_weather_sky.process_mode = Sky.PROCESS_MODE_REALTIME


func _update_weather_sky(intensity: float, gust: float, whiteout: float) -> void:
	if _weather_sky_material == null or _weather_sky_material.shader == null:
		return
	var storm := clampf(intensity * 0.58 + gust * 0.18 + whiteout * 0.78, 0.0, 1.0)
	var clear_top := Color(0.28, 0.47, 0.70)
	var squall_top := Color(0.50, 0.61, 0.72)
	var whiteout_top := Color(0.72, 0.79, 0.86)
	var clear_horizon := Color(0.82, 0.85, 0.84)
	var squall_horizon := Color(0.74, 0.79, 0.84)
	var sky_top := clear_top.lerp(squall_top, clampf(storm * 0.8, 0.0, 1.0)).lerp(whiteout_top, whiteout * 0.65)
	var sky_horizon := clear_horizon.lerp(squall_horizon, storm).lerp(Color(0.87, 0.89, 0.91), whiteout)
	var dusk := 0.0
	var day := 1.0
	if clock_running:
		var elevation := sun_elevation()
		var low := 1.0 - smoothstep(1.0, 18.0, elevation)
		dusk = low * smoothstep(-7.0, 2.0, elevation)
		day = daylight()
		sky_horizon = sky_horizon.lerp(Color(0.96, 0.57, 0.36), dusk * 0.42)
		sky_top = sky_top.lerp(Color(0.35, 0.48, 0.67), dusk * 0.28)
	_weather_sky_material.set_shader_parameter("sky_color", sky_top)
	_weather_sky_material.set_shader_parameter("horizon_color", sky_horizon)
	_weather_sky_material.set_shader_parameter("cloud_light_color", Color(0.98, 0.96, 0.89).lerp(Color(0.87, 0.90, 0.94), storm))
	_weather_sky_material.set_shader_parameter("cloud_shadow_color", Color(0.46, 0.53, 0.62).lerp(Color(0.37, 0.44, 0.54), storm))
	_cloud_coverage = clampf(0.20 + intensity * 0.42 + gust * 0.17 + whiteout * 0.34, 0.08, 0.96)
	_cloud_opacity = lerpf(0.68, 0.94, storm)
	_weather_sky_material.set_shader_parameter("cloud_coverage", _cloud_coverage)
	_weather_sky_material.set_shader_parameter("cloud_opacity", _cloud_opacity)
	_weather_sky_material.set_shader_parameter("cloud_offset", _cloud_offset)
	_weather_sky_material.set_shader_parameter("sun_warmth", maxf(dusk, 0.14 if not clock_running else 0.0))
	_weather_sky_material.set_shader_parameter("daylight_amount", day)
	if _sun:
		var sun_direction := _sun.global_basis.z.normalized()
		_weather_sky_material.set_shader_parameter("sun_direction", sun_direction)
		_weather_sky_material.set_shader_parameter("sun_light_color", _sun.light_color)
		_weather_sky_material.set_shader_parameter("sun_energy", _sun.light_energy)
	_update_weather_sun_projection()


func _update_weather_sun_projection() -> void:
	if _weather_sky_material == null or _sun == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_weather_sky_material.set_shader_parameter("sun_screen_visible", 0.0)
		return
	_weather_sky_material.set_shader_parameter("cloud_origin", Vector2(camera.global_position.x, camera.global_position.z) * 0.0012)
	var sun_direction := _sun.global_basis.z.normalized()
	var sun_target := camera.global_position + sun_direction * 1000.0
	var screen_size := get_viewport().get_visible_rect().size
	var sun_screen := camera.unproject_position(sun_target)
	var radius_uv := tan(deg_to_rad(maxf(_sun.light_angular_distance, 0.53)) * 0.5) / tan(deg_to_rad(camera.fov) * 0.5) * 0.5
	_weather_sky_material.set_shader_parameter("sun_screen_uv", sun_screen / screen_size)
	_weather_sky_material.set_shader_parameter("sun_screen_radius", maxf(radius_uv, 0.004))
	_weather_sky_material.set_shader_parameter("screen_aspect", screen_size.x / maxf(screen_size.y, 1.0))
	_weather_sky_material.set_shader_parameter("sun_screen_visible", 0.0 if camera.is_position_behind(sun_target) else 1.0)


# Approximate the sky's cloud field at the sun's direction. The
# directional light then brightens the ground only when an opening passes over
# the camera, and cloud banks can actually hide the sun instead of leaving a
# permanent circular hole in them.
func _update_cloud_light() -> void:
	if _sun == null or _weather_sky_material == null:
		return
	if Game.dream_mode or Game.phase == Game.Phase.DREAM:
		_sun.light_energy = _sun_clear_energy
		_sun.light_volumetric_fog_energy = _sun_clear_fog_energy
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var view_dir := _sun.global_basis.z.normalized()
	var cloud_uv := Vector2(view_dir.x, view_dir.z) / maxf(view_dir.y + 0.20, 0.24)
	cloud_uv += Vector2(camera.global_position.x, camera.global_position.z) * 0.0012
	var warp_at := cloud_uv * 1.15 + _cloud_offset * 0.42
	var warp := Vector2(
		_cloud_noise2(warp_at + Vector2(4.2, -8.1)),
		_cloud_noise2(warp_at + Vector2(-7.4, 3.6))
	) - Vector2(0.5, 0.5)
	var shape_uv := cloud_uv + warp * 0.46
	var broad := _cloud_fbm(shape_uv * 2.05 + _cloud_offset)
	var detail := _cloud_fbm(shape_uv * 4.3 - _cloud_offset * 1.65 + Vector2(13.7, -9.2))
	var wisps := _cloud_noise2(shape_uv * Vector2(5.8, 1.65) + _cloud_offset * 0.6)
	var shape := broad * 0.67 + detail * 0.23 + wisps * 0.10
	var threshold := lerpf(0.72, 0.30, _cloud_coverage)
	var opacity := smoothstep(threshold - 0.20, threshold + 0.25, shape)
	opacity *= smoothstep(-0.12, 0.10, view_dir.y) * _cloud_opacity
	var transmission := 1.0 - opacity
	_sun.light_energy = _sun_clear_energy * lerpf(0.12, 1.0, transmission)
	_sun.light_volumetric_fog_energy = _sun_clear_fog_energy * lerpf(0.08, 1.0, transmission)


func _cloud_hash(p: Vector2) -> float:
	var value := sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453
	return value - floorf(value)


func _cloud_noise2(p: Vector2) -> float:
	var cell := Vector2(floorf(p.x), floorf(p.y))
	var fraction := p - cell
	fraction = fraction * fraction * (Vector2(3.0, 3.0) - fraction * 2.0)
	var bottom := lerpf(_cloud_hash(cell), _cloud_hash(cell + Vector2.RIGHT), fraction.x)
	var top := lerpf(_cloud_hash(cell + Vector2.DOWN), _cloud_hash(cell + Vector2.ONE), fraction.x)
	return lerpf(bottom, top, fraction.y)


func _cloud_fbm(p: Vector2) -> float:
	var value := 0.0
	var weight := 0.56
	for i in 4:
		value += _cloud_noise2(p) * weight
		p = Vector2(0.80 * p.x + 0.60 * p.y, -0.60 * p.x + 0.80 * p.y) * 2.03 + Vector2(7.1, 3.7)
		weight *= 0.5
	return value

