extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var actor := Player.new()
	get_tree().root.add_child(actor)
	Game.player = actor
	var voice := Voice.new()
	get_tree().root.add_child(voice)
	voice._active = true
	voice._load()
	voice._build_speaker()
	var count := 0
	var file := FileAccess.open(Voice.LINES, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var lines: Array = data.pages.values() + data.places.values() + data.bored
	for line in lines:
		var path: String = Voice.CLIPS + str(line).sha256_text() + ".wav"
		assert(ResourceLoader.exists(path), "Missing imported voice asset: " + path)
		var clip := load(path) as AudioStream
		assert(clip != null and clip.get_length() > 0.0, path)
		count += 1
	assert(voice.say(str(lines[0])))
	assert(voice._speaker.playing)
	assert(is_equal_approx(Game.murmur_left, voice._speaker.stream.get_length()))
	# Once in game by default: repeating the same line is ignored unless repeat=true.
	voice._speaker.stop()
	assert(not voice.say(str(lines[0])))
	assert(voice.say(str(lines[0]), true, true))
	assert(voice.say(str(lines[1]), true))
	assert(Game.murmur == lines[1])
	voice._finished()
	assert(Game.murmur_left == 0.0)
	var note := NoteCatalog.bedside()
	voice.heard_page(note)
	assert(Game.murmur == data.pages["by the bed"])
	voice._finished()
	Game.murmur = ""
	voice.heard_page(note)
	assert(Game.murmur == "")
	voice.heard_page(note, true)
	assert(Game.murmur == data.pages["by the bed"])
	assert(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "Effects")
	print("VOICE PASS: ", count, " clips imported as assets; once-per-game, repeat override, page reaction, subtitle sync, Voice bus")
	get_tree().quit()
