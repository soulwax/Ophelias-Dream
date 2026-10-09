class_name Weather
extends Node3D

const TEX := "res://assets/weather/"

enum Regime {
	CLEARING,
	DRIFT,
	SQUALL,
	WHITEOUT,
}

var regime: Regime = Regime.DRIFT
var intensity := 0.52
var gust := 0.25
var whiteout := 0.0
var flurry := 0.55
var wind := Vector3(8.0, 0.0, 3.0)
var wind_scroll := Vector3.ZERO
var shelter := 0.0
# 0..1, smoothed: how much snow falls here. Over green land (Ground.snow_at
# under the camera) the snowfall thins away; the wind keeps blowing.
var snow_scale := 1.0
var dream_quiet := 0.0

var _heading := 0.72
var _heading_target := 0.72
var _gust_target := 0.28
var _intensity_target := 0.52
var _whiteout_target := 0.0
var _flurry_target := 0.55
var _regime_clock := 14.0
var _pulse_clock := 4.2
var _clock := 0.0
var _pinned_regime := false
var _layers: Array[SnowLayer] = []
var _audio: StormAudio
var _atmosphere: Atmosphere
var _local_volume: FogVolume


func _ready() -> void:
	Game.weather = self
	# It follows the camera every frame, outside the physics tick.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_audio = StormAudio.new()
	add_child(_audio)
	_build_layers()
	for child in get_parent().get_children():
		if child is Atmosphere:
			_atmosphere = child as Atmosphere
			break
	if not Game.lean_graphics and _atmosphere:
		_local_volume = FogVolume.new()
		_local_volume.name = "SquallVolume"
		_local_volume.size = Vector3(96.0, 28.0, 96.0)
		_local_volume.position = Vector3(0.0, 6.0, 0.0)
		add_child(_local_volume)
		_atmosphere.bind_local_volume(_local_volume)
	_apply_env_override()
	settle()


func _apply_env_override() -> void:
	var forced := OS.get_environment("RUN_WEATHER").strip_edges().to_lower()
	if forced == "":
		return
	_pinned_regime = true
	match forced:
		"clearing", "calm":
			set_regime(Regime.CLEARING, true)
		"drift", "snow":
			set_regime(Regime.DRIFT, true)
		"squall", "storm":
			set_regime(Regime.SQUALL, true)
		"whiteout", "blizzard":
			set_regime(Regime.WHITEOUT, true)
		_:
			_pinned_regime = false


func regime_name() -> String:
	match regime:
		Regime.CLEARING:
			return "Clearing"
		Regime.DRIFT:
			return "Snow Drift"
		Regime.SQUALL:
			return "Heavy Squall"
		Regime.WHITEOUT:
			return "Whiteout"
	return "Snow Drift"


func cycle_regime() -> void:
	_pinned_regime = true
	var next := ((int(regime) + 1) % 4) as Regime
	set_regime(next, false)


func set_dream_quiet(amount: float) -> void:
	dream_quiet = clampf(amount, 0.0, 1.0) if Game.dream_mode else 0.0


func set_regime(next: Regime, immediate: bool = false) -> void:
	regime = next
	match regime:
		Regime.CLEARING:
			_intensity_target = randf_range(0.18, 0.28)
			_gust_target = randf_range(0.06, 0.18)
			_whiteout_target = 0.0
			_flurry_target = randf_range(0.32, 0.48)
			_regime_clock = randf_range(11.0, 17.0)
		Regime.DRIFT:
			_intensity_target = randf_range(0.46, 0.62)
			_gust_target = randf_range(0.28, 0.52)
			_whiteout_target = randf_range(0.04, 0.16)
			_flurry_target = randf_range(0.55, 0.78)
			_regime_clock = randf_range(14.0, 23.0)
		Regime.SQUALL:
			_intensity_target = randf_range(0.76, 0.90)
			_gust_target = randf_range(0.68, 0.92)
			_whiteout_target = randf_range(0.35, 0.58)
			_flurry_target = randf_range(0.82, 0.98)
			_regime_clock = randf_range(13.0, 21.0)
		Regime.WHITEOUT:
			_intensity_target = randf_range(0.92, 1.0)
			_gust_target = randf_range(0.86, 1.0)
			_whiteout_target = randf_range(0.82, 0.96)
			_flurry_target = 1.0
			_regime_clock = randf_range(10.0, 16.0)
	# The dream can turn the forest strange without erasing it. Keep its storm
	# readable even when a debug override or a transition requests a whiteout.
	if Game.dream_mode:
		_intensity_target = minf(_intensity_target, 0.68)
		_gust_target = minf(_gust_target, 0.62)
		_whiteout_target = minf(_whiteout_target, 0.18)
	_heading_target += randf_range(-0.48, 0.48)
	if immediate:
		intensity = _intensity_target
		gust = _gust_target
		whiteout = _whiteout_target
		flurry = _flurry_target
		_heading = _heading_target
		var speed := lerpf(3.8, 12.6, clampf(intensity * 0.68 + gust * 0.32, 0.0, 1.0))
		wind = Vector3(cos(_heading), 0.0, sin(_heading)) * speed


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F6:
		cycle_regime()


