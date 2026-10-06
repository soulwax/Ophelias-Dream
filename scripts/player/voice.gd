class_name Voice
extends Node

# She speaks pre-baked lines with subtitles (docs/VOICE.md). The text, with a
# mood per line, is in assets/audio/voice/lines.json; tools/bake_speech.py
# turns each line into a clip named by the SHA-256 of "text|mood". Playing
# never runs a model. A line cut off by a more important one is forgotten, as
# if it had never started, and plays whole at its next chance.

const LINES := "res://assets/audio/voice/lines.json"
const CLIPS := "res://assets/audio/voice/"
# Only a higher number cuts off a playing line (a misread may cut a misread).
const PRIORITY := {"page": 3, "deciphered": 3, "place": 2, "revisit": 2, "bored": 1, "call": 1, "misread": 1}
const STAGES := ["hope", "doubt", "resolve"]
const MOODS := ["steady", "warm", "hushed", "shaken", "breaking", "resolve", "calling"]
const FALLBACK_PAGE := "She wrote this for me. I have to keep going."

# Where each place is, for the drafter (tools/bake_voice.py) and the probes.
const PLACES := {
	"bedroom": "the bedroom she woke in, the lantern lit, Mathilda's side of the bed",
	"hall": "the front hall, the door to the storm",
	"living": "the living room, two chairs pulled out, a candle burned down",
	"backhall": "the back hall, and the stairs going down",
	"stair": "the stairs down under the house",
	"landing": "the bottom of the stairs, no wind",
	"corridor": "a long cellar corridor",
	"janitor": "a janitor's room in the cellar",
	"morgue": "the room with the chambers, and a sheet",
	"snow": "the open snowfield in the storm, Mathilda's prints filling in",
	"lights": "the headlights at the far end of the field, the engine running",
}

var _pages := {}
var _deciphered := {}
var _places := {}
var _revisits := {}
var _bored := {"hope": [], "doubt": [], "resolve": []}
var _calls := {"hope": [], "doubt": [], "resolve": []}
var _misread: Array = []
var _clips := {}

var _active := false
var _speaker: AudioStreamPlayer3D
# The line playing now, and important lines waiting to be heard whole.
var _current := {}
var _queue: Array = []
# Every line that has been heard (or is being heard), by clip key.
var _spoken := {}
var _heard_pages := {}
var _said_deciphered := {}
var _seen := {}
var _first_seen := {}
var _revisited := {}
var _bored_at := {"hope": 0, "doubt": 0, "resolve": 0}
var _call_at := {"hope": 0, "doubt": 0, "resolve": 0}
var _call_left := -1.0
var _echoed := {}
var _echoes := 0
var _echo: AudioStreamPlayer3D

var _misread_at := -99.0
var _clock := 0.0
var _place_dwell := 0.0
var _last_place := ""
var _returning := false
var _still := 0.0
var _since := 99.0


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


func speaks() -> bool:
	return _active


static func clip_key(text: String, mood: String) -> String:
	return (text + "|" + mood).sha256_text()


static func stage_for(found: int, last: bool) -> String:
	if last or found >= 4:
		return "resolve"
	if found >= 2:
		return "doubt"
	return "hope"


func stage() -> String:
	return Voice.stage_for(Game.notes_found, Game.read_last_page)


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
	_echo = Loudness.voice(Tune.CALL_SPL - Tune.ECHO_DROP_DB, "Dread", true)
	_echo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_echo)


func _on_phase(next: int) -> void:
	if next in [Game.Phase.BOOT, Game.Phase.CAUGHT, Game.Phase.ESCAPED]:
		_interrupt()


func _finished() -> void:
	if not _current.is_empty() and Game.murmur == str(_current.text):
		Game.murmur_left = 0.0
	_current = {}


func _process(delta: float) -> void:
	if not _active or Game.player == null:
		return
	_since += delta
	if _speaker.playing and not _current.is_empty() and Game.murmur == str(_current.text):
		Game.murmur_left = maxf(Game.murmur_left, 0.2)
	# A line without a clip lasts as long as its subtitle.
	if not _current.is_empty() and not _speaker.playing and Game.murmur_left <= 0.0:
		_current = {}
	if Game.awake():
		_clock += delta
		if not _queue.is_empty() and not _busy() and _since >= Tune.VOICE_GAP * 0.5:
			_say(_queue.pop_front())
	if Game.phase != Game.Phase.PLAYING:
		_still = 0.0
		return
	_tick_outdoors(delta)
	_notice(delta)


# Calls for Mathilda (Task 6).
func _tick_outdoors(delta: float) -> void:
	_call_tick(delta, not Game.indoors(Game.player.global_position + Vector3.UP * 0.9))


