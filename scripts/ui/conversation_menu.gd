class_name ConversationMenu
extends Control

## Signal terminal for encounters: speaker, current line and topics in a
## compact panel at the right edge. Taken topics stay listed but dimmed.
## Conversation drives it; mouse, keys and pad all choose.

signal chosen(index: int)

const DIM := UiChrome.ASH

var choices_shown := false
var selected := 0

var _name: Label
var _speaker: Label
var _line: Label
var _turn: Label
var _action_row: HBoxContainer
var _topics: VBoxContainer
var _hint: Label
var _panel: PanelContainer
var _buttons: Array[Button] = []
var _choice_texts: Array[String] = []
var _fade: Tween
# A cursor resting where a topic appears must not steal the first topic.
var _pointer_moved := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.56
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.16
	_panel.anchor_bottom = 0.91
	var panel_style := UiChrome.term_box(Color(UiChrome.VOID, 0.9), Color(UiChrome.SIGNAL, 0.54), 1, 22)
	panel_style.border_width_left = 3
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	var channel := UiChrome.term_label("// VOICE CHANNEL", 12, UiChrome.SIGNAL)
	column.add_child(channel)
	_name = UiChrome.term_label("", 26, UiChrome.BONE, true)
	column.add_child(_name)
	var rule := ColorRect.new()
	rule.color = Color(UiChrome.SIGNAL, 0.52)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	_speaker = UiChrome.term_label("", 12, UiChrome.ASH)
	column.add_child(_speaker)
	_line = UiChrome.term_label("", 19, UiChrome.BONE)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 96)
	column.add_child(_line)
	_turn = UiChrome.term_label("", 12, UiChrome.SIGNAL)
	_turn.visible = false
	column.add_child(_turn)
	_action_row = UiChrome.key_row(Game.settings.key_label("interact"), "Continue")
	_action_row.visible = false
	column.add_child(_action_row)
	_topics = VBoxContainer.new()
	_topics.add_theme_constant_override("separation", 2)
	column.add_child(_topics)
	_hint = UiChrome.term_label("", 11, UiChrome.ASH)
	column.add_child(_hint)


func open(npc_name: String) -> void:
	_name.text = npc_name.to_upper()
	_line.text = ""
	_speaker.text = ""
	_turn.hide()
	_clear()
	visible = true
	_fade_to(1.0)


func close() -> void:
	choices_shown = false
	_fade_to(0.0)


## The line being spoken. Her own lines carry her name; the other person's
## stand under the header alone.
func show_line(speaker_name: String, text: String, theirs: bool) -> void:
	_clear()
	_speaker.text = "INBOUND // %s" % speaker_name.to_upper() if theirs else "OUTBOUND // %s" % speaker_name.to_upper()
	_line.text = text if theirs else "“%s”" % text
	_line.add_theme_color_override("font_color", UiChrome.BONE if theirs else UiChrome.ASH)
	_turn.hide()
	_set_action("Continue")
	_hint.text = "Esc  Leave"


## Her topics; the last one leaves. A taken topic is dimmed, not removed.
func show_choices(topics: Array[Dictionary]) -> void:
	_clear()
	_turn.text = "// YOUR RESPONSE    %02d AVAILABLE" % topics.size()
	_turn.show()
	for i in topics.size():
		var button := Button.new()
		var choice_text := str(topics[i].text)
		if topics[i].get("dim", false):
			choice_text += "   /   heard"
		_choice_texts.append(choice_text)
		button.text = "  %02d  %s" % [i + 1, choice_text]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_override("font", UiChrome.mono_font())
		button.add_theme_font_size_override("font_size", 16)
		var color: Color = DIM if topics[i].get("dim", false) else UiChrome.BONE
		if topics[i].get("leave", false):
			color = UiChrome.ASH
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _topic_style(false))
		button.add_theme_stylebox_override("hover", _topic_style(true))
		button.add_theme_stylebox_override("pressed", _topic_style(true))
		button.add_theme_stylebox_override("focus", _topic_style(true))
		button.pressed.connect(func() -> void: chosen.emit(i))
		button.mouse_entered.connect(func() -> void:
			if _pointer_moved:
				select(i))
		_topics.add_child(button)
		_buttons.append(button)
	choices_shown = true
	_pointer_moved = false
	_set_action("Say")
	_hint.text = "↑ / ↓  Choose   ·   1-%d  Speak   ·   Esc  Leave" % topics.size()
	select(0)


func _input(event: InputEvent) -> void:
	if choices_shown and event is InputEventMouseMotion and not _pointer_moved:
		_pointer_moved = true
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered in _buttons:
			select(_buttons.find(hovered))


func select(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	selected = index
	for i in _buttons.size():
		_buttons[i].text = ("> " if i == index else "  ") + "%02d  %s" % [i + 1, _choice_texts[i]]
	_buttons[index].grab_focus()


func step(direction: int) -> void:
	if not _buttons.is_empty():
		select(posmod(selected + direction, _buttons.size()))


func _clear() -> void:
	choices_shown = false
	_action_row.visible = false
	for button in _buttons:
		_topics.remove_child(button)
		button.queue_free()
	_buttons.clear()
	_choice_texts.clear()
	selected = 0


func _set_action(caption: String) -> void:
	UiChrome.set_key(_action_row, Game.settings.key_label("interact"))
	(_action_row.get_child(1) as Label).text = caption
	_action_row.visible = true


func _topic_style(lit: bool) -> StyleBoxFlat:
	var style := UiChrome.term_box(Color(UiChrome.SIGNAL, 0.12) if lit else Color(0, 0, 0, 0),
		Color(UiChrome.SIGNAL, 0.72) if lit else Color(UiChrome.BONE, 0.08), 1, 6)
	style.border_width_left = 2 if lit else 1
	return style


func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, 0.25)
	if alpha <= 0.0:
		_fade.tween_callback(hide)
