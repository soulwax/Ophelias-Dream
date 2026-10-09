class_name FieldNote
extends Node3D

const PAPER_SCENE_PATH := "res://assets/vendor/requested_paper/carpenters_workshop/Art/Meshes/SM_Paper_01.gltf"

var entry: NoteEntry
var collected := false


func collect() -> bool:
	if collected:
		return false
	collected = true
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow:
		glow.light_energy = 0.06
	var marker := get_node_or_null("Mark") as Label3D
	if marker:
		marker.modulate = Color(0.55, 0.56, 0.58, 0.65)
	return true


func _ready() -> void:
	add_to_group("field_notes")
	_build()


## The paper and a little of the snow around it.
func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.3, -0.05, -0.3), Vector3(0.6, 0.35, 0.6))]


func _build() -> void:
	var page := _single_sheet()
	page.name = "SingleSheet"
	page.scale *= 0.4
	page.rotation.y = randf() * TAU
	page.position.y = 0.025
	add_child(page)

	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(0.95, 0.78, 0.45)
	if entry != null and entry.record_of != "":
		glow.light_color = Color(0.62, 0.78, 0.95)
	glow.light_energy = 0.55
	glow.omni_range = 3.2
	glow.position = Vector3(0, 0.45, 0)
	glow.shadow_enabled = false
	add_child(glow)

	var marker := Label3D.new()
	marker.name = "Mark"
	var record := entry != null and entry.record_of != ""
	var house_page := entry != null and not entry.counts and not record
	marker.text = "record" if record else ("page" if house_page else "note")
	marker.font_size = 42
	marker.modulate = Color(0.93, 0.86, 0.7)
	marker.outline_modulate = Color(0, 0, 0)
	marker.outline_size = 8
	marker.position = Vector3(0, 0.85, 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.pixel_size = 0.002
	add_child(marker)


func _single_sheet() -> Node3D:
	if ResourceLoader.exists(PAPER_SCENE_PATH):
		var packed := load(PAPER_SCENE_PATH) as PackedScene
		if packed:
			var paper := packed.instantiate() as Node3D
			if paper:
				for mesh_node in paper.find_children("*", "MeshInstance3D", true, false):
					var mesh := mesh_node as MeshInstance3D
					if mesh.name.to_lower().contains("lod") and not mesh.name.to_lower().contains("lod0"):
						mesh.hide()
				return paper
	return _fallback_sheet()


func _fallback_sheet() -> Node3D:
	var paper := Node3D.new()
	var sheet := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 0.008, 0.46)
	sheet.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d6cfbb")
	material.roughness = 0.94
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	sheet.material_override = material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paper.add_child(sheet)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color("756b5e")
	ink.roughness = 1.0
	for index in 4:
		var line := MeshInstance3D.new()
		var stroke := BoxMesh.new()
		stroke.size = Vector3(0.23 if index < 3 else 0.12, 0.002, 0.009)
		line.mesh = stroke
		line.material_override = ink
		line.position = Vector3(-0.018, 0.006, -0.12 + float(index) * 0.075)
		line.rotation.y = -0.035
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paper.add_child(line)
	return paper
