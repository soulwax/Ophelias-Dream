extends Node3D

const CATALOG := "res://assets/characters/presentation_catalog.json"
const LOCAL_ASSET_BANK_CATALOG := "res://assets/characters/asset_bank/presentation_catalog.local.json"
const CHARACTER := preload("res://scripts/player/creator_character.gd")
const SAVES := "user://characters"
const STAGE_TOP := 0.06
const KENNEY_PREVIEW_PALETTES := [
	{"outfit": "536c7b", "head": "c99e7b"},
	{"outfit": "6d536b", "head": "d5ad8b"},
	{"outfit": "536c60", "head": "c58f71"},
	{"outfit": "75664f", "head": "d8b895"},
	{"outfit": "4d6275", "head": "c99576"},
	{"outfit": "71584c", "head": "d0a685"},
]

var variants: Array[Dictionary] = []
var selected: int = 0
var _display: Node3D
var _model: Node3D
var _camera: Camera3D
var _title: Label
var _description: Label
var _counter: Label
var _heading: Label
var _creator_panel: PanelContainer
var _previous: Button
var _next: Button
var _turn: float = 0.0
var _distance: float = 3.8
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _clips: Array[String] = []
var _collection_select: OptionButton
var _collection_values: Array[String] = []
var _visible_indices: Array[int] = []
var _active_collection: String = ""
var _clip_index: int = 0
var _use_embedded_animations: bool = false
var _rest_pose: bool = false
var _animation_label: Label
var _pose_button: Button
var _hint: Label
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
	_load_local_asset_bank_catalog()
	_build_collection_filter()
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


func _load_local_asset_bank_catalog() -> void:
	# Owner-supplied packs remain local and ignored by Git. Their optional catalog lets
	# the showcase include them on this machine without publishing paths or metadata.
	if not FileAccess.file_exists(LOCAL_ASSET_BANK_CATALOG):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCAL_ASSET_BANK_CATALOG))
	if not parsed is Array:
		push_warning("Local character asset-bank catalog must be a JSON array.")
		return
	for entry: Variant in parsed:
		if not entry is Dictionary:
			push_warning("Skipping invalid local character catalog entry.")
			continue
		var path := str(entry.get("scene", ""))
		if not path.begins_with("res://") or not ResourceLoader.exists(path) or not load(path) is PackedScene:
			push_warning("Skipping missing local character scene: " + path)
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
	_previous.disabled = _visible_indices.size() < 2
	_next.disabled = _visible_indices.size() < 2
	if variants.is_empty():
		_title.text = "No characters to present"
		_description.text = "Add a character scene to the presentation catalog."
		_counter.text = "0 / 0"
		return
	selected = posmod(index, variants.size())
	var entry: Dictionary = variants[selected]
	_use_embedded_animations = bool(entry.get("embedded_animations", false))
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
	_model.visible = true
	for node: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).visible = true
	_display.add_child(_model)
	_apply_preview_materials(entry)
	var creator_supported := _supports_creator(entry)
	_creator_panel.visible = creator_supported
	_camera.h_offset = 0.33 if creator_supported else 0.0
	_turn = 0.0
	_display.rotation.y = 0.0
	_frame_model()
	_title.text = str(entry.get("name", "Unnamed character"))
	_description.text = str(entry.get("description", ""))
	_update_counter()
	_heading.text = "MATHILDA  /  CHARACTER STUDIO" if creator_supported else "CHARACTER COLLECTION  /  MODEL PREVIEW"
	_build_animation_preview()
	_pose_button.visible = _supports_t_pose()
	_pose_button.disabled = not _pose_button.visible
	if _pose_button.visible:
		_hint.text = "← / → Characters   •   ↑ / ↓ Animations   •   X T pose   •   Drag to turn   •   Wheel to zoom   •   Home reset   •   Esc close"
	else:
		_hint.text = "← / → Characters   •   ↑ / ↓ Animations   •   Drag to turn   •   Wheel to zoom   •   Home reset   •   Esc close"
	_sync_creator_controls()


