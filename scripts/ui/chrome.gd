class_name UiChrome
extends RefCounted

const INK := Color(0.94, 0.95, 0.96)
const MUTED := Color(0.72, 0.75, 0.79)
const RUST := Color(0.95, 0.48, 0.4)
const PAPER := Color(0.91, 0.87, 0.78)
const PAPER_INK := Color(0.17, 0.14, 0.11)
# Scratched-out words on a page: the letters a blot is drawn with, and its ink.
const BLOT := "xqvlmnrwzhk"
const BLOT_INK := Color(0.42, 0.33, 0.25, 0.85)

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


static func keycap(on_paper := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var ink := PAPER_INK if on_paper else Color.WHITE
	style.bg_color = Color(ink.r, ink.g, ink.b, 0.1 if on_paper else 0.12)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.border_color = Color(ink.r, ink.g, ink.b, 0.3 if on_paper else 0.16)
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


static func key_row(keys: String, caption: String, on_paper := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", keycap(on_paper))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.custom_minimum_size = Vector2(64, 28)
	var key := label(keys, 14, PAPER_INK if on_paper else INK)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(key)
	row.add_child(cap)
	row.add_child(label(caption, 16, Color(PAPER_INK.r, PAPER_INK.g, PAPER_INK.b, 0.72) if on_paper else MUTED))
	row.custom_minimum_size.x = 210
	return row


# Relabels the keycap of a key_row, for keys that follow the bindings.
static func set_key(row: HBoxContainer, keys: String) -> void:
	var cap := row.get_child(0) as PanelContainer
	if cap and cap.get_child_count() > 0:
		(cap.get_child(0) as Label).text = keys


# The look of the Esc menu's own controls: sliders, toggles, dropdowns and
# the scroll bar, in the plate palette.
static func menu_theme() -> Theme:
	var theme := Theme.new()
	theme.set_color("font_color", "Label", INK)
	for kind in ["Button", "OptionButton", "CheckButton"]:
		theme.set_font_size("font_size", kind, 15)
		theme.set_color("font_color", kind, INK)
		theme.set_color("font_hover_color", kind, Color.WHITE)
		theme.set_color("font_pressed_color", kind, Color.WHITE)
		theme.set_color("font_hover_pressed_color", kind, Color.WHITE)
		theme.set_color("font_focus_color", kind, INK)
	for kind in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, button_style(Color(1, 1, 1, 0.08)))
		theme.set_stylebox("hover", kind, button_style(Color(1, 1, 1, 0.16)))
		theme.set_stylebox("pressed", kind, button_style(Color(1, 1, 1, 0.24)))
		theme.set_stylebox("hover_pressed", kind, button_style(Color(1, 1, 1, 0.24)))
		theme.set_stylebox("focus", kind, StyleBoxEmpty.new())
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.7)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	var lit := fill.duplicate() as StyleBoxFlat
	lit.bg_color = PAPER
	theme.set_stylebox("grabber_area_highlight", "HSlider", lit)
	var menu := plate(8, 6)
	menu.bg_color = Color(0.08, 0.09, 0.11, 0.98)
	theme.set_stylebox("panel", "PopupMenu", menu)
	theme.set_stylebox("hover", "PopupMenu", button_style(Color(1, 1, 1, 0.14)))
	theme.set_color("font_color", "PopupMenu", MUTED)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_font_size("font_size", "PopupMenu", 15)
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(1, 1, 1, 0.05)
	bar.set_corner_radius_all(3)
	bar.content_margin_left = 3
	bar.content_margin_right = 3
	theme.set_stylebox("scroll", "VScrollBar", bar)
	var thumb := bar.duplicate() as StyleBoxFlat
	thumb.bg_color = Color(1, 1, 1, 0.22)
	theme.set_stylebox("grabber", "VScrollBar", thumb)
	var thumb_lit := bar.duplicate() as StyleBoxFlat
	thumb_lit.bg_color = Color(1, 1, 1, 0.36)
	theme.set_stylebox("grabber_highlight", "VScrollBar", thumb_lit)
	theme.set_stylebox("grabber_pressed", "VScrollBar", thumb_lit)
	return theme


