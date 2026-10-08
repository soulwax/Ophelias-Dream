# Mathilda, part two: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the Jungian rewrite into the game: new page text, the turn-around ending, 137 lines in 14 moods with new triggers, the trees answering in her voice, and a fresh bake with Chatterbox cloned from per-mood impressions.

**Architecture:**
- **Script:** `docs/MATHILDA_STORY.md` is the script of record. A small tool turns its spoken script into `lines.json`, so the two can't drift apart.
- **Game:** `Game` gains `turned_around`, and `Player` gains `exhausted` / `landed_hard` signals and `facing()`.
- **Voice:** `Voice` gains line groups (memories, after, spent, cold, falls, turned, endings, answers) on the existing priority and forget-on-interrupt core.
- **Baking:** `bake_speech.py` gains a scrap/archive step, Qwen-rendered impressions, a Chatterbox engine and a review page.

**Tech Stack:** Godot 4.7.2 (`godot-mono`), GDScript; Python 3.12; `qwen-tts` (impressions, existing `build/voice/gpu-venv`); `chatterbox-tts` + `faster-whisper` + `speechbrain` (new `build/voice/cb-venv`), CUDA.

**Spec:** `docs/superpowers/specs/2026-10-06-mathilda-jungian-design.md`, with `docs/MATHILDA_STORY.md`.

## Global Constraints

- **GDScript style:** tabs, static typing, `class_name`, no preload. Run `godot-mono --headless --path . --import` after new class_name scripts.
- **Probes** are scene probes that count failures and `quit(1)` on any; no bare `assert()`.
- **Balance values** go in `Tune`. New constants:
  - `TURN_HOLD := 1.0`, `FALL_HARD := 7.5`, `MEMORY_GAP := 50.0`, `SPENT_GAP := 20.0`, `FALL_GAP := 15.0`
  - `COLD_AFTER := 120.0`, `COLD_GAP := 90.0`, `ENDING_DELAY := 1.2`, `ANSWER_DROP_DB := 6.0`, `ANSWER_ROAD_DELAY := 1.4`
- **The 14 moods:** steady, warm, hushed, shaken, breaking, resolve, calling, numb, bitter, pleading, wry, remembering, panicked, spent.
- **Priorities:** ending 4; page, deciphered and turned 3; place, revisit, spent and fall 2; bored, memory, call, misread and cold 1. Kinds that repeat: call, misread, spent, fall.
- **Clip names:** `sha256(text + "|" + mood).wav`.
- **Never delete a voice clip:** move it to `build/voice/archive/<date>/`.
- **Mathilda never speaks.** Answers are the protagonist's voice. No Jungian vocabulary in any player-facing text.
- **Commits:** one plain sentence, **no Co-Authored-By or attribution lines**. Stage only the task's files.
- **Impressions:** you (the user) said to go with my decisions. So the baker picks impressions automatically (steady by similarity to the existing approved `build/voice/ref/anchor.wav`, the rest by similarity to steady), and writes `build/voice/impressions.html` so any pick can be swapped later with `--pick mood=n`.

## Review Focus

1. **Turning around indoors or before the last page** must do nothing; holding glance-back in the cabin can't trigger the ending. Pinned in Task 2 (`_watch_turn` with glance held and no last page; `turn_around()` refusals).
2. **An ending line cut off or restarted.** Restarting during the ending speech must not leave a delayed answer that plays in the next run. The ending and road-answer timers carry a ticket that `BOOT` invalidates. Pinned in Task 3.
3. **The cold with no weather** (probes, or capture runs) must not crash. `Game.weather == null` means no cold lines. Pinned in Task 3.
4. **The script and the data drifting apart.** `tools/script_to_lines.py --check` fails if `lines.json` doesn't match the doc. Pinned in Task 3 and run in Task 6.
5. **Missing clips** (text-only mode). Every new group must still show its subtitle for its length, and answers must fall back to the plain echo or a subtitle. Pinned in Task 3 (headless probes run without clips).

---

### Task 1: The pages and the intro

**Files:**
- Modify: `scripts/notes/note_catalog.gd` (bodies and betweens only)
- Modify: `scripts/ui/hud.gd` (`_build_intro`)
- Test: `tools/journal_probe.gd`

**Interfaces:** Titles, smudges, readings and keys stay unchanged. `NoteCatalog.LAST_TITLE` stays `"don't turn around"`.

- [ ] **Step 1: Add failing text checks** to `_catalog()` in `tools/journal_probe.gd`:

```gdscript
	var by_title := {}
	for entry in NoteCatalog.everything():
		by_title[entry.title] = entry
	_check(by_title["by the bed"].body.contains("You said go, so I am going."), "the bed page knows about the argument")
	_check(by_title["the handwriting changes"].body.contains("fix the latch. tell her."), "the fridge list ends with tell her")
	_check(by_title["intake"].body.contains("one coat, buttoned to the throat") and by_title["intake"].body.contains("Cause: exposure."), "the intake lists the coat")
	_check(by_title["intake"].between == "Note: the coat held its shape after the sheet was lifted.", "the coat held its shape")
	_check(by_title[NoteCatalog.LAST_TITLE].body.contains("forgive me for going."), "the last page forgives")
	_check(by_title[NoteCatalog.LAST_TITLE].between.contains("the sheet is the coat."), "the sheet is the coat")
```

- [ ] **Step 2: Run** `godot-mono --headless --path . tools/journal_probe.tscn`. Expected: these FAIL; exit 1.

- [ ] **Step 3: Replace each page body and between** in `scripts/notes/note_catalog.gd` with the text in `docs/MATHILDA_STORY.md` → *The seven pages*, keeping every `{word}` exactly as it is, and `\n\n` between paragraphs. The between-the-lines strings change for *on the post* (`"It called me by your name. For a second, I answered to it."`), *don't turn around* (`"the sheet in the cellar is not me. it is the coat. say it back to me. the sheet is the coat."`) and *intake* (`"Note: the coat held its shape after the sheet was lifted."`); the others stay.

- [ ] **Step 4: Intro card.** In `scripts/ui/hud.gd` `_build_intro()`, change `card.offset_top = -100` / `offset_bottom = 100` to `-118` / `118`, and after `box.add_child(line)` add:

