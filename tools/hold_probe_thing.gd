extends Node3D

# hold_probe's stand-in for something that takes a while: counts what the
# player does to it. Hold seconds 0 is instant, as the contract says.

var hold_seconds := 1.0
var uses := 0
var last_fraction := 0.0


func _ready() -> void:
	add_to_group("interactables")


func interact_label() -> String:
	return "Do the thing"


func interact_point() -> Vector3:
	return global_position


func interact() -> bool:
	uses += 1
	return true


func interact_hold_seconds() -> float:
	return hold_seconds


func interact_hold_progress(fraction: float) -> void:
	last_fraction = fraction


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.2, -0.2, -0.2), Vector3(0.4, 0.4, 0.4))]
