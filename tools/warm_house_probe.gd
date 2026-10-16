extends Node

# MASTERPLAN W07 / errands T7: warm_house from the cold stove to the warm house,
# through a real save and reload in the middle and at the end. Run as is, with
# RUN_VENDOR=off (stand-in props), and with PROBE_CHAPTER=mathilda (no errands:
# the stove lights at once, as before). Isolate user data (docs/mvp/BASELINE.md).
#   godot --headless --path . tools/warm_house_probe.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	if OS.get_environment("PROBE_CHAPTER") == "mathilda":
		OS.set_environment("RUN_MATHILDA", "1")
		Game.mathilda_pov = true
	else:
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


func _start() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	for frame in 900:
		await get_tree().process_frame
		if Game.player and Game.phase == Game.Phase.PLAYING and not RunSave.has_pending_load() \
				and (Game.mathilda_pov or (Game.errands and Game.errands.is_built)):
			break
	await _frames(10)
	if Game.player:
		Game.player._autopilot = ""


func _stove() -> Chore:
	return Game.trail.house.find_child("StoveChore", true, false) as Chore


func _warm() -> WarmHouse:
	return Game.errands.builders.get(WarmHouse.ID) as WarmHouse if Game.errands else null


# Stand her beside a thing so it is in reach from her chest.
func _stand_by(at: Vector3) -> void:
	var player := Game.player
	# Outdoors on the side away from the house, indoors on the room's side, so
	# no wall stands between her and the thing.
	var house := Game.trail.house
	var inside := house.contains(at + Vector3.UP * 0.3)
	var away := (at - house.global_position) if not inside else (house.global_position - at)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	var spot := at + away * 0.7
	# Indoors on the boards (y 0 of the house), outdoors on the snow.
	var floor_y := house.global_position.y if inside else Game.trail.ground.height_at(spot.x, spot.z)
	player.global_position = Vector3(spot.x, floor_y + 0.05, spot.z)
	player.velocity = Vector3.ZERO
	player._glide = Vector3.ZERO
	player.reset_physics_interpolation()
	await _frames(6)


func _loose_armful() -> Carryable:
	for item_id: String in Game.errands.get("_items"):
		var armful := Game.errands.item(item_id)
		if item_id.begins_with(WarmHouse.ARMFUL) and armful and armful.socket == null and armful.carrier == null:
			return armful
	return null


func _armfuls() -> int:
	var count := 0
	for item_id: String in Game.errands.get("_items"):
		if item_id.begins_with(WarmHouse.ARMFUL) and Game.errands.item(item_id) != null:
			count += 1
	return count


