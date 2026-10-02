class_name Player
extends CharacterBody3D

const BOOM_LENGTH := 3.35
const BOOM_STEPS := 16
const BOOM_CLEARANCE := 0.35

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
var _sprinting := false
var _left_foot := false
var _glide := Vector3.ZERO
var footprints: Footprints
var stride: Stride
var kicks: SnowKick
# Footfalls come from distance covered, so sound, prints and powder land in
# rhythm with the stride at any speed.
var _travel := 0.0
var _stride_phase := 0.0
# Camera life: a footfall jolt, an alternating roll, a boom that stretches
# and a pivot that trails her momentum.
var _jolt := 0.0
var _roll_kick := 0.0
var _boom := BOOM_LENGTH
var _trail_offset := Vector3.ZERO
# Dev hook: RUN_AUTOPILOT=walk or sprint holds forward (and sprint), so
# RUN_CAPTURE can photograph her mid-stride.
var _autopilot := OS.get_environment("RUN_AUTOPILOT")
var outfit: Outfit
var breath: Breath
# 0 calm .. 1 gasping. Climbs with sprinting and spent stamina, peaks just
# after a long sprint ends, and only slowly settles.
var strain := 0.0
# Space: no steam while held, but it drains her breath, and letting go (or
# running out) comes out as a gasp.
var holding_breath := false
var _held_for := 0.0
var _facing := 0.0
var _lean := Vector2.ZERO
var _sway := 0.0
var _last_glide := Vector3.ZERO


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
	kicks = SnowKick.new()
	add_child(kicks)
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
		_glide = _glide.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = _glide.x
		velocity.z = _glide.z
		if not is_on_floor():
			velocity.y -= Tune.GRAVITY * delta
		move_and_slide()
		_sway = 0.0
		if stride:
			stride.update(_ground_speed())
		_breathe(delta, false)
		_carry(delta, false)
		_move_camera(delta)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _autopilot != "":
		input = Vector2(0.0, -1.0)
	var wish := Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish = global_transform.basis * wish
	wish.y = 0.0

	var moving := wish.length() > 0.05
	if exhaust_left > 0.0:
		exhaust_left -= delta
	var wants_sprint := moving and (Input.is_action_pressed("sprint") or _autopilot == "sprint") and exhaust_left <= 0.0
	var sprinting := wants_sprint and stamina > 0.0 and (_sprinting or stamina > 0.4)
	_sprinting = sprinting
	var speed := Tune.WALK_SPEED
	if sprinting:
		speed = Tune.SPRINT_SPEED
		stamina = maxf(stamina - delta, 0.0)
		if stamina <= 0.0:
			exhaust_left = Tune.EXHAUST_LOCK
			_sprinting = false
			_stumble()
	elif exhaust_left <= 0.0 and not holding_breath:
		stamina = minf(stamina + delta * Tune.STAMINA_REGEN, Tune.STAMINA_MAX)
	speed *= _slope_factor(wish)

	if not is_on_floor():
		velocity.y -= Tune.GRAVITY * delta
	else:
		velocity.y = -1.0
	# Wind leans on her stride only; standing still she holds her ground.
	var push := Vector3.ZERO
	if Game.weather and moving:
		push = Game.weather.wind * 0.03 * (1.0 + Game.weather.gust * 0.8)
	var target := Vector3(wish.x, 0.0, wish.z) * speed
	_glide = _glide.move_toward(target, _momentum(target, moving, sprinting) * delta)
	velocity.x = _glide.x + push.x
	velocity.z = _glide.z + push.z
	move_and_slide()
	_animate(moving, sprinting)
	_breathe(delta, sprinting)
	_carry(delta, sprinting)
	_steps(delta, sprinting)
	_move_camera(delta)
	_flicker_lantern(delta)


# Quick to get going, a short coast when she lets go or eases off a sprint,
# and hard braking when she reverses: weight without sluggishness.
func _momentum(target: Vector3, moving: bool, sprinting: bool) -> float:
	if not moving:
		return Tune.STRIDE_COAST
	if _glide.length() > 0.5 and _glide.dot(target) < 0.0:
		return Tune.STRIDE_BRAKE
	if target.length() > _glide.length():
		return Tune.STRIDE_ACCEL_SPRINT if sprinting else Tune.STRIDE_ACCEL_WALK
	return Tune.STRIDE_COAST


# Uphill costs speed, downhill gives a little back.
func _slope_factor(direction: Vector3) -> float:
	if trail == null or trail.ground == null or direction.length() < 0.05:
		return 1.0
	var ahead := direction.normalized() * 0.8
	var here := trail.ground.height_at(global_position.x, global_position.z)
	var there := trail.ground.height_at(global_position.x + ahead.x, global_position.z + ahead.z)
	return clampf(1.0 - (there - here) / 0.8 * 0.8, 0.72, 1.12)


