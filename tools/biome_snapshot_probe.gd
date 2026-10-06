extends Node

# Real startup and in-memory authored snapshots. Never writes/rebakes a scene.
# Catches missing settlement, stale terrain replacement, lost collision,
# child-index drift at Fence, and the old fence-sized HUD boundary.
var _failed := 0
var _template: Node3D
var _template_owner := Node3D.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for fixture in ["normal", "missing", "old", "same", "route"]:
		await _fixture(fixture)
	_template_owner.free()
	print("Biome snapshot probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)


func _fixture(kind: String) -> void:
	print("Snapshot fixture: " + kind)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var snapshot := main.get_node("EditableLevel")
	if _template:
		var old_trail := snapshot.get_node("Trail")
		snapshot.remove_child(old_trail)
		old_trail.free()
		var copy := _template.duplicate(0)
		snapshot.add_child(copy)
		var curve := (copy.get_node("Route") as Path3D).curve
		var points := PackedVector3Array()
		for index in curve.point_count:
			points.append(curve.get_point_position(index))
		snapshot.set_meta("route_points", points)
		snapshot.set_meta("route_start", (copy.get_node("Route/Start") as Marker3D).position)
	var saved_ground := snapshot.get_node("Trail/Ground") as Node3D
	var saved_house := snapshot.get_node("Trail/House") as Node3D
	var saved_fence := snapshot.get_node("Trail/Fence")
	var fence_slot := (saved_fence.get_meta(EditableLevel.SOURCE_PATH) as PackedInt32Array)[1]
	if kind != "normal":
		saved_house.set_meta("layout_revision", House.LAYOUT_REVISION)
		saved_house.position.x += 1.25
		saved_house.position.z -= 1.5
		saved_house.position.y = 99.0
		saved_house.rotation.y = 0.37
	if kind == "missing":
		saved_ground.remove_meta("terrain_revision")
	elif kind == "same":
		saved_ground.set_meta("terrain_revision", Ground.TERRAIN_REVISION)
		saved_ground.visible = false
	else:
		saved_ground.set_meta("terrain_revision", Ground.TERRAIN_REVISION - 1)
	if kind != "same":
		# Visible poison edits prove the retain branch ignores stale field edits.
		saved_ground.position.x = 200.0
		saved_ground.visible = false
		var saved_trail := snapshot.get_node("Trail")
		for node in saved_trail.get_children():
			if node is Node3D and node.name not in ["House", "Fence", "Threats", "Route"]:
				(node as Node3D).visible = false
	if kind == "route":
		var route := snapshot.get_node("Trail/Route") as Path3D
		route.curve = route.curve.duplicate() as Curve3D
		route.curve.set_point_position(1, route.curve.get_point_position(1) + Vector3(8, 0, 0))
		_check(EditableLevel.route_shift(snapshot)["curve"], "route edit triggers regeneration")
	var house_at := saved_house.position
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var trail := Game.trail
	_check(trail != null and trail.has_method("settle_house"), "startup has house settlement")
	if trail == null:
		main.queue_free()
		await get_tree().process_frame
		return
	var fence := trail.get_node_or_null("Fence")
	_check(fence != null and fence.get_index() == fence_slot, "Fence preserves the snapshot child slot")
	_check(fence != null and fence.get_class() == "Node3D" and fence.get_child_count() == 0, "Fence is an empty Node3D")
	if kind == "same":
		_check(not trail.ground.visible, "same terrain revision applies authored ground visibility")
		_check(trail.house.position.is_equal_approx(house_at) and absf(trail.house.rotation.y - 0.37) < 0.001, "same revision preserves authored house height and placement")
	else:
		_check(trail.ground.visible and trail.flora.visible, "generated Ground and Flora survive snapshot apply")
		var landmarks := 0
		var landmarks_live := true
		for node in trail.route_derived():
			if node == trail.ground or node == trail.flora:
				continue
			landmarks += 1
			landmarks_live = landmarks_live and not node.is_queued_for_deletion() and (not node is Node3D or (node as Node3D).visible)
		_check(landmarks > 0 and landmarks_live, "generated landmarks survive snapshot apply")
		_check(absf(trail.house.position.y - trail.ground.height_at(trail.house.position.x, trail.house.position.z) - House.PLINTH) < 0.05, "house rests on its terrain pad plus plinth")
		if kind in ["missing", "old"]:
			_check(Vector2(trail.house.position.x, trail.house.position.z).distance_to(Vector2(house_at.x, house_at.z)) < 0.001 and absf(trail.house.rotation.y - 0.37) < 0.001, "settlement preserves authored house X/Z and yaw")
	await _terrain(trail.ground)
	_hud(main)
	if kind == "normal":
		# Current generated hierarchy, with scripts stripped and index tags only
		# in memory: changing the fixture revision must not counterfeit a house
		# layout revision on an obsolete shell.
		_template = trail.duplicate(0) as Node3D
		EditableLevel._strip_scripts(_template)
		_template_owner.add_child(_template)
		EditableLevel._tag_tree(trail, _template, PackedInt32Array([1]), _template_owner)
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _terrain(ground: Ground) -> void:
	var count := 0
	var bounds := AABB()
	for node in ground.find_children("Chunk_*", "MeshInstance3D", true, false):
		var chunk := node as MeshInstance3D
		if chunk.mesh == null:
			continue
		var box := ground.global_transform.affine_inverse() * chunk.global_transform * chunk.mesh.get_aabb()
		bounds = box if count == 0 else bounds.merge(box)
		count += 1
	var expected := int(round((Tune.WORLD_MAX_X - Tune.WORLD_MIN_X) / Tune.CHUNK_SIZE)) * int(round((Tune.WORLD_MAX_Z - Tune.WORLD_MIN_Z) / Tune.CHUNK_SIZE))
	_check(count == expected, "world chunk count %d/%d" % [count, expected])
	_check(absf(bounds.position.x - Tune.WORLD_MIN_X) < 0.05 and absf(bounds.end.x - Tune.WORLD_MAX_X) < 0.05 and absf(bounds.position.z - Tune.WORLD_MIN_Z) < 0.05 and absf(bounds.end.z - Tune.WORLD_MAX_Z) < 0.05, "terrain meshes span WORLD bounds")
	var hits := 0
	var worst := 0.0
	# Six by four points well away from the house/stair and world-edge walls.
	for row in 4:
		for column in 6:
			var x := Tune.WORLD_MIN_X + (float(column) + 0.5) * (Tune.WORLD_MAX_X - Tune.WORLD_MIN_X) / 6.0
			var z := Tune.WORLD_MIN_Z + (float(row) + 0.5) * (Tune.WORLD_MAX_Z - Tune.WORLD_MIN_Z) / 4.0
			var height := ground.height_at(x, z)
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, height + 0.1, z), Vector3(x, height - 1.0, z), Tune.LAYER_WORLD)
			var hit := ground.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				hits += 1
				worst = maxf(worst, absf((hit["position"] as Vector3).y - height))
	_check(hits == 24 and worst < 0.2, "24 terrain collision rays outside the stair cut (%d hits, worst %.3f m)" % [hits, worst])
	var attempted := 0
	var sampled := 0
	var cut_skips := 0
	var bound_skips := 0
	var max_error := 0.0
	var normal_error := 0.0
	var face_error := 0.0
	var probes: Array[Vector2] = []
	var labels: Array[String] = []
	var lod_edges := {"west_fine": 0, "east_fine": 0, "north_fine": 0, "south_fine": 0}
	var cells: PackedFloat32Array = ground.get("_chunk_cell")
	# Keep thaw rays independent of seams so both forms of coverage are visible.
	for cz in ground.chunks_z:
		for cx in ground.chunks_x:
			var index := cz * ground.chunks_x + cx
			var cell := cells[index]
			var x := Tune.WORLD_MIN_X + float(cx) * Tune.CHUNK_SIZE + cell * 3.27
			var z := Tune.WORLD_MIN_Z + float(cz) * Tune.CHUNK_SIZE + cell * 4.73
			var snow := ground.snow_at(x, z)
			if snow >= 0.2 and snow <= 0.8:
				probes.append(Vector2(x, z))
				labels.append("thaw %d,%d" % [cx, cz])
			# Enumerate each adjacent pair once (east and south), regardless of
			# which chunk is finer, and sample both sides of every actual border.
			if cx + 1 < ground.chunks_x and cell != cells[index + 1]:
				var fine_west := cell < cells[index + 1]
				var orientation := "west_fine" if fine_west else "east_fine"
				lod_edges[orientation] += 1
				var border := Tune.WORLD_MIN_X + float(cx + 1) * Tune.CHUNK_SIZE
				var along := Tune.WORLD_MIN_Z + (float(cz) + 0.413) * Tune.CHUNK_SIZE
				for side in [-1.0, 1.0]:
					probes.append(Vector2(border + 0.37 * float(side), along))
					labels.append("LOD %s %d,%d side %.0f" % [orientation, cx, cz, side])
				var fine_index := index if fine_west else index + 1
				normal_error = maxf(normal_error, _stitched_derivative_error(ground, fine_index, true, fine_west))
			if cz + 1 < ground.chunks_z and cell != cells[index + ground.chunks_x]:
				var fine_north := cell < cells[index + ground.chunks_x]
				var orientation := "north_fine" if fine_north else "south_fine"
				lod_edges[orientation] += 1
				var border := Tune.WORLD_MIN_Z + float(cz + 1) * Tune.CHUNK_SIZE
				var along := Tune.WORLD_MIN_X + (float(cx) + 0.413) * Tune.CHUNK_SIZE
				for side in [-1.0, 1.0]:
					probes.append(Vector2(along, border + 0.37 * float(side)))
					labels.append("LOD %s %d,%d side %.0f" % [orientation, cx, cz, side])
				var fine_index := index if fine_north else index + ground.chunks_x
				normal_error = maxf(normal_error, _stitched_derivative_error(ground, fine_index, false, fine_north))
	# A tall ray catches disagreement even when the sampler is below collision.
	# Skipped bounds/cut cells are deliberate; every other ray must hit.
	for index in probes.size():
		var at := probes[index]
		var skip := _terrain_ray_skip(ground, at)
		if skip != "":
			cut_skips += 1 if skip == "cut" else 0
			bound_skips += 1 if skip == "bounds" else 0
			print("  skip %s ray %s at %s" % [skip, labels[index], at])
			continue
		attempted += 1
		var height := ground.height_at(at.x, at.y)
		var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, height + 30.0, at.y), Vector3(at.x, height - 30.0, at.y), Tune.LAYER_WORLD)
		var hit := ground.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			_check(false, "terrain collision miss: %s at %s" % [labels[index], at])
			continue
		sampled += 1
		max_error = maxf(max_error, absf((hit["position"] as Vector3).y - height))
		face_error = maxf(face_error, (hit["normal"] as Vector3).distance_to(ground.normal_at(at.x, at.y)))
	print("  LOD border coverage west-fine %d east-fine %d north-fine %d south-fine %d; two rays per border" % [lod_edges.west_fine, lod_edges.east_fine, lod_edges.north_fine, lod_edges.south_fine])
	_check(attempted >= 8 and sampled == attempted and max_error < 0.2, "thaw/LOD collision agreement (%d/%d attempted rays hit, %d cut/%d bounds skipped, worst %.3f m)" % [sampled, attempted, cut_skips, bound_skips, max_error])
	_check(normal_error < 0.001, "stitched edge normals use final heights (gradient error %.4f)" % normal_error)
	_check(face_error < 0.001, "sampled normals agree with collision triangles (vector error %.4f)" % face_error)


