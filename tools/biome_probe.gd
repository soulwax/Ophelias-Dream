extends Node

# Builds the real level and checks the biome world: snow wherever the story
# happens, a mostly snowy core, green beyond it (greener NE and NW than SW),
# thaw bands 30-60 m wide, a walkable route, seamless chunks, an edge she
# cannot pass, and the ground built within its budget. Exits 1 on any failure.
#   godot-mono --headless --path . tools/biome_probe.tscn
#   (RUN_GRAPHICS=full for the full forest)

const GROUND_BUDGET_MSEC := 3500

var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.get_node("EditableLevel").set_meta("seed", 1701)
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var trail := Game.trail
	if trail == null or trail.ground == null:
		_check(false, "the scene built the trail and its ground")
		_finish()
		return
	var ground := trail.ground
	_check(ground.build_msec < GROUND_BUDGET_MSEC, "the ground builds in %d ms (budget %d)" % [ground.build_msec, GROUND_BUDGET_MSEC])
	_story_on_snow(trail, ground)
	_core(ground)
	_green_beyond(ground)
	_thaw_width(ground)
	_normal_width(ground, true)
	await _seed_coverage(trail)
	_seams(ground)
	await _edge(ground)
	_finish()


# Each seed retains story snow. Additional worlds can legitimately have fewer
# outbound crossings; report their coverage without applying the default gate.
func _seed_coverage(trail: Trail) -> void:
	for seed_number in [7919, 314159]:
		var ground := Ground.new()
		ground.seed_value = seed_number
		ground.route = trail.curve
		ground.route_from = trail.player_start_offset
		ground.route_to = trail.exit_offset
		ground.story_points = trail.ground.story_points
		ground.pads = trail.ground.pads
		ground.cuts = trail.ground.cuts
		add_child(ground)
		_story_on_snow(trail, ground)
		_normal_width(ground, false)
		print("  seed %d build %d ms" % [seed_number, ground.build_msec])
		ground.queue_free()
		await get_tree().process_frame


# Discover S=0.5 boundaries independently on a grid, then march in the local
# snow-gradient normal. Threshold brackets are interpolated within <=1 m steps;
# these widths are horizontal world metres, not oblique radial-ray spans.
func _normal_width(ground: Ground, required: bool) -> void:
	var widths: Array[String] = []
	var boundaries := PackedVector2Array()
	var good := 0
	var x := Tune.WORLD_MIN_X + 60.0
	while x < Tune.WORLD_MAX_X - 60.0:
		var z := Tune.WORLD_MIN_Z + 60.0
		while z < Tune.WORLD_MAX_Z - 60.0:
			var a := Vector2(x, z)
			var b := a + Vector2(12.0, 0.0)
			var sa := ground.snow_at(a.x, a.y)
			var sb := ground.snow_at(b.x, b.y)
			if (sa - 0.5) * (sb - 0.5) < 0.0:
				var left := a
				var right := b
				for iteration in 10:
					var middle := (left + right) * 0.5
					if (ground.snow_at(middle.x, middle.y) - 0.5) * (sa - 0.5) > 0.0:
						left = middle
					else:
						right = middle
				var edge := (left + right) * 0.5
				var separate := true
				for other in boundaries:
					if edge.distance_to(other) < 30.0:
						separate = false
						break
				if separate:
					var gradient := Vector2(ground.snow_at(edge.x + 0.5, edge.y) - ground.snow_at(edge.x - 0.5, edge.y), ground.snow_at(edge.x, edge.y + 0.5) - ground.snow_at(edge.x, edge.y - 0.5))
					if gradient.length() > 0.0001:
						var normal := gradient.normalized()
						var high := _threshold_distance(ground, edge, normal, 0.8)
						var low := _threshold_distance(ground, edge, -normal, 0.2)
						if high >= 0.0 and low >= 0.0:
							boundaries.append(edge)
							var width := high + low
							widths.append("%.1f" % width)
							if width >= 30.0 and width <= 60.0:
								good += 1
			z += 12.0
		x += 12.0
	var label := "seed %d normal thaw widths %d/%d in 30-60 m: %s" % [ground.seed_value, good, widths.size(), ", ".join(widths)]
	if required:
		_check(widths.size() >= 8, "seed %d has at least 8 valid normal crossings (%d)" % [ground.seed_value, widths.size()])
		_check(good >= int(ceil(widths.size() * 0.75)), label)
	else:
		print("  observe " + label)


func _threshold_distance(ground: Ground, edge: Vector2, direction: Vector2, target: float) -> float:
	var previous := ground.snow_at(edge.x, edge.y)
	for metre in range(1, 121):
		var at := edge + direction * float(metre)
		if at.x < Tune.WORLD_MIN_X + 1.0 or at.x > Tune.WORLD_MAX_X - 1.0 or at.y < Tune.WORLD_MIN_Z + 1.0 or at.y > Tune.WORLD_MAX_Z - 1.0:
			return -1.0
		var value := ground.snow_at(at.x, at.y)
		if (target > 0.5 and value >= target) or (target < 0.5 and value <= target):
			return float(metre - 1) + (target - previous) / (value - previous)
		previous = value
	return -1.0


# Every place the story happens lies on snow.
func _story_on_snow(trail: Trail, ground: Ground) -> void:
	var lowest := 1.0
	var where := ""
	var offset := trail.player_start_offset
	while offset <= trail.exit_offset:
		var at := trail.position_at(offset)
		var s := ground.snow_at(at.x, at.z)
		if s < lowest:
			lowest = s
			where = "route %.0f m" % (offset - trail.player_start_offset)
		offset += 2.0
	for point in ground.story_points:
		var s := ground.snow_at(point.x, point.z)
		if s < lowest:
			lowest = s
			where = "story point %s" % point
	_check(lowest >= 0.95, "the story is on snow everywhere (lowest %.2f at %s)" % [lowest, where])