func _call_tick(delta: float, outdoors: bool) -> void:
	var now := stage()
	if not outdoors or (_calls[now] as Array).is_empty():
		return
	if _call_left < 0.0:
		_call_left = randf_range(Tune.CALL_FIRST.x, Tune.CALL_FIRST.y)
		return
	_call_left -= delta
	if _call_left > 0.0:
		return
	var lines: Array = _calls[now]
	var line: Dictionary = lines[int(_call_at[now]) % lines.size()]
	if not _say(line):
		return
	Game.heard("call")
	_call_left = randf_range(Tune.CALL_EVERY.x, Tune.CALL_EVERY.y)
	if _wants_echo(now):
		_schedule_echo(line)


func _wants_echo(now: String) -> bool:
	return Game.read_pages.has("on the post") and now != "hope" and not _echoed.has(now) and _echoes < Tune.ECHO_MAX


func _schedule_echo(line: Dictionary) -> void:
	var stream := _clip(line)
	if stream == null or Game.trail == null or Game.trail.flora == null:
		return
	var at := Voice.echo_from(Game.player.global_position, Game.trail.flora.tree_positions())
	if at == Vector3.INF:
		return
	_echoed[str(line.stage)] = true
	_echoes += 1
	get_tree().create_timer(randf_range(1.6, 2.4), false).timeout.connect(_play_echo.bind(stream, at))


# Her own call, back from the trees. No subtitle; the page said not to answer.
func _play_echo(stream: AudioStream, at: Vector3) -> void:
	if Game.phase != Game.Phase.PLAYING or Game.indoors(Game.player.global_position + Vector3.UP * 0.9):
		return
	_echo.stream = stream
	_echo.global_position = at
	Loudness.place(_echo, Tune.CALL_SPL - Tune.ECHO_DROP_DB, true)
	_echo.play()
	Game.heard("echo")


static func echo_from(player_at: Vector3, trees: PackedVector3Array) -> Vector3:
	var best := Vector3.INF
	var nearest := INF
	for tree in trees:
		var flat := Vector2(tree.x - player_at.x, tree.z - player_at.z).length()
		if flat >= 25.0 and flat <= 60.0 and flat < nearest:
			nearest = flat
			best = tree + Vector3.UP * 3.0
	return best


func heard_page(entry: NoteEntry, repeat := false) -> void:
	if not _active or entry == null:
		return
	if _heard_pages.has(entry.title) and not repeat:
		return
	var line: Dictionary = _pages.get(entry.title, _line(FALLBACK_PAGE, "steady", "page", entry.title))
	if not _say(line, repeat):
		_enqueue(line)


## Every smudge on the page is solved (Game.decipher).
func deciphered(entry: NoteEntry) -> void:
	if not _active or entry == null or _said_deciphered.has(entry.title):
		return
	var line: Dictionary = _deciphered.get(entry.title, {})
	if line.is_empty():
		return
	if not _say(line):
		_enqueue(line)


## A wrong reading in the journal.
func misread() -> void:
	if not _active or _misread.is_empty() or _clock - _misread_at < Tune.MISREAD_GAP:
		return
	_say(_misread[randi() % _misread.size()])


func _notice(delta: float) -> void:
	var place := Game.place_at(Game.player.global_position)
	if place != _last_place:
		_returning = _seen.has(place)
		_last_place = place
		_place_dwell = 0.0
	else:
		_place_dwell += delta
	var free := _since >= 2.2 and not _busy()
	if not _seen.has(place):
		var wait := 1.2 if place == "bedroom" else 0.45
		if _place_dwell >= wait and free:
			_say(_places.get(place, _line(_stock_place(place), "steady", "place", place)))
		return
	if _returning and _place_dwell >= 0.45 and free and _wants_revisit(place):
		_returning = false
		_say(_revisits[place])
		return
	var speed := Vector2(Game.player.velocity.x, Game.player.velocity.z).length()
	if speed > 0.35:
		_still = 0.0
		return
	_still += delta
	if _still < Tune.BORED_AFTER or _since < Tune.VOICE_GAP or _busy() or Game.murmur_left > 0.4:
		return
	_still = 0.0
	var lines: Array = _bored[stage()]
	var index := int(_bored_at[stage()])
	if index < lines.size():
		_say(lines[index])


func _wants_revisit(place: String) -> bool:
	return _revisits.has(place) and not _revisited.has(place) and stage() != "hope" \
		and _clock - float(_first_seen.get(place, _clock)) >= Tune.REVISIT_AFTER


func _busy() -> bool:
	return not _current.is_empty()


