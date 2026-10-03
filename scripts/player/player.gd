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
var ears: AudioListener3D
var lantern: SpotLight3D
var visual: Node3D
var animation_player: AnimationPlayer

var stamina: float = Tune.STAMINA_MAX
var _yaw: float = 0.0
var _pitch: float = -0.18
var exhaust_left: float = 0.0
var _sprinting := false
var _sprint_latch := false
var _left_foot := false
var _glide := Vector3.ZERO
var footprints: Footprints
var stride: Stride
var kicks: SnowKick
var foot_lock: FootLock
var grace: Grace
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
	rotation.y = _yaw
	reset_physics_interpolation()
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
				var accepted := thing.call("interact") == true
				var feedback := ""
				if not accepted and thing is HouseDoor:
					feedback = (thing as HouseDoor).blocked_label()
				Game.interaction_feedback.emit(feedback, accepted)
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and Game.phase == Game.Phase.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Look goes straight to the camera every frame. screen_relative is in real
	# pixels, so the window size or stretch never changes the sensitivity.
	if event is InputEventMouseMotion and not Game.locks_look() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var turn := (event as InputEventMouseMotion).screen_relative * Tune.MOUSE_SENS * Game.settings.mouse_sensitivity
		_yaw -= turn.x
		_pitch = clampf(_pitch + (turn.y if Game.settings.invert_y else -turn.y), Tune.PITCH_DOWN, Tune.PITCH_UP)


func _physics_process(delta: float) -> void:
	if trail == null:
		return
	# The body faces the camera so the keys move her relative to the view;
	# her model turns on its own (_carry).
	rotation.y = _yaw
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
		if grace:
			grace.speed = _ground_speed()
		_breathe(delta, false)
		_carry(delta, false)
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
	var wants_sprint := moving and _sprint_wanted(moving) and exhaust_left <= 0.0 and not sliding
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
		_steer(wish, speed, sprinting, on_floor, delta)
	_since_plant += delta
	if foot_lock:
		foot_lock.body_speed = _ground_speed()
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
	_flicker_lantern(delta)


# The camera rig lives outside the physics tick: it follows her interpolated
# position and the mouse every rendered frame, so look and motion stay smooth
# at any frame rate.
func _process(delta: float) -> void:
	if spring_arm == null:
		return
	_move_camera(delta)
	_apply_look()


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


# Both boots at once: takeoff and landing.
func _both_feet(power: float) -> void:
	var forward := Vector3(_glide.x, 0.0, _glide.z)
	forward = forward.normalized() if forward.length() > 0.1 else -global_transform.basis.z
	var side := Vector3(forward.z, 0.0, -forward.x)
	for left in [true, false]:
		var at := global_position + side * (0.12 if left else -0.12)
		var surface := _surface_at(at)
		if Game.soundscape:
			Game.soundscape.play_step(at, surface, power)
		if surface != "snow":
			continue
		var ground_y := trail.ground.height_at(at.x, at.z) if trail and trail.ground else at.y
		if kicks:
			kicks.kick(Vector3(at.x, ground_y + 0.05, at.z), power, -forward)
		if footprints:
			footprints.stamp(Vector3(at.x, ground_y, at.z), atan2(forward.x, forward.z), true, left)


# What is under a foot: the surface its collider is tagged with (the cabin's
# planks, the porch and cellar stone), else snow outside and boards within.
func _surface_at(at: Vector3) -> String:
	if not is_inside_tree():
		return "snow"
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 0.5, Tune.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var body: Object = hit.get("collider")
	if body and body.has_meta("surface"):
		return str(body.get_meta("surface"))
	return "wood" if indoors() else "snow"


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


