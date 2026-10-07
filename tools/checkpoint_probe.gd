extends Node

# The lookout checkpoint: reaching it keeps her pages; rebuilding the run from
# it puts her back at the lookout with them, the page gone from the field; a
# plain restart forgets it.
#   godot --headless --path . tools/checkpoint_probe.tscn

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	Game.set_phase(Game.Phase.PLAYING)
	var first := NoteCatalog.all()[0]
	Game.add_to_journal(first)
	_check(not Game.at_checkpoint and Game.checkpoint.is_empty(), "no checkpoint at the start")
	Game.player.global_position = Game.trail.on_ground(Game.trail.exit_point) + Vector3.UP * 0.3
	Game.player.reset_physics_interpolation()
	await _frames(4)
	_check(Game.at_checkpoint and not Game.checkpoint.is_empty(), "reaching the lookout keeps a checkpoint")
	_check(Game.phase == Game.Phase.PLAYING, "the lookout does not end the run")
	var kept: Transform3D = Game.checkpoint.at
	# What restart(true) does, without reloading the probe's own scene.
	main.queue_free()
	await get_tree().process_frame
	Game._resume = true
	Game.reset()
	_check(not Game.checkpoint.is_empty() and Game.journal.is_empty(), "reset keeps the checkpoint, not the run")
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	_check(Game.phase == Game.Phase.PLAYING and not Game.resuming(), "the rebuilt run starts at once")
	_check(Game.player.global_position.distance_to(kept.origin) < 1.5, "she is back at the lookout")
	_check(Game.journal.size() == 1 and Game.read_pages.has(first.title), "her page came with her")
	var page := Game.trail.get_node_or_null("FieldNote_0") as FieldNote
	_check(page != null and not page.visible and not page.is_in_group("field_notes"), "and it is gone from the field")
	_check(Game.at_checkpoint, "the resumed run counts as past the lookout")
	# A plain restart forgets it (restart() clears before it reloads).
	Game._resume = false
	Game.checkpoint.clear()
	_check(not Game.resuming() and Game.checkpoint.is_empty(), "a new run forgets the lookout")
	print("CHECKPOINT %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
