# Looking for Mathilda Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the old story with the search for Mathilda. The HUD objective gives way to a journal where smudged words on the pages are deciphered. Her 62 acted lines are baked on the GPU with Qwen3-TTS; they speak by stage and priority, and an interrupted line leaves no trace.

**Architecture:**
- **Pages:** `NoteCatalog` holds the new pages; `{word}` in a body becomes a smudge with readings and a key.
- **Knowledge state:** `Game` owns pages read, places visited, events heard and deciphered smudges, plus a new `JOURNAL` phase.
- **UI:** a shared BBCode renderer in `UiChrome` draws smudges for both `NoteReader` and the new `Journal`. `Hud` drops the objective and pips for an "Added to the journal" notice.
- **Voice:** `Voice` is rewritten around line dictionaries (text, mood, kind) with priorities, a "forget on interrupt" rule, stages, revisits, calls and an echo.
- **Baking:** `tools/bake_speech.py` bakes with Qwen3-TTS VoiceDesign on CUDA and picks takes with Whisper WER and ECAPA speaker similarity.

**Tech Stack:** Godot 4.7.2 (`godot-mono` on this machine), GDScript; Python 3.12 (uv venv) with CUDA torch, `qwen-tts`, `faster-whisper`, `speechbrain`, `soundfile`.

**Spec:** `docs/superpowers/specs/2026-10-06-mathilda-story-design.md`

## Global Constraints

- **GDScript style:** tabs, static typing (`:=`, typed returns), `class_name` on every script, referenced by name, not preload. After adding a new `class_name` script, run `godot-mono --headless --path . --import` before any headless run.
- **Build in code.** The only `.tscn` files added are probe harnesses in `tools/`.
- **Probes:** scripts using the `Game` autoload are tested with `tools/*_probe.tscn` scene probes whose root `extends Node`. Every probe counts failures, prints `PASS`/`FAIL` lines, and calls `get_tree().quit(1)` on any failure. Never use bare `assert()`.
- **Balance values** live in `Tune`. New constants:
  - `CALL_SPL := 82.0`, `CALL_FIRST := Vector2(20.0, 30.0)`, `CALL_EVERY := Vector2(45.0, 80.0)`
  - `ECHO_DROP_DB := 14.0`, `ECHO_MAX := 2`
  - `REVISIT_AFTER := 60.0`, `MISREAD_GAP := 8.0`, `JOURNAL_TOAST := 3.0`, `LIGHTS_NEAR := 40.0`
- **Clip names:** SHA-256 hex of `text + "|" + mood` (UTF-8) + `.wav`, identical in GDScript (`String.sha256_text()`) and Python (`hashlib.sha256`).
- **Moods:** exactly `steady`, `warm`, `hushed`, `shaken`, `breaking`, `resolve`, `calling`.
- **Stages:** `notes_found` 0–1 is `hope`, 2–3 is `doubt`, 4+ or `read_last_page` is `resolve`.
- **Priorities:** page and deciphered 3; place and revisit 2; bored, call and misread 1. Only a strictly higher priority interrupts, except a misread may interrupt a misread.
- **No objective text** anywhere on the HUD. The relationship with Mathilda is never named in any text.
- **The game never runs a model.** Models, venvs and caches stay under ignored `build/voice/`.
- **Commits:** each task stages only the files it lists. `scripts/tune.gd`, `CLAUDE.md` and `AGENTS.md` already carry unrelated uncommitted work (the running leap). Unless the user has committed that work first, leave those three files unstaged and list them in the final report. Commit messages are one plain descriptive sentence, with no `Co-Authored-By` or other attribution line.
- **Two deliberate deviations from the spec:**
  - The pad button for the journal is **Y**, because Back is already restart.
  - Calls play through her one speaker, re-levelled to `CALL_SPL` per line, rather than a second player, so interruption stays uniform.

## Review Focus

1. **Voice off.** `RUN_VOICE=0`, capture and headless runs keep `Voice` inactive, so no calls and no echo. Expect every journal page to still be solvable: `event:call` falls back to having visited the snow, and `event:echo` to having read the last page. Pinned in Task 2.
2. **Pages read twice or out of order.** Re-reading a page must not duplicate it in the journal or change `notes_found` twice, and a key from a page read later must unlock an earlier page's smudge. Pinned in Task 2.
3. **Two important lines in a row.** Reading two pages quickly must play both reactions whole, the second after the first, and never drop one. Pinned in Task 5 (the queue).
4. **A line cut off by an ending.** It must not count as heard after a restart or within the run. Pinned in Task 5 (`_on_phase(CAUGHT)`).
5. **Pad and keyboard in the journal.** With no mouse, every smudge must be reachable as a focusable button and every reading pickable. Pinned in Task 4 (blot buttons exist per unsolved smudge, reading buttons are focusable and not `FOCUS_NONE`).

---

### Task 1: Pages and smudges

**Files:**
- Modify: `scripts/notes/note_entry.gd`
- Modify: `scripts/notes/note_catalog.gd` (full rewrite)
- Create: `tools/journal_probe.gd`, `tools/journal_probe.tscn`

**Interfaces:**
- Produces:
  - `NoteEntry.smudges: Array[Dictionary]`, each `{"readings": Array (String, the right one first), "key": String}`
  - `NoteEntry.between: String`
  - `NoteEntry.body` holds `{0}`, `{1}`, … where the smudges sit
  - `NoteCatalog.LAST_TITLE == "don't turn around"`, `NoteCatalog.EVENTS == ["call", "echo"]`
  - `NoteCatalog.all() -> Array[NoteEntry]` (5 trail pages, route order), `NoteCatalog.everything() -> Array[NoteEntry]` (all 7), `NoteCatalog.find(title: String) -> NoteEntry` (null if absent)
- Consumes: `Voice.PLACES` keys (unchanged): bedroom, hall, living, backhall, stair, landing, corridor, janitor, morgue, snow, lights.

- [ ] **Step 1: Write the failing probe**

`tools/journal_probe.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/journal_probe.gd" id="1"]

[node name="JournalProbe" type="Node"]
script = ExtResource("1")
```

`tools/journal_probe.gd`:

```gdscript
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: a parse error on `smudges` / `everything` / `between`, or FAIL lines, and exit code 1.

- [ ] **Step 3: Add the fields to `NoteEntry`**

Append to `scripts/notes/note_entry.gd`:

```gdscript
# Smudged words in body order: {"readings": [right, wrong, wrong], "key":
# "page:<title>" | "place:<place>" | "event:<call|echo>"}. The body holds
# {0}, {1}, ... where they sit (NoteCatalog._make).
@export var smudges: Array[Dictionary] = []
# The sentence between the lines, legible once every smudge is solved.
@export var between: String = ""
```

- [ ] **Step 4: Rewrite `scripts/notes/note_catalog.gd`**

```gdscript
class_name NoteCatalog
extends RefCounted

# Mathilda's pages: five on the trail in route order, then the two in the
# house. {word} marks a smudge that stays blotted until it is deciphered in
# the journal. Each smudge lists its readings (the right one first) and the
# key that makes it legible: page:<title> read, place:<Voice place> visited,
# or event:<call|echo> heard. Lowercase text is the hand going wrong.
# Story: docs/superpowers/specs/2026-10-06-mathilda-story-design.md

# The page that asks her to stop looking. The road remembers it.
const LAST_TITLE := "don't turn around"
const EVENTS := ["call", "echo"]


static func all() -> Array[NoteEntry]:
	var notes: Array[NoteEntry] = [
		_make(
			"from the pack",
			"Packed for {two}: two cups, one candle (we share), the map. Lookout circled. That is where the road comes up. If the storm closes, go there. Someone always comes up the road.\n\nLeft the pack here. Too heavy to run with. You will know it is mine. Follow the {posts}, not the prints. The prints lie in this wind.",
			0.0,
			[[["two", "one", "three"], "place:living"], [["posts", "lights", "trees"], "page:on the post"]],
			"If you find this pack with one cup in it, do not count them again."
		),
		_make(
			"on the post",
			"It is the same afternoon it was. The light has not moved since I left the cabin.\n\nI called your name until I could not hear it over the wind. Then I heard it again, from the trees, in {your} voice.\n\nI did not answer it. If you hear me from the trees, do not {answer} either.",
			0.10,
			[[["your", "my", "her"], "event:call"], [["answer", "follow", "listen"], "event:echo"]],
			"It called me by your name."
		),
		_make(
			"torn page",
			"—your prints from the step. I followed them as far as the pines. They do not go on and they do not come back. They stop, both feet {together}, as if you stood there and the snow decided you had never been here.\n\ni stood in them. they {fit} me.\n\nI am going on to the lights. If you are behind me, you will find this. If I am behind you, I already did.",
			0.28,
			[[["together", "bare", "apart"], "place:snow"], [["fit", "followed", "knew"], "page:the handwriting changes"]],
			"The prints were smaller than mine. Then they were not."
		),
		_make(
			"the handwriting changes",
			"I keep writing to you because writing is the only thing that stays where I put it. The snow does not. The prints do not. the cabin does not. i have passed it twice and it was lit both times and i never went back in.\n\nmy letters are going wrong. they lean the way {yours} lean. i know your hand better than mine. i read every list you ever left me. this is your hand now and i am still writing.\n\nif you are reading this, which of us is holding the {pen}.",
			0.48,
			[[["yours", "mine", "hers"], "page:by the bed"], [["pen", "lantern", "sheet"], "page:intake"]],
			"hold this next to the page by the bed. same hand. it was always the same hand."
		),
		_make(
			LAST_TITLE,
			"stop looking for me.\n\ngo to the lights. the engine has been running since before the snow. someone kept it warm for {one} of us. i will be there or i will not, but you will.\n\ni am right {behind} you. i always was. do not turn around until you reach the road.\n\n— m",
			0.72,
			[[["one", "both", "neither"], "place:lights"], [["behind", "beside", "ahead of"], "page:on the post"]],
			"the sheet in the cellar is not me. say it back to me. the sheet is not me."
		),
	]
	return notes