func _say(line: Dictionary, repeat := false) -> bool:
	var text := str(line.get("text", ""))
	if text == "" or _speaker == null:
		return false
	var kind := str(line.get("kind", "bored"))
	var once := kind != "call" and kind != "misread"
	if once and _spoken.has(_key(line)) and not repeat:
		return false
	if _busy():
		var playing := str(_current.get("kind", "bored"))
		var both_misread := kind == "misread" and playing == "misread"
		if int(PRIORITY.get(kind, 1)) <= int(PRIORITY.get(playing, 1)) and not both_misread:
			return false
		_interrupt()
	_spoken[_key(line)] = true
	_mark(line)
	_current = line
	_since = 0.0
	Game.murmur_line(text)
	Loudness.place(_speaker, Tune.CALL_SPL if kind == "call" else Tune.VOICE_SPL)
	_speaker.stop()
	var stream := _clip(line)
	if stream:
		_speaker.stream = stream
		Game.murmur_left = stream.get_length()
		_speaker.play()
	return true


# Cut the playing line off and forget it, as if it never started.
func _interrupt() -> void:
	if _current.is_empty():
		return
	var line := _current
	_current = {}
	_speaker.stop()
	if Game.murmur == str(line.text):
		Game.murmur = ""
		Game.murmur_left = 0.0
	_forget(line)


func _mark(line: Dictionary) -> void:
	var id := str(line.get("id", ""))
	match str(line.kind):
		"page":
			_heard_pages[id] = true
		"deciphered":
			_said_deciphered[id] = true
		"place":
			_seen[id] = true
			if not _first_seen.has(id):
				_first_seen[id] = _clock
		"revisit":
			_revisited[id] = true
		"bored":
			_bored_at[line.stage] = maxi(int(_bored_at[line.stage]), int(line.index) + 1)
		"call":
			_call_at[line.stage] = int(line.index) + 1
		"misread":
			_misread_at = _clock


func _forget(line: Dictionary) -> void:
	_spoken.erase(_key(line))
	var id := str(line.get("id", ""))
	match str(line.kind):
		"page":
			_heard_pages.erase(id)
			_queue.push_front(line)
		"deciphered":
			_said_deciphered.erase(id)
			_queue.push_front(line)
		"place":
			_seen.erase(id)
			_first_seen.erase(id)
		"revisit":
			_revisited.erase(id)
		"bored":
			_bored_at[line.stage] = mini(int(_bored_at[line.stage]), int(line.index))


func _enqueue(line: Dictionary) -> void:
	for waiting in _queue:
		if _key(waiting) == _key(line):
			return
	_queue.push_back(line)


func _key(line: Dictionary) -> String:
	return Voice.clip_key(str(line.get("text", "")), str(line.get("mood", "steady")))


func _clip(line: Dictionary) -> AudioStream:
	var key := _key(line)
	if _clips.has(key):
		return _clips[key]
	var path := CLIPS + key + ".wav"
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream:
		_clips[key] = stream
	return stream


static func _line(text: String, mood: String, kind: String, id: String, stage := "", index := 0) -> Dictionary:
	return {"text": text, "mood": mood, "kind": kind, "id": id, "stage": stage, "index": index}


static func _parse(item: Variant, kind: String, id: String, stage := "", index := 0) -> Dictionary:
	if typeof(item) == TYPE_DICTIONARY:
		var data := item as Dictionary
		return _line(str(data.get("text", "")).strip_edges(), str(data.get("mood", "steady")), kind, id, stage, index)
	return _line(str(item).strip_edges(), "steady", kind, id, stage, index)


static func read_lines() -> Dictionary:
	if not FileAccess.file_exists(LINES):
		push_warning("Voice: no saved lines at " + LINES)
		return {}
	var file := FileAccess.open(LINES, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func _load() -> void:
	var data := Voice.read_lines()
	for pair in [["pages", _pages, "page"], ["deciphered", _deciphered, "deciphered"],
			["places", _places, "place"], ["revisits", _revisits, "revisit"]]:
		var group: Variant = data.get(pair[0], {})
		if typeof(group) == TYPE_DICTIONARY:
			for id in group:
				(pair[1] as Dictionary)[id] = Voice._parse(group[id], pair[2], str(id))
	for pair in [["bored", _bored, "bored"], ["calls", _calls, "call"]]:
		var group: Variant = data.get(pair[0], {})
		# The old format kept one flat list of idle lines.
		if typeof(group) == TYPE_ARRAY:
			group = {"hope": group}
		if typeof(group) != TYPE_DICTIONARY:
			continue
		for stage in STAGES:
			var list: Array = (group as Dictionary).get(stage, [])
			for index in list.size():
				((pair[1] as Dictionary)[stage] as Array).append(Voice._parse(list[index], pair[2], "%s/%d" % [stage, index], stage, index))
	var misread: Variant = data.get("misread", [])
	if typeof(misread) == TYPE_ARRAY:
		for index in (misread as Array).size():
			_misread.append(Voice._parse(misread[index], "misread", str(index)))


func _stock_place(place: String) -> String:
	match place:
		"morgue":
			return "Not here. She can't be down here."
		"snow":
			return "Mathilda's out in this. Somewhere."
		"lights":
			return "Lights. Someone's there."
		"stair":
			return "Down. Of course it goes down."
	return "She's been here. I can feel it."
