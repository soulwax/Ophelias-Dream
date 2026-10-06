extends Node

# The woods on the generated world: counts by biome, the route corridor, slope
# and species rules, the lean half, the nearest-tree query, trunk collision,
# cleanup and the build budget. Run once lean (the headless default) and once
# with RUN_GRAPHICS=full; exits 1 on any failure.
#   godot-mono --headless --path . tools/flora_probe.tscn
#   RUN_GRAPHICS=full godot-mono --headless --path . tools/flora_probe.tscn

var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var trail := Game.trail
	if trail == null or trail.flora == null or trail.ground == null:
		_check(false, "the scene built the trail, ground and flora")
		_finish()
		return
	var flora := trail.flora
	var ground := trail.ground
	var lean := Game.lean_graphics
	print("mode: %s" % ("lean" if lean else "full"))
	_check(flora.build_msec < 2500, "flora builds in %d ms (budget 2500)" % flora.build_msec)

	var snow_trees := 0
	var green_trees := 0
	var crowded := 0
	var steep := 0
	var wrong_species := 0
	for i in flora.trees.size():
		var at := flora.trees[i]
		var kind: String = flora.tree_kinds[i]
		var s := ground.snow_at(at.x, at.z)
		if kind.begins_with("snow"):
			snow_trees += 1
		else:
			green_trees += 1
		if ground.route_distance(at.x, at.z) < Tune.FOREST_CLEAR - 0.01:
			crowded += 1
		if ground.slope_at(at.x, at.z) > 35.5:
			steep += 1
		# Species follow the biome; the thaw band may mix a little.
		if (kind.begins_with("snow") and s < 0.4) or (kind.begins_with("green") and s > 0.6):
			wrong_species += 1
	print("trees: snow %d green %d giants %d great %d" % [snow_trees, green_trees, flora.giant_count, flora.great_count])
	if not lean:
		_check(snow_trees >= 300 and snow_trees <= 2500, "snow woods hold 300-2500 trees (%d)" % snow_trees)
		_check(green_trees >= 1500 and green_trees <= 12000, "green woods hold 1500-12000 trees (%d)" % green_trees)
		_check(flora.undergrowth_count > 5000, "undergrowth over 5000 in full (%d)" % flora.undergrowth_count)
	_check(crowded == 0, "no tree within %.0f m of the route (%d)" % [Tune.FOREST_CLEAR, crowded])
	_check(steep == 0, "no tree on slopes over 35 degrees (%d)" % steep)
	_check(wrong_species <= maxi(10, flora.trees.size() / 10), "species follow the biome (%d out of place)" % wrong_species)
	_check(flora.giant_count >= 6 and flora.giant_count <= Tune.FOREST_GIANTS, "6-%d lone giants (%d)" % [Tune.FOREST_GIANTS, flora.giant_count])
	_check(flora.great_count > 0, "great pines stand in the snow woods (%d)" % flora.great_count)

	# Lean keeps a stable half of the ordinary trees and of the undergrowth.
	var ordinary_share := float(flora.ordinary_kept) / maxf(float(flora.ordinary_planned), 1.0)
	var under_share := float(flora.undergrowth_count) / maxf(float(flora.undergrowth_planned), 1.0)
	if lean:
		_check(absf(ordinary_share - Tune.FOREST_LEAN_SHARE) <= 0.1, "lean keeps about half the ordinary trees (%.2f)" % ordinary_share)
		_check(absf(under_share - Tune.FOREST_LEAN_SHARE) <= 0.1, "lean keeps about half the undergrowth (%.2f)" % under_share)
	else:
		_check(flora.ordinary_kept == flora.ordinary_planned, "full keeps every ordinary tree")
		_check(flora.undergrowth_count == flora.undergrowth_planned, "full keeps all the undergrowth")

	# Positions agree with the trees, and the nearest query really is nearest.
	_check(flora.tree_positions().size() == flora.trees.size(), "tree_positions lists every tree")
	var probe := trail.position_at(trail.player_start_offset + 120.0)
	var near := flora.tree_positions(probe, 60.0)
	var brute := 0
	var closest := INF
	for at in flora.trees:
		var d := Vector2(at.x - probe.x, at.z - probe.z).length()
		if d <= 60.0:
			brute += 1
			closest = minf(closest, d)
	_check(near.size() == brute, "the radius query finds every tree within 60 m (%d of %d)" % [near.size(), brute])
	if near.size() > 1:
		var first := Vector2(near[0].x - probe.x, near[0].z - probe.z).length()
		_check(is_equal_approx(first, closest), "the radius query lists the nearest tree first")

	# A trunk blocks: a point inside its trunk at chest height is solid. (A
	# sideways ray would meet the hillside first on a slope.)
	var blocked := 0
	var tried := 0
	var space := get_viewport().get_world_3d().direct_space_state
	for i in range(0, flora.trees.size(), maxi(flora.trees.size() / 20, 1)):
		tried += 1
		if _solid(space, flora.trees[i]):
			blocked += 1
	_check(blocked >= tried - 1, "trunks block (%d of %d)" % [blocked, tried])

	# Cliffs near the route are dressed with rock.
	_check(flora.rock_count >= 12, "rock faces dress the cliffs (%d)" % flora.rock_count)

	# Freeing the woods frees their physics bodies.
	var spots: Array[Vector3] = []
	for i in range(0, flora.trees.size(), maxi(flora.trees.size() / 20, 1)):
		spots.append(flora.trees[i])
	trail.remove_child(flora)
	flora.free()
	await get_tree().physics_frame
	var leaked := 0
	for at in spots:
		if _solid(space, at):
			leaked += 1
	_check(leaked == 0, "no trunks left standing after freeing the woods (%d)" % leaked)
	_finish()


func _solid(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at + Vector3.UP * 1.2
	query.collision_mask = Tune.LAYER_WORLD
	return not space.intersect_point(query, 1).is_empty()


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1


func _finish() -> void:
	print("Flora probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)