func _supports_creator(entry: Dictionary) -> bool:
	if entry.get("configuration") is Dictionary:
		return true
	var scene_path := str(entry.get("scene", ""))
	return scene_path.begins_with("res://assets/characters/styloo_elf/") or scene_path.begins_with("res://assets/characters/variants/") or scene_path.begins_with("res://assets/characters/hairstyles/")


func _entry_collection(entry: Dictionary) -> String:
	if entry.has("collection"):
		return str(entry["collection"])
	if entry.get("configuration") is Dictionary:
		return "Character Studio · Saved Designs"
	var scene_path := str(entry.get("scene", ""))
	if scene_path.begins_with("res://assets/characters/styloo_elf/presentation/"):
		return "Styloo · Mage, Dwarf and Knight"
	if scene_path.begins_with("res://assets/characters/styloo_elf/"):
		return "Styloo · Elf"
	if scene_path.begins_with("res://assets/characters/kenney_female/"):
		return "Kenney · Mini Characters"
	if scene_path.begins_with("res://assets/characters/quaternius_animated_women/"):
		return "Quaternius · Animated Women"
	if scene_path.begins_with("res://assets/characters/quaternius_modular_women/"):
		return "Quaternius · Modular Women"
	if scene_path.begins_with("res://assets/characters/variants/") or scene_path.begins_with("res://assets/characters/hairstyles/"):
		return "Character Studio · Variants"
	return "Project Characters"


func _build_collection_filter() -> void:
	if _collection_select == null:
		return
	var counts: Dictionary = {}
	for entry: Dictionary in variants:
		var collection := _entry_collection(entry)
		counts[collection] = int(counts.get(collection, 0)) + 1
	_collection_values.clear()
	_collection_values.append("")
	var labels: Array[String] = []
	for value: Variant in counts.keys():
		labels.append(str(value))
	labels.sort()
	_collection_values.append_array(labels)
	_collection_select.clear()
	_collection_select.add_item("All characters · %d" % variants.size())
	_collection_select.set_item_metadata(0, "")
	for collection: String in labels:
		_collection_select.add_item("%s · %d" % [collection, int(counts[collection])])
		_collection_select.set_item_metadata(_collection_select.item_count - 1, collection)
	_collection_select.select(0)
	_active_collection = ""
	_refresh_visible_indices()


func _on_collection_selected(option_index: int) -> void:
	if option_index < 0 or option_index >= _collection_values.size():
		return
	_active_collection = _collection_values[option_index]
	_refresh_visible_indices()
	if not _visible_indices.is_empty():
		show_variant(_visible_indices[0])


func _refresh_visible_indices() -> void:
	_visible_indices.clear()
	for index: int in variants.size():
		if _active_collection.is_empty() or _entry_collection(variants[index]) == _active_collection:
			_visible_indices.append(index)
	var only_one: bool = _visible_indices.size() < 2
	if _previous != null:
		_previous.disabled = only_one
	if _next != null:
		_next.disabled = only_one


func _change_selection(step: int) -> void:
	if _visible_indices.is_empty():
		return
	var visible_position := _visible_indices.find(selected)
	if visible_position < 0:
		visible_position = 0
	show_variant(_visible_indices[posmod(visible_position + step, _visible_indices.size())])


func _update_counter() -> void:
	var visible_position := _visible_indices.find(selected)
	if visible_position >= 0:
		_counter.text = "%d / %d   ·   %d total" % [visible_position + 1, _visible_indices.size(), variants.size()]
	else:
		_counter.text = "%d / %d" % [selected + 1, variants.size()]


