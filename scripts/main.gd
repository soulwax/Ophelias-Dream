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
	add_child(trail)
	Game.mark("build player")
	var player := Player.new()
	player.name = "Player"
	player.trail = trail
	add_child(player)
	Game.mark("build hunter")
	var hunter := Hunter.new()
	hunter.name = "Hunter"
	hunter.trail = trail
	add_child(hunter)
	Game.mark("build anomalies")
	var director := AnomalyDirector.new()
	director.trail = trail
	add_child(director)
	Game.mark("build weather")
	add_child(Weather.new())
	add_child(Wildlife.new())
	Game.mark("build sound and hud")
	add_child(Soundscape.new())
	var hud := Hud.new()
	add_child(hud)
	Game.mark("scene built")
	var editable_nodes: Array[Node] = [atmosphere, trail, player, hunter]
	if repacking and snapshot:
		EditableLevel.apply(snapshot, editable_nodes)
		player.set_process(false)
		player.set_physics_process(false)
		hunter.set_physics_process(false)
		snapshot.queue_free()
		_finish_repack.call_deferred(editable_nodes, chosen_seed)
		return
	if baking:
		_finish_bake.call_deferred(editable_nodes, chosen_seed)
		return
	if snapshot:
		EditableLevel.apply(snapshot, editable_nodes)
		player.apply_authored_spawn()
		atmosphere.rebind_authoring_resources()
		snapshot.queue_free()
	Game.begin_intro()
	if OS.get_environment("RUN_TEMP_REC") != "":
		_temp_record.call_deferred(float(OS.get_environment("RUN_TEMP_REC")))
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
			EditorInterface.get_resource_filesystem().scan()
			EditorInterface.reload_scene_from_path("res://scenes/main.tscn")
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


func _temp_record(seconds: float) -> void:
	Game.set_phase(Game.Phase.PLAYING)
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	await get_tree().create_timer(0.5).timeout
	var flora := Game.trail.flora.tree_positions().size()
	var house := get_tree().get_nodes_in_group("x").size()
	print("TEMP trees ", flora, " listener ", get_viewport().get_audio_listener_3d(), " buses ", AudioServer.bus_count)
	for i in AudioServer.bus_count:
		print("TEMP bus ", AudioServer.get_bus_name(i), " -> ", AudioServer.get_bus_send(i), " fx ", AudioServer.get_bus_effect_count(i))
	var players := 0
	var playing := 0
	for node in find_children("*", "AudioStreamPlayer3D", true, false):
		players += 1
		if (node as AudioStreamPlayer3D).playing:
			playing += 1
	print("TEMP 3d players ", players, " playing ", playing, " zones ", find_children("*Tone", "Area3D", true, false).size(), " house ", house)
	await get_tree().create_timer(seconds).timeout
	record.set_recording_active(false)
	var clip := record.get_recording()
	if clip:
		clip.save_to_wav(OS.get_environment("RUN_TEMP_WAV"))
		print("TEMP saved ", clip.get_length(), " s")
	get_tree().quit()


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
	EditorInterface.save_scene()
	_bake_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--", "--bake-editor-level"
	]))
	if _bake_pid <= 0:
		push_error("Could not start Godot to rebuild the editable level")
