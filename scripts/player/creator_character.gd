class_name CreatorCharacter
extends Node3D

const DEFAULT := {
	"name": "Mathilda",
	"hair": "bob",
	"outfit": "wayfarer",
	"hair_color": "69402d",
	"eye_color": "5b9fae",
	"cloth_color": "344e66",
	"trim_color": "bca57b",
}
const HAIRS := ["long", "bob", "bun", "braids"]
const OUTFITS := ["elf", "wayfarer", "hearth", "ranger"]

var configuration: Dictionary = DEFAULT.duplicate()
static var _material_cache: Dictionary = {}
static var _source_materials: Dictionary = {}


func _ready() -> void:
	var outfit: String = str(configuration.get("outfit", "wayfarer"))
	var hair: String = str(configuration.get("hair", "bob"))
	if outfit not in OUTFITS:
		outfit = "wayfarer"
	if hair not in HAIRS:
		hair = "bob"
	var model := (load("res://assets/characters/creator/outfit_%s.glb" % outfit) as PackedScene).instantiate() as Node3D
	add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_error("Creator outfit is missing its skeleton")
		return
	var hair_model := (load("res://assets/characters/creator/hair_%s.glb" % hair) as PackedScene).instantiate() as Node3D
	add_child(hair_model)
	var meshes := hair_model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		mesh.name = "Hair_" + mesh.name
		mesh.reparent(skeleton.get_parent(), true)
		mesh.skeleton = mesh.get_path_to(skeleton)
	remove_child(hair_model)
	hair_model.queue_free()
	apply_colors()


func apply_colors() -> void:
	# Retain recently used materials across rebuilds; avoid freeing a material
	# while the renderer still has work queued for the previous character.
	if _material_cache.size() > 512:
		var keys: Array = _material_cache.keys()
		for index: int in 64:
			_material_cache.erase(keys[index])
	var hair := Color.html(str(configuration.get("hair_color", DEFAULT.hair_color)))
	var eye := Color.html(str(configuration.get("eye_color", DEFAULT.eye_color)))
	var cloth := Color.html(str(configuration.get("cloth_color", DEFAULT.cloth_color)))
	var trim := Color.html(str(configuration.get("trim_color", DEFAULT.trim_color)))
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface: int in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var name := original.resource_name.to_lower()
			_source_materials[original.get_instance_id()] = original
			var colors := "fixed"
			if name == "elffirst":
				colors = hair.to_html() + eye.to_html()
			elif name.begins_with("stylehair"):
				colors = hair.to_html()
			elif name == "creatorcloth":
				colors = cloth.to_html() + str(configuration.outfit)
			elif name == "elfsecond":
				colors = cloth.to_html() + trim.to_html()
			elif name == "creatortrim" or name == "braidtie":
				colors = trim.to_html()
			var key := "%d/%s" % [original.get_instance_id(), colors]
			if _material_cache.has(key):
				mesh.set_surface_override_material(surface, _material_cache[key])
				continue
			if name == "creatorcloth":
				var fabric := ShaderMaterial.new()
				fabric.shader = load("res://shaders/creator_fabric.gdshader")
				fabric.set_shader_parameter("cloth_color", cloth)
				fabric.set_shader_parameter("accent_color", cloth.darkened(0.50) if configuration.outfit != "ranger" else Color("322c29"))
				fabric.set_shader_parameter("design", {"wayfarer": 0, "hearth": 1, "ranger": 2}.get(configuration.outfit, 0))
				mesh.set_surface_override_material(surface, fabric)
				_material_cache[key] = fabric
				continue
			if name == "elffirst":
				var appearance := ShaderMaterial.new()
				appearance.shader = load("res://shaders/creator_appearance.gdshader")
				appearance.set_shader_parameter("base_texture", original.albedo_texture)
				appearance.set_shader_parameter("region_mask", load("res://assets/characters/creator/appearance_mask.png"))
				appearance.set_shader_parameter("hair_color", hair)
				appearance.set_shader_parameter("eye_color", eye)
				mesh.set_surface_override_material(surface, appearance)
				_material_cache[key] = appearance
			elif name == "elfsecond":
				var outfit := ShaderMaterial.new()
				outfit.shader = load("res://shaders/creator_outfit.gdshader")
				outfit.set_shader_parameter("base_texture", original.albedo_texture)
				outfit.set_shader_parameter("cloth_color", cloth)
				outfit.set_shader_parameter("trim_color", trim)
				mesh.set_surface_override_material(surface, outfit)
				_material_cache[key] = outfit
			else:
				var material := original.duplicate() as StandardMaterial3D
				if name.begins_with("stylehair"):
					material.albedo_color = hair.lightened(0.06) if name.contains("highlight") else hair
				elif name == "creatorcloth":
					material.albedo_color = cloth
				elif name == "creatortrim" or name == "braidtie":
					material.albedo_color = trim
				mesh.set_surface_override_material(surface, material)
				_material_cache[key] = material
