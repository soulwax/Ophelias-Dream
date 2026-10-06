extends Node3D

var bubble: DialogueBubble
var selected := ""


func _ready() -> void:
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	Game.set_phase(Game.Phase.PLAYING)
	bubble = DialogueBubble.new()
	add_child(bubble)
	assert(bubble.open("Mathilda", "You kept her cup. What do you keep now?", [
		{"id": "locked", "text": "A memory not yet understood", "disabled": true},
		{"id": "return", "text": "Return to Ophelia"},
		{"id": "wait", "text": "Wait with the light"},
	], null, _selected))
	assert(Game.locks_movement() and Game.locks_look() and Game.awake())
	bubble.choose(0)
	assert(selected == "")
	await get_tree().process_frame
	if OS.get_environment("DIALOGUE_SHOT") != "":
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("DIALOGUE_SHOT"))
	bubble.choose(1)
	assert(selected == "return" and Game.phase == Game.Phase.PLAYING)
	assert(not bubble.open("Mathilda", "Empty", []))
	assert(bubble.open("Mathilda", "Stay?", [{"id": "wait", "text": "Wait"}]))
	var leave := InputEventAction.new()
	leave.action = "pause"
	leave.pressed = true
	bubble._input(leave)
	assert(not bubble._active and Game.phase == Game.Phase.PLAYING)
	assert(bubble.open("Mathilda", "Stay?", [{"id": "wait", "text": "Wait"}]))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.set_phase(Game.Phase.CAUGHT)
	assert(not bubble._active and Game.phase == Game.Phase.CAUGHT)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("Dialogue probe passed: disabled topics, selection, cancel, phase and control lifecycle")
	get_tree().quit()


func _selected(id: String) -> void:
	selected = id
