class_name Carryable
extends Node3D

signal picked
signal placed(socket: CarrySocket)
signal dropped

@export var kind: String = "cup"
@export var heavy: bool = false
@export var item_id: String = ""
@export var noun: String = ""
var visual: Node3D
var socket: CarrySocket
var carrier: Player
var _visual_rest := Transform3D.IDENTITY


func _ready() -> void:
	add_to_group("carryables")
	if visual == null:
		visual = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.42, 0.2, 0.26) if heavy else Vector3(0.12, 0.16, 0.12)
		(visual as MeshInstance3D).mesh = mesh
		visual.position.y = mesh.size.y * 0.5
		add_child(visual)
	_visual_rest = visual.transform
	Game.phase_changed.connect(_phase_changed)
	refresh_interaction()


func display_noun() -> String:
	return noun if not noun.is_empty() else kind


func can_take() -> bool:
	return not Game.dream_mode and not Game.mathilda_pov and carrier == null and (not is_instance_valid(socket) or socket.allow_take)


func refresh_interaction() -> void:
	# While her hands are full it stays aimable, so a press says why it won't come.
	if can_take() and Game.player != null:
		add_to_group("interactables")
	else:
		remove_from_group("interactables")


func _phase_changed(_phase: int) -> void:
	refresh_interaction()


func interact_label() -> String:
	return "Pick up the %s" % display_noun()


func interact_point() -> Vector3:
	return global_position


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.22, -0.12, -0.16), Vector3(0.44, 0.3, 0.32))]


func interact() -> bool:
	return Game.player != null and Game.player.pick_up(self)


func blocked_label() -> String:
	if Game.player != null and is_instance_valid(Game.player.carrying):
		return "Your hands are full."
	return ""


func return_visual() -> void:
	if is_instance_valid(visual):
		visual.reparent(self, false)
		visual.transform = _visual_rest


func _exit_tree() -> void:
	# The visual lives under the rig while held; do not orphan it on removal.
	if is_instance_valid(visual) and visual.get_parent() != self:
		visual.queue_free()
