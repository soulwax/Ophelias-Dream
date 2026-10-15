extends Node

## Where each chapter starts once main.gd has finished loading: Mathilda by her
## camp (and at the doorway with RUN_MEETING=1), Ophelia on her authored spawn.
## PROBE_CHAPTER=mathilda runs Mathilda's chapter; quits 1 on any failure.

var _failures := 0


func _ready() -> void:
	# main.gd stops at the title menu unless a run is asked for (since 9b7a3fd).
	OS.set_environment("RUN_MATHILDA" if OS.get_environment("PROBE_CHAPTER") == "mathilda" else "RUN_PLAY", "1")
	_run.call_deferred()


func _check(ok: bool, label: String, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if detail.is_empty() else "  (" + detail + ")"))
	if not ok:
		_failures += 1


func _run() -> void:
	var mathilda := OS.get_environment("PROBE_CHAPTER") == "mathilda"
	Game.mathilda_pov = mathilda
	get_tree().root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	# Past every loading stage: wait for the world to reach PLAYING, then a little more.
	for frame in 1200:
		await get_tree().process_frame
		if Game.phase == Game.Phase.PLAYING and Game.player:
			break
	for frame in 30:
		await get_tree().physics_frame
	_check(Game.phase == Game.Phase.PLAYING, "the chapter is playing", str(Game.phase))
	if Game.player == null or Game.house == null:
		_check(false, "player and house exist")
		get_tree().quit(1)
		return
	var at := Game.player.global_position
	var room := Game.house.room_at(at)
	if mathilda:
		var chapter: Node = Game.voice
		var camp: Vector3 = chapter.get("_camp")
		if OS.get_environment("RUN_MEETING") != "":
			var ophelia: Node3D = chapter.get("_ophelia")
			var gap := at.distance_to(ophelia.global_position) if is_instance_valid(ophelia) else INF
			var across := Vector2(at.x - ophelia.global_position.x, at.z - ophelia.global_position.z).length() if is_instance_valid(ophelia) else INF
			var drop := ophelia.global_position.y - at.y if is_instance_valid(ophelia) else INF
			_check(gap < 3.2, "Mathilda starts within reach of Ophelia at the door", "%.2f m: %.2f across, %.2f below her, room '%s'" % [gap, across, drop, room])
			if is_instance_valid(ophelia):
				var ground: Node = Game.trail.ground
				var her_at := ophelia.global_position
				print("  Ophelia y %.2f over terrain %.2f; Mathilda y %.2f over terrain %.2f; doorstep y %.2f; house floor y %.2f" % [
					her_at.y, ground.height_at(her_at.x, her_at.z), at.y, ground.height_at(at.x, at.z),
					Game.house.doorstep().y, Game.house.global_position.y])
				# OpheliaNpc.settle() takes the first world hit falling from 3 m above.
				var space := Game.player.get_world_3d().direct_space_state
				var from := Vector3(her_at.x, Game.house.doorstep().y + 3.0, her_at.z)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, Tune.LAYER_WORLD))
				if not hit.is_empty():
					var collider := hit.collider as Node
					print("  settle ray hits %s at y %.2f" % [collider.get_path() if collider else "?", (hit.position as Vector3).y])
		else:
			var gap := Vector2(at.x - camp.x, at.z - camp.z).length()
			_check(gap < 12.0, "Mathilda starts by her camp", "%.1f m from it, room '%s'" % [gap, room])
			_check(not Game.house.contains(at), "Mathilda does not start inside the house", "room '%s'" % room)
	else:
		_check(Game.house.contains(at), "Ophelia wakes inside the house", "room '%s'" % room)
	print("Spawn probe: %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
