class_name EditableLevel
extends RefCounted

const SCENE_PATH := "res://scenes/editable_level.scn"
const GENERATED_DIR := "res://scenes/generated/"
const SOURCE_PATH := &"generated_index_path"
const GROUP_PARENT_PATH := &"generated_parent_path"


static func bake(nodes: Array[Node], seed_value: int) -> Error:
	var root := Node3D.new()
	root.name = "EditableLevel"
	root.set_meta("seed", seed_value)
	for index in nodes.size():
		var node := nodes[index]
		if node is Player or node is Hunter:
			_bake_actor(root, node, index)
			continue
		var copy := node.duplicate(0)
		_strip_scripts(copy)
		root.add_child(copy)
		_tag_tree(node, copy, PackedInt32Array([index]), root)
	var result := _save_hierarchy(root)
	root.free()
	return result


static func _save_hierarchy(root: Node3D) -> Error:
	var directory := ProjectSettings.globalize_path(GENERATED_DIR + "house")
	var result := DirAccess.make_dir_recursive_absolute(directory)
	if result != OK:
		return result
	var trail := root.get_node_or_null("Trail") as Node3D
	if trail == null:
		return ERR_INVALID_DATA
	var house := trail.get_node_or_null("House") as Node3D
	if house == null:
		return ERR_INVALID_DATA
	var cellar := house.get_node_or_null("Cellar") as Node3D
	if cellar and cellar.get_node_or_null("Morgue"):
		result = _nest_scene(cellar, cellar.get_node("Morgue"), "house/morgue.scn", root)
		if result != OK:
			return result
	for group_name in ["GroundFloor", "Roof", "Stair", "Cellar", "Furniture", "Lights", "Haunting", "SnowPatch"]:
		var group := house.get_node_or_null(group_name)
		if group:
			result = _nest_scene(house, group, "house/%s.scn" % group_name.to_snake_case(), root)
			if result != OK:
				return result
	result = _nest_scene(trail, house, "house.scn", root)
	if result != OK:
		return result
	var landmarks := _group_landmarks(trail, root)
	for name in ["Ground", "Fence", "Flora"]:
		var branch := trail.get_node_or_null(name)
		if branch:
			result = _nest_scene(trail, branch, "%s.scn" % name.to_snake_case(), root)
			if result != OK:
				return result
	if landmarks:
		result = _nest_scene(trail, landmarks, "landmarks.scn", root)
		if result != OK:
			return result
	for name in ["Atmosphere", "Trail", "Player", "Hunter"]:
		var branch := root.get_node_or_null(name)
		if branch:
			result = _nest_scene(root, branch, "%s.scn" % name.to_snake_case(), root)
			if result != OK:
				return result
	var scene := PackedScene.new()
	result = scene.pack(root)
	if result == OK:
		result = ResourceSaver.save(scene, SCENE_PATH)
	return result


static func _group_landmarks(trail: Node3D, root: Node3D) -> Node3D:
	var group := Node3D.new()
	group.name = "Landmarks"
	group.set_meta("generated_group", true)
	group.set_meta(GROUP_PARENT_PATH, trail.get_meta(SOURCE_PATH, PackedInt32Array()))
	trail.add_child(group)
	group.owner = root
	for child in trail.get_children():
		if child == group or child.name in ["Ground", "House", "Fence", "Flora"]:
			continue
		child.owner = null
		child.reparent(group, false)
		child.owner = root
		if child.scene_file_path != "":
			root.set_editable_instance(child, true)
	return group


static func _nest_scene(parent: Node, branch: Node, file_name: String, outer_root: Node) -> Error:
	var index := branch.get_index()
	_reown_for_scene(branch, branch, outer_root)
	var packed := PackedScene.new()
	var result := packed.pack(branch)
	if result != OK:
		return result
	var path := GENERATED_DIR + file_name
	result = ResourceSaver.save(packed, path)
	if result != OK:
		return result
	var saved := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if saved == null:
		return ERR_CANT_OPEN
	var instance := saved.instantiate()
	parent.remove_child(branch)
	branch.free()
	parent.add_child(instance)
	parent.move_child(instance, index)
	instance.owner = outer_root
	if parent == outer_root:
		outer_root.set_editable_instance(instance, true)
	return OK


static func _reown_for_scene(node: Node, scene_root: Node, old_owner: Node) -> void:
	for child in node.get_children():
		if child.owner == old_owner:
			child.owner = scene_root
		if child.scene_file_path != "":
			if not scene_root.get_meta("preview_actor", false):
				scene_root.set_editable_instance(child, true)
			continue
		_reown_for_scene(child, scene_root, old_owner)


static func _bake_actor(root: Node3D, actor: Node, index: int) -> void:
	var preview: Node3D = CharacterBody3D.new() if actor is Player else Node3D.new()
	preview.name = actor.name
	preview.transform = (actor as Node3D).transform
	preview.set_meta(SOURCE_PATH, PackedInt32Array([index]))
	preview.set_meta("preview_actor", true)
	root.add_child(preview)
	preview.owner = root
	var model_path := "res://assets/characters/styloo_elf/elf.glb" if actor is Player else "res://addons/quaternius_ik_rigged/Models_with_rigging/Master_Rigged.tscn"
	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	if model == null:
		return
	model.name = "Appearance"
	var live_model := (actor as Node).find_child("elf", true, false) as Node3D if actor is Player else (actor as Hunter).model
	if live_model:
		model.transform = (actor as Node3D).global_transform.affine_inverse() * live_model.global_transform
		model.set_meta(SOURCE_PATH, _descendant_path(actor, live_model, index))
	preview.add_child(model)
	model.owner = root


