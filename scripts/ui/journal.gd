class_name Journal
extends Control

# The pages she has found, to read again and decipher. Open, it is
# Game.Phase.JOURNAL: she stands still and the world goes on. A smudge is a
# word she can't read yet; once its key is known (Game.known) she can try its
# three readings. See docs/superpowers/specs/2026-10-06-mathilda-story-design.md.

const HINTS := {
	"page": "Something else she wrote might help.",
	"place": "Maybe if I saw the place.",
	"event": "Maybe if I listened, out there.",
}

var _list: VBoxContainer
var _title: Label
var _body: RichTextLabel
var _between: Label
var _blots: HBoxContainer
var _readings: HBoxContainer
var _hint: Label
var _empty: Label
var _close_keys: HBoxContainer
var _selected: NoteEntry
var _smudge := -1
# This run's order of each smudge's readings, and the readings tried and wrong.
var _order := {}
var _wrong := {}
var _buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	Game.phase_changed.connect(_on_phase)
	Game.journal_changed.connect(_refresh)
	Game.page_deciphered.connect(_on_page_deciphered)


func _on_phase(next: Game.Phase) -> void:
	if next == Game.Phase.JOURNAL:
		_open()
	elif visible:
		visible = false


func _open() -> void:
	visible = true
	var focus := _kept(Game.journal_focus)
	if focus == null and _selected:
		focus = _kept(_selected.title)
	if focus == null and not Game.journal.is_empty():
		focus = Game.journal[0]
	_select(focus)
	UiChrome.set_key(_close_keys, Game.settings.key_label("journal"))
	if _selected and _buttons.has(_selected.title):
		(_buttons[_selected.title] as Button).grab_focus.call_deferred()


func _kept(title: String) -> NoteEntry:
	for entry in Game.journal:
		if entry.title == title:
			return entry
	return null


func _select(entry: NoteEntry) -> void:
	_selected = entry
	_smudge = -1
	_hint.text = ""
	_between.modulate.a = 1.0
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var focus_group: HBoxContainer = null
	var focus_text := ""
	if focused is Button and focused.get_parent() == _blots:
		focus_group = _blots
		focus_text = focused.text
	elif focused is Button and focused.get_parent() == _readings:
		focus_group = _readings
		focus_text = focused.text
	_fill_list()
	_empty.visible = Game.journal.is_empty()
	_title.text = _selected.title if _selected else ""
	_body.text = UiChrome.smudge_text(_selected, true) if _selected else ""
	var whole := _selected != null and Game.page_solved(_selected)
	_between.text = _selected.between if whole else ""
	_between.visible = whole
	_fill_blots()
	_fill_readings()
	if focus_group:
		_focus_child(focus_group, focus_text)


func _focus_child(group: HBoxContainer, text_to_find := "") -> void:
	for child in group.get_children():
		var button := child as Button
		if button and not button.disabled and (text_to_find == "" or button.text == text_to_find):
			button.grab_focus()
			return
	if group != _blots:
		_focus_child(_blots)


func _fill_list() -> void:
	for entry in Game.journal:
		if not _buttons.has(entry.title):
			var button := UiChrome.paper_button(entry.title)
			button.focus_mode = Control.FOCUS_ALL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_select.bind(entry))
			_list.add_child(button)
			_buttons[entry.title] = button
		var shown := _buttons[entry.title] as Button
		shown.text = entry.title + ("   (whole)" if Game.page_solved(entry) else "")
		var chosen := _selected != null and _selected.title == entry.title
		shown.add_theme_color_override("font_color", UiChrome.PAPER_INK if chosen else Color(UiChrome.PAPER_INK, 0.55))


func _fill_blots() -> void:
	for child in _blots.get_children():
		_blots.remove_child(child)
		child.queue_free()
	if _selected == null:
		return
	for index in _selected.smudges.size():
		if Game.solved(_selected, index):
			continue
		var word := str((_selected.smudges[index].readings as Array)[0])
		var button := UiChrome.paper_button(UiChrome.blot(_selected.title, index, word.length()))
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = "Try to make it out"
		button.pressed.connect(_pick.bind(index))
		_blots.add_child(button)