```gdscript
	var told := UiChrome.label("You told her to.", 15, Color(UiChrome.MUTED, 0.75))
	told.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(told)
```

- [ ] **Step 5: Run** the probe. Expected: `JOURNAL PASS`.

- [ ] **Step 6: Commit** `scripts/notes/note_catalog.gd scripts/ui/hud.gd tools/journal_probe.gd`: "Rewrite Mathilda's pages around the argument, the coat and the list that ends with tell her, and add the line that says she told her to go."

---

### Task 2: Turning around, and the third ending

**Files:**
- Modify: `scripts/game/game.gd`, `scripts/player/player.gd`, `scripts/tune.gd`, `scripts/ui/end_card.gd`, `scripts/main.gd`
- Test: `tools/journal_probe.gd`

**Interfaces (produces):**
- `Game.turned_around: bool`, `signal turned`, `Game.turn_around()`, `Game._watch_turn(delta)`, `Game.dev_ending(kind: String)`
- `Player.exhausted` and `Player.landed_hard(fall_speed: float)` signals, and `Player.facing() -> float` (yaw of her body; forward is `Basis(UP, facing) * -Z`)
- `Tune.TURN_HOLD`, `Tune.FALL_HARD`
- calls `voice.turned()`, which Task 3 adds; guarded with `has_method` until then

- [ ] **Step 1: Failing probe.** Add `_turning()` to `_run()` in `tools/journal_probe.gd`:

```gdscript
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
```

- [ ] **Step 2: Run**; expect parse errors (`turned`, `turn_around`); exit 1.

- [ ] **Step 3: `Tune`.** After `LIGHTS_NEAR` add:

```gdscript
# After the last page, holding glance-back this long (s) outdoors is turning around.
const TURN_HOLD := 1.0
# A landing at least this fast (m/s) is a fall she remarks on.
const FALL_HARD := 7.5
```

- [ ] **Step 4: `Player`.**
  - Under `signal stepped(left: bool)` add `signal exhausted` and `signal landed_hard(fall_speed: float)`.
  - In the sprint block, after `exhaust_left = Tune.EXHAUST_LOCK` (the one followed by `_stumble()`), add `exhausted.emit()`.
  - At the top of `_land(fall_speed)`, add `if fall_speed >= Tune.FALL_HARD: landed_hard.emit(fall_speed)`.
  - Add:

```gdscript
## The way her body faces (yaw); forward is Basis(Vector3.UP, facing()) * Vector3.FORWARD.
func facing() -> float:
	return _facing
```

- [ ] **Step 5: `Game`.**
  - Add `signal turned` beside the journal signals.
  - Add vars:

```gdscript
# She looked back after the last page: one set of prints (EndCard, Voice).
var turned_around := false
var _turn_hold := 0.0
```

  - In `reset()`: `turned_around = false` and `_turn_hold = 0.0`.
  - In `_process`, after the `visit(place_at(...))` block: `if phase == Phase.PLAYING and player: _watch_turn(delta)`.
  - Add:

```gdscript
# Holding glance-back after the last page, outdoors, is turning around.
func _watch_turn(delta: float) -> void:
	if turned_around or not read_last_page or player == null or player.glance < 0.9 \
			or indoors(player.global_position + Vector3.UP * 0.9):
		_turn_hold = 0.0
		return
	_turn_hold += delta
	if _turn_hold >= Tune.TURN_HOLD:
		turn_around()


func turn_around() -> void:
	if turned_around or not read_last_page:
		return
	if player and indoors(player.global_position + Vector3.UP * 0.9):
		return
	turned_around = true
	_turn_hold = 0.0
	mark("turned around")
	turned.emit()
	if voice and voice.has_method("turned"):
		voice.turned()


## Dev hook (RUN_ENDING=road|prints): reach the lights, turned around or not.
func dev_ending(kind: String) -> void:
	read_last_page = true
	turned_around = kind == "prints"
	escape()
```

- [ ] **Step 6: `EndCard`.** Replace the `Game.Phase.ESCAPED:` branch with:

```gdscript
		Game.Phase.ESCAPED:
			if Game.turned_around:
				var prints := "You turned around. One set of prints, all the way back to the lit cabin. You get in on the driver's side; the seat is warm because it was always yours."
				if Game.all_deciphered():
					prints += " On the dash, two cups, one fitted inside the other."
				_show("One set of prints", prints, "Walk the ridge again")
			else:
				var road := "The engine is running. The driver's door is open, the seat still warm."
				if Game.read_last_page:
					road += " You didn't turn around."
				if Game.all_deciphered():
					road += " Beside the cup on the dash, a second one. Still warm."
				_show("The road", road, "Walk the ridge again")
```

- [ ] **Step 7: Dev hook.** In `scripts/main.gd`, after the `RUN_JOURNAL` block:

```gdscript
		# Dev hook: RUN_ENDING=road|prints shows that escape card.
		var ending_kind := OS.get_environment("RUN_ENDING")
		if ending_kind != "":
			Game.dev_ending.call_deferred(ending_kind)
```

- [ ] **Step 8: Run** `godot-mono --headless --path . tools/journal_probe.tscn`. Expected: `JOURNAL PASS`.

- [ ] **Step 9: Commit** `game.gd player.gd end_card.gd main.gd journal_probe.gd` (plus `tune.gd`): "Let her turn around after the last page, and end on one set of prints when she does."

---

### Task 3: Her script, its triggers, and the trees answering

**Files:**
- Modify: `docs/MATHILDA_STORY.md` (make the answers section parseable)
- Create: `tools/script_to_lines.py`
- Modify: `assets/audio/voice/lines.json` (generated)
- Modify: `scripts/player/voice.gd`, `scripts/tune.gd`
- Test: `tools/voice_probe.gd`

**Interfaces (produces on `Voice`):**
- `MOODS` (14), `REPEATS`, `AFTER`
- `turned()`, `out_of_breath()`, `fell(fall_speed: float)`
- `_memory_tick(outdoors: bool, speed: float)`, `_cold_tick(outdoors: bool)`, `_speak_ending(ticket: int)`, `_answer_road(ticket: int)`, `_behind(distance: float) -> Vector3`
- groups `_memories`, `_spent`, `_cold`, `_falls`, `_turned`, `_endings`, `_answers`, and `_bored["after"]`

