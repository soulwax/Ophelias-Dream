extends Node3D

var velocity := Vector3.ZERO
var stuck := false
var flight_seconds := 0.0
var visual: Node3D
var shooter: RID

func _ready() -> void:
	add_to_group("fired_arrows")
	visual = (load(Tune.ARROW_MODEL) as PackedScene).instantiate() as Node3D
	visual.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	visual.rotation.x = -PI * 0.5
	add_child(visual)

func _physics_process(delta: float) -> void:
	if stuck or not Game.awake():
		return
	flight_seconds += delta
	if flight_seconds > Tune.ARROW_FLIGHT_SECONDS:
		queue_free()
		return
	var before := global_position
	velocity.y -= Tune.ARROW_GRAVITY * delta
	var after := before + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(before, after, Tune.LAYER_WORLD)
	query.exclude = [shooter] if shooter.is_valid() else []
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		stuck = true
		add_to_group("interactables")
		var collider := hit.collider as Node
		if collider and collider.has_method("receive_arrow"):
			collider.call("receive_arrow", global_position, velocity)
	else:
		global_position = after
	if velocity.length_squared() > 0.01:
		global_basis = Basis.looking_at(-velocity.normalized(), Vector3.UP)

func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.06, -0.06, -0.35), Vector3(0.12, 0.12, 0.7))]

func interact_label() -> String:
	return "Recover the arrow"

func blocked_label() -> String:
	return "Your quiver is full."

func interact() -> bool:
	if not stuck or Game.phase != Game.Phase.PLAYING or Game.arrow_count >= Tune.ARROW_CAPACITY:
		return false
	if not Game.player.collect_arrows(self, visual):
		return false
	remove_from_group("interactables")
	return true

func complete_collection() -> void:
	Game.arrow_count += 1
	queue_free()
