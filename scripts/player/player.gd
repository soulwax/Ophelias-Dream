class_name Player
extends CharacterBody3D

const BOOM_LENGTH := 3.35
const BOOM_STEPS := 16
const BOOM_CLEARANCE := 0.35
const INDOOR_BOOM := 1.75
const INDOOR_SHOULDER := 0.36

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
var foot_lock: FootLock
var posture: Posture
var face: Face
# Per-step dynamics: time since the last real touchdown and how long a step
# has been taking, so speed can check on impact and surge on push-off.
var _since_plant := 0.0
var _step_time := 0.5
var _last_plant_msec := 0
# Jumping: forgiving at edges (coyote) and on early presses (buffer).
var _coyote := 0.0
var _jump_buffer := 0.0
var _airborne := false
var _jumped := false
var _air_time := 0.0
var _fall_speed := 0.0
var _air_weight := 0.0
# Sliding out of a sprint.
var sliding := false
var _slide_time := 0.0
var _slide_speed := 0.0
var _slide_dir := Vector3.FORWARD
var _slide_weight := 0.0
var _spray_in := 0.0
var _autopilot_clock := 0.0
# Footfalls come from distance covered, so sound, prints and powder land in
# rhythm with the stride at any speed.
var _travel := 0.0
var _stride_phase := 0.0
# Camera life: a footfall jolt, an alternating roll, a boom that stretches
# and a pivot that trails her momentum.
var _jolt := 0.0
var _roll_kick := 0.0
var _boom := BOOM_LENGTH
var _shoulder := 0.0
var _glow := 0.0
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
				return
			var thing := nearby_interactable()
			if thing:
				thing.call("interact")
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
		if sliding:
			_end_slide()
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
	var jump_pressed := Input.is_action_just_pressed("jump")
	var slide_pressed := Input.is_action_just_pressed("slide")
	if _autopilot != "":
		input = Vector2(0.0, -1.0)
		_autopilot_clock += delta
		if _autopilot == "jump" and _autopilot_clock > 1.3:
			_autopilot_clock = 0.0
			jump_pressed = true
		if _autopilot == "slide" and _autopilot_clock > 2.2:
			_autopilot_clock = 0.0
			slide_pressed = true
	var wish := Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish = global_transform.basis * wish
	wish.y = 0.0

	var moving := wish.length() > 0.05
	var on_floor := is_on_floor()
	if exhaust_left > 0.0:
		exhaust_left -= delta
	var running := Input.is_action_pressed("sprint") or _autopilot in ["sprint", "jump", "slide"]
	var wants_sprint := moving and running and exhaust_left <= 0.0 and not sliding
	# Once spent she must get some breath back before she can sprint again,
	# so holding Shift through exhaustion cannot stutter into a stumble loop.
	var sprinting := wants_sprint and stamina > 0.0 and (_sprinting or stamina > Tune.SPRINT_RESUME)
	_sprinting = sprinting
	var speed := Tune.WALK_SPEED
	if sprinting:
		speed = Tune.SPRINT_SPEED
		stamina = maxf(stamina - delta, 0.0)
		if stamina <= 0.0:
			exhaust_left = Tune.EXHAUST_LOCK
			_sprinting = false
			_stumble()
	elif exhaust_left <= 0.0 and not holding_breath and not sliding:
		stamina = minf(stamina + delta * Tune.STAMINA_REGEN, Tune.STAMINA_MAX)
	if on_floor:
		speed *= _slope_factor(wish)

	_coyote = Tune.COYOTE if on_floor else _coyote - delta
	_jump_buffer = Tune.JUMP_BUFFER if jump_pressed else _jump_buffer - delta
	if slide_pressed and on_floor and not sliding:
		_start_slide()
	if sliding:
		_slide(delta, wish)
	if _jump_buffer > 0.0 and _coyote > 0.0 and exhaust_left <= 0.0 and stamina > Tune.JUMP_STAMINA * 0.5:
		_jump()
	elif not on_floor:
		# Let go early for a hop; falling is a little heavier than rising.
		if velocity.y > 0.0 and not Input.is_action_pressed("jump") and _jumped and _autopilot == "":
			velocity.y *= pow(Tune.JUMP_CUT, delta * 12.0)
		velocity.y -= Tune.GRAVITY * delta * (Tune.FALL_GRAVITY if velocity.y < 0.0 else 1.0)
	elif not _airborne:
		velocity.y = -1.0

	# Wind leans on her stride only; standing still she holds her ground.
	var push := Vector3.ZERO
	if Game.weather and moving and not indoors():
		push = Game.weather.wind * 0.03 * (1.0 + Game.weather.gust * 0.8)
	if not sliding:
		var target := Vector3(wish.x, 0.0, wish.z) * speed
		var rate := _momentum(target, moving, sprinting)
		if not on_floor:
			rate *= Tune.AIR_CONTROL
		_glide = _glide.move_toward(target, rate * delta)
	_since_plant += delta
	if foot_lock:
		foot_lock.body_speed = _ground_speed()
	if posture:
		posture.speed = _ground_speed()
		foot_lock.suspended = _airborne or sliding
	var surge := _step_surge() if on_floor and not sliding else 1.0
	velocity.x = _glide.x * surge + push.x
	velocity.z = _glide.z * surge + push.z
	move_and_slide()
	_track_air(delta)
	_animate(delta, moving, sprinting)
	_breathe(delta, sprinting)
	_carry(delta, sprinting)
	_steps(delta)
	_move_camera(delta)
	_flicker_lantern(delta)


