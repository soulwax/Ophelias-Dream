class_name CarrySocket
extends Node3D

signal filled(item: Carryable)

@export var accepts: PackedStringArray = []
@export var capacity: int = 1
@export var socket_id: String = ""
@export var allow_take := true
var held: Array[Carryable] = []


func _ready() -> void:
	add_to_group("carry_sockets")
	Game.phase_changed.connect(_phase_changed)
	refresh_interaction()


func can_accept(item: Carryable) -> bool:
	return not Game.dream_mode and not Game.mathilda_pov and is_instance_valid(item) and item.kind in accepts and held.size() < capacity and not held.has(item)


func refresh_interaction() -> void:
	if Game.player != null and can_accept(Game.player.carrying):
		add_to_group("interactables")
	else:
		remove_from_group("interactables")


func _phase_changed(_phase: int) -> void:
	refresh_interaction()


func interact_label() -> String:
	return "Put the %s here" % Game.player.carrying.display_noun() if Game.player and is_instance_valid(Game.player.carrying) else "Put it here"


func interact_point() -> Vector3:
	return global_position


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.25, -0.1, -0.25), Vector3(0.5, 0.3, 0.5))]


func interact() -> bool:
	return Game.player != null and Game.player.place(self)


func item_transform(index: int) -> Transform3D:
	# Override for a table, hook or woodbox with authored placement slots.
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2 * index, 0.0))


func add_item(item: Carryable) -> void:
	held.append(item)
	item.socket = self
	item.tree_exiting.connect(remove_item.bind(item), CONNECT_ONE_SHOT)
	_reflow()


func remove_item(item: Carryable) -> void:
	if item.tree_exiting.is_connected(remove_item.bind(item)):
		item.tree_exiting.disconnect(remove_item.bind(item))
	held.erase(item)
	item.socket = null
	_reflow()


func _reflow() -> void:
	for index in held.size():
		held[index].global_transform = item_transform(index)
		held[index].refresh_interaction()
	refresh_interaction()


func _exit_tree() -> void:
	for item in held.duplicate():
		if is_instance_valid(item):
			remove_item(item)