static func _descendant_path(ancestor: Node, descendant: Node, top_index: int) -> PackedInt32Array:
	var indices: Array[int] = []
	var current := descendant
	while current != ancestor and current != null:
		indices.push_front(current.get_index())
		current = current.get_parent()
	var result := PackedInt32Array([top_index])
	for child_index in indices:
		result.append(child_index)
	return result


static func apply(snapshot: Node, generated: Array[Node]) -> void:
	var originals: Dictionary = {}
	for index in generated.size():
		_index_tree(generated[index], PackedInt32Array([index]), originals)
	var authored: Dictionary = {}
	_apply_tree(snapshot, originals, authored)
	# A removed visual or collision node should stay removed at run time. Scripted
	# nodes remain alive because gameplay can still hold references to them.
	for key in originals:
		if authored.has(key):
			continue
		var node := originals[key] as Node
		if node == null or not is_instance_valid(node):
			continue
		if node.get_script() == null:
			node.queue_free()
		elif node is Node3D:
			(node as Node3D).visible = false


static func _strip_scripts(node: Node) -> void:
	for child in node.get_children():
		_strip_scripts(child)
	node.set_script(null)


static func _tag_tree(original: Node, copy: Node, index_path: PackedInt32Array, root: Node) -> void:
	copy.set_meta(SOURCE_PATH, index_path)
	copy.owner = root
	if copy.scene_file_path != "":
		root.set_editable_instance(copy, true)
		return
	var old_children := original.get_children()
	var new_children := copy.get_children()
	for index in mini(old_children.size(), new_children.size()):
		var path := index_path.duplicate()
		path.append(index)
		_tag_tree(old_children[index], new_children[index], path, root)


static func _index_tree(node: Node, index_path: PackedInt32Array, lookup: Dictionary) -> void:
	lookup[_key(index_path)] = node
	for index in node.get_child_count():
		var path := index_path.duplicate()
		path.append(index)
		_index_tree(node.get_child(index), path, lookup)


static func _apply_tree(node: Node, originals: Dictionary, authored: Dictionary) -> void:
	for child in node.get_children():
		if child.get_meta("generated_group", false):
			_apply_tree(child, originals, authored)
			continue
		var path: PackedInt32Array = child.get_meta(SOURCE_PATH, PackedInt32Array())
		if path.is_empty():
			# A hand-added node belongs to the nearest generated parent.
			var parent_path: PackedInt32Array = node.get_meta(SOURCE_PATH, node.get_meta(GROUP_PARENT_PATH, PackedInt32Array()))
			var target_parent := originals.get(_key(parent_path)) as Node
			if target_parent:
				var addition := child.duplicate(0)
				_clear_tags(addition)
				target_parent.add_child(addition)
			continue
		var key := _key(path)
		authored[key] = true
		var target := originals.get(key) as Node
		if target:
			_copy_editable_properties(child, target)
			if child.get_meta("preview_actor", false) or (child.scene_file_path != "" and not child.scene_file_path.begins_with(GENERATED_DIR)):
				_mark_descendants(target, path, authored)
			if child.scene_file_path != "" and not child.scene_file_path.begins_with(GENERATED_DIR) and not node.get_meta("preview_actor", false):
				_sync_instance_children(child, target)
		if child.scene_file_path != "" and not child.scene_file_path.begins_with(GENERATED_DIR):
			continue
		_apply_tree(child, originals, authored)


static func _sync_instance_children(source: Node, target: Node) -> void:
	for index in mini(source.get_child_count(), target.get_child_count()):
		var from_child := source.get_child(index)
		var to_child := target.get_child(index)
		_copy_editable_properties(from_child, to_child)
		_sync_instance_children(from_child, to_child)


static func _mark_descendants(node: Node, path: PackedInt32Array, authored: Dictionary) -> void:
	for index in node.get_child_count():
		var child_path := path.duplicate()
		child_path.append(index)
		authored[_key(child_path)] = true
		_mark_descendants(node.get_child(index), child_path, authored)


static func _copy_editable_properties(source: Node, target: Node) -> void:
	if source.get_class() != target.get_class():
		push_warning("Editable level node type changed: %s" % source.name)
		return
	for property in source.get_property_list():
		var usage: int = property["usage"]
		if (usage & PROPERTY_USAGE_STORAGE) == 0 or (usage & PROPERTY_USAGE_READ_ONLY) != 0:
			continue
		var property_name: StringName = property["name"]
		if property_name in [&"name", &"owner", &"script", &"scene_file_path", &"unique_name_in_owner", &"autoplay"] or String(property_name).begins_with("metadata/"):
			continue
		target.set(property_name, source.get(property_name))


static func _clear_tags(node: Node) -> void:
	if node.has_meta(SOURCE_PATH):
		node.remove_meta(SOURCE_PATH)
	for child in node.get_children():
		_clear_tags(child)


static func _key(path: PackedInt32Array) -> String:
	return str(path)
