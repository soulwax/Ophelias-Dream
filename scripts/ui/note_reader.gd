class_name NoteReader
extends Control


var _title: Label
var _count: Label
var _body: RichTextLabel
var _scroll: ScrollContainer
var _panel: PanelContainer
var _entry_tween: Tween
var _danger: Label
var _close_keys: HBoxContainer
var _breath_keys: HBoxContainer
var _entry: NoteEntry
var _journal_keys: HBoxContainer
var _accum: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	Game.phase_changed.connect(_on_phase)


func _process(delta: float) -> void:
	if not visible or _entry == null:
		return
	_danger.visible = Game.closeness > 0.4
	if _body.visible_characters < 0:
		return
	var total := _body.get_total_character_count()
	_accum += delta
	var step := 1.0 / Tune.TYPE_CPS
	while _accum >= step and _body.visible_characters < total:
		_accum -= step
		_body.visible_characters += 1
	if _body.visible_characters >= total:
		_body.visible_characters = -1
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
	show_entry(page.entry)


func show_entry(entry: NoteEntry) -> void:
	_entry = entry
	_accum = 0.0
	var notes := NoteCatalog.all()
	_count.text = "Found in the house"
	for i in notes.size():
		if notes[i].title == _entry.title:
			_count.text = "Note %d of %d" % [i + 1, notes.size()]
			break
	if _entry.record_of != "":
		_count.text = "Containment record"
	_title.text = _entry.title
	var text := UiChrome.smudge_text(_entry)
	if Game.page_solved(_entry) and _entry.between != "":
		text += "

[color=#%s]%s[/color]" % [Color(UiChrome.PAPER_INK, 0.55).to_html(true), _entry.between]
	_body.text = text
	_body.visible_characters = 0
	_scroll.scroll_vertical = 0
	UiChrome.set_key(_close_keys, Game.settings.key_label("interact"))
	UiChrome.set_key(_breath_keys, Game.settings.key_label("hold_breath"))
	UiChrome.set_key(_journal_keys, Game.settings.key_label("journal"))
	visible = true
	if _entry_tween and _entry_tween.is_running():
		_entry_tween.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.94
	_panel.modulate.a = 0.0
	_entry_tween = create_tween().set_parallel(true)
	_entry_tween.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entry_tween.tween_property(_panel, "modulate:a", 1.0, 0.17)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_close_from_dim)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -400
	_panel.offset_right = 400
	_panel.offset_top = -280
	_panel.offset_bottom = 280
	_panel.add_theme_stylebox_override("panel", UiChrome.paper(32))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

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

	_body = UiChrome.page_label(20)
	_body.custom_minimum_size = Vector2(700, 0)
	_scroll.add_child(_body)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer)
	_close_keys = UiChrome.key_row("E", "Close the page", true)
	footer.add_child(_close_keys)
	_breath_keys = UiChrome.key_row("RMB", "Hold breath", true)
	footer.add_child(_breath_keys)
	_journal_keys = UiChrome.key_row("J", "Journal", true)
	footer.add_child(_journal_keys)
	var close := UiChrome.paper_button("Close")
	# Keys pressed while she reads must never press the button.
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: Game.close_reading())
	footer.add_child(close)

	_danger = UiChrome.label("It is still moving.", 14, Color(0.62, 0.22, 0.16))
	_danger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger.visible = false
	box.add_child(_danger)