func _fill_readings() -> void:
	for child in _readings.get_children():
		_readings.remove_child(child)
		child.queue_free()
	if _selected == null or _smudge < 0 or Game.solved(_selected, _smudge):
		return
	for reading in _readings_of(_selected, _smudge):
		var button := UiChrome.paper_button(str(reading))
		button.focus_mode = Control.FOCUS_ALL
		var tried := _wrong.has("%s|%d|%s" % [_selected.title, _smudge, reading])
		button.disabled = tried
		button.modulate.a = 0.35 if tried else 1.0
		button.pressed.connect(_choose.bind(str(reading)))
		_readings.add_child(button)


func _readings_of(entry: NoteEntry, index: int) -> Array:
	var id := "%s|%d" % [entry.title, index]
	if not _order.has(id):
		var shuffled := (entry.smudges[index].readings as Array).duplicate()
		shuffled.shuffle()
		_order[id] = shuffled
	return _order[id]


func _pick(index: int) -> void:
	if _selected == null or index < 0 or index >= _selected.smudges.size() or Game.solved(_selected, index):
		return
	var key := str(_selected.smudges[index].key)
	if not Game.known(key):
		_smudge = -1
		_hint.text = "I can't make this out yet. " + str(HINTS.get(key.get_slice(":", 0), ""))
		_fill_readings()
		return
	_smudge = index
	_hint.text = ""
	_fill_readings()
	for child in _readings.get_children():
		if not (child as Button).disabled:
			(child as Button).grab_focus()
			break


func _choose(reading: String) -> void:
	if _selected == null or _smudge < 0:
		return
	match Game.decipher(_selected, _smudge, reading):
		Game.Reading.RIGHT:
			_smudge = -1
			_hint.text = ""
			_refresh()
			_focus_child(_blots)
		Game.Reading.WRONG:
			_wrong["%s|%d|%s" % [_selected.title, _smudge, reading]] = true
			_fill_readings()
			_focus_child(_readings)
		Game.Reading.LOCKED:
			_pick(_smudge)


func _on_page_deciphered(entry: NoteEntry) -> void:
	if not visible or _selected == null or entry.title != _selected.title:
		return
	_between.modulate.a = 0.0
	create_tween().tween_property(_between, "modulate:a", 1.0, 1.2)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -540
	panel.offset_right = 540
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", UiChrome.paper(28))
	add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	panel.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(UiChrome.label("Journal", 30, UiChrome.PAPER_INK))
	_empty = UiChrome.label("Nothing yet. The pages she finds are kept here.", 15, Color(UiChrome.PAPER_INK, 0.6))
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_empty)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	left.add_child(_list)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_close_keys = UiChrome.key_row("J", "Close", true)
	footer.add_child(_close_keys)
	var close := UiChrome.paper_button("Close")
	close.focus_mode = Control.FOCUS_ALL
	close.pressed.connect(func() -> void: Game.close_journal())
	footer.add_child(close)
	left.add_child(footer)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	_title = UiChrome.label("", 28, UiChrome.PAPER_INK)
	right.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	scroll.add_child(page)
	_body = UiChrome.page_label(19)
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.meta_clicked.connect(func(meta: Variant) -> void: _pick(int(str(meta))))
	page.add_child(_body)
	_between = UiChrome.label("", 16, Color(UiChrome.PAPER_INK, 0.55))
	_between.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_between)
	_blots = HBoxContainer.new()
	_blots.add_theme_constant_override("separation", 8)
	right.add_child(_blots)
	_hint = UiChrome.label("", 15, Color(UiChrome.PAPER_INK, 0.65))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_hint)
	_readings = HBoxContainer.new()
	_readings.add_theme_constant_override("separation", 10)
	right.add_child(_readings)
