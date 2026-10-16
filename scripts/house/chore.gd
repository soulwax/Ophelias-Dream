class_name Chore
extends Node3D

## A one-shot small task: a light to catch, a latch to throw. E runs its
## callback once; the default is to then drop out of `interactables`
## entirely, so the reticle has nothing left to offer there. Used for the
## little repairs either woman does before she sets out.

signal blocked

var label := ""
var _reach := 0.6
var _on_do: Callable
var done := false
## Optional: why the chore cannot be done yet, or "" when it can (the stove
## with an empty woodbox). Shown as the prompt and as the press's feedback.
var gate: Callable
## Optional: what a restored save does instead of _on_do (the effect without
## her line about it).
var on_restore: Callable


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
	var why := blocked_label()
	return why if why != "" else label


func blocked_label() -> String:
	return str(gate.call()) if gate.is_valid() else ""


func interact_point() -> Vector3:
	return global_position


func aim_box() -> Array:
	return [global_transform, AABB(Vector3.ONE * -_reach * 0.5, Vector3.ONE * _reach)]


func interact() -> bool:
	if done:
		return false
	if blocked_label() != "":
		blocked.emit()
		return false
	done = true
	remove_from_group("interactables")
	if _on_do.is_valid():
		_on_do.call()
	return true


## A save says it was done: do it again quietly, without replaying her line.
func restore_done() -> void:
	if done:
		return
	done = true
	remove_from_group("interactables")
	if on_restore.is_valid():
		on_restore.call()
	elif _on_do.is_valid():
		_on_do.call()
