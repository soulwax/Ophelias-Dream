class_name Player
extends CharacterBody3D

var trail: Trail

var spring_arm: SpringArm3D
var camera: Camera3D
var lantern: SpotLight3D
var visual: Node3D
var animation_player: AnimationPlayer

var stamina: float = Tune.STAMINA_MAX
var _yaw: float = 0.0
var _pitch: float = -0.18
var exhaust_left: float = 0.0
var _step_debt: float = 0.0
var _bob: float = 0.0
var _clip: String = ""
var _sprinting := false
var _step_interval := 0.5
var _left_foot := false
var footprints: Footprints


func _ready() -> void:
	collision_layer = Tune.LAYER_ACTOR
	collision_mask = Tune.LAYER_WORLD
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true
	_build_body()
	_build_camera()
	_build_model()
	_place()
	footprints = Footprints.new()
	add_child(footprints)
	Game.player = self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if Game.phase == Game.Phase.READING:
			Game.close_reading()
			get_viewport().set_input_as_handled()
			return
		if Game.phase == Game.Phase.PLAYING:
			var page := nearby_note()
			if page:
				Game.active_note = page
				Game.begin_reading()
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and Game.phase == Game.Phase.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and not Game.locks_look():
		_yaw -= event.relative.x * Tune.MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * Tune.MOUSE_SENS, deg_to_rad(-50.0), deg_to_rad(22.0))


func _physics_process(delta: float) -> void:
	if trail == null:
		return
	_apply_look()
	if Game.locks_movement():
		velocity.x = move_toward(velocity.x, 0.0, Tune.SPRINT_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, Tune.SPRINT_SPEED)
		if not is_on_floor():
			velocity.y -= Tune.GRAVITY * delta
		move_and_slide()
		_play_clip("Idle_Talking")
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish = global_transform.basis * wish
	wish.y = 0.0

	var moving := wish.length() > 0.05
	if exhaust_left > 0.0:
		exhaust_left -= delta
	var wants_sprint := moving and Input.is_action_pressed("sprint") and exhaust_left <= 0.0
	var sprinting := wants_sprint and stamina > 0.0 and (_sprinting or stamina > 0.4)
	_sprinting = sprinting
	var speed := Tune.WALK_SPEED
	if sprinting:
		speed = Tune.SPRINT_SPEED
		stamina = maxf(stamina - delta, 0.0)
		if stamina <= 0.0:
			exhaust_left = Tune.EXHAUST_LOCK
			_sprinting = false
	elif exhaust_left <= 0.0:
		stamina = minf(stamina + delta * Tune.STAMINA_REGEN, Tune.STAMINA_MAX)

	if not is_on_floor():
		velocity.y -= Tune.GRAVITY * delta
	else:
		velocity.y = -1.0
	var push := Vector3.ZERO
	if Game.weather:
		push = Game.weather.wind * 0.065 * (1.0 + Game.weather.gust * 0.8)
	velocity.x = wish.x * speed + push.x
	velocity.z = wish.z * speed + push.z
	move_and_slide()
	_animate(moving, sprinting)
	_bob_camera(delta, moving, sprinting)
	_flicker_lantern(delta)
	_steps(delta, moving, sprinting)


func _place() -> void:
	if trail == null:
		return
	var at := trail.position_at(trail.player_start_offset)
	var height := trail.ground.height_at(at.x, at.z) if trail.ground else 0.2
	global_position = Vector3(at.x, height + 0.08, at.z)
	var ahead := trail.position_at(trail.player_start_offset + 2.0)
	var forward := ahead - at
	forward.y = 0.0
	if forward.length() > 0.01:
		_yaw = atan2(forward.x, -forward.z)


func _apply_look() -> void:
	rotation.y = _yaw
	if spring_arm:
		spring_arm.rotation.x = _pitch
	if camera and Game.weather:
		var shake := Game.weather.gust * 0.012
		camera.rotation.z = sin(Time.get_ticks_msec() * 0.009) * shake