## Every page: the trail's, then the bed's and the intake.
static func everything() -> Array[NoteEntry]:
	var pages := all()
	pages.append(bedside())
	pages.append(intake())
	return pages


static func find(title: String) -> NoteEntry:
	for entry in everything():
		if entry.title == title:
			return entry
	return null


## Left on the nightstand, in Mathilda's hand.
static func bedside() -> NoteEntry:
	var entry := _make(
		"by the bed",
		"I lit the lantern so you would see it from the field. Leave it burning.\n\nIf you are reading this, you came back and {I} did not. Stay in. I mean it this time. Do not do what you always do, which is come after me.\n\nPut your coat on before you argue with me.\n\n— {M.}",
		0.10,
		[[["I", "you", "we"], "page:torn page"], [["M.", "Mum", "Me"], "page:from the pack"]],
		"I left the door unlatched so you could get back in. Or so I could."
	)
	entry.counts = false
	return entry


## On the mortuary desk. It could be either of them.
static func intake() -> NoteEntry:
	var entry := _make(
		"intake",
		"Brought in from the step during the storm. Length under the sheet: 1.6 m. Strap stamped M. Aune. Given name, as copied: {M—}. Personal effects: one cup. Next of kin: {out searching}. Not yet notified.",
		0.06,
		[[["M—", "Mathilda", "nobody"], "page:from the pack"], [["out searching", "notified", "none"], "page:by the bed"]],
		"Scratched inside the rim of the cup: M."
	)
	entry.counts = false
	return entry


# smudges: one [readings, key] per {word}, in order; readings[0] is the word.
static func _make(title: String, body: String, corruption: float, smudges: Array = [], between := "") -> NoteEntry:
	var entry := NoteEntry.new()
	entry.title = title
	entry.corruption = corruption
	entry.between = between
	var text := ""
	var at := 0
	var index := 0
	while true:
		var open := body.find("{", at)
		if open < 0:
			break
		var close := body.find("}", open)
		var word := body.substr(open + 1, close - open - 1)
		var spec: Array = smudges[index] if index < smudges.size() else [[word], ""]
		var readings: Array = spec[0]
		if str(readings[0]) != word:
			push_error("NoteCatalog: %s smudge %d reads '%s' but its first reading is '%s'" % [title, index, word, readings[0]])
		entry.smudges.append({"readings": readings, "key": str(spec[1])})
		text += body.substr(at, open - at) + "{%d}" % index
		at = close + 1
		index += 1
	text += body.substr(at)
	if index != smudges.size():
		push_error("NoteCatalog: %s has %d smudges in the text and %d listed" % [title, index, smudges.size()])
	entry.body = text
	return entry
```

- [ ] **Step 5: Run the probe to verify it passes**

Run: `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: only `PASS` lines, ending `JOURNAL PASS`, exit code 0.

- [ ] **Step 6: Check that nothing else used the old titles**

Run: `grep -rn "Field Note — Day 3\|\"from the pack\"\|the handwriting changes\|\"don't\"" scripts tools --include=*.gd`
Expected: hits only in `note_catalog.gd` and `journal_probe.gd`.

- [ ] **Step 7: Commit**

```bash
git add scripts/notes/note_entry.gd scripts/notes/note_catalog.gd tools/journal_probe.gd tools/journal_probe.tscn
git commit -m "Rewrite the pages as Mathilda's, with smudged words, their readings and keys, and a line between the lines on each."
```

---

### Task 2: What she knows, and the journal phase

**Files:**
- Modify: `scripts/game/game.gd`
- Modify: `scripts/game/settings.gd` (`ACTIONS`)
- Modify: `scripts/house/haunting.gd:78`, `scripts/player/footprints.gd:129` (keep the world going in `JOURNAL`)
- Modify: `scripts/tune.gd` (`LIGHTS_NEAR`)
- Test: `tools/journal_probe.gd`

**Interfaces:**
- Consumes: Task 1's `NoteEntry.smudges`, `NoteCatalog.everything()`, `NoteCatalog.LAST_TITLE`.
- Produces on `Game`:
  - `Phase.JOURNAL` (appended last); signals `journal_changed`, `page_added(entry: NoteEntry)`, `page_deciphered(entry: NoteEntry)`
  - `enum Reading { LOCKED, WRONG, RIGHT }`
  - vars `journal: Array[NoteEntry]`, `journal_focus: String`, `read_pages`, `visited`, `heard_events`, `deciphered: Dictionary` (title → {index: true})
  - `awake() -> bool`, `place_at(point: Vector3) -> String`, `visit(place: String)`, `heard(event: String)`, `known(key: String) -> bool`
  - `add_to_journal(entry: NoteEntry)`, `solved(entry: NoteEntry, index: int) -> bool`, `page_solved(entry: NoteEntry) -> bool`, `all_deciphered() -> bool`
  - `decipher(entry: NoteEntry, index: int, reading: String) -> Reading`
  - `open_journal(focus := "")`, `close_journal()`, `dev_journal(title: String)`
- Calls on `voice` (guarded by `voice != null`; added in Task 5): `voice.misread()`, `voice.deciphered(entry)`, `voice.speaks() -> bool`.

- [ ] **Step 1: Add the failing rules checks to the probe**

In `tools/journal_probe.gd`, change `_run()` to:

```gdscript
func _run() -> void:
	_catalog()
	_knowledge()
	_phases()
	print("JOURNAL ", "FAIL (%d)" % _failures if _failures > 0 else "PASS")
	get_tree().quit(1 if _failures > 0 else 0)
```

and add:

```gdscript
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: parse errors for `add_to_journal`, `Reading`, `open_journal`…; exit 1.

- [ ] **Step 3: Add `LIGHTS_NEAR` to `Tune`**

In `scripts/tune.gd`, after `const VOICE_SPL := 55.0`:

```gdscript
# Within this flat distance (m) of the exit she is at "the lights".
const LIGHTS_NEAR := 40.0
```

- [ ] **Step 4: Extend `Game`**

In `scripts/game/game.gd`:

1. Append `JOURNAL` to the enum: `enum Phase { BOOT, INTRO, PLAYING, READING, PAUSED, CAUGHT, ESCAPED, JOURNAL }`.
2. Under the existing signals add:

```gdscript
# A page went into the journal, or a smudge was solved.
signal journal_changed
signal page_added(entry: NoteEntry)
# Every smudge on this page is solved; the line between the lines shows.
signal page_deciphered(entry: NoteEntry)

enum Reading { LOCKED, WRONG, RIGHT }
```

3. Under `var read_last_page := false` add:

```gdscript
# The journal: pages in the order found, the one to open on, and what she
# knows that makes a smudge legible (NoteEntry.smudges keys).
var journal: Array[NoteEntry] = []
var journal_focus := ""
var read_pages: Dictionary = {}
var visited: Dictionary = {}
var heard_events: Dictionary = {}
# title -> {smudge index: true}
var deciphered: Dictionary = {}
```

4. In `_process`, replace `if phase == Phase.PLAYING or phase == Phase.READING:` with `if awake():`. Right after that block's closing (before `if phase != Phase.INTRO:`) add:

```gdscript
	if awake() and player:
		visit(place_at(player.global_position))
```

5. In `reset()`, after `read_last_page = false` add:

```gdscript
	journal.clear()
	journal_focus = ""
	read_pages.clear()
	visited.clear()
	heard_events.clear()
	deciphered.clear()
```

6. In `begin_reading()`, replace

```gdscript
	if voice and entry:
		voice.heard_page(entry)
```

with

```gdscript
	if entry:
		add_to_journal(entry)
	if voice and entry:
		voice.heard_page(entry)
```

7. In `toggle_pause()`, insert at the top:

```gdscript
	if phase == Phase.JOURNAL:
		close_journal()
		return
```

8. In `_ready()`, after `_bind("glance_back", KEY_Q)` add:

```gdscript
	_bind("journal", KEY_J)
	_bind("journal", KEY_TAB)
```

and in `_bind_pad()` add `["journal", JOY_BUTTON_Y]` to the button list.

9. Add these functions after `close_reading()`:

```gdscript
## The world keeps going: playing, reading a page or in the journal.
func awake() -> bool:
	return phase == Phase.PLAYING or phase == Phase.READING or phase == Phase.JOURNAL


## Where she is, for her lines and the journal's keys: a house room, the
## lights near the exit, or the snow.
func place_at(point: Vector3) -> String:
	if house:
		var room := house.room_at(point + Vector3(0.0, 0.9, 0.0))
		if room != "":
			return room
	if trail:
		var end := trail.exit_point
		if Vector2(point.x - end.x, point.z - end.z).length() < Tune.LIGHTS_NEAR:
			return "lights"
	return "snow"


func visit(place: String) -> void:
	if place == "" or visited.has(place):
		return
	visited[place] = true
	journal_changed.emit()


func heard(event: String) -> void:
	if heard_events.has(event):
		return
	heard_events[event] = true
	journal_changed.emit()


## page:<title> read, place:<place> visited, event:<call|echo> heard. With her
## voice off she never calls, so the snow stands in for a call; the echo may
## never come, so the last page stands in for it.
func known(key: String) -> bool:
	var split := key.find(":")
	if split < 0:
		return false
	var what := key.substr(split + 1)
	match key.left(split):
		"page":
			return read_pages.has(what)
		"place":
			return visited.has(what)
		"event":
			if heard_events.has(what):
				return true
			if what == "call":
				return visited.has("snow") and (voice == null or not voice.speaks())
			if what == "echo":
				return read_pages.has(NoteCatalog.LAST_TITLE)
	return false


