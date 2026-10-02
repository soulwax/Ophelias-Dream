extends Node3D

var _capture := false
var _frames := 0


func _ready() -> void:
	_capture = OS.get_environment("RUN_CAPTURE") == "1"
	Game.reset()
	add_child(Atmosphere.new())
	var trail := Trail.new()
	add_child(trail)
	var player := Player.new()
	player.trail = trail
	add_child(player)
	var hunter := Hunter.new()
	hunter.trail = trail
	add_child(hunter)
	add_child(Weather.new())
	add_child(Soundscape.new())
	add_child(Hud.new())
	Game.begin_intro()
	if _capture:
		Game.set_phase(Game.Phase.PLAYING)


func _process(_delta: float) -> void:
	if not _capture:
		return
	_frames += 1
	if _frames == 150:
		_shoot()


func _shoot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OS.get_environment("RUN_SHOT")
	if path == "":
		path = "user://run_shot.png"
	image.save_png(path)
	get_tree().quit()
