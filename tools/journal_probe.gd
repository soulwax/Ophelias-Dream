extends Node

# The journal's data and rules: smudges parse, keys resolve, deciphering
# refuses, accepts and finishes, and reset clears it. Exits 1 on any failure.
#   godot-mono --headless --path . tools/journal_probe.tscn

var _failures := 0
# Set at the end of _turning(): a script error mid-section aborts it silently.
var _turning_ran := false


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
	_render()
	_journal_ui()
	_turning()
	_check(_turning_ran, "the turning checks ran to the end")
	print("JOURNAL ", "FAIL (%d)" % _failures if _failures > 0 else "PASS")
	get_tree().quit(1 if _failures > 0 else 0)


func _catalog() -> void:
	var by_title := {}
	for entry in NoteCatalog.everything():
		by_title[entry.title] = entry
	_check(by_title["by the bed"].body.contains("You said go, so I am going."), "the bed page knows about the argument")
	_check(by_title["the handwriting changes"].body.contains("fix the latch. tell her."), "the fridge list ends with tell her")
	_check(by_title["intake"].body.contains("one coat, buttoned to the throat") and by_title["intake"].body.contains("Cause: exposure."), "the intake lists the coat")
	_check(by_title["intake"].between == "Note: the coat held its shape after the sheet was lifted.", "the coat held its shape")
	_check(by_title[NoteCatalog.LAST_TITLE].body.contains("forgive me for going."), "the last page forgives")
	_check(by_title[NoteCatalog.LAST_TITLE].between.contains("the sheet is the coat."), "the sheet is the coat")
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


func _render() -> void:
	Game.reset()
	var pack := NoteCatalog.find("from the pack")
	var blot := UiChrome.blot(pack.title, 0, 3)
	_check(blot == UiChrome.blot(pack.title, 0, 3) and blot.length() == 3, "a blot is the same every time")
	var text := UiChrome.smudge_text(pack)
	_check(text.contains("[s]") and text.contains(blot), "an unsolved smudge is scratched out")
	_check(not text.contains("{0}") and not text.contains("[url="), "no placeholders and no links in the field")
	_check(UiChrome.smudge_text(pack, true).contains("[url=1]"), "the journal can click a smudge")
	Game.add_to_journal(pack)
	Game.visit("living")
	Game.decipher(pack, 0, "two")
	_check(UiChrome.smudge_text(pack, true).contains("[u]two[/u]") and not UiChrome.smudge_text(pack, true).contains("[url=0]"), "a solved smudge is ink, not a link")
	var reader := NoteReader.new()
	add_child(reader)
	reader.show_entry(pack)
	_check(reader._body.text.contains("[u]two[/u]") and reader._body.visible_characters == 0, "the reader types the page from the start")
	reader._process(60.0)
	_check(reader._body.visible_characters == -1, "the reader finishes typing")
	_check(not reader._body.text.contains(pack.between), "the line between the lines waits for the whole page")
	reader.queue_free()
	Game.reset()


func _journal_ui() -> void:
	Game.reset()
	var journal := Journal.new()
	add_child(journal)
	var post := NoteCatalog.find("on the post")
	Game.add_to_journal(post)
	Game.set_phase(Game.Phase.PLAYING)
	Game.open_journal("on the post")
	_check(journal.visible, "the journal shows in its phase")
	_check(journal._list.get_child_count() == 1, "one page listed")
	_check(journal._blots.get_child_count() == 2, "a focusable button for each unsolved smudge")
	journal._pick(0)
	_check(journal._hint.text.begins_with("I can't make this out yet."), "a locked smudge says so")
	_check(journal._readings.get_child_count() == 0, "a locked smudge offers no readings")
	Game.heard("call")
	journal._pick(0)
	_check(journal._readings.get_child_count() == 3, "an unlocked smudge offers three readings")
	var first := journal._readings.get_child(0) as Button
	_check(first.focus_mode != Control.FOCUS_NONE, "readings can be chosen with a pad")
	journal._choose("my")
	_check(journal.get_viewport().gui_get_focus_owner() != null and journal.get_viewport().gui_get_focus_owner().get_parent() == journal._readings, "focus stays on readings after a wrong choice")
	var struck := 0
	for child in journal._readings.get_children():
		if (child as Button).disabled:
			struck += 1
	_check(struck == 1 and not Game.solved(post, 0), "a wrong reading is struck out")
	journal._choose("your")
	_check(journal.get_viewport().gui_get_focus_owner() != null and journal.get_viewport().gui_get_focus_owner().get_parent() == journal._blots, "focus moves to a remaining blot after solving")
	_check(Game.solved(post, 0) and journal._readings.get_child_count() == 0, "the right reading settles it")
	_check(journal._body.text.contains("[u]your[/u]"), "the page shows the word in ink")
	_check(journal._blots.get_child_count() == 1, "one smudge left")
	Game.heard("echo")
	journal._pick(1)
	journal._choose("answer")
	_check(journal._between.visible and journal._between.text == post.between, "the whole page shows the line between the lines")
	_check(journal.get_viewport().gui_get_focus_owner() != null and journal.get_viewport().gui_get_focus_owner().get_parent() == journal._list, "focus returns to the page list when all blots are solved")
	Game.toggle_pause()
	_check(not journal.visible and Game.phase == Game.Phase.PLAYING, "Esc closes it")
	journal.queue_free()
	Game.reset()


func _turning() -> void:
	Game.reset()
	var turns := [0]
	Game.turned.connect(func() -> void: turns[0] += 1)
	Game.turn_around()
	_check(not Game.turned_around, "no turning around before the last page")
	var actor := Player.new()
	add_child(actor)
	Game.player = actor
	Game.set_phase(Game.Phase.PLAYING)
	actor.glance = 1.0
	Game._watch_turn(2.0)
	_check(not Game.turned_around, "glancing back before the last page changes nothing")
	Game.read_last_page = true
	actor.glance = 0.5
	Game._watch_turn(2.0)
	_check(not Game.turned_around, "a half glance is not turning around")
	actor.glance = 1.0
	Game._watch_turn(0.6)
	_check(not Game.turned_around, "a quick look is not turning around")
	Game._watch_turn(0.6)
	_check(Game.turned_around and turns[0] == 1, "holding the look back for a second turns her around")
	Game.turn_around()
	_check(turns[0] == 1, "she turns around once")
	var card := EndCard.new()
	add_child(card)
	card._on_phase(Game.Phase.ESCAPED)
	_check(card._title.text == "One set of prints", "turning around ends on one set of prints")
	Game.turned_around = false
	card._on_phase(Game.Phase.ESCAPED)
	_check(card._title.text == "The road", "not turning around ends on the road")
	card.queue_free()
	actor.queue_free()
	Game.reset()
	_check(not Game.turned_around and Game._turn_hold == 0.0, "reset forgets the turn")
	_turning_ran = true
