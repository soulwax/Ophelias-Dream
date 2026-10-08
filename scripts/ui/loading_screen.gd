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
	_veil.color = Color("08090d")
	add_child(_veil)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_CENTER)
	stack.offset_left = -260.0
	stack.offset_right = 260.0
	stack.offset_top = -48.0
	stack.offset_bottom = 48.0
	stack.add_theme_constant_override("separation", 12)
	_veil.add_child(stack)

	var heading := Label.new()
	heading.text = "PASSAGE / TRANSITION"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("d5cec7"))
	heading.add_theme_font_size_override("font_size", 15)
	stack.add_child(heading)

	_caption = Label.new()
	_caption.text = "PREPARING THE THRESHOLD"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", Color("a7928e"))
	_caption.add_theme_font_size_override("font_size", 11)
	stack.add_child(_caption)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(520.0, 3.0)
	track.color = Color("302226")
	stack.add_child(track)
	_fill = ColorRect.new()
	_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill.anchor_right = 0.0
	_fill.offset_right = 0.0
	_fill.color = Color("a63430")
	track.add_child(_fill)

	_percent = Label.new()
	_percent.text = "00%"
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.add_theme_color_override("font_color", Color("766a68"))
	_percent.add_theme_font_size_override("font_size", 10)
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