- [ ] **Step 1: Make the answers parseable.** In `docs/MATHILDA_STORY.md` → *The trees answer*, after the explanatory bullets, add:

```markdown
Lines:

- **doubt:** [bitter] Go, then!
- **resolve:** [hushed] I'm right behind you.
- **road:** [warm] Okay.
```

- [ ] **Step 2: Write `tools/script_to_lines.py`.** It parses the *Spoken script* section into the `lines.json` shape and prints the counts. With `--check` it exits 1 when `lines.json` differs.

```python
"""Turn the spoken script in docs/MATHILDA_STORY.md into assets/audio/voice/lines.json.

The story doc is the script of record. `--check` exits 1 if lines.json differs.
"""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs/MATHILDA_STORY.md"
OUT = ROOT / "assets/audio/voice/lines.json"
# Section heading -> (group, shape): keyed (id: line), staged (stage: [lines]), flat [lines], single line.
SECTIONS = {
    "Page reactions": ("pages", "keyed"),
    "Deciphered pages": ("deciphered", "keyed"),
    "First visits": ("places", "keyed"),
    "Revisits": ("revisits", "keyed"),
    "Idle thoughts": ("bored", "staged"),
    "Memories": ("memories", "staged"),
    "Calls into the storm": ("calls", "staged"),
    "When she runs out of breath": ("spent", "flat"),
    "The cold": ("cold", "flat"),
    "Falls": ("falls", "flat"),
    "Turning around": ("turned", "single"),
    "The trees answer": ("answers", "keyed"),
    "Rejected readings in the journal": ("misread", "flat"),
    "Over the end card": ("endings", "keyed"),
}
STAGE = {"hope": "hope", "doubt": "doubt", "resolve": "resolve", "after": "after"}
ENDING_IDS = {"the road": "road", "one set of prints": "prints"}
# Per-line delivery overrides for the baker; the game ignores them.
OVERRIDES = {"Go, then!": {"exaggeration": 0.9}}
KEYED = re.compile(r"^- \*\*(.+?):\*\* \[([a-z]+)\] (.+)$")
PLAIN = re.compile(r"^- \[([a-z]+)\] (.+)$")


def parse(text):
    script = text.split("## Spoken script", 1)[1]
    data, group, shape, stage = {}, None, None, None
    for raw in script.splitlines():
        line = raw.strip()
        if line.startswith("### "):
            title = line[4:]
            group, shape = next((v for k, v in SECTIONS.items() if title.startswith(k)), (None, None))
            stage = None
            if group and group not in data:
                data[group] = [] if shape == "flat" else {}
            continue
        if line.startswith("**") and shape == "staged":
            word = line[2:].split("**", 1)[0].split()[0].lower()
            stage = STAGE.get(word)
            if stage:
                data[group].setdefault(stage, [])
            continue
        if not group or not line.startswith("- "):
            continue
        keyed, plain = KEYED.match(line), PLAIN.match(line)
        if shape == "keyed" and keyed:
            key = keyed.group(1)
            key = ENDING_IDS.get(key.lower(), key)
            data[group][key] = entry(keyed.group(3), keyed.group(2))
        elif plain and shape == "staged" and stage:
            data[group][stage].append(entry(plain.group(2), plain.group(1)))
        elif plain and shape == "flat":
            data[group].append(entry(plain.group(2), plain.group(1)))
        elif plain and shape == "single":
            data[group] = entry(plain.group(2), plain.group(1))
    return data


def entry(text, mood):
    item = {"text": text.strip(), "mood": mood}
    item.update(OVERRIDES.get(item["text"], {}))
    return item


def count(data):
    total = 0
    for value in data.values():
        if isinstance(value, list):
            total += len(value)
        elif "text" in value:
            total += 1
        else:
            total += sum(len(v) if isinstance(v, list) else 1 for v in value.values())
    return total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = parse(DOC.read_text(encoding="utf-8"))
    rendered = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    print(f"{count(data)} lines: " + ", ".join(f"{k} {count({k: v})}" for k, v in data.items()))
    if args.check:
        same = OUT.exists() and json.loads(OUT.read_text(encoding="utf-8")) == data
        print("lines.json matches the script" if same else "lines.json differs from the script")
        sys.exit(0 if same else 1)
    OUT.write_text(rendered, encoding="utf-8")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Generate and check it.** Run `python tools/script_to_lines.py` and then `python tools/script_to_lines.py --check`. Expected:
  - the first prints `137 lines: pages 7, deciphered 7, places 11, revisits 11, bored 36, memories 15, calls 15, spent 8, cold 6, falls 5, turned 1, answers 3, misread 10, endings 2`
  - the second prints "matches", exit 0

  If any count is off, fix the doc's formatting (not the tool) until it matches.

- [ ] **Step 4: Failing probe.** In `tools/voice_probe.gd`:
  - replace `_all_lines()` and `_lines()` with the versions below
  - add `_moments()` and `_answers()` to `_run()` after `_calls()`, and reset `Game.read_pages`/`Game.turned_around` at the start of each

```gdscript
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
	_check(voice._places.size() == 11 and voice._revisits.size() == 11, "eleven places, eleven revisits")
	for stage in Voice.STAGES:
		_check(voice._bored[stage].size() == 10, "ten idle lines for " + stage)
		_check(voice._memories[stage].size() == 5, "five memories for " + stage)
		_check(voice._calls[stage].size() == 5, "five calls for " + stage)
	_check(voice._bored[Voice.AFTER].size() == 6, "six idle lines after turning around")
	_check(voice._misread.size() == 10 and voice._spent.size() == 8 and voice._cold.size() == 6 and voice._falls.size() == 5, "misreads, breath, cold, falls")
	_check(not voice._turned.is_empty() and voice._endings.size() == 2 and voice._answers.size() == 3, "turning, endings, answers")
	var every := _all_lines()
	_check(every.size() == 137, "137 lines in all (%d)" % every.size())
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
	var stale := voice._ending_ticket
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
```

- [ ] **Step 5: Run**: `godot-mono --headless --path . tools/voice_probe.tscn`. Expected: FAIL / parse errors; exit 1.

- [ ] **Step 6: `Tune`.** After `ECHO_MAX` add:

```gdscript
# Memories wait this long (s) after any line, and only while she walks outdoors.
const MEMORY_GAP := 50.0
# Breath and fall lines repeat at most this often (s).
const SPENT_GAP := 20.0
const FALL_GAP := 15.0
# The cold gets to her after this long (s) outdoors in a hard gust or whiteout, then not again for COLD_GAP.
const COLD_AFTER := 120.0
const COLD_GAP := 90.0
# Her line over the escape card waits this long (s); at the road, the answer waits ANSWER_ROAD_DELAY after it.
const ENDING_DELAY := 1.2
const ANSWER_ROAD_DELAY := 1.4
# The trees' answer is this much quieter (dB) than her call.
const ANSWER_DROP_DB := 6.0
```

- [ ] **Step 7: Extend `scripts/player/voice.gd`.** All edits sit on the existing structure.

1. **Header comment:** add a sentence: "The trees answer in her own voice (answers); Mathilda never speaks."
2. **Constants.** Replace `PRIORITY` and `MOODS`, and add `AFTER` and `REPEATS`:

```gdscript
const PRIORITY := {"ending": 4, "page": 3, "deciphered": 3, "turned": 3, "place": 2, "revisit": 2,
	"spent": 2, "fall": 2, "bored": 1, "memory": 1, "call": 1, "misread": 1, "cold": 1}