# Speed and heading move separately, so a turn never costs a slow vector
# blend: at a walk she pivots almost at once, at a sprint she sweeps round
# and hard corners bleed a little speed. Asked to reverse at speed she plants
# and brakes first. Letting go she skids a short way; easing off a sprint she
# slows over a stride or two. In the air she keeps what she left with.
func _steer(wish: Vector3, top: float, sprinting: bool, on_floor: bool, delta: float) -> void:
	var flat := Vector3(_glide.x, 0.0, _glide.z)
	var current := flat.length()
	var asked := wish.length() > 0.05
	if not on_floor:
		if not asked:
			_glide = flat.move_toward(Vector3.ZERO, Tune.AIR_DRAG * delta)
			return
		var aim := wish.normalized() * maxf(top, current)
		_glide = flat.move_toward(aim, Tune.AIR_ACCEL * delta)
		return
	var pace := clampf((current - Tune.WALK_SPEED) / (Tune.SPRINT_SPEED - Tune.WALK_SPEED), 0.0, 1.0)
	if not asked:
		_glide = flat.move_toward(Vector3.ZERO, lerpf(Tune.STRIDE_STOP_WALK, Tune.STRIDE_STOP_SPRINT, pace) * delta)
		return
	var toward := wish.normalized()
	var heading := toward
	if current >= Tune.PIVOT_SPEED:
		heading = flat / current
		var angle := heading.signed_angle_to(toward, Vector3.UP)
		if absf(angle) > Tune.REVERSE_ANGLE:
			_glide = heading * move_toward(current, 0.0, Tune.STRIDE_BRAKE * delta)
			return
		var reach := lerpf(Tune.TURN_RATE_WALK, Tune.TURN_RATE_SPRINT, pace) * delta
		var turned := clampf(angle, -reach, reach)
		heading = heading.rotated(Vector3.UP, turned)
		current *= 1.0 - absf(turned) * Tune.TURN_BLEED * pace
	var want := top * minf(wish.length(), 1.0)
	var rate := Tune.STRIDE_EASE
	if want > current:
		rate = Tune.STRIDE_ACCEL_SPRINT if sprinting else Tune.STRIDE_ACCEL_WALK
	_glide = heading * move_toward(current, want, rate * delta)


# Hold to sprint, or with the toggle setting tap once and she keeps running
# until she stops, is spent, or it is tapped again.
func _sprint_wanted(moving: bool) -> bool:
	if _autopilot in ["sprint", "jump", "slide"]:
		return true
	if not Game.settings.sprint_toggle:
		_sprint_latch = false
		return Input.is_action_pressed("sprint")
	if Input.is_action_just_pressed("sprint"):
		_sprint_latch = not _sprint_latch
	if not moving or exhaust_left > 0.0:
		_sprint_latch = false
	return _sprint_latch


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
		Game.soundscape.play_step(global_position, _surface_at(global_position), 1.0)


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
	var surface := _surface_at(at)
	if Game.soundscape:
		Game.soundscape.play_step(at, surface, clampf((speed - 1.0) / (Tune.SPRINT_SPEED - 1.0), 0.0, 1.0))
	_jolt -= lerpf(0.004, 0.026, power * power)
	_roll_kick += (1.0 if left else -1.0) * lerpf(0.001, 0.01, power)
	# Boards and stone take no prints and throw no powder.
	if surface != "snow":
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
	var turn := Basis(Vector3.UP, _yaw)
	var mount := Vector3(_shoulder, 1.5 - 0.4 * _slide_weight + _jolt * Game.settings.camera_shake, 0.0) + _trail_offset
	var body := get_global_transform_interpolated().origin
	spring_arm.global_transform = Transform3D(turn * Basis(Vector3.RIGHT, _pitch), body + turn * mount)
	_fit_boom_to_ground()
	if camera:
		var shake := Game.weather.gust * 0.012 if Game.weather else 0.0
		camera.rotation.z = (sin(Time.get_ticks_msec() * 0.009) * shake + _roll_kick) * Game.settings.camera_shake
	# She hears from her own head, facing where the camera looks, not from
	# the camera three metres behind her.
	if ears:
		ears.global_transform = Transform3D(turn, body + Vector3(0.0, 1.55 - 0.45 * _slide_weight, 0.0))