# Return only intentional absences, based on the actual cell omitted by cuts.
func _terrain_ray_skip(ground: Ground, at: Vector2) -> String:
	if at.x < Tune.WORLD_MIN_X or at.x >= Tune.WORLD_MAX_X or at.y < Tune.WORLD_MIN_Z or at.y >= Tune.WORLD_MAX_Z:
		return "bounds"
	var cx := int(floor((at.x - Tune.WORLD_MIN_X) / Tune.CHUNK_SIZE))
	var cz := int(floor((at.y - Tune.WORLD_MIN_Z) / Tune.CHUNK_SIZE))
	var cell: float = ground.get("_chunk_cell")[cz * ground.chunks_x + cx]
	var x0 := Tune.WORLD_MIN_X + float(cx) * Tune.CHUNK_SIZE
	var z0 := Tune.WORLD_MIN_Z + float(cz) * Tune.CHUNK_SIZE
	var cell_x := x0 + floorf((at.x - x0) / cell) * cell
	var cell_z := z0 + floorf((at.y - z0) / cell) * cell
	return "cut" if ground.call("_cut", cell_x, cell_z, cell, cell) else ""


# Check the derivative tangent to each fine edge at a stitched grid vertex.
func _stitched_derivative_error(ground: Ground, index: int, vertical: bool, far_edge: bool) -> float:
	var points: int = ground.get("_chunk_points")[index]
	var heights: PackedFloat32Array = ground.get("_chunk_heights")[index]
	var normals: PackedVector3Array = ground.get("_chunk_normals")[index]
	var cell: float = ground.get("_chunk_cell")[index]
	var edge := points - 1 if far_edge else 0
	var k := 4
	var vertex := k * points + edge if vertical else edge * points + k
	var stride := points if vertical else 1
	var gradient := (heights[vertex + stride] - heights[vertex - stride]) / (2.0 * cell)
	var normal := normals[vertex]
	var component := normal.z if vertical else normal.x
	return absf(-component / normal.y - gradient)


