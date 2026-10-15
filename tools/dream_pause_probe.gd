extends Node

## The Esc menu over a dream reply: the reply rows must keep the size the dream
## lays out for them while the world is paused, and the menu must draw above
## every dream overlay. Quits 1 on any failure. Isolate user data as for
## dream_flow_probe (docs/mvp/BASELINE.md).
const MAIN := preload("res://scenes/main.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if detail.is_empty() else "  (" + detail + ")"))
	if not ok:
		_failures += 1


func _rows(experience: Node) -> Array:
	var rows: Array = experience.get("_choice_rows")
	return rows.filter(func(row: Variant) -> bool: return is_instance_valid(row))


func _describe(rows: Array) -> String:
	var parts: PackedStringArray = []
	for row: Control in rows:
		parts.append("%dx%d min %d" % [row.size.x, row.size.y, row.get_combined_minimum_size().y])
	return ", ".join(parts)


func _canvas_layer(node: Node) -> int:
	while node:
		if node is CanvasLayer:
			return (node as CanvasLayer).layer
		node = node.get_parent()
	return 0


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.dream_mode = true
	Game.character_selected = true
	var main := MAIN.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for _frame in 2400:
		if Game.trail and Game.player and Game.phase == Game.Phase.DREAM:
			break
		await get_tree().process_frame
	var route := main.find_child("DreamRoute", true, false)
	var experience: Node = route.get_parent() if route else null
	if experience == null or Game.phase != Game.Phase.DREAM:
		_check(false, "the dream reaches its playable phase")
		get_tree().quit(1)
		return
	# The first small-talk round, as the walk would open it.
	var rounds: Array = (experience.get("_story") as Dictionary).get("small_talk", [])
	var round_data: Dictionary = rounds[0]
	var labels: Array[String] = []
	for choice: Dictionary in round_data.get("choices", []):
		labels.append(str(choice.get("label", "")))
	experience.call("_set_choice_rows", str(round_data.get("prompt", "")), labels)
	# The round adds its guidance above the reply hint, as the walk does.
	var guidance := str(round_data.get("guidance", ""))
	var hint_label := experience.get("_choice_hint") as Label
	if not guidance.is_empty():
		hint_label.text = "%s
%s" % [guidance, hint_label.text]
	var panel := experience.get("_choice_panel") as Control
	panel.visible = true
	for _frame in 20:
		await get_tree().process_frame
	var rows := _rows(experience)
	_check(rows.size() == labels.size(), "the reply rows are built", "%d rows" % rows.size())
	var laid_out: Array[float] = []
	for row: Control in rows:
		laid_out.append(row.size.y)
	print("  playing: " + _describe(rows))
	var fits := true
	for row: Control in rows:
		if row.get_combined_minimum_size().y > row.size.y + 0.5:
			fits = false
	_check(fits, "each row's content fits the height the dream lays out")
	var rows_clear := true
	for index in range(1, rows.size()):
		if (rows[index] as Control).position.y < (rows[index - 1] as Control).position.y + (rows[index - 1] as Control).size.y - 0.5:
			rows_clear = false
	_check(rows_clear, "the reply rows do not overlap")
	var hint := experience.get("_choice_hint") as Label
	var hint_back := experience.get("_choice_hint_back") as Control
	var hint_text := float(hint.get_line_count() * (hint.get_line_height() + hint.get_theme_constant("line_spacing")))
	_check(hint_text <= hint.size.y + 1.0 and hint.size.y <= hint_back.size.y, "the guidance fits its box",
		"%d lines, %.0f px of text, label %.0f, box %.0f" % [hint.get_line_count(), hint_text, hint.size.y, hint_back.size.y])
	var reply_shot := OS.get_environment("PROBE_SHOT")
	if not reply_shot.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(reply_shot.get_basename() + "_unpaused.png")

	Game.toggle_pause()
	_check(Game.phase == Game.Phase.PAUSED and get_tree().paused, "Esc pauses the dream")
	# While paused the dream's per-frame layout stops; a row must not grow to
	# its label's minimum size when something asks it to recompute.
	for row: Control in rows:
		row.update_minimum_size()
		for child in row.get_children():
			(child as Control).update_minimum_size()
	for _frame in 20:
		await get_tree().process_frame
	print("  paused:  " + _describe(rows))
	var held := true
	for index in rows.size():
		if absf((rows[index] as Control).size.y - laid_out[index]) > 0.5:
			held = false
	_check(held, "paused reply rows keep their laid-out height")

	# The HUD's Esc menu; the title menu keeps another PauseMenu as its settings page.
	var huds := get_tree().root.find_children("*", "CanvasLayer", true, false).filter(func(node: Node) -> bool: return node is Hud)
	var menu: Array = [(huds[0] as Hud).menu] if not huds.is_empty() else []
	var menu_layer := _canvas_layer(menu[0]) if not menu.is_empty() else 0
	var dream_layer := _canvas_layer(panel)
	_check(not menu.is_empty() and menu_layer > dream_layer, "the Esc menu draws above the dream reply", "menu layer %d, reply layer %d" % [menu_layer, dream_layer])
	var overlays: PackedStringArray = []
	for layer: CanvasLayer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if layer.visible and layer.layer >= menu_layer and layer.layer < 100 and not layer.is_ancestor_of(menu[0]):
			overlays.append("%s %d" % [layer.name, layer.layer])
	_check(overlays.is_empty(), "no game overlay shares or tops the Esc menu's layer", ", ".join(overlays))

	# With a window, PROBE_SHOT=<png path> keeps what the paused screen shows.
	var shot := OS.get_environment("PROBE_SHOT")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("  shot: " + shot)
	Game.toggle_pause()
	print("Dream pause probe: %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