func add_to_journal(entry: NoteEntry) -> void:
	if entry == null:
		return
	read_pages[entry.title] = true
	for kept in journal:
		if kept.title == entry.title:
			journal_changed.emit()
			return
	journal.append(entry)
	page_added.emit(entry)
	journal_changed.emit()


func solved(entry: NoteEntry, index: int) -> bool:
	return entry != null and deciphered.has(entry.title) and (deciphered[entry.title] as Dictionary).has(index)


func page_solved(entry: NoteEntry) -> bool:
	if entry == null:
		return false
	for index in entry.smudges.size():
		if not solved(entry, index):
			return false
	return true


func all_deciphered() -> bool:
	for entry in NoteCatalog.everything():
		if not page_solved(entry):
			return false
	return true


func decipher(entry: NoteEntry, index: int, reading: String) -> Reading:
	if entry == null or index < 0 or index >= entry.smudges.size():
		return Reading.WRONG
	if solved(entry, index):
		return Reading.RIGHT
	var smudge: Dictionary = entry.smudges[index]
	if not known(str(smudge.key)):
		return Reading.LOCKED
	if reading != str((smudge.readings as Array)[0]):
		if voice:
			voice.misread()
		return Reading.WRONG
	if not deciphered.has(entry.title):
		deciphered[entry.title] = {}
	(deciphered[entry.title] as Dictionary)[index] = true
	journal_changed.emit()
	if page_solved(entry):
		page_deciphered.emit(entry)
		if voice:
			voice.deciphered(entry)
	return Reading.RIGHT


## From play, or from the page she is reading (the journal opens on it).
func open_journal(focus := "") -> void:
	if phase == Phase.READING:
		if focus == "" and active_note and active_note.entry:
			focus = active_note.entry.title
	elif phase != Phase.PLAYING:
		return
	journal_focus = focus
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_phase(Phase.JOURNAL)


func close_journal() -> void:
	if phase != Phase.JOURNAL:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_phase(Phase.PLAYING)


## Dev hook (RUN_JOURNAL): every page in the journal with its first smudge
## solved, opened on title.
func dev_journal(title: String) -> void:
	for entry in NoteCatalog.everything():
		add_to_journal(entry)
		if not deciphered.has(entry.title):
			deciphered[entry.title] = {}
		(deciphered[entry.title] as Dictionary)[0] = true
	journal_changed.emit()
	open_journal(title)
```

- [ ] **Step 5: Make the journal rebindable**

In `scripts/game/settings.gd`, add `["journal", "Journal"],` to `ACTIONS` right after `["interact", "Read / open / use"],`.

- [ ] **Step 6: Keep the house and prints going in the journal**

- In `scripts/house/haunting.gd:78`, replace `if Game.phase != Game.Phase.PLAYING and Game.phase != Game.Phase.READING:` with `if not Game.awake():`.
- In `scripts/player/footprints.gd:129`, make the same replacement.

- [ ] **Step 7: Run the probe**

Run: `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: `JOURNAL PASS`, exit 0. (`voice.speaks()` is not reached because `Game.voice` is null.)

- [ ] **Step 8: Commit**

```bash
git add scripts/game/game.gd scripts/game/settings.gd scripts/house/haunting.gd scripts/player/footprints.gd tools/journal_probe.gd
git commit -m "Let Game keep what she has read, visited and heard, decide which smudges she can decipher, and open a journal phase that holds her still while the world goes on."
```

(`scripts/tune.gd` stays unstaged per Global Constraints unless the leap work was committed.)

---

### Task 3: Smudges on the page

**Files:**
- Modify: `scripts/ui/chrome.gd` (add `BLOT`, `BLOT_INK`, `blot`, `smudge_text`, `page_label`)
- Modify: `scripts/ui/note_reader.gd`
- Test: `tools/journal_probe.gd`

**Interfaces:**
- Consumes: `Game.solved`, `Game.page_solved`, `NoteEntry.smudges/between/body`.
- Produces:
  - `UiChrome.blot(title: String, index: int, length: int) -> String`: deterministic scratch letters, at least 3
  - `UiChrome.smudge_text(entry: NoteEntry, links := false) -> String`: BBCode with solved smudges as `[u]word[/u]` and unsolved ones as `[s][color=#…]blot[/color][/s]`, wrapped in `[url=<index>]…[/url]` when `links`
  - `UiChrome.page_label(size: int) -> RichTextLabel`
  - `NoteReader.show_entry(entry: NoteEntry)`

- [ ] **Step 1: Add the failing render checks**

In `tools/journal_probe.gd`, add `_render()` to `_run()` after `_phases()`, and add:

```gdscript
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: parse errors for `UiChrome.blot` / `show_entry`; exit 1.

- [ ] **Step 3: Add the renderer to `UiChrome`**

In `scripts/ui/chrome.gd`, after the existing color constants:

```gdscript
# Scratched-out words on a page: the letters a blot is drawn with, and its ink.
const BLOT := "xqvlmnrwzhk"
const BLOT_INK := Color(0.42, 0.33, 0.25, 0.85)
```

and at the end of the file:

```gdscript
## The letters a smudge is scratched out with: the same for that smudge on
## every page view, at least three long.
static func blot(title: String, index: int, length: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title + "#" + str(index))
	var out := ""
	for _i in maxi(length, 3):
		out += BLOT[rng.randi() % BLOT.length()]
	return out


## A page body as BBCode: solved smudges underlined in ink, the rest scratched
## out. links: each unsolved smudge is a [url=<index>] the journal can click.
static func smudge_text(entry: NoteEntry, links := false) -> String:
	var text := entry.body.replace("[", "[lb]")
	for index in entry.smudges.size():
		var word := str((entry.smudges[index].readings as Array)[0])
		var shown: String
		if Game.solved(entry, index):
			shown = "[u]%s[/u]" % word
		else:
			shown = "[s][color=#%s]%s[/color][/s]" % [BLOT_INK.to_html(true), blot(entry.title, index, word.length())]
			if links:
				shown = "[url=%d]%s[/url]" % [index, shown]
		text = text.replace("{%d}" % index, shown)
	return text


## The paper's text: BBCode, wrapping, ink on paper, growing with its text.
static func page_label(size: int) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.bbcode_enabled = true
	node.fit_content = true
	node.scroll_active = false
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("normal_font_size", size)
	node.add_theme_color_override("default_color", PAPER_INK)
	node.add_theme_constant_override("line_separation", 6)
	return node
```

- [ ] **Step 4: Switch `NoteReader` to the renderer**

In `scripts/ui/note_reader.gd`:

1. Delete `const _GLYPHS := ...` and `var _stable: String = ""`. Change `var _body: Label` to `var _body: RichTextLabel`. Add `var _journal_keys: HBoxContainer`.
2. Replace `_process` with:

```gdscript
func _process(delta: float) -> void:
	if not visible or _entry == null:
		return
	_danger.visible = Game.closeness > 0.4
	if _body.visible_characters < 0:
		return
	var total := _body.get_total_character_count()
	_accum += delta
	var step := 1.0 / Tune.TYPE_CPS
	while _accum >= step and _body.visible_characters < total:
		_accum -= step
		_body.visible_characters += 1
	if _body.visible_characters >= total:
		_body.visible_characters = -1
	var bar := _scroll.get_v_scroll_bar()
	if bar:
		_scroll.scroll_vertical = int(bar.max_value)
```

3. Replace `_open()` with:

```gdscript
func _open() -> void:
	var page := Game.active_note
	if page == null or page.entry == null:
		return
	show_entry(page.entry)


func show_entry(entry: NoteEntry) -> void:
	_entry = entry
	_accum = 0.0
	var notes := NoteCatalog.all()
	_count.text = "Found in the house"
	for i in notes.size():
		if notes[i].title == _entry.title:
			_count.text = "Note %d of %d" % [i + 1, notes.size()]
			break
	if _entry.record_of != "":
		_count.text = "Containment record"
	_title.text = _entry.title
	var text := UiChrome.smudge_text(_entry)
	if Game.page_solved(_entry) and _entry.between != "":
		text += "\n\n[color=#%s]%s[/color]" % [Color(UiChrome.PAPER_INK, 0.55).to_html(true), _entry.between]
	_body.text = text
	_body.visible_characters = 0
	_scroll.scroll_vertical = 0
	UiChrome.set_key(_close_keys, Game.settings.key_label("interact"))
	UiChrome.set_key(_breath_keys, Game.settings.key_label("hold_breath"))
	UiChrome.set_key(_journal_keys, Game.settings.key_label("journal"))
	visible = true
	if _entry_tween and _entry_tween.is_running():
		_entry_tween.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.94
	_panel.modulate.a = 0.0
	_entry_tween = create_tween().set_parallel(true)
	_entry_tween.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entry_tween.tween_property(_panel, "modulate:a", 1.0, 0.17)
```

4. In `_build()`, replace the `_body = UiChrome.label("", 20, UiChrome.PAPER_INK)` block (the label plus its four property lines) with:

```gdscript
	_body = UiChrome.page_label(20)
	_body.custom_minimum_size = Vector2(700, 0)
	_scroll.add_child(_body)
```

and after `footer.add_child(_breath_keys)` add:

```gdscript
	_journal_keys = UiChrome.key_row("J", "Journal", true)
	footer.add_child(_journal_keys)