# --- Terminal (the Esc menu) ----------------------------------------------
# Bone text on a near-black screen with one signal red: the colours of an old
# instrument console. Fonts are the system's (Bahnschrift for headings,
# Consolas for everything read), with fallbacks for other systems.

const VOID := Color(0.035, 0.03, 0.034, 0.97)
const SIGNAL := Color(0.86, 0.12, 0.16)
const SIGNAL_DIM := Color(0.46, 0.07, 0.09)
const BONE := Color(0.91, 0.89, 0.85)
const ASH := Color(0.56, 0.54, 0.53)
const SOOT := Color(0.06, 0.035, 0.035)

static var _mono: FontVariation
static var _display: FontVariation


## The console's reading face, tracked out a little.
static func mono_font() -> Font:
	if _mono == null:
		var base := SystemFont.new()
		base.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
		_mono = FontVariation.new()
		_mono.base_font = base
		_mono.spacing_glyph = 1
	return _mono


## The heading face: condensed, technical, tracked wide.
static func display_font() -> Font:
	if _display == null:
		var base := SystemFont.new()
		base.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Arial Narrow", "Roboto Condensed", "sans-serif"])
		base.font_weight = 600
		base.font_stretch = 87
		_display = FontVariation.new()
		_display.base_font = base
		_display.spacing_glyph = 3
	return _display


static func term_label(text: String, size: int, color: Color = BONE, heading := false) -> Label:
	var node := label(text, size, color)
	node.add_theme_font_override("font", display_font() if heading else mono_font())
	return node


