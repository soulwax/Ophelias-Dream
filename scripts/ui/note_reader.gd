class_name NoteReader
extends Control

const _GLYPHS := "abcdefghijklmnopqrstuvwxyz.,'"

var _title: Label
var _count: Label
var _body: Label
var _scroll: ScrollContainer
var _danger: Label
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
	_danger.visible = Game.closeness > 0.4
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
	var bar := _scroll.get_v_scroll_bar()
	if bar:
		_scroll.scroll_vertical = int(bar.max_value)


func _on_phase(next: Game.Phase) -> void:
	if next == Game.Phase.READING:
		_open()
	elif visible:
		visible = false


func _close_from_dim(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Game.close_reading()


func _open() -> void:
	var page := Game.active_note
	if page == null or page.entry == null:
		return
	_entry = page.entry
	_stable = ""
	_accum = 0.0
	var notes := NoteCatalog.all()
	var index := 1
	for i in notes.size():
		if notes[i].title == _entry.title:
			index = i + 1
			break
	_count.text = "Note %d of %d" % [index, notes.size()]
	if _entry.record_of != "":
		_count.text = "Containment record"
	_title.text = _entry.title
	_body.text = ""
	_scroll.scroll_vertical = 0
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_close_from_dim)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -280
	panel.offset_bottom = 280
	panel.add_theme_stylebox_override("panel", UiChrome.paper(32))
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	_count = UiChrome.label("Note 1 of 5", 13, Color(0.4, 0.32, 0.24))
	box.add_child(_count)

	_title = UiChrome.label("", 30, UiChrome.PAPER_INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(720, 300)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(_scroll)

	_body = UiChrome.label("", 20, UiChrome.PAPER_INK)
	_body.add_theme_constant_override("line_spacing", 6)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(700, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer)
	footer.add_child(UiChrome.key_row("E", "Close the page"))
	footer.add_child(UiChrome.key_row("Space", "Hold breath"))
	var close := UiChrome.paper_button("Close")
	# Space holds her breath while she reads; it must not press the button.
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: Game.close_reading())
	footer.add_child(close)

	_danger = UiChrome.label("It is still moving.", 14, Color(0.62, 0.22, 0.16))
	_danger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger.visible = false
	box.add_child(_danger)