# Out of breath mid-sprint: she staggers, loses most of her speed, and the
# camera drops with her.
func _stumble() -> void:
	if stride:
		stride.stumble()
	_glide *= 0.5
	_jolt -= 0.09
	strain = 1.0
	if Game.soundscape:
		Game.soundscape.play_step(true)


func _ground_speed() -> float:
	return Vector2(_glide.x, _glide.z).length()


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
	_facing = _yaw


func _apply_look() -> void:
	rotation.y = _yaw
	if spring_arm:
		spring_arm.rotation.x = _pitch
		_fit_boom_to_ground()
	if camera:
		var shake := Game.weather.gust * 0.012 if Game.weather else 0.0
		camera.rotation.z = sin(Time.get_ticks_msec() * 0.009) * shake + _roll_kick


# The ground mesh is one-sided, so a camera that slips under a slope sees
# straight through it. Walk the boom outward and stop before it goes under.
func _fit_boom_to_ground() -> void:
	if trail == null or trail.ground == null:
		return
	var pivot := spring_arm.global_position
	var back := spring_arm.global_transform.basis.z
	var reach := _boom
	for i in range(1, BOOM_STEPS + 1):
		var along := _boom * float(i) / float(BOOM_STEPS)
		var probe := pivot + back * along
		if probe.y < trail.ground.height_at(probe.x, probe.z) + BOOM_CLEARANCE:
			reach = _boom * float(i - 1) / float(BOOM_STEPS)
			break
	spring_arm.spring_length = maxf(reach, 0.5)


func _animate(moving: bool, sprinting: bool) -> void:
	if stride:
		stride.update(_ground_speed())
	# A slight side-to-side carry in time with her steps.
	_sway = 0.0 if not moving else sin(_stride_phase) * (0.012 if sprinting else 0.02)


