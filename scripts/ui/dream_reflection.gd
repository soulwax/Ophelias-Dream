extends CanvasLayer

var memory := ""
var mathilda := false
var outcome := "complete"
var _line: Label
var _panel: Panel
var _armed := false
var _elapsed := 0.0
var _context_reached := false
var _left_camp := false
var _shown := false
var _echo_anchor := Vector3.ZERO
var _echo_anchor_ready := false
const STORY := preload("res://scripts/world/dream_story.gd")


func _ready() -> void:
	if memory.strip_edges().is_empty():
		queue_free()
		return
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	var subtitle_size: int = Settings.SUBTITLE_SIZES[clampi(Game.settings.subtitle_size, 0, Settings.SUBTITLE_SIZES.size() - 1)]
	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiChrome.term_box(Color(UiChrome.VOID, 0.88), Color(UiChrome.SIGNAL, 0.58), 1, 10)
	style.border_width_left = 3
	_panel.add_theme_stylebox_override("panel", style)
	_panel.modulate.a = 0.0
	add_child(_panel)
	_line = UiChrome.term_label(_reflection_text(), subtitle_size, UiChrome.BONE)
	_line.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_color_override("font_outline_color", Color(0.008, 0.012, 0.022, 0.94))
	_line.add_theme_constant_override("outline_size", 3)
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
	_echo_anchor = _echo_anchor_position()
	_echo_anchor_ready = true
	_layout_echo()
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(_line, "modulate:a", 1.0, 0.8)
	fade.tween_property(_panel, "modulate:a", 1.0, 0.8)
	fade.set_parallel(false)
	fade.tween_interval(7.0)
	fade.set_parallel(true)
	fade.tween_property(_line, "modulate:a", 0.0, 1.4)
	fade.tween_property(_panel, "modulate:a", 0.0, 1.4)
	fade.set_parallel(false)
	fade.tween_callback(queue_free)


func _layout_echo() -> void:
	if _line == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(900.0, maxf(1.0, viewport_size.x - 32.0))
	var font_size := _line.get_theme_font_size("font_size")
	var chars_per_line := maxi(int(width / maxf(float(font_size) * 0.58, 1.0)), 1)
	var lines := maxi(1, ceili(float(_line.text.length()) / float(chars_per_line)))
	var height := maxf(72.0, float(lines) * float(font_size) * 1.4 + 24.0)
	var screen := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.23)
	var camera := get_viewport().get_camera_3d()
	if _echo_anchor_ready and camera:
		var focus := _echo_anchor + Vector3.UP * 0.9
		var projected := camera.unproject_position(focus)
		if camera.is_position_behind(focus):
			var toward := focus - camera.global_position
			var side := -1.0 if toward.dot(camera.global_basis.x) < 0.0 else 1.0
			projected = Vector2(viewport_size.x * (0.18 if side < 0.0 else 0.82), viewport_size.y * 0.28)
		screen = projected
	var safe_x := minf(width * 0.5 + 16.0, viewport_size.x * 0.5)
	screen.x = clampf(screen.x, safe_x, viewport_size.x - safe_x)
	screen.y = clampf(screen.y - height - 20.0, 24.0, maxf(24.0, viewport_size.y * 0.76 - height))
	_panel.position = Vector2(screen.x - width * 0.5, screen.y)
	_panel.size = Vector2(width, height)
	_line.offset_left = screen.x - width * 0.5 + 16.0
	_line.offset_right = screen.x + width * 0.5 - 16.0
	_line.offset_top = screen.y + 8.0
	_line.offset_bottom = screen.y + height - 8.0


func _echo_anchor_position() -> Vector3:
	if mathilda:
		var camp := get_tree().get_first_node_in_group("camp") as Camp
		if camp:
			camp.ensure_built()
			if memory in ["waiting", "present_need"] and camp.fire_light:
				return camp.fire_light.global_position
			if memory in ["remember", "walk_beside"] and Game.trail:
				return Game.trail.on_ground(Game.trail.position_at(Game.trail.player_start_offset + Camp.OFFSET + 8.0))
			if camp.spots.has("cups"):
				return camp.spots["cups"]
	if not mathilda and Game.house:
		match memory:
			"waiting", "silence", "present_need":
				if Game.house.lantern_light:
					return Game.house.lantern_light.global_position
			"remember":
				return Game.house.front_door_approach()
	if Game.trail and Game.player:
		var player_offset := Game.trail.offset_of(Game.player.global_position)
		return Game.trail.on_ground(Game.trail.position_at(clampf(player_offset, 0.0, Game.trail.length)))
	return Game.player.global_position if Game.player else Vector3.ZERO


func _reflection_text() -> String:
	var story := STORY.load_data()
	if outcome == "ruptured":
		var ruptured: Dictionary = story.get("ruptured", {})
		return str(ruptured.get("mathilda" if mathilda else "ophelia", "The conversation closed before the warning could be heard."))
	if outcome == "unresolved":
		var unresolved: Dictionary = story.get("unresolved", {})
		return str(unresolved.get("mathilda" if mathilda else "ophelia", "The dream kept its warning behind a closed door."))
	var branch := STORY.branch_for(story, memory)
	if branch.is_empty():
		return "The dream follows Mathilda into the afternoon." if mathilda else "The dream stays with Ophelia."
	return str(branch.get("mathilda" if mathilda else "ophelia", ""))