func _apply_preview_materials(entry: Dictionary) -> void:
	if not str(entry.get("scene", "")).begins_with("res://assets/characters/kenney_female/"):
		return
	var palette: Dictionary = KENNEY_PREVIEW_PALETTES[posmod(selected - 4, KENNEY_PREVIEW_PALETTES.size())]
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var is_head := mesh.name.to_lower().contains("head")
		var color := Color.html(str(palette["head"] if is_head else palette["outfit"]))
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null or source.albedo_texture != null or source.albedo_color != Color.WHITE:
				continue
			var preview := source.duplicate() as StandardMaterial3D
			preview.albedo_color = color
			preview.roughness = 0.82
			preview.metallic = 0.0
			mesh.set_surface_override_material(surface, preview)


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
	_animation_select.clear()
	_animation_select.disabled = true
	if _skeleton == null:
		_animation_label.text = "No character skeleton"
		return
	_clips.clear()
	_animation_select.clear()
	if _use_embedded_animations:
		for node: Node in _model.find_children("*", "AnimationPlayer", true, false):
			var embedded_player := node as AnimationPlayer
			if embedded_player.get_animation_list().is_empty():
				continue
			_animation_player = embedded_player
			_animation_player.stop()
			for clip: String in _animation_player.get_animation_list():
				if clip == "RESET" or clip.ends_with("/RESET"):
					continue
				_clips.append(clip)
				var animation := _animation_player.get_animation(clip)
				if animation != null:
					animation.loop_mode = Animation.LOOP_LINEAR if _embedded_motion_key(clip) in ["idle", "walk", "run", "sprint", "crouch", "sit", "drive"] else Animation.LOOP_NONE
			for clip: String in _clips:
				if _embedded_motion_key(clip) == "idle":
					_clips.erase(clip)
					_clips.push_front(clip)
					break
			break
		if _animation_player == null or _clips.is_empty():
			_animation_label.text = "No embedded character animations"
			return
		for clip: String in _clips:
			_animation_select.add_item(_embedded_animation_label(clip))
		_animation_select.disabled = false
		_clip_index = 0
		_skeleton.reset_bone_poses()
		show_animation(0)
		return
	if not _supports_creator(variants[selected]):
		_animation_label.text = "No compatible character animations"
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
	_animation_select.disabled = _clips.is_empty()
	_skeleton.reset_bone_poses()
	show_animation(0)


func _embedded_motion_key(clip: String) -> String:
	var label: String = clip.get_slice("|", clip.get_slice_count("|") - 1)
	label = label.to_lower()
	if label.begins_with("female_"):
		label = label.trim_prefix("female_")
	return label.get_slice("_", 0)


func _embedded_animation_label(clip: String) -> String:
	var label: String = clip.get_slice("|", clip.get_slice_count("|") - 1).replace("_", " ").replace("-", " ")
	return label.capitalize()


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
	# Let newly added skeletal meshes update their deformed bounds before fitting the camera.
	await get_tree().process_frame
	if not is_instance_valid(_model) or not is_instance_valid(_camera):
		return
	var bounds := AABB()
	var found: bool = false
	var inverse := _display.global_transform.affine_inverse()
	var geometry: Array[GeometryInstance3D] = []
	if _model is GeometryInstance3D:
		geometry.append(_model as GeometryInstance3D)
	for node: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		geometry.append(node as GeometryInstance3D)
	for instance: GeometryInstance3D in geometry:
		var box: AABB = (inverse * instance.global_transform) * instance.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found:
		return
	_model.position += Vector3(-bounds.get_center().x, STAGE_TOP - bounds.position.y, -bounds.get_center().z)
	var height := maxf(bounds.size.y, 0.5)
	var width := maxf(bounds.size.x, bounds.size.z)
	# Skinned GLTF instances can report their bind-pose AABB as a nearly flat sliver.
	# The Synty source body meshes are about 1.8 m tall; use that authored extent when
	# the deformed-instance bounds are not usable, so the camera frames the full figure.
	if bounds.size.y < 0.1 or width < 0.1:
		height = maxf(float(variants[selected].get("preview_height", 1.8)), 0.5)
		width = maxf(float(variants[selected].get("preview_width", 1.6)), 0.5)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_fov := deg_to_rad(_camera.fov * 0.5)
	_distance = maxf(height * 0.76 / tan(half_fov), width * 0.76 / (tan(half_fov) * aspect))
	_camera.position = Vector3(0.0, STAGE_TOP + height * 0.55, _distance)
	_camera.look_at(Vector3(0.0, STAGE_TOP + height * 0.5, 0.0))