static func term_box(fill: Color, border: Color = Color(0, 0, 0, 0), width := 0, margin := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	style.content_margin_left = margin + 6
	style.content_margin_right = margin + 6
	style.anti_aliasing = false
	return style


static func _square(size: Vector2i, color: Color) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


## Square edges, one red, thin rules. Type variations: TermTab (the page
## list), TermAction (resume, restart, quit), TermField (a value you cycle or
## a key you rebind).
static func term_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = mono_font()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", BONE)
	var clear := Color(0, 0, 0, 0)
	for kind in ["Button", "TermTab", "TermAction", "TermField"]:
		if kind != "Button":
			theme.set_type_variation(kind, "Button")
		theme.set_color("font_color", kind, BONE)
		theme.set_color("font_hover_color", kind, Color.WHITE)
		theme.set_color("font_focus_color", kind, Color.WHITE)
		theme.set_color("font_pressed_color", kind, Color.WHITE)
		theme.set_color("font_hover_pressed_color", kind, Color.WHITE)
		theme.set_color("font_disabled_color", kind, ASH)
		theme.set_stylebox("disabled", kind, term_box(clear, Color(BONE, 0.08), 1))
	# Plain buttons (the page reset).
	theme.set_stylebox("normal", "Button", term_box(clear, Color(BONE, 0.22), 1))
	theme.set_stylebox("hover", "Button", term_box(Color(SIGNAL, 0.16), SIGNAL, 1))
	theme.set_stylebox("pressed", "Button", term_box(SIGNAL, SIGNAL, 1))
	theme.set_stylebox("hover_pressed", "Button", term_box(SIGNAL, SIGNAL, 1))
	theme.set_stylebox("focus", "Button", term_box(clear, SIGNAL, 1))
	# Pages: the open one is a solid red block with dark letters.
	var tab_focus := term_box(clear)
	tab_focus.border_color = SIGNAL
	tab_focus.border_width_left = 3
	theme.set_stylebox("normal", "TermTab", term_box(clear))
	theme.set_stylebox("hover", "TermTab", term_box(Color(BONE, 0.06)))
	theme.set_stylebox("pressed", "TermTab", term_box(SIGNAL))
	theme.set_stylebox("hover_pressed", "TermTab", term_box(SIGNAL))
	theme.set_stylebox("focus", "TermTab", tab_focus)
	theme.set_color("font_color", "TermTab", ASH)
	theme.set_color("font_pressed_color", "TermTab", SOOT)
	theme.set_color("font_hover_pressed_color", "TermTab", SOOT)
	theme.set_color("font_focus_color", "TermTab", BONE)
	theme.set_font_size("font_size", "TermTab", 15)
	# Actions: quiet until pointed at.
	theme.set_stylebox("normal", "TermAction", term_box(clear))
	theme.set_stylebox("hover", "TermAction", term_box(Color(BONE, 0.06)))
	theme.set_stylebox("pressed", "TermAction", term_box(Color(SIGNAL, 0.3)))
	theme.set_stylebox("focus", "TermAction", tab_focus)
	theme.set_color("font_color", "TermAction", ASH)
	theme.set_font_size("font_size", "TermAction", 14)
	# Fields.
	theme.set_stylebox("normal", "TermField", term_box(Color(BONE, 0.035), Color(BONE, 0.14), 1, 6))
	theme.set_stylebox("hover", "TermField", term_box(Color(SIGNAL, 0.12), Color(SIGNAL, 0.7), 1, 6))
	theme.set_stylebox("pressed", "TermField", term_box(Color(SIGNAL, 0.3), SIGNAL, 1, 6))
	theme.set_stylebox("hover_pressed", "TermField", term_box(Color(SIGNAL, 0.3), SIGNAL, 1, 6))
	theme.set_stylebox("focus", "TermField", term_box(clear, SIGNAL, 1, 6))
	theme.set_font_size("font_size", "TermField", 14)
	# Sliders: a hairline track filled red, a bone bar for the grabber.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(BONE, 0.12)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = SIGNAL_DIM
	theme.set_stylebox("grabber_area", "HSlider", fill)
	var lit := track.duplicate() as StyleBoxFlat
	lit.bg_color = SIGNAL
	theme.set_stylebox("grabber_area_highlight", "HSlider", lit)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = SIGNAL
	ring.set_border_width_all(1)
	ring.set_expand_margin_all(5)
	theme.set_stylebox("focus", "HSlider", ring)
	theme.set_icon("grabber", "HSlider", _square(Vector2i(6, 18), BONE))
	theme.set_icon("grabber_highlight", "HSlider", _square(Vector2i(6, 18), Color.WHITE))
	theme.set_icon("grabber_disabled", "HSlider", _square(Vector2i(6, 18), ASH))
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(BONE, 0.04)
	bar.content_margin_left = 2
	bar.content_margin_right = 2
	theme.set_stylebox("scroll", "VScrollBar", bar)
	var thumb := bar.duplicate() as StyleBoxFlat
	thumb.bg_color = Color(BONE, 0.25)
	theme.set_stylebox("grabber", "VScrollBar", thumb)
	var thumb_lit := bar.duplicate() as StyleBoxFlat
	thumb_lit.bg_color = SIGNAL
	theme.set_stylebox("grabber_highlight", "VScrollBar", thumb_lit)
	theme.set_stylebox("grabber_pressed", "VScrollBar", thumb_lit)
	return theme


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


## The letters a smudge is scratched out with: the same for that smudge on
## every page view, at least three long.
static func blot(title: String, index: int, length: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title + "#" + str(index))
	var out := ""
	for _i in maxi(length, 3):
		out += BLOT[rng.randi() % BLOT.length()]
	return out


## A page body as BBCode: solved smudges underlined in ink, the rest scratched
## out. links: each unsolved smudge is a [url=<index>] the journal can click.
static func smudge_text(entry: NoteEntry, links := false) -> String:
	var text := entry.body.replace("[", "[lb]")
	for index in entry.smudges.size():
		var word := str((entry.smudges[index].readings as Array)[0])
		var shown: String
		if Game.solved(entry, index):
			shown = "[u]%s[/u]" % word
		else:
			shown = "[s][color=#%s]%s[/color][/s]" % [BLOT_INK.to_html(true), blot(entry.title, index, word.length())]
			if links:
				shown = "[url=%d]%s[/url]" % [index, shown]
		text = text.replace("{%d}" % index, shown)
	return text


## The paper's text: BBCode, wrapping, ink on paper, growing with its text.
static func page_label(size: int) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.bbcode_enabled = true
	node.fit_content = true
	node.scroll_active = false
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("normal_font_size", size)
	node.add_theme_color_override("default_color", PAPER_INK)
	node.add_theme_constant_override("line_separation", 6)
	return node
