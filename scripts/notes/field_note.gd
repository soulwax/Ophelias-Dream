class_name FieldNote
extends Node3D

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


func _build() -> void:
	var page := PropFactory.spawn("SM_Gen_Prop_Papers_01.fbx")
	page.scale = Vector3.ONE * Tune.PROP_SCALE * 1.15
	page.rotation.y = randf() * TAU
	add_child(page)

	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(0.95, 0.78, 0.45)
	glow.light_energy = 0.55
	glow.omni_range = 3.2
	glow.position = Vector3(0, 0.45, 0)
	glow.shadow_enabled = false
	add_child(glow)

	var marker := Label3D.new()
	marker.name = "Mark"
	marker.text = "note"
	marker.font_size = 42
	marker.modulate = Color(0.93, 0.86, 0.7)
	marker.outline_modulate = Color(0, 0, 0)
	marker.outline_size = 8
	marker.position = Vector3(0, 0.85, 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.pixel_size = 0.002
	add_child(marker)
