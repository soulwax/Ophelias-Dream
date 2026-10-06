@tool
extends Node3D

## -1 rolls a new seed whenever the editable level is rebuilt.
@export var world_seed: int = -1
@export_tool_button("Randomize / rebuild editable level") var rebuild_level_action := _regenerate_editor_level

var _capture := false
var _frames := 0
var _bake_pid := -1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_capture = OS.get_environment("RUN_CAPTURE") == "1"
	var repacking := OS.get_cmdline_user_args().has("--repack-editor-level")
	var baking := repacking or OS.get_cmdline_user_args().has("--bake-editor-level")
	var snapshot := get_node_or_null("EditableLevel")
	var chosen_seed := _resolve_seed(null if baking and not repacking else snapshot)
	if snapshot is Node3D:
		(snapshot as Node3D).visible = false
	Game.reset()
	if baking:
		# Headless runs report a lean GPU; author the full visual setup.
		Game.lean_graphics = false
	Game.mark("build atmosphere")
	var atmosphere := Atmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	Game.mark("build trail")
	var trail := Trail.new()
	trail.name = "Trail"
	trail.seed_value = chosen_seed
	var use_snapshot := snapshot != null and not (baking and not repacking)
	var shift := EditableLevel.route_shift(snapshot if use_snapshot else null)
	if use_snapshot:
		var route := snapshot.get_node_or_null("Trail/Route") as Path3D
		if route and route.curve and route.curve.point_count >= 2:
			trail.authored_curve = route.curve
		var start := snapshot.get_node_or_null("Trail/Route/Start") as Marker3D
		if start:
			trail.authored_start = start.position
			trail.use_authored_start = true
	add_child(trail)
	Game.mark("build player")
	var player := Player.new()
	player.name = "Player"
	player.trail = trail
	add_child(player)
	Game.mark("build weather")
	add_child(Weather.new())
	add_child(Wildlife.new())
	Game.mark("build sound and hud")
	add_child(Soundscape.new())
	add_child(Voice.new())
	var hud := Hud.new()
	add_child(hud)
	Game.mark("scene built")
	var editable_nodes: Array[Node] = [atmosphere, trail, player]
	var built_house := trail.house.transform
	var built_exit := trail.exit_point
	var redrawn: bool = shift["curve"] or shift["start"]
	var retain: Array[Node] = []
	var house_changed := false
	if redrawn:
		retain = trail.route_derived()
	# The house blockout changed. Keep the new shell and its matching markers
	# together instead of copying an older snapshot's indexed children onto it.
	if use_snapshot:
		var saved_house := snapshot.get_node_or_null("Trail/House")
		if saved_house and int(saved_house.get_meta("layout_revision", 0)) != House.LAYOUT_REVISION:
			retain.append(trail.house)
			house_changed = true
	# An old bake stored a page as a trail child in the slot Threats uses.
	# Hold that branch aside until the snapshot contains the slot, so the
	# page is not painted onto it.
	var parked := _park_threats(snapshot if use_snapshot else null, trail)
	if repacking and snapshot:
		EditableLevel.apply(snapshot, editable_nodes, retain)
		_restore_parked(trail, parked)
		_settle_route(trail, shift, built_house, built_exit)
		if trail.house:
			trail.house.settle_comfort()
		player.apply_authored_spawn(house_changed)
		player.set_process(false)
		player.set_physics_process(false)
		snapshot.queue_free()
		_finish_repack.call_deferred(editable_nodes, chosen_seed)
		return
	if baking:
		_finish_bake.call_deferred(editable_nodes, chosen_seed)
		return
	if snapshot:
		EditableLevel.apply(snapshot, editable_nodes, retain)
		_restore_parked(trail, parked)
		_settle_route(trail, shift, built_house, built_exit)
		player.apply_authored_spawn(house_changed)
		atmosphere.rebind_authoring_resources()
		snapshot.queue_free()
	if trail.house:
		trail.house.settle_comfort()
	if Game.weather:
		Game.weather.settle()
	trail.adopt_markers()
	Game.begin_intro()
	if _capture:
		Game.set_phase(Game.Phase.PLAYING)
		# Dev hook: RUN_MENU=<page> opens the Esc menu on that page for the shot.
		var page := OS.get_environment("RUN_MENU")
		if page != "":
			process_mode = Node.PROCESS_MODE_ALWAYS
			Game.toggle_pause.call_deferred()
			hud.menu.open_page.call_deferred(page)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if _bake_pid > 0 and not OS.is_process_running(_bake_pid):
			_bake_pid = -1
			# EditorInterface is absent from export templates, even while this
			# branch is unreachable there. Resolve it dynamically so the script
			# still parses in a Windows build.
			var editor_interface = Engine.get_singleton(&"EditorInterface")
			if editor_interface:
				editor_interface.get_resource_filesystem().scan()
				editor_interface.reload_scene_from_path("res://scenes/main.tscn")
		return
	if not _capture:
		return
	_frames += 1
	var shot_frame := OS.get_environment("RUN_SHOT_FRAME").to_int()
	if _frames == (shot_frame if shot_frame > 0 else 150):
		_shoot()


func _shoot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OS.get_environment("RUN_SHOT")
	if path == "":
		path = "user://run_shot.png"
	image.save_png(path)
	get_tree().quit()


func _park_threats(snapshot: Node, trail: Trail) -> Array[Node]:
	var parked: Array[Node] = []
	if snapshot == null:
		return parked
	var authored := snapshot.get_node_or_null("Trail")
	# Older snapshots call the same slot Anomalies.
	if authored and (authored.get_node_or_null("Threats") or authored.get_node_or_null("Anomalies")):
		return parked
	# Route sits after Threats. Lift it first so it does not slide into
	# the slot the old snapshot still uses for something else.
	for branch_name in ["Route", "Threats"]:
		var branch := trail.get_node_or_null(branch_name)
		if branch:
			trail.remove_child(branch)
			parked.append(branch)
	parked.reverse()
	return parked


func _restore_parked(trail: Trail, parked: Array[Node]) -> void:
	for branch in parked:
		trail.add_child(branch)


func _settle_route(trail: Trail, shift: Dictionary, built_house: Transform3D, built_exit: Vector3) -> void:
	if shift["curve"] or shift["start"]:
		trail.house.transform = built_house
	if shift["curve"]:
		var exit_marker := trail.get_node_or_null("Route/Exit") as Marker3D
		if exit_marker:
			exit_marker.global_position = built_exit
		trail.exit_point = built_exit


func _resolve_seed(snapshot: Node) -> int:
	if snapshot and snapshot.has_meta("seed"):
		return int(snapshot.get_meta("seed"))
	if world_seed != -1:
		return world_seed
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(0, 2147300000)


func _finish_bake(nodes: Array[Node], chosen_seed: int) -> void:
	var result := EditableLevel.bake(nodes, chosen_seed)
	if result != OK:
		push_error("Could not save editable level: %s" % error_string(result))
	else:
		print("Saved editable level with seed %d" % chosen_seed)
	get_tree().quit(0 if result == OK else 1)


func _finish_repack(nodes: Array[Node], chosen_seed: int) -> void:
	await get_tree().process_frame
	_finish_bake(nodes, chosen_seed)


func _regenerate_editor_level() -> void:
	if not Engine.is_editor_hint() or _bake_pid > 0:
		return
	var editor_interface = Engine.get_singleton(&"EditorInterface")
	if editor_interface == null:
		return
	editor_interface.save_scene()
	_bake_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--", "--bake-editor-level"
	]))
	if _bake_pid <= 0:
		push_error("Could not start Godot to rebuild the editable level")
