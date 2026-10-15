extends Node

# MASTERPLAN W06 / errands T6: the world verbs on the real player. Each verb
# changes its state, sounds on the Effects bus and is saved by id; an arrow
# knocks a branch's snow down; warming crouches her only while the hold works
# and leaves her warm; the lookout bell answers once per visit.
#   godot --headless --path . tools/verbs_probe.tscn

const ARROW := preload("res://scripts/world/arrow_projectile.gd")

var _failures := 0
var _player: Player


func _ready() -> void:
	OS.set_environment("RUN_PLAY", "1")
	RunSave.set_process(false)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _action(action: String, on: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = on
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _in_front(thing: Node3D, lift := 0.0) -> void:
	var camera := _player.camera
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var chest := _player.global_position + Vector3(0.0, 1.2, 0.0)
	thing.global_position = origin + forward * ((chest - origin).dot(forward) + 0.6) + Vector3.UP * lift


func _sounded(node: Node, sound: String) -> bool:
	var player := node.get_node_or_null("Sound_" + sound) as AudioStreamPlayer3D
	return player != null and player.bus == &"Effects"


func _saved(key: String) -> bool:
	return Game.errands != null and (Game.errands.get("_states") as Dictionary).has(key)


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	_player = Game.player
	if _player == null or Game.errands == null:
		_check(false, "the player and Errands exist")
		_finish()
		return
	Game.set_phase(Game.Phase.PLAYING)
	_player._autopilot = ""
	await _frames(20)
	await _placed()
	await _drawer()
	await _brushable()
	await _snow_branch()
	await _warming()
	await _bell()
	_finish()


func _placed() -> void:
	var world := Game.errands.world_root()
	var bell := world.get_node_or_null("LookoutBell") as Bell
	_check(bell != null and bell.global_position.distance_to(Game.trail.exit_point) < 15.0, "the bell hangs at the lookout")
	if bell:
		# She can ring it standing on the snow in front of it.
		var stand := Game.trail.on_ground(bell.global_position + bell.global_basis.z * 0.9)
		_player.global_position = stand + Vector3.UP * 0.05
		_player.velocity = Vector3.ZERO
		_player.reset_physics_interpolation()
		await _frames(6)
		_check(_player.aim._in_reach(_player, bell), "and is within her reach from the ground")
		# Seen as she arrives: nearer the path she comes up by than the tower is.
		var approach := Game.trail.position_at(Game.trail.offset_of(Game.trail.exit_point) - 12.0)
		var lanterns: Array = get_tree().get_first_node_in_group("lake").get("_lanterns")
		var tower := ((lanterns[0] as Node3D).global_position + (lanterns[1] as Node3D).global_position) * 0.5 if lanterns.size() >= 2 else Game.trail.exit_point
		var bell_gap := Vector2(bell.global_position.x - approach.x, bell.global_position.z - approach.z).length()
		var tower_gap := Vector2(tower.x - approach.x, tower.z - approach.z).length()
		_check(bell_gap < tower_gap, "on the side of the tower she arrives from (%.1f m vs %.1f m)" % [bell_gap, tower_gap])
	_check(world.get_node_or_null("StoveWarmth") is WarmSpot, "there is a warm spot at the stove")
	_check(world.get_node_or_null("CampfireWarmth") is WarmSpot, "and one at the campfire")
	var stove := world.get_node_or_null("StoveWarmth") as WarmSpot
	if stove:
		_check(not stove.visible, "the cold stove offers no warmth")


func _drawer() -> void:
	var drawer := HouseDrawer.make(Game.errands.world_root(), "probe_cupboard", Transform3D.IDENTITY, Vector3(0.6, 0.8, 0.4))
	_in_front(drawer, -1.0)
	drawer.look_at(_player.global_position + Vector3.UP * (drawer.global_position.y - _player.global_position.y), Vector3.UP, true)
	var cup := Carryable.new()
	cup.kind = "cup"
	cup.item_id = "probe_drawer_cup"
	add_child(cup)
	drawer.hold(cup, Vector3(0.0, 0.3, 0.0))
	await _frames(3)
	_check(not drawer.is_open and not cup.visible, "a closed cupboard hides what is in it")
	_check(drawer.interact() and drawer.is_open, "a press opens it")
	await _frames(2)
	_check(cup.visible, "and shows what is in it")
	_check(_sounded(drawer, "cupboard_open"), "opening sounds on the Effects bus")
	_check(_saved("drawer:probe_cupboard") and drawer.state() == true, "its openness is saved by id")
	drawer.apply_state(false)
	_check(not drawer.is_open and not cup.visible, "a restored closed state hides it again")
	cup.queue_free()
	drawer.queue_free()
	await _frames(2)


func _brushable() -> void:
	var brush := Brushable.make(Game.errands.world_root(), "probe_sign", Transform3D.IDENTITY, Vector3(0.8, 0.5, 0.06), "sign")
	brush.event_key = "probe_sign_read"
	_in_front(brush, -0.3)
	await _frames(2)
	_check(brush.interact_hold_seconds() > 0.0, "brushing takes a hold")
	_check(brush.interact() and brush.brushed, "a finished hold brushes it clean")
	_check(Game.heard_events.has("probe_sign_read"), "and tells Game what was under the snow")
	_check(not brush.interact() and not brush.is_in_group("interactables"), "a clean sign asks nothing more")
	_check(_sounded(brush, "cloth"), "brushing sounds on the Effects bus")
	var restored := Brushable.make(Game.errands.world_root(), "probe_sign_2", Transform3D.IDENTITY, Vector3(0.8, 0.5, 0.06))
	restored.apply_state(true)
	_check(restored.brushed and _saved("brush:probe_sign_2"), "brushed is saved and restored by id")
	brush.queue_free()
	restored.queue_free()
	await _frames(2)


func _snow_branch() -> void:
	# Outdoors on the route, where nothing stands between the bow and the branch.
	var at := Game.trail.on_ground(Game.trail.position_at(Game.trail.player_start_offset + 40.0))
	var branch := SnowBranch.make(Game.errands.world_root(), "probe_branch", at, 0.0)
	await _frames(2)
	var drops := [0]
	branch.dropped.connect(func() -> void: drops[0] += 1)
	_check(branch.loaded and branch.knock() and not branch.loaded, "a knock drops the snow")
	_check(branch.get_node_or_null("Puff") != null, "in a puff of powder")
	_check(not branch.knock(), "an empty branch drops nothing")
	Game.day_seconds += Tune.SNOW_BRANCH_REFILL + 1.0
	await _frames(2)
	_check(branch.loaded, "it loads up again as her day goes on")
	# An arrow fired into it, as the bow would.
	var arrow: Node3D = ARROW.new()
	add_child(arrow)
	var target := branch.global_position + Vector3.UP * (SnowBranch.HEIGHT + 0.08)
	arrow.global_position = target + Vector3(0.0, 0.0, 4.0)
	arrow.set("velocity", Vector3(0.0, 0.0, -30.0))
	await _frames(20)
	_check(not branch.loaded and drops[0] == 2, "an arrow knocks it down too")
	_check(_saved("branch:probe_branch"), "the branch is saved by id")
	branch.queue_free()
	if is_instance_valid(arrow):
		arrow.queue_free()
	await _frames(2)


func _warming() -> void:
	var spot := WarmSpot.make(Game.errands.world_root(), "ProbeWarmth", Vector3.ZERO, "the probe fire", func() -> bool: return true)
	_in_front(spot, -0.6)
	_player.warmth = 0.0
	await _frames(4)
	_check(_player.aim.target == spot, "the warm spot is picked")
	_action("interact", true)
	await _seconds(0.6)
	_check(_player.warming and _player.get("_slide_weight") > 0.3, "holding there crouches her")
	_action("interact", false)
	await _frames(4)
	_check(not _player.warming, "letting go stands her up")
	_action("interact", true)
	await _seconds(Tune.WARM_SECONDS + 0.4)
	_action("interact", false)
	await _frames(4)
	_check(_player.warmth > Tune.WARM_QUIET - 2.0, "a finished hold leaves her warm (%.0f s)" % _player.warmth)
	_check(not _player.warming, "and she stands again")
	var unlit := [false]
	var cold := WarmSpot.make(Game.errands.world_root(), "ProbeCold", Vector3.ZERO, "a cold grate", func() -> bool: return unlit[0])
	await _frames(2)
	_check(not cold.visible and not cold.interact(), "an unlit fire is not there to warm at")
	spot.queue_free()
	cold.queue_free()
	await _frames(2)


func _bell() -> void:
	var bell := Game.errands.world_root().get_node_or_null("LookoutBell") as Bell
	if bell == null or Game.voice == null:
		_check(false, "the bell and her voice exist")
		return
	var answers := [0]
	Game.voice.bell_answered.connect(func() -> void: answers[0] += 1)
	var stand := Game.trail.on_ground(bell.global_position + bell.global_basis.z * 0.9) + Vector3.UP * 0.05
	_player.global_position = stand
	_player.reset_physics_interpolation()
	await _frames(4)
	bell.ring()
	_check(_sounded(bell, "bell"), "the bell sounds on the Effects bus")
	await _seconds(Tune.BELL_ECHO_DELAY + 0.4)
	_check(answers[0] == 1, "the trees answer the first ring")
	bell.ring()
	await _seconds(Tune.BELL_ECHO_DELAY + 0.4)
	_check(answers[0] == 1, "but only once a visit")
	_player.global_position = bell.global_position + Vector3(0.0, 0.0, Bell.VISIT_RADIUS + 10.0)
	await _frames(4)
	_player.global_position = stand
	await _frames(4)
	bell.ring()
	await _seconds(Tune.BELL_ECHO_DELAY + 0.4)
	_check(answers[0] == 2, "a new visit gets a new answer")


func _finish() -> void:
	print("VERBS %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
