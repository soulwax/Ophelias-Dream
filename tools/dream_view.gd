extends Node

## Render focused dream compositions for visual review. Run with a window.
const MAIN := preload("res://scenes/main.tscn")
const OUT := "res://build/dream/"

var _camera: Camera3D


func _ready() -> void:
	Game.dream_mode = true
	Game.character_selected = true
	var main := MAIN.instantiate()
	get_tree().root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for _frame in 2400:
		if Game.trail and Game.player and Game.phase == Game.Phase.DREAM:
			break
		await get_tree().process_frame
	if Game.trail == null or Game.player == null or Game.phase != Game.Phase.DREAM:
		push_error("Dream view could not enter the playable phase")
		get_tree().quit(1)
		return
	_camera = Camera3D.new()
	_camera.name = "DreamReviewCamera"
	_camera.fov = 52.0
	_camera.far = 320.0
	get_tree().root.add_child(_camera)
	_camera.current = true
	var route := main.find_child("DreamRoute", true, false) as DreamRoute
	var experience := route.get_parent() if route else null
	if route == null or experience == null:
		push_error("Dream route helpers were not built")
		get_tree().quit(1)
		return
	await _capture_entry(route, "entry")
	await _capture_lantern(route, experience, "lantern")
	await _capture_clearing(route, experience, "clearing")
	await _capture_choice(route, experience, "answer")
	print("Dream visual review captures saved under build/dream/")
	get_tree().quit()


func _place_player(offset: float) -> void:
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + offset)
	Game.player.global_position = Game.trail.on_ground(frame.origin) + Vector3.UP * 0.15
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()


func _aim(offset: float, from_across: float, from_ahead: float, height: float, look_height: float = 0.8) -> void:
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + offset)
	var ahead := Game.trail.frame_at(Game.trail.player_start_offset + offset + 1.0).origin - frame.origin
	ahead.y = 0.0
	ahead = ahead.normalized()
	var across := frame.basis.x
	across.y = 0.0
	across = across.normalized()
	var target := Game.trail.on_ground(frame.origin) + Vector3.UP * look_height
	_camera.global_position = target + across * from_across + ahead * from_ahead + Vector3.UP * height
	_camera.look_at(target, Vector3.UP)


func _capture_entry(route: DreamRoute, name: String) -> void:
	_place_player(1.0)
	_aim(1.0, 9.0, -2.0, 3.0, 1.1)
	await _save_frame(name)


func _capture_lantern(route: DreamRoute, experience: Node, name: String) -> void:
	_place_player(33.0)
	experience.set("_stage", 2)
	experience.call("_set_figure_moving", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 34.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 34.0)
	_aim(33.0, 7.5, 1.5, 3.0, 0.5)
	await _save_frame(name)


func _capture_clearing(route: DreamRoute, experience: Node, name: String) -> void:
	_place_player(58.0)
	experience.set("_stage", 4)
	experience.call("_set_figure_moving", false)
	experience.set("_figure_offset", Game.trail.player_start_offset + 61.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 61.0)
	experience.call("_pulse_effect", 0.72, "merge")
	_aim(DreamRoute.CLEARING_OFFSET, 9.0, 4.0, 6.0, 0.9)
	await _settle()
	await _save_frame(name)


func _capture_choice(route: DreamRoute, experience: Node, name: String) -> void:
	_place_player(65.0)
	experience.set("_stage", 4)
	experience.set("_figure_offset", Game.trail.player_start_offset + 67.0)
	experience.call("_place_figure", Game.trail.player_start_offset + 67.0)
	_aim(DreamRoute.CLEARING_OFFSET, 9.0, 4.0, 6.0, 0.9)
	experience.call("_finish_dream")
	await _settle()
	await _save_frame(name)


func _settle() -> void:
	for _frame in 18:
		await get_tree().process_frame


func _save_frame(name: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save dream review image %s: %s" % [path, error_string(error)])
