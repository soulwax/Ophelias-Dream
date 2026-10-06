extends Node3D

const CATALOG := "res://assets/characters/presentation_catalog.json"
const CHARACTER := preload("res://scripts/player/creator_character.gd")
const SAVES := "user://characters"

var variants: Array[Dictionary] = []
var selected: int = 0
var _display: Node3D
var _model: Node3D
var _camera: Camera3D
var _title: Label
var _description: Label
var _counter: Label
var _previous: Button
var _next: Button
var _turn: float = 0.0
var _distance: float = 3.8
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _clips: Array[String] = []
var _clip_index: int = 0
var _rest_pose: bool = false
var _animation_label: Label
var _working_configuration: Dictionary = CHARACTER.DEFAULT.duplicate()
var _hair_select: OptionButton
var _outfit_select: OptionButton
var _animation_select: OptionButton
var _name_edit: LineEdit
var _color_controls: Dictionary = {}
var _save_status: Label
var _custom_index: int = -1


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_stage()
	_build_ui()
	_load_catalog()
	var start := OS.get_environment("RUN_PRESENTATION_INDEX")
	var default_index: int = 0
	for index: int in variants.size():
		if variants[index].get("configuration", {}).get("outfit", "") == "elf":
			default_index = index
			break
	show_variant(default_index if start.is_empty() else int(start))
	var capture := OS.get_environment("RUN_PRESENTATION_SHOT")
	if not capture.is_empty():
		_capture(capture)


func _load_catalog() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not parsed is Array:
		push_error("Character presentation catalog must be a JSON array.")
		return
	for entry: Variant in parsed:
		if not entry is Dictionary:
			push_warning("Skipping invalid character catalog entry.")
			continue
		var path: String = str(entry.get("scene", ""))
		if entry.get("configuration") is Dictionary:
			variants.append(entry)
			continue
		if not path.begins_with("res://") or not ResourceLoader.exists(path):
			push_warning("Skipping missing character scene: " + path)
			continue
		if not load(path) is PackedScene:
			push_warning("Skipping character resource that is not a scene: " + path)
			continue
		variants.append(entry)
	var directory := DirAccess.open(SAVES)
	if directory != null:
		for filename: String in directory.get_files():
			if filename.ends_with(".json"):
				var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVES.path_join(filename)))
				if saved is Dictionary and saved.get("configuration") is Dictionary:
					variants.append(saved)


func show_variant(index: int) -> void:
	_animation_player = null
	_skeleton = null
	_clips.clear()
	_rest_pose = false
	if _model != null:
		_display.remove_child(_model)
		_model.queue_free()
		_model = null
	_previous.disabled = variants.size() < 2
	_next.disabled = variants.size() < 2
	if variants.is_empty():
		_title.text = "No characters to present"
		_description.text = "Add a character scene to the presentation catalog."
		_counter.text = "0 / 0"
		return
	selected = posmod(index, variants.size())
	var entry: Dictionary = variants[selected]
	var instance: Node
	if entry.get("configuration") is Dictionary:
		instance = CHARACTER.new()
		_working_configuration = CHARACTER.DEFAULT.duplicate()
		_working_configuration.merge(entry["configuration"], true)
		if _working_configuration.outfit not in CHARACTER.OUTFITS:
			_working_configuration.outfit = "elf"
			_save_status.text = "Retired outfit replaced with the original costume."
		instance.configuration = _working_configuration.duplicate()
	else:
		var packed := load(str(entry["scene"])) as PackedScene
		instance = packed.instantiate()
		_working_configuration = CHARACTER.DEFAULT.duplicate()
		_working_configuration.name = str(entry.get("name", "Mathilda"))
		_working_configuration.outfit = "elf"
		_working_configuration.hair = ["long", "long", "long", "long", "bob", "bun", "braids"][mini(selected, 6)]
		var palette_index := [0, 1, 2, 3, 1, 2, 3][mini(selected, 6)] as int
		_working_configuration.hair_color = ["cfb37d", "d4e2eb", "8c3f26", "292c34"][palette_index]
		_working_configuration.eye_color = ["5d9167", "428ecc", "b77b29", "9874bc"][palette_index]
		_working_configuration.cloth_color = ["4d6235", "3c6eac", "7a2a46", "28655e"][palette_index]
	if not instance is Node3D:
		instance.free()
		_title.text = "Character scene needs a 3D root"
		_description.text = str(entry["scene"])
		_counter.text = "%d / %d" % [selected + 1, variants.size()]
		return
	_model = instance as Node3D
	_model.scale *= maxf(float(entry.get("scale", 1.0)), 0.001)
	_model.rotation.y += deg_to_rad(float(entry.get("yaw_degrees", 0.0)))
	_display.add_child(_model)
	_turn = 0.0
	_display.rotation.y = 0.0
	_frame_model()
	_title.text = str(entry.get("name", "Unnamed character"))
	_description.text = str(entry.get("description", ""))
	_counter.text = "%d / %d" % [selected + 1, variants.size()]
	_build_animation_preview()
	_sync_creator_controls()


