class_name BowPickup
extends Node3D

## A discovered prop, not starting equipment. Uses the normal aim/prompt path.
const MODEL := Tune.BOW_MODEL
var bow: Node3D
var taken := false


func _ready() -> void:
	name = "TrailBow"
	add_to_group("interactables")
	add_to_group("bow_pickup")
	bow = (load(MODEL) as PackedScene).instantiate() as Node3D
	bow.name = "FoundBow"
	bow.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	bow.rotation.z = 0.12
	add_child(bow)
	# A short weathered rest keeps the grip within her standing reach.
	var rest := MeshInstance3D.new()
	rest.name = "BowRest"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.19, 0.13, 0.09)
	wood.roughness = 0.95
	var post := CylinderMesh.new()
	post.top_radius = 0.055
	post.bottom_radius = 0.075
	post.height = 1.25
	post.radial_segments = 8
	post.material = wood
	rest.mesh = post
	rest.position = Vector3(0.0, -0.525, 0.14)
	add_child(rest)
	if Game.has_bow:
		remove_from_group("interactables")
		bow.visible = false
		taken = true


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.23, -0.62, -0.12), Vector3(0.46, 1.24, 0.24))]


func interact_label() -> String:
	return "Take the bow"


func blocked_label() -> String:
	return "Step closer and stand still to take the bow."


func interact() -> bool:
	if taken or Game.phase != Game.Phase.PLAYING or Game.player == null:
		return false
	if not Game.player.take_bow(bow):
		return false
	taken = true
	remove_from_group("interactables")
	return true


func remove_found_bow() -> void:
	taken = true
	remove_from_group("interactables")
	if is_instance_valid(bow) and bow.get_parent() == self:
		bow.queue_free()