func _jump() -> void:
	var from_slide := sliding
	if sliding:
		_end_slide()
	# Out of a slide she carries the speed and springs a little higher.
	velocity.y = Tune.JUMP_VELOCITY * (1.1 if from_slide else 1.0)
	_coyote = 0.0
	_jump_buffer = 0.0
	_airborne = true
	_jumped = true
	_air_time = 0.0
	stamina = maxf(stamina - Tune.JUMP_STAMINA, 0.0)
	strain = maxf(strain, 0.4)
	_jolt -= 0.03
	_both_feet(0.6)


# Leaving and meeting the ground. Small bumps that drop her off the floor
# for an instant are not jumps, so the air pose and landing wait a moment.
func _track_air(delta: float) -> void:
	if is_on_floor():
		if _airborne and (_jumped or _air_time > 0.15):
			_land(_fall_speed)
		_airborne = false
		_jumped = false
		_air_time = 0.0
		_fall_speed = 0.0
		return
	_airborne = true
	_air_time += delta
	_fall_speed = maxf(_fall_speed, -velocity.y)


# The harder she comes down, the deeper the absorb, the bigger the jolt and
# spray, and the more speed it costs.
func _land(fall_speed: float) -> void:
	# An ordinary jump lands at about 5.5 m/s and should feel light; only a
	# real drop comes down hard.
	var power := clampf((fall_speed - 6.0) / 6.0, 0.0, 1.0)
	if stride:
		stride.land(power)
	_jolt -= lerpf(0.03, 0.13, power)
	_glide *= lerpf(0.97, 0.7, power)
	_since_plant = 0.0
	_both_feet(maxf(power, 0.45))
	if Game.soundscape:
		Game.soundscape.play_step(true, indoors())


# Both boots at once: takeoff and landing.
func _both_feet(power: float) -> void:
	if indoors():
		if Game.soundscape:
			Game.soundscape.play_step(true, true)
		return
	var forward := Vector3(_glide.x, 0.0, _glide.z)
	forward = forward.normalized() if forward.length() > 0.1 else -global_transform.basis.z
	var side := Vector3(forward.z, 0.0, -forward.x)
	for left in [true, false]:
		var at := global_position + side * (0.12 if left else -0.12)
		var ground_y := trail.ground.height_at(at.x, at.z) if trail and trail.ground else at.y
		if kicks:
			kicks.kick(Vector3(at.x, ground_y + 0.05, at.z), power, -forward)
		if footprints:
			footprints.stamp(Vector3(at.x, ground_y, at.z), atan2(forward.x, forward.z), true, left)
	if Game.soundscape:
		Game.soundscape.play_step(true)