func _sync_creator_controls() -> void:
	_hair_select.select(maxi(CHARACTER.HAIRS.find(_working_configuration.hair), 0))
	_outfit_select.select(maxi(CHARACTER.OUTFITS.find(_working_configuration.outfit), 0))
	_name_edit.text = str(_working_configuration.name)
	for key: String in _color_controls:
		(_color_controls[key] as ColorPickerButton).color = Color.html(str(_working_configuration[key]))


func _ensure_custom() -> void:
	if _custom_index < 0:
		_custom_index = variants.size()
		variants.append({"name": "Custom design", "description": "Your character, your choices.", "configuration": {}, "scale": 0.8})
	variants[_custom_index]["configuration"] = _working_configuration.duplicate()
	variants[_custom_index]["name"] = str(_working_configuration.name)


func _change_component(key: String, value: String) -> void:
	_working_configuration[key] = value
	_ensure_custom()
	var turn := _turn
	var clip := _clips[_clip_index] if not _clips.is_empty() else "Idle"
	show_variant(_custom_index)
	_turn = turn
	_display.rotation.y = turn
	var index := _clips.find(clip)
	if index >= 0:
		show_animation(index)
	_save_status.text = "Unsaved design"


func _change_color(key: String, value: Color) -> void:
	_working_configuration[key] = value.to_html(false)
	_ensure_custom()
	if not _model.has_method("apply_colors"):
		show_variant(_custom_index)
	else:
		_model.configuration = _working_configuration.duplicate()
		_model.apply_colors()
	selected = _custom_index
	_counter.text = "%d / %d" % [selected + 1, variants.size()]
	_title.text = str(_working_configuration.name)
	_save_status.text = "Unsaved design"


