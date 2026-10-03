class_name Hunter
extends Node3D

# The one in the tree line. It wants her still: watched, it leaves, and before
# the third page it only stands where she is not looking. After that it walks
# to her. It will not cross the threshold. It waits on the step, and the
# waiting counts. The body is the Quaternius male rig, cloaked to a silhouette.

var trail: Trail
var offset: float = 0.0
var model: Node3D
var eyes: Node3D
var animation_player: AnimationPlayer
var _clip: String = ""
var _shown := false
var _hunting := false
var _hidden_for := 12.0
var _visible_for := 0.0
var _watched := 0.0
var _snap_in := 6.0


func _ready() -> void:
	_build_model()
	_hide()
	Game.hunter = self


func _physics_process(delta: float) -> void:
	if trail == null or Game.player == null:
		return
	if Game.phase == Game.Phase.INTRO or Game.phase == Game.Phase.PAUSED:
		return
	if Game.phase == Game.Phase.CAUGHT or Game.phase == Game.Phase.ESCAPED:
		_play("Idle")
		return
	if _reached_exit():
		Game.escape()
		return
	if Game.notes_found < Tune.HUNT_NOTES:
		_stalk(delta)
	else:
		_pursue(delta)


func _reached_exit() -> bool:
	var player := Game.player.global_position
	var end := trail.exit_point
	return Vector2(player.x - end.x, player.z - end.z).length() <= Tune.EXIT_RADIUS


func _stalk(delta: float) -> void:
	_hunting = false
	if not _shown:
		_hidden_for -= delta
		Game.set_closeness(0.0)
		if _hidden_for <= 0.0:
			_appear()
		return
	_visible_for -= delta
	_face(Game.player.global_position)
	var distance := _distance_to_player()
	if _player_is_looking():
		_watched += delta
	else:
		_watched = maxf(_watched - delta * 0.5, 0.0)
	if _watched > 0.55 or distance < 7.5 or _visible_for <= 0.0:
		_hide()
		if Game.soundscape and randf() < 0.35:
			Game.soundscape.play_snap(global_position + Vector3.UP * 0.3, Loudness.BRANCH_SNAP - 8.0)
		return
	# Near enough to feel, not near enough to be the chase. The eyes are the tell.
	Game.set_closeness(clampf(lerpf(0.46, 0.34, distance / 30.0), 0.34, 0.46))
	_play("Idle")
	if eyes:
		eyes.visible = true
	if model:
		model.visible = true


func _pursue(delta: float) -> void:
	if not _hunting:
		_hunting = true
		if not _shown or _distance_to_player() > 40.0:
			_place_behind(randf_range(16.0, 22.0))
		_shown = true
	var threat := _threat()
	var speed := lerpf(Tune.HUNTER_CREEP, Tune.HUNTER_CHASE, smoothstep(0.2, 1.0, threat))
	var player_at := Game.player.global_position
	# It does not come into the house. It goes to the doorstep and waits;
	# the hunt clock keeps running while she hides.
	var sheltered := Game.indoors(player_at + Vector3(0.0, 0.9, 0.0))
	if sheltered and Game.house:
		player_at = Game.house.doorstep()
	var flat := player_at - global_position
	flat.y = 0.0
	var distance := flat.length()
	if distance > 0.08:
		var step := minf(speed * delta, distance)
		var next := global_position + flat.normalized() * step
		next = _clamp_inside(next)
		next.y = trail.ground.height_at(next.x, next.z) if trail.ground else next.y
		global_position = next
	_face(player_at)
	offset = trail.offset_of(global_position)
	var horizon := lerpf(30.0, 15.0, threat)
	var presence := clampf(1.0 - distance / horizon, 0.0, 1.0) * lerpf(0.42, 1.0, threat)
	Game.set_closeness(presence)
	if model:
		model.visible = distance < Tune.REVEAL_BODY + threat * 18.0
	if eyes:
		eyes.visible = threat > 0.62 and distance < Tune.REVEAL_EYES
	_play("Sprint" if speed > 3.3 else "Walk")
	_ambience(delta, distance, threat)
	if sheltered:
		# Felt through the walls, never touching her.
		Game.set_closeness(minf(presence, 0.5))
	elif distance < Tune.CATCH_GAP and threat >= 0.48:
		Game.catch_player(
			"You stopped",
			"The one from the trees does not hurry until it knows you have stopped. The snow closed over the place you were."
		)


func _threat() -> float:
	var from_notes := float(Game.notes_found - Tune.HUNT_NOTES) / 2.0
	var from_time := clampf(Game.seconds_hunting() / 75.0, 0.0, 1.0)
	return clampf(0.26 + from_notes * 0.46 + from_time * 0.34, 0.0, 1.0)


