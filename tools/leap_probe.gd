extends Node

# Drives the real player through jumps on the saved trail and checks the
# running leap: flatter and carried from a sprint, one foot down at each end,
# speed kept on landing, chained leaps capped, and the walking hop and the
# slide jump unchanged. Exits 1 on any failure.
#   godot-mono --headless --path . tools/leap_probe.tscn
# With a window it also saves build/leap/leap_flight.png at mid-flight.

var _player: Player
var _trail: Trail
var _failed := 0
# [msec, left] for every footfall she sounds.
var _steps: Array = []


func _ready() -> void:
	process_priority = -100
	process_physics_priority = -100
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	_player = Game.player
	_trail = Game.trail
	if _player == null or _trail == null:
		_check(false, "the scene built the player and the trail")
		_finish()
		return
	_player.stepped.connect(_on_stepped)
	_player.global_position = _trail.on_ground(_trail.position_at(_trail.player_start_offset)) + Vector3.UP * 0.3
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	Game.set_phase(Game.Phase.PLAYING)
	await _ticks(30)
	await _walking_hop()
	await _sprint_leap()
	await _chained_leaps()
	await _slide_jump()
	_finish()


# Keeps her on the route, a few metres ahead.
func _physics_process(_delta: float) -> void:
	if _player == null or _trail == null:
		return
	var ahead := _trail.position_at(minf(_trail.offset_of(_player.global_position) + 5.0, _trail.exit_offset))
	var direction := ahead - _player.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.04:
		_player._yaw = atan2(-direction.x, -direction.z)


func _walking_hop() -> void:
	Input.action_release("sprint")
	Input.action_press("move_forward")
	await _seconds(1.2)
	var took := await _jump()
	_check(not _player.leaping, "a walking jump is a hop, not a leap")
	_check(absf(took.rise - Tune.JUMP_VELOCITY) < 0.01, "the hop rises at JUMP_VELOCITY (%.2f)" % took.rise)
	_check(took.takeoff_steps == 2, "the hop leaves on both feet (%d steps)" % took.takeoff_steps)
	await _land()


func _sprint_leap() -> void:
	_player.stamina = Tune.STAMINA_MAX
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(2.0)
	var tree0 := _player.stride.tree
	var first := float(tree0.get("parameters/locomotion/Sprint_6/seek/current_position"))
	await _ticks(3)
	var later := float(tree0.get("parameters/locomotion/Sprint_6/seek/current_position"))
	_check(not is_equal_approx(first, later), "the sprint still runs through its seek node")
	var slope := _player._slope_factor(-_player.global_transform.basis.z)
	var fov_before := _player.camera.fov
	var took := await _jump()
	_check(_player.leaping, "a sprinting jump is a leap")
	# The route can climb here (slope factor below 1 slows her sprint), so
	# check leap against the speed she actually took off at.
	var expected := clampf((took.speed_before - Tune.LEAP_FROM) / (Tune.SPRINT_SPEED - Tune.LEAP_FROM), 0.0, 1.0)
	_check(absf(_player.leap - expected) < 0.02, "leap follows her takeoff speed (%.2f at %.2f m/s, slope factor %.2f)" % [_player.leap, took.speed_before, slope])
	_check(_player.leap >= 0.5, "this sprint is a real leap (%.2f)" % _player.leap)
	var rise := Tune.JUMP_VELOCITY * lerpf(1.0, Tune.LEAP_LIFT, _player.leap)
	_check(absf(took.rise - rise) < 0.01, "the leap rises at %.2f m/s (got %.2f)" % [rise, took.rise])
	var carried := minf(took.speed_before * (1.0 + Tune.LEAP_CARRY * _player.leap), maxf(took.speed_before, Tune.LEAP_MAX_SPEED))
	_check(took.speed >= carried * 0.98, "the push-off carries her to %.2f m/s (got %.2f)" % [carried, took.speed])
	_check(took.takeoff_steps == 1, "the leap pushes off one foot (%d steps)" % took.takeoff_steps)
	if took.takeoff_steps == 1:
		_check(took.push_left != _player.leap_lead_left, "the push-off foot is not the lead foot")
	await _seconds(_player._leap_airtime * 0.5)
	var tree := _player.stride.tree
	_check(float(tree.get("parameters/leap/blend_amount")) > 0.9, "mid-flight shows the leap pose")
	_check(is_zero_approx(float(tree.get("parameters/air/blend_amount"))), "mid-flight hides the standing jump pose")
	# Run with a window to keep a picture of her mid-flight.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/leap"))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/leap/leap_flight.png"))
	if Game.settings.speed_fov:
		# Speed alone widens the view too (and the carry adds speed), so
		# compare with what her pace by itself would aim for.
		var pace := clampf((_player._ground_speed() - Tune.WALK_SPEED) / (Tune.SPRINT_SPEED - Tune.WALK_SPEED), 0.0, 1.0)
		var by_speed := Game.settings.fov + 9.0 * pace
		_check(_player.camera.fov > by_speed + 0.3, "the view opens on a leap beyond its pace (%.1f, pace alone %.1f, before %.1f)" % [_player.camera.fov, by_speed, fov_before])
	var down := await _land()
	var contact: float = Stride.SPRINT_PHASES["L_contact" if _player.leap_lead_left else "R_contact"]
	_check(absf(down.cued - contact) < 0.08, "the sprint picks up at the lead foot's contact (%.3f vs %.3f)" % [down.cued, contact])
	_check(down.landing.size() == 1, "the leap lands on one foot (%d steps)" % down.landing.size())
	if down.landing.size() == 1:
		_check(down.landing[0][1] == _player.leap_lead_left, "it lands on the lead foot")
	_check(down.after >= down.before * 0.995, "landing keeps her speed (%.2f -> %.2f)" % [down.before, down.after])
	_check(down.echoes == 0, "the rig does not plant the lead foot a second time (%d)" % down.echoes)


