class_name LanternPickup
extends Node3D

## A discovered photorealistic hurricane lantern resting on a wooden stand.
## Interacting with it triggers Ophelia's contact-aware pickup animation.

var lantern: Lantern
var taken := false


func _ready() -> void:
	name = "LanternPickup"
	add_to_group("interactables")
	add_to_group("lantern_pickup")

	lantern = Lantern.new()
	lantern.name = "FoundLantern"
	lantern.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	add_child(lantern)

	# A weathered wooden resting pedestal to bring the lantern to natural reach height.
	var pedestal := MeshInstance3D.new()
	pedestal.name = "Pedestal"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.18, 0.13)
	wood.roughness = 0.92
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.16
	cyl.height = 0.65
	cyl.radial_segments = 12
	cyl.material = wood
	pedestal.mesh = cyl
	pedestal.position = Vector3(0.0, -0.325, 0.0)
	add_child(pedestal)

	if Game.has_lantern:
		remove_from_group("interactables")
		lantern.visible = false
		taken = true


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.25, -0.1, -0.25), Vector3(0.5, 0.65, 0.5))]


func interact_label() -> String:
	return "Take the lantern"


func blocked_label() -> String:
	return "Step closer and stand still to take the lantern."


func interact() -> bool:
	if taken or Game.phase != Game.Phase.PLAYING or Game.player == null:
		return false
	if not Game.player.take_lantern(lantern):
		return false
	taken = true
	remove_from_group("interactables")
	return true


func remove_found_lantern() -> void:
	taken = true
	remove_from_group("interactables")
	if is_instance_valid(lantern) and lantern.get_parent() == self:
		lantern.queue_free()
