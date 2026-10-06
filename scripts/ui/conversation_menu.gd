class_name ConversationMenu
extends Control

## The conversation screen: the other person's name over the line being
## spoken, and her topics under it, on a dark band to the right of the view,
## as in Skyrim. Topics already taken stay listed but dimmed. Conversation
## drives it; mouse, keys and pad all choose.

signal chosen(index: int)

const DIM := Color(0.55, 0.57, 0.6)

var choices_shown := false
var selected := 0

var _name: Label
var _speaker: Label
var _line: Label
var _topics: VBoxContainer
var _hint: Label
var _buttons: Array[Button] = []
var _fade: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	var band := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.025, 0.035, 0.0))
	gradient.set_color(1, Color(0.02, 0.025, 0.035, 0.82))
	gradient.add_point(0.45, Color(0.02, 0.025, 0.035, 0.6))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	band.texture = texture
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.anchor_left = 0.42
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var column := VBoxContainer.new()
	column.anchor_left = 0.56
	column.anchor_right = 0.93
	column.anchor_top = 0.2
	column.anchor_bottom = 0.88
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_name = UiChrome.label("", 30, UiChrome.PAPER)
	column.add_child(_name)
	var rule := ColorRect.new()
	rule.color = Color(UiChrome.PAPER, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	_speaker = UiChrome.label("", 14, UiChrome.MUTED)
	column.add_child(_speaker)
	_line = UiChrome.label("", 23, UiChrome.INK)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 96)
	column.add_child(_line)
	_topics = VBoxContainer.new()
	_topics.add_theme_constant_override("separation", 2)
	column.add_child(_topics)
	_hint = UiChrome.label("", 14, UiChrome.MUTED)
	_hint.anchor_left = 0.56
	_hint.anchor_right = 0.93
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -56
	_hint.offset_bottom = -28
	add_child(_hint)


func open(npc_name: String) -> void:
	_name.text = npc_name.to_upper()
	_line.text = ""
	_speaker.text = ""
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
	_speaker.text = "" if theirs else speaker_name.to_upper()
	_line.text = text if theirs else "“%s”" % text
	_line.add_theme_color_override("font_color", UiChrome.INK if theirs else UiChrome.MUTED)
	_hint.text = "%s  Skip   ·   Esc  Leave" % Game.settings.key_label("interact")


## Her topics; the last one leaves. A taken topic is dimmed, not removed.
func show_choices(topics: Array[Dictionary]) -> void:
	_clear()
	for i in topics.size():
		var button := Button.new()
		button.text = str(topics[i].text)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		var color: Color = DIM if topics[i].get("dim", false) else UiChrome.PAPER
		if topics[i].get("leave", false):
			color = UiChrome.MUTED
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _topic_style(false))
		button.add_theme_stylebox_override("hover", _topic_style(true))
		button.add_theme_stylebox_override("pressed", _topic_style(true))
		button.add_theme_stylebox_override("focus", _topic_style(true))
		button.pressed.connect(func() -> void: chosen.emit(i))
		button.mouse_entered.connect(select.bind(i))
		_topics.add_child(button)
		_buttons.append(button)
	choices_shown = true
	_hint.text = "↑ / ↓  Choose   ·   %s / Enter  Say   ·   Esc  Leave" % Game.settings.key_label("interact")
	select(0)


func select(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	selected = index
	_buttons[index].grab_focus()


func step(direction: int) -> void:
	if not _buttons.is_empty():
		select(posmod(selected + direction, _buttons.size()))


func _clear() -> void:
	choices_shown = false
	for button in _buttons:
		_topics.remove_child(button)
		button.queue_free()
	_buttons.clear()
	selected = 0


func _topic_style(lit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.07 if lit else 0.0)
	style.border_width_left = 3
	style.border_color = Color(UiChrome.PAPER, 0.9 if lit else 0.0)
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, 0.25)
	if alpha <= 0.0:
		_fade.tween_callback(hide)
