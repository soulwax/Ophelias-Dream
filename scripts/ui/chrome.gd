class_name UiChrome
extends RefCounted

const INK := Color(0.94, 0.95, 0.96)
const MUTED := Color(0.72, 0.75, 0.79)
const RUST := Color(0.95, 0.48, 0.4)
const PAPER := Color(0.91, 0.87, 0.78)
const PAPER_INK := Color(0.17, 0.14, 0.11)
const PLATE := Color(0.05, 0.06, 0.08, 0.78)


static func plate(margin: int = 14, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	return style


static func paper(margin: int = 28) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.97)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style


static func keycap() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.12)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.border_color = Color(1, 1, 1, 0.16)
	style.set_border_width_all(1)
	return style


static func button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style


static func label(text: String, size: int, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func key_row(keys: String, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", keycap())
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.custom_minimum_size = Vector2(64, 28)
	var key := label(keys, 14, INK)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(key)
	row.add_child(cap)
	row.add_child(label(caption, 16, MUTED))
	row.custom_minimum_size.x = 210
	return row


static func text_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", button_style(Color(1, 1, 1, 0.08)))
	button.add_theme_stylebox_override("hover", button_style(Color(1, 1, 1, 0.16)))
	button.add_theme_stylebox_override("pressed", button_style(Color(1, 1, 1, 0.22)))
	button.add_theme_stylebox_override("focus", button_style(Color(1, 1, 1, 0.08)))
	return button


static func paper_button(text: String) -> Button:
	var button := text_button(text)
	button.add_theme_color_override("font_color", PAPER_INK)
	button.add_theme_color_override("font_hover_color", PAPER_INK)
	button.add_theme_stylebox_override("normal", button_style(Color(0.17, 0.14, 0.11, 0.08)))
	button.add_theme_stylebox_override("hover", button_style(Color(0.17, 0.14, 0.11, 0.16)))
	button.add_theme_stylebox_override("pressed", button_style(Color(0.17, 0.14, 0.11, 0.24)))
	button.add_theme_stylebox_override("focus", button_style(Color(0.17, 0.14, 0.11, 0.08)))
	return button