```

- [ ] **Step 5: Run the probe**

Run: `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: `JOURNAL PASS`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/chrome.gd scripts/ui/note_reader.gd tools/journal_probe.gd
git commit -m "Draw smudged words on the pages as scratched-out ink that becomes legible once deciphered, in place of the random letter corruption."
```

---

### Task 4: The journal, and a HUD without objectives

**Files:**
- Create: `scripts/ui/journal.gd`
- Modify: `scripts/ui/hud.gd`, `scripts/ui/end_card.gd`, `scripts/ui/pause_menu.gd:23,183`, `scripts/game/settings.gd:51,85`, `scripts/main.gd` (dev hook), `scripts/tune.gd` (`JOURNAL_TOAST`)
- Test: `tools/journal_probe.gd`; screenshots

**Interfaces:**
- Consumes: everything from Tasks 2–3.
- Produces:
  - `Journal` (Control) with `_pick(index: int)`, `_choose(reading: String)`, `_select(entry: NoteEntry)`, and fields `_list`, `_blots`, `_readings`, `_hint`, `_between`, `_body`
  - `Hud.journal: Journal`
  - `Settings.show_journal_toast: bool` (replaces `show_objective`)
  - dev hook `RUN_JOURNAL=<title>` (with `RUN_CAPTURE`)

- [ ] **Step 1: Add the failing journal UI checks**

In `tools/journal_probe.gd`, add `_journal_ui()` to `_run()` after `_render()`, and add:

```gdscript
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
	var struck := 0
	for child in journal._readings.get_children():
		if (child as Button).disabled:
			struck += 1
	_check(struck == 1 and not Game.solved(post, 0), "a wrong reading is struck out")
	journal._choose("your")
	_check(Game.solved(post, 0) and journal._readings.get_child_count() == 0, "the right reading settles it")
	_check(journal._body.text.contains("[u]your[/u]"), "the page shows the word in ink")
	_check(journal._blots.get_child_count() == 1, "one smudge left")
	Game.heard("echo")
	journal._pick(1)
	journal._choose("answer")
	_check(journal._between.visible and journal._between.text == post.between, "the whole page shows the line between the lines")
	Game.toggle_pause()
	_check(not journal.visible and Game.phase == Game.Phase.PLAYING, "Esc closes it")
	journal.queue_free()
	Game.reset()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: parse error, `Journal` not found; exit 1.

- [ ] **Step 3: Write `scripts/ui/journal.gd`**

```gdscript
class_name Journal
extends Control

# The pages she has found, to read again and decipher. Open, it is
# Game.Phase.JOURNAL: she stands still and the world goes on. A smudge is a
# word she can't read yet; once its key is known (Game.known) she can try its
# three readings. See docs/superpowers/specs/2026-10-06-mathilda-story-design.md.

const HINTS := {
	"page": "Something else she wrote might help.",
	"place": "Maybe if I saw the place.",
	"event": "Maybe if I listened, out there.",
}

var _list: VBoxContainer
var _title: Label
var _body: RichTextLabel
var _between: Label
var _blots: HBoxContainer
var _readings: HBoxContainer
var _hint: Label
var _empty: Label
var _close_keys: HBoxContainer
var _selected: NoteEntry
var _smudge := -1
# This run's order of each smudge's readings, and the readings tried and wrong.
var _order := {}
var _wrong := {}
var _buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	Game.phase_changed.connect(_on_phase)
	Game.journal_changed.connect(_refresh)
	Game.page_deciphered.connect(_on_page_deciphered)


func _on_phase(next: Game.Phase) -> void:
	if next == Game.Phase.JOURNAL:
		_open()
	elif visible:
		visible = false


func _open() -> void:
	visible = true
	var focus := _kept(Game.journal_focus)
	if focus == null and _selected:
		focus = _kept(_selected.title)
	if focus == null and not Game.journal.is_empty():
		focus = Game.journal[0]
	_select(focus)
	UiChrome.set_key(_close_keys, Game.settings.key_label("journal"))
	if _selected and _buttons.has(_selected.title):
		(_buttons[_selected.title] as Button).grab_focus.call_deferred()


func _kept(title: String) -> NoteEntry:
	for entry in Game.journal:
		if entry.title == title:
			return entry
	return null


func _select(entry: NoteEntry) -> void:
	_selected = entry
	_smudge = -1
	_hint.text = ""
	_between.modulate.a = 1.0
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	_fill_list()
	_empty.visible = Game.journal.is_empty()
	_title.text = _selected.title if _selected else ""
	_body.text = UiChrome.smudge_text(_selected, true) if _selected else ""
	var whole := _selected != null and Game.page_solved(_selected)
	_between.text = _selected.between if whole else ""
	_between.visible = whole
	_fill_blots()
	_fill_readings()


func _fill_list() -> void:
	for entry in Game.journal:
		if not _buttons.has(entry.title):
			var button := UiChrome.paper_button(entry.title)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_select.bind(entry))
			_list.add_child(button)
			_buttons[entry.title] = button
		var shown := _buttons[entry.title] as Button
		shown.text = entry.title + ("   (whole)" if Game.page_solved(entry) else "")
		var chosen := _selected != null and _selected.title == entry.title
		shown.add_theme_color_override("font_color", UiChrome.PAPER_INK if chosen else Color(UiChrome.PAPER_INK, 0.55))


func _fill_blots() -> void:
	for child in _blots.get_children():
		_blots.remove_child(child)
		child.queue_free()
	if _selected == null:
		return
	for index in _selected.smudges.size():
		if Game.solved(_selected, index):
			continue
		var word := str((_selected.smudges[index].readings as Array)[0])
		var button := UiChrome.paper_button(UiChrome.blot(_selected.title, index, word.length()))
		button.tooltip_text = "Try to make it out"
		button.pressed.connect(_pick.bind(index))
		_blots.add_child(button)


func _fill_readings() -> void:
	for child in _readings.get_children():
		_readings.remove_child(child)
		child.queue_free()
	if _selected == null or _smudge < 0 or Game.solved(_selected, _smudge):
		return
	for reading in _readings_of(_selected, _smudge):
		var button := UiChrome.paper_button(str(reading))
		var tried := _wrong.has("%s|%d|%s" % [_selected.title, _smudge, reading])
		button.disabled = tried
		button.modulate.a = 0.35 if tried else 1.0
		button.pressed.connect(_choose.bind(str(reading)))
		_readings.add_child(button)


func _readings_of(entry: NoteEntry, index: int) -> Array:
	var id := "%s|%d" % [entry.title, index]
	if not _order.has(id):
		var shuffled := (entry.smudges[index].readings as Array).duplicate()
		shuffled.shuffle()
		_order[id] = shuffled
	return _order[id]


func _pick(index: int) -> void:
	if _selected == null or index < 0 or index >= _selected.smudges.size() or Game.solved(_selected, index):
		return
	var key := str(_selected.smudges[index].key)
	if not Game.known(key):
		_smudge = -1
		_hint.text = "I can't make this out yet. " + str(HINTS.get(key.get_slice(":", 0), ""))
		_fill_readings()
		return
	_smudge = index
	_hint.text = ""
	_fill_readings()
	for child in _readings.get_children():
		if not (child as Button).disabled:
			(child as Button).grab_focus()
			break


func _choose(reading: String) -> void:
	if _selected == null or _smudge < 0:
		return
	match Game.decipher(_selected, _smudge, reading):
		Game.Reading.RIGHT:
			_smudge = -1
			_hint.text = ""
			_refresh()
		Game.Reading.WRONG:
			_wrong["%s|%d|%s" % [_selected.title, _smudge, reading]] = true
			_fill_readings()
		Game.Reading.LOCKED:
			_pick(_smudge)


func _on_page_deciphered(entry: NoteEntry) -> void:
	if not visible or _selected == null or entry.title != _selected.title:
		return
	_between.modulate.a = 0.0
	create_tween().tween_property(_between, "modulate:a", 1.0, 1.2)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -540
	panel.offset_right = 540
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", UiChrome.paper(28))
	add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	panel.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(UiChrome.label("Journal", 30, UiChrome.PAPER_INK))
	_empty = UiChrome.label("Nothing yet. The pages she finds are kept here.", 15, Color(UiChrome.PAPER_INK, 0.6))
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_empty)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	left.add_child(_list)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_close_keys = UiChrome.key_row("J", "Close", true)
	footer.add_child(_close_keys)
	var close := UiChrome.paper_button("Close")
	close.pressed.connect(func() -> void: Game.close_journal())
	footer.add_child(close)
	left.add_child(footer)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	_title = UiChrome.label("", 28, UiChrome.PAPER_INK)
	right.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	scroll.add_child(page)
	_body = UiChrome.page_label(19)
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.meta_clicked.connect(func(meta: Variant) -> void: _pick(int(str(meta))))
	page.add_child(_body)
	_between = UiChrome.label("", 16, Color(UiChrome.PAPER_INK, 0.55))
	_between.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_between)
	_blots = HBoxContainer.new()
	_blots.add_theme_constant_override("separation", 8)
	right.add_child(_blots)
	_hint = UiChrome.label("", 15, Color(UiChrome.PAPER_INK, 0.65))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_hint)
	_readings = HBoxContainer.new()
	_readings.add_theme_constant_override("separation", 10)
	right.add_child(_readings)
```

- [ ] **Step 4: Import the new class and run the probe**

Run: `godot-mono --headless --path . --import` then `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: `JOURNAL PASS`, exit 0.

- [ ] **Step 5: Replace the objective in `Hud`**

In `scripts/tune.gd` after `LIGHTS_NEAR` add:

```gdscript
# How long (s) "Added to the journal" stays after a page is found.
const JOURNAL_TOAST := 3.0
```

In `scripts/ui/hud.gd`:

1. Delete the vars `_objective_plate`, `_objective`, `_pips`, and the functions `_refresh_objective()`, `_refresh_pips()`, `_build_objective()`.
2. In `_process`, delete `_objective_plate.visible = playing and Game.settings.show_objective`, `_refresh_objective()` and `_refresh_pips()`. In `_on_phase`, delete `_refresh_objective()`. In `_build()`, replace `_build_objective()` with `_build_toast()`.
3. Add vars:

```gdscript
var _toast: PanelContainer
var _toast_keys: HBoxContainer
var _toast_left := 0.0
var journal: Journal
```

4. In `_ready()`, after `Game.interaction_feedback.connect(...)` add `Game.page_added.connect(_on_page_added)`.
5. In `_process`, change `var reading := Game.phase == Game.Phase.READING` to `var reading := Game.phase == Game.Phase.READING or Game.phase == Game.Phase.JOURNAL`, and after the murmur block add:

```gdscript
	_toast_left = maxf(0.0, _toast_left - delta)
	_toast.visible = _toast_left > 0.0 and (playing or Game.phase == Game.Phase.READING)
	_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
