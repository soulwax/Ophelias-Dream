extends Node

# Her lines: every line loads with a mood (and, with PROBE_CLIPS=1, has its
# baked clip); stages; priorities; an interrupted line is forgotten as if it
# never played. Exits 1 on any failure.
#   godot-mono --headless --path . tools/voice_probe.tscn

var _failures := 0
var voice: Voice


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		_failures += 1
		print("FAIL ", what)


func _run() -> void:
	Game.reset()
	var actor := Player.new()
	get_tree().root.add_child(actor)
	Game.player = actor
	voice = Voice.new()
	get_tree().root.add_child(voice)
	voice._active = true
	voice._load()
	voice._build_speaker()
	_lines()
	_stages()
	_interruption()
	_extra()
	_calls()
	print("VOICE ", "FAIL (%d)" % _failures if _failures > 0 else "PASS")
	get_tree().quit(1 if _failures > 0 else 0)


func _all_lines() -> Array:
	var found: Array = voice._pages.values() + voice._deciphered.values() + voice._places.values() + voice._revisits.values() + voice._misread
	for stage in Voice.STAGES:
		found += voice._bored[stage]
		found += voice._calls[stage]
	return found


func _lines() -> void:
	_check(voice._pages.size() == 7 and voice._deciphered.size() == 7, "seven page and seven deciphered lines")
	_check(voice._places.size() == 11 and voice._revisits.size() == 5, "eleven places, five revisits")
	for stage in Voice.STAGES:
		_check(voice._bored[stage].size() == 6, "six idle lines for " + stage)
		_check(voice._calls[stage].size() == 3, "three calls for " + stage)
	_check(voice._misread.size() == 5, "five misreads")
	var every := _all_lines()
	_check(every.size() == 62, "62 lines in all (%d)" % every.size())
	for line in every:
		_check(Voice.MOODS.has(str(line.mood)) and str(line.text) != "", "a mood for: " + str(line.text))
	for entry in NoteCatalog.everything():
		_check(voice._pages.has(entry.title) and voice._deciphered.has(entry.title), "lines for " + entry.title)
	for place in voice._places:
		_check(Voice.PLACES.has(place), "a known place: " + str(place))
	_check(Voice.clip_key("a", "b") == "a|b".sha256_text(), "clip key is sha256 of text|mood")
	var old: Dictionary = Voice._parse("plain words", "bored", "x")
	_check(old.text == "plain words" and old.mood == "steady", "a plain string loads as steady")
	if OS.get_environment("PROBE_CLIPS") == "1":
		for line in every:
			var path := Voice.CLIPS + voice._key(line) + ".wav"
			var clip := load(path) as AudioStream if ResourceLoader.exists(path) else null
			_check(clip != null and clip.get_length() > 0.0, "clip for: " + str(line.text))
	for line in every:
		_check(not str(line.text).contains("Mara"), "none of the old story: " + str(line.text))


func _stages() -> void:
	_check(Voice.stage_for(0, false) == "hope" and Voice.stage_for(1, false) == "hope", "hope at 0-1 pages")
	_check(Voice.stage_for(2, false) == "doubt" and Voice.stage_for(3, false) == "doubt", "doubt at 2-3")
	_check(Voice.stage_for(4, false) == "resolve" and Voice.stage_for(1, true) == "resolve", "resolve at 4, or after the last page")