# After she turns around her idle thoughts come from this stage, and she stops calling.
const AFTER := "after"
const MOODS := ["steady", "warm", "hushed", "shaken", "breaking", "resolve", "calling",
	"numb", "bitter", "pleading", "wry", "remembering", "panicked", "spent"]
# These may play again; every other line plays once per run.
const REPEATS := ["call", "misread", "spent", "fall"]
```

3. **Vars.** `_bored` gains `"after": []`, and `_bored_at` gains `"after": 0`. Add:

```gdscript
var _memories := {"hope": [], "doubt": [], "resolve": []}
var _memory_at := {"hope": 0, "doubt": 0, "resolve": 0}
var _spent: Array = []
var _cold: Array = []
var _falls: Array = []
var _turned := {}
var _endings := {}
var _answers := {}
var _cold_at := 0
var _cold_next := 0.0
var _outdoor_time := 0.0
var _spent_at := -99.0
var _fall_at := -99.0
var _ending_ticket := 0
```

4. **`_ready()`.** After `Game.phase_changed.connect(_on_phase)`:

```gdscript
	if Game.player:
		Game.player.exhausted.connect(out_of_breath)
		Game.player.landed_hard.connect(fell)
```

5. **`stage()`:**

```gdscript
func stage() -> String:
	if Game.turned_around:
		return AFTER
	return Voice.stage_for(Game.notes_found, Game.read_last_page)
```

6. **`_on_phase()`:**

```gdscript
func _on_phase(next: int) -> void:
	if next in [Game.Phase.BOOT, Game.Phase.CAUGHT, Game.Phase.ESCAPED]:
		_interrupt()
		_cancel_echo()
		_ending_ticket += 1
	if next != Game.Phase.PLAYING and _echo:
		_echo.stop()
	if next == Game.Phase.ESCAPED and is_inside_tree():
		get_tree().create_timer(Tune.ENDING_DELAY).timeout.connect(_speak_ending.bind(_ending_ticket))


func _cancel_echo() -> void:
	_pending_echo_stage = ""
	_echo_ticket += 1
	if _echo:
		_echo.stop()
```

7. **`_finished()`.** Before `_current = {}` add:

```gdscript
	if not _current.is_empty() and str(_current.get("kind", "")) == "ending" \
			and str(_current.get("id", "")) == "road" and not Game.turned_around and is_inside_tree():
		get_tree().create_timer(Tune.ANSWER_ROAD_DELAY).timeout.connect(_answer_road.bind(_ending_ticket))
```

8. **`_tick_outdoors()`:**

```gdscript
func _tick_outdoors(delta: float) -> void:
	var outdoors := not Game.indoors(Game.player.global_position + Vector3.UP * 0.9)
	_call_tick(delta, outdoors)
	_outdoor_time = _outdoor_time + delta if outdoors else 0.0
	_memory_tick(outdoors, Vector2(Game.player.velocity.x, Game.player.velocity.z).length())
	_cold_tick(outdoors)
```

9. **`_call_tick()`.** Its first guard becomes `if Game.turned_around or not outdoors or (_calls.get(now, []) as Array).is_empty(): return`.

10. **`_wants_echo()`.** Prepend `not Game.turned_around and` to the expression.

11. **`_schedule_echo` and `_play_echo`** are replaced by:

```gdscript
func _schedule_echo(line: Dictionary) -> void:
	var now := str(line.stage)
	var answer: Dictionary = _answers.get(now, {})
	var spoken := _clip(answer) if not answer.is_empty() else null
	# The second answer comes from right behind her, not from the trees.
	var close := spoken != null and now == "resolve"
	var stream := spoken if spoken else _clip(line)
	if stream == null:
		return
	if spoken == null:
		answer = {}
	var at := Vector3.ZERO
	if not close:
		if Game.trail == null or Game.trail.flora == null:
			return
		at = Voice.echo_from(Game.player.global_position, Game.trail.flora.tree_positions())
		if at == Vector3.INF:
			return
	_pending_echo_stage = now
	_echo_ticket += 1
	get_tree().create_timer(randf_range(1.6, 2.4), false).timeout.connect(
		_play_echo.bind(stream, at, _echo_ticket, now, answer, close))


# Her own voice, back from the trees or from right behind her. Never Mathilda's.
func _play_echo(stream: AudioStream, at: Vector3, ticket: int, echo_stage: String, answer := {}, close := false) -> void:
	if ticket != _echo_ticket:
		return
	_pending_echo_stage = ""
	if Game.phase != Game.Phase.PLAYING or Game.turned_around or Game.indoors(Game.player.global_position + Vector3.UP * 0.9):
		return
	_echoed[echo_stage] = true
	_echoes += 1
	_echo.stream = stream
	_echo.global_position = _behind(1.4) if close else at
	if answer.is_empty():
		Loudness.place(_echo, Tune.CALL_SPL - Tune.ECHO_DROP_DB, true)
	elif close:
		Loudness.place(_echo, Tune.VOICE_SPL, false)
	else:
		Loudness.place(_echo, Tune.CALL_SPL - Tune.ANSWER_DROP_DB, true)
	_echo.play()
	if not answer.is_empty():
		Game.murmur_line("…" + str(answer.text))
		Game.murmur_left = stream.get_length() + 0.6
	Game.heard("echo")


