extends Node

# Her lines: every line loads with a mood (and, with PROBE_CLIPS=1, has its
# baked clip); stages; priorities; an interrupted line is forgotten as if it
# never played. Exits 1 on any failure.
#   godot-mono --headless --path . tools/voice_probe.tscn

var _failures := 0
var voice: Voice
# Set at the end of _answers(): a script error mid-section aborts it silently.
var _answers_ran := false


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
	_moments()
	_answers()
	_check(_answers_ran, "the answer checks ran to the end")
	print("VOICE ", "FAIL (%d)" % _failures if _failures > 0 else "PASS")
	get_tree().quit(1 if _failures > 0 else 0)


func _all_lines() -> Array:
	var found: Array = voice._pages.values() + voice._deciphered.values() + voice._places.values() \
		+ voice._revisits.values() + voice._misread + voice._spent + voice._cold + voice._falls \
		+ voice._endings.values() + voice._answers.values() + [voice._turned]
	for stage in voice._bored:
		found += voice._bored[stage]
	for stage in Voice.STAGES:
		found += voice._memories[stage]
		found += voice._calls[stage]
	return found


func _lines() -> void:
	_check(voice._pages.size() == 7 and voice._deciphered.size() == 7, "seven page and seven deciphered lines")
	_check(voice._places.size() == 13 and voice._revisits.size() == 13, "thirteen places, thirteen revisits")
	for stage in Voice.STAGES:
		_check(voice._bored[stage].size() == 10, "ten idle lines for " + stage)
		_check(voice._memories[stage].size() == 5, "five memories for " + stage)
		_check(voice._calls[stage].size() == 5, "five calls for " + stage)
	_check(voice._bored[Voice.AFTER].size() == 6, "six idle lines after turning around")
	_check(voice._misread.size() == 10 and voice._spent.size() == 8 and voice._cold.size() == 6 and voice._falls.size() == 5, "misreads, breath, cold, falls")
	_check(not voice._turned.is_empty() and voice._endings.size() == 2 and voice._answers.size() == 3, "turning, endings, answers")
	var every := _all_lines()
	_check(every.size() == 141, "141 lines in all (%d)" % every.size())
	for line in every:
		_check(Voice.MOODS.has(str(line.mood)) and str(line.text) != "", "a mood for: " + str(line.text))
	for entry in NoteCatalog.everything():
		_check(voice._pages.has(entry.title) and voice._deciphered.has(entry.title), "lines for " + entry.title)
	for place in voice._places:
		_check(Voice.PLACES.has(place) and voice._revisits.has(place), "a known place with a revisit: " + str(place))
	_check(Voice.clip_key("a", "b") == "a|b".sha256_text(), "clip key is sha256 of text|mood")
	var old: Dictionary = Voice._parse("plain words", "bored", "x")
	_check(old.text == "plain words" and old.mood == "steady", "a plain string loads as steady")
	if OS.get_environment("PROBE_CLIPS") == "1":
		for line in every:
			var path := Voice.CLIPS + voice._key(line) + ".wav"
			var clip := load(path) as AudioStream if ResourceLoader.exists(path) else null
			_check(clip != null and clip.get_length() > 0.0, "clip for: " + str(line.text))


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
	voice._current = {}
	voice._spoken.erase(voice._key(voice._places["snow"]))
	voice._seen.erase("snow")
	voice._last_place = "snow"
	voice._place_dwell = 1.0
	voice._say(voice._bored["hope"][2])
	voice._notice(0.1)
	_check(str(voice._current.get("kind", "")) == "place", "entering a place interrupts lower-priority speech")
	voice._finished()


func _calls() -> void:
	voice._current = {}
	Game.murmur = ""
	voice._call_left = 0.01
	voice._call_tick(1.0, false)
	_check(Game.murmur == "", "no calls indoors")
	voice._call_tick(1.0, true)
	var hope_calls: Array = voice._calls["hope"].map(func(line: Dictionary) -> String: return str(line.text))
	_check(hope_calls.has(Game.murmur), "a call outdoors, from the hope stage")
	_check(not Game.heard_events.has("call"), "a call is not heard until it finishes")
	_check(voice._call_left >= Tune.CALL_EVERY.x, "the next call waits CALL_EVERY")
	voice._finished()
	_check(Game.heard_events.has("call"), "a completed call is a heard event")
	Game.heard_events.erase("call")
	voice.heard_page(NoteCatalog.find("torn page"), true)
	voice._call_left = 0.01
	voice._call_tick(1.0, true)
	_check(str(voice._current.kind) == "page", "a call never cuts off a page")
	voice._finished()
	voice._call_left = 0.01
	voice._call_tick(1.0, true)
	voice.heard_page(NoteCatalog.find("by the bed"), true)
	_check(not Game.heard_events.has("call"), "an interrupted call leaves no heard event")
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
	voice._pending_echo_stage = "doubt"
	Game.set_phase(Game.Phase.READING)
	voice._play_echo(AudioStreamWAV.new(), Vector3.ZERO, voice._echo_ticket, "doubt")
	_check(voice._pending_echo_stage == "" and voice._echoes == Tune.ECHO_MAX, "a cancelled echo releases its pending stage without spending another echo")