func _interruption() -> void:
	var bored: Dictionary = voice._bored["hope"][0]
	_check(voice._say(bored), "an idle line plays")
	_check(Game.murmur == bored.text and voice._bored_at["hope"] == 1, "its subtitle shows and the idle list moves on")
	var bed := NoteCatalog.bedside()
	voice.heard_page(bed)
	_check(Game.murmur == voice._pages[bed.title].text, "a page reaction cuts it off")
	_check(not voice._spoken.has(voice._key(bored)) and voice._bored_at["hope"] == 0, "the cut line is forgotten, as if never played")
	_check(not voice._say(bored), "a lower line waits while a page plays")
	_check(not voice._say(voice._places["hall"]), "a place line waits while a page plays")
	var pack := NoteCatalog.find("from the pack")
	voice.heard_page(pack)
	_check(Game.murmur == voice._pages[bed.title].text and voice._queue.size() == 1, "a second page waits its turn")
	voice._finished()
	Game.set_phase(Game.Phase.PLAYING)
	voice._since = 99.0
	voice._process(0.1)
	_check(Game.murmur == voice._pages[pack.title].text, "the waiting page plays whole after the first")
	voice._finished()
	_check(voice._say(bored), "the forgotten idle line plays again, whole")
	voice._finished()
	# A first visit cut off is a place not yet seen.
	voice._say(voice._places["hall"])
	_check(voice._seen.has("hall"), "a place line marks the place seen")
	voice.deciphered(pack)
	_check(not voice._seen.has("hall"), "a deciphered line cuts it off and the place is unseen again")
	voice._finished()
	# An ending forgets the line it cut off.
	var later: Dictionary = voice._bored["hope"][1]
	voice._say(later)
	voice._on_phase(Game.Phase.CAUGHT)
	_check(not voice._spoken.has(voice._key(later)) and Game.murmur == "", "a line cut by the ending is not heard")
	Game.set_phase(Game.Phase.PLAYING)


func _extra() -> void:
	voice._current = {}
	voice._clock = 100.0
	voice.misread()
	_check(str(voice._current.get("kind", "")) == "misread", "a wrong reading mutters")
	var first := str(voice._current.text)
	voice.misread()
	_check(str(voice._current.text) == first, "misreads wait MISREAD_GAP")
	voice._clock += Tune.MISREAD_GAP + 0.1
	voice.misread()
	_check(str(voice._current.get("kind", "")) == "misread" and voice._misread_at == voice._clock, "a misread may cut off a misread")
	voice._finished()
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "Effects", "Voice bus under Effects")


func _calls() -> void:
	voice._current = {}
	Game.murmur = ""
	voice._call_left = 0.01
	voice._call_tick(1.0, false)
	_check(Game.murmur == "", "no calls indoors")
	voice._call_tick(1.0, true)
	var hope_calls: Array = voice._calls["hope"].map(func(line: Dictionary) -> String: return str(line.text))
	_check(hope_calls.has(Game.murmur), "a call outdoors, from the hope stage")
	_check(Game.heard_events.has("call"), "a call is a heard event")
	_check(voice._call_left >= Tune.CALL_EVERY.x, "the next call waits CALL_EVERY")
	voice._finished()
	voice.heard_page(NoteCatalog.find("torn page"), true)
	voice._call_left = 0.01
	voice._call_tick(1.0, true)
	_check(str(voice._current.kind) == "page", "a call never cuts off a page")
	voice._finished()
	_check(not voice._wants_echo("doubt"), "no echo before the post")
	Game.read_pages["on the post"] = true
	_check(not voice._wants_echo("hope"), "no echo while still hoping")
	_check(voice._wants_echo("doubt"), "an echo in doubt, after the post")
	voice._echoed["doubt"] = true
	_check(not voice._wants_echo("doubt"), "one echo per stage")
	voice._echoes = Tune.ECHO_MAX
	_check(not voice._wants_echo("resolve"), "at most ECHO_MAX echoes")
	var trees := PackedVector3Array([Vector3(10, 0, 0), Vector3(0, 0, 40), Vector3(70, 0, 0)])
	_check(Voice.echo_from(Vector3.ZERO, trees) == Vector3(0, 3, 40), "the echo comes from the nearest pine 25-60 m off")
	_check(Voice.echo_from(Vector3.ZERO, PackedVector3Array([Vector3(5, 0, 0)])) == Vector3.INF, "no pine in range, no echo")
