class_name Aim
extends RefCounted

# What she is pointing at, worked out once per rendered frame from the camera
# that frame drew, so whatever is outlined is exactly what a press uses.
#
# Every page, door and switch reports a pick box (aim_box: [global transform,
# local AABB]). The ray from the screen centre takes the nearest box it
# enters, unless a wall comes first. If that thing is in reach (the nearest
# point of its box to her chest, or to her feet for a page, with nothing in
# between), it is the target. If it is not, it is shown as out of reach and
# nothing else is chosen in its place. With nothing under the reticle, the
# thing in reach closest to it within AIM_CONE is chosen, and a held choice
# only gives way to one clearly closer to the centre.

## What a press uses this frame.
var target: Node3D
## True when the target is under the reticle, not chosen around it.
var direct := false
## Under the reticle but out of her reach.
var far: Node3D


func update(player: Player) -> void:
	var previous := target
	target = null
	direct = false
	far = null
	var camera := player.camera
	if player.bow_hoist and player.bow_hoist.Busy:
		return
	if camera == null or not player.is_inside_tree() or Game.phase not in [Game.Phase.PLAYING, Game.Phase.DREAM] or player.glance > 0.05:
		return
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var candidates := _candidates(player)
	var nearest := INF
	var hovered: Node3D = null
	for thing in candidates:
		var t := _ray_box(thing, origin, forward)
		if t >= 0.0 and t < nearest:
			nearest = t
			hovered = thing
	if hovered and not _blocked(player, origin, origin + forward * nearest, hovered):
		if _in_reach(player, hovered):
			target = hovered
			direct = true
		else:
			far = hovered
		return
	var best: Node3D = null
	var best_angle := Tune.AIM_CONE
	var kept_angle := INF
	for thing in candidates:
		if not _in_reach(player, thing):
			continue
		var angle := rad_to_deg(forward.angle_to(centre_of(thing) - origin))
		if angle > Tune.AIM_CONE:
			continue
		if thing == previous:
			kept_angle = angle
		if angle < best_angle:
			best_angle = angle
			best = thing
	if previous and kept_angle <= best_angle + Tune.AIM_STICKY:
		best = previous
	target = best


static func centre_of(thing: Node3D) -> Vector3:
	var box: Array = thing.call("aim_box")
	return (box[0] as Transform3D) * (box[1] as AABB).get_center()


# Pages, doors and switches near enough to matter, and visible.
func _candidates(player: Player) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var near := Tune.AIM_RANGE + 2.0
	for group_name in ["interactables", "field_notes"]:
		for node in player.get_tree().get_nodes_in_group(group_name):
			var thing := node as Node3D
			if thing == null or not thing.is_visible_in_tree() or not thing.has_method("aim_box"):
				continue
			if Game.phase == Game.Phase.DREAM and thing.is_in_group("bow_pickup"):
				continue
			if thing.global_position.distance_to(player.global_position) > near:
				continue
			found.append(thing)
	return found


# How far along the ray it enters the thing's box, or -1.
func _ray_box(thing: Node3D, origin: Vector3, direction: Vector3) -> float:
	var box: Array = thing.call("aim_box")
	var frame: Transform3D = box[0]
	var bounds: AABB = box[1]
	var inverse := frame.affine_inverse()
	var hit: Variant = bounds.intersects_ray(inverse * origin, inverse.basis * direction)
	if hit == null:
		return -1.0
	var along := (frame * (hit as Vector3) - origin).dot(direction)
	return along if along >= 0.0 and along <= Tune.AIM_RANGE else -1.0


func _closest(thing: Node3D, from: Vector3) -> Vector3:
	var box: Array = thing.call("aim_box")
	var frame: Transform3D = box[0]
	var bounds: AABB = box[1]
	return frame * (frame.affine_inverse() * from).clamp(bounds.position, bounds.end)


func _in_reach(player: Player, thing: Node3D) -> bool:
	var chest := player.global_position + Vector3(0.0, 1.2, 0.0)
	if thing is FieldNote:
		# Not at a run, and judged from her feet: pages lie on the ground.
		if player.velocity.length() > Tune.WALK_SPEED + 0.55:
			return false
		var feet := player.global_position + Vector3(0.0, 0.1, 0.0)
		if feet.distance_to(_closest(thing, feet)) > Tune.READ_DISTANCE:
			return false
		# Above the paper, so a slope between them does not hide it.
		return not _blocked(player, chest, thing.global_position + Vector3(0.0, 1.0, 0.0), thing)
	var point := _closest(thing, chest)
	if chest.distance_to(point) > Tune.INTERACT_REACH:
		return false
	return not _blocked(player, chest, point, thing)


# Something solid between from and to that is not the thing itself.
func _blocked(player: Player, from: Vector3, to: Vector3, thing: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Tune.LAYER_WORLD)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit.get("collider") as Node
	if collider and (collider == thing or thing.is_ancestor_of(collider)):
		return false
	return (hit["position"] as Vector3).distance_to(to) > 0.06
