class_name PremiumFlora
extends RefCounted

const ROOT := "res://assets/environment/premium/"
const REPLACEMENTS := {
	"SM_Prop_Bench_01.fbx": "painted_wooden_bench_2k.fbx",
	"SM_Prop_Wood_Pile_01.fbx": "SM_MVV_LogPile_c1_LOD0.fbx",
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


static func spawn(file_name: String) -> Node3D:
	if file_name == "flowers" or file_name == "SM_Env_Flowers_01.fbx":
		var vendor := VendorLoader.spawn_nature_prop("flowers")
		if vendor:
			return vendor
	if file_name == "ivy" or file_name == "SM_Env_Ivy_01.fbx":
		var vendor := VendorLoader.spawn_nature_prop("ivy")
		if vendor:
			return vendor
	if file_name == "grass" or file_name == "SM_Env_Grass_01.fbx" or file_name == "SM_Env_Moss_Lumps_03.fbx":
		var vendor := VendorLoader.spawn_nature_prop("grass")
		if vendor:
			return vendor
	if file_name == "bush" or file_name == "card_bush" or file_name.begins_with("SM_Env_Bush"):
		var vendor := VendorLoader.spawn_nature_prop("bush")
		if vendor:
			return vendor
	if not REPLACEMENTS.has(file_name):
		return null
	var replacement: String = REPLACEMENTS[file_name]
	var scene_path := ROOT + "scenes/" + replacement.get_basename() + ".tscn"
	if not _scenes.has(scene_path):
		_scenes[scene_path] = load(scene_path)
	if _scenes[scene_path] == null:
		return null
	return (_scenes[scene_path] as PackedScene).instantiate() as Node3D