func _chained_leaps() -> void:
	_player.stamina = Tune.STAMINA_MAX
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(1.5)
	var top := 0.0
	for i in 3:
		await _jump()
		var down := await _land()
		top = maxf(top, down.top)
	_check(top <= Tune.LEAP_MAX_SPEED + 0.05, "chained leaps stay within LEAP_MAX_SPEED (top %.2f)" % top)


func _slide_jump() -> void:
	_player.stamina = Tune.STAMINA_MAX
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(1.5)
	Input.action_press("slide")
	await _seconds(0.2)
	_check(_player.sliding, "she is sliding before the slide jump")
	var took := await _jump()
	Input.action_release("slide")
	_check(not _player.leaping, "a slide jump is not a leap")
	_check(absf(took.rise - Tune.JUMP_VELOCITY * 1.1) < 0.01, "a slide jump keeps its 1.1x spring (%.2f)" % took.rise)
	await _land()
	Input.action_release("sprint")


# Presses jump until she leaves the ground; returns what she left with.
func _jump() -> Dictionary:
	var before := _player._ground_speed()
	var count := _steps.size()
	Input.action_press("jump")
	for i in 30:
		await get_tree().physics_frame
		if _player._jumped:
			break
		before = _player._ground_speed()
		count = _steps.size()
	var added: Array = _steps.slice(count)
	return {
		"rise": _player.velocity.y,
		"speed_before": before,
		"speed": _player._ground_speed(),
		"takeoff_steps": added.size(),
		"push_left": added[-1][1] if not added.is_empty() else null,
	}


# Waits for touchdown; returns her speed either side of it, the steps sounded
# on landing, and any second plant of the lead foot just after.
func _land() -> Dictionary:
	var before := _player._ground_speed()
	var count := _steps.size()
	var top := before
	for i in 300:
		await get_tree().physics_frame
		if not _player._airborne:
			break
		before = _player._ground_speed()
		count = _steps.size()
		top = maxf(top, before)
	Input.action_release("jump")
	var landing: Array = _steps.slice(count)
	var after := _player._ground_speed()
	var landed := Time.get_ticks_msec()
	await get_tree().process_frame
	var cued := float(_player.stride.tree.get("parameters/locomotion/Sprint_6/seek/current_position"))
	await _seconds(0.25)
	var echoes := 0
	for step: Array in _steps.slice(count + landing.size()):
		if step[1] == _player.leap_lead_left and step[0] - landed < 150:
			echoes += 1
	return {"before": before, "after": after, "top": top, "landing": landing, "echoes": echoes, "cued": cued}


func _on_stepped(left: bool) -> void:
	_steps.append([Time.get_ticks_msec(), left])


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1


func _finish() -> void:
	for action in ["move_forward", "sprint", "jump", "slide"]:
		Input.action_release(action)
	print("Leap probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)
