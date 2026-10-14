class_name Lantern
extends Node3D

## Photorealistic hurricane lantern (Poly Haven CC0 Lantern_01) with PBR brass,
## transparent glass, flickering emissive flame, OmniLight3D and atmospheric fog.

const MODEL_PATH := "res://assets/vendor/polyhaven/Lantern_01/Lantern_01_1k.gltf"
const DIFF_PATH := "res://assets/vendor/polyhaven/Lantern_01/textures/Lantern_01_brass_diff_1k.jpg"
const NOR_PATH := "res://assets/vendor/polyhaven/Lantern_01/textures/Lantern_01_brass_nor_gl_1k.jpg"
const ARM_PATH := "res://assets/vendor/polyhaven/Lantern_01/textures/Lantern_01_brass_arm_1k.jpg"

@export var lit := true:
	set(value):
		lit = value
		_update_lighting()

var omni_light: OmniLight3D
var spot_light: SpotLight3D
var flame_mesh: MeshInstance3D
var body: Node3D
var glass_mesh: MeshInstance3D

var _base_energy := 1.3
var _noise := FastNoiseLite.new()
var _time := 0.0
var _flame_mat: StandardMaterial3D


func _ready() -> void:
	_noise.seed = 2049
	_noise.frequency = 2.0
	_build_model()
	_update_lighting()


func _build_model() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		push_error("Lantern: model missing at " + MODEL_PATH)
		return
	var scene := load(MODEL_PATH) as PackedScene
	body = scene.instantiate() as Node3D
	body.name = "LanternBody"
	add_child(body)

	# Find meshes and set up high-fidelity materials.
	var brass_mat := _create_brass_material()
	var glass_mat := _create_glass_material()

	for child in body.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if "glass" in mi.name.to_lower():
			glass_mesh = mi
			mi.material_override = glass_mat
		else:
			mi.material_override = brass_mat

	# Inner flame at the wick (Y ~ 0.105m inside the glass).
	var flame := SphereMesh.new()
	flame.radius = 0.012
	flame.height = 0.038
	flame.radial_segments = 12
	flame.rings = 6

	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.albedo_color = Color(1.0, 0.74, 0.38)
	_flame_mat.emission_enabled = true
	_flame_mat.emission = Color(1.0, 0.58, 0.22)
	_flame_mat.emission_energy_multiplier = 5.5

	flame_mesh = MeshInstance3D.new()
	flame_mesh.name = "Flame"
	flame_mesh.mesh = flame
	flame_mesh.material_override = _flame_mat
	flame_mesh.position = Vector3(0.0, 0.105, 0.0)
	add_child(flame_mesh)

	# Primary warm kerosene omni light.
	omni_light = OmniLight3D.new()
	omni_light.name = "LanternOmni"
	omni_light.light_color = Color(1.0, 0.68, 0.38)
	omni_light.light_energy = _base_energy
	omni_light.omni_range = Tune.LANTERN_LIGHT_RANGE if "LANTERN_LIGHT_RANGE" in Tune else 11.0
	omni_light.omni_attenuation = 1.25
	omni_light.light_specular = 0.22
	omni_light.light_volumetric_fog_energy = 0.95
	omni_light.shadow_enabled = true
	omni_light.shadow_bias = 0.04
	omni_light.shadow_caster_mask = 0xFFFFF & ~Tune.FOREST_RENDER_LAYER
	omni_light.position = Vector3(0.0, 0.12, 0.0)
	add_child(omni_light)

	# Soft forward beam to light the snowy trail ahead.
	spot_light = SpotLight3D.new()
	spot_light.name = "LanternForwardBeam"
	spot_light.light_color = Color(1.0, 0.72, 0.44)
	spot_light.light_energy = _base_energy * 0.65
	spot_light.spot_range = 14.0
	spot_light.spot_angle = 68.0
	spot_light.spot_attenuation = 1.4
	spot_light.light_specular = 0.18
	spot_light.light_volumetric_fog_energy = 0.6
	spot_light.shadow_enabled = false
	spot_light.position = Vector3(0.0, 0.12, 0.04)
	spot_light.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(180.0), 0.0)
	add_child(spot_light)


func _create_brass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(DIFF_PATH):
		mat.albedo_texture = load(DIFF_PATH)
	if ResourceLoader.exists(NOR_PATH):
		mat.normal_enabled = true
		mat.normal_texture = load(NOR_PATH)
	if ResourceLoader.exists(ARM_PATH):
		var arm: Texture2D = load(ARM_PATH)
		mat.roughness_texture = arm
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.metallic_texture = arm
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		mat.ao_enabled = true
		mat.ao_texture = arm
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.45
	mat.metallic = 0.75
	return mat


func _create_glass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.88, 0.94, 0.16)
	mat.roughness = 0.05
	mat.metallic = 0.1
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _process(delta: float) -> void:
	if not lit:
		return
	_time += delta
	var flicker := _noise.get_noise_1d(_time * 8.0) * 0.5 + _noise.get_noise_1d(_time * 23.0 + 33.0) * 0.25
	var energy := _base_energy * (1.0 + flicker * 0.12)
	if omni_light:
		omni_light.light_energy = energy
	if spot_light:
		spot_light.light_energy = energy * 0.65
	if flame_mesh:
		flame_mesh.scale = Vector3(1.0 + flicker * 0.08, 1.0 + flicker * 0.16, 1.0 + flicker * 0.08)


func _update_lighting() -> void:
	if omni_light:
		omni_light.visible = lit
	if spot_light:
		spot_light.visible = lit
	if flame_mesh:
		flame_mesh.visible = lit


## Grip handle offset relative to lantern root origin.
func handle_offset() -> Vector3:
	return Vector3(0.0, 0.28, 0.0)
