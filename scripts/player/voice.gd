class_name Voice
extends Node

# Her lines were written once by the local model and saved in
# assets/audio/voice/lines.json. Playing does not call the model. Regenerate
# that file with tools/bake_voice.py while the server at 127.0.0.1:8765 is up.
# tools/bake_speech.py reads the reviewed text into CPU-generated wav clips.

const LINES := "res://assets/audio/voice/lines.json"
const CLIPS := "res://assets/audio/voice/"

const PLACES := {
	"bedroom": "the bedroom, and the wool that was already warm",
	"hall": "the front hall, and the door to the snow",
	"living": "the living room, with the candle burned down",
	"backhall": "the back hall, and the stairs going down",
	"stair": "the stairs down under the house",
	"landing": "the bottom of the stairs",
	"corridor": "a cellar corridor",
	"janitor": "a janitor's room in the cellar",
	"morgue": "the room with the chambers, and a sheet",
	"snow": "the snow outside, after the wool and the lantern",
	"lights": "the lights at the far end of the field, already on",
}

var _pages := {}
var _places := {}
var _bored: Array[String] = []
var _clips := {}
var _bored_at := 0
var _place_dwell := 0.0
var _last_place := ""
var _still := 0.0
var _since := 99.0
var _seen := {}
var _heard_pages := {}
var _spoken_once := {}
var _active := false
var _speaker: AudioStreamPlayer3D
var _spoken_line := ""


func _ready() -> void:
	Game.voice = self
	if OS.get_environment("RUN_CAPTURE") == "1" or DisplayServer.get_name() == "headless":
		return
	if OS.get_environment("RUN_VOICE") == "0":
		return
	_active = true
	_load()
	_build_speaker()
	Game.phase_changed.connect(_on_phase)


func _build_speaker() -> void:
	_speaker = Loudness.voice(Tune.VOICE_SPL, "Voice")
	if Game.player and Game.player.breath:
		Game.player.breath.get_parent().add_child(_speaker)
	elif Game.player:
		Game.player.add_child(_speaker)
		_speaker.position = Vector3(0.0, 1.55, 0.0)
	else:
		add_child(_speaker)
	_speaker.finished.connect(_finished)


func _on_phase(next: int) -> void:
	if next in [Game.Phase.BOOT, Game.Phase.CAUGHT, Game.Phase.ESCAPED]:
		_speaker.stop()
		_finished()


func _finished() -> void:
	if Game.murmur == _spoken_line:
		Game.murmur_left = 0.0
	_spoken_line = ""


func _process(delta: float) -> void:
	if not _active or Game.player == null:
		return
	_since += delta
	if _speaker.playing and Game.murmur == _spoken_line:
		Game.murmur_left = maxf(Game.murmur_left, 0.2)
	if Game.phase != Game.Phase.PLAYING:
		_still = 0.0
		return
	_notice(delta)


func heard_page(entry: NoteEntry, repeat := false) -> void:
	if not _active or entry == null:
		return
	var title := entry.title
	if _heard_pages.has(title) and not repeat:
		return
	var line := str(_pages.get(title, ""))
	if line == "":
		line = "They wrote it down so I would have to answer."
	if _say(line, true, repeat):
		_heard_pages[title] = true


func say(line: String, interrupt := false, repeat := false) -> bool:
	return _say(line, interrupt, repeat)


func _notice(delta: float) -> void:
	var room := ""
	if Game.house:
		room = Game.house.room_at(Game.player.global_position + Vector3(0.0, 0.9, 0.0))
	var place := room
	if place == "":
		if Game.trail:
			var at := Game.player.global_position
			var end := Game.trail.exit_point
			if Vector2(at.x - end.x, at.z - end.z).length() < 40.0 and not _seen.has("lights"):
				place = "lights"
		if place == "":
			place = "snow"
	if place != _last_place:
		_last_place = place
		_place_dwell = 0.0
	else:
		_place_dwell += delta
	if place != "" and not _seen.has(place):
		var wait := 1.2 if place == "bedroom" else 0.45
		if _place_dwell >= wait and _since >= 2.2 and not _speaker.playing and Game.murmur_left <= 0.0:
			_say_place(place)
		return
	var speed := Vector2(Game.player.velocity.x, Game.player.velocity.z).length()
	if speed > 0.35:
		_still = 0.0
		return
	_still += delta
	if _still < Tune.BORED_AFTER or _since < Tune.VOICE_GAP or _speaker.playing or Game.murmur_left > 0.4:
		return
	_still = 0.0
	var bored_line := _next_bored()
	if bored_line != "":
		_say(bored_line)


func _say_place(place: String, repeat := false) -> void:
	if _seen.has(place) and not repeat:
		return
	var line := str(_places.get(place, ""))
	if line == "":
		line = _stock_place(place)
	if _say(line, false, repeat):
		_seen[place] = true


func _say(line: String, interrupt := false, repeat := false) -> bool:
	if line == "":
		return false
	if _spoken_once.has(line) and not repeat:
		return false
	if _speaker.playing and not interrupt:
		return false
	_speaker.stop()
	_spoken_once[line] = true
	Game.murmur_line(line)
	_since = 0.0
	_spoken_line = line
	var stream: AudioStream = _clips.get(line)
	if stream == null:
		var path := CLIPS + line.sha256_text() + ".wav"
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			if stream:
				_clips[line] = stream
	if stream:
		_speaker.stream = stream
		Game.murmur_left = stream.get_length()
		_speaker.play()
	return true


func _next_bored() -> String:
	while _bored_at < _bored.size():
		var line := _bored[_bored_at]
		_bored_at += 1
		if not _spoken_once.has(line):
			return line
	return ""


func _load() -> void:
	if not FileAccess.file_exists(LINES):
		push_warning("Voice: no saved lines at " + LINES)
		return
	var file := FileAccess.open(LINES, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data := parsed as Dictionary
	if typeof(data.get("pages")) == TYPE_DICTIONARY:
		_pages = data["pages"]
	if typeof(data.get("places")) == TYPE_DICTIONARY:
		_places = data["places"]
	var bored: Variant = data.get("bored", [])
	if typeof(bored) == TYPE_ARRAY:
		for item in bored:
			var line := str(item).strip_edges()
			if line != "":
				_bored.append(line)
	for line in _pages.values() + _places.values() + _bored:
		var text := str(line)
		var path := CLIPS + text.sha256_text() + ".wav"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				_clips[text] = stream


func _stock_place(place: String) -> String:
	match place:
		"morgue":
			return "Of course there is a room for a body. Of course I came down."
		"snow":
			return "The snow does not care that I left the wool."
		"lights":
			return "The lights were already on. They can keep waiting."
		"stair":
			return "Down is a decision. I am already on it."
	return "I knew this would be here. I came anyway."