func save_design() -> String:
	_working_configuration.name = _name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else "Mathilda"
	DirAccess.make_dir_recursive_absolute(SAVES)
	var entry := {"name": _working_configuration.name, "description": "Saved character design", "configuration": _working_configuration.duplicate(), "scale": 0.8}
	var filename := "%s_%d_%d.json" % [str(_working_configuration.name).validate_filename(), int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	var path := SAVES.path_join(filename)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_save_status.text = "Could not save this design"
		return ""
	file.store_string(JSON.stringify(entry, "\t"))
	file.close()
	variants.append(entry)
	selected = variants.size() - 1
	_counter.text = "%d / %d" % [selected + 1, variants.size()]
	_title.text = str(_working_configuration.name)
	_description.text = "Saved character design"
	_save_status.text = "Saved • available in the collection"
	return path


func _randomize_design() -> void:
	_working_configuration.hair = CHARACTER.HAIRS.pick_random()
	_working_configuration.outfit = CHARACTER.OUTFITS.pick_random()
	_working_configuration.hair_color = ["32231e", "a96740", "d3b884", "d8dfe5", "392e48"].pick_random()
	_working_configuration.eye_color = ["629789", "5d97b6", "af8440", "8874a7"].pick_random()
	_working_configuration.cloth_color = ["354e60", "69364b", "3b5649", "857a69"].pick_random()
	_change_component("hair", str(_working_configuration.hair))


func _build_animation_preview() -> void:
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		_animation_label.text = "No character skeleton"
		return
	for node: Node in _model.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop()
	for node: Node in _model.find_children("*", "AnimationTree", true, false):
		(node as AnimationTree).active = false
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "PresentationAnimations"
	_skeleton.get_parent().add_child(_animation_player)
	_animation_player.root_node = NodePath("..")
	var paths := {
		"": "res://assets/characters/styloo_elf/elf_animations.res",
		"Feminine": "res://assets/characters/styloo_elf/feminine/elf_feminine.res",
	}
	for library_name: String in paths:
		var source := load(paths[library_name]) as AnimationLibrary
		if source == null:
			continue
		var library := source.duplicate(true) as AnimationLibrary
		for clip: StringName in library.get_animation_list():
			library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_animation_player.add_animation_library(library_name, library)
	if _animation_player.has_animation("Idle"):
		_clips.append("Idle")
	for clip: String in _animation_player.get_animation_list():
		if clip != "Idle" and clip != "RESET" and not clip.ends_with("/RESET"):
			_clips.append(clip)
	_clip_index = 0
	_animation_select.clear()
	for clip: String in _clips:
		_animation_select.add_item(clip.replace("_", " "))
	_skeleton.reset_bone_poses()
	show_animation(0)


func show_animation(index: int) -> void:
	if _animation_player == null or _clips.is_empty():
		return
	_clip_index = posmod(index, _clips.size())
	if _rest_pose:
		_skeleton.reset_bone_poses()
	_rest_pose = false
	_animation_player.play(_clips[_clip_index], 0.18)
	_animation_player.advance(0.0)
	_animation_label.text = "↑ / ↓ Animation: %s   (%d / %d)" % [_clips[_clip_index].replace("_", " "), _clip_index + 1, _clips.size()]
	_animation_select.select(_clip_index)


func _toggle_t_pose() -> void:
	if _skeleton == null or _animation_player == null:
		return
	if _rest_pose:
		show_animation(_clip_index)
		return
	_animation_player.stop()
	_skeleton.reset_bone_poses()
	# The imported rest is an A pose. Straighten both arm chains into a T
	# without modifying the skeleton's bind/rest transforms.
	for side: String in ["L", "R"]:
		var direction := Vector3.RIGHT if side == "L" else Vector3.LEFT
		_point_bone("DEF-upper_arm." + side, "DEF-forearm." + side, direction)
		_point_bone("DEF-forearm." + side, "DEF-hand." + side, direction)
	_rest_pose = true
	_animation_label.text = "T pose   •   X to resume animation"


func _point_bone(name: String, child_name: String, direction: Vector3) -> void:
	_skeleton.force_update_all_bone_transforms()
	var bone := _skeleton.find_bone(name)
	var child := _skeleton.find_bone(child_name)
	if bone < 0 or child < 0:
		return
	var current := _skeleton.get_bone_global_pose(bone)
	var axis := (_skeleton.get_bone_global_pose(child).origin - current.origin).normalized()
	var turn := Basis(Quaternion(axis, direction))
	_skeleton.set_bone_global_pose(bone, Transform3D(turn * current.basis, current.origin))
	_skeleton.force_update_all_bone_transforms()


func _frame_model() -> void:
	var bounds := AABB()
	var found: bool = false
	var inverse := _display.global_transform.affine_inverse()
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if _model is MeshInstance3D:
		var mesh := _model as MeshInstance3D
		var box: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found:
		return
	_model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var height := maxf(bounds.size.y, 0.5)
	var width := maxf(bounds.size.x, bounds.size.z)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_fov := deg_to_rad(_camera.fov * 0.5)
	_distance = maxf(height * 0.7 / tan(half_fov), width * 0.7 / (tan(half_fov) * aspect))
	_camera.position = Vector3(0.0, height * 0.55, _distance)
	_camera.look_at(Vector3(0.0, height * 0.5, 0.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				show_variant(selected - 1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				show_variant(selected + 1)
				get_viewport().set_input_as_handled()
			KEY_HOME:
				show_variant(selected)
				get_viewport().set_input_as_handled()
			KEY_UP:
				show_animation(_clip_index + 1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				show_animation(_clip_index - 1)
				get_viewport().set_input_as_handled()
			KEY_X:
				_toggle_t_pose()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				get_tree().quit()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_turn += event.relative.x * 0.008
		_display.rotation.y = _turn
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.position.z = maxf(_camera.position.z * 0.9, _distance * 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.position.z = minf(_camera.position.z * 1.1, _distance * 2.5)


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("18232d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8e6ef")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 145.0, 0.0)
	fill.light_color = Color("b8d5ef")
	fill.light_energy = 0.7
	add_child(fill)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.8
	floor_mesh.bottom_radius = 1.8
	floor_mesh.height = 0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("344653")
	material.roughness = 0.85
	floor_mesh.material = material
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.04
	add_child(floor_node)
	_display = Node3D.new()
	_display.name = "DisplayedCharacter"
	add_child(_display)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 38.0
	_camera.h_offset = 0.33
	_camera.position = Vector3(0.0, 1.0, _distance)
	add_child(_camera)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_right", 390)
	root.add_theme_constant_override("margin_top", 28)
	root.add_theme_constant_override("margin_bottom", 28)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	var heading := Label.new()
	heading.text = "MATHILDA  /  CHARACTER STUDIO"
	heading.add_theme_color_override("font_color", Color("a9c5d8"))
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	column.add_child(_title)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_color_override("font_color", Color("bdcbd5"))
	column.add_child(_description)
	_animation_label = Label.new()
	_animation_label.add_theme_color_override("font_color", Color("a9c5d8"))
	column.add_child(_animation_label)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	_previous = Button.new()
	_previous.text = "← Previous"
	_previous.focus_mode = Control.FOCUS_NONE
	_previous.custom_minimum_size = Vector2(160.0, 48.0)
	_previous.pressed.connect(func() -> void: show_variant(selected - 1))
	row.add_child(_previous)
	_counter = Label.new()
	_counter.custom_minimum_size.x = 90.0
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_counter)
	_next = Button.new()
	_next.text = "Next →"
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size = Vector2(160.0, 48.0)
	_next.pressed.connect(func() -> void: show_variant(selected + 1))
	row.add_child(_next)
	var hint := Label.new()
	hint.text = "← / → Characters   •   ↑ / ↓ Animations   •   X T pose   •   Drag to turn   •   Wheel to zoom   •   Home reset   •   Esc close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("a9c5d8"))
	column.add_child(hint)
	_build_creator_panel(layer)


func _build_creator_panel(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -350.0
	panel.offset_right = -24.0
	panel.offset_top = 24.0
	panel.offset_bottom = -24.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c27")
	style.border_color = Color("405668")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "CREATE A CHARACTER"
	title.add_theme_font_size_override("font_size", 21)
	column.add_child(title)
	var intro := Label.new()
	intro.text = "Mix silhouettes. Make her yours."
	intro.add_theme_color_override("font_color", Color("9bb2c3"))
	column.add_child(intro)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Character name"
	_name_edit.text = "Mathilda"
	_name_edit.text_changed.connect(func(value: String) -> void:
		_working_configuration.name = value
		_ensure_custom()
		_title.text = value)
	column.add_child(_name_edit)
	_creator_label(column, "HAIRSTYLE")
	_hair_select = OptionButton.new()
	for name: String in ["Long • original", "Frost bob", "Gathered bun", "Twin braids"]:
		_hair_select.add_item(name)
	_hair_select.item_selected.connect(func(index: int) -> void: _change_component("hair", CHARACTER.HAIRS[index]))
	column.add_child(_hair_select)
	_creator_label(column, "OUTFIT")
	_outfit_select = OptionButton.new()
	for name: String in ["Elf • original costume"]:
		_outfit_select.add_item(name)
	_outfit_select.disabled = true
	_outfit_select.item_selected.connect(func(index: int) -> void: _change_component("outfit", CHARACTER.OUTFITS[index]))
	column.add_child(_outfit_select)
	var outfit_note := Label.new()
	outfit_note.text = "New garments are being rebuilt from the source body."
	outfit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outfit_note.add_theme_color_override("font_color", Color("9bb2c3"))
	column.add_child(outfit_note)
	for key: String in ["hair_color", "eye_color", "cloth_color", "trim_color"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = {"hair_color": "Hair", "eye_color": "Eyes", "cloth_color": "Cloth", "trim_color": "Trim"}[key]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(116, 34)
		picker.edit_alpha = false
		picker.color = Color.html(str(_working_configuration[key]))
		picker.color_changed.connect(func(value: Color) -> void: _change_color(key, value))
		row.add_child(picker)
		_color_controls[key] = picker
		column.add_child(row)
	_creator_label(column, "MOTION PREVIEW")
	_animation_select = OptionButton.new()
	_animation_select.item_selected.connect(show_animation)
	column.add_child(_animation_select)
	var pose := Button.new()
	pose.text = "X  •  Toggle T pose"
	pose.pressed.connect(_toggle_t_pose)
	column.add_child(pose)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	column.add_child(spacer)
	var randomize := Button.new()
	randomize.text = "Surprise me"
	randomize.pressed.connect(_randomize_design)
	column.add_child(randomize)
	var save := Button.new()
	save.text = "Save character"
	save.pressed.connect(func() -> void: save_design())
	column.add_child(save)
	var reset := Button.new()
	reset.text = "Reset design"
	reset.pressed.connect(func() -> void:
		_working_configuration = CHARACTER.DEFAULT.duplicate()
		_change_component("hair", str(_working_configuration.hair)))
	column.add_child(reset)
	_save_status = Label.new()
	_save_status.text = "Designs are saved on this computer."
	_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_status.add_theme_color_override("font_color", Color("9bb2c3"))
	column.add_child(_save_status)
	for control: Control in column.get_children():
		if control is Button:
			control.focus_mode = Control.FOCUS_NONE
			(control as Button).clip_text = true


func _creator_label(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("91aabd"))
	column.add_child(label)


func _capture(path: String) -> void:
	for frame: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Presentation capture failed: %s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
