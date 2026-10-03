class_name PremiumFlora
extends RefCounted

const ROOT := "res://assets/environment/premium/"
const REPLACEMENTS := {
	"SM_Env_Bush_01.fbx": "SM_MVV_Bush03_B_c1_LOD0.fbx",
	"SM_Env_Bush_01_Alt.fbx": "SM_MVV_Bush03_B_c1_LOD0.fbx",
	"SM_Env_Bush_02.fbx": "SM_MVV_Bush03_B_c1_LOD0.fbx",
	"SM_Env_Bush_02_Alt.fbx": "SM_MVV_Bush03_B_c1_LOD0.fbx",
	"SM_Env_Grass_01.fbx": "SM_PAD_SV_MoorGrass01a_c1_LOD0.fbx",
	"SM_Env_Moss_Lumps_01.fbx": "SM_PAD_SV_Grass01b_c1_LOD0.fbx",
	"SM_Env_Moss_Lumps_02.fbx": "SM_PAD_SV_LadyFern01b_c1_LOD0.fbx",
	"SM_Env_Moss_Lumps_03.fbx": "SM_PAD_SV_Grass02a_c1_LOD0.fbx",
	"SM_Env_Pine_01.fbx": "SM_MVV_Pine02_c1_LOD0.fbx",
	"SM_Env_Pine_02.fbx": "SM_MVV_Pine02_c1_LOD0.fbx",
	"SM_Env_Pine_03.fbx": "SM_MVV_Pine03_c1_LOD0.fbx",
	"SM_Env_Pine_04.fbx": "SM_MVV_Pine02_c1_LOD0.fbx",
	"SM_Env_Pine_05.fbx": "SM_MVV_Pine03_c1_LOD0.fbx",
}
static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}


static func spawn(file_name: String) -> Node3D:
	if not REPLACEMENTS.has(file_name):
		return null
	var replacement: String = REPLACEMENTS[file_name]
	if not _scenes.has(replacement):
		_scenes[replacement] = load(ROOT + replacement)
	var model := (_scenes[replacement] as PackedScene).instantiate() as Node3D
	model.set_meta("premium_flora", true)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		# Unreal collision hulls are exported as visible meshes in these FBXs.
		if mesh.name.begins_with("UCX_"):
			mesh.visible = false
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface)
			var family := source.resource_name if source else "GrassSet"
			mesh.set_surface_override_material(surface, _material(family))
	return model


static func _material(family: String) -> StandardMaterial3D:
	if _materials.has(family):
		return _materials[family]
	var prefix := "T_PAD_GrassSet"
	match family:
		"Bush": prefix = "T_MVV_Bushes"
		"Pine": prefix = "T_MVV_Pine"
		"PineLeaves": prefix = "T_MVV_PineLeaves"
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ROOT + prefix + "_2048_B.png")
	material.normal_enabled = true
	material.normal_texture = load(ROOT + prefix + "_2048_OpenGL_N.png")
	material.ao_enabled = true
	material.ao_texture = load(ROOT + prefix + "_2048_AO.png")
	material.roughness = 0.93
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if family != "Pine":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.35
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.backlight_enabled = true
		material.backlight = Color(0.18, 0.22, 0.14)
		material.albedo_color = Color(0.78, 0.82, 0.73)
	_materials[family] = material
	return material