```

6. In `_unhandled_input`, before the `pause` check, add:

```gdscript
	if event.is_action_pressed("journal"):
		if Game.phase == Game.Phase.JOURNAL:
			Game.close_journal()
			get_viewport().set_input_as_handled()
		elif Game.phase == Game.Phase.PLAYING or Game.phase == Game.Phase.READING:
			Game.open_journal()
			get_viewport().set_input_as_handled()
```

7. In `_build()`, right after `reader` is added (`reader = NoteReader.new()` and its `add_child`), add:

```gdscript
	journal = Journal.new()
	add_child(journal)
```

8. Add:

```gdscript
func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast.offset_left = 28
	_toast.offset_top = -86
	_toast.offset_right = 340
	_toast.offset_bottom = -28
	_toast.add_theme_stylebox_override("panel", UiChrome.plate(14, 6))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	_toast_keys = UiChrome.key_row("J", "Added to the journal")
	_toast.add_child(_toast_keys)


func _on_page_added(_entry: NoteEntry) -> void:
	if not Game.settings.show_journal_toast:
		return
	UiChrome.set_key(_toast_keys, Game.settings.key_label("journal"))
	_toast_left = Tune.JOURNAL_TOAST
```

9. In `_build_intro()`, change the line `"The fence is as far as the snow goes."` to `"Mathilda went out into the storm."`.

- [ ] **Step 6: Rename the setting and its toggle**

- `scripts/game/settings.gd:51`: `"show_objective": true,` becomes `"show_journal_toast": true,`.
- `scripts/game/settings.gd:85`: `var show_objective: bool = DEFAULTS.show_objective` becomes `var show_journal_toast: bool = DEFAULTS.show_journal_toast`.
- `scripts/ui/pause_menu.gd:23`: `"show_objective"` becomes `"show_journal_toast"`.
- `scripts/ui/pause_menu.gd:183`: becomes `_toggle("Journal notice", "show_journal_toast", "A note when a page goes into the journal.")`.

Check that nothing else uses the old name: `grep -rn "show_objective\|_objective\|_pips" scripts` gives no hits.

- [ ] **Step 7: Rewrite the escape card**

In `scripts/ui/end_card.gd`, replace the `Game.Phase.ESCAPED:` branch with:

```gdscript
		Game.Phase.ESCAPED:
			var road := "The engine is running. The driver's door is open, the seat still warm."
			if Game.read_last_page:
				road += " You didn't turn around."
			if Game.all_deciphered():
				road += " Beside the cup on the dash, a second one. Still warm."
			_show("The road", road, "Walk the ridge again")
```

- [ ] **Step 8: Add the `RUN_JOURNAL` dev hook**

In `scripts/main.gd`, inside `if _capture:`, after the `RUN_MENU` block:

```gdscript
		# Dev hook: RUN_JOURNAL=<title> opens the journal, half deciphered, on that page.
		var journal_page := OS.get_environment("RUN_JOURNAL")
		if journal_page != "":
			Game.dev_journal.call_deferred(journal_page)
```

- [ ] **Step 9: Probe and screenshots**

Run: `godot-mono --headless --path . --import` then `godot-mono --headless --path . tools/journal_probe.tscn`. Expected: `JOURNAL PASS`.

Then, in PowerShell:

```powershell
$env:RUN_CAPTURE = "1"; $env:RUN_SHOT = "$PWD\build\shots\journal.png"; $env:RUN_JOURNAL = "the handwriting changes"; godot-mono --path .
Remove-Item Env:RUN_JOURNAL; $env:RUN_SHOT = "$PWD\build\shots\play.png"; godot-mono --path .
Remove-Item Env:RUN_CAPTURE, Env:RUN_SHOT
```

Open both PNGs:
- `journal.png`: the list of seven pages, the selected page, the first smudge underlined in ink, the second scratched out, its blot button.
- `play.png`: no objective plate and no pips.

Expected: blots read as scratched-out handwriting, not a rendering fault. If they look like a bug (tofu boxes, overlap), fix `BLOT` or `BLOT_INK` before going on.

- [ ] **Step 10: Commit**

```bash
git add scripts/ui/journal.gd scripts/ui/hud.gd scripts/ui/end_card.gd scripts/ui/pause_menu.gd scripts/game/settings.gd scripts/main.gd tools/journal_probe.gd
git commit -m "Replace the HUD objective with a journal where she can decipher the smudged words on the pages she has found, and let the road remember a fully deciphered journal."
```

---

### Task 5: Her lines, by mood, stage and priority

**Files:**
- Modify: `assets/audio/voice/lines.json` (full rewrite)
- Modify: `scripts/player/voice.gd` (full rewrite, without calls; calls come in Task 6)
- Modify: `scripts/tune.gd` (`REVISIT_AFTER`, `MISREAD_GAP`)
- Modify: `tools/voice_probe.gd` (full rewrite)

**Interfaces:**
- Consumes: `Game.place_at`, `Game.awake`, `Game.read_pages`, `Game.notes_found`, `Game.read_last_page`, `Game.murmur_line`.
- Produces on `Voice`:
  - `LINES`, `CLIPS`, `PLACES`, `PRIORITY`, `STAGES`, `MOODS`
  - `static clip_key(text: String, mood: String) -> String`, `static stage_for(found: int, last: bool) -> String`, `static read_lines() -> Dictionary`
  - `speaks() -> bool`, `heard_page(entry: NoteEntry, repeat := false)`, `deciphered(entry: NoteEntry)`, `misread()`
  - internals the probes use: `_say(line: Dictionary, repeat := false) -> bool`, `_current`, `_spoken`, `_queue`, `_bored`, `_bored_at`, `_seen`, `_pages`, `_places`, `_misread`, `_clock`, `_since`, `_finished()`, `_on_phase(next)`, `_key(line)`
  - a line is `{"text", "mood", "kind", "id", "stage", "index"}`

- [ ] **Step 1: Write the failing probe**

Replace `tools/voice_probe.gd` with:

```gdscript
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot-mono --headless --path . tools/voice_probe.tscn`
Expected: errors (`_deciphered`, `MOODS`, `stage_for` missing); exit 1.

- [ ] **Step 3: Write `assets/audio/voice/lines.json`**

```json
{
  "pages": {
    "by the bed": {"text": "\"Stay in.\" She's the one out there, and she's telling me to stay in.", "mood": "shaken"},
    "from the pack": {"text": "Two cups. She packed for both of us. She knew I'd come.", "mood": "breaking"},
    "on the post": {"text": "Then I heard it again, from the trees. Okay. I won't answer. I won't.", "mood": "hushed"},
    "torn page": {"text": "Prints that just stop. She's describing mine. I haven't been to the pines yet. Have I?", "mood": "shaken"},
    "the handwriting changes": {"text": "That's my handwriting. That's how I make my M's.", "mood": "hushed"},
    "don't turn around": {"text": "Don't turn around. Fine. I won't. Just be at the lights.", "mood": "resolve"},
    "intake": {"text": "One cup. Just one. I'm not lifting that sheet. I'm not.", "mood": "breaking"}
  },
  "deciphered": {
    "by the bed": {"text": "She left the door open for me. Or for herself. She never could decide which of us needed rescuing.", "mood": "warm"},
    "from the pack": {"text": "One cup. The intake said one cup. I'm not counting again. I'm not.", "mood": "breaking"},
    "on the post": {"text": "It knew my name. It used my name on her.", "mood": "shaken"},
    "torn page": {"text": "Smaller than mine. Then not. Like the prints were growing into me.", "mood": "hushed"},
    "the handwriting changes": {"text": "Same hand, both pages. I'd know it anywhere. That's what scares me.", "mood": "hushed"},
    "don't turn around": {"text": "The sheet is not her. The sheet is not her. I'll say it all the way to the road.", "mood": "resolve"},
    "intake": {"text": "Just an M. It could be either of us. It could be both.", "mood": "breaking"}
  },
  "places": {
    "bedroom": {"text": "Her side of the bed is still warm. She can't be far.", "mood": "warm"},
    "hall": {"text": "Her boots are gone. The door isn't even latched.", "mood": "shaken"},
    "living": {"text": "Two chairs pulled out. She sat up with that candle until it went out.", "mood": "hushed"},
    "backhall": {"text": "Mathilda? She wouldn't go down there. She hates the cellar.", "mood": "hushed"},
    "stair": {"text": "If she's down here, she's been quiet a long time.", "mood": "hushed"},
    "landing": {"text": "No wind down here. Just my heart, and I wish it would slow down.", "mood": "hushed"},
    "corridor": {"text": "Why does a cabin need a hallway this long under the ground?", "mood": "hushed"},
    "janitor": {"text": "Someone keeps this place clean. Someone expects to use it.", "mood": "shaken"},
    "morgue": {"text": "No. She wouldn't be here. She's out in the snow. She has to be.", "mood": "breaking"},
    "snow": {"text": "Her prints are already filling in. I have to be faster than the snow.", "mood": "resolve"},
    "lights": {"text": "Headlights. Someone's waiting. Please let it be her.", "mood": "breaking"}
  },
  "revisits": {
    "bedroom": {"text": "The lantern's still lit. Nobody's been here. Or I have, and I don't remember.", "mood": "shaken"},
    "hall": {"text": "I latched it behind me. I know I did.", "mood": "shaken"},
    "living": {"text": "Still two chairs. I keep thinking one of them will be pushed in.", "mood": "hushed"},
    "morgue": {"text": "I said I wouldn't come back down here. I keep coming back down here.", "mood": "breaking"},
    "snow": {"text": "Every set of prints out here could be mine.", "mood": "hushed"}
  },
  "bored": {
    "hope": [
      {"text": "She knows this field better than I do. She'll have found shelter.", "mood": "steady"},
      {"text": "Ten minutes, she said. Ten minutes, and then the snow came in sideways.", "mood": "shaken"},
      {"text": "When I find her I'm going to be so angry. And then I'm not letting go.", "mood": "warm"},
      {"text": "She always leaves something behind so I can find her. Always.", "mood": "steady"},
      {"text": "Every white shape is her coat, until it isn't.", "mood": "hushed"},
      {"text": "She'll be cold. She never wears the hat. I should've made her wear the hat.", "mood": "warm"}
    ],
    "doubt": [
      {"text": "Her prints stop. Mine don't. What does that make me?", "mood": "shaken"},
      {"text": "I've said her name so many times it's just a sound now.", "mood": "hushed"},
      {"text": "What if she's back at the cabin, by the lantern, writing to me?", "mood": "shaken"},
      {"text": "I can't remember which of us said we'd stay.", "mood": "breaking"},
      {"text": "I keep turning to tell her something. There's nobody to tell.", "mood": "breaking"},
      {"text": "The light hasn't moved. She was right. It's the same afternoon.", "mood": "hushed"}
    ],
    "resolve": [
      {"text": "Don't turn around. I can do that. I can do that much.", "mood": "resolve"},
      {"text": "If she's behind me, she can see me. That has to be enough.", "mood": "breaking"},
      {"text": "The engine's running. Someone kept it warm for one of us.", "mood": "hushed"},
      {"text": "Whatever's at the lights, I'm walking up to it. I'm not stopping now.", "mood": "resolve"},
      {"text": "I'll find you. Or you'll find me. One of us gets to go home.", "mood": "breaking"},
      {"text": "I'm not cold any more. That's bad, isn't it. Keep walking.", "mood": "hushed"}
    ]
  },
  "calls": {
    "hope": [
      {"text": "Mathilda!", "mood": "calling"},
      {"text": "Mathilda! Can you hear me?", "mood": "calling"},
      {"text": "Mathilda! Over here!", "mood": "calling"}
    ],
    "doubt": [
      {"text": "Mathilda! Answer me!", "mood": "calling"},
      {"text": "Mathilda... where are you?", "mood": "breaking"},
      {"text": "Mathilda! Say something!", "mood": "calling"}
    ],
    "resolve": [
      {"text": "Mathilda! I'm coming!", "mood": "calling"},
      {"text": "Mathilda... please.", "mood": "breaking"},
      {"text": "I'm going to the lights, Mathilda! Meet me there!", "mood": "calling"}
    ]
  },
  "misread": [
    {"text": "No. That's not it.", "mood": "hushed"},
    {"text": "That doesn't fit.", "mood": "steady"},
    {"text": "She'd never write that.", "mood": "shaken"},
    {"text": "Wrong. Look again.", "mood": "hushed"},
    {"text": "I want it to say that. It doesn't.", "mood": "breaking"}
  ]
}
```

- [ ] **Step 4: Add the `Tune` constants**

In `scripts/tune.gd` after `JOURNAL_TOAST`:

```gdscript
# A place's second line waits this long (s) after its first.
const REVISIT_AFTER := 60.0
# Wrong readings in the journal: at most one muttered line per MISREAD_GAP s.
const MISREAD_GAP := 8.0
```

- [ ] **Step 5: Rewrite `scripts/player/voice.gd`**

```gdscript
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
func _tick_outdoors(_delta: float) -> void:
	pass


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
```

`Tune.CALL_SPL` is referenced in `_say`. Add it now (Task 6 adds the rest of the call constants) in `scripts/tune.gd` after `MISREAD_GAP`:

```gdscript
# Her calls for Mathilda outdoors: a shout, dB SPL at 1 m.
const CALL_SPL := 82.0
```

- [ ] **Step 6: Run the probe**

Run: `godot-mono --headless --path . tools/voice_probe.tscn`
Expected: `VOICE PASS`, exit 0. Clips are not checked yet: there's no `PROBE_CLIPS`, and nothing has been baked.

- [ ] **Step 7: Run the journal probe again (Game calls into Voice now)**

Run: `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: `JOURNAL PASS`.