func _animate(moving: bool, sprinting: bool) -> void:
	if not moving:
		_play_clip("Idle_Talking")
	elif sprinting:
		_play_clip("Sprint")
	else:
		_play_clip("Jog_Fwd")


func _play_clip(clip: String) -> void:
	if animation_player == null:
		return
	var resolved := _resolve(clip)
	if resolved == "" or resolved == _clip:
		return
	var animation := animation_player.get_animation(resolved)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(resolved, 0.16)
	_clip = resolved


func _resolve(clip: String) -> String:
	if animation_player.has_animation(clip):
		return clip
	var suffix := "/" + clip
	for name in animation_player.get_animation_list():
		if name.ends_with(suffix) or name.ends_with(clip):
			return name
	if clip == "Jog_Fwd":
		return _resolve("Walk")
	return ""


func nearby_note() -> FieldNote:
	if velocity.length() > Tune.WALK_SPEED + 0.55:
		return null
	var best: FieldNote = null
	var best_distance := Tune.READ_DISTANCE
	for node in get_tree().get_nodes_in_group("field_notes"):
		var page := node as FieldNote
		if page == null:
			continue
		var distance := global_position.distance_to(page.global_position)
		if distance < best_distance:
			best_distance = distance
			best = page
	return best


func _bob_camera(delta: float, moving: bool, sprinting: bool) -> void:
	if spring_arm == null:
		return
	if moving:
		_bob += delta * (9.0 if sprinting else 6.0)
	var bob := sin(_bob) * (0.035 if moving else 0.0)
	spring_arm.position.y = 1.5 + bob


func _flicker_lantern(_delta: float) -> void:
	if lantern == null:
		return
	lantern.light_energy = 0.22 + sin(Time.get_ticks_msec() * 0.013) * 0.03


func _steps(delta: float, moving: bool, sprinting: bool) -> void:
	if not moving or not is_on_floor():
		_step_debt = 0.0
		return
	_step_debt += delta
	if _step_debt < _step_interval:
		return
	_step_debt = 0.0
	_step_interval = randf_range(0.28, 0.36) if sprinting else randf_range(0.46, 0.62)
	_left_foot = not _left_foot
	if Game.soundscape:
		Game.soundscape.play_step(sprinting)
	if footprints == null:
		return
	var forward := Vector3(velocity.x, 0.0, velocity.z)
	if forward.length() < 0.05:
		return
	forward = forward.normalized()
	var side := Vector3(forward.z, 0.0, -forward.x)
	var yaw := atan2(forward.x, forward.z)
	var at := global_position + side * (0.12 if _left_foot else -0.12)
	footprints.stamp(at, yaw, sprinting, _left_foot)


func _cloak(root: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.17, 0.2)
	material.roughness = 0.78
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).material_override = material


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.55
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)


func _build_camera() -> void:
	spring_arm = SpringArm3D.new()
	spring_arm.position = Vector3(0, 1.5, 0)
	spring_arm.spring_length = 3.35
	spring_arm.margin = 0.18
	spring_arm.collision_mask = Tune.LAYER_WORLD
	add_child(spring_arm)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 420.0
	spring_arm.add_child(camera)

	lantern = SpotLight3D.new()
	lantern.light_color = Color(1.0, 0.82, 0.58)
	lantern.light_energy = 0.22
	lantern.spot_range = 7.0
	lantern.spot_angle = 24.0
	lantern.spot_attenuation = 0.8
	lantern.light_volumetric_fog_energy = 0.15
	lantern.shadow_enabled = false
	camera.add_child(lantern)

	var fill := OmniLight3D.new()
	fill.light_color = Color(0.7, 0.76, 0.9)
	fill.light_energy = 0.06
	fill.omni_range = 3.5
	fill.position = Vector3(0, 1.3, 0.2)
	add_child(fill)


func _build_model() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var path := "res://addons/quaternius_ik_rigged/Models_with_rigging/Master_Rigged.tscn"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	var model := packed.instantiate()
	model.scale = Vector3.ONE * Tune.ACTOR_SCALE
	model.rotation.y = PI
	visual.add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_cloak(model)
	_play_clip("Idle_Talking")