func _behind(distance: float) -> Vector3:
	var back := Basis(Vector3.UP, Game.player.facing()) * Vector3(0.0, 0.0, distance)
	return Game.player.global_position + back + Vector3.UP * 1.55
```

12. **New entry points and ticks** (after `misread()`):

```gdscript
## She turned around (Game.turn_around): she says so, and nothing answers again.
func turned() -> void:
	_cancel_echo()
	if _active and not _turned.is_empty():
		_say(_turned)


## The sprint ran her out of breath (Player.exhausted).
func out_of_breath() -> void:
	if not _active or _spent.is_empty() or _clock - _spent_at < Tune.SPENT_GAP or Game.phase != Game.Phase.PLAYING:
		return
	_say(_spent[randi() % _spent.size()])


## A hard landing (Player.landed_hard).
func fell(_fall_speed: float) -> void:
	if not _active or _falls.is_empty() or _clock - _fall_at < Tune.FALL_GAP or Game.phase != Game.Phase.PLAYING:
		return
	_say(_falls[randi() % _falls.size()])


func _memory_tick(outdoors: bool, speed: float) -> void:
	var now := stage()
	if not outdoors or speed < 1.0 or _busy() or _since < Tune.MEMORY_GAP or not _memories.has(now):
		return
	var lines: Array = _memories[now]
	var index := int(_memory_at[now])
	if index < lines.size():
		_say(lines[index])


func _cold_tick(outdoors: bool) -> void:
	if not outdoors or _outdoor_time < Tune.COLD_AFTER or _clock < _cold_next or _busy() or _cold_at >= _cold.size():
		return
	var weather := Game.weather
	if weather == null or (weather.whiteout <= 0.5 and weather.gust <= 0.6):
		return
	if _say(_cold[_cold_at]):
		_cold_next = _clock + Tune.COLD_GAP


func _speak_ending(ticket: int) -> void:
	if ticket != _ending_ticket or Game.phase != Game.Phase.ESCAPED or not _active:
		return
	var line: Dictionary = _endings.get("prints" if Game.turned_around else "road", {})
	if not line.is_empty():
		_say(line)


# At the road, after her plea: "Okay.", from behind the car, in her own voice.
func _answer_road(ticket: int) -> void:
	if ticket != _ending_ticket or Game.phase != Game.Phase.ESCAPED or Game.turned_around:
		return
	var line: Dictionary = _answers.get("road", {})
	if line.is_empty():
		return
	var stream := _clip(line)
	if stream:
		_echo.stream = stream
		_echo.global_position = _behind(3.0)
		Loudness.place(_echo, Tune.VOICE_SPL - 3.0, false)
		_echo.play()
	Game.murmur_line("…" + str(line.text))
	if stream:
		Game.murmur_left = stream.get_length() + 0.6
```

13. **`_say()`.** `var once := kind != "call" and kind != "misread"` becomes `var once := not REPEATS.has(kind)`.

14. **`_mark()`.** Add cases:

```gdscript
		"memory":
			_memory_at[line.stage] = maxi(int(_memory_at[line.stage]), int(line.index) + 1)
		"cold":
			_cold_at = maxi(_cold_at, int(line.index) + 1)
		"spent":
			_spent_at = _clock
		"fall":
			_fall_at = _clock
```

15. **`_forget()`.** Add cases:

```gdscript
		"memory":
			_memory_at[line.stage] = mini(int(_memory_at[line.stage]), int(line.index))
		"cold":
			_cold_at = mini(_cold_at, int(line.index))
```

16. **`_load()`** is replaced by:

```gdscript
func _load() -> void:
	var data := Voice.read_lines()
	for pair in [["pages", _pages, "page"], ["deciphered", _deciphered, "deciphered"],
			["places", _places, "place"], ["revisits", _revisits, "revisit"],
			["endings", _endings, "ending"], ["answers", _answers, "answer"]]:
		var group: Variant = data.get(pair[0], {})
		if typeof(group) == TYPE_DICTIONARY:
			for id in group:
				(pair[1] as Dictionary)[id] = Voice._parse(group[id], pair[2], str(id))
	for pair in [["bored", _bored, "bored"], ["memories", _memories, "memory"], ["calls", _calls, "call"]]:
		var group: Variant = data.get(pair[0], {})
		# The old format kept one flat list of idle lines.
		if typeof(group) == TYPE_ARRAY:
			group = {"hope": group}
		if typeof(group) != TYPE_DICTIONARY:
			continue
		for stage in (pair[1] as Dictionary).keys():
			var list: Array = (group as Dictionary).get(stage, [])
			for index in list.size():
				((pair[1] as Dictionary)[stage] as Array).append(Voice._parse(list[index], pair[2], "%s/%d" % [stage, index], stage, index))
	for pair in [["misread", _misread, "misread"], ["spent", _spent, "spent"], ["cold", _cold, "cold"], ["falls", _falls, "fall"]]:
		var list: Variant = data.get(pair[0], [])
		if typeof(list) == TYPE_ARRAY:
			for index in (list as Array).size():
				(pair[1] as Array).append(Voice._parse(list[index], pair[2], str(index), "", index))
	if typeof(data.get("turned")) == TYPE_DICTIONARY:
		_turned = Voice._parse(data["turned"], "turned", "turned")
