class_name Errand
extends RefCounted

## One errand from assets/errands/errands.json: what she has noticed needs
## doing, how far along it is, and its line in the journal's Undone list.
## Errands owns every Errand and is the only thing that changes their state.

enum State { UNKNOWN, KNOWN, DONE, LET_GO }

var id := ""
var state: State = State.UNKNOWN
## Index into steps: the step whose prose the journal shows while it is known.
var step := 0
## Per-errand notes the world pieces keep (saved with it).
var flags: Dictionary = {}
## [{"id", "undone"}] in order.
var steps: Array[Dictionary] = []
var done := ""
var let_go := ""
var requires: PackedStringArray = []


static func from_data(data: Dictionary) -> Errand:
	var errand := Errand.new()
	errand.id = str(data.get("id", ""))
	for entry: Variant in data.get("steps", []):
		if entry is Dictionary:
			errand.steps.append({"id": str(entry.get("id", "")), "undone": str(entry.get("undone", ""))})
	errand.done = str(data.get("done", ""))
	errand.let_go = str(data.get("let_go", ""))
	for other: Variant in data.get("requires", []):
		errand.requires.append(str(other))
	return errand


## The index of a step by its id, or -1.
func step_index(step_id: String) -> int:
	for index in steps.size():
		if steps[index].id == step_id:
			return index
	return -1


func step_id() -> String:
	return str(steps[step].id) if step >= 0 and step < steps.size() else ""


## Her words for it as it stands now; empty while she knows nothing of it.
func undone_text() -> String:
	match state:
		State.KNOWN:
			return str(steps[clampi(step, 0, steps.size() - 1)].undone) if not steps.is_empty() else ""
		State.DONE:
			return done
		State.LET_GO:
			return let_go
	return ""


## Every prose string it carries (the probe checks them for digits).
func prose() -> PackedStringArray:
	var all := PackedStringArray()
	for entry in steps:
		all.append(str(entry.undone))
	all.append(done)
	all.append(let_go)
	return all
