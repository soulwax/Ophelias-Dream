extends "res://tools/warm_house_probe.gd"

## W08 reuses W07's real-world setup, reach helpers, wood carrying and
## RunSave reload harness. Tests its own sequence, including a closed cupboard
## after taking the cup, out-of-order actions and the actual lake flag bridge.
## RUN_VENDOR=off tests fallback; PROBE_CHAPTER=mathilda tests exclusion.
## PROBE_CUPS_CAPTURE=1 also writes rendered evidence into build/mvp/g3/W08.

func _cups() -> TwoCups:
	return Game.errands.builders.get(TwoCups.ID) as TwoCups if Game.errands else null


func _run() -> void:
	await _start()
	if Game.player == null:
		_check(false, "the chapter starts")
		_finish()
		return
	if Game.mathilda_pov:
		await _mathilda()
		_finish()
		return
	var cups := _cups()
	_check(cups != null, "the cups builder exists")
	if cups == null:
		_finish()
		return
	if OS.get_environment("PROBE_CUPS_VIEW") == "1":
		await _view(cups)
		_finish()
		return
	_check(not Game.errands.is_known(TwoCups.ID) and not Game.known("event:cups"), "no errand or evidence before discovery")
	var own := Game.errands.item(TwoCups.OWN_CUP)
	var hers := Game.errands.item(TwoCups.HER_CUP)
	_check(not own.visible and not own.can_take(), "a closed cupboard hides and gates its cup")
	_check(hers.visible and cups.snow.visible, "her cup waits half under snow on the rail")
	var bounds := TwoCups._bounds(hers.visual, Transform3D.IDENTITY)
	_check(bounds.size.y > 0.1 and bounds.size.y < 0.25, "the cup is cup-sized with either asset source")
	_check(absf(hers.global_position.y - (cups.rail.global_position.y + 0.91)) < 0.02, "the porch cup rests on the rail")
	_check(not cups.heat.interact(), "an empty cold stove cannot complete the errand")
	await _capture("porch", Vector3(2.7, 1.7, 6.8), TwoCups.RAIL_AT + Vector3.UP * 0.8)
	await _stand_by(cups.cupboard.interact_point())
	_check(Game.player.aim._in_reach(Game.player, cups.cupboard), "the cupboard can be reached from the kitchen")
	_check(cups.cupboard.interact() and own.visible, "opening reveals the single cup")
	await _frames(35)
	_check(Game.errands.is_known(TwoCups.ID), "opening teaches the missing-cup errand")
	await _capture("cupboard", Vector3(5.5, 1.8, -2.9), TwoCups.CUPBOARD_AT + Vector3.UP * 0.25)
	_check(Game.player.pick_up(own), "she takes the cupboard cup")
	_check(cups.cupboard.interact() and not cups.cupboard.is_open, "she closes the cupboard while carrying it")
	_check(own.visible and cups.cupboard_taken, "closing cannot hide the taken cup")
	_check(RunSave.save_now(), "save with her cup carried and cupboard closed")
	await _reload()
	cups = _cups()
	own = Game.errands.item(TwoCups.OWN_CUP)
	_check(Game.player.carrying == own and own.visible and not cups.cupboard.is_open, "reload restores the visible carried cup outside the closed cupboard")
	await _stand_table(cups.table)
	_check(Game.player.place(cups.table), "she sets her cup on the table")
	await _frames(4)
	_check(own.visible and cups.table.held.size() == 1, "the restored cup stays visible after placement")
	_check(not cups.heat.interact(), "one cup does not complete the errand")
	hers = Game.errands.item(TwoCups.HER_CUP)
	await _stand_rail(cups)
	_check(Game.player.aim._in_reach(Game.player, hers), "the porch cup is reachable from the landing")
	_check(Game.player.pick_up(hers), "she takes Mathilda's cup from the rail")
	_check(not cups.snow.visible and Game.errands.get_errand(TwoCups.ID).step_id() == "found", "finding clears the snow and advances the journal")
	_check(RunSave.save_now(), "save with one cup set and the other carried")
	await _reload()
	cups = _cups()
	hers = Game.errands.item(TwoCups.HER_CUP)
	_check(cups.table.held.size() == 1 and Game.player.carrying == hers and not cups.snow.visible, "reload preserves both distinct cups and the brushed snow")
	await _stand_table(cups.table)
	_check(Game.player.place(cups.table), "she sets the second cup beside the first")
	await _frames(4)
	_check(cups.table.held.size() == 2 and cups.table.held[0].global_position.distance_to(cups.table.held[1].global_position) > 0.3, "the pair sits side by side, not stacked")
	var left := Game.errands.item(TwoCups.OWN_CUP)
	var right := Game.errands.item(TwoCups.HER_CUP)
	var right_at := right.global_transform
	cups.table.remove_item(left)
	_check(right.global_transform.is_equal_approx(right_at), "taking one cup leaves the other's natural placement untouched")
	cups.table.add_item(left)
	_check(right.global_transform.is_equal_approx(right_at), "reversed socket order keeps each cup by its own chair")
	_check(Game.errands.get_errand(TwoCups.ID).step_id() == "kettle", "the journal now asks for the kettle")
	var kettle := Game.errands.item(TwoCups.KETTLE)
	await _stand_by(kettle.global_position)
	_check(Game.player.pick_up(kettle), "she takes the kettle from the counter")
	await _stand_stove(cups)
	_check(Game.player.place(cups.hotplate), "she puts the kettle on the stove")
	await _frames(3)
	_check(cups.heat.blocked_label() == "The stove is cold" and not cups.heat.interact(), "even with both cups set, the cold stove refuses")
	_check(not Game.known("event:cups"), "placing everything grants no premature evidence")
	await _lake_topics(false)
	# Complete the real warm-house prerequisite, without manufacturing its flag.
	_stove().interact()
	for index in Tune.ERRAND_WOOD_ARMFULS:
		_check(await _carry_one(), "carry prerequisite armful %d" % index)
	await _stand_by(_stove().global_position)
	_check(_stove().interact(), "light the filled stove")
	await _frames(4)
	_check(Game.errands.is_done(WarmHouse.ID) and cups.heat.blocked_label() == "", "the lit stove enables warming")
	await _stand_stove(cups)
	await _aim_at(cups.heat)
	print("  kettle target: %s; far: %s; reachable: %s; phase: %s" % [Game.player.aim.target.name if Game.player.aim.target else "none", Game.player.aim.far.name if Game.player.aim.far else "none", Game.player.aim._in_reach(Game.player, cups.heat), Game.phase])
	_check(Game.player.aim.target == cups.heat, "the actual reticle selects kettle warming")
	if Game.player.aim.target != cups.heat:
		_finish()
		return
	_press(true)
	await _frames(int(Tune.HOLD_DEFAULT * 60.0 * 0.5))
	_check(not Game.errands.is_done(TwoCups.ID), "a half hold has not warmed the kettle")
	await _frames(int(Tune.HOLD_DEFAULT * 60.0) + 20)
	_press(false)
	await _frames(3)
	_check(Game.errands.is_done(TwoCups.ID) and Game.known("event:cups"), "a real hold warms the kettle and grants cups evidence")
	_check(cups.steam.emitting and not cups.heat.is_in_group("interactables"), "warm steam replaces the finished interaction")
	_check(not Game.errands.item(TwoCups.OWN_CUP).can_take() and not kettle.can_take(), "the completed pair and kettle stay where her lake line says")
	_check(cups.table.held.all(func(cup: Carryable) -> bool: return not cup.is_in_group("interactables")), "completed cups offer no stale pickup prompts")
	await _capture("warm_table", Vector3(3.0, 2.1, -1.0), Vector3(4.55, 0.95, -2.2))
	_check(RunSave.save_now(), "save the completed tea setting")
	await _reload()
	cups = _cups()
	_check(Game.errands.is_done(TwoCups.ID) and cups.table.held.size() == 2 and cups.hotplate.held.size() == 1, "reload keeps the completed pair and kettle in their sockets")
	_check(Game.errands.item(TwoCups.HER_CUP).global_transform.is_equal_approx(right_at), "save/load preserves the cup's authored offset and angle")
	_check(_stove().done and cups.steam.emitting and Game.known("event:cups"), "reload restores fire, steam and evidence")
	_check(cups.table.held.all(func(cup: Carryable) -> bool: return not cup.is_in_group("interactables")), "restored cups offer no stale pickup prompts")
	_check(not cups.heat.interact(), "completion cannot be replayed")
	var warmth := Game.errands.world_root().get_node("StoveWarmth") as WarmSpot
	await _stand_stove(cups)
	await _aim_at(warmth)
	_check(Game.player.aim.target == warmth, "the fire door still offers warming hands below the kettle")
	await _lake_topics(true)
	_reading_and_endings()
	_finish()


