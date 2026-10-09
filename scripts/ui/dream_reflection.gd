extends CanvasLayer

var memory := ""
var mathilda := false
var _line: Label
var _armed := false
var _elapsed := 0.0
var _context_reached := false
var _left_camp := false
var _shown := false
const STORY := preload("res://scripts/world/dream_story.gd")


func _ready() -> void:
	if memory.strip_edges().is_empty():
		queue_free()
		return
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	var subtitle_size := Settings.SUBTITLE_SIZES[clampi(Game.settings.subtitle_size, 0, Settings.SUBTITLE_SIZES.size() - 1)]
	_line = UiChrome.label(_reflection_text(), subtitle_size, Color("e4e0df"))
	_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_line.offset_top = 92
	_line.offset_bottom = 166
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.modulate.a = 0.0
	add_child(_line)
	get_viewport().size_changed.connect(_layout_echo)
	_layout_echo()
	Game.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(Game.phase)


func _process(delta: float) -> void:
	if not _armed or _shown or Game.phase != Game.Phase.PLAYING or Game.player == null or Game.trail == null:
		return
	_elapsed += delta
	if mathilda:
		_update_mathilda_context()
	else:
		var progress := Game.trail.offset_of(Game.player.global_position) - Game.trail.player_start_offset
		if progress >= 9.0:
			_context_reached = true
	if _context_reached and Game.murmur_left <= 0.0:
		_show_echo()


func _on_phase_changed(next: Game.Phase) -> void:
	if next == Game.Phase.PLAYING:
		_armed = true


func _update_mathilda_context() -> void:
	var camp_frame := Game.trail.frame_at(Game.trail.player_start_offset + 98.0)
	var camp := Game.trail.on_ground(camp_frame.origin + camp_frame.basis.x * 7.5)
	var distance := Game.player.global_position.distance_to(camp)
	if distance > 15.0:
		_left_camp = true
	if _elapsed >= 9.0 and distance <= 11.0:
		_context_reached = true
	elif _left_camp and distance <= 8.0:
		_context_reached = true


func _show_echo() -> void:
	_shown = true
	var fade := create_tween()
	fade.tween_property(_line, "modulate:a", 1.0, 0.8)
	fade.tween_interval(7.0)
	fade.tween_property(_line, "modulate:a", 0.0, 1.4)
	fade.tween_callback(queue_free)


func _layout_echo() -> void:
	if _line == null:
		return
	var width := minf(1020.0, maxf(240.0, get_viewport().get_visible_rect().size.x - 32.0))
	_line.offset_left = -width * 0.5
	_line.offset_right = width * 0.5


func _reflection_text() -> String:
	var branch := STORY.branch_for(STORY.load_data(), memory)
	if branch.is_empty():
		return "The dream follows Mathilda into the afternoon." if mathilda else "The dream stays with Ophelia."
	return str(branch.get("mathilda" if mathilda else "ophelia", ""))
