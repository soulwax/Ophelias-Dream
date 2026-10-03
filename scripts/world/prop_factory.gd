class_name PropFactory
extends RefCounted

const ROOT := "res://assets/environment/"

static var _packed: Dictionary = {}
static var _materials: Dictionary = {}


static func spawn(file_name: String) -> Node3D:
	var premium := PremiumFlora.spawn(file_name)
	if premium:
		return premium
	var packed := _load_scene(file_name)
	if packed == null:
		return _fallback(file_name)
	var node := packed.instantiate() as Node3D
	if node == null:
		return _fallback(file_name)
	_hide_lods(node)
	_paint(node, file_name)
	return node


static func _load_scene(file_name: String) -> PackedScene:
	if _packed.has(file_name):
		return _packed[file_name]
	var path := ROOT + file_name
	var packed: PackedScene = null
	if ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	_packed[file_name] = packed
	return packed


static func _hide_lods(root: Node) -> void:
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_name := mesh_instance.name.to_lower()
		if "lod1" in mesh_name or "lod2" in mesh_name or "lod3" in mesh_name:
			mesh_instance.visible = false


static func _paint(root: Node, file_name: String) -> void:
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var part := (mesh_instance as MeshInstance3D).name
		var mat := _surface_material(file_name, part)
		if mat == null:
			mat = _material_for(file_name)
		(mesh_instance as MeshInstance3D).material_override = mat


static func _surface_material(file_name: String, mesh_name: String) -> StandardMaterial3D:
	var part := mesh_name.to_lower()
	if "branch" in part:
		return _card_material("Branches_01.tga")
	if "moss" in file_name.to_lower():
		return _atlas_material()
	var texture_name := _card_for(file_name)
	if texture_name == "":
		return null
	return _card_material(texture_name)


static func _card_for(file_name: String) -> String:
	match file_name:
		"SM_Env_Pine_04.fbx":
			return "pine04.tga"
		"SM_Env_Pine_05.fbx":
			return "pine05.tga"
		"SM_Env_Pine_03.fbx":
			return "TreePine_03.tga"
		"SM_Env_Pine_02.fbx":
			return "TreePine_02.tga"
		"SM_Env_Pine_01.fbx":
			return "TreePine_01.tga"
		"SM_Env_Bush_01.fbx", "SM_Env_Bush_01_Alt.fbx":
			return "Alpine_Bush_01.tga"
		"SM_Env_Bush_02.fbx", "SM_Env_Bush_02_Alt.fbx":
			return "Alpine_Bush_02.tga"
		"SM_Env_Grass_01.fbx":
			return "Alpine_Grass_01.tga"
		_:
			return ""


static func _card_material(texture_name: String) -> StandardMaterial3D:
	var path := _texture_path(texture_name)
	if path == "":
		return null
	if _materials.has(path):
		return _materials[path]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_materials[path] = mat
	return mat


static func _atlas_material() -> StandardMaterial3D:
	var path := ROOT + "textures/PolygonNatureBiomesS2_Alpine_Texture_01.png"
	if _materials.has(path):
		return _materials[path]
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		mat.albedo_texture = load(path)
	mat.roughness = 0.94
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_materials[path] = mat
	return mat


static func _texture_path(texture_name: String) -> String:
	var foliage := ROOT + "foliage/" + texture_name
	if ResourceLoader.exists(foliage) or FileAccess.file_exists(foliage):
		return foliage
	var textures := ROOT + "textures/" + texture_name
	if ResourceLoader.exists(textures) or FileAccess.file_exists(textures):
		return textures
	return ""


static func _material_for(file_name: String) -> StandardMaterial3D:
	var key := _family(file_name)
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.92
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	match key:
		"pine", "background":
			mat.albedo_color = Color(0.11, 0.24, 0.13)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.roughness = 0.94
		"broadleaf":
			mat.albedo_color = Color(0.13, 0.2, 0.1)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"grass":
			mat.albedo_color = Color(0.22, 0.32, 0.14)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"moss":
			mat.albedo_color = Color(0.16, 0.24, 0.12)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"flower":
			mat.albedo_color = Color(0.62, 0.42, 0.28)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"mushroom":
			mat.albedo_color = Color(0.55, 0.34, 0.22)
			mat.roughness = 0.8
		"shrub":
			mat.albedo_color = Color(0.24, 0.28, 0.12)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"fence":
			mat.albedo_color = Color(0.2, 0.13, 0.08)
			mat.roughness = 0.84
		"dead":
			mat.albedo_color = Color(0.32, 0.24, 0.16)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"snow":
			mat.albedo_color = Color(0.84, 0.88, 0.93)
		"rock", "cliff":
			mat.albedo_color = Color(0.42, 0.43, 0.46)
		"ice":
			mat.albedo_color = Color(0.7, 0.82, 0.9, 0.8)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.22
		"paper":
			mat.albedo_color = Color(0.82, 0.76, 0.64)
			mat.roughness = 0.75
		"lantern", "torch", "camp":
			mat.albedo_color = Color(0.45, 0.26, 0.12)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.45, 0.12)
			mat.emission_energy_multiplier = 0.8
		_:
			mat.albedo_color = Color(0.42, 0.26, 0.15)
	_materials[key] = mat
	return mat


static func _family(file_name: String) -> String:
	var n := file_name.to_lower()
	if "fence" in n:
		return "fence"
	if "mushroom" in n:
		return "mushroom"
	if "flower" in n:
		return "flower"
	if "moss" in n or "groundcover" in n:
		return "moss"
	if "fern" in n or "grass" in n:
		return "grass"
	if "bush" in n or "shrub" in n or "branch" in n:
		return "shrub"
	if "noleaves" in n or "dead" in n or "stump" in n or "log" in n:
		return "dead"
	if "pine" in n or "background_trees" in n:
		return "pine"
	if "tree" in n:
		return "broadleaf"
	if "snow" in n:
		return "snow"
	if "cliff" in n:
		return "cliff"
	if "rock" in n or "mountain" in n:
		return "rock"
	if "ice" in n:
		return "ice"
	if "paper" in n:
		return "paper"
	if "lantern" in n:
		return "lantern"
	if "torch" in n:
		return "torch"
	if "camp" in n:
		return "camp"
	if "tent" in n:
		return "tent"
	return "wood"


static func _fallback(file_name: String) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 1.2, 0.6)
	mesh_instance.mesh = box
	mesh_instance.material_override = _material_for(file_name)
	mesh_instance.position.y = 0.6
	var root := Node3D.new()
	root.add_child(mesh_instance)
	return root