func _appear() -> void:
	var camera := Game.player.camera
	var forward := Vector3.FORWARD
	if camera:
		forward = -camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length() > 0.01:
			forward = forward.normalized()
	var placed := false
	for _attempt in 10:
		var angle := randf() * TAU
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var align := dir.dot(forward)
		if align > 0.78 or align < -0.15:
			continue
		var at := Game.player.global_position + dir * randf_range(16.0, 30.0)
		if not _inside(at, 6.0):
			continue
		_move_to(at)
		placed = true
		break
	if not placed:
		_place_behind(20.0)
	_shown = true
	_visible_for = randf_range(5.5, 8.5)
	_watched = 0.0
	if model:
		model.visible = true
	if eyes:
		eyes.visible = true
	_play("Idle")


func _hide() -> void:
	_shown = false
	_watched = 0.0
	if model:
		model.visible = false
	if eyes:
		eyes.visible = false
	var patience := lerpf(14.0, 4.5, float(Game.notes_found) / float(Tune.HUNT_NOTES))
	_hidden_for = randf_range(patience * 0.75, patience)


func _place_behind(distance: float) -> void:
	var back := Game.player.global_transform.basis.z
	back.y = 0.0
	if back.length() < 0.01:
		back = Vector3(0, 0, 1)
	_move_to(Game.player.global_position + back.normalized() * distance)


func _move_to(at: Vector3) -> void:
	at = _clamp_inside(at)
	at.y = trail.ground.height_at(at.x, at.z) if trail.ground else 0.0
	global_position = at
	_face(Game.player.global_position)
	# A jump to a new spot, not a glide across the field.
	reset_physics_interpolation()


func _clamp_inside(at: Vector3) -> Vector3:
	at.x = clampf(at.x, Tune.FENCE_MIN_X + 2.0, Tune.FENCE_MAX_X - 2.0)
	at.z = clampf(at.z, Tune.FENCE_MIN_Z + 2.0, Tune.FENCE_MAX_Z - 2.0)
	return at


func _inside(at: Vector3, margin: float) -> bool:
	return at.x > Tune.FENCE_MIN_X + margin and at.x < Tune.FENCE_MAX_X - margin and at.z > Tune.FENCE_MIN_Z + margin and at.z < Tune.FENCE_MAX_Z - margin


func _distance_to_player() -> float:
	var delta := Game.player.global_position - global_position
	delta.y = 0.0
	return delta.length()


func _player_is_looking() -> bool:
	var camera := Game.player.camera
	if camera == null:
		return false
	var to_me := global_position + Vector3(0.0, 2.1, 0.0) - camera.global_position
	if to_me.length() < 0.2:
		return true
	var forward := -camera.global_transform.basis.z
	return forward.dot(to_me.normalized()) > 0.86


func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.distance_squared_to(global_position) < 0.04:
		return
	look_at(flat, Vector3.UP)


func _ambience(delta: float, distance: float, threat: float) -> void:
	if Game.soundscape == null or distance < 8.0:
		return
	_snap_in -= delta
	if _snap_in > 0.0:
		return
	_snap_in = randf_range(lerpf(11.0, 4.0, threat), lerpf(18.0, 7.0, threat))
	# Where it is: a branch underfoot, heavier as it closes in.
	Game.soundscape.play_snap(global_position + Vector3.UP * 0.3, Loudness.BRANCH_SNAP + lerpf(-6.0, 2.0, threat))


func _build_model() -> void:
	var path := "res://addons/quaternius_ik_rigged/Models_with_rigging/Master_Rigged.tscn"
	if ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate()
		model.scale = Vector3(0.78, 1.5, 0.78) * Tune.ACTOR_SCALE
		model.rotation.y = PI
		add_child(model)
		_cloak(model)
		animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	eyes = Node3D.new()
	eyes.name = "Eyes"
	add_child(eyes)
	_eye(Vector3(-0.05, 2.42, -0.16))
	_eye(Vector3(0.05, 2.42, -0.16))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.08, 0.05)
	glow.light_energy = 0.35
	glow.omni_range = 3.2
	glow.position = Vector3(0, 2.42, -0.12)
	glow.light_volumetric_fog_energy = 0.4
	eyes.add_child(glow)
	eyes.visible = false
	if model:
		model.visible = false


func _eye(at: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.028
	sphere.height = 0.056
	mesh_instance.mesh = sphere
	mesh_instance.position = at
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.16, 0.1)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.05, 0.02)
	material.emission_energy_multiplier = 2.4
	mesh_instance.material_override = material
	eyes.add_child(mesh_instance)


func _cloak(root: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.012, 0.012, 0.014)
	material.roughness = 0.48
	material.metallic = 0.04
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).material_override = material


func _play(clip: String) -> void:
	if animation_player == null or not _shown:
		return
	var resolved := clip
	if not animation_player.has_animation(resolved):
		var suffix := "/" + clip
		resolved = ""
		for name in animation_player.get_animation_list():
			if name.ends_with(suffix):
				resolved = name
				break
		if resolved == "" and clip == "Sprint":
			_play("Jog_Fwd")
			return
		if resolved == "" and clip == "Idle":
			_play("Idle_Talking")
			return
	if resolved == "" or resolved == _clip:
		return
	var animation := animation_player.get_animation(resolved)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(resolved, 0.25)
	_clip = resolved
