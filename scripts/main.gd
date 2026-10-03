extends Node3D

var _capture := false
var _frames := 0


func _ready() -> void:
	_capture = OS.get_environment("RUN_CAPTURE") == "1"
	Game.reset()
	Game.mark("build atmosphere")
	add_child(Atmosphere.new())
	Game.mark("build trail")
	var trail := Trail.new()
	add_child(trail)
	Game.mark("build player")
	var player := Player.new()
	player.trail = trail
	add_child(player)
	Game.mark("build hunter")
	var hunter := Hunter.new()
	hunter.trail = trail
	add_child(hunter)
	Game.mark("build anomalies")
	var director := AnomalyDirector.new()
	director.trail = trail
	add_child(director)
	Game.mark("build weather")
	add_child(Weather.new())
	Game.mark("build sound and hud")
	add_child(Soundscape.new())
	add_child(Hud.new())
	Game.mark("scene built")
	Game.begin_intro()
	if _capture:
		Game.set_phase(Game.Phase.PLAYING)


func _process(_delta: float) -> void:
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