func _start_slide() -> void:
	if _ground_speed() < Tune.SLIDE_MIN_SPEED or stamina < Tune.SLIDE_STAMINA or exhaust_left > 0.0:
		return
	sliding = true
	_slide_time = 0.0
	_slide_dir = Vector3(_glide.x, 0.0, _glide.z).normalized()
	_slide_speed = _ground_speed() + Tune.SLIDE_BOOST
	stamina -= Tune.SLIDE_STAMINA
	_jolt -= 0.04
	if Game.soundscape:
		Game.soundscape.slide(1.0)


# Low friction on snow, gravity along the slope, a little steering.
func _slide(delta: float, wish: Vector3) -> void:
	_slide_time += delta
	if wish.length() > 0.1:
		var turn := _slide_dir.signed_angle_to(wish.normalized(), Vector3.UP)
		var reach := Tune.SLIDE_STEER * delta
		_slide_dir = _slide_dir.rotated(Vector3.UP, clampf(turn, -reach, reach))
	var grade := 0.0
	if trail and trail.ground and not indoors():
		var ahead := _slide_dir * 0.8
		var here := trail.ground.height_at(global_position.x, global_position.z)
		grade = (trail.ground.height_at(global_position.x + ahead.x, global_position.z + ahead.z) - here) / 0.8
	_slide_speed -= (Tune.SLIDE_FRICTION + grade * Tune.SLIDE_SLOPE) * delta
	_glide = _slide_dir * maxf(_slide_speed, 0.0)
	_spray_in -= delta
	if _spray_in <= 0.0 and kicks and not indoors():
		_spray_in = 0.05
		var side := Vector3(_slide_dir.z, 0.0, -_slide_dir.x) * randf_range(-0.14, 0.14)
		var ground_y := trail.ground.height_at(global_position.x, global_position.z) if trail and trail.ground else global_position.y
		kicks.kick(Vector3(global_position.x, ground_y + 0.04, global_position.z) + _slide_dir * 0.35 + side, 1.0, _slide_dir * 0.6)
	if Game.soundscape:
		Game.soundscape.slide(clampf(_slide_speed / Tune.SPRINT_SPEED, 0.2, 1.0))
	var held := Input.is_action_pressed("slide") or _autopilot == "slide"
	if _slide_time > Tune.SLIDE_MAX_TIME or _slide_speed < Tune.SLIDE_END_SPEED or (not held and _slide_time > Tune.SLIDE_MIN_TIME) or not is_on_floor():
		_end_slide()


func _end_slide() -> void:
	sliding = false
	if Game.soundscape:
		Game.soundscape.slide(0.0)


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
	if trail == null or trail.ground == null or direction.length() < 0.05 or indoors():
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
		Game.soundscape.play_step(true, indoors())


# Within each step her speed checks as the foot lands and surges as it
# pushes off: subtle at a walk, a real drive at a sprint.
func _step_surge() -> float:
	var speed := _ground_speed()
	if speed < 0.5:
		return 1.0
	var pace := clampf((speed - 1.2) / (Tune.SPRINT_SPEED - 1.2), 0.0, 1.0)
	var phase := clampf(_since_plant / _step_time, 0.0, 1.0)
	return 1.0 - lerpf(Tune.STEP_SURGE_WALK, Tune.STEP_SURGE_SPRINT, pace) * cos(TAU * phase)


# A real touchdown from the animation: everything a step does happens here.
func _on_planted(left: bool, at: Vector3) -> void:
	var speed := _ground_speed()
	if speed < 0.5 or not is_on_floor() or Game.locks_movement():
		return
	var now := Time.get_ticks_msec()
	if _last_plant_msec > 0:
		_step_time = clampf(float(now - _last_plant_msec) / 1000.0, 0.18, 1.0)
	_last_plant_msec = now
	_since_plant = 0.0
	_footfall(left, at, speed)


func _footfall(left: bool, at: Vector3, speed: float) -> void:
	_left_foot = left
	var heavy := speed > 4.0
	var power := clampf(speed / Tune.SPRINT_SPEED, 0.2, 1.0)
	var inside := indoors()
	if Game.soundscape:
		Game.soundscape.play_step(heavy, inside)
	_jolt -= lerpf(0.004, 0.026, power * power)
	_roll_kick += (1.0 if left else -1.0) * lerpf(0.001, 0.01, power)
	# Boards and tile take no prints and throw no powder.
	if inside:
		return
	var forward := Vector3(_glide.x, 0.0, _glide.z).normalized()
	var ground_y := trail.ground.height_at(at.x, at.z) if trail and trail.ground else global_position.y
	var sole := Vector3(at.x, ground_y, at.z)
	if kicks:
		kicks.kick(sole + Vector3(0, 0.05, 0), power, -forward)
	if footprints:
		footprints.stamp(sole, atan2(forward.x, forward.z), heavy, left)