func _hud(main: Node) -> void:
	var hud: Hud
	for child in main.get_children():
		if child is Hud:
			hud = child
	if hud == null:
		_check(false, "startup completes through HUD")
		return
	var original := Game.player.global_position
	Game.player.global_position = Vector3(Tune.FENCE_MAX_X + 10.0, 0, 0)
	_check(not hud.call("_against_wire"), "old fence bounds do not trigger the edge cue")
	for at in [Vector3(Tune.WORLD_MIN_X + 1, 0, 0), Vector3(Tune.WORLD_MAX_X - 1, 0, 0), Vector3(0, 0, Tune.WORLD_MIN_Z + 1), Vector3(0, 0, Tune.WORLD_MAX_Z - 1)]:
		Game.player.global_position = at
		_check(hud.call("_against_wire"), "WORLD edge triggers cue at %s" % at)
	for at in [Vector3(Tune.WORLD_MIN_X + 13, 0, 0), Vector3(Tune.WORLD_MAX_X - 13, 0, 0), Vector3(0, 0, Tune.WORLD_MIN_Z + 13), Vector3(0, 0, Tune.WORLD_MAX_Z - 13)]:
		Game.player.global_position = at
		_check(hud.call("_against_wire"), "cue is reachable inside the inset boundary wall at %s" % at)
	Game.player.global_position = original


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1