func _stand_table(table: CarrySocket) -> void:
	await _stand_local(Vector3(4.45, 0.05, -1.7))
	_check(Game.player.aim._in_reach(Game.player, table), "the table is within reach")


func _stand_rail(cups: TwoCups) -> void:
	await _stand_local(Vector3(0.45, 0.05, 5.4))


func _stand_stove(cups: TwoCups) -> void:
	await _stand_local(Vector3(4.35, 0.05, -0.8))


func _stand_local(at: Vector3) -> void:
	Game.player.global_position = Game.trail.house.to_global(at)
	Game.player.velocity = Vector3.ZERO
	Game.player._glide = Vector3.ZERO
	Game.player.reset_physics_interpolation()
	await _frames(8)


func _aim_at(thing: Node3D) -> void:
	var player := Game.player
	# Use the real camera and input path while keeping its test view stable.
	player.camera.top_level = true
	player.camera.global_position = player.global_position + Vector3.UP * 1.55
	player.camera.look_at(Aim.centre_of(thing))
	for frame in 12:
		await get_tree().process_frame
		player.camera.look_at(Aim.centre_of(thing))


func _press(on: bool) -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = on
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _lake_topics(done: bool) -> void:
	var lake := get_tree().get_first_node_in_group("lake") as Lake
	if lake.meeting == null:
		lake._place_mathilda(Game.trail)
	lake._refresh_errand_flags()
	_check(lake.meeting.flags.has("cups") == done, "Lake supplies the actual completed-cups flag: %s" % done)
	var topics := lake.meeting.tree.topics("held", lake.meeting.flags, {})
	var cups_topic := topics.filter(func(topic: Dictionary) -> bool: return topic.get("say") == "o21")
	_check((cups_topic.size() == 1) == done, "cups topic availability matches completion")
	_check(lake.meeting.tree.problems().is_empty(), "lake lines, nodes and replies are coherent")
	if done and not cups_topic.is_empty():
		var topic: Dictionary = cups_topic[0]
		_check(topic.reply == ["m24"], "the approved exchange answers with m24")
		var taken := {str(topic.key): true}
		_check(lake.meeting.tree.topics("held", lake.meeting.flags, taken).all(func(choice: Dictionary) -> bool: return choice.get("say") != "o21"), "the optional exchange is once only")
		await _speak_cups(lake.meeting)