func _breathe(delta: float, sprinting: bool) -> void:
	var awake := Game.phase == Game.Phase.PLAYING or Game.phase == Game.Phase.READING
	var hold := awake and exhaust_left <= 0.0 and stamina > 0.0 and Input.is_action_pressed("hold_breath")
	if hold:
		_held_for += delta
		stamina = maxf(stamina - Tune.HOLD_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			exhaust_left = Tune.EXHAUST_LOCK
			hold = false
	if holding_breath and not hold:
		if breath:
			breath.gasp(clampf(_held_for / 6.0, 0.25, 1.0))
		# What she held comes due as panting.
		strain = maxf(strain, clampf(0.35 + _held_for * 0.09, 0.0, 1.0))
		_held_for = 0.0
	holding_breath = hold
	if breath:
		breath.held = hold
	var spent := 1.0 - stamina / Tune.STAMINA_MAX
	var target := spent * 0.55
	if sprinting:
		# Faster the longer she runs.
		target = 0.3 + spent * 0.6
	elif spent > 0.3:
		# Hardest right after she stops, while the loss is still large.
		target = minf(1.0, 0.2 + spent * 1.1)
	if exhaust_left > 0.0:
		target = 1.0
	strain = move_toward(strain, target, delta * (0.8 if target > strain else 0.09))
	if breath:
		breath.strain = strain


# She turns to where she is going instead of snapping to the camera, leans
# into her acceleration and into curves, and settles when she stops.
func _carry(delta: float, sprinting: bool) -> void:
	if visual == null:
		return
	var flat := Vector3(_glide.x, 0.0, _glide.z)
	var turn_rate := 0.0
	if flat.length() > 0.35:
		var before := _facing
		var target_yaw := atan2(-flat.x, -flat.z)
		_facing = lerp_angle(_facing, target_yaw, 1.0 - exp(-delta * (9.0 if sprinting else 6.0)))
		turn_rate = angle_difference(before, _facing) / maxf(delta, 0.0001)
	var accel := (_glide - _last_glide) / maxf(delta, 0.0001)
	_last_glide = _glide
	var heading := Vector3(-sin(_facing), 0.0, -cos(_facing))
	var pace := flat.length() / Tune.SPRINT_SPEED
	var pitch := clampf(-(pace * 0.09 + accel.dot(heading) * 0.012), -0.2, 0.1)
	var roll := clampf(turn_rate * pace * 0.07, -0.16, 0.16)
	_lean = _lean.lerp(Vector2(pitch, roll), 1.0 - exp(-delta * 5.0))
	visual.rotation = Vector3(_lean.x, _facing - _yaw, _lean.y + _sway)


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


# The camera breathes with her pace: wider and further back at a sprint,
# trailing her momentum a little, and jolted by each footfall.
func _move_camera(delta: float) -> void:
	if spring_arm == null or camera == null:
		return
	var pace := clampf((_ground_speed() - Tune.WALK_SPEED) / (Tune.SPRINT_SPEED - Tune.WALK_SPEED), 0.0, 1.0)
	camera.fov = lerpf(camera.fov, 68.0 + 9.0 * pace, 1.0 - exp(-delta * 4.0))
	_boom = lerpf(_boom, BOOM_LENGTH + 0.5 * pace, 1.0 - exp(-delta * 3.0))
	_jolt = lerpf(_jolt, 0.0, 1.0 - exp(-delta * 11.0))
	_roll_kick = lerpf(_roll_kick, 0.0, 1.0 - exp(-delta * 8.0))
	var lag := global_transform.basis.inverse() * Vector3(-_glide.x, 0.0, -_glide.z) * 0.04
	_trail_offset = _trail_offset.lerp(lag.limit_length(0.32), 1.0 - exp(-delta * 3.0))
	spring_arm.position = Vector3(0.0, 1.5 + _jolt, 0.0) + _trail_offset


func _flicker_lantern(_delta: float) -> void:
	if lantern == null:
		return
	lantern.light_energy = 0.22 + sin(Time.get_ticks_msec() * 0.013) * 0.03


func _steps(delta: float, sprinting: bool) -> void:
	var speed := _ground_speed()
	if not is_on_floor() or speed < 0.3:
		_travel = 0.0
		return
	# Step length grows with pace, so footfalls stay in time with the legs.
	var step_length := lerpf(0.62, 1.12, smoothstep(1.2, Tune.SPRINT_SPEED, speed))
	_travel += speed * delta
	_stride_phase += speed * delta / step_length * PI
	if _travel < step_length:
		return
	_travel -= step_length
	_left_foot = not _left_foot
	var heavy := speed > 4.0 or sprinting
	var power := clampf(speed / Tune.SPRINT_SPEED, 0.2, 1.0)
	if Game.soundscape:
		Game.soundscape.play_step(heavy)
	_jolt -= lerpf(0.004, 0.026, power * power)
	_roll_kick += (1.0 if _left_foot else -1.0) * lerpf(0.001, 0.01, power)
	var forward := Vector3(_glide.x, 0.0, _glide.z).normalized()
	var side := Vector3(forward.z, 0.0, -forward.x)
	var at := global_position + side * (0.12 if _left_foot else -0.12)
	if kicks:
		kicks.kick(at + Vector3(0, 0.05, 0), power, -forward)
	if footprints:
		footprints.stamp(at, atan2(forward.x, forward.z), heavy, _left_foot)


func _cloak(root: Node) -> void:
	var suit := _suit_material()
	var eyes := _eye_material()
	var hair := StandardMaterial3D.new()
	hair.albedo_color = Color(0.22, 0.12, 0.08)
	hair.roughness = 0.72
	hair.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh_instance as MeshInstance3D
		var mesh_name := instance.name.to_lower()
		if "brow" in mesh_name:
			instance.material_override = hair
		elif "eye" in mesh_name:
			instance.material_override = eyes
		else:
			instance.material_override = suit


func _suit_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/characters/girl_coat.png")
	material.albedo_color = Color.WHITE
	var normal_path := "res://addons/quaternius_ik_rigged/Godot - UE/T_Superhero_Female_Normal.png"
	if ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_texture = load(normal_path)
		material.normal_scale = 0.22
	material.roughness = 0.9
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _eye_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var path := "res://addons/quaternius_ik_rigged/Godot - UE/T_Eye_Brown.png"
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path)
	material.roughness = 0.28
	return material


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
	spring_arm.spring_length = BOOM_LENGTH
	spring_arm.margin = 0.18
	spring_arm.collision_mask = Tune.LAYER_WORLD
	var lens := SphereShape3D.new()
	lens.radius = 0.22
	spring_arm.shape = lens
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
	var path := "res://addons/quaternius_ik_rigged/Models_with_rigging/Female_Rigged.tscn"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	var model := packed.instantiate()
	model.scale = Vector3.ONE * Tune.ACTOR_SCALE
	model.rotation.y = PI
	visual.add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_cloak(model)
	outfit = Outfit.dress(model)
	if outfit:
		breath = Breath.new()
		outfit.attach("Head", breath, Transform3D(Basis(), outfit.mouth_rest))
	if animation_player:
		stride = Stride.build(animation_player, model)
