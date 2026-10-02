class_name EndCard
extends Control

var _title: Label
var _body: Label
var _hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	Game.phase_changed.connect(_on_phase)


func _on_phase(next: Game.Phase) -> void:
	match next:
		Game.Phase.CAUGHT:
			_show(
				"It caught you",
				"You stopped. The snow closed over the place you were.",
				"R  —  wake in the cabin again"
			)
		Game.Phase.ESCAPED:
			_show(
				"The road",
				"Headlights. A real road. You do not look back. You run until the snow is only a sound.",
				"R  —  walk the ridge again"
			)
		_:
			visible = false


func _show(title: String, body: String, hint: String) -> void:
	_title.text = title
	_body.text = body
	_hint.text = hint
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -120
	box.offset_bottom = 120
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
	box.add_child(_title)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(640, 0)
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", Color(0.78, 0.78, 0.8))
	box.add_child(_body)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.62, 0.66))
	box.add_child(_hint)