func _core(ground: Ground) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var snowy := 0
	var total := 0
	while total < 600:
		var at := Vector3(rng.randf_range(Tune.WORLD_MIN_X, Tune.WORLD_MAX_X), 0.0, rng.randf_range(Tune.WORLD_MIN_Z, Tune.WORLD_MAX_Z))
		if ground.story_distance(at.x, at.z) > Tune.SNOW_CORE_IN:
			continue
		total += 1
		if ground.snow_at(at.x, at.z) > 0.8:
			snowy += 1
	var share := float(snowy) / float(total)
	_check(share >= 0.85, "the core is mostly snow (%.0f%% of points within %d m)" % [share * 100.0, int(Tune.SNOW_CORE_IN)])


# Beyond the core: green exists, more of it north-east and north-west than south-west.
func _green_beyond(ground: Ground) -> void:
	var centre := ground.story_centre
	var green := {"NE": 0.0, "NW": 0.0, "SE": 0.0, "SW": 0.0}
	var count := {"NE": 0, "NW": 0, "SE": 0, "SW": 0}
	var step := 12.0
	var x := Tune.WORLD_MIN_X + 100.0
	while x < Tune.WORLD_MAX_X - 100.0:
		var z := Tune.WORLD_MIN_Z + 100.0
		while z < Tune.WORLD_MAX_Z - 100.0:
			if ground.story_distance(x, z) > Tune.SNOW_CORE_OUT + 20.0:
				# North is -Z.
				var quadrant := ("N" if z < centre.z else "S") + ("E" if x > centre.x else "W")
				green[quadrant] += 1.0 - ground.snow_at(x, z)
				count[quadrant] += 1
			z += step
		x += step
	var total_green := 0.0
	for key: String in green:
		if count[key] > 0:
			green[key] /= float(count[key])
		total_green += float(green[key])
	_check(total_green > 0.4, "green land exists beyond the core (NE %.2f NW %.2f SE %.2f SW %.2f)" % [green.NE, green.NW, green.SE, green.SW])
	_check(green.NE > green.SW and green.NW > green.SW, "north-east and north-west are greener than south-west")


# Rays from the story outward: where snow gives way to green beyond the core,
# the change from 0.8 to 0.2 takes 30-60 m.
func _thaw_width(ground: Ground) -> void:
	var centre := ground.story_centre
	var crossed := 0
	var good := 0
	var widths: Array[String] = []
	for ray in 16:
		var direction := Vector2.from_angle(TAU * float(ray) / 16.0)
		var step := 1.0
		var distance := 0.0
		var high_at := -1.0
		while distance < 700.0:
			distance += step
			var at := Vector2(centre.x, centre.z) + direction * distance
			if at.x < Tune.WORLD_MIN_X + 60.0 or at.x > Tune.WORLD_MAX_X - 60.0 or at.y < Tune.WORLD_MIN_Z + 60.0 or at.y > Tune.WORLD_MAX_Z - 60.0:
				break
			var s := ground.snow_at(at.x, at.y)
			if s >= 0.8:
				high_at = distance
			elif s <= 0.2 and high_at > 0.0 and ground.story_distance(at.x, at.y) > Tune.SNOW_CORE_IN:
				crossed += 1
				var width := distance - high_at
				widths.append("%.0f" % width)
				if width >= 30.0 and width <= 60.0:
					good += 1
				break
	_check(crossed >= 8, "at least 8 of 16 rays cross a snow edge (%d)" % crossed)
	_check(good >= int(ceil(crossed * 0.75)), "thaw bands are 30-60 m wide (%d of %d: %s)" % [good, crossed, ", ".join(widths)])


# Chunks meet without a step: just either side of a chunk border, the ground
# is at the same height.
func _seams(ground: Ground) -> void:
	var worst := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		var border_x := Tune.WORLD_MIN_X + float(rng.randi_range(1, ground.chunks_x - 1)) * Tune.CHUNK_SIZE
		var z := rng.randf_range(Tune.WORLD_MIN_Z + 20.0, Tune.WORLD_MAX_Z - 20.0)
		worst = maxf(worst, absf(ground.height_at(border_x - 0.001, z) - ground.height_at(border_x + 0.001, z)))
		var border_z := Tune.WORLD_MIN_Z + float(rng.randi_range(1, ground.chunks_z - 1)) * Tune.CHUNK_SIZE
		var x := rng.randf_range(Tune.WORLD_MIN_X + 20.0, Tune.WORLD_MAX_X - 20.0)
		worst = maxf(worst, absf(ground.height_at(x, border_z - 0.001) - ground.height_at(x, border_z + 0.001)))
	_check(worst < 0.01, "chunks meet without a step (worst %.3f m)" % worst)


# Something walking outward is stopped before the world's edge.
func _edge(ground: Ground) -> void:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.55
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	body.add_child(shape)
	body.collision_mask = Tune.LAYER_WORLD
	get_tree().root.add_child(body)
	var start := Vector3(Tune.WORLD_MAX_X - 40.0, 0.0, ground.story_centre.z)
	body.global_position = Vector3(start.x, ground.height_at(start.x, start.z) + 0.5, start.z)
	for i in 400:
		body.velocity = Vector3(12.0, -20.0, 0.0)
		body.move_and_slide()
		await get_tree().physics_frame
	_check(body.global_position.x < Tune.WORLD_MAX_X - 1.0, "the edge stops her (reached x %.1f, edge %.0f)" % [body.global_position.x, Tune.WORLD_MAX_X])
	body.queue_free()


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1


func _finish() -> void:
	print("Biome probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)