func _supports_t_pose() -> bool:
	if _skeleton == null:
		return false
	return _skeleton.find_bone("DEF-upper_arm.L") >= 0 and _skeleton.find_bone("DEF-forearm.L") >= 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				_change_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_change_selection(1)
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
				if _supports_t_pose():
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
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0d1822")
	sky_material.sky_horizon_color = Color("304454")
	sky_material.ground_bottom_color = Color("101922")
	sky_material.ground_horizon_color = Color("273a49")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c9d4")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	key.light_energy = 0.92
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 145.0, 0.0)
	fill.light_color = Color("b8d5ef")
	fill.light_energy = 0.3
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12.0, 180.0, 0.0)
	rim.light_color = Color("9ecde0")
	rim.light_energy = 0.5
	add_child(rim)
	_add_stage_cylinder("PedestalBase", 1.42, 0.16, Vector3(0.0, -0.08, 0.0), Color("15232d"), 0.42, 0.38)
	_add_stage_cylinder("FrostedStage", 1.24, 0.12, Vector3(0.0, -0.01, 0.0), Color("465a68"), 0.08, 0.72)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.08
	ring_mesh.outer_radius = 1.13
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("80aebf")
	ring_material.emission_enabled = true
	ring_material.emission = Color("315c6a")
	ring_material.emission_energy_multiplier = 0.34
	ring_mesh.material = ring_material
	var ring := MeshInstance3D.new()
	ring.name = "StageLightRing"
	ring.mesh = ring_mesh
	ring.position.y = STAGE_TOP - 0.006
	add_child(ring)
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
	_heading = Label.new()
	_heading.text = "MATHILDA  /  CHARACTER STUDIO"
	_heading.add_theme_color_override("font_color", Color("a9c5d8"))
	_heading.add_theme_font_size_override("font_size", 18)
	column.add_child(_heading)
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
	var motion_row := HBoxContainer.new()
	motion_row.add_theme_constant_override("separation", 10)
	column.add_child(motion_row)
	_collection_select = OptionButton.new()
	_collection_select.custom_minimum_size = Vector2(250.0, 38.0)
	_collection_select.tooltip_text = "Filter the collection by source pack"
	_collection_select.item_selected.connect(_on_collection_selected)
	motion_row.add_child(_collection_select)
	_animation_select = OptionButton.new()
	_animation_select.custom_minimum_size = Vector2(220.0, 38.0)
	_animation_select.item_selected.connect(show_animation)
	motion_row.add_child(_animation_select)
	_pose_button = Button.new()
	_pose_button.text = "T pose"
	_pose_button.custom_minimum_size = Vector2(92.0, 38.0)
	_pose_button.pressed.connect(_toggle_t_pose)
	motion_row.add_child(_pose_button)
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
	_previous.pressed.connect(func() -> void: _change_selection(-1))
	row.add_child(_previous)
	_counter = Label.new()
	_counter.custom_minimum_size.x = 90.0
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_counter)
	_next = Button.new()
	_next.text = "Next →"
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size = Vector2(160.0, 48.0)
	_next.pressed.connect(func() -> void: _change_selection(1))
	row.add_child(_next)
	_hint = Label.new()
	_hint.text = "← / → Characters   •   ↑ / ↓ Animations   •   Drag to turn   •   Wheel to zoom   •   Home reset   •   Esc close"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color("c4d3dc"))
	_hint.add_theme_color_override("font_outline_color", Color("101922"))
	_hint.add_theme_constant_override("outline_size", 2)
	column.add_child(_hint)
	_build_creator_panel(layer)


func _build_creator_panel(layer: CanvasLayer) -> void:
	_creator_panel = PanelContainer.new()
	var panel := _creator_panel
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
	outfit_note.text = "Original costume only for now."
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


func _add_stage_cylinder(node_name: String, radius: float, height: float, at: Vector3, color: Color, metallic: float, roughness: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	add_child(instance)


func _capture(path: String) -> void:
	for frame: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Presentation capture failed: %s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