func _wait_choices(conversation: Conversation) -> bool:
	for frame in 600:
		await get_tree().physics_frame
		if conversation._menu.choices_shown:
			return true
		conversation.skip()
	return false


func _speak_cups(conversation: Conversation) -> void:
	_check(conversation.begin(), "the actual lake conversation begins")
	for expected in ["turned", "lake", "held"]:
		if not await _wait_choices(conversation):
			_check(false, "conversation reaches choices at " + expected)
			conversation.cancel()
			return
		_check(conversation.node_id == expected, "conversation reaches " + expected)
		if expected != "held":
			conversation.choose(0)
	var index := -1
	for choice in conversation._topics.size():
		if conversation._topics[choice].get("say") == "o21":
			index = choice
	_check(index >= 0, "the cups exchange is offered in the actual menu")
	if index >= 0:
		conversation.choose(index)
		_check(await _wait_choices(conversation), "the cups exchange returns to the topics")
		_check(conversation.heard.has("o21") and conversation.heard.has("m24"), "both approved cups lines play through Conversation")
		_check(conversation._topics.all(func(choice: Dictionary) -> bool: return choice.get("say") != "o21"), "the actual menu removes the spoken cups exchange")
	conversation.cancel()
	_check(Game.phase == Game.Phase.PLAYING, "leaving the cups conversation returns control")


