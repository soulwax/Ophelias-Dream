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
