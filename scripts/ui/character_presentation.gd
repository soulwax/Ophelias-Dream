extends Node3D

const CATALOG := "res://assets/characters/presentation_catalog.json"

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


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_stage()
	_build_ui()
	_load_catalog()
	show_variant(int(OS.get_environment("RUN_PRESENTATION_INDEX")))
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
		if not path.begins_with("res://") or not ResourceLoader.exists(path):
			push_warning("Skipping missing character scene: " + path)
			continue
		if not load(path) is PackedScene:
			push_warning("Skipping character resource that is not a scene: " + path)
			continue
		variants.append(entry)


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
	var packed := load(str(entry["scene"])) as PackedScene
	var instance := packed.instantiate()
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
	_camera.position = Vector3(0.0, 1.0, _distance)
	add_child(_camera)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_right", 40)
	root.add_theme_constant_override("margin_top", 28)
	root.add_theme_constant_override("margin_bottom", 28)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	var heading := Label.new()
	heading.text = "CHARACTER COLLECTION"
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


func _capture(path: String) -> void:
	for frame: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Presentation capture failed: %s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