func _ground_speed() -> float:
	return Vector2(_glide.x, _glide.z).length()


func _place() -> void:
	if trail == null:
		return
	# She wakes in the cabin, beside the bed.
	if Game.house:
		global_position = Game.house.spawn_point()
		var facing := Game.house.spawn_facing()
		# Dev hook: RUN_SPAWN=outside|bedroom|living|stair|cellar|janitor|morgue.
		var spot := Game.house.dev_spawn(OS.get_environment("RUN_SPAWN"))
		if not spot.is_empty():
			global_position = spot[0]
			facing = spot[1]
		_yaw = atan2(-facing.x, -facing.z)
		_facing = _yaw
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
	# Indoors the walls and ceilings stop the arm; the snow is irrelevant.
	if indoors():
		spring_arm.spring_length = _boom
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


func _animate(delta: float, moving: bool, sprinting: bool) -> void:
	var air_target := 1.0 if _airborne and (_jumped or _air_time > 0.12) else 0.0
	_air_weight = move_toward(_air_weight, air_target, delta * (12.0 if air_target > 0.0 else 9.0))
	_slide_weight = move_toward(_slide_weight, 1.0 if sliding else 0.0, delta * 8.0)
	if stride:
		stride.update(_ground_speed())
		stride.posture(_air_weight, velocity.y / Tune.JUMP_VELOCITY, _slide_weight)
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
		_facing = lerp_angle(_facing, target_yaw, 1.0 - exp(-delta * (9.0 if sprinting else 3.6)))
		turn_rate = angle_difference(before, _facing) / maxf(delta, 0.0001)
	var accel := (_glide - _last_glide) / maxf(delta, 0.0001)
	_last_glide = _glide
	var heading := Vector3(-sin(_facing), 0.0, -cos(_facing))
	var pace := flat.length() / Tune.SPRINT_SPEED
	var pitch := clampf(-(pace * 0.09 + accel.dot(heading) * 0.012), -0.2, 0.1)
	# Sliding, she sits back against the snow.
	pitch = lerpf(pitch, 0.24, _slide_weight)
	var roll := clampf(turn_rate * pace * 0.07, -0.16, 0.16)
	_lean = _lean.lerp(Vector2(pitch, roll), 1.0 - exp(-delta * 5.0))
	visual.rotation = Vector3(_lean.x, _facing - _yaw, _lean.y + _sway)


func indoors() -> bool:
	return Game.indoors(global_position + Vector3(0.0, 0.9, 0.0))


## The door or switch she is facing and can reach, if any.
func nearby_interactable() -> Node3D:
	if camera == null:
		return null
	var chest := global_position + Vector3(0.0, 1.2, 0.0)
	var look := -camera.global_transform.basis.z
	look.y = 0.0
	look = look.normalized()
	var best: Node3D = null
	var best_score := 99.0
	for node in get_tree().get_nodes_in_group("interactables"):
		var point: Vector3 = node.call("interact_point")
		var reach := chest.distance_to(point)
		if reach > 1.8:
			continue
		var toward := point - chest
		toward.y = 0.0
		var facing := toward.normalized().dot(look) if toward.length() > 0.05 else 1.0
		if facing < 0.25:
			continue
		var score := reach - facing * 0.6
		if score < best_score:
			best_score = score
			best = node as Node3D
	return best


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
	camera.fov = lerpf(camera.fov, 68.0 + 9.0 * pace + 5.0 * _slide_weight, 1.0 - exp(-delta * 4.0))
	# Indoors the camera comes in over her shoulder: rooms are a few metres
	# across, and a long boom would only be crushed against the walls.
	var inside := indoors()
	_boom = lerpf(_boom, INDOOR_BOOM if inside else BOOM_LENGTH + 0.5 * pace, 1.0 - exp(-delta * 3.0))
	_shoulder = lerpf(_shoulder, INDOOR_SHOULDER if inside else 0.0, 1.0 - exp(-delta * 3.0))
	# Pressed into her by a wall anyway, it looks past her instead of
	# through the inside of her head.
	if visual:
		visual.visible = spring_arm.get_hit_length() > 0.6
	_jolt = lerpf(_jolt, 0.0, 1.0 - exp(-delta * 11.0))
	_roll_kick = lerpf(_roll_kick, 0.0, 1.0 - exp(-delta * 8.0))
	var lag := global_transform.basis.inverse() * Vector3(-_glide.x, 0.0, -_glide.z) * 0.04
	_trail_offset = _trail_offset.lerp(lag.limit_length(0.32), 1.0 - exp(-delta * 3.0))
	# The camera drops with her into a slide.
	spring_arm.position = Vector3(_shoulder, 1.5 - 0.4 * _slide_weight + _jolt, 0.0) + _trail_offset


