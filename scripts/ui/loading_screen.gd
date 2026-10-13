class_name LoadingScreen
extends CanvasLayer

var _veil: ColorRect
var _caption: Label
var _percent: Label
var _fill: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = UiChrome.VOID
	add_child(_veil)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_CENTER)
	stack.offset_left = -260.0
	stack.offset_right = 260.0
	stack.offset_top = -48.0
	stack.offset_bottom = 48.0
	stack.add_theme_constant_override("separation", 12)
	_veil.add_child(stack)

	var heading := UiChrome.term_label("PASSAGE / TRANSITION", 15, UiChrome.BONE, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	_caption = UiChrome.term_label("PREPARING THE THRESHOLD", 11, UiChrome.ASH)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_caption)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(520.0, 3.0)
	track.color = UiChrome.SIGNAL_DIM
	stack.add_child(track)
	_fill = ColorRect.new()
	_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill.anchor_right = 0.0
	_fill.offset_right = 0.0
	_fill.color = UiChrome.SIGNAL
	track.add_child(_fill)

	_percent = UiChrome.term_label("00%", 10, UiChrome.ASH)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_percent)


func set_progress(value: float, caption := "PREPARING THE THRESHOLD") -> void:
	var progress := clampf(value, 0.0, 1.0)
	_caption.text = caption
	_percent.text = "%02d%%" % roundi(progress * 100.0)
	_fill.anchor_right = progress
	_fill.offset_right = 0.0


func dismiss() -> void:
	set_progress(1.0, "THE WAY IS OPEN")
	await get_tree().process_frame
	var fade := create_tween()
	fade.tween_property(_veil, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade.finished
	queue_free()