- [ ] **Step 8: Commit**

```bash
git add assets/audio/voice/lines.json scripts/player/voice.gd tools/voice_probe.gd
git commit -m "Give her 62 lines about the search for Mathilda, each with a mood, spoken by stage and priority, with an interrupted line forgotten as if it never played."
```

---

### Task 6: Calling for Mathilda, and the echo

**Files:**
- Modify: `scripts/player/voice.gd` (`_tick_outdoors`, echo)
- Modify: `scripts/tune.gd` (`CALL_FIRST`, `CALL_EVERY`, `ECHO_DROP_DB`, `ECHO_MAX`)
- Test: `tools/voice_probe.gd`

**Interfaces:**
- Consumes: `Game.heard`, `Game.read_pages`, `Game.trail.flora.tree_positions()`, `Game.indoors`.
- Produces on `Voice`: `_call_tick(delta: float, outdoors: bool)`, `_wants_echo(stage: String) -> bool`, `static echo_from(player_at: Vector3, trees: PackedVector3Array) -> Vector3` (`Vector3.INF` if none), fields `_call_left`, `_echoed`, `_echoes`, `_echo`.

- [ ] **Step 1: Add the failing call checks**

In `tools/voice_probe.gd`, add `_calls()` to `_run()` after `_extra()`, and add:

```gdscript
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot-mono --headless --path . tools/voice_probe.tscn`
Expected: errors for `_call_tick` / `_wants_echo` / `echo_from`; exit 1.

- [ ] **Step 3: Add the `Tune` constants**

In `scripts/tune.gd`, after `CALL_SPL`:

```gdscript
# The first call comes CALL_FIRST s after she steps out, then every CALL_EVERY s.
const CALL_FIRST := Vector2(20.0, 30.0)
const CALL_EVERY := Vector2(45.0, 80.0)
# The trees answer at most ECHO_MAX times, this much quieter than her call.
const ECHO_DROP_DB := 14.0
const ECHO_MAX := 2
```

- [ ] **Step 4: Implement calls and the echo in `Voice`**

Add vars after `var _call_at := ...`:

```gdscript
var _call_left := -1.0
var _echoed := {}
var _echoes := 0
var _echo: AudioStreamPlayer3D
```

In `_build_speaker()`, at the end:

```gdscript
	_echo = Loudness.voice(Tune.CALL_SPL - Tune.ECHO_DROP_DB, "Dread", true)
	_echo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_echo)
```

Replace the `_tick_outdoors` stub with:

```gdscript
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
```

- [ ] **Step 5: Run both probes**

Run: `godot-mono --headless --path . tools/voice_probe.tscn` and `godot-mono --headless --path . tools/journal_probe.tscn`
Expected: `VOICE PASS`, `JOURNAL PASS`.

- [ ] **Step 6: Commit**

```bash
git add scripts/player/voice.gd tools/voice_probe.gd
git commit -m "Have her call Mathilda's name into the storm, and once she has read the post, let her own call come back from the pines."
```

---

### Task 7: Bake her voice on the GPU with Qwen3-TTS

**Files:**
- Modify: `tools/bake_speech.py` (full rewrite)
- Output: `assets/audio/voice/*.wav`, `assets/audio/voice/manifest.json`
- Not committed: `build/voice/gpu-venv/`, `build/voice/hf/`, `build/voice/ref/`

**Interfaces:**
- Consumes: `assets/audio/voice/lines.json` (Task 5 format), the clip-key rule.
- Produces: one clip per (text, mood), named `sha256(text|mood).wav`; `manifest.json` with `clips[]` of `{text, mood, category, file, seconds, wer, similarity, engine, model}`.

- [ ] **Step 1: Write the script's self-test first**

Create `tools/bake_speech.py` containing only the header, constants and pure helpers from Step 5 (`clip_name`, `lines`, `words`, `wer`), plus:

```python
def self_test():
    import hashlib
    assert clip_name("a", "b") == hashlib.sha256(b"a|b").hexdigest() + ".wav"
    assert wer("Mathilda... please.", "Mathilda, please") == 0.0
    assert wer("two cups", "two cups here") == 0.5
    assert wer("I'm not lifting that sheet", "im not lifting the sheet") > 0.0
    data = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    every = lines(data)
    assert len(every) == 62, len(every)
    assert all(mood in MOODS for _, _, mood in every)
    print("SELF-TEST PASS")
```

and a `main()` that only handles `--self-test`.

- [ ] **Step 2: Run the self-test**

Run: `python tools/bake_speech.py --self-test`
Expected: `SELF-TEST PASS`. If `wer("Mathilda... please.", "Mathilda, please")` isn't 0.0, fix `words()` so punctuation never counts.

- [ ] **Step 3: Create the GPU environment**

Close GPU-heavy apps first; at plan time 6.5 of 8 GB VRAM was in use.