func _reading_and_endings() -> void:
	var pack := NoteCatalog.find("from the pack")
	Game.visited.erase("living")
	_check(Game.reading_known(pack.smudges[0]), "cups evidence can interpret the pair without the living-room key")
	_check(Game.decipher(pack, 0, "two") == Game.Reading.RIGHT, "the real decipher path accepts cups evidence")
	Game.heard_events.erase("cups")
	Game.visit("living")
	_check(Game.reading_known(pack.smudges[0]), "the original living-room key still works without cups")
	for entry in NoteCatalog.all():
		Game.add_to_journal(entry)
	Game.deciphered[NoteCatalog.LAST_TITLE] = {0: true, 1: true}
	var errand := Game.errands.get_errand(TwoCups.ID)
	for state in [Errand.State.UNKNOWN, Errand.State.KNOWN, Errand.State.LET_GO, Errand.State.DONE]:
		errand.state = state
		_check(Game.meeting_ready(), "base meeting eligibility does not depend on cups state %s" % state)
	Game.turned_around = true
	_check(not Game.meeting_ready(), "cups never bypass the no-turning-around rule")
	Game.turned_around = false


func _capture(label: String, camera_at: Vector3, target: Vector3) -> void:
	if OS.get_environment("PROBE_CUPS_CAPTURE") != "1":
		return
	var view := Camera3D.new()
	get_tree().root.add_child(view)
	view.global_position = Game.trail.house.to_global(camera_at)
	view.look_at(Game.trail.house.to_global(target))
	view.fov = 55.0
	view.make_current()
	await _frames(20)
	await RenderingServer.frame_post_draw
	var path := "res://build/mvp/g3/W08/%s.png" % label
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "capture " + label)
	view.queue_free()
	Game.player.camera.make_current()


func _finish() -> void:
	print("CUPS %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## Fast rendered placement review; the normal mode above owns persistence
## and input acceptance. This mode constructs a completed setting explicitly.
func _view(cups: TwoCups) -> void:
	Game.voice.hushed = true
	Game.murmur = ""
	Game.murmur_left = 0.0
	await _capture("porch", Vector3(2.7, 1.7, 6.8), TwoCups.RAIL_AT + Vector3.UP * 0.8)
	cups.cupboard.interact()
	await _frames(35)
	await _capture("cupboard", Vector3(5.5, 1.8, -2.9), TwoCups.CUPBOARD_AT + Vector3.UP * 0.25)
	cups.cupboard.release(Game.errands.item(TwoCups.OWN_CUP))
	cups.snow.hide()
	for id in [TwoCups.OWN_CUP, TwoCups.HER_CUP]:
		cups.table.add_item(Game.errands.item(id))
	cups.hotplate.add_item(Game.errands.item(TwoCups.KETTLE))
	_stove().restore_done()
	Game.errands.finish(WarmHouse.ID)
	_check(cups.warm_kettle(), "construct the warm setting for visual review")
	await _frames(100)
	await _capture("warm_table", Vector3(3.0, 2.1, -1.0), Vector3(4.55, 0.95, -2.2))