func _is_inside() -> bool:
	var listener := get_viewport().get_audio_listener_3d()
	if listener:
		return Game.indoors(listener.global_position)
	var camera := get_viewport().get_camera_3d()
	if camera:
		return Game.indoors(camera.global_position)
	return Game.player != null and Game.player.indoors()


func _ground_focus_y() -> float:
	if Game.player:
		return Game.player.global_position.y
	return global_position.y - 1.6


func settle() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position
	elif Game.player:
		global_position = Game.player.global_position
	var inside := _is_inside()
	shelter = 1.0 if inside else 0.0
	snow_scale = _snow_here()
	for layer in _layers:
		layer.apply(intensity, wind, gust, whiteout, flurry)
		layer.amount_ratio *= snow_scale
		if inside:
			layer.amount_ratio = 0.0
	if _atmosphere:
		_atmosphere.shelter = shelter
		_atmosphere.snow_cover = snow_scale
		_atmosphere.apply_weather(intensity, gust, whiteout, flurry, wind, wind_scroll, _ground_focus_y())
	if _audio:
		_audio.apply(intensity, gust, wind, shelter, whiteout, dream_quiet if Game.dream_mode else 0.0)


func _process(delta: float) -> void:
	_advance(delta)
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position
	var inside := _is_inside()
	snow_scale = move_toward(snow_scale, _snow_here(), delta * 0.6)
	for layer in _layers:
		layer.apply(intensity, wind, gust, whiteout, flurry)
		layer.amount_ratio *= snow_scale
		# No snow falls indoors; the storm is only heard through the walls.
		if inside:
			layer.amount_ratio = 0.0
	# Stepping through a door, the light changes over a breath, not a frame.
	shelter = move_toward(shelter, 1.0 if inside else 0.0, delta * 1.4)
	if _atmosphere:
		_atmosphere.shelter = shelter
		_atmosphere.snow_cover = snow_scale
		_atmosphere.apply_weather(intensity, gust, whiteout, flurry, wind, wind_scroll, _ground_focus_y())
	if _audio:
		_audio.apply(intensity, gust, wind, shelter, whiteout, dream_quiet if Game.dream_mode else 0.0)


# The snow weight under the camera: snow falls where the snow lies.
func _snow_here() -> float:
	if Game.trail == null or Game.trail.ground == null:
		return 1.0
	return clampf(Game.trail.ground.snow_at(global_position.x, global_position.z) * 1.25 - 0.1, 0.0, 1.0)


func _advance(delta: float) -> void:
	_clock += delta
	if not _pinned_regime:
		_regime_clock -= delta
		if _regime_clock <= 0.0:
			_pick_next_regime()

	_pulse_clock -= delta
	if _pulse_clock <= 0.0:
		_pulse_clock = randf_range(3.2, 6.8)
		match regime:
			Regime.CLEARING:
				_gust_target = randf_range(0.05, 0.24)
				_flurry_target = randf_range(0.28, 0.52)
			Regime.DRIFT:
				_gust_target = randf_range(0.24, 0.64)
				_flurry_target = randf_range(0.48, 0.84)
			Regime.SQUALL:
				_gust_target = randf_range(0.62, 0.96)
				_flurry_target = randf_range(0.76, 1.0)
			Regime.WHITEOUT:
				_gust_target = randf_range(0.84, 1.0)
				_flurry_target = randf_range(0.92, 1.0)
		_heading_target += randf_range(-0.24, 0.24)

	var wave := sin(_clock * 0.47) * 0.05 + sin(_clock * 1.13) * 0.035
	intensity = move_toward(intensity, clampf(_intensity_target + wave * 0.5, 0.12, 1.0), delta * 0.14)
	gust = move_toward(gust, clampf(_gust_target + wave, 0.0, 1.0), delta * 0.26)
	whiteout = move_toward(whiteout, _whiteout_target, delta * 0.12)
	flurry = move_toward(flurry, _flurry_target, delta * 0.22)
	_heading = lerpf(_heading, _heading_target, 1.0 - exp(-delta * 0.45))

	var speed := lerpf(3.8, 12.6, clampf(intensity * 0.68 + gust * 0.32, 0.0, 1.0))
	wind = Vector3(cos(_heading), 0.0, sin(_heading)) * speed
	wind_scroll += Vector3(wind.x, -lerpf(1.2, 2.8, intensity), wind.z) * delta