func _flicker_lantern(delta: float) -> void:
	if lantern == null:
		return
	# Indoors her small light is all she has in the unlit rooms.
	_glow = move_toward(_glow, 1.0 if indoors() else 0.0, delta * 1.4)
	lantern.light_energy = lerpf(0.22, 0.85, _glow) + sin(Time.get_ticks_msec() * 0.013) * 0.03
	lantern.spot_range = lerpf(7.0, 9.0, _glow)
	lantern.spot_angle = lerpf(24.0, 34.0, _glow)


func _steps(delta: float) -> void:
	var speed := _ground_speed()
	if not is_on_floor() or speed < 0.3:
		_travel = 0.0
		return
	# Step length grows with pace, so footfalls stay in time with the legs.
	var step_length := lerpf(0.62, 1.12, smoothstep(1.2, Tune.SPRINT_SPEED, speed))
	_travel += speed * delta
	_stride_phase += speed * delta / step_length * PI
	# With planted feet the real touchdowns drive the steps (_on_planted);
	# distance is only the fallback when the rig has no leg IK.
	if foot_lock != null or _travel < step_length:
		return
	_travel -= step_length
	var forward := Vector3(_glide.x, 0.0, _glide.z).normalized()
	var side := Vector3(forward.z, 0.0, -forward.x)
	var left := not _left_foot
	_footfall(left, global_position + side * (0.12 if left else -0.12), speed)


func _cloak(root: Node) -> void:
	var suit := _suit_material()
	var eyes := _eye_material()
	# Soft, warm brown brows, a little see-through so they read as hair on
	# skin, not painted bars.
	var hair := StandardMaterial3D.new()
	hair.albedo_color = Color(0.3, 0.18, 0.11, 0.72)
	hair.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hair.roughness = 0.8
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
	# Only her face shows through the clothes: give it skin, light scattering
	# under the surface, a soft sheen, a faint rim against the snow.
	material.roughness = 0.62
	material.metallic = 0.0
	material.metallic_specular = 0.3
	material.subsurf_scatter_enabled = true
	material.subsurf_scatter_strength = 0.35
	material.subsurf_scatter_skin_mode = true
	material.rim_enabled = true
	material.rim = 0.12
	material.rim_tint = 0.6
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
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		foot_lock = FootLock.fit(model, skeletons[0] as Skeleton3D)
		foot_lock.ground = trail.ground if trail else null
		# Feet land on the boards indoors, on the snow outside.
		foot_lock.floor_at = func(point: Vector3) -> float:
			if indoors() or trail == null or trail.ground == null:
				return global_position.y
			return trail.ground.height_at(point.x, point.z)
		foot_lock.planted.connect(_on_planted)
		posture = Posture.fit(skeletons[0] as Skeleton3D, foot_lock)
		posture.breath = breath
		posture.look = func() -> Vector3:
			return -camera.global_transform.basis.z if camera else Vector3.ZERO
		posture.strain = func() -> float:
			return strain
	if outfit:
		face = Face.fit(model, outfit.body)
		if face:
			face.strain = func() -> float:
				return strain
			face.fear = func() -> float:
				return Game.threat()