```

- [ ] **Step 8: Run both probes**, `tools/voice_probe.tscn` and `tools/journal_probe.tscn`. Expected: `VOICE PASS` and `JOURNAL PASS`. In Task 2 `turn_around()` used `has_method("turned")`, which is now true, so that guard can simplify to `if voice:`. Make that change.

- [ ] **Step 9: Commit** `docs/MATHILDA_STORY.md tools/script_to_lines.py assets/audio/voice/lines.json scripts/player/voice.gd scripts/game/game.gd tools/voice_probe.gd`: "Give her 137 lines generated from the story script, with memories, breath, cold, falls, an after-turning stage, spoken endings, and the trees answering in her own voice."

---

### Task 4: The baker: scrap, impressions, Chatterbox, review

**Files:**
- Modify: `tools/bake_speech.py` (rewrite)
- Environment: create `build/voice/cb-venv`

**Interfaces:**
- **Command lines:**
  - `bake_speech.py --self-test`
  - `--scrap`
  - `--impressions [--moods m1,m2] [--candidates 4] [--pick mood=n]` (run in `gpu-venv`)
  - bake: `[--force] [--only TEXT] [--mood M] [--accept-bad]` (run in `cb-venv`)
  - `--engine chatterbox|kokoro`
- **Outputs:** clips in `assets/audio/voice/`; `build/voice/ref/<mood>.wav`; `build/voice/ref/candidates/<mood>_<n>.wav`; `build/voice/impressions.html`; `build/voice/review.html`; archives in `build/voice/archive/<YYYY-MM-DD>[-label]/`.

- [ ] **Step 1: Create the Chatterbox environment and confirm its API**

```powershell
uv venv build/voice/cb-venv --python 3.12
$env:HF_HOME = "$PWD\build\voice\hf\cache"
uv pip install --python build/voice/cb-venv/Scripts/python.exe chatterbox-tts faster-whisper speechbrain soundfile numpy
build/voice/cb-venv/Scripts/python.exe -c "import torch; print(torch.__version__)"
```

Read the torch version Chatterbox pinned (for example `2.6.0`), then reinstall that version from the matching CUDA index. For 2.6.0 that is cu124:

```powershell
uv pip install --python build/voice/cb-venv/Scripts/python.exe --reinstall "torch==<pinned>" "torchaudio==<pinned>" --index-url https://download.pytorch.org/whl/cu124
build/voice/cb-venv/Scripts/python.exe -c "import torch; print(torch.__version__, torch.cuda.is_available())"
build/voice/cb-venv/Scripts/python.exe -c "from chatterbox.tts import ChatterboxTTS as C; import inspect; print(inspect.signature(C.generate)); print(inspect.signature(C.from_pretrained))"
```

Expected: a `+cu12x` version, `True`, and `generate(self, text, ..., audio_prompt_path=None, exaggeration=..., cfg_weight=..., temperature=...)`. If the names differ, adapt only `class Chatter` in Step 2.

- [ ] **Step 2: Rewrite `tools/bake_speech.py`.** Keep `clip_name`, `words`, `wer`, `level`, `trim`, `Judge` (unchanged) and the Kokoro path. Replace the rest as follows.

**Constants:**

```python
ARCHIVE = ROOT / "build/voice/archive"
CANDIDATES = REF / "candidates"
# Mood: direction (for impressions), impression text, Chatterbox exaggeration, cfg_weight, temperature, level dBFS.
MOODS = {
    "steady": ("Calm and even, talking herself into calm.", "Okay. The kettle's on, the door's shut, the lantern's lit. Everything is where it should be. I'm fine.", 0.45, 0.50, 0.80, -12.0),
    "warm": ("Tender and fond, almost smiling, a catch at the end.", "You always do this. You show up late with snow in your hair and you think a smile fixes it. ...It does, a bit.", 0.55, 0.45, 0.80, -12.0),
    "hushed": ("Barely above a whisper, close and careful, as if something might hear.", "Shh. Don't move. If we stay very still, maybe it won't hear us breathing.", 0.35, 0.55, 0.70, -18.0),
    "shaken": ("Unsteady, breath short, words coming a little too fast.", "I don't... I don't understand, it was right here, I put it right here, I know I did.", 0.70, 0.40, 0.85, -12.0),
    "breaking": ("On the edge of tears, voice cracking, pauses where it gives out.", "I'm sorry. I'm so sorry. I didn't mean it, I never meant any of it, please come back.", 0.85, 0.35, 0.90, -13.0),
    "resolve": ("Low and determined, jaw set, each word placed.", "No. I'm not stopping. Not now. I'll walk until there's nowhere left to walk.", 0.55, 0.45, 0.75, -12.0),
    "calling": ("Shouting as loud as she can into a strong wind, straining, desperate.", "Can you hear me? Hello? I'm over here! Over here!", 1.00, 0.30, 0.85, -9.0),
    "numb": ("Flat, slow and far away, the feeling gone out of her voice.", "It doesn't hurt any more. That's the strange part. Nothing hurts. It's all very far away.", 0.25, 0.60, 0.60, -15.0),
    "bitter": ("Hurt turned into anger, clipped, a little too loud, then quiet.", "Oh, of course. Of course you did. You always get to leave, and I always get to clean up after.", 0.75, 0.40, 0.85, -11.0),
    "pleading": ("Small and begging, bargaining with something that isn't listening.", "Please. I'll do anything. Just this once. Just let her be all right, and I won't ask for anything else.", 0.70, 0.35, 0.85, -13.0),
    "wry": ("Dark humour under her breath, half a laugh, to keep from crying.", "Well. That went about as well as everything else today. Brilliant. Really.", 0.50, 0.45, 0.85, -13.0),
    "remembering": ("Soft and slow, looking at something far away, a smile that hurts.", "We used to skate on the lake when it froze. She'd hold my hands and go backwards, laughing, the whole way across.", 0.40, 0.50, 0.75, -14.0),
    "panicked": ("Fast and breathless, words tripping over each other.", "No no no, where is it, where did it go, I can't, I can't breathe, where is it...", 0.95, 0.30, 0.95, -11.0),
    "spent": ("Completely out of breath, gasping between the words.", "Wait... wait... I just... I need... one second. Okay. Okay.", 0.80, 0.35, 0.90, -13.0),
}
TAKES = 3
MAX_WER = 0.15
```

**`lines(data)`** returns `(category, text, mood, overrides)` for every group:

```python
def lines(data):
    """Every (category, text, mood, overrides) in lines.json, once each."""
    found = []

    def add(category, item):
        if isinstance(item, str):
            item = {"text": item, "mood": "steady"}
        extra = {k: item[k] for k in ("exaggeration", "cfg", "temperature") if k in item}
        found.append((category, item["text"].strip(), item.get("mood", "steady"), extra))

    for category in ("pages", "deciphered", "places", "revisits", "endings", "answers"):
        for item in data.get(category, {}).values():
            add(category, item)
    for category in ("bored", "memories", "calls"):
        group = data.get(category, {})
        if isinstance(group, list):
            group = {"hope": group}
        for stage in ("hope", "doubt", "resolve", "after"):
            for item in group.get(stage, []):
                add(category, item)
    for category in ("misread", "spent", "cold", "falls"):
        for item in data.get(category, []):
            add(category, item)
    if isinstance(data.get("turned"), dict):
        add("turned", data["turned"])
    seen, unique = set(), []
    for entry in found:
        if (entry[1], entry[2]) not in seen:
            seen.add((entry[1], entry[2]))
            unique.append(entry)
    return unique
