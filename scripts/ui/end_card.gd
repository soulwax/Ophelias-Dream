class_name EndCard
extends Control

var _title: Label
var _body: Label
var _again: Button
var _hint: Label
# A catch after the lookout sends her back there; an ending starts a new run.
var _from_checkpoint := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	Game.phase_changed.connect(_on_phase)


func _on_phase(next: Game.Phase) -> void:
	match next:
		Game.Phase.CAUGHT:
			var title := Game.ending_title if Game.ending_title != "" else "It caught you"
			var body := Game.ending_body if Game.ending_body != "" else "You stopped. The snow closed over the place you were."
			_show(title, body, "Back to the lookout" if not Game.checkpoint.is_empty() else "Wake in the cabin")
			_from_checkpoint = not Game.checkpoint.is_empty()
		Game.Phase.ESCAPED:
			if Game.mathilda_pov:
				# Her chapter's endings name themselves (MathildaPov.ENDINGS).
				_show(Game.ending_title, Game.ending_body, "Return to the menu")
				_hint.text = ""
			elif Game.ending_title != "":
				# Mathilda is gone, or the meeting on the ice: named by Game.
				_show(Game.ending_title, Game.ending_body, "Walk the ridge again")
			elif Game.turned_around:
				var prints := "You turned around. Out on the lake, one set of prints goes to the old hole in the ice, and one set comes back. Only ever yours. The ice is singing; it always was."
				if Game.all_deciphered():
					prints += " By the hole, two cups, one fitted inside the other."
				_show("One set of prints", prints, "Walk the ridge again")
			else:
				var lake := "The posts end at the lake. Two sets of prints go out to the old hole in the ice, and two come back, close together, as if one of them was holding the other up."
				if Game.read_last_page:
					lake += " You didn't turn around."
				if Game.all_deciphered():
					lake += " By the hole, a cup in the snow. Beside it, a second one. Still warm."
				_show("The lake", lake, "Walk the ridge again")
			_from_checkpoint = false
		_:
			visible = false


func _show(title: String, body: String, action: String) -> void:
	_title.text = title
	_body.text = body
	_again.text = action
	_hint.text = "%s does the same." % Game.settings.key_label("restart")
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -380
	card.offset_right = 380
	card.offset_top = -160
	card.offset_bottom = 160
	card.add_theme_stylebox_override("panel", UiChrome.plate(32, 8))
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)

	_title = UiChrome.label("", 42)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_body = UiChrome.label("", 18, UiChrome.MUTED)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(640, 0)
	box.add_child(_body)

	_again = UiChrome.text_button("Wake in the cabin")
	_again.pressed.connect(func() -> void:
		Game.mathilda_pov = false
		Game.restart(_from_checkpoint))
	box.add_child(_again)

	_hint = UiChrome.label("R does the same.", 13, UiChrome.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)