func _pick_next_regime() -> void:
	if Game.dream_mode:
		var dream_roll := randf()
		var dream_next := Regime.DRIFT
		match regime:
			Regime.CLEARING:
				dream_next = Regime.DRIFT if dream_roll < 0.78 else Regime.SQUALL
			Regime.DRIFT:
				dream_next = Regime.CLEARING if dream_roll < 0.34 else Regime.SQUALL
			_:
				dream_next = Regime.DRIFT if dream_roll < 0.72 else Regime.CLEARING
		set_regime(dream_next, false)
		return
	var pressure := clampf(Game.threat() + (0.25 if Game.hunt_started else 0.0), 0.0, 1.0)
	var roll := randf()
	var next := Regime.DRIFT
	if regime == Regime.WHITEOUT:
		# Follow a blinding whiteout with either a clearing lull or a drifting tail.
		next = Regime.CLEARING if roll < 0.42 else Regime.DRIFT
	elif regime == Regime.CLEARING:
		next = Regime.DRIFT if roll < (0.62 - pressure * 0.22) else Regime.SQUALL
	elif regime == Regime.DRIFT:
		if roll < 0.22 - pressure * 0.10:
			next = Regime.CLEARING
		elif roll < 0.76 - pressure * 0.15:
			next = Regime.SQUALL
		else:
			next = Regime.WHITEOUT
	else:
		# From SQUALL, either escalate into a full whiteout or ease into drift/clearing.
		if roll < 0.34 + pressure * 0.24:
			next = Regime.WHITEOUT
		elif roll < 0.78:
			next = Regime.DRIFT
		else:
			next = Regime.CLEARING
	set_regime(next, false)


func _build_layers() -> void:
	# 1. CanopyFlakes: broad, steady snowfall filling the surrounding tree line.
	var canopy := SnowLayer.new()
	canopy.name = "CanopyFlakes"
	canopy.position = Vector3(0, 5.8, 0)
	canopy.fall = 2.35
	canopy.wind_scale = 0.58
	canopy.spread_calm = 24.0
	canopy.spread_storm = 11.0
	canopy.setup(TEX + "flake.png", 3200, 5.0, Vector3(24, 9, 24), 0.85, 1.65, Vector2(0.24, 0.24), Color(0.95, 0.97, 1.0, 0.88))
	add_child(canopy)
	_layers.append(canopy)

	# 2. NearFlurries: detailed close-up flakes swirling around the player and camera.
	var near := SnowLayer.new()
	near.name = "NearFlurries"
	near.position = Vector3(0, 3.0, 0)
	near.fall = 1.85
	near.wind_scale = 0.48
	near.spread_calm = 28.0
	near.spread_storm = 14.0
	near.setup(TEX + "flake.png", 1400, 3.4, Vector3(11, 5.5, 11), 0.8, 1.55, Vector2(0.18, 0.18), Color(0.98, 0.99, 1.0, 0.94))
	add_child(near)
	_layers.append(near)

	# 3. DiamondDust: fine glittering ice prisms that catch sunlight during clearings and drifts.
	var dust := SnowLayer.new()
	dust.name = "DiamondDust"
	dust.position = Vector3(0, 2.5, 0)
	dust.fall = 0.68
	dust.wind_scale = 0.28
	dust.spread_calm = 42.0
	dust.spread_storm = 22.0
	dust.glitter_mode = true
	dust.setup(TEX + "flake.png", 800, 4.2, Vector3(12, 5.0, 12), 0.55, 1.15, Vector2(0.11, 0.11), Color(1.0, 0.99, 0.96, 0.82))
	add_child(dust)
	_layers.append(dust)

	# 4. GaleStreaks: fast, velocity-aligned snow needles whipping past during squalls and gusts.
	var streaks := SnowLayer.new()
	streaks.name = "GaleStreaks"
	streaks.position = Vector3(0, 3.8, 0)
	streaks.fall = 1.65
	streaks.wind_scale = 1.15
	streaks.spread_calm = 12.0
	streaks.spread_storm = 5.0
	streaks.gust_only = true
	streaks.setup(TEX + "streak.png", 1200, 2.0, Vector3(18, 7, 18), 0.85, 1.55, Vector2(0.08, 0.44), Color(0.94, 0.97, 1.0, 0.72))
	streaks.align_to_velocity()
	add_child(streaks)
	_layers.append(streaks)

	# 5. GroundSpindrift: low, billowing snow ribbons skimming across the snowpack.
	var spindrift := SnowLayer.new()
	spindrift.name = "GroundSpindrift"
	spindrift.position = Vector3(0, -0.75, 0)
	spindrift.fall = 0.12
	spindrift.wind_scale = 0.92
	spindrift.spread_calm = 16.0
	spindrift.spread_storm = 7.5
	spindrift.spindrift_mode = true
	spindrift.setup_spindrift(TEX + "flake.png", 180, 2.8, Vector3(22, 1.1, 22), 0.85, 1.55, Vector2(3.6, 1.15), Color(0.92, 0.95, 0.99, 0.24), 1.35, 1.12)
	add_child(spindrift)
	_layers.append(spindrift)

	# 6. SquallVeil: mid-air drifting snow curtains that thicken the air during squalls and whiteouts.
	var veil := SnowLayer.new()
	veil.name = "SquallVeil"
	veil.position = Vector3(0, 2.4, 0)
	veil.fall = 0.55
	veil.wind_scale = 0.76
	veil.spread_calm = 20.0
	veil.spread_storm = 9.0
	veil.veil_mode = true
	veil.setup_spindrift(TEX + "flake.png", 110, 3.4, Vector3(24, 5.0, 24), 0.9, 1.75, Vector2(4.8, 2.2), Color(0.90, 0.94, 0.98, 0.18), 1.45, 1.02)
	add_child(veil)
	_layers.append(veil)