```

**Archive:**

```python
def archive(paths, label=""):
    """Move clips (with their .import files) out of the game, never deleting them."""
    import datetime
    import shutil
    target = ARCHIVE / (datetime.date.today().isoformat() + (f"-{label}" if label else ""))
    target.mkdir(parents=True, exist_ok=True)
    for path in paths:
        for item in (path, path.with_name(path.name + ".import")):
            if item.exists():
                shutil.move(str(item), str(target / item.name))
    return target
```

**Qwen, impressions only:**

```python
class Qwen:
    """Qwen3-TTS VoiceDesign, used only to perform the per-mood impressions."""

    def __init__(self):
        import torch
        from qwen_tts import Qwen3TTSModel
        self.torch = torch
        self.design = Qwen3TTSModel.from_pretrained(
            str(HF / "VoiceDesign"), device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")

    def perform(self, mood, count):
        import numpy as np
        direction, text = MOODS[mood][0], MOODS[mood][1]
        self.torch.manual_seed(500)
        wavs, rate = self.design.generate_voice_design(
            text=[text] * count, language="English", instruct=[f"{IDENTITY} {direction}"] * count,
            max_new_tokens=384)
        return [(np.asarray(w, dtype=np.float32).reshape(-1), int(rate)) for w in wavs]
```

**Chatterbox:**

```python
class Chatter:
    """Chatterbox clones each line from its mood's impression, acted by that mood's controls."""

    def __init__(self):
        import torch
        from chatterbox.tts import ChatterboxTTS
        self.torch = torch
        self.model = ChatterboxTTS.from_pretrained(device="cuda")

    def perform(self, text, mood, extra, seed):
        import numpy as np
        _, _, exaggeration, cfg, temperature, _ = MOODS[mood]
        self.torch.manual_seed(seed)
        wav = self.model.generate(
            text, audio_prompt_path=str(REF / f"{mood}.wav"),
            exaggeration=extra.get("exaggeration", exaggeration),
            cfg_weight=extra.get("cfg", cfg), temperature=extra.get("temperature", temperature))
        return wav.squeeze(0).cpu().numpy().astype(np.float32), int(self.model.sr)
```

**Impressions command** (writes candidates, picks automatically, writes `impressions.html`):

```python
def impressions(args):
    import shutil
    import soundfile as sf
    judge, qwen = Judge(), Qwen()
    CANDIDATES.mkdir(parents=True, exist_ok=True)
    moods = args.moods.split(",") if args.moods else list(MOODS)
    if "steady" in moods:
        moods = ["steady"] + [m for m in moods if m != "steady"]
    picks = dict(p.split("=") for p in args.pick or [])
    rows = []
    for mood in moods:
        print(f"[{mood}] {MOODS[mood][1]}", flush=True)
        scored = []
        for n, (samples, rate) in enumerate(qwen.perform(mood, args.candidates)):
            samples = trim(samples, rate)
            path = CANDIDATES / f"{mood}_{n}.wav"
            sf.write(path, level(samples, rate, MOODS[mood][5]), rate, subtype="PCM_16")
            heard = judge.hear(samples, rate)
            # Steady is measured against the approved anchor; every other mood against steady.
            anchor = REF / ("anchor.wav" if mood == "steady" else "steady.wav")
            ref, ref_rate = sf.read(anchor, dtype="float32")
            judge.anchor = judge.embed(ref, ref_rate)
            scored.append(dict(n=n, path=path, wer=wer(MOODS[mood][1], heard),
                               similarity=judge.similarity(samples, rate), heard=heard))
            print(f"    {n}: wer {scored[-1]['wer']:.2f} sim {scored[-1]['similarity']:.2f} | {heard}", flush=True)
        usable = [s for s in scored if s["wer"] <= 0.25] or scored
        chosen = int(picks[mood]) if mood in picks else max(usable, key=lambda s: s["similarity"])["n"]
        shutil.copyfile(CANDIDATES / f"{mood}_{chosen}.wav", REF / f"{mood}.wav")
        rows.append((mood, scored, chosen))
    write_page(REF.parent / "impressions.html", "Impressions", [
        (mood, [(f"ref/candidates/{s['path'].name}", f"#{s['n']}{' (picked)' if s['n'] == chosen else ''}",
                 f"wer {s['wer']:.2f} · sim {s['similarity']:.2f}") for s in scored])
        for mood, scored, chosen in rows])
```

**Review page writer** (shared):

```python
def write_page(path, title, groups):
    """A local listening page: groups of (src, label, detail) rows with an audio player each."""
    import html
    parts = [f"<!doctype html><meta charset=utf-8><title>{title}</title>",
             "<style>body{font:15px system-ui;margin:24px;max-width:980px}h2{margin-top:28px}"
             ".row{display:flex;gap:12px;align-items:center;margin:6px 0}.d{color:#777;font-size:13px}</style>",
             f"<h1>{title}</h1>"]
    for heading, rows in groups:
        parts.append(f"<h2>{html.escape(heading)}</h2>")
        for src, label, detail in rows:
            parts.append(f"<div class=row><audio controls preload=none src='{html.escape(src)}'></audio>"
                         f"<div>{html.escape(label)}<div class=d>{html.escape(detail)}</div></div></div>")
    path.write_text("\n".join(parts), encoding="utf-8")
```

**Bake (`main`)**, with flags `--engine chatterbox|kokoro` (default chatterbox), `--force`, `--only`, `--mood`, `--accept-bad`, `--scrap`, `--impressions`, `--moods`, `--candidates` (default 4), `--pick` (append), `--self-test`:
- **`--scrap`:** archives every `*.wav` in `OUT` plus `manifest.json` under the label `qwen`, then writes an empty manifest.
- **`--impressions`:** runs `impressions(args)`.
- **Otherwise it bakes:**
  - `todo = lines(json)`, filtered by `--only`/`--mood`
  - each line needing work gets `TAKES` Chatterbox takes (seeds 1..3), trimmed and scored with `Judge` (`judge.anchor` set to the embedding of `REF/<mood>.wav`)
  - takes with WER > `MAX_WER` are dropped, and the highest similarity wins
  - the winner is levelled with `MOODS[mood][5]` and written to `OUT/clip_name(...)`
  - any wav in `OUT` not in `keep` is archived, never deleted (skipped with `--only`/`--mood`)
- **Manifest:** `{"engine", "clips": [{text, mood, category, file, seconds, wer, similarity, engine:"chatterbox", reference:"<mood>.wav"}]}`.
- **Review page:** `build/voice/review.html`, written via `write_page` and grouped by category, with `src` = `../../assets/audio/voice/<file>` and detail `"[mood] wer · sim"`.

**`self_test()`:**

```python
def self_test():
    assert clip_name("a", "b") == hashlib.sha256(b"a|b").hexdigest() + ".wav"
    assert wer("Mathilda... please.", "Mathilda, please") == 0.0
    assert wer("Mathilda!", "Matilda!") == 0.0
    assert wer("two cups", "two cups here") == 0.5
    data = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    every = lines(data)
    assert len(every) == 137, len(every)
    assert all(mood in MOODS for _, _, mood, _ in every), {m for _, _, m, _ in every} - set(MOODS)
    assert len(MOODS) == 14 and all(len(v) == 6 and v[1] for v in MOODS.values())
    assert any(extra.get("exaggeration") == 0.9 for _, text, _, extra in every if text == "Go, then!")
    print("SELF-TEST PASS")
```

- [ ] **Step 3: Self-test.** `python tools/bake_speech.py --self-test` → `SELF-TEST PASS`.

- [ ] **Step 4: Commit** `tools/bake_speech.py`: "Rebuild the voice baker around per-mood impressions and Chatterbox, with archived clips and a listening page."

---

### Task 5: Perform her

**Files:** output only (`assets/audio/voice/*.wav`, `manifest.json`).

- [ ] **Step 1: Scrap the old takes into the archive.** Run `python tools/bake_speech.py --scrap`, then check that `build/voice/archive/<date>-qwen/` holds the old wavs and that `assets/audio/voice/` has no wavs.

- [ ] **Step 2: Impressions.** Run `build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --impressions`. Expected: 14 moods × 4 candidates, a pick per mood, and `build/voice/impressions.html`. If any mood's best similarity is below 0.55, re-run that mood alone with `--moods <m>`; Qwen seeds differ per batch size, so use `--candidates 6`.

- [ ] **Step 3: Bake.** Run `$env:HF_HOME = "$PWD\build\voice\hf\cache"; build/voice/cb-venv/Scripts/python.exe tools/bake_speech.py --force`. Expected: 137 lines baked, a WER and similarity printed for each, `build/voice/review.html`, exit 0. Re-run failures with `--only`. If a line fails three times, re-run it with `--accept-bad` and list it in the final report.

- [ ] **Step 4: Import and probe the clips**

```powershell
godot-mono --headless --path . --import
$env:PROBE_CLIPS = "1"; godot-mono --headless --path . tools/voice_probe.tscn; Remove-Item Env:PROBE_CLIPS
```

Expected: `VOICE PASS` with 137 `PASS clip for:` lines.

- [ ] **Step 5: Commit** `assets/audio/voice/`: "Perform all 137 of her lines fresh with Chatterbox, each cloned from an impression of its mood."

---

### Task 6: Docs and the final check

**Files:** `docs/VOICE.md`, `assets/audio/voice/README.md`, `CLAUDE.md`, `AGENTS.md`

- [ ] **Step 1: Update `docs/VOICE.md` and `assets/audio/voice/README.md`.**
  - The script of record and `tools/script_to_lines.py`.
  - The 14 moods; the groups and triggers (Tune names); the answers.
  - The pipeline: `--scrap`, `--impressions` (gpu-venv), the bake (cb-venv, `HF_HOME`), `review.html`/`impressions.html`, `--pick`, `--only`, `--mood`, and that nothing is ever deleted.
  - Licences: Chatterbox MIT, Qwen3-TTS Apache-2.0, faster-whisper MIT, SpeechBrain Apache-2.0.

- [ ] **Step 2: Update `CLAUDE.md` and `AGENTS.md`** (keep them consistent): the Voice paragraph (Chatterbox, impressions, the groups, answers, never-delete), `Game.turned_around` with the third ending, `Player.exhausted`/`landed_hard`/`facing()`, the `RUN_ENDING` dev hook, and the `script_to_lines.py` command.

- [ ] **Step 3: Final verification**

```powershell
python tools/script_to_lines.py --check
python tools/bake_speech.py --self-test
godot-mono --headless --path . --import
godot-mono --headless --path . tools/journal_probe.tscn
$env:PROBE_CLIPS = "1"; godot-mono --headless --path . tools/voice_probe.tscn; Remove-Item Env:PROBE_CLIPS
godot-mono --headless --path . tools/note_access_probe.tscn
$env:RUN_CAPTURE = "1"; $env:RUN_SHOT_FRAME = "20"; $env:RUN_SHOT = "$PWD\build\shots\intro.png"; godot-mono --path .
Remove-Item Env:RUN_SHOT_FRAME
$env:RUN_ENDING = "prints"; $env:RUN_SHOT = "$PWD\build\shots\prints.png"; godot-mono --path .
$env:RUN_ENDING = "road"; $env:RUN_SHOT = "$PWD\build\shots\road.png"; godot-mono --path .
Remove-Item Env:RUN_CAPTURE, Env:RUN_SHOT, Env:RUN_ENDING
```

Expected: all PASS, three screenshots that render (inspect them), and no `SCRIPT ERROR`.

- [ ] **Step 4: Commit** the docs: "Document her performed voice, the answers, and the third ending."
