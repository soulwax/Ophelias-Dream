class_name Chore
extends Node3D

## A one-shot small task: a light to catch, a latch to throw. E runs its
## callback once; the default is to then drop out of `interactables`
## entirely, so the reticle has nothing left to offer there. Used for the
## little repairs either woman does before she sets out.

var label := ""
var _reach := 0.6
var _on_do: Callable
var done := false


static func make(parent: Node3D, name: String, at: Vector3, task_label: String, on_do: Callable, reach: float = 0.6) -> Chore:
	var chore := Chore.new()
	chore.name = name
	chore.label = task_label
	chore._on_do = on_do
	chore._reach = reach
	chore.position = at
	parent.add_child(chore)
	chore.add_to_group("interactables")
	return chore


func interact_label() -> String:
	return label


func interact_point() -> Vector3:
	return global_position


func aim_box() -> Array:
	return [global_transform, AABB(Vector3.ONE * -_reach * 0.5, Vector3.ONE * _reach)]


func interact() -> bool:
	if done:
		return false
	done = true
	remove_from_group("interactables")
	if _on_do.is_valid():
		_on_do.call()
	return true
