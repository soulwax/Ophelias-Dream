extends Node

# Builds the real level and checks the land: the route walkable start to exit,
# no cliffs beside it except the ravine's walls, the ravine itself, cliffs that
# exist, a flat house pad, and the ground built within its time budget.
# Exits 1 on any failure.
#   godot-mono --headless --path . tools/terrain_probe.tscn
#   (RUN_GRAPHICS=full for the full forest)

const BUILD_BUDGET_MSEC := 3500

var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var trail := Game.trail
	if trail == null or trail.ground == null:
		_check(false, "the scene built the trail and its ground")
		_finish()
		return
	var ground := trail.ground
	_check(int(ground.get_meta("terrain_revision", 0)) == Ground.TERRAIN_REVISION, "the ground carries terrain revision %d" % Ground.TERRAIN_REVISION)
	_check(ground.build_msec < BUILD_BUDGET_MSEC, "the ground builds in %d ms (budget %d)" % [ground.build_msec, BUILD_BUDGET_MSEC])
	_route(trail, ground)
	_ravine(trail, ground)
	_check(ground.cliff_cells >= 150, "cliffs exist (%d steep cells)" % ground.cliff_cells)
	_house_pad(trail, ground)
	_finish()


# Walkable from start to exit, and nothing steeper than a slope beside it,
# except the ravine's walls, which start further out.
func _route(trail: Trail, ground: Ground) -> void:
	var worst_grade := 0.0
	var worst_grade_at := Vector3.ZERO
	var worst_slope := 0.0
	var worst_slope_at := Vector3.ZERO
	var worst_side := 0.0
	var worst_side_at := 0.0
	var worst_side_point := Vector3.ZERO
	var span := trail.exit_offset - trail.player_start_offset
	var ravine_from := trail.player_start_offset + span * Tune.RAVINE_FROM
	var ravine_to := trail.player_start_offset + span * Tune.RAVINE_TO
	print("  ravine interval %.2f..%.2f m of %.2f" % [span * Tune.RAVINE_FROM, span * Tune.RAVINE_TO, span])
	var offset := trail.player_start_offset
	var last := trail.on_ground(trail.position_at(offset))
	while offset < trail.exit_offset:
		offset += 1.0
		var frame := trail.frame_at(offset)
		var here := trail.on_ground(frame.origin)
		var run := Vector2(here.x - last.x, here.z - last.z).length()
		if run > 0.2:
			if absf(here.y - last.y) / run > worst_grade:
				worst_grade_at = here
			worst_grade = maxf(worst_grade, absf(here.y - last.y) / run)
		last = here
		if ground.slope_at(here.x, here.z) > worst_slope:
			worst_slope_at = here
		worst_slope = maxf(worst_slope, ground.slope_at(here.x, here.z))
		var sides: Array[float] = [2.0, 5.0]
		if offset <= ravine_from or offset >= ravine_to:
			sides.append_array([8.0, 11.0])
		for side in sides:
			for sign_value in [-1.0, 1.0]:
				var at: Vector3 = frame.origin + frame.basis.x * side * float(sign_value)
				var slope := ground.slope_at(at.x, at.z)
				if slope > worst_side:
					worst_side = slope
					worst_side_at = offset - trail.player_start_offset
					worst_side_point = at
	_check(worst_grade <= 0.12, "the route's steepest grade is %.0f%% (at most 12%%)" % (worst_grade * 100.0))
	print("  route diagnostic: worst grade at %s, route field %.2f m" % [worst_grade_at, ground.route_distance(worst_grade_at.x, worst_grade_at.z)])
	_check(worst_slope <= 25.0, "the ground under the path is at most %.0f° (at most 25°)" % worst_slope)
	print("  slope diagnostic: under %s distance %.2f; side %s distance %.2f" % [worst_slope_at, ground.route_distance(worst_slope_at.x, worst_slope_at.z), worst_side_point, ground.route_distance(worst_side_point.x, worst_side_point.z)])
	_check(worst_side <= 45.0, "nothing beside the path is a cliff (%.0f° at %.0f m)" % [worst_side, worst_side_at])


func _ravine(trail: Trail, ground: Ground) -> void:
	var span := trail.exit_offset - trail.player_start_offset
	var middle := trail.player_start_offset + span * (Tune.RAVINE_FROM + Tune.RAVINE_TO) * 0.5
	var frame := trail.frame_at(middle)
	var floor_y := ground.height_at(frame.origin.x, frame.origin.z)
	for sign_value in [-1.0, 1.0]:
		var at: Vector3 = frame.origin + frame.basis.x * 10.0 * float(sign_value)
		var wall := ground.height_at(at.x, at.z) - floor_y
		_check(wall >= 6.0, "the ravine wall %s of the path stands %.1f m high (at least 6)" % ["left" if sign_value < 0.0 else "right", wall])


func _house_pad(trail: Trail, ground: Ground) -> void:
	var low := 1.0e6
	var high := -1.0e6
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		for z in [-6.0, -3.0, 0.0, 3.0, 6.0]:
			var at := trail.house.to_global(Vector3(x, 0.0, z))
			var h := ground.height_at(at.x, at.z)
			low = minf(low, h)
			high = maxf(high, h)
	_check(high - low <= 0.05, "the house pad is flat (spread %.3f m)" % (high - low))


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1


func _finish() -> void:
	print("Terrain probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)
