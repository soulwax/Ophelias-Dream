extends Node

# The journal's data and rules: smudges parse, keys resolve, deciphering
# refuses, accepts and finishes, and reset clears it. Exits 1 on any failure.
#   godot-mono --headless --path . tools/journal_probe.tscn

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		_failures += 1
		print("FAIL ", what)


func _run() -> void:
	_catalog()
	_knowledge()
	_phases()
	print("JOURNAL ", "FAIL (%d)" % _failures if _failures > 0 else "PASS")
	get_tree().quit(1 if _failures > 0 else 0)


func _catalog() -> void:
	var trail := NoteCatalog.all()
	_check(trail.size() == 5, "five trail pages")
	_check(trail[4].title == NoteCatalog.LAST_TITLE, "the last trail page is LAST_TITLE")
	var every := NoteCatalog.everything()
	_check(every.size() == 7, "seven pages in all")
	var titles := {}
	for entry in every:
		titles[entry.title] = true
	for entry in every:
		_check(entry.smudges.size() == 2, "%s has two smudges" % entry.title)
		_check(entry.between != "", "%s has a line between the lines" % entry.title)
		_check(entry.body.contains("{0}") and entry.body.contains("{1}"), "%s marks both smudges" % entry.title)
		_check(entry.body.count("{") == 2, "%s has no stray braces" % entry.title)
		for smudge in entry.smudges:
			var readings: Array = smudge.readings
			_check(readings.size() == 3, "%s smudge has three readings" % entry.title)
			var key := str(smudge.key)
			var kind := key.get_slice(":", 0)
			var what := key.substr(key.find(":") + 1)
			var real := (kind == "page" and titles.has(what)) \
				or (kind == "place" and Voice.PLACES.has(what)) \
				or (kind == "event" and NoteCatalog.EVENTS.has(what))
			_check(real, "%s key %s names something real" % [entry.title, key])
	_check(NoteCatalog.find("intake") != null and NoteCatalog.find("intake").title == "intake", "find by title")
	_check(NoteCatalog.find("nothing") == null, "find returns null for an unknown title")
	_check(not NoteCatalog.bedside().counts and not NoteCatalog.intake().counts, "house pages do not count")
	for entry in every:
		_check(not entry.body.contains("Mara") and not entry.body.contains("Listener"), "%s has none of the old story" % entry.title)


func _knowledge() -> void:
	Game.reset()
	var post := NoteCatalog.find("on the post")
	var pack := NoteCatalog.find("from the pack")
	Game.add_to_journal(pack)
	Game.add_to_journal(pack)
	_check(Game.journal.size() == 1, "a page read twice is kept once")
	_check(Game.known("page:from the pack"), "a read page is a known key")
	_check(not Game.known("place:living"), "an unvisited place is not known")
	_check(Game.decipher(pack, 0, "two") == Game.Reading.LOCKED, "a smudge with an unknown key refuses")
	Game.visit("living")
	_check(Game.decipher(pack, 0, "one") == Game.Reading.WRONG, "a wrong reading is wrong")
	_check(not Game.solved(pack, 0), "a wrong reading solves nothing")
	_check(Game.decipher(pack, 0, "two") == Game.Reading.RIGHT, "the right reading solves it")
	_check(Game.solved(pack, 0) and not Game.page_solved(pack), "one of two smudges solved")
	# A key from a page read later unlocks an earlier page's smudge.
	_check(Game.decipher(pack, 1, "posts") == Game.Reading.LOCKED, "posts waits for the post")
	var finished: Array[String] = []
	Game.page_deciphered.connect(func(entry: NoteEntry) -> void: finished.append(entry.title))
	Game.add_to_journal(post)
	_check(Game.decipher(pack, 1, "posts") == Game.Reading.RIGHT, "reading the post unlocks posts")
	_check(Game.page_solved(pack) and finished.size() == 1 and finished[0] == "from the pack", "solving the last smudge finishes the page once")
	_check(Game.decipher(pack, 1, "posts") == Game.Reading.RIGHT and finished.size() == 1, "solving again does not finish twice")
	# Voice off: calls and echoes never happen, so the fallbacks must hold.
	_check(Game.voice == null, "no voice in this probe")
	_check(not Game.known("event:call"), "no call before the snow")
	Game.visit("snow")
	_check(Game.known("event:call"), "with her silent, the snow stands in for the call")
	_check(not Game.known("event:echo"), "no echo before the last page")
	Game.add_to_journal(NoteCatalog.find(NoteCatalog.LAST_TITLE))
	_check(Game.known("event:echo"), "the last page stands in for the echo")
	Game.heard("echo")
	_check(Game.heard_events.has("echo"), "heard records an event")
	# With every key known, every page can be finished.
	for entry in NoteCatalog.everything():
		Game.add_to_journal(entry)
	for place in Voice.PLACES:
		Game.visit(place)
	Game.heard("call")
	for entry in NoteCatalog.everything():
		for index in entry.smudges.size():
			Game.decipher(entry, index, str((entry.smudges[index].readings as Array)[0]))
	_check(Game.all_deciphered(), "every page can be finished")
	_check(Game.place_at(Vector3.ZERO) == "snow", "outside the house and far from the lights is the snow")
	Game.reset()
	_check(Game.journal.is_empty() and Game.read_pages.is_empty() and Game.visited.is_empty() \
		and Game.heard_events.is_empty() and Game.deciphered.is_empty(), "reset clears what she knows")


func _phases() -> void:
	Game.reset()
	Game.set_phase(Game.Phase.INTRO)
	Game.open_journal()
	_check(Game.phase == Game.Phase.INTRO, "the journal does not open during the intro")
	Game.set_phase(Game.Phase.PLAYING)
	Game.open_journal("intake")
	_check(Game.phase == Game.Phase.JOURNAL and Game.journal_focus == "intake", "the journal opens from play, on a page")
	_check(Game.locks_movement() and Game.locks_look(), "the journal holds her still")
	_check(Game.awake(), "the world goes on in the journal")
	Game.toggle_pause()
	_check(Game.phase == Game.Phase.PLAYING, "Esc closes the journal instead of pausing")
	Game.open_journal()
	Game.close_journal()
	_check(Game.phase == Game.Phase.PLAYING, "close_journal returns to play")
	_check(InputMap.has_action("journal") and not InputMap.action_get_events("journal").is_empty(), "journal is bound")
	var listed := false
	for pair in Settings.ACTIONS:
		listed = listed or pair[0] == "journal"
	_check(listed, "journal is rebindable")
	Game.reset()
