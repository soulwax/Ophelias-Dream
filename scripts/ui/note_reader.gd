class_name NoteReader
extends Control

const _GLYPHS := "abcdefghijklmnopqrstuvwxyz.,'"

var _panel: PanelContainer
var _title: Label
var _body: Label
var _hint: Label
var _entry: NoteEntry
var _stable: String = ""
var _accum: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	Game.phase_changed.connect(_on_phase)


func _process(delta: float) -> void:
	if not visible or _entry == null:
		return
	if _stable.length() >= _entry.body.length():
		return
	_accum += delta
	var step := 1.0 / Tune.TYPE_CPS
	while _accum >= step and _stable.length() < _entry.body.length():
		_accum -= step
		var next := _entry.body[_stable.length()]
		var corrupt := _entry.corruption > 0.0 and next != " " and next != "\n"
		if corrupt and randf() < _entry.corruption:
			next = _GLYPHS[randi() % _GLYPHS.length()]
		_stable += next
	_body.text = _stable


func _on_phase(next: Game.Phase) -> void:
	if next == Game.Phase.READING:
		_open()
	elif visible:
		visible = false


func _open() -> void:
	var page := Game.active_note
	if page == null or page.entry == null:
		return
	_entry = page.entry
	_stable = ""
	_accum = 0.0
	_title.text = _entry.title
	_body.text = ""
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -390
	_panel.offset_right = 390
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, 0.94)
	style.border_color = Color(0.45, 0.38, 0.28, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	box.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(700, 0)
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", Color(0.84, 0.8, 0.72))
	box.add_child(_body)

	_hint = Label.new()
	_hint.text = "E  —  close the page. It does not stop."
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.45, 0.38))
	box.add_child(_hint)