func _carry_one() -> bool:
	var armful := _loose_armful()
	if armful == null:
		return false
	await _stand_by(armful.global_position)
	if not Game.player.pick_up(armful):
		print("  could not pick up %s from %.2f m" % [armful.item_id, Game.player.global_position.distance_to(armful.global_position)])
		return false
	await _frames(4)
	var warm := _warm()
	await _stand_by(warm.box.global_position)
	var placed := Game.player.place(warm.box)
	if not placed:
		print("  could not place: %.2f m from the box, in reach %s, accepts %s" % [Game.player.global_position.distance_to(warm.box.global_position),
			Game.player.aim._in_reach(Game.player, warm.box), warm.box.can_accept(Game.player.carrying)])
	await _frames(4)
	return placed


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
	var warm := _warm()
	_check(warm != null and warm.box != null and warm.pile != null, "the woodpile and the woodbox are built")
	if warm == null:
		_finish()
		return
	_check(warm.pile.global_position.distance_to(Game.trail.house.doorstep()) < 6.0 and not Game.trail.house.contains(warm.pile.global_position + Vector3.UP * 0.5), "the woodpile is outside, by the door")
	_check(Game.trail.house.contains(warm.box.global_position + Vector3.UP * 0.3), "the woodbox is inside, by the stove")
	var top := -INF
	var size := Vector3.ZERO
	for mesh: MeshInstance3D in warm.pile.find_children("*", "MeshInstance3D", true, false):
		if mesh.visible:
			var box := mesh.global_transform * mesh.get_aabb()
			top = maxf(top, box.end.y)
			size = size.max(box.size)
	var snow := Game.trail.ground.height_at(warm.pile.global_position.x, warm.pile.global_position.z)
	print("  woodpile: top %.2f m over the snow, largest part %.2f x %.2f x %.2f m" % [top - snow, size.x, size.y, size.z])
	_check(top - snow > 0.3, "the woodpile stands out of the snow")
	var space := Game.player.get_world_3d().direct_space_state
	var from := warm.pile.global_position + Vector3(0.0, 4.0, 0.0)
	var down := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0, Tune.LAYER_WORLD)
	var hit := space.intersect_ray(down)
	var surface: float = (hit.position as Vector3).y if not hit.is_empty() else snow
	print("  woodpile at house-local %s; the surface there is %.2f m %s its foot (%s)" % [Game.trail.house.to_local(warm.pile.global_position),
		absf(surface - warm.pile.global_position.y), "above" if surface > warm.pile.global_position.y else "below", (hit.collider as Node).name if not hit.is_empty() else "terrain function"])
	_check(top - surface > 0.3, "the woodpile stands out of whatever surface is there")
	# The cold stove.
	var stove := _stove()
	_check(not Game.errands.is_known(WarmHouse.ID), "nothing is known before she tries the stove")
	_check(stove.interact_label() == "No wood in the box", "the stove's prompt says the box is empty")
	_check(not stove.interact() and not stove.done, "the cold stove does not light")
	_check(Game.errands.is_known(WarmHouse.ID), "trying it, she knows the errand")
	_check(Game.errands.get_errand(WarmHouse.ID).undone_text() != "", "and it has words in the journal")
	# The armfuls.
	await _frames(2)
	_check(_armfuls() == 1 and _loose_armful() != null, "one armful waits on the pile")
	_check(await _carry_one(), "she carries the first armful to the box")
	_check(Game.errands.get_errand(WarmHouse.ID).step_id() == "carry", "the errand is at carrying")
	await _frames(2)
	_check(_armfuls() == 2 and _loose_armful() != null, "a second armful waits on the pile")
	_check(await _carry_one(), "she carries the second")
	await _frames(2)
	# Save while she carries the third, with two in the box, and load it.
	var third := _loose_armful()
	await _stand_by(third.global_position)
	_check(Game.player.pick_up(third), "she picks up the third")
	await _frames(4)
	_check(RunSave.save_now(), "the run saves while she carries it")
	await _reload()
	warm = _warm()
	_check(warm != null and warm.box.held.size() == 2, "after loading, two armfuls are in the box")
	_check(is_instance_valid(Game.player.carrying) and Game.player.carrying.item_id == third.item_id if is_instance_valid(third) else Game.player.carrying != null, "and the third is back in her arms")
	_check(_armfuls() == 3 and _loose_armful() == null, "and no extra armful appeared")
	_check(not _stove().done, "the stove is still cold")
	await _stand_by(warm.box.global_position)
	_check(Game.player.place(warm.box), "she puts the third in the box")
	await _frames(4)
	_check(Game.errands.get_errand(WarmHouse.ID).step_id() == "light", "the box is full: now the stove")
	_check(_loose_armful() == null and _armfuls() == 3, "the pile gives nothing more")
	_check(_stove().blocked_label() == "", "the stove no longer refuses")
	await _stand_by(_stove().global_position)
	_check(_stove().interact() and _stove().done, "the stove lights")
	await _frames(4)
	_check(Game.errands.is_done(WarmHouse.ID), "the errand is done")
	# The warm house settles.
	var haunting := Game.trail.house.haunting
	if haunting:
		await _stand_by(Game.trail.house.to_global(Vector3(3.0, 0.5, 0.0)))
		haunting.tension = 0.5
		await _frames(120)
		_check(haunting.tension < 0.5, "inside the warm house the tension eases (%.2f)" % haunting.tension)
	else:
		_check(false, "the haunting exists")
	# Save after completion, and load again.
	_check(RunSave.save_now(), "the run saves with the house warm")
	await _reload()
	_check(Game.errands.is_done(WarmHouse.ID) and _stove().done, "after loading, the errand is done and the stove lit")
	var crackle := Game.trail.house.find_child("HearthCrackle", true, false) as AudioStreamPlayer3D
	_check(crackle != null and crackle.playing, "the hearth is crackling again")
	_check(_warm().box.held.size() == 3 and _loose_armful() == null, "the box is full and the pile quiet")
	_finish()


func _reload() -> void:
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(RunSave.queue_load(), "the save loads")
	await _start()


func _mathilda() -> void:
	_check(Game.errands == null, "Mathilda's chapter builds no errands")
	var stove := _stove()
	_check(stove != null and stove.interact_label() == "Light the stove", "her stove asks to be lit")
	_check(stove.interact() and stove.done, "and lights at once")


func _finish() -> void:
	print("WARM_HOUSE %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