func _moments() -> void:
	Game.read_pages.clear()
	Game.turned_around = false
	Game.set_phase(Game.Phase.PLAYING)
	voice._finished()
	voice._current = {}
	voice._since = 99.0
	voice._memory_tick(false, 1.5)
	_check(voice._current.is_empty(), "no memories indoors")
	voice._memory_tick(true, 0.4)
	_check(voice._current.is_empty(), "no memories standing still")
	voice._memory_tick(true, 1.5)
	_check(str(voice._current.get("kind", "")) == "memory" and voice._memory_at["hope"] == 1, "a memory while walking the field")
	voice._finished()
	voice._since = 0.0
	voice._memory_tick(true, 1.5)
	_check(voice._current.is_empty(), "memories wait MEMORY_GAP")
	voice._clock = 1000.0
	voice._say(voice._bored["hope"][3])
	voice.fell(9.0)
	_check(str(voice._current.get("kind", "")) == "fall", "a fall cuts off idle talk")
	voice._finished()
	voice.fell(9.0)
	_check(voice._current.is_empty(), "falls wait FALL_GAP")
	voice.out_of_breath()
	_check(str(voice._current.get("kind", "")) == "spent", "out of breath")
	voice._finished()
	voice.out_of_breath()
	_check(voice._current.is_empty(), "breath lines wait SPENT_GAP")
	Game.weather = null
	voice._outdoor_time = Tune.COLD_AFTER + 1.0
	voice._cold_tick(true)
	_check(voice._current.is_empty(), "no cold lines without weather")
	var weather := Weather.new()
	weather.whiteout = 0.9
	Game.weather = weather
	voice._cold_tick(false)
	_check(voice._current.is_empty(), "no cold lines indoors")
	voice._cold_tick(true)
	_check(str(voice._current.get("kind", "")) == "cold", "the cold gets to her in a whiteout")
	voice._finished()
	voice._cold_tick(true)
	_check(voice._current.is_empty(), "the cold waits COLD_GAP")
	Game.weather = null
	weather.free()
	Game.turned_around = true
	_check(voice.stage() == Voice.AFTER, "after turning around she is in the after stage")
	Game.read_pages["on the post"] = true
	voice._echoed.clear()
	voice._echoes = 0
	_check(not voice._wants_echo("resolve"), "nothing answers after she turns around")
	voice._call_left = 0.01
	voice._call_tick(1.0, true)
	_check(voice._current.is_empty(), "she stops calling after she turns around")
	voice.turned()
	_check(str(voice._current.get("kind", "")) == "turned", "she says she turned around")
	voice._finished()
	Game.turned_around = false


func _answers() -> void:
	Game.player.global_position = Vector3.ZERO
	_check(voice._behind(1.4).is_equal_approx(Vector3(0, 1.55, 1.4)), "behind her is opposite the way she faces")
	Game.set_phase(Game.Phase.ESCAPED)
	voice._speak_ending(voice._ending_ticket)
	_check(str(voice._current.get("id", "")) == "road", "the road ending is spoken over the card")
	voice._finished()
	voice._answer_road(voice._ending_ticket)
	_check(Game.murmur == "…" + str(voice._answers["road"].text), "and something answers okay")
	var stale: int = voice._ending_ticket
	voice._on_phase(Game.Phase.BOOT)
	Game.murmur = ""
	voice._answer_road(stale)
	_check(Game.murmur == "", "a restart cancels a pending answer")
	Game.turned_around = true
	Game.set_phase(Game.Phase.ESCAPED)
	voice._speak_ending(voice._ending_ticket)
	_check(str(voice._current.get("id", "")) == "prints", "the prints ending has its own line")
	voice._finished()
	Game.turned_around = false
	Game.set_phase(Game.Phase.PLAYING)
	_answers_ran = true
	_review_fixes()


# Fixes from the final review: each failed before its fix.
func _review_fixes() -> void:
	_check(Hud.murmur_shown(Game.Phase.ESCAPED), "her words over the end card have subtitles")
	_check(not Hud.murmur_shown(Game.Phase.PAUSED), "no subtitles while paused")
	Game.read_last_page = true
	Game.set_phase(Game.Phase.PLAYING)
	voice._finished()
	voice._say(voice._pages["by the bed"], true)
	voice.turned()
	var queued := voice._queue.any(func(line: Dictionary) -> bool: return str(line.kind) == "turned")
	_check(queued, "turning around during a page reaction still gets said, after it")
	voice._queue.clear()
	voice._finished()
	var stream := voice._clip(voice._answers["road"])
	if stream == null:
		stream = AudioStreamWAV.new()
	Game.turned_around = false
	Game.set_phase(Game.Phase.ESCAPED)
	voice._answer_road(voice._ending_ticket)
	voice._process(0.016)
	_check(voice._echo.stream == stream and not voice._echo_stopped_early, "the road answer is not cut off on the next frame")
	Game.set_phase(Game.Phase.PLAYING)
	Game.player.global_position = Vector3.ZERO
	voice._play_echo(stream, Vector3.ZERO, voice._echo_ticket, "resolve", voice._answers["resolve"], true)
	Game.player.global_position = Vector3(6, 0, 0)
	voice._process(0.016)
	_check(voice._echo.global_position.is_equal_approx(voice._behind(1.4)), "the close answer follows her")
	Game.read_last_page = false
