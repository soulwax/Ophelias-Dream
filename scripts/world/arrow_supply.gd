extends Node3D

@export var supply_id := "trail_arrows"
@export var quantity := 6
var visual: Node3D
var reserved := false

func _ready() -> void:
	add_to_group("arrow_supplies")
	visual = Node3D.new()
	add_child(visual)
	for index in mini(quantity, 6):
		var arrow := (load(Tune.ARROW_MODEL) as PackedScene).instantiate() as Node3D
		arrow.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
		arrow.rotation.x = -PI * 0.5
		arrow.rotation.z = (float(index) - 2.5) * 0.04
		arrow.position.x = (float(index) - 2.5) * 0.024
		visual.add_child(arrow)
	refresh()

func refresh() -> void:
	var remaining := quantity - int(Game.arrow_pickups.get(supply_id, 0))
	visible = remaining > 0
	if remaining > 0:
		add_to_group("interactables")
	else:
		remove_from_group("interactables")
	for index in visual.get_child_count():
		(visual.get_child(index) as Node3D).visible = index < remaining

func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.16, -0.38, -0.1), Vector3(0.32, 0.76, 0.2))]

func interact_label() -> String:
	return "Collect the arrows"

func blocked_label() -> String:
	return "Your quiver is full." if Game.arrow_count >= Tune.ARROW_CAPACITY else "Step closer to collect the arrows."

func interact() -> bool:
	if reserved or Game.phase != Game.Phase.PLAYING or Game.player == null:
		return false
	if quantity <= int(Game.arrow_pickups.get(supply_id, 0)) or Game.arrow_count >= Tune.ARROW_CAPACITY:
		return false
	if not Game.player.collect_arrows(self, visual):
		return false
	reserved = true
	remove_from_group("interactables")
	return true

func complete_collection() -> void:
	if not reserved:
		return
	var already := int(Game.arrow_pickups.get(supply_id, 0))
	var amount := mini(quantity - already, Tune.ARROW_CAPACITY - Game.arrow_count)
	Game.arrow_count += amount
	Game.arrow_pickups[supply_id] = already + amount
	reserved = false
	# The animation carried a temporary copy; the world bundle remains here.
	refresh()
	Game.interaction_feedback.emit("Collected %d arrows." % amount, true)
