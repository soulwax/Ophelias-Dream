class_name DoorHingeDynamics
extends RefCounted

## One hinged leaf, ported from merl. E-toggles drive it with a damped spring
## to the stop. The moving collision shape is swept through each candidate
## arc so a door cannot swing through a wall or a prop.

const MAX_SPEED := 3.3
const DRAG_PER_SECOND := 2.4
const DRIVE_STIFFNESS := 38.0
const DRIVE_DAMPING := 10.5
const SWEEP_STEP_RADIANS := 0.045

var open_rotation := 0.0
var angle := 0.0
var angular_velocity := 0.0
var driving := false
var drive_open := false
var blocked := false
# 1 for a hand on the door; well below 1 for a door that drifts by itself.
var pace := 1.0


func configure(rotation_limit: float) -> void:
	open_rotation = rotation_limit
	angle = 0.0
	angular_velocity = 0.0
	driving = false
	drive_open = false


func request(open: bool, drive_pace: float = 1.0) -> void:
	driving = true
	drive_open = open
	pace = drive_pace


func step(delta: float, pivot: Node3D, collision_body: StaticBody3D, collision_shape: CollisionShape3D) -> void:
	if delta <= 0.0:
		return
	var target := open_rotation if drive_open else 0.0
	if driving:
		angular_velocity += (DRIVE_STIFFNESS * pace * pace * (target - angle) - DRIVE_DAMPING * pace * angular_velocity) * delta
	else:
		angular_velocity *= exp(-DRAG_PER_SECOND * delta)
	angular_velocity = clampf(angular_velocity, -MAX_SPEED, MAX_SPEED)
	var candidate := clampf(angle + angular_velocity * delta, minf(0.0, open_rotation), maxf(0.0, open_rotation))
	if absf(candidate - angle) > 0.0001 and not _arc_is_clear(pivot, collision_body, collision_shape, angle, candidate):
		angular_velocity = 0.0
		blocked = true
		return
	blocked = false
	angle = candidate
	pivot.rotation.y = angle
	if is_equal_approx(angle, 0.0) or is_equal_approx(angle, open_rotation):
		angular_velocity = 0.0
	if driving and absf(target - angle) < 0.002 and absf(angular_velocity) < 0.04:
		angle = target
		pivot.rotation.y = target
		angular_velocity = 0.0
		driving = false


func open_fraction() -> float:
	return clampf(1.0 - cos(angle), 0.0, 1.0)


func _arc_is_clear(pivot: Node3D, body: StaticBody3D, shape: CollisionShape3D, from_angle: float, to_angle: float) -> bool:
	if shape == null or shape.shape == null or pivot.get_world_3d() == null:
		return true
	var pivot_to_shape := pivot.global_transform.affine_inverse() * shape.global_transform
	var parent := pivot.get_parent() as Node3D
	if parent == null:
		return true
	# The solid leaf nearly touches floor and jamb; sweep an inset hull.
	var sweep_shape: Shape3D = shape.shape
	if shape.shape is BoxShape3D:
		var authored := shape.shape as BoxShape3D
		var inset := BoxShape3D.new()
		inset.size = Vector3(maxf(0.05, authored.size.x - 0.02), maxf(0.05, authored.size.y - 0.06), maxf(0.02, authored.size.z - 0.008))
		sweep_shape = inset
	var samples := maxi(1, ceili(absf(to_angle - from_angle) / SWEEP_STEP_RADIANS))
	for index in range(1, samples + 1):
		var sample_angle := lerpf(from_angle, to_angle, float(index) / float(samples))
		var pivot_pose := parent.global_transform * Transform3D(Basis(Vector3.UP, sample_angle), pivot.position)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sweep_shape
		query.transform = pivot_pose * pivot_to_shape * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0))
		query.collision_mask = Tune.LAYER_WORLD
		query.exclude = [body.get_rid()]
		var hits := pivot.get_world_3d().direct_space_state.intersect_shape(query, 1)
		if not hits.is_empty():
			return false
	return true