```powershell
uv python install 3.12
uv venv build/voice/gpu-venv --python 3.12
uv pip install --python build/voice/gpu-venv/Scripts/python.exe qwen-tts faster-whisper speechbrain soundfile numpy huggingface_hub
uv pip install --python build/voice/gpu-venv/Scripts/python.exe --reinstall torch torchaudio --index-url https://download.pytorch.org/whl/cu128
build/voice/gpu-venv/Scripts/python.exe -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

Expected: a `+cu128` version, `True`, `NVIDIA GeForce RTX 3070 Ti`. The second install must come after `qwen-tts`, or pip's CPU torch wins.

```powershell
build/voice/gpu-venv/Scripts/hf.exe download Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign --local-dir build/voice/hf/VoiceDesign
build/voice/gpu-venv/Scripts/hf.exe download Qwen/Qwen3-TTS-12Hz-1.7B-Base --local-dir build/voice/hf/Base
```

(If `hf.exe` is missing, use `huggingface-cli.exe download` with the same arguments.)

- [ ] **Step 4: Confirm the `qwen-tts` API before writing the engine**

```powershell
build/voice/gpu-venv/Scripts/python.exe -c "from qwen_tts import Qwen3TTSModel as M; import inspect; print([n for n in dir(M) if n.startswith(('generate','create'))]); print(inspect.signature(M.generate_voice_design)); print(inspect.signature(M.generate_voice_clone)); print(inspect.signature(M.create_voice_clone_prompt))"
```

Expected: `generate_voice_design(text, language, instruct, ...)`, `generate_voice_clone(text, language, ..., voice_clone_prompt=...)` and `create_voice_clone_prompt(ref_audio, ref_text, x_vector_only_mode)`. If a name or argument differs, change only the `Qwen` class in Step 5 to match.

- [ ] **Step 5: Write the full `tools/bake_speech.py`**

```python
"""Bake her reviewed lines into clips; no model runs during gameplay.

Engines: qwen (default) speaks each line with Qwen3-TTS VoiceDesign on CUDA,
directed by its mood, renders four takes, and keeps the one Whisper hears
right and that sounds most like her anchor; kokoro is the old CPU voice.
Setup: docs/VOICE.md. Clips land in assets/audio/voice/ as
sha256("text|mood").wav with manifest.json beside them.
"""

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/voice"
REF = ROOT / "build/voice/ref"
HF = ROOT / "build/voice/hf"
DESIGN_MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
BASE_MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-Base"
IDENTITY = ("A woman around thirty. A low, soft alto with a little breath in it, plain North American accent. "
            "She is cold, tired, and talking quietly to herself in an empty place; never theatrical, never narrating.")
# Mood: (direction appended to her identity, loudest-50-ms level in dBFS).
MOODS = {
    "steady": ("Calm and even, trying to reassure herself.", -12.0),
    "warm": ("Tender and fond, almost smiling, a catch at the end.", -12.0),
    "hushed": ("Barely above a whisper, close and careful, as if something might hear.", -18.0),
    "shaken": ("Unsteady, breath short, words coming a little too fast.", -12.0),
    "breaking": ("On the edge of tears, voice cracking, pauses where it gives out.", -13.0),
    "resolve": ("Low and determined, jaw set, each word placed.", -12.0),
    "calling": ("Shouting as loud as she can into a strong wind, straining, desperate.", -10.0),
}
ANCHOR_TEXT = "I'm going to find her. The lantern's lit, the door's open, and she can't have gone far in this."
TAKES = 4
CLONE_TAKES = 2
MAX_WER = 0.15
MIN_SIMILARITY = 0.60


def clip_name(text, mood):
    return hashlib.sha256(f"{text}|{mood}".encode("utf-8")).hexdigest() + ".wav"


def lines(data):
    """Every (category, text, mood) in lines.json, in file order, once each."""
    found = []

    def add(category, item):
        if isinstance(item, str):
            item = {"text": item, "mood": "steady"}
        found.append((category, item["text"].strip(), item.get("mood", "steady")))

    for category in ("pages", "deciphered", "places", "revisits"):
        for item in data.get(category, {}).values():
            add(category, item)
    for category in ("bored", "calls"):
        group = data.get(category, {})
        if isinstance(group, list):
            group = {"hope": group}
        for stage in ("hope", "doubt", "resolve"):
            for item in group.get(stage, []):
                add(category, item)
    for item in data.get("misread", []):
        add("misread", item)
    seen, unique = set(), []
    for category, text, mood in found:
        if (text, mood) not in seen:
            seen.add((text, mood))
            unique.append((category, text, mood))
    return unique


def words(text):
    return re.findall(r"[a-z0-9']+", text.lower().replace("’", "'"))


def wer(reference, heard):
    ref, hyp = words(reference), words(heard)
    row = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        prev, row[0] = row[0], i
        for j, h in enumerate(hyp, 1):
            prev, row[j] = row[j], min(row[j] + 1, row[j - 1] + 1, prev + (r != h))
    return row[len(hyp)] / max(len(ref), 1)


def level(samples, rate, target_db):
    import numpy as np
    window = max(1, int(rate * 0.05))
    power = np.convolve(samples.astype(np.float64) ** 2, np.ones(window) / window, mode="valid")
    gain = min(10 ** (target_db / 20) / max(float(np.sqrt(power.max())), 1e-8),
               0.95 / max(float(np.abs(samples).max()), 1e-8))
    return samples * gain


def trim(samples, rate, keep=0.06, floor_db=-45.0):
    import numpy as np
    loud = np.abs(samples) > 10 ** (floor_db / 20) * max(float(np.abs(samples).max()), 1e-8)
    idx = np.flatnonzero(loud)
    if idx.size == 0:
        return samples
    pad = int(rate * keep)
    return samples[max(idx[0] - pad, 0): idx[-1] + pad + 1]