func apply_authored_spawn() -> void:
	if OS.get_environment("RUN_SPAWN") != "":
		_place()
		return
	_yaw = rotation.y
	_facing = _yaw


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
	if grace:
		grace.speed = _ground_speed()
		grace.poise = (1.0 - _air_weight) * (1.0 - _slide_weight) * (0.0 if exhaust_left > 0.0 else 1.0)
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
		var pace_turn := clampf((flat.length() - Tune.WALK_SPEED) / (Tune.SPRINT_SPEED - Tune.WALK_SPEED), 0.0, 1.0)
		_facing = lerp_angle(_facing, target_yaw, 1.0 - exp(-delta * lerpf(Tune.FACE_RATE_WALK, Tune.FACE_RATE_SPRINT, pace_turn)))
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
	var widen := (9.0 * pace + 5.0 * _slide_weight) if Game.settings.speed_fov else 0.0
	camera.fov = lerpf(camera.fov, Game.settings.fov + widen, 1.0 - exp(-delta * 4.0))
	# Indoors the camera comes in over her shoulder: rooms are a few metres
	# across, and a long boom would only be crushed against the walls.
	var inside := indoors()
	var outdoors_boom := BOOM_LENGTH * Game.settings.camera_distance + 0.5 * pace
	_boom = lerpf(_boom, minf(INDOOR_BOOM, outdoors_boom) if inside else outdoors_boom, 1.0 - exp(-delta * 3.0))
	_shoulder = lerpf(_shoulder, INDOOR_SHOULDER if inside else 0.0, 1.0 - exp(-delta * 3.0))
	# Pressed into her by a wall anyway, it looks past her instead of
	# through the inside of her head.
	if visual:
		visual.visible = spring_arm.get_hit_length() > 0.6
	_jolt = lerpf(_jolt, 0.0, 1.0 - exp(-delta * 11.0))
	_roll_kick = lerpf(_roll_kick, 0.0, 1.0 - exp(-delta * 8.0))
	var lag := Basis(Vector3.UP, _yaw).inverse() * Vector3(-_glide.x, 0.0, -_glide.z) * 0.04
	_trail_offset = _trail_offset.lerp(lag.limit_length(0.32), 1.0 - exp(-delta * 3.0))


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
	# Placed every frame by _apply_look, not carried by the body's tick.
	spring_arm.top_level = true
	spring_arm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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

	ears = AudioListener3D.new()
	ears.top_level = true
	ears.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(ears)
	ears.make_current()

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
	var path := "res://assets/characters/styloo_elf/elf.glb"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	var model := packed.instantiate()
	model.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	model.rotation.y = PI
	visual.add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var rig_root := skeleton.get_parent()
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	rig_root.add_child(animation_player)
	animation_player.root_node = NodePath("..")
	animation_player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)
	stride = Stride.build(animation_player, rig_root)
	var mouth := BoneAttachment3D.new()
	mouth.name = "Mouth"
	mouth.bone_name = "DEF-spine.006"
	skeleton.add_child(mouth)
	var head := skeleton.find_bone(mouth.bone_name)
	mouth.transform = skeleton.get_bone_global_rest(head).affine_inverse() * Transform3D(Basis(), Vector3(0.0, 1.91, 0.13))
	breath = Breath.new()
	mouth.add_child(breath)
	foot_lock = FootLock.fit(model, skeleton, "DEF-foot.L", "DEF-foot.R")
	foot_lock.ground = trail.ground if trail else null
	# Feet land on the boards indoors, on the snow outside.
	foot_lock.floor_at = func(point: Vector3) -> float:
		if indoors() or trail == null or trail.ground == null:
			return global_position.y
		return trail.ground.height_at(point.x, point.z)
	foot_lock.planted.connect(_on_planted)
	grace = Grace.fit(skeleton)
