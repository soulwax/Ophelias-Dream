class_name VendorLoader
extends RefCounted

## Runtime loader for non-redistributable, proprietary vendor assets placed
## in the git-ignored build/ folder (e.g. build/vendor/requested_*).
## Because build/ has a .gdignore, assets are loaded directly from disk via
## FBXDocument, GLTFDocument, and Image rather than through ResourceLoader.

const BUILD_ROOT := "build/vendor/"
static var _models: Dictionary = {}
static var _textures: Dictionary = {}
static var _wind_shader := preload("res://shaders/nature_wind.gdshader")


static func load_model(rel_path: String) -> Node3D:
	if _models.has(rel_path):
		var cached: Node3D = _models[rel_path]
		return cached.duplicate() if is_instance_valid(cached) else null

	var path := ProjectSettings.globalize_path("res://" + rel_path)
	if not FileAccess.file_exists(path):
		return null
	var ext := path.get_extension().to_lower()
	var root: Node3D = null
	if ext == "fbx":
		var doc := FBXDocument.new()
		var state := FBXState.new()
		if doc.append_from_file(path, state) == OK:
			root = doc.generate_scene(state) as Node3D
	elif ext == "gltf" or ext == "glb":
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) == OK:
			root = doc.generate_scene(state) as Node3D

	if root:
		_clean_hierarchy(root)
		_models[rel_path] = root
		return root.duplicate()
	return null


static func load_texture(rel_path: String) -> ImageTexture:
	if _textures.has(rel_path):
		return _textures[rel_path]
	var path := ProjectSettings.globalize_path("res://" + rel_path)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	var tex := ImageTexture.create_from_image(img)
	_textures[rel_path] = tex
	return tex


static func spawn_nature_prop(kind: String) -> Node3D:
	var mesh_file := ""
	match kind:
		"flowers":
			mesh_file = "flowers/SM_MVV_Flowers_01_B_c1_LOD0.fbx"
		"ivy":
			mesh_file = "ivy/SM_PAD_MV_Ivy01e_c1_LOD0.fbx"
		"grass":
			mesh_file = "grass/SM_PAD_SV_Grass02a_c1_LOD0.fbx"
		"bush":
			mesh_file = "bush/SM_MVV_Bush03_B_c1_LOD0.fbx"
		_:
			return null

	var model_rel := BUILD_ROOT + "requested_nature/" + mesh_file
	var node := load_model(model_rel)
	if node == null:
		return null

	# Wire up nature wind material
	var albedo := load_texture(BUILD_ROOT + "requested_nature/%s/%s_albedo.png" % [kind, kind])
	var normal := load_texture(BUILD_ROOT + "requested_nature/%s/%s_normal.png" % [kind, kind])
	var orm := load_texture(BUILD_ROOT + "requested_nature/%s/%s_orm.png" % [kind, kind])

	var mat := ShaderMaterial.new()
	mat.shader = _wind_shader
	if albedo:
		mat.set_shader_parameter("albedo_texture", albedo)
	if normal:
		mat.set_shader_parameter("normal_texture", normal)
		mat.set_shader_parameter("normal_enabled", true)
	if orm:
		mat.set_shader_parameter("orm_texture", orm)
		mat.set_shader_parameter("orm_enabled", true)

	mat.set_shader_parameter("alpha_scissor_threshold", 0.35)
	mat.set_shader_parameter("is_undergrowth", true)
	var height_ref := 0.6 if kind == "grass" else (1.2 if kind == "flowers" else 1.8)
	var speed_val := 2.6 if kind == "grass" else (2.2 if kind == "flowers" else 1.8)
	mat.set_shader_parameter("height_reference", height_ref)
	mat.set_shader_parameter("wind_speed", speed_val)
	mat.set_shader_parameter("wind_strength", 1.0)

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.visible:
			mi.material_override = mat

	return node


static func _clean_hierarchy(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var name_lower := str(child.name).to_lower()
		# Hide LODs and Unreal collision hulls
		if "lod1" in name_lower or "lod2" in name_lower or "lod3" in name_lower or name_lower.begins_with("ucx_"):
			(child as MeshInstance3D).visible = false
