extends CanvasLayer

var memory := ""
var mathilda := false
var _line: Label
var _waiting := true
const STORY := preload("res://scripts/world/dream_story.gd")


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_line = UiChrome.label(_reflection_text(), 19, Color("e4e0df"))
	_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_line.offset_left = -510
	_line.offset_right = 510
	_line.offset_top = 92
	_line.offset_bottom = 166
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.modulate.a = 0.0
	add_child(_line)
	Game.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(Game.phase)


func _on_phase_changed(next: Game.Phase) -> void:
	if not _waiting or next != Game.Phase.PLAYING:
		return
	_waiting = false
	var fade := create_tween()
	fade.tween_property(_line, "modulate:a", 1.0, 0.8)
	fade.tween_interval(7.0)
	fade.tween_property(_line, "modulate:a", 0.0, 1.4)
	fade.tween_callback(queue_free)


func _reflection_text() -> String:
	var branch := STORY.branch_for(STORY.load_data(), memory)
	if branch.is_empty():
		return "The dream follows Mathilda into the afternoon." if mathilda else "The dream stays with Ophelia."
	return str(branch.get("mathilda" if mathilda else "ophelia", ""))
