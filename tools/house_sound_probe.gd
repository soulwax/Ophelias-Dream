extends Node

var failed := false

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	print("HOUSE SOUND ",description," = ",value)
	if not value:
		failed = true
		push_error(description)

func settle(audio: StormAudio, ears: Vector3, shelter: float = 1.0) -> float:
	for step in range(120):
		audio._place_door_leak(ears,.8,.4,shelter)
	return audio._door_leak.volume_db

func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	Game.set_phase(Game.Phase.PLAYING)
	Game.player.set_process(false)
	Game.player.set_physics_process(false)
	var house: House = Game.house
	var audio: StormAudio = Game.weather._audio
	audio.set_process(false)
	Game.weather.set_process(false)
	var ears := house.to_global(Vector3(0,1.4,3))
	check(audio._door_leak.playing and audio._door_leak.bus==&"Ambience","recorded loop uses existing ambience routing")
	check(settle(audio,ears)<-79,"closed front door silences local wind")
	var door := house.doors["front"] as HouseDoor
	Game.player.global_position = house.to_global(Vector3(0,.08,3.4))
	check(door.interact(),"front door physically opens")
	for frame in range(120): await get_tree().physics_frame
	var open_level := settle(audio,ears)
	check(open_level> -55,"open front door admits local wind")
	var occluded := settle(audio,house.to_global(Vector3(-3.8,1.4,2.7)))
	check(occluded<open_level-20,"closed room partition attenuates the leak")
	check(settle(audio,house.to_global(Vector3(-5.2,-2.2,-2.8)))< -79,"cellar suppresses front-door leak")
	check(settle(audio,ears,0.0)< -79,"outside listening does not double the storm")
	print("HOUSE SOUND ","FAIL" if failed else "PASS")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
