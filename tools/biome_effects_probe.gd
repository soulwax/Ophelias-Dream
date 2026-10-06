extends Node

# Footsteps, prints and snowfall follow the snow weight: grass on green, thaw
# on the band, snow on snow; prints only where it is really snow; the falling
# snow fades out over green and comes back over snow, and the wind keeps blowing.
#   godot-mono --headless --path . tools/biome_effects_probe.tscn

var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	var player := Game.player
	var trail := Game.trail
	var ground := trail.ground if trail else null
	if player == null or ground == null or Game.weather == null:
		_check(false, "the scene built the player, ground and weather")
		_finish()
		return
	Game.set_phase(Game.Phase.PLAYING)
	var on_route := trail.position_at(trail.player_start_offset + 60.0)
	var green := _find(ground, 0.0, 0.15)
	var thaw := _find(ground, 0.42, 0.58)
	_check(green != Vector3.INF, "the world has green land (%s)" % green)
	_check(thaw != Vector3.INF, "the world has a thaw band (%s)" % thaw)
	if green == Vector3.INF or thaw == Vector3.INF:
		_finish()
		return
	# The surface is judged where she stands (indoors or not), so stand there.
	_place(player, on_route)
	await get_tree().physics_frame
	_check(player._surface_at(_on(ground, on_route)) == "snow", "on the route she walks on snow")
	_place(player, green)
	await get_tree().physics_frame
	_check(player._surface_at(_on(ground, green)) == "grass", "on green land she walks on grass (%s)" % player._surface_at(_on(ground, green)))
	_place(player, thaw)
	await get_tree().physics_frame
	_check(player._surface_at(_on(ground, thaw)) == "thaw", "in the thaw band she walks on thaw (%s)" % player._surface_at(_on(ground, thaw)))
	_check(player._leaves_prints(_on(ground, on_route), "snow"), "snow takes her prints")
	_check(not player._leaves_prints(_on(ground, green), "grass"), "grass takes no prints")
	_check(player._leaves_prints(_on(ground, thaw), "thaw") == (ground.snow_at(thaw.x, thaw.z) > 0.6), "thaw takes prints only above S 0.6")
	_check(Game.soundscape.SURFACES.has("grass") and Game.soundscape.SURFACES.has("thaw"), "the soundscape knows grass and thaw")
	_check((Game.soundscape._sets.get("grass", []) as Array).size() >= 3, "grass has its own recorded steps (%d)" % (Game.soundscape._sets.get("grass", []) as Array).size())
	_check(Game.soundscape.SURFACES["thaw"] < Game.soundscape.SURFACES["snow"] - 3.0, "thaw steps are about 4 dB quieter than snow")

	# Snowfall: over green it fades out, over snow it comes back; wind stays.
	_place(player, green)
	await get_tree().create_timer(3.0).timeout
	var weather := Game.weather
	_check(weather.snow_scale < 0.1, "over green the snow stops falling (scale %.2f)" % weather.snow_scale)
	var loudest := 0.0
	for layer in weather._layers:
		loudest = maxf(loudest, layer.amount_ratio)
	_check(loudest < 0.1, "every snow layer thins over green (%.2f)" % loudest)
	_check(weather.wind.length() > 0.1, "the wind still blows over green")
	_check(weather._atmosphere == null or weather._atmosphere.snow_cover < 0.1, "the snow veil thins over green")
	_place(player, on_route)
	await get_tree().create_timer(3.0).timeout
	_check(weather.snow_scale > 0.9, "over snow it falls again (scale %.2f)" % weather.snow_scale)
	_finish()


# A point whose snow weight lies in [lo, hi], searched outward from the story.
func _find(ground: Ground, lo: float, hi: float) -> Vector3:
	for ring in range(260, 520, 20):
		for step in 48:
			var angle := TAU * float(step) / 48.0
			var x := ground.story_centre.x + cos(angle) * float(ring)
			var z := ground.story_centre.z + sin(angle) * float(ring)
			if x < Tune.WORLD_MIN_X + Tune.RING_WIDTH or x > Tune.WORLD_MAX_X - Tune.RING_WIDTH or z < Tune.WORLD_MIN_Z + Tune.RING_WIDTH or z > Tune.WORLD_MAX_Z - Tune.RING_WIDTH:
				continue
			var s := ground.snow_at(x, z)
			if s >= lo and s <= hi and ground.slope_at(x, z) < 25.0:
				return Vector3(x, 0.0, z)
	return Vector3.INF


func _on(ground: Ground, at: Vector3) -> Vector3:
	return Vector3(at.x, ground.height_at(at.x, at.z), at.z)


func _place(player: Player, at: Vector3) -> void:
	player.global_position = _on(Game.trail.ground, at) + Vector3.UP * 0.4
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1


func _finish() -> void:
	print("Biome effects probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)