class Qwen:
    """Qwen3-TTS: VoiceDesign speaks from a direction; Base clones the anchor."""

    def __init__(self):
        import torch
        from qwen_tts import Qwen3TTSModel
        self.torch = torch
        self.loader = Qwen3TTSModel
        self.kwargs = dict(device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
        self.design = Qwen3TTSModel.from_pretrained(str(HF / "VoiceDesign"), **self.kwargs)
        self.base = None
        self.prompt = None

    def speak(self, text, mood, seed):
        import numpy as np
        self.torch.manual_seed(seed)
        wavs, rate = self.design.generate_voice_design(
            text=text, language="English", instruct=f"{IDENTITY} {MOODS[mood][0]}")
        return np.asarray(wavs[0], dtype=np.float32).reshape(-1), int(rate)

    def clone(self, text, seed):
        import numpy as np
        if self.base is None:
            self.base = self.loader.from_pretrained(str(HF / "Base"), **self.kwargs)
            self.prompt = self.base.create_voice_clone_prompt(
                ref_audio=str(REF / "anchor.wav"), ref_text=ANCHOR_TEXT, x_vector_only_mode=False)
        self.torch.manual_seed(seed)
        wavs, rate = self.base.generate_voice_clone(
            text=text, language="English", voice_clone_prompt=self.prompt)
        return np.asarray(wavs[0], dtype=np.float32).reshape(-1), int(rate)


class Judge:
    """Whisper for the words, an ECAPA embedding for whether it is her."""

    def __init__(self):
        import torch
        # ctranslate2 finds cuDNN/cuBLAS in torch's own lib folder.
        os.add_dll_directory(str(Path(torch.__file__).parent / "lib"))
        import torchaudio
        from faster_whisper import WhisperModel
        from speechbrain.inference.speaker import EncoderClassifier
        from speechbrain.utils.fetching import LocalStrategy
        self.torch, self.torchaudio = torch, torchaudio
        self.asr = WhisperModel("large-v3-turbo", device="cuda", compute_type="int8_float16",
                                download_root=str(HF / "whisper"))
        self.ecapa = EncoderClassifier.from_hparams(
            source="speechbrain/spkrec-ecapa-voxceleb", savedir=str(HF / "ecapa"),
            run_opts={"device": "cuda"}, local_strategy=LocalStrategy.COPY)
        self.anchor = None

    def _16k(self, samples, rate):
        wave = self.torch.from_numpy(samples).float().unsqueeze(0)
        return self.torchaudio.functional.resample(wave, rate, 16000)

    def hear(self, samples, rate):
        wave = self._16k(samples, rate).squeeze(0).numpy()
        segments, _ = self.asr.transcribe(wave, language="en", beam_size=5)
        return " ".join(segment.text.strip() for segment in segments)

    def embed(self, samples, rate):
        with self.torch.no_grad():
            vector = self.ecapa.encode_batch(self._16k(samples, rate).cuda()).squeeze()
        return vector / vector.norm()

    def similarity(self, samples, rate):
        return float((self.embed(samples, rate) * self.anchor).sum())


def ensure_anchor(engine, judge, new, seed):
    import soundfile as sf
    path = REF / "anchor.wav"
    if new or not path.exists():
        REF.mkdir(parents=True, exist_ok=True)
        samples, rate = engine.speak(ANCHOR_TEXT, "steady", seed)
        sf.write(path, level(trim(samples, rate), rate, -12.0), rate, subtype="PCM_16")
        print(f"New anchor: {path}  (listen; re-roll with --new-anchor --anchor-seed N)")
    samples, rate = sf.read(path, dtype="float32")
    judge.anchor = judge.embed(samples, rate)


def best_take(engine, judge, text, mood):
    takes = []
    for take in range(TAKES):
        samples, rate = engine.speak(text, mood, seed=1000 + take)
        takes.append(("qwen-design", DESIGN_MODEL, trim(samples, rate), rate))
    scored = [score(judge, text, *take) for take in takes]
    if not any(s["wer"] <= MAX_WER and s["similarity"] >= MIN_SIMILARITY for s in scored):
        for take in range(CLONE_TAKES):
            samples, rate = engine.clone(text, seed=2000 + take)
            scored.append(score(judge, text, "qwen-clone", BASE_MODEL, trim(samples, rate), rate))
    good = [s for s in scored if s["wer"] <= MAX_WER]
    return max(good, key=lambda s: s["similarity"]) if good else min(scored, key=lambda s: s["wer"]), bool(good)


def score(judge, text, engine, model, samples, rate):
    heard = judge.hear(samples, rate)
    result = dict(engine=engine, model=model, samples=samples, rate=rate,
                  wer=wer(text, heard), similarity=judge.similarity(samples, rate), heard=heard)
    print(f"    {engine:12s} wer {result['wer']:.2f}  sim {result['similarity']:.2f}  | {heard}", flush=True)
    return result


def bake_kokoro(args, todo):
    import numpy as np
    import onnxruntime as ort
    from kokoro_onnx import Kokoro
    models = ROOT / "build/voice/models"
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    session = ort.InferenceSession(str(models / "kokoro-v1.0.int8.onnx"), sess_options=options,
                                   providers=["CPUExecutionProvider"])
    kokoro = Kokoro.from_session(session, str(models / "voices-v1.0.bin"))

    def speak(text, mood):
        samples, rate = kokoro.create(text, voice=args.voice, speed=args.speed, lang="en-us")
        return np.asarray(samples, dtype=np.float32), rate
    return speak


def self_test():
    assert clip_name("a", "b") == hashlib.sha256(b"a|b").hexdigest() + ".wav"
    assert wer("Mathilda... please.", "Mathilda, please") == 0.0
    assert wer("two cups", "two cups here") == 0.5
    assert wer("I'm not lifting that sheet", "im not lifting the sheet") > 0.0
    data = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    every = lines(data)
    assert len(every) == 62, len(every)
    assert all(mood in MOODS for _, _, mood in every)
    print("SELF-TEST PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--engine", choices=["qwen", "kokoro"], default="qwen")
    parser.add_argument("--force", action="store_true", help="Re-bake every line")
    parser.add_argument("--only", help="Re-bake only the line with exactly this text")
    parser.add_argument("--new-anchor", action="store_true", help="Render a new anchor voice")
    parser.add_argument("--anchor-seed", type=int, default=7)
    parser.add_argument("--anchor-only", action="store_true", help="Render the anchor and stop")
    parser.add_argument("--accept-bad", action="store_true", help="Keep the best take even above MAX_WER")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--voice", default="af_sarah", help="kokoro voice")
    parser.add_argument("--speed", type=float, default=0.92, help="kokoro speed")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    import numpy as np
    import soundfile as sf

    todo = lines(json.loads((OUT / "lines.json").read_text(encoding="utf-8")))
    manifest_path = OUT / "manifest.json"
    old = {}
    if manifest_path.exists():
        for clip in json.loads(manifest_path.read_text(encoding="utf-8")).get("clips", []):
            old[clip["file"]] = clip
    engine = judge = kokoro = None
    if args.engine == "qwen":
        engine, judge = Qwen(), Judge()
        ensure_anchor(engine, judge, args.new_anchor, args.anchor_seed)
        if args.anchor_only:
            return
    else:
        kokoro = bake_kokoro(args, todo)

    clips, bad, keep = [], [], set()
    for category, text, mood in todo:
        name = clip_name(text, mood)
        keep.add(name)
        target = OUT / name
        redo = (text == args.only) if args.only is not None else (args.force or not target.exists())
        if not redo:
            entry = old.get(name) or dict(text=text, mood=mood, file=name,
                                          seconds=float(sf.info(target).duration), engine="unknown")
            entry["category"] = category
            clips.append(entry)
            continue
        print(f"[{mood}] {text}", flush=True)
        if kokoro:
            samples, rate = kokoro(text, mood)
            result, ok = dict(engine="kokoro", model=args.voice, samples=trim(samples, rate), rate=rate,
                              wer=None, similarity=None), True
        else:
            result, ok = best_take(engine, judge, text, mood)
        if not ok:
            bad.append(text)
            if not args.accept_bad:
                print("    no take passed; skipped (re-run with --accept-bad to keep the best)")
                continue
        samples = level(result["samples"], result["rate"], MOODS[mood][1])
        if len(samples) == 0 or not np.isfinite(samples).all():
            raise ValueError(f"Invalid speech for {text!r}")
        sf.write(target, samples, result["rate"], subtype="PCM_16")
        clips.append(dict(text=text, mood=mood, category=category, file=name,
                          seconds=len(samples) / result["rate"], wer=result["wer"],
                          similarity=result["similarity"], engine=result["engine"], model=result["model"]))
    if args.only is None:
        for stale in OUT.glob("*.wav"):
            if stale.name not in keep:
                stale.unlink()
                imported = OUT / (stale.name + ".import")
                if imported.exists():
                    imported.unlink()
    manifest = {"engine": args.engine, "identity": IDENTITY, "clips": clips}
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Baked {len(clips)} clips into {OUT}")
    if bad:
        print("No take passed for:\n  " + "\n  ".join(bad))
        sys.exit(1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 6: Run the self-test again**

Run: `python tools/bake_speech.py --self-test`
Expected: `SELF-TEST PASS`.

- [ ] **Step 7: Render the anchor and stop for the user (GATE)**

Run: `build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --anchor-only`
Expected: `New anchor: …build/voice/ref/anchor.wav`.

**Stop. Ask the user to listen to `build/voice/ref/anchor.wav`** and say keep or re-roll. A re-roll runs `--anchor-only --new-anchor --anchor-seed <n>` with a new seed. Do not go on until the user keeps an anchor.

- [ ] **Step 8: Bake all 62 lines**

Run: `build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --force`
Expected: 62 entries with per-take WER and similarity, ending `Baked 62 clips`, exit 0. If a line fails, list it to the user. After they listen, re-bake it with `--only "<text>"`, or keep it with `--only "<text>" --accept-bad`.

- [ ] **Step 9: Import and probe the clips**

```powershell
godot-mono --headless --path . --import
$env:PROBE_CLIPS = "1"; godot-mono --headless --path . tools/voice_probe.tscn; Remove-Item Env:PROBE_CLIPS
```

Expected: `VOICE PASS` with a `PASS clip for:` line per line.

- [ ] **Step 10: The listening pass (GATE)**

Ask the user to play the game (or listen in `assets/audio/voice/` by manifest order) and name any lines that sound wrong. Re-bake those with `--only`. If many lines in one mood miss, soften that mood's direction in `MOODS` and re-bake with `--force`.

- [ ] **Step 11: Commit**

```bash
git add tools/bake_speech.py assets/audio/voice/
git commit -m "Bake her lines with Qwen3-TTS on the GPU, each acted to its mood, keeping the take Whisper hears right that sounds most like her."
```

---

### Task 8: Docs and the final check

**Files:**
- Modify: `docs/VOICE.md` (rewrite), `docs/DIRECTION.md` (pointer at the top)
- Modify: `CLAUDE.md`, `AGENTS.md`: the Voice paragraph; the UI paragraph (the journal, no objective); `RUN_JOURNAL` beside `RUN_MENU`; the `journal` action; the HUD's `show_journal_toast`

**Interfaces:** none.

- [ ] **Step 1: Rewrite `docs/VOICE.md`**

Cover, in plain prose:
- **The line file:** `lines.json`'s groups (pages, deciphered, places, revisits, bored/calls by stage, misread) and the seven moods.
- **Playback rules:** stage rules, priorities, the never-played interruption, calls (`Tune.CALL_*`) and the echo (`Tune.ECHO_*`).
- **Clip names:** sha256 of `text|mood`.
- **Baking:** the GPU setup commands from Task 7 Step 3, the anchor gate, `--force`, `--only`, `--accept-bad`, `--engine kokoro`, and the selection rule (4 takes, WER ≤ 0.15, highest ECAPA similarity, Base-clone fallback under 0.60).
- **Licences:** Qwen3-TTS Apache-2.0, faster-whisper MIT, SpeechBrain ECAPA Apache-2.0.
- **The drafter:** `tools/bake_voice.py` predates this format and overwrites `lines.json`, so don't run it.

- [ ] **Step 2: Update `CLAUDE.md` and `AGENTS.md` the same way**

- **Voice:** Kokoro becomes Qwen3-TTS on CUDA via `build/voice/gpu-venv`, with lines by mood and stage, priorities with forget-on-interrupt, and calls with the echo.
- **UI:** `Hud` creates `Journal`. No objective; a "journal notice" instead. Smudges come from `NoteCatalog` `{word}` markup, deciphered with `Game.decipher`, with keys from `Game.known`.
- **Game:** `Phase.JOURNAL`; `awake()` for systems that keep running in it.
- **Commands:** `RUN_JOURNAL=<title>` with `RUN_CAPTURE`; `tools/journal_probe.tscn` and `tools/voice_probe.tscn` in the probe list.

- [ ] **Step 3: Point `docs/DIRECTION.md` at the new story**

Under its first quote block, add:

```markdown
> The story is now the search for Mathilda (2026-10-06): see [the design](superpowers/specs/2026-10-06-mathilda-story-design.md). The HUD has no objective; pages are deciphered in the journal.
```

- [ ] **Step 4: Final verification**

```powershell
godot-mono --headless --path . --import
godot-mono --headless --path . tools/journal_probe.tscn
$env:PROBE_CLIPS = "1"; godot-mono --headless --path . tools/voice_probe.tscn; Remove-Item Env:PROBE_CLIPS
godot-mono --headless --path . tools/note_access_probe.tscn
godot-mono --headless --path . tools/house_space_probe.tscn
$env:RUN_CAPTURE = "1"; $env:RUN_SHOT = "$PWD\build\shots\final_play.png"; godot-mono --path .
$env:RUN_JOURNAL = "torn page"; $env:RUN_SHOT = "$PWD\build\shots\final_journal.png"; godot-mono --path .
Remove-Item Env:RUN_CAPTURE, Env:RUN_SHOT, Env:RUN_JOURNAL
```

Expected:
- `JOURNAL PASS`, `VOICE PASS`; the two existing probes pass as before.
- Both screenshots render: no objective plate, and the journal readable.
- No `SCRIPT ERROR` in any output.

- [ ] **Step 5: Commit**

```bash
git add docs/VOICE.md docs/DIRECTION.md
git commit -m "Document the journal, her staged and acted voice, and the GPU speech bake."
```

Report to the user any files left unstaged per Global Constraints (`scripts/tune.gd`, `CLAUDE.md`, `AGENTS.md`).
