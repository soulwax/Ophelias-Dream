extends Node

# The other one out on her afternoon, and passing her: brought out near the
# player, noticed, a passing staged and left unfinished, the spot without prints,
# speaking cut to half a word, the cap of three, and retiring.
# PROBE_CHAPTER=mathilda runs it in Mathilda's chapter (Ophelia is the one met).

var _failed := false
var _speakers := {}
var _lines := {}


func _ready() -> void:
	Game.mathilda_pov = OS.get_environment("PROBE_CHAPTER") == "mathilda"
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	print("Encounter: ", message, " = ", ok)
	if not ok:
		_failed = true
		push_error(message)


var _trace_clock := 0.0
var trace_wanderer: Wanderer


func _process(delta: float) -> void:
	_trace_clock += delta
	if OS.get_environment("PROBE_TRACE") == "1" and trace_wanderer and _trace_clock > 1.0:
		_trace_clock = 0.0
		print("  t state=", trace_wanderer.State, " apart=", snappedf(Game.player.global_position.distance_to(trace_wanderer.global_position), 0.1), " allowed=", trace_wanderer.Allowed, " phase=", Game.phase, " murmur=", Game.murmur)
	if Game.murmur_left > 0.0 and Game.murmur != "":
		_speakers[Game.murmur_speaker] = true
		_lines[Game.murmur] = true


func _until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if condition.call():
			return true
		await get_tree().process_frame
		left -= get_process_delta_time()
	return condition.call()


func _run() -> void:
	Engine.time_scale = 3.0
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	var encounters: Encounters = null
	for i in 240:
		await get_tree().process_frame
		for child in main.get_children():
			if child is Encounters and (child as Encounters).wanderer != null:
				encounters = child
		if encounters:
			break
	_check(encounters != null, "the other one is built")
	if encounters == null:
		return _finish()
	var other := "Ophelia" if Game.mathilda_pov else "Mathilda"
	_check(encounters.body.name == other, "the one met is " + other)
	var wanderer := encounters.wanderer
	trace_wanderer = wanderer
	_check(not wanderer.Present and not wanderer.visible, "she starts offstage")
	Game.set_phase(Game.Phase.PLAYING)
	var player := Game.player
	player.set_physics_process(false)
	var trail := Game.trail
	var home := trail.offset_of(Game.house.doorstep())
	var stand_at := home + (30.0 if Game.mathilda_pov else 70.0)
	player.global_position = trail.on_ground(trail.position_at(stand_at)) + Vector3.UP * 0.1
	player.reset_physics_interpolation()

	# Out she comes, ahead on the path, and wanders.
	wanderer.ForceEnterNear(trail.position_at(stand_at + 30.0))
	_check(await _until(func() -> bool: return wanderer.Present and wanderer.visible, 2.0), "she comes out")
	var start: Vector3 = wanderer.global_position
	_check(await _until(func() -> bool: return wanderer.global_position.distance_to(start) > 0.5 or wanderer.State == "Linger", 3.0), "she is doing something, not standing in for one")

	# Close, in sight: she notices, and the passing begins.
	await _approach(wanderer, player)
	_check(await _until(func() -> bool: return wanderer.State == "Passing", 12.0), "she notices and stops (" + wanderer.State + ")")
	_check(Game.passings == 1, "the first passing is counted")
	_check(Game.voice == null or Game.voice.hushed, "nothing else in her head gets said meanwhile")
	_check(await _until(func() -> bool: return wanderer.State == "Leave", 40.0), "it ends with her walking off (" + wanderer.State + ")")
	_check(_speakers.has(other), "she spoke, with her own name on the subtitle")
	_check(_speakers.has(""), "the one played spoke too")
	_check(Game.voice == null or not Game.voice.hushed, "afterwards the thoughts come back")
	# Where she stood: once she is well away, nothing, not even prints.
	var spot: Vector3 = encounters._spots[0] if not encounters._spots.is_empty() else start
	_check(await _until(func() -> bool: return not wanderer.Present or wanderer.global_position.distance_to(spot) > 13.0, 60.0), "she walks well away")
	player.global_position = spot + Vector3.UP * 0.1
	var after := "No prints. Not hers, not anyone's." if Game.mathilda_pov else "Nothing. Not even prints."
	_check(await _until(func() -> bool: return _lines.has(after), 6.0), "the spot she stood on has no prints in it")

	# The second time she knows something she could not know; this time, speak.
	wanderer.ForceEnterNear(player.global_position + Vector3(6.0, 0.0, 0.0))
	await _approach(wanderer, player)
	_check(await _until(func() -> bool: return wanderer.State == "Passing", 12.0), "the second passing begins (" + wanderer.State + ")")
	var knows := ["You lit the stove.", "You didn't light the stove.", "You found my thread."] if not Game.mathilda_pov 		else ["Your fire's going.", "Your fire's low."]
	_check(await _until(func() -> bool: return knows.any(func(text: String) -> bool: return _lines.has(text)), 10.0), "she knows a thing she could not know")
	player.global_position = wanderer.global_position + (player.global_position - wanderer.global_position).normalized() * 2.4
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	encounters._unhandled_input(press)
	_check(await _until(func() -> bool: return _lines.has("Hm?"), 8.0), "speaking gets half a word and a \"hm?\"")
	_check(await _until(func() -> bool: return wanderer.State == "Leave", 10.0), "and she goes (" + wanderer.State + ")")
	_check(Game.passings == 2, "two passings")
	await get_tree().create_timer(4.0).timeout
	_check(wanderer.State != "Passing" and wanderer.State != "Notice", "no new passing while she walks off")

	# The third time she says the player's own words back.
	wanderer.ForceEnterNear(player.global_position + Vector3(6.0, 0.0, 0.0))
	await _approach(wanderer, player)
	_check(await _until(func() -> bool: return wanderer.State == "Passing", 12.0), "the third passing begins")
	var echo := "Don't turn around." if Game.mathilda_pov else "Go, then."
	_check(await _until(func() -> bool: return _lines.has(echo), 12.0), "she says the player's own words back")
	_check(await _until(func() -> bool: return _lines.has("Sorry. You go.") or _lines.has("You first."), 30.0), "both start to apologise; it goes unanswered")
	_check(await _until(func() -> bool: return wanderer.State == "Leave", 15.0), "and she goes again")

	# Never a fourth.
	wanderer.ForceEnterNear(player.global_position + Vector3(5.0, 0.0, 0.0))
	await _approach(wanderer, player)
	await get_tree().create_timer(3.0).timeout
	_check(wanderer.State != "Passing" and wanderer.State != "Notice" and Game.passings == 3, "never more than three passings")
	if Game.mathilda_pov:
		Game.voice.set("_going_home", true)
	else:
		Game.meeting_waiting = true
	_check(await _until(func() -> bool: return wanderer.State == "Retired", 90.0), "she stops coming out (" + wanderer.State + ")")
	_finish()


func _approach(wanderer: Wanderer, player: Player) -> void:
	var her: Vector3 = wanderer.global_position
	var away := (player.global_position - her)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	player.global_position = Game.trail.on_ground(her + away * 5.0) + Vector3.UP * 0.1
	player.reset_physics_interpolation()
	await get_tree().process_frame


func _finish() -> void:
	Engine.time_scale = 1.0
	print("ENCOUNTER ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)
