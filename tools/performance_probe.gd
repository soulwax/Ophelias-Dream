extends Node

# Rendering policies and the terrain cache on the real authored level.
#   godot --headless --path . tools/performance_probe.tscn
var _failed := 0


class ColdFlora extends Flora:
	var placement_seed := 1701

	func _draw_batches() -> void:
		# Save the fresh placement before the normal renderer consumes it.
		_save_placements(_cache_fingerprint(placement_seed))
		super._draw_batches()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	var source := Game.trail.ground
	print("startup terrain: %d ms; cache %s; write %d ms" % [source.build_msec, source.cache_hit, source.cache_write_msec])
	var sun := main.get_node("Atmosphere/Sun") as DirectionalLight3D
	_check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "snapshot keeps the two-cascade budget")
	var camp := get_tree().get_first_node_in_group("camp") as Camp
	_check(camp.fire_light.shadow_enabled and (camp.fire_light.shadow_caster_mask & Tune.FOREST_RENDER_LAYER) == 0, "fire shadows exclude forest, retain camp/player")
	var batches := Game.trail.flora.get_node("Batches")
	var layers_ok := true
	for batch in batches.get_children():
		layers_ok = layers_ok and (batch as VisualInstance3D).layers == Tune.FOREST_RENDER_LAYER
	_check(layers_ok, "all forest batches use the dedicated render layer")
	var material := source.get_node("Chunks").get_child(0).material_override as ShaderMaterial
	_check(material.get_shader_parameter("terrain_noise") != null, "authored terrain materials have baked noise")
	_check(get_viewport().use_occlusion_culling, "occlusion culling is enabled")
	var occluders := Game.house.get_node("RenderOccluders")
	_check(occluders.get_child_count() > 0, "opaque house structure has occluders")
	var openings_clear := true
	for window: Array in Game.house.windows():
		openings_clear = openings_clear and not _occluded(occluders, window[0])
	openings_clear = openings_clear and not _occluded(occluders, Game.house.to_global(Vector3(0, House.DOOR_HEIGHT * 0.5, House.UPSTAIRS.end.y)))
	_check(openings_clear, "occluders leave window and front doorway centres clear")

	OS.set_environment("RUN_TERRAIN_CACHE", "off")
	var fresh := _copy_inputs(source)
	fresh.position.x = -1400.0
	add_child(fresh)
	fresh._save_cache(fresh._cache_fingerprint())
	OS.set_environment("RUN_TERRAIN_CACHE", "")
	var cached := _copy_inputs(source)
	cached.position.x = 1400.0
	add_child(cached)
	print("terrain fresh %d ms; cache write %d ms; cached %d ms" % [fresh.build_msec, fresh.cache_write_msec, cached.build_msec])
	_check(cached.cache_hit, "matching terrain inputs load the binary cache")
	_check(fresh._chunk_heights == cached._chunk_heights and fresh._chunk_normals == cached._chunk_normals, "cached chunk heights and stitched normals are exact")
	_check(fresh._snow_distance == cached._snow_distance and fresh._route_distance == cached._route_distance, "cached biome/route fields are exact")
	_check(fresh.cliff_cells == cached.cliff_cells and fresh.story_centre == cached.story_centre, "cache preserves terrain diagnostics")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hits := 0
	for k in 12:
		var x := Tune.WORLD_MIN_X + 60.0 + float(k % 4) * 250.0
		var z := Tune.WORLD_MIN_Z + 90.0 + float(k / 4) * 330.0
		var height := cached.height_at(x, z)
		var at := cached.to_global(Vector3(x, height, z))
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1, at - Vector3.UP, Tune.LAYER_WORLD)
		var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and absf((hit.position as Vector3).y - at.y) < 0.02:
			hits += 1
	_check(hits == 12, "cached mesh collision agrees with cached heights (12 rays)")
	var changed := _copy_inputs(source)
	var fingerprint := changed._cache_fingerprint()
	changed.seed_value += 1
	_check(changed._cache_fingerprint() != fingerprint, "seed change invalidates the cache")
	changed.seed_value -= 1
	changed.pads[0][0] += Vector2(0.5, 0)
	_check(changed._cache_fingerprint() != fingerprint, "pad edit invalidates the cache")
	changed.pads = source.pads.duplicate(true)
	changed.route = source.route.duplicate() as Curve3D
	changed.route.set_point_position(1, changed.route.get_point_position(1) + Vector3(1, 0, 0))
	_check(changed._cache_fingerprint() != fingerprint, "route edit invalidates the cache")
	changed.free()
	OS.set_environment("RUN_TERRAIN_CACHE", "off")
	var fresh_woods := ColdFlora.new()
	fresh_woods.placement_seed = Game.trail.seed_value
	add_child(fresh_woods)
	fresh_woods.grow(source, Game.trail.curve, Game.trail._reserved, fresh_woods.placement_seed)
	OS.set_environment("RUN_TERRAIN_CACHE", "")
	var cached_woods := Flora.new()
	add_child(cached_woods)
	cached_woods.grow(source, Game.trail.curve, Game.trail._reserved, Game.trail.seed_value)
	print("flora fresh %d ms; cached %d ms" % [fresh_woods.build_msec, cached_woods.build_msec])
	_check(cached_woods.cache_hit, "matching placement inputs load the flora cache")
	_check(cached_woods.trees == fresh_woods.trees and cached_woods.tree_kinds == fresh_woods.tree_kinds, "cached tree positions, ordering and species are exact")
	var centre := Game.trail.position_at(Game.trail.player_start_offset + 100.0)
	_check(cached_woods.nearest_indices(centre, 12, 60.0) == fresh_woods.nearest_indices(centre, 12, 60.0), "cached spatial hash finds the same nearest trees")
	_check(cached_woods.undergrowth_count == fresh_woods.undergrowth_count and cached_woods.ordinary_planned == fresh_woods.ordinary_planned, "cached biome counts are exact")
	print("Performance probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)


func _copy_inputs(source: Ground) -> Ground:
	var result := Ground.new()
	result.seed_value = source.seed_value
	result.route = source.route
	result.route_from = source.route_from
	result.route_to = source.route_to
	result.story_points = source.story_points.duplicate()
	result.pads = source.pads.duplicate(true)
	result.cuts = source.cuts.duplicate(true)
	return result


func _occluded(root: Node, at: Vector3) -> bool:
	for node in root.get_children():
		var occluder := node as OccluderInstance3D
		var size := (occluder.occluder as BoxOccluder3D).size
		if AABB(-size * 0.5, size).has_point(occluder.to_local(at)):
			return true
	return false


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1
